# Second-pass image-generation prompts

The second-pass PNG previews were made with the built-in image-generation
workflow. The supplied Launcher screenshot was used as a style reference, and
the revised light mock was then used as the structural reference for the dark
and action states.

## Light text state

```text
Use case: ui-mockup
Asset type: polished second-pass mockup for the native macOS Clipboard utility
Input images: Image 1 is the visual-style reference only—the supplied Launcher screenshot. Match its surface restraint, typography, density, spacing, selected-row treatment, divider subtlety, footer, keycaps, and overall professional tone. Do not reproduce Launcher’s application content.
Primary request: Redesign Clipboard so it clearly belongs in the exact same product family as the reference Launcher, while preserving Clipboard’s history-and-preview split. Make this pass noticeably sleeker and more professional than a card-heavy settings UI.
Composition: one isolated 774×512-style floating macOS panel centered on a plain black surround, matching the reference framing and proportions; light appearance; straight-on UI screenshot
Panel shell: 16px continuous corners; very subtle warm-gray translucent popover surface close to the reference; hairline outer stroke; no traffic-light controls; no conventional title bar; soft understated utility-window shadow
Header: precisely 59px tall and completely flat—no outlined search box, no inset search field, no magnifying-glass container. Large 20px medium gray placeholder text aligned at x=16 reading exactly "Search clipboard history". At right, understated text "All Types" with a tiny chevron, then small "Hotkey" label, a compact keycap "⇧⌘V", and the same small rounded gear button treatment as the reference. One hairline divider below.
Main layout: split pane with a 350px history list on the left and preview on the right, separated by one hairline vertical divider. Both panes live directly on the shared panel surface—avoid separate white cards.
History pane: 36px section header "Today" in 13px semibold secondary text. Six single-line 48px rows matching Launcher’s geometry. Each row has a restrained 20–24px native icon, 15–16px medium primary title, an optional short secondary source label inline, and right-aligned age. Only the first row has the reference’s broad quiet gray rounded selection background; all other rows are completely flat with no separators and no individual cards. Items: selected "Clipboard should feel instant, quiet, and native." with inline "Notes" and right label "2m"; "github.com/stevemurr/clipboard" with "Safari" and "15m"; "Image (1440×960)" with "Preview" and "32m"; "#7967E8" with "Figma" and "45m"; "LauncherView.swift" with "Finder" and "1h". Below, a small section header "Yesterday".
Preview pane: flat section header "Preview" with small right label "Text". A generous, calm text preview aligned top-left with monospaced text and no heavy border: "Clipboard should feel instant, quiet, and native." Use a barely perceptible inner surface only if needed. Near the bottom, one simple hairline divider and a single compact metadata strip—not a card—reading "Notes  ·  Text  ·  143 characters  ·  Copied 2 minutes ago" in secondary 12–13px type.
Footer: exactly 39px, separated by one hairline divider and lightly tinted like the reference. Left: small clipboard symbol. Right: primary label "Copy to Clipboard" followed by a Return keycap, a thin vertical divider, then "Quick Look" followed by separate Command and K keycaps. Match the supplied Launcher footer’s alignment and restraint.
Visual system: SF Pro typography; near-monochrome grayscale palette; 20px search, 13px section labels, 15–16px rows, 12px metadata; selected fill about 9–10% black; compact 6px-radius keycaps; restrained icon color only; crisp native macOS rendering.
Text (verbatim): "Search clipboard history"; "All Types"; "Hotkey"; "Today"; "Yesterday"; "Preview"; "Text"; "Clipboard should feel instant, quiet, and native."; "github.com/stevemurr/clipboard"; "Image (1440×960)"; "#7967E8"; "LauncherView.swift"; "Copy to Clipboard"; "Quick Look"
Constraints: The style reference is the source of truth. Preserve its quiet flat surface, large unboxed search header, single selected pill, roomy blank space, small icon scale, muted grays, and precise baseline alignment. The result must feel like a sibling app authored by the same designer.
Avoid: outlined search fields, magnifying glass inside a box, boxed icons, stacked metadata cards, tile grids, frosted-glass spectacle, big gradients, blue selection, excessive borders, traffic lights, browser chrome, Raycast branding, mobile UI, logos, watermark
```

## Dark image state

```text
Use case: ui-mockup
Asset type: dark-mode companion mockup for the native macOS Clipboard utility
Input images: Image 1 is the original Launcher style reference. Image 2 is the edit target and layout source of truth—the revised light Clipboard mock. Preserve Image 2’s exact panel proportions, flat header, split-pane geometry, row density, footer alignment, and overall restraint. Apply Image 1’s sibling-product visual discipline.
Primary request: Create a dark-appearance version of Image 2 with an image-history item selected and an elegant image preview. Change only appearance and content appropriate to the image state; keep the structural design invariant.
Composition: same isolated 774×512-style panel centered on a plain black surround, same framing and scale as Image 2
Dark surface: adaptive near-black popover surface around RGB 27/27/30, subtle active material, hairline separators around 15% white, 16px continuous corner, understated shadow; no glow and no blue-tinted window chrome
Header: same flat 59px unboxed header. Search text exactly "design references" at 20px medium. Right side exactly "Images", tiny chevron, "Hotkey", compact "⇧⌘V" keycap, and gear. No outlined search box.
History pane: same 350px pane, section label "Results", five single-line 48px rows. Select the first row using a broad subtle 10% white rounded background. Rows: "Image (1440×960)" with inline "Preview" and right age "2m"; "Image (2560×1440)" with "Safari" and "15m"; "Image (1200×800)" with "Figma" and "32m"; "Image (512×512)" with "Finder" and "1h". Use restrained 22px thumbnail icons, not boxed app tiles. All unselected rows remain completely flat.
Preview pane: flat section heading "Preview" with right label "PNG". Show a refined landscape image with layered dark navy and muted teal mountain silhouettes and one small warm off-white sun; the preview should be large but calm, with a modest 10px corner radius, no thick frame, and a subtle natural shadow. Keep generous dark negative space around it. At the bottom, use the same single divider and metadata strip from Image 2, reading exactly "1440 × 960  ·  PNG  ·  624 KB  ·  Copied 2 minutes ago". No card around metadata.
Footer: preserve exact 39px structure. Left small clipboard symbol. Right "Copy to Clipboard" plus Return keycap, divider, "Quick Look" plus Command and K keycaps.
Typography and tone: SF Pro; primary text warm white; secondary text around 60% white; 20px search, 13px headers, 15–16px rows, 12–13px metadata; all baselines precise; tiny restrained thumbnail color only.
Text (verbatim): "design references"; "Images"; "Hotkey"; "Results"; "Preview"; "PNG"; "Image (1440×960)"; "Image (2560×1440)"; "Image (1200×800)"; "Image (512×512)"; "Copy to Clipboard"; "Quick Look"
Constraints: preserve Image 2’s flatness and geometry exactly; maintain same-family relationship to Image 1; one shared surface, one selected pill, no individual row cards, no boxed search, no metadata card.
Avoid: navy glass dashboard aesthetic, neon, purple, excessive contrast, card stacks, outlined controls, traffic lights, browser chrome, Raycast branding, oversized preview border, logos, watermark
```

## Link action state

```text
Use case: ui-mockup
Asset type: action-state companion mockup for the native macOS Clipboard utility
Input images: Image 1 is the Launcher style reference, especially its flat shell, footer, and selected-row treatment. Image 2 is the edit target and exact base design. Preserve Image 2’s panel scale, light surface, header, split-pane geometry, row rhythm, typography, and footer. Add only a selected link state and a Launcher-style action palette.
Primary request: Create the third state in the revised Clipboard mock set: a light-mode link item selected with an elegant actions palette floating above the lower-right footer. It must feel professional and restrained, as though implemented with the same components as the reference Launcher.
Base panel invariant: isolated 774×512-style panel on black surround; 16px corners; light warm-gray popover; flat unboxed 59px header; 350px list pane; hairline split divider; 39px footer. Do not redesign the base.
Header: placeholder exactly "Search clipboard history". Right side "All Types", tiny chevron, "Hotkey", keycap "⇧⌘V", gear.
History content: section "Today". Select first single-line 48px row using the broad quiet gray pill: "github.com/stevemurr/clipboard" with inline "Safari" and right age "12m". Other flat rows: "Clipboard should feel instant, quiet, and native." with "Notes"; "Image (1440×960)" with "Preview"; "#7967E8" with "Figma"; "LauncherView.swift" with "Finder". Small restrained native icons, no icon tiles.
Preview pane behind palette: flat heading "Preview" with right label "Link". Show the URL "https://github.com/stevemurr/clipboard" cleanly in medium monospaced type, with generous whitespace and no bordered card. Bottom metadata strip: "Safari  ·  Link  ·  Copied 12 minutes ago".
Footer: left small clipboard symbol; right "Copy to Clipboard" plus Return keycap, divider, then "Actions" plus separate Command and K keycaps.
Actions palette: float it just above the footer at bottom right, about 350px wide. It must match the reference Launcher’s popover exactly: subtly translucent same-family surface, 14px continuous radius, hairline outline, confident but soft shadow, small 40px title header, four 40px rows, 7px outer inset, 9px row radius. Palette title exactly "github.com/stevemurr/clipboard" in 13px secondary semibold. First row selected with a quiet gray background: "Copy to Clipboard" and Return keycap. Second: "Open Link" with Command and Return keycaps. Third: "Quick Look" with Command and Y keycaps. Fourth: "Delete from History" in restrained system red with Command and Delete keycaps. Use small monochrome SF Symbols-like icons. Keycaps must be compact and consistent.
Visual tone: SF Pro, muted grayscale, only link icon blue and delete red; precise baselines; plenty of shared-surface negative space; quiet focus rather than ornamental glass.
Text (verbatim): "Search clipboard history"; "All Types"; "Hotkey"; "Today"; "Preview"; "Link"; "github.com/stevemurr/clipboard"; "https://github.com/stevemurr/clipboard"; "Copy to Clipboard"; "Actions"; "Open Link"; "Quick Look"; "Delete from History"
Constraints: change only the selected content and add the palette; preserve Image 2’s sleek flat design. The palette should look like a true child component of the reference Launcher, not a generic context menu.
Avoid: rounded search box, card-heavy preview, boxed icons, thick palette border, giant palette, blur spectacle, colored menu rows, traffic lights, browser chrome, Raycast branding, watermark
```

## Final light-state polish

```text
Use case: precise-object-edit
Asset type: final polish of the primary light Clipboard UI mock
Input images: Image 1 is the Launcher style reference. Image 2 is the edit target.
Primary request: Make exactly one targeted layout correction in Image 2: keep the selected first history row strictly single-line like the Launcher reference. Move the secondary source label "Notes" onto the same baseline as the selected title "Clipboard should feel instant, quiet, and native.", positioned after the title in muted secondary gray. Keep the right-aligned age "2m" on that same baseline. Remove the existing second-line "Notes" label.
Constraints: change only the selected first row’s source-label placement. Preserve every other pixel-level design decision as closely as possible: exact panel framing, light surface, 59px flat header, text, split divider, all other history rows, Preview pane, metadata strip, footer, corner radii, typography, spacing, colors, icons, and black surround. Do not add or remove any other content.
Text (verbatim): "Clipboard should feel instant, quiet, and native."; "Notes"; "2m"
Avoid: new cards, outlined search field, two-line selected row, moved icons, changed preview, changed footer, changed panel scale, watermark
```
