-- Modern aura icons: observable Blizzard frames keep their Faders alpha lifecycle.
local h = ...
local I = h.lib("modern-icons")

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

local function fixture(t)
    _G.TemporaryEnchantFrame = CreateFrame("Frame", "TemporaryEnchantFrame", UIParent)
    local buff = I.aura(t.mock, "BuffButton1", BuffFrame)
    local magic = I.aura(t.mock, "DebuffButton1", DebuffFrame, "Magic")
    local enchant = I.aura(t.mock, "TempEnchant1", TemporaryEnchantFrame)
    return buff, magic, enchant
end

h.test("auras skin buff debuff and temporary-enchant icons with duration below", function(t)
    local A, ns = t.assert, t.ns
    local buff, magic, enchant = fixture(t)
    enable(ns)
    for _, button in ipairs({ buff, magic, enchant }) do
        A.ok(I.zoomed(button.Icon), button:GetName() .. " icon is cropped")
        A.ok(I.border(button), button:GetName() .. " has a one-pixel border")
        A.ok(I.outlined(button.Duration), button:GetName() .. " duration outlined")
        A.ok(button.Duration:GetNumPoints() > 0, button:GetName() .. " duration is positioned")
    end
end)

h.test("magic debuff receives the magic dispel border colour", function(t)
    local A, ns = t.assert, t.ns
    local _, magic = fixture(t)
    _G.DebuffTypeColor = { Magic = { r = 0.2, g = 0.6, b = 1 } }
    enable(ns)
    local coloured = false
    for _, region in ipairs(magic._regions) do
        local c = region._color
        if c and c[1] == 0.2 and c[2] == 0.6 and c[3] == 1 then coloured = true end
    end
    A.ok(coloured, "magic border colour")
end)

h.test("aura skin neither changes Faders alpha nor uses visibility calls", function(t)
    local A, ns = t.assert, t.ns
    local buff = fixture(t)
    BuffFrame:SetAlpha(0.35)
    local calls = I.watchVisibility(BuffFrame)
    enable(ns)
    A.alpha(BuffFrame, 0.35, "Faders alpha remains authoritative")
    A.deep(calls, { hide = 0, show = 0 }, "aura container visibility")
end)

h.test("auras restore icon, border, duration and font state when disabled", function(t)
    local A, ns = t.assert, t.ns
    local buff, magic, enchant = fixture(t)
    enable(ns)
    A.ok(I.zoomed(buff.Icon), "skin applied before disabling")
    A.ok(I.outlined(buff.Duration), "duration treatment applied before disabling")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    for _, button in ipairs({ buff, magic, enchant }) do
        A.ok(not I.zoomed(button.Icon), button:GetName() .. " icon restored")
        A.ok(not I.border(button), button:GetName() .. " border hidden")
        A.eq(button.Duration:GetNumPoints(), 0, button:GetName() .. " duration points restored")
        A.ok(not I.outlined(button.Duration), button:GetName() .. " duration font restored")
    end
end)

h.test("missing and forbidden aura controls are skipped while valid auras still skin", function(t)
    local A, ns = t.assert, t.ns
    local buff, magic = fixture(t)
    magic._forbidden = true
    buff.Duration = nil
    enable(ns)
    A.ok(I.zoomed(buff.Icon), "valid available parts still skin")
    A.ok(not I.zoomed(magic.Icon), "forbidden aura skipped")
end)
