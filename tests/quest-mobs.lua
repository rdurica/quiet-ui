-- Run from the addon directory: lua tests/quest-mobs.lua
-- QuestMobs.lua in isolation: the quest icon left of an attackable quest mob's nameplate,
-- chosen from UnitIsRelatedToActiveQuest, tooltip data lines and the quest log objectives.
local failures, cases = 0, 0
local out = print

local PLATE_FORBIDDEN = { SetAlpha = true, SetPoint = true, ClearAllPoints = true, Show = true, Hide = true }
local SECRET = { secret = true }
local TITLE, OBJECTIVE = 17, 8
local KILL_Q, LOOT_Q, OTHER_Q = 101, 102, 103

-- Per-test world state, rebuilt by Boot().
local W

local function noop() end

local function count(list, key)
    return list[key] or 0
end

local newTexture
local function newFrame(parent, opts)
    opts = opts or {}
    local f = { parent = parent, shown = true, alpha = 1, scripts = {}, points = {}, plate = opts.plate,
        name = opts.name, height = opts.height or 10 }
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
    function f:SetParent(p) guard('SetParent'); self.parent = p end
    function f:ClearAllPoints() guard('ClearAllPoints'); self.points = {} end
    function f:SetPoint(...) guard('SetPoint'); self.points[#self.points + 1] = { ... } end
    function f:SetAllPoints(...) guard('SetAllPoints'); self.points[#self.points + 1] = { 'ALL', ... } end
    function f:GetHeight() return self.height end
    function f:GetWidth() return self.height * 8 end
    function f:GetSize() return self.height * 8, self.height end
    function f:GetFrameLevel() return 1 end
    -- Requested size, kept apart from the fixture height that GetHeight reports.
    function f:SetSize(w, h) rawset(self, 'sizeW', w); rawset(self, 'sizeH', h or w) end
    function f:SetWidth(w) rawset(self, 'sizeW', w) end
    function f:SetHeight(h) rawset(self, 'sizeH', h) end
    function f:EnableMouse(v) self.mouse = v end
    function f:IsMouseEnabled() return self.mouse == true end
    function f:SetScript(name, fn)
        self.scripts[name] = fn
        if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = f.name or 'frame' end
    end
    function f:GetScript(name) return self.scripts[name] end
    function f:HookScript(name, fn)
        if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = f.name or 'frame' end
    end
    function f:CreateTexture()
        local t = newTexture(self)
        W.objects[#W.objects + 1] = t
        return t
    end
    function f:CreateAnimationGroup()
        local g = setmetatable({}, { __index = function() return noop end })
        function g:SetScript(name, fn)
            if name == 'OnUpdate' and fn then W.onUpdate[#W.onUpdate + 1] = 'animation group' end
        end
        return g
    end
    -- Fields a frame may lack must read as nil, not as the catch-all method.
    setmetatable(f, { __index = function(_, k)
        if k == 'plate' or k == 'parent' or k == 'name' or k == 'texture' or k == 'mouse'
            or k == 'UnitFrame' or k == 'healthBar' or k == 'HealthBar' or k == 'namePlateUnitToken' or k == 'unit'
            or k:find('^_quiet') then return nil end
        return noop
    end })
    return f
end

newTexture = function(parent)
    local t = newFrame(parent)
    t.isTexture = true
    function t:SetTexture(v) self.texture = v end
    function t:GetTexture() return self.texture end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetTexCoord() end
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

local function record(name, arg)
    W.calls[name] = W.calls[name] or {}
    W.calls[name][arg] = (W.calls[name][arg] or 0) + 1
    W.total[name] = (W.total[name] or 0) + 1
end

local function Boot(opts)
    opts = opts or {}
    W = { objects = {}, onUpdate = {}, plateViolations = {}, forbiddenCalls = 0, prints = {}, plates = {},
        units = {}, objectives = {}, calls = {}, total = {}, timers = {}, inCombat = false,
        instance = opts.instance or 'none', on = opts.on ~= false, glance = false, showAll = false, editMode = false }

    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        W.prints[#W.prints + 1] = table.concat(parts, ' ')
    end
    unpack = unpack or table.unpack
    issecretvalue = function(value) return type(value) == 'table' and value.secret == true end
    GetTime = function() return 100 end
    UIParent = newFrame(nil, { name = 'UIParent' })
    CreateFrame = function(_, _, parent)
        local f = newFrame(parent)
        W.objects[#W.objects + 1] = f
        return f
    end
    InCombatLockdown = function() return W.inCombat end
    IsInInstance = function()
        if W.instance == 'none' then return false, 'none' end
        return true, W.instance
    end
    UnitGUID = function(unit) return W.units[unit] and ('Creature-0-1-2-3-' .. unit) or nil end
    UnitExists = function(unit) return W.units[unit] ~= nil end
    UnitCanAttack = function(a, b)
        record('UnitCanAttack', b)
        assert(a == 'player', 'UnitCanAttack must be asked for the player, got ' .. tostring(a))
        local u = W.units[b]
        if u then return u.attack end
        return false
    end
    GameTooltip = setmetatable({}, { __index = function(_, k)
        return function() error('GameTooltip.' .. tostring(k) .. ' must never be used') end
    end })

    C_QuestLog = {}
    if not opts.noRelated then
        C_QuestLog.UnitIsRelatedToActiveQuest = function(unit)
            record('Related', unit)
            local u = W.units[unit]
            if u then return u.related end
            return false
        end
    end
    if not opts.noObjectives then
        C_QuestLog.GetQuestObjectives = function(questID)
            record('Objectives', questID)
            return W.objectives[questID]
        end
    end
    if opts.noTooltipInfo then
        C_TooltipInfo = nil
    else
        C_TooltipInfo = {}
        if not opts.noGetUnit then
            C_TooltipInfo.GetUnit = function(unit)
                record('GetUnit', unit)
                local u = W.units[unit]
                if not u or u.lines == nil then return nil end
                return { lines = u.lines }
            end
        end
    end
    C_NamePlate = {
        GetNamePlateForUnit = function(token)
            record('GetNamePlateForUnit', token)
            for _, p in ipairs(W.plates) do
                if p.token == token then return p.plate end
            end
        end,
        GetNamePlates = function()
            record('GetNamePlates', 'all')
            local list = {}
            for _, p in ipairs(W.plates) do list[#list + 1] = p.plate end
            return list
        end,
    }
    GetNamePlateForUnit = nil
    -- C_Timer.After only collects callbacks; NextFrame runs them like the next frame.
    if opts.noTimer then
        C_Timer = nil
    else
        C_Timer = { After = function(delay, fn) W.timers[#W.timers + 1] = { delay = delay, fn = fn } end }
    end

    QuietUIDB = { enabled = opts.enabled ~= false }
    QuietUICharDB = {}
    local ns = {}
    assert(loadfile('Core.lua'))('QuietUI', ns)
    ns.QuestMobs = function() return W.on end
    ns.ShowAll = function() return W.showAll end
    ns.Glancing = function() return W.glance end
    ns.EditMode = function() return W.editMode end
    local chunk, err = loadfile('QuestMobs.lua')
    assert(chunk, 'QuestMobs.lua could not be loaded: ' .. tostring(err))
    chunk('QuietUI', ns)
    assert(type(ns.ApplyQuestMobs) == 'function', 'ns.ApplyQuestMobs is missing')
    assert(type(ns.RestoreQuestMobs) == 'function', 'ns.RestoreQuestMobs is missing')
    assert(type(ns.QuestMobsEvent) == 'function', 'ns.QuestMobsEvent is missing')
    W.ns = ns
    return ns
end

-- Tooltip data lines.
local function Q(id, title) return { type = TITLE, id = id, leftText = title or ('Quest ' .. id) } end
local function O(text) return { type = OBJECTIVE, leftText = text } end
local function Name(text) return { type = 2, leftText = text } end

local KOBOLD = { Name('Kobold Vermin'), Q(KILL_Q, 'Kobold Clearing'), O('0/10 Kobold Vermin slain') }
local WOLF = { Name('Timber Wolf'), Q(LOOT_Q, 'Wolves Across the Border'), O('4/8 Tough Wolf Meat') }

local function Quests()
    W.objectives[KILL_Q] = { { text = 'Kobold Vermin slain: 0/10', type = 'monster', finished = false } }
    W.objectives[LOOT_Q] = { { text = 'Tough Wolf Meat: 4/8', type = 'item', finished = false } }
end

-- A nameplate for token. spec: attack (default true), related (default true), lines (tooltip lines).
local function AddPlate(token, spec, opts)
    opts = opts or {}
    spec = spec or {}
    local plate = newFrame(UIParent, { plate = true, name = token })
    local unitFrame = newFrame(plate, { plate = true, name = token .. '.UnitFrame' })
    plate.UnitFrame = unitFrame
    unitFrame.unit = token
    plate.namePlateUnitToken = token
    if not opts.noHealthBar then
        local bar = newFrame(unitFrame, { plate = true, name = token .. '.healthBar', height = opts.barHeight or 8 })
        unitFrame.healthBar = bar
        plate.bar = bar
    end
    W.plates[#W.plates + 1] = { token = token, plate = plate }
    local unit = { attack = true, related = true, lines = spec.lines }
    if spec.attack ~= nil or spec.noAttack then unit.attack = spec.attack end
    if spec.related ~= nil or spec.noRelated then unit.related = spec.related end
    W.units[token] = unit
    return plate
end

local function RemovePlate(token)
    for i, p in ipairs(W.plates) do
        if p.token == token then table.remove(W.plates, i) break end
    end
    W.units[token] = nil
end

local function event(name, ...) W.ns.QuestMobsEvent(name, ...) end

local function Add(token, spec, opts)
    local plate = AddPlate(token, spec, opts)
    event('NAME_PLATE_UNIT_ADDED', token)
    return plate
end

local function Remove(token)
    RemovePlate(token)
    event('NAME_PLATE_UNIT_REMOVED', token)
end

-- Runs every timer callback collected so far, like the next frame. Later timers wait.
local function NextFrame()
    local list, n = W.timers, #W.timers
    for i = 1, n do
        local t = list[i]
        if not t.ran then t.ran = true; t.fn() end
    end
end

local function Pending()
    local n = 0
    for _, t in ipairs(W.timers) do if not t.ran then n = n + 1 end end
    return n
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

local function Kind(path)
    if type(path) ~= 'string' then return end
    path = path:lower():gsub('\\', '/')
    if path:find('media/quest%-kill') then return 'kill' end
    if path:find('media/quest%-loot') then return 'loot' end
end

-- The visible quest icon on plate: 'kill', 'loot' or nil. Never more than one.
local function IconOn(plate)
    local found, tex = nil, nil
    local n = 0
    for _, o in ipairs(W.objects) do
        local kind = o.isTexture and Kind(o.texture)
        if kind and within(o, plate) and visible(o) then
            n = n + 1
            found, tex = kind, o
        end
    end
    assert(n <= 1, 'Expected at most one quest icon on ' .. tostring(plate.name) .. ', got ' .. n)
    return found, tex
end

local function OnPlate(plate)
    for _, p in ipairs(W.plates) do
        if p.plate == plate then return true end
    end
    return false
end

-- Our objects attached directly to a frame of plate (the plate itself, UnitFrame or the health bar).
local function RootsOn(plate)
    local list = {}
    for _, o in ipairs(W.objects) do
        if o.parent and o.parent ~= UIParent and rawget(o.parent, 'plate') and within(o.parent, plate) then
            list[#list + 1] = o
        end
    end
    return list
end

local function AnchoredRightToLeftOf(o, target)
    for _, p in ipairs(o.points) do
        local rel = p[2]
        if p[1] == 'RIGHT' and rel == target and p[3] == 'LEFT' then return true end
    end
    return false
end

local function Reports()
    local n = 0
    for _, line in ipairs(W.prints) do
        if line:find('error', 1, true) then n = n + 1 end
    end
    return n
end

local function NothingShown()
    for _, o in ipairs(W.objects) do
        if o.isTexture and Kind(o.texture) and visible(o) then return false end
    end
    return true
end

local function test(name, fn)
    cases = cases + 1
    local ok, err = pcall(function()
        fn()
        assert(W, 'Boot was not called')
        assert(#W.plateViolations == 0, 'Plate frames were touched: ' .. table.concat(W.plateViolations, ', '))
        assert(#W.onUpdate == 0, 'An OnUpdate script was set on ' .. tostring(W.onUpdate[1]))
        if not W.expectReports then
            assert(#W.prints == 0, 'Unexpected chat output: ' .. table.concat(W.prints, ' | '))
        end
        -- A visible quest icon may only live on a plate that is still on screen.
        for _, o in ipairs(W.objects) do
            if o.isTexture and Kind(o.texture) and visible(o) then
                local home = false
                for _, p in ipairs(W.plates) do
                    if within(o, p.plate) then home = true end
                end
                assert(home, 'A visible quest icon is not on any current nameplate')
            end
        end
    end)
    print = out
    out((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

-- Standard: QuietUI on, Quest mobs on, quest log with the kill and loot quests.
local function Ready(opts)
    Boot(opts)
    Quests()
    W.ns.ApplyQuestMobs()
end

-- Icon choice -------------------------------------------------------------------------------

test('Kill objective shows the exclamation left of the health bar, parented to the plate, no mouse', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    local kind, tex = IconOn(plate)
    assert(kind == 'kill', 'Expected the exclamation (Media/quest-kill), got ' .. tostring(kind))
    assert(count(W.calls.GetUnit or {}, 'nameplate1') >= 1, 'C_TooltipInfo.GetUnit was not asked for nameplate1')
    local roots = RootsOn(plate)
    assert(#roots >= 1, 'The icon is not attached to the plate')
    local direct = false
    for _, o in ipairs(roots) do
        if o.parent == plate then direct = true end
    end
    assert(direct, 'The icon frame must be parented to the plate itself')
    local anchored = false
    for _, o in ipairs(W.objects) do
        if within(o, plate) and AnchoredRightToLeftOf(o, plate.bar) then anchored = true end
    end
    assert(anchored, 'The icon must anchor its RIGHT to the LEFT of UnitFrame.healthBar')
    for _, o in ipairs(W.objects) do
        if within(o, plate) then
            assert(o.mouse ~= true, 'The icon must not take the mouse')
        end
    end
    assert(within(tex, plate), 'The icon texture is not on the plate')
end)

test('Without a health bar the icon anchors to the left of UnitFrame', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD }, { noHealthBar = true })
    assert(IconOn(plate) == 'kill', 'Expected the exclamation without a health bar')
    local anchored = false
    for _, o in ipairs(W.objects) do
        if within(o, plate) and AnchoredRightToLeftOf(o, plate.UnitFrame) then anchored = true end
    end
    assert(anchored, 'The icon must anchor its RIGHT to the LEFT of UnitFrame as fallback')
end)

test('Item objective "4/8 Tough Wolf Meat" shows the pouch', function()
    Ready()
    local plate = Add('nameplate1', { lines = WOLF })
    assert(IconOn(plate) == 'loot', 'Expected the pouch (Media/quest-loot), got ' .. tostring(IconOn(plate)))
end)

test('Monster and item both unfinished show only the exclamation', function()
    Ready()
    local plate = Add('nameplate1', { lines = {
        Q(KILL_Q), O('0/10 Kobold Vermin slain'), Q(LOOT_Q), O('4/8 Tough Wolf Meat') } })
    assert(IconOn(plate) == 'kill', 'Exclamation must win over the pouch')
end)

test('Monster and item in one quest show only the exclamation', function()
    Ready()
    W.objectives[OTHER_Q] = {
        { text = 'Tough Wolf Meat: 1/8', type = 'item', finished = false },
        { text = 'Kobold Vermin slain: 0/10', type = 'monster', finished = false },
    }
    local plate = Add('nameplate1', { lines = { Q(OTHER_Q), O('1/8 Tough Wolf Meat'), O('0/10 Kobold Vermin slain') } })
    assert(IconOn(plate) == 'kill', 'Exclamation must win over the pouch within one quest')
end)

local FALLBACKS = {
    { 'an unmatched objective line', { Q(LOOT_Q), O('0/3 Gnoll Paws') } },
    { 'an objective of another type', { Q(OTHER_Q), O('0/1 Old Lockbox') } },
    { 'a quest title without objective lines', { Q(LOOT_Q) } },
    { 'no tooltip lines at all', {} },
}
for _, c in ipairs(FALLBACKS) do
    test('Related quest mob with ' .. c[1] .. ' shows the exclamation', function()
        Ready()
        W.objectives[OTHER_Q] = { { text = 'Old Lockbox: 0/1', type = 'object', finished = false } }
        local plate = Add('nameplate1', { lines = c[2] })
        assert(IconOn(plate) == 'kill', 'Expected the exclamation fallback, got ' .. tostring(IconOn(plate)))
    end)
end

test('Related quest mob whose tooltip data is nil shows the exclamation', function()
    Ready()
    local plate = Add('nameplate1', { lines = nil })
    assert(IconOn(plate) == 'kill', 'Expected the exclamation without tooltip data')
end)

test('Objectives are matched per quest block', function()
    Ready()
    -- "Red Bandana" is an item of quest 102 but the tooltip lists it under quest 103.
    W.objectives[LOOT_Q] = { { text = 'Red Bandana: 0/5', type = 'item', finished = false } }
    W.objectives[OTHER_Q] = { { text = 'Something Else: 0/2', type = 'item', finished = false } }
    local plate = Add('nameplate1', { lines = { Q(LOOT_Q), Q(OTHER_Q), O('0/5 Red Bandana') } })
    assert(IconOn(plate) == 'kill', 'A line must only match objectives of its own quest')
end)

test('A completed "10/10" line is skipped and the other unfinished item shows the pouch', function()
    Ready()
    W.objectives[OTHER_Q] = {
        { text = 'Kobold Vermin slain: 10/10', type = 'monster', finished = true },
        { text = 'Tough Wolf Meat: 2/8', type = 'item', finished = false },
    }
    local plate = Add('nameplate1', { lines = { Q(OTHER_Q), O('10/10 Kobold Vermin slain'), O('2/8 Tough Wolf Meat') } })
    assert(IconOn(plate) == 'loot', 'The completed monster line must not count, got ' .. tostring(IconOn(plate)))
end)

test('A tooltip line at its goal is skipped even while the quest log still lags behind', function()
    Ready()
    W.objectives[OTHER_Q] = {
        { text = 'Kobold Vermin slain: 9/10', type = 'monster', finished = false },
        { text = 'Tough Wolf Meat: 2/8', type = 'item', finished = false },
    }
    local plate = Add('nameplate1', { lines = { Q(OTHER_Q), O('10/10 Kobold Vermin slain'), O('2/8 Tough Wolf Meat') } })
    assert(IconOn(plate) == 'loot', 'x >= y on the tooltip line marks it done, got ' .. tostring(IconOn(plate)))
end)

-- Unreadable data -------------------------------------------------------------------------
-- Any secret or missing value in the tooltip lines or quest objectives leads to the
-- exclamation, even next to a readable unfinished item objective that alone shows the pouch.

local UNREADABLE = {
    { 'a quest title with a secret id', { Q(SECRET, 'Hidden Quest'), O('0/3 Gnoll Paws'),
        Q(LOOT_Q), O('4/8 Tough Wolf Meat') } },
    { 'a quest title with a missing id', { Q(nil, 'Hidden Quest'), O('0/3 Gnoll Paws'),
        Q(LOOT_Q), O('4/8 Tough Wolf Meat') } },
    { 'an objective line with secret text', { Q(LOOT_Q), { type = OBJECTIVE, leftText = SECRET },
        O('4/8 Tough Wolf Meat') } },
    { 'a line with a secret type', { Q(LOOT_Q), { type = SECRET, leftText = '0/3 Gnoll Paws' },
        O('4/8 Tough Wolf Meat') } },
}
for _, c in ipairs(UNREADABLE) do
    test('Readable item objective next to ' .. c[1] .. ' shows the exclamation, not the pouch', function()
        Ready()
        local plate = Add('nameplate1', { lines = c[2] })
        local kind = IconOn(plate)
        assert(kind == 'kill', 'Unreadable data must lead to the exclamation, got ' .. tostring(kind))
    end)
end

test('A matched quest objective with a secret type shows the exclamation without error', function()
    Ready()
    W.objectives[OTHER_Q] = {
        { text = 'Gnoll Paws: 0/3', type = SECRET, finished = false },
        { text = 'Tough Wolf Meat: 4/8', type = 'item', finished = false },
    }
    local plate = Add('nameplate1', { lines = { Q(OTHER_Q), O('4/8 Tough Wolf Meat'), O('0/3 Gnoll Paws') } })
    local kind = IconOn(plate)
    assert(kind == 'kill', 'A secret objective type must lead to the exclamation, got ' .. tostring(kind))
end)

-- Icon size follows the health bar height, clamped to 12..24.
for _, h in ipairs({ 8, 10, 20 }) do
    test('With a health bar of height ' .. h .. ' the icon is a square about that tall', function()
        Ready()
        local plate = Add('nameplate1', { lines = KOBOLD }, { barHeight = h })
        local kind, tex = IconOn(plate)
        assert(kind == 'kill', 'Expected the exclamation, got ' .. tostring(kind))
        local frame = tex.parent
        local w, hh = rawget(frame, 'sizeW'), rawget(frame, 'sizeH')
        assert(type(w) == 'number' and type(hh) == 'number', 'The icon frame size was not set')
        assert(w == hh, 'The icon must be square, got ' .. w .. 'x' .. hh)
        local want = math.min(24, math.max(12, h))
        assert(math.abs(hh - want) <= 2,
            'Icon size ' .. hh .. ' must be within 2 of ' .. want .. ' for a health bar of height ' .. h)
    end)
end

-- Gating ------------------------------------------------------------------------------------

test('Unrelated mob shows nothing and its tooltip data is never read', function()
    Ready()
    local plate = Add('nameplate1', { related = false, lines = KOBOLD })
    assert(IconOn(plate) == nil, 'An unrelated mob got an icon')
    assert(count(W.calls.GetUnit or {}, 'nameplate1') == 0, 'C_TooltipInfo.GetUnit was called for an unrelated mob')
end)

test('Friendly NPC shows nothing and neither quest relation nor tooltip is asked', function()
    Ready()
    local plate = Add('nameplate1', { attack = false, lines = KOBOLD })
    assert(IconOn(plate) == nil, 'A friendly NPC got an icon')
    assert(count(W.calls.UnitCanAttack or {}, 'nameplate1') >= 1, 'UnitCanAttack was not asked')
    assert(count(W.calls.Related or {}, 'nameplate1') == 0, 'UnitIsRelatedToActiveQuest was called for a friendly NPC')
    assert(count(W.calls.GetUnit or {}, 'nameplate1') == 0, 'C_TooltipInfo.GetUnit was called for a friendly NPC')
end)

for _, c in ipairs({
    { 'a secret UnitCanAttack', { attack = SECRET, lines = KOBOLD } },
    { 'a nil UnitCanAttack', { noAttack = true, attack = nil, lines = KOBOLD } },
    { 'a secret UnitIsRelatedToActiveQuest', { related = SECRET, lines = KOBOLD } },
    { 'a nil UnitIsRelatedToActiveQuest', { noRelated = true, related = nil, lines = KOBOLD } },
}) do
    test(c[1] .. ' shows nothing without error', function()
        Ready()
        local plate = Add('nameplate1', c[2])
        event('QUEST_LOG_UPDATE')
        NextFrame()
        assert(IconOn(plate) == nil, 'An icon was shown for ' .. c[1])
        assert(count(W.calls.GetUnit or {}, 'nameplate1') == 0, 'Tooltip data was read for ' .. c[1])
    end)
end

test('Disabled QuietUI shows nothing and reads no tooltip', function()
    Boot({ enabled = false })
    Quests()
    W.ns.ApplyQuestMobs()
    local plate = Add('nameplate1', { lines = KOBOLD })
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate) == nil, 'An icon was shown while QuietUI is off')
    assert(count(W.calls.GetUnit or {}, 'nameplate1') == 0, 'Tooltip data was read while QuietUI is off')
end)

test('Quest mobs off shows nothing', function()
    Ready({ on = false })
    local plate = Add('nameplate1', { lines = KOBOLD })
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate) == nil, 'An icon was shown with Quest mobs off')
end)

-- Updates -----------------------------------------------------------------------------------

test('A finished objective (related turns false) loses its icon after QUEST_LOG_UPDATE', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    assert(IconOn(plate) == 'kill', 'Precondition: exclamation shown')
    W.units.nameplate1.related = false
    W.units.nameplate1.lines = { Q(KILL_Q), O('10/10 Kobold Vermin slain') }
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate) == nil, 'The icon stayed after the objective was finished')
end)

test('UNIT_QUEST_LOG_CHANGED for the player re-evaluates the plates', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    W.units.nameplate1.related = false
    event('UNIT_QUEST_LOG_CHANGED', 'player')
    NextFrame()
    assert(IconOn(plate) == nil, 'UNIT_QUEST_LOG_CHANGED("player") did not re-evaluate')
end)

test('A quest log change switches the icon on the same plate without a second icon', function()
    Ready()
    W.objectives[OTHER_Q] = {
        { text = 'Kobold Vermin slain: 0/10', type = 'monster', finished = false },
        { text = 'Tough Wolf Meat: 0/8', type = 'item', finished = false },
    }
    local plate = Add('nameplate1', { lines = { Q(OTHER_Q), O('0/10 Kobold Vermin slain'), O('0/8 Tough Wolf Meat') } })
    assert(IconOn(plate) == 'kill', 'Precondition: exclamation shown')
    W.units.nameplate1.lines = { Q(OTHER_Q), O('10/10 Kobold Vermin slain'), O('0/8 Tough Wolf Meat') }
    W.objectives[OTHER_Q][1] = { text = 'Kobold Vermin slain: 10/10', type = 'monster', finished = true }
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate) == 'loot', 'Expected the pouch after the kill objective was done, got ' .. tostring(IconOn(plate)))
end)

test('Several quest log events in one frame cause exactly one recalculation and no polling', function()
    Ready()
    Add('nameplate1', { lines = KOBOLD })
    Add('nameplate2', { lines = WOLF })
    Add('nameplate3', { related = false, lines = KOBOLD })
    NextFrame()
    local scans, reads = W.total.GetNamePlates or 0, W.total.GetUnit or 0
    event('QUEST_LOG_UPDATE')
    event('QUEST_LOG_UPDATE')
    event('UNIT_QUEST_LOG_CHANGED', 'player')
    event('QUEST_LOG_UPDATE')
    assert((W.total.GetUnit or 0) == reads, 'Quest log events must only mark dirty, not recalculate at once')
    assert(Pending() <= 1, 'Expected one scheduled recalculation, got ' .. Pending())
    NextFrame()
    assert((W.total.GetNamePlates or 0) - scans == 1, 'Expected one plate scan, got ' .. ((W.total.GetNamePlates or 0) - scans))
    assert((W.total.GetUnit or 0) - reads == 2, 'Expected one tooltip read per quest plate, got ' .. ((W.total.GetUnit or 0) - reads))
    assert(Pending() == 0, 'A recalculation rescheduled itself without a new event')
    -- A later frame without events does no work.
    NextFrame()
    assert((W.total.GetNamePlates or 0) - scans == 1, 'Work happened on a frame without events')
end)

test('Quest objectives are read once per quest within one recalculation and again in the next', function()
    Ready()
    Add('nameplate1', { lines = KOBOLD })
    Add('nameplate2', { lines = KOBOLD })
    local plate3 = Add('nameplate3', { lines = WOLF })
    NextFrame()
    local before = count(W.calls.Objectives or {}, KILL_Q)
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(count(W.calls.Objectives, KILL_Q) - before == 1, 'Expected one GetQuestObjectives per quest per recalculation, got '
        .. (count(W.calls.Objectives, KILL_Q) - before))
    -- The next recalculation must not reuse old objectives.
    W.objectives[LOOT_Q] = { { text = 'Tough Wolf Meat: 4/8', type = 'monster', finished = false } }
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate3) == 'kill', 'Objectives from an earlier recalculation were reused')
end)

test('PLAYER_ENTERING_WORLD re-evaluates the visible plates', function()
    Ready()
    local plate = AddPlate('nameplate1', { lines = KOBOLD })
    event('PLAYER_ENTERING_WORLD', false, false)
    NextFrame()
    assert(IconOn(plate) == 'kill', 'PLAYER_ENTERING_WORLD did not evaluate the visible plate')
end)

test('ApplyQuestMobs evaluates plates already on screen', function()
    Boot()
    Quests()
    local a = AddPlate('nameplate1', { lines = KOBOLD })
    local b = AddPlate('nameplate2', { lines = WOLF })
    W.ns.ApplyQuestMobs()
    assert(IconOn(a) == 'kill' and IconOn(b) == 'loot', 'ApplyQuestMobs did not evaluate visible plates')
end)

-- Combat, instances, HUD rules ----------------------------------------------------------------

test('In combat a new plate shows its icon and existing icons stay', function()
    Ready()
    local a = Add('nameplate1', { lines = KOBOLD })
    W.inCombat = true
    event('PLAYER_REGEN_DISABLED')
    local b = Add('nameplate2', { lines = WOLF })
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(a) == 'kill', 'The existing icon disappeared in combat')
    assert(IconOn(b) == 'loot', 'A plate added in combat got no icon')
end)

for _, kind in ipairs({ 'party', 'raid', 'pvp', 'arena' }) do
    test('Icons show in a ' .. kind .. ' instance', function()
        Ready()
        local a = Add('nameplate1', { lines = KOBOLD })
        W.instance = kind
        event('PLAYER_ENTERING_WORLD', false, false)
        event('ZONE_CHANGED_NEW_AREA')
        NextFrame()
        local b = Add('nameplate2', { lines = WOLF })
        W.ns.ApplyQuestMobs()
        assert(IconOn(a) == 'kill', 'The icon disappeared in a ' .. kind .. ' instance')
        assert(IconOn(b) == 'loot', 'No icon in a ' .. kind .. ' instance')
    end)
end

test('Glance, Edit Mode and ShowAll do not change the icons', function()
    Ready()
    local a = Add('nameplate1', { lines = KOBOLD })
    local b = Add('nameplate2', { related = false, lines = KOBOLD })
    W.glance, W.editMode, W.showAll = true, true, true
    W.ns.ApplyQuestMobs()
    event('QUEST_LOG_UPDATE')
    NextFrame()
    local c = Add('nameplate3', { lines = WOLF })
    assert(IconOn(a) == 'kill' and IconOn(c) == 'loot', 'HUD flags changed a quest icon')
    assert(IconOn(b) == nil, 'HUD flags revealed an icon on an unrelated mob')
end)

-- Recycling ---------------------------------------------------------------------------------

test('NAME_PLATE_UNIT_REMOVED hides the icon and returns it to UIParent', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    local other = Add('nameplate2', { lines = WOLF })
    local roots = RootsOn(plate)
    assert(#roots >= 1 and IconOn(plate) == 'kill', 'Precondition: icon on the plate')
    Remove('nameplate1')
    assert(IconOn(plate) == nil, 'The icon still shows on a removed plate')
    assert(#RootsOn(plate) == 0, 'An icon object stayed attached to the removed plate')
    for _, o in ipairs(roots) do
        assert(o.parent == UIParent or OnPlate(o.parent), 'The released icon was not returned to UIParent')
        if o.parent == UIParent then assert(not visible(o), 'The released icon is still visible on UIParent') end
    end
    assert(IconOn(other) == 'loot', 'Removing another plate hid an unrelated icon')
end)

test('A recycled plate for an unrelated mob shows no stale icon', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    Remove('nameplate1')
    -- The client hands the same plate object to another unit.
    W.plates[#W.plates + 1] = { token = 'nameplate5', plate = plate }
    plate.namePlateUnitToken = 'nameplate5'
    plate.UnitFrame.unit = 'nameplate5'
    W.units.nameplate5 = { attack = true, related = false, lines = {} }
    event('NAME_PLATE_UNIT_ADDED', 'nameplate5')
    assert(IconOn(plate) == nil, 'A recycled plate showed the previous mob\'s icon')
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(plate) == nil, 'A recycled plate showed a stale icon after recalculation')
end)

test('A recycled plate for another quest mob shows only its own icon', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    Remove('nameplate1')
    W.plates[#W.plates + 1] = { token = 'nameplate6', plate = plate }
    plate.namePlateUnitToken = 'nameplate6'
    plate.UnitFrame.unit = 'nameplate6'
    W.units.nameplate6 = { attack = true, related = true, lines = WOLF }
    event('NAME_PLATE_UNIT_ADDED', 'nameplate6')
    assert(IconOn(plate) == 'loot', 'Expected only the pouch on the recycled plate, got ' .. tostring(IconOn(plate)))
end)

test('Removing a plate with a recalculation pending shows nothing on it later', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    event('QUEST_LOG_UPDATE')
    Remove('nameplate1')
    NextFrame()
    assert(IconOn(plate) == nil, 'A removed plate got its icon back from the pending recalculation')
end)

-- Restore -----------------------------------------------------------------------------------

test('RestoreQuestMobs hides every icon at once and returns them to UIParent', function()
    Ready()
    local a = Add('nameplate1', { lines = KOBOLD })
    local b = Add('nameplate2', { lines = WOLF })
    local roots = {}
    for _, o in ipairs(RootsOn(a)) do roots[#roots + 1] = o end
    for _, o in ipairs(RootsOn(b)) do roots[#roots + 1] = o end
    assert(#roots >= 2, 'Precondition: two icons attached')
    QuietUIDB.enabled = false
    W.ns.RestoreQuestMobs()
    assert(NothingShown(), 'An icon is still visible after RestoreQuestMobs')
    for _, o in ipairs(roots) do
        assert(o.parent == UIParent, 'A restored icon was not returned to UIParent')
    end
    -- A recalculation queued before the restore must not bring them back.
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(NothingShown(), 'A pending recalculation showed icons after RestoreQuestMobs')
end)

test('A recalculation pending at restore time stays without effect', function()
    Ready()
    Add('nameplate1', { lines = KOBOLD })
    event('QUEST_LOG_UPDATE')
    QuietUIDB.enabled = false
    W.ns.RestoreQuestMobs()
    NextFrame()
    assert(NothingShown(), 'The pending recalculation showed an icon after restore')
end)

test('Re-enabling after RestoreQuestMobs evaluates the plates again', function()
    Ready()
    local a = Add('nameplate1', { lines = KOBOLD })
    QuietUIDB.enabled = false
    W.ns.RestoreQuestMobs()
    -- While off the quest state changed and another mob appeared.
    local b = AddPlate('nameplate2', { lines = WOLF })
    W.units.nameplate1.related = false
    QuietUIDB.enabled = true
    W.ns.ApplyQuestMobs()
    assert(IconOn(a) == nil, 'A stale icon came back after re-enable')
    assert(IconOn(b) == 'loot', 'Re-enable did not evaluate the visible plates')
end)

test('Unchecking Quest mobs and applying hides all icons at once; checking again shows them', function()
    Ready()
    local a = Add('nameplate1', { lines = KOBOLD })
    local b = Add('nameplate2', { lines = WOLF })
    W.on = false
    W.ns.ApplyQuestMobs()
    assert(NothingShown(), 'Icons stayed after Quest mobs was unchecked')
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(NothingShown(), 'Icons came back while Quest mobs is unchecked')
    W.on = true
    W.ns.ApplyQuestMobs()
    assert(IconOn(a) == 'kill' and IconOn(b) == 'loot', 'Checking Quest mobs again did not show the icons')
end)

-- Missing or hostile client pieces ------------------------------------------------------------

test('Missing UnitIsRelatedToActiveQuest: no icon, no crash, one report', function()
    Ready({ noRelated = true })
    W.expectReports = true
    local a = Add('nameplate1', { lines = KOBOLD })
    local b = Add('nameplate2', { lines = WOLF })
    event('QUEST_LOG_UPDATE')
    NextFrame()
    W.ns.ApplyQuestMobs()
    assert(IconOn(a) == nil and IconOn(b) == nil, 'An icon was shown without UnitIsRelatedToActiveQuest')
    assert(Reports() == 1, 'Expected exactly one report, got ' .. Reports() .. ': ' .. table.concat(W.prints, ' | '))
end)

for _, c in ipairs({ { 'C_TooltipInfo.GetUnit', { noGetUnit = true } }, { 'C_TooltipInfo', { noTooltipInfo = true } } }) do
    test('Missing ' .. c[1] .. ': exclamation, no crash, one report', function()
        Ready(c[2])
        W.expectReports = true
        local a = Add('nameplate1', { lines = KOBOLD })
        local b = Add('nameplate2', { lines = WOLF })
        event('QUEST_LOG_UPDATE')
        NextFrame()
        assert(IconOn(a) == 'kill' and IconOn(b) == 'kill', 'Without tooltip data a related mob must show the exclamation')
        assert(Reports() == 1, 'Expected exactly one report, got ' .. Reports() .. ': ' .. table.concat(W.prints, ' | '))
    end)
end

test('Missing GetQuestObjectives: exclamation, no crash, one report', function()
    Ready({ noObjectives = true })
    W.expectReports = true
    local a = Add('nameplate1', { lines = KOBOLD })
    local b = Add('nameplate2', { lines = WOLF })
    event('QUEST_LOG_UPDATE')
    NextFrame()
    assert(IconOn(a) == 'kill' and IconOn(b) == 'kill', 'Without objectives a related mob must show the exclamation')
    assert(Reports() == 1, 'Expected exactly one report, got ' .. Reports() .. ': ' .. table.concat(W.prints, ' | '))
end)

test('Forbidden plate is skipped without calling its methods', function()
    Ready()
    local proxy = forbiddenProxy()
    W.plates[#W.plates + 1] = { token = 'nameplate1', plate = proxy }
    W.units.nameplate1 = { attack = true, related = true, lines = KOBOLD }
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    event('QUEST_LOG_UPDATE')
    NextFrame()
    W.ns.ApplyQuestMobs()
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(W.forbiddenCalls == 0, 'A forbidden plate had ' .. W.forbiddenCalls .. ' method calls')
    assert(NothingShown(), 'Something was shown on a forbidden plate')
end)

test('A plate event without a plate does not error', function()
    Ready()
    W.units.nameplate9 = { attack = true, related = true, lines = KOBOLD }
    event('NAME_PLATE_UNIT_ADDED', 'nameplate9')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate9')
    event('NAME_PLATE_UNIT_REMOVED', 'nameplate8')
    assert(NothingShown(), 'An icon appeared without a plate')
end)

test('Missing C_Timer: quest log events do not error', function()
    Ready({ noTimer = true })
    local plate = Add('nameplate1', { lines = KOBOLD })
    W.units.nameplate1.related = false
    event('QUEST_LOG_UPDATE')
    event('UNIT_QUEST_LOG_CHANGED', 'player')
    W.ns.ApplyQuestMobs()
    assert(IconOn(plate) == nil, 'ApplyQuestMobs did not re-evaluate without C_Timer')
end)

test('Unknown event is ignored without error', function()
    Ready()
    event('SOME_UNKNOWN_EVENT', 'x')
end)

-- Hygiene -----------------------------------------------------------------------------------

test('Plates are never moved, faded, shown or hidden through a full cycle', function()
    Ready()
    local plate = Add('nameplate1', { lines = KOBOLD })
    W.inCombat = true
    event('QUEST_LOG_UPDATE')
    NextFrame()
    Remove('nameplate1')
    W.plates[#W.plates + 1] = { token = 'nameplate1', plate = plate }
    W.units.nameplate1 = { attack = true, related = true, lines = WOLF }
    event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
    QuietUIDB.enabled = false
    W.ns.RestoreQuestMobs()
    assert(plate.alpha == 1 and plate.shown, 'The plate changed state')
    assert(#plate.points == 0 and #plate.UnitFrame.points == 0 and #plate.bar.points == 0, 'A plate frame was moved')
    -- Plate violations and OnUpdate are asserted after every case.
end)

test('QuestMobs.lua never uses GameTooltip or SetUnit', function()
    Boot()
    local f = assert(io.open('QuestMobs.lua'))
    local source = f:read('*a')
    f:close()
    assert(not source:find('GameTooltip', 1, true), 'QuestMobs.lua mentions GameTooltip')
    assert(not source:find('SetUnit', 1, true), 'QuestMobs.lua mentions SetUnit')
end)

test('Media/quest-kill.tga and Media/quest-loot.tga exist', function()
    for _, file in ipairs({ 'Media/quest-kill.tga', 'Media/quest-loot.tga' }) do
        local f = io.open(file, 'rb')
        assert(f, file .. ' does not exist')
        local size = f:seek('end')
        f:close()
        assert(size and size > 18, file .. ' is not a TGA image')
    end
    W = W or { plateViolations = {}, onUpdate = {}, prints = {}, objects = {}, plates = {} }
end)

io.write(string.format('%d cases, %d failed\n', cases, failures))
if failures > 0 then os.exit(1) end
