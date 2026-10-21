local _, ns = ...

-- Reputation, Skills, Currency and Statistics panes of the Forever character window: a pooled ScrollBox of collapsible headers
-- (common-button-list art with a StateIcon) and rows whose Content holds a bar, plus a detail pane with one bar.
-- Headers become section strips with a light title, bars a borderless dark track as tall as their fill; the coloured
-- fill stays.
-- Currency and statistics rows have no bar and keep their icon, texts and hover art.

local Modern = ns.Modern
local Character = Modern.Character

local LISTS = {
    { frame = "ReputationFrame", bar = "ReputationBar", detail = "ReputationDetailFrame", detailBar = "StandingBar" },
    { frame = "SkillsFrame", bar = "SkillsBar", detail = "SkillDetailFrame", detailBar = "RankBar" },
    { frame = "TokenFrame" },
    { frame = "StatisticsFrame" },
}

local function FillOf(bar)
    if bar.Fill then return bar.Fill end
    if type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local ok, fill = pcall(bar.GetStatusBarTexture, bar)
    return ok and fill or nil
end

-- Blizzard's fill is about half as tall as the bar frame; the track takes the fill's height, centred like it.
local TRACK = 15

local function TrackHeight(fill)
    local height = ns.Usable(fill) and type(fill.GetHeight) == "function" and fill:GetHeight()
    if type(height) == "number" and not ns.IsSecret(height) and height > 0 then return height end
    return TRACK
end

local function Bar(skin, bar)
    if not ns.Usable(bar) or type(bar.CreateTexture) ~= "function" then return end
    local fill = FillOf(bar)
    Character.HoldArt(skin, bar, fill)
    local track = skin:Own(bar, "track", function()
        local texture = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetPoint("LEFT", bar, "LEFT", 0, 0)
        texture:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        return texture
    end)
    track:SetHeight(TrackHeight(fill))
    track:SetColorTexture(unpack(Modern.Theme().track))
    track:Show()
end

local function Row(skin, row, list)
    if not ns.Usable(row) then return end
    if row.StateIcon then
        Character.HoldArt(skin, row, row.StateIcon)
        Modern.Strip(skin, row, Character.STRIP)
        if ns.Usable(row.Name) and type(row.Name.GetTextColor) == "function" then
            local text = Modern.Theme().text
            skin:Set(row.Name, "SetTextColor", text[1], text[2], text[3], 1)
        end
        return
    end
    local content = row.Content
    if list.bar and ns.Usable(content) then Bar(skin, content[list.bar]) end
end

local function List(skin, list)
    local frame = _G[list.frame]
    if not ns.Usable(frame) then return end
    local box = frame.ScrollBox
    if ns.Usable(box) then
        -- The keyless children of the ScrollBox carry the long divider lines.
        for _, child in ipairs(Character.Children(box)) do
            if child ~= box.ScrollTarget then Character.HoldArt(skin, child) end
        end
        for _, row in ipairs(Character.Children(box.ScrollTarget)) do Row(skin, row, list) end
    end
    Character.ScrollBar(skin, frame.ScrollBar)
    local detail = list.detail and frame[list.detail]
    if ns.Usable(detail) then
        if ns.Usable(detail.Divider) then skin:Hold(detail.Divider) end
        Bar(skin, detail[list.detailBar])
    end
end

function Character.Lists(skin)
    for _, list in ipairs(LISTS) do List(skin, list) end
end

-- Rows are pooled: the panes are skinned again when they open and when their list updates.
function Character.WatchLists(again)
    for _, list in ipairs(LISTS) do
        local frame = _G[list.frame]
        if ns.Usable(frame) then
            if type(frame.HookScript) == "function" then pcall(frame.HookScript, frame, "OnShow", again) end
            local box = frame.ScrollBox
            if ns.Usable(box) and type(box.Update) == "function" then pcall(hooksecurefunc, box, "Update", again) end
        end
    end
end
