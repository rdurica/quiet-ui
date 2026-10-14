-- Player and pet per-frame cost and cache invalidation: one target-life read and one style read
-- per frame, stable pet ancestry needs no walk, reparenting and style changes take effect.
local h = ...
local P = h.lib("player")
local unwrap = P.unwrap

-- Fixture with counters: style reads, parent reads on the pet, SetParent hook installs.
local function setup(t)
    local ns, mock = t.ns, t.mock
    local s = P.env(t, { plain = true })
    s.style, s.targetReads, s.styleReads, s.parentReads = "classic", 0, 0, 0
    s.sample = P.secret(mock, 0.5)
    UnitHealthPercent = function() return s.sample end
    UnitPowerPercent = function() return s.sample end
    local life = UnitIsDeadOrGhost
    UnitIsDeadOrGhost = function(unit)
        if unit == "target" then s.targetReads = s.targetReads + 1 end
        return life(unit)
    end
    ns.Settings.PlayerStyle = function() s.styleReads = s.styleReads + 1; return s.style end
    QuietUICharDB.requireLivingTarget = true
    function s.countParents(f)
        local get = f.GetParent
        f.GetParent = function(self) s.parentReads = s.parentReads + 1; return get(self) end
    end
    function s.hookInstalls()
        local n = 0
        for _, hook in ipairs(mock.hooks) do
            if hook.method == "SetParent" then n = n + 1 end
        end
        return n
    end
    function s.frame(parent) return CreateFrame("Frame", nil, parent or UIParent) end
    s.countParents(PetFrame)
    function s.step() ns.UpdateSmooth(1 / 60) end
    return s
end

h.test("Player and target visibility share one target-life read per frame", function(t)
    local s = setup(t)
    s.step()
    s.targetReads = 0
    for _ = 1, 60 do s.step() end
    t.assert.eq(s.targetReads, 60, "Player and target visibility must share one target-life read per frame")
end)

h.test("Player visibility and thresholds share one style read per frame", function(t)
    local s = setup(t)
    s.step()
    s.styleReads = 0
    for _ = 1, 60 do s.step() end
    t.assert.eq(s.styleReads, 60, "Player visibility and thresholds must share one style read per frame")
end)

h.test("A stable pet parent needs no repeated ancestry walks or hook installs", function(t)
    local s = setup(t)
    s.step()
    local installs = s.hookInstalls()
    s.parentReads = 0
    for _ = 1, 60 do s.step() end
    t.assert.eq(s.parentReads, 0, "A successful stable-parent hook must prevent repeated ancestry walks")
    t.assert.eq(s.hookInstalls(), installs, "The parent hook must not be installed again")
end)

h.test("Alpha samples stay fresh every frame", function(t)
    local s = setup(t)
    s.step()
    s.sample = P.secret(t.mock, 0.5)
    s.step()
    t.assert.ok(rawequal(PlayerFrame._alpha, s.sample) and rawequal(PetFrame._alpha, s.sample),
        "Alpha samples must stay fresh every frame")
end)

h.test("A dead target fades in combat and releases its alpha when revived", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat, s.targetDead = true, true
    s.step()
    A.ne(TargetFrame._alpha, 1, "A dead target must still fade during combat")
    s.targetDead = false
    s.step()
    A.eq(TargetFrame._alpha, 1, "Reviving the target must release its alpha immediately")
end)

h.test("Reparenting the pet under the portrait isolates it and death leaves it visible", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat = true
    s.step()
    PetFrame:SetParent(PlayerFrame)
    s.step()
    A.ok(PetFrame:IsIgnoringParentAlpha(), "Reparenting under PlayerFrame must invalidate ancestry and isolate the pet")
    s.life = "dead"
    s.step()
    A.ok(unwrap(PlayerFrame._alpha) < 1 and PetFrame._alpha == 1, "Player death must leave the isolated pet visible")
    t.ns.RestorePlayerFader()
    t.ns.RestoreAlpha()
    A.falsy(PetFrame:IsIgnoringParentAlpha(), "Disable must restore original alpha inheritance")
    s.life = "alive"
    PetFrame:SetParent(UIParent)
    s.step()
    A.eq(PetFrame._alpha, 1, "Moving the pet back to UIParent must invalidate ancestry again")
end)

h.test("Changing player style takes effect on the next frame", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat = true
    s.step()
    s.style = "resource"
    t.ns.UpdateSmooth(0.3)
    A.ok(unwrap(PlayerFrame._alpha) == 0 and unwrap(PetFrame._alpha) == 0,
        "Changing player style must take effect on the next frame")
    s.style = "classic"
    s.step()
    A.ok(PlayerFrame._alpha == 1 and PetFrame._alpha == 1,
        "Re-enabling the portrait must immediately refresh cached style")
end)

h.test("Reparenting an intermediate ancestor does not leave a stale cache", function(t)
    local s = setup(t)
    s.InCombat = true
    local container = s.frame()
    PetFrame:SetParent(container)
    s.step()
    container:SetParent(PlayerFrame)
    s.step()
    t.assert.ok(PetFrame:IsIgnoringParentAlpha(), "Reparenting an intermediate ancestor must not leave a stale cache")
end)

for _, mode in ipairs({ "missing", "failed" }) do
    h.test("Unavailable parent hook (" .. mode .. ") keeps checking ancestry", function(t)
        local A = t.assert
        local s = setup(t)
        s.InCombat = true
        local working = hooksecurefunc
        if mode == "missing" then hooksecurefunc = nil
        else
            hooksecurefunc = function(obj, method, hook)
                if method == "SetParent" then error("Parent hook unavailable") end
                working(obj, method, hook)
            end
        end
        PetFrame = s.frame()
        s.countParents(PetFrame)
        s.step()
        s.parentReads = 0
        s.step()
        A.ok(s.parentReads > 0, "Unavailable parent hooks must keep checking ancestry")
        PetFrame:SetParent(PlayerFrame)
        s.step()
        A.ok(PetFrame:IsIgnoringParentAlpha(), "Reparenting must still isolate the pet without a parent hook")
    end)
end
