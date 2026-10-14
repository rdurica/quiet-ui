# Modern: Modernize

The Modern tab of `/quiet setup`. Modernize gives Blizzard's windows and frames a quiet dark look by skinning them in place. Skins change textures, colours, TexCoords, points of windows and their own child regions; fade rules (bars, player frame, XP bar, auras, party) stay alpha-only and are untouched, and a skin never hides a frame with `Hide()`, `Show()` or a state driver.

Modernize skins action bars, unit frames, windows, map, minimap, tooltips, auras and XP/reputation. Each area can be enabled independently. Client frame variants are resolved at run time; missing parts are skipped. The actual look and client compatibility are checked in game.

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

## Action bars

Apply: square-crop standard, multibar, pet, stance and gamepad action icons, replace button art with flat theme textures, add a thin border and outline hotkey/count text. Hold Blizzard bar decorations and slot art hidden. Keep button size, Edit Mode layout, bar alpha and combat behavior. Late gamepad loading receives the same skin through `ADDON_LOADED`.

Restore: release held art and restore button textures, crops, fonts and colours; hide reusable own regions. The Bars feature exposes its buttons through `ns.Bars.Buttons()`.

## Unit frames

Apply: skin player, pet, target, target of target and focus in place. Hold frame art hidden, theme health/power bar textures, and add their backgrounds and borders. Use the standard 2D portrait with square crop; remove supported portrait masks. Portrait borders are gold for elite, silver for rare/rareelite, red for bosses and themed otherwise. If the portrait source is itself round, retain it inside the square border for later in-game tuning. Player health colours follow class colours; NPC health follows reaction colours, reapplied after Blizzard changes them. Class colours off keeps Blizzard colours. Never read health or power values. Keep frame points, size and every existing fade rule.

Restore: restore textures, crops, masks and colours, release held art and hide own regions. Colour hooks stop applying when the area is off.

## Windows and parchment

Apply: dark chrome for character tabs/subpanels, spellbook, talents, quest log and bags. Resolve classic/newer spellbook and talent names, `QuestLogFrame`/`QuestMapFrame`, and combined or separate bags at run time. Keep talent-tree, spellbook-page and character-model content art. Bag icons are cropped square and quality colours remain on flat borders; bags retain Blizzard stacking. Character, spellbook, talents and quest log have title drag handles and saved positions; load-on-demand windows are skinned when loaded.

NPC quest, gossip and item text use the parchment behavior from branch 008: warm torn parchment extending 12 px past the frame, dark-ink title two pixels larger, flat red primary/grey secondary buttons in a bottom band, a small close cross and scroll content lifted above the band. Blizzard text, objectives, rewards and scripts stay. Reapply on show and relevant quest/gossip/item-text events.

Restore: restore exact chrome, points, fonts, colours, crops, scroll anchors and button geometry; release holds and drag handles. Original window points return out of combat, or on combat end even after QuietUI is off. Saved positions remain.

## Map

Apply: dark chrome and a title drag handle on `WorldMapFrame`. Reopen at the saved character position; no point change or drag begins during combat.

Restore: original chrome and Blizzard position, immediately out of combat or deferred until combat ends. Saved positions remain.

## Minimap

Apply: square mask, thin theme border and flat zone text strip. Hold the ring, decorations and zoom buttons hidden; disable zoom-button clicks and enable mouse-wheel zoom. The minimap, LFG eye, mail and tracking remain visible and usable. `GetMinimapShape()` returns `SQUARE`; the setup button projects onto the square edge.

Restore: exact original mask (round fallback when unreadable), shape function or nil, wheel script/enabled state, zoom-button mouse state and art alpha. The setup button returns to its circular placement. Hide own strip and border.

## Tooltips

Apply: themed background and border on GameTooltip, item-reference and shopping tooltips, with NineSlice/backdrop compatibility. An item border follows item quality and a unit health bar uses the theme texture. No health values are read.

Restore: original backdrop, border colours and health-bar texture; release chrome holds and hide own regions. Tooltip update hooks remain inert while off.

## Buffs and debuffs

Apply: square-crop buff, debuff and temporary-enchant icons, add thin borders (debuff dispel colour), and outline duration text beneath each icon. Keep aura fades and button size/layout.

Restore: original crops, duration font/anchors and art, hiding own borders. Updates stop skinning while the area is off.

## XP and reputation

Apply: own 6 px XP bar with rested overlay and a 4 px watched-reputation bar 2 px above it, parented to Blizzard's status container so existing fades still apply. Hold stock art hidden, keeping Blizzard mouse behavior and text. XP, exhaustion, level and faction events refresh the values. Ordinary gains interpolate over 0.4 s and play a short end glow; secret values go directly to widgets without arithmetic or comparison. Per-frame animation runs only while a gain is active.

Restore: stop animation, hide reusable own visuals and restore stock art. Container alpha and points remain owned by Blizzard and Faders.

## Reset positions

While Modernize is checked, Reset positions clears character `windowPoints` immediately, independently of Save, and restores tracked original window positions. It stops dragging and waits for combat end before positioning when necessary, including after `/quiet off`. Other settings remain. This explicit action differs from Reset default, which preserves saved positions.
