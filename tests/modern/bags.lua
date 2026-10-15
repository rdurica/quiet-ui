-- Bags on the 12.0 client: item buttons from Items / EnumerateValidItems, button.icon, and an IconBorder whose
-- colour and visibility Blizzard updates per item.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local EPIC, RARE = { 0.64, 0.21, 0.93 }, { 0, 0.44, 0.87 }

local function setup(ns)
    W.area(ns, "windows")
    B.install()
    local bag = B.bag("ContainerFrame1")
    ContainerFrame1 = bag
    local combined = B.bag("ContainerFrameCombinedBags")
    ContainerFrameCombinedBags = combined
    return bag, combined
end

h.test("Bags zoom item icons, hold IconBorder hidden and draw a border in the current quality colour", function(t)
    local A, ns = t.assert, t.ns
    local bag, combined = setup(ns)
    local epic = B.item(bag, "ContainerFrame1Item1", EPIC)
    local plain = B.item(bag, "ContainerFrame1Item2")
    local other = B.item(combined, "ContainerFrameCombinedBagsItem1", RARE)
    W.enable(ns)
    local theme = ns.Modern.Theme().border
    for _, button in ipairs({ epic, plain, other }) do
        A.ok(L.zoomed(button.icon), button:GetName() .. " icon is square-cropped")
    end
    A.ok(R.invisible(epic.IconBorder, bag), "Blizzard IconBorder is not visible")
    A.ok(B.same(B.border(epic), EPIC), "epic item gets an epic coloured 1 px border")
    A.ok(B.same(B.border(other), RARE), "combined-bag item gets its own quality colour")
    A.ok(B.same(B.border(plain), theme), "an item without quality gets the theme border")
    -- Blizzard updates the item: quality changes, then clears.
    B.quality(epic, RARE)
    A.ok(R.invisible(epic.IconBorder, bag), "IconBorder is still hidden after Blizzard shows it again")
    A.ok(B.same(B.border(epic), RARE), "the border follows the new quality colour")
    B.quality(epic, nil)
    A.ok(B.same(B.border(epic), theme), "the border returns to the theme colour when the quality goes")
    B.quality(plain, EPIC)
    A.ok(B.same(B.border(plain), EPIC), "an item that gains quality gets that colour")
    A.ok(R.invisible(plain.IconBorder, bag), "its IconBorder stays hidden")
end)

h.test("Bags hide the 12.0 bag chrome behind a dark panel; separate bags keep Blizzard stacking", function(t)
    local A, ns = t.assert, t.ns
    local bag, combined = setup(ns)
    B.item(bag, "ContainerFrame1Item1", EPIC)
    W.enable(ns)
    for _, frame in ipairs({ bag, combined }) do
        A.eq(R.visibleChrome(frame), "", frame:GetName() .. " chrome is hidden")
        A.ok(R.dark(frame), frame:GetName() .. " has a dark panel")
        A.alpha(frame.TitleContainer.TitleText, 1, frame:GetName() .. " title stays")
    end
    A.eq(L.handle(bag), nil, "a separate bag keeps Blizzard stacking")
end)

h.test("Bags opened or updated after Modernize applied are skinned too", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bag = setup(ns)
    local first = B.item(bag, "ContainerFrame1Item1", EPIC)
    W.enable(ns)
    local late = B.bag("ContainerFrame2")
    ContainerFrame2 = late
    local lateItem = B.item(late, "ContainerFrame2Item1", RARE)
    B.refresh(mock, late)
    A.ok(R.dark(late), "a bag created later gets the dark panel")
    A.eq(R.visibleChrome(late), "", "its chrome is hidden")
    A.ok(L.zoomed(lateItem.icon), "its icon is zoomed")
    A.ok(R.invisible(lateItem.IconBorder, late), "its IconBorder is hidden")
    A.ok(B.same(B.border(lateItem), RARE), "its border shows the quality")
    local added = B.item(bag, "ContainerFrame1Item2", EPIC)
    B.refresh(mock, bag)
    A.ok(L.zoomed(added.icon), "an item button added to an existing bag is zoomed")
    A.ok(B.same(B.border(added), EPIC), "and gets its quality border")
    A.ok(B.same(B.border(first), EPIC), "existing items keep theirs")
end)

h.test("Bags restore icons, IconBorder and chrome when the area turns off or Modern restores", function(t)
    local A, ns = t.assert, t.ns
    local bag, combined = setup(ns)
    local item = B.item(bag, "ContainerFrame1Item1", EPIC)
    local other = B.item(combined, "ContainerFrameCombinedBagsItem1")
    local list = {}
    for _, root in ipairs({ bag, combined }) do for _, object in ipairs(R.all(root)) do list[#list + 1] = object end end
    before = L.snapshot(list)
    W.enable(ns)
    A.ok(L.zoomed(item.icon) and B.same(B.border(item), EPIC), "the bag was skinned before turning off")
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "area off restores bags")
    B.quality(item, RARE)
    A.eq(item.IconBorder._shown, true, "Blizzard's IconBorder works normally again")
    A.eq(item.IconBorder._alpha, 1)
    A.eq(B.border(item), nil, "no addon border remains after area off")
    B.quality(other, nil)
    W.enable(ns)
    ns.Modern.Restore()
    B.quality(item, EPIC)
    A.eq(B.border(item), nil, "no addon border after Restore either")
end)

h.test("Bags skin the buttons of a pool style iterator that yields (button, true)", function(t)
    local A, ns = t.assert, t.ns
    local bag = setup(ns)
    local epic = B.item(bag, "ContainerFrame1Item1", EPIC)
    local pool = { [epic] = true }
    function bag:EnumerateValidItems() return pairs(pool) end
    bag.Items = {}
    W.enable(ns)
    A.ok(L.zoomed(epic.icon), "the pooled button icon is square-cropped")
    A.ok(B.same(B.border(epic), EPIC), "the pooled button gets its quality border")
end)

h.test("Bags draw square slots and a flat search box, leave bare money text and hide the gamepad bag bar", function(t)
    local A, ns = t.assert, t.ns
    local bag, combined = setup(ns)
    local quest = B.item(bag, "ContainerFrame1Item1", RARE)
    local empty = B.item(bag, "ContainerFrame1Item2")
    local art = {}
    for _, button in ipairs({ quest, empty }) do
        for _, texture in ipairs(B.slotArt(button)) do art[#art + 1] = texture end
    end
    combined.MoneyFrame = CreateFrame("Frame", nil, combined)
    combined.MoneyFrame.Border = B.field(nil, combined.MoneyFrame)
    BagItemSearchBox = B.field("BagItemSearchBox", combined)
    GamepadBagBar = CreateFrame("Frame", "GamepadBagBar", combined)
    GamepadBagBar:SetAlpha(1)
    local backpack = CreateFrame("Button", "GamepadBackpackButton", GamepadBagBar)
    backpack:EnableMouse(true)
    local dropdown = CreateFrame("Button", nil, backpack)
    dropdown:EnableMouse(true)
    B.quest(quest, true)
    local list = {}
    for _, object in ipairs(R.all(combined)) do list[#list + 1] = object end
    for _, object in ipairs(R.all(bag)) do list[#list + 1] = object end
    local before = L.snapshot(list)
    W.enable(ns)
    for _, texture in ipairs(art) do
        A.ok(R.invisible(texture, texture._parent._parent), tostring(texture._texture) .. " is held hidden")
    end
    for _, button in ipairs({ quest, empty }) do A.ok(R.dark(button), button:GetName() .. " has a dark slot fill") end
    A.ok(B.same(B.border(quest), ns.Modern.Theme().accent), "a quest item gets the accent border")
    B.quest(quest, false)
    A.ok(B.same(B.border(quest), RARE), "the quality colour returns when the quest mark goes")
    B.quest(quest, true)
    A.ok(B.same(B.border(quest), ns.Modern.Theme().accent), "and the accent when Blizzard marks it again")
    for _, field in ipairs({ BagItemSearchBox, combined.MoneyFrame.Border }) do
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            A.ok(R.invisible(field[key], field), key .. " field art is held hidden")
        end
    end
    A.ok(R.dark(BagItemSearchBox), "the search box has a dark fill")
    A.ok(not R.dark(combined.MoneyFrame.Border), "the money bar has no fill: money is bare text on the bag")
    A.eq(B.border(combined.MoneyFrame.Border), nil, "and no border")
    A.ok(R.invisible(GamepadBagBar, combined), "the gamepad bag bar docked at the bag is held invisible")
    GamepadBagBar:SetAlpha(1)
    A.ok(R.invisible(GamepadBagBar, combined), "Blizzard's SetAlpha does not bring it back")
    A.eq(backpack:IsMouseEnabled(), false, "the invisible backpack button lets clicks through to the sort button")
    A.eq(dropdown:IsMouseEnabled(), false, "and so does its bag dropdown")
    B.quest(quest, true)
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns the slot and field art")

end)

h.test("The combined bag is dragged by its title, keeps the saved point when Blizzard re-anchors bags and returns on area off", function(t)
    local A, ns = t.assert, t.ns
    _G.UpdateContainerFrameAnchors = function() end
    ns.Registry.InstallHooks()
    local _, combined = setup(ns)
    L.blizzardPoint(combined, "BOTTOMRIGHT", -20, 100)
    W.enable(ns)
    L.drag(combined, "CENTER", "CENTER", 40, -30)
    A.deep(QuietUICharDB.windowPoints.ContainerFrameCombinedBags, { "CENTER", "CENTER", 40, -30 }, "the point is saved")
    L.blizzardPoint(combined, "BOTTOMRIGHT", -20, 100)
    UpdateContainerFrameAnchors()
    A.deep(W.point(combined), { "CENTER", "CENTER", 40, -30 }, "the saved point wins over Blizzard's bag anchors")
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(W.point(combined), { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 100 }, "area off returns Blizzard's point")
    A.deep(QuietUICharDB.windowPoints.ContainerFrameCombinedBags, { "CENTER", "CENTER", 40, -30 }, "the saved point remains")
end)

h.test("The combined bag drag handle lies over a TitleContainer that sits far above the bag's children", function(t)
    local A, ns = t.assert, t.ns
    local _, combined = setup(ns)
    combined.TitleContainer:SetFrameLevel(510)
    W.enable(ns)
    local handle = L.handle(combined)
    A.ok(handle, "the combined bag has a drag handle")
    A.ok(handle:GetFrameLevel() > 510, "the handle is above the title container")
    A.eq(handle._points[1][2], combined.TitleContainer, "the handle covers the title container")
end)

h.test("Item buttons a bag acquires when it opens are skinned on show", function(t)
    local A, ns = t.assert, t.ns
    local bag = setup(ns)
    W.enable(ns)
    local late = B.item(bag, "ContainerFrame1Item1", EPIC)
    bag:Hide(); bag:Show()
    A.ok(L.zoomed(late.icon), "the button acquired on open is square-cropped")
    A.ok(B.same(B.border(late), EPIC), "and gets its quality border")
end)

h.test("An empty slot's wing atlas on the icon is held invisible and an item placed there shows its icon", function(t)
    local A, ns = t.assert, t.ns
    local bag = setup(ns)
    local slot = B.item(bag, "ContainerFrame1Item1")
    local item = B.item(bag, "ContainerFrame1Item2", EPIC)
    B.atlas(slot); B.atlas(item)
    B.empty(slot)
    item.icon:SetAlpha(1)
    W.enable(ns)
    A.ok(R.invisible(slot.icon, slot), "the empty-slot wing is invisible")
    A.alpha(item.icon, 1, "a filled slot keeps its icon")
    B.fill(slot, "Interface\\Icons\\INV_Misc_Bag")
    A.alpha(slot.icon, 1, "an item placed in the slot shows its icon")
    B.empty(item)
    A.ok(R.invisible(item.icon, item), "a slot that empties hides the wing")
    item.icon:SetAlpha(1)
    A.ok(R.invisible(item.icon, item), "Blizzard's SetAlpha does not bring the wing back")
    B.fill(item, "Interface\\Icons\\ContainerFrame1Item2")
    B.empty(slot)
    ns.Modern.Restore()
    B.empty(item); B.fill(slot, "Interface\\Icons\\ContainerFrame1Item1")
    A.alpha(item.icon, 1, "after Restore the wing is Blizzard's again")
    B.fill(item, "Interface\\Icons\\ContainerFrame1Item2"); B.empty(slot)
end)
