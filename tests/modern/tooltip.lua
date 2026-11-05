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
        F.sameColor(A, F.topColor(tip), ns.Modern.Theme().border, (tip:GetName() or "shopping") .. " top edge")
        local border = F.borderColor(tip)
        A.ok(not border or border[4] == 0, (tip:GetName() or "shopping") .. " has no frame border")
    end
    A.eq(GameTooltipStatusBar:GetAlpha(), 0, "unit health bar is hidden")
end)

h.test("Tooltip item quality updates its top edge and restore returns Blizzard's colour and chrome", function(t)
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
    F.sameColor(A, F.topColor(GameTooltip), EPIC, "epic top edge")
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
    A.eq(GameTooltipStatusBar:GetAlpha(), 0, "unit health bar is hidden")
    ns.Modern.Restore()
end)

-- An old backdrop tooltip (no NineSlice): OnShow is hooked once per session, never replaced.
local function oldTip(ns)
    F.area(ns, "tooltip")
    GameTooltip, GameTooltipStatusBar = F.tooltip("GameTooltip", false)
    GameTooltip._native, GameTooltip._setScript, GameTooltip._hookScript = 0, 0, {}
    GameTooltip:SetScript("OnShow", function(self) self._native = self._native + 1 end)
    local set, hook = GameTooltip.SetScript, GameTooltip.HookScript
    GameTooltip.SetScript = function(self, ...) self._setScript = self._setScript + 1; return set(self, ...) end
    GameTooltip.HookScript = function(self, name, fn)
        self._hookScript[name] = (self._hookScript[name] or 0) + 1
        return hook(self, name, fn)
    end
    GameTooltip.GetItem = function(self) if self._item then return self._item[1], self._item[2] end end
    C_Item = { GetItemQualityByID = function() return 4 end }
    ITEM_QUALITY_COLORS = { [4] = { r = EPIC[1], g = EPIC[2], b = EPIC[3] } }
    ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 = nil, nil, nil
    return GameTooltip
end

h.test("old backdrop tooltip gets exactly one OnShow hook for the session and SetScript is never called", function(t)
    local A, ns = t.assert, t.ns
    local tip = oldTip(ns)
    F.enable(ns)
    ns.Modern.Apply()
    ns.Modern.Restore()
    F.enable(ns)
    A.eq(tip._hookScript.OnShow, 1, "OnShow hooked once across apply, restore and re-apply")
    A.eq(tip._setScript, 0, "SetScript was never called by the area")
end)

h.test("old backdrop tooltip OnShow hook repaints the quality edge while on and is inert once off", function(t)
    local A, ns = t.assert, t.ns
    local tip = oldTip(ns)
    tip:SetBackdropBorderColor(0.1, 0.2, 0.3, 0.4)
    F.enable(ns)
    tip._item = { "Epic Item", "item:12345" }
    tip:Hide(); tip:Show()
    F.sameColor(A, F.topColor(tip), EPIC, "epic top edge after show")
    A.eq(tip._native, 1, "Blizzard's own OnShow ran")
    tip._item = nil
    tip:Hide(); tip:Show()
    F.sameColor(A, F.topColor(tip), ns.Modern.Theme().border, "theme top edge for a non-item")
    ns.Modern.Restore()
    F.sameColor(A, tip._backdropBorder, { 0.1, 0.2, 0.3, 0.4 }, "Blizzard border after restore")
    tip._item = { "Epic Item", "item:12345" }
    tip:Hide(); tip:Show()
    F.sameColor(A, tip._backdropBorder, { 0.1, 0.2, 0.3, 0.4 }, "hook does nothing once off")
    A.eq(tip._native, 3, "Blizzard's OnShow still runs after restore")
    A.eq(tip._setScript, 0, "SetScript never called")
end)
