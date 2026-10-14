local _, ns = ...

-- Bags collapse into one button. Left click opens bags, right click shows
-- the bag slots for swapping, drag moves the button. Defines the Menu table and its
-- private state; Micro.lua shares it.

local Menu = {}
ns.Menu = Menu

-- Private to the Menu files. Other features never read it.
local S = {
    button = nil,
    bagSlotsPinned = false,
    shownSlots = nil,
    refreshing = false,
}
Menu.state = S

local BORDER = { 0.85, 0.85, 0.85, 0.35 }
local HIGHLIGHT = { 0.95, 0.75, 0.25, 0.95 }


------------------------------------------------------------------------------
-- Bag slots
------------------------------------------------------------------------------
function Menu.BagsShouldShow()
    if not ns.DB().enabled then return false end
    return S.bagSlotsPinned or ns.World.CursorHasItem()
end

-- ItemButtonMixin:SetAlpha fades the icon, not the frame. HoldAlpha would
-- zero the icon and then skip restoring it, because the frame alpha stays 1.
local function UsesIconAlpha(frame)
    return type(ItemButtonMixin) == "table" and frame.SetAlpha == ItemButtonMixin.SetAlpha
end

local function ShowWidget(widget)
    if widget and widget.SetAlpha then
        widget:SetAlpha(1)
    end
end

local function ReleaseIconAlpha(frame)
    frame._quietAlpha = nil
    frame._quietSecret = nil
    ShowWidget(frame.icon or frame.Icon)
    ShowWidget(frame.IconBorder)
    ShowWidget(frame.IconOverlay)
    ShowWidget(frame.Count)
    ShowWidget(frame.Stock)
end

-- Alpha 0 still receives the mouse, so a hidden slot would show its tooltip.
function S.SetBagInput(frame, show)
    if frame.SetMouseMotionEnabled then
        pcall(frame.SetMouseMotionEnabled, frame, show)
    end
    if frame.SetMouseClickEnabled then
        pcall(frame.SetMouseClickEnabled, frame, show)
    end
end


function Menu.UpdateBagSlots()
    if not ns.DB().enabled then return end
    local show = Menu.BagsShouldShow()
    if show == S.shownSlots then return end
    S.shownSlots = show
    local alpha = show and 1 or 0
    ns.Bars.EachBagFrame(function(frame)
        if UsesIconAlpha(frame) then
            ReleaseIconAlpha(frame)
        else
            ns.HoldAlpha(frame, alpha)
        end
        S.SetBagInput(frame, show)
    end)
    if S.button and S.button.SetBackdropBorderColor then
        S.button:SetBackdropBorderColor(unpack(show and HIGHLIGHT or BORDER))
    end
end

local function ToggleBagSlots()
    S.bagSlotsPinned = not S.bagSlotsPinned
    Menu.UpdateBagSlots()
    if S.bagSlotsPinned then
        ns.Print("bag slots shown")
    end
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------
local function PlaceButton(force)
    local db = ns.DB()
    if not force and S.button._quietPlaced == db then return end
    S.button._quietPlaced = db
    S.button:ClearAllPoints()
    if type(db.point) == "string" and type(db.relPoint) == "string"
        and type(db.x) == "number" and type(db.y) == "number" then
        S.button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    else
        S.button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
    end
end

local function SavePoint(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    if not point or type(x) ~= "number" or type(y) ~= "number" then return end
    local db = ns.DB()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    self._quietPlaced = db
end

local function Style(frame)
    if not frame.SetBackdrop then return end
    pcall(function()
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
        frame:SetBackdropBorderColor(unpack(BORDER))
    end)
end

local function AddIcon(frame)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    local usedAtlas = false
    if icon.SetAtlas then
        local ok, result = pcall(icon.SetAtlas, icon, "bag-main")
        usedAtlas = ok and result and true or false
    end
    if not usedAtlas then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    if highlight.SetColorTexture then
        highlight:SetColorTexture(1, 1, 1, 0.18)
    end
end

local function OnMouseUp(self, click)
    if self._moved then
        self._moved = false
        return
    end
    if click == "RightButton" then
        ToggleBagSlots()
    elseif type(ToggleAllBags) == "function" then
        ToggleAllBags()
    elseif type(ToggleBackpack) == "function" then
        ToggleBackpack()
    end
end

local function OnEnter(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("QuietUI", 1, 1, 1)
    GameTooltip:AddLine("Left click: open bags", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Right click: bag slots", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function CreateButton()
    local ok, created = pcall(CreateFrame, "Button", nil, UIParent, "BackdropTemplate")
    if not ok or not created then
        created = CreateFrame("Button", nil, UIParent)
    end
    created:SetSize(28, 28)
    created:SetFrameStrata("MEDIUM")
    created:SetFrameLevel(40)
    created:SetClampedToScreen(true)
    created:SetMovable(true)
    created:EnableMouse(true)
    created:RegisterForDrag("LeftButton")
    created:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Style(created)
    AddIcon(created)
    created:SetScript("OnDragStart", function(self)
        self._moved = true
        self:StartMoving()
    end)
    created:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePoint(self)
    end)
    created:SetScript("OnMouseUp", OnMouseUp)
    created:SetScript("OnEnter", OnEnter)
    created:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return created
end

function S.EnsureButton()
    if S.button then
        PlaceButton(false)
    else
        S.button = CreateButton()
        PlaceButton(true)
    end
    S.button:Show()
end

------------------------------------------------------------------------------
-- Micro menu
