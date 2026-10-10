-- Parchment windows settings contracts (Misc. tab, draft, Save, Reset, presets). Off by default.
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
        applied[#applied + 1] = { enabled = ns.Parchment and ns.Parchment(),
            saved = QuietUICharDB.parchment }
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
    assert(button and type(button.scripts.OnClick) == 'function', 'Required Parchment windows control is missing')
    button.scripts.OnClick(button)
end
local function enabled(ns)
    assert(type(ns.Parchment) == 'function', 'ns.Parchment public setting accessor is missing')
    return ns.Parchment()
end
-- The Misc. checkbox: a page child labelled "Parchment windows" with a box (the section heading has no box).
local function choice(ui)
    local found
    for _, child in ipairs(ui.pages[6].children) do
        if child.box and child.label and child.label.text == 'Parchment windows' then
            assert(not found, 'Misc. must have exactly one Parchment windows checkbox')
            found = child
        end
    end
    assert(found, 'Misc. Parchment windows checkbox is missing')
    return found
end
local function checked(ui) return choice(ui).box.checked == true end
local function header(ui)
    for _, child in ipairs(ui.pages[6].children) do
        if child.kind == 'Frame' and not child.box and child.label and child.label.text == 'Parchment windows' then
            return child
        end
    end
    error('Misc. has no Parchment windows section')
end
local function questMobsChoice(ui)
    for _, child in ipairs(ui.pages[6].children) do
        if child.box and child.label and child.label.text == 'Quest mobs' then return child end
    end
    error('Misc. Quest mobs checkbox must remain')
end
-- Resolves a TOPLEFT offset relative to the page, following anchors to sibling widgets.
local function offset(widget, page, depth)
    depth = depth or 0
    assert(depth < 10, 'Anchor chain too deep')
    local point = widget.points[1]
    assert(point, 'Widget has no anchor')
    local rel, relPoint, x, y = point[2], point[3] or point[1], point[4] or 0, point[5] or 0
    if type(rel) ~= 'table' then
        rel, relPoint, x, y = widget.parent, point[1], point[2] or 0, point[3] or 0
    end
    if rel == page then return x, y end
    local rx, ry = offset(rel, page, depth + 1)
    if type(relPoint) == 'string' and relPoint:find('RIGHT') then rx = rx + (rel.width or 0) end
    if type(relPoint) == 'string' and relPoint:find('BOTTOM') then ry = ry - (rel.height or 0) end
    return rx + x, ry + y
end
local function tooltip(help)
    local lines = {}
    GameTooltip = { SetOwner = function() end, SetText = function(_, text) lines[#lines + 1] = text end,
        Show = function() end, Hide = function() end, IsOwned = function() return true end,
        AddLine = function(_, text) lines[#lines + 1] = text end }
    if help and help.scripts.OnEnter then help.scripts.OnEnter(help) end
    return table.concat(lines, '\n')
end
local function texts(object, out)
    out = out or {}
    if type(object.text) == 'string' and object.text ~= '' then out[#out + 1] = object.text end
    for _, child in ipairs(object.children) do texts(child, out) end
    return out
end

case('Clean profile reads off and only explicit true turns it on', function(ns)
    assert(enabled(ns) == false, 'Missing parchment must default off')
    for _, value in ipairs({ false, 0, 1, 'on' }) do
        QuietUICharDB.parchment = value
        assert(enabled(ns) == false, 'Only true may enable parchment windows, got on for ' .. tostring(value))
    end
    QuietUICharDB.parchment = true
    assert(enabled(ns) == true, 'Personal true must enable parchment windows')
end)

case('parchment is a shared preset key', function(ns)
    local copy = ns.CopySettings({ parchment = true, unrelated = 'ignore' })
    assert(copy.parchment == true, 'CopySettings must keep parchment = true (add it to Presets.lua KEYS)')
    local target = { parchment = true }
    ns.CopySettings({}, target)
    assert(target.parchment == nil, 'Omitted parchment must clear a stale true')
    local id = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), { parchment = true })
    assert(ns.Presets()[id].settings.parchment == true, 'Preset creation must preserve parchment = true')
    ns.ActivatePreset(id)
    assert(QuietUICharDB.parchment == true and enabled(ns) == true, 'Activating an on preset must turn parchment on')
    ns.Presets()[id].settings.parchment = nil
    QuietUICharDB.parchment = true
    assert(enabled(ns) == false, 'Accessor must read the active preset (missing = off), not the personal snapshot')
end)

case('Misc. shows Parchment windows unchecked under Quest mobs with an English info text', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local page = ui.pages[6]
    assert(ui.tabs[6].label.text == 'Misc.' and #ui.tabs == 7, 'Misc. stays the sixth of seven tabs')
    local box = choice(ui)
    assert(box.parent == page, 'Parchment windows belongs on Misc.')
    assert(not checked(ui), 'Clean profile must paint Parchment windows unchecked')
    local section = header(ui)
    local _, sectionY = offset(section, page)
    local _, boxY = offset(box, page)
    local mobs = questMobsChoice(ui)
    local _, mobsY = offset(mobs, page)
    assert(-sectionY >= -mobsY + mobs.height, 'Parchment windows section must sit below the Quest mobs checkbox')
    assert(-boxY >= -sectionY + section.height, 'Parchment windows checkbox sits under its heading')
    assert(-boxY + box.height <= page.height, 'Parchment windows checkbox must fit inside the Misc. page height')
    local all = (tooltip(section.help) .. '\n' .. table.concat(texts(page), '\n')):lower()
    local info = tooltip(section.help):lower()
    assert(info:find('parchment', 1, true), 'Info must mention parchment')
    assert(info:find('quest', 1, true), 'Info must mention quest windows')
    assert(info:find('dialog', 1, true), 'Info must mention NPC dialog windows')
    assert(info:find('book', 1, true), 'Info must mention book windows')
    assert(all:find('parchment windows', 1, true), 'Misc. must show the Parchment windows label')
end)

case('Setup keeps one height on every tab and Misc. fits inside the window', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local box = choice(ui)
    local height = ui.height
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        assert(ui.height == height, 'Tab switch must not resize setup')
        assert(ui.pages[index].shown, 'Selected tab must show its page')
        for other, page in ipairs(ui.pages) do
            assert(page.shown == (index == other), 'Only selected page may be shown')
        end
    end
    local page = ui.pages[6]
    local pageTop = page.points[1][3]
    assert(type(pageTop) == 'number', 'Misc. page anchors with a numeric top offset')
    local _, boxY = offset(box, page)
    local footerTop = height - ui.save.points[1][3] - ui.save.height
    assert(-pageTop + page.height <= footerTop, 'Misc. page must not overlap the footer')
    assert(-pageTop - boxY + box.height <= footerTop, 'Parchment windows checkbox must sit above the footer')
    assert(-pageTop - boxY + box.height <= height, 'Parchment windows checkbox must fit inside the window')
end)

case('Checking is a draft; X and Escape discard it; an old saved false reads off', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(choice(ui))
    assert(checked(ui), 'Click must paint an on draft')
    assert(QuietUICharDB.parchment == nil and enabled(ns) == false, 'Unsaved draft must not change the setting')
    assert(#applied == 0, 'Draft must not apply live changes')
    ui:Hide(); ns.ShowSetup()
    assert(not checked(ui) and QuietUICharDB.parchment == nil, 'Closing must discard the on draft')
    QuietUICharDB.parchment = true
    ui:Hide(); ns.ShowSetup()
    assert(checked(ui), 'Setup paints stored on')
    click(choice(ui))
    ui:Hide(); ns.ShowSetup()
    assert(QuietUICharDB.parchment == true and checked(ui), 'Closing must keep the stored on value')
    QuietUICharDB.parchment = false
    ui:Hide(); ns.ShowSetup()
    assert(not checked(ui) and enabled(ns) == false, 'An old saved false reads and paints off')
    assert(#applied == 0, 'Closing must not apply')
    local escapeRegistered = false
    for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escapeRegistered = true end end
    assert(escapeRegistered, 'Escape must close the same setup frame and discard drafts')
end)

case('Save stores true only when on, nothing when off, and applies', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(ui.save)
    assert(QuietUICharDB.parchment == nil, 'Save while off must not store parchment')
    assert(#applied == 1 and applied[1].enabled == false, 'Save applies the off state')
    click(choice(ui)); click(ui.save)
    assert(QuietUICharDB.parchment == true and enabled(ns) == true, 'Save on must persist explicit true')
    assert(#applied == 2 and applied[2].enabled == true and applied[2].saved == true,
        'Save on must call ApplyAll after committing the setting')
    assert(ui.shown and checked(ui), 'Save keeps setup open and paints saved on')
    click(choice(ui)); click(ui.save)
    assert(QuietUICharDB.parchment == nil and enabled(ns) == false, 'Save off must omit the default')
    assert(#applied == 3 and applied[3].enabled == false and applied[3].saved == nil, 'Save off applies')
end)

case('Save with an active preset writes into the preset; switching picks up its value', function(ns)
    local on = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), { parchment = true })
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), {})
    ns.ActivatePreset(on); ns.ShowSetup()
    local ui = QuietUISetup
    assert(checked(ui), 'Selecting an on preset must paint checked')
    click(choice(ui)); click(ui.save)
    assert(ns.Presets()[on].settings.parchment == nil and enabled(ns) == false, 'Save off must clear preset true')
    click(choice(ui)); click(ui.save)
    assert(ns.Presets()[on].settings.parchment == true and enabled(ns) == true, 'Save on must update the preset')
    ns.ActivatePreset(off); ns.ShowSetup()
    assert(not checked(ui) and enabled(ns) == false and QuietUICharDB.parchment == nil,
        'Switching to an off preset reads off')
    ns.ActivatePreset(on); ns.ShowSetup()
    assert(checked(ui) and enabled(ns) == true, 'Switching back reads the preset on value')
    ns.ActivatePreset(nil)
    assert(QuietUICharDB.parchment == true and enabled(ns) == true, 'Detach keeps the last snapshot')
end)

case('Preset selector is a draft; saving the selection applies its parchment', function(ns, applied)
    local on = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), { parchment = true })
    ns.ShowSetup()
    local ui = QuietUISetup
    choice(ui)
    click(ui.presetSelector); click(ui.presetMenu.items[2])
    assert(checked(ui) and enabled(ns) == false, 'Preset draft must paint on without applying it')
    assert(QuietUICharDB.presetId == nil and #applied == 0, 'Preset choice must stay unsaved')
    ui:Hide(); ns.ShowSetup()
    assert(not checked(ui), 'Closing discards the preset draft')
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    assert(QuietUICharDB.presetId == on and enabled(ns) == true, 'Saving the preset selection applies on')
    assert(#applied == 1 and applied[1].enabled == true, 'Preset Save applies the committed state')
end)

case('Reset turns Parchment windows off, saves, and leaves the shared preset unchanged', function(ns, applied)
    local on = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), { parchment = true })
    ns.ActivatePreset(on); ns.ShowSetup()
    local ui = QuietUISetup
    assert(checked(ui), 'Preset on must paint')
    click(ui.reset)
    assert(QuietUICharDB.presetId == nil and QuietUICharDB.parchment == nil and enabled(ns) == false,
        'Reset must detach and save default off')
    assert(not checked(ui) and ui.shown, 'Reset paints off and leaves setup open')
    assert(ns.Presets()[on].settings.parchment == true, 'Reset must not mutate the shared preset')
    assert(#applied == 1 and applied[1].enabled == false, 'Reset applies immediately')
end)

for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
print(string.format('%d parchment settings cases, %d failures', cases, #failures))
assert(#failures == 0, 'Parchment settings contracts failed')
