-- Quest mobs setting: accessor, shared preset key, Misc. tab layout and info text, draft handling.
local h = ...

local function click(button)
    if not (button and type(button._scripts.OnClick) == "function") then error("Required control is missing", 0) end
    button._scripts.OnClick(button)
end

-- Records what ApplyAll sees when Setup commits: the Quest mobs setting and the stored value.
local function boot(t)
    t.boot()
    t.ns.CurrentLayoutRef = function() return { layoutName = "Original", layoutType = 1 } end
    local applied = {}
    t.ns.ApplyAll = function()
        applied[#applied + 1] = { enabled = t.ns.Settings.QuestMobs(), saved = QuietUICharDB.questMobs }
    end
    return applied
end

local function label(widget) return widget.label and widget.label._text end

-- The Misc. checkbox: a page child labelled "Quest mobs" with a box (the section heading has no box).
local function choice(ui)
    local found
    for _, child in ipairs(ui.pages[6]._children) do
        if child.box and label(child) == "Quest mobs" then
            if found then error("Misc. must have exactly one Quest mobs checkbox", 0) end
            found = child
        end
    end
    if not found then error("Misc. Quest mobs checkbox is missing", 0) end
    return found
end
local function checked(ui) return choice(ui).box._checked == true end
local function heading(ui, text)
    for _, child in ipairs(ui.pages[6]._children) do
        if child._kind == "Frame" and not child.box and label(child) == text then return child end
    end
    error("Misc. has no " .. text .. " section", 0)
end

-- Resolves a TOPLEFT offset relative to the page, following anchors to sibling widgets.
local function offset(widget, page, depth)
    depth = depth or 0
    if depth >= 10 then error("Anchor chain too deep", 0) end
    local point = widget._points[1]
    if not point then error("Widget has no anchor", 0) end
    local rel, relPoint, x, y = point[2], point[3] or point[1], point[4] or 0, point[5] or 0
    if type(rel) ~= "table" then
        rel, relPoint, x, y = widget._parent, point[1], point[2] or 0, point[3] or 0
    end
    if rel == page then return x, y end
    local rx, ry = offset(rel, page, depth + 1)
    if type(relPoint) == "string" and relPoint:find("RIGHT") then rx = rx + (rel._w or 0) end
    if type(relPoint) == "string" and relPoint:find("BOTTOM") then ry = ry - (rel._h or 0) end
    return rx + x, ry + y
end

local function tooltip(mock, help)
    GameTooltip._lines = {}
    if help and help._scripts.OnEnter then help._scripts.OnEnter(help) end
    return table.concat(GameTooltip._lines, "\n")
end

local function texts(object, out)
    out = out or {}
    if type(object._text) == "string" and object._text ~= "" then out[#out + 1] = object._text end
    for _, child in ipairs(object._children) do texts(child, out) end
    for _, region in ipairs(object._regions) do texts(region, out) end
    return out
end

h.test("Clean profile reads on and only explicit false turns it off", function(t)
    local ns, A = t.ns, t.assert
    A.eq(ns.Settings.QuestMobs(), true, "Missing questMobs must default on")
    for _, value in ipairs({ true, 0, "off" }) do
        QuietUICharDB.questMobs = value
        A.eq(ns.Settings.QuestMobs(), true, "Only false may disable quest mob icons")
    end
    QuietUICharDB.questMobs = false
    A.eq(ns.Settings.QuestMobs(), false, "Personal false must disable quest mob icons")
end)

h.test("questMobs is a shared preset key", function(t)
    local ns, A = t.ns, t.assert
    t.boot()
    ns.CurrentLayoutRef = function() return { layoutName = "Original", layoutType = 1 } end
    local copy = ns.Settings.CopySettings({ questMobs = false, unrelated = "ignore" })
    A.eq(copy.questMobs, false, "CopySettings must keep questMobs = false")
    local target = { questMobs = false }
    ns.Settings.CopySettings({}, target)
    A.eq(target.questMobs, nil, "Omitted questMobs must clear a stale false")
    local id = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questMobs = false })
    A.eq(ns.Settings.Presets()[id].settings.questMobs, false, "Preset creation must preserve questMobs = false")
    ns.Settings.ActivatePreset(id)
    A.ok(QuietUICharDB.questMobs == false and ns.Settings.QuestMobs() == false, "Activating an off preset must turn icons off")
    ns.Settings.Presets()[id].settings.questMobs = nil
    QuietUICharDB.questMobs = false
    A.eq(ns.Settings.QuestMobs(), true, "Accessor must read the active preset, not the personal snapshot")
end)

h.test("Misc. shows Quest mobs checked under Highlights with an English info text", function(t)
    local ns, A = t.ns, t.assert
    boot(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local page = ui.pages[6]
    A.ok(label(ui.tabs[6]) == "Misc." and #ui.tabs == 7, "Misc. stays the sixth of seven tabs")
    local box = choice(ui)
    A.eq(box._parent, page, "Quest mobs belongs on Misc.")
    A.ok(checked(ui), "Clean profile must paint Quest mobs checked")
    local section = heading(ui, "Quest mobs")
    local _, sectionY = offset(section, page)
    local _, boxY = offset(box, page)
    local _, highlightY = offset(heading(ui, "Highlights"), page)
    A.ok(-sectionY > -highlightY, "Quest mobs section must sit below the Highlights heading")
    for _, key in ipairs({ "highlightHerb", "highlightOre", "highlightQuest" }) do
        local widget = ui[key]
        A.ok(widget, "Highlights choice " .. key .. " must remain")
        local _, y = offset(widget, page)
        A.ok(-sectionY >= -y + widget._h, "Quest mobs section must sit below the Highlights choices")
    end
    A.ok(-boxY >= -sectionY + section._h, "Quest mobs checkbox sits under its heading")
    A.ok(-boxY + box._h <= page._h, "Quest mobs checkbox must fit inside the Misc. page height")
    local all = (tooltip(t.mock, section.help) .. "\n" .. table.concat(texts(page), "\n")):lower()
    A.ok(all:find("exclamation", 1, true), "Info must mention the exclamation mark for kill mobs")
    A.ok(all:find("pouch", 1, true), "Info must mention the pouch for mobs that drop a quest item")
    A.ok(all:find("attack", 1, true), "Info must say only attackable mobs are marked")
    A.ok(all:find("complete", 1, true), "Info must say the icon disappears once the objective is complete")
end)

h.test("Setup keeps one height on every tab and fits the tallest page", function(t)
    local ns, A = t.ns, t.assert
    boot(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    choice(ui)
    local height = ui._h
    A.ok(height <= 474, "Setup must stay compact")
    local tallest = 0
    for _, page in ipairs(ui.pages) do if page._h > tallest then tallest = page._h end end
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        A.eq(ui._h, height, "Tab switch must not resize setup")
        A.ok(ui.pages[index]._shown, "Selected tab must show its page")
        for other, page in ipairs(ui.pages) do
            A.eq(page._shown, index == other, "Only selected page may be shown")
        end
    end
    A.ok(ui.pages[6]._h <= tallest, "Misc. may not exceed the tallest tab")
end)

h.test("Unchecking is a draft; X and Escape discard it", function(t)
    local ns, A = t.ns, t.assert
    local applied = boot(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(choice(ui))
    A.falsy(checked(ui), "Click must paint an off draft")
    A.ok(QuietUICharDB.questMobs == nil and ns.Settings.QuestMobs() == true, "Unsaved draft must not change the setting")
    A.eq(#applied, 0, "Draft must not apply live changes")
    ui:Hide(); ns.Setup.Show()
    A.ok(checked(ui) and QuietUICharDB.questMobs == nil, "Closing must discard the off draft")
    QuietUICharDB.questMobs = false
    ui:Hide(); ns.Setup.Show()
    A.falsy(checked(ui), "Setup paints stored off")
    click(choice(ui))
    ui:Hide(); ns.Setup.Show()
    A.ok(QuietUICharDB.questMobs == false and not checked(ui), "Closing must keep the stored off value")
    A.eq(#applied, 0, "Closing must not apply")
    A.contains(UISpecialFrames, "QuietUISetup", "Escape must close the same setup frame and discard drafts")
end)

h.test("Save stores false only when off, nothing when on, and applies", function(t)
    local ns, A = t.ns, t.assert
    local applied = boot(t)
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.save)
    A.eq(QuietUICharDB.questMobs, nil, "Save while on must not store questMobs")
    A.ok(#applied == 1 and applied[1].enabled == true, "Save applies the on state")
    click(choice(ui)); click(ui.save)
    A.ok(QuietUICharDB.questMobs == false and ns.Settings.QuestMobs() == false, "Save off must persist explicit false")
    A.ok(#applied == 2 and applied[2].enabled == false and applied[2].saved == false,
        "Save off must call ApplyAll after committing the setting")
    A.ok(ui:IsShown() and not checked(ui), "Save keeps setup open and paints saved off")
    click(choice(ui)); click(ui.save)
    A.ok(QuietUICharDB.questMobs == nil and ns.Settings.QuestMobs() == true, "Save on must omit the default")
    A.ok(#applied == 3 and applied[3].enabled == true and applied[3].saved == nil, "Save on applies")
end)

h.test("Save with an active preset writes into the preset; switching picks up its value", function(t)
    local ns, A = t.ns, t.assert
    boot(t)
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questMobs = false })
    local on = ns.Settings.SavePreset(nil, "On", ns.CurrentLayoutRef(), {})
    ns.Settings.ActivatePreset(off); ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.falsy(checked(ui), "Selecting an off preset must paint unchecked")
    click(choice(ui)); click(ui.save)
    A.ok(ns.Settings.Presets()[off].settings.questMobs == nil and ns.Settings.QuestMobs() == true, "Save on must clear preset false")
    click(choice(ui)); click(ui.save)
    A.ok(ns.Settings.Presets()[off].settings.questMobs == false and ns.Settings.QuestMobs() == false, "Save off must update the preset")
    ns.Settings.ActivatePreset(on); ns.Setup.Show()
    A.ok(checked(ui) and ns.Settings.QuestMobs() == true and QuietUICharDB.questMobs == nil, "Switching to on preset reads on")
    ns.Settings.ActivatePreset(off); ns.Setup.Show()
    A.ok(not checked(ui) and ns.Settings.QuestMobs() == false, "Switching back reads the preset off value")
    ns.Settings.ActivatePreset(nil)
    A.ok(QuietUICharDB.questMobs == false and ns.Settings.QuestMobs() == false, "Detach keeps the last snapshot")
end)

h.test("Preset selector is a draft; saving the selection applies its questMobs", function(t)
    local ns, A = t.ns, t.assert
    local applied = boot(t)
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questMobs = false })
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    choice(ui)
    click(ui.presetSelector); click(ui.presetMenu.items[2])
    A.ok(not checked(ui) and ns.Settings.QuestMobs() == true, "Preset draft must paint off without applying it")
    A.ok(QuietUICharDB.presetId == nil and #applied == 0, "Preset choice must stay unsaved")
    ui:Hide(); ns.Setup.Show()
    A.ok(checked(ui), "Closing discards the preset draft")
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    A.ok(QuietUICharDB.presetId == off and ns.Settings.QuestMobs() == false, "Saving the preset selection applies off")
    A.ok(#applied == 1 and applied[1].enabled == false, "Preset Save applies the committed state")
end)

h.test("Reset turns Quest mobs on, saves, and leaves the shared preset unchanged", function(t)
    local ns, A = t.ns, t.assert
    local applied = boot(t)
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questMobs = false })
    ns.Settings.ActivatePreset(off); ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.falsy(checked(ui), "Preset off must paint")
    click(ui.reset)
    A.ok(QuietUICharDB.presetId == nil and QuietUICharDB.questMobs == nil and ns.Settings.QuestMobs() == true,
        "Reset must detach and save default on")
    A.ok(checked(ui) and ui:IsShown(), "Reset paints on and leaves setup open")
    A.eq(ns.Settings.Presets()[off].settings.questMobs, false, "Reset must not mutate the shared preset")
    A.ok(#applied == 1 and applied[1].enabled == true, "Reset applies immediately")
end)
