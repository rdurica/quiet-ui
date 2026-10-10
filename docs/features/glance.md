# Glance

The Glance key and `/quiet glance`.

- Press `` ` `` (Glance) to show the faded HUD at once: every action bar, the XP bar, the cooldown manager, the damage meter, the personal resource bar (health and power), the quest tracker, buffs and debuffs, the bag button, and the micro menu. The portrait and pet show only when the player frame is on. Press again and the rules above apply, including a checked row. The state is not saved, and turning QuietUI off clears it. Chat is unchanged and the addon does not toggle. The binding is `QUIETUI_GLANCE`, category `QUIETUI` (shown as QuietUI). Do not set `header` on it: the client turns that into a bindable row named `HEADER_QUIETUI` under Other. `SetBinding` applies `` ` `` when that key is free or still on `HEADER_QUIETUI`, and leaves any other action alone. The key can be changed in Key Bindings. Only the key-down arrives as a toggle; key-up is ignored.
- `/quiet glance` toggles Glance through the same function as its key binding, for use in macros and controller setups. It does nothing while QuietUI is off, does not toggle the addon, and does not save the Glance state.
