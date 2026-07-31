# Compact-list refinement

The sleek second pass established the right visual language, but its history
pane still consumed too much horizontal and vertical space. This refinement
makes the list behave more like an efficient Launcher result set.

## Updated density

- History pane: approximately 39–40% of the panel instead of half.
- Section header: 30–32 points.
- Result row: 40–42 points.
- Inter-row spacing: 0–2 points.
- Selection radius: approximately 9 points.
- Icon or thumbnail: 18–20 points.
- Primary row text: 14–15 points.
- Inline source and age: 12–13 points.

The narrower pane deliberately truncates long clipboard values; the full value
remains available in Preview. This gives the list a clearer job—rapid scanning
and selection—while the preview receives enough room for text, images, and
files.

## Current implementation target

`clipboard-launcher-light-v3-compact.png`

The dark and action-state mocks use the same pane width and row rhythm.
