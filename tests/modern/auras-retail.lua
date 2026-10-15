-- Modern aura icons against the retail 12.0 shapes: BuffFrame / DebuffFrame keep their buttons in
-- .auraFrames (children of .AuraContainer, anonymous), art keys Icon / Duration / DebuffBorder /
-- TempEnchantBorder, the dispel type lives in button.buttonInfo.debuffType and the colour comes from
-- AuraUtil.GetAuraBorderColor (DebuffTypeColor is gone). The classic-named fallback is in auras.lua.
local h = ...
local L = h.lib("modern")
local I = h.lib("modern-icons")
local R = h.lib("modern-retail")
local P = h.lib("player")

local MAGIC = { 0.2, 0.6, 1 }
local CURSE = { 0.6, 0, 1 }

local function fixture(t)
    R.installAuraUtil()
    local buffs = R.auraFrame(BuffFrame, { { "Buff" }, { "TempEnchant" } })
    local debuffs = R.auraFrame(DebuffFrame, { { "Debuff", "Magic" } })
    return buffs[1], buffs[2], debuffs[1]
end

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

local function coloured(frame, rgb)
    for _, region in ipairs(frame._regions) do
        local c = region._color
        if region._layer == "BORDER" and region._shown and c and c[1] == rgb[1] and c[2] == rgb[2] and c[3] == rgb[3] then
            return true
        end
    end
    return false
end

h.test("12.0 buttons in BuffFrame.auraFrames and DebuffFrame.auraFrames get a zoomed icon, a border and outlined duration", function(t)
    local A, ns = t.assert, t.ns
    local buff, enchant, debuff = fixture(t)
    enable(ns)
    for _, button in ipairs({ buff, enchant, debuff }) do
        A.ok(I.zoomed(button.Icon), "icon is cropped")
        A.ok(I.border(button), "has a one-pixel border")
        A.ok(I.outlined(button.Duration), "duration outlined")
        A.ok(button.Duration:GetNumPoints() > 0, "duration is positioned")
    end
    A.eq(L.errors(t.mock), 0, "no Report")
end)

h.test("12.0 a magic debuff border uses the colour from AuraUtil.GetAuraBorderColor, other auras the theme border", function(t)
    local A, ns = t.assert, t.ns
    local buff, enchant, debuff = fixture(t)
    enable(ns)
    A.ok(coloured(debuff, MAGIC), "magic dispel border colour")
    A.falsy(coloured(buff, MAGIC), "a buff is not coloured by dispel type")
    A.ok(coloured(buff, ns.Modern.Theme().border), "a buff has the theme border")
    A.ok(coloured(enchant, ns.Modern.Theme().border), "a temporary enchant has the theme border")
end)

h.test("12.0 Blizzard's debuff and enchant border art is held hidden after Blizzard shows it", function(t)
    local A, ns = t.assert, t.ns
    local buff, enchant, debuff = fixture(t)
    enable(ns)
    debuff.DebuffBorder:Show()
    enchant.TempEnchantBorder:Show()
    A.alpha(debuff.DebuffBorder, 0, "DebuffBorder is held")
    A.alpha(enchant.TempEnchantBorder, 0, "TempEnchantBorder is held")
    A.alpha(buff.DebuffBorder, 0, "unused border art is held too")
end)

h.test("12.0 a Blizzard update that changes the dispel type recolours the border", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local _, _, debuff = fixture(t)
    enable(ns)
    DebuffFrame.auraInfo[1] = { auraType = "Debuff", debuffType = "Curse" }
    DebuffFrame:UpdateAuraButtons()
    mock:fire("UNIT_AURA", "player")
    A.ok(coloured(debuff, CURSE), "curse colour after the update")
    A.falsy(coloured(debuff, MAGIC), "the old magic colour is gone")
    A.alpha(debuff.DebuffBorder, 0, "Blizzard's border art stays held")
end)

h.test("12.0 buttons added later are skinned after the next Blizzard update or player UNIT_AURA", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(t)
    enable(ns)
    local late = R.addAura(DebuffFrame, "Debuff", "Magic")
    late:Show(); late:Update(DebuffFrame.auraInfo[#DebuffFrame.auraInfo])
    DebuffFrame:UpdateAuraButtons()
    mock:fire("UNIT_AURA", "player")
    A.ok(I.zoomed(late.Icon), "late button icon is cropped")
    A.ok(I.border(late), "late button has a border")
    A.ok(coloured(late, MAGIC), "late magic debuff has the dispel colour")
    A.alpha(late.DebuffBorder, 0, "late Blizzard border art is held")
end)

h.test("12.0 UNIT_AURA for another unit does not rescan the aura frames", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local _, _, debuff = fixture(t)
    enable(ns)
    DebuffFrame.auraInfo[1].debuffType = "Curse" -- changed behind the area's back
    debuff.buttonInfo.debuffType = "Curse"
    local calls = R.calls(mock)
    for _ = 1, 100 do
        mock:fire("UNIT_AURA", "target")
        mock:fire("UNIT_AURA", "nameplate1")
    end
    R.sameCalls(A, calls, mock.calls, "no frame walks for other units")
    A.ok(coloured(debuff, MAGIC), "no rescan: the border still has the old colour")
    A.eq(L.errors(mock), 0)
end)

h.test("12.0 private aura anchors and forbidden or incomplete buttons are skipped without a Report", function(t)
    local A, ns = t.assert, t.ns
    local buff, _, debuff = fixture(t)
    local anchor = R.privateAnchor(DebuffFrame)
    debuff._forbidden = true
    buff.Duration = nil
    A.noThrow(function() enable(ns) end)
    A.ok(I.zoomed(buff.Icon), "a button without Duration still skins")
    A.falsy(I.zoomed(debuff.Icon), "a forbidden button is skipped")
    A.eq(anchor.Icon._alpha, 1, "the private anchor is untouched")
    A.eq(L.errors(t.mock), 0, "no Report")
end)

h.test("12.0 restore returns icon, border, held art, duration and stops skinning later updates", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local buff, enchant, debuff = fixture(t)
    local before = L.snapshot({ buff.Icon, buff.DebuffBorder, buff.Duration, enchant.TempEnchantBorder,
        debuff.Icon, debuff.DebuffBorder, debuff.Duration })
    enable(ns)
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    for _, button in ipairs({ buff, enchant, debuff }) do
        A.ok(not I.zoomed(button.Icon), "icon restored")
        A.ok(not I.border(button), "border hidden")
        A.eq(button.Duration:GetNumPoints(), 0, "duration points restored")
        A.ok(not I.outlined(button.Duration), "duration font restored")
    end
    A.deep(L.diff(before), {}, "art alpha and textures are as before")
    local late = R.addAura(BuffFrame, "Buff")
    BuffFrame:UpdateAuraButtons()
    mock:fire("UNIT_AURA", "player")
    A.ok(not I.zoomed(late.Icon), "after restore, no later update skins buttons")
end)

h.test("12.0 aura skin leaves the Faders alpha, secret or not, and never shows or hides the aura frames", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(t)
    local secret = P.secret(mock, 0.5)
    BuffFrame._alpha, DebuffFrame._alpha = secret, 0.35
    local calls = { I.watchVisibility(BuffFrame), I.watchVisibility(DebuffFrame),
        I.watchVisibility(BuffFrame.AuraContainer) }
    enable(ns)
    mock:fire("UNIT_AURA", "player")
    A.ok(rawequal(BuffFrame._alpha, secret), "the secret Faders alpha is untouched")
    A.alpha(DebuffFrame, 0.35, "Faders alpha remains authoritative")
    for _, c in ipairs(calls) do A.deep(c, { hide = 0, show = 0 }, "aura container visibility") end
    A.eq(L.errors(mock), 0)
end)
