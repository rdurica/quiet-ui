-- The soft-target icon: hidden through alpha while it belongs to QuietUI, restored when it does not.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("An unchecked category hides the icon QuietUI turned on and restores it after", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    A.ok(w.nothingShown(), "an unchecked category was highlighted")
    A.eq(plate.soft.Icon._alpha, 0, "the icon QuietUI turned on is still visible")
    A.eq(plate.soft.Icon._texture, H.MINE, "the icon texture was cleared")
    w.target(nil, "GameObject-Ore")
    A.eq(plate.soft.Icon._alpha, 1, "losing the target did not restore the icon")
    return w
end)

case("Unchecking a category on the current target keeps its icon hidden", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    w.setFlags({ herb = true })
    w.apply()
    A.ok(w.nothingShown(), "the unchecked category still glows")
    A.eq(plate.soft.Icon._alpha, 0, "unchecking revealed the icon QuietUI turned on")
    return w
end)

case("Game object icons follow the original SoftTargetIconGameObject", function(t, A)
    local cvars = H.copy(H.ORIGINAL)
    cvars.SoftTargetIconInteract = "1"
    local w = H.world(t, { flags = { herb = true }, cvars = cvars })
    w.apply()
    local object = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    A.eq(object.soft.Icon._alpha, 0, "a game object icon the player had off is visible")
    local npc = w.addPlate("nameplate2", "Creature-NPC", H.SPEAK)
    w.target("Creature-NPC")
    A.eq(object.soft.Icon._alpha, 1, "the previous icon was not restored")
    A.eq(npc.soft.Icon._alpha, 1, "an NPC icon the player had on was hidden")
    return w
end)

case("An interact icon the player had off is hidden for NPCs too", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    local npc = w.addPlate("nameplate1", "Creature-NPC", H.SPEAK)
    w.target("Creature-NPC")
    A.eq(npc.soft.Icon._alpha, 0, "an NPC icon QuietUI turned on is visible")
    return w
end)

case("Re-checking an unchecked target does not reveal its icon in between", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    local icon = plate.soft.Icon
    w.target("GameObject-Ore")
    local writes = {}
    local set = icon.SetAlpha
    icon.SetAlpha = function(self, alpha) writes[#writes + 1] = alpha; return set(self, alpha) end
    w.target("GameObject-Ore")
    w.event("PLAYER_REGEN_ENABLED")
    for _, alpha in ipairs(writes) do
        A.eq(alpha, 0, "the held icon was written to another alpha during a re-check")
    end
    A.eq(icon._alpha, 0, "the icon is visible after re-checks")
    return w
end)

case("Removing a plate releases the hold on an unchecked icon", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    A.eq(plate.soft.Icon._alpha, 1, "plate removal did not restore the icon")
    plate.soft.Icon:SetAlpha(0.8)
    A.eq(plate.soft.Icon._alpha, 0.8, "the removed icon is still held")
    return w
end)

case("Icons stay untouched while the CVars are not changed yet", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.combat(true)
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    A.eq(plate.soft.Icon._alpha, 1, "an icon was hidden before QuietUI changed the CVars")
    return w
end)

case("Disabling restores an unchecked icon", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-Ore", H.MINE)
    w.target("GameObject-Ore")
    w.restore()
    A.eq(plate.soft.Icon._alpha, 1, "disabling did not restore the icon")
    return w
end)

case("Highlighted icon stays hidden across Blizzard alpha writes without losing its texture", function(t, A)
    local w, plate = H.oreShown(t)
    local icon = plate.soft.Icon
    A.eq(icon._alpha, 0, "the overhead icon is still visible")
    A.eq(icon._texture, H.MINE, "the category texture was removed")
    icon:SetAlpha(1)
    A.eq(icon._alpha, 0, "Blizzard revealed the held icon")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    A.ok(w.shownOn(plate), "hiding the icon broke category detection")
    w.restore()
    A.eq(icon._alpha, 1, "the original icon alpha was not restored")
    icon:SetAlpha(0.6)
    A.eq(icon._alpha, 0.6, "the icon hook still holds after restore")
    return w
end)

case("Changing to an unrelated object restores the old icon and leaves the new one alone", function(t, A)
    local w = H.world(t, { flags = { ore = true }, cvars = H.ICONS_ON })
    w.apply()
    local old = w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    local other = w.addPlate("nameplate2", "Creature-B", H.GEAR)
    w.target("Creature-B")
    A.eq(old.soft.Icon._alpha, 1, "the previous icon was not restored")
    A.eq(other.soft.Icon._alpha, 1, "an unrelated interact icon was hidden")
    return w
end)

case("Icon restore preserves a partial alpha and captures a fresh value on reuse", function(t, A)
    local w = H.world(t, { flags = { ore = true }, cvars = H.ICONS_ON })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", H.MINE)
    local icon = plate.soft.Icon
    icon:SetAlpha(0.4)
    w.target("GameObject-A")
    A.eq(icon._alpha, 0, "the partial alpha icon was not hidden")
    w.target(nil, "GameObject-A")
    A.eq(icon._alpha, 0.4, "the partial alpha was not restored")
    icon:SetAlpha(0.7)
    w.target("GameObject-A")
    w.setFlags({})
    w.apply()
    A.eq(icon._alpha, 0.7, "reusing a plate restored a stale alpha")
    return w
end)

case("Removing the highlighted plate releases the icon hold", function(t, A)
    local w, plate = H.oreShown(t)
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    A.eq(plate.soft.Icon._alpha, 1, "plate removal did not restore the icon")
    plate.soft.Icon:SetAlpha(0.8)
    A.eq(plate.soft.Icon._alpha, 0.8, "the removed icon is still held")
    return w
end)
