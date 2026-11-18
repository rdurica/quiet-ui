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
    return bar, z
end

local function pad()
    local held = {}
    C_GamePad = {
        GetActiveDeviceID = function() return 1 end,
        GetDeviceMappedState = function()
            local buttons = {}
            for i, name in ipairs(BUTTONS) do buttons[i] = held[name] == true end
            return { buttons = buttons }
        end,
        ButtonIndexToBinding = function(index) return BUTTONS[index + 1] end,
    }
    return held
end

local function boot(t, on)
    QuietUIDB = { enabled = true }
    QuietUICharDB = { gamepadPeek = on or nil }
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

h.test("gamepad peek is off by default", function(t)
    local A = t.assert
    local bar, _, held = boot(t, false)
    settle(t)
    A.alpha(bar, 0, "The gamepad bar did not fade out of combat")
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(bar, 0, "LT showed the gamepad bar with the option off")
end)

h.test("LT shows only the left zone", function(t)
    local A = t.assert
    local bar, z, held = boot(t, true)
    settle(t)
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "LT did not show the gamepad bar")
    zones(A, z, { left = 1 }, "LT")
end)

h.test("RT shows the right zone with the stance bar", function(t)
    local A = t.assert
    local bar, z, held = boot(t, true)
    settle(t)
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "RT did not show the gamepad bar")
    zones(A, z, { right = 1, stance = 1 }, "RT")
end)

h.test("both triggers or a shoulder button show the centre", function(t)
    local A = t.assert
    local _, z, held = boot(t, true)
    settle(t)
    held.PADLTRIGGER, held.PADRTRIGGER = true, true
    settle(t)
    zones(A, z, { top = 1, bottom = 1 }, "LT+RT")
    held.PADLTRIGGER, held.PADRTRIGGER = nil, nil
    held.PADRSHOULDER = true
    settle(t)
    zones(A, z, { top = 1, bottom = 1 }, "RB")
    held.PADRTRIGGER = true
    settle(t)
    zones(A, z, { right = 1, stance = 1, top = 1, bottom = 1 }, "RB+RT")
end)

h.test("release fades the bar out before freeing the zones", function(t)
    local A = t.assert
    local bar, z, held = boot(t, true)
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

h.test("a bar shown by the usual rules keeps every zone", function(t)
    local A = t.assert
    local bar, z, held = boot(t, true)
    t.ns.World.ShowAll = function() return true end
    held.PADLTRIGGER = true
    settle(t)
    A.alpha(bar, 1, "Show-all did not show the gamepad bar")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Show-all")
end)

h.test("turning QuietUI off releases the zones", function(t)
    local A = t.assert
    local _, z, held = boot(t, true)
    settle(t)
    held.PADRTRIGGER = true
    settle(t)
    A.alpha(z.left, 0, "RT did not hide the left zone")
    SlashCmdList.QUIETUI("off")
    zones(A, z, { left = 1, right = 1, bottom = 1, top = 1, stance = 1 }, "Off")
end)
