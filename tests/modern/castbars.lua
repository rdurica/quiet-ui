-- Cast bars: retail CastingBarMixin parts (Border, TextBorder, Background, Flash, Spark, Text, Icon) on
-- PlayerCastingBarFrame and TargetFrameSpellBar. Blizzard re-textures the fill with an atlas on every cast.
local h = ...
local L = h.lib("modern")
local C = h.lib("modern-castbars")

h.test("Cast bars registers in the Modern area list", function(t)
    local A, ns = t.assert, t.ns
    local _, area = L.indexOf(ns, "castbars")
    A.type(area, "table", "the cast bar area is registered")
    A.eq(area.label, "Cast bars")
end)

h.test("Cast bars holds the frame art, flattens the fill, makes the bar taller with its texts inside and restores", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar, fill = C.castbar("PlayerCastingBarFrame")
    local target = C.castbar("TargetFrameSpellBar")
    local before = L.snapshot({ bar, fill, bar.Border, bar.TextBorder, bar.Background, bar.Flash, bar.Spark,
        bar.Text, bar.Icon, target })
    L.enable()
    ns.Modern.Apply()
    for _, key in ipairs({ "Border", "TextBorder", "Background", "Flash" }) do
        A.alpha(bar[key], 0, key .. " is held")
    end
    A.alpha(bar.Spark, 1, "the spark stays")
    A.eq(fill._texture, "Interface\\Buttons\\WHITE8X8", "the fill is flat")
    A.near(bar._barColor[1], 0.95, 0.001, "a standard cast takes the accent colour")
    A.eq(bar:GetHeight(), 18, "the player's bar is 18 px tall")
    A.eq(target:GetHeight(), 14, "the other bars are 14 px tall")
    A.deep({ bar.Text:GetPoint(1) }, { "LEFT", bar, "LEFT", 4, 0 }, "the spell name sits inside the bar")
    A.ok(bar.Text._font[3]:find("OUTLINE", 1, true) ~= nil, "the spell name is outlined")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the cast bar restores exactly")
end)

h.test("an own square icon left of the bar mirrors Blizzard's spell icon, which is held", function(t)
    local A, ns = t.assert, t.ns
    local bar = C.castbar("PlayerCastingBarFrame")
    bar.Icon:Hide()
    L.enable()
    ns.Modern.Apply()
    local icon, border = C.icon(bar), C.iconBorder(bar)
    A.type(icon, "table", "the bar has its own icon")
    A.ok(icon:IsShown() and border:IsShown(), "it shows with its border even though Blizzard hides its own")
    A.alpha(bar.Icon, 0, "Blizzard's icon is held")
    A.ok(L.zoomed(icon), "the icon is square-cropped")
    A.deep({ icon:GetSize() }, { 18, 18 }, "the icon is as tall as the bar")
    A.eq(icon._texture, "Interface\\Icons\\Spell_Frost_FrostBolt02", "the current spell is copied")
    bar.Icon:SetTexture("Interface\\Icons\\Spell_Fire_SelfDestruct")
    A.eq(icon._texture, "Interface\\Icons\\Spell_Fire_SelfDestruct", "a new cast's icon is mirrored")
    ns.Modern.Restore()
    A.falsy(icon:IsShown() or border:IsShown(), "restore hides the own icon and its border")
    bar.Icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
    A.eq(icon._texture, "Interface\\Icons\\Spell_Fire_SelfDestruct", "the mirror is inert after restore")
end)

h.test("Blizzard's SetLook is answered by laying the bar out again", function(t)
    local A, ns = t.assert, t.ns
    local bar = C.castbar("PlayerCastingBarFrame")
    L.enable()
    ns.Modern.Apply()
    bar.SetHeight(bar, 10)
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("TOP", bar, "BOTTOM", 0, -1)
    bar:SetLook("UNITFRAME")
    A.eq(bar:GetHeight(), 18, "the height is put back")
    A.deep({ bar.Text:GetPoint(1) }, { "LEFT", bar, "LEFT", 4, 0 }, "the spell name is put back inside")
end)

h.test("a Blizzard re-texture is answered with the flat fill in the cast type colour, and not after restore", function(t)
    local A, ns = t.assert, t.ns
    local bar, fill = C.castbar("PlayerCastingBarFrame")
    L.enable()
    ns.Modern.Apply()
    bar.barType = "channel"
    bar:SetStatusBarTexture("ui-castingbar-filling-channel")
    A.eq(fill._texture, "Interface\\Buttons\\WHITE8X8", "the fill is flat again")
    A.near(bar._barColor[2], 0.75, 0.001, "a channel is green")
    bar.barType = "interrupted"
    bar:SetStatusBarTexture("ui-castingbar-interrupted")
    A.near(bar._barColor[1], 0.85, 0.001, "an interrupted cast takes the danger colour")
    ns.Modern.Restore()
    bar:SetStatusBarTexture("ui-castingbar-filling-standard")
    A.eq(fill._texture, "ui-castingbar-filling-standard", "the hook is inert after restore")
end)
