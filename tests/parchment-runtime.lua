-- Run from the addon directory: lua tests/parchment-runtime.lua
-- Runtime wiring for Parchment windows: ApplyAll / RestoreAll and event forwarding in QuietUI.lua.
local PM_EVENTS = {
    'QUEST_DETAIL', 'QUEST_PROGRESS', 'QUEST_COMPLETE', 'QUEST_GREETING', 'GOSSIP_SHOW', 'ITEM_TEXT_READY',
    'ADDON_LOADED',
}
local ARGS = {
    QUEST_DETAIL = { 'npc' },
    QUEST_PROGRESS = {},
    QUEST_COMPLETE = {},
    QUEST_GREETING = {},
    GOSSIP_SHOW = { 'gossip' },
    ITEM_TEXT_READY = {},
    ADDON_LOADED = { 'Blizzard_GossipFrame', false },
}
-- Window events are gated like every other active-only event; ADDON_LOADED always runs.
local WINDOW_EVENTS = { 'QUEST_DETAIL', 'QUEST_PROGRESS', 'QUEST_COMPLETE', 'QUEST_GREETING', 'GOSSIP_SHOW', 'ITEM_TEXT_READY' }

-- Fresh QuietUI.lua runtime with counting ns stubs. opts.noParchment leaves the module missing;
-- opts.throwOn makes RegisterEvent fail for that event name like an unknown event on this client.
local function Load(opts)
    opts = opts or {}
    local env = { ns = {}, calls = {}, errors = {}, db = opts.db or { enabled = true } }
    local ns, calls = env.ns, env.calls
    local events = { scripts = {}, registered = {} }
    env.events = events
    local function spy(name)
        return function(...) calls[name] = calls[name] or {}; calls[name][#calls[name] + 1] = { n = select('#', ...), ... } end
    end
    env.spy = spy
    ns.DB = function() return env.db end
    ns.CharDB = function() return {} end
    ns.ForceQuietLayout = function() return false end
    ns.ModernChat = function() return false end
    ns.FrameHot = function() return false end
    ns.FocusChanged = function() return false end
    ns.ConsumeHud = function() return false end
    ns.ShowAll = function() return false end
    for _, key in ipairs({ 'UpdateRange', 'UpdateSmooth', 'ForgetCursor', 'BeginTick', 'NextFadeTick', 'RefreshWorld', 'EnsureLayout',
        'RefreshChrome', 'RestoreChat', 'UpdateBars', 'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots', 'HideQuestCatcher',
        'HideRangeMark', 'HideBarCatchers', 'ResetMenu', 'RestoreAlpha', 'Print', 'FindFaders', 'UpdateParty', 'ScanSwing',
        'EnsureMinimap', 'NoteCombat', 'MarkCombatEnd', 'MarkQuestXP', 'ForgetBarButtons', 'ForgetRangeSlot',
        'StripAllChat', 'RestripChat', 'ScanParty', 'ShowSetup', 'PresetCommand', 'SyncVisibleEdits', 'UpdateChat',
        'ApplyQuestNotice', 'RestoreQuestNotice', 'UpdateQuestNotice', 'ApplyHighlights', 'RestoreHighlights',
        'ApplyQuestMobs', 'RestoreQuestMobs' }) do
        ns[key] = function() end
    end
    for _, key in ipairs({ 'HighlightsEvent', 'QuestNoticeEvent', 'QuestMobsEvent', 'ForgetRangePlate' }) do ns[key] = spy(key) end
    ns.Report = function(key, err) env.errors[#env.errors + 1] = tostring(key) .. ': ' .. tostring(err) end
    if not opts.noParchment then
        for _, key in ipairs({ 'ApplyParchment', 'RestoreParchment', 'ParchmentEvent' }) do ns[key] = spy(key) end
    end
    function events:SetScript(key, value) self.scripts[key] = value end
    function events:RegisterEvent(name)
        if opts.throwOn and name == opts.throwOn then error('Attempt to register unknown event "' .. name .. '"') end
        self.registered[name] = true
    end
    CreateFrame = function() return events end
    GetTime = function() return 100 end
    GetCursorPosition = function() return 0, 0 end
    InCombatLockdown = function() return false end
    C_Timer = nil
    SlashCmdList = {}
    local ok, err = pcall(assert(loadfile('QuietUI.lua')), 'QuietUI', ns)
    env.loadError = not ok and tostring(err) or nil
    env.slash = SlashCmdList.QUIETUI
    env.glance = QuietUIGlance
    function env.count(name) return #(calls[name] or {}) end
    function env.dispatch(name, ...) events.scripts.OnEvent(events, name, ...) end
    function env.forwards(name, from)
        local list = {}
        for i = (from or 0) + 1, env.count('ParchmentEvent') do
            if calls.ParchmentEvent[i][1] == name then list[#list + 1] = calls.ParchmentEvent[i] end
        end
        return list
    end
    return env
end

local failures, cases = 0, 0
local function test(name, fn)
    cases = cases + 1
    local ok, err = pcall(fn)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function noErrors(env) assert(#env.errors == 0, 'Runtime errors: ' .. table.concat(env.errors, '; ')) end

local main = Load()
assert(not main.loadError, 'Harness: QuietUI.lua failed to load: ' .. tostring(main.loadError))
assert(main.events.scripts.OnEvent and main.slash, 'Harness: runtime did not install OnEvent or /quiet')
main.dispatch('PLAYER_LOGIN')
-- The existing ADDON_LOADED handler calls ns.RequestRescan for other addons after boot.
main.ns.RequestRescan = main.spy('RequestRescan')

test('boot applies parchment without runtime errors', function()
    noErrors(main)
    assert(main.count('ApplyParchment') > 0, 'Boot (ApplyAll) must call ns.ApplyParchment')
end)

test('Save path ns.ApplyAll calls ApplyParchment', function()
    local n = main.count('ApplyParchment')
    main.ns.ApplyAll()
    assert(main.count('ApplyParchment') > n, 'ns.ApplyAll must call ns.ApplyParchment')
end)

test('parchment events are registered', function()
    for _, name in ipairs(PM_EVENTS) do
        assert(main.events.registered[name], 'Missing registered ' .. name)
    end
end)

test('enabled runtime forwards each parchment event once with original arguments', function()
    for _, name in ipairs(PM_EVENTS) do
        local n = main.count('ParchmentEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        local got = main.forwards(name, n)
        assert(#got == 1, 'Expected one forward of ' .. name .. ' to ns.ParchmentEvent, got ' .. #got)
        local want = ARGS[name]
        assert(got[1].n == #want + 1, name .. ': argument count changed (' .. tostring(got[1].n - 1) .. ' vs ' .. #want .. ')')
        for i, v in ipairs(want) do
            assert(got[1][i + 1] == v, name .. ': argument ' .. i .. ' lost')
        end
    end
    noErrors(main)
end)

test('existing ADDON_LOADED handler still runs next to the parchment forward', function()
    local r, p = main.count('RequestRescan'), main.count('ParchmentEvent')
    main.dispatch('ADDON_LOADED', 'Blizzard_ItemTextUI', false)
    assert(main.count('RequestRescan') == r + 1, 'ADDON_LOADED no longer reaches ns.RequestRescan')
    assert(#main.forwards('ADDON_LOADED', p) == 1, 'ADDON_LOADED must also reach ns.ParchmentEvent')
    noErrors(main)
end)

test('Glance toggle does not apply or restore parchment', function()
    local a, r = main.count('ApplyParchment'), main.count('RestoreParchment')
    main.glance('down'); main.slash('glance')
    assert(main.count('ApplyParchment') == a and main.count('RestoreParchment') == r, 'Glance must not touch parchment')
    main.glance('down')
end)

test('Edit Mode layout update does not apply or restore parchment', function()
    local a, r = main.count('ApplyParchment'), main.count('RestoreParchment')
    main.dispatch('EDIT_MODE_LAYOUTS_UPDATED')
    assert(main.count('ApplyParchment') == a and main.count('RestoreParchment') == r, 'Edit Mode must not touch parchment')
end)

test('/quiet off calls RestoreParchment', function()
    local n = main.count('RestoreParchment')
    main.slash('off')
    assert(main.count('RestoreParchment') > n, '/quiet off (RestoreAll) must call ns.RestoreParchment')
end)

test('disabled runtime forwards no window events', function()
    assert(main.db.enabled == false, 'Precondition: disabled')
    for _, name in ipairs(WINDOW_EVENTS) do
        local n = main.count('ParchmentEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        assert(#main.forwards(name, n) == 0, name .. ' must not be forwarded while disabled')
    end
    noErrors(main)
end)

test('/quiet on calls ApplyParchment', function()
    local n = main.count('ApplyParchment')
    main.slash('on')
    assert(main.count('ApplyParchment') > n, '/quiet on must call ns.ApplyParchment')
    noErrors(main)
end)

test('missing parchment module does not error', function()
    local env = Load({ noParchment = true })
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    env.dispatch('PLAYER_LOGIN')
    for _, name in ipairs(PM_EVENTS) do env.dispatch(name, table.unpack(ARGS[name])) end
    env.ns.ApplyAll()
    env.slash('off')
    env.slash('on')
    noErrors(env)
end)

test('RegisterEvent failing for QUEST_GREETING keeps loading and the other events', function()
    local env = Load({ throwOn = 'QUEST_GREETING' })
    assert(not env.loadError, 'A throwing RegisterEvent must not break loading: ' .. tostring(env.loadError))
    for _, name in ipairs(PM_EVENTS) do
        if name ~= 'QUEST_GREETING' then
            assert(env.events.registered[name], 'Missing registered ' .. name)
        end
    end
    env.dispatch('PLAYER_LOGIN')
    local n = env.count('ParchmentEvent')
    env.dispatch('GOSSIP_SHOW', 'gossip')
    assert(#env.forwards('GOSSIP_SHOW', n) == 1, 'Other events must still forward')
end)

test('Boot while disabled reaches RestoreParchment and not ApplyParchment', function()
    local env = Load({ db = { enabled = false } })
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    env.dispatch('PLAYER_LOGIN')
    assert(env.count('RestoreParchment') > 0, 'Boot while disabled must call ns.RestoreParchment (ApplyAll -> RestoreAll)')
    assert(env.count('ApplyParchment') == 0, 'Boot while disabled must not apply parchment')
    noErrors(env)
end)

test('A throwing ParchmentEvent keeps the other handlers and reports once under parchment', function()
    local env = Load()
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    -- The real Core report: once per key, printed to chat.
    local core = {}
    assert(loadfile('Core.lua'))('QuietUI', core)
    env.ns.Report = core.Report
    env.dispatch('PLAYER_LOGIN')
    env.ns.RequestRescan = env.spy('RequestRescan')
    local thrown = 0
    env.ns.ParchmentEvent = function() thrown = thrown + 1; error('parchment exploded') end
    local printed = {}
    local realPrint = print
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        printed[#printed + 1] = table.concat(parts, ' ')
    end
    local rescans = env.count('RequestRescan')
    local ok, err = pcall(function()
        env.dispatch('QUEST_DETAIL', 'npc')
        env.dispatch('ADDON_LOADED', 'Blizzard_GossipFrame', false)
        env.dispatch('GOSSIP_SHOW', 'gossip')
    end)
    print = realPrint
    assert(ok, 'Dispatch crashed: ' .. tostring(err))
    assert(thrown == 3, 'Expected ParchmentEvent to be reached for all three events, got ' .. thrown)
    assert(env.count('RequestRescan') == rescans + 1, 'ADDON_LOADED skipped ns.RequestRescan')
    assert(#printed == 1, 'Expected exactly one error report, got ' .. #printed .. ': ' .. table.concat(printed, ' | '))
    assert(printed[1]:lower():find('parchment', 1, true) and printed[1]:find('exploded', 1, true),
        'The report is not under the parchment key: ' .. printed[1])
end)

test('ADDON_LOADED before boot does not reach ParchmentEvent, so saved variables are not touched early', function()
    local env = Load()
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    -- An addon sorted before QuietUI loads before our saved variables exist.
    env.dispatch('ADDON_LOADED', 'CzechForever', false)
    env.dispatch('ADDON_LOADED', 'QuietUI', false)
    assert(env.count('ParchmentEvent') == 0, 'ADDON_LOADED before boot must not reach ns.ParchmentEvent')
    env.dispatch('PLAYER_LOGIN')
    env.ns.RequestRescan = env.spy('RequestRescan')
    env.dispatch('ADDON_LOADED', 'Blizzard_ItemTextUI', false)
    assert(#env.forwards('ADDON_LOADED') == 1, 'ADDON_LOADED after boot must reach ns.ParchmentEvent')
    noErrors(env)
end)

test('TOC loads Parchment.lua after QuestMobs.lua and before QuietUI.lua', function()
    local f = assert(io.open('QuietUI.toc')); local toc = f:read('*a'); f:close()
    local questMobs = toc:find('\nQuestMobs.lua', 1, true)
    local feature = toc:find('\nParchment.lua', 1, true)
    local runtime = toc:find('\nQuietUI.lua', 1, true)
    assert(feature, 'TOC must list Parchment.lua')
    assert(questMobs and runtime and questMobs < feature and feature < runtime,
        'TOC order must be QuestMobs.lua, Parchment.lua, QuietUI.lua')
end)

print(string.format('%d/%d parchment runtime cases passed', cases - failures, cases))
if failures > 0 then os.exit(1) end
