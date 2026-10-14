-- General tab: preset draft selection, layout preview, save, detach, reset, rename, delete.
local h = ...

local function click(b) b._scripts.OnClick(b) end

-- Layout functions are replaced by recorders; everything else is the real addon.
local function fixture(t)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = { chatFade = 20 }
    local rec = {}
    ns.ApplyAll = function() end
    ns.CurrentLayoutRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.LayoutChoices = function() return { { name = "Other", ref = { layoutName = "Other", layoutType = 1 } } } end
    ns.PreviewLayout = function(ref) rec.preview = ref.layoutName end
    ns.CommitLayoutPreview = function() rec.committed = true; rec.preview = nil end
    ns.CancelLayoutPreview = function() rec.cancelled = true; rec.preview = nil end
    rec.id = ns.SavePreset(nil, "Healer", ns.CurrentLayoutRef(), { chat = false, chatFade = 0, groupAuras = false,
        player = "resource", requireLivingTarget = true, visible = { bars = true, swing = true },
        groups = { ["1"] = 2 }, hostile = { ["1"] = true }, friendly = { ["2"] = true },
        range = { yards = "spell", kind = "friendly", spell = "Heal" } })
    return rec
end

h.test("General: preset selection stays a draft until Save, layout preview commits on Save", function(t)
    local ns, A = t.ns, t.assert
    local rec = fixture(t)
    local id = rec.id
    ns.ShowSetup()
    local ui = t.mock:findByName("QuietUISetup")
    A.ok(ui.presetSelector, "General has no preset selector")
    click(ui.presetSelector)
    A.ok(ui.presetMenu, "Preset selector must open a menu")
    click(ui.presetMenu.items[2])
    A.ok(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, "Selection must remain a draft")
    ui:Hide(); ns.ShowSetup(); click(ui.save)
    A.ok(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, "Closing discards selection")
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    A.ok(QuietUICharDB.presetId == id and QuietUICharDB.chat == false and QuietUICharDB.chatFade == 0)
    click(ui.layoutSelector); click(ui.layoutMenu.items[1])
    A.eq(rec.preview, "Other", "Layout selection must preview immediately")
    A.eq(ns.Presets()[id].layout.layoutName, "Raid", "Preview must not save the shared preset")
    ui:Hide(); ns.ShowSetup()
    A.ok(rec.cancelled and rec.preview == nil and ns.Presets()[id].layout.layoutName == "Raid")
    click(ui.layoutSelector); click(ui.layoutMenu.items[1]); click(ui.save)
    A.ok(rec.committed and ns.Presets()[id].layout.layoutName == "Other", "Save must commit the preview")
    A.ok(QuietUICharDB.groupAuras == false and QuietUICharDB.player == "resource")
    A.ok(QuietUICharDB.requireLivingTarget and (not QuietUICharDB.visible
        or (not QuietUICharDB.visible.bars and not QuietUICharDB.visible.swing)))
    A.ok(QuietUICharDB.groupVisibility[1] == "always" and QuietUICharDB.groupVisibility[2] == "always"
        and QuietUICharDB.groupVisibility[10] == "always", "Legacy bar pins were not migrated")
    A.ok(QuietUICharDB.groups["1"] == 2 and QuietUICharDB.hostile["1"] and QuietUICharDB.friendly["2"])
    A.ok(QuietUICharDB.range.spell == "Heal" and QuietUICharDB.range.kind == "friendly")
end)

h.test("General: detach keeps settings; Reset does not touch the shared preset", function(t)
    local ns, A = t.ns, t.assert
    local rec = fixture(t)
    local id = rec.id
    ns.ActivatePreset(id)
    ns.ShowSetup()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.presetSelector); click(ui.presetMenu.items[1]); click(ui.save)
    A.ok(not QuietUICharDB.presetId and QuietUICharDB.chat == false, "Detach preserves settings")
    ns.ActivatePreset(id); ns.ShowSetup(); click(ui.reset)
    A.ok(not QuietUICharDB.presetId and QuietUICharDB.chat == nil)
    A.eq(ns.Presets()[id].settings.chat, false, "Reset must not mutate shared preset")
end)

h.test("General: new, rename and delete presets are drafts until Save; preset command refreshes setup", function(t)
    local ns, A = t.ns, t.assert
    local rec = fixture(t)
    local id = rec.id
    ns.ShowSetup()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.newPreset)
    ui.presetDialog.edit:SetText("  Tank  ")
    click(ui.presetDialog.yes)
    A.eq(#ns.PresetList(), 1, "New preset stays a draft")
    click(ui.save)
    local tank = QuietUICharDB.presetId
    A.ok(tank and tank ~= id and ns.Presets()[tank].name == "Tank")
    click(ui.renamePreset)
    ui.presetDialog.edit:SetText("Healing")
    click(ui.presetDialog.yes)
    ui:Hide(); ns.ShowSetup()
    A.eq(ns.Presets()[tank].name, "Tank", "Closing must discard rename")
    click(ui.renamePreset)
    ui.presetDialog.edit:SetText("Defender")
    click(ui.presetDialog.yes)
    click(ui.save)
    A.ok(QuietUICharDB.presetId == tank and ns.Presets()[tank].name == "Defender")
    click(ui.deletePreset)
    click(ui.presetDialog.no)
    A.ok(ns.Presets()[tank], "Cancelling deletion must preserve the preset")
    click(ui.deletePreset)
    click(ui.presetDialog.yes)
    A.ok(not ns.Presets()[tank] and not QuietUICharDB.presetId)
    click(ui.newPreset)
    ui.presetDialog.edit:SetText("Unsaved")
    ns.PresetCommand("healer")
    A.ok(QuietUICharDB.presetId == id and ui:IsShown())
    A.eq(ui.presetSelector._text, "Healer", "Preset command must refresh the open setup")
    A.ok(not ui.presetDialog:IsShown(), "Preset command must close a stale draft dialog")
    click(ui.save)
    A.ok(#ns.PresetList() == 1 and QuietUICharDB.presetId == id,
        "Saving after a preset command must preserve its selection instead of the old draft")
end)
