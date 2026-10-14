-- Fade steps (UpdateFaded, EaseAlpha) and texture hiding with a secret alpha.
local h = ...

local FADE = 0.3

h.test("ForceTextureHidden hides a texture whose alpha is secret", function(t)
    local A = t.assert
    local holder = CreateFrame("Frame")
    local tex = holder:CreateTexture()
    tex._alpha = t.mock:secret(1)
    A.noThrow(t.ns.ForceTextureHidden, tex)
    A.eq(tex._alpha, 0, "secret-alpha texture alpha")
end)

h.test("UpdateFaded shows at once and fades by elapsed / 0.3", function(t)
    local A, ns = t.assert, t.ns
    local f = CreateFrame("Frame")
    ns.NextFadeTick()
    ns.UpdateFaded(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.1 / FADE, 1e-6, "first hide step")
    ns.UpdateFaded(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.1 / FADE, 1e-6, "second call in the same tick must not fade again")
    ns.NextFadeTick()
    ns.UpdateFaded(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.2 / FADE, 1e-6, "second hide step")
    ns.NextFadeTick()
    ns.UpdateFaded(f, true, 0.1)
    A.eq(f:GetAlpha(), 1, "show is immediate")
    for _ = 1, 4 do
        ns.NextFadeTick()
        ns.UpdateFaded(f, false, 0.1)
    end
    A.eq(f:GetAlpha(), 0, "hide settles at 0")
end)

h.test("EaseAlpha shows at once and fades by elapsed / 0.3", function(t)
    local A, ns = t.assert, t.ns
    local f = CreateFrame("Frame")
    ns.EaseAlpha(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.1 / FADE, 1e-6, "first hide step")
    ns.EaseAlpha(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.2 / FADE, 1e-6, "second hide step")
    ns.EaseAlpha(f, true, 0.1)
    A.eq(f:GetAlpha(), 1, "show is immediate")
    for _ = 1, 4 do ns.EaseAlpha(f, false, 0.1) end
    A.eq(f:GetAlpha(), 0, "hide settles at 0")
end)

h.test("EaseAlpha with a held secret alpha reads the frame and fades from it", function(t)
    local A, ns = t.assert, t.ns
    local f = CreateFrame("Frame")
    ns.HoldSecretAlpha(f, 1)
    ns.EaseAlpha(f, false, 0.1)
    A.near(f:GetAlpha(), 1 - 0.1 / FADE, 1e-6, "secret hold step")
    A.eq(f._quietSecret, nil, "secret hold cleared by EaseAlpha")
end)
