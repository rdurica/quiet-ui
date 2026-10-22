-- Small dialogs of the Forever UI source: GameMenuFrame (MainMenuFrameTemplate: DialogBorderTemplate, a
-- DialogHeaderTemplate title and ThreeSliceButton buttons rebuilt on every show), StaticPopup1 (a BG frame with Top
-- and Bottom, StaticPopupButtonTemplate buttons with UI-DialogBox-Button art, an InputBox) and GroupLootFrame1 (toast
-- Background and Border, IconFrame with Icon and Border, a Timer bar with a Background).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")

local function threeSlice(c, parent, label)
    local button = CreateFrame("Button", nil, parent)
    for _, key in ipairs({ "Left", "Right", "Center" }) do
        button[key] = P.texture(c, button, "art", "128-RedButton-" .. key, "BACKGROUND", { atlas = true })
    end
    button.Text = P.text(c, button, label)
    return button
end

local function popup(c)
    local frame = CreateFrame("Frame", "StaticPopup1", UIParent)
    frame.BG = CreateFrame("Frame", nil, frame)
    frame.BG.Top = P.texture(c, frame.BG, "art", "UI-DialogBox-Top", "BACKGROUND")
    frame.BG.Bottom = P.texture(c, frame.BG, "art", "UI-DialogBox-Bottom", "BACKGROUND")
    frame.Text = P.text(c, frame, "Delete Linen Cloth?")
    local button = CreateFrame("Button", "StaticPopup1Button1", frame)
    P.buttonArt(c, button, { GetNormalTexture = "UI-DialogBox-Button-Up", GetPushedTexture = "UI-DialogBox-Button-Down",
        GetHighlightTexture = "UI-DialogBox-Button-Highlight" }, "art")
    button.Text = P.text(c, button, "Accept")
    c.accept = button
    local box = CreateFrame("EditBox", "StaticPopup1EditBox", frame)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        box[key] = P.texture(c, box, "art", "common-search-border-" .. key, "BACKGROUND", { atlas = true })
    end
    c.box = box
    return frame
end

local function roll(c)
    local frame = CreateFrame("Frame", "GroupLootFrame1", UIParent)
    frame.Background = P.texture(c, frame, "art", "LootToast-Background", "BACKGROUND")
    frame.Border = P.texture(c, frame, "art", "LootToast-Border", "BORDER")
    frame.IconFrame = CreateFrame("Button", nil, frame)
    frame.IconFrame.Icon = P.texture(c, frame.IconFrame, "keep", "Icons\\INV_Sword_04")
    frame.IconFrame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.IconFrame.Border = P.texture(c, frame.IconFrame, "art", "loottoast-itemborder-green", "OVERLAY",
        { atlas = true })
    frame.Timer = CreateFrame("StatusBar", nil, frame)
    frame.Timer.Background = P.texture(c, frame.Timer, "art", "Timer-Background", "BACKGROUND")
    c.need = CreateFrame("Button", nil, frame)
    P.buttonArt(c, c.need, { GetNormalTexture = "lootroll-toast-icon-need-up" }, "keep")
    return frame
end

h.test("Windows darkens the game menu, popups and loot rolls, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = P.new()
    local menu = P.dialog(c, "GameMenuFrame")
    local options = threeSlice(c, menu, "Options")
    local pop, loot = popup(c), roll(c)
    local before = L.snapshot(R.all(UIParent))
    W.enable(ns)
    A.ok(W.isDark(menu) and W.isDark(pop) and W.isDark(loot), "menu, popup and loot roll are dark panels")
    A.eq(P.visibleArt(c, R), "", "dialog borders, header pieces, popup halves, plates and toast art are held")
    A.eq(P.hiddenKeep(c, R), "", "texts, the item icon and the roll buttons stay")
    A.ok(W.isDark(options) and P.hasHover(options), "a game menu button is a flat field")
    A.ok(W.isDark(c.accept) and P.hasHover(c.accept), "a popup button is a flat field")
    A.ok(W.isDark(c.box), "the popup's input box is a flat field")
    A.ok(L.zoomed(loot.IconFrame.Icon), "the rolled item's icon is square-cropped")
    local point, relative = W.point(menu.Header.Text)
    A.ok(point[1] == "TOP" and relative == menu, "the game menu title sits in the header band")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the dialogs restore exactly")
end)

h.test("Windows skins game menu buttons Blizzard builds when the menu shows", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local menu = P.dialog(c, "GameMenuFrame")
    menu:Hide()
    W.enable(ns)
    local late = P.new()
    local logout = threeSlice(late, menu, "Log Out")
    menu:Show()
    A.eq(P.visibleArt(late, R), "", "a button built on show is flat")
    A.ok(W.isDark(logout), "the new button has the dark field")
end)
