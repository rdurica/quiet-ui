local _, ns = ...

-- Shared presets: CRUD, the effective settings, and the personal snapshot.

local snapshotChar, snapshotPreset

local KEYS = { "visible", "hoverOnly", "groupVisibility", "forceLayout", "player", "playerThresholdKind", "playerThresholdPercent", "requireLivingTarget", "groupAuras", "alwaysShowDebuffs", "questNotice", "questNoticeSize", "chatTabs", "questMobs",
    "chat", "chatFade", "groups", "hostile", "friendly", "range", "autoHideParty", "highlights" }

function ns.Settings.CopySettings(source, target)
    target = target or {}
    ns.Settings.MigrateOnce(source)
    for _, key in ipairs(KEYS) do target[key] = ns.Copy(source[key]) end
    return target
end

function ns.Settings.Presets()
    local db = ns.DB()
    if type(db.presets) ~= "table" then db.presets = {} end
    return db.presets
end

local function PresetFor(char)
    local preset = char.presetId and ns.Settings.Presets()[char.presetId]
    if type(preset) ~= "table" then
        char.presetId = nil
        return nil
    end
    return preset
end

function ns.Settings.ActivePreset()
    return PresetFor(ns.Settings.CharDB())
end

function ns.Settings.Effective()
    local char = ns.Settings.CharDB()
    local preset = PresetFor(char)
    if preset then
        ns.Settings.MigrateOnce(preset.settings)
        if snapshotChar ~= char or snapshotPreset ~= preset then
            ns.Settings.CopySettings(preset.settings, char)
            snapshotChar, snapshotPreset = char, preset
        end
        return preset.settings
    end
    return char
end

function ns.Settings.PresetInterfaceStyle(preset)
    if type(preset.interfaceStyle) == "number" then return preset.interfaceStyle end
    local style = ns.LayoutInterfaceStyle and ns.LayoutInterfaceStyle(preset.layout)
        or (preset.layout and preset.layout.interfaceStyle)
    if style == nil and not ns.LayoutInterfaceStyle then style = 0 end
    if style ~= nil then preset.interfaceStyle = style end
    return style
end

function ns.Settings.PresetCompatible(preset)
    local style = ns.Settings.PresetInterfaceStyle(preset)
    return style ~= nil and style == (ns.CurrentInterfaceStyle and ns.CurrentInterfaceStyle() or 0)
end

function ns.Settings.PresetList()
    local list = {}
    for id, preset in pairs(ns.Settings.Presets()) do
        if ns.Settings.PresetCompatible(preset) then
            list[#list + 1] = { id = id, name = preset.name }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function ns.Settings.PresetName(name, id)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Enter a preset name." end
    for other, preset in pairs(ns.Settings.Presets()) do
        if other ~= id and preset.name:lower() == name:lower() then
            return nil, "A preset with that name already exists."
        end
    end
    return name
end

function ns.Settings.SavePreset(id, name, layout, settings)
    local valid, err = ns.Settings.PresetName(name, id)
    if not valid then return nil, err end
    local db = ns.DB()
    if id and not ns.Settings.Presets()[id] then return nil, "That preset no longer exists." end
    if not id then
        db.nextPresetId = (db.nextPresetId or 0) + 1
        id = tostring(db.nextPresetId)
    end
    local saved = ns.Settings.CopySettings(settings)
    saved.forceLayout = nil
    local style = ns.LayoutInterfaceStyle and ns.LayoutInterfaceStyle(layout)
        or (layout and layout.interfaceStyle)
        or (ns.CurrentInterfaceStyle and ns.CurrentInterfaceStyle() or 0)
    ns.Settings.Presets()[id] = { name = valid, layout = ns.Copy(layout), settings = saved, interfaceStyle = style }
    return id
end

function ns.Settings.ActivatePreset(id, settings)
    local char = ns.Settings.CharDB()
    if id and not ns.Settings.Presets()[id] then return false end
    if id and not ns.Settings.PresetCompatible(ns.Settings.Presets()[id]) then
        return false, "That preset is not available for the current interface mode."
    end
    if settings then ns.Settings.CopySettings(settings, char) else ns.Settings.Effective() end
    char.presetId = id
    snapshotChar, snapshotPreset = nil, nil
    if id then ns.Settings.CopySettings(ns.Settings.Presets()[id].settings, char) end
    return true
end

function ns.Settings.DeletePreset(id)
    if ns.Settings.CharDB().presetId == id then ns.Settings.Effective(); ns.Settings.CharDB().presetId = nil end
    ns.Settings.Presets()[id] = nil
end

function ns.Settings.PresetCommand(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then
        local active = ns.Settings.ActivePreset()
        ns.Print("Current preset: " .. (active and active.name or "<no preset>") .. ".")
        local names = {}
        for _, preset in ipairs(ns.Settings.PresetList()) do
            names[#names + 1] = '"' .. preset.name .. '"'
        end
        ns.Print("Available presets: " .. (#names > 0 and table.concat(names, ", ") or "none") .. ".")
        return
    end
    if name:sub(1, 1) == '"' then
        if #name < 2 or name:sub(-1) ~= '"' then
            ns.Print('Use /quiet preset "name".')
            return
        end
        name = name:sub(2, -2):match("^%s*(.-)%s*$")
    end
    local selected
    for id, preset in pairs(ns.Settings.Presets()) do
        if preset.name:lower() == name:lower() then
            if selected then
                ns.Print('More than one preset is named "' .. name .. '". Rename it in /quiet setup.')
                return
            end
            selected = id
        end
    end
    if not selected then
        ns.Print('Preset "' .. name .. '" was not found. Use /quiet preset to list presets.')
        return
    end
    if not ns.Settings.PresetCompatible(ns.Settings.Presets()[selected]) then
        ns.Print('Preset "' .. ns.Settings.Presets()[selected].name .. '" is not available for the current interface mode.')
        return
    end
    if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
    ns.Settings.ActivatePreset(selected)
    if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
    if ns.ApplyAll then ns.ApplyAll() end
    if ns.RefreshSetup then ns.RefreshSetup() end
    ns.Print('Preset "' .. ns.Settings.Presets()[selected].name .. '" selected.')
end
