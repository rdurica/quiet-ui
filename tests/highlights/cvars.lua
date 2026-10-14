-- Highlights soft-target CVars: stored originals, game object versus NPC targets, retries,
-- unreadable CVars, a clean profile and a disabled addon.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("Clean profile writes no CVar and shows nothing", function(t, A)
    local w = H.world(t)
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    w.apply()
    A.eq(w.writes(), 0, "a CVar was written with every category off")
    A.eq(w.saved(), nil, "highlightCVars was stored with every category off")
    A.ok(w.nothingShown(), "something was shown with every category off")
    return w
end)

case("An empty Highlights table counts as all off", function(t, A)
    local w = H.world(t, { flags = {} })
    w.apply()
    A.eq(w.writes(), 0, "a CVar was written for an empty settings table")
    return w
end)

case("Disabled QuietUI is inactive even with Ore on", function(t, A)
    local w = H.world(t, { flags = { ore = true }, enabled = false })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    A.eq(w.writes(), 0, "a CVar was written while QuietUI is disabled")
    A.ok(w.nothingShown(), "the glow was shown while QuietUI is disabled")
    return w
end)

case("Ore on out of combat and instance sets 3/15/1/1/2/1 and stores originals", function(t)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.assertCVars(H.IDLE, "After apply")
    w.assertSaved(H.ORIGINAL)
    return w
end)

case("A game object target turns the nameplate and icon CVars on; an NPC turns them back", function(t)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.assertCVars(H.IDLE, "Without a target")
    w.target("GameObject-A")
    w.assertCVars(H.WANT, "Game object target")
    w.target("Creature-V")
    w.assertCVars(H.IDLE, "NPC target")
    w.target(nil)
    w.assertCVars(H.IDLE, "Target cleared")
    w.assertSaved(H.ORIGINAL)
    return w
end)

case("An NPC target keeps the original icon when soft interact was already on", function(t, A)
    local w = H.world(t, { flags = { ore = true }, cvars = H.ICONS_ON })
    w.apply()
    w.target("Creature-V")
    A.eq(w.cvar("SoftTargetIconInteract"), "1", "the original icon was not kept for an NPC")
    A.eq(w.cvar("SoftTargetNameplateInteract"), "0", "an NPC got a nameplate")
    return w
end)

case("An NPC target in combat leaves the CVars until combat ends", function(t)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.target("GameObject-A")
    w.combat(true)
    w.target("Creature-V")
    w.assertCVars(H.WANT, "In combat")
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    w.assertCVars(H.IDLE, "After combat")
    return w
end)

case("ApplyHighlights is idempotent", function(t)
    local w = H.world(t, { flags = { ore = true } })
    w.apply(); w.apply(); w.apply()
    w.assertCVars(H.IDLE, "After repeated apply")
    w.assertSaved(H.ORIGINAL)
    return w
end)

case("Turning the last category off restores all six originals", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.setFlags({})
    w.apply()
    w.assertCVars(H.ORIGINAL, "After last category off")
    A.eq(w.saved(), nil, "highlightCVars was not cleared")
    return w
end)

case("RestoreHighlights restores all six originals and hides the glow", function(t, A)
    local w = H.oreShown(t)
    A.ok(w.glow(), "the glow was not shown before restore")
    w.restore()
    w.assertCVars(H.ORIGINAL, "After restore")
    A.eq(w.saved(), nil, "highlightCVars was not cleared")
    w.assertHidden()
    return w
end)

case("A failed CVar restore keeps its original until a later retry succeeds", function(t, A)
    local w = H.oreShown(t)
    local set = C_CVar.SetCVar
    C_CVar.SetCVar = function(name, value)
        if name == "SoftTargetInteract" then error("temporary restore failure") end
        return set(name, value)
    end
    w.restore()
    A.eq(w.cvar("SoftTargetInteract"), H.WANT.SoftTargetInteract, "the failing write changed the CVar")
    A.eq(w.saved().SoftTargetInteract, H.ORIGINAL.SoftTargetInteract, "a failed restore lost the original CVar value")
    for name, value in pairs(H.ORIGINAL) do
        if name ~= "SoftTargetInteract" then
            A.eq(w.cvar(name), value, "one failed restore prevented restoring " .. name)
        end
    end
    A.ok(w.reported(), "the write failure was not reported")
    w.assertHidden()
    C_CVar.SetCVar = set
    w.event("PLAYER_REGEN_ENABLED")
    w.assertCVars(H.ORIGINAL, "After retrying the failed restore")
    A.eq(w.saved(), nil, "the successfully restored snapshot was not cleared")
    return w
end)

case("A failed CVar activation keeps its original and retries the desired value", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    local set = C_CVar.SetCVar
    C_CVar.SetCVar = function(name, value)
        if name == "SoftTargetInteract" then error("temporary activation failure") end
        return set(name, value)
    end
    w.apply()
    w.assertSaved(H.ORIGINAL)
    A.eq(w.cvar("SoftTargetInteract"), H.ORIGINAL.SoftTargetInteract, "the failing write changed the CVar")
    A.ok(w.reported(), "the write failure was not reported")
    C_CVar.SetCVar = set
    w.event("PLAYER_REGEN_ENABLED")
    w.assertCVars(H.IDLE, "After retrying the failed activation")
    w.assertSaved(H.ORIGINAL)
    w.restore()
    w.assertCVars(H.ORIGINAL, "After disabling the recovered activation")
    A.eq(w.saved(), nil, "highlightCVars was not cleared after recovery")
    return w
end)

case("Reload while active keeps the stored originals", function(t, A)
    local w = H.world(t, { flags = { ore = true }, cvars = H.WANT, saved = H.copy(H.ORIGINAL) })
    w.apply()
    w.assertSaved(H.ORIGINAL)
    w.assertCVars(H.IDLE, "After reload apply")
    w.setFlags({})
    w.apply()
    w.assertCVars(H.ORIGINAL, "After off following reload")
    A.eq(w.saved(), nil, "highlightCVars was not cleared")
    return w
end)

case("An older CVar snapshot captures the arc before changing it", function(t, A)
    local saved, cvars = H.copy(H.ORIGINAL), H.copy(H.WANT)
    saved.SoftTargetInteractArc = nil
    cvars.SoftTargetInteractArc = "1"
    local w = H.world(t, { flags = { ore = true }, saved = saved, cvars = cvars })
    w.apply()
    A.eq(w.saved().SoftTargetInteractArc, "1", "the existing arc was not saved")
    A.eq(w.cvar("SoftTargetInteractArc"), "2", "the wider arc was not applied")
    w.restore()
    A.eq(w.cvar("SoftTargetInteractArc"), "1", "the existing arc was not restored")
    return w
end)

local function writtenTo(w, name)
    for _, entry in ipairs(w.mock.cvarLog) do
        if entry[1] == name then return true end
    end
    return false
end

case("An unreadable CVar (nil) is not stored and not written", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    local get = C_CVar.GetCVar
    C_CVar.GetCVar = function(name)
        if name == "SoftTargetIconGameObject" then return nil end
        return get(name)
    end
    w.apply()
    local saved = w.saved()
    A.type(saved, "table", "the readable originals were not stored")
    A.eq(saved.SoftTargetIconGameObject, nil, "an unreadable CVar was stored")
    A.eq(saved.SoftTargetInteract, "1", "a readable original was not stored")
    A.falsy(writtenTo(w, "SoftTargetIconGameObject"), "an unreadable CVar was written")
    A.eq(w.cvar("SoftTargetInteract"), "3", "a readable CVar was not set")
    w.setFlags({})
    w.apply()
    A.falsy(writtenTo(w, "SoftTargetIconGameObject"), "an unreadable CVar was written on restore")
    A.eq(w.cvar("SoftTargetInteract"), "1", "a readable CVar was not restored")
    return w
end)

case("A CVar read that throws is not stored and not written", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    local get = C_CVar.GetCVar
    C_CVar.GetCVar = function(name)
        if name == "SoftTargetInteractRange" then error("cannot read " .. name) end
        return get(name)
    end
    w.apply()
    local saved = w.saved() or {}
    A.eq(saved.SoftTargetInteractRange, nil, "a failing CVar read was stored")
    A.falsy(writtenTo(w, "SoftTargetInteractRange"), "a CVar with a failing read was written")
    return w
end)
