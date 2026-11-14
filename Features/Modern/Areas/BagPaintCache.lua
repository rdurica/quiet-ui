local _, ns = ...

-- The game can reassign unchanged bag icons and border textures every frame.
-- Compare the actual slot styling state before repainting costly gradients.
local Cache = {}
ns.Modern.BagPaintCache = Cache
local state = setmetatable({}, { __mode = "k" })

local function SameColor(left, right)
    if left == right then return true end
    if not left or not right then return false end
    for i = 1, 4 do
        if left[i] ~= right[i] then return false end
    end
    return true
end

function Cache.Same(button, skin, icon, theme, vacant, placeholder, rich, color)
    local last = state[button]
    return last and last.skin == skin and last.icon == icon
        and last.theme == theme and last.vacant == vacant
        and last.placeholder == placeholder and last.rich == rich
        and SameColor(last.color, color) or false
end

function Cache.Put(button, skin, icon, theme, vacant, placeholder, rich, color)
    state[button] = {
        skin = skin, icon = icon, theme = theme, vacant = vacant,
        placeholder = placeholder, rich = rich, color = color,
    }
end

function Cache.Forget(button)
    state[button] = nil
end
