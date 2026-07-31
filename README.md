# Clipboard

A Raycast-style clipboard history app for macOS, built with SwiftUI. Runs as a
menu bar app, records everything you copy (text, links, colors, images,
files), and recalls it from a keyboard-first floating panel.

## Usage

- **⌘⇧V** (editable in Settings) — open the history panel
- **Type** to filter entries; use the dropdown to filter by type
- **↑ / ↓** — move selection
- **↵** — copy the selected entry to the clipboard and close
- **⌘↵** — open the selected link or file
- **⌘K** — open the selected entry's actions menu
- **⌘P** — toggle the preview drawer
- **⌘Y** — Quick Look the selected entry (works for text, images, and files)
- **⌘⌫** — delete the selected entry
- **Esc** — close the actions menu, Quick Look, preview drawer, then the panel

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

Unit tests are safe to run on the host:

```sh
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Debug \
  -derivedDataPath build test
```

UI tests drive the real panel with synthesized keyboard events. The `--uitest`
launch flag points the app at a throwaway store so tests never touch real
history. They run in an ephemeral VM so XCUITest never takes over the host's
mouse, keyboard, or clipboard:

```sh
~/.claude/skills/vm-uitest/uitest.sh
```
