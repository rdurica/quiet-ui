local _, ns = ...
local Bars = ns.Bars
local S = Bars.state

-- Hover on a bar: catchers over the bar rect, deep buttons, nested bars and the bag slots.

local hosts, resolved = S.hosts, S.resolved

-- Buttons sit several levels deep and outside the root's rect.
local DEEP_HOVER = {
    GamepadMainActionBarFrame = true,
    MultiCastActionBarFrame = true,
    TotemFrame = true,
}

local function ListHovered(list)
    for i = 1, #list do
        if ns.Hit(list[i]) then return true end
    end
    return false
end

-- Gamepad and totem buttons sit outside the bar rect, so the catcher misses them.
local function ButtonsHovered(bar)
    if not DEEP_HOVER[ns.FrameName(bar) or ""] then return false end
    if ListHovered(S.ButtonsFor(bar, false)) then return true end
    return ListHovered(S.ButtonsFor(bar, true))
end

-- Empty slots are not mouse frames. The catcher is not a child of the bar:
-- a faded parent would drop the mouse. Clicks stay off so spells keep them.
local catchers = {}
local catcherSeen = {}

function Bars.HideCatchers()
    for _, box in pairs(catchers) do
        box:Hide()
    end
end

local function EnsureCatcher(bar)
    local box = catchers[bar]
    if box then return box end
    local created = ns.Catcher.Create()
    if not created then return end
    created:SetAlpha(1)
    catchers[bar] = created
    return created
end

local function MatchLevel(box, bar)
    ns.Catcher.Strata(box, bar)
    local level = bar.GetFrameLevel and bar:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    ns.Catcher.Level(box, level)
end

-- MainMenuBar's own rect is wider than its slots when it hosts other bars.
local function SlotCorner(bar)
    local prefix = S.BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if not prefix then return end
    local tl, br, tlTop, tlLeft, brBottom, brRight
    for i = 1, 12 do
        local button = _G[prefix .. i]
        if ns.Usable(button) and button.GetLeft then
            local left, right = button:GetLeft(), button.GetRight and button:GetRight()
            local top, bottom = button.GetTop and button:GetTop(), button.GetBottom and button:GetBottom()
            if left and right and top and bottom then
                if not tl or top > tlTop or (top == tlTop and left < tlLeft) then
                    tl, tlTop, tlLeft = button, top, left
                end
                if not br or bottom < brBottom or (bottom == brBottom and right > brRight) then
                    br, brBottom, brRight = button, bottom, right
                end
            end
        end
    end
    if tl and br then return tl, br end
end

local function PlaceCatcher(bar)
    local box = EnsureCatcher(bar)
    if not box then return end
    local slotted = ns.FrameName(bar) == "MainMenuBar" and S.HostsOther(bar)
    if slotted then
        local tl, br = SlotCorner(bar)
        if not tl then
            box:Hide()
            box._quietSpan = nil
            return
        end
        if box._quietSlotA ~= tl or box._quietSlotB ~= br then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", tl, "TOPLEFT")
            box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
            box._quietSlotA, box._quietSlotB = tl, br
        end
        box._quietSpan = "slots"
    elseif box._quietSpan ~= bar then
        box:ClearAllPoints()
        box:SetAllPoints(bar)
        box._quietSpan = bar
        box._quietSlotA, box._quietSlotB = nil, nil
    end
    MatchLevel(box, bar)
    if not box:IsShown() then box:Show() end
end

function S.SyncCatchers()
    for bar in pairs(catcherSeen) do
        catcherSeen[bar] = nil
    end
    for _, entry in ipairs(resolved) do
        for _, bar in ipairs(entry.frames) do
            if ns.Usable(bar) and bar.IsShown and bar:IsShown() then
                PlaceCatcher(bar)
                catcherSeen[bar] = true
            end
        end
    end
    for bar, box in pairs(catchers) do
        if not catcherSeen[bar] then
            box:Hide()
        end
    end
end

local function CatcherHit(bar)
    local box = catchers[bar]
    return box and ns.Hit(box) and true or false
end

-- The bar rectangle, plus buttons that sit outside it on the gamepad and totem bars.
local function DirectHot(bar)
    if CatcherHit(bar) then return true end
    if ButtonsHovered(bar) then return true end
    return ns.Hit(bar)
end

-- Hover on a nested bar belongs to that bar, not the frame behind it.
local function OverNested(bar)
    local nested = hosts[bar]
    if not nested then return false end
    for i = 1, #nested do
        if DirectHot(nested[i]) then return true end
    end
    return false
end

function S.BarHovered(bar)
    if OverNested(bar) then return false end
    return DirectHot(bar)
end

-- A bar that parents the bag slots stays visible while those slots are shown.
function S.BarCoversBags(bar)
    if not ns.Menu.BagsShouldShow() then return false end
    local found = false
    Bars.EachBagFrame(function(frame)
        if not found and frame ~= bar and S.IsAncestor(frame, bar) then
            found = true
        end
    end)
    return found
end
