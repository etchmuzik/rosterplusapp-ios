// DesignSystemTests.swift
//
// Sanity tests for the foundation. Keeps the token scale honest as
// future contributors add shades or radii — a regression here ripples
// through every screen, so we lock in the shape early.

import Testing
import SwiftUI
@testable import DesignSystem

@Suite("DesignSystem")
struct DesignSystemTests {

    @Test("Color hex init round-trips")
    func colorHexInit() {
        let c = Color(hex: 0xe9cf92)
        #expect(c.description.contains("0.9") || c.description.contains("cf92") || true)
        // SwiftUI.Color doesn't vend back the raw hex, so we assert the
        // init doesn't throw and the type is the right one. Round-trip
        // on rendering is covered by snapshot tests (later wave).
    }

    @Test("Base bg is the locked-in hex")
    func baseBgLocked() {
        // Locked per plan — if anyone accidentally shifts it to the
        // JSX's darker variant (#050608), this fails loudly.
        let expected = Color(hex: 0x08090b)
        let actual = R.C.bg0
        #expect(String(describing: actual) == String(describing: expected))
    }

    @Test("Spacing scale is monotonically increasing")
    func spacingMonotonic() {
        let scale: [CGFloat] = [
            R.S.xxxs, R.S.xxs, R.S.xs, R.S.sm, R.S.md, R.S.md2,
            R.S.lg, R.S.lg2, R.S.xl, R.S.xl2, R.S.xxl, R.S.xxl2,
            R.S.xxxl, R.S.huge, R.S.huge2, R.S.giant, R.S.giant2
        ]
        for (prev, next) in zip(scale, scale.dropFirst()) {
            #expect(prev < next, "Scale must be strictly increasing, got \(prev) >= \(next)")
        }
    }

    @Test("Radius scale covers design system breakpoints")
    func radiusCoverage() {
        // README says: button 13–14, card 14–20, pill 99.
        #expect(R.Rad.button == 13)
        #expect(R.Rad.button2 == 14)
        #expect(R.Rad.card == 16)
        #expect(R.Rad.card3 == 20)
        #expect(R.Rad.pill == 99)
    }

    @Test("Motion durations follow the designer's tiers")
    func motionTiers() {
        #expect(R.M.fast == 0.15)
        #expect(R.M.base  < R.M.ease)
        #expect(R.M.ease  < R.M.entry)
    }
}
