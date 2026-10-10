-- Run from the addon directory: lua tests/highlights.lua
-- Highlights.lua in isolation: soft-target CVars, the glow on the soft-interact nameplate,
-- combat-safe CVars / instance gating and graceful failure on missing client APIs.
local failures, cases = 0, 0

local ORE = { 0.95, 0.75, 0.25 }
local HERB = { 0.30, 0.74, 0.40 }
local HERBS = 'Cursor Crosshair_GatherHerbs_64'
local HERBS_FAR = 'Cursor Crosshair_UnableGatherHerbs_64'
local MINE = 'Cursor Crosshair_Mine_64'
local NAMES = { 'SoftTargetInteract', 'SoftTargetInteractRange', 'SoftTargetNameplateInteract',
    'SoftTargetIconGameObject', 'SoftTargetInteractArc', 'SoftTargetIconInteract' }
local WANT = { SoftTargetInteract = '3', SoftTargetInteractRange = '15', SoftTargetNameplateInteract = '1',
    SoftTargetIconGameObject = '1', SoftTargetInteractArc = '2', SoftTargetIconInteract = '1' }
local ORIGINAL = { SoftTargetInteract = '1', SoftTargetInteractRange = '10', SoftTargetNameplateInteract = '0',
    SoftTargetIconGameObject = '0', SoftTargetInteractArc = '0', SoftTargetIconInteract = '0' }
local PLATE_FORBIDDEN = { SetAlpha = true, SetPoint = true, ClearAllPoints = true, Show = true, Hide = true }

-- Per-test world state, rebuilt by Boot().
local W

local function noop() end

local function newGroup(owner)
    local g = { owner = owner, playing = false, plays = 0, scripts = {}, anims = {} }
    W.groups[#W.groups + 1] = g
    function g:Play() self.playing = true; self.plays = self.plays + 1 end
    function g:Stop() self.playing = false end
    function g:Restart() self.playing = true end
    function g:IsPlaying() return self.playing end
    function g:SetLooping(mode) self.looping = mode end
    function g:GetLooping() return self.looping end
    function g:SetScript(name, fn)
        self.scripts[name] = fn
        if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = 'animation group' end
    end
    function g:GetScript(name) return self.scripts[name] end
    function g:HookScript(name, fn) self:SetScript(name, fn) end
    function g:CreateAnimation(kind)
        local a = { kind = kind, scripts = {} }
        function a:SetScript(name, fn)
            self.scripts[name] = fn
            if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = 'animation' end
        end
        function a:GetScript(name) return self.scripts[name] end
        function a:GetParent() return g end
        setmetatable(a, { __index = function() return noop end })
        self.anims[#self.anims + 1] = a
        return a
    end
    setmetatable(g, { __index = function() return noop end })
    return g
end

local newTexture
local function newFrame(parent, opts)
    opts = opts or {}
    local f = { parent = parent, shown = true, alpha = 1, scripts = {}, points = {}, level = opts.level,
        plate = opts.plate, name = opts.name }
    local function guard(method)
        if f.plate and PLATE_FORBIDDEN[method] then
            W.plateViolations[#W.plateViolations + 1] = (f.name or 'plate') .. ':' .. method
        end
    end
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:IsVisible()
        local x = self
        while x do
            if x.shown == false then return false end
            x = x.parent
        end
        return true
    end
    function f:Show() guard('Show'); self.shown = true end
    function f:Hide() guard('Hide'); self.shown = false end
    function f:SetShown(v) if v then self:Show() else self:Hide() end end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) guard('SetAlpha'); self.alpha = a end
    function f:GetParent() return self.parent end
    function f:SetParent(p)
        self.parent = p
        if type(p) == 'table' and rawget(p, 'plate') == true then self.wasOnPlate = true end
    end
    function f:ClearAllPoints() guard('ClearAllPoints'); self.points = {} end
    function f:SetPoint(...) guard('SetPoint'); self.points[#self.points + 1] = { ... } end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetFrameLevel(l) self.level = l; self.levelSet = true end
    function f:EnableMouse(v) self.mouse = v end
    function f:IsMouseEnabled() return self.mouse ~= false and self.mouse ~= nil end
    function f:SetScript(name, fn)
        self.scripts[name] = fn
        if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = 'frame' end
    end
    function f:GetScript(name) return self.scripts[name] end
    function f:HookScript(name, fn) self:SetScript(name, fn) end
    function f:CreateTexture() return newTexture(self) end
    if not W.noAnimations then
        function f:CreateAnimationGroup() return newGroup(self) end
    end
    -- Fields a frame may lack must read as nil, not as the catch-all method.
    setmetatable(f, { __index = function(_, k)
        if k == 'plate' or k == 'parent' or k == 'name' or k:find('^_quiet') then return nil end
        return noop
    end })
    return f
end

newTexture = function(parent, opts)
    local t = newFrame(parent, opts)
    function t:SetTexture(v) self.texture = v end
    function t:GetTexture() return self.texture end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function t:GetVertexColor() return unpack(self.color or { 1, 1, 1, 1 }) end
    function t:SetBlendMode(m) self.blend = m end
    W.textures[#W.textures + 1] = t
    return t
end

-- A forbidden plate: any method call except IsForbidden is a violation.
local function forbiddenProxy()
    local proxy
    proxy = setmetatable({}, {
        __index = function(_, key)
            if key == 'IsForbidden' then return function() return true end end
            return proxy
        end,
        __call = function() W.forbiddenCalls = W.forbiddenCalls + 1 end,
    })
    return proxy
end

local function Boot(opts)
    opts = opts or {}
    W = { groups = {}, textures = {}, created = {}, onUpdate = {}, plateViolations = {}, forbiddenCalls = 0,
        reports = {}, writes = {}, plates = {}, tokens = {}, softGUID = nil, inCombat = false,
        instance = opts.instance or 'none', noAnimations = opts.noAnimations, unitExists = 0 }
    W.cvars = {}
    for k, v in pairs(opts.cvars or ORIGINAL) do W.cvars[k] = v end
    W.unreadable = opts.unreadable or {}

    hooksecurefunc = function(target, name, hook)
        if type(target) ~= 'table' then return end
        local original = target[name]
        target[name] = function(self, ...)
            local r = { original(self, ...) }
            hook(self, ...)
            return table.unpack(r)
        end
    end
    unpack = unpack or table.unpack
    GetTime = function() return 100 end
    UIParent = newFrame(nil, { level = 0 })
    UIParent.name = 'UIParent'
    CreateFrame = function(_, _, parent)
        local f = newFrame(parent)
        W.created[#W.created + 1] = f
        return f
    end
    InCombatLockdown = function() return W.inCombat end
    IsInInstance = function()
        if W.instance == 'none' then return false, 'none' end
        return true, W.instance
    end
    UnitGUID = function(unit)
        if unit == 'softinteract' then return W.softGUID end
        return W.tokens[unit]
    end
    UnitExists = function(unit)
        W.unitExists = W.unitExists + 1
        error('UnitExists must not be called (got ' .. tostring(unit) .. ')')
    end
    if opts.noCVar then
        C_CVar = nil
    else
        C_CVar = {
            GetCVar = function(name)
                if W.unreadable[name] == 'error' then error('cannot read ' .. name) end
                if W.unreadable[name] then return nil end
                return W.cvars[name]
            end,
            SetCVar = function(name, value)
                W.writes[#W.writes + 1] = { name, tostring(value) }
                W.cvars[name] = tostring(value)
                return true
            end,
        }
    end
    GetCVar = nil
    SetCVar = nil
    if opts.noNamePlate then
        C_NamePlate = nil
    else
        C_NamePlate = {
            GetNamePlateForUnit = function(token)
                for _, p in ipairs(W.plates) do
                    if p.token == token then return p.plate end
                end
            end,
            GetNamePlates = function()
                local list = {}
                for _, p in ipairs(W.plates) do list[#list + 1] = p.plate end
                return list
            end,
        }
    end
    GetNamePlateForUnit = nil
    -- C_Timer.After only collects callbacks; RunTimers runs them like the next frame.
    W.timers = {}
    if opts.noTimer then
        C_Timer = nil
    else
        C_Timer = { After = function(delay, fn) W.timers[#W.timers + 1] = { delay = delay, fn = fn } end }
    end

    QuietUIDB = { enabled = opts.enabled ~= false, highlightCVars = opts.saved }
    QuietUICharDB = {}
    local ns = {}
    assert(loadfile('Core.lua'))('QuietUI', ns)
    W.flags = opts.flags or { herb = false, ore = false, quest = false }
    ns.Highlights = function() return W.flags end
    ns.Report = function(name) W.reports[name] = (W.reports[name] or 0) + 1 end
    ns.ShowAll = function() return false end
    ns.Glancing = function() return false end
    W.created = {}
    local chunk, err = loadfile('Highlights.lua')
    assert(chunk, 'Highlights.lua could not be loaded: ' .. tostring(err))
    chunk('QuietUI', ns)
    assert(type(ns.ApplyHighlights) == 'function', 'ns.ApplyHighlights is missing')
    assert(type(ns.RestoreHighlights) == 'function', 'ns.RestoreHighlights is missing')
    assert(type(ns.HighlightsEvent) == 'function', 'ns.HighlightsEvent is missing')
    W.ns = ns
    return ns
end

-- A nameplate for token / guid with a soft-target icon texture (texture may be nil or a number).
local function AddPlate(token, guid, texture, opts)
    opts = opts or {}
    local plate = newFrame(UIParent, { plate = true, name = token, level = 1 })
    local unitFrame = newFrame(plate, { plate = true, name = token .. '.UnitFrame', level = 2 })
    plate.UnitFrame = unitFrame
    if not opts.noUnitToken then unitFrame.unit = token end
    plate.namePlateUnitToken = token
    if not opts.noSoftTarget then
        local soft = newFrame(unitFrame, { plate = true, name = token .. '.SoftTargetFrame', level = 5 })
        local icon = newTexture(soft, { name = token .. '.Icon', level = 5 })
        icon.texture = texture
        if opts.atlas then
            function icon:GetAtlas() return opts.atlas end
        end
        soft.Icon = icon
        unitFrame.SoftTargetFrame = soft
        plate.soft = soft
    end
    W.plates[#W.plates + 1] = { token = token, plate = plate }
    W.tokens[token] = guid
    return plate
end

local function RemovePlate(token)
    for i, p in ipairs(W.plates) do
        if p.token == token then table.remove(W.plates, i) break end
    end
    W.tokens[token] = nil
end

local function event(name, ...) W.ns.HighlightsEvent(name, ...) end
-- Runs the collected timer callbacks with index in [from, to] (default all), in order.
local function RunTimers(from, to)
    local list = W.timers
    for i = from or 1, to or #list do
        local t = list[i]
        if t and not t.ran then t.ran = true; t.fn() end
    end
end
local function Target(guid, ...)
    W.softGUID = guid
    event('PLAYER_SOFT_INTERACT_CHANGED', ...)
end

local function within(f, root)
    local seen = 0
    while f and seen < 50 do
        if f == root then return true end
        f = f.parent
        seen = seen + 1
    end
    return false
end

local function visible(f)
    local seen = 0
    while f and seen < 50 do
        if f.shown == false or (type(f.alpha) == 'number' and f.alpha <= 0) then return false end
        f = f.parent
        seen = seen + 1
    end
    return true
end

-- The module's root frame: a created frame currently or previously parented to a plate.
local function Glow()
    for _, f in ipairs(W.created) do
        for _, p in ipairs(W.plates) do
            if f.parent == p.plate then return f end
        end
    end
    for _, f in ipairs(W.created) do
        if f.wasOnPlate then return f end
    end
end

local function ShownOn(plate)
    for _, f in ipairs(W.created) do
        if within(f, plate) and visible(f) then return f end
    end
end

local function NothingShown()
    for _, f in ipairs(W.created) do
        if visible(f) then return false end
    end
    return true
end

local function near(a, b) return type(a) == 'number' and math.abs(a - b) < 0.01 end

local function HasColor(root, color)
    for _, t in ipairs(W.textures) do
        if within(t, root) and t.color and near(t.color[1], color[1]) and near(t.color[2], color[2])
            and near(t.color[3], color[3]) then return true end
    end
    return false
end

local function LoopsPlaying(root)
    local any = false
    for _, g in ipairs(W.groups) do
        if (root == nil or within(g.owner, root)) and (g.looping == 'BOUNCE' or g.looping == 'REPEAT') and g.playing then
            any = true
        end
    end
    return any
end

local function AssertHiddenAtUIParent()
    local glow = Glow()
    assert(glow, 'The glow frame was never placed on a plate')
    assert(glow.parent == UIParent, 'The hidden glow was not returned to UIParent')
    assert(NothingShown(), 'Something from Highlights is still shown')
    assert(not LoopsPlaying(), 'A looping animation still plays while hidden')
end

local function AssertCVars(values, msg)
    for _, name in ipairs(NAMES) do
        assert(W.cvars[name] == values[name], (msg or 'CVar') .. ': ' .. name .. ' is ' .. tostring(W.cvars[name])
            .. ', expected ' .. tostring(values[name]))
    end
end

local function AssertSaved(values)
    local saved = QuietUIDB.highlightCVars
    assert(type(saved) == 'table', 'QuietUIDB.highlightCVars was not stored')
    for _, name in ipairs(NAMES) do
        assert(tostring(saved[name]) == values[name], 'highlightCVars.' .. name .. ' is ' .. tostring(saved[name])
            .. ', expected ' .. values[name])
    end
end

local function test(name, fn)
    cases = cases + 1
    local ok, err = pcall(function()
        fn()
        assert(W, 'Boot was not called')
        assert(#W.plateViolations == 0, 'Plate frames were touched: ' .. table.concat(W.plateViolations, ', '))
        assert(W.unitExists == 0, 'UnitExists was called ' .. W.unitExists .. ' times')
        assert(#W.onUpdate == 0, 'An OnUpdate script was set on a ' .. tostring(W.onUpdate[1]))
    end)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

-- A standard "ore on, mine target shown" setup.
local function OreShown(...)
    -- An explicit nil means a missing texture; no argument means the mine texture.
    local texture = select('#', ...) == 0 and MINE or ...
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-0-1-2-3-1731-0001', texture)
    Target('GameObject-0-1-2-3-1731-0001', nil, 'GameObject-0-1-2-3-1731-0001')
    return plate
end

-- Clean profile ---------------------------------------------------------------------------

test('Clean profile writes no CVar and shows nothing', function()
    Boot()
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    W.ns.ApplyHighlights()
    assert(#W.writes == 0, 'A CVar was written with every category off')
    assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was stored with every category off')
    assert(NothingShown(), 'Something was shown with every category off')
end)

test('An empty Highlights table counts as all off', function()
    Boot({ flags = {} })
    W.ns.ApplyHighlights()
    assert(#W.writes == 0, 'A CVar was written for an empty settings table')
end)

test('Disabled QuietUI is inactive even with Ore on', function()
    Boot({ flags = { ore = true }, enabled = false })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(#W.writes == 0, 'A CVar was written while QuietUI is disabled')
    assert(NothingShown(), 'The glow was shown while QuietUI is disabled')
end)

-- CVars -----------------------------------------------------------------------------------

test('Ore on out of combat and instance sets 3/15/1/1/2/1 and stores originals', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    AssertCVars(WANT, 'After apply')
    AssertSaved(ORIGINAL)
end)

test('ApplyHighlights is idempotent', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    W.ns.ApplyHighlights()
    W.ns.ApplyHighlights()
    AssertCVars(WANT, 'After repeated apply')
    AssertSaved(ORIGINAL)
end)

test('Turning the last category off restores all six originals', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    W.flags.ore = false
    W.ns.ApplyHighlights()
    AssertCVars(ORIGINAL, 'After last category off')
    assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was not cleared')
end)

test('RestoreHighlights restores all six originals and hides the glow', function()
    OreShown()
    assert(Glow(), 'The glow was not shown before restore')
    W.ns.RestoreHighlights()
    AssertCVars(ORIGINAL, 'After restore')
    assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was not cleared')
    AssertHiddenAtUIParent()
end)

test('Reload while active keeps the stored originals', function()
    Boot({ flags = { ore = true }, cvars = WANT, saved = {
        SoftTargetInteract = '1', SoftTargetInteractRange = '10', SoftTargetNameplateInteract = '0',
        SoftTargetIconGameObject = '0', SoftTargetInteractArc = '0', SoftTargetIconInteract = '0' } })
    W.ns.ApplyHighlights()
    AssertSaved(ORIGINAL)
    AssertCVars(WANT, 'After reload apply')
    W.flags.ore = false
    W.ns.ApplyHighlights()
    AssertCVars(ORIGINAL, 'After off following reload')
    assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was not cleared')
end)

test('An unreadable CVar (nil) is not stored and not written', function()
    Boot({ flags = { ore = true }, unreadable = { SoftTargetIconGameObject = true } })
    W.ns.ApplyHighlights()
    local saved = QuietUIDB.highlightCVars
    assert(type(saved) == 'table', 'The readable originals were not stored')
    assert(saved.SoftTargetIconGameObject == nil, 'An unreadable CVar was stored')
    assert(saved.SoftTargetInteract == '1', 'A readable original was not stored')
    for _, w in ipairs(W.writes) do
        assert(w[1] ~= 'SoftTargetIconGameObject', 'An unreadable CVar was written')
    end
    assert(W.cvars.SoftTargetInteract == '3', 'A readable CVar was not set')
    W.flags.ore = false
    W.ns.ApplyHighlights()
    for _, w in ipairs(W.writes) do
        assert(w[1] ~= 'SoftTargetIconGameObject', 'An unreadable CVar was written on restore')
    end
    assert(W.cvars.SoftTargetInteract == '1', 'A readable CVar was not restored')
end)

test('A CVar read that throws is not stored and not written', function()
    Boot({ flags = { ore = true }, unreadable = { SoftTargetInteractRange = 'error' } })
    W.ns.ApplyHighlights()
    local saved = QuietUIDB.highlightCVars or {}
    assert(saved.SoftTargetInteractRange == nil, 'A failing CVar read was stored')
    for _, w in ipairs(W.writes) do
        assert(w[1] ~= 'SoftTargetInteractRange', 'A CVar with a failing read was written')
    end
end)

-- Glow ------------------------------------------------------------------------------------

test('Ore target with the mine icon shows a gold glow on its plate', function()
    local plate = OreShown()
    local glow = ShownOn(plate)
    assert(glow, 'Nothing is shown on the target plate')
    local root = Glow()
    assert(root and root.parent == plate, 'The glow is not parented to the plate')
    local last = root.points[#root.points]
    assert(last, 'The glow has no anchor')
    assert(#root.points == 1, 'ClearAllPoints was not called before anchoring')
    assert(last[1] == 'CENTER' and last[2] == plate.soft and (last[3] == 'CENTER' or last[3] == nil),
        'The glow is not anchored to the SoftTargetFrame center')
    assert(HasColor(root, ORE), 'No texture uses the ore color 0.95, 0.75, 0.25')
    assert(root.levelSet and root.level < plate.soft:GetFrameLevel(),
        'The glow frame level is not below the SoftTargetFrame')
    assert(root.mouse == false, 'The glow does not disable the mouse')
    assert(LoopsPlaying(root), 'No looping animation plays on the shown glow')
    assert(next(W.reports) == nil, 'Report was called on the happy path')
end)

test('Mixed-case mine texture is recognized', function()
    local plate = OreShown('interface/cursor/CURSOR CROSSHAIR_MINE_64')
    assert(ShownOn(plate), 'Upper-case mine texture was not recognized')
    plate = OreShown('cursor crosshair_mine_64')
    assert(ShownOn(plate), 'Lower-case mine texture was not recognized')
end)

test('Out-of-reach mine texture is recognized', function()
    local plate = OreShown('Cursor Crosshair_UnableMine_64')
    assert(ShownOn(plate), 'The out-of-reach mine texture was not recognized')
end)

test('A non-crosshair texture containing mine shows nothing', function()
    local plate = OreShown('Interface/Icons/INV_Misc_Determine_01')
    assert(not ShownOn(plate), 'A texture that only contains mine was treated as ore')
end)

test('Re-evaluating a shown glow does not restart its animations', function()
    OreShown()
    local root = Glow()
    local before = {}
    for i, g in ipairs(W.groups) do before[i] = g.plays end
    Target('GameObject-0-1-2-3-1731-0001', nil, 'GameObject-0-1-2-3-1731-0001')
    event('PLAYER_REGEN_ENABLED')
    for i, g in ipairs(W.groups) do
        assert(g.plays == before[i], 'An animation was played again on a glow that was already shown')
    end
    assert(LoopsPlaying(root), 'The glow stopped playing')
end)

test('GetAtlas is the fallback when GetTexture is empty', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', nil, { atlas = MINE })
    Target('GameObject-A', nil, 'GameObject-A')
    assert(ShownOn(plate), 'The atlas fallback was not used')
end)

for _, c in ipairs({
    { 'herb', HERBS },
    { 'out-of-reach herb', HERBS_FAR },
    { 'interact', 'Cursor Crosshair_Interact_64' },
    { 'missing', nil },
    { 'numeric', 136243 },
}) do
    test('Only Ore on and a ' .. c[1] .. ' texture shows nothing', function()
        OreShown(c[2])
        event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(NothingShown(), 'Something was shown for a ' .. c[1] .. ' texture')
    end)
end

for _, c in ipairs({ { 'herb', HERBS }, { 'out-of-reach herb', HERBS_FAR }, { 'upper-case herb', 'CURSOR CROSSHAIR_GATHERHERBS_64' } }) do
    test('Herbs on and a ' .. c[1] .. ' texture shows a green glow', function()
        Boot({ flags = { herb = true } })
        W.ns.ApplyHighlights()
        AssertCVars(WANT, 'Herbs on')
        local plate = AddPlate('nameplate1', 'GameObject-H', c[2])
        Target('GameObject-H', nil, 'GameObject-H')
        assert(ShownOn(plate), 'Nothing is shown for a ' .. c[1] .. ' target')
        local root = Glow()
        assert(root and root.parent == plate, 'The herb glow is not parented to the plate')
        assert(HasColor(root, HERB), 'No texture uses the herb color 0.30, 0.74, 0.40')
        assert(not HasColor(root, ORE), 'The herb glow still uses the ore color')
        assert(LoopsPlaying(root), 'No looping animation plays on the herb glow')
    end)
end

test('Only Herbs on and the mine icon shows nothing', function()
    Boot({ flags = { herb = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(NothingShown(), 'A mine target was highlighted with only Herbs on')
end)

test('Changing from an ore to a herb target switches the color', function()
    Boot({ flags = { herb = true, ore = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    local h = AddPlate('nameplate2', 'GameObject-H', HERBS)
    Target('GameObject-H', 'GameObject-A', 'GameObject-H')
    assert(ShownOn(h), 'The herb target was not shown')
    local root = Glow()
    assert(root.parent == h, 'The glow did not move to the herb plate')
    assert(HasColor(root, HERB), 'The color did not switch to herb green')
end)

test('Herb and Quest on show nothing for the mine icon', function()
    Boot({ flags = { herb = true, quest = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    assert(NothingShown(), 'A mine target was highlighted with Ore off')
end)

-- Generic interact objects retain the legacy quest flag. -----------------------------------

for _, texture in ipairs({ 'Cursor Crosshair_Interact_64', 'CURSOR CROSSHAIR_INTERACT_64',
    'Cursor Crosshair_UnableInteract_64', 'CURSOR CROSSHAIR_UNABLEINTERACT_64' }) do
    test('Interact objects recognizes ' .. texture .. ' with warm-white particles', function()
        Boot({ flags = { quest = true } })
        W.ns.ApplyHighlights()
        local plate = AddPlate('nameplate1', 'GameObject-Interact', texture)
        Target('GameObject-Interact', nil, 'GameObject-Interact')
        assert(ShownOn(plate), 'The generic gear object was not highlighted')
        assert(HasColor(Glow(), { 0.78, 0.76, 0.70 }), 'The interact glow is not warm white')
        assert(plate.soft.Icon.alpha == 0, 'The gear icon is still visible')
        assert(LoopsPlaying(Glow()), 'The interact particles are not animated')
        W.ns.RestoreHighlights()
        assert(plate.soft.Icon.alpha == 1, 'The gear icon was not restored')
    end)
end

for _, texture in ipairs({ HERBS, MINE, 'Cursor Crosshair_Speak_64' }) do
    test('Only Interact objects does not highlight ' .. texture, function()
        Boot({ flags = { quest = true } })
        W.ns.ApplyHighlights()
        local plate = AddPlate('nameplate1', 'GameObject-Other', texture)
        Target('GameObject-Other', nil, 'GameObject-Other')
        assert(NothingShown(), 'An unrelated category was highlighted')
        assert(plate.soft.Icon.alpha == 1, 'An unrelated icon was hidden')
    end)
end

-- Finding the plate -----------------------------------------------------------------------

test('Target found through NAME_PLATE_UNIT_ADDED after the target event', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    Target('GameObject-A', nil, 'GameObject-A')
    assert(NothingShown(), 'Something was shown before the plate exists')
    AddPlate('nameplate3', 'GameObject-B', MINE)
    event('NAME_PLATE_UNIT_ADDED', 'nameplate3')
    assert(NothingShown(), 'A plate of another object was highlighted')
    local plate = AddPlate('nameplate4', 'GameObject-A', MINE)
    event('NAME_PLATE_UNIT_ADDED', 'nameplate4')
    assert(ShownOn(plate), 'The added plate of the target was not highlighted')
end)

test('Target found by scanning GetNamePlates on PLAYER_SOFT_INTERACT_CHANGED', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-B', MINE)
    local plate = AddPlate('nameplate2', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    assert(ShownOn(plate), 'The scanned plate of the target was not highlighted')
end)

test('Scan falls back to namePlateUnitToken when UnitFrame.unit is missing', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate2', 'GameObject-A', MINE, { noUnitToken = true })
    Target('GameObject-A', nil, 'GameObject-A')
    assert(ShownOn(plate), 'namePlateUnitToken was not used')
end)

test('Target GUID falls back to UnitGUID("softinteract")', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A')
    assert(ShownOn(plate), 'UnitGUID("softinteract") was not used without event args')
end)

test('Changing target re-reads the texture and moves the anchor', function()
    local a = OreShown()
    assert(ShownOn(a), 'The first target was not shown')
    local before = #W.created
    AddPlate('nameplate2', 'GameObject-B', 'Cursor Crosshair_Interact_64')
    Target('GameObject-B', 'GameObject-0-1-2-3-1731-0001', 'GameObject-B')
    AssertHiddenAtUIParent()
    local c = AddPlate('nameplate3', 'GameObject-C', MINE)
    Target('GameObject-C', 'GameObject-B', 'GameObject-C')
    assert(ShownOn(c), 'The new target was not shown')
    local root = Glow()
    assert(root.parent == c, 'The glow did not move to the new plate')
    local last = root.points[#root.points]
    assert(#root.points == 1 and last[2] == c.soft, 'The glow is not anchored to the new SoftTargetFrame')
    assert(not ShownOn(a), 'The old plate still shows the glow')
    assert(#W.created == before, 'The glow frames were created again')
end)

test('Same plate with a changed icon is re-read on the next target event', function()
    local plate = OreShown()
    plate.soft.Icon.texture = 'Cursor Crosshair_Interact_64'
    Target('GameObject-0-1-2-3-1731-0001', 'GameObject-0-1-2-3-1731-0001', 'GameObject-0-1-2-3-1731-0001')
    assert(NothingShown(), 'A stale texture was used')
end)

test('Nil target hides and returns the frame to UIParent at once', function()
    OreShown()
    Target(nil, 'GameObject-0-1-2-3-1731-0001', nil)
    AssertHiddenAtUIParent()
end)

test('Removing the anchor plate hides at once; an unrelated removal does nothing', function()
    local plate = OreShown()
    AddPlate('nameplate9', 'Creature-X', nil)
    RemovePlate('nameplate9')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate9')
    assert(ShownOn(plate), 'An unrelated plate removal hid the glow')
    assert(Glow().parent == plate, 'An unrelated plate removal moved the glow')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    RemovePlate('nameplate1')
    AssertHiddenAtUIParent()
end)

-- Icon ownership --------------------------------------------------------------------------

test('Highlighted icon stays hidden across Blizzard alpha writes without losing its texture', function()
    local plate = OreShown()
    local icon = plate.soft.Icon
    assert(icon.alpha == 0, 'The overhead icon is still visible')
    assert(icon.texture == MINE, 'The category texture was removed')
    icon:SetAlpha(1)
    assert(icon.alpha == 0, 'Blizzard revealed the held icon')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(ShownOn(plate), 'Hiding the icon broke category detection')
    W.ns.RestoreHighlights()
    assert(icon.alpha == 1, 'The original icon alpha was not restored')
    icon:SetAlpha(0.6)
    assert(icon.alpha == 0.6, 'The icon hook still holds after restore')
end)

test('Changing to an unrelated object restores the old icon and leaves the new one alone', function()
    local old = OreShown()
    local other = AddPlate('nameplate2', 'Creature-B', 'Cursor Crosshair_Interact_64')
    Target('Creature-B', nil, 'Creature-B')
    assert(old.soft.Icon.alpha == 1, 'The previous icon was not restored')
    assert(other.soft.Icon.alpha == 1, 'An unrelated interact icon was hidden')
end)

test('Icon restore preserves a partial alpha and captures a fresh value on reuse', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', MINE)
    local icon = plate.soft.Icon
    icon:SetAlpha(0.4)
    Target('GameObject-A', nil, 'GameObject-A')
    assert(icon.alpha == 0, 'The partial alpha icon was not hidden')
    Target(nil, 'GameObject-A', nil)
    assert(icon.alpha == 0.4, 'The partial alpha was not restored')
    icon:SetAlpha(0.7)
    Target('GameObject-A', nil, 'GameObject-A')
    W.flags.ore = false
    W.ns.ApplyHighlights()
    assert(icon.alpha == 0.7, 'Reusing a plate restored a stale alpha')
end)

test('Removing the highlighted plate releases the icon hold', function()
    local plate = OreShown()
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(plate.soft.Icon.alpha == 1, 'Plate removal did not restore the icon')
    plate.soft.Icon:SetAlpha(0.8)
    assert(plate.soft.Icon.alpha == 0.8, 'The removed icon is still held')
end)

test('Combat keeps the icon hidden; instances restore it', function()
    local plate = OreShown()
    event('PLAYER_REGEN_DISABLED')
    assert(plate.soft.Icon.alpha == 0, 'Combat revealed the highlighted icon')
    event('PLAYER_REGEN_ENABLED')
    assert(plate.soft.Icon.alpha == 0, 'Leaving combat did not hide the icon again')
    W.instance = 'party'
    event('PLAYER_ENTERING_WORLD')
    assert(plate.soft.Icon.alpha == 1, 'Entering an instance did not restore the icon')
end)

test('An older CVar snapshot captures the arc before changing it', function()
    local saved, cvars = {}, {}
    for name, value in pairs(ORIGINAL) do saved[name] = value end
    for name, value in pairs(WANT) do cvars[name] = value end
    saved.SoftTargetInteractArc = nil
    cvars.SoftTargetInteractArc = '1'
    Boot({ flags = { ore = true }, saved = saved, cvars = cvars })
    W.ns.ApplyHighlights()
    assert(QuietUIDB.highlightCVars.SoftTargetInteractArc == '1', 'The existing arc was not saved')
    assert(W.cvars.SoftTargetInteractArc == '2', 'The wider arc was not applied')
    W.ns.RestoreHighlights()
    assert(W.cvars.SoftTargetInteractArc == '1', 'The existing arc was not restored')
end)

-- Combat ----------------------------------------------------------------------------------

test('Combat keeps the glow and particles without CVar changes', function()
    local plate = OreShown()
    local writes = #W.writes
    W.inCombat = true
    event('PLAYER_REGEN_DISABLED')
    assert(ShownOn(plate), 'Entering combat hid the glow')
    assert(LoopsPlaying(Glow()), 'Entering combat stopped the particles')
    assert(plate.soft.Icon.alpha == 0, 'Entering combat revealed the icon')
    assert(#W.writes == writes, 'Entering combat wrote a CVar')
    W.inCombat = false
    event('PLAYER_REGEN_ENABLED')
    assert(ShownOn(plate), 'The glow did not return after combat')
    assert(#W.writes == writes, 'Leaving combat rewrote unchanged CVars')
    AssertCVars(WANT, 'After combat')
end)

test('Combat event alone keeps the glow visible', function()
    local plate = OreShown()
    event('PLAYER_REGEN_DISABLED')
    assert(ShownOn(plate), 'Combat event hid the glow')
end)

for _, category in ipairs({ { 'herb', HERBS }, { 'ore', MINE },
    { 'quest', 'Cursor Crosshair_UnableInteract_64' } }) do
    test(category[1] .. ' target and late plate changes work during combat', function()
        Boot({ flags = { [category[1]] = true } })
        W.ns.ApplyHighlights()
        W.inCombat = true
        event('PLAYER_REGEN_DISABLED')
        local writes = #W.writes
        Target('GameObject-A', nil, 'GameObject-A')
        local plate = AddPlate('nameplate1', 'GameObject-A', category[2])
        event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(ShownOn(plate), 'A new target plate was not highlighted during combat')
        assert(LoopsPlaying(Glow()), 'Combat particles are not playing')
        assert(plate.soft.Icon.alpha == 0, 'Combat target icon was not hidden')
        Target(nil, 'GameObject-A', nil)
        AssertHiddenAtUIParent()
        assert(plate.soft.Icon.alpha == 1, 'Losing a combat target did not restore its icon')
        assert(#W.writes == writes, 'Combat target changes wrote CVars')
    end)
end

test('CVar change requested in combat waits for PLAYER_REGEN_ENABLED', function()
    Boot({ flags = { ore = true } })
    W.inCombat = true
    W.ns.ApplyHighlights()
    assert(#W.writes == 0, 'A CVar was written in combat')
    assert(QuietUIDB.highlightCVars == nil, 'Originals were stored in combat before any write')
    W.inCombat = false
    event('PLAYER_REGEN_ENABLED')
    AssertCVars(WANT, 'After combat')
    AssertSaved(ORIGINAL)
end)

test('Deferred change applies the then-current state after combat', function()
    Boot({ flags = { ore = true } })
    W.inCombat = true
    W.ns.ApplyHighlights()
    W.flags.ore = false
    W.ns.ApplyHighlights()
    W.inCombat = false
    event('PLAYER_REGEN_ENABLED')
    assert(#W.writes == 0, 'An outdated combat request was applied')
    AssertCVars(ORIGINAL, 'After combat')
end)

test('RestoreHighlights in combat defers the CVar restore', function()
    OreShown()
    W.inCombat = true
    event('PLAYER_REGEN_DISABLED')
    local writes = #W.writes
    QuietUIDB.enabled = false
    W.ns.RestoreHighlights()
    assert(#W.writes == writes, 'RestoreHighlights wrote CVars in combat')
    AssertHiddenAtUIParent()
    W.inCombat = false
    event('PLAYER_REGEN_ENABLED')
    AssertCVars(ORIGINAL, 'After combat restore')
    assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was not cleared after combat')
end)

-- Instances -------------------------------------------------------------------------------

local function InstanceCase(kind, enter)
    test('Entering a ' .. kind .. ' instance via ' .. enter .. ' hides and restores; leaving sets again', function()
        OreShown()
        W.instance = kind
        if enter == 'ApplyHighlights' then W.ns.ApplyHighlights() else event(enter) end
        AssertHiddenAtUIParent()
        AssertCVars(ORIGINAL, 'Inside ' .. kind)
        assert(QuietUIDB.highlightCVars == nil, 'highlightCVars was not cleared inside ' .. kind)
        W.instance = 'none'
        if enter == 'ApplyHighlights' then W.ns.ApplyHighlights() else event(enter) end
        AssertCVars(WANT, 'After leaving ' .. kind)
        AssertSaved(ORIGINAL)
    end)
end
for _, kind in ipairs({ 'party', 'raid', 'pvp', 'arena' }) do InstanceCase(kind, 'ApplyHighlights') end
InstanceCase('party', 'PLAYER_ENTERING_WORLD')
InstanceCase('raid', 'ZONE_CHANGED_NEW_AREA')

test('A scenario instance is not one of the blocked types', function()
    Boot({ flags = { ore = true } })
    W.instance = 'scenario'
    W.ns.ApplyHighlights()
    AssertCVars(WANT, 'In a scenario')
end)

-- Missing or hostile client pieces --------------------------------------------------------

test('Missing C_CVar: no error, reported, nothing written', function()
    Boot({ flags = { ore = true }, noCVar = true })
    W.ns.ApplyHighlights()
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    W.ns.RestoreHighlights()
    assert(next(W.reports), 'Missing C_CVar was not reported')
end)

test('Missing C_NamePlate: no error, reported, nothing shown', function()
    Boot({ flags = { ore = true }, noNamePlate = true })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(next(W.reports), 'Missing C_NamePlate was not reported')
    assert(NothingShown(), 'Something was shown without C_NamePlate')
end)

test('Missing SoftTargetFrame: no error, reported, nothing shown', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE, { noSoftTarget = true })
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(next(W.reports), 'Missing SoftTargetFrame was not reported')
    assert(NothingShown(), 'Something was shown without SoftTargetFrame')
end)

test('Missing CreateAnimationGroup: no error, reported', function()
    Boot({ flags = { ore = true }, noAnimations = true })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', MINE)
    Target('GameObject-A', nil, 'GameObject-A')
    Target(nil, 'GameObject-A', nil)
    Target('GameObject-A', nil, 'GameObject-A')
    assert(next(W.reports), 'Missing CreateAnimationGroup was not reported')
end)

test('Forbidden plate is skipped without calling its methods', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local proxy = forbiddenProxy()
    W.plates[#W.plates + 1] = { token = 'nameplate1', plate = proxy }
    W.tokens.nameplate1 = 'GameObject-A'
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(W.forbiddenCalls == 0, 'A forbidden plate had ' .. W.forbiddenCalls .. ' method calls')
    assert(NothingShown(), 'Something was shown on a forbidden plate')
end)

test('Unknown event is ignored without error', function()
    OreShown()
    event('SOME_UNKNOWN_EVENT', 'x')
end)

-- Re-enable and late icons ---------------------------------------------------------------

test('Re-enable after the soft target changed while off shows the new target', function()
    local a = OreShown()
    assert(ShownOn(a), 'The first target was not shown')
    W.ns.RestoreHighlights()
    AssertHiddenAtUIParent()
    -- While off no events arrive; the game picked another object meanwhile.
    local b = AddPlate('nameplate2', 'GameObject-B', MINE)
    W.softGUID = 'GameObject-B'
    W.ns.ApplyHighlights()
    assert(ShownOn(b), 'The new soft target was not shown after re-enable (stale GUID kept)')
    assert(not ShownOn(a), 'The stale target still shows the glow')
end)

test('Re-enable with no soft target any more shows nothing', function()
    OreShown()
    W.ns.RestoreHighlights()
    W.softGUID = nil
    W.ns.ApplyHighlights()
    assert(NothingShown(), 'A stale target was shown after re-enable')
end)

test('Icon filled one frame after the target event shows after the re-check', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', nil)
    Target('GameObject-A', nil, 'GameObject-A')
    assert(NothingShown(), 'Something was shown with an empty icon')
    assert(#W.timers >= 1, 'No next-frame re-check was scheduled after the target event')
    for _, t in ipairs(W.timers) do assert(t.delay == 0, 'The re-check must run on the next frame (delay 0)') end
    plate.soft.Icon.texture = MINE
    RunTimers()
    assert(ShownOn(plate), 'The re-check did not show the glow for the late icon')
end)

test('Icon filled one frame after NAME_PLATE_UNIT_ADDED shows after the re-check', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    Target('GameObject-A', nil, 'GameObject-A')
    RunTimers()
    local plate = AddPlate('nameplate4', 'GameObject-A', nil)
    local before = #W.timers
    event('NAME_PLATE_UNIT_ADDED', 'nameplate4')
    assert(NothingShown(), 'Something was shown with an empty icon')
    assert(#W.timers > before, 'No next-frame re-check was scheduled after the plate was added')
    plate.soft.Icon.texture = MINE
    RunTimers()
    assert(ShownOn(plate), 'The re-check did not show the glow for the late plate icon')
end)

test('A newer target event cancels the older pending re-check', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    AddPlate('nameplate1', 'GameObject-A', nil)
    local b = AddPlate('nameplate2', 'GameObject-B', nil)
    Target('GameObject-A', nil, 'GameObject-A')
    local first = #W.timers
    assert(first >= 1, 'No re-check was scheduled for the first target')
    Target('GameObject-B', 'GameObject-A', 'GameObject-B')
    assert(#W.timers > first, 'No re-check was scheduled for the second target')
    b.soft.Icon.texture = MINE
    RunTimers(1, first)
    assert(NothingShown(), 'An outdated re-check still evaluated')
    RunTimers(first + 1)
    assert(ShownOn(b), 'The newest re-check did not show the glow')
end)

test('RestoreHighlights cancels a pending re-check', function()
    Boot({ flags = { ore = true } })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', nil)
    Target('GameObject-A', nil, 'GameObject-A')
    W.ns.RestoreHighlights()
    plate.soft.Icon.texture = MINE
    RunTimers()
    assert(NothingShown(), 'A re-check after restore showed the glow')
end)

test('Missing C_Timer: late icon events do not error', function()
    Boot({ flags = { ore = true }, noTimer = true })
    W.ns.ApplyHighlights()
    local plate = AddPlate('nameplate1', 'GameObject-A', nil)
    Target('GameObject-A', nil, 'GameObject-A')
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    assert(NothingShown(), 'Something was shown with an empty icon')
    plate.soft.Icon.texture = MINE
    Target('GameObject-A', 'GameObject-A', 'GameObject-A')
    assert(ShownOn(plate), 'The next target event did not show the glow')
end)

-- Textures --------------------------------------------------------------------------------

test('The aura uses Media/glow.tga, glints Media/glint.tga and sparks Media/spark.tga, all on disk', function()
    local plate = OreShown()
    local root = Glow()
    assert(root and root.parent == plate, 'The glow was not shown')
    local glow, spark, round, glint = 0, 0, 0, 0
    for _, t in ipairs(W.textures) do
        if within(t, root) and type(t.texture) == 'string' then
            local path = t.texture:lower()
            if path == 'interface\\addons\\quietui\\media\\glow.tga' then glow = glow + 1 end
            if path == 'interface\\addons\\quietui\\media\\spark.tga' then spark = spark + 1 end
            if path == 'interface\\addons\\quietui\\media\\glint.tga' then glint = glint + 1 end
            assert(not path:find('ripple.tga', 1, true), 'The unwanted ground ripple is still present')
            if path:find('round.tga', 1, true) then round = round + 1 end
        end
    end
    assert(glow >= 1, 'No aura texture uses Media/glow.tga')
    assert(spark == 4, 'Expected four small motes, got ' .. spark)
    assert(glint == 3, 'Expected three four-point glints')
    assert(round == 0, 'The glow still uses Media/round.tga')
    for _, file in ipairs({ 'Media/glow.tga', 'Media/spark.tga', 'Media/glint.tga' }) do
        local f = io.open(file, 'rb')
        assert(f, file .. ' does not exist')
        f:close()
    end
end)

-- Hygiene ---------------------------------------------------------------------------------

test('Plates are never moved, faded, shown or hidden through a full cycle', function()
    local plate = OreShown()
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    W.inCombat = true
    event('PLAYER_REGEN_DISABLED')
    W.inCombat = false
    event('PLAYER_REGEN_ENABLED')
    Target(nil, 'GameObject-0-1-2-3-1731-0001', nil)
    Target('GameObject-0-1-2-3-1731-0001', nil, 'GameObject-0-1-2-3-1731-0001')
    W.ns.RestoreHighlights()
    assert(plate.alpha == 1 and plate.shown, 'The plate changed state')
    assert(#plate.soft.points == 0, 'The SoftTargetFrame was moved')
    -- Plate violations and OnUpdate are asserted after every case.
end)

io.write(string.format('%d cases, %d failed\n', cases, failures))
if failures > 0 then os.exit(1) end
