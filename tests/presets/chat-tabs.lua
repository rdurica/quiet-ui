-- Presets carry the chat tabs placement.
local h = ...

h.test("A preset saved with Tabs = Top applies top and one without applies bottom", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local topId = assert(ns.Settings.SavePreset(nil, "Tabs top", {}, { chatTabs = "top" }))
    local plainId = assert(ns.Settings.SavePreset(nil, "Tabs plain", {}, {}))
    A.eq(ns.Settings.CopySettings({ chatTabs = "top" }).chatTabs, "top", "copy keeps top")
    ns.Settings.ActivatePreset(topId)
    A.eq(ns.Settings.ChatTabs(), "top", "preset with Top")
    ns.Settings.ActivatePreset(plainId)
    A.eq(ns.Settings.ChatTabs(), "bottom", "preset without it")
end)

h.test("A top preset applies to a character without chatTabs", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatTabs = nil }
    A.eq(ns.Settings.ChatTabs(), "bottom", "other character starts at Bottom")
    local id = assert(ns.Settings.SavePreset(nil, "Tabs top", {}, { chatTabs = "top" }))
    QuietUICharDB = {}
    ns.Settings.ActivatePreset(id)
    A.eq(ns.Settings.ChatTabs(), "top")
end)
