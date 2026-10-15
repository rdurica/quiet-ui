-- Modern unit frames: square portraits, removed masks and rarity borders on the retail 12.0 structure.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("portraits are cropped square, masks come off and return on restore", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    for _, f in ipairs(frames) do
        A.eq(U.parts(f).portrait:GetNumMaskTextures(), 1, f:GetName() .. " fixture has a portrait mask")
    end
    enable(ns)
    for _, f in ipairs(frames) do
        local p = U.parts(f).portrait
        A.deep({ p:GetTexCoord() }, { 0.08, 0.92, 0.08, 0.92 }, f:GetName() .. " square crop")
        A.eq(p:GetNumMaskTextures(), 0, f:GetName() .. " portrait mask removed")
        A.ok(U.portraitBorder(f), f:GetName() .. " portrait border")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do
        local parts = U.parts(f)
        A.deep({ parts.portrait:GetTexCoord() }, { 0, 1, 0, 1 }, f:GetName() .. " crop restored")
        A.eq(parts.portrait:GetNumMaskTextures(), 1, f:GetName() .. " mask count restored")
        A.eq(parts.portrait:GetMaskTexture(1), parts.mask, f:GetName() .. " same mask restored")
        A.ok(not U.portraitBorder(f), f:GetName() .. " portrait border hidden")
    end
end)

h.test("target portrait border is gold for elite, silver for rare, red for bosses and themed otherwise", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = U.frames()[3]
    U.installColours(mock)
    enable(ns)
    local theme = ns.Modern.Theme().border
    for _, spec in ipairs({
        { "elite", { 0.95, 0.75, 0.25 } },
        { "rare", { 0.85, 0.85, 0.85 } },
        { "rareelite", { 0.85, 0.85, 0.85 } },
        { "worldboss", { 0.9, 0.15, 0.15 } },
        { "boss", { 0.9, 0.15, 0.15 } },
        { "normal", { theme[1], theme[2], theme[3] } },
    }) do
        mock:setUnit("target", { exists = true, player = false, classification = spec[1] })
        mock:fire("PLAYER_TARGET_CHANGED")
        local c = U.portraitBorderColor(target)
        A.ok(c, spec[1] .. " portrait border exists")
        A.deep({ c[1], c[2], c[3] }, spec[2], spec[1] .. " portrait border")
    end
end)

h.test("non-target portraits keep the theme border whatever the target is", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    mock:setUnit("target", { exists = true, player = false, classification = "elite" })
    enable(ns)
    mock:fire("PLAYER_TARGET_CHANGED")
    local theme = ns.Modern.Theme().border
    for _, i in ipairs({ 1, 2, 4 }) do
        local c = U.portraitBorderColor(frames[i])
        A.ok(c, frames[i]:GetName() .. " border")
        A.deep({ c[1], c[2], c[3] }, { theme[1], theme[2], theme[3] }, frames[i]:GetName() .. " theme border")
    end
end)
