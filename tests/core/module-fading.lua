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

local function spyMethods(ns, entries)
    local counts = {}
    for _, entry in ipairs(entries) do
        local owner, name = entry[1], entry[2]
        local tableRef = owner == "ns" and ns or ns[owner]
        local original = tableRef[name]
        local label = owner == "ns" and name or (owner .. "." .. name)
        counts[label] = 0
        tableRef[name] = function(...)
            counts[label] = counts[label] + 1
            if original then return original(...) end
        end
    end
    return counts
end

local function zeroCounts(counts)
    for k in pairs(counts) do counts[k] = 0 end
end

local function shownBubble(chat, text)
    for _, child in ipairs(chat._children) do
        if child:IsShown() then
            for _, region in ipairs(child._regions) do
                if region._kind == "FontString" and region._text == text then return child end
            end
        end
    end
end

local function chatCatcher(mock)
    for _, f in ipairs(mock.frames) do
        if f._parent == UIParent and f._kind == "Frame" and f._scripts.OnMouseWheel then return f end
    end
end

local function stepFrames(mock, count, elapsed, onTick)
    for i = 1, count do
        mock.now = mock.now + elapsed
        if onTick then onTick(i) end
        mock:tick(elapsed)
    end
end

h.test("Only chat enabled: OnUpdate ticks and 1-second rescans skip fading/world work and disabled callbacks while chat bubbles and hover work", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = {
        welcomed = true,
        chatFade = 5,
        modules = { chat = true, fading = false, helpers = false, layout = false, modernize = false },
    }
    ChatFrame1:SetSize(300, 150)

    local probe = { frame = 0, tick = 0, rescan = 0, fade = 0 }
    ns.Feature({
        name = "disabledWiringProbe",
        enabled = function() return false end,
        frame = function() probe.frame = probe.frame + 1 end,
        tick = function() probe.tick = probe.tick + 1 end,
        rescan = function() probe.rescan = probe.rescan + 1 end,
        fade = function() probe.fade = probe.fade + 1 end,
    })

    local calls = spyMethods(ns, {
        { "World", "RefreshWorld" },
        { "Registry", "Fade" },
        { "Bars", "Update" },
        { "Bars", "ScanSwing" },
        { "Bars", "ForgetButtons" },
        { "Faders", "Update" },
        { "Faders", "UpdateRange" },
        { "Faders", "UpdateSmooth" },
        { "Faders", "Find" },
        { "Menu", "UpdateButton" },
        { "Menu", "UpdateBagSlots" },
        { "Menu", "RefreshChrome" },
        { "QuestNotice", "Update" },
        { "ns", "FocusChanged" },
    })

    local cursorInfoCalls = 0
    local origCursorInfo = GetCursorInfo
    GetCursorInfo = function(...)
        cursorInfoCalls = cursorInfoCalls + 1
        return origCursorInfo(...)
    end

    t.boot()
    local bootWorldCalls = calls["World.RefreshWorld"]

    zeroCounts(calls)
    zeroCounts(probe)
    cursorInfoCalls = 0

    ChatFrame1:AddMessage("hello chat", 1, 1, 1)
    stepFrames(mock, 15, 0.1, function(i)
        if i <= 3 then mock.state.cursor = { i, i } end
    end)

    local bubble = shownBubble(ChatFrame1, "hello chat")
    A.ok(bubble, "chat bubble should appear with only chat enabled")
    A.near(bubble:GetAlpha(), 1, 0.01, "fresh chat bubble stays opaque")
    local catcher = chatCatcher(mock)
    A.ok(catcher and catcher:IsShown(), "chat wheel catcher should be shown")

    mock.now = mock.now + 6
    stepFrames(mock, 10, 0.1)
    A.falsy(shownBubble(ChatFrame1, "hello chat"), "expired chat bubble hides before hover test")

    -- Drive hover purely through cursor move + mouseFocus (IsMouseOver stays false),
    -- so FocusChanged + PointerMoved + Hit must all run in OnUpdate.
    mock.state.cursor = { 10, 10 }
    mock.state.mouseFocus = catcher
    stepFrames(mock, 1, 0.05)
    A.eq(ns.PointerMoved(), true, "PointerMoved should report cursor movement")
    A.eq(ns.Hit(catcher), true, "Hit should match focused chat catcher")
    A.ok(calls["FocusChanged"] > 0, "FocusChanged should run when chat is enabled")
    local hovered = shownBubble(ChatFrame1, "hello chat")
    A.ok(hovered and hovered:GetAlpha() == 1, "hovering focused chat catcher reveals expired chat bubble")

    stepFrames(mock, 1, 0.05)
    A.eq(ns.PointerMoved(), false, "PointerMoved should clear when cursor stays still")

    mock.state.cursor = { 20, 20 }
    mock.state.mouseFocus = nil
    stepFrames(mock, 1, 0.1)
    A.eq(ns.Hit(catcher), false, "Hit should clear when mouse focus leaves catcher")

    A.eq(calls["World.RefreshWorld"], 0, "OnUpdate/rescan must not call World.RefreshWorld")
    A.eq(bootWorldCalls, 0, "BootScan must skip World.RefreshWorld when fading is off")
    A.eq(calls["Registry.Fade"], 0, "OnUpdate must not call Registry.Fade")
    A.eq(cursorInfoCalls, 0, "OnUpdate must not call GetCursorInfo")
    for _, key in ipairs({
        "Bars.Update", "Bars.ScanSwing", "Bars.ForgetButtons",
        "Faders.Update", "Faders.UpdateRange", "Faders.UpdateSmooth", "Faders.Find",
        "Menu.UpdateButton", "Menu.UpdateBagSlots", "Menu.RefreshChrome",
        "QuestNotice.Update",
    }) do
        A.eq(calls[key], 0, key .. " must not run when disabled")
    end
    A.deep(probe, { frame = 0, tick = 0, rescan = 0, fade = 0 }, "disabled feature callbacks must not run")
end)

h.test("Fading and chat both off: OnUpdate does not poll GetCursorPosition or GetMouseFoci", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = {
        welcomed = true,
        modules = { chat = false, fading = false, helpers = true, layout = false, modernize = false },
    }

    local calls = spyMethods(ns, { { "QuestNotice", "Update" } })
    local cursorPosCalls, fociCalls, focusCalls = 0, 0, 0
    local origPos, origFoci, origFocus = GetCursorPosition, GetMouseFoci, GetMouseFocus
    GetCursorPosition = function(...)
        cursorPosCalls = cursorPosCalls + 1
        return origPos(...)
    end
    GetMouseFoci = function(...)
        fociCalls = fociCalls + 1
        return origFoci(...)
    end
    GetMouseFocus = function(...)
        focusCalls = focusCalls + 1
        return origFocus(...)
    end

    t.boot()
    calls["QuestNotice.Update"] = 0
    cursorPosCalls, fociCalls, focusCalls = 0, 0, 0

    stepFrames(mock, 15, 0.1, function(i)
        mock.state.cursor = { i, i }
        mock.state.mouseFocus = UIParent
    end)

    A.eq(cursorPosCalls, 0, "OnUpdate must not poll GetCursorPosition when fading and chat are off")
    A.eq(fociCalls, 0, "OnUpdate must not poll GetMouseFoci when fading and chat are off")
    A.eq(focusCalls, 0, "OnUpdate must not poll GetMouseFocus when fading and chat are off")
    A.ok(calls["QuestNotice.Update"] > 0, "enabled helpers frame phase still runs in OnUpdate")
end)

h.test("Fading off at boot: Glance.EnsureBinding does not run or bind a key", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true, modules = { fading = false } }

    local calls = spyMethods(ns, { { "Glance", "EnsureBinding" } })
    local bound = {}
    SetBinding = function(key, action)
        bound[#bound + 1] = { key, action }
        GetBindingKey = function(name) if name == action then return key end end
        return true
    end

    t.boot()
    A.eq(calls["Glance.EnsureBinding"], 0, "Glance.EnsureBinding must not be called when fading is off")
    A.eq(#bound, 0, "SetBinding must not be called when fading is off")
end)

h.test("Fading on at boot: Glance.EnsureBinding binds the default Glance key", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }

    local calls = spyMethods(ns, { { "Glance", "EnsureBinding" } })
    local bound = {}
    SetBinding = function(key, action)
        bound[#bound + 1] = { key, action }
        GetBindingKey = function(name) if name == action then return key end end
        return true
    end

    t.boot()
    A.ok(calls["Glance.EnsureBinding"] >= 1, "Glance.EnsureBinding runs at boot when fading is on")
    A.deep(bound, { { "`", "QUIETUI_GLANCE" } }, "default Glance key is bound when free")
end)

h.test("Off at boot, then /quiet on: the default Glance key is bound", function(t)
    local A = t.assert
    QuietUIDB = { enabled = false }
    QuietUICharDB = { welcomed = true }
    local bound = {}
    SetBinding = function(key, action)
        bound[#bound + 1] = { key, action }
        GetBindingKey = function(name) if name == action then return key end end
        return true
    end

    t.boot()
    A.eq(#bound, 0, "nothing is bound while QuietUI is off")
    SlashCmdList.QUIETUI("on")
    A.deep(bound, { { "`", "QUIETUI_GLANCE" } }, "/quiet on binds the free Glance key")
end)
