local _, ns = ...

-- The 12.0 character window (Forever): pane backgrounds, equipment slots, the stats list and its
-- scroll bar, the vertical mode tabs and the stats sidebar tabs. The model scene backdrop is content and stays.
-- Stat rows come from a ScrollBox pool, so they are skinned again whenever the list updates.

local Modern = ns.Modern
local Character = {}
Modern.Character = Character

local SIDEBAR_TABS = 3
-- Section rows are taller than their title; their strip hugs the title. Shared with the list panes.
Character.STRIP = 22
-- A mode tab takes an equipment slot's size; this one when the slot cannot be measured.
local SLOT_SIZE = 37
local SIDEBAR_SELECTED = "UI-Character-Info-StatTab-Selected"

local styled = setmetatable({}, { __mode = "k" })  -- watched frame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Regions(frame)
    if not ns.Usable(frame) or type(frame.GetRegions) ~= "function" then return {} end
    return { frame:GetRegions() }
end

function Character.Children(frame)
    if not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return {} end
    return { frame:GetChildren() }
end

-- Every texture of the frame except `keep`.
function Character.HoldArt(skin, frame, keep)
    for _, region in ipairs(Regions(frame)) do
        -- A pooled frame is held again on every update; the skin's own strip or rule must stay.
        if IsTexture(region) and region ~= keep and not skin:Owns(frame, region) then skin:Hold(region) end
    end
end

local function AtlasOf(texture)
    if type(texture.GetAtlas) ~= "function" then return nil end
    local ok, atlas = pcall(texture.GetAtlas, texture)
    return ok and atlas or nil
end

-- Pane backgrounds, the stone art and the divider of the stats pane, the strip behind the level text.
local function Panes(skin, frame)
    Character.HoldArt(skin, frame.LeftPaneHost)
    local right = frame.RightPaneHost
    Character.HoldArt(skin, right)
    for _, child in ipairs(Character.Children(right)) do Character.HoldArt(skin, child) end
    local paperdoll = _G.PaperDollFrame
    if ns.Usable(paperdoll) then Character.HoldArt(skin, paperdoll.TopBackgroundStripHost) end
end

-- Equipment slots by name as well: a layout may nest them below PaperDollItemsFrame.
local SLOT_NAMES = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs",
    "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }

local function SlotList()
    local list, seen = {}, {}
    local function Add(slot)
        if ns.Usable(slot) and not seen[slot] and (slot.icon or slot.Icon) then
            seen[slot] = true
            list[#list + 1] = slot
        end
    end
    for _, slot in ipairs(Character.Children(_G.PaperDollItemsFrame)) do Add(slot) end
    for _, name in ipairs(SLOT_NAMES) do Add(_G["Character" .. name .. "Slot"]) end
    return list
end

function Character.Slots(skin)
    for _, slot in ipairs(SlotList()) do
        Modern.Bags.Item(skin, slot, true)
        Character.HoldArt(skin, slot.BorderFrame)
    end
end

local function SlotSize()
    local slot = _G.CharacterHeadSlot
    if ns.Usable(slot) and type(slot.GetSize) == "function" then
        local width = slot:GetSize()
        if type(width) == "number" and not ns.IsSecret(width) and width > 0 then return width end
    end
    return SLOT_SIZE
end

-- A vertical mode tab shrinks to an equipment slot's size; its icon, cropped square, fills it inside the border.
local function ModeTab(skin, tab)
    Modern.TabChrome(skin, tab)
    local size = SlotSize()
    skin:Set(tab, "SetSize", size, size)
    local icon = tab.Icon
    if not ns.Usable(icon) or type(icon.ClearAllPoints) ~= "function" then return end
    skin:Icon(icon)
    skin:Set(icon, "SetPoint", "TOPLEFT", tab, "TOPLEFT", 1, -1)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
end

-- Minimal scroll bar: the track art is held, the thumb becomes a flat bar in the border colour.
function Character.ScrollBar(skin, bar)
    if not ns.Usable(bar) then return end
    Modern.ScrollArrows(skin, bar)
    local track = bar.Track
    if not ns.Usable(track) then return end
    Character.HoldArt(skin, track)
    local thumb = track.Thumb
    if not ns.Usable(thumb) or type(thumb.CreateTexture) ~= "function" then return end
    Character.HoldArt(skin, thumb)
    local fill = skin:Own(thumb, "thumb", function()
        local texture = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
        texture:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, 0)
        texture:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 0)
        return texture
    end)
    if fill then
        fill:SetColorTexture(unpack(Modern.Theme().border))
        fill:Show()
    end
end

-- A thin rule in the border colour along the bottom of a header.
function Character.Rule(skin, line)
    if not ns.Usable(line) or type(line.CreateTexture) ~= "function" then return end
    local rule = skin:Own(line, "rule", function()
        local texture = line:CreateTexture(nil, "ARTWORK")
        texture:SetHeight(1)
        texture:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 4, 0)
        texture:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -4, 0)
        return texture
    end)
    if rule then
        rule:SetColorTexture(unpack(Modern.Theme().border))
        rule:Show()
    end
end

-- A category title loses its banner and becomes a section strip; a stat row loses its stripe.
local function StatLine(skin, line)
    if not ns.Usable(line) then return end
    if IsTexture(line.Background) then skin:Hold(line.Background) end
    if line.Title then Modern.Strip(skin, line, Character.STRIP) end
end

local function StatLines(skin, pane)
    local box = pane.ScrollBox
    local target = ns.Usable(box) and box.ScrollTarget
    for _, line in ipairs(Character.Children(target)) do StatLine(skin, line) end
    -- Older layouts keep fixed category frames on the pane.
    for _, key in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
        StatLine(skin, pane[key])
    end
end

local function StatsPane(skin)
    local pane = _G.CharacterStatsPaneScrollBox or _G.CharacterStatsPane
    if not ns.Usable(pane) then return end
    Character.HoldArt(skin, pane)
    StatLines(skin, pane)
    Character.ScrollBar(skin, pane.ScrollBar)
end

-- The stats sidebar tabs: frame art held, a bare icon without fill or border; the selected one, shown by Blizzard's
-- selected art, gets a 2 px accent line under it.
local function SidebarSelected(tab)
    for _, region in ipairs(Regions(tab)) do
        if IsTexture(region) and AtlasOf(region) == SIDEBAR_SELECTED then
            return type(region.IsShown) == "function" and region:IsShown() and region or nil, region
        end
    end
end

local function SidebarMark(skin, tab)
    local mark = skin:Own(tab, "sidebar mark", function()
        local texture = tab:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetHeight(2)
        texture:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -2)
        texture:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", 0, -2)
        return texture
    end)
    if not mark then return end
    mark:SetColorTexture(unpack(Modern.Theme().accent))
    mark:SetShown(SidebarSelected(tab) and true or false)
end

local function SidebarTab(skin, tab)
    if not ns.Usable(tab) then return end
    Character.HoldArt(skin, tab, tab.Icon)
    SidebarMark(skin, tab)
    styled[tab] = skin
    skin:Remember(tab, "modern sidebar tab", function() styled[tab] = nil end)
    if hooked[tab] then return end
    local _, marker = SidebarSelected(tab)
    if not marker then return end
    hooked[tab] = true
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if type(marker[method]) == "function" then
            pcall(hooksecurefunc, marker, method, function()
                local owner = styled[tab]
                if owner then ns.Profiler.Run("modern character", SidebarMark, owner, tab) end
            end)
        end
    end
end

local function Refresh(skin)
    Character.Slots(skin)
    StatsPane(skin)
    Character.Lists(skin)
end

-- New pool rows and late slots are skinned when the window opens and when the stats list updates.
local function Watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    local function Again()
        local skin = styled[frame]
        if skin then ns.Profiler.Run("modern character", Refresh, skin) end
    end
    if type(frame.HookScript) == "function" then pcall(frame.HookScript, frame, "OnShow", Again) end
    local pane = _G.CharacterStatsPaneScrollBox
    local box = ns.Usable(pane) and pane.ScrollBox
    if ns.Usable(box) and type(box.Update) == "function" then pcall(hooksecurefunc, box, "Update", Again) end
    if type(_G.PaperDollFrame_UpdateStats) == "function" then pcall(hooksecurefunc, "PaperDollFrame_UpdateStats", Again) end
    if type(_G.PaperDollItemSlotButton_Update) == "function" then
        pcall(hooksecurefunc, "PaperDollItemSlotButton_Update", function(slot)
            ns.Profiler.Run("modern character", Modern.Bags.Repaint, slot)
        end)
    end
    Character.WatchLists(Again)
end

function Character.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern character", function() styled[frame] = nil end)
    Panes(skin, frame)
    Character.Controls(skin, frame)
    for _, tab in ipairs(Character.Children(frame.ModeTabs)) do
        if ns.Usable(tab) and tab.SelectedTexture then ModeTab(skin, tab) end
    end
    for index = 1, SIDEBAR_TABS do SidebarTab(skin, _G["PaperDollSidebarTab" .. index]) end
    Refresh(skin)
    Watch(frame)
end
