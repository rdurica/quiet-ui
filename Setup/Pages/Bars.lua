local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

-- Twelve bars: a little tighter than a regular row so the table fits the window.
local BAR_ROW = 28

Setup.Pages.bars = function(widget, bars)
    widget.groupHeader = Setup.Section(bars, "Fade together",
        "Bars with the same Group number appear together on hover and fade together. Enemy and Friend keep an individual bar visible for a matching living target. Use the Groups tab to control visibility for the entire group.")
    widget.groupHeader:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, 0)
    widget.groupRows = {}
    local y = -30
    for index, info in ipairs(ns.BAR_ROWS) do
        local id = info.id
        local row = Setup.Stepper(bars, info.label, function(sign)
            Setup.NudgeGroup(id, sign)
        end)
        row:SetHeight(BAR_ROW)
        Setup.Stripe(row, index)
        row.label:SetPoint("LEFT", 8, 0)
        row.value:SetWidth(40)
        row.id = id
        row.hostile = Setup.TargetBox(row, function()
            draft.hostile[id] = not draft.hostile[id]
            Setup.Paint()
        end)
        row.friendly = Setup.TargetBox(row, function()
            draft.friendly[id] = not draft.friendly[id]
            Setup.Paint()
        end)
        row.friendly:SetPoint("RIGHT", row.minus, "LEFT", -24, 0)
        row.hostile:SetPoint("RIGHT", row.friendly, "LEFT", -16, 0)
        -- Spans the stepper so the column title uses the button top, same as Enemy and Friend.
        row.step = CreateFrame("Frame", nil, row)
        row.step:SetPoint("TOPLEFT", row.minus, "TOPLEFT", 0, 0)
        row.step:SetPoint("BOTTOMRIGHT", row.plus, "BOTTOMRIGHT", 0, 0)
        row:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, y)
        y = y - BAR_ROW
        widget.groupRows[#widget.groupRows + 1] = row
    end
    local first = widget.groupRows[1]
    widget.enemyHeader = Setup.ColumnLabel(bars, "Enemy")
    widget.friendHeader = Setup.ColumnLabel(bars, "Friend")
    widget.groupColumn = Setup.ColumnLabel(bars, "Group")
    -- The first row starts 30px under "Fade together", so these titles sit on its strip.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 26)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 26)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 26)
end
