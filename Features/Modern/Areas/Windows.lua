local _, ns = ...

-- Character, spellbook / talents, quest log, bags and the NPC parchment windows. Named runtime
-- lookups support both Forever's classic and newer window variants; an absent one is skipped.
-- QuestMapFrame lives inside WorldMapFrame and is never made movable or panelled.
local Modern = ns.Modern

local BAG_EVENTS = { BAG_UPDATE_DELAYED = true, BAG_NEW_ITEMS_UPDATED = true }

local function Character(skin)
    Modern.Window(skin, _G.CharacterFrame, "CharacterFrame")
    for index = 1, 5 do Modern.TabChrome(skin, _G["CharacterFrameTab" .. index]) end
    Modern.Window(skin, _G.CharacterFrameReputationFrame)
    Modern.Window(skin, _G.CharacterFrameCurrencyFrame)
end

-- The first frame the client has, so a classic and a newer window are never both moved.
local function Movable(skin, ...)
    for index = 1, select("#", ...) do
        local name = select(index, ...)
        local frame = _G[name]
        if ns.Usable(frame) then
            Modern.Window(skin, frame, name)
            return
        end
    end
end

local function Apply(skin)
    Character(skin)
    Movable(skin, "SpellBookFrame", "PlayerSpellsFrame")
    Movable(skin, "PlayerTalentFrame", "ClassTalentFrame")
    Movable(skin, "QuestLogFrame")
    Modern.Bags.Apply(skin)
    -- Parchment owns the replacement layer and button band; the common journal holds
    -- the Blizzard chrome as well so it remains hidden when the client repaints it.
    for _, name in ipairs({ "QuestFrame", "GossipFrame", "ItemTextFrame" }) do
        Modern.WindowChrome(skin, _G[name])
    end
    if Modern.Parchment then Modern.Parchment.Apply() end
end

Modern.Register{
    key = "windows",
    label = "Windows",
    apply = Apply,
    restore = function()
        if Modern.Parchment then Modern.Parchment.Restore() end
    end,
    addons = { "Blizzard_TalentUI", "Blizzard_PlayerSpells", "Blizzard_SpellBookUI", "Blizzard_QuestUI" },
    events = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW", "ITEM_TEXT_READY",
        "BAG_UPDATE_DELAYED", "BAG_NEW_ITEMS_UPDATED" },
    onEvent = function(skin, event)
        if BAG_EVENTS[event] then
            Modern.Bags.Apply(skin)
        elseif Modern.Parchment then
            Modern.Parchment.Event(event)
        end
    end,
}
