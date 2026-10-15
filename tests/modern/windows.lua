-- Modern Windows: runtime variants, dark chrome, bags and the branch-008 parchment behaviour.
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

h.test("Windows makes character, spellbook, talents and quest log movable but keeps Blizzard bag stacking", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    W.enable(ns)
    for _, frame in ipairs({ f.character, f.spellbook, f.talents, f.quest }) do
        A.ok(L.handle(frame), (frame:GetName() or "window") .. " has a title drag handle")
    end
    A.eq(L.handle(f.bag), nil, "bags keep Blizzard stacking")
    L.drag(f.character, "CENTER", "CENTER", 8, 9)
    A.deep(QuietUICharDB.windowPoints.CharacterFrame, { "CENTER", "CENTER", 8, 9 })
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(W.point(f.character), { "TOPLEFT", "TOPLEFT", 31, -71 }, "area off restores Blizzard position")
    A.deep(QuietUICharDB.windowPoints.CharacterFrame, { "CENTER", "CENTER", 8, 9 }, "saved point remains")
end)

h.test("Windows ports the parchment behaviour for NPC quest, gossip and item text and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local quest, gossip, itemText = W.window("QuestFrame"), W.window("GossipFrame"), W.window("ItemTextFrame")
    QuestFrame, GossipFrame, ItemTextFrame = quest, gossip, itemText
    local accept = W.button(quest, "QuestFrameAcceptButton")
    local decline = W.button(quest, "QuestFrameDeclineButton")
    local close = W.button(quest, "QuestFrameCloseButton")
    local scroll = CreateFrame("ScrollFrame", "QuestDetailScrollFrame", quest)
    scroll:SetPoint("BOTTOM", quest, "BOTTOM", 0, 2)
    local text = quest:CreateFontString(nil, "OVERLAY")
    text:SetText("Blizzard quest text")
    local title = quest.TitleContainer.TitleText
    title:SetTextColor(0.8, 0.7, 0.6, 0.5)
    local before = L.snapshot({ quest, quest.chrome, accept, decline, close, scroll, text, title, gossip, itemText })
    W.enable(ns)
    for _, frame in ipairs({ quest, gossip, itemText }) do
        A.ok(W.hasTexture(mock, frame, "Media\\parchment.tga"), (frame:GetName() or "NPC window") .. " has parchment")
        A.alpha(frame.chrome, 0, "old chrome is held")
    end
    A.eq(text:GetText(), "Blizzard quest text", "NPC text remains Blizzard-owned")
    A.eq(accept:GetPoint(), "BOTTOMLEFT", "primary action enters the parchment button band")
    A.eq(decline:GetPoint(), "BOTTOMRIGHT", "secondary action enters the parchment button band")
    A.eq(close:GetPoint(), "TOPRIGHT", "close button becomes the parchment corner cross")
    local _, _, _, _, y = scroll:GetPoint(1)
    A.ok(y > 2, "scroll text clears the button band")
    local _, titleSize = title:GetFont()
    A.eq(titleSize, 15, "title uses the branch-008 ink title size")
    local tr, tg, tb = title:GetTextColor()
    A.eq(tr, 0.24); A.eq(tg, 0.16); A.eq(tb, 0.09, "title uses dark ink")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "parchment restores exact original state")
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
