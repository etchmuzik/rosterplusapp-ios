// NotificationsView.swift — Screen 16
//
// Grouped activity feed. Port of `NotificationsScreen` at ios-app.jsx
// line 1443. Wave 5.1: backed by NotificationsStore (public.notifications).
//
// Tap routes to the relevant destination (booking detail, thread,
// invoice, etc.) using the foreign-key columns (booking_id/contract_id/
// payment_id) on each row. Marking read flips the DB column in place.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct NotificationsView: View {
    @Bindable var nav: NavigationModel
    @Environment(NotificationsStore.self) private var store
    @Environment(AuthStore.self) private var auth

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
                    for n in store.unread { store.markRead(n.id) }
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
                    switch store.state {
                    case .idle, .loading:
                        loadingSkeleton
                    case .failed(let message):
                        failureCard(message)
                    case .loaded:
                        unreadSection
                        earlierSection
                    }
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.xs)
            }
            .refreshable {
                guard let userID = auth.currentUserID else { return }
                store.refresh(for: userID)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Sections

    @ViewBuilder
    private var unreadSection: some View {
        sectionIfAny(title: "Unread", items: store.unread)
    }

    @ViewBuilder
    private var earlierSection: some View {
        sectionIfAny(title: "Earlier", items: store.read)
    }

    @ViewBuilder
    private func sectionIfAny(title: String, items: [NotificationRow]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: R.S.xs) {
                Text(title)
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                    .padding(.top, R.S.xs)
                VStack(spacing: R.S.xs) {
                    ForEach(items) { n in
                        NotificationCell(notification: n) {
                            if !n.read { store.markRead(n.id) }
                            route(for: n)
                        }
                    }
                }
            }
        }
    }

    // MARK: — Loading / failure

    private var loadingSkeleton: some View {
        VStack(spacing: R.S.xs) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 68)
            }
        }
        .redacted(reason: .placeholder)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Couldn't load notifications")
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg2)
        }
        .padding(R.S.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.red.opacity(0.08))
        }
    }

    // MARK: — Routing

    private func route(for n: NotificationRow) {
        switch n.kind {
        case .booking, .calendar:
            // Prefer the href if the server set one; else do nothing.
            if let href = n.href, let target = destination(from: href) {
                nav.push(target)
            }
        case .message:
            if let href = n.href, let target = destination(from: href) {
                nav.push(target)
            }
        case .contract:
            if let href = n.href, let target = destination(from: href) {
                nav.push(target)
            }
        case .payment:
            if let href = n.href, let target = destination(from: href) {
                nav.push(target)
            }
        case .review:
            if let href = n.href, let target = destination(from: href) {
                nav.push(target)
            }
        case .profile, .other:
            // Passive — profile notifications are informational only.
            break
        }
    }

    /// Thin wrapper around `Route.parse(href:)` so existing callsites
    /// don't need to change. Server hrefs share the shape used by
    /// universal links and APNs payloads.
    private func destination(from href: String) -> Route? {
        Route.parse(href: href)
    }
}

// MARK: - Row

private struct NotificationCell: View {
    let notification: NotificationRow
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
                        Text(Self.relative(notification.createdAt))
                            .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
                    }
                    Text(notification.body)
                        .font(R.F.body(12.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !notification.read {
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

    private func style(for kind: NotificationRow.Kind) -> (String, Color) {
        switch kind {
        case .booking:  return ("calendar",                     R.C.fg1)
        case .message:  return ("bubble.left.and.bubble.right", R.C.blue)
        case .payment:  return ("creditcard",                   R.C.green)
        case .contract: return ("doc.text",                     R.C.blue)
        case .review:   return ("star.fill",                    R.C.amber)
        case .calendar: return ("calendar.badge.clock",         R.C.fg2)
        case .profile:  return ("person.fill",                  R.C.fg2)
        case .other:    return ("bell",                         R.C.fg2)
        }
    }

    /// Short relative label: "2m ago", "Yesterday", "12 Apr".
    private static func relative(_ date: Date) -> String {
        let now = Date()
        let delta = now.timeIntervalSince(date)
        if delta < 60 { return "Just now" }
        if delta < 3600 { return "\(Int(delta / 60))m ago" }
        if delta < 86_400 { return "\(Int(delta / 3600))h ago" }
        if delta < 2 * 86_400 { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

#if DEBUG
#Preview("NotificationsView") {
    let nav = NavigationModel()
    let store = NotificationsStore()
    store._testLoad([
        NotificationRow(
            id: UUID(), kind: .booking, title: "DJ NOVAK accepted",
            body: "Your request for WHITE Dubai was accepted.",
            createdAt: Date().addingTimeInterval(-120), read: false,
            href: "/bookings/\(UUID().uuidString)"
        ),
        NotificationRow(
            id: UUID(), kind: .payment, title: "Payment scheduled",
            body: "AED 32K scheduled for 28 Apr.",
            createdAt: Date().addingTimeInterval(-3600 * 3), read: true,
            href: nil
        )
    ])
    return NotificationsView(nav: nav)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
