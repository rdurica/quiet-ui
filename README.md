# QuietUI

**Less UI. More world.** A quiet interface for the **WoW Forever beta** (Interface 16001).

QuietUI fades the Blizzard HUD while you explore and brings back the parts you
need through hover, combat, and your current situation. One setup window chooses
what stays visible, with personal settings or shared presets across characters.

![QuietUI while exploring](docs/images/img001.png)

## What you get

- **Bars when you need them.** Hover reveals a group of action bars; combat and
  instances bring bars back by default. Set each group to **Always visible** or
  **Only on hover**, or choose individual bars to show for an enemy or friendly target.
- **A quieter HUD.** Quests appear on hover. Cooldowns and the damage meter appear
  when fighting or grouped. Health and resources appear when they need attention.
- **Chat without the chrome.** Messages appear in dark bubbles and fade after
  10 seconds by default. Hover to see faded lines, scroll through history, or copy
  a message. Enter works as usual.
- **One bag button.** Left click opens bags, right click reveals bag slots, and
  dragging moves the button.
- **Glance.** Press `` ` `` to reveal the faded HUD at once. Press again to return
  to your usual visibility rules. Chat stays unchanged.

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

The minimap button also opens settings, even while QuietUI is off. Drag it around
the minimap to move it.

Glance defaults to `` ` `` if the key is free. Change it under **QuietUI** in
**Key Bindings**. You can also use `/quiet glance` in a macro and bind that macro
to a controller button through your controller setup.

Preset names ignore letter case. Use quotes for names with spaces. Selecting a
preset saves the choice for this character and applies its settings and linked
layout while QuietUI is enabled; combat delays the layout change. While QuietUI
is off, the selection is saved for the next enable. If settings are open, the
command cancels the pending draft and layout preview and shows the selected preset.
The layout list shows only layouts for your current interface mode, including
custom layouts: keyboard and mouse layouts normally, Gamepad layouts in Gamepad mode.
On login or reload, a preset linked to a layout for another mode detaches to
your personal settings. Its shared settings and layout link stay intact.
Shared presets are also tagged for keyboard and mouse or Gamepad mode based on
their linked layout. The preset menu and `/quiet preset` list only presets for
the current mode; commands cannot select a preset for another mode. Existing
presets acquire their tag automatically from their layout.

## Make it yours

Open `/quiet setup`, change your choices, then click **Save**. The window stays
open. **X** or **Escape** closes it without saving pending changes.

![QuietUI setup](docs/images/img007.png)

- **General:** Choose a shared preset or keep `<no preset>` for personal settings.
  Create, rename, or delete presets here, and choose the existing Edit Mode layout
  each preset uses. Without a preset, **Force QuietUI layout** switches to the
  bundled layout when QuietUI turns on; it is off by default.
- **Visible:** Choose **Always visible** or **Only on hover** for each HUD element.
  Both unchecked keeps its usual rules. The two choices are mutually exclusive.
  XP defaults to **Only on hover**; uncheck it to use the usual bar triggers.
  Party and raid frames default to **Always visible**. Uncheck it to fade them
  while exploring; combat, instances, hover, Glance and Edit Mode reveal them.
  **Only on hover** is disabled for this row.
- **Bars:** Assign action bars and the swing timer to groups. **Enemy** and
  **Friend** show an individual bar for the matching target when its group uses
  the usual rules.
- **Groups:** Each used group lists its members with **Always visible** and
  **Only on hover** choices. Group modes temporarily disable Enemy/Friend
  without discarding their values. Scroll the group list to reach later groups.
- **Player:** Toggle the portrait and pet, group buffs with the player frame, or
  require a living target. **Always show debuffs** is on by default and keeps
  debuffs visible independently of the player frame and aura grouping. Optional
  **In range** adds a green gradient to your
  target's nameplate while in range and the action bars are down. Choose 10 yards,
  28 yards, or Spell; leave the spell name empty to use the longest matching spell
  on bar 1. Choose Unfriendly or Friendly for the target type.
- **Chat:** Toggle modern chat and choose the fade delay. **Stay** keeps messages
  visible at the bottom.
- **Info:** A short guide to QuietUI and Glance.

With a preset selected, **Save** updates its settings for every character using
it. Other characters load the changes on their next login. Selecting, creating,
and renaming take effect after **Save**. Choosing a preset's layout previews it
immediately; **Save** stores the link, while **X** or **Escape** restores the layout
used before the preview. Deletion takes
effect immediately after confirmation. New characters start with `<no preset>`.
Leaving a preset, or losing it because it was deleted on another character, keeps
the last settings used as a personal copy.

A preset selects its linked layout when you log in, enable QuietUI, or save it.
Turning QuietUI off restores your previous layout. If the linked layout is missing,
QuietUI uses its bundled layout and reports the missing link once per login. Choose
a replacement in General and save to repair it. Layout changes wait until combat
ends. Presets can also be managed while QuietUI is off.

**Reset default** disconnects this character from its preset without changing the
shared preset, then applies and saves the defaults immediately: Always visible off except for party/raid
frames, Only on hover on for XP and off for other elements, default bar groups, player
frame, grouped buffs, and Always show debuffs on,
modern chat with a 10-second fade, and Force layout, living-target requirement, and
In range off.

**Import layout** adds or updates the bundled Edit Mode layout immediately,
including after choosing Not now. Each bundled layout version is offered once;
updates require your agreement. Without a preset and with Force layout off,
enabling or disabling QuietUI leaves your active layout alone.

<details>
<summary><strong>Visibility rules in detail</strong></summary>

**Only on hover** overrides automatic triggers, including combat, instances,
groups, target rules, low resources, XP rewards, and post-combat meter time.
For buffs and debuffs it also overrides aura grouping and **Always show debuffs**.
Glance and Edit Mode still reveal these elements. Bars and XP also stay up with
an open spell flyout or an item on the cursor; the bag button stays up while
its slots are open, while dragging, or with an item on the cursor.
Cooldowns, the meter, and the resource bar gain hover detection in this mode.
Existing Action bars and Swing timer pins move to group settings automatically;
mixed groups are split when needed to preserve which bars stay visible.

The usual rules below follow your Always visible choices and Glance, except that the player
and pet require the player frame to be enabled. Edit Mode reveals the HUD for
arranging it. Elements appear immediately and fade out over 0.3 seconds.

- **Action bars:** Hover, combat, a vehicle, an instance, an open spell flyout, or
  an item on the cursor. By default, bars 1–3, stance, pet, and totem fade together;
  bars 4–5 share another group, later bars each have their own, and swing uses 10.
- **XP:** Only on hover by default. With that unchecked: hover, combat, a vehicle,
  an instance, five seconds after a quest awards XP, a spell flyout, or an item
  on the cursor.
- **Cooldowns and damage meter:** Combat, an instance, or a group. The meter stays
  for 10 seconds after combat. Hover does not reveal either.
- **Personal resource:** Combat, an instance, or mana, focus, or energy below 70%.
  Its health bar also appears when health is not full.
- **Player and pet:** A target, combat, an instance, a group, a vehicle, hover, or
  low mana, focus, or energy. Having a pet out alone does not reveal them.
  **Require a living target** overrides these rules and Glance for a dead target,
  fading player, pet, and target frames; Edit Mode still reveals them.
- **Party and raid:** Blizzard visibility by default. With **Always visible**
  unchecked: combat, an instance, hover across the block, Glance, or Edit Mode.
  Target selection and group membership alone do not reveal them.
- **Buffs and debuffs:** Combat, an instance, a group, or hover. Grouping is on by
  default and also reveals them with the enabled player frame. **Always show debuffs**
  keeps debuffs visible by default; turn it off to apply these fade rules to them.
- **Quest tracker and micro menu:** Hover across their whole area, including gaps.
- **Bag button:** Hover, open bag slots, an item on the cursor, or dragging.

In range needs a visible target nameplate and a living target. It stays off during
combat, in vehicles and instances, in Edit Mode, with a spell flyout or item on the
cursor, during Glance, and while an action bar group uses Always visible.

</details>
