-- Run from the addon directory: lua tests/highlights-runtime.lua
-- Runtime wiring for Highlights: ApplyAll / RestoreAll and event forwarding in QuietUI.lua.
local HL_EVENTS = {
    'PLAYER_SOFT_INTERACT_CHANGED', 'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'ZONE_CHANGED_NEW_AREA',
    'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_ENTERING_WORLD',
}
local ARGS = {
    PLAYER_SOFT_INTERACT_CHANGED = { 'Creature-old', 'GameObject-0-1-2-3-4-5' },
    NAME_PLATE_UNIT_ADDED = { 'nameplate4' },
    NAME_PLATE_UNIT_REMOVED = { 'nameplate4' },
    ZONE_CHANGED_NEW_AREA = {},
    PLAYER_REGEN_DISABLED = {},
    PLAYER_REGEN_ENABLED = {},
    PLAYER_ENTERING_WORLD = { false, false },
}

-- Fresh QuietUI.lua runtime with counting ns stubs. opts.noHighlights leaves the module missing;
-- opts.throwOn makes RegisterEvent fail for that event name like an unknown event on this client.
local function Load(opts)
    opts = opts or {}
    local env = { ns = {}, calls = {}, errors = {}, db = { enabled = true } }
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
        'EnsureMinimap', 'NoteCombat', 'MarkCombatEnd', 'MarkQuestXP', 'ForgetBarButtons', 'ForgetRangePlate', 'ForgetRangeSlot',
        'StripAllChat', 'RestripChat', 'ScanParty', 'ShowSetup', 'PresetCommand', 'SyncVisibleEdits', 'UpdateChat',
        'ApplyQuestNotice', 'RestoreQuestNotice', 'QuestNoticeEvent', 'UpdateQuestNotice' }) do
        ns[key] = function() end
    end
    ns.Report = function(key, err) env.errors[#env.errors + 1] = tostring(key) .. ': ' .. tostring(err) end
    if not opts.noHighlights then
        for _, key in ipairs({ 'ApplyHighlights', 'RestoreHighlights', 'HighlightsEvent' }) do ns[key] = spy(key) end
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
        for i = (from or 0) + 1, env.count('HighlightsEvent') do
            if calls.HighlightsEvent[i][1] == name then list[#list + 1] = calls.HighlightsEvent[i] end
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

test('boot applies highlights without runtime errors', function()
    noErrors(main)
    assert(main.count('ApplyHighlights') > 0, 'Boot (ApplyAll) must call ns.ApplyHighlights')
end)

test('Save path ns.ApplyAll calls ApplyHighlights', function()
    local n = main.count('ApplyHighlights')
    main.ns.ApplyAll()
    assert(main.count('ApplyHighlights') > n, 'ns.ApplyAll must call ns.ApplyHighlights')
end)

test('highlight events are registered', function()
    for _, name in ipairs(HL_EVENTS) do
        assert(main.events.registered[name], 'Missing registered ' .. name)
    end
end)

test('enabled runtime forwards each highlight event with original arguments', function()
    for _, name in ipairs(HL_EVENTS) do
        local n = main.count('HighlightsEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        local got = main.forwards(name, n)
        assert(#got == 1, 'Expected one forward of ' .. name .. ', got ' .. #got)
        local want = ARGS[name]
        assert(got[1].n == #want + 1, name .. ': argument count changed (' .. tostring(got[1].n - 1) .. ' vs ' .. #want .. ')')
        for i, v in ipairs(want) do
            assert(got[1][i + 1] == v, name .. ': argument ' .. i .. ' lost')
        end
    end
    noErrors(main)
end)

test('Glance toggle does not apply or restore highlights', function()
    local a, r = main.count('ApplyHighlights'), main.count('RestoreHighlights')
    main.glance('down'); main.slash('glance')
    assert(main.count('ApplyHighlights') == a and main.count('RestoreHighlights') == r, 'Glance must not touch highlights')
    main.glance('down')
end)

test('Edit Mode layout update does not apply or restore highlights', function()
    local a, r = main.count('ApplyHighlights'), main.count('RestoreHighlights')
    main.dispatch('EDIT_MODE_LAYOUTS_UPDATED')
    assert(main.count('ApplyHighlights') == a and main.count('RestoreHighlights') == r, 'Edit Mode must not touch highlights')
end)

test('/quiet off calls RestoreHighlights', function()
    local n = main.count('RestoreHighlights')
    main.slash('off')
    assert(main.count('RestoreHighlights') > n, '/quiet off (RestoreAll) must call ns.RestoreHighlights')
end)

test('disabled runtime forwards only PLAYER_REGEN_ENABLED', function()
    assert(main.db.enabled == false, 'Precondition: disabled')
    for _, name in ipairs(HL_EVENTS) do
        local n = main.count('HighlightsEvent')
        main.dispatch(name, table.unpack(ARGS[name]))
        local got = #main.forwards(name, n)
        if name == 'PLAYER_REGEN_ENABLED' then
            assert(got == 1, 'PLAYER_REGEN_ENABLED must reach HighlightsEvent while disabled (deferred CVar restore)')
        else
            assert(got == 0, name .. ' must not be forwarded while disabled')
        end
    end
    noErrors(main)
end)

test('/quiet on calls ApplyHighlights', function()
    local n = main.count('ApplyHighlights')
    main.slash('on')
    assert(main.count('ApplyHighlights') > n, '/quiet on must call ns.ApplyHighlights')
    noErrors(main)
end)

test('missing highlights module does not error', function()
    local env = Load({ noHighlights = true })
    assert(not env.loadError, 'Load failed: ' .. tostring(env.loadError))
    env.dispatch('PLAYER_LOGIN')
    for _, name in ipairs(HL_EVENTS) do env.dispatch(name, table.unpack(ARGS[name])) end
    env.ns.ApplyAll()
    env.slash('off')
    env.dispatch('PLAYER_REGEN_ENABLED')
    env.slash('on')
    noErrors(env)
end)

test('RegisterEvent failing for PLAYER_SOFT_INTERACT_CHANGED keeps the other events', function()
    local env = Load({ throwOn = 'PLAYER_SOFT_INTERACT_CHANGED' })
    assert(not env.loadError, 'A throwing RegisterEvent must not break loading: ' .. tostring(env.loadError))
    for _, name in ipairs(HL_EVENTS) do
        if name ~= 'PLAYER_SOFT_INTERACT_CHANGED' then
            assert(env.events.registered[name], 'Missing registered ' .. name)
        end
    end
    env.dispatch('PLAYER_LOGIN')
    local n = env.count('HighlightsEvent')
    env.dispatch('NAME_PLATE_UNIT_ADDED', 'nameplate2')
    assert(#env.forwards('NAME_PLATE_UNIT_ADDED', n) == 1, 'Other events must still forward')
    noErrors(env)
end)

test('TOC loads Highlights.lua after QuestNotice.lua and before QuietUI.lua', function()
    local f = assert(io.open('QuietUI.toc')); local toc = f:read('*a'); f:close()
    local quest = toc:find('\nQuestNotice.lua', 1, true)
    local feature = toc:find('\nHighlights.lua', 1, true)
    local runtime = toc:find('\nQuietUI.lua', 1, true)
    assert(feature, 'TOC must list Highlights.lua')
    assert(quest and runtime and quest < feature and feature < runtime, 'TOC order must be QuestNotice.lua, Highlights.lua, QuietUI.lua')
end)

print(string.format('%d/%d highlights runtime cases passed', cases - failures, cases))
if failures > 0 then os.exit(1) end
