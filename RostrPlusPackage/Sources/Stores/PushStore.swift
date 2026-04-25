// PushStore.swift
//
// iOS push notification registration. Owns the APNs token lifecycle:
//   1. View kicks `requestAuthorization()` on a relevant moment (e.g.
//      first sign-in, or a permissions prompt on the Settings screen).
//   2. UIApplication calls back with an APNs device token (Data).
//      The app shell hands it to `register(token:for:)`, which
//      upserts it into public.device_tokens scoped to the user.
//   3. On sign-out, `clearToken(for:)` deletes the token so notifs
//      for the previous user don't reach the device.
//
// The server-side trigger on public.notifications fans out to
// send-push which reads device_tokens for the recipient; no per-push
// iOS work is needed beyond registration.

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

@Observable
@MainActor
public final class PushStore {

    public enum Authorization: String, Sendable {
        case notDetermined
        case denied
        case authorized
        case provisional
    }

    public private(set) var authorization: Authorization = .notDetermined
    public private(set) var lastRegisteredToken: String?
    public private(set) var lastError: String?

    private let client = RostrSupabase.shared

    public init() {}

    // MARK: — Auth prompt

    /// Request push permission from the user. Call on a contextual
    /// moment (after first sign-in or when they tap a "turn on
    /// notifications" row). Safe to call repeatedly — iOS only shows
    /// the prompt once.
    public func requestAuthorization() async {
        #if canImport(UIKit)
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            authorization = granted ? .authorized : .denied
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            lastError = error.localizedDescription
            authorization = .denied
        }
        #endif
    }

    /// Refresh the cached authorization state from UNUserNotificationCenter.
    /// Call on app-foreground so a permission change made in Settings
    /// is picked up.
    public func refreshAuthorization() async {
        #if canImport(UIKit)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:  authorization = .notDetermined
        case .denied:         authorization = .denied
        case .authorized:     authorization = .authorized
        case .provisional:    authorization = .provisional
        case .ephemeral:      authorization = .provisional
        @unknown default:     authorization = .notDetermined
        }
        #endif
    }

    // MARK: — Token lifecycle

    /// Upsert the APNs device token against the signed-in user. Called
    /// from the UIApplicationDelegate
    /// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    /// after iOS hands us raw bytes.
    public func register(rawTokenData: Data, for userID: UUID) async {
        let token = rawTokenData.map { String(format: "%02x", $0) }.joined()
        await register(token: token, for: userID)
    }

    /// Upsert a hex-encoded APNs token. Exposed separately so tests
    /// (and any non-UIKit host) can go through the same path without
    /// synthesising a Data.
    public func register(token: String, for userID: UUID) async {
        lastRegisteredToken = token
        lastError = nil

        struct Row: Encodable {
            let user_id: UUID
            let token: String
            let platform: String
            let environment: String
            let app_version: String?
            let last_seen_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let row = Row(
            user_id: userID,
            token: token,
            platform: "ios",
            environment: Self.currentAPNSEnvironment,
            app_version: Self.appVersion,
            last_seen_at: now
        )

        do {
            _ = try await client
                .from("device_tokens")
                .upsert(row, onConflict: "token")
                .execute()
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
            print("PushStore.register failed:", error)
            #endif
        }
    }

    /// Remove the last-registered token for this user — called on
    /// sign-out so the device stops receiving notifications for the
    /// previous account.
    public func clearToken(for userID: UUID) async {
        guard let token = lastRegisteredToken else { return }
        do {
            _ = try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userID)
                .eq("token", value: token)
                .execute()
            lastRegisteredToken = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: — Env

    /// Debug builds hit the APNs sandbox, release builds hit production.
    /// The `environment` column on device_tokens lets the server-side
    /// dispatcher pick the right host per token.
    private static var currentAPNSEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private static var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    // MARK: — App-shell bridge

    /// NotificationCenter name the app shell posts on when UIKit hands
    /// us an APNs token. The package listens on this notification so
    /// the AppDelegate can stay thin.
    ///
    /// Post from your UIApplicationDelegate:
    ///   application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
    /// with `object: deviceToken` (a `Data`).
    public static let tokenReceivedNotification = Notification.Name(
        "rostr.push.tokenReceived"
    )

    /// Companion notification for APNs registration failure. Post
    /// `object: error` (any Error) from your AppDelegate's
    /// `didFailToRegisterForRemoteNotificationsWithError`.
    public static let registrationFailedNotification = Notification.Name(
        "rostr.push.registrationFailed"
    )

    #if DEBUG
    /// Test seam — set the authorization + token without touching UIKit
    /// or the network.
    public func _testSet(authorization: Authorization, token: String? = nil) {
        self.authorization = authorization
        self.lastRegisteredToken = token
    }
    #endif
}
