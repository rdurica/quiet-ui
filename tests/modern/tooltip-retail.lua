-- Modern tooltips against the retail 12.0 shapes: TooltipBackdropTemplate (NineSlice child), no
-- OnTooltipSetItem script, TooltipDataProcessor post calls. Scripts are hooked, never replaced, so
-- the secure GameTooltip is not tainted.
local h = ...
local L = h.lib("modern")
local F = h.lib("modern-map-tip")
local R = h.lib("modern-retail")

local EPIC = { 0.64, 0.21, 0.93 }
local function before(mock) R.dataProcessor(mock) end

local function fixture(ns)
    ITEM_QUALITY_COLORS = { [4] = { r = EPIC[1], g = EPIC[2], b = EPIC[3] } }
    GameTooltip, GameTooltipStatusBar = R.tooltip("GameTooltip", true)
    ItemRefTooltip = R.tooltip("ItemRefTooltip")
    ShoppingTooltip1 = R.tooltip("ShoppingTooltip1")
    ShoppingTooltip2 = R.tooltip("ShoppingTooltip2")
    F.area(ns, "tooltip")
    return { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }
end

h.test("12.0 tooltips get the themed background and a 1px border and hide their NineSlice art", function(t)
    local A, ns = t.assert, t.ns
    local tips = fixture(ns)
    F.enable(ns)
    local theme = ns.Modern.Theme()
    for _, tip in ipairs(tips) do
        local name = tip:GetName()
        A.alpha(tip.NineSlice, 0, name .. " NineSlice art is held hidden")
        A.ok(R.hasColor(tip, theme.bg), name .. " has the theme background")
        F.sameColor(A, F.borderColor(tip), theme.border, name .. " theme border")
    end
    A.eq(GameTooltipStatusBar:GetStatusBarTexture():GetTexture(), theme.bar, "unit health bar uses the theme texture")
    A.eq(L.errors(t.mock), 0, "no Report on the retail shapes")
end, { beforeLoad = before })

h.test("12.0 item post call colours GameTooltip and ItemRefTooltip with the epic quality colour", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(ns)
    F.enable(ns)
    R.showItem(mock, GameTooltip, 4)
    F.sameColor(A, F.borderColor(GameTooltip), EPIC, "GameTooltip epic border")
    R.showItem(mock, ItemRefTooltip, 4)
    F.sameColor(A, F.borderColor(ItemRefTooltip), EPIC, "ItemRefTooltip epic border")
    F.sameColor(A, F.borderColor(ShoppingTooltip1), ns.Modern.Theme().border, "an untouched tooltip keeps the theme border")
end, { beforeLoad = before })

h.test("12.0 a non-item tooltip after an item returns to the theme border", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(ns)
    F.enable(ns)
    R.showItem(mock, GameTooltip, 4)
    F.sameColor(A, F.borderColor(GameTooltip), EPIC, "epic first")
    GameTooltip:Hide()
    GameTooltip._item = nil -- a unit or spell tooltip: GetItem returns nothing
    GameTooltip:Show()
    F.sameColor(A, F.borderColor(GameTooltip), ns.Modern.Theme().border, "theme border again")
end, { beforeLoad = before })

h.test("12.0 tooltip scripts are hooked, never replaced, and OnTooltipSetItem is never touched", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local tips = fixture(ns)
    F.enable(ns)
    R.showItem(mock, GameTooltip, 4)
    GameTooltip:Hide(); GameTooltip:Show()
    ns.Modern.Restore()
    for _, tip in ipairs(tips) do
        A.eq(tip._setScript, 0, tip:GetName() .. " SetScript was never called")
        A.eq(tip._badGet, 0, tip:GetName() .. " GetScript(OnTooltipSetItem) was never called")
    end
    A.eq(L.errors(mock), 0, "nothing was reported")
    local native = GameTooltip._native
    GameTooltip:Hide(); GameTooltip:Show()
    A.eq(GameTooltip._native, native + 1, "Blizzard's own OnShow still runs after restore")
end, { beforeLoad = before })

h.test("12.0 the item post call is registered once and ignores tooltips while the area is off", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(ns)
    local regions = #GameTooltip._regions
    R.showItem(mock, GameTooltip, 4) -- Modernize is off
    A.eq(#GameTooltip._regions, regions, "no border or background is created while off")
    A.falsy(F.borderColor(GameTooltip), "no border colour while off")
    F.enable(ns)
    ns.Modern.Restore()
    F.enable(ns)
    QuietUICharDB.modernize.tooltip = false
    ns.Modern.Apply()
    A.eq(#R.itemPostCalls(mock), 1, "registered exactly once across apply, restore and area toggles")
    GameTooltip:Hide()
    R.showItem(mock, GameTooltip, 4)
    A.falsy(F.borderColor(GameTooltip) and R.hasColor(GameTooltip, EPIC), "area off: the post call does not colour")
    for _, region in ipairs(GameTooltip._regions) do
        if region._color and (region._w == 1 or region._h == 1) then
            A.falsy(region._shown, "area off: no border line is shown")
        end
    end
    A.alpha(GameTooltip.NineSlice, 0.65, "area off: Blizzard's NineSlice is back")
    A.eq(L.errors(mock), 0)
end, { beforeLoad = before })

h.test("12.0 the post call leaves a tooltip alone that the area never skinned", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(ns)
    F.enable(ns)
    local other = R.tooltip("SomeOtherTooltip")
    local regions = #other._regions
    R.showItem(mock, other, 4)
    A.eq(#other._regions, regions, "no region was added")
    A.alpha(other.NineSlice, 0.65, "its NineSlice stays")
    A.eq(L.errors(mock), 0)
end, { beforeLoad = before })

h.test("12.0 tooltip skips a missing or forbidden tooltip without reading secret health", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    fixture(ns)
    UnitHealth = function() error("secret health was read", 0) end
    UnitHealthMax = function() error("secret health maximum was read", 0) end
    ItemRefTooltip = nil
    ShoppingTooltip1._forbidden = true
    A.noThrow(function() F.enable(ns) end)
    A.eq(GameTooltipStatusBar:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar)
    A.eq(L.errors(mock), 0, "skipped parts are not errors")
end, { beforeLoad = before })
