-- Settings getters keep returning today's values for the same saved variables.
local h = ...

h.test("CharDB creates an empty table when the saved variable is missing", function(t)
    QuietUICharDB = nil
    local db = t.ns.Settings.CharDB()
    t.assert.type(db, "table")
    t.assert.eq(QuietUICharDB, db, "global is set to the returned table")
    t.assert.eq(next(db), nil, "fresh table is empty")
end)

h.test("CharDB returns the populated saved table itself", function(t)
    local saved = { visible = { xp = true }, chat = false }
    QuietUICharDB = saved
    t.assert.eq(t.ns.Settings.CharDB(), saved)
    t.assert.eq(t.ns.Settings.CharDB().chat, false)
end)

h.test("CharDB keeps the first character's account copy and drops the account keys", function(t)
    QuietUIDB = { enabled = true, visible = { xp = true }, player = "resource" }
    QuietUICharDB = {}
    local db = t.ns.Settings.CharDB()
    t.assert.eq(db.visible and db.visible.xp, true, "visible moved")
    t.assert.eq(db.player, "resource", "player moved")
    t.assert.eq(QuietUIDB.visible, nil, "account visible dropped")
    t.assert.eq(QuietUIDB.player, nil, "account player dropped")
end)

h.test("CharDB does not overwrite character settings with the account copy", function(t)
    QuietUIDB = { enabled = true, visible = { xp = true } }
    QuietUICharDB = { visible = { bars = false } }
    local db = t.ns.Settings.CharDB()
    t.assert.eq(db.visible.xp, nil, "account value stays out")
    t.assert.eq(QuietUIDB.visible, nil, "account key still dropped")
end)

h.test("Pinned reads visible[name] as a boolean", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.Pinned("xp"), false, "fresh")
    QuietUICharDB = { visible = { xp = true, meter = false } }
    A.eq(ns.Settings.Pinned("xp"), true, "pinned")
    A.eq(ns.Settings.Pinned("meter"), false, "explicit false")
    A.eq(ns.Settings.Pinned("other"), false, "unknown")
    QuietUICharDB = { visible = "xp" }
    A.eq(ns.Settings.Pinned("xp"), false, "non-table visible")
end)

h.test("Pinned keeps legacy bar pins working after migration", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = { visible = { xp = true, bars = true } }
    A.eq(ns.Settings.Pinned("xp"), true, "xp stays pinned")
    A.type(ns.Settings.CharDB().groupVisibility, "table", "legacy bars pin becomes group visibility")
end)

h.test("PlayerStyle is classic unless resource is saved", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.PlayerStyle(), "classic")
    QuietUICharDB = { player = "resource" }
    A.eq(ns.Settings.PlayerStyle(), "resource")
    QuietUICharDB = { player = "other" }
    A.eq(ns.Settings.PlayerStyle(), "classic")
end)

h.test("Boolean getters default on and turn off only with an explicit false", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.GroupAuras(), true)
    A.eq(ns.Settings.AlwaysShowDebuffs(), true)
    A.eq(ns.Settings.QuestNoticeEnabled(), true)
    A.eq(ns.Settings.QuestMobs(), true)
    A.eq(ns.Settings.ModernChat(), true)
    QuietUICharDB = { groupAuras = false, alwaysShowDebuffs = false, questNotice = false,
        questMobs = false, chat = false }
    A.eq(ns.Settings.GroupAuras(), false)
    A.eq(ns.Settings.AlwaysShowDebuffs(), false)
    A.eq(ns.Settings.QuestNoticeEnabled(), false)
    A.eq(ns.Settings.QuestMobs(), false)
    A.eq(ns.Settings.ModernChat(), false)
end)

h.test("Boolean getters that default off turn on only with an explicit true", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.AutoHideParty(), false)
    A.eq(ns.Settings.RequireLivingTarget(), false)
    QuietUICharDB = { autoHideParty = true, requireLivingTarget = true }
    A.eq(ns.Settings.AutoHideParty(), true)
    A.eq(ns.Settings.RequireLivingTarget(), true)
end)

h.test("Highlights returns all categories off by default", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.deep(ns.Settings.Highlights(), { herb = false, ore = false, quest = false })
    QuietUICharDB = { highlights = { herb = true, ore = "yes", quest = true } }
    A.deep(ns.Settings.Highlights(), { herb = true, ore = false, quest = true })
end)

h.test("QuestNoticeSize accepts only smaller and larger", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.QuestNoticeSize(), "default")
    QuietUICharDB = { questNoticeSize = "larger" }
    A.eq(ns.Settings.QuestNoticeSize(), "larger")
    QuietUICharDB = { questNoticeSize = "huge" }
    A.eq(ns.Settings.QuestNoticeSize(), "default")
end)

h.test("PlayerThreshold defaults to health 70 and validates the saved value", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    local kind, value = ns.Settings.PlayerThreshold()
    A.eq(kind, "health"); A.eq(value, 70)
    QuietUICharDB = { playerThresholdKind = "resource", playerThresholdPercent = 40 }
    kind, value = ns.Settings.PlayerThreshold()
    A.eq(kind, "resource"); A.eq(value, 40)
    QuietUICharDB = { playerThresholdPercent = false }
    kind, value = ns.Settings.PlayerThreshold()
    A.eq(kind, "health"); A.eq(value, nil)
    QuietUICharDB = { playerThresholdPercent = 150 }
    kind, value = ns.Settings.PlayerThreshold()
    A.eq(value, 70, "out of range falls back")
end)

h.test("ChatFade defaults to 10, clamps and rounds down to steps of 5", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.ChatFade(), 10)
    QuietUICharDB = { chatFade = 0 }
    A.eq(ns.Settings.ChatFade(), 0)
    QuietUICharDB = { chatFade = 27 }
    A.eq(ns.Settings.ChatFade(), 25)
    QuietUICharDB = { chatFade = 500 }
    A.eq(ns.Settings.ChatFade(), 60)
    QuietUICharDB = { chatFade = "x" }
    A.eq(ns.Settings.ChatFade(), 10)
end)

h.test("Range is off by default and returns yards, kind and spell", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.Range(), nil)
    QuietUICharDB = { range = { yards = 28 } }
    local yards, kind, spell = ns.Settings.Range()
    A.eq(yards, 28); A.eq(kind, "hostile"); A.eq(spell, nil)
    QuietUICharDB = { range = { yards = "spell", kind = "friendly", spell = "  Heal  " } }
    yards, kind, spell = ns.Settings.Range()
    A.eq(yards, "spell"); A.eq(kind, "friendly"); A.eq(spell, "Heal")
    QuietUICharDB = { range = { yards = 5 } }
    A.eq(ns.Settings.Range(), nil, "unknown yards")
end)

h.test("OnlyOnHover defaults on for xp only, unless xp is always visible", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.OnlyOnHover("xp"), true)
    A.eq(ns.Settings.OnlyOnHover("meter"), false)
    QuietUICharDB = { visible = { xp = true } }
    A.eq(ns.Settings.OnlyOnHover("xp"), false)
    QuietUICharDB = { hoverOnly = { xp = false, meter = true } }
    A.eq(ns.Settings.OnlyOnHover("xp"), false)
    A.eq(ns.Settings.OnlyOnHover("meter"), true)
end)

h.test("ChatTabs is top only for the literal top", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = {}
    A.eq(ns.Settings.ChatTabs(), "bottom", "missing")
    QuietUICharDB = { chatTabs = "bottom" }
    A.eq(ns.Settings.ChatTabs(), "bottom", "bottom")
    QuietUICharDB = { chatTabs = "top" }
    A.eq(ns.Settings.ChatTabs(), "top", "top")
    for _, v in ipairs({ "Top", "above", "", 1, true }) do
        QuietUICharDB = { chatTabs = v }
        A.eq(ns.Settings.ChatTabs(), "bottom", "unknown " .. tostring(v))
    end
end)
