# QuietUI

**Less UI. More world.** A quiet interface for the **WoW Forever beta** (Interface 16001).

QuietUI fades the Blizzard HUD while you explore and brings back the parts you
need through hover, combat, and your current situation. It works out of the box;
one setup window lets you tweak what stays visible.

![QuietUI while exploring](docs/images/img001.png)

## What you get

- **Bars when you need them.** Hover reveals a group of action bars; combat and
  instances bring all bars back.
- **A quieter HUD.** Quests appear on hover. Cooldowns and the damage meter appear
  when fighting or grouped. Health and resources appear when they need attention.
- **One bag button.** Left click opens bags, right click reveals bag slots, and
  dragging moves the button.
- **Glance.** Press `` ` `` to reveal the faded HUD at once. Press again to return
  to your usual visibility rules.
- **Small extras.** Chat without the chrome, short quest update notices, a glow on
  the herb, ore, or object you can interact with, and an icon on mobs your quests need.

![QuietUI in combat](docs/images/img003.png)

## Install

1. Download the zip from the [latest release](https://github.com/rdurica/quiet-ui/releases/latest).
2. Extract it into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
   The addon file should end up at `AddOns/QuietUI/QuietUI.toc`.
3. Start the game or type `/reload`. Accept the optional QuietUI layout, or choose
   **Not now** to keep your current layout.

## Controls

```text
/quiet          Toggle QuietUI
/quiet on       Enable QuietUI
/quiet off      Disable QuietUI
/quiet setup    Open settings
/quiet glance   Toggle the faded HUD while QuietUI is enabled
/quiet preset   List the current and available presets
/quiet preset "Healer"   Select a shared preset by name
```

The minimap button also opens settings, even while QuietUI is off. Glance defaults
to `` ` `` if the key is free; change it under **QuietUI** in **Key Bindings**.

## Settings

Open `/quiet setup`, change your choices, then click **Save**. **X** or **Escape**
closes the window without saving. Tabs: General (presets and layout), Visible,
Bars, Groups, Player, Misc. (chat, quest updates, highlights, quest mobs), and Info.

![QuietUI setup](docs/images/img007.png)

## Documentation

Full documentation of every feature, setting, and visibility rule is in
[docs/features](docs/features/README.md).
