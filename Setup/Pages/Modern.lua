local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

Setup.Pages.modern = function(widget, modern)
    local column = 280
    widget.modernHeader = Setup.Section(modern, "Modern",
        "Modernize gives Blizzard's windows and frames a quiet dark look. Theme and Background set the colours, Class colours tints with your class, and each area can be turned off on its own. Turning Modernize off restores the original look.")
    widget.modernHeader:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, 0)
    widget.modernHeader:SetWidth(column - 16)
    widget.modernize = Setup.Choice(modern, "Modernize", function()
        draft.modernize = not draft.modernize
        Setup.Paint()
    end)
    widget.modernize:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, -22)
    widget.modernize:SetWidth(column - 16)
    widget.modernTheme = Setup.Stepper(modern, "Theme", function(sign)
        Setup.NudgeModernTheme(sign)
    end)
    widget.modernTheme:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, -48)
    widget.modernTheme:SetWidth(column - 16)
    widget.modernTheme.value:SetWidth(72)
    widget.modernOpacity = Setup.Stepper(modern, "Background", function(sign)
        Setup.NudgeModernOpacity(sign)
    end)
    widget.modernOpacity:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, -74)
    widget.modernOpacity:SetWidth(column - 16)
    widget.modernOpacity.value:SetWidth(72)
    widget.modernColors = Setup.Choice(modern, "Class colours", function()
        draft.modernClassColors = not draft.modernClassColors
        Setup.Paint()
    end)
    widget.modernColors:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, -100)
    widget.modernColors:SetWidth(column - 16)
    widget.modernAreaHeader = Setup.Section(modern, "Areas")
    widget.modernAreaHeader:SetPoint("TOPLEFT", modern, "TOPLEFT", column, 0)
    widget.modernAreaHeader:SetWidth(Setup.CONTENT_W - column)
    widget.modernOptions = { widget.modernTheme, widget.modernOpacity, widget.modernColors, widget.modernAreaHeader }
    widget.modernAreas = {}
    -- One checkbox per registered area, in registration order, in the right column
    -- so the page stays inside the compact setup height.
    for index, area in ipairs(ns.Modern.Areas()) do
        local key = area.key
        local button = Setup.Choice(modern, area.label, function()
            draft.modernAreas[key] = not (draft.modernAreas[key] ~= false)
            Setup.Paint()
        end)
        button:SetWidth(Setup.CONTENT_W - column)
        button:SetPoint("TOPLEFT", modern, "TOPLEFT", column, -22 - (index - 1) * 22)
        widget.modernAreas[index] = { key = key, button = button }
        widget.modernOptions[#widget.modernOptions + 1] = button
    end
    widget.modernResetPositions = Setup.Button(modern, "Reset positions", function()
        ns.Modern.ResetPositions()
    end)
    if not widget.modernResetPositions.label then
        widget.modernResetPositions.label = widget.modernResetPositions:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        widget.modernResetPositions.label:SetPoint("CENTER")
        widget.modernResetPositions.label:SetText("Reset positions")
    end
    widget.modernResetPositions:SetPoint("TOPLEFT", modern, "TOPLEFT", 0, -132)
    widget.modernOptions[#widget.modernOptions + 1] = widget.modernResetPositions
end
