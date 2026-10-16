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

-- WorldMapFrame 12.0: chrome on BorderFrame (PortraitFrameTemplateMinimizable), canvas in ScrollContainer,
-- the quest log as the child QuestMapFrame (a global too). Returns the map.
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
    map.BorderFrame = CreateFrame("Frame", nil, map)
    map.BorderFrame.chromeList = {}
    R.portraitParts(map.BorderFrame)
    map.BorderFrame.InsetBorderTop = texture(map.BorderFrame, "InnerTopTile", "BORDER", map.BorderFrame.chromeList)
    map.BorderFrame.MaximizeMinimizeFrame = CreateFrame("Frame", nil, map.BorderFrame)
    local quest = CreateFrame("Frame", "QuestMapFrame", map)
    quest:SetPoint("TOPRIGHT", map, "TOPRIGHT", -8, -30)
    quest.Background = quest:CreateTexture(nil, "BACKGROUND")
    quest.Background:SetTexture("Interface\\QuestFrame\\QuestMapBackground")
    quest.Background:SetAlpha(0.8)
    quest.DetailsFrame = CreateFrame("Frame", nil, quest)
    quest.DetailsFrame.art = quest.DetailsFrame:CreateTexture(nil, "ARTWORK")
    quest.DetailsFrame.art:SetAlpha(0.77)
    map.QuestMapFrame = quest
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

-- True when any region at or under frame is the theme's dark fill.
function R.dark(frame)
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == 0.05 then return true end
    end
    for _, child in ipairs(frame._children) do
        if R.dark(child) then return true end
    end
    return false
end

return R
