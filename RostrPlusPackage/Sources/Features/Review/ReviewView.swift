// ReviewView.swift — Screen 17
//
// Post-event mutual review. Port of `ReviewScreen` at ios-app.jsx
// line 1512. Layout:
//
//   NavHeader("Leave a review")
//   Context card   — who + when + event. So users know which booking
//                    they're rating.
//   Star picker    — 5 stars, role="radiogroup" semantics, gold fill
//                    on active. Tap or drag to set the value.
//   Quick tags     — 2×3 grid of suggestive chips (Punctual · Pro rider · …)
//                    Multi-select, gold outline on active.
//   Note           — TextEditor, 500-char counter, placeholder copy.
//   Submit CTA     — disabled until rating > 0; success haptic on submit.
//
// Matches the review card pattern on the web booking-detail page so
// iOS and web ask the same questions in the same order.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ReviewView: View {
    @Bindable var nav: NavigationModel
    let bookingID: String

    @State private var rating: Int = 0
    @State private var tags: Set<String> = []
    @State private var note: String = ""

    private let tagOptions = [
        "Punctual", "Pro rider", "Great energy",
        "Clean handover", "Smooth set", "Would rebook"
    ]

    public init(nav: NavigationModel, bookingID: String) {
        self.nav = nav
        self.bookingID = bookingID
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Leave a review", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    contextCard
                    starCard
                    tagsCard
                    noteCard
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
            submitBar
        }
        .background(R.C.bg0)
    }

    // MARK: — Context card

    private var contextCard: some View {
        HStack(spacing: R.S.md) {
            Cover(seed: "KARIMA-N", size: 48, cornerRadius: R.Rad.md)
            VStack(alignment: .leading, spacing: 2) {
                Text("KARIMA-N")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("Cavalli Club · SAT 20 APR")
                    .font(R.F.mono(9.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg3)
            }
            Spacer()
            StatusTag(.completed)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Star card

    private var starCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("Your rating")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                if rating > 0 {
                    Text("\(rating) of 5")
                        .monoLabel(size: 10, tracking: 0.6, color: R.C.amber)
                }
            }
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        setRating(i)
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(i <= rating ? R.C.amber : R.C.fg3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                    .accessibilityAddTraits(i == rating ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Rating")

            // Live-status line — mirrors the role="status" aria-live region
            // shipped on the web review card.
            Text(rating == 0 ? "Pick a rating to submit." : "\(rating) star\(rating == 1 ? "" : "s") selected. Ready to submit.")
                .font(R.F.body(11.5, weight: .regular))
                .foregroundStyle(rating == 0 ? R.C.fg3 : R.C.fg2)
                .accessibilityAddTraits(.isStaticText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Tags card

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Highlights")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            Text("Tap any that apply. Optional.")
                .font(R.F.body(11.5, weight: .regular))
                .foregroundStyle(R.C.fg3)
            FlowLayout(spacing: R.S.xs) {
                ForEach(tagOptions, id: \.self) { tag in
                    TagChip(label: tag, isActive: tags.contains(tag)) {
                        toggleTag(tag)
                    }
                }
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Note card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack {
                Text("Note")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(note.count) / 500")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }
            TextEditor(text: $note)
                .font(R.F.body(14))
                .foregroundStyle(R.C.fg1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, maxHeight: 160)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                }
            Text("Public on their profile. Admins moderate anything that crosses a line.")
                .font(R.F.body(11.5, weight: .regular))
                .foregroundStyle(R.C.fg3)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Submit bar

    private var submitBar: some View {
        PrimaryButton("Submit review", variant: .filled, isEnabled: rating > 0) {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            nav.pop()
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.md)
        .background {
            LinearGradient(
                colors: [R.C.bg0.opacity(0), R.C.bg0.opacity(0.95), R.C.bg0],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    // MARK: — Actions

    private func setRating(_ value: Int) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(R.M.easeOutFast) { rating = value }
    }

    private func toggleTag(_ tag: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(R.M.easeOutFast) {
            if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
        }
    }
}

// MARK: - Tag chip

private struct TagChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(R.F.mono(10, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? R.C.amber : R.C.fg2)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                        .fill(isActive ? R.C.amber.opacity(0.12) : R.C.glassLo)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                        .strokeBorder(
                            isActive ? R.C.amber.opacity(0.4) : R.C.borderSoft,
                            lineWidth: R.S.hairline
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - FlowLayout
//
// Minimal flow layout so tag chips wrap naturally without LazyVGrid's
// equal-column-width behaviour (which would force every chip to the
// widest chip's size). SwiftUI iOS 16+ gave us Layout — we use it.

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        return CGSize(width: max(maxX, 0), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + width {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

#if DEBUG
#Preview("ReviewView") {
    let nav = NavigationModel()
    return ReviewView(nav: nav, bookingID: "karima-n")
        .preferredColorScheme(.dark)
}
#endif
