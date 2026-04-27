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
}
