-- The set of function names on ns after loading the addon (no boot).
local h = ...

-- Baseline captured from the code before ticket #8, plus the shared helpers.
local BASELINE = {
    "ApplyAll",
    "CancelLayoutPreview",
    "CommitLayoutPreview",
    "Copy",
    "CurrentInterfaceStyle",
    "CurrentLayoutRef",
    "DB",
    "DialogBackground",
    "DialogGoldWindow",
    "EaseAlpha",
    "EnsureAlphaHook",
    "EnsureLayout",
    "FocusChanged",
    "ForceLayout",
    "ForceTextureHidden",
    "FrameHot",
    "FrameName",
    "Glancing",
    "HideBackground",
    "HideTextures",
    "Hit",
    "HoldAlpha",
    "HoldSecretAlpha",
    "IsSecret",
    "LayoutChoices",
    "LayoutInterfaceStyle",
    "LayoutLabel",
    "LayoutPreviewActive",
    "LayoutSettingsChanged",
    "LayoutStatus",
    "MouseOver",
    "NextFadeTick",
    "NoteChat",
    "PointerMoved",
    "PreviewLayout",
    "Print",
    "PushAlpha",
    "RaiseDialog",
    "RefreshMouse",
    "ReleaseAlpha",
    "ReleaseChatHold",
    "Remember",
    "Report",
    "RequestRescan",
    "RestoreAll",
    "RestoreAlpha",
    "RestorePreviousLayout",
    "SelectPresetLayout",
    "SelectQuietLayout",
    "ToggleGlance",
    "UpdateFaded",
    "UpdateLayoutPreview",
    "Usable",
    "ValidatePresetInterface",
    "Wipe",
    "Run", "Flat", "Backdropped", "Feature", "Features",
    "GoldEdge", "PortraitChrome", "ApplyTitle",
}

h.test("ns exposes exactly the baseline functions plus Run, Flat, Backdropped, Feature, Features", function(t)
    local want, have = {}, {}
    for _, name in ipairs(BASELINE) do want[name] = true end
    for name, value in pairs(t.ns) do
        if type(value) == "function" then have[name] = true end
    end
    local missing, extra = {}, {}
    for name in pairs(want) do if not have[name] then missing[#missing + 1] = name end end
    for name in pairs(have) do if not want[name] then extra[#extra + 1] = name end end
    table.sort(missing)
    table.sort(extra)
    t.assert.eq(#missing + #extra, 0,
        "missing: [" .. table.concat(missing, ", ") .. "] unexpected: [" .. table.concat(extra, ", ") .. "]")
end)
