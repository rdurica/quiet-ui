-- Helper for the Setup window/prompt appearance tests, loaded with h.lib("setupmodel").
-- A small frame model that tracks levels, strata, textures and backdrops, because the mock
-- frames do not model stacking. Structural contracts only; real clipping needs /reload in WoW.
local function same(color, r, g, b, a)
    return color and color[1] == r and color[2] == g and color[3] == b
        and (a == nil or color[4] == a)
end

local function scenario(t, mode)
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
    function methods:IsForbidden() return self.forbidden == true end
    function methods:GetChildren()
        assert(not self.forbidden, 'forbidden GetChildren')
        local children = {}
        for _, child in ipairs(self.children) do
            if child.kind ~= 'Texture' and child.kind ~= 'FontString' then children[#children + 1] = child end
        end
        return table.unpack(children)
    end
    function methods:GetFrameLevel()
        assert(not self.forbidden, 'forbidden GetFrameLevel')
        return self.level
    end
    function methods:SetFrameStrata(strata) self.strata = strata end
    function methods:GetFrameStrata()
        assert(not self.forbidden, 'forbidden GetFrameStrata')
        return self.strata or (self.parent and self.parent:GetFrameStrata())
    end
    -- Sibling-only Raise is deliberately insufficient for descendant content.
    -- This is a structural regression model, not proof of the client's renderer.
    function methods:Raise()
        if mode.raiseFails then error('Raise unavailable') end
        local maximum = self.level
        for _, object in ipairs(objects) do
            if not object.forbidden and object.parent == self.parent and object:GetFrameStrata() == self:GetFrameStrata() then
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
    function methods:SetFontString(font) self.font = font end
    for _, part in ipairs({ 'Normal', 'Disabled' }) do
        local field = part:lower() .. 'Font'
        methods['Set' .. part .. 'FontObject'] = function(self, font) self[field] = font end
        methods['Get' .. part .. 'FontObject'] = function(self) return self[field] end
    end
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
    for _, part in ipairs({ 'Normal', 'Highlight', 'Pushed', 'Disabled' }) do
        local field = part:lower() .. 'Texture'
        methods['Set' .. part .. 'Texture'] = function(self, texture) self[field] = texture end
        methods['Get' .. part .. 'Texture'] = function(self) return type(self[field]) == 'table' and self[field] or nil end
    end
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
        if template == 'UIPanelButtonTemplate' and mode.nativeButtons == false then error('template unavailable') end
        local object = make(kind, parent, name)
        object.template = template
        if mode.noRaise then object.Raise = false end
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
        if template == 'UIPanelButtonTemplate' then
            object.nativeNormal = object:CreateTexture(nil, 'ARTWORK')
            object.nativeNormal.texture = 'native-panel-normal'
            object.normalTexture = object.nativeNormal
            object.normalFont = 'GameFontNormal'
            object.disabledFont = 'GameFontDisable'
        end
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
    local ns = t.ns
    ns.Report = function(name, err) error(name .. ': ' .. tostring(err)) end
    ns.Print = function() end
    ns.ApplyAll = function() end
    ns.Settings.BarGroup = function() return 1 end
    ns.Settings.BarTarget = function() return false end
    ns.Glance.Active = function() return false end
    ns.Layout.STRING = 'export'
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
local function nativeAction(button)
    return button.template == 'UIPanelButtonTemplate' and button.normalTexture == button.nativeNormal
        and button.nativeNormal and button.nativeNormal.shown
end
local function goldSmall(button)
    if button.backdrop and button.backdrop.edgeFile and button.backdrop.edgeFile:find('Gold') then return true end
    local color = button.borderColor
    if color and color[1] > color[2] and color[2] > color[3] then return true end
    for _, texture in ipairs(button.textures) do
        local c = texture.color
        if texture.shown and texture.layer == 'BORDER' and c and c[1] > c[2] and c[2] > c[3] then return true end
    end
    return false
end
local function tint(button)
    local label = button.label or button.font
    local color = label and label.textColor
    local nativeFont = button.disabled and button:GetDisabledFontObject() or button:GetNormalFontObject()
    return button.alpha, label and label.alpha, color and table.concat(color, ','), nativeFont
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
    { name = 'native buttons unavailable', portrait = true, backdrop = true, nativeButtons = false },
    { name = 'Raise missing', portrait = true, backdrop = true, noRaise = true },
    { name = 'Raise failing', portrait = true, backdrop = true, raiseFails = true },
}
return { same = same, scenario = scenario, opaque = opaque, darkControl = darkControl,
    nativeAction = nativeAction, goldSmall = goldSmall, tint = tint, fillBounds = fillBounds,
    click = click, modes = modes }
