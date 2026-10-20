-- The set of function names on ns after loading the addon (no boot).
local h = ...

-- Baseline captured from the code before ticket #8, plus the shared helpers.
local BASELINE = {
    "ApplyAll",
    "Copy",
    "DB",
    "DialogBackground",
    "EaseAlpha",
    "EnsureAlphaHook",
    "FocusChanged",
    "ForceTextureHidden",
    "FrameHot",
    "FrameName",
    "HideBackground",
    "HideTextures",
    "Hit",
    "HoldAlpha",
    "HoldSecretAlpha",
    "IsSecret",
    "MouseOver",
    "NextFadeTick",
    "NoteChat",
    "PointerMoved",
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
    "UpdateFaded",
    "Usable",
    "Wipe",
    "Run", "Flat", "Backdropped", "Feature", "Features",
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
