-- Character window equipment slots and the model scene backdrop: all slot art is held (not a named list), the weapon
-- slots are found wherever they nest, empty slots are sockets, filled ones icons, and the model scene stays.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
local S = h.lib("modern-slots")
B.use(R)
S.use(R, B)

local GREEN, BLUE = { 0.12, 1, 0 }, { 0, 0.44, 0.87 }

local function setup(ns, opts)
    W.area(ns, "windows")
    local gear = S.gear()
    return S.window(opts), gear
end

local function heldAll(A, c, slot, label)
    for _, texture in ipairs(slot.extras) do
        A.ok(R.invisible(texture, slot), label .. " extra art is held: " .. tostring(texture._texture))
    end
end

h.test("Every equipment slot, weapons and an unnamed nested one included, holds all its extra art", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c, gear = setup(ns)
    gear.equip(c.head, 3)
    t.mock:tick(0)
    W.enable(ns)
    t.mock:tick(0)
    local labels = { "head", "main hand", "off hand", "ranged", "unnamed nested weapon" }
    for index, slot in ipairs(c.slots) do heldAll(A, c, slot, labels[index]) end
    A.ok(not R.invisible(c.head.icon, c.head), "a filled slot keeps its icon")
    A.ok(B.border(c.head) ~= nil, "the skin's own border stays visible")
    A.ok(S.shown(c.main, "BACKGROUND", ns.Modern.Theme().well), "an empty slot keeps the skin's own socket")
    -- The window opens again: the skin's own regions must not be held with Blizzard's.
    c.frame:Hide()
    c.frame:Show()
    t.mock:tick(0)
    A.ok(B.border(c.head) ~= nil, "the border survives the next refresh")
    A.ok(S.shown(c.main, "BACKGROUND", ns.Modern.Theme().well), "so does the socket")
    A.ok(S.shown(c.loose, "BACKGROUND", ns.Modern.Theme().well), "also on the unnamed nested slot")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("An empty equipment slot is a flat dark socket; a filled one a cropped icon, framed from uncommon up", function(t)
    local A, ns = t.assert, t.ns
    local c, gear = setup(ns)
    gear.equip(c.off, 2)
    t.mock:tick(0)
    gear.equip(c.ranged, 1)
    t.mock:tick(0)
    gear.equip(c.loose, 3)
    t.mock:tick(0)
    W.enable(ns)
    t.mock:tick(0)
    local theme = ns.Modern.Theme()
    A.ok(B.same(B.border(c.main), theme.wellEdge), "the empty main hand has the quieter well edge, like a bag slot")
    A.ok(S.shown(c.main, "BACKGROUND", theme.well), "and the dark socket fill")
    A.ok(R.invisible(c.main.icon, c.main), "the empty-slot wing is invisible")
    A.ok(not S.shown(c.main, "ARTWORK"), "no light over an empty slot")
    for _, slot in ipairs({ c.off, c.ranged, c.loose }) do
        A.ok(L.zoomed(slot.icon), "a filled slot's icon is square-cropped")
        A.ok(not R.invisible(slot.icon, slot), "and shown")
        A.ok(not S.shown(slot, "BACKGROUND", theme.well), "without the socket")
        A.ok(S.shown(slot, "ARTWORK"), "with a soft light over the icon")
    end
    A.ok(B.same(B.border(c.off), GREEN), "an uncommon item is framed green")
    A.ok(B.same(B.border(c.loose), BLUE), "a rare item on the unnamed nested slot is framed blue")
    A.ok(B.same(B.border(c.ranged), theme.border), "a common item keeps the theme border, not white")
end)

h.test("Equipping or removing an item flips the slot between socket and icon without reopening", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c, gear = setup(ns)
    W.enable(ns)
    t.mock:tick(0)
    local theme = ns.Modern.Theme()
    for _, slot in ipairs({ c.main, c.loose }) do
        local name = slot:GetName() or "unnamed nested slot"
        A.ok(S.shown(slot, "BACKGROUND", theme.well), name .. " starts as a socket")
        gear.equip(slot, 2)
        t.mock:tick(0)
        A.ok(not S.shown(slot, "BACKGROUND", theme.well), name .. " drops the socket when an item is equipped")
        A.ok(B.same(B.border(slot), GREEN), name .. " gets the quality border")
        A.ok(not R.invisible(slot.icon, slot), name .. " shows the icon")
        gear.remove(slot)
        t.mock:tick(0)
        A.ok(S.shown(slot, "BACKGROUND", theme.well), name .. " is a socket again when the item is removed")
        A.ok(B.same(B.border(slot), theme.wellEdge), name .. " has the well edge again")
        A.ok(R.invisible(slot.icon, slot), name .. " hides the wing again")
    end
    -- The event path: the server changes the item, Blizzard updates the button, the event arrives.
    gear.equip(c.loose, 3)
    t.mock:tick(0)
    mock:fire("PLAYER_EQUIPMENT_CHANGED")
    mock:drain()
    t.mock:tick(0)
    A.ok(B.same(B.border(c.loose), BLUE), "PLAYER_EQUIPMENT_CHANGED keeps the nested slot painted")
    A.ok(L.zoomed(c.loose.icon), "and its icon cropped")
end)

h.test("A weapon slot below a child frame of PaperDollItemsFrame is skinned, with or without a global name", function(t)
    local A, ns = t.assert, t.ns
    local c = setup(ns)
    local late = S.slot(c.row, nil, 20)
    W.enable(ns)
    t.mock:tick(0)
    for _, slot in ipairs({ c.main, c.off, c.ranged, c.loose }) do
        A.ok(L.zoomed(slot.icon), (slot:GetName() or "unnamed slot") .. " icon is cropped")
        A.ok(B.border(slot) ~= nil, "and has a flat border")
        A.ok(R.invisible(slot.IconBorder, slot), "and its IconBorder is held")
    end
    -- A slot acquired after apply is skinned when the window opens again.
    c.frame:Hide()
    c.frame:Show()
    t.mock:tick(0)
    A.ok(L.zoomed(late.icon) and B.border(late) ~= nil, "a slot created later is skinned on the next show")
    heldAll(A, c, late, "late slot")
end)

h.test("The model scene backdrop is held while the scene, actor and controls stay unchanged", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c = setup(ns)
    local keep = { c.scene, c.actor, c.scene.ControlFrame, c.zoom }
    local before = L.snapshot(keep)
    local points, w, h2 = { c.scene:GetPoint(1) }, c.scene:GetSize()
    W.enable(ns)
    t.mock:tick(0)
    for _, texture in ipairs(c.backdrop) do
        A.ok(R.invisible(texture, c.scene), "backdrop art is held: " .. tostring(texture._texture))
    end
    for _, object in ipairs(keep) do
        A.ok(not R.invisible(object, c.frame), (object:GetName() or object._kind) .. " stays shown")
    end
    A.ok(not R.invisible(c.zoom.Icon, c.frame), "the control icon stays")
    A.deep({ c.scene:GetPoint(1) }, points, "the scene keeps its point")
    A.deep({ c.scene:GetSize() }, { w, h2 }, "and its size")
    A.eq(c.scene._alpha, before[c.scene]._alpha, "and its alpha")
    A.eq(#mock.printed, 0, "nothing reported")
    local after = L.diff(before)
    for _, field in ipairs(after) do
        A.ok(not field:find("_points") and not field:find("_shown") and not field:find("_alpha")
            and not field:find("_w") and not field:find("_h"), "unchanged: " .. field)
    end
end)

h.test("Restore brings back every slot texture, the icon crop and the backdrop exactly", function(t)
    local A, ns = t.assert, t.ns
    local c, gear = setup(ns)
    gear.equip(c.head, 2)
    t.mock:tick(0)
    gear.equip(c.off, 3)
    t.mock:tick(0)
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    t.mock:tick(0)
    A.ok(R.invisible(c.main.extras[1], c.main) and R.invisible(c.backdrop[1], c.scene), "the art was held before Restore")
    gear.remove(c.off)
    t.mock:tick(0)
    gear.equip(c.main, 2)
    t.mock:tick(0)
    gear.remove(c.main)
    t.mock:tick(0)
    gear.equip(c.off, 3)
    t.mock:tick(0)
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns slots, icons and backdrop")
    QuietUICharDB.modernize.windows = false
    W.enable(ns, { windows = false })
    t.mock:tick(0)
    A.deep(L.diff(before), {}, "the area off returns them as well")
end)

h.test("Slot and backdrop regions that are missing or forbidden are skipped without an error", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c = setup(ns, { scene = false })
    W.enable(ns)
    t.mock:tick(0)
    A.eq(#mock.printed, 0, "no model scene: nothing reported")
    heldAll(A, c, c.main, "main hand")
end)

h.test("Slots without BorderFrame are skinned and held without an error", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c = setup(ns, { noBorderFrame = true })
    W.enable(ns)
    t.mock:tick(0)
    A.eq(#mock.printed, 0, "nothing reported")
    for _, slot in ipairs(c.slots) do
        A.ok(L.zoomed(slot.icon) or slot.icon:GetAtlas() ~= nil, "the slot is skinned")
        heldAll(A, c, slot, slot:GetName() or "unnamed slot")
    end
end)

h.test("A forbidden slot, slot child frame or model scene is skipped while the others are skinned", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local c = setup(ns)
    local forbiddenSlot = S.slot(c.row, "CharacterAmmoSlot", 21)
    forbiddenSlot._forbidden = true
    c.main.Backing._forbidden = true
    c.scene._forbidden = true
    W.enable(ns)
    t.mock:tick(0)
    A.eq(#mock.printed, 0, "nothing reported")
    A.ok(L.zoomed(c.off.icon) and B.border(c.off) ~= nil, "another slot is skinned")
    heldAll(A, c, c.off, "off hand")
    A.ok(R.invisible(c.main.extras[1], c.main), "the usable art of the slot with a forbidden child is held")
    A.falsy(L.zoomed(forbiddenSlot.icon), "the forbidden slot is left alone")
end)

h.test("An empty slot with Blizzard's rounded placeholder art, not the wing atlas, is a square socket", function(t)
    local A, ns = t.assert, t.ns
    local c, gear = setup(ns)
    -- Forever paints an empty equipment slot with a placeholder texture file (UI-PaperDoll-Slot-*).
    PaperDollItemSlotButton_Update = function(slot)
        local texture = GetInventoryItemTexture("player", slot:GetID())
        slot.icon:SetTexture(texture or ("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slot:GetID()))
    end
    for _, slot in ipairs(c.slots) do PaperDollItemSlotButton_Update(slot) end
    gear.equip(c.off, 2)
    t.mock:tick(0)
    W.enable(ns)
    t.mock:tick(0)
    local theme = ns.Modern.Theme()
    A.ok(S.shown(c.main, "BACKGROUND", theme.well), "the empty main hand is a socket")
    A.ok(B.same(B.border(c.main), theme.wellEdge), "with the well edge")
    A.ok(R.invisible(c.main.icon, c.main), "and its rounded placeholder is held")
    A.ok(not R.invisible(c.off.icon, c.off), "a filled slot shows its icon")
    gear.remove(c.off)
    t.mock:tick(0)
    A.ok(S.shown(c.off, "BACKGROUND", theme.well), "removing the item makes it a socket")
    A.ok(R.invisible(c.off.icon, c.off), "and holds the placeholder")
    gear.equip(c.main, 3)
    t.mock:tick(0)
    A.ok(not R.invisible(c.main.icon, c.main), "equipping shows the item's icon again")
    A.ok(B.same(B.border(c.main), BLUE), "framed in its quality colour")
    ns.Modern.Restore()
    A.ok(not R.invisible(c.off.icon, c.off), "restore gives the placeholder back")
end)
