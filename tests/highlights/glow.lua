-- Highlights glow: the colour per category, which icon textures count, how the glow sits on the plate.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("Ore target with the mine icon shows a gold glow on its plate", function(t, A)
    local w, plate = H.oreShown(t)
    A.ok(w.shownOn(plate), "nothing is shown on the target plate")
    local root = w.glow()
    A.eq(root._parent, plate, "the glow is not parented to the plate")
    A.eq(#root._points, 1, "ClearAllPoints was not called before anchoring")
    local point = root._points[1]
    A.ok(point[1] == "CENTER" and point[2] == plate.soft and (point[3] == "CENTER" or point[3] == nil),
        "the glow is not anchored to the SoftTargetFrame center")
    A.ok(w.hasColor(root, H.ORE), "no texture uses the ore color 0.95, 0.75, 0.25")
    A.ok(root:GetFrameLevel() < plate.soft:GetFrameLevel(), "the glow frame level is not below the SoftTargetFrame")
    A.eq(root:IsMouseEnabled(), false, "the glow does not disable the mouse")
    A.ok(w.loopsPlaying(root), "no looping animation plays on the shown glow")
    w.assertNoErrors()
    return w
end)

case("Mixed-case mine texture is recognized", function(t, A)
    local w, plate = H.oreShown(t, "interface/cursor/CURSOR CROSSHAIR_MINE_64")
    A.ok(w.shownOn(plate), "upper-case mine texture was not recognized")
    w, plate = H.oreShown(t, "cursor crosshair_mine_64")
    A.ok(w.shownOn(plate), "lower-case mine texture was not recognized")
    return w
end)

case("Out-of-reach mine texture is recognized", function(t, A)
    local w, plate = H.oreShown(t, "Cursor Crosshair_UnableMine_64")
    A.ok(w.shownOn(plate), "the out-of-reach mine texture was not recognized")
    return w
end)

case("A non-crosshair texture containing mine shows nothing", function(t, A)
    local w, plate = H.oreShown(t, "Interface/Icons/INV_Misc_Determine_01")
    A.falsy(w.shownOn(plate), "a texture that only contains mine was treated as ore")
    return w
end)

case("Re-evaluating a shown glow does not restart its animations", function(t, A)
    local w = H.oreShown(t)
    local root = w.glow()
    local before = {}
    for i, g in ipairs(w.groups()) do before[i] = g._plays end
    w.target("GameObject-0-1-2-3-1731-0001", "GameObject-0-1-2-3-1731-0001")
    w.event("PLAYER_REGEN_ENABLED")
    for i, g in ipairs(w.groups()) do
        A.eq(g._plays, before[i], "an animation was played again on a glow that was already shown")
    end
    A.ok(w.loopsPlaying(root), "the glow stopped playing")
    return w
end)

case("GetAtlas is the fallback when GetTexture is empty", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", nil, { atlas = H.MINE })
    w.target("GameObject-A")
    A.ok(w.shownOn(plate), "the atlas fallback was not used")
    return w
end)

for _, c in ipairs({
    { "herb", H.HERBS },
    { "out-of-reach herb", H.HERBS_FAR },
    { "interact", H.GEAR },
    { "missing", nil },
    { "numeric", 136243 },
}) do
    case("Only Ore on and a " .. c[1] .. " texture shows nothing", function(t, A)
        local w = H.oreShown(t, c[2])
        w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
        A.ok(w.nothingShown(), "something was shown for a " .. c[1] .. " texture")
        return w
    end)
end

for _, c in ipairs({ { "herb", H.HERBS }, { "out-of-reach herb", H.HERBS_FAR },
    { "upper-case herb", "CURSOR CROSSHAIR_GATHERHERBS_64" } }) do
    case("Herbs on and a " .. c[1] .. " texture shows a green glow", function(t, A)
        local w = H.world(t, { flags = { herb = true } })
        w.apply()
        w.assertCVars(H.IDLE, "Herbs on")
        local plate = w.addPlate("nameplate1", "GameObject-H", c[2])
        w.target("GameObject-H")
        A.ok(w.shownOn(plate), "nothing is shown for a " .. c[1] .. " target")
        local root = w.glow()
        A.eq(root._parent, plate, "the herb glow is not parented to the plate")
        A.ok(w.hasColor(root, H.HERB), "no texture uses the herb color 0.30, 0.74, 0.40")
        A.falsy(w.hasColor(root, H.ORE), "the herb glow still uses the ore color")
        A.ok(w.loopsPlaying(root), "no looping animation plays on the herb glow")
        return w
    end)
end

case("Only Herbs on and the mine icon shows nothing", function(t, A)
    local w = H.world(t, { flags = { herb = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    A.ok(w.nothingShown(), "a mine target was highlighted with only Herbs on")
    return w
end)

case("Changing from an ore to a herb target switches the color", function(t, A)
    local w = H.world(t, { flags = { herb = true, ore = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    local herb = w.addPlate("nameplate2", "GameObject-H", H.HERBS)
    w.target("GameObject-H", "GameObject-A")
    A.ok(w.shownOn(herb), "the herb target was not shown")
    local root = w.glow()
    A.eq(root._parent, herb, "the glow did not move to the herb plate")
    A.ok(w.hasColor(root, H.HERB), "the color did not switch to herb green")
    return w
end)

case("Herb and Quest on show nothing for the mine icon", function(t, A)
    local w = H.world(t, { flags = { herb = true, quest = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    A.ok(w.nothingShown(), "a mine target was highlighted with Ore off")
    return w
end)

-- Generic interact objects keep the legacy quest flag.
for _, texture in ipairs({ "Cursor Crosshair_Interact_64", "CURSOR CROSSHAIR_INTERACT_64",
    "Cursor Crosshair_UnableInteract_64", "CURSOR CROSSHAIR_UNABLEINTERACT_64" }) do
    case("Interact objects recognizes " .. texture .. " with warm-white particles", function(t, A)
        local w = H.world(t, { flags = { quest = true } })
        w.apply()
        local plate = w.addPlate("nameplate1", "GameObject-Interact", texture)
        w.target("GameObject-Interact")
        A.ok(w.shownOn(plate), "the generic gear object was not highlighted")
        A.ok(w.hasColor(w.glow(), H.INTERACT), "the interact glow is not warm white")
        A.eq(plate.soft.Icon._alpha, 0, "the gear icon is still visible")
        A.ok(w.loopsPlaying(w.glow()), "the interact particles are not animated")
        w.restore()
        A.eq(plate.soft.Icon._alpha, 1, "the gear icon was not restored")
        return w
    end)
end

for _, texture in ipairs({ H.HERBS, H.MINE, H.SPEAK }) do
    case("Only Interact objects does not highlight " .. texture, function(t, A)
        local w = H.world(t, { flags = { quest = true }, cvars = H.ICONS_ON })
        w.apply()
        local plate = w.addPlate("nameplate1", "GameObject-Other", texture)
        w.target("GameObject-Other")
        A.ok(w.nothingShown(), "an unrelated category was highlighted")
        A.eq(plate.soft.Icon._alpha, 1, "an unrelated icon was hidden")
        return w
    end)
end

case("The aura uses glow, glints and sparks textures with the expected counts, all on disk", function(t, A)
    local w, plate = H.oreShown(t)
    local root = w.glow()
    A.eq(root._parent, plate, "the glow was not shown")
    local glow, spark, round, glint = 0, 0, 0, 0
    for _, tex in ipairs(w.textures(root)) do
        if type(tex._texture) == "string" then
            local path = tex._texture:lower()
            if path == "interface\\addons\\quietui\\media\\glow.tga" then glow = glow + 1 end
            if path == "interface\\addons\\quietui\\media\\spark.tga" then spark = spark + 1 end
            if path == "interface\\addons\\quietui\\media\\glint.tga" then glint = glint + 1 end
            A.falsy(path:find("ripple.tga", 1, true), "the unwanted ground ripple is still present")
            if path:find("round.tga", 1, true) then round = round + 1 end
        end
    end
    A.ok(glow >= 1, "no aura texture uses Media/glow.tga")
    A.eq(spark, 6, "expected six small motes")
    A.eq(glint, 5, "expected five four-point glints")
    A.eq(round, 0, "the glow still uses Media/round.tga")
    for _, file in ipairs({ "Media/glow.tga", "Media/spark.tga", "Media/glint.tga" }) do
        A.ok(t.fileExists(file), file .. " does not exist")
    end
    return w
end)
