-- Per-frame catcher writes and bar ownership passes stay out of the steady state.
local h = ...

-- Counts the layout writes every frame created from now on receives.
local function countLayoutWrites()
    local made = {}
    local create = CreateFrame
    CreateFrame = function(...)
        local f = create(...)
        local entry = { frame = f, strata = 0, level = 0 }
        local setStrata, setLevel = f.SetFrameStrata, f.SetFrameLevel
        f.SetFrameStrata = function(self, v) entry.strata = entry.strata + 1; return setStrata(self, v) end
        f.SetFrameLevel = function(self, v) entry.level = entry.level + 1; return setLevel(self, v) end
        made[#made + 1] = entry
        return f
    end
    return made
end

h.test("Quest catcher keeps strata and level writes out of a stable tracker", function(t)
    local A, ns = t.assert, t.ns
    local made = countLayoutWrites()
    t.boot()
    ns.Faders.Find(false)
    for _ = 1, 60 do ns.Faders.Update(0.016) end
    local catcher
    for _, entry in ipairs(made) do
        local point = entry.frame._points[1]
        if point and point[1] == "ALL" and point[2] == ObjectiveTrackerFrame then catcher = entry end
    end
    A.ok(catcher, "quest catcher was not placed over the tracker")
    A.shown(catcher.frame, true, "quest catcher")
    A.ok(catcher.strata <= 1, "stable tracker repeated SetFrameStrata: " .. catcher.strata)
    A.ok(catcher.level <= 1, "stable tracker repeated SetFrameLevel: " .. catcher.level)
    local level = catcher.level
    ObjectiveTrackerFrame:SetFrameLevel(9)
    ns.Faders.Update(0.016)
    A.eq(catcher.level, level + 1, "changed tracker level reaches the catcher once")
    A.eq(catcher.frame:GetFrameLevel(), 8, "catcher sits one level under the tracker")
end)

-- Bar fixture: MainMenuBar hosts MultiBarBottomLeft; MultiBarRight stands alone.
local function bars(t)
    t.boot()
    MultiBarBottomLeft:SetParent(MainMenuBar)
    return function()
        t.ns.NextFadeTick()
        t.ns.Bars.Update(false, 1, true)
    end
end

h.test("Stable bars skip the owner ancestry pass after the first Collect", function(t)
    local A, ns = t.assert, t.ns
    local tick = bars(t)
    local ids = {}
    for _, row in ipairs(ns.BAR_ROWS) do ids[row.id] = true end
    -- The owner pass is only visible as pairs() over the bar -> row id map.
    local ownerWalks = 0
    local realPairs = pairs
    pairs = function(tbl)
        local key, value = next(tbl)
        if type(key) == "table" and type(value) == "string" and ids[value] then ownerWalks = ownerWalks + 1 end
        return realPairs(tbl)
    end
    local ok, err = pcall(function()
        ns.Bars.ForgetButtons()
        tick()
        A.ok(ownerWalks > 0, "the spy must see the first Collect pass")
        ownerWalks = 0
        for _ = 1, 59 do tick() end
    end)
    pairs = realPairs
    A.ok(ok, err)
    A.eq(ownerWalks, 0, "owner walks in 59 stable ticks")
end)

h.test("ForgetBarButtons recomputes hosting; a bar nested in MainMenuBar still fades alone", function(t)
    local A, ns = t.assert, t.ns
    local tick = bars(t)
    ns.Bars.ForgetButtons()
    tick()
    A.alpha(MainMenuBar, 1, "hosting MainMenuBar stays opaque")
    A.alpha(MultiBarBottomLeft, 0, "nested bar fades")
    A.alpha(MultiBarRight, 0, "standalone bar fades")
    -- Raw reparent bypasses the SetParent hook; only ForgetBarButtons may refresh the maps.
    MultiBarBottomLeft._parent = UIParent
    ns.Bars.ForgetButtons()
    tick()
    A.alpha(MainMenuBar, 0, "MainMenuBar kept stale hosting after ForgetBarButtons")
    MultiBarBottomLeft._parent = MainMenuBar
    ns.Bars.ForgetButtons()
    MultiBarBottomLeft:SetAlpha(1)
    MultiBarBottomLeft._quietAlpha = nil
    tick()
    A.alpha(MainMenuBar, 1, "re-nested MainMenuBar is a host again")
    A.alpha(MultiBarBottomLeft, 0, "nested bar keeps fading on its own")
end)
