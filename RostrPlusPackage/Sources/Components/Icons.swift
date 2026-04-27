// Icons.swift
//
// Line icons used across the 23 screens, translated from the inline SVG
// paths in ios-app.jsx into SwiftUI Shape views.
//
// Why not SF Symbols? Because the JSX designer picked paths that are
// visibly distinct from Apple's defaults (e.g. the inbox tab icon is a
// flat envelope with a corner pennant, not the SF speech-bubble). Using
// SF Symbols would subtly drift the brand.
//
// Each icon is a Shape, so callers can .stroke(...) with the weight +
// color they want. All designed on a 24×24 grid to match the JSX viewBox.

import SwiftUI

public struct TabIcon: Shape {
    public enum Kind: Sendable {
        case home, roster, bookings, inbox, me
    }

    let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }

    public func path(in rect: CGRect) -> Path {
        // Normalize to 24×24 viewBox space
        let s = min(rect.width, rect.height) / 24
        let x = (rect.width  - 24 * s) / 2
        let y = (rect.height - 24 * s) / 2
        var p = Path()

        switch kind {
        case .home:
            // M3 10l9-7 9 7v11a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1z
            p.move(to: CGPoint(x: x + 3*s, y: y + 10*s))
            p.addLine(to: CGPoint(x: x + 12*s, y: y + 3*s))
            p.addLine(to: CGPoint(x: x + 21*s, y: y + 10*s))
            p.addLine(to: CGPoint(x: x + 21*s, y: y + 21*s))
            p.addLine(to: CGPoint(x: x + 15*s, y: y + 21*s))
            p.addLine(to: CGPoint(x: x + 15*s, y: y + 14*s))
            p.addLine(to: CGPoint(x: x + 9*s,  y: y + 14*s))
            p.addLine(to: CGPoint(x: x + 9*s,  y: y + 21*s))
            p.addLine(to: CGPoint(x: x + 3*s,  y: y + 21*s))
            p.closeSubpath()

        case .roster:
            // Three horizontal lines — M4 5h16M4 12h16M4 19h10
            for (start, end) in [
                (CGPoint(x: 4*s, y: 5*s),  CGPoint(x: 20*s, y: 5*s)),
                (CGPoint(x: 4*s, y: 12*s), CGPoint(x: 20*s, y: 12*s)),
                (CGPoint(x: 4*s, y: 19*s), CGPoint(x: 14*s, y: 19*s))
            ] {
                p.move(to: CGPoint(x: x + start.x, y: y + start.y))
                p.addLine(to: CGPoint(x: x + end.x, y: y + end.y))
            }

        case .bookings:
            // Bookmark outline — M5 4h14a1 1 0 011 1v15l-4-2-4 2-4-2-4 2V5a1 1 0 011-1z
            p.move(to: CGPoint(x: x + 5*s, y: y + 4*s))
            p.addLine(to: CGPoint(x: x + 19*s, y: y + 4*s))
            p.addLine(to: CGPoint(x: x + 20*s, y: y + 5*s))
            p.addLine(to: CGPoint(x: x + 20*s, y: y + 20*s))
            p.addLine(to: CGPoint(x: x + 16*s, y: y + 18*s))
            p.addLine(to: CGPoint(x: x + 12*s, y: y + 20*s))
            p.addLine(to: CGPoint(x: x + 8*s,  y: y + 18*s))
            p.addLine(to: CGPoint(x: x + 4*s,  y: y + 20*s))
            p.addLine(to: CGPoint(x: x + 4*s,  y: y + 5*s))
            p.closeSubpath()

        case .inbox:
            // Envelope with corner pennant — M4 4h16v12H7l-3 3z
            p.move(to: CGPoint(x: x + 4*s,  y: y + 4*s))
            p.addLine(to: CGPoint(x: x + 20*s, y: y + 4*s))
            p.addLine(to: CGPoint(x: x + 20*s, y: y + 16*s))
            p.addLine(to: CGPoint(x: x + 7*s,  y: y + 16*s))
            p.addLine(to: CGPoint(x: x + 4*s,  y: y + 19*s))
            p.closeSubpath()

        case .me:
            // Person — head circle + shoulders arc
            // Circle for head at (12,8) r=4
            p.addEllipse(in: CGRect(
                x: x + 8*s, y: y + 4*s,
                width: 8*s, height: 8*s
            ))
            // Shoulders — rounded bucket M5 19v1h14v-1c0-2.8-3-5-7-5s-7 2.2-7 5z
            p.move(to: CGPoint(x: x + 5*s, y: y + 20*s))
            p.addLine(to: CGPoint(x: x + 5*s, y: y + 19*s))
            p.addCurve(
                to: CGPoint(x: x + 12*s, y: y + 14*s),
                control1: CGPoint(x: x + 5*s, y: y + 16.2*s),
                control2: CGPoint(x: x + 8*s, y: y + 14*s)
            )
            p.addCurve(
                to: CGPoint(x: x + 19*s, y: y + 19*s),
                control1: CGPoint(x: x + 16*s, y: y + 14*s),
                control2: CGPoint(x: x + 19*s, y: y + 16.2*s)
            )
            p.addLine(to: CGPoint(x: x + 19*s, y: y + 20*s))
            p.closeSubpath()
        }

        return p
    }
}

/// Convenience view that renders a TabIcon as a stroked line — the form
/// the floating tab bar actually wants. Separate from the Shape so tests
/// can still inspect the raw path.
public struct TabIconView: View {
    let kind: TabIcon.Kind
    let size: CGFloat
    let color: Color
    let filled: Bool

    public init(_ kind: TabIcon.Kind, size: CGFloat = 20, color: Color = .white, filled: Bool = false) {
        self.kind = kind
        self.size = size
        self.color = color
        self.filled = filled
    }

    public var body: some View {
        Group {
            if filled {
                TabIcon(kind).fill(color)
            } else {
                TabIcon(kind).stroke(color, style: .init(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: Bell (notifications) + chevron + chart — used outside the tab bar

public struct BellIcon: View {
    let size: CGFloat
    let color: Color
    public init(size: CGFloat = 18, color: Color = .white) {
        self.size = size; self.color = color
    }
    public var body: some View {
        // SF Symbol is fine here — the JSX draws a plain bell which
        // matches bell.fill / bell exactly. Chose outline for a-a
        // consistency with other tab icons.
        //
        // Marked accessibilityHidden because every callsite wraps this
        // in a Button with its own .accessibilityLabel ("Notifications",
        // etc.). Without this VoiceOver double-announces "bell, button"
        // followed by the parent's label.
        Image(systemName: "bell")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

public struct ChevronRightIcon: View {
    let size: CGFloat
    let color: Color
    public init(size: CGFloat = 14, color: Color = .white) {
        self.size = size; self.color = color
    }
    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

public struct ChartIcon: View {
    let size: CGFloat
    let color: Color
    public init(size: CGFloat = 18, color: Color = .white) {
        self.size = size; self.color = color
    }
    public var body: some View {
        Image(systemName: "chart.bar")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
