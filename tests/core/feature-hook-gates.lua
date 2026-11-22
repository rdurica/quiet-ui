-- Hooks respect the feature's own gate (ns.Feature{ enabled = ... }), not only the addon switch:
-- a gated feature's hook does nothing while its module is off, and restore still runs.
local h = ...

local function hooked(t, global, gate)
    local count = { original = 0, hook = 0 }
    local original = function() count.original = count.original + 1 end
    _G[global] = original
    t.ns.Feature({
        name = "hookgate" .. global, enabled = gate,
        hooks = { [global] = function() count.hook = count.hook + 1 end },
    })
    return count, original
end

local function hookCount(mock, method)
    local n = 0
    for _, hook in ipairs(mock.hooks) do
        if hook.obj == _G and hook.method == method then n = n + 1 end
    end
    return n
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
    t.ns.ApplyAll()
    _G.QuietGateLive(); A.eq(count.hook, 1, "gate off")
    on = true
    t.ns.ApplyAll()
    _G.QuietGateLive(); A.eq(count.hook, 2, "gate on again")
end)

h.test("a hook is not installed while its gate is off at boot, installs on ApplyAll when enabled, and stops on ApplyAll when disabled", function(t)
    local A = t.assert
    local on = false
    local count, original = hooked(t, "QuietGateDeferred", function() return on end)
    t.boot()
    A.eq(_G.QuietGateDeferred, original, "global stays unwrapped at boot while gate is off")
    A.eq(hookCount(t.mock, "QuietGateDeferred"), 0, "hooksecurefunc not called while gate is off")
    t.ns.Registry.InstallHooks()
    A.eq(_G.QuietGateDeferred, original, "InstallHooks skips disabled feature")
    A.eq(hookCount(t.mock, "QuietGateDeferred"), 0)
    _G.QuietGateDeferred()
    A.deep(count, { original = 1, hook = 0 })

    on = true
    t.ns.ApplyAll()
    A.ne(_G.QuietGateDeferred, original, "global wrapped once gate turns on and ApplyAll runs")
    A.eq(hookCount(t.mock, "QuietGateDeferred"), 1, "installed once")
    t.ns.ApplyAll()
    A.eq(hookCount(t.mock, "QuietGateDeferred"), 1, "still installed only once across ApplyAll")
    _G.QuietGateDeferred()
    A.deep(count, { original = 2, hook = 1 })

    on = false
    t.ns.ApplyAll()
    _G.QuietGateDeferred()
    A.deep(count, { original = 3, hook = 1 }, "hook does not run after gate turns off and ApplyAll runs")
end)

h.test("a hook installed while enabled stops running after the gate flips off and RestoreAll runs", function(t)
    local A = t.assert
    local on = true
    local count = hooked(t, "QuietGateFlipRestore", function() return on end)
    t.boot()
    _G.QuietGateFlipRestore()
    A.deep(count, { original = 1, hook = 1 }, "hook runs while gate is on")

    on = false
    t.ns.RestoreAll()
    _G.QuietGateFlipRestore()
    A.deep(count, { original = 2, hook = 1 }, "hook stops after gate flips off and RestoreAll runs")

    on = true
    t.ns.ApplyAll()
    _G.QuietGateFlipRestore()
    A.deep(count, { original = 3, hook = 2 }, "hook runs again after gate flips on and ApplyAll runs")
end)

h.test("a late global is hooked once its disabled gate turns on and ApplyAll runs", function(t)
    local A = t.assert
    local on = false
    local count = { original = 0, hook = 0 }
    t.ns.Feature({
        name = "hookgatelatedeferred", enabled = function() return on end,
        hooks = { QuietGateLateDeferred = function() count.hook = count.hook + 1 end },
    })
    t.boot()
    local original = function() count.original = count.original + 1 end
    _G.QuietGateLateDeferred = original
    t.ns.ApplyAll()
    A.eq(_G.QuietGateLateDeferred, original, "late global stays unwrapped while gate is off")
    A.eq(hookCount(t.mock, "QuietGateLateDeferred"), 0)

    on = true
    t.ns.ApplyAll()
    A.ne(_G.QuietGateLateDeferred, original, "late global wrapped after gate turns on and ApplyAll runs")
    A.eq(hookCount(t.mock, "QuietGateLateDeferred"), 1)
    _G.QuietGateLateDeferred()
    A.deep(count, { original = 1, hook = 1 })
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
