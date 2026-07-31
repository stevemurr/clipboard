# Launcher aesthetic audit for Clipboard

## Summary

Launcher and Clipboard already share the right product archetype: both are
keyboard-first floating macOS utilities. The largest difference is not color;
it is hierarchy. Launcher uses a stronger command header, roomier result rows,
clear section rhythm, and a persistent action footer. Those choices make a
small utility feel calmer and more intentional.

The current recommended direction is the compact light text-selection mock:
`clipboard-launcher-light-v3-compact.png`. It responds directly to the rendered
Launcher reference by reducing component chrome, narrowing the history pane,
and tightening rows while retaining Clipboard’s history/preview split on one
shared surface. See `COMPACT_PASS.md` for the latest refinement.

## Visual comparison

| Element | Launcher standard | Current Clipboard | Proposed Clipboard |
| --- | --- | --- | --- |
| Window | 774×512, 16 pt continuous radius | 750×470, 14 pt radius | Adopt 774×512 and 16 pt radius |
| Material | Popover blur plus 84% adaptive surface | Regular material plus 50% window background | Use Launcher’s popover/surface stack |
| Light surface | RGB 240/240/242 | System-derived | Match Launcher token |
| Dark surface | RGB 27/27/29 | System-derived | Match Launcher token |
| Header | 59 pt, 20 pt medium search | Approximately 48 pt, 16 pt search | Adopt Launcher header |
| Sections | 36 pt, 13 pt semibold | 11 pt label with ad hoc padding | Adopt 36 pt rhythm |
| Results | 48 pt, 12 pt selection radius | Roughly 34 pt, 8 pt selection radius | Adopt Launcher row geometry |
| Selection | Primary at 10% opacity | Primary at 12% opacity | Use quieter 10% fill |
| Footer | 39 pt, persistent action model | Similar anatomy, looser keycaps | Standardize to Launcher footer |
| Keycaps | 23×22 minimum, 6 pt radius, 0.5 pt stroke | Smaller 18 pt minimum, 4 pt radius | Reuse Launcher keycap component |
| Overlays | 14 pt popover, 40 pt actions, deep soft shadow | No equivalent action palette | Optional extension |

## What should carry over

1. **The shell.** Reuse Launcher’s popover material, adaptive surface tokens,
   outer stroke, 16-point continuous corner, and shadow treatment.
2. **The command header.** Search should become the dominant control. The type
   filter can remain, but as a compact Launcher-like chip beside the hotkey and
   settings affordance.
3. **List density.** Clipboard rows benefit from Launcher’s 48-point target and
   24-point icon. Secondary source/time metadata can sit below the primary
   value without making the list feel busy.
4. **Section cadence.** Promote Today, Yesterday, and Results into true
   36-point section headers rather than small labels floating in list padding.
5. **The preview hierarchy.** Keep the split pane, but place text and metadata
   in the same restrained 12–13-point cards Launcher uses in Settings.
6. **The footer and keycaps.** Use one shared keycap visual and keep the primary
   Return action visually stronger than secondary actions.

## What should not be copied literally

- Clipboard should retain its split history/preview information architecture.
- Content previews need more visual area than Launcher result rows.
- The action-palette concept is useful, but Launcher’s Command-K binding
  conflicts with Clipboard’s current Command-K Quick Look binding. Treat the
  palette mock as a visual/interaction exploration until shortcuts are decided.
- Keep Clipboard’s content-type accents sparse. Launcher is primarily
  grayscale and becomes less elegant if every row receives a saturated badge.

## Suggested implementation order

1. Introduce shared surface, separator, keycap, and geometry tokens.
2. Update the panel shell, header, and footer.
3. Restyle section headers and history rows.
4. Restyle preview and information cards.
5. Validate both appearances with representative text, image, link, color, and
   file history.
6. Consider the action palette separately after resolving keyboard behavior.

## Artifacts

- `launcher-reference-light.png` — rendered Launcher reference captured from
  the current `../launcher` build
- `clipboard-launcher-light.png` — recommended light-mode Clipboard direction
- `clipboard-launcher-dark.png` — dark appearance with an image preview
- `clipboard-launcher-actions.png` — optional Launcher-style action palette
- `index.html` — editable, deterministic visual study containing all three
  states and the core design tokens
