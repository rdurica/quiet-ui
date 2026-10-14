-- Bar visibility rules: target death, show-all, group visibility, legacy pins, ancestry cache.
local h = ...

local function boot(t)
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    t.boot()
end

h.test("target death invalidates cached bars without pointer movement", function(t)
    local A = t.assert
    boot(t)
    local ns = t.ns
    local bar = MainActionBar
    QuietUICharDB.friendly = { ['1'] = true }
    local dead = false
    UnitExists = function() return true end
    UnitIsFriend = function() return true end
    UnitCanAttack = function() return false end
    UnitIsDeadOrGhost = function() return dead end
    ns.World.RefreshWorld()
    ns.World.ConsumeHud()
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    A.alpha(bar, 1, 'Living friendly target did not show its bar')
    dead = true
    ns.World.RefreshWorld()
    A.ok(ns.World.ConsumeHud(), 'Target death did not invalidate cached bar visibility')
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    A.alpha(bar, 0, 'Dead friendly target kept its bar visible')
end)

h.test("show-all transitions recalculate bars even with a stationary pointer", function(t)
    local A = t.assert
    boot(t)
    local ns, mock = t.ns, t.mock
    local scans = 0
    local update = ns.UpdateBars
    ns.UpdateBars = function(showAll, dt, rescan, ...)
        if rescan then scans = scans + 1 end
        return update(showAll, dt, rescan, ...)
    end
    local force = false
    ns.World.ShowAll = function() return force end
    mock:tick(0.01)
    scans = 0
    force = true
    mock:tick(0.01)
    A.eq(scans, 1, 'Entering edit mode did not recalculate bars')
    scans = 0
    force = false
    mock:tick(0.01)
    A.eq(scans, 1, 'Leaving edit mode did not recalculate bars')
    QuietUIGlance('up')
    A.falsy(ns.Glancing(), 'Key-up toggled Glance')
    QuietUIGlance('down')
    A.ok(ns.Glancing(), 'Key-down did not toggle Glance')
    QuietUIGlance('down')
    A.falsy(ns.Glancing(), 'Second key-down did not clear Glance')
    SlashCmdList.QUIETUI('  GlAnCe  ')
    A.ok(ns.Glancing(), 'Slash command did not toggle Glance')
    A.ok(QuietUIDB.enabled, 'Glance command disabled the addon')
    scans = 0
    mock:tick(0.01)
    A.eq(scans, 1, 'Glance command did not recalculate bars')
    QuietUIGlance('down')
    A.falsy(ns.Glancing(), 'Key binding did not clear command Glance')
    SlashCmdList.QUIETUI('glance')
    SlashCmdList.QUIETUI('glance')
    A.falsy(ns.Glancing(), 'Second Glance command did not clear Glance')
    QuietUIDB.enabled = false
    QuietUIGlance('down')
    A.falsy(ns.Glancing(), 'Glance toggled while addon was disabled')
    SlashCmdList.QUIETUI('glance')
    A.falsy(ns.Glancing(), 'Glance command toggled while addon was disabled')
    A.falsy(QuietUIDB.enabled, 'Glance command enabled the addon')
    QuietUIDB.enabled = true
    SlashCmdList.QUIETUI('glance')
    ns.Settings.ForceQuietLayout = function() return false end
    SlashCmdList.QUIETUI('off')
    A.falsy(ns.Glancing(), 'Disabling the addon did not clear command Glance')
    A.falsy(QuietUIDB.enabled, 'Off command did not disable the addon')
end)

h.test("group visibility overrides automatic triggers and keeps hover exceptions", function(t)
    local A = t.assert
    local swing = CreateFrame('Frame', 'SwingTimer', UIParent)
    boot(t)
    local ns = t.ns
    local main, left = MainActionBar, MultiBarBottomLeft
    local hot = {}
    ns.Hit = function(obj) return hot[obj] == true end
    ns.Glancing = function() return false end
    local explicit = false
    ns.World.XPForced = function() return explicit end
    QuietUICharDB.groups = { swing = 1 }
    QuietUICharDB.groupVisibility = { [1] = 'hover' }
    QuietUICharDB.friendly = { ['1'] = true }
    UnitExists = function() return true end
    UnitIsFriend = function() return true end
    UnitIsDeadOrGhost = function() return false end
    ns.World.RefreshWorld()
    local function tick(showAll)
        ns.NextFadeTick(); ns.UpdateBars(showAll, 1, true)
    end
    tick(true)
    A.ok(main._alpha == 0 and left._alpha == 0 and swing._alpha == 0,
        'Combat/instance or target revealed a hover group')
    hot[left] = true
    tick(true)
    A.ok(main._alpha == 1 and left._alpha == 1 and swing._alpha == 1,
        'Hover did not reveal every group member')
    hot[left] = false
    tick(true)
    A.alpha(main, 0)
    explicit = true; tick(false)
    A.alpha(main, 1, 'Edit/flyout/cursor exception failed')
    explicit = false
    ns.Glancing = function() return true end; tick(false)
    A.alpha(main, 1, 'Glance exception failed')
    ns.Glancing = function() return false end
    QuietUICharDB.groupVisibility[1] = 'always'; tick(false)
    A.ok(main._alpha == 1 and swing._alpha == 1)
    QuietUICharDB.groupVisibility = nil; tick(false)
    A.ok(main._alpha == 1 and left._alpha == 0, 'Usual Enemy/Friend rule must show one bar only')
    ns.RestoreAlpha(); QuietUIDB.enabled = false
    A.alpha(left, 1, 'Disable did not restore the bar alpha')
end)

h.test("legacy pins split mixed groups without changing which bars stay up", function(t)
    local A = t.assert
    local ns = t.ns
    QuietUIDB = { enabled = true }
    local source = { visible = { bars = true, quests = true }, groups = { swing = 1 } }
    ns.Settings.MigrateVisibility(source)
    A.ok(source.visible.quests and not source.visible.bars and not source.visible.swing)
    QuietUICharDB = source
    A.eq(ns.Settings.GroupVisibility(ns.Settings.BarGroup('1')), 'always')
    A.falsy(ns.Settings.GroupVisibility(ns.Settings.BarGroup('swing')), 'Migration pinned the unpinned swing timer')
    local oldGroup = source.groups['1']
    ns.Settings.MigrateVisibility(source)
    A.eq(source.groups['1'], oldGroup, 'Migration must be idempotent')
    source = { visible = { swing = true }, groups = { swing = 1 } }
    ns.Settings.MigrateVisibility(source); QuietUICharDB = source
    A.eq(ns.Settings.GroupVisibility(ns.Settings.BarGroup('swing')), 'always')
    A.falsy(ns.Settings.GroupVisibility(ns.Settings.BarGroup('1')), 'Migration pinned unpinned action bars')
    source.hoverOnly = { meter = true }
    local id = assert(ns.Settings.SavePreset(nil, 'Hover', {}, source))
    ns.Settings.ActivatePreset(id)
    A.ok(ns.Settings.OnlyOnHover('meter') and ns.Settings.GroupVisibility(ns.Settings.BarGroup('swing')) == 'always')
    ns.Settings.DeletePreset(id)
    A.ok(ns.Settings.OnlyOnHover('meter'), 'Deleting preset lost hover snapshot')
end)

h.test("bar ancestry cache preserves nesting, reparenting, replacement and disable", function(t)
    local A = t.assert
    boot(t)
    local ns = t.ns
    local main, left = MainActionBar, MultiBarBottomLeft
    ns.Hit = function() return false end
    local parentReads = 0
    for _, obj in ipairs({ main, left, UIParent }) do
        local get = obj.GetParent
        obj.GetParent = function(self) parentReads = parentReads + 1; return get(self) end
    end
    local function tick()
        ns.NextFadeTick()
        ns.UpdateBars(false, 1, true)
    end
    tick()
    parentReads = 0
    for _ = 1, 100 do tick() end
    A.eq(parentReads, 0, 'Stable bars repeated ancestor walks: ' .. parentReads)
    left:SetParent(main)
    A.ok(ns.World.ConsumeHud(), 'Reparenting did not invalidate hover visibility')
    tick()
    A.ok(main._alpha == 1 and left._alpha == 0,
        'Hosting bar must stay opaque so the child fades independently')
    left:SetParent(UIParent)
    tick()
    A.alpha(main, 0, 'Unnested bar retained cached hosting status')
    local old = left
    MultiBarBottomLeft = CreateFrame('Frame', 'MultiBarBottomLeft', UIParent)
    ns.ForgetBarButtons(); tick()
    A.alpha(MultiBarBottomLeft, 0, 'Replacement bar was not discovered')
    ns.RestoreAlpha()
    A.ok(main._alpha == 1 and MultiBarBottomLeft._alpha == 1 and old._alpha == 1,
        'Disable did not restore original alphas')
end)
