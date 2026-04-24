// InboxView.swift — Screen 06
//
// Thread list with unread badges. Port of `InboxScreen` at ios-app.jsx
// line 578. Wave 5.1: threads are derived from public.messages (there
// is no separate threads table) via InboxStore.

import SwiftUI
import DesignSystem

public struct InboxView: View {
    @Bindable var nav: NavigationModel
    @Environment(InboxStore.self) private var store

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)

                switch store.state {
                case .idle, .loading:
                    loadingSkeleton
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)

                case .failed(let message):
                    failureCard(message)
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)

                case .loaded:
                    if store.threads.isEmpty {
                        emptyState
                            .padding(.horizontal, R.S.lg)
                            .padding(.top, R.S.xl)
                    } else {
                        VStack(spacing: R.S.xs) {
                            ForEach(store.threads) { thread in
                                Row(thread: thread) {
                                    nav.push(.thread(threadID: thread.id))
                                }
                            }
                        }
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)
                    }
                }

                Color.clear.frame(height: 100)
            }
        }
        .background(R.C.bg0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inbox")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(store.unreadCount) unread")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: — Loading / empty / failure

    private var loadingSkeleton: some View {
        VStack(spacing: R.S.xs) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 64)
            }
        }
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(spacing: R.S.xs) {
            Text("No conversations yet")
                .font(R.F.body(14, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text("Messages about a booking land here.")
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Couldn't load inbox")
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
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.red.opacity(0.25), lineWidth: R.S.hairline)
        }
    }
}

// MARK: - Row

private struct Row: View {
    let thread: InboxThread
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                Cover(seed: thread.counterpartyName, size: 44, cornerRadius: R.Rad.md)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(thread.counterpartyName)
                            .font(R.F.body(14, weight: .semibold))
                            .foregroundStyle(R.C.fg1)
                        Spacer()
                        Text(Self.timeFormatter.string(from: thread.lastAt))
                            .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
                    }
                    Text(thread.lastMessage)
                        .font(R.F.body(12.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                        .lineLimit(1)
                }
                if thread.unread > 0 {
                    Text("\(thread.unread)")
                        .font(R.F.mono(10, weight: .bold))
                        .foregroundStyle(R.C.bg0)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 5)
                        .background {
                            Capsule().fill(R.C.amber)
                        }
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }

    /// Display: "14:20" when today, "Mon" within the week, else "6 Apr".
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = false
        f.dateFormat = "HH:mm"
        return f
    }()
}

#if DEBUG
#Preview("InboxView") {
    let nav = NavigationModel()
    let store = InboxStore()
    let me = UUID()
    let other = UUID()
    let bookingID = UUID()
    store._testLoad(
        userID: me,
        messages: [
            MessageDTO(
                id: UUID(), senderID: other, receiverID: me,
                bookingID: bookingID,
                content: "Sending the updated set list by EOD.",
                read: false,
                createdAt: Date().addingTimeInterval(-600)
            )
        ],
        names: [other: "MIRELA"]
    )
    return InboxView(nav: nav)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
