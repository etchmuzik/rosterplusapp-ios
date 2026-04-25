// ContractView.swift — Screen 09
//
// E-signable contract view. Wave Tier-A: Sign + Send actions go live.
//
// Both promoter and artist see the same screen. The action footer
// adapts to who's signed in:
//
//   Promoter, status=draft → "Send to artist" button (flips to 'sent')
//   Promoter, not yet signed → "Sign as promoter" button
//   Artist, not yet signed   → "Sign as artist" button
//   Both signed              → "Signed" pill (no actions)
//
// Mirrors web's `DB.signContract(contractId, role)` semantics — the
// counterparty sees the signature reflected immediately on refresh.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ContractView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth
    @Environment(ContractsStore.self) private var store
    @Environment(BookingsStore.self) private var bookings

    /// Route passes the booking id (matches the rest of the nav
    /// routing pattern). The store resolves the contract row via
    /// `booking_id`.
    let contractID: String

    @State private var isWorking = false
    @State private var errorMessage: String?

    public init(nav: NavigationModel, contractID: String) {
        self.nav = nav
        self.contractID = contractID
    }

    private var resolvedBookingID: UUID? { UUID(uuidString: contractID) }

    private var contractRow: ContractRow? {
        if case .loaded(let row) = store.state { return row }
        return nil
    }

    private var booking: BookingRow? {
        guard let id = resolvedBookingID else { return nil }
        return bookings.detailCache[id]
    }

    private var role: ContractsStore.Signer {
        if case .signedIn(_, _, let r) = auth.state, r == "artist" {
            return .artist
        }
        return .promoter
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Contract", onBack: { nav.pop() })
            ScrollView {
                if let row = contractRow {
                    VStack(alignment: .leading, spacing: R.S.lg) {
                        if let errorMessage {
                            errorBanner(errorMessage)
                        }
                        header(for: row)
                        contractBody(for: row)
                        signatureBlock(for: row)
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                } else {
                    loadingOrError
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.xl)
                }
            }
            actions(for: contractRow)
        }
        .background(R.C.bg0)
        .task {
            if let id = resolvedBookingID {
                store.fetch(forBookingID: id)
                bookings.fetchDetail(id: id)
            }
        }
    }

    // MARK: — States

    @ViewBuilder
    private var loadingOrError: some View {
        switch store.state {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: R.S.lg) {
                RoundedRectangle(cornerRadius: R.Rad.card3, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 120)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 70)
                }
            }
            .redacted(reason: .placeholder)

        case .failed(let message):
            VStack(alignment: .leading, spacing: R.S.sm) {
                Text("No contract yet")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(message)
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)

        case .loaded:
            EmptyView()
        }
    }

    // MARK: — Title card

    private func header(for row: ContractRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance agreement")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text(headerTitle)
                .font(R.F.display(24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(R.C.fg1)
            Text("Contract #\(row.id.uuidString.prefix(8).uppercased())")
                .font(R.F.mono(10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    private var headerTitle: String {
        guard let b = booking else { return "Performance contract" }
        return "\(b.artistName.uppercased()) at \(b.venueName)"
    }

    // MARK: — Body

    @ViewBuilder
    private func contractBody(for row: ContractRow) -> some View {
        if !row.content.isEmpty {
            // Server provided custom contract content — render it as
            // a single readable card.
            VStack(alignment: .leading, spacing: R.S.xs) {
                Text(row.title)
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(row.content)
                    .font(R.F.body(13, weight: .regular))
                    .foregroundStyle(R.C.fg2)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        } else {
            // Default boilerplate when the server contract is empty.
            VStack(alignment: .leading, spacing: R.S.md) {
                Clause(
                    title: "1. Engagement",
                    text: engagementClause(for: booking)
                )
                Clause(
                    title: "2. Fee",
                    text: feeClause(for: booking)
                )
                Clause(
                    title: "3. Rider",
                    text: "Technical and hospitality rider attached as Schedule A. The Promoter confirms that all requirements will be in place by call-time."
                )
                Clause(
                    title: "4. Cancellation",
                    text: "Cancellation by either party within 14 days of the event forfeits 50% of the fee. Within 72 hours, 100%. Force majeure excepted."
                )
                Clause(
                    title: "5. Governing law",
                    text: "This agreement is governed by the laws of the Dubai International Financial Centre."
                )
            }
        }
    }

    private func engagementClause(for booking: BookingRow?) -> String {
        guard let b = booking else {
            return "The Artist agrees to perform under the terms outlined in this booking."
        }
        let f = DateFormatter()
        f.dateStyle = .full
        return "The Artist (\(b.artistName)) agrees to perform on \(f.string(from: b.eventDate)) at \(b.venueName)."
    }

    private func feeClause(for booking: BookingRow?) -> String {
        guard let b = booking, let fee = b.fee, fee > 0 else {
            return "Fee terms as agreed via the ROSTR+ booking flow. Payable within 7 days of performance."
        }
        return "Total fee is \(b.feeFormatted), inclusive of agent commission. Payable within 7 days of performance via bank transfer."
    }

    // MARK: — Signature block

    @ViewBuilder
    private func signatureBlock(for row: ContractRow) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Signatures")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            VStack(spacing: R.S.xs) {
                signatureRow(
                    label: "Promoter",
                    signed: row.promoterSigned,
                    at: row.promoterSignedAt
                )
                signatureRow(
                    label: "Artist",
                    signed: row.artistSigned,
                    at: row.artistSignedAt
                )
            }
        }
    }

    private func signatureRow(label: String, signed: Bool, at: Date?) -> some View {
        HStack(spacing: R.S.sm) {
            Circle()
                .fill(signed ? R.C.green : R.C.amber)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(signed ? "\(label) — signed" : "\(label) — awaiting signature")
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(signedAtLabel(at))
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
            Spacer()
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }

    private func signedAtLabel(_ date: Date?) -> String {
        guard let date else { return "Not yet signed" }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy · HH:mm 'GST'"
        return f.string(from: date)
    }

    // MARK: — Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(R.C.red)
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg1)
            Spacer(minLength: 0)
        }
        .padding(R.S.md)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.red.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.red.opacity(0.3), lineWidth: R.S.hairline)
        }
    }

    // MARK: — Actions

    @ViewBuilder
    private func actions(for row: ContractRow?) -> some View {
        if let row {
            HStack(spacing: R.S.sm) {
                if shouldShowSendCTA(for: row) {
                    PrimaryButton(
                        "Send to artist",
                        variant: .filled,
                        isLoading: isWorking,
                        isEnabled: !isWorking
                    ) {
                        Task { await send(row) }
                    }
                    .layoutPriority(1)
                } else if shouldShowSignCTA(for: row) {
                    PrimaryButton(
                        signCTALabel(for: row),
                        variant: .filled,
                        isLoading: isWorking,
                        isEnabled: !isWorking
                    ) {
                        Task { await sign(row) }
                    }
                    .layoutPriority(1)
                } else {
                    fullySignedPill
                        .layoutPriority(1)
                }
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
        } else {
            EmptyView()
        }
    }

    private var fullySignedPill: some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(R.C.green)
            Text("Signed by both parties")
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.green.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.green.opacity(0.30), lineWidth: R.S.hairline)
        }
    }

    private func shouldShowSendCTA(for row: ContractRow) -> Bool {
        role == .promoter && row.status == .draft
    }

    private func shouldShowSignCTA(for row: ContractRow) -> Bool {
        switch role {
        case .promoter: return !row.promoterSigned && row.status != .cancelled
        case .artist:   return !row.artistSigned && row.status != .cancelled
        }
    }

    private func signCTALabel(for row: ContractRow) -> String {
        role == .promoter ? "Sign as promoter" : "Sign as artist"
    }

    // MARK: — Mutations

    private func sign(_ row: ContractRow) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        await store.sign(contractID: row.id, as: role)
        if let err = store.lastError {
            errorMessage = err
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func send(_ row: ContractRow) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        await store.send(contractID: row.id)
        if let err = store.lastError {
            errorMessage = err
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - Clause

private struct Clause: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text(text)
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

#if DEBUG
#Preview("ContractView") {
    let nav = NavigationModel()
    let auth = AuthStore()
    let store = ContractsStore()
    let bookings = BookingsStore()
    let bookingID = UUID()
    let row = ContractRow(
        id: UUID(),
        bookingID: bookingID,
        title: "Performance Contract",
        content: "",
        status: .sent,
        promoterSigned: false,
        artistSigned: false,
        promoterSignedAt: nil,
        artistSignedAt: nil,
        signedAt: nil,
        createdAt: Date()
    )
    store._testLoad(row)
    return ContractView(nav: nav, contractID: bookingID.uuidString)
        .environment(auth)
        .environment(store)
        .environment(bookings)
        .preferredColorScheme(.dark)
}
#endif
