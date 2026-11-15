-- Fading module (settings.modules.fading): off means bars, faders, menu and glance apply nothing,
-- change no alpha, run no hooks and ignore Glance. Missing means on.
local h = ...

local COUNTED = {
    { "Bars", "ForgetButtons" }, { "Bars", "ScanSwing" }, { "Faders", "Find" }, { "Faders", "UpdateParty" },
    { "Menu", "RefreshChrome" }, { "Menu", "UpdateBagSlots" },
}

-- Counts calls to the public functions the Fading features run when they apply (and the boot scan).
local function spy(ns)
    local calls = {}
    for _, entry in ipairs(COUNTED) do
        local owner, name = ns[entry[1]], entry[2]
        local original = owner[name]
        local label = entry[1] .. "." .. name
        calls[label] = 0
        owner[name] = function(...)
            calls[label] = calls[label] + 1
            return original(...)
        end
    end
    return calls
end

local function start(t, modules)
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modules = modules }
    local calls = spy(t.ns)
    t.boot()
    return calls
end

local HUD = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "StanceBar", "PetActionBar", "MicroMenu", "BagsBar", "PlayerFrame", "PetFrame", "MainStatusTrackingBarContainer",
    "ObjectiveTrackerFrame", "BuffFrame", "MinimapCluster" }

local function settle(t)
    for _ = 1, 30 do t.mock:tick(0.1) end
    t.mock:drain()
end

h.test("Fading on (missing): boot and ApplyAll run the bars, faders and menu applies and the boot scan", function(t)
    local calls = start(t, nil)
    t.ns.ApplyAll()
    for label, n in pairs(calls) do t.assert.ok(n > 0, label .. " ran with Fading on") end
end)

h.test("Fading off: boot and ApplyAll call no apply of bars, faders, menu or glance and no boot scan", function(t)
    local calls = start(t, { fading = false })
    t.ns.ApplyAll()
    settle(t)
    for label, n in pairs(calls) do t.assert.eq(n, 0, label .. " must not run with Fading off") end
end)

h.test("Fading off: no action bar, HUD element, player frame or micro menu gets a changed alpha", function(t)
    local A = t.assert
    start(t, { fading = false })
    t.ns.ApplyAll()
    settle(t)
    t.mock.state.combat = true
    t.mock:fire("PLAYER_REGEN_DISABLED")
    settle(t)
    t.mock.state.combat = false
    t.mock:fire("PLAYER_REGEN_ENABLED")
    settle(t)
    for _, name in ipairs(HUD) do
        local frame = _G[name]
        if frame then A.alpha(frame, 1, name .. " alpha changed with Fading off") end
    end
end)

h.test("Fading on: the same run does fade the action bar, so the alpha test above can fail", function(t)
    start(t, nil)
    t.ns.ApplyAll()
    settle(t)
    t.assert.alpha(MainActionBar, 0, "bar hidden out of combat with Fading on")
end)

h.test("Fading off: a hook of a Fading feature does nothing when its global runs", function(t)
    local A = t.assert
    local calls = start(t, { fading = false })
    UpdateMicroButtons()
    A.eq(calls["Menu.RefreshChrome"], 0, "UpdateMicroButtons hook ran with Fading off")
end)

h.test("Fading on: the UpdateMicroButtons hook rebuilds the micro chrome", function(t)
    local A = t.assert
    local calls = start(t, nil)
    local before = calls["Menu.RefreshChrome"]
    UpdateMicroButtons()
    A.ok(calls["Menu.RefreshChrome"] > before, "hook ran with Fading on")
end)

h.test("Fading off: Glance toggle by API, key and /quiet glance changes nothing", function(t)
    local A, ns = t.assert, t.ns
    start(t, { fading = false })
    ns.Glance.Toggle()
    A.falsy(ns.Glance.Active(), "Glance.Toggle")
    QuietUIGlance("down")
    A.falsy(ns.Glance.Active(), "key")
    SlashCmdList.QUIETUI("glance")
    A.falsy(ns.Glance.Active(), "/quiet glance")
    A.ok(QuietUIDB.enabled, "/quiet glance must not turn QuietUI off either")
end)

h.test("Fading on: Glance toggle still works through the same three routes", function(t)
    local A, ns = t.assert, t.ns
    start(t, nil)
    ns.Glance.Toggle()
    A.ok(ns.Glance.Active(), "Glance.Toggle")
    QuietUIGlance("down")
    A.falsy(ns.Glance.Active(), "key")
    SlashCmdList.QUIETUI("glance")
    A.ok(ns.Glance.Active(), "/quiet glance")
end)

h.test("Fading turned off while Glance is active: restore clears it and it stays off", function(t)
    local A, ns = t.assert, t.ns
    start(t, nil)
    ns.Glance.Toggle()
    QuietUICharDB.modules = { fading = false }
    ns.RestoreAll()
    A.falsy(ns.Glance.Active(), "restore clears Glance")
    ns.Glance.Toggle()
    A.falsy(ns.Glance.Active(), "no toggle after the module is off")
end)
