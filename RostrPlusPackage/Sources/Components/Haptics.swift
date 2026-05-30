// Haptics.swift
//
// Single gate for all haptic feedback in the app. Every call site routes
// through here so the Settings → Haptics toggle actually controls whether
// feedback fires. Before this existed, ~41 call sites fired
// UIImpactFeedbackGenerator / UINotificationFeedbackGenerator directly and
// the toggle was inert.
//
// The toggle is an `@AppStorage("hapticsEnabled")` Bool in SettingsView;
// we read the same UserDefaults key here. `@AppStorage` shows `true` by
// default when the key is ABSENT, but `UserDefaults.bool(forKey:)` returns
// `false` for an absent key — so we treat "key not set" as enabled to
// match the toggle's default-on behaviour for users who never opened
// Settings.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum Haptics {

    /// UserDefaults key shared with SettingsView's @AppStorage toggle.
    public static let defaultsKey = "hapticsEnabled"

    /// Default-on: an unset key means the user hasn't touched the toggle,
    /// so haptics are enabled (mirrors @AppStorage's default value).
    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    /// Light selection-style tap — the everyday "something happened" tick.
    @MainActor
    public static func tap() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Success notification feedback — completed a write, sent a thing.
    @MainActor
    public static func success() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Error notification feedback — a write failed, validation blocked.
    @MainActor
    public static func error() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Warning notification feedback — destructive confirmation (sign out).
    @MainActor
    public static func warning() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    /// Selection-changed feedback — moving through a picker / segmented set.
    @MainActor
    public static func selection() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
