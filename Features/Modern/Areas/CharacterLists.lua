local _, ns = ...

-- Reputation and Skills panes of the Forever character window: a pooled ScrollBox of collapsible headers
-- (common-button-list art with a StateIcon) and rows whose Content holds a bar, plus a detail pane with one bar.
-- Headers become a title with a thin rule, bars a dark field with a thin border; the coloured fill stays.

local Modern = ns.Modern
local Character = Modern.Character

local LISTS = {
    { frame = "ReputationFrame", bar = "ReputationBar", detail = "ReputationDetailFrame", detailBar = "StandingBar" },
    { frame = "SkillsFrame", bar = "SkillsBar", detail = "SkillDetailFrame", detailBar = "RankBar" },
}

local function FillOf(bar)
    if bar.Fill then return bar.Fill end
    if type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local ok, fill = pcall(bar.GetStatusBarTexture, bar)
    return ok and fill or nil
end

local function Bar(skin, bar)
    if not ns.Usable(bar) then return end
    Character.HoldArt(skin, bar, FillOf(bar))
    skin:Panel(bar)
    skin:Border(bar)
end

local function Row(skin, row, list)
    if not ns.Usable(row) then return end
    if row.StateIcon then
        Character.HoldArt(skin, row, row.StateIcon)
        Character.Rule(skin, row)
        return
    end
    local content = row.Content
    if ns.Usable(content) then Bar(skin, content[list.bar]) end
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
    local detail = frame[list.detail]
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
