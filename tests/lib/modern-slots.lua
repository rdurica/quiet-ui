-- Character window equipment slots and model scene, shaped after the Forever 12.0 dump: every slot carries extra
-- art of unknown names (a bevel and a glow on the slot, BorderFrame art, another child frame's art), the weapon slots
-- sit one level below a child frame of PaperDollItemsFrame, and CharacterModelScene has a backdrop, extra
-- background regions, a background child frame, an actor and a ControlFrame with a zoom button.
local S = {}
local R, Bags  -- modern-windows-retail and modern-bags, passed through S.use

function S.use(retail, bags) R, Bags = retail, bags end

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Forever\\" .. name)
    texture:SetAlpha(0.9)
    list[#list + 1] = texture
    return texture
end

-- An equipment ItemButton (empty: the wing atlas on its icon). `slot.extras` lists every texture that must be held:
-- two on the slot, BorderFrame's, and two on another child frame. opts.noBorderFrame leaves BorderFrame out.
function S.slot(parent, name, id, opts)
    opts = opts or {}
    local slot = CreateFrame("ItemButton", name, parent)
    slot:SetSize(36, 36)
    function slot:GetID() return id end
    slot.icon = slot:CreateTexture(nil, "BORDER")
    slot.icon:SetTexture("Interface\\Icons\\Empty" .. id)
    slot.icon:SetTexCoord(0, 1, 0, 1)
    Bags.atlas(slot)
    Bags.empty(slot)
    slot.IconBorder = slot:CreateTexture(nil, "OVERLAY")
    slot.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    slot.IconBorder:Hide()
    slot.extras = {}
    art(slot, slot.extras, "Bevel" .. id, "BACKGROUND")
    art(slot, slot.extras, "Glow" .. id, "OVERLAY")
    if not opts.noBorderFrame then
        slot.BorderFrame = CreateFrame("Frame", nil, slot)
        art(slot.BorderFrame, slot.extras, "GearSlot" .. id, "BACKGROUND")
    end
    slot.Backing = CreateFrame("Frame", nil, slot)
    art(slot.Backing, slot.extras, "Backing" .. id, "BACKGROUND")
    art(slot.Backing, slot.extras, "BackingEdge" .. id, "BORDER")
    return slot
end

-- The window. c.slots: Head (direct child), MainHand / SecondaryHand / Ranged (global names, below c.row) and
-- c.loose (no global name, one level below c.extras). opts.scene == false builds no model scene.
function S.window(opts)
    opts = opts or {}
    local c = { slots = {} }
    c.frame = R.window("CharacterFrame")
    CharacterFrame = c.frame
    local paperdoll = CreateFrame("Frame", "PaperDollFrame", c.frame)
    PaperDollFrame = paperdoll
    local items = CreateFrame("Frame", "PaperDollItemsFrame", paperdoll)
    PaperDollItemsFrame = items
    c.items = items
    c.head = S.slot(items, "CharacterHeadSlot", 1)
    CharacterHeadSlot = c.head
    c.row = CreateFrame("Frame", nil, items)
    c.main = S.slot(c.row, "CharacterMainHandSlot", 16, opts)
    c.off = S.slot(c.row, "CharacterSecondaryHandSlot", 17, opts)
    c.ranged = S.slot(c.row, "CharacterRangedSlot", 18, opts)
    CharacterMainHandSlot, CharacterSecondaryHandSlot, CharacterRangedSlot = c.main, c.off, c.ranged
    c.extras = CreateFrame("Frame", nil, items)
    c.loose = S.slot(c.extras, nil, 19, opts)
    c.slots = { c.head, c.main, c.off, c.ranged, c.loose }
    if opts.scene == false then return c end

    local scene = CreateFrame("ModelScene", "CharacterModelScene", paperdoll)
    CharacterModelScene = scene
    c.scene = scene
    scene:SetSize(300, 360)
    scene:SetPoint("CENTER", paperdoll, "CENTER", 0, 10)
    c.backdrop = {}
    scene.backdrop = art(scene, c.backdrop, "RaceBackground", "BACKGROUND")
    scene.Vignette = art(scene, c.backdrop, "Vignette", "OVERLAY")
    scene.Background = CreateFrame("Frame", nil, scene)
    art(scene.Background, c.backdrop, "SceneBg", "BACKGROUND")
    art(scene.Background, c.backdrop, "SceneEdge", "BORDER")
    c.actor = CreateFrame("PlayerModel", nil, scene)
    scene.Actor = c.actor
    scene.ControlFrame = CreateFrame("Frame", nil, scene)
    c.zoom = CreateFrame("Button", nil, scene.ControlFrame)
    scene.ControlFrame.zoomInButton = c.zoom
    c.zoom.Icon = c.zoom:CreateTexture(nil, "OVERLAY")
    c.zoom.Icon:SetTexture("Interface\\Common\\ZoomIn")
    c.zoom.Icon:SetVertexColor(1, 1, 1, 1)
    c.zoom.Icon:SetDesaturated(false)
    return c
end

-- What the server says about the worn items: id -> { texture, quality }. Defines the Blizzard globals the slot skin
-- reads; call before enabling Modern. c.equip / c.remove do what Blizzard does on a change: set the icon, update.
function S.gear()
    local worn = {}
    local gear = {}
    ITEM_QUALITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 }, [1] = { r = 1, g = 1, b = 1 },
        [2] = { r = 0.12, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 },
    }
    GetInventoryItemQuality = function(unit, id) return unit == "player" and worn[id] and worn[id].quality or nil end
    GetInventoryItemTexture = function(unit, id) return unit == "player" and worn[id] and worn[id].texture or nil end
    PaperDollItemSlotButton_Update = function(slot)
        local item = worn[slot:GetID()]
        if item then slot.icon:SetTexture(item.texture) else slot.icon:SetAtlas("bags-item-slot64") end
    end
    function gear.equip(slot, quality)
        worn[slot:GetID()] = { texture = "Interface\\Icons\\Item" .. slot:GetID(), quality = quality }
        PaperDollItemSlotButton_Update(slot)
    end
    function gear.remove(slot)
        worn[slot:GetID()] = nil
        PaperDollItemSlotButton_Update(slot)
    end
    return gear
end

-- True when a visible region of the given layer (and colour, when given) was drawn on the button.
function S.shown(button, layer, color)
    for _, region in ipairs(button._regions) do
        if region._layer == layer and region._shown and region._color
            and (not color or Bags.same(region._color, color)) then return true end
    end
    return false
end

return S
