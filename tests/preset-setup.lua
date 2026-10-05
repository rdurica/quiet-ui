local ns = {}
QuietUIDB = {}; QuietUICharDB = { chatFade = 20 }
local function widget(parent)
    local obj = { parent = parent, scripts = {}, shown = true, text = '', width = 100, height = 10, scrollOffset = 0 }
    return setmetatable(obj, { __index = function(self, key)
        if key == 'CreateTexture' or key == 'CreateFontString' then return function() return widget(self) end end
        if key == 'GetScript' then return function(_, event) return self.scripts[event] end end
        if key == 'SetScript' then return function(_, event, fn) self.scripts[event] = fn end end
        if key == 'HookScript' then return function(_, event, fn) self.scripts[event] = fn end end
        if key == 'SetText' then return function(_, value) self.text = value; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end end
        if key == 'GetText' then return function() return self.text end end
        if key == 'GetName' then return function() return self.name end end
        if key == 'GetFrameLevel' then return function() return 1 end end
        if key == 'HasFocus' then return function() return false end end
        if key == 'Show' then return function() self.shown = true end end
        if key == 'Hide' then return function() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
        if key == 'IsShown' then return function() return self.shown end end
        if key == 'GetFontString' then return function() return widget(self) end end
        if key == 'Disable' then return function() self.disabled = true end end
        if key == 'Enable' then return function() self.disabled = false end end
        if key == 'SetChecked' then return function(_, value) self.checked = value end end
        if key == 'SetSize' then return function(_, w, h) self.width = w; self.height = h end end
        if key == 'SetHeight' then return function(_, h) self.height = h end end
        if key == 'GetHeight' then return function() return self.height end end
        if key == 'SetVerticalScroll' then return function(_, value) self.scrollOffset = value end end
        if key == 'GetVerticalScroll' then return function() return self.scrollOffset end end
        if key == 'HighlightText' then return function() end end
        if key:match('^Set') or key:match('^Enable') or key:match('^Clear') or key:match('^Register') then return function() end end
    end })
end
UIParent = widget()
CreateFrame = function(_, name, parent) local obj = widget(parent); obj.name = name; if name then _G[name] = obj end; return obj end
UISpecialFrames = {}
ns.DB = function() return QuietUIDB end
ns.IsSecret = function() return false end
ns.Print = function(message) ns.message = message end
assert(loadfile('Bars.lua'))('QuietUI', ns)
ns.Glancing = function() return false end
ns.BarGroup = function() return 1 end
ns.BarTarget = function() return false end
ns.ApplyAll = function() end
ns.CurrentLayoutRef = function() return { layoutName = 'Raid', layoutType = 1 } end
ns.LayoutChoices = function() return { { name = 'Other', ref = { layoutName = 'Other', layoutType = 1 } } } end
local preview, committed, cancelled
ns.PreviewLayout = function(ref) preview = ref.layoutName end
ns.CommitLayoutPreview = function() committed = true; preview = nil end
ns.CancelLayoutPreview = function() cancelled = true; preview = nil end
assert(loadfile('Presets.lua'))('QuietUI', ns)
assert(loadfile('Setup.lua'))('QuietUI', ns)
local id = ns.SavePreset(nil, 'Healer', ns.CurrentLayoutRef(), { chat = false, chatFade = 0, groupAuras = false, player = 'resource',
    requireLivingTarget = true, visible = { bars = true, swing = true },
    groups = { ['1'] = 2 }, hostile = { ['1'] = true }, friendly = { ['2'] = true },
    range = { yards = 'spell', kind = 'friendly', spell = 'Heal' } })
ns.ShowSetup()
local ui = QuietUISetup
assert(ui.presetSelector, 'General has no preset selector')
ui.presetSelector.scripts.OnClick()
assert(ui.presetMenu, 'Preset selector must open a menu')
ui.presetMenu.items[2].scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, 'Selection must remain a draft')
ui:Hide(); ns.ShowSetup(); ui.save.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, 'Closing discards selection')
ui.presetSelector.scripts.OnClick(); ui.presetMenu.items[2].scripts.OnClick(); ui.save.scripts.OnClick()
assert(QuietUICharDB.presetId == id and QuietUICharDB.chat == false and QuietUICharDB.chatFade == 0)
ui.layoutSelector.scripts.OnClick(); ui.layoutMenu.items[1].scripts.OnClick()
assert(preview == 'Other', 'Layout selection must preview immediately')
assert(ns.Presets()[id].layout.layoutName == 'Raid', 'Preview must not save the shared preset')
ui:Hide(); ns.ShowSetup()
assert(cancelled and preview == nil and ns.Presets()[id].layout.layoutName == 'Raid')
ui.layoutSelector.scripts.OnClick(); ui.layoutMenu.items[1].scripts.OnClick(); ui.save.scripts.OnClick()
assert(committed and ns.Presets()[id].layout.layoutName == 'Other', 'Save must commit the preview')
assert(QuietUICharDB.groupAuras == false and QuietUICharDB.player == 'resource')
assert(QuietUICharDB.requireLivingTarget and (not QuietUICharDB.visible
    or (not QuietUICharDB.visible.bars and not QuietUICharDB.visible.swing)))
assert(QuietUICharDB.groupVisibility[1] == 'always' and QuietUICharDB.groupVisibility[2] == 'always'
    and QuietUICharDB.groupVisibility[10] == 'always', 'Legacy bar pins were not migrated')
assert(QuietUICharDB.groups['1'] == 2 and QuietUICharDB.hostile['1'] and QuietUICharDB.friendly['2'])
assert(QuietUICharDB.range.spell == 'Heal' and QuietUICharDB.range.kind == 'friendly')
ui.presetSelector.scripts.OnClick(); ui.presetMenu.items[1].scripts.OnClick(); ui.save.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chat == false, 'Detach preserves settings')
ns.ActivatePreset(id); ns.ShowSetup(); ui.reset.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chat == nil)
assert(ns.Presets()[id].settings.chat == false, 'Reset must not mutate shared preset')
ui.newPreset.scripts.OnClick()
ui.presetDialog.edit:SetText('  Tank  ')
ui.presetDialog.yes.scripts.OnClick()
assert(#ns.PresetList() == 1, 'New preset stays a draft')
ui.save.scripts.OnClick()
local tank = QuietUICharDB.presetId
assert(tank and tank ~= id and ns.Presets()[tank].name == 'Tank')
ui.renamePreset.scripts.OnClick()
ui.presetDialog.edit:SetText('Healing')
ui.presetDialog.yes.scripts.OnClick()
ui:Hide(); ns.ShowSetup()
assert(ns.Presets()[tank].name == 'Tank', 'Closing must discard rename')
ui.renamePreset.scripts.OnClick()
ui.presetDialog.edit:SetText('Defender')
ui.presetDialog.yes.scripts.OnClick()
ui.save.scripts.OnClick()
assert(QuietUICharDB.presetId == tank and ns.Presets()[tank].name == 'Defender')
ui.deletePreset.scripts.OnClick()
ui.presetDialog.no.scripts.OnClick()
assert(ns.Presets()[tank], 'Cancelling deletion must preserve the preset')
ui.deletePreset.scripts.OnClick()
ui.presetDialog.yes.scripts.OnClick()
assert(not ns.Presets()[tank] and not QuietUICharDB.presetId)
ui.newPreset.scripts.OnClick()
ui.presetDialog.edit:SetText('Unsaved')
ns.PresetCommand('healer')
assert(QuietUICharDB.presetId == id and ui:IsShown())
assert(ui.presetSelector.text == 'Healer', 'Preset command must refresh the open setup')
assert(not ui.presetDialog:IsShown(), 'Preset command must close a stale draft dialog')
ui.save.scripts.OnClick()
assert(#ns.PresetList() == 1 and QuietUICharDB.presetId == id,
    'Saving after a preset command must preserve its selection instead of the old draft')
print('PASS General draft selection, cancel, save, detach and reset')
assert(ui.width >= 592 and ui.width <= 636 and ui.height <= 474, 'Setup is not compact')
assert(#ui.tabs == 7 and ui.pages[4].id == 'groups', 'Groups tab is missing')
assert(ui.visibilityHeader.parent == ui.pages[4] and ui.groupRows[1].parent == ui.pages[3],
    'Group visibility did not move out of Bars')
assert(ui.presetSelector.width == ui.pages[1].width and ui.layoutSelector.width == ui.pages[1].width,
    'General selectors do not use the content width')
for _, row in ipairs(ui.rows) do
    assert(row.key ~= 'bars' and row.key ~= 'swing', 'Bars still appear on Visible')
end
local group = ui.visibilityRows[1]
assert(group.members.text:find('Bar 2') and group.members.text:find('Stance bar'))
local first = ui.groupRows[1]
ui.visibilityRows[2].hover.scripts.OnClick()
assert(first.hostile.disabled and first.friendly.disabled)
assert(ui.visibilityRows[2].hover.box.checked and not ui.visibilityRows[2].always.box.checked)
ui:Hide(); ns.ShowSetup()
assert(ui.visibilityRows[2].always.box.checked, 'Cancel saved a hover mode')
ui.visibilityRows[2].hover.scripts.OnClick(); ui.save.scripts.OnClick()
assert(ns.Presets()[id].settings.groupVisibility[2] == 'hover')
ui.visibilityRows[3].always.scripts.OnClick()
first.plus.scripts.OnClick()
assert(ui.visibilityRows[3].members.text:find('Bar 1'), 'Group membership did not refresh')
assert(not first.hostile.disabled, 'Moved bar retained old group control')
ui.save.scripts.OnClick()
assert(QuietUICharDB.groups['1'] == 3)
local visible = ui.rows[1]
assert(visible.hover.box.checked, "XP must default to Only on hover")
visible.hover.scripts.OnClick()
visible.hover.scripts.OnClick()
assert(visible.hover.box.checked and not visible.always.box.checked)
visible.always.scripts.OnClick()
assert(visible.always.box.checked and not visible.hover.box.checked)
visible.hover.scripts.OnClick(); ui.save.scripts.OnClick()
assert(QuietUICharDB.hoverOnly.xp and (not QuietUICharDB.visible or not QuietUICharDB.visible.xp))
-- Every possible group is reachable, and regrouping clamps a stale scroll offset.
for index, row in ipairs(ui.groupRows) do
    for i = 1, 12 do row.plus.scripts.OnClick() end
    for i = index + 1, 12 do row.minus.scripts.OnClick() end
end
ui.groupScroll.scripts.OnMouseWheel(nil, -100)
assert(ui.groupScroll.scrollOffset == 12 * 44 - 264, 'Last groups cannot be reached')
for _, row in ipairs(ui.groupRows) do
    for i = 1, 12 do row.minus.scripts.OnClick() end
end
assert(ui.groupScroll.scrollOffset == 0 and ui.visibilityRows[1].shown and not ui.visibilityRows[2].shown)
ui:Hide(); ns.ShowSetup()
ui.reset.scripts.OnClick()
assert(not QuietUICharDB.groupVisibility and not QuietUICharDB.hoverOnly and ns.OnlyOnHover("xp"))
assert(ns.Presets()[id].settings.groupVisibility[2] == 'hover', 'Reset changed shared modes')
print('PASS Compact seven-tab setup, group modes, membership, mutual exclusion, scrolling and reset')

local partyRow
for _, row in ipairs(ui.rows) do if row.key == 'party' then partyRow = row end end
assert(partyRow and partyRow.always.box.checked and partyRow.hover.disabled,
    'Party frames must default to Always visible with Only on hover disabled')
partyRow.hover.scripts.OnClick()
assert(not partyRow.hover.box.checked, 'The disabled party hover choice must never change its value')
partyRow.always.scripts.OnClick()
assert(not QuietUICharDB.autoHideParty, 'Unchecking must remain a draft')
ui:Hide(); ns.ShowSetup()
assert(partyRow.always.box.checked, 'Closing must cancel party autohide edits')
partyRow.always.scripts.OnClick(); ui.save.scripts.OnClick()
assert(QuietUICharDB.autoHideParty and ns.AutoHideParty(), 'Save must enable party autohide')
local partyPreset = ns.SavePreset(nil, 'Party fade', ns.CurrentLayoutRef(), QuietUICharDB)
ns.ActivatePreset(partyPreset)
assert(ns.AutoHideParty(), 'Preset must retain party autohide')
ns.ShowSetup(); partyRow.always.scripts.OnClick(); ui.save.scripts.OnClick()
assert(not ns.AutoHideParty() and ns.Presets()[partyPreset].settings.autoHideParty == nil,
    'Saving Always visible must update the active preset')
ns.ShowSetup(); partyRow.always.scripts.OnClick(); ui.save.scripts.OnClick()
ns.DeletePreset(partyPreset)
assert(ns.AutoHideParty(), 'Deleting a preset must retain the personal autohide snapshot')
ns.ActivatePreset(nil, {}); ns.ShowSetup()
partyRow.always.scripts.OnClick(); ui.save.scripts.OnClick()
ui.reset.scripts.OnClick()
assert(not ns.AutoHideParty() and partyRow.always.box.checked, 'Reset must restore Always visible')
print('PASS Party frame UI defaults, disabled hover, save, cancel, presets and reset')
