-- Run from the addon directory: lua tests/menu-cache.lua
-- The micro button list is rebuilt by RefreshChrome, not by every hover tick.
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function frame(name, x)
    local f = { name = name, alpha = 1, shown = true, x = x or 0 }
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetLeft() return self.x end
    function f:GetRight() return self.x + 20 end
    function f:GetTop() return 40 end
    function f:GetBottom() return 10 end
    function f:GetFrameStrata() return 'MEDIUM' end
    function f:GetFrameLevel() return 3 end
    function f:GetPoint() end
    for _, method in ipairs({ 'SetSize', 'SetFrameStrata', 'SetFrameLevel', 'SetClampedToScreen', 'SetMovable',
        'EnableMouse', 'RegisterForDrag', 'RegisterForClicks', 'SetScript', 'SetPoint', 'ClearAllPoints',
        'SetAllPoints', 'SetTexture', 'SetTexCoord', 'SetColorTexture' }) do
        f[method] = function() end
    end
    function f:CreateTexture() return frame() end
    return f
end

-- Micro buttons live behind an __index proxy on _G so every name lookup is counted.
local served, reads = {}, 0
setmetatable(_G, { __index = function(_, key)
    if type(key) == 'string' and key:find('MicroButton$') then reads = reads + 1 end
    return served[key]
end })

local function environment()
    for key in pairs(served) do served[key] = nil end
    served.CharacterMicroButton = frame('CharacterMicroButton', 0)
    served.SpellbookMicroButton = frame('SpellbookMicroButton', 20)
    served.QuestLogMicroButton = frame('QuestLogMicroButton', 40)
    served.MainMenuMicroButton = frame('MainMenuMicroButton', 60)
    served.HelpMicroButton = frame('HelpMicroButton', 80)
    UIParent = frame('UIParent')
    MICRO_BUTTONS = nil
    CreateFrame = function() return frame() end
    local s = { hover = false, faded = {} }
    local ns = {}
    ns.DB = function() return { enabled = true } end
    ns.Usable = function(f) return f ~= nil and not f:IsForbidden() end
    ns.FrameName = function(f) return f and f.name end
    ns.Hit = function(f) return s.hover and f ~= nil and f.name ~= nil and f.name:find('Micro') ~= nil end
    ns.VisibilityShow = function(_, usual, hovered) return usual or hovered or false end
    ns.UpdateFaded = function(f, show)
        s.faded[f] = (s.faded[f] or 0) + 1
        f.alpha = show and 1 or 0
    end
    ns.EachBagFrame = function() end
    ns.TreeHas = function() return false end
    for _, name in ipairs({ 'InEditMode', 'CursorHasItem', 'IsQueue', 'IsBarFrame', 'IsBagRelated', 'IsSpared' }) do
        ns[name] = function() return false end
    end
    for _, name in ipairs({ 'ArmCatcher', 'HoldAlpha', 'Mute', 'HideTextures', 'Print' }) do
        ns[name] = function() end
    end
    ns.Report = function(key, err) error(key .. ': ' .. tostring(err)) end
    assert(loadfile('Menu.lua'))('QuietUI', ns)
    s.ns = ns
    return s
end

test('Hover ticks between two RefreshChrome calls do not rebuild the micro list', function()
    local s = environment()
    s.ns.RefreshChrome()
    s.hover = true
    s.ns.UpdateMenuButton(0.016)
    reads = 0
    for _ = 1, 60 do s.ns.UpdateMenuButton(0.016) end
    local ticks = reads
    s.ns.RefreshChrome()
    print('Micro hover, 60 ticks: micro global reads=' .. ticks)
    assert(ticks == 0, 'Hover ticks rebuilt the micro button list: _G reads=' .. ticks)
    assert(served.CharacterMicroButton.alpha == 1 and served.HelpMicroButton.alpha == 1,
        'Hover must keep the micro menu shown')
end)

test('A micro button added before UpdateMicroButtons joins the cache and the fade', function()
    local s = environment()
    s.ns.RefreshChrome()
    s.ns.UpdateMenuButton(0.016)
    served.HousingMicroButton = frame('HousingMicroButton', 100)
    -- QuietUI hooks UpdateMicroButtons to ns.RefreshChrome.
    s.ns.RefreshChrome()
    s.ns.UpdateMenuButton(0.016)
    local added = served.HousingMicroButton
    assert(s.faded[added], 'New micro button was not included in the fade')
    assert(added.alpha == 0, 'New micro button must fade with the menu')
    s.hover = true
    s.ns.UpdateMenuButton(0.016)
    assert(added.alpha == 1, 'New micro button must show on hover with the menu')
end)

os.exit(failures == 0 and 0 or 1)
