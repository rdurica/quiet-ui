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
    P.texture(c, frame, "art", "Stationery_Left", "BACKGROUND", { name = "SendStationeryBackgroundLeft" })
    P.texture(c, frame, "art", "UI-ClassTrainer-HorizontalBar", "ARTWORK")
    c.to = P.namedInput(c, frame, "SendMailNameEditBox")
    c.body = CreateFrame("EditBox", "SendMailBodyEditBox", frame)
    c.body:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    c.body:SetTextColor(unpack(INK))
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
