local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

local GROUP_ROW = 44

Setup.Pages.groups = function(widget, groups)
    widget.visibilityHeader = Setup.Section(groups, "Group visibility",
        "Always visible keeps every member of the group on screen. Only on hover reveals the whole group when any member is hovered and overrides automatic triggers. Glance, Edit Mode, spell flyouts and cursor items still reveal it. Group modes override Enemy and Friend.")
    widget.visibilityHeader:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, 0)
    local groupAlwaysHeader = Setup.ColumnLabel(widget.visibilityHeader, "Always visible")
    groupAlwaysHeader:SetPoint("TOP", groups, "TOPLEFT", Setup.ALWAYS_X, -6)
    local groupHoverHeader = Setup.ColumnLabel(widget.visibilityHeader, "Only on hover")
    groupHoverHeader:SetPoint("TOP", groups, "TOPLEFT", Setup.HOVER_X, -6)
    widget.groupScroll = CreateFrame("ScrollFrame", nil, groups)
    widget.groupScroll:SetSize(Setup.CONTENT_W - 32, Setup.GROUP_VIEW_H)
    widget.groupScroll:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -30)
    widget.groupContent = CreateFrame("Frame", nil, widget.groupScroll)
    widget.groupContent:SetSize(Setup.CONTENT_W - 32, 1)
    widget.groupScroll:SetScrollChild(widget.groupContent)
    local function ScrollGroups(delta)
        local max = math.max(0, widget.groupContent:GetHeight() - Setup.GROUP_VIEW_H)
        widget.groupScroll:SetVerticalScroll(math.max(0, math.min(max,
            widget.groupScroll:GetVerticalScroll() + delta)))
    end
    widget.groupScroll:EnableMouseWheel(true)
    widget.groupScroll:SetScript("OnMouseWheel", function(_, delta) ScrollGroups(-delta * GROUP_ROW) end)
    widget.groupUp = Setup.Arrow(groups, true, function() ScrollGroups(-GROUP_ROW) end)
    widget.groupUp:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -30)
    widget.groupDown = Setup.Arrow(groups, false, function() ScrollGroups(GROUP_ROW) end)
    widget.groupDown:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -30 - Setup.GROUP_VIEW_H + 24)
    widget.visibilityRows = {}
    for group = 1, #ns.BAR_ROWS do
        local id = group
        local row = CreateFrame("Frame", nil, widget.groupContent)
        row:SetSize(Setup.CONTENT_W - 32, GROUP_ROW)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("TOPLEFT", 8, -6)
        row.label:SetText("Group " .. id)
        row.members = Setup.Note(row, "")
        row.members:SetWidth(Setup.ALWAYS_X - 60)
        row.members:SetPoint("TOPLEFT", 8, -24)
        row.always = Setup.TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "always" and "always" or nil
            Setup.Paint()
        end)
        row.hover = Setup.TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "hover" and "hover" or nil
            Setup.Paint()
        end)
        row.always:SetPoint("CENTER", row, "LEFT", Setup.ALWAYS_X, 0)
        row.hover:SetPoint("CENTER", row, "LEFT", Setup.HOVER_X, 0)
        widget.visibilityRows[group] = row
    end
    local help = Setup.Note(groups, "Both unchecked: usual rules. Glance and Edit Mode still show hover-only frames.")
    help:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -30 - Setup.GROUP_VIEW_H - 12)
end
