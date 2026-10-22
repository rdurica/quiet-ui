local _, ns = ...

local Setup = ns.Setup

Setup.Pages.info = function(widget, info)
    local column = Setup.Column(info, 0, Setup.CONTENT_W)
    widget.about = column:Add(Setup.Section(info, "About"), 30)
    widget.aboutBody = column:Add(Setup.Body(info, "While you explore, fewer frames stay on screen. They come back when you need them: talking to someone, a quest, a dungeon, or PvP."), 40)
    column:Gap()
    widget.glanceHeader = column:Add(Setup.Section(info, "Glance",
        "Press the Glance binding or use /quiet glance to reveal the hidden HUD, including hover-only elements. Press again to return to the usual visibility rules. Chat is unchanged and Glance is not saved."), 30)
    widget.glanceBody = column:Add(Setup.Body(info, "Press ` to show what has faded. Press it again and the choices on the other tabs apply. Change the key under QuietUI in Key Bindings. You can also use /quiet glance in a macro for your controller."), 40)
end
