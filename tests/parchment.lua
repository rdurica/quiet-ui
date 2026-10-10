-- Run from the addon directory: lua tests/parchment.lua
-- Parchment.lua in isolation: the quest, gossip and item text windows reskinned as clean
-- parchment with flat buttons. Only textures, button points and the addon's own layer change.
local failures, cases = 0, 0
local out = print
local unpack = table.unpack

-- Per-test world state, rebuilt by Boot().
local W

local function noop() end

-- Method-like keys a stub does not define read as a no-op; element fields read as nil.
local VERB = { 'Set', 'Get', 'Is', 'Has', 'Can', 'Enable', 'Register', 'Unregister', 'Clear', 'Raise', 'Lower', 'Lock', 'Unlock' }
local function catchAll(_, k)
    if type(k) ~= 'string' then return nil end
    for _, v in ipairs(VERB) do
        if k:sub(1, #v) == v and k:sub(#v + 1, #v + 1):match('%u') then return noop end
    end
    return nil
end

-- Calls that windows may only see from Blizzard code, never from the reskin.
local WINDOW_GUARD = { Hide = true, SetSize = true, SetWidth = true, SetHeight = true, SetPoint = true,
    ClearAllPoints = true, SetAllPoints = true, SetScale = true }
-- Writes the reskin must never make to a Blizzard FontString.
local FONT_WRITES = { SetText = true, SetFormattedText = true, SetFont = true, SetFontObject = true,
    SetTextColor = true, SetShadowColor = true }
-- The only FontString writes allowed, and only on the window title (TitleContainer.TitleText).
local TITLE_WRITES = { SetTextColor = true, SetFont = true }
-- Writes the reskin must never make to a Blizzard button's text.
local BUTTON_TEXT_WRITES = { SetText = true, SetFormattedText = true, SetNormalFontObject = true,
    SetHighlightFontObject = true, SetDisabledFontObject = true }

local function violation(msg) W.violations[#W.violations + 1] = msg end

local function label(o) return o and (o.name or o.kind or '?') or 'nil' end

local function normalizePoint(self, point, a, b, c, d)
    local rel, relPoint, x, y
    if a == nil then
        rel, relPoint, x, y = self.parent, point, 0, 0
    elseif type(a) == 'number' then
        rel, relPoint, x, y = self.parent, point, a, b or 0
    else
        rel = a
        if type(rel) == 'string' then rel = _G[rel] end
        if type(b) == 'number' then
            relPoint, x, y = point, b, c or 0
        else
            relPoint, x, y = b or point, c or 0, d or 0
        end
    end
    return { point, rel, relPoint, x, y }
end

-- One stub for frames, buttons, textures and font strings.
local function newObject(kind, parent, name)
    local o = { kind = kind, parent = parent, name = name, shown = true, alpha = 1, points = {},
        width = 10, height = 10, scripts = {}, hooks = {}, regions = {}, children = {},
        created = not W.fixture, enabled = true }
    function o:GetObjectType() return self.kind end
    function o:IsObjectType(t) return self.kind == t or (t == 'Frame' and (self.kind == 'Button')) end
    function o:IsForbidden() return false end
    function o:GetName() return self.name end
    function o:GetParent() return self.parent end
    function o:IsShown() return self.shown end
    function o:IsVisible()
        local x = self
        while x do
            if not x.shown then return false end
            x = x.parent
        end
        return true
    end
    function o:Show()
        if self.window and not W.blizzard then violation(label(self) .. ':Show') end
        local was = self.shown
        self.shown = true
        if not was then W.Fire(self, 'OnShow') end
    end
    function o:Hide()
        if self.window and not W.blizzard then violation(label(self) .. ':Hide') end
        local was = self.shown
        self.shown = false
        if was then W.Fire(self, 'OnHide') end
    end
    function o:SetShown(v) if v then self:Show() else self:Hide() end end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha = a end
    function o:GetEffectiveAlpha()
        local a, x = 1, self
        while x do a = a * x.alpha; x = x.parent end
        return a
    end
    function o:ClearAllPoints() self.points = {} end
    function o:SetPoint(...) self.points[#self.points + 1] = normalizePoint(self, ...) end
    function o:SetAllPoints(rel)
        rel = rel or self.parent
        if type(rel) == 'string' then rel = _G[rel] end
        self.points = { { 'TOPLEFT', rel, 'TOPLEFT', 0, 0 }, { 'BOTTOMRIGHT', rel, 'BOTTOMRIGHT', 0, 0 } }
    end
    function o:GetNumPoints() return #self.points end
    function o:GetPoint(i)
        local p = self.points[i or 1]
        if p then return unpack(p, 1, 5) end
    end
    function o:SetSize(w, h) self.width = w; self.height = h or w end
    function o:SetWidth(w) self.width = w end
    function o:SetHeight(h) self.height = h end
    function o:GetSize() return self.width, self.height end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:SetScale(s) self.scale = s end
    function o:GetScale() return self.scale or 1 end
    function o:GetFrameLevel() return self.level or 1 end
    function o:SetFrameLevel(l) self.level = l end
    function o:GetFrameStrata() return 'MEDIUM' end
    function o:SetScript(script, fn)
        if script == 'OnClick' and not W.fixture and not W.blizzard then violation(label(self) .. ':SetScript OnClick') end
        self.scripts[script] = fn
    end
    function o:GetScript(script) return self.scripts[script] end
    function o:HasScript() return true end
    function o:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function o:GetRegions() return unpack(self.regions) end
    function o:GetNumRegions() return #self.regions end
    function o:GetChildren() return unpack(self.children) end
    function o:GetNumChildren() return #self.children end
    function o:EnableMouse(v) self.mouse = v end
    function o:IsMouseOver() return self.mouseOver == true end
    function o:CreateTexture(texName, layer, _, sub)
        local t = W.New('Texture', self, texName)
        t.layer = layer or 'ARTWORK'
        t.sublevel = sub
        return t
    end
    function o:CreateFontString(fsName, layer)
        local f = W.New('FontString', self, fsName)
        f.layer = layer or 'OVERLAY'
        return f
    end
    function o:CreateMaskTexture(n, layer) return self:CreateTexture(n, layer) end
    function o:CreateLine(n, layer) return self:CreateTexture(n, layer) end
    function o:CreateAnimationGroup()
        return setmetatable({}, { __index = function() return noop end })
    end
    if kind == 'Texture' then
        o.layer = 'ARTWORK'
        function o:SetTexture(path) self.texture = path; self.colorTex = nil end
        function o:GetTexture() return self.texture end
        function o:SetAtlas(atlas) self.atlas = atlas end
        function o:GetAtlas() return self.atlas end
        function o:SetColorTexture(r, g, b, a) self.colorTex = { r, g, b, a or 1 }; self.texture = nil end
        function o:SetVertexColor(r, g, b, a) self.vcolor = { r, g, b, a or 1 } end
        function o:GetVertexColor()
            local c = self.vcolor or { 1, 1, 1, 1 }
            return c[1], c[2], c[3], c[4]
        end
        function o:SetDrawLayer(layer, sub) self.layer = layer; self.sublevel = sub end
        function o:GetDrawLayer() return self.layer, self.sublevel end
        function o:SetTexCoord() end
        function o:SetBlendMode() end
    elseif kind == 'FontString' then
        o.layer = 'OVERLAY'
        o.text = ''
        o.font = { 'Fonts\\FRIZQT__.TTF', 12, '' }
        o.color = { 1, 1, 1, 1 }
        local function write(method)
            return function(self, a, b, c, d)
                -- The window title may only get its ink colour and a larger size of the same face.
                local titleWrite = self.title and TITLE_WRITES[method]
                if not self.created and not W.fixture and not titleWrite then violation(label(self) .. ':' .. method) end
                if method == 'SetText' then self.text = a end
                if method == 'SetFont' then self.font = { a, b, c } end
                if method == 'SetTextColor' then self.color = { a, b, c, d or 1 } end
            end
        end
        for method in pairs(FONT_WRITES) do o[method] = write(method) end
        function o:GetText() return self.text end
        function o:GetFont() return self.font[1], self.font[2], self.font[3] end
        function o:GetTextColor() return self.color[1], self.color[2], self.color[3], self.color[4] end
        function o:SetDrawLayer(layer) self.layer = layer end
        function o:GetDrawLayer() return self.layer end
        function o:GetStringWidth() return 40 end
    end
    if kind == 'Button' then
        function o:IsEnabled() return self.enabled end
        function o:Enable()
            if self.enabled then return end
            self.enabled = true
            W.Fire(self, 'OnEnable')
        end
        function o:Disable()
            if not self.enabled then return end
            self.enabled = false
            W.Fire(self, 'OnDisable')
        end
        function o:SetEnabled(v) if v then self:Enable() else self:Disable() end end
        function o:GetNormalTexture() return self.normal end
        function o:GetPushedTexture() return self.pushed end
        function o:GetHighlightTexture() return self.highlight end
        function o:GetDisabledTexture() return self.disabled end
        function o:SetNormalTexture(t) self.normal = type(t) == 'table' and t or nil end
        function o:SetPushedTexture(t) self.pushed = type(t) == 'table' and t or nil end
        function o:SetHighlightTexture(t) self.highlight = type(t) == 'table' and t or nil end
        function o:SetDisabledTexture(t) self.disabled = type(t) == 'table' and t or nil end
        function o:GetFontString() return self.Text end
        function o:GetText() return self.Text and self.Text.text end
        for method in pairs(BUTTON_TEXT_WRITES) do
            o[method] = function(self)
                if not W.fixture and not W.blizzard then violation(label(self) .. ':' .. method) end
            end
        end
        function o:Click() W.Fire(self, 'OnClick') end
    end
    setmetatable(o, { __index = catchAll })
    if parent then
        if kind == 'Texture' or kind == 'FontString' then
            parent.regions[#parent.regions + 1] = o
        else
            parent.children[#parent.children + 1] = o
        end
    end
    W.objects[#W.objects + 1] = o
    if o.created then W.created[#W.created + 1] = o end
    if name then _G[name] = o end
    return o
end

-- Window guard: wraps the size and position setters with a check for Blizzard context.
local function guardWindow(f)
    f.window = true
    for method in pairs(WINDOW_GUARD) do
        local orig = f[method]
        if method ~= 'Hide' and orig then
            f[method] = function(self, ...)
                if not W.blizzard and not W.fixture then violation(label(self) .. ':' .. method) end
                return orig(self, ...)
            end
        end
    end
end

local function hooksecurefuncStub(a, b, c)
    local obj, method, fn
    if type(a) == 'string' then obj, method, fn = _G, a, b else obj, method, fn = a, b, c end
    local orig = obj[method]
    assert(type(orig) == 'function', 'hooksecurefunc on a missing method ' .. tostring(method))
    rawset(obj, method, function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end)
end

-- Fixtures ----------------------------------------------------------------------------------

local function tex(parent, name, layer, alpha)
    local t = W.New('Texture', parent, name)
    t.layer = layer or 'ARTWORK'
    t.alpha = alpha or 1
    t.texture = 'Interface\\Blizzard\\' .. (name or 'Texture')
    return t
end

local function fontString(parent, text, name)
    local f = W.New('FontString', parent, name)
    f.text = text
    return f
end

local function clickScript() end

-- A Blizzard UIPanelButton (Left/Middle/Right) or arrow button (Normal/Pushed/Disabled only).
local function button(parent, name, anchor, opts)
    opts = opts or {}
    local b = W.New('Button', parent, name)
    b:SetSize(opts.w or 120, opts.h or 22)
    b:SetPoint(unpack(anchor))
    b.onClick = function() end
    b.scripts.OnClick = b.onClick
    if not opts.arrow and not opts.noLMR then
        b.Left = tex(b, nil, 'BACKGROUND'); b.Left.name = (name or 'button') .. '.Left'
        b.Middle = tex(b, nil, 'BACKGROUND', 0.8); b.Middle.name = (name or 'button') .. '.Middle'
        b.Right = tex(b, nil, 'BACKGROUND'); b.Right.name = (name or 'button') .. '.Right'
    end
    if not opts.noNormal then
        b.normal = tex(b, nil, 'ARTWORK'); b.normal.name = (name or 'button') .. '.Normal'
    end
    b.pushed = tex(b, nil, 'ARTWORK'); b.pushed.name = (name or 'button') .. '.Pushed'
    b.highlight = tex(b, nil, 'HIGHLIGHT'); b.highlight.name = (name or 'button') .. '.Highlight'
    b.disabled = tex(b, nil, 'ARTWORK'); b.disabled.name = (name or 'button') .. '.Disabled'
    if not opts.arrow then
        b.Text = fontString(b, opts.text or name, (name or 'button') .. 'Text')
    end
    return b
end

local function scrollBar(parent, name, opts)
    opts = opts or {}
    local bar = W.New('Frame', parent, name)
    bar.Background = tex(bar, nil, 'BACKGROUND'); bar.Background.name = label(bar) .. '.Background'
    if not opts.noTrack then
        local track = W.New('Frame', bar)
        track.name = label(bar) .. '.Track'
        bar.Track = track
        track.Begin = tex(track, nil, 'ARTWORK'); track.Begin.name = track.name .. '.Begin'
        track.Middle = tex(track, nil, 'ARTWORK'); track.Middle.name = track.name .. '.Middle'
        track.End = tex(track, nil, 'ARTWORK'); track.End.name = track.name .. '.End'
        local thumb = W.New('Button', track)
        thumb.name = label(bar) .. '.Thumb'
        track.Thumb = thumb
        thumb.Begin = tex(thumb, nil, 'ARTWORK'); thumb.Begin.name = thumb.name .. '.Begin'
        thumb.Middle = tex(thumb, nil, 'ARTWORK'); thumb.Middle.name = thumb.name .. '.Middle'
        thumb.End = tex(thumb, nil, 'ARTWORK'); thumb.End.name = thumb.name .. '.End'
    end
    return bar
end

-- A PortraitFrameTemplate-like window with NineSlice, Bg, portrait, title and close button.
local function window(name, opts)
    opts = opts or {}
    local f = W.New('Frame', UIParent, name)
    guardWindow(f)
    f:SetSize(384, 512)
    f:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 16, -116)
    f.chrome = {}
    f.blizzardShows = 0
    f.scripts.OnShow = function(self) self.blizzardShows = self.blizzardShows + 1 end
    if not opts.noBg then
        f.Bg = tex(f, name .. 'Bg', 'BACKGROUND')
        table.insert(f.chrome, f.Bg)
    end
    if not opts.noNineSlice then
        local ns9 = W.New('Frame', f)
        ns9.name = name .. '.NineSlice'
        f.NineSlice = ns9
        for _, piece in ipairs({ 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner',
            'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'Center' }) do
            local t = tex(ns9, nil, 'BORDER', piece == 'Center' and 0.5 or 1)
            t.name = name .. '.NineSlice.' .. piece
            ns9[piece] = t
            table.insert(f.chrome, t)
        end
    end
    if not opts.noPortrait then
        local pc = W.New('Frame', f)
        pc.name = name .. '.PortraitContainer'
        f.PortraitContainer = pc
        pc.portrait = tex(pc, nil, 'OVERLAY')
        pc.portrait.name = name .. '.portrait'
        table.insert(f.chrome, pc.portrait)
    end
    local title = W.New('Frame', f)
    title.name = name .. '.TitleContainer'
    f.TitleContainer = title
    title.TitleText = fontString(title, name .. ' title', name .. 'TitleText')
    title.TitleText.title = true
    title.TitleText.font = { 'Fonts\\FRIZQT__.TTF', 14, 'OUTLINE' }
    title.TitleText.color = { 1, 0.82, 0, 1 }
    f.scrolls = {}
    if not opts.noClose then
        f.CloseButton = button(f, name .. 'CloseButton', { 'TOPRIGHT', f, 'TOPRIGHT', 4, 5 },
            { arrow = true, w = 32, h = 32 })
    end
    return f
end

local ROLE = {}

-- A scroll frame anchored to the window: TOPLEFT high up, its bottom edge `bottom` px above the window bottom.
-- `both` adds a BOTTOMLEFT point as well. Scroll frames are not protected.
local function scrollFrame(win, parent, name, bottom, opts)
    opts = opts or {}
    local s = W.New('Frame', parent, name)
    s.scrollFrame = true
    s:SetPoint('TOPLEFT', win, 'TOPLEFT', 20, -80)
    if opts.both then s:SetPoint('BOTTOMLEFT', win, 'BOTTOMLEFT', 20, bottom) end
    s:SetPoint('BOTTOMRIGHT', win, 'BOTTOMRIGHT', -40, bottom)
    table.insert(win.scrolls, s)
    return s
end

local function BuildQuestFrame(opts)
    opts = opts or {}
    local f = window('QuestFrame', opts)
    local anchorAway = UIParent
    local panels = {}
    for _, p in ipairs({ 'QuestFrameDetailPanel', 'QuestFrameProgressPanel', 'QuestFrameRewardPanel', 'QuestFrameGreetingPanel' }) do
        local panel = W.New('Frame', f, p)
        panel:SetAllPoints(f)
        panels[p] = panel
    end
    -- Detail, progress and reward text reaches under the button band; greeting sits high enough.
    local scroll = scrollFrame(f, panels.QuestFrameDetailPanel, 'QuestDetailScrollFrame', 20)
    scrollFrame(f, panels.QuestFrameProgressPanel, 'QuestProgressScrollFrame', 12)
    scrollFrame(f, panels.QuestFrameRewardPanel, 'QuestRewardScrollFrame', 4, { both = true })
    scrollFrame(f, panels.QuestFrameGreetingPanel, 'QuestGreetingScrollFrame', 60)
    scroll.ScrollBar = scrollBar(scroll, 'QuestDetailScrollFrameScrollBar', opts)
    f.reward = tex(panels.QuestFrameRewardPanel, 'QuestInfoRewardsFrameQuestInfoItem1IconTexture', 'ARTWORK')
    f.content = { f.reward }
    f.fonts = { fontString(panels.QuestFrameDetailPanel, 'Quest title', 'QuestInfoTitleHeader'),
        fontString(panels.QuestFrameDetailPanel, 'Quest text', 'QuestInfoDescriptionText') }
    local spec = {
        { 'QuestFrameAcceptButton', 'QuestFrameDetailPanel', 'primary' },
        { 'QuestFrameDeclineButton', 'QuestFrameDetailPanel', 'secondary' },
        { 'QuestFrameCompleteButton', 'QuestFrameProgressPanel', 'primary' },
        { 'QuestFrameGoodbyeButton', 'QuestFrameProgressPanel', 'secondary' },
        { 'QuestFrameCompleteQuestButton', 'QuestFrameRewardPanel', 'primary' },
        { 'QuestFrameGreetingGoodbyeButton', 'QuestFrameGreetingPanel', 'secondary' },
    }
    f.buttons = {}
    for i, s in ipairs(spec) do
        if not (opts.onlyAccept and s[1] ~= 'QuestFrameAcceptButton') then
            local b = button(panels[s[2]], s[1], { 'TOPLEFT', anchorAway, 'TOPLEFT', 100 + i, -700 - i },
                { noLMR = opts.onlyAccept, noNormal = opts.onlyAccept })
            ROLE[b] = s[3]
            f.buttons[#f.buttons + 1] = b
        end
    end
    return f
end

local function BuildGossipFrame(opts)
    local f = window('GossipFrame', opts)
    local panel = W.New('Frame', f)
    panel.name = 'GossipFrame.GreetingPanel'
    panel:SetAllPoints(f)
    f.GreetingPanel = panel
    panel.ScrollBar = scrollBar(panel, nil)
    panel.ScrollBar.name = 'GossipFrame.GreetingPanel.ScrollBar'
    local box = scrollFrame(f, panel, nil, 8)
    box.name = 'GossipFrame.GreetingPanel.ScrollBox'
    panel.ScrollBox = box
    f.optionIcon = tex(box, 'GossipOptionIcon', 'ARTWORK')
    f.content = { f.optionIcon }
    f.fonts = { fontString(box, 'Greetings, traveler.', 'GossipGreetingText') }
    local bye = button(panel, nil, { 'TOPLEFT', UIParent, 'TOPLEFT', 300, -800 }, { text = 'Goodbye' })
    bye.name = 'GossipFrame.GreetingPanel.GoodbyeButton'
    panel.GoodbyeButton = bye
    ROLE[bye] = 'secondary'
    f.buttons = { bye }
    return f
end

local function BuildItemTextFrame(opts)
    local f = window('ItemTextFrame', opts)
    local scroll = scrollFrame(f, f, 'ItemTextScrollFrame', 10)
    scroll.ScrollBar = scrollBar(scroll, 'ItemTextScrollFrameScrollBar')
    f.content = {}
    f.fonts = { fontString(scroll, 'Page one', 'ItemTextPageText'), fontString(f, 'Page 1', 'ItemTextCurrentPage') }
    local prev = button(f, 'ItemTextPrevPageButton', { 'TOPLEFT', UIParent, 'TOPLEFT', 400, -900 }, { arrow = true, w = 32, h = 32 })
    local nxt = button(f, 'ItemTextNextPageButton', { 'TOPLEFT', UIParent, 'TOPLEFT', 500, -900 }, { arrow = true, w = 32, h = 32 })
    ROLE[prev] = 'secondary'
    ROLE[nxt] = 'primary'
    f.buttons = { prev, nxt }
    return f
end

-- Snapshot of everything Restore must bring back.
local function serializePoints(o)
    local parts = {}
    for _, p in ipairs(o.points) do
        parts[#parts + 1] = string.format('%s>%s>%s>%s>%s', tostring(p[1]), tostring(p[2]), tostring(p[3]),
            tostring(p[4]), tostring(p[5]))
    end
    return table.concat(parts, '|')
end

local function snapshot()
    local s = {}
    for _, o in ipairs(W.objects) do
        if not o.created then
            s[o] = { alpha = o.alpha, shown = o.shown, points = serializePoints(o), w = o.width, h = o.height,
                texture = o.texture, normal = o.normal, pushed = o.pushed, highlight = o.highlight,
                disabled = o.disabled, onClick = o.scripts.OnClick, text = o.text,
                font = o.font and table.concat({ tostring(o.font[1]), tostring(o.font[2]), tostring(o.font[3]) }, '>'),
                color = o.color and { unpack(o.color) } }
        end
    end
    return s
end

local function Build(opts)
    W.fixture = true
    UIParent = W.New('Frame', nil, 'UIParent')
    UIParent:SetSize(1920, 1080)
    if not opts.noQuest then W.quest = BuildQuestFrame(opts.quest) end
    if not opts.noGossip then W.gossip = BuildGossipFrame(opts.gossip) end
    if not opts.noItemText then W.itemText = BuildItemTextFrame(opts.itemText) end
    W.fixture = false
end

local function Boot(opts)
    opts = opts or {}
    W = { objects = {}, created = {}, violations = {}, prints = {}, inCombat = false,
        parchment = opts.parchment ~= false, fixture = false, blizzard = false }
    W.New = newObject
    W.Fire = function(frame, script, ...)
        if frame.scripts[script] then frame.scripts[script](frame, ...) end
        for _, fn in ipairs(frame.hooks[script] or {}) do fn(frame, ...) end
    end
    for _, g in ipairs({ 'QuestFrame', 'GossipFrame', 'ItemTextFrame', 'QuestFrameAcceptButton', 'QuestFrameDeclineButton',
        'QuestFrameCompleteButton', 'QuestFrameGoodbyeButton', 'QuestFrameCompleteQuestButton',
        'QuestFrameGreetingGoodbyeButton', 'ItemTextPrevPageButton', 'ItemTextNextPageButton', 'QuestDetailScrollFrame',
        'ItemTextScrollFrame', 'QuestProgressScrollFrame', 'QuestRewardScrollFrame', 'QuestGreetingScrollFrame',
        'QuestFrameDetailPanel', 'QuestFrameProgressPanel', 'QuestFrameRewardPanel',
        'QuestFrameGreetingPanel', 'QuestFrameCloseButton', 'GossipFrameCloseButton', 'ItemTextFrameCloseButton' }) do
        _G[g] = nil
    end
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        W.prints[#W.prints + 1] = table.concat(parts, ' ')
    end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) W.prints[#W.prints + 1] = tostring(msg) end }
    issecretvalue = function(v) return type(v) == 'table' and v.secret == true end
    hooksecurefunc = hooksecurefuncStub
    _G.unpack = table.unpack
    GetTime = function() return 100 end
    InCombatLockdown = function() return W.inCombat end
    C_Timer = { After = function(_, fn) fn() end }
    CreateFrame = function(_, frameName, parent)
        return W.New('Frame', parent or UIParent, frameName)
    end
    Build(opts)
    if opts.combat then W.inCombat = true end

    QuietUIDB = { enabled = opts.enabled ~= false }
    QuietUICharDB = {}
    local ns = {}
    assert(loadfile('Core.lua'))('QuietUI', ns)
    ns.Parchment = function() return W.parchment end
    local chunk, err = loadfile('Parchment.lua')
    assert(chunk, 'Parchment.lua could not be loaded: ' .. tostring(err))
    chunk('QuietUI', ns)
    assert(type(ns.ApplyParchment) == 'function', 'ns.ApplyParchment is missing')
    assert(type(ns.RestoreParchment) == 'function', 'ns.RestoreParchment is missing')
    assert(type(ns.ParchmentEvent) == 'function', 'ns.ParchmentEvent is missing')
    W.ns = ns
    W.original = snapshot()
    return ns
end

-- Queries -----------------------------------------------------------------------------------

local function within(o, root)
    local seen = 0
    while o and seen < 50 do
        if o == root then return true end
        o = o.parent
        seen = seen + 1
    end
    return false
end

-- Shown with alpha above zero from o up to (not including) stop.
local function visibleUpTo(o, stop)
    local seen = 0
    while o and o ~= stop and seen < 50 do
        if not o.shown or (type(o.alpha) == 'number' and o.alpha <= 0) then return false end
        o = o.parent
        seen = seen + 1
    end
    return true
end

local function visible(o) return visibleUpTo(o, nil) end

local function isParchment(o)
    local path = o.kind == 'Texture' and (o.texture or o.atlas)
    return type(path) == 'string' and path:lower():find('parchment', 1, true) ~= nil
end

local function parchmentsOn(win)
    local all, shown = {}, {}
    for _, o in ipairs(W.objects) do
        if isParchment(o) and within(o, win) then
            all[#all + 1] = o
            if visible(o) then shown[#shown + 1] = o end
        end
    end
    return all, shown
end

-- True when o's anchors lead to win (directly or through addon frames covering it).
local function anchoredTo(o, win, depth)
    depth = depth or 0
    if depth > 5 then return false end
    for _, p in ipairs(o.points) do
        local rel = p[2]
        if rel == win then return true end
        if rel and rel ~= o and rel.created and anchoredTo(rel, win, depth + 1) then return true end
    end
    return false
end

-- True when o sits in the bottom part of win: a BOTTOM anchor inside it, possibly via other buttons.
local function anchoredBottom(o, win, depth)
    depth = depth or 0
    if depth > 6 then return false end
    for _, p in ipairs(o.points) do
        local rel, relPoint, y = p[2], tostring(p[3]), p[5] or 0
        if rel == win or (rel and rel.created and within(rel, win)) or (rel and rel.created and anchoredTo(rel, win)) then
            if relPoint:find('BOTTOM') and y >= 0 then return true end
        elseif rel and rel ~= o and rel ~= UIParent and within(rel, win) and anchoredBottom(rel, win, depth + 1) then
            return true
        end
    end
    return false
end

local function colorOf(t)
    local c = { 1, 1, 1, 1 }
    for _, src in ipairs({ t.colorTex, t.vcolor }) do
        if src then
            for i = 1, 4 do c[i] = c[i] * (src[i] or 1) end
        end
    end
    return c
end

local function effAlpha(t, stop)
    local a, x = 1, t
    while x and x ~= stop do a = a * (x.alpha or 1); x = x.parent end
    return a * colorOf(t)[4]
end

local function lum(c) return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3] end

-- Addon-made coloured textures visible inside a button.
local function fillsOf(b)
    local list = {}
    for _, o in ipairs(W.created) do
        if o.kind == 'Texture' and (o.colorTex or o.vcolor) and not isParchment(o) and within(o, b)
            and visibleUpTo(o, b) then
            list[#list + 1] = o
        end
    end
    return list
end

local function baseFill(b)
    local best, bestA
    for _, t in ipairs(fillsOf(b)) do
        local a = effAlpha(t, b)
        if not best or a > bestA then best, bestA = t, a end
    end
    return best, bestA or 0
end

local function look(b)
    local sum = 0
    for _, t in ipairs(fillsOf(b)) do sum = sum + lum(colorOf(t)) * effAlpha(t, b) end
    return sum
end

local function buttonTextures(b)
    local list = {}
    for _, k in ipairs({ 'Left', 'Middle', 'Right', 'normal', 'pushed', 'highlight', 'disabled' }) do
        local t = W.original[b] and W.original[b][k] or b[k]
        if type(t) == 'table' and not t.created then list[#list + 1] = t end
    end
    return list
end

local function windows()
    local list = {}
    for _, f in ipairs({ W.quest, W.gossip, W.itemText }) do if f then list[#list + 1] = f end end
    return list
end

local function allButtons()
    local list = {}
    for _, f in ipairs(windows()) do
        for _, b in ipairs(f.buttons) do list[#list + 1] = b end
    end
    return list
end

local function scrollBarsOf(f)
    if f == W.quest then return { QuestDetailScrollFrame.ScrollBar } end
    if f == W.gossip then return { f.GreetingPanel.ScrollBar } end
    if f == W.itemText then return { ItemTextScrollFrame.ScrollBar } end
    return {}
end

local function event(name, ...) W.ns.ParchmentEvent(name, ...) end

-- Runs fn as Blizzard code: window guards do not fire.
local function Blizzard(fn)
    W.blizzard = true
    local ok, err = pcall(fn)
    W.blizzard = false
    if not ok then error(err, 2) end
end

local function near(a, b) return math.abs((a or -1) - (b or -2)) < 0.011 end

-- Every window matches its fixture state: textures, points, sizes, buttons, no addon look visible.
local function assertOriginal(where)
    for o, s in pairs(W.original) do
        if o.kind == 'Texture' then
            assert(near(o.alpha, s.alpha), where .. ': ' .. label(o) .. ' alpha ' .. tostring(o.alpha)
                .. ', expected ' .. tostring(s.alpha))
            assert(o.shown == s.shown, where .. ': ' .. label(o) .. ' shown state changed')
        end
        -- Points of every Blizzard object (buttons, windows, scroll frames, panels) come back exactly.
        assert(serializePoints(o) == s.points, where .. ': ' .. label(o) .. ' points not restored: '
            .. serializePoints(o) .. ', expected ' .. s.points)
        if o.title then
            local font = table.concat({ tostring(o.font[1]), tostring(o.font[2]), tostring(o.font[3]) }, '>')
            assert(font == s.font, where .. ': ' .. label(o) .. ' font not restored: ' .. font .. ', expected ' .. s.font)
            for i = 1, 4 do
                assert(o.color[i] == s.color[i], where .. ': ' .. label(o) .. ' colour not restored')
            end
        end
        if o.kind == 'Button' or o.window then
            assert(serializePoints(o) == s.points, where .. ': ' .. label(o) .. ' points not restored')
            assert(o.width == s.w and o.height == s.h, where .. ': ' .. label(o) .. ' size not restored')
        end
        if o.kind == 'Button' then
            assert(o.normal == s.normal and o.pushed == s.pushed and o.highlight == s.highlight
                and o.disabled == s.disabled, where .. ': ' .. label(o) .. ' state textures replaced')
        end
    end
    for _, f in ipairs(windows()) do
        local _, shown = parchmentsOn(f)
        assert(#shown == 0, where .. ': parchment still visible on ' .. label(f))
    end
    for _, b in ipairs(allButtons()) do
        assert(#fillsOf(b) == 0, where .. ': a flat fill is still visible on ' .. label(b))
    end
    for _, f in ipairs(windows()) do
        local close = f.CloseButton
        if close then
            for _, o in ipairs(W.created) do
                if within(o, close) and visibleUpTo(o, close) then
                    error(where .. ': an addon cross is still visible on ' .. label(close))
                end
            end
        end
    end
end

local function test(name, fn)
    cases = cases + 1
    local ok, err = pcall(function()
        fn()
        assert(W, 'Boot was not called')
        assert(#W.violations == 0, 'Forbidden calls: ' .. table.concat(W.violations, ', '))
        local allowed = W.allowPrints or 0
        assert(#W.prints <= allowed, 'Unexpected chat output: ' .. table.concat(W.prints, ' | '))
    end)
    print = out
    out((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

-- Standard: QuietUI on, Parchment windows on, all three windows loaded, reskin applied.
local function Ready(opts)
    Boot(opts)
    W.ns.ApplyParchment()
end

-- 1. Parchment layer and hidden chrome ------------------------------------------------------

test('Apply puts one visible parchment texture at BACKGROUND on each window', function()
    Ready()
    for _, f in ipairs(windows()) do
        local all, shown = parchmentsOn(f)
        assert(#shown == 1, label(f) .. ' shows ' .. #shown .. ' parchment textures, expected 1')
        assert(#all == 1, label(f) .. ' has ' .. #all .. ' parchment textures, expected 1')
        local p = shown[1]
        assert(p.created, 'The parchment texture is not the addon\'s own layer')
        assert(p.layer == 'BACKGROUND', label(f) .. ' parchment layer is ' .. tostring(p.layer))
        assert(anchoredTo(p, f), label(f) .. ' parchment is not anchored to the window')
    end
end)

test('Apply hides NineSlice, Bg and portrait through alpha', function()
    Ready()
    for _, f in ipairs(windows()) do
        assert(#f.chrome > 0, 'fixture without chrome')
        for _, t in ipairs(f.chrome) do
            assert(t.alpha == 0, label(t) .. ' alpha is ' .. tostring(t.alpha) .. ', expected 0')
        end
    end
end)

test('Apply leaves the window itself alone: shown, alpha, size and points', function()
    Ready()
    for _, f in ipairs(windows()) do
        local s = W.original[f]
        assert(f.shown, label(f) .. ' was hidden')
        assert(f.alpha == 1, label(f) .. ' alpha changed to ' .. tostring(f.alpha))
        assert(f.width == s.w and f.height == s.h, label(f) .. ' size changed')
        assert(serializePoints(f) == s.points, label(f) .. ' points changed')
    end
end)

test('Apply keeps content textures (reward icon, gossip option icon) visible', function()
    Ready()
    for _, f in ipairs(windows()) do
        for _, t in ipairs(f.content) do
            assert(t.alpha == 1 and t.shown, label(t) .. ' was hidden')
        end
    end
end)

-- 2. Alpha hook --------------------------------------------------------------------------------

test('Blizzard SetAlpha(1) on hidden chrome is held at 0 while Parchment is on', function()
    Ready()
    for _, f in ipairs(windows()) do
        for _, t in ipairs(f.chrome) do
            t:SetAlpha(1)
            assert(t.alpha == 0, label(t) .. ' came back to ' .. tostring(t.alpha))
        end
    end
    local left = QuestFrameAcceptButton.Left
    left:SetAlpha(1)
    assert(left.alpha == 0, 'Accept Left texture came back to ' .. tostring(left.alpha))
end)

test('Parchment off + Restore: original alphas come back and SetAlpha(1) sticks', function()
    Ready()
    W.parchment = false
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
    assert(QuestFrame.NineSlice.Center.alpha == 0.5, 'Center did not return to 0.5')
    for _, f in ipairs(windows()) do
        for _, t in ipairs(f.chrome) do
            t:SetAlpha(1)
            assert(t.alpha == 1, label(t) .. ' was held at ' .. tostring(t.alpha) .. ' with Parchment off')
        end
    end
    QuestFrameAcceptButton.Middle:SetAlpha(1)
    assert(QuestFrameAcceptButton.Middle.alpha == 1, 'Accept Middle was held with Parchment off')
end)

test('Blizzard alpha change while held is what Restore brings back', function()
    Ready()
    local center = QuestFrame.NineSlice.Center
    center:SetAlpha(0.8)
    assert(center.alpha == 0, 'Center came back to ' .. tostring(center.alpha))
    W.parchment = false
    W.ns.RestoreParchment()
    assert(center.alpha == 0.8, 'Restore put back a stale alpha: ' .. tostring(center.alpha))
end)

test('QuietUI off + Restore: SetAlpha(1) sticks', function()
    Ready()
    QuietUIDB.enabled = false
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
    QuestFrame.PortraitContainer.portrait:SetAlpha(1)
    assert(QuestFrame.PortraitContainer.portrait.alpha == 1, 'Portrait was held with QuietUI off')
end)

-- 3. OnShow and events re-apply ------------------------------------------------------------------

test('Window OnShow re-hides a portrait Blizzard reset while closed', function()
    Ready()
    local portrait = QuestFrame.PortraitContainer.portrait
    Blizzard(function()
        QuestFrame:Hide()
        -- A template reset that does not pass through SetAlpha (e.g. SetPortraitTexture).
        portrait.alpha = 1
        portrait.shown = true
        QuestFrame:Show()
    end)
    assert(QuestFrame.blizzardShows == 1, 'The Blizzard OnShow script did not run')
    assert(portrait.alpha == 0, 'Portrait visible after OnShow: ' .. tostring(portrait.alpha))
    local _, shown = parchmentsOn(QuestFrame)
    assert(#shown == 1, 'Parchment not visible after OnShow')
end)

test('Quest and gossip events re-apply the reskin', function()
    Ready()
    for _, case in ipairs({ { 'QUEST_DETAIL', QuestFrame }, { 'QUEST_PROGRESS', QuestFrame },
        { 'QUEST_COMPLETE', QuestFrame }, { 'QUEST_GREETING', QuestFrame }, { 'GOSSIP_SHOW', GossipFrame },
        { 'ITEM_TEXT_READY', ItemTextFrame } }) do
        local portrait = case[2].PortraitContainer.portrait
        portrait.alpha = 1
        event(case[1])
        assert(portrait.alpha == 0, case[1] .. ' did not re-hide the portrait of ' .. label(case[2]))
    end
end)

-- 4. Buttons -----------------------------------------------------------------------------------

test('Button textures are hidden through alpha and a flat fill is visible', function()
    Ready()
    for _, b in ipairs(allButtons()) do
        for _, t in ipairs(buttonTextures(b)) do
            assert(t.alpha == 0, label(t) .. ' alpha is ' .. tostring(t.alpha))
        end
        local fill = baseFill(b)
        assert(fill, label(b) .. ' has no visible flat fill')
    end
end)

test('Primary buttons are dark red, secondary buttons muted grey', function()
    Ready()
    for _, b in ipairs(allButtons()) do
        local fill = assert(baseFill(b), label(b) .. ' has no fill')
        local c = colorOf(fill)
        local r, g, bl = c[1], c[2], c[3]
        local rgb = string.format('%.2f,%.2f,%.2f', r, g, bl)
        if ROLE[b] == 'primary' then
            assert(r >= 0.25 and r - math.max(g, bl) >= 0.1, label(b) .. ' is not dark red: ' .. rgb)
            assert(r <= 0.8, label(b) .. ' red is not dark: ' .. rgb)
        else
            assert(math.abs(r - g) < 0.08 and math.abs(g - bl) < 0.08 and math.abs(r - bl) < 0.08,
                label(b) .. ' is not grey: ' .. rgb)
        end
    end
end)

test('Buttons move to the bottom of their window and restore exactly', function()
    Ready()
    for _, f in ipairs(windows()) do
        for _, b in ipairs(f.buttons) do
            assert(serializePoints(b) ~= W.original[b].points, label(b) .. ' was not moved')
            assert(anchoredBottom(b, f), label(b) .. ' is not anchored inside the bottom of ' .. label(f))
        end
    end
    W.parchment = false
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
end)

test('Button OnClick scripts and texts are unchanged', function()
    Ready()
    for _, b in ipairs(allButtons()) do
        assert(b.scripts.OnClick == b.onClick, label(b) .. ' OnClick changed')
        if b.Text then assert(b.Text.text == W.original[b.Text].text, label(b) .. ' text changed') end
    end
    W.ns.RestoreParchment()
    for _, b in ipairs(allButtons()) do
        assert(b.scripts.OnClick == b.onClick, label(b) .. ' OnClick changed after Restore')
    end
end)

test('Hover lightens the fill, leaving brings it back', function()
    Ready()
    for _, b in ipairs({ QuestFrameAcceptButton, QuestFrameDeclineButton, GossipFrame.GreetingPanel.GoodbyeButton,
        ItemTextNextPageButton }) do
        local before = look(b)
        b.mouseOver = true
        W.Fire(b, 'OnEnter')
        local hover = look(b)
        b.mouseOver = false
        W.Fire(b, 'OnLeave')
        local after = look(b)
        assert(hover > before + 0.005, label(b) .. ' hover is not lighter: ' .. before .. ' -> ' .. hover)
        assert(near(after, before), label(b) .. ' did not return after leave: ' .. before .. ' -> ' .. after)
    end
end)

test('A disabled button has a dimmer fill; enabling brings it back', function()
    Ready()
    local b = ItemTextPrevPageButton
    local _, enabledA = baseFill(b)
    local enabledLook = look(b)
    Blizzard(function() b:Disable() end)
    event('ITEM_TEXT_READY')
    local _, disabledA = baseFill(b)
    local disabledLook = look(b)
    assert(disabledA < enabledA - 0.05 or disabledLook < enabledLook - 0.005,
        'Disabled fill is not dimmer: alpha ' .. enabledA .. ' -> ' .. disabledA)
    Blizzard(function() b:Enable() end)
    event('ITEM_TEXT_READY')
    local _, againA = baseFill(b)
    assert(near(againA, enabledA), 'Enabled fill did not come back: ' .. enabledA .. ' -> ' .. againA)
end)

-- 5. Close button ------------------------------------------------------------------------------

test('Close button becomes a smaller dark cross and restores', function()
    Ready()
    for _, f in ipairs(windows()) do
        local close = f.CloseButton
        assert(close.width < 32 and close.height < 32, label(close) .. ' was not made smaller')
        for _, t in ipairs(buttonTextures(close)) do
            assert(t.alpha == 0, label(t) .. ' alpha is ' .. tostring(t.alpha))
        end
        local cross
        for _, o in ipairs(W.created) do
            if within(o, close) and (o.kind == 'Texture' or o.kind == 'FontString') and visibleUpTo(o, close) then
                cross = o
                if o.kind == 'Texture' and (o.colorTex or o.vcolor) then
                    assert(lum(colorOf(o)) < 0.5, label(close) .. ' cross is not dark')
                end
            end
        end
        assert(cross, label(close) .. ' shows no cross')
        assert(close.scripts.OnClick == close.onClick, label(close) .. ' OnClick changed')
    end
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
    for _, f in ipairs(windows()) do
        assert(f.CloseButton.scripts.OnClick == f.CloseButton.onClick, 'Close OnClick changed after Restore')
    end
end)

-- 6. Scroll bars -------------------------------------------------------------------------------

test('Scroll bar track and background are dimmed, the thumb stays visible', function()
    Ready()
    for _, f in ipairs(windows()) do
        for _, bar in ipairs(scrollBarsOf(f)) do
            for _, t in ipairs({ bar.Background, bar.Track.Begin, bar.Track.Middle, bar.Track.End }) do
                assert(effAlpha(t, f) < 1, label(t) .. ' was not dimmed')
            end
            local thumb = bar.Track.Thumb
            for _, t in ipairs({ thumb.Begin, thumb.Middle, thumb.End }) do
                assert(visible(t) and effAlpha(t) >= 0.99, label(t) .. ' is not fully visible')
            end
        end
    end
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
end)

-- 7. FontStrings ---------------------------------------------------------------------------------

test('No Blizzard FontString is written through Apply, events and Restore', function()
    Ready()
    for _, e in ipairs({ 'QUEST_DETAIL', 'QUEST_PROGRESS', 'QUEST_COMPLETE', 'QUEST_GREETING', 'GOSSIP_SHOW', 'ITEM_TEXT_READY' }) do
        event(e)
    end
    W.ns.RestoreParchment()
    W.ns.ApplyParchment()
    for _, f in ipairs(windows()) do
        for _, fs in ipairs(f.fonts) do
            assert(fs.text == W.original[fs].text, label(fs) .. ' text changed')
        end
        assert(f.TitleContainer.TitleText.text == label(f) .. ' title', label(f) .. ' title text changed')
    end
    -- Violations (SetText, SetFont, SetTextColor...) are asserted after every case.
end)

-- 8. Missing parts -------------------------------------------------------------------------------

test('Missing GossipFrame and ItemTextFrame: QuestFrame is reskinned, no error', function()
    Boot({ noGossip = true, noItemText = true })
    W.allowPrints = 1
    W.ns.ApplyParchment()
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    event('ADDON_LOADED', 'Blizzard_ItemText')
    W.ns.RestoreParchment()
    W.ns.ApplyParchment()
    local _, shown = parchmentsOn(QuestFrame)
    assert(#shown == 1, 'QuestFrame was not reskinned')
end)

test('Missing NineSlice, portrait, close button, buttons and button textures: no error', function()
    Boot({ quest = { noNineSlice = true, noPortrait = true, noClose = true, onlyAccept = true, noTrack = true },
        gossip = { noBg = true, noClose = true } })
    W.allowPrints = 1
    W.ns.ApplyParchment()
    for _, e in ipairs({ 'QUEST_DETAIL', 'QUEST_PROGRESS', 'QUEST_COMPLETE', 'QUEST_GREETING', 'GOSSIP_SHOW', 'ITEM_TEXT_READY' }) do
        event(e)
    end
    local _, shown = parchmentsOn(QuestFrame)
    assert(#shown == 1, 'QuestFrame was not reskinned')
    assert(QuestFrame.Bg.alpha == 0, 'QuestFrame Bg was not hidden')
    assert(baseFill(QuestFrameAcceptButton), 'Accept has no fill')
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
end)

test('Unknown event is ignored without error', function()
    Ready()
    event('SOME_UNKNOWN_EVENT', 'x')
    event('ADDON_LOADED', 'SomeOtherAddon')
end)

-- 9. Load on demand ------------------------------------------------------------------------------

local function LoadItemText()
    W.fixture = true
    W.itemText = BuildItemTextFrame()
    W.fixture = false
    for o, s in pairs(snapshot()) do if not W.original[o] then W.original[o] = s end end
end

test('ItemTextFrame loaded later is reskinned on ADDON_LOADED', function()
    Boot({ noItemText = true })
    W.ns.ApplyParchment()
    LoadItemText()
    event('ADDON_LOADED', 'Blizzard_ItemText')
    local _, shown = parchmentsOn(ItemTextFrame)
    assert(#shown == 1, 'ItemTextFrame was not reskinned on ADDON_LOADED')
    assert(ItemTextFrame.PortraitContainer.portrait.alpha == 0, 'ItemTextFrame portrait still visible')
    assert(baseFill(ItemTextNextPageButton), 'Next page has no fill')
end)

test('ItemTextFrame loaded later is reskinned on ITEM_TEXT_READY', function()
    Boot({ noItemText = true })
    W.ns.ApplyParchment()
    LoadItemText()
    event('ITEM_TEXT_READY')
    local _, shown = parchmentsOn(ItemTextFrame)
    assert(#shown == 1, 'ItemTextFrame was not reskinned on ITEM_TEXT_READY')
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
end)

-- 10. Idempotence --------------------------------------------------------------------------------

test('Apply twice, events and toggling create no second layer and keep true originals', function()
    Ready()
    local created = #W.created
    W.ns.ApplyParchment()
    event('QUEST_DETAIL')
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    assert(#W.created == created, 'Re-apply created ' .. (#W.created - created) .. ' new objects')
    for _, f in ipairs(windows()) do
        local all = parchmentsOn(f)
        assert(#all == 1, label(f) .. ' has ' .. #all .. ' parchment textures')
    end
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
    W.ns.ApplyParchment()
    assert(#W.created == created, 'Apply after Restore created new objects')
    W.ns.RestoreParchment()
    assertOriginal('after second Restore')
end)

-- 11. Off states ---------------------------------------------------------------------------------

test('QuietUI off: Apply and events do nothing', function()
    Boot({ enabled = false })
    W.ns.ApplyParchment()
    event('QUEST_DETAIL')
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    assertOriginal('QuietUI off')
end)

test('Parchment off: Apply and events do nothing', function()
    Boot({ parchment = false })
    W.ns.ApplyParchment()
    event('QUEST_DETAIL')
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    assertOriginal('Parchment off')
end)

-- Off by default: only an explicit true from the accessor turns the reskin on.
test('Missing accessor or a nil setting means off: Apply and events do nothing', function()
    Boot()
    W.ns.Parchment = nil
    W.ns.ApplyParchment()
    event('QUEST_DETAIL')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    assertOriginal('Missing ns.Parchment accessor')
    Boot()
    W.parchment = nil
    W.ns.ApplyParchment()
    event('GOSSIP_SHOW')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    assertOriginal('ns.Parchment() returning nil')
end)

test('Parchment switched off then Apply (Save) restores the original look', function()
    Ready()
    W.parchment = false
    W.ns.ApplyParchment()
    assertOriginal('Apply with Parchment off')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    event('QUEST_DETAIL')
    assertOriginal('OnShow and event with Parchment off')
    W.parchment = true
    W.ns.ApplyParchment()
    local _, shown = parchmentsOn(QuestFrame)
    assert(#shown == 1, 'Switching back on did not reskin')
end)

-- 12. Combat -------------------------------------------------------------------------------------

test('In combat: Apply still reskins without error', function()
    Ready({ combat = true })
    for _, f in ipairs(windows()) do
        local _, shown = parchmentsOn(f)
        assert(#shown == 1, label(f) .. ' was not reskinned in combat')
    end
    assert(baseFill(QuestFrameAcceptButton), 'Accept has no fill in combat')
    W.ns.RestoreParchment()
    assertOriginal('Restore in combat')
end)

-- 13. In-game feedback: button band, safe area, title, overhang -------------------------------

-- CzechForever's CZ/EN row sits at the window BOTTOM, y = 6, height 18: its centre is 15 px up.
local ROW_CENTER = 15
local SAFE_GAP = 4

-- The BOTTOM* point of o anchored to win: point, x, y.
local function bottomAnchor(o, win)
    for _, p in ipairs(o.points) do
        local point = tostring(p[1])
        if point:find('BOTTOM') and p[2] == win then return point, p[4] or 0, p[5] or 0 end
    end
end

-- Top of the skinned button band, from the actual button anchors (fallback: a 22 px button on the row).
local function bandTop(f)
    local top
    for _, b in ipairs(f.buttons) do
        local _, _, y = bottomAnchor(b, f)
        if y then top = math.max(top or y + b.height, y + b.height) end
    end
    return top or (ROW_CENTER + 11)
end

-- y offsets of the BOTTOM* points of a scroll frame, keyed by point name.
local function scrollBottoms(s, win)
    local list = {}
    for _, p in ipairs(s.points) do
        if tostring(p[1]):find('BOTTOM') then list[#list + 1] = { p[1], p[2], p[3], p[4], p[5] } end
    end
    return list
end

test('Buttons sit level with the CZ/EN row and inside the window', function()
    Ready()
    for _, f in ipairs(windows()) do
        for _, b in ipairs(f.buttons) do
            local point, x, y = bottomAnchor(b, f)
            assert(point, label(b) .. ' has no BOTTOM* point anchored to ' .. label(f))
            local centre = y + b.height / 2
            assert(math.abs(centre - ROW_CENTER) <= 1, label(b) .. ' centre is ' .. centre
                .. ' px above the window bottom, expected ' .. ROW_CENTER .. ' (y=' .. y .. ', h=' .. b.height .. ')')
            if point:find('LEFT') then
                assert(x >= 10, label(b) .. ' left inset is ' .. x .. ', expected >= 10')
            elseif point:find('RIGHT') then
                assert(x <= -10, label(b) .. ' right inset is ' .. x .. ', expected <= -10')
            end
        end
    end
end)

test('Scroll frames end above the button band; high ones and the window stay untouched', function()
    Ready()
    for _, f in ipairs(windows()) do
        local top = bandTop(f)
        local o = W.original[f]
        assert(f.width == o.w and f.height == o.h and serializePoints(f) == o.points, label(f) .. ' size or points changed')
        for _, sf in ipairs(f.scrolls) do
            local before = W.original[sf]
            local origLow = false
            for _, p in ipairs(sf.points) do
                assert(p[2] == f, label(sf) .. ' was re-anchored away from ' .. label(f))
            end
            local bottoms = scrollBottoms(sf, f)
            assert(#bottoms > 0, label(sf) .. ' lost its BOTTOM* points')
            for _, p in ipairs(bottoms) do
                assert(p[5] >= top + SAFE_GAP, label(sf) .. ' ' .. p[1] .. ' bottom is ' .. p[5]
                    .. ' px, band top is ' .. top .. ' (needs >= ' .. (top + SAFE_GAP) .. ')')
            end
            -- Point names, relative frames, x offsets and the non-bottom points stay as they were.
            assert(#sf.points == before.points:gsub('[^|]', ''):len() + 1, label(sf) .. ' point count changed')
            for i, p in ipairs(sf.points) do
                local orig = {}
                for part in (before.points .. '|'):gmatch('([^|]*)|') do orig[#orig + 1] = part end
                local name, rel, relPoint, x, y = orig[i]:match('^(.-)>(.-)>(.-)>(.-)>(.-)$')
                assert(tostring(p[1]) == name and tostring(p[2]) == rel and tostring(p[3]) == relPoint
                    and tostring(p[4]) == x, label(sf) .. ' point ' .. i .. ' changed beyond its y offset')
                if not name:find('BOTTOM') then
                    assert(tostring(p[5]) == y, label(sf) .. ' ' .. name .. ' y offset changed')
                elseif tonumber(y) >= top + SAFE_GAP then
                    assert(tostring(p[5]) == y, label(sf) .. ' was high enough but was moved: ' .. y .. ' -> ' .. p[5])
                else
                    origLow = true
                end
            end
            if not origLow then
                assert(serializePoints(sf) == before.points, label(sf) .. ' was high enough but its points changed')
            end
        end
    end
    -- The panels stay flush with the window.
    for _, name in ipairs({ 'QuestFrameDetailPanel', 'QuestFrameRewardPanel' }) do
        assert(serializePoints(_G[name]) == W.original[_G[name]].points, name .. ' points changed')
    end
    assert(serializePoints(GossipFrame.GreetingPanel) == W.original[GossipFrame.GreetingPanel].points,
        'GossipFrame.GreetingPanel points changed')
end)

test('Scroll frame lift is idempotent and Restore puts back the exact points', function()
    Ready()
    local lifted = {}
    for _, f in ipairs(windows()) do
        for _, sf in ipairs(f.scrolls) do lifted[sf] = serializePoints(sf) end
    end
    assert(lifted[QuestRewardScrollFrame] ~= W.original[QuestRewardScrollFrame].points, 'QuestRewardScrollFrame was not lifted')
    W.ns.ApplyParchment()
    event('QUEST_COMPLETE')
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    Blizzard(function() QuestFrame:Hide(); QuestFrame:Show() end)
    for sf, pts in pairs(lifted) do
        assert(serializePoints(sf) == pts, label(sf) .. ' was lifted twice: ' .. pts .. ' -> ' .. serializePoints(sf))
    end
    W.parchment = false
    W.ns.RestoreParchment()
    for sf in pairs(lifted) do
        assert(serializePoints(sf) == W.original[sf].points, label(sf) .. ' points not restored: '
            .. serializePoints(sf) .. ', expected ' .. W.original[sf].points)
    end
    W.parchment = true
    W.ns.ApplyParchment()
    for sf, pts in pairs(lifted) do
        assert(serializePoints(sf) == pts, label(sf) .. ' lift after Restore differs: ' .. serializePoints(sf))
    end
    W.ns.RestoreParchment()
    assertOriginal('after second Restore')
end)

test('Window title gets dark ink and a larger size of the same face; Restore brings it back', function()
    Ready()
    for _, f in ipairs(windows()) do
        local t = f.TitleContainer.TitleText
        local o = W.original[t]
        local face, size = o.font:match('^(.-)>(.-)>')
        assert(t.color[1] < 0.35 and t.color[2] < 0.35 and t.color[3] < 0.35, label(t) .. ' is not dark ink: '
            .. string.format('%.2f,%.2f,%.2f', t.color[1], t.color[2], t.color[3]))
        assert(t.font[1] == face, label(t) .. ' font face changed to ' .. tostring(t.font[1]))
        assert(type(t.font[2]) == 'number' and t.font[2] >= tonumber(size) + 1, label(t) .. ' size is '
            .. tostring(t.font[2]) .. ', expected >= ' .. (tonumber(size) + 1))
        assert(t.text == o.text, label(t) .. ' text changed')
    end
    -- Re-apply does not keep growing the title.
    local sizes = {}
    for _, f in ipairs(windows()) do sizes[f] = f.TitleContainer.TitleText.font[2] end
    W.ns.ApplyParchment()
    event('QUEST_DETAIL')
    event('GOSSIP_SHOW')
    event('ITEM_TEXT_READY')
    for _, f in ipairs(windows()) do
        assert(f.TitleContainer.TitleText.font[2] == sizes[f], label(f) .. ' title grew on re-apply')
    end
    W.parchment = false
    W.ns.RestoreParchment()
    assertOriginal('after Restore')
    W.parchment = true
    W.ns.ApplyParchment()
    for _, f in ipairs(windows()) do
        assert(f.TitleContainer.TitleText.font[2] == sizes[f], label(f) .. ' title size differs after re-enable')
    end
end)

test('Parchment layer overhangs every window edge by at least 10 px', function()
    Ready()
    for _, f in ipairs(windows()) do
        local _, shown = parchmentsOn(f)
        local p = assert(shown[1], label(f) .. ' has no parchment')
        local edges = {}
        for _, pt in ipairs(p.points) do
            local point, rel, relPoint, x, y = pt[1], pt[2], pt[3], pt[4] or 0, pt[5] or 0
            assert(rel == f and point == relPoint, label(f) .. ' parchment point ' .. tostring(point)
                .. ' is not anchored to the matching window point')
            if point:find('LEFT') then assert(x <= -10, label(f) .. ' left overhang ' .. -x); edges.left = true end
            if point:find('RIGHT') then assert(x >= 10, label(f) .. ' right overhang ' .. x); edges.right = true end
            if point:find('TOP') then assert(y >= 10, label(f) .. ' top overhang ' .. y); edges.top = true end
            if point:find('BOTTOM') then assert(y <= -10, label(f) .. ' bottom overhang ' .. -y); edges.bottom = true end
        end
        assert(edges.left and edges.right and edges.top and edges.bottom, label(f) .. ' parchment does not cover all edges')
    end
end)

-- Hygiene ----------------------------------------------------------------------------------------

test('Parchment.lua never hides windows or uses secure snippets', function()
    local f = io.open('Parchment.lua')
    assert(f, 'Parchment.lua does not exist')
    local source = f:read('*a')
    f:close()
    for _, w in ipairs({ 'QuestFrame', 'GossipFrame', 'ItemTextFrame' }) do
        assert(not source:find(w .. ':Hide', 1, true), 'Parchment.lua calls ' .. w .. ':Hide')
    end
    assert(not source:find('SecureHandler', 1, true), 'Parchment.lua uses secure snippets')
    assert(not source:find('ForceTextureHidden', 1, true), 'Parchment.lua uses ns.ForceTextureHidden')
    W = W or { violations = {}, prints = {} }
end)

test('Media/parchment.tga exists', function()
    local f = io.open('Media/parchment.tga', 'rb')
    assert(f, 'Media/parchment.tga does not exist')
    local size = f:seek('end')
    f:close()
    assert(size and size > 18, 'Media/parchment.tga is not a TGA image')
    W = W or { violations = {}, prints = {} }
end)

test('Media/parchment.tga is a warm, darker tone in its central area', function()
    W = W or { violations = {}, prints = {} }
    local f = assert(io.open('Media/parchment.tga', 'rb'), 'Media/parchment.tga does not exist')
    local data = f:read('*a')
    f:close()
    local idLen, mapType, imageType = data:byte(1, 3)
    assert(mapType == 0 and imageType == 2, 'Media/parchment.tga is not an uncompressed true-colour TGA')
    local w = data:byte(13) + data:byte(14) * 256
    local h = data:byte(15) + data:byte(16) * 256
    local bpp = data:byte(17)
    assert(bpp == 32, 'Media/parchment.tga is ' .. bpp .. '-bit, expected 32')
    local base = 18 + idLen
    assert(#data >= base + w * h * 4, 'Media/parchment.tga is truncated')
    local r, g, b, n = 0, 0, 0, 0
    for y = math.floor(h / 4), math.floor(h * 3 / 4) - 1 do
        local row = base + y * w * 4
        for x = math.floor(w / 4), math.floor(w * 3 / 4) - 1 do
            local i = row + x * 4 + 1
            local cb, cg, cr = data:byte(i, i + 2)
            r, g, b, n = r + cr, g + cg, b + cb, n + 1
        end
    end
    r, g, b = r / n, g / n, b / n
    local rgb = string.format('%.1f,%.1f,%.1f', r, g, b)
    assert(r <= 225 and g <= 225 and b <= 225, 'Parchment centre is too white: mean RGB ' .. rgb .. ', each must be <= 225')
    assert(r - b >= 30, 'Parchment centre is not warm enough: mean RGB ' .. rgb .. ', R - B must be >= 30')
end)

io.write(string.format('%d parchment cases, %d failed\n', cases, failures))
if failures > 0 then os.exit(1) end
