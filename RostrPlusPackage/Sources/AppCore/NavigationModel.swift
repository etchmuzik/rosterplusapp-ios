// NavigationModel.swift
//
// Single source of truth for app navigation. Directly mirrors the
// `InteractiveDevice` component in ios-app.jsx (line 759):
//
//   const [tab, setTab]     = useState('home');
//   const [role, setRole]   = useState('promoter');
//   const [stack, setStack] = useState([]);
//   const push = v => setStack([...stack, v]);
//   const pop  = () => setStack(stack.slice(0, -1));
//   const top  = stack[stack.length - 1];
//
// Translated to @Observable so SwiftUI views can bind to it.
// @MainActor because every mutation happens from view code.

import Foundation
import SwiftUI
import Observation

public enum Role: String, Hashable, Sendable {
    case promoter
    case artist
}

@Observable
@MainActor
public final class NavigationModel {
    public var tab: TabBar.Tab = .home
    public var role: Role = .promoter

    /// Push stack for detail screens. `top` is whatever the user is
    /// currently looking at over the tab's root. nil = no overlay.
    public private(set) var stack: [Route] = []

    public init() {}

    public var top: Route? { stack.last }

    /// Push a route onto the detail stack.
    public func push(_ route: Route) {
        stack.append(route)
    }

    /// Pop the top route. No-op if the stack is empty.
    public func pop() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    /// Clear the entire detail stack. Called when switching tabs, per
    /// the JSX prototype's behaviour (tapping a different tab resets
    /// the overlay even if you were deep in a detail flow).
    public func clearStack() {
        stack.removeAll()
    }

    /// Change the active tab and clear any detail overlay.
    public func setTab(_ tab: TabBar.Tab) {
        if self.tab != tab { clearStack() }
        self.tab = tab
    }

    /// Toggle promoter ↔ artist role. Clears the stack because the
    /// two roles expose different detail screens (e.g. artist
    /// dashboard routes to availability editor, promoter doesn't).
    public func setRole(_ role: Role) {
        if self.role != role { clearStack() }
        self.role = role
    }
}
