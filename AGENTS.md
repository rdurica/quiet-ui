# QuietUI

Opinionated UI for WoW Forever. Modern and quiet: few frames, few buttons, text stays. The addon turns on or off, and one window chooses what stays visible.

## Principles

- Clean UI with minimal settings. Full functionality, minimal UI.
- Works out of the box after install. Defaults must be right; settings exist only for small tweaks.
- Not a configurable framework: no sliders, no libraries like Ace3.
- Player-facing text (chat, tooltip) is English.

## Behavior

The behavior spec lives in `docs/features/` (index: `docs/features/README.md`), one file per `/quiet setup` tab. Read the relevant file before changing behavior and update it in the same commit. `README.md` is for players and links there.

## Client

- WoW Forever beta, `Interface: 16001`. The API mixes classic and newer frames; a global may not exist.
- The main bar is `MainActionBar`, not `MainMenuBar`. In gamepad mode the bars live under `GamepadMainActionBarFrame` (load-on-demand `Blizzard_GamepadActionBars`). The damage meter is a Blizzard load-on-demand addon; its frames are found by the `DamageMeter` prefix. The cooldown manager is `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`. The personal resource bar is `PersonalResourceDisplayFrame`; do not fade nameplates, they are recycled across units.
- Unit health and power are secret values, even out of combat. Never compare them or do math on them; pass them to widgets (for example `UnitPowerPercent` with a `C_CurveUtil` curve into `SetAlpha`). Check with `ns.IsSecret`.
- Scans of `UIParent` children can hit forbidden frames. Check `ns.Usable` before calling any method.
- Wrap calls that may be missing on this client in `pcall`, or check `type` first.
- An unknown event in `RegisterEvent` throws. Register each event separately inside `pcall`.
- Print each error once through `Report`.

## Touching the UI

- Action bars only through alpha. Do not use `Hide()`, `Show()`, or state drivers on bars.
- No secure snippets. Do not touch `ChatFrame_OpenChat`.
- `PlayerFrame` and `PetFrame` only through alpha, per `docs/features/player.md`. TargetFrame may only be faded through alpha for Require a living target. Party and raid frames may only be faded through alpha for the optional autohide rule in `docs/features/visible.md`. Do not hide the minimap, vehicle / extra action / zone ability, or the LFG eye (`QueueStatus`, `LFGEye`).
- Quest, gossip and item text windows are changed only through textures, button points and an own layer, never through `Hide()` of the window itself.
- Blizzard overwrites alpha. Hold the wanted value with a `SetAlpha` hook and the `_quietApplying` flag so the hook does not loop.
- Disabling must restore saved alpha and textures (`RestoreAll`). Wire new behavior into both `ApplyAll` and `RestoreAll`.

## Code

- Files load in `QuietUI.toc` order and share the addon table: `local _, ns = ...`. No globals except `QuietUIDB`, `QuietUICharDB`, the slash command, `QuietUISetup` so Escape can close the setup window, and `QuietUIGlance`, `BINDING_CATEGORY_QUIETUI`, and `BINDING_NAME_QUIETUI_GLANCE` for the Glance key. Do not add libraries.
  - `Core.lua`: `DB`, `Print`, `Report`, alpha hooks, fading, texture hiding, restore.
  - `Presets.lua`: shared preset CRUD, effective settings, and personal snapshots.
  - `Frames.lua`: bar / bag / spared classification, `Mute`.
  - `Bars.lua`: action bars, `ShowAll`, and `BarTarget`.
  - `Faders.lua`: XP bar, cooldown manager, damage meter, player frame, pet frame, quest tracker, buffs, and the range gradient.
  - `QuestNotice.lua`: temporary quest snapshots, acceptance/progress/completion notices, and their bounded queue.
  - `Highlights.lua`: soft-interact glow for herbs, ore, and interact objects, and the soft-target CVars it sets and restores.
  - `QuestMobs.lua`: the quest icon left of an attackable quest mob's nameplate.
  - `Parchment.lua`: quest, gossip and item text parchment reskin.
  - `Menu.lua`: the bag button and the micro menu fade.
  - `Chat.lua`: chat chrome, line bubbles, and the input box.
  - `LayoutString.lua`: only the Edit Mode export string. Update it by pasting a new export.
  - `Layout.lua`: asks to add or update the `QuietUI` Edit Mode layout from that string.
  - `Setup.lua`: the `/quiet setup` window, `CharDB`, `Pinned`, `PlayerStyle`, `GroupAuras`, `AlwaysShowDebuffs`, `ChatFade`, `Range`, `Highlights`, `QuestMobs`, `Parchment`.
  - `QuietUI.lua`: `ApplyAll`, `RestoreAll`, events, `OnUpdate`, `/quiet`.
- Call other files through `ns` at run time, not through locals captured at load, so load order only matters for `QuietUI.lua` being last.
- Comments in English, short, only where the reason is not visible from the code.

## Agent skills

Issue tracker: local markdown. See `docs/agents/config/issue-tracker.md`.
Domain docs: `docs/adr/`. See `docs/agents/config/domain.md`.
Workflow defaults: `docs/agents/config/workflow.md` (branch-owner, push, language, work types).
Pipeline: `/align` → `/analyze` → `/implement` → `/verify` (functional → code review → finalize).
`/implement` orchestrates fresh test subagents → parent test commit → fresh implementation subagents → automatic `/verify`; see the skill for detailed rules.
Skills: the shared pack installed in the runner; `/setup` updates project configuration, not the global pack. Repo-specific additions belong in `docs/agents/config/`.
