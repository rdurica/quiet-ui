-- Highlights follow the soft interact target: finding its nameplate, moving, hiding and re-enabling.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("Target found through NAME_PLATE_UNIT_ADDED after the target event", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.target("GameObject-A")
    A.ok(w.nothingShown(), "something was shown before the plate exists")
    w.addPlate("nameplate3", "GameObject-B", H.MINE)
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate3")
    A.ok(w.nothingShown(), "a plate of another object was highlighted")
    local plate = w.addPlate("nameplate4", "GameObject-A", H.MINE)
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate4")
    A.ok(w.shownOn(plate), "the added plate of the target was not highlighted")
    return w
end)

case("Target found by scanning the plates on PLAYER_SOFT_INTERACT_CHANGED", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-B", H.MINE)
    local plate = w.addPlate("nameplate2", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    A.ok(w.shownOn(plate), "the scanned plate of the target was not highlighted")
    return w
end)

case("Scan falls back to namePlateUnitToken when UnitFrame.unit is missing", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate2", "GameObject-A", H.MINE, { noUnitToken = true })
    w.target("GameObject-A")
    A.ok(w.shownOn(plate), "namePlateUnitToken was not used")
    return w
end)

case("Target GUID falls back to UnitGUID(softinteract)", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.targetNoArgs("GameObject-A")
    A.ok(w.shownOn(plate), "UnitGUID(softinteract) was not used without event args")
    return w
end)

case("Changing target re-reads the texture and moves the anchor", function(t, A)
    local w, a = H.oreShown(t)
    A.ok(w.shownOn(a), "the first target was not shown")
    local root = w.glow()
    local groups, textures = #w.groups(), #w.textures(root)
    w.addPlate("nameplate2", "GameObject-B", H.GEAR)
    w.target("GameObject-B", "GameObject-0-1-2-3-1731-0001")
    w.assertHidden()
    local c = w.addPlate("nameplate3", "GameObject-C", H.MINE)
    w.target("GameObject-C", "GameObject-B")
    A.ok(w.shownOn(c), "the new target was not shown")
    A.eq(w.glow(), root, "the glow frame was created again")
    A.eq(root._parent, c, "the glow did not move to the new plate")
    A.ok(#root._points == 1 and root._points[1][2] == c.soft, "the glow is not anchored to the new SoftTargetFrame")
    A.falsy(w.shownOn(a), "the old plate still shows the glow")
    A.ok(#w.groups() == groups and #w.textures(root) == textures, "the glow parts were created again")
    return w
end)

case("Same plate with a changed icon is re-read on the next target event", function(t, A)
    local w, plate = H.oreShown(t)
    plate.soft.Icon:SetTexture(H.GEAR)
    local guid = "GameObject-0-1-2-3-1731-0001"
    w.target(guid, guid)
    A.ok(w.nothingShown(), "a stale texture was used")
    return w
end)

case("Nil target hides and returns the frame to UIParent at once", function(t)
    local w = H.oreShown(t)
    w.target(nil, "GameObject-0-1-2-3-1731-0001")
    w.assertHidden()
    return w
end)

case("Removing the anchor plate hides at once; an unrelated removal does nothing", function(t, A)
    local w, plate = H.oreShown(t)
    w.addPlate("nameplate9", "Creature-X", nil)
    w.removePlate("nameplate9")
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate9")
    A.ok(w.shownOn(plate), "an unrelated plate removal hid the glow")
    A.eq(w.glow()._parent, plate, "an unrelated plate removal moved the glow")
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    w.removePlate("nameplate1")
    w.assertHidden()
    return w
end)

case("Re-enable after the soft target changed while off shows the new target", function(t, A)
    local w, a = H.oreShown(t)
    A.ok(w.shownOn(a), "the first target was not shown")
    w.restore()
    w.assertHidden()
    -- While off no events arrive; the game picked another object meanwhile.
    local b = w.addPlate("nameplate2", "GameObject-B", H.MINE)
    t.mock.units.softinteract = { exists = true, guid = "GameObject-B" }
    w.apply()
    A.ok(w.shownOn(b), "the new soft target was not shown after re-enable (stale GUID kept)")
    A.falsy(w.shownOn(a), "the stale target still shows the glow")
    return w
end)

case("Re-enable with no soft target any more shows nothing", function(t, A)
    local w = H.oreShown(t)
    w.restore()
    t.mock.units.softinteract = nil
    w.apply()
    A.ok(w.nothingShown(), "a stale target was shown after re-enable")
    return w
end)

case("Plates are never moved, faded, shown or hidden through a full cycle", function(t, A)
    local w, plate = H.oreShown(t)
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    w.combat(true)
    w.event("PLAYER_REGEN_DISABLED")
    w.combat(false)
    w.event("PLAYER_REGEN_ENABLED")
    local guid = "GameObject-0-1-2-3-1731-0001"
    w.target(nil, guid)
    w.target(guid)
    w.restore()
    A.ok(plate._alpha == 1 and plate._shown, "the plate changed state")
    A.eq(#plate.soft._points, 0, "the SoftTargetFrame was moved")
    return w
end)
