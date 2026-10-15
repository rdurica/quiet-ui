local _, ns = ...

-- Bag windows (ContainerFrameN and ContainerFrameCombinedBags): dark chrome, square icons and a
-- flat border that follows the quality colour Blizzard sets on IconBorder. Bags keep Blizzard
-- stacking, so they get no drag handle.

local Modern = ns.Modern
local Bags = {}
Modern.Bags = Bags

local MAX_BAGS = 20
local styled = setmetatable({}, { __mode = "k" })  -- window or item button -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

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
            for _, button in iter, state, init do Add(button) end
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

-- Quality colour while Blizzard shows IconBorder, the theme border otherwise.
local function Border(skin, button)
    local color
    local border = button.IconBorder
    if ns.Usable(border) and type(border.IsShown) == "function" and border:IsShown()
        and type(border.GetVertexColor) == "function" then
        local r, g, b, a = border:GetVertexColor()
        if type(r) == "number" and not ns.IsSecret(r) then color = { r, g, b, a or 1 } end
    end
    skin:Border(button, color)
end

local function Follow(button)
    local border = button.IconBorder
    if hooked[button] or not ns.Usable(border) then return end
    hooked[button] = true
    for _, method in ipairs({ "SetVertexColor", "Show", "Hide", "SetShown" }) do
        if type(border[method]) == "function" then
            pcall(hooksecurefunc, border, method, function()
                local skin = styled[button]
                if skin then ns.Run("modern bags", Border, skin, button) end
            end)
        end
    end
end

local function Item(skin, button)
    if styled[button] then return end
    styled[button] = skin
    skin:Remember(button, "modern bag item", function() styled[button] = nil end)
    local icon = IconOf(button)
    if ns.Usable(icon) then skin:Icon(icon) end
    if ns.Usable(button.IconBorder) then skin:Hold(button.IconBorder) end
    Border(skin, button)
    Follow(button)
end

local function SkinItems(skin, bag)
    for _, button in ipairs(Items(bag)) do Item(skin, button) end
end

-- A bag re-fills its buttons when it updates; new buttons are skinned then.
local function Watch(bag)
    if hooked[bag] then return end
    hooked[bag] = true
    if type(bag.UpdateItems) == "function" then
        pcall(hooksecurefunc, bag, "UpdateItems", function()
            local skin = styled[bag]
            if skin then ns.Run("modern bags", SkinItems, skin, bag) end
        end)
    end
end

local function SkinBag(skin, bag)
    if not ns.Usable(bag) then return end
    if not styled[bag] then
        styled[bag] = skin
        skin:Remember(bag, "modern bag", function() styled[bag] = nil end)
        Modern.Window(skin, bag)
        Watch(bag)
    end
    SkinItems(skin, bag)
end

-- Bags that exist and buttons not yet skinned; cheap enough to run on every bag event.
function Bags.Apply(skin)
    for index = 1, MAX_BAGS do SkinBag(skin, _G["ContainerFrame" .. index]) end
    SkinBag(skin, _G.ContainerFrameCombinedBags)
end
