// InboxView.swift — Screen 06
//
// Thread list with unread badges. Port of `InboxScreen` at ios-app.jsx
// line 578. Each row: counter-party name, last message preview, time,
// optional gold unread badge.

import SwiftUI
import DesignSystem

public struct InboxView: View {
    @Bindable var nav: NavigationModel

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                VStack(spacing: R.S.xs) {
                    ForEach(MockData.inbox) { thread in
                        Row(thread: thread) {
                            nav.push(.thread(threadID: thread.id))
                        }
                    }
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.lg)
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
            let unreadCount = MockData.inbox.map(\.unread).reduce(0, +)
            Text("\(unreadCount) unread")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Row: View {
    let thread: MockInboxThread
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                Cover(seed: thread.who, size: 44, cornerRadius: R.Rad.md)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(thread.who)
                            .font(R.F.body(14, weight: .semibold))
                            .foregroundStyle(R.C.fg1)
                        Spacer()
                        Text(thread.time)
                            .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
                    }
                    Text(thread.last)
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
}

#if DEBUG
#Preview("InboxView") {
    let nav = NavigationModel()
    return InboxView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
