local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.info = function(widget, info)
    widget.about = Setup.Section(info, "About")
    widget.about:SetPoint("TOPLEFT", info, "TOPLEFT", 0, 0)
    widget.aboutBody = Setup.Body(info, "While you explore, fewer frames stay on screen. They come back when you need them: talking to someone, a quest, a dungeon, or PvP.")
    widget.aboutBody:SetPoint("TOPLEFT", widget.about, "BOTTOMLEFT", 0, -4)
    widget.glanceHeader = Setup.Section(info, "Glance",
        "Press the Glance binding or use /quiet glance to reveal the hidden HUD, including hover-only elements. Press again to return to the usual visibility rules. Chat is unchanged and Glance is not saved.")
    widget.glanceHeader:SetPoint("TOPLEFT", widget.aboutBody, "BOTTOMLEFT", 0, -12)
    widget.glanceBody = Setup.Body(info, "Press ` to show what has faded. Press it again and the choices on the other tabs apply. Change the key under QuietUI in Key Bindings. You can also use /quiet glance in a macro for your controller.")
    widget.glanceBody:SetPoint("TOPLEFT", widget.glanceHeader, "BOTTOMLEFT", 0, -4)

end
