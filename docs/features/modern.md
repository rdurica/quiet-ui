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

`dark` is background `0.05, 0.05, 0.05` with the chosen background alpha, opaque border `0.33, 0.33, 0.33, 1` (a translucent one is tinted by the world behind a translucent fill), accent `0.95, 0.75, 0.25` and the flat bar texture `Interface\Buttons\WHITE8X8`. A theme is one entry of data; `ns.Modern.Theme()` returns a copy of the active theme with the background alpha applied.

## Areas

An area is one file under `Features/Modern/Areas/` that calls `ns.Modern.Register{ key, label, apply, restore, events, onEvent, addons }`. A bad entry (missing key, label or apply, a reserved or duplicate key) is reported once and skipped.

- Apply: when Modernize and the area are on, `apply` runs once per area. Unchecking an area, or Modernize, restores only what changed. Changing the theme, background or class colours restores and applies the applied areas again.
- Restore: `/quiet off` or Reset restores every applied area in reverse registration order. Each area has a journal (`skin`) of what it changed; restore undoes it in reverse, so one area never touches another's frames, and held art alpha is released.
- Events: the events an area lists reach its `onEvent` only while the area is applied. Each event is registered on its own and a client that does not know it is skipped. `ADDON_LOADED` for an addon the area lists runs its `apply` again, so load-on-demand frames get skinned.
- Skin helpers: `Icon` (crop `0.08, 0.92, 0.08, 0.92`), `Border` and `Panel` (own regions, hidden on undo and reused), `Button` (flat fill, original art held hidden), `Hold` (art held at alpha 0, or a given alpha, against Blizzard through the alpha hook), and `Set` (any other `SetX` with its previous `GetX` value). A missing frame is skipped; a missing method is reported once.

## Movable windows

`ns.Modern.MakeMovable(frame, key)` adds an invisible drag handle over the top strip of a window. Dragging saves `windowPoints[key]` as `{ point, relativePoint, x, y }` relative to `UIParent` in the character settings (not in presets; Reset default keeps it). The saved point is put back on every show and after Blizzard positions its panels. In combat no point is set, no drag starts, and the wanted point is applied when combat ends. A window without a saved point keeps Blizzard's position. `ns.Modern.ReleaseMovable(frame)` stops the handle and returns to Blizzard's position; saved points are kept. The window's scripts are never replaced: one `HookScript("OnShow")` per window re-applies the saved point and does nothing once released; Reset positions re-anchors only windows that are still movable.

## Action bars

Apply: square-crop standard, multibar, pet, stance and gamepad action icons, replace button art with flat theme textures, add a thin border and outline hotkey/count text. Hold Blizzard bar decorations and slot art hidden: on 12.0 the `MainActionBar` `BorderArt` and the `EndCaps` (`LeftEndCap`, `RightEndCap`; the classic `MainMenuBar` textures as fallback), and per button `SlotArt`, `SlotBackground`, `NormalTexture` and `Border`. The 12.0 `IconMask` is taken off the icon so the square crop is not clipped. Keep the icon crop, button size, Edit Mode layout, bar alpha and combat behavior. Late gamepad loading receives the same skin through `ADDON_LOADED`.

State feedback: because Blizzard's hover, pressed and checked textures are held hidden, each button gets its own flat theme-coloured regions over the icon: a light hover region in the `HIGHLIGHT` layer, a dark one while pressed (`SetButtonState("PUSHED")` or mouse down) and an accent one while checked (`SetChecked`). They follow Blizzard through `hooksecurefunc` on `SetButtonState` and `SetChecked` and `HookScript` on `OnMouseDown` / `OnMouseUp`; no script is replaced, no field is written on the secure button, and nothing is shown or hidden on a bar.

Restore: release held art and restore button textures, crops, icon masks, fonts and colours; hide reusable own regions (including the state feedback). The hooks stay but do nothing while the area is off. The Bars feature exposes its buttons through `ns.Bars.Buttons()`.

## Unit frames

Apply: skin player, pet, target, target of target and focus in place. The retail 12.0 structure (`PlayerFrameContainer`, `TargetFrameContainer`, their content parts, `PetFrame` globals) is resolved at run time with the older flat names as fallbacks; missing or forbidden parts are skipped quietly.
- Frame art (frame texture, alternate power and vehicle textures, combat flash, resting glow `StatusTexture`, boss portrait frame, reputation colour strip) is held at alpha 0 against Blizzard's `SetAlpha`.
- Health and power bars get the theme flat texture, a themed background and a 1 px border. Blizzard retexturing a bar (`SetStatusBarTexture`) puts the theme texture back.
- Health colour: player units use their class colour and NPCs their reaction colour (class colours on); class colours off, or a secret `UnitIsPlayer` / `UnitClass` / `UnitReaction` result (never used as a branch or table key), give a flat green, because the flat texture would otherwise be white. The colour is reapplied after every Blizzard `SetStatusBarColor` / `SetStatusBarTexture` and on target and focus changes and on faction and classification events for the skinned units (events for nameplates or party members do no work).
- Power colour follows the power type (`PowerBarColor`) and is reapplied after `UnitFrameManaBar_UpdateType` (hooked with `hooksecurefunc`, no script replacement).
- No portraits: Blizzard's portrait is held at alpha 0 in place (points and size unchanged). The target's health bar border carries its rarity: gold for elite, silver for rare/rareelite, red for bosses; every other border is themed.
- The bars take the portrait's space. Where the frame has a level text (player, target, focus), a square box as tall as health top to power bottom sits at the portrait's outer edge (left for player, right for target and focus) with a theme fill and border; the level text and the target's high-level skull are centred in it, and the textures anchored to the level text (its ring art) are held at alpha 0. The name of those frames is left-aligned 2 px above the health bar's left edge. Health and power bars keep their inner edge and reach to 2 px from the box, or to the portrait's outer edge for pet and target of target. Each rect is read once per apply, before anything moves, so laying out again gives the same points; a Blizzard `SetPoint` / `SetAllPoints` on a laid-out bar or text (target classification, vehicle art) is answered by putting the layout back (hooked with `hooksecurefunc`). The bar fill's fixed-size mask is removed, and the value texts (`TextString`, `LeftText`, `RightText`) are anchored to the bar: centre, left +2 px, right -2 px. A region the client reports as protected is not moved in combat; combat end lays it out.
- Health and power values are never read. The unit frames' own points, size and every existing fade rule stay.

Restore: restore bar textures, colours, masks and points, the value text, name (and its justification), level text and skull points, release held art (portraits and level ring included) and hide own regions. The hooks stay installed but do nothing while the area is off.

## Windows and parchment

Apply: dark chrome for character tabs and sub-panels (12.0 `ReputationFrame` and `TokenFrame`; the classic `CharacterFrameReputationFrame` and `CharacterFrameCurrencyFrame` as fallback), spellbook, talents, quest log and bags. Resolve classic/newer spellbook and talent names, a standalone `QuestLogFrame`, and combined or separate bags at run time; absent ones are skipped silently. The 12.0 chrome (`PortraitFrameTemplate` / `ButtonFrameTemplate`: `NineSlice`, `Bg`, `TopTileStreaks`, the portrait in `PortraitContainer`, and the nested `Inset` with its own `NineSlice` and `Bg`, plus `CharacterFrame.InsetRight` of the stats pane) is held at alpha 0 through the skin journal, so Blizzard repainting it changes nothing; the title, close button and content stay. Panel tab art (`Left`/`Middle`/`Right` and the `Active` and `Disabled` variants, also on the spellbook `TabSystem`) is held and replaced by a dark fill with a thin border; the selected tab, shown by Blizzard through its `Active` art, gets the accent border. Keep talent-tree, spellbook-page and character-model content art. On 12.0 the quest log lives inside the world map and is covered by the Map area; `QuestMapFrame` is never made movable, panelled or saved separately. The spellbook and talents window (`PlayerSpellsFrame`) is skinned after `Blizzard_PlayerSpells` loads.

Bags: items come from `EnumerateValidItems()` / `Items` of `ContainerFrameN` and `ContainerFrameCombinedBags`. Item icons (`icon`) are cropped square, Blizzard's `IconBorder` is held hidden, and a flat 1 px border takes the quality colour that Blizzard sets on `IconBorder` (`SetItemButtonQuality`: shown and coloured per item) and returns to the theme border when the quality goes. The border follows `IconBorder` through hooks that do nothing while the area is off. Bags opened or refilled later (`BAG_UPDATE_DELAYED`, `UpdateItems`) are skinned too. Bags retain Blizzard stacking. Character, spellbook, talents and a standalone quest log have title drag handles and saved positions; load-on-demand windows are skinned when loaded.

NPC quest, gossip and item text use the parchment behavior from branch 008: warm torn parchment extending 12 px past the frame, dark-ink title two pixels larger, flat red primary/grey secondary buttons in a bottom band, a small close cross and scroll content lifted above the band. Blizzard text, objectives, rewards and scripts stay: no script is replaced, each frame script is hooked once with `HookScript` and the hooks do nothing while the area is off. Blizzard art on these windows (chrome, button textures, scroll bar tracks) is held at alpha 0 only through the Windows skin journal (`Skin:Hold`, the shared alpha hold): one hold and one `SetAlpha` hook per texture, no parchment-owned hold. Restore returns the alpha the texture had when it was first held; a secret alpha is never read or compared, and a repeated apply does not stack holds. Reapply on show and relevant quest/gossip/item-text events.

Restore: restore exact chrome, tab and item art, icon crops, `IconBorder`, points, fonts, colours, scroll anchors and button geometry; hide own borders and fills; release holds and drag handles. Original window points return out of combat, or on combat end even after QuietUI is off. Saved positions remain.

## Map

Apply: dark panel and border on `WorldMapFrame`, a title drag handle, and the 12.0 chrome held hidden: the map frame's own chrome and `BorderFrame` (`NineSlice`, `Bg`, `TopTileStreaks`, portrait, `Inset`, `InsetBorderTop`). The canvas (`ScrollContainer`), the blackout, the title and the quest log inside the map (`QuestMapFrame`) stay untouched. Reopen at the saved character position; no point change or drag begins during combat.

Restore: original chrome and Blizzard position, immediately out of combat or deferred until combat ends. Saved positions remain.

## Minimap

Apply: square mask, thin theme border and flat zone text strip. Hold the ring art hidden: `MinimapCluster.BorderTop` and `MinimapCompassTexture` on 12.0 (older clients: `MinimapBorder`, `MinimapNorthTag`). The zoom buttons (`Minimap.ZoomIn`, `ZoomOut`, `ZoomHitArea`, or the older `MinimapZoomIn` / `MinimapZoomOut`) are held at alpha 0 and cannot be clicked, even when Blizzard shows them on mouse over. Mouse-wheel zoom stays Blizzard's own; only a minimap without a wheel script gets a wheel handler. The minimap, queue button (LFG eye), mail, tracking and the expansion landing page button remain visible and usable and are never faded. `GetMinimapShape()` returns `SQUARE`; the setup button projects onto the square edge. A missing or forbidden part is skipped.

Restore: exact original mask (the round `Textures\MinimapMask` when the client cannot read it), shape function or nil, wheel script/enabled state when it was changed, zoom-button mouse state and art alpha. The setup button returns to its circular placement. Hide own strip and border.

## Tooltips

Apply: themed background and a 1 px border on GameTooltip, item-reference and shopping tooltips. A tooltip with a `NineSlice` (all 12.0 tooltips) has that art held at alpha 0 and gets own regions; an older backdrop tooltip keeps `SetBackdropColor` / `SetBackdropBorderColor`. The unit health bar uses the theme texture; health values are never read. The border of an item follows its quality colour (`ITEM_QUALITY_COLORS`) and returns to the theme border when the tooltip is shown with anything else. Limit: the aura tooltip of the target frame (WoW Forever beta) lives in a frame that `EnumerateFrames` does not return and whose text no scan finds, so addons cannot reach it; it keeps Blizzard's border.

Scripts are never replaced on a `NineSlice` tooltip and `OnTooltipSetItem` is never touched (it throws on 12.0). The quality comes from one `TooltipDataProcessor.AddTooltipPostCall` for items, registered once when the addon loads, and a `Show` hook. Both do nothing while the area is off and ignore a tooltip the area did not skin. An old backdrop tooltip without a `NineSlice` gets exactly one `HookScript("OnShow")` for the session (a repeated apply adds none) that repaints the quality border while the area is on and does nothing once it is off. `SetScript` is never called on any tooltip and Blizzard's own `OnShow` keeps running.

Restore: original backdrop and border colours (old tooltips) and health-bar texture; release the held `NineSlice`, hide own regions. The hooks stay but do nothing while off (no script is restored, none was replaced).

## Buffs and debuffs

Apply: square-crop the icons of the buttons in `BuffFrame.auraFrames` and `DebuffFrame.auraFrames` (temporary enchants are among them), add a thin border around the icon and outline the duration text beneath it. Older clients are found through `BuffButtonN`, `DebuffButtonN`, `TempEnchantN` and the children of the frames. Private aura anchors (`isAuraAnchor`) and forbidden or incomplete buttons are skipped. A debuff border takes the dispel colour of `button.buttonInfo.debuffType` from `AuraUtil.GetAuraBorderColor` (`DebuffTypeColor` on older clients, red for a debuff without a type); every other aura gets the theme border. Blizzard's `DebuffBorder` and `TempEnchantBorder` art is held at alpha 0. Aura fades, frame alpha, button size and layout stay and the frames are never shown or hidden.

New buttons and changed dispel types are skinned again after Blizzard's `UpdateAuraButtons` (hooked with `hooksecurefunc`) and on the player's `UNIT_AURA`. `UNIT_AURA` for any other unit does no work.

Restore: original crops, duration font and anchors, border art; own borders are hidden. The hooks stay but skin nothing while the area is off.

## XP and reputation

Apply: own 6 px XP bar and a 4 px watched-reputation bar 2 px above it, parented to Blizzard's status container (so existing fades still apply, and the bars never set their own alpha). Rested XP is a lighter bar one frame level behind the XP fill covering the XP value up to `min(xp + exhaustion, maximum)`. Reputation reads `C_Reputation.GetWatchedFactionData()` (`GetWatchedFactionInfo()` on older clients) with `currentReactionThreshold`, `nextReactionThreshold` and `currentStanding`; nothing watched (no data, or `factionID` 0) hides the bar until a faction is watched. Blizzard's bar art is held at alpha 0: the container's `BarFrameTexture` and textures, and for each tracking bar the `StatusBar` `Background`, `Underlay`, `Overlay` and fill, looked at again on every refresh because Blizzard swaps tracking bars. Blizzard's mouse behavior and text stay.

XP, exhaustion, level and faction events refresh the values. Ordinary gains interpolate over 0.4 s and play a short end glow, and the rested bar follows at once; a lower value (level up) is set directly, and a new maximum applies even while a gain is animating. Secret values go directly to widgets; a secret XP, maximum or exhaustion skips the rested math and is never added or compared. Per-frame animation runs only while a gain is active and is removed afterwards.

Restore: stop animation, hide reusable own bars and release the stock art. Container alpha and points remain owned by Blizzard and Faders.

## Reset positions

While Modernize is checked, Reset positions clears character `windowPoints` immediately, independently of Save, and restores tracked original window positions. It stops dragging and waits for combat end before positioning when necessary, including after `/quiet off`. A window that is hidden when combat ends also gets Blizzard's point back, so it does not open displaced. Other settings remain. This explicit action differs from Reset default, which preserves saved positions.
