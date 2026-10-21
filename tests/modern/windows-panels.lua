-- The plainer windows of the Forever UI source: BankFrame (PortraitFrameTemplate with a Background atlas, the
-- bank-divider, a BankPanel whose RefreshBankPanel fills pooled item buttons), PetStableFrame (stable backdrops and
-- PetStableSlotTemplate slots with a named $parentIconTexture), PetitionFrame (a parchment Bg and dark ink) and
-- FlightMapFrame (MapCanvas: chrome on BorderFrame, pins on the canvas).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")

local function bank(c)
    local frame = P.window(c, "BankFrame")
    frame.Background = P.texture(c, frame, "art", "bank-frame-background", "BACKGROUND", { atlas = true })
    P.texture(c, frame, "art", "bank-divider", "ARTWORK", { atlas = true })
    local panel = CreateFrame("Frame", "BankPanel", frame)
    frame.BankPanel = panel
    function panel:RefreshBankPanel() end
    return frame, panel
end

local function stableSlot(c, parent, name)
    local slot = CreateFrame("CheckButton", name, parent)
    P.texture(c, slot, "keep", "Icons\\Ability_Hunter_Pet_Wolf", "BORDER", { name = name .. "IconTexture" })
    for _, key in ipairs({ "unlockedBackground", "currentBackground", "lockedBackground" }) do
        slot[key] = P.texture(c, slot, "art", "ui-stables-pet-frame-" .. key, "ARTWORK", { atlas = true })
    end
    return slot
end

h.test("Windows skins the bank, the stable and a petition, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = P.new()
    local frame, panel = bank(c)
    local item = P.itemButton(c, panel, "BankItem1")
    local stable = P.window(c, "PetStableFrame")
    P.texture(c, stable, "art", "ui-stables-footer-bg", "BACKGROUND", { atlas = true })
    local slot = stableSlot(c, stable, "PetStableStabledPet1")
    local petition = P.window(c, "PetitionFrame")
    P.texture(c, petition, "art", "GuildCharter-Icon", "OVERLAY", { name = "PetitionFramePortrait" })
    local charter = P.text(c, petition, "We the undersigned")
    charter:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    charter:SetTextColor(0.18, 0.12, 0.06, 1)
    local before = L.snapshot(R.all(UIParent))
    W.enable(ns)
    A.ok(W.isDark(frame) and W.isDark(stable) and W.isDark(petition), "bank, stable and petition are dark windows")
    A.eq(P.visibleArt(c, R), "", "backdrops, dividers, slot frames, portraits and chrome are held")
    A.eq(P.hiddenKeep(c, R), "", "pet icons, item icons and texts stay")
    A.ok(L.zoomed(item.icon), "a bank item is square-cropped")
    A.ok(L.zoomed(_G.PetStableStabledPet1IconTexture), "a stabled pet's icon is cropped")
    A.ok(#slot._regions > 4, "a stabled pet's slot gets its own socket and border")
    A.ok(charter:GetTextColor() > 0.5, "the petition text is light")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "bank, stable and petition restore exactly")
end)

h.test("Windows skins bank slots the bank panel fills for a new page", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local _, panel = bank(c)
    W.enable(ns)
    local late = P.new()
    local item = P.itemButton(late, panel, "BankItem9")
    panel:RefreshBankPanel()
    A.ok(L.zoomed(item.icon), "a slot added for the new page is square-cropped")
    A.eq(P.visibleArt(late, R), "", "its slot art is held")
end)

h.test("Windows gives the flight map its window chrome and leaves the canvas alone", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local map = CreateFrame("Frame", "FlightMapFrame", UIParent)
    map.BorderFrame = P.window(c, nil, map)
    map.BorderFrame.TopBorder = P.texture(c, map.BorderFrame, "art", "AdventureMap_TopBorder", "BORDER",
        { atlas = true })
    map.ScrollContainer = CreateFrame("ScrollFrame", nil, map)
    local pin = P.panelButton(P.new(), map.ScrollContainer, "", "FlightPin1")
    W.enable(ns)
    A.ok(W.isDark(map), "the flight map is a dark window")
    A.eq(P.visibleArt(c, R), "", "the border frame's chrome is held")
    A.ok(not W.isDark(pin) and not R.invisible(pin.Left, map), "a pin on the canvas is not walked")
end)
