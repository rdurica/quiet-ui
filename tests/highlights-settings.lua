-- Highlights settings contracts (Misc. tab, draft, Save, Reset, presets); visuals still need /reload.
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
        applied[#applied + 1] = { highlights = type(ns.Highlights) == 'function' and ns.Highlights() or nil,
            saved = ns.Copy(QuietUICharDB.highlights) }
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
    assert(button and type(button.scripts.OnClick) == 'function', 'Required Highlights control is missing')
    button.scripts.OnClick(button)
end
local function highlights(ns)
    assert(type(ns.Highlights) == 'function', 'ns.Highlights public setting accessor is missing')
    local value = ns.Highlights()
    assert(type(value) == 'table', 'ns.Highlights must return a table')
    return value
end
local function expect(ns, herb, ore, quest, message)
    local value = highlights(ns)
    assert(value.herb == herb and value.ore == ore and value.quest == quest,
        string.format('%s (got herb=%s ore=%s quest=%s)', message,
            tostring(value.herb), tostring(value.ore), tostring(value.quest)))
end
local KEYS = { herb = 'highlightHerb', ore = 'highlightOre', quest = 'highlightQuest' }
local LABELS = { herb = 'Herbs', ore = 'Ore', quest = 'Quest objects' }
local function choice(ui, key)
    local widget = ui[KEYS[key]]
    assert(widget and widget.box and widget.label, 'Misc. ' .. LABELS[key] .. ' choice is missing')
    return widget
end
local function checked(ui, key) return choice(ui, key).box.checked == true end
local function stored(value, expected, message)
    if expected == nil then assert(value == nil, message .. ' (expected nil key)') return end
    assert(type(value) == 'table', message .. ' (expected a table)')
    for key, flag in pairs(value) do
        assert(flag == true and expected[key] == true, message .. ' (unexpected key ' .. tostring(key) .. ')')
    end
    for key in pairs(expected) do assert(value[key] == true, message .. ' (missing ' .. key .. ')') end
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
local function header(ui)
    local page = ui.pages[6]
    for _, child in ipairs(page.children) do
        if child.label and child.label.text == 'Highlights' and child.kind == 'Frame' then return child end
    end
    error('Misc. has no Highlights section')
end

case('Clean profile reads all three categories off', function(ns)
    expect(ns, false, false, false, 'Missing highlights must mean all off')
    QuietUICharDB.highlights = {}
    expect(ns, false, false, false, 'Empty table must mean all off')
    QuietUICharDB.highlights = { ore = true }
    expect(ns, false, true, false, 'Only ore stored must read ore on')
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }
    expect(ns, true, true, true, 'All stored must read all on')
end)

case('Misc. shows Highlights below Quests with three unchecked choices on one row', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local page = ui.pages[6]
    assert(ui.tabs[6].label.text == 'Misc.' and #ui.tabs == 7, 'Misc. stays the sixth of seven tabs')
    local section = header(ui)
    local _, sectionY = offset(section, page)
    local _, sizeY = offset(ui.questNoticeSize, page)
    assert(-sectionY >= -sizeY + ui.questNoticeSize.height, 'Highlights must sit below the Quests controls')
    local previousX, rowY, previousWidth
    for _, key in ipairs({ 'herb', 'ore', 'quest' }) do
        local widget = choice(ui, key)
        assert(widget.parent == page, LABELS[key] .. ' belongs on Misc.')
        assert(widget.label.text == LABELS[key], 'Choice label must be ' .. LABELS[key])
        assert(not widget.box.checked, LABELS[key] .. ' must start unchecked')
        local x, y = offset(widget, page)
        assert(-y >= -sectionY + section.height, LABELS[key] .. ' sits under the Highlights heading')
        if rowY then
            assert(y == rowY, 'Highlights choices must share one row')
            assert(x >= previousX + previousWidth, 'Highlights choices must not overlap and go left to right')
        end
        previousX, rowY, previousWidth = x, y, widget.width
    end
end)

case('Highlights info text is English and explains Interact and soft targeting', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local section = header(ui)
    local all = tooltip(section.help) .. '\n' .. table.concat(texts(ui.pages[6]), '\n')
    assert(all:find('Interact With Target', 1, true), 'Info must name the Interact With Target binding')
    assert(all:find('Key Bindings', 1, true), 'Info must point to Key Bindings')
    assert(all:lower():find('soft target', 1, true), 'Info must mention soft targeting')
    assert(all:lower():find('glow', 1, true), 'Info must say the object glows')
    assert(all:lower():find('restore', 1, true), 'Info must say settings are restored when turned off')
end)

case('Misc. content fits and setup keeps one height on every tab', function(ns)
    ns.ShowSetup()
    local ui = QuietUISetup
    local page = ui.pages[6]
    for _, key in ipairs({ 'herb', 'ore', 'quest' }) do
        local widget = choice(ui, key)
        local _, y = offset(widget, page)
        assert(-y + widget.height <= page.height, LABELS[key] .. ' must fit inside the Misc. tab height')
    end
    local height = ui.height
    local tallest = 0
    for _, other in ipairs(ui.pages) do if other.height > tallest then tallest = other.height end end
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        assert(ui.height == height, 'Tab switch must not resize setup')
        assert(ui.pages[index].shown, 'Selected tab must show its page')
    end
    assert(page.height <= tallest, 'Misc. may not exceed the tallest tab')
end)

case('Toggling is a draft, Save stores only true keys and applies', function(ns, applied)
    ns.ShowSetup()
    local ui = QuietUISetup
    click(choice(ui, 'ore'))
    assert(checked(ui, 'ore') and not checked(ui, 'herb') and not checked(ui, 'quest'), 'Click paints only Ore')
    assert(QuietUICharDB.highlights == nil and #applied == 0, 'Unsaved toggle must not store or apply')
    expect(ns, false, false, false, 'Unsaved toggle must not change live settings')
    click(ui.save)
    stored(QuietUICharDB.highlights, { ore = true }, 'Save must store only ore=true')
    expect(ns, false, true, false, 'Saved ore must read on')
    assert(#applied == 1 and applied[1].highlights and applied[1].highlights.ore == true,
        'Save must call ApplyAll after committing highlights')
    assert(ui.shown and checked(ui, 'ore'), 'Save keeps setup open and paints saved state')
    click(choice(ui, 'herb')); click(choice(ui, 'quest')); click(ui.save)
    stored(QuietUICharDB.highlights, { herb = true, ore = true, quest = true }, 'Save must store all three')
    expect(ns, true, true, true, 'All saved must read on')
    click(choice(ui, 'herb')); click(choice(ui, 'ore')); click(choice(ui, 'quest')); click(ui.save)
    assert(QuietUICharDB.highlights == nil, 'All off must clear the key instead of storing an empty table')
    expect(ns, false, false, false, 'All off must read off')
    assert(#applied == 3, 'Each Save applies')
end)

case('X and Escape discard unsaved highlight changes', function(ns, applied)
    QuietUICharDB.highlights = { herb = true }
    ns.ShowSetup()
    local ui = QuietUISetup
    assert(checked(ui, 'herb') and not checked(ui, 'ore'), 'Setup paints stored highlights')
    click(choice(ui, 'herb')); click(choice(ui, 'ore'))
    ui:Hide(); ns.ShowSetup()
    assert(checked(ui, 'herb') and not checked(ui, 'ore') and not checked(ui, 'quest'), 'Closing must discard drafts')
    stored(QuietUICharDB.highlights, { herb = true }, 'Closing must keep stored highlights')
    assert(#applied == 0, 'Closing must not apply')
    local escapeRegistered = false
    for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escapeRegistered = true end end
    assert(escapeRegistered, 'Escape must close the same setup frame and discard drafts')
end)

case('Reset default clears highlights and leaves the shared preset unchanged', function(ns, applied)
    local id = ns.SavePreset(nil, 'Gather', ns.CurrentLayoutRef(), { highlights = { ore = true, quest = true } })
    ns.ActivatePreset(id); ns.ShowSetup()
    local ui = QuietUISetup
    assert(checked(ui, 'ore') and checked(ui, 'quest'), 'Preset highlights must paint')
    click(ui.reset)
    assert(QuietUICharDB.presetId == nil and QuietUICharDB.highlights == nil, 'Reset must detach and clear highlights')
    expect(ns, false, false, false, 'Reset must turn every category off')
    assert(not checked(ui, 'herb') and not checked(ui, 'ore') and not checked(ui, 'quest'), 'Reset paints all off')
    stored(ns.Presets()[id].settings.highlights, { ore = true, quest = true }, 'Reset must not mutate shared preset')
    assert(#applied == 1, 'Reset applies immediately')
end)

case('Presets copy, share and snapshot highlights', function(ns)
    local copy = ns.CopySettings({ highlights = { herb = true }, unrelated = 1 })
    stored(copy.highlights, { herb = true }, 'CopySettings must copy highlights')
    local source = { highlights = { ore = true } }
    local deep = ns.CopySettings(source)
    deep.highlights.herb = true
    assert(source.highlights.herb == nil, 'CopySettings must deep-copy highlights')
    local target = { highlights = { quest = true } }
    ns.CopySettings({}, target)
    assert(target.highlights == nil, 'Omitted highlights must clear a stale value')
    local id = ns.SavePreset(nil, 'Herbs', ns.CurrentLayoutRef(), { highlights = { herb = true } })
    stored(ns.Presets()[id].settings.highlights, { herb = true }, 'Preset creation must keep highlights')
    ns.ActivatePreset(id)
    stored(ns.Settings().highlights, { herb = true }, 'Active preset settings must expose highlights')
    stored(QuietUICharDB.highlights, { herb = true }, 'Activation must snapshot highlights')
    expect(ns, true, false, false, 'Accessor reads effective preset settings')
    ns.Presets()[id].settings.highlights = { quest = true }
    QuietUICharDB.highlights = nil
    expect(ns, false, false, true, 'Accessor must read the active preset, not the snapshot')
    ns.ShowSetup()
    local ui = QuietUISetup
    click(choice(ui, 'ore')); click(ui.save)
    stored(ns.Presets()[id].settings.highlights, { ore = true, quest = true }, 'Save must update the active preset')
    ns.ActivatePreset(nil)
    stored(QuietUICharDB.highlights, { ore = true, quest = true }, 'Detach keeps the last snapshot')
    expect(ns, false, true, true, 'Detached accessor reads personal snapshot')
end)

for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
print(string.format('%d highlights settings cases, %d failures', cases, #failures))
assert(#failures == 0, 'Highlights settings contracts failed')
