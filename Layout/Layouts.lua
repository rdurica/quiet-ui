local _, ns = ...

-- Edit Mode layout discovery, select, restore, write, and the add/update flow.
-- Offers the QuietUI Edit Mode layout from String.lua. Each new version
-- of that string is offered once; an update still waits for consent.
-- With Force QuietUI layout on, turning the addon on selects the layout
-- (creating it when missing) and remembers the previous one. Turning it off
-- selects that layout again. With force off, the active layout stays as it is.
-- Only C_EditMode is used: calling EditModeManagerFrame methods would taint it.

local Layout = ns.Layout

local LAYOUT_NAME = "QuietUI"
Layout.NAME = LAYOUT_NAME

-- Private state of the Layout files. Preview, prompt and settle fields live here.
Layout.state = {
    done = false,             -- the add/update check ran this session
    missingWarned = {},
    previewOriginal = nil, previewPending = nil, previewApplying = false,
    prompt = nil,
    pending = nil,            -- "select" | "restore" | nil
    chosen = false, finishing = false, armed = false,
    settleUntil = 0, settleToken = 0,
    presetCheckPending = false,
}
local S = Layout.state

-- Blizzard ships Modern and Classic presets ahead of saved layouts.
local FALLBACK_PRESETS = { { layoutName = "Modern" }, { layoutName = "Classic" } }

function Layout.Ready()
    return C_EditMode
        and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.ConvertStringToLayoutInfo) == "function"
        and type(C_EditMode.SaveLayouts) == "function"
        and type(C_EditMode.SetActiveLayout) == "function"
end

local presetManager, presetLayouts

function Layout.Presets()
    local manager = EditModePresetLayoutManager
    if presetLayouts and presetManager == manager then return presetLayouts end
    if manager then
        local presets = manager.presetLayoutInfo
        if type(presets) ~= "table" and type(manager.GetCopyOfPresetLayouts) == "function" then
            local ok, result = pcall(manager.GetCopyOfPresetLayouts, manager)
            if ok then presets = result end
        end
        if type(presets) == "table" and #presets > 0 then
            local list = {}
            for index, preset in ipairs(presets) do
                list[index] = type(preset) == "table" and {
                    layoutName = preset.layoutName, interfaceStyle = preset.interfaceStyle,
                } or {}
            end
            presetManager, presetLayouts = manager, list
            return list
        end
    end
    return FALLBACK_PRESETS
end

function Layout.PresetCount()
    return #Layout.Presets()
end

function Layout.KeyboardStyle()
    return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Mkb or 0
end

function Layout.CurrentStyle()
    if InputUtil and type(InputUtil.GetCurrentInterfaceStyle) == "function" then
        local ok, style = pcall(InputUtil.GetCurrentInterfaceStyle)
        if ok and type(style) == "number" then return style end
    end
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
        if ok and enabled then
            return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad or 1
        end
    end
    return Layout.KeyboardStyle()
end

function Layout.Reference(layout)
    return { layoutName = layout.layoutName, layoutType = layout.layoutType,
        interfaceStyle = layout.interfaceStyle or Layout.KeyboardStyle() }
end

function Layout.Label(ref)
    if not ref then return "Choose layout" end
    if ref.layoutName then return ref.layoutName end
    if ref.builtin then
        local names = Layout.Presets()
        local name = names[ref.builtin] and names[ref.builtin].layoutName
            or ({ "Modern", "Classic" })[ref.builtin]
            or ("Built-in layout " .. ref.builtin)
        if name:lower() == "gamepad" then return name .. " (Gamepad mode only)" end
        return name
    end
    return "Choose layout"
end

function Layout.Find(layouts)
    for i, layout in ipairs(layouts) do
        if layout.layoutName == LAYOUT_NAME then return i end
    end
end

function Layout.ReadShipped()
    local layout = C_EditMode.ConvertStringToLayoutInfo(Layout.STRING or "")
    if type(layout) ~= "table" then
        error("Layout/String.lua could not be read")
    end
    layout.layoutName = LAYOUT_NAME
    layout.layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    return layout
end

-- The client rewrites a saved layout, so it never matches the string again.
-- Instead the string's hash marks which version the player already answered.
local function Hash(text)
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + text:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

function Layout.ShippedHash()
    return Hash(Layout.STRING or "")
end

function Layout.MarkAnswered()
    ns.DB().layoutHash = Layout.ShippedHash()
end

function Layout.Load()
    local ok, info = pcall(C_EditMode.GetLayouts)
    if not ok then return nil end
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end

function Layout.RefOf(info, absolute)
    if type(absolute) ~= "number" then return nil end
    if absolute <= Layout.PresetCount() then return { builtin = absolute } end
    local layout = info.layouts[absolute - Layout.PresetCount()]
    if not layout then return nil end
    return Layout.Reference(layout)
end

function Layout.Resolve(info, ref)
    if type(ref) ~= "table" then return nil end
    local count = Layout.PresetCount()
    if ref.builtin and ref.builtin >= 1 and ref.builtin <= count then return ref.builtin end
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == ref.layoutName and layout.layoutType == ref.layoutType
            and (ref.interfaceStyle == nil or (layout.interfaceStyle or Layout.KeyboardStyle()) == ref.interfaceStyle) then
            return count + index
        end
    end
end

function Layout.InterfaceStyle(ref)
    if type(ref) ~= "table" then return nil end
    if type(ref.interfaceStyle) == "number" then return ref.interfaceStyle end
    if ref.builtin then
        local layout = Layout.Presets()[ref.builtin]
        return layout and (layout.interfaceStyle or Layout.KeyboardStyle()) or nil
    end
    if not Layout.Ready() then return nil end
    local info = Layout.Load()
    if not info then return nil end
    local absolute = Layout.Resolve(info, ref)
    local layout = absolute and info.layouts[absolute - Layout.PresetCount()]
    return layout and (layout.interfaceStyle or Layout.KeyboardStyle()) or Layout.KeyboardStyle()
end

function Layout.ValidatePresetInterface()
    local preset = ns.Settings.ActivePreset and ns.Settings.ActivePreset()
    if not preset then return true end
    if not Layout.Ready() then return false end
    local info = Layout.Load()
    if not info then return false end
    local style = ns.Settings.PresetInterfaceStyle(preset)
    if style == nil then return false end
    if style ~= Layout.CurrentStyle() then
        ns.Settings.ActivatePreset(nil)
        if Layout.SettingsChanged then Layout.SettingsChanged() end
        if ns.Setup then ns.Setup.Refresh() end
        ns.Print('Preset "' .. preset.name .. '" uses a layout for another interface mode. '
            .. 'Using personal settings instead.')
    end
    return true
end

function Layout.Status()
    if not Layout.Ready() then return "Edit Mode is not available." end
    local info = Layout.Load()
    if not info then return "Edit Mode layouts are not loaded." end
    local preset = ns.Settings.ActivePreset and ns.Settings.ActivePreset()
    local linked = preset and Layout.Resolve(info, preset.layout)
    return string.format("Active layout: %s; preset layout: %s; preview: %s.",
        tostring(info.activeLayout), tostring(linked or "none"),
        S.previewPending and "pending" or S.previewOriginal and "open" or "none")
end

-- Remember the original identity; switching between presets must not replace it.
local function Remember(active, absolute)
    if type(active) ~= "number" or active < 1 or active == absolute then return end
    local char = ns.Settings.CharDB()
    if char.previousLayout == nil then
        char.previousLayout = active
        local info = Layout.Load()
        char.previousLayoutRef = info and Layout.RefOf(info, active)
    end
end

function Layout.Write()
    local info = Layout.Load()
    if not info then error("Edit Mode layouts are not loaded") end
    local shipped = Layout.ReadShipped()
    local index = Layout.Find(info.layouts)
    local created = not index
    if index then
        shipped.layoutType = info.layouts[index].layoutType or shipped.layoutType
        info.layouts[index] = shipped
    else
        info.layouts[#info.layouts + 1] = shipped
        index = #info.layouts
    end
    -- Count presets before saving. SaveLayouts can rewrite the table it is given.
    local absolute = Layout.PresetCount() + index
    if created then
        info.activeLayout = absolute
    end
    C_EditMode.SaveLayouts(info)
    if created then
        C_EditMode.SetActiveLayout(absolute)
        ns.Print("Edit Mode layout \"" .. LAYOUT_NAME .. "\" saved.")
    else
        ns.Print("Edit Mode layout \"" .. LAYOUT_NAME .. "\" saved. Type /reload to finish.")
    end
end

-- True when the switch has been applied. False asks the caller to try again.
function Layout.SelectQuiet()
    if InCombatLockdown() or not Layout.Ready() then return false end
    local info = Layout.Load()
    if not info then return false end
    local index = Layout.Find(info.layouts)
    if not index then
        Remember(info.activeLayout, Layout.PresetCount() + #info.layouts + 1)
        Layout.MarkAnswered()
        Layout.Write()
        info = Layout.Load()
        index = info and Layout.Find(info.layouts)
        if not index then return false end
    end
    local absolute = Layout.PresetCount() + index
    if info.activeLayout == absolute then return true end
    Remember(info.activeLayout, absolute)
    C_EditMode.SetActiveLayout(absolute)
    -- A new character applies its default preset after this call. Not done until it stuck.
    local after = Layout.Load()
    if after and after.activeLayout == absolute then return true end
    return false
end

function Layout.SelectPreset()
    if InCombatLockdown() or not Layout.Ready() then return false end
    local preset = ns.Settings.ActivePreset()
    if not preset then return Layout.SelectQuiet() end
    local info = Layout.Load()
    if not info then return false end
    local absolute = Layout.Resolve(info, preset.layout)
    if not absolute then
        if not Layout.SelectQuiet() then return false end
        if ns.Settings.CharDB().previousLayout then ns.Settings.CharDB().presetLayoutManaged = true end
        local id = ns.Settings.CharDB().presetId
        if not S.missingWarned[id] then
            ns.Print('Preset "' .. preset.name .. '" refers to missing Edit Mode layout "'
                .. (preset.layout and preset.layout.layoutName or "Unknown") .. '". Using "QuietUI" instead.')
            S.missingWarned[id] = true
        end
        return true
    end
    Remember(info.activeLayout, absolute)
    if ns.Settings.CharDB().previousLayout then ns.Settings.CharDB().presetLayoutManaged = true end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = Layout.Load()
    return after and after.activeLayout == absolute or false
end

function Layout.RestorePrevious()
    local char = ns.Settings.CharDB()
    local previous = char.previousLayout
    if previous == nil then char.presetLayoutManaged = nil; return true end
    if InCombatLockdown() or not Layout.Ready() then return false end
    local info = Layout.Load()
    if not info then return false end
    if char.previousLayoutRef then previous = Layout.Resolve(info, char.previousLayoutRef) end
    local presets = Layout.PresetCount()
    local valid = type(previous) == "number" and previous >= 1
        and (previous <= presets or type(info.layouts[previous - presets]) == "table")
    if valid and info.activeLayout ~= previous then
        C_EditMode.SetActiveLayout(previous)
        local after = Layout.Load()
        if not after or after.activeLayout ~= previous then return false end
    end
    char.previousLayout = nil
    char.previousLayoutRef = nil
    char.presetLayoutManaged = nil
    return true
end

-- Setup's Import layout writes the shipped layout now, even after "Not now".
function Layout.Force()
    if not Layout.Ready() then
        ns.Print("Edit Mode is not available")
        return
    end
    if InCombatLockdown() then
        ns.Print("layout can not change in combat")
        return
    end
    if S.prompt then S.prompt:Hide() end
    local ok, err = pcall(Layout.Write)
    if ok then
        Layout.MarkAnswered()
        S.done = true
    else
        ns.Report("layout", err)
    end
end

-- Layouts are not loaded right at login and are locked in combat, so this
-- retries on every apply until it has run once per session.
function Layout.Ensure()
    if ns.Settings.ActivePreset and ns.Settings.ActivePreset() then return end
    if S.done or InCombatLockdown() or not Layout.Ready() then return end
    local ok, finished = pcall(Layout.Check)
    if not ok then
        S.done = true
        ns.Report("layout", finished)
    elseif finished then
        S.done = true
    end
end
