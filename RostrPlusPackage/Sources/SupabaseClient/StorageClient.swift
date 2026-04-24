// StorageClient.swift
//
// Thin wrapper around the `artist-media` Supabase Storage bucket.
// The bucket is public-read, owner-write — policy layout:
//   artist-media/<auth.uid()>/<kind>/<filename>
// where kind is one of avatar, gallery, rider. The first path
// component must equal auth.uid() so the Owners-can-update/delete
// policy recognises the object.
//
// Upload helpers return the object's public URL (since the bucket is
// public), so callers can immediately patch it onto artists/profiles.

import Foundation
import Supabase
import Storage

public enum StorageKind: String, Sendable {
    case avatar
    case gallery
    case rider
}

public struct StoragePath: Sendable, Hashable {
    public let objectPath: String
    public let publicURL: URL
}

public enum RostrStorageError: Error, Sendable {
    case notSignedIn
    case uploadFailed(String)
    case urlUnavailable
}

public enum RostrStorage {

    /// Bucket id used across the app. Defined here so only one spot
    /// in the codebase names it — forks or stage envs only have to
    /// change this constant.
    public static let bucket = "artist-media"

    /// Upload raw bytes to the `artist-media` bucket under the signed-
    /// in user's namespace. Returns the object path + public URL.
    ///
    /// `kind` controls the subfolder. `ext` should be the file's
    /// extension without a dot (jpg / png / pdf). A random suffix is
    /// appended so repeat uploads don't collide on filename.
    @MainActor
    public static func upload(
        data: Data,
        kind: StorageKind,
        extensionHint ext: String,
        userID: UUID,
        contentType: String
    ) async throws -> StoragePath {
        let client = RostrSupabase.shared
        let suffix = String(UUID().uuidString.prefix(8))
        let filename = "\(Int(Date().timeIntervalSince1970))-\(suffix).\(ext)"
        let path = "\(userID.uuidString)/\(kind.rawValue)/\(filename)"

        do {
            _ = try await client.storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: false
                    )
                )
        } catch {
            throw RostrStorageError.uploadFailed(error.localizedDescription)
        }

        let url: URL
        do {
            url = try client.storage
                .from(bucket)
                .getPublicURL(path: path)
        } catch {
            throw RostrStorageError.urlUnavailable
        }
        return StoragePath(objectPath: path, publicURL: url)
    }
}
