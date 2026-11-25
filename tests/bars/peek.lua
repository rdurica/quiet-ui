-- Gamepad peek: a held trigger or shoulder button shows one zone of the faded gamepad bar.
local h = ...

local PAGE = "GamepadMainActionBarFramePageUnit"
local BUTTONS = { "PADLTRIGGER", "PADRTRIGGER", "PADLSHOULDER", "PADRSHOULDER" }

local function named(name, parent)
    local frame = CreateFrame("Frame", name, parent)
    _G[name] = frame
    return frame
end

-- The gamepad bar as the client builds it: zones under the page unit, the stance bar under the top anchor.
local function gamepad()
    local bar = named("GamepadMainActionBarFrame", UIParent)
    local page = named(PAGE, bar)
    local top = named(PAGE .. "TopCenteredAnchor", page)
    local z = {
        left = named(PAGE .. "LeftCenteredAnchor", page),
        right = named(PAGE .. "RightCenteredAnchor", page),
        bottom = named(PAGE .. "BottomCenteredAnchor", page),
        top = named(PAGE .. "TopCenteredAnchorTopBar", top),
        stance = named(PAGE .. "TopCenteredAnchorStanceBar", top),
    }
    CreateFrame("Button", nil, z.top)
    -- Unnamed "RB + RT" hint under the right class action, and the LB/RB icons drawn on the page.
    z.hint = CreateFrame("Frame", nil, page)
    z.icon = page:CreateTexture()
    local centre = function(x) return function() return x, 100 end end
    z.left.GetCenter, z.bottom.GetCenter, z.right.GetCenter = centre(445), centre(640), centre(835)
    z.hint.GetCenter = centre(778)
    return bar, z
end

local function pad()
    local held = { polls = 0 }
    C_GamePad = {
        GetActiveDeviceID = function() return 1 end,
        GetDeviceMappedState = function()
            held.polls = held.polls + 1
            local buttons = {}
            for i, name in ipairs(BUTTONS) do buttons[i] = held[name] == true end
            return { buttons = buttons }
        end,
        ButtonIndexToBinding = function(index) return BUTTONS[index + 1] end,
    }
    return held
end

local function boot(t)
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local bar, z = gamepad()
    local held = pad()
    t.boot()
    return bar, z, held
end

-- Enough real ticks for a poll, the pass it triggers, and a full fade out.
local function settle(t)
    for _ = 1, 8 do t.mock:tick(0.1) end
end

local function zones(A, z, want, label)
    for _, key in ipairs({ "left", "right", "bottom", "top", "stance" }) do
        A.alpha(z[key], want[key] or 0, label .. ": " .. key)
    end
end

h.test("LT shows only the left zone", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    settle(t)
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "LT did not show the gamepad bar")
    zones(A, z, { left = 1 }, "LT")
end)

h.test("RT shows the right zone with the stance bar", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    settle(t)
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "RT did not show the gamepad bar")
    zones(A, z, { right = 1, stance = 1 }, "RT")
end)

h.test("a shoulder button shows the centre, both triggers add the LT+RT bar", function(t)
    local A = t.assert
    local _, z, held = boot(t)
    settle(t)
    held.PADLTRIGGER, held.PADRTRIGGER = true, true
    settle(t)
    zones(A, z, { top = 1, bottom = 1 }, "LT+RT")
    held.PADLTRIGGER, held.PADRTRIGGER = nil, nil
    held.PADRSHOULDER = true
    settle(t)
    zones(A, z, { top = 1 }, "RB")
    held.PADRSHOULDER = nil
    held.PADLSHOULDER = true
    settle(t)
    zones(A, z, { top = 1 }, "LB")
    held.PADLSHOULDER = nil
    held.PADRSHOULDER = true
    held.PADRTRIGGER = true
    settle(t)
    zones(A, z, { right = 1, stance = 1, top = 1 }, "RB+RT")
end)

h.test("unclassified page parts follow their zone and are never forced visible", function(t)
    local A = t.assert
    local _, z, held = boot(t)
    z.icon:SetAlpha(0.4)
    settle(t)
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(z.hint, 0, "LT showed the RB + RT hint of the right zone")
    A.alpha(z.icon, 0, "LT showed the shoulder icons of the centre")
    held.PADLTRIGGER = nil
    held.PADRSHOULDER = true
    settle(t)
    A.alpha(z.hint, 0, "RB showed the RB + RT hint of the right zone")
    A.alpha(z.icon, 0.4, "RB did not give the shoulder icons back their own alpha")
    held.PADRSHOULDER = nil
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(z.hint, 1, "RT hid the RB + RT hint")
    A.alpha(z.icon, 0, "RT showed the shoulder icons of the centre")
end)

h.test("the radial menu opened by Start turns peek off", function(t)
    local A = t.assert
    local bar, _, held = boot(t)
    local menu = named("GamepadRadial", UIParent)
    menu:Hide()
    settle(t)
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "RT did not show the gamepad bar with the radial menu closed")
    menu:Show()
    settle(t)
    A.alpha(bar, 0, "RT showed the gamepad bar behind the radial menu")
    menu:Hide()
    settle(t)
    A.alpha(bar, 1, "Peek did not come back after the radial menu closed")
end)

h.test("an open game menu turns peek off", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    local menu = named("GameMenuFrame", UIParent)
    menu:Hide()
    settle(t)
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "LT did not show the gamepad bar with the menu closed")
    menu:Show()
    settle(t)
    A.alpha(bar, 0, "The gamepad bar stayed up after the game menu opened")
    held.PADLTRIGGER = nil
    held.PADRSHOULDER = true
    settle(t)
    A.alpha(bar, 0, "A pad button showed the gamepad bar behind the game menu")
    menu:Hide()
    settle(t)
    A.alpha(bar, 1, "Peek did not come back after the game menu closed")
    zones(A, z, { top = 1 }, "RB after menu")
end)

h.test("release fades the bar out before freeing the zones", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    settle(t)
    held.PADLTRIGGER = true
    settle(t)
    held.PADLTRIGGER = nil
    t.mock:tick(0.1)
    t.mock:tick(0.1)
    A.ok(bar:GetAlpha() > 0 and bar:GetAlpha() < 1, "The gamepad bar did not fade out gradually")
    A.alpha(z.right, 0, "A hidden zone flashed while the bar faded out")
    settle(t)
    A.alpha(bar, 0, "The gamepad bar stayed up after release")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Released")
end)

h.test("a bar shown by the usual rules keeps every zone and skips pad polling", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    t.ns.World.ShowAll = function() return true end
    settle(t)
    local touches = 0
    local origTouch = t.ns.World.TouchHud
    t.ns.World.TouchHud = function(...)
        touches = touches + 1
        return origTouch(...)
    end
    held.polls = 0
    held.PADLTRIGGER = true
    settle(t)
    A.eq(held.polls, 0, "Pad polling ran while ShowAll was active")
    A.eq(touches, 0, "Trigger changes touched the HUD while ShowAll was active")
    A.alpha(bar, 1, "Show-all did not show the gamepad bar")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Show-all")
end)

h.test("absent or hidden gamepad bar skips pad polling", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    settle(t)
    bar:Hide()
    held.polls = 0
    held.PADLTRIGGER = true
    settle(t)
    A.eq(held.polls, 0, "Pad polling ran while GamepadMainActionBarFrame was hidden")

    _G.GamepadMainActionBarFrame = nil
    settle(t)
    A.eq(held.polls, 0, "Pad polling ran when GamepadMainActionBarFrame was absent")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Hidden")
end)

h.test("turning QuietUI off and back on resets peek state cleanly", function(t)
    local A = t.assert
    local bar, z, held = boot(t)
    settle(t)
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(z.left, 0, "RT did not hide the left zone")
    SlashCmdList.QUIETUI("off")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Off")
    held.PADRTRIGGER = nil
    SlashCmdList.QUIETUI("on")
    t.mock:tick(0.01)
    A.ok(bar:GetAlpha() < 1, "Stale peek kept the gamepad bar at alpha 1 after re-enabling")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Re-enabled")
    settle(t)
    A.alpha(bar, 0, "The gamepad bar did not fade out after re-enabling")
end)
