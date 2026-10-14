-- Modern tab of the setup window: tab order, Modernize checkbox, dependent options from the
-- registry, drafts, Save, presets and Reset default.
local h = ...
local L = h.lib("modern")

local function click(b) b._scripts.OnClick(b) end

local function fixture(t, stored)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = stored or {}
    ns.ApplyAll = function() end
    ns.Layout.CurrentRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.Layout.Choices = function() return {} end
    ns.Layout.Preview = function() end
    ns.Layout.CommitPreview = function() end
    ns.Layout.CancelPreview = function() end
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    for _, tab in ipairs(ui.tabs) do
        if tab.id == "modern" then click(tab) end
    end
    return ui
end

-- Checkbox button / stepper row by exact label.
local function check(t, label)
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "Button" and f.box and f.label and f.label._text == label then return f end
    end
end
local function stepper(t, label)
    for _, f in ipairs(t.mock.frames) do
        if f.plus and f.minus and f.value and f.label and f.label._text == label then return f end
    end
end
local function checked(button) return button.box._checked == true end

h.test("Modern is the seventh of eight tabs, between Misc. and Info", function(t)
    local A = t.assert
    local ui = fixture(t)
    A.eq(#ui.tabs, 8)
    A.eq(ui.tabs[6].label._text, "Misc.")
    A.eq(ui.tabs[7].label._text, "Modern")
    A.eq(ui.tabs[7].id, "modern")
    A.eq(ui.tabs[8].label._text, "Info")
    A.eq(ui.pages[7].id, "modern")
end)

h.test("Modernize is unchecked by default and hides the options", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t)
    local modernize = check(t, "Modernize")
    A.ok(modernize, "Modernize checkbox")
    A.ok(modernize:IsVisible(), "Modernize is visible on the Modern tab")
    A.falsy(checked(modernize))
    A.falsy(stepper(t, "Theme"):IsVisible(), "Theme hidden")
    A.falsy(stepper(t, "Background"):IsVisible(), "Background hidden")
    A.falsy(check(t, "Class colours"):IsVisible(), "Class colours hidden")
    A.falsy(check(t, "Zz alpha"):IsVisible(), "area hidden")
end)

h.test("checking Modernize shows theme, background 75, class colours on and every area on", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t)
    click(check(t, "Modernize"))
    A.ok(checked(check(t, "Modernize")))
    local theme, bg = stepper(t, "Theme"), stepper(t, "Background")
    A.ok(theme:IsVisible() and bg:IsVisible())
    A.ok(theme.value._text:lower():find("dark", 1, true), "theme shows Dark, got " .. tostring(theme.value._text))
    A.ok(bg.value._text:find("75", 1, true), "background shows 75, got " .. tostring(bg.value._text))
    local colours = check(t, "Class colours")
    A.ok(colours:IsVisible() and checked(colours), "class colours default on")
    for _, area in ipairs(ns.Modern.Areas()) do
        local box = check(t, area.label)
        A.ok(box, "checkbox for " .. area.key)
        A.ok(box:IsVisible() and checked(box), area.key .. " visible and on")
    end
end)

h.test("area checkboxes follow ns.Modern.Areas() in order and label", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t)
    click(check(t, "Modernize"))
    local list = ns.Modern.Areas()
    local boxes = {}
    for _, area in ipairs(list) do boxes[#boxes + 1] = check(t, area.label) end
    A.eq(#boxes, #list)
    -- Registration order is the vertical order on the page (higher y first).
    local function top(b)
        local p = b.points and b.points[1] or b._points[1]
        return p[#p]
    end
    local last
    for i, b in ipairs(boxes) do
        local y = top(b)
        if last then A.ok(y < last, "area " .. list[i].key .. " sits below the previous one") end
        last = y
    end
end)

h.test("unchecking Modernize hides the options but keeps their values", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t)
    click(check(t, "Modernize"))
    click(check(t, "Zz alpha"))
    click(check(t, "Class colours"))
    click(stepper(t, "Background").plus)
    local bgText = stepper(t, "Background").value._text
    click(check(t, "Modernize"))
    A.falsy(check(t, "Zz alpha"):IsVisible()); A.falsy(stepper(t, "Background"):IsVisible())
    click(check(t, "Modernize"))
    A.falsy(checked(check(t, "Zz alpha")), "area stays unchecked")
    A.falsy(checked(check(t, "Class colours")), "class colours stay unchecked")
    A.eq(stepper(t, "Background").value._text, bgText, "background keeps its value")
end)

h.test("Background steps 50, 75, 90 and stops at the ends", function(t)
    local A = t.assert
    local ui = fixture(t)
    click(check(t, "Modernize"))
    local bg = stepper(t, "Background")
    local function has(n) return bg.value._text:find(tostring(n), 1, true) ~= nil end
    A.ok(has(75))
    click(bg.plus); A.ok(has(90))
    click(bg.plus); A.ok(has(90), "stays at 90")
    click(bg.minus); click(bg.minus); A.ok(has(50))
    click(bg.minus); A.ok(has(50), "stays at 50")
end)

h.test("nothing is stored until Save, closing discards the draft", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t)
    click(check(t, "Modernize"))
    A.eq(QuietUICharDB.modernize, nil, "draft only")
    ui:Hide(); ns.Setup.Show()
    A.falsy(checked(check(t, "Modernize")), "closing discards")
end)

h.test("Save with Modernize on stores enabled and the chosen options under their keys", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t)
    click(check(t, "Modernize"))
    click(check(t, "Zz beta"))
    click(check(t, "Class colours"))
    click(stepper(t, "Background").plus)
    click(ui.save)
    local m = QuietUICharDB.modernize
    A.type(m, "table")
    A.eq(m.enabled, true)
    A.eq(m.zz_beta, nil)
    A.eq(m.zz_b, false, "unchecked area saved under its key without Setup changes")
    A.ok(m.zz_a == nil or m.zz_a == true)
    A.eq(m.classColors, false)
    A.eq(m.opacity, 90)
    A.eq(ns.Settings.Modernize(), true)
    A.eq(ns.Settings.ModernArea("zz_b"), false)
    A.eq(ns.Settings.ModernArea("zz_a"), true)
end)

h.test("the tab shows the saved values after reopening", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t, { modernize = { enabled = true, opacity = 50, zz_a = false, classColors = false } })
    A.ok(checked(check(t, "Modernize")))
    A.ok(stepper(t, "Background").value._text:find("50", 1, true))
    A.falsy(checked(check(t, "Zz alpha")))
    A.falsy(checked(check(t, "Class colours")))
    A.ok(check(t, "Zz alpha"):IsVisible(), "options visible while Modernize is on")
end)

h.test("saving with Modernize unchecked turns it off and keeps the other values", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t, { modernize = { enabled = true, opacity = 90 } })
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(ns.Settings.Modernize(), false)
    A.eq(QuietUICharDB.modernize and QuietUICharDB.modernize.enabled, nil)
end)

h.test("Reset default clears modernize, turns Modernize off and keeps windowPoints", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t, { modernize = { enabled = true, opacity = 90 },
        windowPoints = { CharacterFrame = { "CENTER", "CENTER", 1, 2 } } })
    click(ui.reset)
    A.eq(QuietUICharDB.modernize, nil)
    A.eq(ns.Settings.Modernize(), false)
    A.falsy(checked(check(t, "Modernize")), "the tab shows Modernize off")
    A.deep(QuietUICharDB.windowPoints, { CharacterFrame = { "CENTER", "CENTER", 1, 2 } })
end)

h.test("a preset saved with Modernize on brings the same modernize table on another character", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t)
    click(check(t, "Modernize"))
    click(check(t, "Zz alpha"))
    click(ui.save)
    local saved = ns.Copy(QuietUICharDB.modernize)
    local id = ns.Settings.SavePreset(nil, "Modern", ns.Layout.CurrentRef(), QuietUICharDB)
    QuietUICharDB = {}
    ns.Settings.ActivatePreset(id)
    A.deep(QuietUICharDB.modernize, saved)
    A.eq(ns.Settings.Modernize(), true)
    A.eq(ns.Settings.ModernArea("zz_a"), false)
end)
