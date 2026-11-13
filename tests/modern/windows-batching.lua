local h = ...
local W = h.lib("modern-windows")

local function fixture(ns)
    local root = CreateFrame("Frame")
    local boxes = {}
    for i = 1, 2 do
        local pane = CreateFrame("Frame", nil, root)
        local box = CreateFrame("Frame", nil, pane)
        pane.ScrollBox = box
        function box:Update() end
        boxes[i] = box
    end
    local skin = ns.Modern.Skin("batch-test")
    return root, boxes, skin
end

h.test("Shared windows batch each dirty list and a show consumes its pending lists", function(t)
    local ns, A = t.ns, t.assert
    local root, boxes, skin = fixture(ns)
    local full, lists = 0, {}
    local function paint() full = full + 1 end
    local again = ns.Modern.Shapes.Keep(skin, root, "test", paint, {
        list = function(_, box) lists[box] = (lists[box] or 0) + 1 end,
    })
    A.eq(full, 1, "initial apply is immediate")
    for _ = 1, 100 do boxes[1]:Update() end
    A.eq(lists[boxes[1]], nil)
    t.mock:tick(0)
    A.eq(full, 1, "a list update does not walk the whole window")
    A.eq(lists[boxes[1]], 1)
    A.eq(lists[boxes[2]], nil, "untouched lists are skipped")
    boxes[1]:Update(); boxes[2]:Update()
    t.mock:tick(0)
    A.eq(lists[boxes[1]], 2)
    A.eq(lists[boxes[2]], 1, "different dirty lists each refresh once")
    root:Hide(); root:Show()
    for _ = 1, 100 do again(); boxes[1]:Update(); boxes[2]:Update() end
    t.mock:tick(0)
    A.eq(full, 2, "shows and refill hooks share a full refresh")
    A.eq(lists[boxes[1]], 2, "the full refresh consumes list work")
    A.eq(lists[boxes[2]], 1)
    t.mock:tick(0)
    A.eq(full, 2)
end)

h.test("Shared window hooks follow reapply and discard work when restored", function(t)
    local ns, A = t.ns, t.assert
    local root, boxes, skin = fixture(ns)
    local first, second = 0, 0
    ns.Modern.Shapes.Keep(skin, root, "test", function() first = first + 1 end)
    root:Hide(); root:Show()
    skin:Undo()
    ns.Modern.Shapes.Keep(skin, root, "test", function() second = second + 1 end)
    t.mock:tick(0)
    A.eq(first, 1)
    A.eq(second, 1, "the old full refresh was cancelled")
    root:Hide(); root:Show()
    t.mock:tick(0)
    A.eq(second, 2, "existing hooks use the new callback")
    skin:Undo()
    root:Hide(); root:Show(); boxes[1]:Update()
    t.mock:tick(0)
    A.eq(second, 2, "restored hooks are inert")
end)

h.test("Every window addon load avoids unrelated window groups", function(t)
    local ns, A = t.ns, t.assert
    W.enable(ns)
    local calls = {}
    for _, group in ipairs({ "Character", "Spellbook", "Talents", "Professions", "Auction", "Calendar",
        "Merchant", "Loot", "Bags", "Npc", "Mail", "Social", "Finder", "Trainer", "Panels", "Dialogs" }) do
        ns.Modern[group].Apply = function(_, only)
            calls[#calls + 1] = group .. (type(only) == "string" and ":" .. only or "")
        end
    end
    local cases = {
        Blizzard_TalentUI = { "Talents" },
        Blizzard_PlayerSpells = { "Spellbook", "Talents" },
        Blizzard_SpellBookUI = { "Spellbook", "Talents" },
        Blizzard_QuestUI = { "Npc:QuestFrame" },
        Blizzard_Professions = { "Professions" },
        Blizzard_AuctionHouseUI = { "Auction" },
        Blizzard_MailFrame = { "Mail" },
        Blizzard_FriendsFrame = { "Social:FriendsFrame" },
        Blizzard_RaidFrame = { "Social:FriendsFrame", "Social:RaidInfoFrame" },
        Blizzard_Communities = { "Social:CommunitiesFrame" },
        Blizzard_GroupFinder_VanillaStyle = { "Finder" },
        Blizzard_TrainerUI = { "Trainer" },
        Blizzard_MacroUI = { "Panels:MacroFrame" },
        Blizzard_InspectUI = { "Panels:InspectFrame" },
        Blizzard_FlightMap = { "Panels:FlightMapFrame" },
        Blizzard_StableUI = { "Panels:PetStableFrame" },
        Blizzard_AddOnList = { "Panels:AddonList" },
        Blizzard_TimeManager = { "Panels:TimeManagerFrame" },
        Blizzard_LegacySystem = { "Panels:LegacySystemFrame" },
        Blizzard_GameMenu = { "Dialogs:GameMenuFrame" },
        Blizzard_ColorPickerFrame = { "Dialogs:ColorPickerFrame" },
        Blizzard_CompactRaidFrames = { "Dialogs:CompactRaidFrameManager" },
        Blizzard_Calendar = { "Calendar" },
    }
    for addon, expected in pairs(cases) do
        calls = {}
        ns.Modern.AddonLoaded(addon)
        A.deep(calls, expected, addon)
    end
end)
