// ArtistPhoto.swift
//
// Resolves an artist's bundled portrait by handle, mirroring the web
// app's `artistPhotoSrc()` convention (web/assets/images/artists/<handle>.jpg).
// The JPGs are bundled under Resources/artists/ in this package; this
// helper loads them from Bundle.module and hands a SwiftUI Image to the
// Cover component. Returns nil when no photo exists for the handle, so
// Cover falls back to its seeded gradient.
//
// This is the iOS counterpart to the web's three-tier photo chain
// (avatar_url → bundled handle photo → initials/gradient). Today iOS
// covers tiers 2 and 3; the remote avatar_url tier can layer on later
// via the same Cover `image:` parameter.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ArtistPhoto {

    /// A few DB handles don't match their on-disk filename exactly
    /// (the web assets predate the handle backfill). Normalise here.
    private static let filenameOverrides: [String: String] = [
        "eva-kim": "evakim",
    ]

    /// Derive a handle-style slug from a stage name when an explicit
    /// handle isn't threaded through (e.g. "ASHKAN K" → "ashkan-k",
    /// "ETCH" → "etch"). Lowercase, spaces→hyphens, strip the rest.
    public static func slug(fromStageName name: String) -> String {
        let lowered = name.lowercased()
        var out = ""
        var lastDash = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastDash = false
            } else if ch == " " || ch == "-" || ch == "_" {
                if !lastDash && !out.isEmpty { out.append("-"); lastDash = true }
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }

    /// Convenience: resolve a photo straight from a stage name.
    public static func image(forStageName name: String) -> Image? {
        image(forHandle: slug(fromStageName: name))
    }

    /// Returns the bundled portrait for a handle, or nil if none exists.
    public static func image(forHandle handle: String?) -> Image? {
        guard let handle, !handle.isEmpty else { return nil }
        let file = filenameOverrides[handle] ?? handle
        #if canImport(UIKit)
        // Resources/artists/<file>.jpg, bundled via the package's
        // Resources processing. Try the subdirectory first, then a flat
        // lookup (SwiftPM resource layout can vary by toolchain).
        let bundle = Bundle.module
        let url = bundle.url(forResource: file, withExtension: "jpg", subdirectory: "artists")
            ?? bundle.url(forResource: file, withExtension: "jpg")
        guard let url, let ui = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }
}
