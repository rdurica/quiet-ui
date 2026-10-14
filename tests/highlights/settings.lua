-- Highlights settings contracts: ns.Settings.Highlights accessor, the Misc. tab (draft, Save, Reset, presets).
local h = ...

local KEYS = { herb = "highlightHerb", ore = "highlightOre", quest = "highlightQuest" }
local LABELS = { herb = "Herbs", ore = "Ore", quest = "Interact objects" }

local function click(b) b._scripts.OnClick(b) end

-- Real addon; only the layout and apply seams are replaced by recorders.
local function fixture(t)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = {}
    local applied = {}
    ns.CurrentLayoutRef = function() return { layoutName = "Original", layoutType = 1 } end
    ns.LayoutChoices = function() return {} end
    ns.PreviewLayout = function() end
    ns.CommitLayoutPreview = function() end
    ns.CancelLayoutPreview = function() end
    ns.ApplyAll = function()
        applied[#applied + 1] = { highlights = ns.Settings.Highlights(), saved = ns.Copy(QuietUICharDB.highlights) }
    end
    return ns, applied
end

local function expect(t, herb, ore, quest, message)
    local value = t.ns.Settings.Highlights()
    t.assert.type(value, "table")
    t.assert.ok(value.herb == herb and value.ore == ore and value.quest == quest,
        string.format("%s (got herb=%s ore=%s quest=%s)", message, tostring(value.herb), tostring(value.ore),
            tostring(value.quest)))
end

local function choice(ui, key)
    local widget = ui[KEYS[key]]
    if not (widget and widget.box and widget.label) then error("Misc. " .. LABELS[key] .. " choice is missing", 0) end
    return widget
end
local function checked(ui, key) return choice(ui, key).box._checked == true end

local function stored(t, value, expected, message)
    if expected == nil then t.assert.eq(value, nil, message .. " (expected nil key)") return end
    t.assert.type(value, "table", message .. " (expected a table)")
    for key, flag in pairs(value) do
        t.assert.ok(flag == true and expected[key] == true, message .. " (unexpected key " .. tostring(key) .. ")")
    end
    for key in pairs(expected) do t.assert.ok(value[key] == true, message .. " (missing " .. key .. ")") end
end

-- Resolves a TOPLEFT offset relative to the page, following anchors to sibling widgets.
local function offset(widget, page, depth)
    depth = depth or 0
    if depth >= 10 then error("Anchor chain too deep", 0) end
    local point, rel, relPoint, x, y = widget:GetPoint(1)
    if not point then error("Widget has no anchor", 0) end
    if type(rel) ~= "table" then rel, relPoint, x, y = widget:GetParent(), point, rel or 0, relPoint or 0 end
    x, y = x or 0, y or 0
    if rel == page then return x, y end
    local rx, ry = offset(rel, page, depth + 1)
    if type(relPoint) == "string" and relPoint:find("RIGHT") then rx = rx + (rel:GetWidth() or 0) end
    return rx + x, ry + y
end

local function texts(object, out)
    out = out or {}
    if type(object._text) == "string" and object._text ~= "" then out[#out + 1] = object._text end
    for _, child in ipairs(object._children) do texts(child, out) end
    for _, region in ipairs(object._regions) do texts(region, out) end
    return out
end

local function header(ui)
    for _, child in ipairs(ui.pages[6]._children) do
        if child.label and child.label._text == "Highlights" then return child end
    end
    error("Misc. has no Highlights section", 0)
end

local function tooltip(t, help)
    GameTooltip:ClearLines()
    local enter = help and help._scripts.OnEnter
    if enter then enter(help) end
    return table.concat(GameTooltip._lines or {}, "\n")
end

h.test("Clean profile reads all three categories off", function(t)
    fixture(t)
    expect(t, false, false, false, "Missing highlights must mean all off")
    QuietUICharDB.highlights = {}
    expect(t, false, false, false, "Empty table must mean all off")
    QuietUICharDB.highlights = { ore = true }
    expect(t, false, true, false, "Only ore stored must read ore on")
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }
    expect(t, true, true, true, "All stored must read all on")
end)

h.test("Misc. shows Highlights below Quests with three unchecked choices on one row", function(t)
    local A = t.assert
    local ns = fixture(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local page = ui.pages[6]
    A.ok(ui.tabs[6].label._text == "Misc." and #ui.tabs == 7, "Misc. stays the sixth of seven tabs")
    local section = header(ui)
    local _, sectionY = offset(section, page)
    local _, sizeY = offset(ui.questNoticeSize, page)
    A.ok(-sectionY >= -sizeY + ui.questNoticeSize:GetHeight(), "Highlights must sit below the Quests controls")
    local previousX, rowY, previousWidth
    for _, key in ipairs({ "herb", "ore", "quest" }) do
        local widget = choice(ui, key)
        A.ok(widget:GetParent() == page, LABELS[key] .. " belongs on Misc.")
        A.eq(widget.label._text, LABELS[key], "Choice label must be " .. LABELS[key])
        A.ok(not widget.box._checked, LABELS[key] .. " must start unchecked")
        local x, y = offset(widget, page)
        A.ok(-y >= -sectionY + section:GetHeight(), LABELS[key] .. " sits under the Highlights heading")
        if rowY then
            A.eq(y, rowY, "Highlights choices must share one row")
            A.ok(x >= previousX + previousWidth, "Highlights choices must not overlap and go left to right")
        end
        previousX, rowY, previousWidth = x, y, widget:GetWidth()
    end
end)

h.test("Highlights info text is English and explains Interact and soft targeting", function(t)
    local A = t.assert
    local ns = fixture(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local all = tooltip(t, header(ui).help) .. "\n" .. table.concat(texts(ui.pages[6]), "\n")
    A.ok(all:find("Interact With Target", 1, true), "Info must name the Interact With Target binding")
    A.ok(all:find("Key Bindings", 1, true), "Info must point to Key Bindings")
    A.ok(all:lower():find("soft target", 1, true), "Info must mention soft targeting")
    A.ok(all:lower():find("glow", 1, true), "Info must say the object glows")
    A.ok(all:lower():find("restore", 1, true), "Info must say settings are restored when turned off")
end)

h.test("Misc. content fits and setup keeps one height on every tab", function(t)
    local A = t.assert
    local ns = fixture(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local page = ui.pages[6]
    for _, key in ipairs({ "herb", "ore", "quest" }) do
        local widget = choice(ui, key)
        local _, y = offset(widget, page)
        A.ok(-y + widget:GetHeight() <= page:GetHeight(), LABELS[key] .. " must fit inside the Misc. tab height")
    end
    local height = ui:GetHeight()
    local tallest = 0
    for _, other in ipairs(ui.pages) do if other:GetHeight() > tallest then tallest = other:GetHeight() end end
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        A.eq(ui:GetHeight(), height, "Tab switch must not resize setup")
        A.ok(ui.pages[index]:IsShown(), "Selected tab must show its page")
    end
    A.ok(page:GetHeight() <= tallest, "Misc. may not exceed the tallest tab")
end)

h.test("Toggling is a draft, Save stores only true keys and applies", function(t)
    local A = t.assert
    local ns, applied = fixture(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(choice(ui, "ore"))
    A.ok(checked(ui, "ore") and not checked(ui, "herb") and not checked(ui, "quest"), "Click paints only Ore")
    A.ok(QuietUICharDB.highlights == nil and #applied == 0, "Unsaved toggle must not store or apply")
    expect(t, false, false, false, "Unsaved toggle must not change live settings")
    click(ui.save)
    stored(t, QuietUICharDB.highlights, { ore = true }, "Save must store only ore=true")
    expect(t, false, true, false, "Saved ore must read on")
    A.ok(#applied == 1 and applied[1].highlights.ore == true, "Save must call ApplyAll after committing highlights")
    A.ok(ui:IsShown() and checked(ui, "ore"), "Save keeps setup open and paints saved state")
    click(choice(ui, "herb")); click(choice(ui, "quest")); click(ui.save)
    stored(t, QuietUICharDB.highlights, { herb = true, ore = true, quest = true }, "Save must store all three")
    expect(t, true, true, true, "All saved must read on")
    click(choice(ui, "herb")); click(choice(ui, "ore")); click(choice(ui, "quest")); click(ui.save)
    A.eq(QuietUICharDB.highlights, nil, "All off must clear the key instead of storing an empty table")
    expect(t, false, false, false, "All off must read off")
    A.eq(#applied, 3, "Each Save applies")
end)

h.test("X and Escape discard unsaved highlight changes", function(t)
    local A = t.assert
    local ns, applied = fixture(t)
    QuietUICharDB.highlights = { herb = true }
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.ok(checked(ui, "herb") and not checked(ui, "ore"), "Setup paints stored highlights")
    click(choice(ui, "herb")); click(choice(ui, "ore"))
    ui:Hide(); ns.Setup.Show()
    A.ok(checked(ui, "herb") and not checked(ui, "ore") and not checked(ui, "quest"), "Closing must discard drafts")
    stored(t, QuietUICharDB.highlights, { herb = true }, "Closing must keep stored highlights")
    A.eq(#applied, 0, "Closing must not apply")
    local escapeRegistered = false
    for _, name in ipairs(UISpecialFrames) do if name == "QuietUISetup" then escapeRegistered = true end end
    A.ok(escapeRegistered, "Escape must close the same setup frame and discard drafts")
end)

h.test("Reset default clears highlights and leaves the shared preset unchanged", function(t)
    local A = t.assert
    local ns, applied = fixture(t)
    local id = ns.Settings.SavePreset(nil, "Gather", ns.CurrentLayoutRef(), { highlights = { ore = true, quest = true } })
    ns.Settings.ActivatePreset(id); ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.ok(checked(ui, "ore") and checked(ui, "quest"), "Preset highlights must paint")
    click(ui.reset)
    A.ok(QuietUICharDB.presetId == nil and QuietUICharDB.highlights == nil, "Reset must detach and clear highlights")
    expect(t, false, false, false, "Reset must turn every category off")
    A.ok(not checked(ui, "herb") and not checked(ui, "ore") and not checked(ui, "quest"), "Reset paints all off")
    stored(t, ns.Settings.Presets()[id].settings.highlights, { ore = true, quest = true }, "Reset must not mutate shared preset")
    A.eq(#applied, 1, "Reset applies immediately")
end)

h.test("Presets copy, share and snapshot highlights", function(t)
    local A = t.assert
    local ns = fixture(t)
    local copy = ns.Settings.CopySettings({ highlights = { herb = true }, unrelated = 1 })
    stored(t, copy.highlights, { herb = true }, "CopySettings must copy highlights")
    local source = { highlights = { ore = true } }
    local deep = ns.Settings.CopySettings(source)
    deep.highlights.herb = true
    A.eq(source.highlights.herb, nil, "CopySettings must deep-copy highlights")
    local target = { highlights = { quest = true } }
    ns.Settings.CopySettings({}, target)
    A.eq(target.highlights, nil, "Omitted highlights must clear a stale value")
    local id = ns.Settings.SavePreset(nil, "Herbs", ns.CurrentLayoutRef(), { highlights = { herb = true } })
    stored(t, ns.Settings.Presets()[id].settings.highlights, { herb = true }, "Preset creation must keep highlights")
    ns.Settings.ActivatePreset(id)
    stored(t, ns.Settings.Effective().highlights, { herb = true }, "Active preset settings must expose highlights")
    stored(t, QuietUICharDB.highlights, { herb = true }, "Activation must snapshot highlights")
    expect(t, true, false, false, "Accessor reads effective preset settings")
    ns.Settings.Presets()[id].settings.highlights = { quest = true }
    QuietUICharDB.highlights = nil
    expect(t, false, false, true, "Accessor must read the active preset, not the snapshot")
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(choice(ui, "ore")); click(ui.save)
    stored(t, ns.Settings.Presets()[id].settings.highlights, { ore = true, quest = true }, "Save must update the active preset")
    ns.Settings.ActivatePreset(nil)
    stored(t, QuietUICharDB.highlights, { ore = true, quest = true }, "Detach keeps the last snapshot")
    expect(t, false, true, true, "Detached accessor reads personal snapshot")
end)
