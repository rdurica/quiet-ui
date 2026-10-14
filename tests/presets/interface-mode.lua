-- Preset interface-mode tags, legacy tagging, lists, commands and activation guards.
local h = ...

h.test("preset mode tags, legacy migration, lists, commands and activation guards", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    QuietUIDB = {}; QuietUICharDB = {}
    local mode, canceled, applied = 0, 0, 0
    ns.CurrentInterfaceStyle = function() return mode end
    ns.LayoutInterfaceStyle = function(ref)
        if ref.builtin == 3 or ref.layoutName == "aaaddd" then return 1 end
        return ref.interfaceStyle or 0
    end
    ns.CancelLayoutPreview = function() canceled = canceled + 1 end
    ns.ApplyAll = function() applied = applied + 1 end
    local db, char = QuietUIDB, QuietUICharDB
    local keyboard = ns.SavePreset(nil, "Keyboard", { layoutName = "QuietUI", layoutType = 1 }, { chat = false })
    mode = 1
    local gamepad = ns.SavePreset(nil, "Test A", { builtin = 3 }, { chatFade = 0 })
    local custom = ns.SavePreset(nil, "Custom", { layoutName = "aaaddd", layoutType = 1 }, {})
    A.ok(db.presets[keyboard].interfaceStyle == 0 and db.presets[gamepad].interfaceStyle == 1)
    A.eq(db.presets[custom].interfaceStyle, 1)
    -- Older saved presets acquire their tag from the linked layout.
    db.presets[gamepad].interfaceStyle = nil
    db.presets[custom].interfaceStyle = nil
    mode = 0
    local list = ns.PresetList()
    A.ok(#list == 1 and list[1].id == keyboard)
    A.ok(db.presets[gamepad].interfaceStyle == 1 and db.presets[custom].interfaceStyle == 1)
    A.ok(ns.ActivatePreset(keyboard))
    ns.PresetCommand("Test A")
    A.ok(char.presetId == keyboard and canceled == 0 and applied == 0,
        "Incompatible commands must leave settings and previews untouched")
    A.printed(mock, "current interface mode")
    A.falsy(ns.ActivatePreset(gamepad), "Direct activation must reject incompatible presets too")
    A.eq(char.presetId, keyboard)
    local out = A.capture(mock, ns.PresetCommand, "")
    A.ok(out[#out]:match('Available presets: "Keyboard"%.$'), "Only compatible presets are listed")
    mode = 1
    list = ns.PresetList()
    A.ok(#list == 2 and list[1].id == custom and list[2].id == gamepad)
    ns.PresetCommand("Test A")
    A.ok(char.presetId == gamepad and char.chatFade == 0 and canceled == 1 and applied == 1)
    ns.SavePreset(gamepad, "Test A", { layoutName = "QuietUI", layoutType = 1 }, {})
    A.eq(db.presets[gamepad].interfaceStyle, 0, "Saving a different linked mode must update the preset tag")
end)
