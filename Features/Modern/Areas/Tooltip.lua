local _, ns = ...

local Modern = ns.Modern
local savedBorders = setmetatable({}, { __mode = "k" })

local function Quality(tip)
    if not ns.Usable(tip) then return end
    local link = tip.GetItem and select(2, tip:GetItem())
    local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    local quality
    if itemID and C_Item and type(C_Item.GetItemQualityByID) == "function" then
        quality = C_Item.GetItemQualityByID(itemID)
    end
    if quality == nil and link and type(GetItemInfo) == "function" then quality = select(3, GetItemInfo(link)) end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local theme = Modern.Theme()
    local rgb = color and { color.r, color.g, color.b, color.a or 1 } or theme.border
    if tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(unpack(rgb)) end
    local skin = Modern.Skin("tooltip")
    skin:Border(tip, rgb)
end

local function HookQuality(skin, tip)
    if not ns.Usable(tip) or not tip.SetScript or not tip.GetScript then return end
    local oldItem = tip:GetScript("OnTooltipSetItem")
    local oldShow = tip:GetScript("OnShow")
    skin:Remember(tip, "quality scripts", function()
        tip:SetScript("OnTooltipSetItem", oldItem)
        tip:SetScript("OnShow", oldShow)
    end)
    tip:SetScript("OnTooltipSetItem", function(self, ...)
        if oldItem then oldItem(self, ...) end
        Quality(self)
    end)
    tip:SetScript("OnShow", function(self, ...)
        if oldShow then oldShow(self, ...) end
        Quality(self)
    end)
end

local function ApplyTip(skin, tip)
    if not ns.Usable(tip) then return end
    skin:Panel(tip)
    skin:Border(tip)
    if ns.Usable(tip.NineSlice) then skin:Hold(tip.NineSlice) end
    if tip.SetBackdropColor then
        local theme = Modern.Theme()
        local old = type(tip.GetBackdropColor) == "function" and { tip:GetBackdropColor() } or nil
        skin:Remember(tip, "backdrop", function() if old then tip:SetBackdropColor(unpack(old)) end end)
        tip:SetBackdropColor(unpack(theme.bg))
    end
    if tip.SetBackdropBorderColor then
        local old = type(tip.GetBackdropBorderColor) == "function" and { tip:GetBackdropBorderColor() } or nil
        savedBorders[tip] = old
        skin:Remember(tip, "backdrop border", function() if old then tip:SetBackdropBorderColor(unpack(old)) end end)
    end
    local name = tip.GetName and tip:GetName()
    local bar = tip.StatusBar or (name and _G[name .. "StatusBar"])
    if ns.Usable(bar) and bar.SetStatusBarTexture and bar.GetStatusBarTexture then
        local texture = bar:GetStatusBarTexture()
        local previous = texture and texture.GetTexture and texture:GetTexture()
        skin:Remember(bar, "status texture", function()
            if previous then bar:SetStatusBarTexture(previous) end
        end)
        bar:SetStatusBarTexture(Modern.Theme().bar)
    end
    HookQuality(skin, tip)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, Quality)
    end
end

Modern.Register{
    key = "tooltip",
    label = "Tooltip",
    apply = function(skin)
        for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
            ApplyTip(skin, _G[name])
        end
    end,
    restore = function()
        for tip, color in pairs(savedBorders) do
            if ns.Usable(tip) and tip.SetBackdropBorderColor and color then tip:SetBackdropBorderColor(unpack(color)) end
        end
    end,
}
