-- Run from the addon directory: lua tests/hotpath-cache.lua
-- Per-frame catcher writes and bar ownership passes stay out of the steady state.
local failures = 0
local unpack = table.unpack or unpack
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function frame(parent)
    local obj = { alpha = 1, shown = true, parent = parent, children = {}, regions = {}, calls = {} }
    if parent then parent.children[#parent.children + 1] = obj end
    local function count(key) obj.calls[key] = (obj.calls[key] or 0) + 1 end
    function obj:IsForbidden() return false end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:IsShown() return self.shown end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:GetParent() return self.parent end
    function obj:SetParent(value) self.parent = value end
    function obj:GetName() return self.name end
    function obj:GetFrameLevel() return self.level or 5 end
    function obj:GetFrameStrata() return self.strata or 'LOW' end
    function obj:SetFrameLevel() count('SetFrameLevel') end
    function obj:SetFrameStrata() count('SetFrameStrata') end
    function obj:GetWidth() return 100 end
    function obj:GetHeight() return 10 end
    function obj:GetNumRegions() return #self.regions end
    function obj:GetNumChildren() return #self.children end
    function obj:GetRegions() return unpack(self.regions) end
    function obj:GetChildren() return unpack(self.children) end
    function obj:SetScript() end
    function obj:HookScript() end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'EnableMouse',
        'SetMouseMotionEnabled', 'SetMouseClickEnabled', 'SetIgnoreParentAlpha' }) do
        obj[name] = function() end
    end
    function obj:CreateTexture() return frame(self) end
    return obj
end

test('Quest catcher keeps strata and level writes out of a stable tracker', function()
    QuietUIDB = { enabled = true }
    UIParent = frame()
    ObjectiveTrackerFrame = frame(UIParent)
    ObjectiveTrackerFrame.name = 'ObjectiveTrackerFrame'
    local boxes = {}
    CreateFrame = function() local f = frame(UIParent); boxes[#boxes + 1] = f; return f end
    local errors = {}
    local ns = setmetatable({}, { __index = function() return function() return false end end })
    ns.DB = function() return QuietUIDB end
    ns.Usable = function(f) return f and not f:IsForbidden() end
    ns.FrameName = function(f) return f and f.name end
    ns.UpdateFaded = function() end
    ns.ArmCatcher = function() end
    ns.Report = function(key, err) errors[#errors + 1] = key .. ': ' .. tostring(err) end
    loadAddon('Faders.lua', ns)
    ns.FindFaders(false)
    for _ = 1, 60 do ns.UpdateFaders(0.016) end
    local catcher
    for _, box in ipairs(boxes) do
        if box.shown and (box.calls.SetFrameStrata or box.calls.SetFrameLevel) then catcher = box end
    end
    assert(catcher, 'Quest catcher was not placed over the tracker: ' .. table.concat(errors, '; '))
    local strata, level = catcher.calls.SetFrameStrata or 0, catcher.calls.SetFrameLevel or 0
    print('Quest catcher, 60 stable frames: SetFrameStrata=' .. strata .. ' SetFrameLevel=' .. level)
    assert(strata <= 1, 'Stable tracker repeated SetFrameStrata: ' .. strata)
    assert(level <= 1, 'Stable tracker repeated SetFrameLevel: ' .. level)
    ObjectiveTrackerFrame.level = 9
    ns.UpdateFaders(0.016)
    assert(catcher.calls.SetFrameLevel == level + 1, 'Changed tracker level did not reach the catcher')
    ObjectiveTrackerFrame = nil
end)

-- Shared bar fixture: MainMenuBar hosts MultiBarBottomLeft; MultiBarRight stands alone.
local function bars()
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    UIParent = frame()
    GetTime = function() return 100 end
    hooksecurefunc = function(obj, method, hook)
        local original = obj[method]
        obj[method] = function(self, ...)
            local result = original(self, ...)
            hook(self, ...)
            return result
        end
    end
    local ns = {}
    loadAddon('Core.lua', ns)
    for _, name in ipairs({ 'InEditMode', 'Glancing', 'BagsShouldShow', 'Hit' }) do
        ns[name] = function() return false end
    end
    ns.CharDB = function() return QuietUICharDB end
    ns.TouchHud = function() end
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    MainMenuBar = frame(UIParent); MainMenuBar.name = 'MainMenuBar'
    MultiBarBottomLeft = frame(MainMenuBar); MultiBarBottomLeft.name = 'MultiBarBottomLeft'
    MultiBarRight = frame(UIParent); MultiBarRight.name = 'MultiBarRight'
    CreateFrame = function() return frame(UIParent) end
    local function tick()
        ns.NextFadeTick()
        ns.UpdateBars(false, 1, true)
    end
    return ns, tick
end

test('Stable bars skip the owner ancestry pass after the first Collect', function()
    local ns, tick = bars()
    local barSet = { [MainMenuBar] = true, [MultiBarBottomLeft] = true, [MultiBarRight] = true }
    local ids = {}
    for _, row in ipairs(ns.BAR_ROWS) do ids[row.id] = true end
    -- IsAncestor is local; the owner pass is visible as pairs() over the bar -> row id map.
    local ownerWalks = 0
    local realPairs = pairs
    pairs = function(t)
        local key, value = next(t)
        if barSet[key] and type(value) == 'string' and ids[value] then ownerWalks = ownerWalks + 1 end
        return realPairs(t)
    end
    local ok, err = pcall(function()
        tick()
        ownerWalks = 0
        for _ = 1, 59 do tick() end
    end)
    pairs = realPairs
    assert(ok, err)
    print('Stable bars, 59 ticks after first Collect: owner walks=' .. ownerWalks)
    assert(ownerWalks == 0, 'UpdateBars repeated the owner ancestry pass: ' .. ownerWalks)
    MainMenuBar, MultiBarBottomLeft, MultiBarRight = nil, nil, nil
end)

test('ForgetBarButtons recomputes hosting; a bar nested in MainMenuBar still fades alone', function()
    local ns, tick = bars()
    tick()
    assert(MainMenuBar.alpha == 1 and MultiBarBottomLeft.alpha == 0 and MultiBarRight.alpha == 0,
        'Hosting MainMenuBar must stay opaque while its nested bar fades')
    -- Raw reparent bypasses the SetParent hook; only ForgetBarButtons may refresh the maps.
    MultiBarBottomLeft.parent = UIParent
    ns.ForgetBarButtons(); tick()
    assert(MainMenuBar.alpha == 0, 'MainMenuBar kept stale hosting after ForgetBarButtons')
    MultiBarBottomLeft.parent = MainMenuBar
    ns.ForgetBarButtons()
    MultiBarBottomLeft.alpha, MultiBarBottomLeft._quietAlpha = 1, nil
    tick()
    assert(MainMenuBar.alpha == 1, 'Re-nested MainMenuBar was not treated as a host again')
    assert(MultiBarBottomLeft.alpha == 0, 'Nested bar must keep fading on its own')
    MainMenuBar, MultiBarBottomLeft, MultiBarRight = nil, nil, nil
end)

os.exit(failures == 0 and 0 or 1)
