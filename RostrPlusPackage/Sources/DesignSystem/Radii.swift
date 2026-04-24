// Radii.swift
//
// Corner radius scale from the handoff README:
// 6 / 8 / 9 / 10 / 11 / 12 / 13 / 14 / 16 / 18 / 20 / 24 / 99 (pill)
//
// Button radius is typically 13–14. Cards 14–20. Pills 99.

import CoreGraphics

public extension R {
    enum Rad {
        public static let xs:      CGFloat = 6
        public static let sm:      CGFloat = 8
        public static let md:      CGFloat = 10
        public static let mdPlus:  CGFloat = 12
        public static let button:  CGFloat = 13
        public static let button2: CGFloat = 14
        public static let card:    CGFloat = 16
        public static let card2:   CGFloat = 18
        public static let card3:   CGFloat = 20
        public static let xl:      CGFloat = 24
        public static let tabBar:  CGFloat = 28
        public static let pill:    CGFloat = 99
    }
}
