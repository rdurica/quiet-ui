-- Run from the addon directory: lua tests/party-performance.lua
local ns, grouped, editing, glance, combat, instance = {}, false, false, false, false, false
local reads, writes, catchers = 0, 0, 0
local function frame(parent)
    local f = { parent = parent, alpha = 1, shown = true, children = {} }
    function f:IsForbidden() return false end
    function f:GetParent() return self.parent end
    function f:IsShown() reads = reads + 1; return self.shown end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(alpha) writes = writes + 1; self.alpha = alpha end
    function f:GetChildren() return table.unpack(self.children) end
    function f:GetRegions() end
    function f:IsIgnoringParentAlpha() return self.independent or false end
    function f:GetFrameLevel() reads = reads + 1; return 2 end
    function f:GetFrameStrata() reads = reads + 1; return 'MEDIUM' end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetFrameLevel', 'SetFrameStrata',
        'SetMouseMotionEnabled', 'SetMouseClickEnabled' }) do f[name] = function() end end
    return f
end
QuietUIDB, QuietUICharDB = { enabled = true }, { autoHideParty = true }
UIParent = frame()
CreateFrame = function() catchers = catchers + 1; return frame(UIParent) end
hooksecurefunc = function(obj, name, hook)
    local original = obj[name]
    obj[name] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
for _, file in ipairs({ 'Core.lua', 'Setup.lua', 'Faders.lua' }) do
    assert(loadfile(file))('QuietUI', ns)
end
ns.InGroup = function() return grouped end
ns.InEditMode = function() return editing end
ns.Glancing = function() return glance end
ns.InCombat = function() return combat end
ns.InForcedInstance = function() return instance end
ns.Hit = function() return false end
PartyFrame = frame(UIParent)
for i = 1, 100 do
    local child = frame(PartyFrame)
    child.independent = true
    PartyFrame.children[i] = child
end
ns.FindFaders(false)
reads, writes = 0, 0
for _ = 1, 60 do ns.UpdateParty(1 / 60) end
print(('Solo 60 frames: frame reads=%d alpha writes=%d catchers=%d'):format(reads, writes, catchers))
assert(reads == 0 and writes == 0 and catchers == 0, 'Solo autohide must leave empty party containers idle')
grouped = true
ns.UpdateParty(0.1)
assert(PartyFrame.alpha > 0 and PartyFrame.alpha < 1, 'Joining must immediately start the normal fade')
ns.UpdateParty(0.3)
assert(PartyFrame.alpha == 0 and PartyFrame.children[100].alpha == 0, 'Independent indicators must fade with the group')
grouped = false
reads, writes = 0, 0
ns.UpdateParty(1 / 60)
assert(writes == 0, 'Leaving the group must stop indicator updates')
editing = true
ns.UpdateParty(0)
assert(PartyFrame.alpha == 1 and PartyFrame.children[100].alpha == 1, 'Solo Edit Mode must reveal previews')
editing, grouped = false, true
ns.UpdateParty(0.3)
grouped, glance = false, true
ns.UpdateParty(0)
assert(PartyFrame.alpha == 1, 'Glance must still reveal shown party frames')
glance = false
for _, trigger in ipairs({ 'combat', 'instance' }) do
    grouped = true
    ns.UpdateParty(0.3)
    grouped = false
    combat, instance = trigger == 'combat', trigger == 'instance'
    ns.UpdateParty(0)
    assert(PartyFrame.alpha == 1, 'Solo forced visibility must still reveal shown party frames')
    combat, instance = false, false
end
QuietUICharDB.autoHideParty = nil
ns.UpdateParty(0)
assert(PartyFrame.alpha == 1 and PartyFrame.children[100]._quietAlpha == nil,
    'Disabling autohide while solo must restore independent indicators')
print('PASS solo party idling, join and leave, Edit Mode, Glance and restore')
