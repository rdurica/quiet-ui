-- Only on hover overrides combat, grace, XP rewards and grouped auras; Glance and Edit Mode reveal.
local h = ...

local function frame(parent) return CreateFrame("Frame", nil, parent) end

h.test("Visible hover mode suppresses combat, grace, XP rewards and grouped auras", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB.hoverOnly = { xp = true, cooldowns = true, meter = true, auras = true }
    MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter = frame(UIParent), frame(UIParent), frame(UIParent)
    BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
    ns.InCombat = function() return true end
    ns.InGroup = function() return true end
    ns.InForcedInstance = function() return true end
    ns.Hit = function(obj) return obj.hot == true end
    ns.FindFaders(false)
    ns.MarkCombatEnd(); ns.MarkQuestXP(100)
    local function tick()
        ns.NextFadeTick(); ns.UpdateFaders(1); ns.UpdateSmooth(1)
    end
    tick()
    local all = { MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter, BuffFrame, DebuffFrame }
    for _, obj in ipairs(all) do
        A.eq(obj._alpha, 0, "Automatic rule overrode Only on hover")
        obj.hot = true
    end
    tick()
    A.ok(DebuffFrame._alpha == 1 and BuffFrame._alpha == 1 and DamageMeter._alpha == 1
        and EssentialCooldownViewer._alpha == 1 and MainStatusTrackingBarContainer._alpha == 1)
    for _, obj in ipairs(all) do obj.hot = false end
    ns.Glancing = function() return true end
    tick(); A.ok(DamageMeter._alpha == 1 and DebuffFrame._alpha == 1)
    ns.Glancing = function() return false end
    ns.InEditMode = function() return true end
    tick(); A.ok(DamageMeter._alpha == 1 and BuffFrame._alpha == 1)
    ns.InEditMode = function() return false end
    tick(); A.ok(DamageMeter._alpha == 0 and DebuffFrame._alpha == 0)
    local box
    for _, f in ipairs(mock.frames) do
        local p = f._points[1]
        if p and p[1] == "ALL" and p[2] == DamageMeter then box = f end
    end
    A.ok(box, "No hover catcher was placed over the meter")
    A.ok(box._parent == UIParent and box._shown, "Hover catcher followed faded parent")
    box.hot = true; tick(); A.eq(DamageMeter._alpha, 1, "Container gap catcher did not reveal meter")
    ns.HideHoverCatchers(); A.shown(box, false)
    ns.RestoreAlpha(); A.eq(DamageMeter._alpha, 1)
end)
