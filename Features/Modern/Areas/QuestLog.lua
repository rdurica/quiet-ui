local _, ns = ...

-- The quest log inside the world map (QuestMapFrame), shaped after a frame dump of the Forever 12.0 client. Its
-- parchment and gold frame art is held, so the lists stand bare on the map's dark panel; the search box and quest
-- count become dark fields, zone headers solid strips with an accent edge, the scroll bars flat.
-- The quest details page loses its parchment and reward art, its buttons become flat fields and its dark ink
-- turns light as on the NPC quest window. QuestMapFrame itself is never panelled or made movable. Headers are
-- pooled, so the list is scanned again whenever Blizzard rebuilds it.

local Modern = ns.Modern
local QuestLog = {}
Modern.QuestLog = QuestLog

local FRAME_ART = { "Border", "TopDetail", "Shadow" }
local DETAILS_ART = { "Bg", "SealMaterialBG" }
local REWARD_ART = { "Top", "Bottom", "Background" }
local BUTTONS = { "AbandonButton", "ShareButton", "TrackButton" }

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

local function HoldKeys(skin, frame, keys)
    if not ns.Usable(frame) then return end
    for _, key in ipairs(keys) do Hold(skin, frame[key]) end
end

local function Children(frame)
    if not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return {} end
    return { frame:GetChildren() }
end

-- The gold QuestLog-frame around a page: held without a replacement, the map panel already frames the log.
local function Frame(skin, page)
    if ns.Usable(page) then HoldKeys(skin, page.BorderFrame, FRAME_ART) end
end

-- A panel button: a flat field; the dividers Blizzard draws between the detail buttons go too.
local function Button(skin, button)
    if not ns.Usable(button) then return end
    Modern.Field(skin, button)
    if type(button.GetRegions) ~= "function" then return end
    for _, region in ipairs({ button:GetRegions() }) do
        local ok, layer = pcall(region.GetDrawLayer, region)
        if ok and layer == "OVERLAY" and type(region.SetAlpha) == "function" then Hold(skin, region) end
    end
end

-- Zone headers (pooled buttons with a CollapseButton), the story header and the separator.
function QuestLog.List(skin, quest)
    local scroll = ns.Usable(quest) and ns.Usable(quest.QuestsFrame) and quest.QuestsFrame.ScrollFrame
    local contents = ns.Usable(scroll) and scroll.Contents
    if not ns.Usable(contents) then return end
    for _, child in ipairs(Children(contents)) do
        if ns.Usable(child.CollapseButton) and child.ButtonText then
            Modern.Character.HoldArt(skin, child)
            Modern.Strip(skin, child)
        end
    end
    HoldKeys(skin, contents.StoryHeader, { "Background", "HighlightTexture", "Divider" })
    HoldKeys(skin, contents.Separator, { "Divider" })
end

function QuestLog.Details(skin, quest)
    local details = ns.Usable(quest) and ns.Usable(quest.QuestsFrame) and quest.QuestsFrame.DetailsFrame
    if not ns.Usable(details) then return end
    HoldKeys(skin, details, DETAILS_ART)
    Frame(skin, details)
    local back = details.BackFrame
    if ns.Usable(back) then
        Modern.Character.HoldArt(skin, back)
        Button(skin, back.BackButton)
    end
    for _, key in ipairs(BUTTONS) do Button(skin, details[key]) end
    local rewards = ns.Usable(details.RewardsFrameContainer) and details.RewardsFrameContainer.RewardsFrame
    HoldKeys(skin, rewards, REWARD_ART)
    if ns.Usable(details.ScrollFrame) then Modern.Character.ScrollBar(skin, details.ScrollFrame.ScrollBar) end
    Modern.InkTree(skin, details, { tone = Modern.Theme().text, heading = Modern.Npc.Heading, plain = true })
end

local function Quests(skin, quest)
    local scroll = ns.Usable(quest.QuestsFrame) and quest.QuestsFrame.ScrollFrame
    if not ns.Usable(scroll) then return end
    HoldKeys(skin, scroll, { "Background", "Edge" })
    Frame(skin, scroll)
    Modern.Field(skin, scroll.SearchBox)
    Modern.Field(skin, scroll.QuestLogCount or _G.QuestLogCount)
    Modern.Character.ScrollBar(skin, scroll.ScrollBar)
end

-- The events and map legend pages share the gold frame and the parchment list background.
local function Pages(skin, quest)
    local events = quest.EventsFrame
    if ns.Usable(events) then
        Frame(skin, events)
        if ns.Usable(events.ScrollBox) then Hold(skin, events.ScrollBox.Background) end
        Modern.Character.ScrollBar(skin, events.ScrollBar)
    end
    local legend = quest.MapLegend
    if ns.Usable(legend) then
        Frame(skin, legend)
        local scroll = legend.ScrollFrame
        if ns.Usable(scroll) then
            Hold(skin, scroll.Background)
            Modern.Character.ScrollBar(skin, scroll.ScrollBar)
        end
    end
end

function QuestLog.Apply(skin, quest)
    if not ns.Usable(quest) then return end
    Hold(skin, quest.VerticalSeparator)
    Quests(skin, quest)
    QuestLog.List(skin, quest)
    QuestLog.Details(skin, quest)
    Pages(skin, quest)
end
