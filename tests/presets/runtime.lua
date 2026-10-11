-- Preset layout selection at runtime: save invalidation, combat deferral, disabled restore, retries.
local h = ...

-- Edit Mode is replaced by recorders on the public ns; the real event flow drives them.
local function setup(t)
    local ns = t.ns
    local c = { selected = 0, quiet = 0, restored = 0, combat = false, ready = true }
    QuietUIDB = { enabled = true }
    QuietUICharDB = { previousLayout = 3, presetLayoutManaged = true }
    local id = assert(ns.SavePreset(nil, 'Healer', { layoutName = 'Raid' }, { chatFade = 0 }))
    ns.ActivatePreset(id)
    ns.ForceQuietLayout = function() return c.force ~= false end
    ns.ModernChat = function() return false end
    ns.SelectQuietLayout = function() c.quiet = c.quiet + 1; return true end
    ns.SelectPresetLayout = function()
        if c.combat or not c.ready then return false end
        c.selected = c.selected + 1
        return true
    end
    ns.RestorePreviousLayout = function()
        if c.combat then return false end
        c.restored = c.restored + 1
        return true
    end
    t.boot()
    c.base = c.selected
    return c
end

h.test("active preset selects its own layout, not the QuietUI one", function(t)
    local A = t.assert
    local c = setup(t)
    A.ok(c.selected >= 1, 'Active presets must select their own layout')
    A.eq(c.quiet, 0, 'Active presets must select their own layout')
end)

h.test("saving a different layout invalidates the selection", function(t)
    local A = t.assert
    local c = setup(t)
    t.ns.ApplyAll()
    A.eq(c.selected, c.base, 'A chosen layout is not selected again')
    t.ns.LayoutSettingsChanged(); t.ns.ApplyAll()
    A.eq(c.selected, c.base + 1, 'Saving a different layout must invalidate selection')
end)

h.test("combat defers layout selection until combat ends", function(t)
    local A = t.assert
    local c = setup(t)
    t.ns.LayoutSettingsChanged(); t.ns.ApplyAll()
    A.eq(c.selected, c.base + 1)
    c.combat = true; t.ns.LayoutSettingsChanged(); t.ns.ApplyAll()
    A.eq(c.selected, c.base + 1)
    c.combat = false; t.mock:fire('PLAYER_REGEN_ENABLED')
    A.eq(c.selected, c.base + 2, 'Combat must defer selection')
end)

h.test("restore finishes while disabled even after detaching the preset", function(t)
    local A = t.assert
    local c = setup(t)
    c.combat = true; QuietUIDB.enabled = false; t.ns.ApplyAll()
    t.ns.ForceQuietLayout = function() return false end
    c.combat = false; t.mock:fire('PLAYER_REGEN_ENABLED')
    A.eq(c.restored, 1, 'Restore must finish while disabled, even after detaching the preset')
end)

h.test("pending layout retries once Edit Mode is ready without another event", function(t)
    local A = t.assert
    local c = setup(t)
    c.ready = false; t.ns.LayoutSettingsChanged(); t.ns.ApplyAll()
    A.eq(c.selected, c.base)
    c.ready = true; t.mock:tick(0.1)
    A.eq(c.selected, c.base + 1, 'Retry pending layout after Edit Mode becomes ready without another event')
end)

h.test("saved layout does not override an active preview and disabled previews retry", function(t)
    local A = t.assert
    local c = setup(t)
    local previews = 0
    t.ns.UpdateLayoutPreview = function() previews = previews + 1; return true end
    t.ns.LayoutSettingsChanged(); t.ns.ApplyAll()
    A.eq(c.selected, c.base, 'Saved layout must not override an active preview')
    A.ok(previews > 0, 'Saved layout must not override an active preview')
    QuietUIDB.enabled = false
    local previous = previews
    t.mock:fire('PLAYER_REGEN_ENABLED')
    A.ok(previews > previous, 'Deferred previews must retry while disabled')
end)
