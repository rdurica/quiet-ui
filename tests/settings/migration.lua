-- Visibility migration runs at most once per settings table and is seen at once by getters.
local h = ...

-- Counts MigrateVisibility calls per settings table.
local function counted(t, char, db)
    QuietUIDB = db or { enabled = true }
    QuietUICharDB = char
    local ns = t.ns
    local calls = {}
    local real = ns.MigrateVisibility
    ns.MigrateVisibility = function(settings)
        calls[settings] = (calls[settings] or 0) + 1
        return real(settings)
    end
    return ns, calls
end

h.test("CharDB migrates the same visible table at most once", function(t)
    local ns, calls = counted(t, { visible = { xp = true } })
    for _ = 1, 100 do ns.CharDB() end
    local n = calls[QuietUICharDB] or 0
    t.assert.ok(n <= 1, "CharDB ran MigrateVisibility " .. n .. " times for one visible table")
end)

h.test("a replaced visible table with legacy bars migrates on the next CharDB", function(t)
    local ns = counted(t, { visible = { xp = true } })
    for _ = 1, 10 do ns.CharDB() end
    QuietUICharDB.visible = { bars = true }
    local char = ns.CharDB()
    t.assert.eq(char.visible.bars, nil, "Legacy visible.bars survived")
    local always = false
    for _, mode in pairs(char.groupVisibility or {}) do
        if mode == "always" then always = true end
    end
    t.assert.ok(always, "groupVisibility has no 'always' group after migration")
end)

h.test("a direct chat write is visible at once", function(t)
    local ns = counted(t, { visible = {} })
    t.assert.eq(ns.ModernChat(), true, "Modern chat must default on")
    QuietUICharDB.chat = false
    t.assert.eq(ns.ModernChat(), false, "Direct write QuietUICharDB.chat = false was not seen")
    QuietUICharDB.chat = nil
    t.assert.eq(ns.ModernChat(), true, "Clearing chat did not restore the default")
end)

h.test("Settings with an active preset migrates preset.settings at most once", function(t)
    local settings = { visible = { xp = true }, chat = false }
    local ns, calls = counted(t, { presetId = "1" }, {
        enabled = true,
        presets = { ["1"] = { name = "A", layout = {}, settings = settings, interfaceStyle = 0 } },
    })
    local result
    for _ = 1, 100 do result = ns.Settings() end
    t.assert.eq(result, settings, "Settings did not return preset.settings")
    local n = calls[settings] or 0
    t.assert.ok(n <= 1, "Settings ran MigrateVisibility(preset.settings) " .. n .. " times")
end)
