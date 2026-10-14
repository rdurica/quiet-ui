local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.bars = function(widget, bars)
    local y
    widget.groupHeader = Setup.Section(bars, "Fade together",
        "Bars with the same Group number appear together on hover and fade together. Enemy and Friend keep an individual bar visible for a matching living target. Use the Groups tab to control visibility for the entire group.")
    widget.groupHeader:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, 0)
    widget.groupRows = {}
    y = -20
    for _, info in ipairs(ns.BAR_ROWS) do
        local id = info.id
        local row = Setup.Stepper(bars, info.label, function(sign)
            Setup.NudgeGroup(id, sign)
        end)
        row.id = id
        row.hostile = Setup.TargetBox(row, function()
            draft.hostile[id] = not draft.hostile[id]
            Setup.Paint()
        end)
        row.friendly = Setup.TargetBox(row, function()
            draft.friendly[id] = not draft.friendly[id]
            Setup.Paint()
        end)
        row.friendly:SetPoint("RIGHT", row.minus, "LEFT", -8, 0)
        row.hostile:SetPoint("RIGHT", row.friendly, "LEFT", -4, 0)
        -- Spans the stepper so the column title uses the button top, same as Enemy and Friend.
        row.step = CreateFrame("Frame", nil, row)
        row.step:SetPoint("TOPLEFT", row.minus, "TOPLEFT", 0, 0)
        row.step:SetPoint("BOTTOMRIGHT", row.plus, "BOTTOMRIGHT", 0, 0)
        row:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, y)
        y = y - 24
        widget.groupRows[#widget.groupRows + 1] = row
    end
    local first = widget.groupRows[1]
    widget.enemyHeader = Setup.ColumnLabel(bars, "Enemy")
    widget.friendHeader = Setup.ColumnLabel(bars, "Friend")
    widget.groupColumn = Setup.ColumnLabel(bars, "Group")
    -- The first row starts 20px under "Fade together", so these titles share that line.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 20)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 20)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 20)

end
