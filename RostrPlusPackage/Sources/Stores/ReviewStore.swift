// ReviewStore.swift
//
// Wraps the public.create_review RPC. ReviewView calls
// `submit(bookingID:rating:comment:)` from its Submit CTA. The RPC
// enforces:
//   - caller participated in the booking (auth.uid() = promoter_id
//     or artist_id on the row)
//   - rating in [1, 5]
//   - one review per (booking, reviewer)
// and returns the inserted reviews row id on success.
//
// Mirrors web's app.js:2192 createReview() — same RPC, same error-code
// translation, so a review left on iOS and a review left on web are
// indistinguishable to the receiving artist's profile.

import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class ReviewStore {

    public enum SubmitState: Sendable {
        case idle
        case submitting
        case submitted(reviewID: String)
        case failed(String)
    }

    public private(set) var state: SubmitState = .idle

    private let client = RostrSupabase.shared

    public init() {}

    /// Submit a review. `comment` may be empty — gets normalised to nil
    /// so the database doesn't store empty strings.
    /// Tags from the UI are joined into the comment as a leading hashtag
    /// list (Web does the same — keeps the wire format identical so the
    /// artist profile can render reviews from either source uniformly).
    @discardableResult
    public func submit(
        bookingID: String,
        rating: Int,
        tags: [String] = [],
        note: String = ""
    ) async -> Bool {
        state = .submitting

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment: String? = {
            let tagBlock = tags.isEmpty ? "" : tags.map { "#\($0.replacingOccurrences(of: " ", with: ""))" }.joined(separator: " ")
            switch (tagBlock.isEmpty, trimmedNote.isEmpty) {
            case (true, true):   return nil
            case (false, true):  return tagBlock
            case (true, false):  return trimmedNote
            case (false, false): return tagBlock + "\n\n" + trimmedNote
            }
        }()

        struct Args: Encodable {
            let p_booking_id: String
            let p_rating: Int
            let p_comment: String?
        }

        do {
            let response = try await client
                .rpc("create_review", params: Args(
                    p_booking_id: bookingID,
                    p_rating: rating,
                    p_comment: comment
                ))
                .execute()

            // RPC returns the new row id as a JSON string scalar or a
            // single-row object depending on the RETURNS shape. Be
            // defensive: try both.
            let raw = response.data
            let decoded = decodeReviewID(raw) ?? "ok"
            state = .submitted(reviewID: decoded)
            return true
        } catch {
            state = .failed(humanize(error))
            return false
        }
    }

    private func decodeReviewID(_ data: Data) -> String? {
        // Try a bare JSON string first.
        if let s = try? JSONDecoder().decode(String.self, from: data) {
            return s
        }
        // Then a {"id": "..."} object.
        struct Body: Decodable { let id: String? }
        if let b = try? JSONDecoder().decode(Body.self, from: data) {
            return b.id
        }
        // Then an array of those.
        if let arr = try? JSONDecoder().decode([Body].self, from: data),
           let first = arr.first {
            return first.id
        }
        return nil
    }

    /// Translate Postgres exception messages from the RPC into copy
    /// the user can act on. The RPC raises with codes like
    /// 'review_not_authorised' / 'review_already_exists' / 'invalid_rating'.
    private func humanize(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("already") {
            return "You've already reviewed this booking."
        }
        if msg.contains("not_authorised") || msg.contains("authorised") || msg.contains("authorized") {
            return "You can only review bookings you took part in."
        }
        if msg.contains("invalid_rating") || msg.contains("rating") {
            return "Rating must be between 1 and 5."
        }
        return "Couldn't submit your review. Try again."
    }

    /// Reset to idle. Useful when the view re-appears after a successful
    /// submit and we want a fresh slate.
    public func reset() {
        state = .idle
    }
}
