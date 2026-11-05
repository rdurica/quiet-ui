# QuietUI

**Less UI. More world.** A quiet interface for **WoW Forever** (Interface 16001).

Ever hidden the UI just to enjoy the view? QuietUI lets you play like that. While you explore, the action bars, the XP bar and everything else you don't need right now fade away. When something happens, they come back: a pull, a hover over the bars, a dungeon. It works right after you install it, and one window lets you tweak the rest.

![Exploring: the world gets the whole screen](https://media.forgecdn.net/attachments/2152/157/01-exploring-jpg.jpg)

## Classic or Modern

The first time you log in, each character picks a look:

- **Classic** keeps Blizzard's frames, just quieter.
- **Modern** (experimental) gives the UI a flat, dark graphite style: slim unit frames, clean windows, and a tidier map, minimap and tooltips. You can turn any area off on its own, and switching Modern off brings the original look back.

<p align="center">
<img src="https://media.forgecdn.net/attachments/2152/158/02-combat-jpg.jpg" width="49%" alt="Classic in combat">
<img src="https://media.forgecdn.net/attachments/2152/163/03-modern-hud-jpg.jpg" width="49%" alt="Modern in combat">
</p>
<p align="center"><em>The same fight in Classic (left) and Modern (right).</em></p>

## What it does

- **Action bars** show up when you hover them and come back in combat and in instances. Keep a group on screen, or show a single bar for an enemy or friendly target.
- **The rest of the HUD** stays out of the way: the quest tracker waits for a hover, cooldowns and the damage meter appear when you fight or group up, and health and resources pop up when they need attention.
- **Glance**: press `` ` `` to see the whole HUD at once, and press it again to go quiet.
- **Chat** without boxes and borders. Messages fade out after a while; hover to read back, hover a line to copy it, and press Alt+Up to bring back what you typed.
- **Small helpers**: a short note when a quest updates, a soft glow on the herb, ore or object you can interact with, an icon on mobs your quests need, and one bag button instead of five.
- **Presets** carry your setup over to your other characters.

## Install

1. Get it from [CurseForge](https://www.curseforge.com/wow/addons/quietui), or download the zip from the [latest release](https://github.com/rdurica/quiet-ui/releases/latest).
2. Extract it into `World of Warcraft/_forever_/Interface/AddOns/`, so the addon ends up at `AddOns/QuietUI/QuietUI.toc`.
3. Start the game, pick a look, and accept the optional QuietUI Edit Mode layout, or choose **Not now** to keep yours.

**Updating?** Delete the old `QuietUI` folder first, then restart the game. `/reload` does not load new files. Your settings are kept.

## Settings

Type `/quiet setup` or click the minimap button. Everything is in one window, with a short explanation next to each option; click **Save** when you're done. **X** or **Escape** closes it without saving.

| Tab | What you set there |
|---|---|
| General | Shared presets and the bundled Edit Mode layout |
| Visible | *Always visible* or *Only on hover* for each part of the HUD |
| Bars, Groups | Which bars fade together, and bars for enemy or friendly targets |
| Player | Player frame and pet, buffs and debuffs, the range indicator |
| Misc. | Modern chat, quest updates, highlights and quest mobs |
| Modern | The Modern look, its theme, and each area on its own |
| Info | A short introduction and how Glance works |

<p align="center">
<a href="https://media.forgecdn.net/attachments/2152/242/04b-modern-character-detail-jpg.jpg"><img src="https://media.forgecdn.net/attachments/2152/242/04b-modern-character-detail-jpg.jpg" width="24%" alt="Character window"></a>
<a href="https://media.forgecdn.net/attachments/2152/243/05-modern-bags-jpg.jpg"><img src="https://media.forgecdn.net/attachments/2152/243/05-modern-bags-jpg.jpg" width="24%" alt="Bags"></a>
<a href="https://media.forgecdn.net/attachments/2152/245/07-modern-map-jpg.jpg"><img src="https://media.forgecdn.net/attachments/2152/245/07-modern-map-jpg.jpg" width="24%" alt="Map and quest log"></a>
<a href="https://media.forgecdn.net/attachments/2152/209/08-setup-jpg.jpg"><img src="https://media.forgecdn.net/attachments/2152/209/08-setup-jpg.jpg" width="24%" alt="Setup window"></a>
</p>
<p align="center"><em>Character window, bags, map and the setup window. Click to enlarge.</em></p>

## Commands

```text
/quiet                  Turn QuietUI on or off (/quiet on, /quiet off)
/quiet setup            Open the settings, also while QuietUI is off
/quiet glance           Show the whole HUD (works in macros and with a controller)
/quiet preset           List your presets
/quiet preset "Name"    Switch to a shared preset
```

`/quietui` works too. Glance uses `` ` `` when the key is free; change it under **QuietUI** in **Key Bindings**. `/quiet off` brings Blizzard's frames back.

## Feedback

Found something odd, especially in Modern? Please [open an issue](https://github.com/rdurica/quiet-ui/issues).

## Documentation

Every feature, setting and visibility rule is described in [docs/features](docs/features/README.md).
