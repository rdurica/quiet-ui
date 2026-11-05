-- The layout prompt per character: the version is answered on the account, the switch on each character.
local h = ...

local function editMode(info)
    local state = { writes = 0, switches = {} }
    C_EditMode = {
        GetLayouts = function() return info end,
        SetActiveLayout = function(index) state.switches[#state.switches + 1] = index; info.activeLayout = index end,
        SaveLayouts = function() state.writes = state.writes + 1 end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    InCombatLockdown = function() return false end
    return state
end

local function prompt(mock)
    local found = mock:find(function(f) return f.yes and f.no and f.text end)
    for _, f in ipairs(found) do if f:IsShown() then return f end end
end

local function label(button)
    return button.label and button.label:GetText() or button:GetText()
end

local function answered(ns)
    QuietUIDB = { enabled = true, layoutHash = ns.Layout.ShippedHash() }
end

h.test("A character without the active layout is asked to switch", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    answered(ns)
    QuietUICharDB = { welcomed = true }
    local state = editMode({ activeLayout = 1, layouts = { { layoutName = "QuietUI", layoutType = 1 } } })
    t.boot()
    local p = prompt(mock)
    A.ok(p, "the prompt is shown")
    A.eq(label(p.yes), "Switch")
    p.yes:Click()
    A.eq(state.switches[#state.switches], ns.Layout.PresetCount() + 1, "the QuietUI layout is active")
    A.eq(state.writes, 0, "the layout is not written again")
    A.eq(QuietUICharDB.layoutHash, ns.Layout.ShippedHash())
end)

h.test("A character already on the layout is not asked", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    answered(ns)
    QuietUICharDB = { welcomed = true }
    editMode({ activeLayout = 3, layouts = { { layoutName = "QuietUI", layoutType = 1 } } })
    t.boot()
    A.falsy(prompt(mock))
    A.eq(QuietUICharDB.layoutHash, ns.Layout.ShippedHash())
end)

h.test("Not now on one character still asks on the next", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    answered(ns)
    QuietUICharDB = { welcomed = true }
    editMode({ activeLayout = 1, layouts = {} })
    t.boot()
    local p = prompt(mock)
    A.ok(p, "the prompt is shown")
    A.eq(label(p.yes), "Add")
end)

h.test("A changed layout asks to update, then the character counts as answered", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { enabled = true, layoutHash = "old" }
    QuietUICharDB = { welcomed = true, layoutHash = "old" }
    local state = editMode({ activeLayout = 3, layouts = { { layoutName = "QuietUI", layoutType = 1 } } })
    t.boot()
    local p = prompt(mock)
    A.eq(label(p.yes), "Update")
    p.yes:Click()
    A.eq(state.writes, 1)
    A.eq(QuietUIDB.layoutHash, ns.Layout.ShippedHash())
    A.eq(QuietUICharDB.layoutHash, ns.Layout.ShippedHash())
end)

h.test("The layout prompt follows a welcome that keeps the look", function(t)
    local mock, A = t.mock, t.assert
    editMode({ activeLayout = 1, layouts = {} })
    t.boot()
    A.falsy(prompt(mock), "the welcome answers first")
    local welcome = mock:find(function(f) return f.cards and f.note end)[1]
    welcome.cards.classic:Click()
    welcome.choose._scripts.PreClick(welcome.choose)
    welcome.choose._scripts.PostClick(welcome.choose)
    local p = prompt(mock)
    A.ok(p, "the layout prompt follows without a reload")
    A.eq(label(p.yes), "Add")
end)
