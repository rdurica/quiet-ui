-- The Forever 12.0 loot window, shaped after a frame dump of the client: LootFrame (ScrollingFlatPanelTemplate)
-- with a metal NineSlice, a flat Bg frame (TopSection, BottomEdge, BottomLeft, BottomRight), ClosePanelButton,
-- TitleContainer and pooled cards in ScrollBox.ScrollTarget: NameFrame, BorderFrame, HighlightNameFrame,
-- PushedNameFrame, IconQuestTexture, Text and an Item button (icon, IconBorder, NormalTexture).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Loot\\" .. name)
    texture:SetAlpha(0.9)
    if list then list[#list + 1] = texture end
    return texture
end

local function card(target, list, label)
    local element = CreateFrame("Frame", nil, target)
    for _, key in ipairs({ "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame" }) do
        element[key] = art(element, list, "Looting_ItemCard_" .. key)
    end
    element.IconQuestTexture = art(element, nil, "QuestBorder", "OVERLAY")
    element.Text = element:CreateFontString(nil, "OVERLAY")
    element.Text:SetText(label)
    local button = CreateFrame("Button", nil, element)
    element.Item = button
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetTexture("Interface\\Icons\\" .. label)
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.IconBorder = art(button, list, "WhiteIconFrame", "OVERLAY")
    button.NormalTexture = art(button, list, "Quickslot")
    return element
end

local function loot()
    local list = {}
    local frame = CreateFrame("Frame", "LootFrame", UIParent)
    frame:SetSize(220, 92)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -300)
    frame.chromeList = list
    frame.NineSlice = R.nineSlice(frame, list)
    frame.Bg = CreateFrame("Frame", "LootFrameBg", frame)
    for _, key in ipairs({ "TopSection", "BottomEdge", "BottomLeft", "BottomRight" }) do
        frame.Bg[key] = art(frame.Bg, list, "UIFrameBackground-" .. key, "BACKGROUND")
    end
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString(nil, "OVERLAY")
    frame.TitleContainer.TitleText:SetText("Items")
    frame.ClosePanelButton = R.artButton(frame, "RedButton-Exit", list)
    frame.ScrollBox = CreateFrame("Frame", nil, frame)
    function frame.ScrollBox:Update() end
    frame.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, frame.ScrollBox)
    local first = card(frame.ScrollBox.ScrollTarget, list, "Linen")
    return { frame = frame, art = list, card = first }
end

local function visibleArt(c)
    local names = {}
    for _, texture in ipairs(c.art) do
        if not R.invisible(texture, c.frame) then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

h.test("Windows gives the loot window the dark template with bare cards, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = loot()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    local frame, element = c.frame, c.card
    A.ok(W.isDark(frame), "the loot window is a dark window")
    A.eq(visibleArt(c), "", "metal border, flat background, card art, slot art and close art are all held")
    A.ok(L.zoomed(element.Item.icon), "the item icon is square-cropped")
    A.ok(B.border(element.Item) ~= nil, "the item button is a flat slot with a border")
    A.ok(not W.isDark(element) and B.border(element) == nil, "the card stays bare")
    A.ok(not R.invisible(element.Text, frame), "the item name stays")
    A.ok(not R.invisible(element.IconQuestTexture, frame), "the quest border stays")
    A.ok(not R.invisible(frame.TitleContainer.TitleText, frame), "the title stays")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "loot window restores exactly")
end)

h.test("pooled loot cards are skinned on LOOT_OPENED and scroll updates, and not after restore", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = loot()
    W.enable(ns)
    local target = c.frame.ScrollBox.ScrollTarget
    local late = card(target, {}, "Copper")
    mock:fire("LOOT_OPENED")
    A.alpha(late.NameFrame, 0, "a card built after apply is skinned on LOOT_OPENED")
    local later = card(target, {}, "Silk")
    c.frame.ScrollBox:Update()
    A.alpha(later.BorderFrame, 0, "a card built after apply is skinned when the scroll box updates")
    ns.Modern.Restore()
    local after = card(target, {}, "Wool")
    c.frame.ScrollBox:Update()
    mock:fire("LOOT_OPENED")
    A.alpha(after.NameFrame, 0.9, "nothing is skinned after restore")
end)
