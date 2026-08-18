// SupabaseDateDecodingTests.swift
//
// Regression guard for the App Store 2.1(a) "Couldn't load bookings —
// the data couldn't be read because it isn't in the correct format"
// rejection (review 2026-06-11).
//
// Root cause: `bookings.event_date` is a Postgres `date` column, which
// PostgREST serializes as a bare "yyyy-MM-dd" string. The supabase-swift
// default decoder only parses full ISO-8601 timestamps, so decoding
// BookingDTO.eventDate threw DecodingError.dataCorrupted, whose
// localizedDescription is exactly the reviewer-visible message. The bug
// also hit Payments and Invoices (both inline the same `bookings(event_date)`
// join). The fix injects RostrSupabase.jsonDecoder — which falls back to
// date-only parsing while keeping ISO-8601 timestamp parsing identical to
// the SDK default — onto the shared client.
//
// These tests decode the *real* demo-row JSON shape through that shared
// decoder. They fail on the SDK default and pass with the fallback.

import Foundation
import Testing
@testable import RostrPlusFeature

@Suite("Supabase date decoding")
struct SupabaseDateDecodingTests {

    /// The shape BookingsStore actually fetches for the App Review demo
    /// promoter: a `date`-typed event_date, a `time`-typed event_time, a
    /// microsecond timestamptz created_at, and the inlined artist join.
    private static let bookingJSON = """
    [{
      "id": "c863b7c9-5471-4922-b73f-eb91d72d10c4",
      "promoter_id": "e182c045-418f-435f-8e69-e77b785efc43",
      "artist_id": "9060cb8a-969a-410b-9ef4-cef0ebdf88c3",
      "venue_id": null,
      "event_name": "Friday Mainstage",
      "event_date": "2026-06-28",
      "event_time": "23:00:00",
      "set_duration": 120,
      "status": "confirmed",
      "fee": 28000.00,
      "currency": "AED",
      "venue_name": "WHITE Dubai",
      "notes": null,
      "created_at": "2026-06-01T17:13:27.421135+00:00",
      "artists": { "stage_name": "BETOKO" }
    }]
    """

    /// PaymentDTO inlines bookings(event_date,...) — the same `date`
    /// column, one level deeper. The demo account has one payment, so the
    /// Payments and Invoices screens threw the identical error.
    private static let paymentJSON = """
    [{
      "id": "11111111-1111-1111-1111-111111111111",
      "booking_id": "c863b7c9-5471-4922-b73f-eb91d72d10c4",
      "amount": 28000.00,
      "currency": "AED",
      "type": "final",
      "status": "completed",
      "paid_at": "2026-06-02T09:00:00.123456+00:00",
      "created_at": "2026-06-01T18:00:00+00:00",
      "invoice_number": "INV-2026-0042",
      "bookings": {
        "event_name": "Friday Mainstage",
        "event_date": "2026-06-28",
        "venue_name": "WHITE Dubai"
      }
    }]
    """

    @Test("BookingDTO decodes a date-only event_date through the shared decoder")
    func decodesBookingDateOnly() throws {
        let data = Data(Self.bookingJSON.utf8)
        let rows = try RostrSupabase.jsonDecoder.decode([BookingDTO].self, from: data)
        let row = try #require(rows.first)
        // The field that broke App Review: a bare yyyy-MM-dd must decode.
        let eventDate = try #require(row.eventDate)
        // And it must still parse the microsecond timestamptz created_at.
        let createdAt = try #require(row.createdAt)
        #expect(eventDate > createdAt) // event (Jun 28) is after creation (Jun 1)
        #expect(row.artist?.stageName == "BETOKO")

        // Sanity: the decoded date is the calendar day we sent, in the
        // DEVICE calendar — every view formats/compares eventDate with
        // Calendar.current / a default-tz DateFormatter, so a date-only
        // column must land on local midnight, not UTC midnight (which
        // reads as the previous day for anyone west of UTC — App Review).
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: eventDate)
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
        #expect(comps.day == 28)
        #expect(cal.startOfDay(for: eventDate) == eventDate)
    }

    @Test("Date-only column decodes to LOCAL midnight so Calendar.current sees the right day")
    func dateOnlyDecodesToLocalMidnight() throws {
        // Build today's yyyy-MM-dd the same way BookingView writes it
        // (default-tz DateFormatter), decode it, and check that the
        // Home-screen "Tonight" logic (Calendar.current.isDateInToday)
        // agrees. This is what App Review sees on a US-timezone device.
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let todayString = f.string(from: Date())
        struct Probe: Decodable { let d: Date }
        let json = #"{ "d": "\#(todayString)" }"#
        let probe = try RostrSupabase.jsonDecoder.decode(Probe.self, from: Data(json.utf8))
        #expect(Calendar.current.isDateInToday(probe.d))
        #expect(Calendar.current.startOfDay(for: probe.d) == probe.d)
        // Round-trip: re-formatting with the same writer yields the same day.
        #expect(f.string(from: probe.d) == todayString)
    }

    @Test("PaymentDTO decodes the nested bookings(event_date) join")
    func decodesPaymentNestedDate() throws {
        let data = Data(Self.paymentJSON.utf8)
        let rows = try RostrSupabase.jsonDecoder.decode([PaymentDTO].self, from: data)
        let row = try #require(rows.first)
        #expect(try #require(row.booking?.eventDate) != Date.distantPast)
        #expect(try #require(row.paidAt) != Date.distantPast)
    }

    @Test("Full ISO-8601 timestamps still decode (no regression for timestamptz columns)")
    func decodesIsoTimestamps() throws {
        // The decoder must keep parsing the two timestamp shapes PostgREST
        // emits for timestamptz columns: with and without fractional seconds.
        struct Probe: Decodable { let a: Date; let b: Date }
        let json = """
        { "a": "2026-06-01T17:13:27.421135+00:00", "b": "2026-06-01T18:00:00+00:00" }
        """
        let probe = try RostrSupabase.jsonDecoder.decode(Probe.self, from: Data(json.utf8))
        #expect(probe.a < probe.b) // 17:13:27 is before 18:00:00
    }

    @Test("A genuinely malformed date still throws (we didn't swallow real errors)")
    func malformedStillThrows() {
        struct Probe: Decodable { let d: Date }
        let json = #"{ "d": "not-a-date" }"#
        #expect(throws: DecodingError.self) {
            try RostrSupabase.jsonDecoder.decode(Probe.self, from: Data(json.utf8))
        }
    }
}
