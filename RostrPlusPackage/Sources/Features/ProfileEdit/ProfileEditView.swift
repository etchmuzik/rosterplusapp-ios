// ProfileEditView.swift — Screen 22
//
// Edit the artist's public profile. Wave 5.6: avatar uploads go live.
//   - Stage name + primary genre + socials → public.artists via
//     ArtistDetailStore.updateProfileCore(...)
//   - Bio → public.profiles.bio via ProfileStore.update(...)
//   - Avatar photo → artist-media/<uid>/avatar/<timestamp>.jpg via
//     RostrStorage.upload(...), then the public URL is patched onto
//     public.profiles.avatar_url.
// Saves fire on the Save button with haptic feedback and an inline
// error banner on failure. Gallery + rider upload still scaffolded
// (UI only) until the media management sweep.

import SwiftUI
import PhotosUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ProfileEditView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ArtistDetailStore.self) private var artistStore

    // Local editable state — seeded from the stores in `.task`.
    @State private var stageName: String = ""
    @State private var genre: String = ""
    @State private var bio: String = ""
    @State private var instagram: String = ""
    @State private var soundcloud: String = ""
    @State private var spotify: String = ""
    @State private var gallery: [String] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Avatar upload.
    @State private var avatarURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Edit profile", onBack: { nav.pop() }) {
                Button(action: { Task { await save() } }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(R.C.bg0)
                            .frame(width: 38, height: 28)
                            .background { Capsule().fill(R.C.fg1) }
                    } else {
                        Text("Save")
                            .monoLabel(size: 10, tracking: 0.8, color: R.C.bg0)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background { Capsule().fill(R.C.fg1) }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityLabel("Save profile")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerCard
                    bioCard
                    galleryCard
                    riderCard
                    socialsCard
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
        .task {
            hydrateFromStores()
        }
    }

    // MARK: — Seeding + save

    private func hydrateFromStores() {
        if let profile = profileStore.current {
            bio = profile.bio ?? ""
            if let raw = profile.avatarURL, let url = URL(string: raw) {
                avatarURL = url
            }
        }
        if let myID = artistStore.myArtistID, let detail = artistStore.cache[myID] {
            stageName = detail.stageName
            genre = detail.genres.first ?? ""
            instagram = detail.social?.instagram ?? ""
            soundcloud = detail.social?.soundcloud ?? ""
            spotify = detail.social?.spotify ?? ""
        }
    }

    /// Handle a PhotosPicker selection — load raw bytes, upload to
    /// artist-media, then PATCH public.profiles.avatar_url with the
    /// returned public URL. Any failure surfaces in the error banner.
    private func handleAvatarSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard case .signedIn(let userID, _, _) = auth.state else {
            errorMessage = "Sign in to upload a photo."
            return
        }
        isUploadingAvatar = true
        errorMessage = nil
        defer { isUploadingAvatar = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Couldn't read the selected photo."
                return
            }
            let (ext, mime) = Self.imageEncoding(for: data)
            let uploaded = try await RostrStorage.upload(
                data: data,
                kind: .avatar,
                extensionHint: ext,
                userID: userID,
                contentType: mime
            )
            await profileStore.updateAvatarURL(uploaded.publicURL.absoluteString, userID: userID)
            if let err = profileStore.lastError {
                errorMessage = err
                return
            }
            avatarURL = uploaded.publicURL
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch let error as RostrStorageError {
            errorMessage = Self.humanise(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sniff the image header — JPEG vs PNG — so we upload with the
    /// right content type. PhotosPicker hands us raw Data, no mime.
    private static func imageEncoding(for data: Data) -> (ext: String, mime: String) {
        guard data.count >= 4 else { return ("jpg", "image/jpeg") }
        let header = data.prefix(4)
        if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return ("png", "image/png")
        }
        return ("jpg", "image/jpeg")
    }

    private static func humanise(_ error: RostrStorageError) -> String {
        switch error {
        case .notSignedIn:        return "Sign in to upload a photo."
        case .uploadFailed(let m): return "Upload failed — \(m)"
        case .urlUnavailable:     return "Couldn't read the uploaded file's URL."
        }
    }

    private func save() async {
        guard case .signedIn(let userID, _, _) = auth.state else {
            errorMessage = "Sign in to save changes."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Persist bio to profiles (always safe — even for promoters).
        await profileStore.update(userID: userID, bio: bio)
        if let err = profileStore.lastError {
            errorMessage = err
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }

        // Artist-side fields land on public.artists.
        if let artistID = artistStore.myArtistID {
            let social = ArtistDTO.SocialLinks(
                instagram: instagram.nilIfEmpty,
                soundcloud: soundcloud.nilIfEmpty,
                spotify: spotify.nilIfEmpty
            )
            await artistStore.updateProfileCore(
                artistID: artistID,
                stageName: stageName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                primaryGenre: genre.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                social: social
            )
            if let err = artistStore.lastError {
                errorMessage = err
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #endif
                return
            }
        }

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        nav.pop()
    }

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

    // MARK: — Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack(alignment: .center, spacing: R.S.md) {
                avatarThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile photo")
                        .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg3)
                    PhotosPicker(
                        selection: $avatarPickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text(isUploadingAvatar ? "Uploading…" : (avatarURL == nil ? "Upload" : "Change"))
                            .font(R.F.mono(10, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(R.C.fg1)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background {
                                Capsule().fill(R.C.glassLo)
                            }
                            .overlay {
                                Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                            }
                    }
                    .disabled(isUploadingAvatar)
                    .accessibilityLabel("Change profile photo")
                }
                Spacer()
            }

            field(label: "Stage name",  text: $stageName)
            field(label: "Primary genre", text: $genre)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
        .onChange(of: avatarPickerItem) { _, newItem in
            Task { await handleAvatarSelection(newItem) }
        }
    }

    /// Either the uploaded photo (AsyncImage) or the deterministic
    /// gradient Cover fallback when the user hasn't uploaded yet.
    @ViewBuilder
    private var avatarThumbnail: some View {
        if let url = avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Cover(
                        seed: stageName.isEmpty ? "Artist" : stageName,
                        size: nil,
                        cornerRadius: R.Rad.card
                    )
                @unknown default:
                    Cover(
                        seed: stageName.isEmpty ? "Artist" : stageName,
                        size: nil,
                        cornerRadius: R.Rad.card
                    )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous))
            .overlay {
                if isUploadingAvatar {
                    RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                    ProgressView().tint(R.C.fg1)
                }
            }
        } else {
            Cover(
                seed: stageName.isEmpty ? "Artist" : stageName,
                size: 64,
                cornerRadius: R.Rad.card
            )
            .overlay {
                if isUploadingAvatar {
                    RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                    ProgressView().tint(R.C.fg1)
                }
            }
        }
    }

    // MARK: — Bio card

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack {
                Text("Bio")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(bio.count) / 240")
                    .monoLabel(size: 8.5, tracking: 0.5, color: bio.count > 240 ? R.C.red : R.C.fg3)
            }
            TextEditor(text: $bio)
                .font(R.F.body(14))
                .foregroundStyle(R.C.fg1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90, maxHeight: 140)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Gallery card (still local-only until Wave 5.6)

    private var galleryCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack {
                Text("Gallery")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(gallery.count) / 12")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: R.S.xs), count: 3), spacing: R.S.xs) {
                ForEach(gallery, id: \.self) { item in
                    Cover(seed: item, size: nil, cornerRadius: R.Rad.button2)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation(R.M.easeOutFast) { gallery.removeAll { $0 == item } }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(R.C.fg1)
                                    .frame(width: 20, height: 20)
                                    .background { Circle().fill(Color.black.opacity(0.55)) }
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                            .accessibilityLabel("Remove photo")
                        }
                }
                addTile
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private var addTile: some View {
        Button {
            // Wave 5.6: real picker
            gallery.append("NewPhoto-\(gallery.count)")
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .strokeBorder(
                        R.C.borderMid,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(R.C.fg2)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add photo")
    }

    // MARK: — Rider card (deferred to Wave 5.6 file uploads)

    private var riderCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Technical rider")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            HStack(spacing: R.S.sm) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("No rider attached")
                        .font(R.F.body(13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("Upload a PDF — promoters see it on every booking request.")
                        .font(R.F.mono(8.5, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(R.C.fg3)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    // Wave 5.6: Supabase Storage uploader.
                } label: {
                    Text("Attach")
                        .font(R.F.mono(9.5, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(R.C.fg1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background { Capsule().fill(R.C.glassLo) }
                        .overlay { Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
                }
                .buttonStyle(.plain)
            }
            .padding(R.S.xs)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Socials card

    private var socialsCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Socials")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            socialField(icon: "camera.fill",     label: "Instagram",  text: $instagram)
            socialField(icon: "waveform",        label: "SoundCloud", text: $soundcloud)
            socialField(icon: "music.note",      label: "Spotify",    text: $spotify)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private func socialField(icon: String, label: String, text: Binding<String>) -> some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                        .fill(R.C.glassLo)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
                TextField(
                    "",
                    text: text,
                    prompt: Text("@handle").foregroundStyle(R.C.fg3)
                )
                .foregroundStyle(R.C.fg1)
                .font(R.F.body(13))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: — Text field helper

    private func field(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            TextField(
                "",
                text: text,
                prompt: Text(label).foregroundStyle(R.C.fg3)
            )
            .foregroundStyle(R.C.fg1)
            .font(R.F.body(14))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}

#if DEBUG
#Preview("ProfileEditView") {
    let nav = NavigationModel()
    let auth = AuthStore()
    let profile = ProfileStore()
    let artistStore = ArtistDetailStore()
    return ProfileEditView(nav: nav)
        .environment(auth)
        .environment(profile)
        .environment(artistStore)
        .preferredColorScheme(.dark)
}
#endif
