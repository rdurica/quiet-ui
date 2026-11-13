local _, ns = ...

-- Character, spellbook / talents, professions, auction house, the calendar, merchant, loot, quest log, bags, the NPC
-- quest, gossip and item text windows, mail, the social windows, the trainer, the plainer panels and small dialogs. Named runtime lookups support both Forever's classic and newer window variants; an absent one is skipped.
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

local PANEL_ADDONS = {
    Blizzard_MacroUI = "MacroFrame", Blizzard_InspectUI = "InspectFrame", Blizzard_FlightMap = "FlightMapFrame",
    Blizzard_StableUI = "PetStableFrame", Blizzard_AddOnList = "AddonList", Blizzard_TimeManager = "TimeManagerFrame",
    Blizzard_LegacySystem = "LegacySystemFrame",
}
local DIALOG_ADDONS = {
    Blizzard_GameMenu = "GameMenuFrame", Blizzard_ColorPickerFrame = "ColorPickerFrame",
    Blizzard_CompactRaidFrames = "CompactRaidFrameManager",
}
local SOCIAL_ADDONS = { Blizzard_FriendsFrame = "FriendsFrame", Blizzard_Communities = "CommunitiesFrame" }

-- Loading a window must not re-walk bags, character slots and every other existing window.
local function Loaded(skin, addon)
    if PANEL_ADDONS[addon] then
        Modern.Panels.Apply(skin, PANEL_ADDONS[addon])
    elseif DIALOG_ADDONS[addon] then
        Modern.Dialogs.Apply(skin, DIALOG_ADDONS[addon])
    elseif SOCIAL_ADDONS[addon] then
        Modern.Social.Apply(skin, SOCIAL_ADDONS[addon])
    elseif addon == "Blizzard_Professions" then
        Modern.Professions.Apply(skin, _G.ProfessionsFrame)
    elseif addon == "Blizzard_PlayerSpells" or addon == "Blizzard_SpellBookUI" then
        FirstWindow(skin, "SpellBookFrame", "PlayerSpellsFrame")
        Modern.Spellbook.Apply(skin, _G.PlayerSpellsFrame)
        Modern.Talents.Apply(skin, _G.PlayerSpellsFrame)
    elseif addon == "Blizzard_TalentUI" then
        FirstWindow(skin, "PlayerTalentFrame", "ClassTalentFrame")
        Modern.Talents.Apply(skin, _G.PlayerSpellsFrame)
    elseif addon == "Blizzard_QuestUI" then
        FirstWindow(skin, "QuestLogFrame")
        Modern.Npc.Apply(skin, "QuestFrame")
    elseif addon == "Blizzard_AuctionHouseUI" then
        Modern.Auction.Apply(skin, _G.AuctionHouseFrame)
    elseif addon == "Blizzard_MailFrame" then
        Modern.Mail.Apply(skin)
    elseif addon == "Blizzard_RaidFrame" then
        Modern.Social.Apply(skin, "FriendsFrame")
        Modern.Social.Apply(skin, "RaidInfoFrame")
    elseif addon == "Blizzard_GroupFinder_VanillaStyle" then
        Modern.Finder.Apply(skin)
    elseif addon == "Blizzard_TrainerUI" then
        Modern.Trainer.Apply(skin, _G.ClassTrainerFrame)
    elseif addon == "Blizzard_Calendar" then
        Modern.Calendar.Apply(skin)
    else
        return false
    end
    return true
end

local function Apply(skin, loadedAddon)
    if loadedAddon and Loaded(skin, loadedAddon) then return end
    Character(skin)
    FirstWindow(skin, "SpellBookFrame", "PlayerSpellsFrame")
    Modern.Spellbook.Apply(skin, _G.PlayerSpellsFrame)
    Modern.Talents.Apply(skin, _G.PlayerSpellsFrame)
    FirstWindow(skin, "PlayerTalentFrame", "ClassTalentFrame")
    FirstWindow(skin, "QuestLogFrame")
    Modern.Professions.Apply(skin, _G.ProfessionsFrame)
    Modern.Auction.Apply(skin, _G.AuctionHouseFrame)
    Modern.Calendar.Apply(skin)
    Modern.Merchant.Apply(skin, _G.MerchantFrame)
    Modern.Loot.Apply(skin, _G.LootFrame)
    Modern.Bags.Apply(skin)
    Modern.Npc.Apply(skin)
    Modern.Mail.Apply(skin)
    Modern.Social.Apply(skin)
    Modern.Finder.Apply(skin)
    Modern.Trainer.Apply(skin, _G.ClassTrainerFrame)
    Modern.Panels.Apply(skin)
    Modern.Dialogs.Apply(skin)
end

Modern.Register{
    key = "windows",
    label = "Windows",
    apply = Apply,
    addons = { "Blizzard_TalentUI", "Blizzard_PlayerSpells", "Blizzard_SpellBookUI", "Blizzard_QuestUI",
        "Blizzard_Professions", "Blizzard_AuctionHouseUI", "Blizzard_MailFrame", "Blizzard_FriendsFrame",
        "Blizzard_RaidFrame", "Blizzard_Communities", "Blizzard_GroupFinder_VanillaStyle", "Blizzard_TrainerUI",
        "Blizzard_MacroUI", "Blizzard_InspectUI", "Blizzard_FlightMap", "Blizzard_StableUI", "Blizzard_AddOnList",
        "Blizzard_TimeManager", "Blizzard_LegacySystem", "Blizzard_GameMenu", "Blizzard_ColorPickerFrame",
        "Blizzard_CompactRaidFrames", "Blizzard_Calendar" },
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
