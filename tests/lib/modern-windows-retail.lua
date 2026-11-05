-- Retail 12.0 (Midnight) window shapes, as built by Blizzard's PortraitFrameTemplate / ButtonFrameTemplate
-- (SharedUIPanelTemplates.xml), PanelTabButtonTemplate and WorldMapFrame (Blizzard_WorldMap.xml).
-- Every chrome texture a frame owns is listed in frame.chromeList so a test can assert on all of them.
local R = {}

local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
    "LeftEdge", "RightEdge", "Center" }

local function texture(parent, name, layer, list)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture("Interface\\FrameGeneral\\" .. name)
    t:SetAlpha(0.9)
    if list then list[#list + 1] = t end
    return t
end

-- NineSlicePanelTemplate: a child frame whose pieces are textures under the piece names.
function R.nineSlice(parent, list)
    local slice = CreateFrame("Frame", nil, parent)
    for _, key in ipairs(NINE) do slice[key] = texture(slice, "NineSlice-" .. key, "BORDER", list) end
    return slice
end

-- InsetFrameTemplate: a frame with its own NineSlice and Bg.
function R.inset(parent, list)
    local inset = CreateFrame("Frame", nil, parent)
    inset.Bg = texture(inset, "Inset-Bg", "BACKGROUND", list)
    inset.NineSlice = R.nineSlice(inset, list)
    return inset
end

-- Fills `frame` with the PortraitFrameTemplate parts. opts.inset == false leaves the Inset out.
function R.portraitParts(frame, opts)
    opts = opts or {}
    local list = frame.chromeList or {}
    frame.chromeList = list
    frame.NineSlice = R.nineSlice(frame, list)
    frame.Bg = texture(frame, "UI-Background-Rock", "BACKGROUND", list)
    frame.TopTileStreaks = texture(frame, "TopTileStreaks", "BORDER", list)
    frame.PortraitContainer = CreateFrame("Frame", nil, frame)
    frame.PortraitContainer.portrait = texture(frame.PortraitContainer, "Portrait", "OVERLAY", list)
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString(nil, "OVERLAY")
    frame.TitleContainer.TitleText:SetText((frame:GetName() or "Window") .. " title")
    frame.CloseButton = CreateFrame("Button", nil, frame)
    if opts.inset ~= false then frame.Inset = R.inset(frame, list) end
    return frame
end

function R.window(name, opts)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(480, 420)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 31, -71)
    return R.portraitParts(frame, opts)
end

-- PanelTabButtonTemplate. chromeList holds the six tab art textures; the hover highlights are extra.
function R.tab(parent, name)
    local tab = CreateFrame("Button", name, parent)
    tab:SetSize(80, 32)
    tab.chromeList = {}
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
        tab[key] = texture(tab, "Tab-" .. key, "BACKGROUND", tab.chromeList)
    end
    tab.LeftHighlight = texture(tab, "Tab-LeftHighlight", "HIGHLIGHT")
    tab.Text = tab:CreateFontString(nil, "OVERLAY")
    tab.Text:SetText(name)
    return tab
end

-- Content art a window must keep: a page/tree/model frame with a texture and a nested model frame.
function R.content(parent, key, alpha)
    local content = CreateFrame("Frame", nil, parent)
    parent[key] = content
    content.art = content:CreateTexture(nil, "ARTWORK")
    content.art:SetTexture("Interface\\Content\\" .. key)
    content.art:SetAlpha(alpha or 0.73)
    content.Model = CreateFrame("Frame", nil, content)
    content.Model.back = content.Model:CreateTexture(nil, "BACKGROUND")
    content.Model.back:SetTexture("Interface\\Content\\" .. key .. "Back")
    content.Model.back:SetAlpha((alpha or 0.73) - 0.1)
    return content
end

-- A button whose art Blizzard sets through SetNormalTexture / SetHighlightTexture (close, maximize, minimize).
function R.artButton(parent, name, list)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(27, 28)
    button.normal = texture(button, name, "ARTWORK", list)
    button.highlight = texture(button, name .. "-Highlight", "HIGHLIGHT", list)
    button.GetNormalTexture = function() return button.normal end
    button.GetHighlightTexture = function() return button.highlight end
    return button
end

-- UIPanelButtonTemplate: three-piece art, a text and a highlight.
function R.panelButton(parent, label, list)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(104, 22)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        button[key] = texture(button, "UIPanelButton-" .. key, "BACKGROUND", list)
    end
    button.Text = button:CreateFontString(nil, "OVERLAY")
    button.Text:SetText(label)
    return button
end

-- A breadcrumb of the map's navBar (NavButtonTemplate): art, arrow, selected and highlight textures, the text
-- and the dropdown arrow as a child button that stays.
function R.crumb(bar, label)
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(106, 30)
    for _, piece in ipairs({ { "Crumb", "ARTWORK" }, { "Crumb-Arrow", "OVERLAY" }, { "Crumb-Selected", "OVERLAY" },
        { "Crumb-Highlight", "HIGHLIGHT" } }) do
        texture(button, piece[1], piece[2], bar.crumbArt)
    end
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetText(label)
    button.MenuArrowButton = CreateFrame("Button", nil, button)
    button.MenuArrowButton.art = texture(button.MenuArrowButton, "Crumb-MenuArrow", "ARTWORK")
    return button
end

local function inked(parent, name, value)
    local font = parent:CreateFontString(name, "OVERLAY")
    font:SetText(value)
    font:SetFont("Fonts\\MORPHEUS.TTF", 13, "")
    font:SetTextColor(0.18, 0.12, 0.06, 1)
    -- The mock keeps no font string names.
    if name then font.GetName = function() return name end end
    return font
end

-- QuestMapFrame inside the map, as dumped from the Forever client: the quest list (QuestScrollFrame) with its
-- search box, quest count, gold frame, minimal scroll bar and pooled zone headers, and the details page.
-- quest.art lists every texture the Map area holds; quest.content what must stay.
local function questLog(map)
    local quest = CreateFrame("Frame", "QuestMapFrame", map)
    quest:SetPoint("TOPRIGHT", map, "TOPRIGHT", -3, -25)
    local art = {}
    quest.art = art
    quest.VerticalSeparator = texture(quest, "InnerRightTile", "OVERLAY", art)
    quest.QuestsFrame = CreateFrame("Frame", nil, quest)
    local scroll = CreateFrame("ScrollFrame", "QuestScrollFrame", quest.QuestsFrame)
    quest.QuestsFrame.ScrollFrame = scroll
    scroll.Background = texture(scroll, "QuestLog-main-background", "BACKGROUND", art)
    scroll.Edge = texture(scroll, "questlog_line_scrollbar", "OVERLAY", art)
    scroll.SearchBox = CreateFrame("EditBox", nil, scroll)
    local count = CreateFrame("Frame", "QuestLogCount", scroll)
    for _, field in ipairs({ scroll.SearchBox, count }) do
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            field[key] = texture(field, "common-search-border-" .. key, "BACKGROUND", art)
        end
    end
    scroll.BorderFrame = CreateFrame("Frame", nil, scroll)
    for _, key in ipairs({ "Border", "TopDetail", "Shadow" }) do
        scroll.BorderFrame[key] = texture(scroll.BorderFrame, "QuestLog-frame-" .. key, "BORDER", art)
    end
    scroll.ScrollBar = CreateFrame("Frame", nil, scroll)
    scroll.ScrollBar.Track = CreateFrame("Frame", nil, scroll.ScrollBar)
    texture(scroll.ScrollBar.Track, "minimal-scrollbar-track", "ARTWORK", art)
    scroll.ScrollBar.Track.Thumb = CreateFrame("Button", nil, scroll.ScrollBar.Track)
    texture(scroll.ScrollBar.Track.Thumb, "minimal-scrollbar-thumb", "ARTWORK", art)
    local contents = CreateFrame("Frame", nil, scroll)
    scroll.Contents = contents
    function quest.header(label)
        local header = CreateFrame("Button", nil, contents)
        header:SetSize(289, 21)
        texture(header, "common-button-list-collapseExpand", "ARTWORK", art)
        header.ButtonText = header:CreateFontString(nil, "OVERLAY")
        header.ButtonText:SetText(label)
        header.CollapseButton = CreateFrame("Button", nil, header)
        header.CollapseButton.art = texture(header.CollapseButton, "QuestLog-minus", "ARTWORK")
        return header
    end
    quest.header("Teldrassil")
    local title = CreateFrame("Button", nil, contents)
    title.Text = title:CreateFontString(nil, "OVERLAY")
    title.Text:SetText("[7] Timberling Seeds")
    title.Text:SetTextColor(1, 0.82, 0, 1)
    title.HighlightTexture = texture(title, "QuestLog-quest-glow-yellow", "BORDER")
    quest.content = { title, title.Text, title.HighlightTexture }

    local details = CreateFrame("Frame", nil, quest.QuestsFrame)
    quest.QuestsFrame.DetailsFrame = details
    details.Bg = texture(details, "QuestDetailsBackgrounds", "BACKGROUND", art)
    details.SealMaterialBG = texture(details, "SealMaterialBG", "BORDER", art)
    details.BorderFrame = CreateFrame("Frame", nil, details)
    details.BorderFrame.Border = texture(details.BorderFrame, "QuestLog-frame", "BORDER", art)
    details.BackFrame = CreateFrame("Frame", nil, details)
    texture(details.BackFrame, "QuestLog-reward-top-frame", "BORDER", art)
    details.BackFrame.BackButton = R.panelButton(details.BackFrame, "Back", art)
    for _, key in ipairs({ "AbandonButton", "ShareButton", "TrackButton" }) do
        details[key] = R.panelButton(details, key, art)
    end
    texture(details.ShareButton, "UI-Frame-BtnDivMiddle", "OVERLAY", art)
    details.RewardsFrameContainer = CreateFrame("Frame", nil, details)
    local rewards = CreateFrame("Frame", nil, details.RewardsFrameContainer)
    details.RewardsFrameContainer.RewardsFrame = rewards
    for _, key in ipairs({ "Top", "Bottom", "Background" }) do
        rewards[key] = texture(rewards, "QuestLog-reward-" .. key, "BORDER", art)
    end
    details.ScrollFrame = CreateFrame("ScrollFrame", "QuestMapDetailsScrollFrame", details)
    details.ScrollFrame.Contents = CreateFrame("Frame", nil, details.ScrollFrame)
    quest.heading = inked(details.ScrollFrame.Contents, "QuestInfoTitleHeader", "Timberling Seeds")
    quest.description = inked(details.ScrollFrame.Contents, nil, "Bring me eight Timberling Seeds.")
    function quest.ink(value) return inked(details.ScrollFrame.Contents, nil, value) end
    return quest
end

-- WorldMapFrame 12.0 after a frame dump of the Forever client: chrome on BorderFrame
-- (PortraitFrameTemplateMinimizable) with the close and maximize / minimize buttons, the canvas in
-- ScrollContainer, the zone breadcrumb (navBar), the tracking filter and pin buttons, and the quest log as the
-- child QuestMapFrame (a global too). Returns the map.
function R.worldMap()
    local map = CreateFrame("Frame", "WorldMapFrame", UIParent)
    map:SetSize(1000, 700)
    map:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 31, -71)
    map.BlackoutFrame = CreateFrame("Frame", nil, map)
    map.BlackoutFrame.Blackout = map.BlackoutFrame:CreateTexture(nil, "BACKGROUND")
    map.BlackoutFrame.Blackout:SetAlpha(0.5)
    map.ScrollContainer = CreateFrame("Frame", nil, map)
    map.ScrollContainer.canvas = map.ScrollContainer:CreateTexture(nil, "ARTWORK")
    map.ScrollContainer.canvas:SetTexture("Interface\\WorldMap\\Canvas")
    local border = CreateFrame("Frame", nil, map)
    map.BorderFrame = border
    border.chromeList = {}
    R.portraitParts(border)
    border.InsetBorderTop = texture(border, "InnerTopTile", "BORDER", border.chromeList)
    border.CloseButton = R.artButton(border, "RedButton-Exit", border.chromeList)
    border.MaximizeMinimizeFrame = CreateFrame("Frame", nil, border)
    border.MaximizeMinimizeFrame.MaximizeButton = R.artButton(border.MaximizeMinimizeFrame, "RedButton-Expand",
        border.chromeList)
    border.MaximizeMinimizeFrame.MinimizeButton = R.artButton(border.MaximizeMinimizeFrame, "RedButton-Condense",
        border.chromeList)

    local bar = CreateFrame("Frame", nil, map)
    map.navBar = bar
    bar.crumbArt = {}
    texture(bar, "NavBar-Bg", "BACKGROUND", bar.crumbArt)
    texture(bar, "UI-Frame-InnerBotTile", "BORDER", bar.crumbArt)
    bar.overlay = CreateFrame("Frame", nil, bar)
    texture(bar.overlay, "NavBar-Overlay", "OVERLAY", bar.crumbArt)
    bar.overflowButton = R.crumb(bar, "")
    bar.homeButton = R.crumb(bar, "World")
    R.crumb(bar, "Kalimdor")
    NavBar_AddButton = function(navBar, data) R.crumb(navBar, data.name) end

    local filter = CreateFrame("Button", nil, map)
    map.WorldMapTrackingOptionsButton = filter
    filter.Icon = texture(filter, "common-dropdown-a-button", "ARTWORK")
    local pin = CreateFrame("Button", nil, map)
    map.WorldMapTrackingPinButton = pin
    pin.trackingArt = {}
    texture(pin, "MapCornerShadow-Right", "BACKGROUND", pin.trackingArt)
    pin.Background = texture(pin, "MiniMap-TrackingBackground", "BACKGROUND", pin.trackingArt)
    pin.Border = texture(pin, "MiniMap-TrackingBorder", "OVERLAY", pin.trackingArt)
    texture(pin, "UI-Minimap-ZoomButton-Highlight", "HIGHLIGHT", pin.trackingArt)
    pin.Icon = texture(pin, "Waypoint-MapPin-Untracked", "ARTWORK")

    local quest = questLog(map)
    map.QuestLog = quest
    map.QuestMapFrame = quest
    QuestLogQuests_Update = function() quest.header("Darnassus") end
    QuestMapFrame_ShowQuestDetails = function() quest.ink("Reward text") end
    return map
end

-- Every frame and region at or under root, for snapshot / diff.
function R.all(root, out)
    out = out or {}
    out[#out + 1] = root
    for _, region in ipairs(root._regions) do out[#out + 1] = region end
    for _, child in ipairs(root._children) do R.all(child, out) end
    return out
end

-- True when the object, or an ancestor below `stop`, is hidden or at alpha 0.
function R.invisible(object, stop)
    local p = object
    while p and p ~= stop do
        if p._shown == false or p._alpha == 0 then return true end
        p = p._parent
    end
    return false
end

-- Comma list of chrome texture names still visible ("" when all are hidden), for a readable failure.
function R.visibleChrome(frame, stop)
    local names = {}
    for i, texture in ipairs(frame.chromeList or {}) do
        if not R.invisible(texture, stop or frame) then
            names[#names + 1] = (tostring(texture._texture or i):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

-- True when any region at or under frame is the theme's dark fill, flat or as the bottom of a lit gradient.
function R.dark(frame)
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == 0.075 then return true end
        if region._gradient and region._gradient[2][1] == 0.075 then return true end
    end
    for _, child in ipairs(frame._children) do
        if R.dark(child) then return true end
    end
    return false
end

return R
