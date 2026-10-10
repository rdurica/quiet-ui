-- Quest mobs settings contracts (Misc. tab, draft, Save, Reset, presets); visuals still need /reload.
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
        applied[#applied + 1] = { enabled = type(ns.QuestMobs) == 'function' and ns.QuestMobs() or nil,
            saved = QuietUICharDB.questMobs }
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
    assert(button and type(button.scripts.OnClick) == 'function', 'Required Quest mobs control is missing')
    button.scripts.OnClick(button)
end
local function enabled(ns)
    assert(type(ns.QuestMobs) == 'function', 'ns.QuestMobs public setting accessor is missing')
    return ns.QuestMobs()
end
-- The Misc. checkbox: a page child labelled "Quest mobs" with a box (the section heading has no box).
local function choice(ui)
    local page = ui.pages[6]
    local found
    for _, child in ipairs(page.children) do
        if child.box and child.label and child.label.text == 'Quest mobs' then
            assert(not found, 'Misc. must have exactly one Quest mobs checkbox')
            found = child
        end
    end
    assert(found, 'Misc. Quest mobs checkbox is missing')
    return found
end
local function checked(ui) return choice(ui).box.checked == true end
local function header(ui)
    for _, child in ipairs(ui.pages[6].children) do
        if child.kind == 'Frame' and not child.box and child.label and child.label.text == 'Quest mobs' then
            return child
        end
    end
    error('Misc. has no Quest mobs section')
end
local function highlightHeader(ui)
    for _, child in ipairs(ui.pages[6].children) do
        if child.kind == 'Frame' and child.label and child.label.text == 'Highlights' then return child end
    end
    error('Misc. has no Highlights section')
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

case('Clean profile reads on and only explicit false turns it off', function(ns)
    assert(enabled(ns) == true, 'Missing questMobs must default on')
    for _, value in ipairs({ true, 0, 'off' }) do
        QuietUICharDB.questMobs = value
        assert(enabled(ns) == true, 'Only false may disable quest mob icons')
    end
    QuietUICharDB.questMobs = false
    assert(enabled(ns) == false, 'Personal false must disable quest mob icons')
end)

case('questMobs is a shared preset key', function(ns)
    local copy = ns.CopySettings({ questMobs = false, unrelated = 'ignore' })
    assert(copy.questMobs == false, 'CopySettings must keep questMobs = false (add it to Presets.lua KEYS)')
    local target = { questMobs = false }
    ns.CopySettings({}, target)
    assert(target.questMobs == nil, 'Omitted questMobs must clear a stale false')
    local id = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questMobs = false })
    assert(ns.Presets()[id].settings.questMobs == false, 'Preset creation must preserve questMobs = false')
    ns.ActivatePreset(id)
    assert(QuietUICharDB.questMobs == false and enabled(ns) == false, 'Activating an off preset must turn icons off')
    ns.Presets()[id].settings.questMobs = nil
    QuietUICharDB.questMobs = false
    assert(enabled(ns) == true, 'Accessor must read the active preset, not the personal snapshot')
end)

case('Misc. shows Quest mobs checked under Highlights with an English info text', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local page = ui.pages[6]
    assert(ui.tabs[6].label.text == 'Misc.' and #ui.tabs == 7, 'Misc. stays the sixth of seven tabs')
    local box = choice(ui)
    assert(box.parent == page, 'Quest mobs belongs on Misc.')
    assert(checked(ui), 'Clean profile must paint Quest mobs checked')
    local section = header(ui)
    local _, sectionY = offset(section, page)
    local _, boxY = offset(box, page)
    local _, highlightY = offset(highlightHeader(ui), page)
    assert(-sectionY > -highlightY, 'Quest mobs section must sit below the Highlights heading')
    for _, key in ipairs({ 'highlightHerb', 'highlightOre', 'highlightQuest' }) do
        local widget = ui[key]
        assert(widget, 'Highlights choice ' .. key .. ' must remain')
        local _, y = offset(widget, page)
        assert(-sectionY >= -y + widget.height, 'Quest mobs section must sit below the Highlights choices')
    end
    assert(-boxY >= -sectionY + section.height, 'Quest mobs checkbox sits under its heading')
    assert(-boxY + box.height <= page.height, 'Quest mobs checkbox must fit inside the Misc. page height')
    local all = (tooltip(section.help) .. '\n' .. table.concat(texts(page), '\n')):lower()
    assert(all:find('exclamation', 1, true), 'Info must mention the exclamation mark for kill mobs')
    assert(all:find('pouch', 1, true), 'Info must mention the pouch for mobs that drop a quest item')
    assert(all:find('attack', 1, true), 'Info must say only attackable mobs are marked')
    assert(all:find('complete', 1, true), 'Info must say the icon disappears once the objective is complete')
end)

case('Setup keeps one height on every tab and fits the tallest page', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    choice(ui)
    local height = ui.height
    assert(height <= 474, 'Setup must stay compact')
    local tallest = 0
    for _, page in ipairs(ui.pages) do if page.height > tallest then tallest = page.height end end
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        assert(ui.height == height, 'Tab switch must not resize setup')
        assert(ui.pages[index].shown, 'Selected tab must show its page')
        for other, page in ipairs(ui.pages) do
            assert(page.shown == (index == other), 'Only selected page may be shown')
        end
    end
    assert(ui.pages[6].height <= tallest, 'Misc. may not exceed the tallest tab')
end)

case('Unchecking is a draft; X and Escape discard it', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(choice(ui))
    assert(not checked(ui), 'Click must paint an off draft')
    assert(QuietUICharDB.questMobs == nil and enabled(ns) == true, 'Unsaved draft must not change the setting')
    assert(#applied == 0, 'Draft must not apply live changes')
    ui:Hide(); ns.ShowSetup()
    assert(checked(ui) and QuietUICharDB.questMobs == nil, 'Closing must discard the off draft')
    QuietUICharDB.questMobs = false
    ui:Hide(); ns.ShowSetup()
    assert(not checked(ui), 'Setup paints stored off')
    click(choice(ui))
    ui:Hide(); ns.ShowSetup()
    assert(QuietUICharDB.questMobs == false and not checked(ui), 'Closing must keep the stored off value')
    assert(#applied == 0, 'Closing must not apply')
    local escapeRegistered = false
    for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escapeRegistered = true end end
    assert(escapeRegistered, 'Escape must close the same setup frame and discard drafts')
end)

case('Save stores false only when off, nothing when on, and applies', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(ui.save)
    assert(QuietUICharDB.questMobs == nil, 'Save while on must not store questMobs')
    assert(#applied == 1 and applied[1].enabled == true, 'Save applies the on state')
    click(choice(ui)); click(ui.save)
    assert(QuietUICharDB.questMobs == false and enabled(ns) == false, 'Save off must persist explicit false')
    assert(#applied == 2 and applied[2].enabled == false and applied[2].saved == false,
        'Save off must call ApplyAll after committing the setting')
    assert(ui.shown and not checked(ui), 'Save keeps setup open and paints saved off')
    click(choice(ui)); click(ui.save)
    assert(QuietUICharDB.questMobs == nil and enabled(ns) == true, 'Save on must omit the default')
    assert(#applied == 3 and applied[3].enabled == true and applied[3].saved == nil, 'Save on applies')
end)

case('Save with an active preset writes into the preset; switching picks up its value', function(ns)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questMobs = false })
    local on = ns.SavePreset(nil, 'On', ns.CurrentLayoutRef(), {})
    ns.ActivatePreset(off); ns.ShowSetup()
    local ui = QuietUISetup
    assert(not checked(ui), 'Selecting an off preset must paint unchecked')
    click(choice(ui)); click(ui.save)
    assert(ns.Presets()[off].settings.questMobs == nil and enabled(ns) == true, 'Save on must clear preset false')
    click(choice(ui)); click(ui.save)
    assert(ns.Presets()[off].settings.questMobs == false and enabled(ns) == false, 'Save off must update the preset')
    ns.ActivatePreset(on); ns.ShowSetup()
    assert(checked(ui) and enabled(ns) == true and QuietUICharDB.questMobs == nil, 'Switching to on preset reads on')
    ns.ActivatePreset(off); ns.ShowSetup()
    assert(not checked(ui) and enabled(ns) == false, 'Switching back reads the preset off value')
    ns.ActivatePreset(nil)
    assert(QuietUICharDB.questMobs == false and enabled(ns) == false, 'Detach keeps the last snapshot')
end)

case('Preset selector is a draft; saving the selection applies its questMobs', function(ns, applied)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questMobs = false })
    ns.ShowSetup()
    local ui = QuietUISetup
    choice(ui)
    click(ui.presetSelector); click(ui.presetMenu.items[2])
    assert(not checked(ui) and enabled(ns) == true, 'Preset draft must paint off without applying it')
    assert(QuietUICharDB.presetId == nil and #applied == 0, 'Preset choice must stay unsaved')
    ui:Hide(); ns.ShowSetup()
    assert(checked(ui), 'Closing discards the preset draft')
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    assert(QuietUICharDB.presetId == off and enabled(ns) == false, 'Saving the preset selection applies off')
    assert(#applied == 1 and applied[1].enabled == false, 'Preset Save applies the committed state')
end)

case('Reset turns Quest mobs on, saves, and leaves the shared preset unchanged', function(ns, applied)
    local off = ns.SavePreset(nil, 'Off', ns.CurrentLayoutRef(), { questMobs = false })
    ns.ActivatePreset(off); ns.ShowSetup()
    local ui = QuietUISetup
    assert(not checked(ui), 'Preset off must paint')
    click(ui.reset)
    assert(QuietUICharDB.presetId == nil and QuietUICharDB.questMobs == nil and enabled(ns) == true,
        'Reset must detach and save default on')
    assert(checked(ui) and ui.shown, 'Reset paints on and leaves setup open')
    assert(ns.Presets()[off].settings.questMobs == false, 'Reset must not mutate the shared preset')
    assert(#applied == 1 and applied[1].enabled == true, 'Reset applies immediately')
end)

for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
print(string.format('%d quest mobs settings cases, %d failures', cases, #failures))
assert(#failures == 0, 'Quest mobs settings contracts failed')
