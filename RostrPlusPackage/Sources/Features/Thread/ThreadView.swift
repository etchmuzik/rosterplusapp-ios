// ThreadView.swift — Screen 07
//
// Real-time chat view. Port of `ThreadScreen` at ios-app.jsx line 1028.
// Wave 5.1: reads + writes through InboxStore (server: public.messages).
//
// Realtime subscriptions land in Wave 5.2 — for now the composer does
// an optimistic append via store.send() and the user can pull-to-refresh
// via the Inbox tab. Every in-app message is addressed (sender_id,
// receiver_id, booking_id); the thread id carries all three.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ThreadView: View {
    @Bindable var nav: NavigationModel
    @Environment(InboxStore.self) private var store
    let threadID: String

    @State private var draft: String = ""

    public init(nav: NavigationModel, threadID: String) {
        self.nav = nav
        self.threadID = threadID
    }

    private var messages: [ThreadMessage] {
        store.messages(for: threadID)
    }

    private var thread: InboxThread? {
        store.threads.first { $0.id == threadID }
    }

    private var headerName: String {
        thread?.counterpartyName ?? store.counterpartyName(for: threadID)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        emptyState
                            .padding(.top, R.S.xxl)
                    } else {
                        VStack(alignment: .leading, spacing: R.S.sm) {
                            ForEach(messages) { m in
                                Bubble(message: m).id(m.id)
                            }
                        }
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.md)
                        .padding(.bottom, R.S.md)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(R.M.easeOut) {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            composer
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var headerBar: some View {
        HStack(spacing: R.S.md) {
            Button {
                nav.pop()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
            }
            .buttonStyle(.plain)

            Cover(seed: headerName, size: 36, cornerRadius: R.Rad.md)
            VStack(alignment: .leading, spacing: 1) {
                Text(headerName)
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                HStack(spacing: 4) {
                    Circle().fill(R.C.green).frame(width: 5, height: 5)
                    Text("Online")
                        .monoLabel(size: 8.5, tracking: 0.6, color: R.C.fg3)
                }
            }
            Spacer()
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.xs)
    }

    // MARK: — Composer

    private var composer: some View {
        HStack(spacing: R.S.sm) {
            TextField(
                "",
                text: $draft,
                prompt: Text("Message…").foregroundStyle(R.C.fg3)
            )
            .foregroundStyle(R.C.fg1)
            .font(R.F.body(14))
            .padding(.horizontal, R.S.md)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSend ? R.C.bg0 : R.C.fg3)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(canSend ? R.C.fg1 : R.C.glassLo)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.sm)
        .background {
            R.C.bg0.opacity(0.96)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(R.C.borderSoft)
                        .frame(height: R.S.hairline)
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: R.S.xs) {
            Text("Start the conversation")
                .font(R.F.body(14, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text("Your first message sends in a thread about this booking.")
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, R.S.lg)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty && thread != nil
    }

    private func send() {
        guard canSend, let t = thread else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        store.send(
            content: draft,
            to: t.counterpartyID,
            bookingID: t.bookingID
        )
        draft = ""
    }
}

// MARK: - Bubble

private struct Bubble: View {
    let message: ThreadMessage

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: R.S.xxl) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(R.F.body(14, weight: .regular))
                    .foregroundStyle(message.isMine ? R.C.bg0 : R.C.fg1)
                    .padding(.horizontal, R.S.md)
                    .padding(.vertical, R.S.xs)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous)
                            .fill(message.isMine ? R.C.fg1 : R.C.glassLo)
                    }
                    .overlay {
                        if !message.isMine {
                            RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous)
                                .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                        }
                    }
                Text(Self.timeFormatter.string(from: message.sentAt))
                    .monoLabel(size: 8, tracking: 0.4, color: R.C.fg3)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
            if !message.isMine { Spacer(minLength: R.S.xxl) }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

#if DEBUG
#Preview("ThreadView") {
    let nav = NavigationModel()
    let store = InboxStore()
    let me = UUID()
    let other = UUID()
    let bookingID = UUID()
    store._testLoad(
        userID: me,
        messages: [
            MessageDTO(id: UUID(), senderID: other, receiverID: me, bookingID: bookingID,
                       content: "Good morning — quick one on soundcheck.", read: true,
                       createdAt: Date().addingTimeInterval(-7200)),
            MessageDTO(id: UUID(), senderID: me, receiverID: other, bookingID: bookingID,
                       content: "Shoot.", read: true,
                       createdAt: Date().addingTimeInterval(-7000))
        ],
        names: [other: "DJ NOVAK"]
    )
    return ThreadView(nav: nav, threadID: bookingID.uuidString)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
