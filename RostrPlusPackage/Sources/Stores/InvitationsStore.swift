// InvitationsStore.swift
//
// Promoter-facing helper that lets an iOS user invite an artist by
// email. Mirrors web's `DB.sendInvitation({ email, name, role,
// message })` semantics in assets/js/app.js — INSERT into
// public.invitations, then call the `send-email` edge function with
// the tokenised invite URL.
//
// Keeping the URL in lockstep with the web origin
// (https://rosterplus.io/auth.html?invite=<token>&role=<role>) is
// important: artists who tap the email link land on the web auth
// page, which finishes the claim handshake. iOS doesn't need to
// host an in-app deep link for v1.

import Foundation
import Observation
import OSLog
import Supabase

private let log = Logger(subsystem: "io.rosterplus.app", category: "InvitationsStore")

public struct InvitationRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let email: String
    public let name: String
    public let role: String
    public let status: String
    public let createdAt: Date
}

@Observable
@MainActor
public final class InvitationsStore {

    public enum SendResult: Equatable, Sendable {
        case idle
        case sending
        case sent(email: String)
        case failed(String)
    }

    public private(set) var sendResult: SendResult = .idle
    public private(set) var recent: [InvitationRow] = []

    private let client = RostrSupabase.shared
    private let webOrigin = "https://rosterplus.io"

    public init() {}

    /// Drop cached invitations and any pending result. Called on
    /// sign-out so the next signed-in promoter starts fresh.
    public func reset() {
        sendResult = .idle
        recent = []
    }

    // MARK: — Send

    /// Invite an artist (or another promoter) by email. Mirrors web's
    /// DB.sendInvitation: insert into public.invitations, fire the
    /// templated email through send-email edge function, surface
    /// success/failure to the caller via sendResult.
    public func send(
        email: String,
        name: String,
        role: String,
        message: String,
        invitedBy userID: UUID,
        inviterName: String
    ) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.contains("@") else {
            sendResult = .failed("Enter a valid email address.")
            return
        }
        guard ["artist", "promoter"].contains(role) else {
            sendResult = .failed("Role must be artist or promoter.")
            return
        }

        sendResult = .sending

        struct Insert: Encodable {
            let invited_by: UUID
            let email: String
            let name: String
            let role: String
            let message: String
        }

        do {
            // Insert + select to read back the server-generated token.
            let row: InvitationDTO = try await client
                .from("invitations")
                .insert(Insert(
                    invited_by: userID,
                    email: trimmedEmail,
                    name: trimmedName,
                    role: role,
                    message: message
                ))
                .select(InvitationDTO.selectFields)
                .single()
                .execute()
                .value

            // Fire the templated email via send-email edge function.
            // Web's `Emails.send(to, type, data)` is just a wrapper
            // around POST /functions/v1/send-email — same shape.
            let token = row.token ?? ""
            let inviteURL = "\(webOrigin)/auth.html?invite=\(token)&role=\(role)"

            struct EmailPayload: Encodable {
                let to: String
                let type: String
                let data: EmailData

                struct EmailData: Encodable {
                    let inviter_name: String
                    let role: String
                    let message: String
                    let invite_url: String
                }
            }
            let payload = EmailPayload(
                to: trimmedEmail,
                type: "invitation",
                data: .init(
                    inviter_name: inviterName,
                    role: role,
                    message: message,
                    invite_url: inviteURL
                )
            )

            do {
                try await client.functions.invoke(
                    "send-email",
                    options: FunctionInvokeOptions(body: payload)
                )
            } catch {
                // Email dispatch failure is non-fatal — the invitation
                // row is in the database, so an admin can resend later.
                #if DEBUG
                log.error("send email step failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }

            sendResult = .sent(email: trimmedEmail)
            // Prepend to the recent list for UX.
            let display = InvitationRow(
                id: row.id,
                email: row.email,
                name: row.name ?? "",
                role: row.role ?? "artist",
                status: row.status ?? "pending",
                createdAt: row.createdAt ?? Date()
            )
            recent.insert(display, at: 0)
        } catch {
            sendResult = .failed(error.localizedDescription)
        }
    }

    // MARK: — Read

    public func loadRecent(invitedBy userID: UUID) async {
        do {
            let rows: [InvitationDTO] = try await client
                .from("invitations")
                .select(InvitationDTO.selectFields)
                .eq("invited_by", value: userID)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value
            recent = rows.compactMap { dto in
                InvitationRow(
                    id: dto.id,
                    email: dto.email,
                    name: dto.name ?? "",
                    role: dto.role ?? "artist",
                    status: dto.status ?? "pending",
                    createdAt: dto.createdAt ?? Date()
                )
            }
        } catch {
            // Silent failure — UX falls back to "no recent invites".
        }
    }

    #if DEBUG
    public func _testSet(result: SendResult, recent: [InvitationRow] = []) {
        self.sendResult = result
        self.recent = recent
    }
    #endif
}
