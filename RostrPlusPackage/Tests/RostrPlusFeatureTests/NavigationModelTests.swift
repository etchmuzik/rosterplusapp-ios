// NavigationModelTests.swift
//
// Verifies the navigation primitives match the InteractiveDevice
// behaviour in ios-app.jsx — push/pop, tab-switch clears the stack,
// role-switch clears the stack.

import Testing
@testable import RostrPlusFeature

@MainActor
@Suite("NavigationModel")
struct NavigationModelTests {

    @Test("Fresh model starts on Home tab with empty stack")
    func freshDefaults() {
        let nav = NavigationModel()
        #expect(nav.tab == .home)
        #expect(nav.role == .promoter)
        #expect(nav.stack.isEmpty)
        #expect(nav.top == nil)
    }

    @Test("push adds a route, pop removes it")
    func pushPop() {
        let nav = NavigationModel()
        nav.push(.artist(artistID: "abc"))
        #expect(nav.stack.count == 1)
        #expect(nav.top == .artist(artistID: "abc"))

        nav.pop()
        #expect(nav.stack.isEmpty)
        #expect(nav.top == nil)
    }

    @Test("Switching tabs clears any open detail stack")
    func tabSwitchClearsStack() {
        let nav = NavigationModel()
        nav.push(.artist(artistID: "abc"))
        nav.push(.booking(artistID: "abc"))
        #expect(nav.stack.count == 2)

        nav.setTab(.bookings)
        #expect(nav.tab == .bookings)
        #expect(nav.stack.isEmpty, "switching tabs should pop all detail routes")
    }

    @Test("Re-tapping the same tab preserves the stack")
    func sameTabPreservesStack() {
        let nav = NavigationModel()
        nav.push(.thread(threadID: "xyz"))
        nav.setTab(.home)  // already on .home
        #expect(nav.top == .thread(threadID: "xyz"), "same-tab tap must not clear stack")
    }

    @Test("Role switch clears the stack")
    func roleSwitchClearsStack() {
        let nav = NavigationModel()
        nav.push(.notifications)
        nav.setRole(.artist)
        #expect(nav.role == .artist)
        #expect(nav.stack.isEmpty)
    }

    @Test("pop on empty stack is a no-op")
    func popEmpty() {
        let nav = NavigationModel()
        nav.pop()
        #expect(nav.stack.isEmpty)
    }
}
