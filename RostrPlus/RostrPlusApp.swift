// RostrPlusApp.swift
//
// The app shell. Per CLAUDE.md guidance: this target is a thin wrapper
// that hands off to the feature package. Don't add feature code here —
// stick it in RostrPlusPackage/Sources/Features.
//
// Wave 5.8: we now also wire an AppDelegate adapter so UIKit can hand
// us APNs device tokens. The adapter forwards the token via a
// NotificationCenter post; the package's PushStore subscribes and
// upserts it into public.device_tokens. Keeping the bridge at the
// NotificationCenter layer means the package stays free of UIKit
// AppDelegate imports and the shell stays tiny.

import SwiftUI
import UIKit
import DesignSystem
import RostrPlusFeature

@main
struct RostrPlusApp: App {

    /// UIApplicationDelegate adapter — owns the APNs callbacks. It's
    /// the only piece of the shell that reaches into UIKit lifecycle.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Register bundled Fontshare + JetBrains fonts with CoreText
        // before SwiftUI's first render. Missing font files log a DEBUG
        // warning but don't crash — we fall back to SF Pro.
        R.F.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

// MARK: - AppDelegate

/// Bridge between UIKit's remote-notification callbacks and the
/// package's PushStore. Kept deliberately thin — four methods, no
/// business logic.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Kick off APNs registration on launch. iOS only shows the
    /// authorization prompt the first time PushStore.requestAuthorization()
    /// runs, but we always want to register for notifications so a
    /// previously-granted permission re-establishes its token on
    /// every launch.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// APNs handed us a fresh device token — forward to PushStore via
    /// NotificationCenter. The package listens for this notification
    /// name and upserts the token against the signed-in user.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationCenter.default.post(
            name: PushStore.tokenReceivedNotification,
            object: deviceToken
        )
    }

    /// APNs registration failed — bubble up so the package can surface
    /// diagnostics. We don't retry; iOS retries automatically on the
    /// next launch.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: PushStore.registrationFailedNotification,
            object: error
        )
    }

    /// Foreground notification handling is deferred to a future pass —
    /// for now the OS still shows the banner, we just don't do any
    /// custom in-app presentation.
}
