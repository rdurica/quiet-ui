-- Party autohide row and the Player threshold selector: defaults, drafts, presets, validation, reset.
local h = ...

local function click(b) b._scripts.OnClick(b) end
-- The mock's SetText does not fire OnTextChanged, as typing would.
local function typeInto(edit, text)
    edit:SetText(text)
    if edit._scripts.OnTextChanged then edit._scripts.OnTextChanged(edit) end
end

local function fixture(t, activate)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = { chatFade = 20 }
    ns.ApplyAll = function() end
    ns.Layout.CurrentRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.Layout.Choices = function() return {} end
    ns.Layout.Preview = function() end
    ns.Layout.CommitPreview = function() end
    ns.Layout.CancelPreview = function() end
    local id = ns.Settings.SavePreset(nil, "Healer", ns.Layout.CurrentRef(), { chat = false, chatFade = 0, groupAuras = false, player = "resource" })
    if activate then ns.Settings.ActivatePreset(id) end
    ns.Setup.Show()
    return t.mock:findByName("QuietUISetup"), id
end

local function partyRowOf(ui)
    for _, row in ipairs(ui.rows) do if row.key == "party" then return row end end
end

h.test("Party frames: defaults, disabled hover, draft, save, presets, snapshot and reset", function(t)
    local ns, A = t.ns, t.assert
    local ui = fixture(t)
    local partyRow = partyRowOf(ui)
    A.ok(partyRow and partyRow.always.box._checked and not partyRow.hover:IsEnabled(),
        "Party frames must default to Always visible with Only on hover disabled")
    click(partyRow.hover)
    A.ok(not partyRow.hover.box._checked, "The disabled party hover choice must never change its value")
    click(partyRow.always)
    A.ok(not QuietUICharDB.autoHideParty, "Unchecking must remain a draft")
    ui:Hide(); ns.Setup.Show()
    A.ok(partyRow.always.box._checked, "Closing must cancel party autohide edits")
    click(partyRow.always); click(ui.save)
    A.ok(QuietUICharDB.autoHideParty and ns.Settings.AutoHideParty(), "Save must enable party autohide")
    local partyPreset = ns.Settings.SavePreset(nil, "Party fade", ns.Layout.CurrentRef(), QuietUICharDB)
    ns.Settings.ActivatePreset(partyPreset)
    A.ok(ns.Settings.AutoHideParty(), "Preset must retain party autohide")
    ns.Setup.Show(); click(partyRow.always); click(ui.save)
    A.ok(not ns.Settings.AutoHideParty() and ns.Settings.Presets()[partyPreset].settings.autoHideParty == nil,
        "Saving Always visible must update the active preset")
    ns.Setup.Show(); click(partyRow.always); click(ui.save)
    ns.Settings.DeletePreset(partyPreset)
    A.ok(ns.Settings.AutoHideParty(), "Deleting a preset must retain the personal autohide snapshot")
    ns.Settings.ActivatePreset(nil, {}); ns.Setup.Show()
    click(partyRow.always); click(ui.save)
    click(ui.reset)
    A.ok(not ns.Settings.AutoHideParty() and partyRow.always.box._checked, "Reset must restore Always visible")
end)

h.test("Player threshold: selector, drafts, validation, presets and snapshots", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    local ui, id = fixture(t, true)
    A.ok(ui.playerThresholdPercent.edit:GetText() == "70" and ui.playerThresholdKind.value._text == "Health")
    A.ok(not ui.playerThresholdPercent:IsShown() and not ui.playerThresholdKind:IsShown())
    click(ui.playerRow)
    A.ok(ui.playerThresholdPercent:IsShown() and ui.playerThresholdKind:IsShown())
    typeInto(ui.playerThresholdPercent.edit, "45")
    click(ui.playerThresholdKind.plus)
    A.ok(ui.playerThresholdKind.value._text == "Resource" and ui.playerThresholdPercent.edit:GetText() == "45")
    click(ui.groupAuras)
    A.eq(ui.playerThresholdPercent.edit:GetText(), "45", "Painting another control lost threshold edits")
    click(ui.save)
    A.ok(QuietUICharDB.playerThresholdPercent == 45 and QuietUICharDB.playerThresholdKind == "resource")
    A.ok(ns.Settings.Presets()[id].settings.playerThresholdPercent == 45
        and ns.Settings.Presets()[id].settings.playerThresholdKind == "resource")
    for _, invalid in ipairs({ "0", "101", "-1", "45.5", "no", "1e1" }) do
        typeInto(ui.playerThresholdPercent.edit, invalid)
        local out = A.capture(mock, click, ui.save)
        A.eq(QuietUICharDB.playerThresholdPercent, 45, "invalid " .. invalid .. " was saved")
        A.ok(out[#out] and out[#out]:find("whole percentage", 1, true), "no warning for " .. invalid)
    end
    ui:Hide(); ns.Setup.Show()
    A.ok(ui.playerThresholdPercent.edit:GetText() == "45" and ui.playerThresholdKind.value._text == "Resource")
    typeInto(ui.playerThresholdPercent.edit, "100")
    click(ui.playerRow)
    A.ok(not ui.playerThresholdPercent:IsShown() and not ui.playerThresholdKind:IsShown())
    click(ui.playerRow)
    A.eq(ui.playerThresholdPercent.edit:GetText(), "100")
    click(ui.save)
    A.eq(QuietUICharDB.playerThresholdPercent, 100)
    typeInto(ui.playerThresholdPercent.edit, "1"); click(ui.save)
    A.eq(QuietUICharDB.playerThresholdPercent, 1)
    typeInto(ui.playerThresholdPercent.edit, " "); click(ui.save)
    local kind, percent = ns.Settings.PlayerThreshold()
    A.ok(kind == "resource" and percent == nil and ns.Settings.Presets()[id].settings.playerThresholdPercent == false)
    click(ui.reset)
    kind, percent = ns.Settings.PlayerThreshold()
    A.ok(kind == "health" and percent == 70)
    A.ok(ui.playerThresholdPercent.edit:GetText() == "70" and ui.playerThresholdKind.value._text == "Health")
    A.eq(ns.Settings.Presets()[id].settings.playerThresholdPercent, false, "Reset changed the shared threshold")
    click(ui.newPreset); ui.presetDialog.edit:SetText("Threshold"); click(ui.presetDialog.yes)
    typeInto(ui.playerThresholdPercent.edit, "55"); click(ui.save)
    local threshold = QuietUICharDB.presetId
    ns.Settings.ActivatePreset(id); ns.Setup.Show()
    A.ok(ui.playerThresholdPercent.edit:GetText() == "" and ui.playerThresholdKind.value._text == "Resource")
    ns.Settings.ActivatePreset(threshold); ns.Setup.Show()
    A.ok(ui.playerThresholdPercent.edit:GetText() == "55" and ui.playerThresholdKind.value._text == "Health")
    ns.Settings.DeletePreset(threshold)
    A.ok(QuietUICharDB.playerThresholdPercent == 55 and QuietUICharDB.playerThresholdKind == nil)
end)
