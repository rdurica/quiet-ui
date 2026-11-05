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
        ns.Menu.RefreshChrome()
        for _, b in pairs(served) do b:SetMouseOver(true) end
        ns.Menu.UpdateButton(0.016)
        state.reads = 0
        for _ = 1, 60 do ns.Menu.UpdateButton(0.016) end
        A.eq(state.reads, 0, "micro global reads during 60 hover ticks")
        ns.Menu.RefreshChrome()
        A.alpha(served.CharacterMicroButton, 1, "hover keeps the first micro button shown")
        A.alpha(served.HelpMicroButton, 1, "hover keeps the last micro button shown")
    end)
end)

h.test("A micro button added before UpdateMicroButtons joins the cache and the fade", function(t)
    local A, ns = t.assert, t.ns
    withMicroGlobals(t, function(served)
        ns.Menu.RefreshChrome()
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.016)
        local added = CreateFrame("Button", "HousingMicroButton", UIParent)
        served.HousingMicroButton = added
        -- QuietUI hooks UpdateMicroButtons to rebuild the cache.
        UpdateMicroButtons()
        added:SetAlpha(1)
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.5)
        A.alpha(added, 0, "new micro button fades with the menu")
        for _, b in pairs(served) do b:SetMouseOver(true) end
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.016)
        A.alpha(added, 1, "new micro button shows on hover with the menu")
    end)
end)

h.test("Hover passes read the micro corners at most every 0.1 s and skip a settled walk", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    withMicroGlobals(t, function(served)
        ns.Menu.RefreshChrome()
        for _, b in pairs(served) do b:SetMouseOver(true) end
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.016)
        local first = served.CharacterMicroButton
        local edges, faded = 0, 0
        local left = first.GetLeft
        first.GetLeft = function(self) edges = edges + 1; return left(self) end
        local update = ns.UpdateFaded
        ns.UpdateFaded = function(frame, ...)
            if frame == first then faded = faded + 1 end
            return update(frame, ...)
        end
        for _ = 1, 30 do
            ns.NextFadeTick()
            ns.Menu.UpdateButton(0.016)
        end
        A.eq(edges, 0, "the micro corners were read on every hover pass")
        A.eq(faded, 0, "a settled micro menu walked its buttons on every pass")
        mock.now = mock.now + 0.11
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.016)
        A.ok(edges > 0 and faded > 0, "the periodic placement and walk stopped")
        for _, b in pairs(served) do b:SetMouseOver(false) end
        ns.NextFadeTick()
        ns.Menu.UpdateButton(0.016)
        A.ok(first:GetAlpha() < 1, "leaving the menu did not start the fade at once")
        ns.UpdateFaded = update
    end)
end)
