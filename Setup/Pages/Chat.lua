local _, ns = ...

local Setup = ns.Setup

-- Chat only: how its messages fade and where its tabs sit.
Setup.Pages.chat = function(widget, chat)
    local left = Setup.Column(chat, 0, Setup.COLUMN_W)
    widget.chatHeader = left:Add(Setup.Section(chat, "Chat",
        "Chat replaces the chat chrome with fading message bubbles. Fade after controls how long new lines remain visible; 0 keeps them. Hover and scrolling reveal older messages. The tabs sit below the chat by default; set Tabs to Top to keep them above it. Turning the Chat module off restores the original chat."), 30)
    widget.fade = left:Add(Setup.Stepper(chat, "Fade after", function(sign)
        Setup.NudgeFade(sign * 5)
    end))
    widget.chatTabs = left:Add(Setup.Stepper(chat, "Tabs", function()
        Setup.CycleChatTabs()
    end))
end
