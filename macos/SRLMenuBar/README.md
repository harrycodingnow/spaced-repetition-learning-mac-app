# SRL Menu Bar for macOS

A native SwiftUI companion for the `srl` CLI. An invisible hover target matches the MacBook notch exactly; hovering it morphs the notch into a flush, black Dynamic Island interface. It reads and writes the same `~/.srl` JSON files, so progress stays shared with the command line.

## MVP features

- A compact, half-height Today view with question entry above side-by-side revise/new queues.
- Native Liquid Glass navigation and controls on macOS 26, with material fallbacks on older Macs.
- No-click hover opening with a two-stage notch morph, overshoot, and soft settle.
- A persistent menu-bar icon with Show and Quit actions.
- Transparent collapsed state and a black expanded surface connected to the top screen edge.
- Quick 1–5 rating input with Tab autocomplete, including shorthand such as `Two Sum -5`.
- The CLI-compatible schedule: a rating of `n` schedules the next review in `n` days.
- Mastery after two consecutive ratings of 5.
- A 52-week activity heatmap in its own Activity tab.
- A weekly calendar with previous/next navigation for past completions and upcoming reviews.
- Selectable, topic-grouped Blind 75, NeetCode 150, and NeetCode 250 routes.

## Requirements

- macOS 13 or newer.
- Xcode Command Line Tools with Swift 6 or newer.

## Build a double-clickable app

From the repository root:

```bash
./macos/SRLMenuBar/scripts/build-app.sh
open "macos/SRLMenuBar/dist/SRL Menu Bar.app"
```

The build is ad-hoc signed for local use. It is intentionally not sandboxed because it must access the existing `~/.srl` directory. Distribution to other Macs would require Developer ID signing and notarization.

## Develop and test

Open `macos/SRLMenuBar/Package.swift` in Xcode, or use Swift Package Manager:

```bash
swift run --package-path macos/SRLMenuBar
swift test --package-path macos/SRLMenuBar
```

The app reloads `~/.srl` when opened or when the refresh button is clicked. Writes use atomic file replacement and remain compatible with the Python CLI schema.
