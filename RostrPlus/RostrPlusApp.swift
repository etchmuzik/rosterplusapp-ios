// RostrPlusApp.swift
//
// The app shell. Per CLAUDE.md guidance: this target is a thin wrapper
// that hands off to the feature package. Don't add feature code here —
// stick it in RostrPlusPackage/Sources/Features.

import SwiftUI
import DesignSystem
import RostrPlusFeature

@main
struct RostrPlusApp: App {

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
