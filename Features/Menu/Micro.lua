local _, ns = ...

-- The micro menu fades on its own: hover, edit mode, and Glance show it, and the Visible
-- row holds it. Also the chrome refresh, the button fade, the reset, and the registration.

local Menu = ns.Menu
local S = Menu.state

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
-- Frame access is slow on this client. The catcher's corners are read at most every MICRO_EVERY
-- seconds (hovering runs a pass each frame), and while every button sits at its alpha with the same
-- wanted state a pass skips the button walk; a full walk still runs with each placement.
local MICRO_EVERY = 0.1
local microPlaceAt = 0
local microShow
local microSettled = false

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
    microSettled = false
    microPlaceAt = 0
end

local function MicroList()
    if not microBuilt then BuildMicroButtons() end
    return microButtons
end

-- A container that also holds bars, bags, or the LFG eye keeps those children.
local function HoldsSpared(frame)
    return ns.Bars.TreeHas(frame, ns.Bars.IsQueue) or ns.Bars.TreeHas(frame, ns.Bars.IsBarFrame)
        or ns.Bars.TreeHas(frame, ns.Bars.IsBagRelated)
end

local function HoldsMicro(frame)
    return ns.Bars.TreeHas(frame, KnownMicro)
end

-- Parent alpha stays. Zeroing a container would hide the buttons inside it.
local function MuteMenuFrame(frame)
    if not ns.Usable(frame) then return end
    if ns.Bars.IsBarFrame(frame) or ns.Bars.IsBagRelated(frame) or KnownMicro(frame) then return end
    ns.HideTextures(frame)
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) and not ns.Bars.IsSpared(child) and not ns.Bars.IsBagRelated(child) and not KnownMicro(child) then
            if HoldsMicro(child) or HoldsSpared(child) then
                MuteMenuFrame(child)
            else
                ns.Bars.Mute(child)
            end
        end
    end
end

function Menu.RefreshChrome()
    if S.refreshing or not ns.DB().enabled then return end
    S.refreshing = true
    local ok, err = pcall(function()
        BuildMicroButtons()
        for _, name in ipairs(MENU_FRAMES) do
            local frame = _G[name]
            if frame and not frame._quietChrome then
                MuteMenuFrame(frame)
                frame._quietChrome = true
            end
        end
        S.EnsureButton()
    end)
    S.refreshing = false
    if not ok then ns.Report("menu", err) end
end

-- Gaps between buttons are not hover. The catcher is not their child, so a
-- faded button does not drop the mouse, and it does not take the click.
local microCatcher

local function EnsureMicroCatcher()
    if microCatcher then return microCatcher end
    local created = ns.Catcher.Create()
    if not created then return end
    created:SetAlpha(1)
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
    if not ns.DB().enabled or ns.World.InEditMode() then
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
    ns.Catcher.Strata(box, tl)
    local level = tl.GetFrameLevel and tl:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    local other = br.GetFrameLevel and br:GetFrameLevel()
    if type(other) == "number" and other < level then level = other end
    ns.Catcher.Level(box, math.max(level - 1, 0))
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
    local now = GetTime()
    local due = now >= microPlaceAt
    if due then
        PlaceMicroCatcher()
        microPlaceAt = now + MICRO_EVERY
    end
    local show = ns.Settings.VisibilityShow("micro", false, MicroHot()) and true or false
    if microSettled and show == microShow and not due then return end
    microShow = show
    microSettled = true
    local target = show and 1 or 0
    local list = MicroList()
    for i = 1, #list do
        local button = list[i]
        if ns.Usable(button) then
            ns.UpdateFaded(button, show, elapsed)
            if button._quietAlpha ~= target then microSettled = false end
        end
    end
end

-- Hover, bag slots, a drag, or Glance on keeps the button up. Setup can pin it on.
function Menu.UpdateButton(elapsed)
    UpdateMicro(elapsed)
    if not S.button or not S.button:IsShown() then return end
    local show = ns.Settings.VisibilityShow("menu", false, ns.Hit(S.button))
        or S.button._moved or Menu.BagsShouldShow()
    ns.UpdateFaded(S.button, show, elapsed)
end

function Menu.Reset()
    S.bagSlotsPinned = false
    S.shownSlots = nil
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
    if S.button then S.button:Hide() end
    BuildMicroButtons()
    ns.Bars.EachBagFrame(function(frame)
        S.SetBagInput(frame, true)
    end)
end

ns.Feature({
    name = "menu",
    apply = function()
        Menu.RefreshChrome()
        Menu.UpdateBagSlots()
    end,
    restore = function() Menu.Reset() end,
    fade = function(elapsed) Menu.UpdateButton(elapsed) end,
    tick = function() Menu.UpdateBagSlots() end,
    rescan = function(deep)
        if not deep then Menu.RefreshChrome() end
    end,
    events = {
        PLAYER_REGEN_ENABLED = function() Menu.RefreshChrome() end,
    },
    hooks = {
        -- Hooked arguments are not ours to forward.
        UpdateMicroButtons = function() Menu.RefreshChrome() end,
    },
})
