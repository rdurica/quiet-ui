-- Run from the addon directory: lua tests/range-cache.lua
local unpack = table.unpack or unpack
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

local walks, actionReads, now = 0, 0, 1000
local function frame(parent, width, height)
    local f = { parent = parent, alpha = 1, shown = true, children = {}, width = width or 0,
        height = height or 0, scripts = {} }
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetFrameLevel() return 3 end
    function f:GetName() return nil end
    function f:GetChildren()
        if self.counted then walks = walks + 1 end
        return unpack(self.children)
    end
    function f:CreateTexture() return frame(self) end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel', 'SetFrameStrata',
        'EnableMouse', 'SetIgnoreParentAlpha', 'SetColorTexture', 'SetMouseClickEnabled',
        'SetMouseMotionEnabled' }) do f[name] = function() end end
    return f
end

hooksecurefunc = function(target, name, hook)
    if type(target) == 'string' then return end
    local original = target[name]
    target[name] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
UIParent = frame()
local created = {}
CreateFrame = function(_, _, parent)
    local f = frame(parent)
    created[#created + 1] = f
    return f
end
GetTime = function() return now end
UnitExists = function() return true end
UnitIsDeadOrGhost = function() return false end
CheckInteractDistance = function() return true end
IsActionInRange = function() return true end
GetActionInfo = function(slot)
    actionReads = actionReads + 1
    if slot == 1 then return 'spell', 133 end
end
C_Spell = {
    GetSpellInfo = function() return { name = 'Fireball', maxRange = 35 } end,
    IsSpellHarmful = function() return true end,
    IsSpellHelpful = function() return false end,
    IsSpellInRange = function() return true end,
}
local plate
C_NamePlate = { GetNamePlateForUnit = function() return plate end }
local function makePlate()
    local p = frame(UIParent, 120, 60)
    local unit = frame(p, 120, 60)
    unit.counted = true
    unit.children = { frame(unit, 100, 10) }
    p.UnitFrame = unit
    return p
end

QuietUIDB = { enabled = true }
QuietUICharDB = { range = { yards = 'spell', kind = 'hostile', spell = 'Fireball' } }
local ns = {}
for _, file in ipairs({ 'Core.lua', 'Setup.lua', 'Faders.lua' }) do
    assert(loadfile(file))('QuietUI', ns)
end
ns.ShowAll = function() return false end
ns.Glancing = function() return false end
ns.Report = function(name, err) error(name .. ': ' .. tostring(err)) end

local function frames(count)
    for _ = 1, count do
        now = now + 1 / 60
        ns.UpdateRange(1 / 60)
    end
end

test('Same target plate looks up its health bar at most once in 60 frames', function()
    plate = makePlate()
    walks = 0
    frames(60)
    local bar, placed = plate.UnitFrame.children[1], false
    for _, f in ipairs(created) do placed = placed or (f.parent == bar and f.shown) end
    assert(placed, 'The range gradient was not shown on the health bar')
    assert(walks >= 1, 'The health bar was never searched')
    assert(walks <= 1, 'TightestBar walked the same plate ' .. walks .. ' times in 60 frames')
end)

test('ForgetRangePlate makes the next frame search the plate again', function()
    assert(type(ns.ForgetRangePlate) == 'function', 'ns.ForgetRangePlate is missing')
    frames(2)
    walks = 0
    ns.ForgetRangePlate()
    frames(1)
    assert(walks == 1, 'After ForgetRangePlate the bar was searched ' .. walks .. ' times')
end)

test('A different plate is searched without an event', function()
    plate = makePlate()
    walks = 0
    frames(2)
    assert(walks == 1, 'A new plate was searched ' .. walks .. ' times')
end)

test('Empty Spell field rescans bar 1 only on the five second fallback', function()
    QuietUICharDB.range = { yards = 'spell', kind = 'hostile' }
    frames(1)
    actionReads = 0
    frames(600)
    local scans = actionReads / 12
    assert(scans >= 1, 'Bar 1 was never scanned')
    assert(scans <= 2, 'BestSlot ran ' .. scans .. ' times in 10 s without events')
end)

test('ForgetRangeSlot rescans bar 1 on the next frame', function()
    assert(type(ns.ForgetRangeSlot) == 'function', 'ns.ForgetRangeSlot is missing')
    frames(1)
    actionReads = 0
    ns.ForgetRangeSlot()
    frames(1)
    assert(actionReads == 12, 'After ForgetRangeSlot bar 1 was read ' .. actionReads .. ' times')
end)

test('Events forget the range caches', function()
    local wired = {}
    CreateFrame = function(_, _, parent)
        local f = frame(parent)
        wired[#wired + 1] = f
        return f
    end
    SlashCmdList = {}
    local events_ns = {}
    assert(loadfile('Core.lua'))('QuietUI', events_ns)
    local slots, plates = 0, 0
    events_ns.ForgetRangeSlot = function() slots = slots + 1 end
    events_ns.ForgetRangePlate = function() plates = plates + 1 end
    events_ns.RefreshWorld = function() end
    assert(loadfile('QuietUI.lua'))('QuietUI', events_ns)
    local events = wired[1]
    local onEvent = events.scripts.OnEvent
    for i = 1, 100 do
        local name = debug.getupvalue(onEvent, i)
        if name == 'booted' then debug.setupvalue(onEvent, i, true) break end
        if not name then break end
    end
    for _, name in ipairs({ 'ACTIONBAR_SLOT_CHANGED', 'SPELLS_CHANGED', 'PLAYER_TARGET_CHANGED',
        'NAME_PLATE_UNIT_REMOVED' }) do
        assert(events.events and events.events[name], name .. ' is not registered')
    end
    onEvent(events, 'ACTIONBAR_SLOT_CHANGED', 1)
    onEvent(events, 'SPELLS_CHANGED')
    assert(slots == 2, 'Slot events forgot the slot ' .. slots .. ' times')
    onEvent(events, 'PLAYER_TARGET_CHANGED')
    onEvent(events, 'NAME_PLATE_UNIT_REMOVED', 'nameplate1')
    assert(plates == 2, 'Plate events forgot the plate ' .. plates .. ' times')
end)

if failures > 0 then
    error(failures .. ' range cache test(s) failed')
end
