// Spacing.swift
//
// Spacing scale from the handoff README (§Spacing scale):
// 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / 20 / 22 / 24 / 28 / 32 / 40 / 48 / 64 / 80
//
// SwiftUI layouts lean heavily on these literals — .padding(R.S.md),
// .spacing(R.S.sm) — so they deserve short names. One-letter-ish.

import CoreGraphics

public extension R {
    enum S {
        public static let hairline: CGFloat = 0.5   // glass borders
        public static let xxxs:     CGFloat = 4
        public static let xxs:      CGFloat = 6
        public static let xs:       CGFloat = 8
        public static let sm:       CGFloat = 10
        public static let md:       CGFloat = 12
        public static let md2:      CGFloat = 14
        public static let lg:       CGFloat = 16
        public static let lg2:      CGFloat = 18
        public static let xl:       CGFloat = 20
        public static let xl2:      CGFloat = 22
        public static let xxl:      CGFloat = 24
        public static let xxl2:     CGFloat = 28
        public static let xxxl:     CGFloat = 32
        public static let huge:     CGFloat = 40
        public static let huge2:    CGFloat = 48
        public static let giant:    CGFloat = 64
        public static let giant2:   CGFloat = 80
    }
}
