# Modern: Modernize

The Modern tab of `/quiet setup`. Modernize reskins Blizzard's frames in place into a light, modern, dark look. Exact colours, sizes and frame names live in the code (`Theme`, the area files); this file holds the direction and the rules.

## Direction

- Graphite panels, not black: the window panel is lit slightly towards the top, insets sink a step below it.
- One gold mark per window: a thin accent hairline under the title band. Section headers are strips a step lighter than the panel with a short accent edge on the left.
- No boxes around things that do not need them. Items, buttons, breadcrumbs, money and counts stand bare on the panel. A border appears only where it carries meaning: item quality from uncommon up, a quest item, a debuff type, a target's rarity. The selected tab gets an accent line, not an accent border.
- Empty slots read as sockets, not holes; filled slots drop the socket.
- Controls are bare glyphs (cross, chevron, square, bar, plus / minus) in grey that turn light under the mouse; accent marks state (checked, selected, scrollable). Flat buttons, dropdowns and tabs show a faint light wash under the mouse.
- Dark parchment ink becomes light text of the same hue. Content art stays: talent trees, spell icons, character models, the map canvas.
- Icons are cropped square.

## Palette

Theme Dark (`Features/Modern/Theme.lua` is the source of truth; keep this table in step with it). Panels have background alpha 90 %; it cannot be changed.

| Key | RGB | Hex | Used for |
|---|---|---|---|
| `bg` | 0.075, 0.08, 0.09 | `#131417` | window and box panel (graphite, not black) |
| `strip` | 0.16, 0.165, 0.18 | `#292A2E` | title band and section strips |
| `tip` | 0.11, 0.115, 0.13, 0.95 | `#1C1D21` | tooltip fill |
| `well` | 0.13, 0.135, 0.15, 0.9 | `#212226` | empty slot socket |
| `wellEdge` | 0.22, 0.225, 0.24 | `#38393D` | socket edge, quiet rules, disabled controls |
| `track` | 0.02, 0.02, 0.03, 0.9 | `#050508` | bar tracks, fields, checkbox box |
| `sunk` | 0, 0, 0, 0.3 | — | darkening over an inset |
| `outline` | 0.22, 0.23, 0.25 | `#383B40` | window outer edge |
| `border` | 0.33, 0.33, 0.33 | `#545454` | thin borders, scroll thumb |
| `accent` | 0.95, 0.75, 0.25 | `#F2BF40` | the gold: title hairline, strip edge, selected tab, checked |
| `glyph` | 0.75, 0.75, 0.75 | `#BFBFBF` | bare control glyphs at rest |
| `text` | 0.9, 0.9, 0.9 | `#E6E6E6` | light ink on former parchment, glyphs under the mouse |
| `danger` | 0.85, 0.25, 0.20 | `#D94033` | close cross under the mouse, interrupted cast |

Area colours outside the theme: health bar near-black `#242629`, mana `#3373E6`, cast `#C79933`, channel cast `#409E4D`, uninterruptible cast `#8C8C8C`. Item quality, class and reaction colours are Blizzard's (`ITEM_QUALITY_COLORS`, `RAID_CLASS_COLORS`, `FACTION_BAR_COLORS`). Flat texture: `Interface\Buttons\WHITE8X8`.

## Settings

- Modernize is off unless checked (`modernize.enabled`). It is shared through presets; Reset default turns it off.
- While checked, the tab shows Theme and one checkbox per area; unchecked, they are hidden and keep their values. Nothing is stored until Save. A Save that changes what Modernize draws (on, off, theme or an area) while QuietUI is on reloads the UI instead of restyling in place, so every frame takes the full new look; a Save that changes nothing there does not.
- Theme: one theme today, Dark (`modernize.theme`; missing or unknown means Dark).
- Areas: one checkbox per registered area, in registration order; on unless unchecked (`modernize.<area key>`). Saving stores only values that differ from the defaults.
- The XP area heads its own section with Show on big XP gain (`modernize.xpGain`, on by default, disabled while the XP area is off): quest XP and any single gain of at least 5 % of the level show the XP bar for 5 s, even when the XP row is Only on hover; see [visible.md](visible.md).

## Rules

- An area is one file under `Features/Modern/Areas/` registered through `ns.Modern.Register{ key, label, apply, restore, events, onEvent, addons }`. A bad entry is reported once and skipped.
- Apply runs once per enabled area. Unchecking an area or Modernize restores only what changed. Changing theme or background restores and applies again (from Save this happens through the reload).
- Every change goes through the area's journal (`Skin`); restore undoes it in reverse, so one area never touches another's frames. `/quiet off` and Reset restore all areas in reverse order.
- An area's events reach its `onEvent` only while it is applied. `ADDON_LOADED` for a listed addon applies it again, so load-on-demand frames get skinned.
- Blizzard art is held at alpha 0 (also against `SetAlphaFromBoolean` and vertex alpha), never hidden. No `Hide()`, `Show()` or state drivers on bars or unit frames; fade rules keep owning alpha.
- Hooks use `hooksecurefunc` / `HookScript`, are set once and do nothing while the area is off. No script is replaced.
- Pooled rows and rebuilt pages are skinned again on the update that refills them. A window is also skinned again when it shows.
- Blizzard's shared templates (tabs, scroll bars, item buttons, three-piece buttons and input boxes, dropdowns, insets, dialog borders) are recognised by their keys, so a window file names only its own art.
- Protected regions and window points change only out of combat; a wanted point is applied when combat ends.
- Secret values (health, power, XP, unit identity) go straight to widgets and are never compared or used as keys.
- A missing or forbidden frame is skipped quietly; a missing method is reported once.

## Movable windows

Character, spellbook / talents, a standalone quest log, the combined bag and the map get a drag handle over their title. Dragging saves `windowPoints[key]` per character (not in presets; Reset default keeps it), and the point is put back on every show. No drag or point change in combat. Reset positions clears the saved points immediately, independently of Save, and returns windows to Blizzard's position (after combat if needed).

## Areas

Each area: what the player sees on apply. Restore puts back everything the journal recorded and hides QuietUI's own regions.

- **Action bars**: square icons on flat sockets with a thin border, outlined hotkey and count; bar end caps and slot art held. Own hover, pressed and checked feedback. Layout, size and bar alpha stay Blizzard's / Bars'.
- **Unit frames** (player, pet, target, target of target, focus, party, boss): each frame is one compact dark box with a near-black health bar and a thin power line; portraits and frame art held. Health value text centred and always shown (the `statusText` CVar is on while applied, the player's value comes back on restore); name and level above the box; target and focus show a class icon for players. Name in class or reaction colour. Target's box border shows elite, rare or boss. Raid frames and raid-style party frames become flat rectangles (their Edit Mode size) with sharp corners and a thin black edge: the unit frames' near-black health fill over a darker track (an offline member's fill is as dark as the track), a thin flat power line in Blizzard's power colour muted toward grey, the name in class colour, and the health percent centred on the fill (Blizzard's `raidFramesHealthText` CVar is `perc` while applied, its value comes back on restore); role, ready check, aura, dispel, aggro and selection marks stay. Nameplates are never touched. Health and power are never read.
- **Cast bars** (player, pet, target, focus, and the breath, fatigue and feign death timers): flat fill on a dark track with a crisp black edge, a soft top sheen and a thin light line at the fill's leading edge; outlined spell name and time inside it, a square spell icon as tall as the frame at its left; Blizzard's spark is held. The player's bar is longer and taller than Blizzard's. Colour by cast type (cast, channel, uninterruptible, interrupted). Nameplate cast bars stay Blizzard's.
- **Windows**: character (equipment, stats, reputation, skills, currency, statistics), spellbook, talents, professions, auction house, merchant, loot, bags, NPC quest, gossip and item text, mail, friends (with raid and ignore list), guild and communities, group finder (listing, browse, who), trainer, trade, bank, taxi and flight map, macros, inspect, dressing room, tabard, petition, guild registrar, stable, addon list, clock, progress legacy, game menu, static popups, raid manager, ready check, stack split, colour picker and loot rolls; the settings panel gets the window, its buttons, search box and scroll bars, and in its list only checkboxes and value sliders (a thin dark track filled in accent up to a flat knob, bare chevron steppers, grey while disabled). Graphite panel, title band with the gold hairline, flat close / maximize glyphs, dark tabs with a thin border, the selected one marked by an accent line on its top edge, section strips for headers, flat fields for inputs and buttons, flat checkboxes, accent scroll arrows and expand signs. Item slots get the socket treatment with a quality border from uncommon up. Talents: the ornate backdrop, frames, dividers and spec rings go, the tree art stays inside a quiet edge; tree titles get a thin rule, the trees quiet lines between them, and each talent a thin border in its state colour (maxed accent, partly spent green, locked quiet); the Primary / Secondary tabs have no border and the search box is narrower. Professions: the side tabs are small square icon tabs like the character window's; overview cards and spell icons stand bare on the panel, primary cards parted by a quiet rule, skill bars on a borderless dark track under the fill, unlearn a bare cross like the close button; recipe categories become section strips. Auction house: the category list, result lists, sell form and item display stand bare on the panel without borders; a result row keeps its cropped icon beside the name, without a slot field. Light ink and a readable font (Arial Narrow, with Central European letters) on quest, gossip, book, letter and petition text. Quest and gossip text stands on the panel, without a sunken inset box. Group finder results stand bare with a quiet hover and Blizzard's selection, their groupings (Groups, Players) become section strips with an accent plus / minus. Mail rows stand bare inside the window, without an inner box or rules, the inbox pages turn with bare chevrons, and on the send page the money stands as text and the coin inputs are dark fields without a border; list rows stand bare with a quiet rule or their hover; a mail attachment is framed in its quality colour. Dialog titles sit in the header band; popups and loot rolls have no title and no band. Maps (taxi, flight map canvas), models, emblems, role and class icons stay.
- **Map**: the same window chrome on `WorldMapFrame`; breadcrumb, tracking buttons and the quest log inside it stand bare on the panel, zone headers become section strips, quest details get light ink. The canvas stays.
- **Quest tracker**: the All Objectives header and each module header (Quests, Campaign, …) become section strips; their minimize buttons become accent plus / minus signs. Quest blocks, POI buttons, text and the tracker's place stay Blizzard's.
- **Minimap**: square map with a thin border under a header band (zone name centred, tracking at the left end, a calendar page with today's day at the right). Addon compartment and clock on the row under the map; round addon buttons (QuietUI's, LibDBIcon) become flat plates 14 px inside the edge. Ring art and zoom buttons held; wheel zoom stays. `GetMinimapShape()` returns `SQUARE` while applied. The minimap, LFG eye, mail and tracking are never hidden or faded.
- **Tooltips**: borderless grey fill with an accent edge on top, coloured by item quality from uncommon up; player names in class colour; the unit health bar held; the chat item tooltip's close button is the windows' thin cross. The queue status panel and the friends tooltip take the same look. Never replaces scripts or touches `OnTooltipSetItem`. The target frame's aura tooltip cannot be reached and keeps Blizzard's look.
- **Damage meter**: themed panel and title band, bare header glyphs, flat rows in the class colour, square spec icons. Values never read; alpha stays with the meter fade rule.
- **Buffs and debuffs**: square icons with a thin border, debuffs bordered in their dispel colour, outlined duration. Layout, size and fades stay.
- **XP and reputation**: own segmented XP bar with rested XP and a thin watched-reputation bar above it, inside Blizzard's container so fades still apply. Gains ease in with a short flash and sparks; soft bubbles drift in the fill. Animation runs only while needed.
