local _, ns = ...

-- Bag windows (ContainerFrameN and ContainerFrameCombinedBags): dark chrome with a header band, square slots like the
-- action bars and a flat border in the item's quality colour from common up (the accent for quest
-- items). The combined bag has a title drag handle; separate bags keep Blizzard
-- stacking, so they get none.

local Modern = ns.Modern
local Bags = {}
Modern.Bags = Bags

local MAX_BAGS = 20
local styled = setmetatable({}, { __mode = "k" })  -- window or item button -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })
local empty = setmetatable({}, { __mode = "k" })   -- empty-slot icon -> true while held
local worn = setmetatable({}, { __mode = "k" })    -- equipment slot button -> true

local function Items(bag)
    local list, seen = {}, {}
    local function Add(button)
        if ns.Usable(button) and not seen[button] then
            seen[button] = true
            list[#list + 1] = button
        end
    end
    if type(bag.EnumerateValidItems) == "function" then
        local ok, iter, state, init = pcall(bag.EnumerateValidItems, bag)
        if ok and type(iter) == "function" then
            -- Index-and-button or pool style (button, true): the button is the table either way.
            for key, value in iter, state, init do
                Add(value)
                Add(key)
            end
        end
    end
    if type(bag.Items) == "table" then
        for _, button in pairs(bag.Items) do Add(button) end
    end
    return list
end

local function IconOf(button)
    return button.icon or button.Icon
end

-- Blizzard slot art replaced by the flat slot: the bevelled frame, the empty-slot wing and the thick quest border.
local SLOT_ART = { "ItemSlotBackground", "IconQuestTexture", "ExtendedSlot" }

local function Shown(texture)
    return ns.Usable(texture) and type(texture.IsShown) == "function" and texture:IsShown() and true or false
end

-- Poor (grey) items keep the theme border; common (white) and up are framed, uncommon and up also glow.
local MIN_QUALITY = 1

local function Call(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(func, ...)
    if ok then return a, b, c, d end
end

-- Quality read from the item itself: Forever does not colour IconBorder on every button.
local function ItemQuality(button)
    if type(button.GetID) ~= "function" then return nil end
    local slot = Call(button.GetID, button)
    local quality
    if worn[button] then
        quality = Call(_G.GetInventoryItemQuality, "player", slot)
    elseif type(button.GetBagID) == "function" then
        local bag = Call(button.GetBagID, button)
        local info = C_Container and Call(C_Container.GetContainerItemInfo, bag, slot)
        if type(info) == "table" then
            quality = info.quality
        else
            quality = select(4, Call(_G.GetContainerItemInfo, bag, slot))
        end
    end
    if type(quality) ~= "number" or ns.IsSecret(quality) then return nil end
    return quality
end

local function QualityColor(quality)
    if quality < MIN_QUALITY then return nil end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if type(color) ~= "table" then return nil end
    return { color.r, color.g, color.b, 1 }
end

-- 12.0 paints an empty slot by putting this atlas (the wing) on the item icon itself.
local EMPTY_ATLAS = "bags-item-slot64"

-- A slot without an item: the wing atlas on its icon, or (older clients) no icon texture at all.
local function Vacant(button)
    local icon = IconOf(button)
    if not ns.Usable(icon) then return false end
    if empty[icon] then return true end
    if type(icon.GetTexture) ~= "function" then return false end
    local ok, texture = pcall(icon.GetTexture, icon)
    if not ok or texture ~= nil then return false end
    local okAtlas, atlas = pcall(icon.GetAtlas or function() end, icon)
    return not (okAtlas and atlas)
end

-- Accent while Blizzard shows the quest border, else the item's quality colour (from its data, or from IconBorder
-- when the data is missing); nil for the theme border. The second value is true when the colour is a real
-- quality (uncommon and up) or the quest accent, which also tints the slot's glow.
local function SlotColor(button)
    local border = button.IconBorder
    local quality = ItemQuality(button)
    if Shown(button.IconQuestTexture) then return Modern.Theme().accent, true end
    if quality then return QualityColor(quality), quality > MIN_QUALITY end
    if Shown(border) and type(border.GetVertexColor) == "function" then
        local r, g, b, a = border:GetVertexColor()
        if type(r) == "number" and not ns.IsSecret(r) then return { r, g, b, a or 1 }, true end
    end
end

local function Gradient(texture, from, to)
    return type(texture.SetGradient) == "function" and type(CreateColor) == "function"
        and pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(unpack(from)), CreateColor(unpack(to)))
end

-- Own slot regions: behind an empty slot a socket with a lit top edge and a faint diamond mark; over an item's icon a soft light on the top
-- half and a glow of the quality colour rising from the bottom. Below the count text (ARTWORK sublevel 2).
local MARK = 8

local function Look(skin, button)
    return unpack(skin:Own(button, "slot look", function()
        local well = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        well:SetAllPoints(button)
        local sheen = button:CreateTexture(nil, "BACKGROUND", nil, -6)
        sheen:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        sheen:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
        sheen:SetHeight(1)
        local mark = button:CreateTexture(nil, "BACKGROUND", nil, -5)
        mark:SetSize(MARK, MARK)
        mark:SetPoint("CENTER", button, "CENTER", 0, 0)
        if type(mark.SetRotation) == "function" then pcall(mark.SetRotation, mark, math.rad(45)) end
        local gloss = button:CreateTexture(nil, "ARTWORK", nil, -8)
        gloss:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        gloss:SetPoint("BOTTOMRIGHT", button, "RIGHT", -1, 0)
        local glow = button:CreateTexture(nil, "ARTWORK", nil, -8)
        glow:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        glow:SetPoint("TOPRIGHT", button, "RIGHT", -1, 0)
        return { well, sheen, mark, gloss, glow }
    end))
end

local function Paint(skin, button)
    local theme = Modern.Theme()
    local well, sheen, mark, gloss, glow = Look(skin, button)
    if Vacant(button) then
        local top = theme.well
        skin:Border(button, theme.wellEdge)
        well:SetColorTexture(unpack(top))
        if not Gradient(well, { top[1] * 0.55, top[2] * 0.55, top[3] * 0.55, top[4] }, top) then
            well:SetColorTexture(unpack(top))
        end
        sheen:SetColorTexture(1, 1, 1, 0.08)
        mark:SetColorTexture(1, 1, 1, 0.07)
        for _, region in ipairs({ well, sheen, mark }) do region:Show() end
        gloss:Hide()
        glow:Hide()
        return
    end
    local color, rich = SlotColor(button)
    skin:Border(button, color)
    for _, region in ipairs({ well, sheen, mark }) do region:Hide() end
    gloss:SetColorTexture(1, 1, 1, 1)
    if not Gradient(gloss, { 1, 1, 1, 0 }, { 1, 1, 1, 0.12 }) then gloss:SetColorTexture(1, 1, 1, 0.05) end
    gloss:Show()
    glow:SetColorTexture(1, 1, 1, 1)
    if rich and Gradient(glow, { color[1], color[2], color[3], 0.2 }, { color[1], color[2], color[3], 0 }) then
        glow:Show()
    else
        glow:Hide()
    end
end

local function Follow(button)
    if hooked[button] then return end
    hooked[button] = true
    for _, texture in ipairs({ button.IconBorder, button.IconQuestTexture }) do
        if ns.Usable(texture) then
            for _, method in ipairs({ "SetVertexColor", "Show", "Hide", "SetShown" }) do
                if type(texture[method]) == "function" then
                    pcall(hooksecurefunc, texture, method, function()
                        local skin = styled[button]
                        if skin then ns.Run("modern bags", Paint, skin, button) end
                    end)
                end
            end
        end
    end
end

-- The empty-slot icon is held invisible; an item's icon gets Blizzard's alpha back.
local function Empty(skin, icon)
    local ok, atlas = pcall(icon.GetAtlas, icon)
    if ok and atlas == EMPTY_ATLAS then
        empty[icon] = true
        skin:Hold(icon)
    elseif empty[icon] then
        empty[icon] = nil
        ns.ReleaseAlpha(icon)
    end
end

local function FollowIcon(button, icon)
    if hooked[icon] or type(icon.GetAtlas) ~= "function" then return end
    hooked[icon] = true
    for _, method in ipairs({ "SetAtlas", "SetTexture" }) do
        if type(icon[method]) == "function" then
            pcall(hooksecurefunc, icon, method, function()
                local skin = styled[button]
                if not skin then return end
                ns.Run("modern bags", Empty, skin, icon)
                ns.Run("modern bags", Paint, skin, button)
            end)
        end
    end
end

local function NormalOf(button)
    if ns.Usable(button.NormalTexture) then return button.NormalTexture end
    if type(button.GetNormalTexture) ~= "function" then return nil end
    local ok, texture = pcall(button.GetNormalTexture, button)
    return ok and ns.Usable(texture) and texture or nil
end

-- One square slot; the character window's equipment slots (`equipped`) use it too. A slot already skinned is
-- only repainted.
function Bags.Item(skin, button, equipped)
    if equipped then worn[button] = true end
    if styled[button] then
        Paint(styled[button], button)
        return
    end
    styled[button] = skin
    skin:Remember(button, "modern bag item", function()
        styled[button] = nil
        local icon = IconOf(button)
        if icon then empty[icon] = nil end
    end)
    local icon = IconOf(button)
    if ns.Usable(icon) then
        skin:Icon(icon)
        Modern.NoMask(skin, icon)
        if type(icon.GetAtlas) == "function" then Empty(skin, icon) end
        FollowIcon(button, icon)
    end
    if ns.Usable(button.IconBorder) then skin:Hold(button.IconBorder) end
    local normal = NormalOf(button)
    if normal then skin:Hold(normal) end
    for _, key in ipairs(SLOT_ART) do
        if ns.Usable(button[key]) then skin:Hold(button[key]) end
    end
    skin:Panel(button)
    Paint(skin, button)
    Follow(button)
end

-- Repaints the border of a skinned slot after Blizzard updates its item; nothing while the area is off.
function Bags.Repaint(button)
    local skin = styled[button]
    if skin then Paint(skin, button) end
end

local function SkinItems(skin, bag)
    for _, button in ipairs(Items(bag)) do Bags.Item(skin, button) end
end

-- A bag acquires its buttons when it opens and re-fills them when it updates; new buttons are skinned then.
local function Watch(bag)
    if hooked[bag] then return end
    hooked[bag] = true
    local function Refresh()
        local skin = styled[bag]
        if skin then ns.Run("modern bags", SkinItems, skin, bag) end
    end
    if type(bag.UpdateItems) == "function" then pcall(hooksecurefunc, bag, "UpdateItems", Refresh) end
    if type(bag.HookScript) == "function" then pcall(bag.HookScript, bag, "OnShow", Refresh) end
end

local function SkinBag(skin, bag)
    if not ns.Usable(bag) then return end
    if not styled[bag] then
        styled[bag] = skin
        skin:Remember(bag, "modern bag", function() styled[bag] = nil end)
        if bag == _G.ContainerFrameCombinedBags then
            -- 12.0: TitleContainer lies far above the bag's children, so the handle goes over it.
            Modern.Window(skin, bag, "ContainerFrameCombinedBags", bag.TitleContainer)
        else
            Modern.Window(skin, bag)
        end
        Modern.Header(skin, bag)
        Watch(bag)
        local money = bag.MoneyFrame
        -- The money stays as bare text on the bag background.
        if ns.Usable(money) then Modern.Field(skin, money.Border, true) end
    end
    SkinItems(skin, bag)
end

-- The frame and its descendants stop catching the mouse; undo enables it again where it was enabled.
local function PassMouse(skin, frame)
    if not ns.Usable(frame) or type(frame.IsMouseEnabled) ~= "function" or type(frame.EnableMouse) ~= "function" then
        return
    end
    if frame:IsMouseEnabled() then
        skin:Remember(frame, "modern bags mouse", function() pcall(frame.EnableMouse, frame, true) end)
        pcall(frame.EnableMouse, frame, false)
    end
    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do PassMouse(skin, child) end
    end
end

-- Bags that exist and buttons not yet skinned; cheap enough to run on every bag event.
function Bags.Apply(skin)
    for index = 1, MAX_BAGS do SkinBag(skin, _G["ContainerFrame" .. index]) end
    SkinBag(skin, _G.ContainerFrameCombinedBags)
    Modern.Field(skin, _G.BagItemSearchBox)
    -- In gamepad mode Blizzard docks its bag bar at the open bag's corner, over the sort button. It is held
    -- invisible and lets the mouse through; Blizzard re-parents the sort button, so its level cannot be raised.
    local bar = _G.GamepadBagBar
    if ns.Usable(bar) then
        skin:Hold(bar)
        PassMouse(skin, bar)
    end
end
