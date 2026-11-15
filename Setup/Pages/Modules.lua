local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

-- One checkbox per module with a line on what it covers. Unchecking hides the tabs of the module at once.
Setup.Pages.modules = function(widget, modules)
    local column = Setup.Column(modules, 0, Setup.CONTENT_W)
    widget.modulesHeader = column:Add(Setup.Section(modules, "Modules",
        "Switch on only the parts of QuietUI you want. A module that is off applies nothing, and its tabs leave this window. Save reloads the UI when the set changes."), 30)
    widget.moduleRows = {}
    for _, info in ipairs(Setup.MODULES) do
        local key = info.key
        local row = Setup.Choice(modules, info.label, function()
            draft.modules[key] = not draft.modules[key]
            Setup.Paint()
        end)
        column:Add(row, 24)
        column:Add(Setup.Note(modules, info.text), 24, 28)
        widget.moduleRows[#widget.moduleRows + 1] = { key = key, button = row }
    end
end
