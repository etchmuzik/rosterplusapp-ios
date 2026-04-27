// ShareSheet.swift
//
// Thin SwiftUI wrapper around UIActivityViewController so any view in
// the package can present the iOS share sheet without reaching for
// UIKit lifecycle code. Hosted in a `.sheet`; the iOS-native chrome
// (handle, dismiss gesture, AirDrop / Messages / Mail / Copy options)
// comes for free.

#if canImport(UIKit)
import SwiftUI
import UIKit

public struct ShareSheet: UIViewControllerRepresentable {
    public let items: [Any]
    public let activities: [UIActivity]?

    public init(items: [Any], activities: [UIActivity]? = nil) {
        self.items = items
        self.activities = activities
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {
        // No-op — the items are captured at construction. Re-presenting
        // is handled by SwiftUI tearing down + recreating the wrapper.
    }
}
#endif
