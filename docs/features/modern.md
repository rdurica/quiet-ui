# Modern: Modernize

The Modern tab of `/quiet setup`. Modernize reskins Blizzard's frames in place into a light, modern, dark look. Exact colours, sizes and frame names live in the code (`Theme`, the area files); this file holds the direction and the rules.

## Direction

- Graphite panels, not black: the window panel is lit slightly towards the top, insets sink a step below it.
- One gold mark per window: a thin accent hairline under the title band. Section headers are strips a step lighter than the panel with a short accent edge on the left.
- No boxes around things that do not need them. Items, buttons, breadcrumbs, money and counts stand bare on the panel. A border appears only where it carries meaning: item quality from uncommon up, a quest item, the selected tab, a debuff type, a target's rarity.
- Empty slots read as sockets, not holes; filled slots drop the socket.
- Controls are bare glyphs (cross, chevron, square, bar, plus / minus) in grey that turn light under the mouse; accent marks state (checked, selected, scrollable).
- Dark parchment ink becomes light text of the same hue. Content art stays: talent trees, spell icons, character models, the map canvas.
- Icons are cropped square.

## Palette

Theme Dark (`Features/Modern/Theme.lua` is the source of truth; keep this table in step with it). Panels take the Background setting as alpha.

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
| `accent` | 0.95, 0.75, 0.25 | `#F2BF40` | the gold: title hairline, strip edge, selected tab, checked, cast bar |
| `glyph` | 0.75, 0.75, 0.75 | `#BFBFBF` | bare control glyphs at rest |
| `text` | 0.9, 0.9, 0.9 | `#E6E6E6` | light ink on former parchment, glyphs under the mouse |
| `danger` | 0.85, 0.25, 0.20 | `#D94033` | close cross under the mouse, interrupted cast |

Area colours outside the theme: health bar near-black `#242629`, mana `#3373E6`, channel cast `#4DBF59`, uninterruptible cast `#8C8C8C`. Item quality, class and reaction colours are Blizzard's (`ITEM_QUALITY_COLORS`, `RAID_CLASS_COLORS`, `FACTION_BAR_COLORS`). Flat texture: `Interface\Buttons\WHITE8X8`.

## Settings

- Modernize is off unless checked (`modernize.enabled`). It is shared through presets; Reset default turns it off.
- While checked, the tab shows Theme, Background, Class colours and one checkbox per area; unchecked, they are hidden and keep their values. Nothing is stored until Save.
- Theme: one theme today, Dark (`modernize.theme`; missing or unknown means Dark).
- Background: panel background alpha 50, 75 or 90 % (`modernize.opacity`; anything else means 75).
- Class colours: on unless unchecked (`modernize.classColors`).
- Areas: one checkbox per registered area, in registration order; on unless unchecked (`modernize.<area key>`). Saving stores only values that differ from the defaults.
- The XP area heads its own section with Show on big XP gain (`modernize.xpGain`, on by default, disabled while the XP area is off): quest XP and any single gain of at least 5 % of the level show the XP bar for 5 s, even when the XP row is Only on hover; see [visible.md](visible.md).

## Rules

- An area is one file under `Features/Modern/Areas/` registered through `ns.Modern.Register{ key, label, apply, restore, events, onEvent, addons }`. A bad entry is reported once and skipped.
- Apply runs once per enabled area. Unchecking an area or Modernize restores only what changed. Changing theme, background or class colours restores and applies again.
- Every change goes through the area's journal (`Skin`); restore undoes it in reverse, so one area never touches another's frames. `/quiet off` and Reset restore all areas in reverse order.
- An area's events reach its `onEvent` only while it is applied. `ADDON_LOADED` for a listed addon applies it again, so load-on-demand frames get skinned.
- Blizzard art is held at alpha 0 (also against `SetAlphaFromBoolean` and vertex alpha), never hidden. No `Hide()`, `Show()` or state drivers on bars or unit frames; fade rules keep owning alpha.
- Hooks use `hooksecurefunc` / `HookScript`, are set once and do nothing while the area is off. No script is replaced.
- Pooled rows and rebuilt pages are skinned again on the update that refills them.
- Protected regions and window points change only out of combat; a wanted point is applied when combat ends.
- Secret values (health, power, XP, unit identity) go straight to widgets and are never compared or used as keys.
- A missing or forbidden frame is skipped quietly; a missing method is reported once.

## Movable windows

Character, spellbook / talents, a standalone quest log, the combined bag and the map get a drag handle over their title. Dragging saves `windowPoints[key]` per character (not in presets; Reset default keeps it), and the point is put back on every show. No drag or point change in combat. Reset positions clears the saved points immediately, independently of Save, and returns windows to Blizzard's position (after combat if needed).

## Areas

Each area: what the player sees on apply. Restore puts back everything the journal recorded and hides QuietUI's own regions.

- **Action bars**: square icons on flat sockets with a thin border, outlined hotkey and count; bar end caps and slot art held. Own hover, pressed and checked feedback. Layout, size and bar alpha stay Blizzard's / Bars'.
- **Unit frames** (player, pet, target, target of target, focus): each frame is one compact dark box with a near-black health bar and a thin power line; portraits and frame art held. Health value text centred; name and level above the box; target and focus show a class icon for players. Name in class or reaction colour when Class colours is on. Target's box border shows elite, rare or boss. Health and power are never read.
- **Cast bars** (player, pet, target, focus): flat bar with a thin border, spell name and time inside it, a square spell icon at its left. Colour by cast type (cast, channel, uninterruptible, interrupted). Nameplate cast bars stay Blizzard's.
- **Windows**: character (equipment, stats, reputation, skills, currency, statistics), spellbook, talents, professions, auction house, merchant, loot, bags, NPC quest, gossip and item text. Graphite panel, title band with the gold hairline, flat close / maximize glyphs, dark tabs with an accent on the selected one, section strips for headers, flat fields for inputs and buttons, flat checkboxes, accent scroll arrows and expand signs. Item slots get the socket treatment with a quality border from uncommon up. Light ink and a readable font (Arial Narrow, with Central European letters) on quest, gossip and book text.
- **Map**: the same window chrome on `WorldMapFrame`; breadcrumb, tracking buttons and the quest log inside it stand bare on the panel, zone headers become section strips, quest details get light ink. The canvas stays.
- **Minimap**: square map with a thin border under a header band (zone name centred, tracking at the left end, a calendar page with today's day at the right). Addon compartment and clock on the row under the map; round addon buttons (QuietUI's, LibDBIcon) become flat plates 14 px inside the edge. Ring art and zoom buttons held; wheel zoom stays. `GetMinimapShape()` returns `SQUARE` while applied. The minimap, LFG eye, mail and tracking are never hidden or faded.
- **Tooltips**: borderless grey fill with an accent edge on top, coloured by item quality from uncommon up; player names in class colour; the unit health bar held. Never replaces scripts or touches `OnTooltipSetItem`. The target frame's aura tooltip cannot be reached and keeps Blizzard's look.
- **Damage meter**: themed panel and title band, bare header glyphs, flat rows in the class colour, square spec icons. Values never read; alpha stays with the meter fade rule.
- **Buffs and debuffs**: square icons with a thin border, debuffs bordered in their dispel colour, outlined duration. Layout, size and fades stay.
- **XP and reputation**: own segmented XP bar with rested XP and a thin watched-reputation bar above it, inside Blizzard's container so fades still apply. Gains ease in with a short flash and sparks; soft bubbles drift in the fill. Animation runs only while needed.
