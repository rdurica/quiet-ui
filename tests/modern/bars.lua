-- Modern action bars: public discovery, square icon treatment and alpha-only safety.
local h = ...
local I = h.lib("modern-icons")

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

local function createGamepad(t)
    local m = t.mock
    _G.GamepadMainActionBarFrame = CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
    return I.button(m, "GamepadActionButton1", GamepadMainActionBarFrame)
end

local function fixture(t, withoutGamepad)
    local m = t.mock
    local standard = I.button(m, "ActionButton1", MainActionBar)
    local pet = I.button(m, "PetActionButton1", PetActionBar)
    local stance = I.button(m, "StanceButton1", StanceBar)
    local gamepad
    if not withoutGamepad then
        gamepad = createGamepad(t)
        GamepadMainActionBarFrame:Hide()
    end
    local barArt = I.barArt(MainActionBar, "MainMenuBarTexture0")
    return standard, pet, stance, gamepad, barArt
end

h.test("Bars.Buttons discovers standard, pet, stance and loaded gamepad buttons", function(t)
    local A, ns = t.assert, t.ns
    local standard, pet, stance, gamepad = fixture(t)
    A.type(ns.Bars.Buttons, "function", "public action-button list")
    local list = ns.Bars.Buttons()
    for _, button in ipairs({ standard, pet, stance, gamepad }) do A.contains(list, button) end
end)

h.test("bars skin icons, all button art and text while preserving size and alpha", function(t)
    local A, ns = t.assert, t.ns
    local standard, pet, stance, gamepad, barArt = fixture(t)
    local before = {}
    for _, button in ipairs({ standard, pet, stance, gamepad }) do
        before[button] = { button:GetWidth(), button:GetHeight(), button:GetAlpha() }
    end
    enable(ns)
    for _, button in ipairs({ standard, pet, stance, gamepad }) do
        A.ok(I.zoomed(button.Icon), button:GetName() .. " icon is cropped")
        for _, texture in ipairs({ button.NormalTexture, button.PushedTexture, button.HighlightTexture, button.CheckedTexture,
            button.Border, button.SlotBackground }) do A.alpha(texture, 0, button:GetName() .. " Blizzard art held") end
        A.ok(I.border(button), button:GetName() .. " has a one-pixel border")
        A.ok(I.outlined(button.HotKey), button:GetName() .. " hotkey outlined")
        A.ok(I.outlined(button.Count), button:GetName() .. " count outlined")
    end
    for _, button in ipairs({ standard, pet, stance, gamepad }) do
        A.eq(button:GetWidth(), before[button][1], button:GetName() .. " width")
        A.eq(button:GetHeight(), before[button][2], button:GetName() .. " height")
        A.alpha(button, before[button][3], button:GetName() .. " alpha")
    end
    A.alpha(MainActionBar, 1, "bar alpha")
    A.alpha(barArt, 0, "orphan bar art held")
end)

h.test("bars skin in combat without visibility calls or state drivers", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local standard = fixture(t)
    local barCalls, buttonCalls = I.watchVisibility(MainActionBar), I.watchVisibility(standard)
    local drivers = 0
    _G.RegisterStateDriver = function() drivers = drivers + 1 end
    mock.state.combat = true
    enable(ns)
    A.ok(I.zoomed(standard.Icon), "texture work is allowed in combat")
    A.deep(barCalls, { hide = 0, show = 0 }, "bar visibility")
    A.deep(buttonCalls, { hide = 0, show = 0 }, "button visibility")
    A.eq(drivers, 0, "no state driver")
end)

h.test("late gamepad load reapplies the same skin and disabled restore returns every property", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local standard = fixture(t, true)
    enable(ns)
    A.ok(I.zoomed(standard.Icon), "initial standard button")
    A.eq(_G.GamepadMainActionBarFrame, nil, "unloaded gamepad controls are absent")
    local gamepad = createGamepad(t)
    ns.Modern.AddonLoaded("Blizzard_GamepadActionBars")
    A.ok(I.zoomed(gamepad.Icon), "loaded gamepad button")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    for _, button in ipairs({ standard, gamepad }) do
        A.ok(not I.zoomed(button.Icon), button:GetName() .. " icon restored")
        A.alpha(button.NormalTexture, 0.7, button:GetName() .. " normal art released")
        A.ok(not I.border(button), button:GetName() .. " own border hidden")
        A.ok(not I.outlined(button.HotKey), button:GetName() .. " hotkey font restored")
        A.ok(not I.outlined(button.Count), button:GetName() .. " count font restored")
    end
    A.eq(#mock.printed, 0, "no missing frame report")
end)

h.test("missing and forbidden bar controls are skipped while valid controls still skin", function(t)
    local A, ns = t.assert, t.ns
    local standard = fixture(t)
    local missing = I.button(t.mock, "ActionButton2", MainActionBar)
    missing.Icon = nil; missing.icon = nil; missing.IconTexture = nil
    local forbidden = I.button(t.mock, "ActionButton3", MainActionBar)
    forbidden._forbidden = true
    enable(ns)
    A.ok(I.zoomed(standard.Icon), "valid button still skins")
    A.ok(not I.zoomed(missing.NormalTexture), "missing icon skipped")
    A.ok(not I.zoomed(forbidden.Icon), "forbidden button skipped")
end)
