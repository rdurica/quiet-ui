local _, ns = ...

-- Tooltip chrome. Tooltips are secure frames: a tooltip with a NineSlice (every 12.0 tooltip) never
-- gets a script replaced, and OnTooltipSetItem is never touched (it throws on 12.0). Item quality
-- arrives through one TooltipDataProcessor post call registered at load; a hook on Show returns a
-- tooltip to the theme border. Both do nothing for a tooltip this area did not skin. An old
-- backdrop tooltip without a NineSlice gets one OnShow HookScript for the session; Safe ignores it
-- while the area is off.

local Modern = ns.Modern

local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local skinned = setmetatable({}, { __mode = "k" })    -- tip -> { skin, nine } while the area is applied
local hooked = setmetatable({}, { __mode = "k" })

local function Link(tip, data)
    if type(data) == "table" and not ns.IsSecret(data.hyperlink) and type(data.hyperlink) == "string" then
        return data.hyperlink
    end
    if type(tip.GetItem) ~= "function" then return end
    local ok, _, link = pcall(tip.GetItem, tip)
    if ok and type(link) == "string" and not ns.IsSecret(link) then return link end
end

local function ItemID(link, data)
    local id = type(data) == "table" and data.id
    if type(id) == "number" and not ns.IsSecret(id) then return id end
    return link and tonumber(link:match("item:(%d+)"))
end

local function Quality(link, id)
    local quality
    if id and C_Item and type(C_Item.GetItemQualityByID) == "function" then
        quality = C_Item.GetItemQualityByID(id)
    end
    if quality == nil and link and type(GetItemInfo) == "function" then quality = select(3, GetItemInfo(link)) end
    if type(quality) ~= "number" or ns.IsSecret(quality) then return end
    return quality
end

-- Item quality colour, or the theme border when the tooltip shows something else.
local function Paint(tip, data)
    local record = skinned[tip]
    if not record or not ns.Usable(tip) then return end
    local link = Link(tip, data)
    local quality = link and Quality(link, ItemID(link, data))
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local rgb = color and { color.r, color.g, color.b, color.a or 1 } or Modern.Theme().border
    -- With a NineSlice the backdrop colours belong to the held art; only own lines are painted.
    if not record.nine and tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(unpack(rgb)) end
    record.skin:Border(tip, rgb)
end

local function Safe(tip, data)
    ns.Run("modern tooltip", Paint, tip, data)
end

local function Bar(skin, tip)
    local name = tip.GetName and tip:GetName()
    local bar = tip.StatusBar or (name and _G[name .. "StatusBar"])
    if not ns.Usable(bar) or not bar.SetStatusBarTexture or not bar.GetStatusBarTexture then return end
    local texture = bar:GetStatusBarTexture()
    local previous = texture and texture.GetTexture and texture:GetTexture()
    skin:Remember(bar, "status texture", function()
        if previous then bar:SetStatusBarTexture(previous) end
    end)
    bar:SetStatusBarTexture(Modern.Theme().bar)
end

local function Backdrop(skin, tip)
    local theme = Modern.Theme()
    if tip.SetBackdropColor then
        local old = type(tip.GetBackdropColor) == "function" and { tip:GetBackdropColor() } or nil
        skin:Remember(tip, "backdrop", function() if old then tip:SetBackdropColor(unpack(old)) end end)
        tip:SetBackdropColor(unpack(theme.bg))
    end
    if tip.SetBackdropBorderColor then
        local old = type(tip.GetBackdropBorderColor) == "function" and { tip:GetBackdropBorderColor() } or nil
        skin:Remember(tip, "backdrop border", function() if old then tip:SetBackdropBorderColor(unpack(old)) end end)
    end
end

-- Repaints when the tooltip is shown, so a tooltip that no longer shows an item loses the quality colour.
local function Watch(tip, nine)
    if nine then
        if not hooked[tip] and pcall(hooksecurefunc, tip, "Show", Safe) then hooked[tip] = true end
    elseif not hooked[tip] and type(tip.HookScript) == "function" then
        if pcall(tip.HookScript, tip, "OnShow", function(self) Safe(self) end) then hooked[tip] = true end
    end
end

local function ApplyTip(skin, tip)
    if not ns.Usable(tip) then return end
    local nine = ns.Usable(tip.NineSlice) and tip.NineSlice or nil
    skin:Panel(tip)
    skin:Border(tip)
    if nine then skin:Hold(nine) else Backdrop(skin, tip) end
    Bar(skin, tip)
    skinned[tip] = { skin = skin, nine = nine ~= nil }
    Watch(tip, nine ~= nil)
end

if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, Safe)
end

Modern.Register{
    key = "tooltip",
    label = "Tooltip",
    apply = function(skin)
        for _, name in ipairs(TIPS) do ApplyTip(skin, _G[name]) end
    end,
    restore = function()
        for tip in pairs(skinned) do skinned[tip] = nil end
    end,
}
