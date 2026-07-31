# Second-pass design rationale

The supplied Launcher screenshot exposed a key distinction that the original
mockups missed: Launcher is not primarily a collection of polished controls.
It is one calm surface whose hierarchy comes from typography, spacing, and a
single selected-row treatment.

## What changed

| First pass | Second pass |
| --- | --- |
| Outlined search control | Large unboxed command text |
| Two-line, card-like history rows | Flat single-line 48-point rows |
| Boxed or tiled icons | Small native icons and thumbnails |
| Bordered preview card | Preview directly on the pane |
| Stacked metadata card | One hairline-separated metadata strip |
| Product-dashboard polish | Native utility-window restraint |
| Multiple competing corner treatments | Corners reserved for selection, keycaps, preview media, and popovers |

## Recommended direction

`clipboard-launcher-light-v2-final.png` is the implementation target.

Its most important qualities are:

1. **One shared surface.** The shell, list, and preview read as one utility,
   divided only where the information architecture requires it.
2. **Launcher-native density.** Header, section labels, rows, and footer follow
   Launcher’s established 59/36/48/39-point vertical rhythm.
3. **Single-line scanning.** Clipboard source and age become quiet inline
   metadata, making the history pane faster to scan.
4. **Selection as the primary shape.** The selected row is the only broad
   rounded rectangle in the normal state.
5. **Professional preview treatment.** Content gets space rather than chrome.
   Metadata is available without becoming a second focal point.

## Interaction note

The action-palette state intentionally demonstrates Launcher’s visual pattern.
Its Command-K footer label is conceptual because Clipboard currently uses
Command-K for Quick Look. Shortcut behavior should be resolved separately from
the visual implementation.
