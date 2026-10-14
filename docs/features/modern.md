# Modern: Modernize

The Modern tab of `/quiet setup`. Modernize gives Blizzard's windows and frames a quiet dark look by skinning them in place. Skins change textures, colours, TexCoords, points of windows and their own child regions; fade rules (bars, player frame, XP bar, auras, party) stay alpha-only and are untouched, and a skin never hides a frame with `Hide()`, `Show()` or a state driver.

This file describes the foundation. The areas themselves are added in later commits, each with its own section below; until then the area list is empty.

## Settings

- Modernize is off unless the Modern tab checks it (`modernize.enabled`; missing means off). It is shared through presets and Reset default turns it off.
- While Modernize is checked the tab shows Theme, Background, Class colours and one checkbox per area. Unchecked, those options are hidden and keep their values. Nothing is stored until Save; closing the window discards the draft.
- Theme steps through the known themes. Today there is one: Dark (`modernize.theme`; missing or an unknown name means Dark).
- Background is the background alpha of skinned panels: 50, 75 or 90 percent (`modernize.opacity`; missing or any other value means 75). The stepper stops at both ends.
- Class colours is on unless unchecked (`modernize.classColors`; `false` turns it off). Areas that tint with the class colour read it.
- Area checkboxes follow the area registry in registration order, with each area's English label. An area is on unless unchecked (`modernize.<area key>`; `false` turns that area off). Saving stores only values that differ from the defaults.

## Theme

`dark` is background `0.05, 0.05, 0.05` with the chosen background alpha, border `0.85, 0.85, 0.85, 0.35`, accent `0.95, 0.75, 0.25` and the flat bar texture `Interface\Buttons\WHITE8X8`. A theme is one entry of data; `ns.Modern.Theme()` returns a copy of the active theme with the background alpha applied.

## Areas

An area is one file under `Features/Modern/Areas/` that calls `ns.Modern.Register{ key, label, apply, restore, events, onEvent, addons }`. A bad entry (missing key, label or apply, a reserved or duplicate key) is reported once and skipped.

- Apply: when Modernize and the area are on, `apply` runs once per area. Unchecking an area, or Modernize, restores only what changed. Changing the theme, background or class colours restores and applies the applied areas again.
- Restore: `/quiet off` or Reset restores every applied area in reverse registration order. Each area has a journal (`skin`) of what it changed; restore undoes it in reverse, so one area never touches another's frames, and held art alpha is released.
- Events: the events an area lists reach its `onEvent` only while the area is applied. Each event is registered on its own and a client that does not know it is skipped. `ADDON_LOADED` for an addon the area lists runs its `apply` again, so load-on-demand frames get skinned.
- Skin helpers: `Icon` (crop `0.08, 0.92, 0.08, 0.92`), `Border` and `Panel` (own regions, hidden on undo and reused), `Button` (flat fill, original art held hidden), `Hold` (art held at alpha 0 against Blizzard through the alpha hook), and `Set` (any other `SetX` with its previous `GetX` value). A missing frame is skipped; a missing method is reported once.

## Movable windows

`ns.Modern.MakeMovable(frame, key)` adds an invisible drag handle over the top strip of a window. Dragging saves `windowPoints[key]` as `{ point, relativePoint, x, y }` relative to `UIParent` in the character settings (not in presets; Reset default keeps it). The saved point is put back on every show and after Blizzard positions its panels. In combat no point is set, no drag starts, and the wanted point is applied when combat ends. A window without a saved point keeps Blizzard's position. `ns.Modern.ReleaseMovable(frame)` stops the handle and returns to Blizzard's position; saved points are kept.
