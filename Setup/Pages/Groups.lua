local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.groups = function(widget, groups)
    widget.visibilityHeader = Setup.Section(groups, "Group visibility",
        "Always visible keeps every member of the group on screen. Only on hover reveals the whole group when any member is hovered and overrides automatic triggers. Glance, Edit Mode, spell flyouts and cursor items still reveal it. Group modes override Enemy and Friend.")
    widget.visibilityHeader:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, 0)
    local groupAlwaysHeader = Setup.ColumnLabel(groups, "Always visible")
    groupAlwaysHeader:SetPoint("TOP", groups, "TOPLEFT", 380, 0)
    local groupHoverHeader = Setup.ColumnLabel(groups, "Only on hover")
    groupHoverHeader:SetPoint("TOP", groups, "TOPLEFT", 484, 0)
    widget.groupScroll = CreateFrame("ScrollFrame", nil, groups)
    widget.groupScroll:SetSize(Setup.CONTENT_W - 28, Setup.GROUP_VIEW_H)
    widget.groupScroll:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24)
    widget.groupContent = CreateFrame("Frame", nil, widget.groupScroll)
    widget.groupContent:SetSize(Setup.CONTENT_W - 28, 1)
    widget.groupScroll:SetScrollChild(widget.groupContent)
    local function ScrollGroups(delta)
        local max = math.max(0, widget.groupContent:GetHeight() - Setup.GROUP_VIEW_H)
        widget.groupScroll:SetVerticalScroll(math.max(0, math.min(max,
            widget.groupScroll:GetVerticalScroll() + delta)))
    end
    widget.groupScroll:EnableMouseWheel(true)
    widget.groupScroll:SetScript("OnMouseWheel", function(_, delta) ScrollGroups(-delta * 44) end)
    widget.groupUp = Setup.Mini(groups, "^", function() ScrollGroups(-44) end)
    widget.groupUp:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24)
    widget.groupDown = Setup.Mini(groups, "v", function() ScrollGroups(44) end)
    widget.groupDown:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24 - Setup.GROUP_VIEW_H + 22)
    widget.visibilityRows = {}
    for group = 1, #ns.BAR_ROWS do
        local id = group
        local row = CreateFrame("Frame", nil, widget.groupContent)
        row:SetSize(Setup.CONTENT_W - 28, 44)
        row.label = Setup.Section(row, "Group " .. id)
        row.label:SetPoint("TOPLEFT", 2, -2)
        row.members = Setup.Body(row, "")
        row.members:SetWidth(308)
        row.members:SetPoint("TOPLEFT", 2, -18)
        row.always = Setup.TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "always" and "always" or nil
            Setup.Paint()
        end)
        row.hover = Setup.TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "hover" and "hover" or nil
            Setup.Paint()
        end)
        row.always:SetPoint("CENTER", row, "TOPLEFT", 380, -16)
        row.hover:SetPoint("CENTER", row, "TOPLEFT", 484, -16)
        widget.visibilityRows[group] = row
    end
    local help = Setup.Body(groups, "Both unchecked: usual rules. Glance and Edit Mode still show hover-only frames.")
    help:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24 - Setup.GROUP_VIEW_H - 10)

end
