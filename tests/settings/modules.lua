-- Modules setting: the Module getter, its defaults, the migration from the old chat and
-- modernize.enabled keys, presets carrying it, and Modernize following the modernize module.
local h = ...

local ON = { "chat", "fading", "helpers", "layout" }

h.test("Module defaults: chat, fading, helpers and layout on, modernize off", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    A.type(ns.Settings.Module, "function", "ns.Settings.Module")
    for _, name in ipairs(ON) do A.eq(ns.Settings.Module(name), true, name .. " defaults on") end
    A.eq(ns.Settings.Module("modernize"), false, "modernize defaults off")
end)

h.test("Module defaults also hold with an empty modules table and with the saved variable missing", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modules = {} }
    for _, name in ipairs(ON) do A.eq(ns.Settings.Module(name), true, name) end
    A.eq(ns.Settings.Module("modernize"), false)
    QuietUICharDB = nil
    for _, name in ipairs(ON) do A.eq(ns.Settings.Module(name), true, name .. " without a saved table") end
    A.eq(ns.Settings.Module("modernize"), false)
end)

h.test("Module turns a default-on module off only for an explicit false", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    for _, name in ipairs(ON) do
        QuietUICharDB = { modules = { [name] = false } }
        for _, other in ipairs(ON) do
            A.eq(ns.Settings.Module(other), other ~= name, name .. " off, asked " .. other)
        end
        A.eq(ns.Settings.Module("modernize"), false)
    end
    for _, junk in ipairs({ "no", 0, "false", true }) do
        QuietUICharDB = { modules = { chat = junk, fading = junk } }
        A.eq(ns.Settings.Module("chat"), true, "chat = " .. tostring(junk))
        A.eq(ns.Settings.Module("fading"), true, "fading = " .. tostring(junk))
    end
    QuietUICharDB = { modules = "chat" }
    A.eq(ns.Settings.Module("chat"), true, "non-table modules")
end)

h.test("Module turns modernize on only for an explicit true", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modules = { modernize = true } }
    A.eq(ns.Settings.Module("modernize"), true)
    for _, junk in ipairs({ false, "yes", 1 }) do
        QuietUICharDB = { modules = { modernize = junk } }
        A.eq(ns.Settings.Module("modernize"), false, "modernize = " .. tostring(junk))
    end
end)

h.test("a direct write to modules is seen at once", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    A.eq(ns.Settings.Module("chat"), true)
    QuietUICharDB.modules = { chat = false }
    A.eq(ns.Settings.Module("chat"), false, "write not seen")
    QuietUICharDB.modules.chat = nil
    A.eq(ns.Settings.Module("chat"), true, "clearing did not restore the default")
    QuietUICharDB.modules.modernize = true
    A.eq(ns.Settings.Module("modernize"), true)
end)

h.test("the old Modern chat getter is gone", function(t)
    t.assert.eq(t.ns.Settings.ModernChat, nil)
end)

h.test("Modernize follows the modernize module, ModernArea and ModernXPGain build on it", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    A.eq(ns.Settings.Modernize(), ns.Settings.Module("modernize"))
    A.eq(ns.Settings.Modernize(), false)
    A.eq(ns.Settings.ModernArea("bars"), false, "Modernize off")
    A.eq(ns.Settings.ModernXPGain(), false, "Modernize off")
    QuietUICharDB = { modules = { modernize = true } }
    A.eq(ns.Settings.Modernize(), true)
    A.eq(ns.Settings.Modernize(), ns.Settings.Module("modernize"))
    A.eq(ns.Settings.ModernArea("bars"), true, "default on while Modernize is on")
    A.eq(ns.Settings.ModernXPGain(), true)
    QuietUICharDB = { modules = { modernize = true }, modernize = { bars = false, status = false } }
    A.eq(ns.Settings.ModernArea("bars"), false)
    A.eq(ns.Settings.ModernArea("units"), true)
    A.eq(ns.Settings.ModernXPGain(), false, "status area off")
    QuietUICharDB = { modules = { modernize = true }, modernize = { xpGain = false } }
    A.eq(ns.Settings.ModernXPGain(), false)
    QuietUICharDB = { modules = { modernize = false }, modernize = { bars = true } }
    A.eq(ns.Settings.ModernArea("bars"), false, "options alone do not turn Modernize on")
end)

-- Migration ---------------------------------------------------------------------------------

h.test("chat = false migrates to modules.chat = false and the chat key is dropped", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chat = false }
    A.eq(ns.Settings.Module("chat"), false)
    local char = ns.Settings.CharDB()
    A.eq(char.chat, nil, "chat key dropped")
    A.type(char.modules, "table")
    A.eq(char.modules.chat, false)
    A.eq(ns.Settings.Module("fading"), true, "others untouched")
end)

h.test("the chat migration runs on a table without a visible table", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 20, chat = false }
    local char = ns.Settings.CharDB()
    A.eq(char.chat, nil)
    A.eq(char.modules and char.modules.chat, false)
    A.eq(char.chatFade, 20, "other keys kept")
end)

h.test("the chat migration is idempotent", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chat = false, visible = { xp = true } }
    for _ = 1, 3 do ns.Settings.CharDB() end
    ns.Settings.MigrateOnce(QuietUICharDB)
    local once = ns.Copy(QuietUICharDB)
    A.deep(once.modules, { chat = false })
    A.eq(once.chat, nil)
    -- The migrated shape handed over again as a fresh table stays as it is.
    QuietUICharDB = ns.Copy(once)
    ns.Settings.MigrateOnce(QuietUICharDB)
    A.deep(QuietUICharDB, once)
    A.eq(ns.Settings.Module("chat"), false)
end)

h.test("a replaced settings table with a legacy chat key migrates on its next read", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    A.eq(ns.Settings.Module("chat"), true)
    QuietUICharDB = { chat = false }
    A.eq(ns.Settings.Module("chat"), false)
    A.eq(QuietUICharDB.chat, nil)
end)

h.test("a chat key that is not false leaves Chat on", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chat = true }
    A.eq(ns.Settings.Module("chat"), true)
end)

h.test("modernize.enabled = true migrates to modules.modernize = true and keeps the theme", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modernize = { enabled = true, theme = "light", bars = false, xpGain = false } }
    A.eq(ns.Settings.Module("modernize"), true)
    A.eq(ns.Settings.Modernize(), true)
    local char = ns.Settings.CharDB()
    A.eq(char.modules.modernize, true)
    A.deep(char.modernize, { theme = "light", bars = false, xpGain = false })
    A.eq(ns.Settings.ModernArea("bars"), false, "area options survive")
    A.eq(ns.Settings.ModernXPGain(), false, "xpGain survives")
end)

h.test("modernize = { enabled = true } alone migrates to the module with no options left", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modernize = { enabled = true } }
    A.eq(ns.Settings.Modernize(), true)
    local char = ns.Settings.CharDB()
    A.eq(char.modules.modernize, true)
    A.eq(char.modernize == nil or next(char.modernize) == nil, true, "no enabled key left")
end)

h.test("modernize.enabled = false leaves Modernize off and keeps the theme", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modernize = { enabled = false, theme = "light" } }
    A.eq(ns.Settings.Modernize(), false)
    local char = ns.Settings.CharDB()
    A.eq(char.modernize.theme, "light")
    A.ok(not (char.modules and char.modules.modernize), "modernize module stays off")
end)

h.test("the modernize migration is idempotent", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modernize = { enabled = true, theme = "light" } }
    for _ = 1, 3 do ns.Settings.CharDB() end
    local once = ns.Copy(QuietUICharDB)
    A.deep(once.modernize, { theme = "light" })
    A.eq(once.modules.modernize, true)
    QuietUICharDB = ns.Copy(once)
    ns.Settings.MigrateOnce(QuietUICharDB)
    A.deep(QuietUICharDB, once)
end)

h.test("the migration keeps modules already set and combines both old keys", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modules = { fading = false }, chat = false, modernize = { enabled = true, theme = "light" } }
    local char = ns.Settings.CharDB()
    A.deep(char.modules, { fading = false, chat = false, modernize = true })
    A.eq(char.chat, nil)
    A.deep(char.modernize, { theme = "light" })
end)

h.test("settings with no legacy keys and no modules migrate to the Classic set", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 20, visible = { xp = true } }
    for _, name in ipairs(ON) do A.eq(ns.Settings.Module(name), true, name) end
    A.eq(ns.Settings.Module("modernize"), false)
    A.eq(ns.Settings.CharDB().chatFade, 20)
end)

h.test("the shared preset's own legacy keys migrate when it is read", function(t)
    local ns, A = t.ns, t.assert
    local settings = { chat = false, modernize = { enabled = true, theme = "light" } }
    QuietUIDB = { enabled = true, presets = {
        ["1"] = { name = "Old", layout = {}, settings = settings, interfaceStyle = 0 } } }
    QuietUICharDB = { presetId = "1" }
    A.eq(ns.Settings.Module("chat"), false)
    A.eq(ns.Settings.Module("modernize"), true)
    A.eq(settings.chat, nil, "preset chat key dropped")
    A.deep(settings.modules, { chat = false, modernize = true })
    A.deep(settings.modernize, { theme = "light" })
end)

h.test("a legacy settings table handed to SavePreset is stored in the new shape", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = {}
    local id = assert(ns.Settings.SavePreset(nil, "Legacy", { layoutName = "Raid", layoutType = 1 },
        { chat = false, modernize = { enabled = true, theme = "light" } }))
    local stored = ns.Settings.Presets()[id].settings
    A.eq(stored.chat, nil)
    A.deep(stored.modules, { chat = false, modernize = true })
    A.deep(stored.modernize, { theme = "light" })
end)

-- Presets -----------------------------------------------------------------------------------

h.test("a preset saved with modules = { fading = false } hands that selection to another character", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = {}
    local id = assert(ns.Settings.SavePreset(nil, "No fading", { layoutName = "Raid", layoutType = 1 },
        { modules = { fading = false } }))
    A.deep(ns.Settings.Presets()[id].settings.modules, { fading = false }, "stored in the preset")
    QuietUICharDB = {}
    A.eq(ns.Settings.Module("fading"), true, "a character without the preset starts on")
    A.ok(ns.Settings.ActivatePreset(id))
    A.eq(ns.Settings.Module("fading"), false, "the preset's selection reaches the character")
    A.eq(ns.Settings.Module("chat"), true)
    A.eq(ns.Settings.Module("modernize"), false)
    A.deep(QuietUICharDB.modules, { fading = false })
end)

h.test("a preset keeps its own copy of modules", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = { modules = { chat = false, modernize = true } }
    local id = assert(ns.Settings.SavePreset(nil, "Mod", { layoutName = "Raid", layoutType = 1 }, QuietUICharDB))
    local stored = ns.Settings.Presets()[id].settings.modules
    A.deep(stored, { chat = false, modernize = true })
    A.ok(stored ~= QuietUICharDB.modules, "not aliased")
    QuietUICharDB.modules.chat = nil
    A.eq(ns.Settings.Presets()[id].settings.modules.chat, false)
end)

h.test("editing a shared preset's modules reaches a character that has it active", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = {}
    local id = assert(ns.Settings.SavePreset(nil, "Shared", { layoutName = "Raid", layoutType = 1 }, {}))
    ns.Settings.ActivatePreset(id)
    A.eq(ns.Settings.Module("layout"), true)
    ns.Settings.SavePreset(id, "Shared", { layoutName = "Raid", layoutType = 1 }, { modules = { layout = false } })
    A.eq(ns.Settings.Module("layout"), false)
end)

h.test("Reset default clears modules back to the Classic set", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = { modules = { chat = false, modernize = true } }
    ns.Settings.ActivatePreset(nil, {})
    A.eq(QuietUICharDB.modules, nil)
    for _, name in ipairs(ON) do A.eq(ns.Settings.Module(name), true, name) end
    A.eq(ns.Settings.Module("modernize"), false)
end)
