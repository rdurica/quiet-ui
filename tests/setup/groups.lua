-- Compact eight-tab setup: Groups tab, visibility modes, membership, scrolling and reset.
local h = ...

local function click(b) b._scripts.OnClick(b) end

local function fixture(t)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = { chatFade = 20 }
    ns.ApplyAll = function() end
    ns.Layout.CurrentRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.Layout.Choices = function() return { { name = "Other", ref = { layoutName = "Other", layoutType = 1 } } } end
    ns.Layout.Preview = function() end
    ns.Layout.CommitPreview = function() end
    ns.Layout.CancelPreview = function() end
    local id = ns.Settings.SavePreset(nil, "Healer", ns.Layout.CurrentRef(), { chat = false, chatFade = 0, groupAuras = false,
        player = "resource", requireLivingTarget = true, visible = { bars = true, swing = true },
        groups = { ["1"] = 2 }, hostile = { ["1"] = true }, friendly = { ["2"] = true },
        range = { yards = "spell", kind = "friendly", spell = "Heal" } })
    ns.Settings.ActivatePreset(id)
    ns.Setup.Show()
    return t.mock:findByName("QuietUISetup"), id
end

h.test("setup is compact with eight tabs; group visibility lives on Groups and Bars is not on Visible", function(t)
    local ns, A = t.ns, t.assert
    local ui = fixture(t)
    A.ok(ui:GetWidth() >= 592 and ui:GetWidth() <= 636 and ui:GetHeight() <= 474, "Setup is not compact")
    A.ok(#ui.tabs == 8 and ui.pages[4].id == "groups", "Groups tab is missing")
    A.ok(ui.visibilityHeader:GetParent() == ui.pages[4] and ui.groupRows[1]:GetParent() == ui.pages[3],
        "Group visibility did not move out of Bars")
    A.ok(ui.presetSelector:GetWidth() == ui.pages[1]:GetWidth() and ui.layoutSelector:GetWidth() == ui.pages[1]:GetWidth(),
        "General selectors do not use the content width")
    for _, row in ipairs(ui.rows) do
        A.ok(row.key ~= "bars" and row.key ~= "swing", "Bars still appear on Visible")
    end
    local group = ui.visibilityRows[1]
    A.ok(group.members._text:find("Bar 2") and group.members._text:find("Stance bar"))
end)

h.test("group modes: hover/always exclusion, cancel, save into preset, membership and bar groups", function(t)
    local ns, A = t.ns, t.assert
    local ui, id = fixture(t)
    local first = ui.groupRows[1]
    click(ui.visibilityRows[2].hover)
    A.ok(not first.hostile:IsEnabled() and not first.friendly:IsEnabled())
    A.ok(ui.visibilityRows[2].hover.box._checked and not ui.visibilityRows[2].always.box._checked)
    ui:Hide(); ns.Setup.Show()
    A.ok(ui.visibilityRows[2].always.box._checked, "Cancel saved a hover mode")
    click(ui.visibilityRows[2].hover); click(ui.save)
    A.eq(ns.Settings.Presets()[id].settings.groupVisibility[2], "hover")
    click(ui.visibilityRows[3].always)
    click(first.plus)
    A.ok(ui.visibilityRows[3].members._text:find("Bar 1"), "Group membership did not refresh")
    A.ok(first.hostile:IsEnabled(), "Moved bar retained old group control")
    click(ui.save)
    A.eq(QuietUICharDB.groups["1"], 3)
end)

h.test("Visible rows: XP defaults to hover, modes are mutually exclusive and stored as hoverOnly", function(t)
    local ns, A = t.ns, t.assert
    local ui = fixture(t)
    local visible = ui.rows[1]
    A.ok(visible.hover.box._checked, "XP must default to Only on hover")
    click(visible.hover)
    click(visible.hover)
    A.ok(visible.hover.box._checked and not visible.always.box._checked)
    click(visible.always)
    A.ok(visible.always.box._checked and not visible.hover.box._checked)
    click(visible.hover); click(ui.save)
    A.ok(QuietUICharDB.hoverOnly.xp and (not QuietUICharDB.visible or not QuietUICharDB.visible.xp))
end)

h.test("every group is reachable, regrouping clamps scroll, Reset leaves shared modes alone", function(t)
    local ns, A = t.ns, t.assert
    local ui, id = fixture(t)
    click(ui.visibilityRows[2].hover); click(ui.save)
    for index, row in ipairs(ui.groupRows) do
        for _ = 1, 12 do click(row.plus) end
        for _ = index + 1, 12 do click(row.minus) end
    end
    ui.groupScroll._scripts.OnMouseWheel(nil, -100)
    A.eq(ui.groupScroll:GetVerticalScroll(), 12 * 44 - 264, "Last groups cannot be reached")
    for _, row in ipairs(ui.groupRows) do
        for _ = 1, 12 do click(row.minus) end
    end
    A.ok(ui.groupScroll:GetVerticalScroll() == 0 and ui.visibilityRows[1]:IsShown()
        and not ui.visibilityRows[2]:IsShown())
    ui:Hide(); ns.Setup.Show()
    click(ui.reset)
    A.ok(not QuietUICharDB.groupVisibility and not QuietUICharDB.hoverOnly and ns.Settings.OnlyOnHover("xp"))
    A.eq(ns.Settings.Presets()[id].settings.groupVisibility[2], "hover", "Reset changed shared modes")
end)
