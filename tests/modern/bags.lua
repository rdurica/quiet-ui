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

h.test("Bags hide the 12.0 bag chrome behind a dark panel and keep Blizzard stacking", function(t)
    local A, ns = t.assert, t.ns
    local bag, combined = setup(ns)
    B.item(bag, "ContainerFrame1Item1", EPIC)
    W.enable(ns)
    for _, frame in ipairs({ bag, combined }) do
        A.eq(R.visibleChrome(frame), "", frame:GetName() .. " chrome is hidden")
        A.ok(R.dark(frame), frame:GetName() .. " has a dark panel")
        A.alpha(frame.TitleContainer.TitleText, 1, frame:GetName() .. " title stays")
        A.eq(L.handle(frame), nil, frame:GetName() .. " keeps Blizzard stacking")
    end
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
