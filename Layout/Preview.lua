local _, ns = ...

-- Layout preview for the setup window: a draft owns the layout until Save or cancel.

local Layout = ns.Layout
local S = Layout.state

local function SelectReference(ref)
    if InCombatLockdown() or not Layout.Ready() then return false end
    local info = Layout.Load()
    if not info then return false end
    local absolute = Layout.Resolve(info, ref)
    if not absolute then error("The selected Edit Mode layout is no longer available.") end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = Layout.Load()
    return after and after.activeLayout == absolute or false
end

function Layout.PreviewActive()
    return S.previewOriginal ~= nil or S.previewPending ~= nil
end

-- A draft owns the layout until Save or cancel, including login-settle retries.
function Layout.UpdatePreview()
    if S.previewApplying then return true end
    if S.previewPending then
        S.previewApplying = true
        local ok, applied = pcall(SelectReference, S.previewPending)
        S.previewApplying = false
        if not ok then
            S.previewPending = nil
            ns.Report("layout preview", applied)
        elseif applied then
            S.previewPending = nil
        end
    end
    return S.previewOriginal ~= nil or S.previewPending ~= nil
end

function Layout.Preview(ref)
    if not S.previewOriginal then
        if not Layout.Ready() then return end
        local info = Layout.Load()
        if not info then return end
        S.previewOriginal = Layout.RefOf(info, info.activeLayout)
    end
    S.previewPending = ns.Copy(ref)
    Layout.UpdatePreview()
end

function Layout.CancelPreview()
    if not S.previewOriginal then return end
    S.previewPending = S.previewOriginal
    S.previewOriginal = nil
    Layout.UpdatePreview()
end

function Layout.CommitPreview(managed)
    if managed and S.previewOriginal and ns.DB().enabled then
        local char = ns.Settings.CharDB()
        if char.previousLayout == nil then
            local info = Layout.Load()
            local absolute = info and Layout.Resolve(info, S.previewOriginal)
            if absolute then
                char.previousLayout = absolute
                char.previousLayoutRef = ns.Copy(S.previewOriginal)
                char.presetLayoutManaged = true
            end
        end
    end
    S.previewOriginal, S.previewPending = nil, nil
end

function Layout.Choices()
    if not Layout.Ready() then return {} end
    local info = Layout.Load()
    if not info then return {} end
    local result = {}
    local style = Layout.CurrentStyle()
    local keyboard = Layout.KeyboardStyle()
    for index, layout in ipairs(Layout.Presets()) do
        if (layout.interfaceStyle or keyboard) == style then
            result[#result + 1] = { name = Layout.Label({ builtin = index }), ref = { builtin = index } }
        end
    end
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    for _, layout in ipairs(info.layouts) do
        if layout.layoutType == account and (layout.interfaceStyle or keyboard) == style then
            result[#result + 1] = { name = layout.layoutName,
                ref = Layout.Reference(layout) }
        end
    end
    return result
end

function Layout.CurrentRef()
    if not Layout.Ready() then return nil end
    local info = Layout.Load()
    if not info then return nil end
    local ref = Layout.RefOf(info, info.activeLayout)
    for _, choice in ipairs(Layout.Choices()) do
        if Layout.Resolve(info, choice.ref) == info.activeLayout then return ref end
    end
    return { layoutName = Layout.NAME,
        layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1 }
end
