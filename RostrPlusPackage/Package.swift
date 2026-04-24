// swift-tools-version: 6.0
// ROSTR+ iOS feature package.
//
// The app target (`RostrPlus`) is a thin shell — every feature lives here,
// in the `RostrPlusFeature` product. Matches the workspace + SPM pattern
// documented in the repo's CLAUDE.md.

import PackageDescription

let package = Package(
    name: "RostrPlusPackage",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RostrPlusFeature",
            targets: ["RostrPlusFeature"]
        ),
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        )
    ],
    dependencies: [
        // Supabase Swift SDK — auth, postgrest, realtime, storage, functions.
        // Pinned to the 2.x line; each minor has been stable for our use.
        .package(
            url: "https://github.com/supabase/supabase-swift.git",
            from: "2.24.0"
        )
    ],
    targets: [
        // ─── DesignSystem ─────────────────────────────────────────
        // Colors, Typography, Spacing, Radii, Motion, GlassSurface,
        // and the bundled Fontshare + JetBrains Mono font files.
        //
        // Kept as its own module so it can be imported by previews +
        // tests without pulling in the rest of the feature surface.
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem",
            resources: [
                .process("Fonts")
            ]
        ),

        // ─── RostrPlusFeature ─────────────────────────────────────
        // The big one — all 23 screens + navigation + stores + the
        // Supabase client wrapper. Sources are spread across several
        // sibling folders (AppCore, Features, Stores, SupabaseClient,
        // Components) — rolled into one module via a shared `Sources`
        // path with DesignSystem excluded (it's its own target).
        .target(
            name: "RostrPlusFeature",
            dependencies: [
                "DesignSystem",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources",
            exclude: ["DesignSystem"]
        ),

        // ─── Tests ────────────────────────────────────────────────
        .testTarget(
            name: "RostrPlusFeatureTests",
            dependencies: ["RostrPlusFeature", "DesignSystem"]
        )
    ]
)
