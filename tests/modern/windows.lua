-- Modern Windows: runtime variants, dark chrome, bags.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

local function fixture()
    local character = W.window("CharacterFrame")
    CharacterFrame = character
    CharacterFrameTab1 = W.tab(character, "CharacterFrameTab1")
    CharacterFrameReputationFrame = W.window("CharacterFrameReputationFrame")
    CharacterFrameCurrencyFrame = W.window("CharacterFrameCurrencyFrame")
    local spellbook = W.window("PlayerSpellsFrame")
    PlayerSpellsFrame = spellbook
    spellbook.pageArt = W.texture(spellbook, "SpellbookPageContent", 0.73)
    local talents = W.window("ClassTalentFrame")
    ClassTalentFrame = talents
    talents.treeArt = W.texture(talents, "TalentTreeContent", 0.74)
    local quest = W.window("QuestLogFrame")
    QuestLogFrame = quest
    local bag = W.window("ContainerFrame1")
    ContainerFrame1 = bag
    local combined = W.window("ContainerFrameCombinedBags")
    ContainerFrameCombinedBags = combined
    return { character = character, spellbook = spellbook, talents = talents, quest = quest, bag = bag,
        combined = combined }
end

h.test("Windows skins runtime frame-name variants, character tabs and bag windows while content art stays", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    local before = L.snapshot({ f.character, f.character.chrome, CharacterFrameTab1, CharacterFrameReputationFrame,
        CharacterFrameCurrencyFrame, f.spellbook, f.talents, f.quest, f.bag, f.combined })
    W.enable(ns)
    for _, frame in ipairs({ f.character, CharacterFrameTab1, CharacterFrameReputationFrame, CharacterFrameCurrencyFrame,
        f.spellbook, f.talents, f.quest, f.bag, f.combined }) do
        A.ok(W.isDark(frame), (frame:GetName() or "window") .. " gets a dark panel")
    end
    A.alpha(f.character.chrome, 0, "Blizzard character chrome held")
    A.alpha(f.spellbook.pageArt, 0.73, "spellbook page content remains")
    A.alpha(f.talents.treeArt, 0.74, "talent tree content remains")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "all chrome, points, colours, sizes and fonts restore exactly")
end)

h.test("Windows skins late spellbook and talent frames after their load-on-demand addons", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    CharacterFrame = W.window("CharacterFrame")
    W.enable(ns)
    local spellbook, talents = W.window("PlayerSpellsFrame"), W.window("ClassTalentFrame")
    PlayerSpellsFrame, ClassTalentFrame = spellbook, talents
    ns.Modern.AddonLoaded("Blizzard_PlayerSpells")
    ns.Modern.AddonLoaded("Blizzard_TalentUI")
    A.ok(W.isDark(spellbook), "late spellbook is skinned")
    A.ok(W.isDark(talents), "late talent window is skinned")
end)

h.test("Windows makes character, spellbook, talents, quest log and the combined bag movable; separate bags keep stacking", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    W.enable(ns)
    for _, frame in ipairs({ f.character, f.spellbook, f.talents, f.quest }) do
        A.ok(L.handle(frame), (frame:GetName() or "window") .. " has a title drag handle")
    end
    A.eq(L.handle(f.bag), nil, "separate bags keep Blizzard stacking")
    A.ok(L.handle(f.combined), "the combined bag has a title drag handle")
    L.drag(f.character, "CENTER", "CENTER", 8, 9)
    A.deep(QuietUICharDB.windowPoints.CharacterFrame, { "CENTER", "CENTER", 8, 9 })
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(W.point(f.character), { "TOPLEFT", "TOPLEFT", 31, -71 }, "area off restores Blizzard position")
    A.deep(QuietUICharDB.windowPoints.CharacterFrame, { "CENTER", "CENTER", 8, 9 }, "saved point remains")
end)

h.test("Windows skips absent variants without reporting and does not scan UIParent descendants", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local character = W.window("CharacterFrame")
    CharacterFrame = character
    UIParent.GetChildren = function() error("Windows must use named runtime frames, not a UIParent scan", 0) end
    W.enable(ns)
    A.ok(W.isDark(character), "available window still skins")
    A.eq(#mock.printed, 0, "missing variants are intentionally skipped")
end)

h.test("Top-level windows get a header band with a rule under the title row; nested panels do not", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    local strip = ns.Modern.Theme().strip
    local function band(frame)
        for _, region in ipairs(frame._regions) do
            if region._layer == "BACKGROUND" and region._shown and region._color and region._h == 23 then
                return true
            end
        end
        return false
    end
    W.enable(ns)
    for _, frame in ipairs({ f.character, f.spellbook, f.talents, f.quest, f.bag, f.combined }) do
        A.ok(band(frame), frame:GetName() .. " has a header band")
    end
    A.ok(not band(CharacterFrameReputationFrame), "a nested character pane has no header band")
    A.ok(strip[1] > 0.05, "the band is a step above the panel")
    ns.Modern.Restore()
    for _, frame in ipairs({ f.character, f.combined }) do
        A.ok(not band(frame), frame:GetName() .. " loses the band on Restore")
    end
end)

h.test("Top-level windows are lit graphite with a quiet outline, a gold hairline and a sunken inset", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    f.character.Inset = CreateFrame("Frame", nil, f.character)
    local theme = ns.Modern.Theme()
    local function regions(frame, test)
        local found = {}
        for _, region in ipairs(frame._regions) do
            if region._shown ~= false and test(region) then found[#found + 1] = region end
        end
        return found
    end
    local function gradients(frame, orientation)
        return regions(frame, function(r) return r._gradient and r._gradient[1] == orientation end)
    end
    W.enable(ns)
    A.ok(#regions(f.character, function(r)
        return r._gradient and r._gradient[2][1] == theme.bg[1] and r._gradient[3][1] > theme.bg[1]
    end) == 1, "the panel is graphite lit towards the top")
    A.ok(#regions(f.character, function(r) return r._h == 1 and r._color and r._color[1] == theme.accent[1] end) == 1,
        "a gold hairline sits under the title band")
    A.eq(#regions(f.character, function(r) return r._color and r._color[1] == theme.outline[1] end), 4,
        "the window has a quiet outline")
    A.eq(#gradients(f.character, "HORIZONTAL"), 0, "no shadow around the window")
    A.eq(#regions(f.character.Inset, function(r) return r._color and r._color[4] == theme.sunk[4] end), 1,
        "the inset sinks below the panel")
    ns.Modern.Restore()
    A.eq(#regions(f.character.Inset, function(r) return r._color ~= nil end), 0, "Restore lifts the inset")
end)

h.test("A window's maximize / minimize buttons take flat glyphs like the map's and restore their art", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    local sizing = CreateFrame("Frame", nil, f.spellbook)
    f.spellbook.MaximizeMinimizeButton = sizing
    local art = {}
    for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
        local button = CreateFrame("Button", nil, sizing)
        local normal = button:CreateTexture(nil, "ARTWORK")
        normal:SetAlpha(1)
        function button:GetNormalTexture() return normal end
        sizing[key] = button
        art[key] = normal
    end
    W.enable(ns)
    A.alpha(art.MaximizeButton, 0, "the red maximize art is held")
    A.alpha(art.MinimizeButton, 0, "the red minimize art is held")
    ns.Modern.Restore()
    A.alpha(art.MaximizeButton, 1, "Restore gives the maximize art back")
    A.alpha(art.MinimizeButton, 1, "and the minimize art")
end)
