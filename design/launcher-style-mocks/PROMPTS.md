# Image-generation prompt set

The PNG previews were produced with the built-in image-generation tool. The
editable HTML study remains the deterministic source of truth.

## Light text-selection state

```text
Use case: ui-mockup
Asset type: polished product design mock for a native macOS clipboard history utility
Primary request: Show a single centered macOS floating panel that applies the exact visual language of a refined keyboard-first launcher to a clipboard history app. The app is named Clipboard.
Scene/backdrop: subtle cool gray macOS desktop wallpaper, no other windows, no menu bar
Style/medium: crisp high-fidelity native macOS UI screenshot, minimal, restrained, Apple-like, not a web app
Composition/framing: landscape 3:2 image, centered 774×512-style floating window, generous desktop margin, straight-on view
Window geometry: continuous 16px outer radius, thin separator border, subtle translucent light-gray popover material, soft real macOS utility-window shadow
Header: 59px command header, large 20px medium-weight search placeholder reading exactly "Search clipboard history", compact "All Types" filter chip, small "Hotkey" label with a ⇧⌘V keycap, small gear button
Main content: split pane; left pane about 330px with section headings "Today" and "Yesterday" and 48px rounded rows for text, link, image, color, and file items; first row selected with a quiet 10% black fill; small 24px rounded icons; readable examples including "Clipboard should feel instant, quiet, and native.", "github.com/stevemurr/clipboard", "Image (1440×960)", "#7967E8", and "LauncherView.swift"; secondary metadata like "Notes · 2 min ago"
Right pane: section label "Preview" with a restrained rounded card containing the selected text in monospaced type; below it a section label "Information" and a compact rounded three-row metadata card for Source Notes, Content Text, and Last copied 2 minutes ago
Footer: 39px quiet translucent footer; left label "Clipboard History"; right action "Copy to Clipboard" with Return keycap and "Quick Look" with Command and K keycaps
Visual language: SF Pro typography, 13–16px content type, 36px section headers, 48px rows, 12–14px card corners, subtle separators, tiny bordered rounded keycaps, grayscale dominant palette with very restrained blue/orange/purple icon color
Text (verbatim): "Search clipboard history"; "All Types"; "Hotkey"; "Today"; "Yesterday"; "Preview"; "Information"; "Clipboard History"; "Copy to Clipboard"; "Quick Look"
Constraints: realistic coherent UI, preserve the split history/preview anatomy, exact alignment and generous whitespace, text should be sharp and correctly spelled where specified, no traffic-light window controls, no title bar chrome, no logos, no watermark
Avoid: Raycast branding, browser chrome, iPhone UI, dramatic gradients, neon, excessive glass, thick borders, oversized icons, cards everywhere, illegible text
```

## Dark image-selection state

```text
Use case: ui-mockup
Asset type: second polished product design mock for a native macOS clipboard history utility
Primary request: Create the dark-appearance companion to a keyboard-first macOS Clipboard utility adopting a refined Launcher visual system. Show one centered floating Clipboard panel with an image item selected.
Scene/backdrop: understated deep blue-gray macOS desktop wallpaper, no other windows, no menu bar
Style/medium: crisp high-fidelity native macOS dark mode UI screenshot, minimal, quiet, restrained, Apple-like
Composition/framing: landscape 3:2 image, centered 774×512-style floating window, straight-on, generous desktop margin
Window: continuous 16px radius, thin light separator border, near-black translucent popover surface around RGB 27/27/30, soft realistic macOS shadow, no traffic-light controls
Header: 59px command header, 20px medium search text reading exactly "design references", compact "Images" filter chip, small gear button
Main: split pane; left history pane 330px with section header "Results" and four 48px image rows using small 24px rounded thumbnail icons; first row quietly selected with a 10% white fill; readable titles "Image (1440×960)", "Image (2560×1440)", "Image (1200×800)", "Image (512×512)" and subtle source/time metadata
Right pane: section label "Preview" and a tasteful landscape image preview showing abstract teal and navy mountain forms with a small warm sun; preview has 13px rounded corners and subtle shadow; below is a compact rounded information card with "Dimensions 1440 × 960" and "Image size 624 KB"
Footer: 39px translucent dark footer; left label "Clipboard"; right action "Copy" with Return keycap and "Quick Look" with Command and K keycaps
Visual language: SF Pro, 13–16px content, 36px section header, 48px rows, thin separators, subtle translucent surfaces, compact rounded bordered keycaps, extremely restrained cyan/blue thumbnail accents
Text (verbatim): "design references"; "Images"; "Results"; "Preview"; "Dimensions"; "Image size"; "Clipboard"; "Copy"; "Quick Look"
Constraints: exact macOS dark appearance, preserve split history/preview anatomy, sharp correctly spelled labels where specified, coherent alignment and spacing, no logos, no watermark
Avoid: browser chrome, title bar traffic lights, Raycast branding, neon, purple glow, excessive blur, thick borders, oversized icons, illegible text
```

## Actions-palette state

```text
Use case: ui-mockup
Asset type: third polished product interaction mock for a native macOS clipboard utility
Primary request: Show a light-mode macOS Clipboard history panel adopting a refined keyboard-first Launcher aesthetic, with a Launcher-style Actions palette open over the lower-right of the window.
Scene/backdrop: subtle cool gray macOS desktop wallpaper, no other windows, no menu bar
Style/medium: high-fidelity native macOS UI screenshot, restrained and precise
Composition/framing: landscape 3:2, centered floating 774×512-style panel, straight-on, generous margin
Base window: continuous 16px radius, translucent warm light-gray popover material, thin separator border, soft macOS shadow; 59px header with 20px search placeholder "Search clipboard history", "All Types" chip and gear; split content with 330px history list and a link preview; 39px footer
History: section "Today" with 48px rounded rows; selected link row "github.com/stevemurr/clipboard"; other rows for text, image and color; 24px rounded icons; selected fill is subtle 10% black
Right preview: label "Preview", a restrained rounded card showing "https://github.com/stevemurr/clipboard", and a compact metadata card showing Source Safari and Last copied 12 min ago
Footer: left Clipboard icon, right "Copy" with Return keycap, divider, then "Actions" with Command and K keycaps
Open action palette: overlays bottom-right just above footer; 360px wide translucent popover with 14px continuous radius, thin separator border, strong soft shadow; title "github.com/stevemurr/clipboard" in small secondary text; four 40px rows with small monochrome icons and right-aligned keycaps: selected "Copy to Clipboard" Return, "Open Link" Command-Return, "Quick Look" Command-Y, and red "Delete from History" Command-Delete; 9px selected row radius
Visual language: SF Pro, 13–16px content, quiet grayscale, very restrained blue icon accent, consistent 6px keycaps, exact Launcher-like density and hierarchy
Text (verbatim): "Search clipboard history"; "All Types"; "Today"; "Preview"; "Copy"; "Actions"; "github.com/stevemurr/clipboard"; "Copy to Clipboard"; "Open Link"; "Quick Look"; "Delete from History"
Constraints: sharp correctly spelled labels, action palette visibly distinct but visually related to base panel, no traffic-light controls, no logos, no watermark
Avoid: Raycast branding, browser chrome, neon, heavy gradients, excessive glass, giant icons, thick borders, mobile UI, illegible text
```
