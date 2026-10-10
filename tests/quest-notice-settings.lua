-- Settings and structural UI contracts; visual alignment still needs /reload.
local methods = {}
local make
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(target) self.allPoints = target or self.parent end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) end
function methods:IsForbidden() return false end
function methods:GetChildren()
    local children = {}
    for _, child in ipairs(self.children) do
        if child.kind ~= 'Texture' and child.kind ~= 'FontString' then children[#children + 1] = child end
    end
    return table.unpack(children)
end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetText(text)
    self.text = text
    if self.font then self.font.text = text end
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:GetName() return self.name end
function methods:GetFontString() return self.font end
function methods:SetFontString(font) self.font = font end
function methods:GetStringWidth() return #(self.text or '') * 6 end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha end
function methods:SetTexture(texture) self.texture = texture; return true end
function methods:SetAtlas(atlas) self.texture = atlas; return true end
function methods:GetTexture() return self.texture end
function methods:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
function methods:SetChecked(checked) self.checked = checked end
function methods:Enable() self.disabled = false end
function methods:Disable() self.disabled = true end
function methods:SetFocus() self.focus = true end
function methods:ClearFocus() self.focus = false end
function methods:HasFocus() return self.focus == true end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetNormalTexture(texture) self.normalTexture = texture end
function methods:SetHighlightTexture(texture) self.highlightTexture = texture end
-- Explicit input and text-format methods which do not affect these contracts.
for _, name in ipairs({ 'SetFontObject', 'SetJustifyH', 'SetJustifyV', 'SetAutoFocus', 'SetMaxLetters',
    'SetTextInsets', 'SetTexCoord', 'EnableMouse', 'EnableMouseWheel', 'RegisterForClicks',
    'RegisterForDrag', 'HighlightText', 'SetMotionScriptsWhileDisabled' }) do
    methods[name] = function() end
end
make = function(kind, parent, name)
    local object = setmetatable({ kind = kind, parent = parent, name = name, scripts = {}, children = {},
        points = {}, shown = true, text = '', width = 100, height = 22,
        level = parent and parent.level + 1 or 0 }, { __index = methods })
    if parent then parent.children[#parent.children + 1] = object end
    return object
end
function methods:CreateTexture() return make('Texture', self) end
function methods:CreateFontString() return make('FontString', self) end

local function fixture()
    QuietUISetup = nil; QuietUIDB = {}; QuietUICharDB = {}; UISpecialFrames = {}
    UIParent = make('Frame'); UIParent.strata = 'MEDIUM'
    Enum = nil; InputUtil = nil; EditModePresetLayoutManager = nil
    InCombatLockdown = function() return false end
    CreateFrame = function(kind, name, parent, template)
        if template == 'PortraitFrameTemplate' then error('portrait template unavailable') end
        local object = make(kind, parent, name)
        if name then _G[name] = object end
        if kind == 'Button' or kind == 'CheckButton' then object.font = object:CreateFontString() end
        return object
    end
    local ns, applied = {}, {}
    ns.DB = function() return QuietUIDB end
    ns.IsSecret = function() return false end
    ns.Print = function(message) ns.message = message end
    ns.Glancing = function() return false end
    ns.BarGroup = function() return 1 end
    ns.BarTarget = function() return false end
    ns.CurrentLayoutRef = function() return { layoutName = 'Original', layoutType = 1 } end
    ns.LayoutChoices = function() return {} end
    ns.ApplyAll = function()
        applied[#applied + 1] = { enabled = ns.QuestNoticeEnabled and ns.QuestNoticeEnabled(),
            saved = QuietUICharDB.questNotice }
    end
    assert(loadfile('Bars.lua'))('QuietUI', ns)
    assert(loadfile('Presets.lua'))('QuietUI', ns)
    assert(loadfile('Setup.lua'))('QuietUI', ns)
    return ns, applied
end

local failures, cases = {}, 0
local function case(name, run)
    cases = cases + 1
    local ns, applied = fixture()
    local ok, err = pcall(run, ns, applied)
    if ok then print('PASS ' .. name) else failures[#failures + 1] = name .. ': ' .. tostring(err) end
end
local function click(button)
    assert(button and type(button.scripts.OnClick) == 'function', 'Required Quest updates control is missing')
    button.scripts.OnClick(button)
end
local function enabled(ns)
    assert(type(ns.QuestNoticeEnabled) == 'function', 'QuestNoticeEnabled public setting accessor is missing')
    return ns.QuestNoticeEnabled()
end

case('Quest updates defaults on and only explicit false turns it off', function(ns)
    assert(enabled(ns) == true, 'Missing setting must default on')
    for _, value in ipairs({ true, 0, 'off' }) do
        QuietUICharDB.questNotice = value
        assert(enabled(ns) == true, 'Only false may disable notices')
    end
    QuietUICharDB.questNotice = false
    assert(enabled(ns) == false, 'Personal false must disable notices')
    local id = ns.SavePreset(nil, 'Default', ns.CurrentLayoutRef(), {})
    ns.ActivatePreset(id)
    assert(enabled(ns) == true, 'Effective preset default must override personal off')
    ns.Presets()[id].settings.questNotice = false
    QuietUICharDB.questNotice = nil
    assert(enabled(ns) == false, 'Accessor must read active preset settings')
end)

case('CopySettings snapshots explicit false and clears omitted defaults', function(ns)
    local copy = ns.CopySettings({ questNotice = false, unrelated = 'ignore' })
    assert(copy.questNotice == false, 'CopySettings whitelist drops notice off')
    assert(copy.unrelated == nil, 'Settings copy must stay whitelisted')
    local target = { questNotice = false, previousLayout = 3 }
    ns.CopySettings({}, target)
    assert(target.questNotice == nil, 'Omitted notice setting must clear a stale false')
    assert(target.previousLayout == 3, 'CopySettings must preserve layout lifecycle metadata')
end)

case('Quest updates sits on Misc. below chat with a description', function(ns)
    ns.ShowSetup()
    local ui, choice = QuietUISetup, QuietUISetup.questNotice
    local page = ui.pages[6]
    assert(choice and choice.box and choice.label, 'Misc. Quest updates choice is missing')
    assert(ui.tabs[6].label.text == 'Misc.', 'Sixth tab is Misc.')
    assert(choice.parent == page and choice.label.text == 'Quest updates', 'Choice belongs on Misc.')
    assert(choice.box.checked, 'Default choice must be checked')
    assert(#ui.tabs == 7, 'Adding Quest updates must retain seven tabs')
    local height = ui.height
    assert(height <= 474, 'Quest updates must fit the existing compact setup height')
    local fade, header = ui.fade, ui.questHeader
    assert(header and header.parent == page and header.points[1][2] == page, 'Quest section belongs on Misc.')
    assert(-header.points[1][5] >= -fade.points[1][5] + fade.height + 24, 'Quest section must sit clear of chat')
    assert(header.help, 'Quest heading must offer an info button')
    local lines = {}
    GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end, Hide = function() end,
        AddLine = function(_, text) lines[#lines + 1] = text end }
    header.help.scripts.OnEnter(header.help)
    local bubble = table.concat(lines, '\n')
    assert(bubble:find('accepted', 1, true) and bubble:find('completed', 1, true),
        'Info bubble must say what quest updates do')
    local point = choice.points[1]
    assert(point and point[1] == 'TOPLEFT' and point[2] == page and point[3] == 'TOPLEFT',
        'Choice sits on the Misc. page')
    assert(-point[5] >= -header.points[1][5] + header.height, 'Choice sits under the quest heading')
    local sizeRow = ui.questNoticeSize
    assert(sizeRow and sizeRow.parent == page and sizeRow.value.text == 'Default', 'Text size defaults on Misc.')
    assert(-sizeRow.points[1][5] >= -point[5] + choice.height, 'Text size sits under Quest updates')
    assert(-sizeRow.points[1][5] + sizeRow.height <= page.height, 'Text size must fit Misc. content')
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        assert(ui.height == height, 'Tab switch must not resize setup')
        assert(ui.pages[index].shown, 'Selected tab must show its page')
        for other, page in ipairs(ui.pages) do
            assert(page.shown == (index == other), 'Only selected page may be shown')
        end
    end
end)

case('Text size cycles only Smaller, Default and Larger and saves the two offsets', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    local function label() return ui.questNoticeSize.value.text end
    click(ui.questNoticeSize.minus)
    assert(label() == 'Smaller' and QuietUICharDB.questNoticeSize == nil, 'Smaller stays a draft')
    click(ui.questNoticeSize.minus)
    assert(label() == 'Smaller', 'Minus stops at Smaller')
    click(ui.questNoticeSize.plus); click(ui.questNoticeSize.plus)
    assert(label() == 'Larger', 'Plus moves Smaller, Default, Larger')
    click(ui.questNoticeSize.plus)
    assert(label() == 'Larger', 'Plus stops at Larger')
    assert(#applied == 0 and ns.QuestNoticeSize() == 'default', 'Unsaved size must not change live notices')
    click(ui.save)
    assert(QuietUICharDB.questNoticeSize == 'larger' and ns.QuestNoticeSize() == 'larger', 'Save keeps Larger')
    click(ui.questNoticeSize.minus); click(ui.save)
    assert(QuietUICharDB.questNoticeSize == nil and ns.QuestNoticeSize() == 'default', 'Default omits the stored size')
    click(ui.questNoticeSize.minus); click(ui.save)
    assert(QuietUICharDB.questNoticeSize == 'smaller' and ns.QuestNoticeSize() == 'smaller', 'Save keeps Smaller')
    QuietUICharDB.questNoticeSize = 'huge'
    assert(ns.QuestNoticeSize() == 'default', 'Only smaller and larger are accepted')
    local copy = ns.CopySettings({ questNoticeSize = 'larger' })
    assert(copy.questNoticeSize == 'larger', 'Presets keep an explicit text size')
end)

case('Draft click and close discard without changing saved notice state', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(ui.questNotice)
    assert(not ui.questNotice.box.checked, 'Click must paint an off draft')
    assert(QuietUICharDB.questNotice == nil and enabled(ns), 'Unsaved draft must not disable live notices')
    assert(#applied == 0, 'Draft must not apply live changes')
    ui:Hide(); ns.ShowSetup()
    assert(ui.questNotice.box.checked and enabled(ns), 'Closing must discard off draft')
    local escapeRegistered = false
    for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escapeRegistered = true end end
    assert(escapeRegistered, 'Escape must close the same setup frame and discard drafts')
end)

case('Save off stores false, Save on stores nil, both apply immediately', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(ui.questNotice); click(ui.save)
    assert(QuietUICharDB.questNotice == false and not enabled(ns), 'Save off must persist explicit false')
    assert(#applied == 1 and applied[1].enabled == false and applied[1].saved == false,
        'Save off must call ApplyAll after committing setting')
    assert(ui.shown and not ui.questNotice.box.checked, 'Save keeps setup open and paints saved off')
    click(ui.questNotice)
    assert(not enabled(ns), 'Unsaved on must leave notices disabled')
    ui:Hide(); ns.ShowSetup()
    assert(not ui.questNotice.box.checked, 'Closing must discard on draft')
    click(ui.questNotice); click(ui.save)
    assert(QuietUICharDB.questNotice == nil and enabled(ns), 'Save on must omit default setting')
    assert(#applied == 2 and applied[2].enabled == true and applied[2].saved == nil,
        'Save on must apply after clearing stored false')
end)

case('Presets preserve off through create select save detach and deletion', function(ns)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questNotice = false })
    local on = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), {})
    assert(ns.Presets()[off].settings.questNotice == false, 'Preset creation must preserve false')
    ns.ActivatePreset(off)
    assert(QuietUICharDB.questNotice == false and not enabled(ns), 'Select off must snapshot false')
    ns.ShowSetup()
    local ui = QuietUISetup
    assert(not ui.questNotice.box.checked, 'Selecting preset must paint its off state')
    click(ui.questNotice); click(ui.save)
    assert(ns.Presets()[off].settings.questNotice == nil and enabled(ns), 'Save on must clear active preset false')
    click(ui.questNotice); click(ui.save)
    assert(ns.Presets()[off].settings.questNotice == false, 'Save off must update active preset')
    ns.ActivatePreset(on); ns.ShowSetup()
    assert(ui.questNotice.box.checked and QuietUICharDB.questNotice == nil, 'Select on clears stale snapshot')
    ns.ActivatePreset(off); ns.ActivatePreset(nil)
    assert(QuietUICharDB.questNotice == false and not enabled(ns), 'Detach must retain last personal snapshot')
    ns.ActivatePreset(off); ns.DeletePreset(off)
    assert(QuietUICharDB.questNotice == false and not enabled(ns), 'Delete active preset retains snapshot')
end)

case('Preset selector remains a draft, saving selection applies notice setting', function(ns, applied)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questNotice = false })
    ns.ShowSetup()
    local ui = QuietUISetup
    assert(ui.questNotice and ui.questNotice.box, 'Misc. Quest updates choice is missing')
    click(ui.presetSelector); click(ui.presetMenu.items[2])
    assert(not ui.questNotice.box.checked and enabled(ns), 'Preset draft must paint off without applying it')
    assert(QuietUICharDB.presetId == nil and #applied == 0, 'Preset choice must stay unsaved')
    ui:Hide(); ns.ShowSetup()
    assert(ui.questNotice.box.checked and not QuietUICharDB.presetId, 'Closing discards preset off draft')
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    assert(QuietUICharDB.presetId == off and not enabled(ns), 'Saving preset selection must apply off')
    assert(#applied == 1 and applied[1].enabled == false, 'Preset Save applies committed notice state')
end)

case('Reset turns notices on detaches and leaves shared preset unchanged', function(ns, applied)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questNotice = false })
    ns.ActivatePreset(off); ns.ShowSetup()
    local ui = QuietUISetup
    click(ui.reset)
    assert(QuietUICharDB.presetId == nil and QuietUICharDB.questNotice == nil and enabled(ns),
        'Reset must detach and save default on')
    assert(ui.questNotice.box.checked and ui.shown, 'Reset paints on and leaves setup open')
    assert(ns.Presets()[off].settings.questNotice == false, 'Reset must not mutate shared preset')
    assert(#applied == 1 and applied[1].enabled == true, 'Reset immediately applies saved default')
end)

for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
print(string.format('%d quest notice settings cases, %d failures', cases, #failures))
assert(#failures == 0, 'Quest notice settings contracts failed')
