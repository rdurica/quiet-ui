-- /quiet preset: listing, selection by name, errors, combat deferral, disabled addon.
local h = ...

-- Layout switching talks to Edit Mode; replace it with a recorder on the public ns.
local function setup(t)
    local ns = t.ns
    local ctx = { selected = {}, restored = 0, combat = false, canceled = 0, refreshed = 0 }
    ns.ForceQuietLayout = function() return ns.ActivePreset() ~= nil end
    ns.ModernChat = function() return false end
    ns.SelectPresetLayout = function()
        if ctx.combat then return false end
        ctx.selected[#ctx.selected + 1] = ns.ActivePreset().layout.layoutName
        ns.CharDB().previousLayout = ns.CharDB().previousLayout or 3
        ns.CharDB().presetLayoutManaged = true
        return true
    end
    ns.RestorePreviousLayout = function()
        if ctx.combat then return false end
        ctx.restored = ctx.restored + 1
        ns.CharDB().previousLayout, ns.CharDB().presetLayoutManaged = nil, nil
        return true
    end
    local cancel, refresh = ns.CancelLayoutPreview, ns.RefreshSetup
    ns.CancelLayoutPreview = function(...)
        ctx.canceled = ctx.canceled + 1
        if cancel then return cancel(...) end
    end
    ns.RefreshSetup = function(...)
        ctx.refreshed = ctx.refreshed + 1
        if refresh then return refresh(...) end
    end
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    ctx.healer = ns.SavePreset(nil, 'Raid Healer', { layoutName = 'Raid' }, { chatFade = 0 })
    ctx.minimal = ns.SavePreset(nil, 'Minimal', { layoutName = 'Quiet' }, { chat = false })
    t.boot()
    ctx.command = SlashCmdList.QUIETUI
    t.mock.printed = {}
    ctx.last = function() return t.mock.printed[#t.mock.printed] or '' end
    ctx.line = function(i) return t.mock.printed[i] or '' end
    return ctx
end

local function find(s, text) return s:find(text, 1, true) end

h.test("preset with no name lists the current preset and available presets", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset')
    A.ok(find(c.line(1), 'Current preset: <no preset>.'), c.line(1))
    A.ok(find(c.line(2), 'Available presets: "Minimal", "Raid Healer".'), c.line(2))
    A.eq(QuietUICharDB.presetId, nil)
    A.eq(#c.selected, 0)
    A.eq(c.canceled, 0)
end)

h.test("preset selects by name ignoring case and padding, with snapshot and layout", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('  PrEsEt "rAiD hEaLeR"  ')
    A.eq(QuietUICharDB.presetId, c.healer)
    A.eq(QuietUICharDB.chatFade, 0)
    A.ok(QuietUIDB.enabled)
    A.eq(c.selected[1], 'Raid')
    A.eq(QuietUICharDB.previousLayout, 3)
    A.eq(c.canceled, 1)
    A.eq(c.refreshed, 1)
    A.ok(find(c.last(), 'Preset "Raid Healer" selected.'), c.last())
end)

h.test("preset reports unknown names, bad quoting and empty quoted names without changing anything", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset "Raid Healer"')
    c.command('preset Missing')
    A.ok(find(c.last(), 'was not found'), c.last())
    c.command('preset "Raid Healer')
    A.ok(find(c.last(), 'Use /quiet preset "name".'), c.last())
    c.command('preset ""')
    A.ok(find(c.last(), 'was not found'), c.last())
    A.eq(QuietUICharDB.presetId, c.healer)
    A.eq(#c.selected, 1)
    A.eq(c.canceled, 1)
end)

h.test("preset refuses an ambiguous name", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset "Raid Healer"')
    QuietUIDB.presets.duplicate = { name = 'RAID HEALER', settings = {} }
    c.command('preset "Raid Healer"')
    A.ok(find(c.last(), 'More than one preset'), c.last())
    A.eq(QuietUICharDB.presetId, c.healer)
    A.eq(c.canceled, 1)
end)

h.test("preset in combat applies settings now and selects the layout after combat", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset "Raid Healer"')
    c.combat = true
    c.command('preset Minimal')
    A.eq(QuietUICharDB.presetId, c.minimal)
    A.eq(QuietUICharDB.chat, false)
    A.eq(QuietUICharDB.chatFade, nil)
    A.eq(#c.selected, 1)
    A.eq(QuietUICharDB.previousLayout, 3)
    A.ok(QuietUIDB.enabled)
    c.combat = false
    t.mock:fire('PLAYER_REGEN_ENABLED')
    A.eq(c.selected[2], 'Quiet')
    A.eq(QuietUICharDB.previousLayout, 3)
    c.command('preset Raid Healer')
    A.eq(QuietUICharDB.presetId, c.healer)
    A.eq(c.selected[3], 'Raid')
end)

h.test("preset can be selected while disabled; off restores the layout and on selects it", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset "Raid Healer"')
    c.command('preset Minimal')
    c.command('preset Raid Healer')
    A.eq(#c.selected, 3)
    c.command('off')
    A.falsy(QuietUIDB.enabled)
    A.eq(c.restored, 1)
    A.eq(QuietUICharDB.previousLayout, nil)
    c.command('preset Minimal')
    A.falsy(QuietUIDB.enabled)
    A.eq(QuietUICharDB.presetId, c.minimal)
    A.eq(#c.selected, 3)
    c.command('on')
    A.ok(QuietUIDB.enabled)
    A.eq(c.selected[4], 'Quiet')
    A.eq(QuietUICharDB.previousLayout, 3)
    c.command('preset')
    A.ok(find(t.mock.printed[#t.mock.printed - 1] or '', 'Current preset: Minimal.'))
end)

h.test("preset lists none when no presets exist and detaches", function(t)
    local A = t.assert
    local c = setup(t)
    c.command('preset Minimal')
    QuietUIDB.presets = {}
    c.command('preset')
    A.ok(find(c.last(), 'Available presets: none.'), c.last())
    A.eq(QuietUICharDB.presetId, nil)
end)
