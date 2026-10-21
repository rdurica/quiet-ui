-- The shared shapes inside a window, on the trade window of the Forever UI source (TradeFrame, ButtonFrameTemplate):
-- tabs, both scroll bars, slot cards with item buttons, three-piece buttons, named input boxes, the money edge,
-- dropdowns, square, stretch and side-tab buttons, label-less checkboxes, list rows, an inner inset and a nested
-- portrait window. The taxi window keeps its map (InsetBg).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")

local function trade()
    local c = P.new()
    local frame = P.window(c, "TradeFrame")
    c.frame = frame
    c.tab = P.tab(c, frame, "TradeFrameTab1")
    c.scroll = P.scrollBar(c, frame)
    c.slider = P.sliderBar(c, frame, "TradeSlider")
    c.card = P.card(c, frame, "TradePlayerItem1")
    c.button = P.panelButton(c, frame, "Trade", "TradeFrameTradeButton")
    c.input = P.namedInput(c, frame, "TradeNameBox")
    c.money = P.moneyEdge(c, frame, "TradeRecipientMoneyBg")
    c.dropdown = P.dropdown(c, frame)
    c.square = P.squareButton(c, frame)
    c.stretch = P.stretchButton(c, frame, "Decline")
    c.side = P.sideTab(c, frame)
    c.check = P.checkbox(c, frame)
    c.row = P.listRow(c, frame)
    c.inset = P.inset(c, frame, "TradeRecipientItemsInset")
    c.nested = P.window(c, "TradeNestedWindow", frame)
    return c
end

h.test("Windows skins the shared shapes inside a window and restores them exactly", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = trade()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    local frame = c.frame
    A.ok(W.isDark(frame), "the trade window is a dark window")
    A.eq(P.visibleArt(c, R, frame), "", "every template's art is held")
    A.eq(P.hiddenKeep(c, R, frame), "", "icons, arrows, names and texts stay")
    A.ok(W.isDark(c.button) and P.hasHover(c.button), "a panel button is a flat field that lights up under the mouse")
    A.ok(W.isDark(c.input), "a named input box is a flat field")
    A.ok(not W.isDark(c.money), "the money edge stays bare")
    A.ok(W.isDark(c.dropdown) and P.hasHover(c.dropdown), "a dropdown is a flat field with a hover")
    A.ok(W.isDark(c.square) and W.isDark(c.stretch), "square and stretch buttons are flat")
    A.ok(L.zoomed(c.card.ItemButton.icon), "the traded item's icon is square-cropped")
    A.ok(W.isDark(c.nested), "a nested portrait window is a dark window too")
    A.ok(P.hasHover(c.tab), "a tab lights up under the mouse")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the trade window restores exactly")
end)

h.test("Windows keeps the taxi map when it flattens the taxi window", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local frame = CreateFrame("Frame", "TaxiFrame", UIParent)
    for _, key in ipairs({ "TopLeftCorner", "TopBorder", "BotRightCorner", "LeftBorder", "InsetBorderTop",
        "InsetBorderBottomLeft" }) do
        frame[key] = P.texture(c, frame, "art", "UI-Frame-" .. key, "BORDER")
    end
    frame.Bg = P.texture(c, frame, "art", "UI-Background-Rock", "BACKGROUND")
    frame.InsetBg = P.texture(c, frame, "keep", "TaxiMap", "BACKGROUND")
    W.enable(ns)
    A.eq(P.visibleArt(c, R, frame), "", "the basic frame's corners, edges and inset border are held")
    A.eq(P.hiddenKeep(c, R, frame), "", "the taxi map stays")
end)

h.test("Windows skins rows a window's list refills after it was applied", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local frame = P.window(c, "AddonList")
    local box = P.scrollBox(frame)
    W.enable(ns)
    local late = P.new()
    local row = CreateFrame("Button", nil, box.ScrollTarget)
    local check = P.checkbox(late, row)
    box:Update()
    A.eq(P.visibleArt(late, R, frame), "", "a pooled row's checkbox is skinned on the list update")
    A.ok(W.isDark(check) or #check._regions > 3, "the checkbox has its own square")
    ns.Modern.Restore()
    local again = P.new()
    P.checkbox(again, CreateFrame("Button", nil, box.ScrollTarget))
    box:Update()
    A.ok(P.visibleArt(again, R, frame) ~= "", "nothing is skinned while the area is off")
end)

h.test("Windows keeps a tooltip inside a window and gives a dialog popout its own dark panel", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local frame = P.window(c, "FriendsFrame")
    local tip = CreateFrame("Frame", "FriendsFrameNoteTooltip", frame)
    tip.NineSlice = CreateFrame("Frame", nil, tip)
    tip.NineSlice.Center = P.texture(c, tip.NineSlice, "keep", "Tooltip-Center", "BACKGROUND")
    local popout = CreateFrame("Frame", nil, frame)
    popout.Border = CreateFrame("Frame", nil, popout)
    popout.Border.Bg = P.texture(c, popout.Border, "art", "UI-DialogBox-Background", "BACKGROUND")
    W.enable(ns)
    A.eq(P.hiddenKeep(c, R, frame), "", "the tooltip keeps its backdrop")
    A.eq(P.visibleArt(c, R, frame), "", "the popout's dialog border is held")
    A.ok(W.isDark(popout), "the popout floats on a dark panel of its own")
end)
