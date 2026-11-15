-- Hooks respect the feature's own gate (ns.Feature{ enabled = ... }), not only the addon switch:
-- a gated feature's hook does nothing while its module is off, and restore still runs.
local h = ...

local function hooked(t, global, gate)
    local count = { original = 0, hook = 0 }
    _G[global] = function() count.original = count.original + 1 end
    t.ns.Feature({
        name = "hookgate" .. global, enabled = gate,
        hooks = { [global] = function() count.hook = count.hook + 1 end },
    })
    return count
end

h.test("a hook of a feature with a false gate does nothing while the addon is on; the original still runs", function(t)
    local A = t.assert
    local count = hooked(t, "QuietGateGlobal", function() return false end)
    t.boot()
    A.eq(QuietUIDB.enabled, true, "the addon is on")
    _G.QuietGateGlobal()
    A.deep({ count.original, count.hook }, { 1, 0 })
end)

h.test("a hook of a feature with a true gate or no gate runs", function(t)
    local A = t.assert
    local gated = hooked(t, "QuietGateOn", function() return true end)
    local plain = hooked(t, "QuietGatePlain", nil)
    t.boot()
    _G.QuietGateOn()
    _G.QuietGatePlain()
    A.eq(gated.hook, 1, "true gate")
    A.eq(plain.hook, 1, "no gate")
end)

h.test("a hook follows its gate live: on, off, on", function(t)
    local A = t.assert
    local on = true
    local count = hooked(t, "QuietGateLive", function() return on end)
    t.boot()
    _G.QuietGateLive(); A.eq(count.hook, 1, "gate on")
    on = false
    _G.QuietGateLive(); A.eq(count.hook, 1, "gate off")
    on = true
    _G.QuietGateLive(); A.eq(count.hook, 2, "gate on again")
end)

h.test("a gate that throws counts as off for its hook", function(t)
    local count = hooked(t, "QuietGateThrows", function() error("gate boom") end)
    t.boot(false)
    _G.QuietGateThrows()
    _G.QuietGateThrows()
    t.assert.eq(count.hook, 0, "hook ran with a throwing gate")
end)

h.test("a hook installed late for a feature with a false gate does nothing", function(t)
    local count = { hook = 0 }
    t.ns.Feature({
        name = "hookgatelate", enabled = function() return false end,
        hooks = { QuietGateLate = function() count.hook = count.hook + 1 end },
    })
    _G.QuietGateLate = function() end
    t.boot()
    _G.QuietGateLate()
    t.assert.eq(count.hook, 0)
end)

h.test("with the addon off a hook does nothing even when its gate is true", function(t)
    local count = hooked(t, "QuietGateOff", function() return true end)
    t.boot()
    SlashCmdList.QUIETUI("off")
    _G.QuietGateOff()
    t.assert.eq(count.hook, 0)
end)

h.test("a feature with a false gate still restores, and its hook stays silent", function(t)
    local A = t.assert
    local restored = 0
    local count = { hook = 0 }
    _G.QuietGateRestore = function() end
    t.ns.Feature({
        name = "hookgaterestore", enabled = function() return false end,
        restore = function() restored = restored + 1 end,
        hooks = { QuietGateRestore = function() count.hook = count.hook + 1 end },
    })
    t.boot()
    t.ns.RestoreAll()
    _G.QuietGateRestore()
    A.eq(restored, 1, "restore ran")
    A.eq(count.hook, 0, "hook silent")
end)
