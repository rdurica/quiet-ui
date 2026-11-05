local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

local function Toggle(key)
    return function()
        draft[key] = not draft[key]
        Setup.Paint()
    end
end

-- Chat and quest updates on the left, world helpers on the right.
Setup.Pages.chat = function(widget, chat)
    local left = Setup.Column(chat, 0, Setup.COLUMN_W)
    widget.chatHeader = left:Add(Setup.Section(chat, "Chat",
        "Modern chat replaces the chat chrome with fading message bubbles. Fade after controls how long new lines remain visible; 0 keeps them. Hover and scrolling reveal older messages. The tabs sit below the chat by default; set Tabs to Top to keep them above it. Turning Modern chat off restores the original chat."), 30)
    widget.chat = left:Add(Setup.Choice(chat, "Modern chat", Toggle("chat")))
    widget.fade = left:Add(Setup.Stepper(chat, "Fade after", function(sign)
        Setup.NudgeFade(sign * 5)
    end))
    widget.chatTabs = left:Add(Setup.Stepper(chat, "Tabs", function()
        Setup.CycleChatTabs()
    end))
    left:Gap()
    widget.questHeader = left:Add(Setup.Section(chat, "Quests",
        "Shows the quest you just accepted, changed, or completed at the top of the quest area for a few seconds. The rest of the tracker stays hidden, and WoW's center-screen quest text stays hidden while this is on."), 30)
    widget.questNotice = left:Add(Setup.Choice(chat, "Quest updates", Toggle("questNotice")))
    widget.questNoticeSize = left:Add(Setup.Stepper(chat, "Text size", function(sign)
        Setup.NudgeNoticeSize(sign)
    end))

    local right = Setup.Column(chat, Setup.RIGHT_X, Setup.COLUMN_W)
    widget.highlightHeader = right:Add(Setup.Section(chat, "Highlights",
        "The object the game picks for the Interact key glows: herbs green, ore gold, interact objects white. Set that key in Key Bindings as Interact With Target. Interact objects includes anything with the gear icon, not just quest objects. QuietUI widens soft targeting, hides the highlighted icon and any icon you had turned off, and restores your settings when turned off."), 30)
    widget.highlightNote = right:Add(Setup.Note(chat, "Turns on soft targeting for the Interact key, so nearby NPCs show their names."), 40)
    for _, choice in ipairs({
        { key = "highlightHerb", label = "Herbs" },
        { key = "highlightOre", label = "Ore" },
        { key = "highlightQuest", label = "Interact objects" },
    }) do
        widget[choice.key] = right:Add(Setup.Choice(chat, choice.label, Toggle(choice.key)))
    end
    right:Gap()
    widget.questMobsHeader = right:Add(Setup.Section(chat, "Quest mobs",
        "A gold exclamation mark shows left of the nameplate of mobs you need to kill for a quest, and a pouch for mobs that drop a quest item. Only mobs you can attack are marked, and the icon disappears once the objective is complete."), 30)
    widget.questMobs = right:Add(Setup.Choice(chat, "Quest mobs", Toggle("questMobs")))
end
