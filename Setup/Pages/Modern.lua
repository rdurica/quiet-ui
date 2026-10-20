local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

local function Toggle(key)
    return function()
        draft[key] = not draft[key]
        Setup.Paint()
    end
end

-- Look and XP on the left, one checkbox per registered area on the right.
Setup.Pages.modern = function(widget, modern)
    local left = Setup.Column(modern, 0, Setup.COLUMN_W)
    widget.modernHeader = left:Add(Setup.Section(modern, "Modern",
        "Modernize gives Blizzard's windows and frames a quiet dark look. Theme and Background set the colours, Class colours tints with your class, and each area can be turned off on its own. Turning Modernize off restores the original look."), 30)
    widget.modernize = left:Add(Setup.Choice(modern, "Modernize", Toggle("modernize")))
    widget.modernTheme = left:Add(Setup.Stepper(modern, "Theme", function(sign)
        Setup.NudgeModernTheme(sign)
    end))
    widget.modernOpacity = left:Add(Setup.Stepper(modern, "Background", function(sign)
        Setup.NudgeModernOpacity(sign)
    end))
    widget.modernColors = left:Add(Setup.Choice(modern, "Class colours", Toggle("modernClassColors")))
    left:Gap(6)
    widget.modernResetPositions = left:Add(Setup.Button(modern, "Reset positions", function()
        ns.Modern.ResetPositions()
    end), 34, 0, false)
    left:Gap()
    widget.modernXPHeader = left:Add(Setup.Section(modern, "XP and reputation"), 30)

    local right = Setup.Column(modern, Setup.RIGHT_X, Setup.COLUMN_W)
    widget.modernAreaHeader = right:Add(Setup.Section(modern, "Areas"), 30)
    widget.modernOptions = { widget.modernTheme, widget.modernOpacity, widget.modernColors, widget.modernAreaHeader,
        widget.modernXPHeader, widget.modernResetPositions }
    widget.modernAreas = {}
    -- Registration order. The XP area heads its own section on the left.
    for _, area in ipairs(ns.Modern.Areas()) do
        local key = area.key
        local button = Setup.Choice(modern, area.label, function()
            draft.modernAreas[key] = not (draft.modernAreas[key] ~= false)
            Setup.Paint()
        end)
        if key == "status" then left:Add(button) else right:Add(button) end
        widget.modernAreas[#widget.modernAreas + 1] = { key = key, button = button }
        widget.modernOptions[#widget.modernOptions + 1] = button
    end
    widget.modernXPGain = left:Add(Setup.Choice(modern, "Show on big XP gain", Toggle("modernXPGain")))
    widget.modernOptions[#widget.modernOptions + 1] = widget.modernXPGain
end
