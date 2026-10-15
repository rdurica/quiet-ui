local _, ns = ...

-- Bag windows (ContainerFrameN and ContainerFrameCombinedBags): dark chrome, square slots like the
-- action bars and a flat border that follows the quality colour Blizzard sets on IconBorder (the
-- accent for quest items). The combined bag has a title drag handle; separate bags keep Blizzard
-- stacking, so they get none.

local Modern = ns.Modern
local Bags = {}
Modern.Bags = Bags

local MAX_BAGS = 20
local styled = setmetatable({}, { __mode = "k" })  -- window or item button -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })
local empty = setmetatable({}, { __mode = "k" })   -- empty-slot icon -> true while held

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

-- Accent while Blizzard shows the quest border, quality colour while it shows IconBorder, the theme border otherwise.
local function Border(skin, button)
    local color
    local border = button.IconBorder
    if Shown(button.IconQuestTexture) then
        color = Modern.Theme().accent
    elseif Shown(border) and type(border.GetVertexColor) == "function" then
        local r, g, b, a = border:GetVertexColor()
        if type(r) == "number" and not ns.IsSecret(r) then color = { r, g, b, a or 1 } end
    end
    skin:Border(button, color)
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
                        if skin then ns.Run("modern bags", Border, skin, button) end
                    end)
                end
            end
        end
    end
end

-- 12.0 paints an empty slot by putting this atlas (the wing) on the item icon itself.
local EMPTY_ATLAS = "bags-item-slot64"

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
                if skin then ns.Run("modern bags", Empty, skin, icon) end
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

-- One square slot; the character window's equipment slots use it too.
function Bags.Item(skin, button)
    if styled[button] then return end
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
    Border(skin, button)
    Follow(button)
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
