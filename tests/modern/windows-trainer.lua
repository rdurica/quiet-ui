-- The trainer of the Forever UI source (ClassTrainerFrame, Blizzard_TrainerUI): ButtonFrameTemplate with a keyed BG
-- and the named ClassTrainerFrameMoneyBg, ClassTrainerStatusBar (named Left / Right / Middle / Background and a bar
-- texture), a FilterDropdown, and a pooled list of category headers (Left / Right / CenterPiece, CollapseIcon with a
-- Professions-recipe-header-expand / -collapse atlas) and skill rows (icon, selectedTex, NormalTexture).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")

local function category(c, target, collapsed)
    local header = CreateFrame("Button", nil, target)
    for _, key in ipairs({ "LeftPiece", "RightPiece", "CenterPiece" }) do
        header[key] = P.texture(c, header, "art", "Professions-recipe-header-" .. key, "BACKGROUND", { atlas = true })
    end
    header.CollapseIcon = P.texture(c, header, "art", collapsed and "Professions-recipe-header-expand"
        or "Professions-recipe-header-collapse", "ARTWORK", { atlas = true })
    header.Label = P.text(c, header, "Fire")
    return header
end

local function skill(c, target)
    local row = CreateFrame("Button", nil, target)
    row.icon = P.texture(c, row, "keep", "Icons\\Spell_Fire_Fireball", "OVERLAY")
    row.icon:SetTexCoord(0, 1, 0, 1)
    row.selectedTex = P.texture(c, row, "keep", "TrainerTextures-Selected", "OVERLAY")
    P.buttonArt(c, row, { GetNormalTexture = "TrainerTextures-Normal" }, "art")
    row.name = P.text(c, row, "Fireball (Rank 2)")
    return row
end

local function trainer()
    local c = P.new()
    local frame = P.window(c, "ClassTrainerFrame")
    frame.BG = P.texture(c, frame, "art", "TrainerTextures", "BACKGROUND")
    P.texture(c, frame, "art", "UI-MoneyFrame-Border", "ARTWORK", { name = "ClassTrainerFrameMoneyBg" })
    local bar = CreateFrame("StatusBar", "ClassTrainerStatusBar", frame)
    for _, key in ipairs({ "Left", "Right", "Middle", "Background" }) do
        P.texture(c, bar, "art", "GuildFrame-" .. key, "ARTWORK", { name = "ClassTrainerStatusBar" .. key })
    end
    c.fill = P.texture(c, bar, "keep", "UI-Character-Skills-Bar", "ARTWORK")
    frame.FilterDropdown = P.dropdown(c, frame)
    local box = P.scrollBox(frame)
    c.header = category(c, box.ScrollTarget, false)
    c.skill = skill(c, box.ScrollTarget)
    c.frame, c.box, c.bar = frame, box, bar
    return c
end

h.test("Windows gives the trainer section strips and bare skill rows, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = trainer()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.ok(W.isDark(c.frame), "the trainer is a dark window")
    A.eq(P.visibleArt(c, R, c.frame), "", "background, money border, bar pieces, header and row art are held")
    A.eq(P.hiddenKeep(c, R, c.frame), "", "icons, selection, names and the bar fill stay")
    A.ok(W.isDark(c.bar), "the skill bar sits on a flat track")
    A.ok(L.zoomed(c.skill.icon), "a skill icon is square-cropped")
    local accent = ns.Modern.Theme().accent
    local strip
    for _, region in ipairs(c.header._regions) do
        if region._color and region._color[1] == accent[1] and region._color[2] == accent[2] then strip = true end
    end
    A.ok(strip, "a category header is a section strip with an accent mark")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the trainer restores exactly")
end)

h.test("Windows skins a trainer row the list adds after the window was skinned", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = trainer()
    W.enable(ns)
    local late = P.new()
    local header = category(late, c.box.ScrollTarget, true)
    local row = skill(late, c.box.ScrollTarget)
    c.box:Update()
    A.eq(P.visibleArt(late, R, c.frame), "", "the new header and row lose their art")
    A.ok(L.zoomed(row.icon) and header ~= nil, "the new skill icon is cropped")
end)
