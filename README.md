# TopNest

TopNest is a native macOS notch panel for music, clipboard history, calendar events, weather, system stats, AI usage limits, and small custom widgets. It stays compact until you click it or choose to open it on hover.

> **Developer preview · macOS 14+**
> Version 0.5.0. The current build script produces an ad hoc signed app for local testing. A Developer ID signed and notarized public download has not been published yet.

## Get started

Clone the repository on a Mac with Xcode 26 and Swift 6, then run:

```sh
zsh scripts/build-app.sh
open dist/TopNest.app
```

The script creates `dist/TopNest.app`. Click the capsule near the notch to open the panel. The menu bar icon provides another way to open it and access Settings. `⌘,` opens Settings while TopNest is active; `Esc` closes the expanded panel.

For production distribution, the app and its embedded helper need Developer ID signing and notarization. The current build is intended for local development.

## What it does

| Area | Features |
| --- | --- |
| Music | Spotify and Apple Music controls through AppleScript. An optional extended mode can show more players, artwork, and seeking. |
| Widgets | Arrange music, calendar, weather, clipboard, Codex and Claude limits, CPU, RAM, GPU, network, and custom widgets in a two-row grid. |
| Clipboard and shelf | Search recent copied text and hold files for drag and drop. Clipboard history is opt-in. |
| AI | Show Codex and Claude usage limits. Optional hooks notify you when an AI tool needs attention; answers and permission decisions stay in the original tool. |
| Displays | Use a single display by default, or show a compact capsule on every eligible display. |
| Appearance | System, light, or dark theme; four UI languages; compact and expanded panel styles. |

The extended music mode uses an unsupported MediaRemote workaround and may stop working after a macOS update. TopNest falls back to the standard music mode if it fails. Calendar and music Automation permissions are requested only when those features are used. Weather uses Open-Meteo; review its license before commercial distribution.

## Extensions

TopNest 0.5.0 introduces a **widget extension catalog**. These extensions are declarative JSON packages. They display a value from an HTTPS endpoint; they do not add native code to the app.

- Open **Settings → Extensions** to browse the catalog, install, update, or remove a widget.
- On the [Extensions site source](docs/extensions/index.html), **Open in TopNest** uses a `topnest://install?id=…` link. TopNest downloads the matching package, verifies its SHA-256 digest, checks its version and HTTPS data source, then shows a confirmation sheet. The site must be published through GitHub Pages before this link works from the web.
- **Import package file…** works offline with a downloaded `.json` package. The sample [Swift stars package](docs/extensions/packages/swift-stars.json) can be used to test this flow now.
- The older **Settings → Widgets → Import from file…** option still accepts individual custom-widget JSON files. Those files are not versioned extension packages. It can import shell-command widgets only after showing the command and asking for confirmation.

The catalog's current scope is deliberately narrow: remote packages containing shell commands are rejected. A command widget runs under your macOS user account, so it belongs in the explicit local import flow. See [extension format and publishing guide](docs/EXTENSIONS.md).

## Website

The static landing page and Extensions page live in [`docs/`](docs/index.html). They are ready to publish with GitHub Pages using **main → /docs**. The app expects the catalog at `https://qobulovasror.github.io/TopNest/extensions/catalog.json`; if the Pages URL or repository owner changes, update `ExtensionDownload.catalogURL` and the package URLs in `docs/extensions/catalog.json` together.

The site currently directs visitors to build from source. Add a public download link after a Developer ID signed and notarized release is available. Do not upload `dist/TopNest.app` from the current ad hoc build as a public installer.

## Develop and test

```sh
swift test
```

The test suite covers widget layout and persistence, music source fallback, AI notices, system stats, and extension package validation and updates. Snapshot tests write PNGs when `TOPNEST_SNAPSHOT_DIR` is set:

```sh
TOPNEST_SNAPSHOT_DIR=/path/to/output swift test --filter SnapshotTests
```

The interface strings come from `scripts/generate-localizations.py`. After changing user-facing strings, run that script and review the generated tables in `Resources/`.

## Known limits

TopNest is still a prototype. External-display and fullscreen behavior, Apple Music, and some visual interactions need more testing on real Macs. The website catalog requires GitHub Pages to be enabled, and the public app download requires production signing and notarization. Package hashes protect downloads against an unexpected file change, but the official catalog itself must remain under trusted maintainer control.

## License

No open-source license has been selected yet. The repository is source-visible, but redistribution and contributions need an explicit license decision before this is presented as an open-source project.
