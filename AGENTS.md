# QuietUI

Opinionated UI for WoW Forever. Modern and quiet: few frames, few buttons, text stays. The addon turns on or off, and one window chooses what stays visible.

## Principles

- Clean UI with minimal settings. Full functionality, minimal UI.
- Works out of the box after install. Defaults must be right; settings exist only for small tweaks.
- Not a configurable framework: no sliders, no libraries like Ace3.
- Player-facing text (chat, tooltip) is English.

## Behavior

The behavior spec lives in `docs/features/` (index: `docs/features/README.md`), one file per `/quiet setup` tab. Read the relevant file before changing behavior and update it in the same commit when behavior or a rule changes; looks, sizes, colours and frame names live in the code, not the spec. Keep the spec short. `README.md` is for players and links there.

## Client

- WoW Forever beta, `Interface: 16001`. The API mixes classic and newer frames; a global may not exist.
- The main bar is `MainActionBar`, not `MainMenuBar`. In gamepad mode the bars live under `GamepadMainActionBarFrame` (load-on-demand `Blizzard_GamepadActionBars`). The damage meter is a Blizzard load-on-demand addon; its frames are found by the `DamageMeter` prefix. The cooldown manager is `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`. The personal resource bar is `PersonalResourceDisplayFrame`; do not fade nameplates, they are recycled across units.
- Unit health and power are secret values, even out of combat. Never compare them or do math on them; pass them to widgets (for example `UnitPowerPercent` with a `C_CurveUtil` curve into `SetAlpha`). Check with `ns.IsSecret`.
- Scans of `UIParent` children can hit forbidden frames. Check `ns.Usable` before calling any method.
- Wrap calls that may be missing on this client in `pcall`, or check `type` first.
- An unknown event in `RegisterEvent` throws. Register each event separately inside `pcall`.
- Print each error once through `Report`.

## Touching the UI

- Action bars are faded only through alpha. Modernize may change textures, TexCoords, colours and its own child regions on action buttons and bar art. Do not use `Hide()`, `Show()`, or state drivers on bars.
- No secure snippets. Do not touch `ChatFrame_OpenChat`.
- `PlayerFrame` and `PetFrame` only through alpha, per `docs/features/player.md`. TargetFrame may only be faded through alpha for Require a living target. Party and raid frames may only be faded through alpha for the optional autohide rule in `docs/features/visible.md`. Do not hide the minimap, vehicle / extra action / zone ability, or the LFG eye (`QueueStatus`, `LFGEye`).
- Modernize may change textures, TexCoords, colours, fonts, its own child regions, and the points and sizes of parts inside the frames it skins, all through its journal and restored on undo. Window and protected points change only out of combat. Alpha stays owned by the fade rules; the minimap is never hidden or faded. Content art (talent trees, spell icons, character models, map canvas) stays. Design direction: `docs/features/modern.md`.
- Blizzard overwrites alpha. Hold the wanted value with a `SetAlpha` hook and the `_quietApplying` flag so the hook does not loop.
- Disabling must restore saved alpha and textures (`RestoreAll`). Give new behavior both `apply` and `restore` in its feature spec, so `ApplyAll` and `RestoreAll` cover it.

## Code

- Files load in `QuietUI.toc` order and share the addon table: `local _, ns = ...`. No globals except `QuietUIDB`, `QuietUICharDB`, the slash command, `QuietUISetup` so Escape can close the setup window, and `QuietUIGlance`, `BINDING_CATEGORY_QUIETUI`, and `BINDING_NAME_QUIETUI_GLANCE` for the Glance key, plus `GetMinimapShape` only while the Modern minimap area is applied (restore its prior value on undo). Do not add libraries.
- Folders, in load order. One responsibility per file, at most 400 lines (checked by `tests/core/structure.lua`, together with cross-file references and stray globals).
  - `Core/`: helpers every file uses (`DB`, `Print`, `Report`, `Run`, `Usable`, `IsSecret`, `Flat`, `Backdropped`), alpha hooks, fading, hover catchers, nameplate helpers, texture hiding, `RestoreAlpha`, world state (`ns.World`), the profiler, and the feature registry (`Feature.lua`).
  - `Settings/`: `ns.Settings`: `CharDB` store, the getters, presets with personal snapshots, and migrations.
  - `Features/<Feature>/`: one folder per feature, one table on `ns` (`ns.Bars`, `ns.Modern`, …). Modern: the area registry with `Theme`, `Skin` (a per-area change journal) and `Movable`; a new area is one file under `Features/Modern/Areas/` registered through `ns.Modern.Register`, loaded before `Feature.lua` in the `.toc`.
  - `Setup/`: `ns.Setup`, the `/quiet setup` window: window, widgets, draft, paint, minimap button, and one file per tab in `Pages/`.
  - `Layout/`: `ns.Layout`, the `QuietUI` Edit Mode layout: layouts, preview, prompt, settle. `String.lua` holds only the Edit Mode export string; update it by pasting a new export.
  - `QuietUI.lua`: last file. Boot, `ApplyAll`, `RestoreAll`, `OnUpdate` scheduler, `/quiet`. It walks the registry for apply, restore, events and per-frame phases; adding a feature never changes it.
- Namespaces: each feature owns one table on `ns` holding its public functions and the ones shared between its own files. A file may capture a feature table in a local (`local Chat = ns.Chat`), never a function of another file; call through the table at run time. State shared inside a feature lives on its private `<Feature>.state`; other features never read it. A helper used by one file stays `local`. Core helpers stay on `ns`.
- Feature registry (`Core/Feature.lua`): `ns.Feature{ name, enabled, apply, restore, events, always, early, required, fade, frame, tick, rescan, hooks }`. `ApplyAll` calls `apply` in registration order, `RestoreAll` calls `restore` in reverse, `OnUpdate` calls `fade`, `frame`, `tick` and `rescan`, and the registry (`ns.Registry`) owns the event frame. `early` events are delivered before boot and while off; `required` events report a failed `RegisterEvent` once as `<name> events`. A failing callback is reported once and the others continue.
- A new feature is a folder under `Features/` that calls `ns.Feature` in its last file, plus `.toc` lines, a `docs/features/` section and `tests/<area>/`.
- Comments in English, short, only where the reason is not visible from the code.

## Tests

- `lua tests/run.lua [filter]` runs every test; the filter matches area or file names. Exit code 0 means all passed. It includes the structure check (`tests/core/structure.lua`).
- New tests go in `tests/<area>/` and use only the public `ns.*`, never internals or production file names.
- `tests/measure/` holds direct scripts, not run by `run.lua`, for example `lua tests/measure/performance.lua --measure`.

## Agent skills

Issue tracker: GitHub. See `docs/agents/config/issue-tracker.md`.
Domain docs: `docs/adr/`. See `docs/agents/config/domain.md`.
Workflow defaults: `docs/agents/config/workflow.md` (branch-owner, push, language, work types).
Pipeline: `/analyze` → `/implement` → `/verify` (functional → code review [→ ux] → finalize).
`/implement` (Opus) orchestrates `test-writer` agents → parent test commit → `implementer` agents → automatic `/verify` with reviewer and `check-runner` agents (Sonnet/Haiku); see the skill for detailed rules.
Skills: the shared pack installed in `~/.claude/`; `/setup` updates project configuration, not the pack. Repo-specific additions belong in `docs/agents/config/`.
