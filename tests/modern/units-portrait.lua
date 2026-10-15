-- Modern unit frames: no portraits, the target's rarity on its health bar border (retail 12.0 structure).
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("portraits are held at alpha 0 in place and return on restore", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
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
        A.alpha(U.parts(f).portrait, 1, f:GetName() .. " portrait released")
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

h.test("target health border is gold for elite, silver for rare, red for bosses and themed otherwise", function(t)
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
        local c = U.borderColor(U.parts(target).health)
        A.ok(c, spec[1] .. " health border exists")
        A.deep({ c[1], c[2], c[3] }, spec[2], spec[1] .. " health border")
        local m = U.borderColor(U.parts(target).mana)
        A.deep({ m[1], m[2], m[3] }, { theme[1], theme[2], theme[3] }, spec[1] .. " power border stays themed")
    end
end)

h.test("other units keep the theme health border whatever the target is", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    mock:setUnit("target", { exists = true, player = false, classification = "elite" })
    enable(ns)
    mock:fire("PLAYER_TARGET_CHANGED")
    local theme = ns.Modern.Theme().border
    for _, i in ipairs({ 1, 2, 4, 5 }) do
        local c = U.borderColor(U.parts(frames[i]).health)
        A.ok(c, frames[i]:GetName() .. " border")
        A.deep({ c[1], c[2], c[3] }, { theme[1], theme[2], theme[3] }, frames[i]:GetName() .. " theme border")
    end
end)
