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
