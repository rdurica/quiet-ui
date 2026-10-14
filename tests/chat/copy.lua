-- Copying a chat line keeps only the message: no time, channel tag or sender.
local h = ...

local NAME = "|Hplayer:Name-Realm:12:CHANNEL:2|h[|cff40c040Name|r]|h"
local ITEM = "|cffffffff|Hitem:2589::::::::|h[Linen Cloth]|h|r"

local function copied(t, text)
    local Chat = t.ns.Chat
    return Chat.PlainText(Chat.MessageBody(text))
end

h.test("copy drops time, channel tag and sender", function(t)
    local A = t.assert
    A.eq(copied(t, "[12:00] |Hchannel:channel:2|h[2]|h " .. NAME .. ": prodam"), "prodam")
    A.eq(copied(t, "12:00:31 [G] " .. NAME .. ": ahoj"), "ahoj")
    A.eq(copied(t, NAME .. " says: ahoj"), "ahoj")
    A.eq(copied(t, NAME .. " yells: pozor"), "pozor")
    A.eq(copied(t, NAME .. " whispers: hi"), "hi")
    A.eq(copied(t, "To " .. NAME .. ": hi"), "hi")
    A.eq(copied(t, "|cffff80ff[12:00] To " .. NAME .. ": hi|r"), "hi")
end)

h.test("copy keeps links and brackets inside the message", function(t)
    local A = t.assert
    A.eq(copied(t, "[2] " .. NAME .. ": WTS " .. ITEM .. " [cheap]: pm"), "WTS [Linen Cloth] [cheap]: pm")
end)

h.test("copy keeps lines without a sender, minus the time", function(t)
    local A = t.assert
    A.eq(copied(t, "You receive loot: " .. ITEM .. "."), "You receive loot: [Linen Cloth].")
    A.eq(copied(t, "[12:00] Quest accepted: Hogger"), "Quest accepted: Hogger")
    A.eq(copied(t, NAME .. " waves."), "[Name] waves.")
    A.eq(copied(t, NAME .. " has earned the achievement " .. ITEM .. "!"), "[Name] has earned the achievement [Linen Cloth]!")
    A.eq(copied(t, "[12:00] " .. NAME .. ": "), "[Name]: ")
end)
