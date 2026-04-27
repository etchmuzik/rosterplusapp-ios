// BookingView.swift — Screen 05
//
// Three-step booking wizard. Port of `BookingScreen` at ios-app.jsx
// line 507. Steps:
//
//   1. Event — date, time, venue
//   2. Fee   — amount input + currency pill  (shows conflict banner if any)
//   3. Review— confirm + send
//
// Wave 5.2: submit is live — builds a public.bookings row with the
// promoter's auth.uid() as promoter_id and the artist's UUID as
// artist_id, then triggers BookingsStore.refresh() so the new row
// shows up in the artist's pending-requests list on their dashboard.
// Conflict detection is still deferred (check_availability RPC).

import SwiftUI
import DesignSystem
import Supabase
#if canImport(UIKit)
import UIKit
#endif

public struct BookingView: View {
    @Bindable var nav: NavigationModel
    @Environment(ArtistDetailStore.self) private var artistDetail
    @Environment(AuthStore.self) private var auth
    @Environment(BookingsStore.self) private var bookings
    @Environment(AvailabilityCheckStore.self) private var availabilityCheck
    let artistID: String

    @State private var step: Int = 1
    @State private var isSubmitting: Bool = false
    @State private var submitError: String? = nil

    // Step 1
    @State private var eventDate: Date = Date().addingTimeInterval(86_400 * 7)
    @State private var eventTime: Date = Calendar.current.date(from: DateComponents(hour: 23)) ?? Date()
    @State private var venue: String = ""

    // Step 2
    @State private var fee: String = ""
    @State private var currency: String = "AED"

    public init(nav: NavigationModel, artistID: String) {
        self.nav = nav
        self.artistID = artistID
    }

    private var resolvedArtistID: UUID? { UUID(uuidString: artistID) }

    /// True when the check_availability RPC says the artist can't take
    /// this date. Fail-open — absence of a result means "no conflict".
    private var hasConflict: Bool {
        guard let id = resolvedArtistID,
              let result = availabilityCheck.result(for: id, date: eventDate)
        else { return false }
        return !result.available
    }

    /// Copy surfaced on the banner — falls back to generic text when
    /// the RPC didn't supply a reason.
    private var conflictReason: String {
        guard let id = resolvedArtistID,
              let result = availabilityCheck.result(for: id, date: eventDate),
              !result.available
        else { return "Artist unavailable on this date" }
        return result.reason ?? "Artist unavailable on this date"
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Request booking", onBack: { nav.pop() })
            progressBar
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.xs)
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    stepContent
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)
                    Color.clear.frame(height: 120)
                }
            }
            footerActions
        }
        .background(R.C.bg0)
        .task {
            // Warm the artist-detail cache so the review step + any
            // future read can show the real stage name instead of a
            // placeholder.
            if let id = resolvedArtistID {
                artistDetail.fetch(id: id)
                if let ccy = artistDetail.cache[id]?.currency {
                    currency = ccy
                }
                availabilityCheck.check(artistID: id, on: eventDate)
            }
        }
        .onChange(of: eventDate) { _, newDate in
            guard let id = resolvedArtistID else { return }
            availabilityCheck.check(artistID: id, on: newDate)
        }
    }

    // MARK: — Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(i < step ? R.C.fg1 : R.C.glassLo)
                    .frame(height: 3)
            }
        }
    }

    // MARK: — Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: step1
        case 2: step2
        default: step3
        }
    }

    // Step 1 — Event

    private var step1: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            SectionLabel("Step 1 of 3 · Event")
            FieldLabel("Date")
            DatePicker("", selection: $eventDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(R.C.amber)
            FieldLabel("Start time")
            DatePicker("", selection: $eventTime, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(R.C.amber)
            FieldLabel("Venue")
            TextField("e.g. WHITE Dubai", text: $venue, prompt:
                Text("e.g. WHITE Dubai").foregroundStyle(R.C.fg3)
            )
            .textFieldStyle(GlassFieldStyle())
        }
    }

    // Step 2 — Fee

    private var step2: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            SectionLabel("Step 2 of 3 · Fee")
            if hasConflict {
                ConflictBanner(reason: conflictReason)
            }
            FieldLabel("Amount")
            HStack(spacing: R.S.sm) {
                Menu {
                    ForEach(["AED", "SAR", "USD", "EUR"], id: \.self) { c in
                        Button(c) { currency = c }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currency)
                            .font(R.F.mono(12, weight: .semibold))
                            .tracking(0.6)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(R.C.fg1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
                }
                TextField("28,000", text: $fee, prompt:
                    Text("28,000").foregroundStyle(R.C.fg3)
                )
                .keyboardType(.numberPad)
                .textFieldStyle(GlassFieldStyle())
            }

            Text("Quote before platform fees. Artist gets push + email the moment you send.")
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .padding(.top, R.S.xs)
        }
    }

    // Step 3 — Review

    private var step3: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            SectionLabel("Step 3 of 3 · Review")
            ReviewRow(label: "Artist",  value: displayArtist)
            ReviewRow(label: "Date",    value: eventDate.formatted(date: .abbreviated, time: .omitted))
            ReviewRow(label: "Time",    value: eventTime.formatted(date: .omitted, time: .shortened))
            ReviewRow(label: "Venue",   value: venue.isEmpty ? "—" : venue)
            ReviewRow(label: "Fee",     value: fee.isEmpty ? "—" : "\(currency) \(fee)", isMono: true)
        }
    }

    private var displayArtist: String {
        if let id = resolvedArtistID, let cached = artistDetail.cache[id] {
            return cached.stageName
        }
        return "Artist"
    }

    // MARK: — Footer actions

    private var footerActions: some View {
        HStack(spacing: R.S.sm) {
            if step > 1 {
                PrimaryButton("Back", variant: .ghost) {
                    withAnimation(R.M.easeOut) { step -= 1 }
                }
            }
            PrimaryButton(
                step == 3 ? "Send request" : "Continue",
                variant: .filled,
                isLoading: isSubmitting,
                isEnabled: !isSubmitting
            ) {
                if step == 3 {
                    Task { await submit() }
                } else {
                    withAnimation(R.M.easeOut) { step += 1 }
                }
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.md)
        .overlay(alignment: .top) {
            if let msg = submitError {
                Text(msg)
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.red)
                    .padding(.horizontal, R.S.lg)
                    .padding(.vertical, R.S.xs)
                    .background { Capsule().fill(R.C.red.opacity(0.12)) }
                    .offset(y: -32)
            }
        }
        .background {
            LinearGradient(
                colors: [R.C.bg0.opacity(0.0), R.C.bg0.opacity(0.95), R.C.bg0],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    /// Build the INSERT payload and POST to public.bookings. RLS on the
    /// table gates writes to the caller's own promoter_id, so the
    /// server-side policy is the final backstop even if a client skips
    /// the auth guard here.
    private func submit() async {
        guard case .signedIn(let userID, _, _) = auth.state else {
            submitError = "Sign in to send a request."
            return
        }
        guard let targetArtist = resolvedArtistID else {
            submitError = "This artist can't receive requests yet."
            return
        }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        struct InsertRow: Encodable {
            let promoter_id: UUID
            let artist_id: UUID
            let event_name: String
            let event_date: String       // ISO date-only
            let event_time: String?      // "HH:mm:ss"
            let venue_name: String?
            let fee: Double?
            let currency: String
            let status: String
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let payload = InsertRow(
            promoter_id: userID,
            artist_id: targetArtist,
            event_name: venue.isEmpty ? "Booking request" : venue,
            event_date: dateFormatter.string(from: eventDate),
            event_time: timeFormatter.string(from: eventTime),
            venue_name: venue.isEmpty ? nil : venue,
            // Parse via Decimal so user input like "28,500.50" survives
            // through to the JSON encoder without binary-floating-point
            // rounding. Wire format is JSON number, hence the final
            // Decimal → Double conversion (lossless within our value
            // ceiling of low-millions in any GCC currency).
            fee: Decimal(string: fee.replacingOccurrences(of: ",", with: ""))
                .map { NSDecimalNumber(decimal: $0).doubleValue },
            currency: currency,
            status: "inquiry"
        )

        do {
            _ = try await RostrSupabase.shared
                .from("bookings")
                .insert(payload)
                .execute()

            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            // Refresh so the new row lands in our own BookingsStore
            // immediately — the artist on the other side will see it
            // on their next dashboard refresh.
            bookings.refresh(for: userID, role: .promoter)
            nav.pop()
        } catch {
            submitError = "Couldn't send — \(error.localizedDescription)"
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }
}

// MARK: - Section + field labels

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
    }
}

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(R.F.mono(9, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(R.C.fg2)
            .padding(.top, R.S.xs)
    }
}

// MARK: - Review row

private struct ReviewRow: View {
    let label: String
    let value: String
    var isMono: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Spacer()
            Text(value)
                .font(isMono
                      ? R.F.mono(13, weight: .semibold)
                      : R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Conflict banner

private struct ConflictBanner: View {
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: R.S.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(R.C.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Potential conflict")
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("\(reason). You can still send — they'll decline if it clashes.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg2)
            }
        }
        .padding(R.S.md)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(Color(hex: 0xe9cf92, opacity: 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(Color(hex: 0xe9cf92, opacity: 0.24), lineWidth: R.S.hairline)
        }
    }
}

// MARK: - Glass text-field style

private struct GlassFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(R.C.fg1)
            .font(R.F.body(14))
            .padding(.horizontal, R.S.md)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
    }
}

#if DEBUG
#Preview("BookingView — Step 1") {
    let nav = NavigationModel()
    let auth = AuthStore()
    let bookings = BookingsStore()
    let artistDetail = ArtistDetailStore()
    let id = UUID()
    artistDetail._testLoad(
        ArtistDetail(
            id: id, stageName: "DJ NOVAK",
            genres: ["Tech House"], citiesActive: ["Dubai"],
            baseFee: 28_000, currency: "AED", rating: 4.9,
            totalBookings: 32, verified: true, epkURL: nil,
            pressQuotes: [], pastPerformances: [], social: nil
        )
    )
    let availabilityCheck = AvailabilityCheckStore()
    return BookingView(nav: nav, artistID: id.uuidString)
        .environment(auth)
        .environment(bookings)
        .environment(artistDetail)
        .environment(availabilityCheck)
        .preferredColorScheme(.dark)
}
#endif
