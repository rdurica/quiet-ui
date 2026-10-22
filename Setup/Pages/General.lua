local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

local ACTION_W = 180

Setup.Pages.general = function(widget, general)
    local column = Setup.Column(general, 0, Setup.CONTENT_W)
    widget.presetHeader = column:Add(Setup.Section(general, "Shared preset",
        "Share settings and an Edit Mode layout across characters. Save updates the selected preset for everyone using it. Without a preset, settings belong to this character."), 30)
    widget.presetSelector = Setup.Selector(general, "<no preset>", function()
        if widget.layoutMenu then widget.layoutMenu:Hide() end
        local entries = { { name = "<no preset>", selected = S.presetName == nil, select = function()
            if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
            S.selectedPresetId, S.presetName, S.presetLayout = nil, nil, nil
            Setup.Paint()
        end } }
        for _, item in ipairs(ns.Settings.PresetList()) do
            local id = item.id
            entries[#entries + 1] = { name = item.name, selected = S.selectedPresetId == id, select = function()
                local preset = ns.Settings.Presets()[id]
                if not preset then return end
                if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
                Setup.ReadDraft(preset.settings)
                S.selectedPresetId, S.presetName, S.presetLayout = id, preset.name, ns.Copy(preset.layout)
                Setup.Paint()
            end }
        end
        Setup.SelectMenu(widget, "presetMenu", widget.presetSelector, entries)
    end)
    column:Add(widget.presetSelector, 34)
    widget.newPreset = Setup.Button(general, "New preset", function()
        Setup.PresetDialog(widget, "Name the new shared preset.", "", function(name)
            local valid, err = ns.Settings.PresetName(name)
            if not valid then return false, err end
            S.selectedPresetId, S.presetName = nil, valid
            S.presetLayout = ns.Layout.CurrentRef()
            return true
        end)
    end)
    widget.renamePreset = Setup.Button(general, "Rename", function()
        Setup.PresetDialog(widget, "Rename this shared preset.", S.presetName, function(name)
            local valid, err = ns.Settings.PresetName(name, S.selectedPresetId)
            if not valid then return false, err end
            S.presetName = valid
            return true
        end)
    end)
    widget.deletePreset = Setup.Button(general, "Delete", function()
        local id = S.selectedPresetId
        if not id then return end
        Setup.PresetDialog(widget, 'Delete "' .. S.presetName .. '" for all characters? They will keep their last settings.', nil, function()
            if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
            ns.Settings.DeletePreset(id)
            Setup.LoadSavedDraft()
            if ns.Layout.SettingsChanged then ns.Layout.SettingsChanged() end
            if ns.ApplyAll then ns.ApplyAll() end
            return true
        end)
    end)
    for _, button in ipairs({ widget.newPreset, widget.renamePreset, widget.deletePreset }) do
        button:SetWidth(ACTION_W)
    end
    widget.newPreset:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -column.y)
    widget.renamePreset:SetPoint("TOPLEFT", general, "TOPLEFT", (Setup.CONTENT_W - ACTION_W) / 2, -column.y)
    widget.deletePreset:SetPoint("TOPRIGHT", general, "TOPRIGHT", 0, -column.y)
    column:Gap(34 + Setup.GAP)
    widget.layoutHeader = column:Add(Setup.Section(general, "Layout",
        "A preset uses the selected Edit Mode layout. Choosing one previews it immediately; Save keeps it, while closing cancels the preview. Without a preset, Force QuietUI layout selects the bundled layout on enable and restores your previous layout on disable."), 30)
    widget.layoutSelector = Setup.Selector(general, "Choose layout", function()
        if widget.presetMenu then widget.presetMenu:Hide() end
        local entries = {}
        for _, choice in ipairs(ns.Layout.Choices()) do
            local ref = choice.ref
            entries[#entries + 1] = { name = choice.name, selected = S.presetLayout and (
                ref.builtin and ref.builtin == S.presetLayout.builtin
                or not ref.builtin and ref.layoutName == S.presetLayout.layoutName
                    and ref.layoutType == S.presetLayout.layoutType), select = function()
                S.presetLayout = ns.Copy(ref)
                if ns.Layout.Preview then ns.Layout.Preview(S.presetLayout) end
                Setup.Paint()
            end }
        end
        if #entries == 0 then ns.Print("Edit Mode layouts are not available yet."); return end
        Setup.SelectMenu(widget, "layoutMenu", widget.layoutSelector, entries)
    end)
    widget.forceLayout = Setup.Choice(general, "Force QuietUI layout", function()
        draft.forceLayout = not draft.forceLayout
        Setup.Paint()
    end)
    -- Paint shows the selector with a preset and Force without one, in the same place.
    widget.forceLayout:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -column.y)
    widget.forceLayout:SetWidth(Setup.CONTENT_W)
    column:Add(widget.layoutSelector, 34 + Setup.GAP)
    widget.presetHelp = column:Add(Setup.Note(general, "Save updates the selected preset for every character. Without a preset, settings belong to this character."))
end
