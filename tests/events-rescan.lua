-- Run from the addon directory: lua tests/events-rescan.lua
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function frame(name)
    local obj = { alpha = 1, shown = true, scripts = {}, name = name }
    function obj:IsForbidden() return false end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:IsShown() return self.shown end
    function obj:GetName() return self.name end
    function obj:SetScript(key, fn) self.scripts[key] = fn end
    function obj:RegisterEvent() end
    return obj
end

local STUBS = { 'RefreshWorld', 'FindFaders', 'ScanSwing', 'ForgetBarButtons', 'EnsureLayout', 'RefreshChrome',
    'StripAllChat', 'RestoreChat', 'BeginTick', 'UpdateBars', 'UpdateFaders', 'UpdateMenuButton', 'UpdateParty',
    'UpdateBagSlots', 'EnsureMinimap', 'ForgetCursor', 'UpdateRange', 'UpdateSmooth', 'UpdateChat',
    'SyncVisibleEdits', 'HideQuestCatcher', 'HideRangeMark', 'HideBarCatchers', 'ResetMenu', 'NoteCombat',
    'MarkCombatEnd', 'MarkQuestXP', 'ForgetRangeSlot', 'ForgetRangePlate' }

-- Boots QuietUI.lua against stubs. Rescan is the only caller of FindFaders(true).
local function harness(opts)
    opts = opts or {}
    local h = { timers = {}, rescans = 0, greetings = 0, prints = {}, hooks = {} }
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    UIParent = frame('UIParent')
    GetTime = function() return 100 end
    GetCursorPosition = function() return 0, 0 end
    NUM_CHAT_WINDOWS = 3
    for _, name in ipairs({ 'FCF_SetWindowAlpha', 'FCF_SetWindowColor', 'FCF_DockUpdate', 'UpdateMicroButtons' }) do
        _G[name] = function() end
    end
    hooksecurefunc = function(a, b, c)
        if type(a) == 'string' then h.hooks[a] = b; return end
        local original = a[b]
        a[b] = function(self, ...)
            local result = original(self, ...)
            c(self, ...)
            return result
        end
    end
    if opts.noTimer then
        C_Timer = nil
    else
        C_Timer = { After = function(delay, fn) h.timers[#h.timers + 1] = { delay = delay, fn = fn } end }
    end
    local ns = {}
    h.ns = ns
    loadAddon('Core.lua', ns)
    for _, key in ipairs(STUBS) do ns[key] = function() end end
    for _, key in ipairs({ 'ShowAll', 'FocusChanged', 'ConsumeHud', 'FrameHot' }) do
        ns[key] = function() return false end
    end
    ns.CharDB = function() return QuietUICharDB end
    ns.ModernChat = function() return QuietUICharDB.chat ~= false end
    ns.ForceQuietLayout = function() return opts.force or false end
    ns.SelectQuietLayout = function() return true end
    ns.RestorePreviousLayout = function() return true end
    ns.FindFaders = function(full) if full then h.rescans = h.rescans + 1 end end
    ns.Print = function(msg)
        h.prints[#h.prints + 1] = msg
        if tostring(msg):match('^is ') then h.greetings = h.greetings + 1 end
    end
    if opts.chat then loadAddon('Chat.lua', ns) end
    local events = frame()
    CreateFrame = function() return events end
    SlashCmdList = {}
    local realPrint = print
    print = function() end
    local ok, err = pcall(loadAddon, 'QuietUI.lua', ns)
    print = realPrint
    assert(ok, err)
    function h.fire(event, ...)
        local saved = print
        print = function() end
        events.scripts.OnEvent(events, event, ...)
        print = saved
    end
    -- Runs callbacks queued for the next frame (delay 0) only.
    function h.nextFrame()
        local due, later = {}, {}
        for _, timer in ipairs(h.timers) do
            if timer.delay == 0 then due[#due + 1] = timer else later[#later + 1] = timer end
        end
        h.timers = later
        for _, timer in ipairs(due) do timer.fn() end
    end
    function h.count(delay)
        local n = 0
        for _, timer in ipairs(h.timers) do if timer.delay == delay then n = n + 1 end end
        return n
    end
    return h
end

test('Three foreign ADDON_LOADED in one frame rescan exactly once', function()
    local h = harness()
    h.fire('PLAYER_LOGIN')
    h.nextFrame()
    h.rescans = 0
    h.fire('ADDON_LOADED', 'Foo')
    h.fire('ADDON_LOADED', 'Bar')
    h.fire('ADDON_LOADED', 'Baz')
    assert(h.rescans == 0, 'ADDON_LOADED rescanned synchronously ' .. h.rescans .. ' times')
    h.nextFrame()
    assert(h.rescans == 1, 'Expected one rescan after the timer, got ' .. h.rescans)
end)

test('Login then initial PLAYER_ENTERING_WORLD greets and arms the layout once', function()
    local h = harness({ force = true })
    h.fire('PLAYER_LOGIN')
    h.fire('PLAYER_ENTERING_WORLD', true, false)
    assert(h.greetings == 1, 'Greeting printed ' .. h.greetings .. ' times')
    -- ArmLayoutSettle schedules its retries at 1, 3 and 6 seconds.
    assert(h.count(1) == 1, 'ArmLayoutSettle armed ' .. h.count(1) .. ' times')
    h.rescans = 0
    h.nextFrame()
    assert(h.rescans <= 1, 'Rescan ran ' .. h.rescans .. ' times after PEW in one frame')
end)

test('Zoning PLAYER_ENTERING_WORLD rescans once by next frame without a greeting', function()
    local h = harness()
    h.fire('PLAYER_LOGIN')
    h.nextFrame()
    h.rescans, h.greetings = 0, 0
    h.fire('PLAYER_ENTERING_WORLD', false, false)
    h.nextFrame()
    assert(h.rescans == 1, 'Zoning rescans: ' .. h.rescans)
    assert(h.greetings == 0, 'Zoning printed the greeting')
end)

test('RequestRescan without C_Timer rescans immediately', function()
    local h = harness({ noTimer = true })
    h.fire('PLAYER_LOGIN')
    h.rescans = 0
    assert(type(h.ns.RequestRescan) == 'function', 'ns.RequestRescan is missing')
    h.ns.RequestRescan()
    assert(h.rescans == 1, 'Without C_Timer rescans: ' .. h.rescans)
end)

test('RequestRescan does nothing while QuietUI is disabled', function()
    local h = harness()
    h.fire('PLAYER_LOGIN')
    h.nextFrame()
    QuietUIDB.enabled = false
    h.rescans = 0
    local queued = h.count(0)
    assert(type(h.ns.RequestRescan) == 'function', 'ns.RequestRescan is missing')
    h.ns.RequestRescan()
    assert(h.count(0) == queued, 'Disabled RequestRescan scheduled a timer')
    h.nextFrame()
    assert(h.rescans == 0, 'Disabled RequestRescan rescanned')
end)

-- Chat windows without AddMessage skip bubbles; HideTextures marks a stripped window.
local function chatHarness()
    local h = harness({ chat = true })
    for i = 1, 3 do _G['ChatFrame' .. i] = frame('ChatFrame' .. i) end
    ChatFrameMenuButton = frame('ChatFrameMenuButton')
    h.stripped, h.chrome = {}, 0
    h.ns.HideTextures = function(target)
        if target and target.name then h.stripped[target.name] = (h.stripped[target.name] or 0) + 1 end
    end
    h.ns.HideBackground = function() end
    h.ns.Mute = function(target) if target == ChatFrameMenuButton then h.chrome = h.chrome + 1 end end
    h.fire('PLAYER_LOGIN')
    h.nextFrame()
    return h
end

test('FCF_SetWindowColor restrips only the passed chat frame', function()
    local h = chatHarness()
    assert(ChatFrame1._quietStripped and ChatFrame3._quietStripped, 'Login did not strip chat')
    h.stripped, h.chrome = {}, 0
    assert(h.hooks.FCF_SetWindowColor, 'FCF_SetWindowColor is not hooked')
    h.hooks.FCF_SetWindowColor(ChatFrame3, 0, 0, 0)
    assert(h.stripped.ChatFrame3 == 1, 'ChatFrame3 was not restripped')
    assert(h.stripped.ChatFrame1 == nil, 'ChatFrame1 was reprocessed')
    assert(h.stripped.ChatFrame2 == nil, 'ChatFrame2 was reprocessed')
    assert(h.chrome == 0, 'CHAT_CHROME was muted again')
end)

test('FCF_DockUpdate strips only windows not yet stripped', function()
    local h = chatHarness()
    ChatFrame2._quietStripped = nil
    h.stripped, h.chrome = {}, 0
    assert(h.hooks.FCF_DockUpdate, 'FCF_DockUpdate is not hooked')
    h.hooks.FCF_DockUpdate()
    assert(h.stripped.ChatFrame2 == 1, 'New window ChatFrame2 was not stripped')
    assert(h.stripped.ChatFrame1 == nil and h.stripped.ChatFrame3 == nil, 'Stripped windows were forced again')
    assert(h.chrome == 0, 'CHAT_CHROME was muted again')
end)

for i = 1, 3 do _G['ChatFrame' .. i] = nil end
if failures > 0 then os.exit(1) end
