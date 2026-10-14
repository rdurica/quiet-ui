-- Chat hyperlinks: hover tooltips, hiding, clicks through SetItemRef, and rendered
-- hyperlink hit testing instead of manual rectangles.
local h = ...

local function bubbles(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child break end
        end
    end
    return out
end

-- Link buttons the layout placed over a bubble, in text order.
local function linkButtons(bubble)
    local out = {}
    for _, child in ipairs(bubble._children) do
        if child._kind == "Button" and child._scripts.OnClick then out[#out + 1] = child end
    end
    return out
end

local function link(kind) return "|H" .. kind .. ":123|h[Tailoring]|h" end

-- Recording stand-ins for the tooltip and the link opener.
local function recorders()
    local rec = { hyperlinks = {}, texts = {}, owners = {}, opened = {}, shown = 0, hidden = 0 }
    GameTooltip.SetOwner = function(_, owner) rec.owners[#rec.owners + 1] = owner end
    GameTooltip.SetHyperlink = function(_, l) rec.hyperlinks[#rec.hyperlinks + 1] = l end
    GameTooltip.SetText = function(_, text) rec.texts[#rec.texts + 1] = text end
    GameTooltip.Show = function() rec.shown = rec.shown + 1 end
    GameTooltip.Hide = function() rec.hidden = rec.hidden + 1 end
    SetItemRef = function(l, text, button, chat)
        rec.opened[#rec.opened + 1] = { l, text, button, chat }
    end
    return rec
end

local PLAIN = { "trade", "garrtrade", "player", "unknown" }
local TIPPED = { "item", "spell", "enchant", "quest", "achievement", "currency" }

-- Without rendered hit testing the layout falls back to one button per link.
local function buttonChat(t)
    local ns = t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        frame.SetHyperlinksEnabled = false
        return frame
    end
    local chat = ChatFrame1
    chat:SetSize(1000, 200)
    ns.Chat.StripAll()
    local parts = {}
    for _, kind in ipairs(PLAIN) do parts[#parts + 1] = link(kind) end
    for _, kind in ipairs(TIPPED) do parts[#parts + 1] = link(kind) end
    chat:AddMessage(table.concat(parts, " "))
    ns.Chat.Update(1 / 60)
    return chat, linkButtons(bubbles(chat)[1])
end

h.test("Chat link hover keeps profession links click-only and preserves tooltips", function(t)
    local A = t.assert
    local rec = recorders()
    local chat, buttons = buttonChat(t)
    A.eq(#buttons, #PLAIN + #TIPPED, "one button per link")
    for i = 1, #PLAIN do
        local button = buttons[i]
        button._scripts.OnEnter(button)
        A.eq(#rec.hyperlinks, 0, PLAIN[i] .. " hover dispatched a hyperlink")
        A.eq(#rec.opened, 0, PLAIN[i] .. " hover opened a link")
        button._scripts.OnLeave(button)
    end
    A.ok(rec.shown == 4 and rec.hidden == 4, "Plain hover tooltip did not show and hide")
    for _, text in ipairs(rec.texts) do A.eq(text, "[Tailoring]") end
    A.eq(#rec.texts, 4, "Plain hover shows the link text")

    local trade = buttons[1]
    trade._scripts.OnClick(trade, "LeftButton")
    A.eq(#rec.opened, 1, "Profession click did not open the link")
    A.eq(rec.opened[1][1], "trade:123")
    A.eq(rec.opened[1][2], "[Tailoring]")
    A.eq(rec.opened[1][3], "LeftButton")
    A.eq(rec.opened[1][4], chat)

    for i, kind in ipairs(TIPPED) do
        local button = buttons[#PLAIN + i]
        button._scripts.OnEnter(button)
        A.eq(rec.hyperlinks[#rec.hyperlinks], kind .. ":123", kind .. " tooltip was lost")
    end
    A.ok(#rec.hyperlinks == 6 and #rec.opened == 1)
end)

h.test("Chat uses rendered hyperlinks without covering wrapped text with buttons", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local SECRET = "secret line"
    issecretvalue = function(v) return v == SECRET end
    local chat = ChatFrame1
    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        if parent == chat then
            function frame:SetHyperlinksEnabled(value) self.hyperlinks = value end
        end
        return frame
    end
    chat:SetSize(300, 200)
    ns.Chat.StripAll()
    chat:AddMessage("wrapped " .. link("item") .. " links")
    ns.Chat.Update(1 / 60)
    local bubble = bubbles(chat)[1]
    A.ok(bubble.hyperlinks, "Rendered hyperlink hit testing was not enabled")
    A.eq(#linkButtons(bubble), 0, "Manual hit rectangles still cover rendered text")

    local rec = recorders()
    -- The renderer supplies the same link on either row, and distinct adjacent links.
    for _, l in ipairs({ "item:1", "item:1", "item:2" }) do
        bubble._scripts.OnHyperlinkEnter(bubble, l, "[Wrapped item]")
        bubble._scripts.OnHyperlinkClick(bubble, l, "[Wrapped item]", "LeftButton")
        bubble._scripts.OnHyperlinkLeave(bubble)
        A.eq(rec.hyperlinks[#rec.hyperlinks], l, "Tooltip used the wrong item")
        A.ok(rec.hidden > 0, "Tooltip was not hidden")
        A.eq(rec.owners[#rec.owners], bubble, "Tooltip owner is the bubble")
        local click = rec.opened[#rec.opened]
        A.ok(click[1] == l and click[2] == "[Wrapped item]"
            and click[3] == "LeftButton" and click[4] == chat, "Click opened the wrong link")
    end

    -- A secret message gets its own bubble: no hit testing, so no tooltip and no click.
    chat:AddMessage(SECRET)
    ns.Chat.Update(1 / 60)
    local all = bubbles(chat)
    A.eq(#all, 2, "secret line has its own bubble")
    local secret = all[2]
    A.falsy(secret.hyperlinks, "Secret text still has hyperlink hit testing")
    secret._scripts.OnHyperlinkEnter(secret, "item:3", "[Secret]")
    secret._scripts.OnHyperlinkClick(secret, "item:3", "[Secret]", "LeftButton")
    A.ok(#rec.hyperlinks == 3 and #rec.opened == 3, "Secret message opened a link")

    -- Released bubbles are reused; the reused one gets hit testing back.
    chat:Clear()
    ns.Chat.Update(1 / 60)
    chat:AddMessage("reused bubble")
    ns.Chat.Update(1 / 60)
    local reused
    for _, b in ipairs(bubbles(chat)) do
        if b:IsShown() then reused = b end
    end
    A.ok(reused, "a pooled bubble shows the new line")
    A.eq(#bubbles(chat), 2, "bubble was reused, not created")
    A.ok(reused.hyperlinks, "Reused bubble did not restore hyperlink hit testing")
end)

h.test("Chat without hyperlink hit testing on this client still builds link buttons", function(t)
    local A = t.assert
    -- Older clients may lack the method: no error, and the fallback buttons exist.
    local _, buttons = buttonChat(t)
    A.ok(#buttons > 0, "fallback link buttons")
end)
