-- Run from the addon directory: lua tests/cpu-idle.lua
local unpack = table.unpack or unpack
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function frame(parent)
    local obj = { alpha = 1, shown = true, parent = parent, scripts = {}, children = {}, regions = {} }
    function obj:IsForbidden() return false end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:IsShown() return self.shown end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:GetParent() return self.parent end
    function obj:SetParent(value) self.parent = value end
    function obj:GetName() return self.name end
    function obj:GetFrameLevel() return 1 end
    function obj:GetNumChildren() return #self.children end
    function obj:GetChildren() return unpack(self.children) end
    function obj:GetRegions() return unpack(self.regions) end
    function obj:SetScript(name, fn) self.scripts[name] = fn end
    function obj:RegisterEvent() end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel',
        'EnableMouse', 'EnableMouseWheel' }) do
        obj[name] = function() end
    end
    return obj
end
local function boot(ns)
    local created = {}
    CreateFrame = function()
        local obj = frame(UIParent)
        created[#created + 1] = obj
        return obj
    end
    SlashCmdList = {}
    loadAddon('QuietUI.lua', ns)
    local events = created[1]
    local update = events.scripts.OnUpdate
    for i = 1, 100 do
        local name = debug.getupvalue(update, i)
        if name == 'booted' then debug.setupvalue(update, i, true) break end
        if not name then break end
    end
    return function(elapsed) update(events, elapsed) end
end

test('Periodic bar refresh waits for a child-count change', function()
    local ns = {}
    QuietUIDB = { enabled = true }
    UIParent = frame()
    MainActionBar = frame(UIParent)
    MainActionBar.name = 'MainActionBar'
    MainActionBar.children = { frame(MainActionBar) }
    GetCursorPosition = function() return 0, 0 end
    GetTime = function() return 1000 end
    loadAddon('Core.lua', ns)
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    ns.CharDB = function() return {} end
    ns.BagsShouldShow = function() return false end
    local touches = 0
    local realTouch = ns.TouchHud
    ns.TouchHud = function()
        touches = touches + 1
        realTouch()
    end
    local errors = {}
    ns.Report = function(name, err) errors[#errors + 1] = name .. ': ' .. tostring(err) end
    for _, key in ipairs({ 'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots', 'UpdateRange',
        'UpdateSmooth', 'FindFaders', 'RefreshChrome' }) do
        ns[key] = function() end
    end
    ns.ModernChat = function() return false end
    local update = boot(ns)
    update(1)
    update(1)
    assert(touches == 0, 'Stable bars still rebuilt the HUD: ' .. touches)
    MainActionBar.children[#MainActionBar.children + 1] = frame(MainActionBar)
    update(1)
    assert(touches == 1, 'A new child did not rebuild bar buttons')
    assert(#errors == 0, 'Idle tick reported: ' .. table.concat(errors, '; '))
    MainActionBar = nil
end)

test('Missing child counts rebuild on a five second fallback', function()
    local ns = {}
    QuietUIDB = { enabled = true }
    UIParent = frame()
    MainActionBar = frame(UIParent)
    MainActionBar.name = 'MainActionBar'
    MainActionBar.GetNumChildren = nil
    local now = 1000
    GetCursorPosition = function() return 0, 0 end
    GetTime = function() return now end
    loadAddon('Core.lua', ns)
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    ns.CharDB = function() return {} end
    ns.BagsShouldShow = function() return false end
    local touches = 0
    local realTouch = ns.TouchHud
    ns.TouchHud = function()
        touches = touches + 1
        realTouch()
    end
    ns.Report = function() end
    for _, key in ipairs({ 'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots', 'UpdateRange',
        'UpdateSmooth', 'FindFaders', 'RefreshChrome' }) do
        ns[key] = function() end
    end
    ns.ModernChat = function() return false end
    local update = boot(ns)
    update(1)
    update(1)
    assert(touches == 0, 'Missing GetNumChildren rebuilt bars before five seconds')
    now = 1005
    update(1)
    assert(touches == 1, 'Five second fallback did not rebuild bars')
    MainActionBar = nil
end)

test('Party alpha tree stays unread while autohide is off', function()
    local ns = {}
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    UIParent = frame()
    loadAddon('Core.lua', ns)
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    PartyFrame = frame(UIParent)
    PartyFrame.name = 'PartyFrame'
    local unit = frame(PartyFrame)
    PartyFrame.children = { unit }
    local walks = 0
    function PartyFrame:GetChildren()
        walks = walks + 1
        return unit
    end
    function PartyFrame:GetRegions()
        walks = walks + 1
    end
    ns.FindFaders(false)
    assert(walks == 0, 'Autohide off still walked party frames')
    QuietUICharDB.autoHideParty = true
    ns.FindFaders(false)
    assert(walks > 0, 'Autohide on did not collect party alphas')
    PartyFrame = nil
end)

test('Still pointer does not probe settled chat bubbles', function()
    local ns = {}
    QuietUIDB = { enabled = true }
    UIParent = frame()
    loadAddon('Core.lua', ns)
    loadAddon('Chat.lua', ns)
    NUM_CHAT_WINDOWS = 1
    local overs = 0
    local bubble = frame()
    function bubble:IsMouseOver()
        overs = overs + 1
        return false
    end
    local msg = {}
    ChatFrame1 = frame()
    ChatFrame1._quietBubbles = true
    ChatFrame1._quietByMsg = { [msg] = bubble }
    GetTime = function() return 10 end
    ns.ModernChat = function() return true end
    ns.PointerMoved = function() return false end
    ns.UpdateChat(1 / 60)
    assert(overs == 0, 'Stationary chat still called IsMouseOver')
    bubble._quietHot = true
    ns.UpdateChat(1 / 60)
    assert(overs >= 1, 'A hot bubble was not checked for the pointer leaving')
    overs = 0
    bubble._quietHot = false
    ns.PointerMoved = function() return true end
    ns.UpdateChat(1 / 60)
    assert(overs >= 1, 'A moving pointer skipped bubble hover')
    ChatFrame1 = nil
end)

test('Layout retry stays idle without a pending layout or preview', function()
    local ns = {}
    QuietUIDB = { enabled = true }
    UIParent = frame()
    GetCursorPosition = function() return 4, 4 end
    loadAddon('Core.lua', ns)
    loadAddon('Layout.lua', ns)
    local calls = 0
    ns.UpdateLayoutPreview = function()
        calls = calls + 1
        return true
    end
    ns.ConsumeHud = function() return false end
    ns.ForgetCursor = function() end
    ns.ShowAll = function() return false end
    ns.FocusChanged = function() return false end
    ns.ModernChat = function() return false end
    ns.FrameHot = function() return false end
    for _, key in ipairs({ 'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots', 'UpdateRange',
        'UpdateSmooth', 'FindFaders', 'ScanSwing', 'RefreshWorld', 'RefreshChrome',
        'NextFadeTick', 'BeginTick', 'UpdateBars' }) do
        ns[key] = function() end
    end
    local update = boot(ns)
    update(0.2)
    update(0.2)
    assert(calls == 0, 'Idle ticks still ran layout preview')
    ns.LayoutPreviewActive = function() return true end
    update(0.2)
    assert(calls == 1, 'An open preview did not keep retrying')
end)

test('Swing scan skips debug names on named frames and keeps a found timer', function()
    local ns = {}
    UIParent = frame()
    local named = frame(UIParent)
    named.name = 'PlayerFrame'
    function named:GetDebugName() error('Named frames must not ask for a debug name') end
    local anon = frame(UIParent)
    function anon:GetName() return nil end
    local debugs, walks = 0, 0
    function anon:GetDebugName()
        debugs = debugs + 1
        return 'OffHandSwingTimer'
    end
    function UIParent:GetChildren()
        walks = walks + 1
        return named, anon
    end
    GetTime = function() return 50 end
    loadAddon('Core.lua', ns)
    loadAddon('Bars.lua', ns)
    ns.ScanSwing()
    assert(debugs == 1, 'Anonymous swing frame was not identified')
    assert(walks == 1, 'The first scan did not walk UIParent')
    ns.ScanSwing()
    assert(walks == 1 and debugs == 1, 'A live swing timer was scanned again inside 10s')
end)

os.exit(failures == 0 and 0 or 1)
