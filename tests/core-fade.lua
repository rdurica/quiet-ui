-- Run from the addon directory: lua tests/core-fade.lua
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local SECRET = setmetatable({}, { __tostring = function() return '<secret>' end })
local function namespace()
    QuietUIDB = { enabled = true }
    issecretvalue = function(value) return value == SECRET end
    hooksecurefunc = function(obj, method, hook)
        local original = obj[method]
        obj[method] = function(self, ...)
            local result = original(self, ...)
            hook(self, ...)
            return result
        end
    end
    local ns = {}
    assert(loadfile('Core.lua'))('QuietUI', ns)
    return ns
end
local function frame(alpha)
    local obj = { alpha = alpha or 1 }
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    return obj
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

test('ForceTextureHidden hides a texture whose alpha is secret', function()
    local ns = namespace()
    local tex = frame()
    tex.GetAlpha = function() return SECRET end
    function tex:GetObjectType() return 'Texture' end
    local ok, err = pcall(ns.ForceTextureHidden, tex)
    assert(ok, 'ForceTextureHidden threw on a secret alpha: ' .. tostring(err))
    assert(tex.alpha == 0, 'Secret alpha texture was not set to 0, got ' .. tostring(tex.alpha))
end)

test('UpdateFaded shows at once and fades by elapsed / 0.3', function()
    local ns = namespace()
    local f = frame(1)
    ns.NextFadeTick()
    ns.UpdateFaded(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.1 / 0.3), 'First hide step: ' .. f.alpha)
    ns.UpdateFaded(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.1 / 0.3), 'Faded twice in one tick: ' .. f.alpha)
    ns.NextFadeTick()
    ns.UpdateFaded(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.2 / 0.3), 'Second hide step: ' .. f.alpha)
    ns.NextFadeTick()
    ns.UpdateFaded(f, true, 0.1)
    assert(f.alpha == 1, 'Show was not immediate: ' .. f.alpha)
    for _ = 1, 4 do
        ns.NextFadeTick()
        ns.UpdateFaded(f, false, 0.1)
    end
    assert(f.alpha == 0, 'Hide did not settle at 0: ' .. f.alpha)
end)

test('EaseAlpha shows at once and fades by elapsed / 0.3', function()
    local ns = namespace()
    local f = frame(1)
    ns.EaseAlpha(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.1 / 0.3), 'First hide step: ' .. f.alpha)
    ns.EaseAlpha(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.2 / 0.3), 'Second hide step: ' .. f.alpha)
    ns.EaseAlpha(f, true, 0.1)
    assert(f.alpha == 1, 'Show was not immediate: ' .. f.alpha)
    for _ = 1, 4 do ns.EaseAlpha(f, false, 0.1) end
    assert(f.alpha == 0, 'Hide did not settle at 0: ' .. f.alpha)
end)

test('EaseAlpha with a held secret alpha reads the frame and fades from it', function()
    local ns = namespace()
    local f = frame(1)
    ns.HoldSecretAlpha(f, 1)
    ns.EaseAlpha(f, false, 0.1)
    assert(near(f.alpha, 1 - 0.1 / 0.3), 'Secret hold step: ' .. tostring(f.alpha))
    assert(f._quietSecret == nil, 'Secret hold was not cleared by EaseAlpha')
end)

if failures > 0 then os.exit(1) end
