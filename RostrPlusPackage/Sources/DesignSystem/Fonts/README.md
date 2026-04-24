# Bundled fonts

Drop these files here so the package's static resources pick them up:

## Chillax (Fontshare — https://www.fontshare.com/fonts/chillax)
- `Chillax-Regular.otf`
- `Chillax-Medium.otf`
- `Chillax-Semibold.otf`
- `Chillax-Bold.otf`

## Satoshi (Fontshare — https://www.fontshare.com/fonts/satoshi)
- `Satoshi-Regular.otf`
- `Satoshi-Medium.otf`
- `Satoshi-Bold.otf`

## JetBrains Mono (Google Fonts — https://fonts.google.com/specimen/JetBrains+Mono)
- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Medium.ttf`
- `JetBrainsMono-SemiBold.ttf`
- `JetBrainsMono-Bold.ttf`

## Licensing
- Chillax + Satoshi are OFL-licensed. Fontshare's download bundle includes `OFL.txt` — commit it here alongside the font files.
- JetBrains Mono is OFL. Ship `OFL.txt` from the Google Fonts download too.

## Why we bundle instead of loading via CDN
1. Offline reliability — a cold start on a bad flight-wifi shouldn't render in SF Pro and look broken.
2. First-paint latency — no extra round trip to Fontshare before Chillax becomes available.
3. App Store review — Apple flags apps that fetch critical assets over HTTP at runtime.

Once the files land, `R.F.registerBundledFonts()` (called from `RostrPlusApp.init()`) registers them with CoreText and every `R.F.display(...)` / `R.F.body(...)` / `R.F.mono(...)` resolves correctly.
