-- The mailbox of the Forever UI source (Blizzard_MailFrame): MailFrame (ButtonFrameTemplate) with InboxFrameBg, the
-- rows MailItemN (two unkeyed MailItemBorder textures, a sender, a CheckButton MailItemNButton with Icon, IconBorder
-- and a named $parentSlot), the send page (stationery, divider bars, the body edit box with parchment ink, named
-- input boxes, SendMailAttachmentN whose item shows as the NormalTexture over an unkeyed slot texture), and
-- OpenMailFrame with its stationery and the letter text in parchment ink.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")
local B = h.lib("modern-bags")

local INK = { 0.18, 0.12, 0.06, 1 }

local function inked(c, parent, value)
    local font = P.text(c, parent, value)
    font:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    font:SetTextColor(unpack(INK))
    return font
end

-- SendMailAttachment: a slot texture, IconBorder, and the item set later through SetNormalTexture.
local function attachment(c, parent, name)
    local button = CreateFrame("Button", name, parent)
    P.texture(c, button, "art", "UI-Slot-Background", "BACKGROUND")
    button.IconBorder = P.texture(c, button, "art", "WhiteIconFrame", "OVERLAY")
    button.IconBorder:Hide()
    local normal
    function button:SetNormalTexture(file)
        normal = normal or self:CreateTexture(nil, "ARTWORK")
        normal:SetTexture(file)
    end
    function button:ClearNormalTexture() if normal then normal:SetTexture(nil) end end
    function button:GetNormalTexture() return normal end
    return button
end

local function mailbox()
    local c = P.new()
    local frame = P.window(c, "MailFrame")
    P.tab(c, frame, "MailFrameTab1")
    P.texture(c, frame, "art", "UI-MailFrameBG", "BACKGROUND", { name = "InboxFrameBg" })
    local row = CreateFrame("Frame", "MailItem1", frame)
    P.texture(c, row, "art", "MailItemBorder", "BACKGROUND")
    P.texture(c, row, "art", "MailItemBorder", "BACKGROUND")
    P.text(c, row, "Merisa")
    c.row = P.itemButton(c, row, "MailItem1Button", { kind = "CheckButton", Icon = true, slot = true })
    c.mailRow = row
    -- The inbox page buttons: spellbook page art with a label beside it.
    local inbox = CreateFrame("Frame", "InboxFrame", frame)
    for _, page in ipairs({ { "InboxPrevPageButton", "PrevPage", "Prev" }, { "InboxNextPageButton", "NextPage", "Next" } }) do
        local button = CreateFrame("Button", page[1], inbox)
        local normal = P.texture(c, button, "art", "UI-SpellbookIcon-" .. page[2] .. "-Up", "ARTWORK")
        function button:GetNormalTexture() return normal end
        button.label = P.text(c, button, page[3])
    end
    P.texture(c, frame, "art", "Stationery_Left", "BACKGROUND", { name = "SendStationeryBackgroundLeft" })
    P.texture(c, frame, "art", "UI-ClassTrainer-HorizontalBar", "ARTWORK")
    c.to = P.namedInput(c, frame, "SendMailNameEditBox")
    c.body = CreateFrame("EditBox", "SendMailBodyEditBox", frame)
    c.body:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    c.body:SetTextColor(unpack(INK))
    -- The divider reported by file id on Forever, so it is only known by its name.
    local bar = P.texture(c, frame, "art", "137012", "ARTWORK", { name = "SendMailHorizontalBarLeft" })
    c.barRight = P.texture(c, frame, "art", "137012", "ARTWORK")
    c.barRight:SetPoint("LEFT", bar, "RIGHT", 0, 0)
    -- The money bar under the player's coins and the gold input of the amount to send.
    c.moneyBar = P.inset(c, frame, "SendMailMoneyInset")
    c.moneyBg = CreateFrame("Frame", "SendMailMoneyBg", frame)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        c.moneyBg[key] = P.texture(c, c.moneyBg, "art", "MoneyBg-" .. key, "BACKGROUND")
    end
    c.gold = P.namedInput(c, frame, "SendMailMoneyGold")
    c.coin = P.texture(c, c.gold, nil, "UI-GoldIcon", "ARTWORK")
    c.slot = attachment(c, frame, "SendMailAttachment1")
    c.send = P.panelButton(c, frame, "Send", "SendMailMailButton")
    c.frame = frame

    local open = P.window(c, "OpenMailFrame")
    P.texture(c, open, "art", "Stationery_Right", "BACKGROUND", { name = "OpenStationeryBackgroundRight" })
    c.letter = inked(c, open, "Thank you for the linen.")
    c.open = open
    return c
end

h.test("Windows gives the mailbox the dark window with bare rows and light letter ink, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = mailbox()
    local before = L.snapshot(R.all(c.frame))
    local beforeOpen = L.snapshot(R.all(c.open))
    W.enable(ns)
    A.ok(W.isDark(c.frame) and W.isDark(c.open), "the mailbox and the open letter are dark windows")
    A.eq(P.visibleArt(c, R), "", "parchment, row frames, stationery, bars, slot and field art are held")
    A.eq(P.hiddenKeep(c, R), "", "sender names, icons and texts stay")
    A.ok(L.zoomed(c.row.icon), "a row's mail icon is square-cropped")
    A.ok(W.isDark(c.to), "the recipient box is a flat field")
    local r = c.letter:GetTextColor()
    A.ok(r > 0.5, "the letter text is light")
    A.ok(c.body:GetTextColor() > 0.5, "the body of a new letter is light")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the mailbox restores exactly")
    A.deep(L.diff(beforeOpen), {}, "the open letter restores exactly")
end)

h.test("Windows lets the inbox stand bare, without an inner box or row rules, and turns its pages with chevrons", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = mailbox()
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.ok(B.border(c.frame.Inset) == nil, "the inbox inset draws no second box")
    for _, region in ipairs(c.frame.Inset._regions) do
        A.ok(region._shown == false or not region._color, "the inbox inset has no darker fill")
    end
    for _, region in ipairs(c.mailRow._regions) do
        A.ok(region._shown == false or not region._color, "a row has no rule under it")
    end
    for _, name in ipairs({ "InboxPrevPageButton", "InboxNextPageButton" }) do
        local button = _G[name]
        local strokes = 0
        for _, region in ipairs(button._regions) do
            if region._shown ~= false and region._color and region._color[1] == theme.accent[1] then strokes = strokes + 1 end
        end
        A.eq(strokes, 2, name .. " is a bare accent chevron")
        A.ok(R.invisible(button:GetNormalTexture(), c.frame), name .. " loses the spellbook page art")
        A.ok(not R.invisible(button.label, c.frame), name .. " keeps its label")
    end
    ns.Modern.Restore()
    A.ok(not R.invisible(_G.InboxPrevPageButton:GetNormalTexture(), c.frame), "the page art comes back")
end)

h.test("Windows quiets the send page: no divider bars, the money as bare text, coin inputs without a border", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = mailbox()
    W.enable(ns)
    A.ok(R.invisible(_G.SendMailHorizontalBarLeft, c.frame), "the divider bar is held by its name")
    A.ok(R.invisible(c.barRight, c.frame), "the unnamed right half anchored to it goes too")
    A.ok(B.border(c.moneyBar) == nil and B.border(c.moneyBg) == nil, "the money bar has no border")
    A.ok(not W.isDark(c.moneyBg), "the money bar has no field")
    A.ok(W.isDark(c.gold), "a coin input keeps its dark field")
    A.ok(B.border(c.gold) == nil, "a coin input has no border")
    A.ok(not R.invisible(c.coin, c.frame), "the coin icon stays")
    ns.Modern.Restore()
    A.ok(not R.invisible(_G.SendMailHorizontalBarLeft, c.frame), "the divider bar comes back")
end)

h.test("Windows frames a mail attachment in its quality colour and crops it", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = mailbox()
    W.enable(ns)
    local slot = c.slot
    c.slot:SetNormalTexture("Interface\\Icons\\INV_Fabric_Linen")
    slot.IconBorder:SetVertexColor(0.12, 1, 0, 1)
    slot.IconBorder:Show()
    A.ok(L.zoomed(slot:GetNormalTexture()), "the attached item is square-cropped")
    A.ok(not R.invisible(slot:GetNormalTexture(), c.frame), "the attached item stays visible")
    local border
    for _, region in ipairs(slot._regions) do
        if region._layer == "OVERLAY" and region._color and region._shown ~= false and region ~= slot.IconBorder then
            border = region._color
        end
    end
    A.ok(border and border[2] == 1 and border[1] == 0.12, "the slot border takes the uncommon green")
    slot.IconBorder:Hide()
    slot:ClearNormalTexture()
    ns.Modern.Restore()
    slot:SetNormalTexture("Interface\\Icons\\INV_Fabric_Wool")
    A.eq(#t.mock.printed, 0, "a send slot changed while the area is off reports nothing")
end)

h.test("the letter body edit box takes the light ink but keeps Blizzard's font, so restore never sets one", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = mailbox()
    local body = c.body
    -- The client reports a font instance without a font object as its own font object.
    function body:GetFontObject() return self end
    local fontCalls = 0
    local setFont, setObject = body.SetFont, body.SetFontObject
    function body:SetFont(...) fontCalls = fontCalls + 1; return setFont(self, ...) end
    function body:SetFontObject(...) fontCalls = fontCalls + 1; return setObject(self, ...) end
    W.enable(ns)
    A.ok(body:GetTextColor() > 0.5, "the body of a new letter is light")
    ns.Modern.Restore()
    A.eq(fontCalls, 0, "changing an edit box's font crashes the client on restore")
    A.eq(body:GetFont(), "Fonts\\FRIZQT__.TTF", "Blizzard's face stays")
    A.eq(select(1, body:GetTextColor()), 0.18, "Blizzard's ink is back")
end)
