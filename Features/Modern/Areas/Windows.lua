local _, ns = ...

-- Character, spellbook / talents, professions, auction house, merchant, loot, quest log, bags and the NPC quest,
-- gossip and item text windows. Named runtime lookups support both Forever's classic and newer window variants; an absent one is skipped.
-- QuestMapFrame lives inside WorldMapFrame and is never made movable or panelled.
local Modern = ns.Modern

local BAG_EVENTS = { BAG_UPDATE_DELAYED = true, BAG_NEW_ITEMS_UPDATED = true }

local function Character(skin)
    Modern.Window(skin, _G.CharacterFrame, "CharacterFrame")
    Modern.Header(skin, _G.CharacterFrame)
    for index = 1, 5 do Modern.TabChrome(skin, _G["CharacterFrameTab" .. index]) end
    Modern.Character.Apply(skin, _G.CharacterFrame)
    -- 12.0 names first, the classic ones as fallback; both are skinned when the client has both.
    for _, name in ipairs({ "ReputationFrame", "TokenFrame", "CharacterFrameReputationFrame", "CharacterFrameCurrencyFrame" }) do
        Modern.Window(skin, _G[name])
    end
end

-- The first window the client has, so a classic and a newer variant are never both skinned and moved.
local function FirstWindow(skin, ...)
    for index = 1, select("#", ...) do
        local name = select(index, ...)
        local frame = _G[name]
        if ns.Usable(frame) then
            Modern.Window(skin, frame, name)
            Modern.Header(skin, frame)
            return
        end
    end
end

local function Apply(skin)
    Character(skin)
    FirstWindow(skin, "SpellBookFrame", "PlayerSpellsFrame")
    Modern.Spellbook.Apply(skin, _G.PlayerSpellsFrame)
    FirstWindow(skin, "PlayerTalentFrame", "ClassTalentFrame")
    FirstWindow(skin, "QuestLogFrame")
    Modern.Professions.Apply(skin, _G.ProfessionsFrame)
    Modern.Auction.Apply(skin, _G.AuctionHouseFrame)
    Modern.Merchant.Apply(skin, _G.MerchantFrame)
    Modern.Loot.Apply(skin, _G.LootFrame)
    Modern.Bags.Apply(skin)
    Modern.Npc.Apply(skin)
end

Modern.Register{
    key = "windows",
    label = "Windows",
    apply = Apply,
    addons = { "Blizzard_TalentUI", "Blizzard_PlayerSpells", "Blizzard_SpellBookUI", "Blizzard_QuestUI",
        "Blizzard_Professions", "Blizzard_AuctionHouseUI" },
    events = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW", "ITEM_TEXT_READY",
        "LOOT_OPENED", "BAG_UPDATE_DELAYED", "BAG_NEW_ITEMS_UPDATED", "PLAYER_EQUIPMENT_CHANGED" },
    onEvent = function(skin, event)
        if BAG_EVENTS[event] then
            Modern.Bags.Apply(skin)
        elseif event == "LOOT_OPENED" then
            Modern.Loot.Apply(skin, _G.LootFrame)
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            Modern.Character.Slots(skin)
        else
            Modern.Npc.Event(skin, event)
        end
    end,
}
