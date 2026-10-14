local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.chat = function(widget, chat)
    widget.chatHeader = Setup.Section(chat, "Chat",
        "Modern chat replaces the chat chrome with fading message bubbles. Fade after controls how long new lines remain visible; 0 keeps them. Hover and scrolling reveal older messages. The tabs sit below the chat by default; set Tabs to Top to keep them above it. Turning Modern chat off restores the original chat.")
    widget.chatHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
    widget.chat = Setup.Choice(chat, "Modern chat", function()
        draft.chat = not draft.chat
        Setup.Paint()
    end)
    widget.chat:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -20)
    widget.fade = Setup.Stepper(chat, "Fade after", function(sign)
        Setup.NudgeFade(sign * 5)
    end)
    widget.fade:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -44)
    widget.fade.value:SetWidth(72)
    widget.chatTabs = Setup.Stepper(chat, "Tabs", function()
        Setup.CycleChatTabs()
    end)
    widget.chatTabs:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -68)
    widget.chatTabs.value:SetWidth(72)
    widget.questHeader = Setup.Section(chat, "Quests",
        "Shows the quest you just accepted, changed, or completed at the top of the quest area for a few seconds. The rest of the tracker stays hidden, and WoW's center-screen quest text stays hidden while this is on.")
    widget.questHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -122)
    widget.questNotice = Setup.Choice(chat, "Quest updates", function()
        draft.questNotice = not draft.questNotice
        Setup.Paint()
    end)
    widget.questNotice:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -142)
    widget.questNoticeSize = Setup.Stepper(chat, "Text size", function(sign)
        Setup.NudgeNoticeSize(sign)
    end)
    widget.questNoticeSize:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -168)
    widget.questNoticeSize.value:SetWidth(72)
    widget.highlightHeader = Setup.Section(chat, "Highlights",
        "The object the game picks for the Interact key glows: herbs green, ore gold, interact objects white. Set that key in Key Bindings as Interact With Target. Interact objects includes anything with the gear icon, not just quest objects. QuietUI widens soft targeting, hides the highlighted icon and any icon you had turned off, and restores your settings when turned off.")
    widget.highlightHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -202)
    widget.highlightNote = Setup.Body(chat, "Turns on soft targeting for the Interact key, so nearby NPCs show their names.")
    widget.highlightNote:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -220)
    local highlightChoices = {
        { key = "highlightHerb", label = "Herbs" },
        { key = "highlightOre", label = "Ore" },
        { key = "highlightQuest", label = "Interact objects" },
    }
    for i, choice in ipairs(highlightChoices) do
        local button = Setup.Choice(chat, choice.label, function()
            draft[choice.key] = not draft[choice.key]
            Setup.Paint()
        end)
        button:SetWidth(120)
        button:SetPoint("TOPLEFT", chat, "TOPLEFT", (i - 1) * 124, -238)
        widget[choice.key] = button
    end
    widget.questMobsHeader = Setup.Section(chat, "Quest mobs",
        "A gold exclamation mark shows left of the nameplate of mobs you need to kill for a quest, and a pouch for mobs that drop a quest item. Only mobs you can attack are marked, and the icon disappears once the objective is complete.")
    widget.questMobsHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -274)
    widget.questMobs = Setup.Choice(chat, "Quest mobs", function()
        draft.questMobs = not draft.questMobs
        Setup.Paint()
    end)
    widget.questMobs:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -294)

end
