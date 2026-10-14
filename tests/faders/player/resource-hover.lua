-- Resource hover mode bypasses the secret curves and restores both child and root alpha.
local h = ...

local function frame(parent) return CreateFrame("Frame", nil, parent) end

h.test("Resource hover bypasses secret curves and restores both child and root alpha", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB.hoverOnly = { resource = true }
    ns.World.InCombat = function() return true end
    ns.Hit = function(obj) return obj.hot == true end
    PersonalResourceDisplayFrame = frame(UIParent)
    local root = PersonalResourceDisplayFrame
    local health, power = frame(root), frame(root)
    health._alpha, power._alpha = 0.6, 0.8
    root.HealthBarsContainer = health
    UnitPowerPercent = function() error("Hover mode read power") end
    UnitHealthPercent = function() error("Hover mode read health") end
    ns.Faders.Find(false)
    local update = ns.Faders.UpdateSmooth
    update(1)
    A.ok(root._alpha == 1 and health._alpha == 0 and power._alpha == 0)
    root.hot = true; update(0.01)
    A.ok(health._alpha == 1 and power._alpha == 1)
    root.hot = false; update(0.15)
    A.ok(health._alpha > 0 and health._alpha < 1 and power._alpha > 0 and power._alpha < 1)
    update(0.15); A.ok(health._alpha == 0 and power._alpha == 0)
    ns.Glancing = function() return true end
    update(0.01); A.ok(health._alpha == 1 and power._alpha == 1)
    ns.Glancing = function() return false end
    root._children = {}; root._quietKids = nil
    update(0.15); update(0.15)
    A.eq(root._alpha, 0, "Childless resource root never finished fading")
    ns.RestoreAlpha()
    A.ok(root._alpha == 1 and health._alpha == 0.6 and power._alpha == 0.8)
    A.eq(#mock.printed, 0, "Hover mode reported an error: " .. tostring(mock.printed[1]))
end)
