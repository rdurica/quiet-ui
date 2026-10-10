local _, ns = ...

local snapshotChar, snapshotPreset

local KEYS = { "visible", "hoverOnly", "groupVisibility", "forceLayout", "player", "playerThresholdKind", "playerThresholdPercent", "requireLivingTarget", "groupAuras", "alwaysShowDebuffs", "questNotice", "questNoticeSize", "questMobs", "parchment",
    "chat", "chatFade", "groups", "hostile", "friendly", "range", "autoHideParty", "highlights" }

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = ns.Copy(item) end
    return result
end

function ns.CopySettings(source, target)
    target = target or {}
    if ns.MigrateOnce then ns.MigrateOnce(source) end
    for _, key in ipairs(KEYS) do target[key] = ns.Copy(source[key]) end
    return target
end

function ns.Presets()
    local db = ns.DB()
    if type(db.presets) ~= "table" then db.presets = {} end
    return db.presets
end

local function PresetFor(char)
    local preset = char.presetId and ns.Presets()[char.presetId]
    if type(preset) ~= "table" then
        char.presetId = nil
        return nil
    end
    return preset
end

function ns.ActivePreset()
    return PresetFor(ns.CharDB())
end

function ns.Settings()
    local char = ns.CharDB()
    local preset = PresetFor(char)
    if preset then
        if ns.MigrateOnce then ns.MigrateOnce(preset.settings) end
        if snapshotChar ~= char or snapshotPreset ~= preset then
            ns.CopySettings(preset.settings, char)
            snapshotChar, snapshotPreset = char, preset
        end
        return preset.settings
    end
    return char
end

function ns.PresetInterfaceStyle(preset)
    if type(preset.interfaceStyle) == "number" then return preset.interfaceStyle end
    local style = ns.LayoutInterfaceStyle and ns.LayoutInterfaceStyle(preset.layout)
        or (preset.layout and preset.layout.interfaceStyle)
    if style == nil and not ns.LayoutInterfaceStyle then style = 0 end
    if style ~= nil then preset.interfaceStyle = style end
    return style
end

function ns.PresetCompatible(preset)
    local style = ns.PresetInterfaceStyle(preset)
    return style ~= nil and style == (ns.CurrentInterfaceStyle and ns.CurrentInterfaceStyle() or 0)
end

function ns.PresetList()
    local list = {}
    for id, preset in pairs(ns.Presets()) do
        if ns.PresetCompatible(preset) then
            list[#list + 1] = { id = id, name = preset.name }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function ns.PresetName(name, id)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Enter a preset name." end
    for other, preset in pairs(ns.Presets()) do
        if other ~= id and preset.name:lower() == name:lower() then
            return nil, "A preset with that name already exists."
        end
    end
    return name
end

function ns.SavePreset(id, name, layout, settings)
    local valid, err = ns.PresetName(name, id)
    if not valid then return nil, err end
    local db = ns.DB()
    if id and not ns.Presets()[id] then return nil, "That preset no longer exists." end
    if not id then
        db.nextPresetId = (db.nextPresetId or 0) + 1
        id = tostring(db.nextPresetId)
    end
    local saved = ns.CopySettings(settings)
    saved.forceLayout = nil
    local style = ns.LayoutInterfaceStyle and ns.LayoutInterfaceStyle(layout)
        or (layout and layout.interfaceStyle)
        or (ns.CurrentInterfaceStyle and ns.CurrentInterfaceStyle() or 0)
    ns.Presets()[id] = { name = valid, layout = ns.Copy(layout), settings = saved, interfaceStyle = style }
    return id
end

function ns.ActivatePreset(id, settings)
    local char = ns.CharDB()
    if id and not ns.Presets()[id] then return false end
    if id and not ns.PresetCompatible(ns.Presets()[id]) then
        return false, "That preset is not available for the current interface mode."
    end
    if settings then ns.CopySettings(settings, char) else ns.Settings() end
    char.presetId = id
    snapshotChar, snapshotPreset = nil, nil
    if id then ns.CopySettings(ns.Presets()[id].settings, char) end
    return true
end

function ns.DeletePreset(id)
    if ns.CharDB().presetId == id then ns.Settings(); ns.CharDB().presetId = nil end
    ns.Presets()[id] = nil
end

function ns.PresetCommand(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then
        local active = ns.ActivePreset()
        ns.Print("Current preset: " .. (active and active.name or "<no preset>") .. ".")
        local names = {}
        for _, preset in ipairs(ns.PresetList()) do
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
    for id, preset in pairs(ns.Presets()) do
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
    if not ns.PresetCompatible(ns.Presets()[selected]) then
        ns.Print('Preset "' .. ns.Presets()[selected].name .. '" is not available for the current interface mode.')
        return
    end
    if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
    ns.ActivatePreset(selected)
    if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
    if ns.ApplyAll then ns.ApplyAll() end
    if ns.RefreshSetup then ns.RefreshSetup() end
    ns.Print('Preset "' .. ns.Presets()[selected].name .. '" selected.')
end
