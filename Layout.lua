local _, ns = ...

-- Offers the QuietUI Edit Mode layout from LayoutString.lua. Each new version
-- of that string is offered once; an update still waits for consent.
-- With Force QuietUI layout on, turning the addon on selects the layout
-- (creating it when missing) and remembers the previous one. Turning it off
-- selects that layout again. With force off, the active layout stays as it is.
-- Only C_EditMode is used: calling EditModeManagerFrame methods would taint it.

local LAYOUT_NAME = "QuietUI"

-- Blizzard ships Modern and Classic presets ahead of saved layouts.
local FALLBACK_PRESETS = { { layoutName = "Modern" }, { layoutName = "Classic" } }

local done = false
local missingWarned = {}

local function EditModeReady()
    return C_EditMode
        and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.ConvertStringToLayoutInfo) == "function"
        and type(C_EditMode.SaveLayouts) == "function"
        and type(C_EditMode.SetActiveLayout) == "function"
end

local presetManager, presetLayouts

local function PresetLayouts()
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

local function PresetCount()
    return #PresetLayouts()
end

local function KeyboardStyle()
    return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Mkb or 0
end

local function CurrentStyle()
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
    return KeyboardStyle()
end

ns.CurrentInterfaceStyle = CurrentStyle

local function LayoutReference(layout)
    return { layoutName = layout.layoutName, layoutType = layout.layoutType,
        interfaceStyle = layout.interfaceStyle or KeyboardStyle() }
end

function ns.LayoutLabel(ref)
    if not ref then return "Choose layout" end
    if ref.layoutName then return ref.layoutName end
    if ref.builtin then
        local names = PresetLayouts()
        local name = names[ref.builtin] and names[ref.builtin].layoutName
            or ({ "Modern", "Classic" })[ref.builtin]
            or ("Built-in layout " .. ref.builtin)
        if name:lower() == "gamepad" then return name .. " (Gamepad mode only)" end
        return name
    end
    return "Choose layout"
end

local function FindLayout(layouts)
    for i, layout in ipairs(layouts) do
        if layout.layoutName == LAYOUT_NAME then return i end
    end
end

local function ReadShipped()
    local layout = C_EditMode.ConvertStringToLayoutInfo(ns.LAYOUT_STRING or "")
    if type(layout) ~= "table" then
        error("LayoutString.lua could not be read")
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

local function ShippedHash()
    return Hash(ns.LAYOUT_STRING or "")
end

local function MarkAnswered()
    ns.DB().layoutHash = ShippedHash()
end

local function LoadLayouts()
    local ok, info = pcall(C_EditMode.GetLayouts)
    if not ok then return nil end
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end

local function LayoutRef(info, absolute)
    if type(absolute) ~= "number" then return nil end
    if absolute <= PresetCount() then return { builtin = absolute } end
    local layout = info.layouts[absolute - PresetCount()]
    if not layout then return nil end
    return LayoutReference(layout)
end

local function ResolveLayout(info, ref)
    if type(ref) ~= "table" then return nil end
    if ref.builtin and ref.builtin >= 1 and ref.builtin <= PresetCount() then return ref.builtin end
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == ref.layoutName and layout.layoutType == ref.layoutType
            and (ref.interfaceStyle == nil or (layout.interfaceStyle or KeyboardStyle()) == ref.interfaceStyle) then
            return PresetCount() + index
        end
    end
end

function ns.LayoutInterfaceStyle(ref)
    if type(ref) ~= "table" then return nil end
    if type(ref.interfaceStyle) == "number" then return ref.interfaceStyle end
    if ref.builtin then
        local layout = PresetLayouts()[ref.builtin]
        return layout and (layout.interfaceStyle or KeyboardStyle()) or nil
    end
    if not EditModeReady() then return nil end
    local info = LoadLayouts()
    if not info then return nil end
    local absolute = ResolveLayout(info, ref)
    local layout = absolute and info.layouts[absolute - PresetCount()]
    return layout and (layout.interfaceStyle or KeyboardStyle()) or KeyboardStyle()
end

function ns.ValidatePresetInterface()
    local preset = ns.ActivePreset and ns.ActivePreset()
    if not preset then return true end
    if not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local style = ns.PresetInterfaceStyle(preset)
    if style == nil then return false end
    if style ~= CurrentStyle() then
        ns.ActivatePreset(nil)
        if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
        if ns.RefreshSetup then ns.RefreshSetup() end
        ns.Print('Preset "' .. preset.name .. '" uses a layout for another interface mode. '
            .. 'Using personal settings instead.')
    end
    return true
end

local previewOriginal, previewPending, previewApplying

function ns.LayoutStatus()
    if not EditModeReady() then return "Edit Mode is not available." end
    local info = LoadLayouts()
    if not info then return "Edit Mode layouts are not loaded." end
    local preset = ns.ActivePreset and ns.ActivePreset()
    local linked = preset and ResolveLayout(info, preset.layout)
    return string.format("Active layout: %s; preset layout: %s; preview: %s.",
        tostring(info.activeLayout), tostring(linked or "none"),
        previewPending and "pending" or previewOriginal and "open" or "none")
end

local function SelectReference(ref)
    if InCombatLockdown() or not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local absolute = ResolveLayout(info, ref)
    if not absolute then error("The selected Edit Mode layout is no longer available.") end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = LoadLayouts()
    return after and after.activeLayout == absolute or false
end

-- A draft owns the layout until Save or cancel, including login-settle retries.
function ns.UpdateLayoutPreview()
    if previewApplying then return true end
    if previewPending then
        previewApplying = true
        local ok, applied = pcall(SelectReference, previewPending)
        previewApplying = false
        if not ok then
            previewPending = nil
            ns.Report("layout preview", applied)
        elseif applied then
            previewPending = nil
        end
    end
    return previewOriginal ~= nil or previewPending ~= nil
end

function ns.PreviewLayout(ref)
    if not previewOriginal then
        if not EditModeReady() then return end
        local info = LoadLayouts()
        if not info then return end
        previewOriginal = LayoutRef(info, info.activeLayout)
    end
    previewPending = ns.Copy(ref)
    ns.UpdateLayoutPreview()
end

function ns.CancelLayoutPreview()
    if not previewOriginal then return end
    previewPending = previewOriginal
    previewOriginal = nil
    ns.UpdateLayoutPreview()
end

function ns.CommitLayoutPreview(managed)
    if managed and previewOriginal and ns.DB().enabled then
        local char = ns.CharDB()
        if char.previousLayout == nil then
            local info = LoadLayouts()
            local absolute = info and ResolveLayout(info, previewOriginal)
            if absolute then
                char.previousLayout = absolute
                char.previousLayoutRef = ns.Copy(previewOriginal)
                char.presetLayoutManaged = true
            end
        end
    end
    previewOriginal, previewPending = nil, nil
end

function ns.LayoutChoices()
    if not EditModeReady() then return {} end
    local info = LoadLayouts()
    if not info then return {} end
    local result = {}
    local style = CurrentStyle()
    for index, layout in ipairs(PresetLayouts()) do
        if (layout.interfaceStyle or KeyboardStyle()) == style then
            result[#result + 1] = { name = ns.LayoutLabel({ builtin = index }), ref = { builtin = index } }
        end
    end
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    for _, layout in ipairs(info.layouts) do
        if layout.layoutType == account and (layout.interfaceStyle or KeyboardStyle()) == style then
            result[#result + 1] = { name = layout.layoutName,
                ref = LayoutReference(layout) }
        end
    end
    return result
end

function ns.CurrentLayoutRef()
    if not EditModeReady() then return nil end
    local info = LoadLayouts()
    if not info then return nil end
    local ref = LayoutRef(info, info.activeLayout)
    for _, choice in ipairs(ns.LayoutChoices()) do
        if ResolveLayout(info, choice.ref) == info.activeLayout then return ref end
    end
    return { layoutName = LAYOUT_NAME,
        layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1 }
end

-- Remember the original identity; switching between presets must not replace it.
local function Remember(active, absolute)
    if type(active) ~= "number" or active < 1 or active == absolute then return end
    local char = ns.CharDB()
    if char.previousLayout == nil then
        char.previousLayout = active
        local info = LoadLayouts()
        char.previousLayoutRef = info and LayoutRef(info, active)
    end
end

local function Write()
    local info = LoadLayouts()
    if not info then error("Edit Mode layouts are not loaded") end
    local shipped = ReadShipped()
    local index = FindLayout(info.layouts)
    local created = not index
    if index then
        shipped.layoutType = info.layouts[index].layoutType or shipped.layoutType
        info.layouts[index] = shipped
    else
        info.layouts[#info.layouts + 1] = shipped
        index = #info.layouts
    end
    -- Count presets before saving. SaveLayouts can rewrite the table it is given.
    local absolute = PresetCount() + index
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
function ns.SelectQuietLayout()
    if InCombatLockdown() or not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local index = FindLayout(info.layouts)
    if not index then
        Remember(info.activeLayout, PresetCount() + #info.layouts + 1)
        MarkAnswered()
        Write()
        info = LoadLayouts()
        index = info and FindLayout(info.layouts)
        if not index then return false end
    end
    local absolute = PresetCount() + index
    if info.activeLayout == absolute then return true end
    Remember(info.activeLayout, absolute)
    C_EditMode.SetActiveLayout(absolute)
    -- A new character applies its default preset after this call. Not done until it stuck.
    local after = LoadLayouts()
    if after and after.activeLayout == absolute then return true end
    return false
end

function ns.SelectPresetLayout()
    if InCombatLockdown() or not EditModeReady() then return false end
    local preset = ns.ActivePreset()
    if not preset then return ns.SelectQuietLayout() end
    local info = LoadLayouts()
    if not info then return false end
    local absolute = ResolveLayout(info, preset.layout)
    if not absolute then
        if not ns.SelectQuietLayout() then return false end
        if ns.CharDB().previousLayout then ns.CharDB().presetLayoutManaged = true end
        local id = ns.CharDB().presetId
        if not missingWarned[id] then
            ns.Print('Preset "' .. preset.name .. '" refers to missing Edit Mode layout "'
                .. (preset.layout and preset.layout.layoutName or "Unknown") .. '". Using "QuietUI" instead.')
            missingWarned[id] = true
        end
        return true
    end
    Remember(info.activeLayout, absolute)
    if ns.CharDB().previousLayout then ns.CharDB().presetLayoutManaged = true end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = LoadLayouts()
    return after and after.activeLayout == absolute or false
end

function ns.RestorePreviousLayout()
    local char = ns.CharDB()
    local previous = char.previousLayout
    if previous == nil then char.presetLayoutManaged = nil; return true end
    if InCombatLockdown() or not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    if char.previousLayoutRef then previous = ResolveLayout(info, char.previousLayoutRef) end
    local presets = PresetCount()
    local valid = type(previous) == "number" and previous >= 1
        and (previous <= presets or type(info.layouts[previous - presets]) == "table")
    if valid and info.activeLayout ~= previous then
        C_EditMode.SetActiveLayout(previous)
        local after = LoadLayouts()
        if not after or after.activeLayout ~= previous then return false end
    end
    char.previousLayout = nil
    char.previousLayoutRef = nil
    char.presetLayoutManaged = nil
    return true
end

------------------------------------------------------------------------------
-- Prompt. Own frame instead of StaticPopup, which spreads taint.
-- Same character frame as setup, with a gear instead of the player portrait.
------------------------------------------------------------------------------
local prompt

local CHROME = {
    portrait = { width = 400, side = 26, textY = -96, buttonY = 18, height = 188 },
    gold = { width = 420, side = 28, titleY = -26, textY = -56, buttonY = 28, height = 166 },
    flat = { width = 380, side = 16, titleY = -14, textY = -40, buttonY = 16, height = 132 },
}

local function Flat(frame, alpha)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    frame:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
end

local function Backdropped(kind, name, parent)
    local ok, frame = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and frame then return frame end
    return CreateFrame(kind, name, parent)
end

local function PortraitChrome(widget)
    return widget.SetTitle or widget.TitleText or widget.TitleContainer
        or widget.PortraitContainer or widget.portrait
end

local function ApplyTitle(widget, text)
    if widget.SetTitle then
        local ok = pcall(widget.SetTitle, widget, text)
        if ok then return end
    end
    local title = widget.TitleText
    if not title and widget.TitleContainer then
        title = widget.TitleContainer.TitleText
    end
    if title and title.SetText then
        title:SetText(text)
    end
end

local function PortraitRegion(widget)
    if widget.PortraitContainer and widget.PortraitContainer.portrait then
        return widget.PortraitContainer.portrait
    end
    return widget.portrait
end

local function TextureShown(texture)
    return texture and texture.GetTexture and texture:GetTexture()
end

-- Gear, same order as the minimap button. The character frame needs an icon in the circle.
local function ApplyGearPortrait(widget)
    if widget.SetPortraitAtlas then
        local ok = pcall(widget.SetPortraitAtlas, widget, "mechagon-projects")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    if widget.SetPortraitToAsset then
        local ok = pcall(widget.SetPortraitToAsset, widget, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    local texture = PortraitRegion(widget)
    if not texture then return end
    if texture.SetAtlas then
        local ok, result = pcall(texture.SetAtlas, texture, "mechagon-projects")
        if ok and result then return end
    end
    if type(SetPortraitToTexture) == "function" then
        local ok = pcall(SetPortraitToTexture, texture, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(texture) then return end
    end
    if not texture:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        texture:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
end

-- The template close hides the frame without an answer. Only the two buttons decide.
local function HideClose(widget)
    local close = widget.CloseButton or widget.closeButton
    if close and close.Hide then close:Hide() end
end

local function SetButtonLabel(button, text)
    if button.label then
        button.label:SetText(text)
        return
    end
    if button.SetText then button:SetText(text) end
end

local function CreatePrompt()
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and frame and PortraitChrome(frame) then
        kind = "portrait"
        frame._quietGear = true
        ApplyTitle(frame, "QuietUI")
        ApplyGearPortrait(frame)
        HideClose(frame)
    else
        if not (ok and frame) then
            frame = Backdropped("Frame", nil, UIParent)
        end
        if ns.DialogGoldWindow(frame) then kind = "gold"
        else Flat(frame, 1) end
    end
    ns.DialogBackground(frame)
    local metrics = CHROME[kind]
    frame:ClearAllPoints()
    frame:SetSize(metrics.width, metrics.height)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if kind ~= "portrait" then
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetText("|cff8fd4c8QuietUI|r")
        frame.title:SetPoint("TOP", 0, metrics.titleY)
    end
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, metrics.textY)
    frame.text:SetWidth(metrics.width - metrics.side * 2)
    frame.text:SetJustifyH("CENTER")
    frame.yes = ns.DialogButton(frame, "Add", function()
        frame:Hide()
        if InCombatLockdown() then
            ns.Print("layout can not change in combat, /reload after combat to try again")
            return
        end
        local okWrite, err = pcall(Write)
        if okWrite then
            MarkAnswered()
        else
            ns.Report("layout", err)
        end
    end)
    frame.no = ns.DialogButton(frame, "Not now", function()
        frame:Hide()
        MarkAnswered()
    end)
    local level = frame:GetFrameLevel() + 20
    frame.yes:SetFrameLevel(level)
    frame.no:SetFrameLevel(level)
    frame.no:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    frame.yes:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    frame:Hide()
    return frame
end

local function Ask(text, yesLabel)
    prompt = prompt or CreatePrompt()
    if prompt._quietGear then ApplyGearPortrait(prompt) end
    prompt.text:SetText(text)
    SetButtonLabel(prompt.yes, yesLabel)
    prompt:Show()
    ns.RaiseDialog(prompt)
end

-- Returns true once the check could run, so it is not repeated this session.
local function Check()
    if ns.DB().layoutHash == ShippedHash() then return true end
    local info = LoadLayouts()
    if not info then return false end
    ReadShipped()
    if FindLayout(info.layouts) then
        Ask("The " .. LAYOUT_NAME .. " layout has changed. Update yours?", "Update")
    else
        Ask("Add the " .. LAYOUT_NAME .. " layout and switch to it?", "Add")
    end
    return true
end

-- Setup's Import layout writes the shipped layout now, even after "Not now".
function ns.ForceLayout()
    if not EditModeReady() then
        ns.Print("Edit Mode is not available")
        return
    end
    if InCombatLockdown() then
        ns.Print("layout can not change in combat")
        return
    end
    if prompt then prompt:Hide() end
    local ok, err = pcall(Write)
    if ok then
        MarkAnswered()
        done = true
    else
        ns.Report("layout", err)
    end
end

-- Layouts are not loaded right at login and are locked in combat, so this
-- retries on every apply until it has run once per session.
function ns.EnsureLayout()
    if ns.ActivePreset and ns.ActivePreset() then return end
    if done or InCombatLockdown() or not EditModeReady() then return end
    local ok, finished = pcall(Check)
    if not ok then
        done = true
        ns.Report("layout", finished)
    elseif finished then
        done = true
    end
end
