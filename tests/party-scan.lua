-- Run from the addon directory: lua tests/party-scan.lua
local unpack = table.unpack or unpack
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

-- A full party scan enumerates every root once; the signature only reads counts.
local scans = 0
local function frame(parent, name)
    local f = { parent = parent, name = name, alpha = 1, shown = true, children = {}, regions = {},
        scripts = {} }
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:GetName() return self.name end
    function f:GetFrameLevel() return 2 end
    function f:GetFrameStrata() return 'MEDIUM' end
    function f:GetNumChildren() return #self.children end
    function f:GetNumRegions() return #self.regions end
    function f:GetChildren()
        if self.name == 'CompactRaidFrameContainer' then scans = scans + 1 end
        return unpack(self.children)
    end
    function f:GetRegions() return unpack(self.regions) end
    function f:IsIgnoringParentAlpha() return self.independent or false end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
    for _, method in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel', 'SetFrameStrata',
        'SetMouseMotionEnabled', 'SetMouseClickEnabled', 'EnableMouse' }) do f[method] = function() end end
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
local created = {}
UIParent = frame()
CreateFrame = function(_, _, parent)
    local f = frame(parent)
    created[#created + 1] = f
    return f
end
SlashCmdList = {}
local queued = {}
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
local function flush()
    local list = queued
    queued = {}
    for _, fn in ipairs(list) do fn() end
end

QuietUIDB, QuietUICharDB = { enabled = true }, { autoHideParty = true }
local ns = {}
for _, file in ipairs({ 'Core.lua', 'Setup.lua', 'Faders.lua' }) do
    assert(loadfile(file))('QuietUI', ns)
end
local grouped = false
ns.InGroup = function() return grouped end
ns.InEditMode = function() return false end
ns.Glancing = function() return false end
ns.InCombat = function() return false end
ns.InForcedInstance = function() return false end
ns.Hit = function() return false end
ns.RefreshWorld = function() end

CompactRaidFrameContainer = frame(UIParent, 'CompactRaidFrameContainer')
for i = 1, 5 do
    CompactRaidFrameContainer.children[i] = frame(CompactRaidFrameContainer)
end
PartyFrame = frame(UIParent, 'PartyFrame')

-- GROUP_ROSTER_UPDATE reaches Faders through the QuietUI.lua event frame.
local firstCreated = #created + 1
assert(loadfile('QuietUI.lua'))('QuietUI', ns)
local events = created[firstCreated]
local onEvent = events.scripts.OnEvent
for i = 1, 100 do
    local name = debug.getupvalue(onEvent, i)
    if name == 'booted' then debug.setupvalue(onEvent, i, true) break end
    if not name then break end
end
local function fire(name)
    onEvent(events, name)
    flush()
end
local function ticks(count)
    for _ = 1, count do ns.FindFaders(false) end
end

test('Ten idle 1 s ticks skip the full party scan', function()
    ns.FindFaders(true)
    scans = 0
    ticks(10)
    assert(scans == 0, 'Unchanged party containers were fully scanned ' .. scans .. ' times')
end)

test('A new raid container child triggers exactly one full scan', function()
    ticks(1)
    local added = frame(CompactRaidFrameContainer)
    added.independent = true
    CompactRaidFrameContainer.children[#CompactRaidFrameContainer.children + 1] = added
    scans = 0
    ticks(1)
    assert(scans == 1, 'Child count change ran ' .. scans .. ' full scans on the next tick')
    ticks(1)
    assert(scans == 1, 'The settled signature scanned again: ' .. scans)
    grouped = true
    ns.UpdateParty(0.3)
    grouped = false
    assert(added.alpha == 0, 'The new independent child was not collected by the scan')
end)

test('GROUP_ROSTER_UPDATE scans only while autohide is on', function()
    ticks(1)
    scans = 0
    fire('GROUP_ROSTER_UPDATE')
    assert(scans == 1, 'Roster update with autohide ran ' .. scans .. ' full scans')
    QuietUICharDB.autoHideParty = false
    scans = 0
    fire('GROUP_ROSTER_UPDATE')
    assert(scans == 0, 'Roster update without autohide ran ' .. scans .. ' full scans')
    QuietUICharDB.autoHideParty = true
end)

test('Turning autohide on scans at the next tick without a signature change', function()
    ticks(2)
    QuietUICharDB.autoHideParty = false
    ticks(1)
    QuietUICharDB.autoHideParty = true
    scans = 0
    ticks(1)
    assert(scans == 1, 'Enabling autohide ran ' .. scans .. ' full scans')
    ticks(1)
    assert(scans == 1, 'Enabled autohide kept scanning: ' .. scans)
end)

if failures > 0 then
    error(failures .. ' party scan test(s) failed')
end
