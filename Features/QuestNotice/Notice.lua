local _, ns = ...

-- The notice frame over the quest tracker: placement, style and text.

local Q = ns.QuestNotice
local S = Q.state
local TEXT_SCALE = Q.TEXT_SCALE

function Q.Hide()
    if S.frame and S.frame:IsShown() then S.frame:Hide(); S.frame:SetAlpha(0) end
end

local TRACKER_NAMES = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

local function Tracker()
    for i = 1, #TRACKER_NAMES do
        local tracker = _G[TRACKER_NAMES[i]]
        if tracker and ns.Usable(tracker) and Q.Call(tracker.IsShown, tracker) then return tracker end
    end
end

local function EnsureFrame()
    if S.frame then return S.frame end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    S.frame = created
    Q.Call(S.frame.EnableMouse, S.frame, false)
    Q.Call(S.frame.SetMouseClickEnabled, S.frame, false)
    Q.Call(S.frame.SetMouseMotionEnabled, S.frame, false)
    Q.Call(S.frame.SetFrameStrata, S.frame, "MEDIUM")
    S.titleText = S.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    S.titleText:SetPoint("TOPLEFT", S.frame, "TOPLEFT", 0, 0)
    S.titleText:SetJustifyH("LEFT")
    S.titleText:SetWordWrap(true)
    S.bodyText = S.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    S.bodyText:SetPoint("TOPLEFT", S.titleText, "BOTTOMLEFT", 0, 0)
    S.bodyText:SetJustifyH("LEFT")
    S.bodyText:SetWordWrap(true)
    Q.Hide()
    return S.frame
end

local function ScaleOf(region)
    local scale = Q.Try(region.GetEffectiveScale, region)
    if Q.Number(scale) and scale > 0 then return scale end
    return 1
end

local function Offset(value)
    if value == nil then return 0 end
    if Q.Number(value) then return value end
end

-- First slot under the quest header. Individual quest blocks are not consulted.
local function FirstSlot(tracker)
    local module = QuestObjectiveTracker
    if not (module and ns.Usable(module)) then module = QUEST_TRACKER_MODULE end
    if module and ns.Usable(module) then
        local contents = module.ContentsFrame
        local dx, dy = Offset(module.blockOffsetX), Offset(module.fromHeaderOffsetY)
        if contents and ns.Usable(contents) and dx and dy
            and Q.Number(Q.Try(contents.GetLeft, contents)) and Q.Number(Q.Try(contents.GetTop, contents)) then
            return contents, "TOPLEFT", dx, dy
        end
    end
    local header = tracker.Header
    local text = type(header) == "table" and header.Text
    if text and ns.Usable(text) and Q.Number(Q.Try(text.GetLeft, text)) and Q.Number(Q.Try(text.GetBottom, text)) then
        return text, "BOTTOMLEFT", 0, 0
    end
    return tracker, "TOPLEFT", 0, 0
end

local function Style(region, object, anchorScale, chosen)
    if type(object) ~= "table" or not ns.Usable(object) then return end
    local path, size, flags = Q.Try(object.GetFont, object)
    local r, g, b, a = Q.Try(object.GetTextColor, object)
    local noticeScale = ScaleOf(region)
    local textScale = TEXT_SCALE[chosen] or TEXT_SCALE.default
    if type(path) == "string" and Q.Number(size) and size > 0 then
        region:SetFont(path, size * textScale * anchorScale / noticeScale, type(flags) == "string" and flags or "")
    end
    if Q.Number(r) and Q.Number(g) and Q.Number(b) then
        region:SetTextColor(r, g, b, Q.Number(a) and a or 1)
    end
end

-- The rectangle, not the frame under the cursor. The notice sits in that area and must not keep itself up.
local function MouseOver(region)
    if not region or not ns.Usable(region) then return false end
    return Q.Try(region.IsMouseOver, region) == true
end

function Q.AreaHover()
    local tracker = Tracker()
    if not tracker then return false end
    if ns.Faders and ns.Faders.QuestTrackerHovered and ns.Faders.QuestTrackerHovered() then return true end
    return ns.Hit(tracker) or MouseOver(tracker)
end

function Q.Draw(alpha)
    local tracker = Tracker()
    if not tracker or ns.Glancing() or ns.World.InEditMode() or ns.Settings.Pinned("quests") or ns.Settings.OnlyOnHover("quests") then Q.Hide(); return end
    local width = Q.Call(tracker.GetWidth, tracker)
    if not Q.Number(width) or width <= 20 or not EnsureFrame() then Q.Hide(); return end
    local anchor, point, dx, dy = FirstSlot(tracker)
    local anchorScale = ScaleOf(anchor)
    local frameScale = ScaleOf(S.frame)
    local chosen = type(ns.Settings.QuestNoticeSize) == "function" and ns.Settings.QuestNoticeSize() or "default"
    local titleFont = ObjectiveTrackerHeaderFont or GameFontNormal
    local bodyFont = ObjectiveTrackerFont or GameFontHighlightSmall
    -- The tracker text size option resizes the same font objects in place.
    local _, titleSize = Q.Try(titleFont and titleFont.GetFont, titleFont)
    local _, bodySize = Q.Try(bodyFont and bodyFont.GetFont, bodyFont)
    if not Q.Number(titleSize) then titleSize = nil end
    if not Q.Number(bodySize) then bodySize = nil end
    if S.placed.anchor ~= anchor or S.placed.point ~= point or S.placed.dx ~= dx or S.placed.dy ~= dy or S.placed.width ~= width
        or S.placed.anchorScale ~= anchorScale or S.placed.frameScale ~= frameScale or S.placed.size ~= chosen
        or S.placed.titleFont ~= titleFont or S.placed.bodyFont ~= bodyFont
        or S.placed.titleSize ~= titleSize or S.placed.bodySize ~= bodySize then
        S.frame:ClearAllPoints()
        S.frame:SetPoint("TOPLEFT", anchor, point, dx * anchorScale / frameScale, dy * anchorScale / frameScale)
        S.frame:SetWidth(width)
        S.titleText:SetWidth(width)
        S.bodyText:SetWidth(width)
        Style(S.titleText, titleFont, anchorScale, chosen)
        Style(S.bodyText, bodyFont, anchorScale, chosen)
        S.placed.anchor, S.placed.point, S.placed.dx, S.placed.dy, S.placed.width = anchor, point, dx, dy, width
        S.placed.anchorScale, S.placed.frameScale, S.placed.size = anchorScale, frameScale, chosen
        S.placed.titleFont, S.placed.bodyFont = titleFont, bodyFont
        S.placed.titleSize, S.placed.bodySize = titleSize, bodySize
        -- A new font size changes the measured height.
        S.drawn = nil
    end
    if S.drawn ~= S.current or S.drawnWidth ~= width then
        S.titleText:SetText(S.current.title)
        local lines = {}
        if S.current.status then lines[#lines + 1] = S.current.status end
        for _, objective in ipairs(S.current.objectives) do
            local text = objective.text
            if objective.fulfilled ~= nil and objective.required ~= nil and objective.required > 0 then
                local progress = tostring(objective.fulfilled) .. "/" .. tostring(objective.required)
                if not text:find(progress, 1, true) then text = text .. " " .. progress end
            end
            lines[#lines + 1] = text
        end
        S.bodyText:SetText(table.concat(lines, "\n"))
        local titleHeight = S.titleText:GetStringHeight()
        local bodyHeight = S.bodyText:GetStringHeight()
        S.frame:SetHeight((Q.Number(titleHeight) and titleHeight or 0) + (Q.Number(bodyHeight) and bodyHeight or 0))
        S.drawn, S.drawnWidth = S.current, width
    end
    S.frame:SetAlpha(alpha)
    if not S.frame:IsShown() then S.frame:Show() end
end

