// SupabaseClient.swift
//
// Shared Supabase client. Same project ref + anon key as the web app —
// server-side RLS gates everything, so the anon key is safe to bundle.
//
// Keep this tiny. Anything domain-specific (DTOs, RPC wrappers) lives
// in its own file under DTO/ or RPC/.

import Foundation
import Supabase

public enum RostrSupabase {

    /// Project ref for "roster new" — see the web app's `assets/js/app.js`
    /// for the matching URL + key. Anon key is public by design.
    private static let url: URL = {
        guard let u = URL(string: "https://vgjmfpryobsuboukbemr.supabase.co") else {
            preconditionFailure("Hardcoded Supabase URL literal is malformed — fix the constant above.")
        }
        return u
    }()

    /// Anon key. Safe to ship — Row Level Security enforces row-level
    /// access server-side; clients can't bypass RLS by inspecting this.
    /// If this ever leaks an admin-shaped grant, rotate it in the
    /// dashboard and ship a new build.
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnam1mcHJ5b2JzdWJvdWtiZW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTkzNTksImV4cCI6MjA5MDk3NTM1OX0.8bd3ki35UxHcLVJm3mUhzE3udZ7yec2im-oH0SzQoyw"

    public static let shared: SupabaseClient = {
        // Opt into supabase-swift's upcoming default: emit the locally
        // cached session as the initial session instead of waiting for
        // a refresh. Matches what we assume everywhere else in the app
        // (AuthStore checks .isSignedIn on startup), and silences the
        // deprecation notice logged on every launch.
        //
        // See https://github.com/supabase/supabase-swift/pull/822 for
        // the behaviour change — moves from legacy default false to
        // true in the next major.
        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(decoder: jsonDecoder),
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: options
        )
    }()

    /// JSON decoder used for every PostgREST `.execute().value` decode.
    ///
    /// The supabase-swift default decoder parses only ISO-8601
    /// *timestamps* (with and without fractional seconds). It throws
    /// `DecodingError.dataCorrupted("Invalid date format: …")` on a bare
    /// `yyyy-MM-dd` string — which is exactly what PostgREST returns for
    /// a Postgres `date` column. `bookings.event_date` is such a column
    /// and is decoded into `Date?` by `BookingDTO`, `PaymentDTO`
    /// (nested `bookings(event_date)` join), and the invoice flow.
    ///
    /// That mismatch was the App Store 2.1(a) "Couldn't load bookings —
    /// the data couldn't be read because it isn't in the correct format"
    /// rejection (2026-06-11): an empty result decoded fine, so the bug
    /// stayed latent until the demo account had a seeded booking.
    ///
    /// This decoder first runs the SDK's own ISO-8601 strategy verbatim
    /// (so every `timestamptz` column keeps decoding byte-for-byte the
    /// same), then falls back to a `yyyy-MM-dd` parse anchored to
    /// **local midnight**. A string that matches neither still throws, so
    /// genuinely corrupt data is not silently swallowed. Regression-tested
    /// in `Tests/RostrPlusFeatureTests/SupabaseDateDecodingTests.swift`.
    ///
    /// Why local midnight and not UTC: a Postgres `date` has no instant —
    /// it *is* a calendar day. Every consumer in the app (Home "Tonight",
    /// Bookings upcoming/past, CalendarView `isDate(inSameDayAs:)`,
    /// every `DateFormatter`) reasons in `Calendar.current`. Anchoring to
    /// UTC midnight made "2026-06-28" render as **Jun 27** for anyone west
    /// of UTC (App Review is US-based) and broke same-day detection.
    /// Local midnight is also exactly what `BookingView` writes back
    /// (default-tz `yyyy-MM-dd` formatter), so the round-trip is stable.
    public static let jsonDecoder: JSONDecoder = {
        // Device calendar day. `autoupdatingCurrent` so a tz change while
        // the app is alive still resolves against the user's current day.
        let dateOnly: DateFormatter = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.autoupdatingCurrent
            f.dateFormat = "yyyy-MM-dd"
            f.isLenient = false
            return f
        }()

        // The exact ISO-8601 timestamp styles the supabase-swift default
        // decoder uses (its own `currentTimestamp` helper is fileprivate,
        // so we replicate them). Parsing a timestamptz column with these
        // reproduces the SDK byte-for-byte. Built once, outside the
        // @Sendable closure — FormatStyle is Sendable, a local func is not.
        let fractionalTimestamp = Date.ISO8601FormatStyle()
            .year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: true)
        let plainTimestamp = Date.ISO8601FormatStyle()
            .year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: false)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // 1) Full ISO-8601 timestamp (timestamptz columns). Try with
            //    fractional seconds first, then without — same order and
            //    styles as the SDK default, so timestamp decoding is
            //    unchanged.
            if let date = try? Date(string, strategy: fractionalTimestamp) {
                return date
            }
            if let date = try? Date(string, strategy: plainTimestamp) {
                return date
            }

            // 2) Date-only column (e.g. bookings.event_date) → LOCAL midnight.
            if let date = dateOnly.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }()
}
