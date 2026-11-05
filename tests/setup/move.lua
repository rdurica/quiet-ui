-- The setup window drags by its header and opens where it was left, after a reload too.
local h = ...

h.test("Dragging the header moves setup, saves the point and Show puts it back", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    local handle = ui.dragHandle
    A.ok(ui:IsMovable() and handle, "setup is movable by a header handle")
    handle._scripts.OnDragStart(handle)
    A.ok(ui:IsMoving(), "drag starts moving the window")
    ui:ClearAllPoints()
    ui:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
    handle._scripts.OnDragStop(handle)
    A.falsy(ui:IsMoving(), "drag stop ends moving")
    local saved = QuietUIDB.setupPoint
    A.ok(saved and saved[1] == "TOPLEFT" and saved[3] == 120 and saved[4] == -80, "point is saved")
    ui:Hide()
    ui:ClearAllPoints()
    ui:SetPoint("CENTER")
    ns.Setup.Show()
    local point, _, _, x, y = ui:GetPoint(1)
    A.ok(point == "TOPLEFT" and x == 120 and y == -80, "Show restores the saved point")
end)
