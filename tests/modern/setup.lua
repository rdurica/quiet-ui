-- Modern tab of the setup window: tab order, the Modernize checkbox on the Modules tab, the options from the
-- registry, drafts, Save, presets and Reset default.
local h = ...
local L = h.lib("modern")

local function click(b) b._scripts.OnClick(b) end

-- Opens the Modern tab. The tab is only listed while Modernize is on, so a stored table decides that.
local function fixture(t, stored)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = stored or { modules = { modernize = true } }
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

local function tabIndex(ui, id)
    for i, tab in ipairs(ui.tabs) do
        if tab.id == id then return i end
    end
end

local function inside(frame, page)
    local p = frame
    while p do
        if p == page then return true end
        p = p._parent
    end
    return false
end

h.test("Modules is the first tab and Modern sits between Helpers and Info", function(t)
    local A = t.assert
    local ui = fixture(t)
    A.eq(ui.tabs[1].id, "modules")
    local helpers, modern, info = tabIndex(ui, "helpers"), tabIndex(ui, "modern"), tabIndex(ui, "info")
    A.ok(helpers and modern and info, "helpers, modern and info tabs")
    A.eq(modern, helpers + 1, "Modern follows Helpers")
    A.eq(info, modern + 1, "Info follows Modern")
    A.eq(ui.tabs[modern].label._text, "Modern")
    A.eq(ui.pages[modern].id, "modern")
    A.eq(tabIndex(ui, "misc"), nil, "no Misc. tab")
end)

h.test("the Modernize checkbox lives on the Modules tab, unchecked by default, and not on the Modern tab", function(t)
    local A = t.assert
    local ui = fixture(t, {})
    local modules, modern = ui.pages[tabIndex(ui, "modules")], ui.pages[tabIndex(ui, "modern")]
    local boxes = 0
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "Button" and f.box and f.label and f.label._text == "Modernize" then
            boxes = boxes + 1
            A.ok(inside(f, modules), "checkbox sits on the Modules page")
            A.falsy(inside(f, modern), "checkbox is not on the Modern page")
        end
    end
    A.eq(boxes, 1, "exactly one Modernize checkbox")
    A.falsy(checked(check(t, "Modernize")), "off by default")
end)

h.test("with Modernize on the Modern tab shows the theme and every area, enabled, with no class colours option", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t)
    A.ok(ui.tabs[tabIndex(ui, "modern")]:IsVisible(), "Modern tab listed")
    A.ok(checked(check(t, "Modernize")))
    local theme = stepper(t, "Theme")
    A.ok(theme:IsVisible() and theme:IsEnabled(), "theme always enabled on the page")
    A.ok(theme.value._text:lower():find("dark", 1, true), "theme shows Dark, got " .. tostring(theme.value._text))
    A.eq(stepper(t, "Background"), nil, "no Background option")
    A.eq(check(t, "Class colours"), nil, "no Class colours option")
    for _, area in ipairs(ns.Modern.Areas()) do
        local box = check(t, area.label)
        A.ok(box, "checkbox for " .. area.key)
        A.ok(box:IsVisible() and box:IsEnabled() and checked(box), area.key .. " visible, enabled and on")
    end
end)

h.test("checking Modernize in the draft lists the Modern tab and unchecking it hides the tab at once", function(t)
    local A = t.assert
    local ui = fixture(t, {})
    local tab = ui.tabs[tabIndex(ui, "modern")]
    A.falsy(tab:IsVisible(), "no Modern tab while Modernize is off")
    click(check(t, "Modernize"))
    A.ok(tab:IsVisible(), "Modern tab listed once checked")
    click(check(t, "Modernize"))
    A.falsy(tab:IsVisible(), "Modern tab gone once unchecked")
end)

h.test("area checkboxes follow ns.Modern.Areas() in order and label", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t)
    -- The XP area heads its own section; the others fill the Areas column.
    local list = {}
    for _, area in ipairs(ns.Modern.Areas()) do
        if area.key ~= "status" then list[#list + 1] = area end
    end
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

local function section(t, text)
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "FontString" and f._text == text then return f end
    end
end

h.test("the XP and reputation section holds the Modern XP bar and Show on big XP gain, on by default", function(t)
    local A = t.assert
    fixture(t)
    A.ok(section(t, "XP and reputation"), "XP and reputation section")
    local area, gain = check(t, "Modern XP bar"), check(t, "Show on big XP gain")
    A.ok(area and area:IsVisible() and checked(area), "Modern XP bar on")
    A.ok(gain and gain:IsVisible() and checked(gain), "Show on big XP gain on")
    local _, _, _, areaX, areaY = area:GetPoint(1)
    local _, _, _, gainX, gainY = gain:GetPoint(1)
    A.eq(areaX, 0, "left column"); A.eq(gainX, 0, "left column")
    A.ok(gainY < areaY, "Show on big XP gain sits under Modern XP bar")
end)

h.test("Show on big XP gain is disabled while Modern XP bar is off and saves false only when unchecked", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t)
    click(check(t, "Modern XP bar"))
    A.falsy(check(t, "Show on big XP gain"):IsEnabled(), "disabled without the XP area")
    click(check(t, "Modern XP bar"))
    A.ok(check(t, "Show on big XP gain"):IsEnabled(), "enabled again")
    click(ui.save)
    A.eq(QuietUICharDB.modernize.xpGain, nil, "the default is not stored")
    A.ok(ns.Settings.ModernXPGain())
    click(check(t, "Show on big XP gain"))
    click(ui.save)
    A.eq(QuietUICharDB.modernize.xpGain, false)
    A.falsy(ns.Settings.ModernXPGain())
end)

h.test("turning Modernize off and on again in the draft keeps the area values", function(t)
    local A = t.assert
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t)
    click(check(t, "Zz alpha"))
    click(check(t, "Modernize"))
    click(check(t, "Modernize"))
    A.falsy(checked(check(t, "Zz alpha")), "area stays unchecked")
end)

h.test("nothing is stored until Save, closing discards the draft", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t, {})
    click(check(t, "Modernize"))
    A.eq(QuietUICharDB.modules, nil, "draft only")
    A.eq(QuietUICharDB.modernize, nil, "draft only")
    ui:Hide(); ns.Setup.Show()
    A.falsy(checked(check(t, "Modernize")), "closing discards")
end)

h.test("Save with Modernize on stores the module and the chosen options under their keys", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    L.area(t, "zz_b", { label = "Zz beta" })
    local ui = fixture(t, {})
    click(check(t, "Modernize"))
    click(check(t, "Zz beta"))
    click(ui.save)
    A.type(QuietUICharDB.modules, "table")
    A.eq(QuietUICharDB.modules.modernize, true)
    local m = QuietUICharDB.modernize
    A.type(m, "table")
    A.eq(m.enabled, nil, "no enabled key any more")
    A.eq(m.zz_beta, nil)
    A.eq(m.zz_b, false, "unchecked area saved under its key without Setup changes")
    A.ok(m.zz_a == nil or m.zz_a == true)
    A.eq(m.classColors, nil, "no class colours key")
    A.eq(m.opacity, nil, "no opacity key")
    A.eq(ns.Settings.Modernize(), true)
    A.eq(ns.Settings.ModernArea("zz_b"), false)
    A.eq(ns.Settings.ModernArea("zz_a"), true)
end)

h.test("the tab shows the saved values after reopening", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t, { modules = { modernize = true }, modernize = { zz_a = false } })
    A.ok(checked(check(t, "Modernize")))
    A.falsy(checked(check(t, "Zz alpha")))
    A.ok(check(t, "Zz alpha"):IsVisible(), "options visible while Modernize is on")
end)

h.test("saving with Modernize unchecked turns it off and keeps the other values", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t, { modules = { modernize = true }, modernize = { theme = "dark", zz_a = false } })
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(ns.Settings.Modernize(), false)
    A.eq(QuietUICharDB.modules and QuietUICharDB.modules.modernize, nil)
    A.eq(QuietUICharDB.modernize and QuietUICharDB.modernize.zz_a, false, "the area choice is kept")
end)

h.test("Reset default clears modernize, turns Modernize off and keeps windowPoints", function(t)
    local A, ns = t.assert, t.ns
    local ui = fixture(t, { modules = { modernize = true }, modernize = { theme = "dark" },
        windowPoints = { CharacterFrame = { "CENTER", "CENTER", 1, 2 } } })
    click(ui.reset)
    A.eq(QuietUICharDB.modernize, nil)
    A.eq(QuietUICharDB.modules, nil)
    A.eq(ns.Settings.Modernize(), false)
    A.falsy(checked(check(t, "Modernize")), "the tab shows Modernize off")
    A.deep(QuietUICharDB.windowPoints, { CharacterFrame = { "CENTER", "CENTER", 1, 2 } })
end)

h.test("a preset saved with Modernize on brings the same modernize table on another character", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a", { label = "Zz alpha" })
    local ui = fixture(t, {})
    click(check(t, "Modernize"))
    click(check(t, "Zz alpha"))
    click(ui.save)
    local saved = ns.Copy(QuietUICharDB.modernize)
    local id = ns.Settings.SavePreset(nil, "Modern", ns.Layout.CurrentRef(), QuietUICharDB)
    QuietUICharDB = {}
    ns.Settings.ActivatePreset(id)
    A.deep(QuietUICharDB.modernize, saved)
    A.deep(QuietUICharDB.modules, { modernize = true })
    A.eq(ns.Settings.Modernize(), true)
    A.eq(ns.Settings.ModernArea("zz_a"), false)
end)

h.test("saving Modernize on or off reloads the UI once; saving it again unchanged does not", function(t)
    local A = t.assert
    local reloads = 0
    ReloadUI = function() reloads = reloads + 1 end
    local ui = fixture(t, {})
    QuietUIDB.enabled = true
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(reloads, 1, "turning Modernize on reloads")
    click(ui.save)
    A.eq(reloads, 1, "saving while it is already on does not")
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(reloads, 2, "turning it off reloads")
    click(ui.save)
    A.eq(reloads, 2, "saving while it is already off does not")
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(reloads, 3, "turning it on again reloads")
end)

h.test("a Save that reloads leaves applying to the reload", function(t)
    local A, ns = t.assert, t.ns
    local applies = 0
    ReloadUI = function() end
    local ui = fixture(t, {})
    QuietUIDB.enabled = true
    ns.ApplyAll = function() applies = applies + 1 end
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(applies, 0, "nothing restyled in place before the reload")
    click(ui.save)
    A.eq(applies, 1, "a Save without a Modernize change applies")
end)

h.test("a new Modernize look saved in combat applies in place and asks for /reload", function(t)
    local A, ns = t.assert, t.ns
    local reloads, applies = 0, 0
    ReloadUI = function() reloads = reloads + 1 end
    local ui = fixture(t, { modules = { modernize = true }, modernize = { theme = "dark" } })
    QuietUIDB.enabled = true
    ns.ApplyAll = function() applies = applies + 1 end
    click(stepper(t, "Theme").plus)
    local was = InCombatLockdown
    InCombatLockdown = function() return true end
    local ok, err = pcall(click, ui.save)
    InCombatLockdown = was
    if not ok then error(err, 0) end
    A.eq(reloads, 0, "no reload can be armed in combat")
    A.eq(applies, 1, "applied in place")
    local said = false
    for _, line in ipairs(t.mock.printed) do
        if line:find("type /reload to finish the new look", 1, true) then said = true end
    end
    A.ok(said, "chat asks for /reload")
end)

h.test("saving Modernize on while QuietUI is off does not reload", function(t)
    local A = t.assert
    local reloads = 0
    ReloadUI = function() reloads = reloads + 1 end
    local ui = fixture(t, {})
    QuietUIDB.enabled = false
    click(check(t, "Modernize"))
    click(ui.save)
    A.eq(reloads, 0)
end)
