// HapticsTests.swift
//
// Guards the one branching decision in the Haptics gate: how an unset
// vs. explicitly-set "hapticsEnabled" UserDefaults key resolves. The
// actual feedback firing is a UIKit side-effect we can't assert in a
// unit test — but the enable/disable policy is pure and must stay
// default-on so first-launch users (who never opened Settings) still
// feel haptics.

import Testing
import Foundation
@testable import RostrPlusFeature

@Suite("Haptics — enable policy", .serialized)
struct HapticsTests {

    private var key: String { Haptics.defaultsKey }

    @Test("Unset key defaults to enabled (matches @AppStorage default-on)")
    func unsetDefaultsEnabled() {
        UserDefaults.standard.removeObject(forKey: key)
        #expect(Haptics.isEnabled == true)
    }

    @Test("Explicit false disables")
    func explicitFalseDisables() {
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        #expect(Haptics.isEnabled == false)
    }

    @Test("Explicit true enables")
    func explicitTrueEnables() {
        UserDefaults.standard.set(true, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        #expect(Haptics.isEnabled == true)
    }
}
