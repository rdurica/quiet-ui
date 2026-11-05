-- Draggable windows with saved points (windowPoints in the character settings).
local h = ...
local L = h.lib("modern")

local function window(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(300, 400)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -116)
    return f
end

local function point(f)
    local p, rel, rp, x, y = f:GetPoint(1)
    return { p, rp, x, y }, rel
end

h.test("dragging out of combat saves windowPoints[key] as point, relativePoint, x, y", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = window("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.drag(f, "TOPLEFT", "BOTTOMLEFT", 120, 340)
    A.deep(QuietUICharDB.windowPoints.ZzWindow, { "TOPLEFT", "BOTTOMLEFT", 120, 340 })
    A.eq(f:IsMoving(), false, "movement stopped")
end)

h.test("the drag handle starts a real move and the window is movable", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = window("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    local handle = L.handle(f)
    A.ok(handle, "a drag handle child exists")
    local startFn = handle._scripts.OnDragStart or handle._scripts.OnMouseDown
    startFn(handle)
    A.eq(f:IsMoving(), true, "StartMoving was called")
    local stopFn = handle._scripts.OnDragStop or handle._scripts.OnMouseUp
    stopFn(handle)
    A.eq(f:IsMoving(), false)
end)

h.test("reshowing applies the saved point over Blizzard's", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { windowPoints = { ZzWindow = { "CENTER", "CENTER", 10, 20 } } }
    t.boot()
    local f = window("ZzWindow")
    f:Hide()
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    f:Show()
    local p, rel = point(f)
    A.deep(p, { "CENTER", "CENTER", 10, 20 })
    A.eq(rel, UIParent)
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    f:Hide(); f:Show()
    p = point(f)
    A.deep(p, { "CENTER", "CENTER", 10, 20 }, "applied on every show")
end)

h.test("a window with no saved point keeps Blizzard's position", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = window("ZzWindow")
    f:Hide()
    ns.Modern.MakeMovable(f, "ZzWindow")
    f:Show()
    A.deep(point(f), { "TOPLEFT", "TOPLEFT", 0, -116 })
end)

h.test("in combat no point is set; the saved point applies on PLAYER_REGEN_ENABLED", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUICharDB = { windowPoints = { ZzWindow = { "CENTER", "CENTER", 10, 20 } } }
    t.boot()
    local f = window("ZzWindow")
    f:Hide()
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    mock.state.combat = true
    local setPoints = 0
    local original = f.SetPoint
    f.SetPoint = function(self, ...) setPoints = setPoints + 1; return original(self, ...) end
    local clears = 0
    local clear = f.ClearAllPoints
    f.ClearAllPoints = function(self, ...) clears = clears + 1; return clear(self, ...) end
    f:Show()
    A.eq(setPoints, 0, "no SetPoint in combat")
    A.eq(clears, 0, "no ClearAllPoints in combat")
    A.deep(point(f), { "TOPLEFT", "TOPLEFT", 0, -116 })
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.deep(point(f), { "CENTER", "CENTER", 10, 20 }, "applied after combat")
end)

h.test("ReleaseMovable keeps saved points and stops applying them", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = window("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.drag(f, "CENTER", "CENTER", 30, 40)
    ns.Modern.ReleaseMovable(f)
    A.deep(QuietUICharDB.windowPoints.ZzWindow, { "CENTER", "CENTER", 30, 40 }, "saved point kept")
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    f:Hide(); f:Show()
    A.deep(point(f), { "TOPLEFT", "TOPLEFT", 0, -116 }, "Blizzard position is used again")
    local handle = L.handle(f)
    if handle then
        local startFn = handle._scripts.OnDragStart or handle._scripts.OnMouseDown
        if startFn then startFn(handle) end
    end
    A.eq(f:IsMoving(), false, "the handle no longer moves the window")
end)

h.test("MakeMovable again after ReleaseMovable uses the kept point", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = window("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.drag(f, "CENTER", "CENTER", 30, 40)
    ns.Modern.ReleaseMovable(f)
    f:Hide()
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    f:Show()
    A.deep(point(f), { "CENTER", "CENTER", 30, 40 })
end)

h.test("two windows keep separate saved points", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local a, b = window("ZzA"), window("ZzB")
    ns.Modern.MakeMovable(a, "ZzA"); ns.Modern.MakeMovable(b, "ZzB")
    L.drag(a, "CENTER", "CENTER", 1, 2)
    L.drag(b, "TOP", "TOP", 3, 4)
    A.deep(QuietUICharDB.windowPoints.ZzA, { "CENTER", "CENTER", 1, 2 })
    A.deep(QuietUICharDB.windowPoints.ZzB, { "TOP", "TOP", 3, 4 })
end)
