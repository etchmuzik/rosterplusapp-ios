// Motion.swift
//
// Easing + duration scale from the handoff README:
//   ease-out: cubic-bezier(0.16, 1, 0.3, 1)
//   fast:     150ms   (micro-interactions — hover, pill press)
//   default:  200-250ms (screen transitions, most state changes)
//   entry:    400-600ms (first-paint reveals, onboarding slides)
//
// SwiftUI has no first-class cubic-bezier constructor; Animation.timingCurve
// is the closest. For previews we also export the raw Animation values
// so tests can pattern-match against them.

import SwiftUI

public extension R {
    enum M {

        // MARK: Durations
        public static let fast:    TimeInterval = 0.15
        public static let base:    TimeInterval = 0.22
        public static let ease:    TimeInterval = 0.28
        public static let entry:   TimeInterval = 0.5

        // MARK: Animations
        //
        // `easeOut` approximates the designer's cubic-bezier(0.16, 1, 0.3, 1).
        // SwiftUI's .timingCurve(_:_:_:_:duration:) takes control points in
        // the 0–1 space exactly as CSS does, so this is a direct port.

        public static let easeOutFast:  Animation = .timingCurve(0.16, 1, 0.3, 1, duration: fast)
        public static let easeOut:      Animation = .timingCurve(0.16, 1, 0.3, 1, duration: base)
        public static let easeOutSlow:  Animation = .timingCurve(0.16, 1, 0.3, 1, duration: entry)

        // MARK: Reduced-motion guard
        //
        // Check `accessibilityReduceMotion` in views and swap to this when
        // the user has the toggle on. README rule: "Respect
        // prefers-reduced-motion".
        public static let reducedMotion: Animation = .linear(duration: 0)
    }
}
