-- A window released or reset during combat while hidden still gets Blizzard's point back when
-- combat ends, so it does not show up displaced the next time it opens.
local h = ...
local W = h.lib("modern-windows")

h.test("a hidden window reset in combat returns to its Blizzard point when combat ends", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    t.boot()
    QuietUICharDB = { modernize = { enabled = true } }
    local frame = W.window("ZzHiddenResetWindow")
    ns.Modern.MakeMovable(frame, "ZzHiddenResetWindow")
    local original = W.point(frame)
    QuietUICharDB.windowPoints = { ZzHiddenResetWindow = { "CENTER", "CENTER", 7, 8 } }
    frame:Hide(); frame:Show()
    A.deep(W.point(frame), { "CENTER", "CENTER", 7, 8 }, "saved point applied")
    frame:Hide()
    mock.state.combat = true
    ns.Modern.ResetPositions()
    A.deep(W.point(frame), { "CENTER", "CENTER", 7, 8 }, "combat does not set points")
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.deep(W.point(frame), original, "original point returns while the window is hidden")
end)
