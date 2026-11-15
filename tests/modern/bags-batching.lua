local h = ...
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local EPIC, RARE = { 0.64, 0.21, 0.93 }, { 0, 0.44, 0.87 }

local function setup(t)
    B.install()
    local bag = B.bag("ContainerFrame1")
    ContainerFrame1 = bag
    local item = B.item(bag, "ContainerFrame1Item1", EPIC)
    B.slotArt(item)
    B.atlas(item)
    W.enable(t.ns)
    t.mock:tick(0)
    return bag, item
end

h.test("Bag callbacks paint each dirty slot once per frame using its latest quality", function(t)
    local _, item = setup(t)
    local skin = t.ns.Modern.Skin("windows")
    local border, paints = skin.Border, 0
    function skin:Border(frame, ...)
        if frame == item then paints = paints + 1 end
        return border(self, frame, ...)
    end
    for _ = 1, 20 do
        B.quality(item, RARE)
        item.icon:SetTexture("Interface\\Icons\\NewItem")
        t.ns.Modern.Bags.Repaint(item)
    end
    t.assert.eq(paints, 0, "callbacks wait for the next frame")
    t.assert.ok(B.same(B.border(item), EPIC), "previous border stays until the frame runs")
    t.mock:tick(0)
    t.assert.eq(paints, 1, "all callbacks share one repaint")
    t.assert.ok(B.same(B.border(item), RARE), "the latest quality is drawn")
    t.mock:tick(0)
    t.assert.eq(paints, 1, "idle frames do not repaint")
    B.quality(item, EPIC)
    t.mock:tick(0)
    t.assert.eq(paints, 2, "later changes schedule another repaint")
    t.assert.ok(B.same(B.border(item), EPIC))
end)

h.test("Turning Modern off discards queued slot work and restores the icon", function(t)
    local _, item = setup(t)
    B.empty(item)
    t.ns.Modern.Restore()
    t.mock:tick(0)
    t.assert.eq(B.border(item), nil, "queued work must not resurrect the border")
    t.assert.alpha(item.icon, 1, "queued work must not hold the restored icon")
    t.assert.eq(#t.mock.printed, 0)
    W.enable(t.ns)
    t.mock:tick(0)
    t.assert.ok(B.same(B.border(item), t.ns.Modern.Theme().wellEdge), "re-enabling paints current state")
end)


h.test("Unchanged bag icon churn does not repaint, but quality and quest borders still update", function(t)
    local _, item = setup(t)
    local skin = t.ns.Modern.Skin("windows")
    local original, paints = skin.Border, 0
    function skin:Border(frame, ...)
        if frame == item then paints = paints + 1 end
        return original(self, frame, ...)
    end

    -- Texture refreshes do not change the material appearance of the slot.
    for i = 1, 20 do
        item.icon:SetTexture("Interface\\\\Icons\\\\NewItem")
        t.ns.Modern.Bags.Repaint(item)
        t.mock:tick(0)
    end
    t.assert.eq(paints, 0, "unchanged icon callbacks do not repaint")

    B.quality(item, RARE)
    t.mock:tick(0)
    t.assert.eq(paints, 1, "quality change repaints exactly once")
    t.assert.ok(B.same(B.border(item), RARE))

    B.quest(item, true)
    t.mock:tick(0)
    t.assert.eq(paints, 2, "quest accent repaints exactly once")
    t.assert.ok(B.same(B.border(item), t.ns.Modern.Theme().accent))

    B.quest(item, false)
    t.mock:tick(0)
    t.assert.eq(paints, 3, "removing quest accent restores quality border")
    t.assert.ok(B.same(B.border(item), RARE))

    t.ns.Modern.Restore()
    W.enable(t.ns)
    t.mock:tick(0)
    t.assert.ok(B.same(B.border(item), RARE), "restoring and reapplying paints again")
end)
