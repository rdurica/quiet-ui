-- Structural contracts only; actual overlap/chrome clipping require /reload in WoW.
local failures, checks = {}, 0
local function check(value, message)
    checks = checks + 1
    if not value then failures[#failures + 1] = message end
end
local function same(color, r, g, b, a)
    return color and color[1] == r and color[2] == g and color[3] == b
        and (a == nil or color[4] == a)
end

local function scenario(mode)
    local objects, methods = {}, {}
    local make
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = function(...) if old then old(...) end; fn(...) end
    end
    function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
    function methods:ClearAllPoints() self.points = {} end
    function methods:SetAllPoints(target) self.allPoints = target or self.parent end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetFrameLevel(level)
        local delta = level - self.level
        self.level = level
        -- WoW moves descendants along with their parent's level.
        for _, child in ipairs(self.children) do
            if child.kind ~= 'Texture' and child.kind ~= 'FontString' then child:SetFrameLevel(child.level + delta) end
        end
    end
    function methods:GetFrameLevel() return self.level end
    function methods:SetFrameStrata(strata) self.strata = strata end
    function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) end
    function methods:Raise()
        local maximum = self.level
        for _, object in ipairs(objects) do
            if object.parent == self.parent and object:GetFrameStrata() == self:GetFrameStrata() then
                maximum = math.max(maximum, object.level)
            end
        end
        self:SetFrameLevel(maximum + 1)
        self.raises = (self.raises or 0) + 1
    end
    function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function methods:Hide()
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
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
    function methods:SetTextColor(...) self.textColor = {...} end
    function methods:SetColorTexture(...) self.color = {...} end
    function methods:SetVertexColor(...) self.vertexColor = {...} end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:GetAlpha() return self.alpha end
    function methods:SetTexture(texture) self.texture = texture; return true end
    function methods:GetTexture() return self.texture end
    function methods:SetAtlas(atlas) self.texture = atlas; return true end
    function methods:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
    function methods:SetChecked(value) self.checked = value end
    function methods:Enable() self.disabled = false end
    function methods:Disable() self.disabled = true end
    function methods:IsEnabled() return not self.disabled end
    function methods:SetEnabled(enabled) self.disabled = not enabled end
    function methods:EnableMouse(enabled) self.mouse = enabled end
    function methods:SetFocus() self.focus = true end
    function methods:ClearFocus() self.focus = false end
    function methods:HasFocus() return self.focus == true end
    function methods:SetVerticalScroll(value) self.scroll = value end
    function methods:GetVerticalScroll() return self.scroll or 0 end
    function methods:SetScrollChild(child) self.scrollChild = child end
    function methods:GetStringWidth() return #(self.text or '') * 6 end
    function methods:SetNormalTexture(texture) self.normalTexture = texture end
    function methods:SetHighlightTexture(texture) self.highlightTexture = texture end
    function methods:SetPushedTexture(texture) self.pushedTexture = texture end
    function methods:SetDisabledTexture(texture) self.disabledTexture = texture end
    function methods:GetNormalTexture() return type(self.normalTexture) == 'table' and self.normalTexture or nil end
    function methods:GetHighlightTexture() return type(self.highlightTexture) == 'table' and self.highlightTexture or nil end
    function methods:GetPushedTexture() return type(self.pushedTexture) == 'table' and self.pushedTexture or nil end
    function methods:GetDisabledTexture() return type(self.disabledTexture) == 'table' and self.disabledTexture or nil end
    -- Explicit non-observable layout/input methods; no catchall supplies absent APIs.
    for _, name in ipairs({ 'SetFontObject', 'SetJustifyH', 'SetJustifyV', 'SetAutoFocus', 'SetMaxLetters',
        'SetTextInsets', 'SetTexCoord', 'EnableMouseWheel', 'RegisterForClicks', 'RegisterForDrag',
        'HighlightText', 'SetMotionScriptsWhileDisabled' }) do methods[name] = function() end end
    make = function(kind, parent, name)
        local object = setmetatable({ kind = kind, parent = parent, name = name, scripts = {},
            children = {}, textures = {}, points = {}, shown = true, width = 100, height = 22,
            level = parent and parent.level + 1 or 0, alpha = 1, text = '' }, { __index = methods })
        if parent then parent.children[#parent.children + 1] = object end
        objects[#objects + 1] = object
        return object
    end
    function methods:CreateTexture(_, layer, _, sublevel)
        local texture = make('Texture', self)
        texture.layer, texture.sublevel = layer, sublevel
        self.textures[#self.textures + 1] = texture
        return texture
    end
    function methods:CreateFontString() return make('FontString', self) end
    UIParent = make('Frame')
    UIParent.strata = 'MEDIUM'
    QuietUISetup = nil; UISpecialFrames = {}; QuietUIDB = { enabled = false }; QuietUICharDB = { chatFade = 20 }
    Enum = nil; InputUtil = nil; EditModePresetLayoutManager = nil
    InCombatLockdown = function() return false end
    SetPortraitTexture = function(texture, unit) texture.texture = unit end
    CreateFrame = function(kind, name, parent, template)
        if template == 'PortraitFrameTemplate' and not mode.portrait then error('template unavailable') end
        local object = make(kind, parent, name)
        object.template = template
        if name then _G[name] = object end
        if mode.backdrop and template ~= 'PortraitFrameTemplate' then
            object.SetBackdrop = function(self, value) self.backdrop = value end
            object.SetBackdropColor = function(self, ...) self.backdropColor = {...} end
            object.SetBackdropBorderColor = function(self, ...) self.borderColor = {...} end
        end
        if template == 'PortraitFrameTemplate' then
            object.TitleText = object:CreateFontString()
            object.portrait = object:CreateTexture(nil, 'ARTWORK')
            object.CloseButton = make('Button', object)
            object.SetPortraitToUnit = function(self, unit) self.portrait.texture = unit end
            if mode.portraitBackdrop then
                object.SetBackdrop = function(self, value) self.backdrop = value end
                object.SetBackdropColor = function(self, ...) self.backdropColor = {...} end
                object.SetBackdropBorderColor = function(self, ...) self.borderColor = {...} end
            end
        elseif kind == 'Button' or kind == 'CheckButton' then object.font = object:CreateFontString() end
        return object
    end
    local layouts = { activeLayout = 3, layouts = { { layoutName = 'Original', layoutType = 1 } } }
    local writes = 0
    C_EditMode = {
        GetLayouts = function() return layouts end,
        ConvertStringToLayoutInfo = function() return {} end,
        SaveLayouts = function(value) writes = writes + 1; layouts = value end,
        SetActiveLayout = function(index) layouts.activeLayout = index end,
    }
    local ns = {}
    assert(loadfile('Core.lua'))('QuietUI', ns)
    ns.Report = function(name, err) error(name .. ': ' .. tostring(err)) end
    ns.Print = function() end
    ns.ApplyAll = function() end
    assert(loadfile('Presets.lua'))('QuietUI', ns)
    assert(loadfile('Bars.lua'))('QuietUI', ns)
    ns.BarGroup = function() return 1 end
    ns.BarTarget = function() return false end
    ns.Glancing = function() return false end
    ns.LAYOUT_STRING = 'export'
    assert(loadfile('Layout.lua'))('QuietUI', ns)
    assert(loadfile('Setup.lua'))('QuietUI', ns)
    return ns, objects, function() return writes, layouts end
end

local function opaque(frame)
    for _, texture in ipairs(frame.textures) do
        if texture.shown and same(texture.color, 0.05, 0.05, 0.05, 1)
            and texture.alpha == 1 and (texture.allPoints or #texture.points >= 2)
            and (texture.layer == 'BACKGROUND' or texture.layer == 'BORDER') then return texture end
    end
end
local function darkControl(button)
    if button.backdropColor and button.backdropColor[1] <= 0.15 and button.borderColor then return true end
    for _, texture in ipairs(button.textures) do
        if texture.shown and texture.color and texture.color[1] <= 0.15
            and texture.layer ~= 'HIGHLIGHT' then return true end
    end
    return false
end
local function tint(button)
    local label = button.label or button.font
    local color = label and label.textColor
    return button.alpha, label and label.alpha, color and table.concat(color, ',')
end
local function fillBounds(frame, fill)
    if not fill then return false end
    if fill.allPoints == frame and fill.layer == 'BACKGROUND' then return true end
    local left, top, right, bottom
    for _, point in ipairs(fill.points) do
        local anchor = point[1]
        local x, y = point[#point - 1], point[#point]
        if anchor == 'TOPLEFT' then left, top = x, y end
        if anchor == 'BOTTOMRIGHT' then right, bottom = x, y end
    end
    return type(left) == 'number' and type(top) == 'number' and type(right) == 'number'
        and type(bottom) == 'number' and left >= 0 and right <= 0 and top <= 0 and bottom >= 0
        and left < frame.width / 2 and -right < frame.width / 2
        and -top + bottom < frame.height
end
local function click(button) assert(button.scripts.OnClick, 'Missing click handler'); button.scripts.OnClick(button) end
local modes = {
    { name = 'portrait without backdrop', portrait = true, backdrop = true },
    { name = 'portrait with backdrop', portrait = true, backdrop = true, portraitBackdrop = true },
    { name = 'gold fallback', backdrop = true },
    { name = 'flat without backdrop' },
}
for _, mode in ipairs(modes) do
    local ns, objects, layoutState = scenario(mode)
    local function expect(value, message) check(value, mode.name .. ': ' .. message) end
    local other = CreateFrame('Frame', nil, UIParent)
    other:SetFrameStrata('DIALOG'); other:SetFrameLevel(500)
    local otherLevel, otherAlpha = other.level, other.alpha
    ns.ShowSetup()
    local ui = QuietUISetup
    expect(opaque(ui), 'setup has its own opaque dark background independent of SetBackdrop')
    expect(fillBounds(ui, opaque(ui)), 'setup fill stays behind chrome and within window bounds')
    expect(ui:GetFrameStrata() == 'DIALOG' and ui.level > other.level, 'setup opening raises over sibling DIALOG')
    expect(other.level == otherLevel and other.alpha == otherAlpha and other.shown, 'foreign dialog state is preserved')
    expect(QuietUIDB.enabled == false, 'setup opening preserves disabled addon')
    if mode.portrait then
        expect(ui.portrait.texture == 'player' and ui.portrait.shown and ui.TitleText.text == 'QuietUI'
            and ui.CloseButton.shown, 'portrait title and close chrome are preserved')
    elseif mode.backdrop then
        expect(ui.backdrop and ui.backdrop.edgeFile:find('Gold'), 'gold fallback keeps gold frame')
    else expect(ui.title and ui.close, 'flat fallback keeps title and usable close') end
    local height, width = ui.height, ui.width
    local labels = { 'General', 'Visible', 'Bars', 'Groups', 'Player', 'Chat', 'Info' }
    expect(#ui.tabs == 7, 'seven tabs retained')
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        expect(tab.label.text == labels[index], 'tab order ' .. index)
        expect(same(tab.label.textColor, 0.95, 0.75, 0.25), 'active tab uses gold accent without hover: ' .. labels[index])
        expect(ui.height == height and ui.width == width, 'switching tabs keeps window geometry')
        local pageTop = ui.pages[index].points[1][3]
        local footerTop = height - ui.save.points[1][3] - ui.save.height
        expect(-pageTop + ui.pages[index].height <= footerTop, 'page body does not overlap footer: ' .. labels[index])
        for otherIndex, otherTab in ipairs(ui.tabs) do
            if otherIndex ~= index then
                expect(not same(otherTab.label.textColor, 0.95, 0.75, 0.25), 'inactive tabs differ from selected gold tab')
            end
        end
        for pageIndex, page in ipairs(ui.pages) do expect(page.shown == (pageIndex == index), 'only selected page is shown') end
    end
    click(ui.tabs[1])
    expect(ui.presetSelector.width == ui.pages[1].width and ui.layoutSelector.width == ui.pages[1].width,
        'General selectors span content width')
    for _, button in ipairs({ ui.presetSelector, ui.layoutSelector, ui.newPreset, ui.renamePreset,
        ui.deletePreset, ui.reset, ui.import, ui.save, ui.tabs[1], ui.groupRows[1].plus }) do
        expect(darkControl(button), 'consistent dark control styling: ' .. (button.text ~= '' and button.text or button.label.text))
    end
    expect(ui.renamePreset.disabled and ui.deletePreset.disabled, 'unavailable preset actions remain disabled')
    local disabledAlpha, disabledLabelAlpha, disabledColor = tint(ui.renamePreset)
    expect(ui.newPreset.width == ui.renamePreset.width and ui.renamePreset.width == ui.deletePreset.width,
        'preset actions have uniform width')
    expect(ui.newPreset.width >= #'New preset' * 6, 'preset action label fits')
    local left = ui.newPreset.points[1][4]
    local middle = ui.renamePreset.points[1][4]
    local right = ui.pages[1].width + ui.deletePreset.points[1][4] - ui.deletePreset.width
    expect(middle - left - ui.newPreset.width == right - middle - ui.renamePreset.width,
        'General preset action gaps are equal')
    click(ui.presetSelector)
    expect(opaque(ui.presetMenu), 'preset menu has independent opaque fill')
    expect(ui.presetMenu.level > ui.save.level and ui.presetMenu.items[1].level > ui.presetMenu.level,
        'preset menu and entries are above main controls')
    click(ui.presetSelector); expect(not ui.presetMenu.shown, 'selector toggles menu closed')
    click(ui.newPreset)
    local dialog = ui.presetDialog
    expect(opaque(dialog), 'preset dialog has independent opaque fill')
    expect(fillBounds(dialog, opaque(dialog)), 'preset dialog fill stays behind chrome and inside bounds')
    expect(dialog.level > dialog.blocker.level and dialog.blocker.level > ui.save.level
        and dialog.yes.level > dialog.level and dialog.no.level > dialog.level,
        'modal controls and mouse blocker stay above main content')
    expect(dialog.blocker.mouse and dialog.blocker.allPoints == ui and dialog.blocker.shown,
        'modal blocker covers setup and intercepts mouse')
    expect(darkControl(dialog.yes) and darkControl(dialog.no), 'modal buttons use shared dark styling')
    dialog.edit:SetText('Appearance'); click(dialog.yes); click(ui.save)
    expect(ui.shown and QuietUICharDB.presetId and QuietUIDB.enabled == false, 'Save commits preset and keeps disabled setup open')
    local enabledAlpha, enabledLabelAlpha, enabledColor = tint(ui.renamePreset)
    expect(disabledAlpha ~= enabledAlpha or disabledLabelAlpha ~= enabledLabelAlpha or disabledColor ~= enabledColor,
        'disabled actions are visibly distinguished from enabled actions')
    click(ui.layoutSelector)
    expect(opaque(ui.layoutMenu), 'layout menu has independent opaque fill')
    expect(ui.layoutMenu.level > ui.save.level and ui.layoutMenu.items[1].level > ui.layoutMenu.level,
        'layout menu entries stay above owner')
    click(ui.layoutMenu.items[#ui.layoutMenu.items])
    expect(not ui.layoutMenu.shown, 'layout selection closes menu')
    ui:Hide(); other:SetFrameLevel(ui.level + 200); ns.ShowSetup()
    expect(ui.level > other.level, 'reopening raises over later sibling dialogs')
    click(ui.presetSelector)
    expect(ui.presetMenu.level > ui.save.level, 'reused preset menu stays above raised owner')
    click(ui.renamePreset)
    expect(dialog.level > dialog.blocker.level and dialog.blocker.level > ui.save.level
        and dialog.yes.level > dialog.level, 'reused modal stays above raised owner')
    dialog.edit:SetText('Renamed'); click(dialog.yes); click(ui.save)
    expect(ns.ActivePreset().name == 'Renamed', 'renaming still saves through draft')
    click(ui.deletePreset); click(dialog.no)
    expect(ns.ActivePreset() ~= nil, 'cancel deletion preserves preset')
    click(ui.deletePreset); click(dialog.yes)
    expect(not ns.ActivePreset(), 'confirmed deletion remains immediate')
    ui.chat.scripts.OnClick(); ui:Hide(); ns.ShowSetup()
    expect(QuietUICharDB.chat == nil, 'closing discards changed draft')
    local escape = false
    for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escape = true end end
    expect(escape, 'Escape retains named-frame closing registration')
    click(ui.reset)
    expect(ui.shown and QuietUICharDB.chat == nil and QuietUICharDB.chatFade == nil,
        'Reset saves defaults and leaves setup open')
    -- Prompt must not mutate layouts/hash simply by appearing or hiding.
    ns.EnsureLayout()
    local prompt
    for _, object in ipairs(objects) do
        if object.parent == UIParent and object.yes and object.no then prompt = object end
    end
    assert(prompt, 'layout prompt fixture did not open')
    local writes = layoutState()
    expect(writes == 0 and QuietUIDB.layoutHash == nil, 'opening layout prompt does not imply consent')
    expect(opaque(prompt), 'layout prompt has independent opaque fill')
    expect(fillBounds(prompt, opaque(prompt)), 'prompt fill stays behind gear/chrome and inside bounds')
    expect(prompt:GetFrameStrata() == 'DIALOG' and prompt.level > other.level, 'layout prompt raises above ordinary sibling dialog')
    expect(prompt.yes.level > prompt.level and prompt.no.level > prompt.level, 'prompt controls are above its fill')
    expect(darkControl(prompt.yes) and darkControl(prompt.no), 'layout prompt buttons share dark styling')
    if mode.portrait then
        expect(prompt.portrait.shown and prompt.portrait.texture ~= nil and prompt.portrait.texture ~= 'player'
            and not prompt.CloseButton.shown, 'gear chrome preserved and unanswered close hidden')
    elseif mode.backdrop then expect(prompt.backdrop and prompt.backdrop.edgeFile:find('Gold'), 'layout prompt keeps gold fallback') end
    prompt:Hide()
    expect(QuietUIDB.layoutHash == nil and layoutState() == writes, 'hiding prompt records no answer')
    prompt:Show(); click(prompt.no)
    expect(QuietUIDB.layoutHash ~= nil and layoutState() == writes, 'Not now records consent answer without writing layout')
    click(ui.import)
    expect(layoutState() == writes + 1, 'Import layout writes immediately after Not now')
    expect(QuietUIDB.enabled == false, 'dialogs and import preserve disabled addon')
    -- Exercise Add and Update in isolated sessions as the prompt is once per session.
    for _, update in ipairs({ false, true }) do
        local addNs, addObjects, addState = scenario(mode)
        local _, info = addState()
        if update then info.layouts[2] = { layoutName = 'QuietUI', layoutType = 1 } end
        addNs.EnsureLayout()
        local addPrompt
        for _, object in ipairs(addObjects) do if object.yes and object.no then addPrompt = object end end
        assert(addPrompt, 'Add/Update prompt fixture did not open')
        local label = addPrompt.yes.label and addPrompt.yes.label.text or addPrompt.yes.text
        expect(label == (update and 'Update' or 'Add'), 'correct consent action label')
        click(addPrompt.yes)
        expect(addState() == 1 and QuietUIDB.layoutHash ~= nil, 'Add/Update writes and records answer once')
    end
end
for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
print(string.format('%d appearance checks, %d failures', checks, #failures))
assert(#failures == 0, 'Setup appearance contracts failed')
