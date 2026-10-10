local _, ns = ...

-- Bags collapse into one button. Left click opens bags, right click shows
-- the bag slots for swapping, drag moves the button. The micro menu fades on
-- its own: hover, edit mode, and Glance show it, and the Visible row holds it.

local MICRO_NAMES = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "PlayerSpellsMicroButton",
    "ProfessionMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
    "PVPMicroButton",
    "HousingMicroButton",
}

local MENU_FRAMES = {
    "MicroMenu",
    "MicroMenuContainer",
    "MicroButtonAndBagsBar",
    "BagsBar",
}

local BORDER = { 0.85, 0.85, 0.85, 0.35 }
local HIGHLIGHT = { 0.95, 0.75, 0.25, 0.95 }

local button
local bagSlotsPinned = false
local refreshing = false

------------------------------------------------------------------------------
-- Bag slots
------------------------------------------------------------------------------
function ns.BagsShouldShow()
    if not ns.DB().enabled then return false end
    return bagSlotsPinned or ns.CursorHasItem()
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
local function SetBagInput(frame, show)
    if frame.SetMouseMotionEnabled then
        pcall(frame.SetMouseMotionEnabled, frame, show)
    end
    if frame.SetMouseClickEnabled then
        pcall(frame.SetMouseClickEnabled, frame, show)
    end
end

local shownSlots

function ns.UpdateBagSlots()
    if not ns.DB().enabled then return end
    local show = ns.BagsShouldShow()
    if show == shownSlots then return end
    shownSlots = show
    local alpha = show and 1 or 0
    ns.EachBagFrame(function(frame)
        if UsesIconAlpha(frame) then
            ReleaseIconAlpha(frame)
        else
            ns.HoldAlpha(frame, alpha)
        end
        SetBagInput(frame, show)
    end)
    if button and button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(unpack(show and HIGHLIGHT or BORDER))
    end
end

local function ToggleBagSlots()
    bagSlotsPinned = not bagSlotsPinned
    ns.UpdateBagSlots()
    if bagSlotsPinned then
        ns.Print("bag slots shown")
    end
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------
local function PlaceButton(force)
    local db = ns.DB()
    if not force and button._quietPlaced == db then return end
    button._quietPlaced = db
    button:ClearAllPoints()
    if type(db.point) == "string" and type(db.relPoint) == "string"
        and type(db.x) == "number" and type(db.y) == "number" then
        button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    else
        button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
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

local function EnsureButton()
    if button then
        PlaceButton(false)
    else
        button = CreateButton()
        PlaceButton(true)
    end
    button:Show()
end

------------------------------------------------------------------------------
-- Micro menu
------------------------------------------------------------------------------
local MICRO_SET = {}
for _, name in ipairs(MICRO_NAMES) do
    MICRO_SET[name] = true
end

local function KnownMicro(frame)
    local name = ns.FrameName(frame)
    if not name or name:find("Queue") then return false end
    if MICRO_SET[name] then return true end
    if type(MICRO_BUTTONS) ~= "table" then return false end
    for _, entry in ipairs(MICRO_BUTTONS) do
        if entry == name or entry == frame then return true end
    end
    return false
end

-- Built by RefreshChrome and ResetMenu, so hover ticks do not read globals.
local microButtons = {}
local microBuilt = false
local microSeen = {}

-- Names and frames share the seen set, so a button listed both ways is kept once.
local function AddMicro(frame, key)
    if microSeen[key] then return end
    microSeen[key] = true
    if not ns.Usable(frame) or microSeen[frame] then return end
    microSeen[frame] = true
    microButtons[#microButtons + 1] = frame
end

local function BuildMicroButtons()
    for i = #microButtons, 1, -1 do microButtons[i] = nil end
    for key in pairs(microSeen) do microSeen[key] = nil end
    for _, name in ipairs(MICRO_NAMES) do
        AddMicro(_G[name], name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, entry in ipairs(MICRO_BUTTONS) do
            if type(entry) == "string" then
                if not entry:find("Queue") then AddMicro(_G[entry], entry) end
            elseif ns.Usable(entry) then
                local name = ns.FrameName(entry)
                if not name or not name:find("Queue") then AddMicro(entry, entry) end
            end
        end
    end
    for key in pairs(microSeen) do microSeen[key] = nil end
    microBuilt = true
end

local function MicroList()
    if not microBuilt then BuildMicroButtons() end
    return microButtons
end

-- A container that also holds bars, bags, or the LFG eye keeps those children.
local function HoldsSpared(frame)
    return ns.TreeHas(frame, ns.IsQueue) or ns.TreeHas(frame, ns.IsBarFrame)
        or ns.TreeHas(frame, ns.IsBagRelated)
end

local function HoldsMicro(frame)
    return ns.TreeHas(frame, KnownMicro)
end

-- Parent alpha stays. Zeroing a container would hide the buttons inside it.
local function MuteMenuFrame(frame)
    if not ns.Usable(frame) then return end
    if ns.IsBarFrame(frame) or ns.IsBagRelated(frame) or KnownMicro(frame) then return end
    ns.HideTextures(frame)
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) and not ns.IsSpared(child) and not ns.IsBagRelated(child) and not KnownMicro(child) then
            if HoldsMicro(child) or HoldsSpared(child) then
                MuteMenuFrame(child)
            else
                ns.Mute(child)
            end
        end
    end
end

function ns.RefreshChrome()
    if refreshing or not ns.DB().enabled then return end
    refreshing = true
    local ok, err = pcall(function()
        BuildMicroButtons()
        for _, name in ipairs(MENU_FRAMES) do
            local frame = _G[name]
            if frame and not frame._quietChrome then
                MuteMenuFrame(frame)
                frame._quietChrome = true
            end
        end
        EnsureButton()
    end)
    refreshing = false
    if not ok then ns.Report("menu", err) end
end

-- Gaps between buttons are not hover. The catcher is not their child, so a
-- faded button does not drop the mouse, and it does not take the click.
local microCatcher

local function EnsureMicroCatcher()
    if microCatcher then return microCatcher end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:SetAlpha(1)
    created:Hide()
    microCatcher = created
    return created
end

local function ReadEdge(button, method)
    local fn = button[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, button)
    if ok and type(value) == "number" then return value end
end

local function MicroCorner()
    local tl, br, tlTop, tlLeft, brBottom, brRight
    local list = MicroList()
    for i = 1, #list do
        local button = list[i]
        if ns.Usable(button) and button.IsShown and button:IsShown() then
            local left, right = ReadEdge(button, "GetLeft"), ReadEdge(button, "GetRight")
            local top, bottom = ReadEdge(button, "GetTop"), ReadEdge(button, "GetBottom")
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

local function PlaceMicroCatcher()
    local box = EnsureMicroCatcher()
    if not box then return end
    if not ns.DB().enabled or ns.InEditMode() then
        box:Hide()
        return
    end
    local tl, br = MicroCorner()
    if not tl then
        box:Hide()
        box._quietA, box._quietB = nil, nil
        return
    end
    if box._quietA ~= tl or box._quietB ~= br then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", tl, "TOPLEFT")
        box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
        box._quietA, box._quietB = tl, br
    end
    local strata = tl.GetFrameStrata and tl:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = tl.GetFrameLevel and tl:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    local other = br.GetFrameLevel and br:GetFrameLevel()
    if type(other) == "number" and other < level then level = other end
    level = math.max(level - 1, 0)
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
    if not box:IsShown() then box:Show() end
end

local function MicroHot()
    if microCatcher and ns.Hit(microCatcher) then return true end
    local list = MicroList()
    for i = 1, #list do
        if ns.Hit(list[i]) then return true end
    end
    return false
end

local function UpdateMicro(elapsed)
    if not ns.DB().enabled then return end
    PlaceMicroCatcher()
    local show = ns.VisibilityShow("micro", false, MicroHot())
    local list = MicroList()
    for i = 1, #list do
        if ns.Usable(list[i]) then ns.UpdateFaded(list[i], show, elapsed) end
    end
end

-- Hover, bag slots, a drag, or Glance on keeps the button up. Setup can pin it on.
function ns.UpdateMenuButton(elapsed)
    UpdateMicro(elapsed)
    if not button or not button:IsShown() then return end
    local show = ns.VisibilityShow("menu", false, ns.Hit(button))
        or button._moved or ns.BagsShouldShow()
    ns.UpdateFaded(button, show, elapsed)
end

function ns.ResetMenu()
    bagSlotsPinned = false
    shownSlots = nil
    local function clear(name)
        local frame = _G[name]
        if frame then frame._quietChrome = nil end
    end
    for _, name in ipairs(MICRO_NAMES) do
        clear(name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, entry in ipairs(MICRO_BUTTONS) do
            if type(entry) == "string" then
                clear(entry)
            elseif entry then
                entry._quietChrome = nil
            end
        end
    end
    for _, name in ipairs(MENU_FRAMES) do
        clear(name)
    end
    if microCatcher then
        microCatcher:Hide()
        microCatcher._quietA, microCatcher._quietB = nil, nil
    end
    if button then button:Hide() end
    BuildMicroButtons()
    ns.EachBagFrame(function(frame)
        SetBagInput(frame, true)
    end)
end
