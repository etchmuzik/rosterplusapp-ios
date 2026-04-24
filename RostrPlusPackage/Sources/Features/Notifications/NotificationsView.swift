// NotificationsView.swift — Screen 16
//
// Grouped activity feed. Port of `NotificationsScreen` at ios-app.jsx
// line 1443. Seven notification types, each with its own SF Symbol
// glyph + subtle tinted chip. Unread rows get a gold dot indicator.
//
// Tap routes to the relevant destination (booking detail, thread,
// invoice, etc.) per README §Interactions & behavior.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct NotificationsView: View {
    @Bindable var nav: NavigationModel

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Notifications", onBack: { nav.pop() }) {
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Text("Mark read")
                        .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg2)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background { Capsule().fill(R.C.glassLo) }
                        .overlay { Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark all as read")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.md) {
                    unreadSection
                    earlierSection
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.xs)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Sections

    private var unreadSection: some View {
        let items = MockData.notifications.filter(\.unread)
        return sectionIfAny(title: "Unread", items: items)
    }

    private var earlierSection: some View {
        let items = MockData.notifications.filter { !$0.unread }
        return sectionIfAny(title: "Earlier", items: items)
    }

    @ViewBuilder
    private func sectionIfAny(title: String, items: [MockNotification]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: R.S.xs) {
                Text(title)
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                    .padding(.top, R.S.xs)
                VStack(spacing: R.S.xs) {
                    ForEach(items) { n in
                        NotificationRow(notification: n) {
                            route(for: n)
                        }
                    }
                }
            }
        }
    }

    private func route(for n: MockNotification) {
        switch n.kind {
        case .booking, .calendar:
            nav.push(.bookingDetail(bookingID: n.id))
        case .message:
            nav.push(.thread(threadID: n.id))
        case .contract:
            nav.push(.contract(contractID: n.id))
        case .payment:
            nav.push(.invoice(bookingID: n.id))
        case .review:
            nav.push(.review(bookingID: n.id))
        case .profile:
            // Viewing your public profile = pushing the EPK as yourself.
            nav.push(.epk(artistID: "me"))
        }
    }
}

// MARK: - Row

private struct NotificationRow: View {
    let notification: MockNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: R.S.md) {
                glyphChip
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notification.title)
                            .font(R.F.body(13.5, weight: .semibold))
                            .foregroundStyle(R.C.fg1)
                        Spacer(minLength: R.S.xs)
                        Text(notification.when)
                            .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
                    }
                    Text(notification.body)
                        .font(R.F.body(12.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if notification.unread {
                    Circle()
                        .fill(R.C.amber)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                        .accessibilityLabel("Unread")
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }

    private var glyphChip: some View {
        let (symbol, color) = style(for: notification.kind)
        return ZStack {
            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                .fill(color.opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                .strokeBorder(color.opacity(0.24), lineWidth: R.S.hairline)
        }
    }

    private func style(for kind: MockNotification.Kind) -> (String, Color) {
        switch kind {
        case .booking:  return ("calendar",                  R.C.fg1)
        case .message:  return ("bubble.left.and.bubble.right", R.C.blue)
        case .payment:  return ("creditcard",                R.C.green)
        case .contract: return ("doc.text",                  R.C.blue)
        case .review:   return ("star.fill",                 R.C.amber)
        case .calendar: return ("calendar.badge.clock",      R.C.fg2)
        case .profile:  return ("person.fill",               R.C.fg2)
        }
    }
}

#if DEBUG
#Preview("NotificationsView") {
    let nav = NavigationModel()
    return NotificationsView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
