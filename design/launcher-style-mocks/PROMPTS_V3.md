# Compact-pass image-generation prompts

The compact PNGs were produced with the built-in image-generation workflow.
The supplied Launcher screenshot remained the style reference; the final
second-pass light mock supplied the initial edit target.

## Compact light state

```text
Use case: precise-object-edit
Asset type: density refinement of the primary light Clipboard UI mock
Input images: Image 1 is the Launcher density/style reference. Image 2 is the edit target.
Primary request: Make the history list in Image 2 substantially more compact and scan-efficient. The current list pane and vertical gaps are too roomy. Change only the left list pane and the split position; preserve the header, right preview, bottom metadata, footer, panel shell, colors, and overall Launcher-family style.
List width: move the vertical split divider left so the history pane occupies about 39–40% of the inner panel width rather than half. Give the preview pane the additional width.
Vertical density: use a 30–32px section header and contiguous 40–42px single-line result rows, with 0–2px space between rows. The rows should read as a compact list like the supplied Launcher reference, not widely separated floating objects. Use 18–20px icons, 14–15px primary text, 12–13px inline source/age labels. Selected row height should also be only 40–42px, with the same broad quiet rounded selection fill and about 9px radius.
Content: Under "Today", show these compact rows in order: selected "Clipboard should feel instant…" with inline "Notes" and right "2m"; "github.com/stevemurr/clipboard" with "Safari" and "15m"; "Image (1440×960)" with "Preview" and "32m"; "#7967E8" with "Figma" and "45m"; "LauncherView.swift" with "Finder" and "1h". Then a compact "Yesterday" header followed immediately by two more compact rows: "xcodebuild -project Clipboard…" with "Terminal" and "Yesterday"; "developer.apple.com/design" with "Safari" and "Yesterday". Truncate titles cleanly with an ellipsis where necessary. Keep every row on one baseline.
Invariants: Preserve Image 2’s 59px flat unboxed search header, all header controls, exact right-side Preview content and typography, bottom metadata strip, 39px footer, panel framing, black surround, surface treatment, and icon style. The full selected text must remain visible in the Preview pane.
Text (verbatim where visible): "Today"; "Yesterday"; "Clipboard should feel instant…"; "Notes"; "2m"; "github.com/stevemurr/clipboard"; "Safari"; "15m"; "Image (1440×960)"; "Preview"; "32m"; "#7967E8"; "Figma"; "45m"; "LauncherView.swift"; "Finder"; "1h"; "xcodebuild -project Clipboard…"; "Terminal"; "developer.apple.com/design"
Avoid: tall rows, 80–100px gaps, two-line rows, large icons, oversized selection, row cards, separators between every row, changes to the preview/header/footer, watermark
```

## Compact dark state

```text
Use case: precise-object-edit
Asset type: compact-list refinement of the dark Clipboard mock
Input images: Image 1 is the Launcher density/style reference. Image 2 is the compact light layout reference and defines the desired narrow pane and row rhythm. Image 3 is the dark edit target whose dark appearance, image preview, header, metadata, and footer must be preserved.
Primary request: Update only Image 3’s history pane to match Image 2’s compact list density and width. Make the dark list substantially narrower and tighter while leaving the rest of the dark mock unchanged.
List width: move Image 3’s vertical split divider left so the history pane occupies about 39–40% of the inner panel, exactly like Image 2. Expand the image preview pane into the reclaimed width without changing its overall visual treatment.
Vertical density: use a 30–32px "Results" header and contiguous 40–42px single-line rows with 0–2px between rows, as shown in Image 2. Use 18–20px thumbnails, 14–15px primary type, and 12–13px secondary source/age. The selected pill is only 40–42px tall with about 9px radius. No large vertical gaps.
Rows: selected "Image (1440×960)" with inline "Preview" and right "2m"; "Image (2560×1440)" with "Safari" and "15m"; "Image (1200×800)" with "Figma" and "32m"; "Image (512×512)" with "Finder" and "1h"; "Screenshot 2026-07-29.png" with "Preview" and "Yesterday"; "clipboard-icon.png" with "Finder" and "Yesterday". Truncate long titles cleanly. Keep every row on one baseline.
Invariants: Preserve Image 3’s exact near-black surface, flat unboxed header, search text "design references", Images/Hotkey/gear controls, large mountain image preview, Preview/PNG labels, metadata strip, footer, panel shell, black surround, colors, and typography. The image preview may become wider only because the divider moves left.
Avoid: tall rows, 80–100pt gaps, two-line rows, large thumbnails, row cards, per-row separators, changes to dark colors, changes to preview content, changes to header/footer, watermark
```

## Compact action state

```text
Use case: precise-object-edit
Asset type: compact-list refinement of the light Clipboard action-state mock
Input images: Image 1 is the Launcher density/style reference. Image 2 is the compact light layout reference and defines the desired narrow history pane and row rhythm. Image 3 is the action-state edit target whose header, link preview, footer, and floating action palette must be preserved.
Primary request: Update only Image 3’s history pane and split position to use Image 2’s compact density. The existing action-state list is too roomy. Keep the palette and all right-pane content visually unchanged.
List width: move the vertical divider left so the history pane occupies about 39–40% of the inner panel width, matching Image 2. Allow the preview pane to widen. Keep the floating actions palette anchored above the lower-right footer, fully inside the panel.
Vertical density: 30–32px section header, then contiguous 40–42px single-line result rows with only 0–2px between. Use 18–20px icons, 14–15px primary text, 12–13px source/age. The selected row is only 40–42px tall with a 9px-radius quiet gray selection. No tall gaps or floating-row feel.
Content: Under "Today", selected "github.com/stevemurr/clipboard" with inline "Safari" and right "12m"; "Clipboard should feel instant…" with "Notes" and "2m"; "Image (1440×960)" with "Preview" and "32m"; "#7967E8" with "Figma" and "45m"; "LauncherView.swift" with "Finder" and "1h". Then a compact "Yesterday" header and two rows: "xcodebuild -project Clipboard…" with "Terminal" and "Yesterday"; "developer.apple.com/design" with "Safari" and "Yesterday". Truncate long titles cleanly; all rows stay on one baseline.
Invariants: Preserve Image 3’s flat unboxed header, All Types/Hotkey/gear controls, exact link Preview content, Link label, bottom metadata strip, footer, action palette title and four actions, palette styling and shadow, panel shell, black surround, colors, and typography. Do not change palette size or labels.
Avoid: tall rows, wide left pane, two-line rows, large icons, row cards, per-row separators, moved or resized action palette, changes to header/preview/footer, watermark
```
