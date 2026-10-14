-- The micro button list is rebuilt by RefreshChrome, not by every hover tick.
local h = ...

local NAMES = { "CharacterMicroButton", "SpellbookMicroButton", "QuestLogMicroButton",
    "MainMenuMicroButton", "HelpMicroButton" }

-- Micro buttons live behind an __index proxy on _G so every name lookup is counted.
-- The proxy is always removed again, whatever the test does.
local function withMicroGlobals(t, body)
    local served, state = {}, { reads = 0 }
    for _, name in ipairs(NAMES) do
        local b = CreateFrame("Button", name, UIParent)
        b:SetMouseOver(false)
        served[name] = b
    end
    local function install()
        setmetatable(_G, { __index = function(_, key)
            if type(key) == "string" and key:find("MicroButton$") then state.reads = state.reads + 1 end
            return served[key]
        end })
    end
    t.boot()
    install()
    local ok, err = pcall(body, served, state)
    setmetatable(_G, nil)
    if not ok then error(err, 0) end
end

h.test("Hover ticks between two RefreshChrome calls do not rebuild the micro list", function(t)
    local A, ns = t.assert, t.ns
    withMicroGlobals(t, function(served, state)
        ns.RefreshChrome()
        for _, b in pairs(served) do b:SetMouseOver(true) end
        ns.UpdateMenuButton(0.016)
        state.reads = 0
        for _ = 1, 60 do ns.UpdateMenuButton(0.016) end
        A.eq(state.reads, 0, "micro global reads during 60 hover ticks")
        ns.RefreshChrome()
        A.alpha(served.CharacterMicroButton, 1, "hover keeps the first micro button shown")
        A.alpha(served.HelpMicroButton, 1, "hover keeps the last micro button shown")
    end)
end)

h.test("A micro button added before UpdateMicroButtons joins the cache and the fade", function(t)
    local A, ns = t.assert, t.ns
    withMicroGlobals(t, function(served)
        ns.RefreshChrome()
        ns.NextFadeTick()
        ns.UpdateMenuButton(0.016)
        local added = CreateFrame("Button", "HousingMicroButton", UIParent)
        served.HousingMicroButton = added
        -- QuietUI hooks UpdateMicroButtons to rebuild the cache.
        UpdateMicroButtons()
        added:SetAlpha(1)
        ns.NextFadeTick()
        ns.UpdateMenuButton(0.5)
        A.alpha(added, 0, "new micro button fades with the menu")
        for _, b in pairs(served) do b:SetMouseOver(true) end
        ns.NextFadeTick()
        ns.UpdateMenuButton(0.016)
        A.alpha(added, 1, "new micro button shows on hover with the menu")
    end)
end)
