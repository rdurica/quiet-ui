# QuietUI behavior

The full behavior of QuietUI, the source of truth for every rule and default. Each file follows a tab of `/quiet setup`; the rest have their own file. Player-facing overview: [the main README](../../README.md).

The goal is a clean UI, not a configurable framework. It works out of the box; settings only tweak it.

| File | Covers |
|------|--------|
| [setup.md](setup.md) | The `/quiet` command, the `/quiet setup` window, its look, and chat messages. |
| [settings.md](settings.md) | What `QuietUIDB` (account) and `QuietUICharDB` (character) may hold, with defaults. |
| [general.md](general.md) | Shared presets, `/quiet preset`, interface modes, and the bundled Edit Mode layout. |
| [visible.md](visible.md) | Always visible and Only on hover, and the rules for each faded HUD element except action bars and the player frame. |
| [bars.md](bars.md) | Action bar fade groups, the swing timer, Enemy/Friend, and group visibility. |
| [player.md](player.md) | Player and pet frames, thresholds, a living target, buffs and debuffs, and the In range gradient. |
| [misc.md](misc.md) | Modern chat, quest update notices, Highlights, and Quest mobs. |
| [glance.md](glance.md) | The Glance key and `/quiet glance`. |
