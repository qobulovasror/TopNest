# TopNest

TopNest is a native macOS notch panel for music, clipboard history, calendar events, tasks, notes, a focus timer, weather, system stats, device batteries, AI usage limits, and small custom widgets. It stays compact until you click it or choose to open it on hover.

> **Developer preview · macOS 14+**
> Version 0.7.0. The current build script produces an ad hoc signed app for local testing. A Developer ID signed and notarized public download has not been published yet.

## Get started

Clone the repository on a Mac with Xcode 26 and Swift 6, then run:

```sh
zsh scripts/build-app.sh
open dist/TopNest.app
```

The script creates `dist/TopNest.app`. Click the capsule near the notch to open the panel. The menu bar icon provides another way to open it and access Settings. `⌘,` opens Settings while TopNest is active. `Esc` first leaves a focused text field, then closes the expanded panel.

Global shortcuts: `⌃⌥⌘N` panel, `⌃⌥⌘V` clipboard search, `⌃⌥⌘T` start or pause the timer, `⌃⌥⌘J` new note.

For production distribution, the app and its embedded helper need Developer ID signing and notarization. The current build is intended for local development.

## What it does

| Area | Features |
| --- | --- |
| Music | Spotify and Apple Music controls through AppleScript. An optional extended mode can show more players, artwork, and seeking. |
| Widgets | Arrange music, calendar, tasks, notes, timer, calculator, translation, weather, world clocks, prayer times, clipboard, Codex and Claude limits, system (CPU, RAM, GPU, network, disk, battery health), device batteries, screen time, Shortcuts, and custom widgets in a two-row grid. |
| Tabs | Home, Clipboard, Shelf, Notes, Tasks and Tools (calculator and translation). Choose and reorder tabs in Settings. |
| Focus | Timer and Pomodoro with a countdown next to the notch, notifications with “+5 min” and “Start next”, and an optional break reminder based on screen time. |
| Productivity | Quick notes (drag text onto the notch, ⌃⌥⌘J), Apple Reminders tasks, a calculator that copies results, and translation (Apple on-device on macOS 15+, optional Google Cloud key stored in Keychain). |
| Live activities | Charging, meetings, timer, connected Bluetooth devices, upcoming rain, downloads, and optional prayer reminders appear briefly next to the notch. |
| Clipboard and shelf | Search recent copied text and hold files for drag and drop. Clipboard history is opt-in. A clipboard item can be sent to notes. |
| Privacy | Screen time, Downloads monitoring, location, Reminders and translation services are off until you turn them on. Screen time stays on this Mac and is deleted after 30 days. |
| AI | Show Codex and Claude usage limits. Optional hooks notify you when an AI tool needs attention; answers and permission decisions stay in the original tool. |
| Displays | Use a single display by default, or show a compact capsule on every eligible display. |
| Appearance | System, light, or dark theme; four UI languages; compact and expanded panel styles. |

The extended music mode uses an unsupported MediaRemote workaround and may stop working after a macOS update. TopNest falls back to the standard music mode if it fails. Calendar and music Automation permissions are requested only when those features are used. Weather uses Open-Meteo; review its license before commercial distribution.

## Extensions

TopNest 0.5.0 introduces a **widget extension catalog**. These extensions are declarative JSON packages. They display a value from an HTTPS endpoint; they do not add native code to the app.

- Open **Settings → Extensions** to browse the catalog, install, update, or remove a widget.
- On the [Extensions site source](docs/extensions/index.html), **Open in TopNest** uses a `topnest://install?id=…` link. TopNest downloads the matching package, verifies its SHA-256 digest, checks its version and HTTPS data source, then shows a confirmation sheet. The site must be published through GitHub Pages before this link works from the web.
- **Import package file…** works offline with a downloaded `.json` package. The sample [Swift stars package](docs/extensions/packages/swift-stars.json) and the Central Bank of Uzbekistan currency packages ([USD](docs/extensions/packages/cbu-usd.json), [EUR](docs/extensions/packages/cbu-eur.json), [RUB](docs/extensions/packages/cbu-rub.json)) can be used to test this flow now. The catalog copies of these packages reach users only after the `TopNest-site` repository is updated.
- The older **Settings → Widgets → Import from file…** option still accepts individual custom-widget JSON files. Those files are not versioned extension packages. It can import shell-command widgets only after showing the command and asking for confirmation.

The catalog's current scope is deliberately narrow: remote packages containing shell commands are rejected. A command widget runs under your macOS user account, so it belongs in the explicit local import flow. See [extension format and publishing guide](docs/EXTENSIONS.md).

## Website

The static landing page and Extensions page live in [`docs/`](docs/index.html). They are published from the separate public [`TopNest-site`](https://github.com/qobulovasror/TopNest-site) repository so the app repository can stay private. The app expects the catalog at `https://qobulovasror.github.io/TopNest-site/extensions/catalog.json`; if the Pages URL or repository owner changes, update `ExtensionDownload.catalogURL` and the package URLs in `docs/extensions/catalog.json` together.

The site currently directs visitors to build from source. Add a public download link after a Developer ID signed and notarized release is available. Do not upload `dist/TopNest.app` from the current ad hoc build as a public installer.

## Develop and test

```sh
swift test
```

The test suite covers widget layout and persistence, widget states, the activity priority next to the notch, music source fallback, AI notices, system stats, the timer and Pomodoro model, the calculator parser, notes storage, task ordering, device battery parsing, screen time accounting, weather and prayer time parsing, translation requests, and extension package validation and updates. Snapshot tests write PNGs when `TOPNEST_SNAPSHOT_DIR` is set:

```sh
TOPNEST_SNAPSHOT_DIR=/path/to/output swift test --filter SnapshotTests
```

The interface strings come from `scripts/generate-localizations.py`. After changing user-facing strings, run that script and review the generated tables in `Resources/`.

## Known limits

TopNest is still a prototype. External-display and fullscreen behavior, Apple Music, and some visual interactions need more testing on real Macs. Permission prompts for Reminders, location and the Downloads folder are tied to the code signature, so an ad hoc rebuild may ask again. AirPods battery levels come from `system_profiler` and update every few minutes. Apple Translation needs macOS 15 and installed language packs; Uzbek may require the optional Google Cloud provider. The website catalog requires GitHub Pages to be enabled, and the public app download requires production signing and notarization. Package hashes protect downloads against an unexpected file change, but the official catalog itself must remain under trusted maintainer control.

## License

No open-source license has been selected yet. The repository is source-visible, but redistribution and contributions need an explicit license decision before this is presented as an open-source project.
