# Modules

QuietUI is split into five modules. A module that is off applies nothing, draws nothing, offers no layout and shows none of its tabs; turning it off restores what it touched. The Modules tab of `/quiet setup` and the welcome's Custom screen choose them.

| Module | Covers | Tabs |
|--------|--------|------|
| Chat | Modern chat and chat input history ([chat.md](chat.md)) | Chat |
| Fading | Action bars, the faded HUD, player and pet frames, party autohide, the micro menu, Glance ([bars.md](bars.md), [visible.md](visible.md), [player.md](player.md), [glance.md](glance.md)) | Visible, Bars, Groups, Player |
| Helpers | Quest updates, Highlights, Quest mobs ([helpers.md](helpers.md)) | Helpers |
| Layout | The bundled Edit Mode layout, its prompt, Force QuietUI layout, a preset's layout switch ([general.md](general.md)) | none; the layout controls on General |
| Modernize | The Modern look ([modern.md](modern.md)) | Modern |

- Defaults (`modules` missing, see [settings.md](settings.md)): Chat, Fading, Helpers and Layout on, Modernize off. This is the Classic set. Modern turns all five on. Custom, and the Modules tab, choose any set; the welcome's Custom starts with only Chat checked. At least one module must be on.
- Modules are shared through presets. Existing characters keep their previous behaviour after the update and do not see the welcome again.
- Apply: a feature runs only while its module is on; disabled modules unregister their events, skip hook installation (and any installed hooks do nothing while off), and drop out of per-frame and periodic updates. Restore: `/quiet off` and turning a module off restore every feature regardless of the gate; turning Layout off selects the layout from before QuietUI again.
- Unknown `/quiet` subcommands leave QuietUI's enabled state unchanged and print `Unknown command "<arg>". Try /quiet [on|off|setup|glance|preset|profile|dump].`; bare `/quiet` toggles on and off, and `/quiet on` / `/quiet off` set it explicitly.
- A module change in setup (Save) restores everything and then reloads the UI, so no frame stays half-styled. A Save that leaves the set unchanged applies without a reload.
- Combat: Save refuses a module change in combat and prints `Leave combat to change modules.`; the welcome's Custom Save does the same.
