-- Highlights in combat: CVar changes wait for PLAYER_REGEN_ENABLED, the glow and icon hold stay.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("Combat keeps the glow and particles without CVar changes", function(t, A)
    local w, plate = H.oreShown(t)
    local writes = w.writes()
    w.combat(true)
    w.event("PLAYER_REGEN_DISABLED")
    A.ok(w.shownOn(plate), "entering combat hid the glow")
    A.ok(w.loopsPlaying(w.glow()), "entering combat stopped the particles")
    A.eq(plate.soft.Icon._alpha, 0, "entering combat revealed the icon")
    A.eq(w.writes(), writes, "entering combat wrote a CVar")
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    A.ok(w.shownOn(plate), "the glow did not return after combat")
    A.eq(w.writes(), writes, "leaving combat rewrote unchanged CVars")
    w.assertCVars(H.WANT, "After combat")
    return w
end)

case("Combat event alone keeps the glow visible", function(t, A)
    local w, plate = H.oreShown(t)
    w.event("PLAYER_REGEN_DISABLED")
    A.ok(w.shownOn(plate), "combat event hid the glow")
    return w
end)

for _, category in ipairs({ { "herb", H.HERBS }, { "ore", H.MINE },
    { "quest", "Cursor Crosshair_UnableInteract_64" } }) do
    case(category[1] .. " target and late plate changes work during combat", function(t, A)
        local w = H.world(t, { flags = { [category[1]] = true } })
        w.apply()
        w.combat(true)
        w.event("PLAYER_REGEN_DISABLED")
        local writes = w.writes()
        w.target("GameObject-A")
        local plate = w.addPlate("nameplate1", "GameObject-A", category[2])
        w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
        A.ok(w.shownOn(plate), "a new target plate was not highlighted during combat")
        A.ok(w.loopsPlaying(w.glow()), "combat particles are not playing")
        A.eq(plate.soft.Icon._alpha, 0, "combat target icon was not hidden")
        w.target(nil, "GameObject-A")
        w.assertHidden()
        A.eq(plate.soft.Icon._alpha, 1, "losing a combat target did not restore its icon")
        A.eq(w.writes(), writes, "combat target changes wrote CVars")
        return w
    end)
end

case("CVar change requested in combat waits for PLAYER_REGEN_ENABLED", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.combat(true)
    w.apply()
    A.eq(w.writes(), 0, "a CVar was written in combat")
    A.eq(w.saved(), nil, "originals were stored in combat before any write")
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    w.assertCVars(H.IDLE, "After combat")
    w.assertSaved(H.ORIGINAL)
    return w
end)

case("Deferred change applies the then-current state after combat", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.combat(true)
    w.apply()
    w.setFlags({})
    w.apply()
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    A.eq(w.writes(), 0, "an outdated combat request was applied")
    w.assertCVars(H.ORIGINAL, "After combat")
    return w
end)

case("RestoreHighlights in combat defers the CVar restore", function(t, A)
    local w = H.oreShown(t)
    w.combat(true)
    w.event("PLAYER_REGEN_DISABLED")
    local writes = w.writes()
    w.ns.DB().enabled = false
    w.restore()
    A.eq(w.writes(), writes, "RestoreHighlights wrote CVars in combat")
    w.assertHidden()
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    w.assertCVars(H.ORIGINAL, "After combat restore")
    A.eq(w.saved(), nil, "highlightCVars was not cleared after combat")
    return w
end)

case("Combat keeps the icon hidden; instances restore it", function(t, A)
    local w, plate = H.oreShown(t)
    w.event("PLAYER_REGEN_DISABLED")
    A.eq(plate.soft.Icon._alpha, 0, "combat revealed the highlighted icon")
    w.event("PLAYER_REGEN_ENABLED")
    A.eq(plate.soft.Icon._alpha, 0, "leaving combat did not hide the icon again")
    w.instance("party")
    w.event("PLAYER_ENTERING_WORLD")
    A.eq(plate.soft.Icon._alpha, 1, "entering an instance did not restore the icon")
    return w
end)
