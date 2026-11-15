-- Layout module off (settings.modules.layout = false): QuietUI never prompts for, selects or switches an
-- Edit Mode layout, and turning the module off restores previousLayout first. Driven through public ns.* and events.
local h = ...

-- Edit Mode with Original (index 1) active and the QuietUI layout already in the account list.
local function env(t)
    local ns = t.ns
    local e = { combat = false, switches = {}, saves = 0, prompts = {} }
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    ns.Layout.STRING = "export"
    InCombatLockdown = function() return e.combat end
    e.info = { activeLayout = 1, layouts = {
        { layoutName = "Original", layoutType = 1 },
        { layoutName = "Raid", layoutType = 1 },
        { layoutName = "QuietUI", layoutType = 1 },
    } }
    C_EditMode = {
        GetLayouts = function() return e.info end,
        SetActiveLayout = function(index)
            e.switches[#e.switches + 1] = index
            e.info.activeLayout = index
        end,
        SaveLayouts = function(value) e.saves = e.saves + 1; e.info = value end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    local create = CreateFrame
    CreateFrame = function(...)
        local frame = create(...)
        e.prompts[#e.prompts + 1] = frame
        return frame
    end
    function e.promptShown()
        for _, frame in ipairs(e.prompts) do
            if frame.yes and frame.no and frame:IsShown() then return true end
        end
        return false
    end
    return e
end

local function layoutOff() return { layout = false } end

local function untouched(A, e, why)
    A.eq(#e.switches, 0, why .. ": active layout must not be switched")
    A.eq(e.info.activeLayout, 1, why .. ": active layout must stay")
    A.eq(e.saves, 0, why .. ": no layout may be written")
    A.eq(QuietUICharDB.previousLayout, nil, why .. ": nothing to restore later")
    A.eq(QuietUIDB.layoutHash, nil, why .. ": no layout answer recorded")
end

h.test("layout on: the switch prompt appears (control for the off cases)", function(t)
    local A = t.assert
    local e = env(t)
    t.boot()
    A.ok(e.promptShown(), "Layout on must ask to switch to the QuietUI layout")
end)

h.test("layout off: no layout prompt appears", function(t)
    local A = t.assert
    local e = env(t)
    QuietUICharDB.modules = layoutOff()
    t.boot()
    t.ns.ApplyAll()
    A.falsy(e.promptShown(), "Layout off must not offer the QuietUI layout")
    untouched(A, e, "prompt")
end)

h.test("layout off: no prompt even when the shipped layout is missing from the account", function(t)
    local A = t.assert
    local e = env(t)
    e.info.layouts[3] = nil
    QuietUICharDB.modules = layoutOff()
    t.boot()
    t.ns.ApplyAll()
    A.falsy(e.promptShown(), "Layout off must not offer to add the QuietUI layout")
    untouched(A, e, "missing layout")
end)

h.test("layout on: Force QuietUI layout selects the QuietUI layout on boot", function(t)
    local A = t.assert
    local e = env(t)
    QuietUICharDB.forceLayout = true
    t.boot()
    A.eq(e.info.activeLayout, 3 + #t.ns.Layout.Presets(), "Layout on with force must select the QuietUI layout")
    A.eq(QuietUICharDB.previousLayout, 1)
end)

h.test("layout off: Force QuietUI layout selects nothing on boot, apply and settle events", function(t)
    local A, mock = t.assert, t.mock
    local e = env(t)
    QuietUICharDB.forceLayout = true
    QuietUICharDB.modules = layoutOff()
    t.boot()
    t.ns.ApplyAll()
    mock:fire("EDIT_MODE_LAYOUTS_UPDATED")
    mock:fire("PLAYER_REGEN_ENABLED")
    mock:tick(10)
    untouched(A, e, "force")
    A.falsy(e.promptShown())
end)

h.test("layout off: ForceQuietLayout is false, with force set and with an active preset", function(t)
    local ns, A = t.ns, t.assert
    env(t)
    QuietUICharDB.forceLayout = true
    A.ok(ns.Settings.ForceQuietLayout(), "Control: force on selects the layout")
    QuietUICharDB.modules = layoutOff()
    A.eq(ns.Settings.ForceQuietLayout(), false, "Layout off beats Force QuietUI layout")
    QuietUICharDB.forceLayout = nil
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.ActivatePreset(id)
    A.ok(ns.Settings.ForceQuietLayout(), "Control: an active preset selects its layout while Layout is on")
    ns.Settings.Presets()[id].settings.modules = layoutOff()
    ns.Settings.ActivatePreset(id)
    A.eq(ns.Settings.ForceQuietLayout(), false, "Layout off beats an active preset")
end)

h.test("layout off: activating a preset with a linked layout does not switch the layout", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    local e = env(t)
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.Presets()[id].settings.modules = layoutOff()
    A.ok(ns.Settings.ActivatePreset(id))
    t.boot()
    ns.ApplyAll()
    mock:fire("EDIT_MODE_LAYOUTS_UPDATED")
    mock:tick(10)
    untouched(A, e, "preset")
    A.eq(QuietUICharDB.presetLayoutManaged, nil, "A preset must not take ownership of the layout")
    A.falsy(e.promptShown())
end)

h.test("layout on: activating a preset with a linked layout switches to it (control)", function(t)
    local ns, A = t.ns, t.assert
    local e = env(t)
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    A.ok(ns.Settings.ActivatePreset(id))
    t.boot()
    A.eq(e.info.activeLayout, 2 + #ns.Layout.Presets(), "Layout on must select the preset's layout")
end)

h.test("layout off: direct layout selection does nothing", function(t)
    local ns, A = t.ns, t.assert
    local e = env(t)
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.Presets()[id].settings.modules = layoutOff()
    ns.Settings.ActivatePreset(id)
    ns.Layout.SelectPreset()
    ns.Layout.SelectQuiet()
    untouched(A, e, "direct selection")
end)

h.test("turning Layout off: RestoreAll selects previousLayout again, like /quiet off", function(t)
    local ns, A = t.ns, t.assert
    local e = env(t)
    QuietUICharDB.forceLayout = true
    t.boot()
    local quiet = 3 + #ns.Layout.Presets()
    A.eq(e.info.activeLayout, quiet, "Setup: QuietUI layout is active")
    A.eq(QuietUICharDB.previousLayout, 1)
    -- Setup.Write restores while the old module set is still in effect, then saves and reloads.
    ns.RestoreAll()
    A.eq(e.info.activeLayout, 1, "previousLayout must be selected again before the reload")
    A.eq(QuietUICharDB.previousLayout, nil, "Restore metadata is cleared once restored")
end)

h.test("turning Layout off with a preset layout: RestoreAll selects previousLayout again", function(t)
    local ns, A = t.ns, t.assert
    local e = env(t)
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.ActivatePreset(id)
    t.boot()
    A.eq(e.info.activeLayout, 2 + #ns.Layout.Presets(), "Setup: the preset layout is active")
    ns.RestoreAll()
    A.eq(e.info.activeLayout, 1, "previousLayout must be selected again before the reload")
    A.eq(QuietUICharDB.previousLayout, nil)
end)

h.test("after Layout is saved off and the UI reloads, the layout feature never touches the layout", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    local e = env(t)
    QuietUICharDB.forceLayout = true
    t.boot()
    ns.RestoreAll()
    A.eq(e.info.activeLayout, 1, "Setup: previousLayout restored")
    local before = #e.switches
    QuietUICharDB.modules = layoutOff()
    ns.ApplyAll()
    mock:fire("EDIT_MODE_LAYOUTS_UPDATED")
    mock:fire("PLAYER_REGEN_ENABLED")
    mock:tick(10)
    A.eq(#e.switches, before, "Layout off must not switch the layout again after the restore")
    A.eq(e.info.activeLayout, 1)
    A.eq(QuietUICharDB.previousLayout, nil)
    A.falsy(e.promptShown())
end)
