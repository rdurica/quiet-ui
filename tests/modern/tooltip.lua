-- Modern tooltips: panels, borders and status bars are themed without reading secret health values.
local h = ...
local F = h.lib("modern-map-tip")

local EPIC = { 0.64, 0.21, 0.93 }

h.test("Tooltip themes GameTooltip, item reference and shopping tooltips with NineSlice and backdrop fallbacks", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "tooltip")
    GameTooltip, GameTooltipStatusBar = F.tooltip("GameTooltip", true)
    ItemRefTooltip = F.tooltip("ItemRefTooltip", false)
    ShoppingTooltip1 = F.tooltip("ShoppingTooltip1", true)
    ShoppingTooltip2 = F.tooltip("ShoppingTooltip2", false)
    F.enable(ns)

    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        A.ok(tip.NineSlice == nil or tip.NineSlice:GetAlpha() == 0, (tip:GetName() or "shopping") .. " NineSlice is hidden")
        A.ok(tip._backdropColor or #tip._regions > 0, (tip:GetName() or "shopping") .. " has themed background")
        A.ok(F.borderColor(tip), (tip:GetName() or "shopping") .. " has a one-pixel border")
    end
    A.eq(GameTooltipStatusBar:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar,
        "unit health bar uses the theme texture")
end)

h.test("Tooltip item quality updates its border and restore returns Blizzard's colour and chrome", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "tooltip")
    GameTooltip, GameTooltipStatusBar = F.tooltip("GameTooltip", false)
    GameTooltip.GetItem = function() return "Epic Item", "item:12345" end
    GameTooltip:SetBackdropBorderColor(0.1, 0.2, 0.3, 0.4)
    local old = { 0.1, 0.2, 0.3, 0.4 }
    C_Item = { GetItemQualityByID = function() return 4 end }
    ITEM_QUALITY_COLORS = { [4] = { r = EPIC[1], g = EPIC[2], b = EPIC[3] } }
    F.enable(ns)
    local update = GameTooltip:GetScript("OnTooltipSetItem") or GameTooltip:GetScript("OnShow")
    A.type(update, "function", "quality updates when the item tooltip changes")
    update(GameTooltip)
    F.sameColor(A, F.borderColor(GameTooltip), EPIC, "epic border")
    ns.Modern.Restore()
    F.sameColor(A, GameTooltip._backdropBorder, old, "Blizzard border after restore")
end)

h.test("Tooltip skin never reads secret health values and safely skips missing or forbidden tooltip frames", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "tooltip")
    GameTooltip, GameTooltipStatusBar = F.tooltip("GameTooltip", false)
    UnitHealth = function() error("secret health was read", 0) end
    UnitHealthMax = function() error("secret health maximum was read", 0) end
    ItemRefTooltip = nil
    ShoppingTooltip1 = F.tooltip("ShoppingTooltip1", false)
    ShoppingTooltip1._forbidden = true
    A.noThrow(function() F.enable(ns) end)
    A.eq(GameTooltipStatusBar:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar)
    ns.Modern.Restore()
end)
