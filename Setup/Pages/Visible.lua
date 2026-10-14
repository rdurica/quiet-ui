local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.visible = function(widget, visible)
    widget.always = Setup.Section(visible, "Visibility",
        "Always visible keeps an element on screen. Only on hover overrides its automatic triggers; Glance and Edit Mode still reveal it. With both unchecked, its usual rules apply. Party and raid frames use their own exploration fade rules.")
    widget.always:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, 0)
    local alwaysHeader = Setup.ColumnLabel(visible, "Always visible")
    alwaysHeader:SetPoint("TOP", visible, "TOPLEFT", 380, 0)
    local hoverHeader = Setup.ColumnLabel(visible, "Only on hover")
    hoverHeader:SetPoint("TOP", visible, "TOPLEFT", 484, 0)
    widget.rows = {}
    local y = -20
    for _, info in ipairs(Setup.ROWS) do
        local key = info.key
        local row = CreateFrame("Frame", nil, visible)
        row:SetSize(Setup.CONTENT_W, 22)
        row.label = Setup.Body(row, info.label)
        row.label:SetWidth(308)
        row.label:SetPoint("LEFT", 2, 0)
        row.always = Setup.TargetBox(row, function()
            draft[key] = not draft[key]
            if draft[key] then draft.hoverOnly[key] = false end
            Setup.Paint()
        end)
        row.hover = Setup.TargetBox(row, function()
            if info.noHover then return end
            draft.hoverOnly[key] = not draft.hoverOnly[key]
            if draft.hoverOnly[key] then draft[key] = false end
            Setup.Paint()
        end)
        row.always:SetPoint("CENTER", row, "LEFT", 380, 0)
        row.hover:SetPoint("CENTER", row, "LEFT", 484, 0)
        row.key = key
        if info.noHover then
            row.hover:Disable()
            row.hover:SetAlpha(0.35)
            local width = row.label.GetStringWidth and row.label:GetStringWidth()
            row.label:SetWidth(type(width) == "number" and width or 180)
            row.help = Setup.Help(row, row.label, "Party and raid frames",
                "Uncheck Always visible to fade these frames while exploring.\nCombat, instances, hover, Glance and Edit Mode reveal them.")
        end
        row:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y)
        y = y - 24
        widget.rows[#widget.rows + 1] = row
    end

end
