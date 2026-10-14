-- Shared presets: creation, snapshots, rename, validation, deletion across characters.
local h = ...

h.test("shared presets: create, activate, edit across characters, snapshots, rename, deletion", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}
    QuietUICharDB = { forceLayout = true, chat = false, range = { yards = 28 }, previousLayout = 4 }
    A.type(ns.Settings.SavePreset, "function", "Preset creation is not implemented")
    local id = assert(ns.Settings.SavePreset(nil, "  Healer  ", { layoutName = "Raid", layoutType = 1 }, QuietUICharDB))
    A.eq(QuietUIDB.presets[id].name, "Healer")
    A.eq(QuietUIDB.presets[id].settings.chat, false)
    A.eq(QuietUIDB.presets[id].settings.previousLayout, nil)
    A.eq(QuietUIDB.presets[id].settings.forceLayout, nil)
    local first = QuietUICharDB
    ns.Settings.ActivatePreset(id)
    QuietUICharDB = {}
    A.eq(ns.Settings.Effective().chat, nil, "New characters must not inherit a preset")
    ns.Settings.ActivatePreset(id)
    A.eq(ns.Settings.Effective().chat, false)
    ns.Settings.SavePreset(id, "Healing", { layoutName = "Raid", layoutType = 1 }, { chatFade = 0, groups = { [1] = 3 } })
    QuietUICharDB = first
    A.eq(ns.Settings.Effective().chatFade, 0, "Shared edits must reach other characters")
    A.eq(ns.Settings.Effective().chat, nil, "Missing values must replace old settings")
    A.eq(QuietUIDB.presets[id].name, "Healing")
    A.eq(first.previousLayout, 4)
    QuietUICharDB.groups[1] = 8
    A.eq(QuietUIDB.presets[id].settings.groups[1], 3, "Snapshots must not alias shared settings")
    A.falsy(ns.Settings.SavePreset(nil, " healing ", {}, {}), "Duplicate names must be rejected")
    A.falsy(ns.Settings.SavePreset(nil, "   ", {}, {}), "Empty names must be rejected")
    first.groups[1] = 3
    ns.Settings.Effective()
    QuietUICharDB = {}
    ns.Settings.ActivatePreset(id)
    ns.Settings.DeletePreset(id)
    QuietUICharDB = first
    A.eq(ns.Settings.Effective().groups[1], 3)
    A.eq(first.presetId, nil, "Deleted presets must detach other characters")
    A.eq(first.previousLayout, 4)
end)
