// ThreadView.swift — Screen 07
//
// Real-time chat view. Port of `ThreadScreen` at ios-app.jsx line 1028.
// Layout:
//
//   NavHeader("DJ NOVAK") with avatar chip
//   ScrollView of message bubbles (mine right-aligned, theirs left)
//   Composer: text field + send button (glass bar, sticks to bottom)
//
// Realtime on public.messages lands with the real Supabase wire in a
// later pass. For now, mock messages render statically and the
// composer clears itself on send (locally appended).

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ThreadView: View {
    @Bindable var nav: NavigationModel
    let threadID: String

    @State private var messages: [MockMessage] = MockData.threadMessages
    @State private var draft: String = ""

    public init(nav: NavigationModel, threadID: String) {
        self.nav = nav
        self.threadID = threadID
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: R.S.sm) {
                        ForEach(messages) { m in
                            Bubble(message: m).id(m.id)
                        }
                    }
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                    .padding(.bottom, R.S.md)
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

            Cover(seed: "DJ NOVAK", size: 36, cornerRadius: R.Rad.md)
            VStack(alignment: .leading, spacing: 1) {
                Text("DJ NOVAK")
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

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func send() {
        guard canSend else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let time = Date().formatted(date: .omitted, time: .shortened)
        messages.append(.init(
            id: "local-\(UUID().uuidString.prefix(6))",
            from: "me",
            body: draft.trimmingCharacters(in: .whitespaces),
            time: time,
            isMine: true
        ))
        draft = ""
    }
}

// MARK: - Bubble

private struct Bubble: View {
    let message: MockMessage

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: R.S.xxl) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                Text(message.body)
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
                Text(message.time)
                    .monoLabel(size: 8, tracking: 0.4, color: R.C.fg3)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
            if !message.isMine { Spacer(minLength: R.S.xxl) }
        }
    }
}

#if DEBUG
#Preview("ThreadView") {
    let nav = NavigationModel()
    return ThreadView(nav: nav, threadID: "dj-novak")
        .preferredColorScheme(.dark)
}
#endif
