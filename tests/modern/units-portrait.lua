-- Modern unit frames: every portrait is held, the target's rarity on its bar box border (retail 12.0).
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("every unit portrait is held at alpha 0 in place", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for i = 1, #frames do
        local f = frames[i]
        local p = U.parts(f).portrait
        A.alpha(p, 0, f:GetName() .. " portrait held")
        p:SetAlpha(1)
        A.alpha(p, 0, f:GetName() .. " Blizzard cannot show it again")
        p:SetAlphaFromBoolean(true, 1, 0.55)
        A.alpha(p, 0, f:GetName() .. " SetAlphaFromBoolean cannot show it again")
        A.eq(p:GetNumPoints(), 0, f:GetName() .. " portrait not moved")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do
        A.alpha(U.parts(f).portrait, 1, f:GetName() .. " portrait visible after restore")
    end
end)

h.test("portraits stay hidden when Blizzard sets their vertex colour every frame", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for i = 1, #frames do
        local p = U.parts(frames[i]).portrait
        p:SetVertexColor(1, 1, 1, 1)
        A.alpha(p, 0, frames[i]:GetName() .. " portrait hidden after a white vertex colour")
        p:SetVertexColor(0.35, 0.35, 0.35, 1)
        A.alpha(p, 0, frames[i]:GetName() .. " portrait hidden after the dead grey")
    end
    ns.Modern.Restore()
    for _, i in ipairs({ 2, 4 }) do
        local p = U.parts(frames[i]).portrait
        p:SetVertexColor(1, 1, 1, 1)
        A.alpha(p, 1, frames[i]:GetName() .. " portrait left alone while off")
    end
end)

h.test("the resting glow around the player frame is held hidden", function(t)
    local A, ns = t.assert, t.ns
    local status = U.parts(U.frames()[1]).status
    enable(ns)
    status:Show(); status:SetAlpha(1)
    A.alpha(status, 0, "Blizzard showing the resting glow cannot undo the hold")
    ns.Modern.Restore()
    A.alpha(status, 1, "resting glow released")
end)

h.test("target box border is gold for elite, silver for rare, red for bosses and themed otherwise", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = U.frames()[3]
    U.installColours(mock)
    enable(ns)
    for _, spec in ipairs({
        { "elite", { 0.95, 0.75, 0.25 } },
        { "rare", { 0.85, 0.85, 0.85 } },
        { "rareelite", { 0.85, 0.85, 0.85 } },
        { "worldboss", { 0.9, 0.15, 0.15 } },
        { "boss", { 0.9, 0.15, 0.15 } },
        { "normal", { 0, 0, 0 } },
    }) do
        mock:setUnit("target", { exists = true, player = false, classification = spec[1] })
        mock:fire("PLAYER_TARGET_CHANGED")
        local c = U.boxBorderColor(target)
        A.ok(c, spec[1] .. " box border exists")
        A.deep({ c[1], c[2], c[3] }, spec[2], spec[1] .. " box border")
    end
end)

h.test("other units keep the dark box border whatever the target is", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    mock:setUnit("target", { exists = true, player = false, classification = "elite" })
    enable(ns)
    mock:fire("PLAYER_TARGET_CHANGED")
    for _, i in ipairs({ 1, 2, 4, 5 }) do
        local c = U.boxBorderColor(frames[i])
        A.ok(c, frames[i]:GetName() .. " border")
        A.deep({ c[1], c[2], c[3] }, { 0, 0, 0 }, frames[i]:GetName() .. " dark border")
    end
end)
