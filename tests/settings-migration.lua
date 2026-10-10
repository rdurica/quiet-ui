-- Run from the addon directory: lua tests/settings-migration.lua
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function frame()
    local obj = {}
    setmetatable(obj, { __index = function() return function() end end })
    return obj
end

-- Loads the real settings stack and counts MigrateVisibility calls per argument.
local function namespace(char, db)
    QuietUIDB = db or { enabled = true }
    QuietUICharDB = char
    UIParent = frame()
    hooksecurefunc = function() end
    local ns = {}
    loadAddon('Core.lua', ns)
    loadAddon('Presets.lua', ns)
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    loadAddon('Setup.lua', ns)
    local calls = {}
    local real = ns.MigrateVisibility
    ns.MigrateVisibility = function(settings)
        calls[settings] = (calls[settings] or 0) + 1
        return real(settings)
    end
    return ns, calls
end

test('CharDB migrates the same visible table at most once', function()
    local ns, calls = namespace({ visible = { xp = true } })
    for _ = 1, 100 do ns.CharDB() end
    local n = calls[QuietUICharDB] or 0
    assert(n <= 1, 'CharDB ran MigrateVisibility ' .. n .. ' times for one visible table')
end)

test('A replaced visible table with legacy bars migrates on the next CharDB', function()
    local ns = namespace({ visible = { xp = true } })
    for _ = 1, 10 do ns.CharDB() end
    QuietUICharDB.visible = { bars = true }
    local char = ns.CharDB()
    assert(char.visible.bars == nil, 'Legacy visible.bars survived')
    local always = false
    for _, mode in pairs(char.groupVisibility or {}) do
        if mode == 'always' then always = true end
    end
    assert(always, 'groupVisibility has no "always" group after migration')
end)

test('A direct chat write is visible at once', function()
    local ns = namespace({ visible = {} })
    assert(ns.ModernChat() == true, 'Modern chat must default on')
    QuietUICharDB.chat = false
    assert(ns.ModernChat() == false, 'Direct write QuietUICharDB.chat = false was not seen')
    QuietUICharDB.chat = nil
    assert(ns.ModernChat() == true, 'Clearing chat did not restore the default')
end)

test('Settings with an active preset migrates preset.settings at most once', function()
    local settings = { visible = { xp = true }, chat = false }
    local ns, calls = namespace({ presetId = '1' }, {
        enabled = true,
        presets = { ['1'] = { name = 'A', layout = {}, settings = settings, interfaceStyle = 0 } },
    })
    local result
    for _ = 1, 100 do result = ns.Settings() end
    assert(result == settings, 'Settings did not return preset.settings')
    local n = calls[settings] or 0
    assert(n <= 1, 'Settings ran MigrateVisibility(preset.settings) ' .. n .. ' times')
end)

if failures > 0 then os.exit(1) end
