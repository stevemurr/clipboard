# Clipboard

A Raycast-style clipboard history app for macOS, built with SwiftUI. Runs as a
menu bar app, records everything you copy (text, links, colors, images,
files), and recalls it from a keyboard-first floating panel.

## Usage

- **⌘⇧V** (editable in Settings) — open the history panel
- **Type** to filter entries; use the dropdown to filter by type
- **↑ / ↓** — move selection
- **↵** — copy the selected entry to the clipboard and close
- **⌘K** — Quick Look the selected entry (works for text, images, and files)
- **⌘⌫** — delete the selected entry
- **Esc** — close Quick Look, then the panel

History persists across launches (SwiftData at
`~/Library/Application Support/Clipboard/`, images stored as PNG files).
Duplicate copies bump a "times copied" counter instead of creating new rows.
Concealed pasteboard content (password managers) is never recorded. The
history size cap is configurable in Settings.

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Clipboard.app
```

## Tests

UI tests drive the real panel with synthesized keyboard events. The `--uitest`
launch flag points the app at a throwaway store so tests never touch real
history. Note: the tests overwrite the system clipboard while running.

```sh
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Debug \
  -derivedDataPath build test
```
