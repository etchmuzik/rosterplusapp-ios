// ProfileEditView.swift — Screen 22
//
// Edit the artist's public profile. Port of `ProfileEditScreen` at
// ios-app.jsx line 2014. Sections:
//
//   1. Avatar + stage name + genre
//   2. Bio — multi-line text field
//   3. Gallery — 3-column image grid with +add tile (Wave 4: wire uploads)
//   4. Rider — attached PDF pill with "replace" action
//   5. Socials — IG / SoundCloud / Spotify inputs with glyph chips
//
// No real uploads in Wave 3 — all fields are local @State. Wave 4
// ships the Supabase storage wire-up to the `artist-media` bucket.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ProfileEditView: View {
    @Bindable var nav: NavigationModel

    @State private var stageName: String = "NOVAK"
    @State private var genre: String = "Tech House"
    @State private var bio: String = "Dubai-based selector building long, patient sets. Residencies at WHITE + Soho Garden."
    @State private var instagram: String = "@dj.novak"
    @State private var soundcloud: String = "novakdxb"
    @State private var spotify: String = "0nov4kxx"
    @State private var gallery: [String] = ["Gallery1", "Gallery2", "Gallery3"]

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Edit profile", onBack: { nav.pop() }) {
                Button(action: save) {
                    Text("Save")
                        .monoLabel(size: 10, tracking: 0.8, color: R.C.bg0)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background { Capsule().fill(R.C.fg1) }
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
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
    }

    // MARK: — Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack(alignment: .center, spacing: R.S.md) {
                Cover(seed: stageName, size: 64, cornerRadius: R.Rad.card)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile photo")
                        .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg3)
                    Button {
                        // Wave 4: trigger UIImagePicker / PhotosPicker
                    } label: {
                        Text("Change")
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
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            field(label: "Stage name",  text: $stageName)
            field(label: "Primary genre", text: $genre)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Bio card

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack {
                Text("Bio")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(bio.count) / 240")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
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

    // MARK: — Gallery card

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
            // Wave 4: real picker
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

    // MARK: — Rider card

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
                    Text("novak-rider-v3.pdf")
                        .font(R.F.body(13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("842 KB · Updated 12 Apr")
                        .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
                }
                Spacer()
                Button {
                    // Wave 4: file picker
                } label: {
                    Text("Replace")
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

    private func save() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        nav.pop()
    }
}

#if DEBUG
#Preview("ProfileEditView") {
    let nav = NavigationModel()
    return ProfileEditView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
