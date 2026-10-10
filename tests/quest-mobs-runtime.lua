-- Run from the addon directory: lua tests/quest-mobs-runtime.lua
-- Runtime wiring for Quest mobs: ApplyAll / RestoreAll and event forwarding in QuietUI.lua.
local QM_EVENTS = {
    'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'QUEST_LOG_UPDATE', 'UNIT_QUEST_LOG_CHANGED',
    'PLAYER_ENTERING_WORLD',
}
local ARGS = {
    NAME_PLATE_UNIT_ADDED = { 'nameplate4' },
    NAME_PLATE_UNIT_REMOVED = { 'nameplate4' },
    QUEST_LOG_UPDATE = {},
    UNIT_QUEST_LOG_CHANGED = { 'player' },
    PLAYER_ENTERING_WORLD = { false, false },
}
-- Handlers that already ran for these events must keep running next to Quest mobs.
local EXISTING = {
    NAME_PLATE_UNIT_ADDED = { 'HighlightsEvent' },
    NAME_PLATE_UNIT_REMOVED = { 'HighlightsEvent', 'ForgetRangePlate' },
    QUEST_LOG_UPDATE = { 'QuestNoticeEvent' },
    PLAYER_ENTERING_WORLD = { 'HighlightsEvent', 'QuestNoticeEvent' },
}

-- Fresh QuietUI.lua runtime with counting ns stubs. opts.noQuestMobs leaves the module missing;
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
        'ApplyQuestNotice', 'RestoreQuestNotice', 'UpdateQuestNotice', 'ApplyHighlights', 'RestoreHighlights' }) do
        ns[key] = function() end
    end
    for _, key in ipairs({ 'HighlightsEvent', 'QuestNoticeEvent', 'ForgetRangePlate' }) do ns[key] = spy(key) end
    ns.Report = function(key, err) env.errors[#env.errors + 1] = tostring(key) .. ': ' .. tostring(err) end
    if not opts.noQuestMobs then
        for _, key in ipairs({ 'ApplyQuestMobs', 'RestoreQuestMobs', 'QuestMobsEvent' }) do ns[key] = spy(key) end
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
    function env.forwards(name, from, spyName)
        spyName = spyName or 'QuestMobsEvent'
        local list = {}
        for i = (from or 0) + 1, env.count(spyName) do
            if spyName == 'ForgetRangePlate' or calls[spyName][i][1] == name then list[#list + 1] = calls[spyName][i] end
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

test('boot applies quest mobs without runtime errors', function()
    noErrors(main)
    assert(main.count('ApplyQuestMobs') > 0, 'Boot (ApplyAll) must call ns.ApplyQuestMobs')
end)

test('Save path ns.ApplyAll calls ApplyQuestMobs', function()
    local n = main.count('ApplyQuestMobs')
    main.ns.ApplyAll()
    assert(main.count('ApplyQuestMobs') > n, 'ns.ApplyAll must call ns.ApplyQuestMobs')
end)

test('quest mob events are registered, including UNIT_QUEST_LOG_CHANGED', function()
    for _, name in ipairs(QM_EVENTS) do
        assert(main.events.registered[name], 'Missing registered ' .. name)
    end
end)

test('enabled runtime forwards each quest mob event once with original arguments', function()
    for _, name in ipairs(QM_EVENTS) do
        local n = main.count('QuestMobsEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        local got = main.forwards(name, n)
        assert(#got == 1, 'Expected one forward of ' .. name .. ' to ns.QuestMobsEvent, got ' .. #got)
        local want = ARGS[name]
        assert(got[1].n == #want + 1, name .. ': argument count changed (' .. tostring(got[1].n - 1) .. ' vs ' .. #want .. ')')
        for i, v in ipairs(want) do
            assert(got[1][i + 1] == v, name .. ': argument ' .. i .. ' lost')
        end
    end
    noErrors(main)
end)

test('existing handlers still run next to the quest mob forward', function()
    for name, spies in pairs(EXISTING) do
        for _, spyName in ipairs(spies) do
            local n = main.count(spyName)
            main.dispatch(name, table.unpack(ARGS[name]))
            assert(#main.forwards(name, n, spyName) >= 1, name .. ' no longer reaches ' .. spyName)
        end
    end
    noErrors(main)
end)

test('Glance toggle does not apply or restore quest mobs', function()
    local a, r = main.count('ApplyQuestMobs'), main.count('RestoreQuestMobs')
    main.glance('down'); main.slash('glance')
    assert(main.count('ApplyQuestMobs') == a and main.count('RestoreQuestMobs') == r, 'Glance must not touch quest mobs')
    main.glance('down')
end)

test('Edit Mode layout update does not apply or restore quest mobs', function()
    local a, r = main.count('ApplyQuestMobs'), main.count('RestoreQuestMobs')
    main.dispatch('EDIT_MODE_LAYOUTS_UPDATED')
    assert(main.count('ApplyQuestMobs') == a and main.count('RestoreQuestMobs') == r, 'Edit Mode must not touch quest mobs')
end)

test('/quiet off calls RestoreQuestMobs', function()
    local n = main.count('RestoreQuestMobs')
    main.slash('off')
    assert(main.count('RestoreQuestMobs') > n, '/quiet off (RestoreAll) must call ns.RestoreQuestMobs')
end)

test('disabled runtime forwards no plate or quest log events', function()
    assert(main.db.enabled == false, 'Precondition: disabled')
    for _, name in ipairs({ 'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'QUEST_LOG_UPDATE', 'UNIT_QUEST_LOG_CHANGED' }) do
        local n = main.count('QuestMobsEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        assert(#main.forwards(name, n) == 0, name .. ' must not be forwarded while disabled')
    end
    noErrors(main)
end)

test('/quiet on calls ApplyQuestMobs', function()
    local n = main.count('ApplyQuestMobs')
    main.slash('on')
    assert(main.count('ApplyQuestMobs') > n, '/quiet on must call ns.ApplyQuestMobs')
    noErrors(main)
end)

test('missing quest mobs module does not error', function()
    local env = Load({ noQuestMobs = true })
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    env.dispatch('PLAYER_LOGIN')
    for _, name in ipairs(QM_EVENTS) do env.dispatch(name, table.unpack(ARGS[name])) end
    env.ns.ApplyAll()
    env.slash('off')
    env.slash('on')
    noErrors(env)
end)

test('RegisterEvent failing for UNIT_QUEST_LOG_CHANGED keeps loading and the other events', function()
    local env = Load({ throwOn = 'UNIT_QUEST_LOG_CHANGED' })
    assert(not env.loadError, 'A throwing RegisterEvent must not break loading: ' .. tostring(env.loadError))
    for _, name in ipairs(QM_EVENTS) do
        if name ~= 'UNIT_QUEST_LOG_CHANGED' then
            assert(env.events.registered[name], 'Missing registered ' .. name)
        end
    end
    env.dispatch('PLAYER_LOGIN')
    local n = env.count('QuestMobsEvent')
    env.dispatch('QUEST_LOG_UPDATE')
    assert(#env.forwards('QUEST_LOG_UPDATE', n) == 1, 'Other events must still forward')
end)

test('Boot while disabled reaches RestoreQuestMobs and not ApplyQuestMobs', function()
    local env = Load({ db = { enabled = false } })
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    env.dispatch('PLAYER_LOGIN')
    assert(env.count('RestoreQuestMobs') > 0, 'Boot while disabled must call ns.RestoreQuestMobs (ApplyAll -> RestoreAll)')
    assert(env.count('ApplyQuestMobs') == 0, 'Boot while disabled must not apply quest mobs')
    noErrors(env)
end)

test('TOC loads QuestMobs.lua after Highlights.lua and before QuietUI.lua', function()
    local f = assert(io.open('QuietUI.toc')); local toc = f:read('*a'); f:close()
    local highlights = toc:find('\nHighlights.lua', 1, true)
    local feature = toc:find('\nQuestMobs.lua', 1, true)
    local runtime = toc:find('\nQuietUI.lua', 1, true)
    assert(feature, 'TOC must list QuestMobs.lua')
    assert(highlights and runtime and highlights < feature and feature < runtime,
        'TOC order must be Highlights.lua, QuestMobs.lua, QuietUI.lua')
end)

print(string.format('%d/%d quest mobs runtime cases passed', cases - failures, cases))
if failures > 0 then os.exit(1) end
