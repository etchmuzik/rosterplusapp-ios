// ScreenshotSeed.swift
//
// DEBUG-only. Seeds every user-scoped store with curated, Gulf-authentic
// demo data so App Store screenshots render full, polished surfaces
// WITHOUT touching live Supabase or exposing real users' data.
//
// Activated by the `-RostrScreenshotMode 1` launch argument (see
// AppRoot.seedScreenshotsIfRequested). The whole file is gated on
// #if DEBUG, so it physically cannot ship in the Release App Store
// binary — the screenshot build runs Debug config.
//
// Data quality mirrors Stores/MockData.swift (which feeds previews) but
// is expressed in the real DISPLAY types each store holds (RosterArtist,
// BookingRow, PaymentRow, …) so the seeded screens are pixel-identical to
// production-rendered ones. MessageDTO has no public init by design, so
// those are produced via the same JSON decode path the live app uses.

#if DEBUG
import Foundation

@MainActor
public enum ScreenshotSeed {

    /// Launch-arg switch. AppRoot checks this before wiring real data.
    public static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-RostrScreenshotMode")
    }

    /// Stable fake identity for the signed-in demo user. No network —
    /// AuthStore is forced to `.signedIn` with this id/role.
    public static let demoUserID = UUID(uuidString: "5C0FFEE0-0000-4000-8000-00000000A11C")!
    public static let demoEmail = "studio@rosterplus.io"
    public static let demoRole = "promoter" // promoter sees the richer booking surface

    // Deterministic dates relative to a fixed anchor so captures look the
    // same every run (Date() would drift the "TUE 24" style labels).
    private static let anchor = Date(timeIntervalSince1970: 1_746_057_600) // 2025-05-01 00:00 UTC
    private static func day(_ offset: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: anchor) ?? anchor
    }

    // Stable cross-reference IDs so the UITest can deep-link to specific
    // screens by a known id (no need to predict random UUIDs).
    public static let bookingID  = UUID(uuidString: "B0000001-0000-4000-8000-000000000001")!
    public static let contractID = UUID(uuidString: "C0000001-0000-4000-8000-000000000001")!
    public static let threadBookingID = bookingID // thread is bound to the booking

    // Stable artist IDs so booking/contract/thread cross-reference cleanly.
    // ETCH is the hero (idEtch). The supporting cast are REAL ROSTR+ roster
    // artists whose bundled portraits resolve by stage-name slug
    // (web/assets/images/artists/<handle>.jpg → iOS Resources/artists/).
    public static let idEtchPublic = "A0000001-0000-4000-8000-000000000001"
    private static let idEtch    = UUID(uuidString: "A0000001-0000-4000-8000-000000000001")!
    private static let idAshkan  = UUID(uuidString: "A0000002-0000-4000-8000-000000000002")!
    private static let idImen    = UUID(uuidString: "A0000003-0000-4000-8000-000000000003")!
    private static let idLithK   = UUID(uuidString: "A0000004-0000-4000-8000-000000000004")!
    private static let idEpi     = UUID(uuidString: "A0000005-0000-4000-8000-000000000005")!
    private static let idSarabi  = UUID(uuidString: "A0000006-0000-4000-8000-000000000006")!

    // MARK: — Roster directory (real ROSTR+ artists, ETCH first)

    private static let roster: [RosterArtist] = [
        .init(id: idEtch,   stage: "ETCH",     genre: "House",       city: "Dubai",  rating: 5.0, verified: true),
        .init(id: idAshkan, stage: "ASHKAN K", genre: "House",       city: "Dubai",  rating: 4.9, verified: true),
        .init(id: idImen,   stage: "IMEN",     genre: "Electronic",  city: "Dubai",  rating: 4.9, verified: true),
        .init(id: idLithK,  stage: "LITH K",   genre: "House",       city: "Dubai",  rating: 4.8, verified: true),
        .init(id: idEpi,    stage: "EPI",      genre: "Open Format", city: "Dubai",  rating: 4.8, verified: true),
        .init(id: idSarabi, stage: "SARABI",   genre: "House",       city: "Dubai",  rating: 4.8, verified: true),
    ]

    // MARK: — Bookings

    private static let upcoming: [BookingRow] = [
        .init(id: bookingID, eventName: "Friday Mainstage", artistName: "ETCH",
              venueName: "WHITE Dubai", eventDate: day(23), status: "confirmed",
              feeFormatted: "AED 28K", currency: "AED", fee: 28_000),
        .init(id: UUID(), eventName: "Rooftop Sessions", artistName: "ASHKAN K",
              venueName: "Blu Dahlia", eventDate: day(26), status: "pending",
              feeFormatted: "SAR 42K", currency: "SAR", fee: 42_000),
        .init(id: UUID(), eventName: "Closing Set", artistName: "IMEN",
              venueName: "Cavalli Club", eventDate: day(27), status: "contracted",
              feeFormatted: "AED 32K", currency: "AED", fee: 32_000),
    ]

    private static let past: [BookingRow] = [
        .init(id: UUID(), eventName: "Saturday Headline", artistName: "IMEN",
              venueName: "Cavalli Club", eventDate: day(-8), status: "completed",
              feeFormatted: "AED 32K", currency: "AED", fee: 32_000),
        .init(id: UUID(), eventName: "Late Set", artistName: "LITH K",
              venueName: "Soho Garden", eventDate: day(-15), status: "completed",
              feeFormatted: "AED 24K", currency: "AED", fee: 24_000),
    ]

    // MARK: — Payments

    private static let payments: [PaymentRow] = [
        .init(id: UUID(), artistName: "ETCH", eventLabel: "WHITE Dubai · Fri 23",
              amount: 28_000, currency: "AED", amountFormatted: "AED 28,000",
              status: .paid, eventDate: day(23), paidAt: day(24)),
        .init(id: UUID(), artistName: "IMEN", eventLabel: "Cavalli Club · Sat 27",
              amount: 32_000, currency: "AED", amountFormatted: "AED 32,000",
              status: .scheduled, eventDate: day(27), paidAt: nil),
        .init(id: UUID(), artistName: "ASHKAN K", eventLabel: "Blu Dahlia · Sat 26",
              amount: 42_000, currency: "SAR", amountFormatted: "SAR 42,000",
              status: .pending, eventDate: day(26), paidAt: nil),
        .init(id: UUID(), artistName: "LITH K", eventLabel: "Soho Garden · Sat 12",
              amount: 24_000, currency: "AED", amountFormatted: "AED 24,000",
              status: .paid, eventDate: day(-15), paidAt: day(-14)),
    ]

    // MARK: — Notifications

    private static let notifications: [NotificationRow] = [
        .init(id: UUID(), kind: .booking, title: "ETCH accepted",
              body: "Your request for WHITE Dubai · Fri 23 was accepted.",
              createdAt: day(0).addingTimeInterval(-120), read: false, href: nil),
        .init(id: UUID(), kind: .message, title: "LITH K sent a message",
              body: "Sending the updated set list by EOD.",
              createdAt: day(0).addingTimeInterval(-840), read: false, href: nil),
        .init(id: UUID(), kind: .contract, title: "Contract countersigned",
              body: "IMEN signed the Cavalli Club agreement.",
              createdAt: day(0).addingTimeInterval(-3_600), read: true, href: nil),
        .init(id: UUID(), kind: .payment, title: "Payment scheduled",
              body: "AED 32K scheduled for Sat 27.",
              createdAt: day(0).addingTimeInterval(-10_800), read: true, href: nil),
        .init(id: UUID(), kind: .profile, title: "Your profile got 12 views",
              body: "Four from Riyadh, eight from Dubai.",
              createdAt: day(-2), read: true, href: nil),
    ]

    // MARK: — Artist detail / EPK (ETCH)

    private static func etchDetail() -> ArtistDetail {
        ArtistDetail(
            id: idEtch,
            stageName: "ETCH",
            genres: ["House", "Electronic"],
            citiesActive: ["Dubai", "Cairo"],
            baseFee: 28_000,
            currency: "AED",
            rating: 5.0,
            totalBookings: 47,
            verified: true,
            epkURL: "https://rosterplus.io/a/etch",
            pressQuotes: [
                .init(outlet: "MixMag ME", quote: "A controlled burn of a set — leaves the room breathing heavy."),
                .init(outlet: "Time Out Dubai", quote: "The house selector you didn't know you needed."),
            ],
            pastPerformances: [
                .init(venue: "WHITE Dubai", city: "Dubai", date: "12 Apr", crowd: "1,400 people"),
                .init(venue: "Sahel Beach", city: "Cairo", date: "28 Mar", crowd: "900 people"),
                .init(venue: "Cavalli Club", city: "Dubai", date: "21 Mar", crowd: "1,200 people"),
                .init(venue: "Soho Garden", city: "Dubai", date: "14 Mar", crowd: "2,000 people"),
            ],
            social: .init(
                instagram: "https://instagram.com/etch",
                soundcloud: "https://soundcloud.com/etch",
                spotify: "https://open.spotify.com/artist/etch"
            ),
            tourMode: true
        )
    }

    // MARK: — Contract (IMEN · Cavalli Club, signed)

    private static func cavalliContract(bookingID: UUID) -> ContractRow {
        ContractRow(
            id: contractID,
            bookingID: bookingID,
            title: "Performance Agreement — ETCH",
            content: """
            This Performance Agreement is made between Studio (Promoter) and \
            ETCH (Artist) for a DJ performance at WHITE Dubai, Dubai.

            1. Engagement. Artist will perform a 90-minute mainstage set on \
            Fri 23, doors 23:00, set 01:00–02:30.
            2. Fee. AED 28,000, payable 50% on signature, balance on the \
            night of performance.
            3. Rider. Hospitality, ground transport from DXB, and technical \
            rider as attached. Pioneer CDJ-3000 ×3 + DJM-V10.
            4. Cancellation. Either party may cancel with 14 days' notice; \
            within 14 days the deposit is non-refundable.
            5. Audit trail. Both parties e-sign in-app; signatures are \
            timestamped and immutable.
            """,
            status: .signed,
            promoterSigned: true,
            artistSigned: true,
            promoterSignedAt: day(-3),
            artistSignedAt: day(-2),
            signedAt: day(-2),
            createdAt: day(-4)
        )
    }

    // MARK: — Thread messages (decoded via the live path; no public init)

    private static func threadMessages(bookingID: UUID) -> [MessageDTO] {
        let me = demoUserID
        let artist = idEtch
        // Build via JSONDecoder so we hit the same decode path production
        // uses — MessageDTO intentionally has no public init.
        let rows: [[String: Any]] = [
            ["id": UUID().uuidString, "sender_id": artist.uuidString, "receiver_id": me.uuidString,
             "booking_id": bookingID.uuidString, "content": "Good morning — quick one on soundcheck.",
             "read": true, "created_at": "2025-05-01T11:02:00Z"],
            ["id": UUID().uuidString, "sender_id": me.uuidString, "receiver_id": artist.uuidString,
             "booking_id": bookingID.uuidString, "content": "Shoot.",
             "read": true, "created_at": "2025-05-01T11:04:00Z"],
            ["id": UUID().uuidString, "sender_id": artist.uuidString, "receiver_id": me.uuidString,
             "booking_id": bookingID.uuidString, "content": "Can we push to 21:00 instead of 20:00? Flight lands at 18:40.",
             "read": true, "created_at": "2025-05-01T11:05:00Z"],
            ["id": UUID().uuidString, "sender_id": me.uuidString, "receiver_id": artist.uuidString,
             "booking_id": bookingID.uuidString, "content": "Works for us. I'll loop the venue.",
             "read": true, "created_at": "2025-05-01T11:08:00Z"],
            ["id": UUID().uuidString, "sender_id": artist.uuidString, "receiver_id": me.uuidString,
             "booking_id": bookingID.uuidString, "content": "Thanks — sending updated rider after lunch.",
             "read": false, "created_at": "2025-05-01T11:09:00Z"],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return [] }
        let decoder = JSONDecoder()
        let fmt = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            return fmt.date(from: s) ?? Date()
        }
        return (try? decoder.decode([MessageDTO].self, from: data)) ?? []
    }

    private static func demoProfile() -> ProfileDTO {
        ProfileDTO(
            id: demoUserID,
            email: demoEmail,
            displayName: "Studio Collective",
            role: demoRole,
            avatarURL: nil,
            phone: nil,
            company: "Studio Collective",
            bio: "Booking the Gulf's loudest nights.",
            city: "Dubai",
            notificationPrefs: .defaultAllOn
        )
    }

    // MARK: — Apply

    /// Seed every store from the curated data above. Called once from
    /// AppRoot after the stores exist and AuthStore is forced signed-in.
    public static func apply(
        roster rosterStore: RosterStore,
        bookings bookingsStore: BookingsStore,
        payments paymentsStore: PaymentsStore,
        notifications notificationsStore: NotificationsStore,
        inbox inboxStore: InboxStore,
        contracts contractsStore: ContractsStore,
        artistDetail artistDetailStore: ArtistDetailStore,
        profile profileStore: ProfileStore
    ) {
        rosterStore._testLoad(roster)
        bookingsStore._testLoad(upcoming: upcoming, past: past)
        paymentsStore._testLoad(payments)
        notificationsStore._testLoad(notifications)
        profileStore._testLoad(demoProfile())
        artistDetailStore._testLoad(etchDetail())

        // Thread + contract are bound to the stable demo booking id.
        let names: [UUID: String] = [idEtch: "ETCH", demoUserID: "Studio Collective"]
        inboxStore._testLoad(userID: demoUserID, messages: threadMessages(bookingID: bookingID), names: names)
        contractsStore._testLoad(cavalliContract(bookingID: bookingID))
    }
}
#endif
