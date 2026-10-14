-- Repaint cost of a shown notice and following the tracker text size.
local h = ...
local Q = h.lib("questnotice")
local function env(t, opts) return Q.fixture(t.mock, t.ns, opts) end

-- Counts SetFont / SetPoint / ClearAllPoints on the notice and its text regions.
local function count(f)
    local c = { SetFont = 0, SetPoint = 0, ClearAllPoints = 0 }
    local function wrap(obj, name)
        local orig = obj[name]
        obj[name] = function(...) c[name] = c[name] + 1; return orig(...) end
    end
    wrap(f, "SetPoint"); wrap(f, "ClearAllPoints")
    for _, r in ipairs(f._regions) do
        if r._kind == "FontString" then wrap(r, "SetFont"); wrap(r, "SetPoint") end
    end
    return c
end
local function reset(c) for k in pairs(c) do c[k] = 0 end end

h.test("a stable shown notice restyles and re-anchors at most once in 60 frames", function(t)
    local s = env(t, { bodyFont = true })
    s.change(3)
    s.has("Wolves 3/8")
    local c = count(s.notice())
    for _ = 1, 60 do s.tick(0.016) end
    t.assert.ok(c.SetFont <= 1, "Stable notice restyled every frame: SetFont=" .. c.SetFont)
    t.assert.ok(c.SetPoint <= 1, "Stable notice re-anchored every frame: SetPoint=" .. c.SetPoint)
end)

h.test("changing the text size forces a restyle", function(t)
    local s = env(t, { bodyFont = true })
    s.change(3)
    for _ = 1, 5 do s.tick(0.016) end
    local c = count(s.notice())
    reset(c)
    QuietUICharDB.questNoticeSize = "larger"
    s.tick(0.016)
    t.assert.ok(c.SetFont >= 1, "Larger text size did not restyle the notice")
end)

h.test("a tracker font resized in place restyles the shown notice", function(t)
    local s = env(t, { bodyFont = true })
    s.change(3)
    for _ = 1, 5 do s.tick(0.016) end
    local body = s.textRegion("Wolves 3/8")
    local _, size = body:GetFont()
    t.assert.eq(size, 12, "Notice body did not start at the tracker size")
    GameFontHighlightSmall:SetFont("Fonts/default.ttf", 16, "")
    s.tick(0.016)
    local _, after = body:GetFont()
    t.assert.eq(after, 16, "Notice kept the old tracker font size")
end)
