local _, ns = ...

-- Tooltip chrome: a borderless grey panel with an accent edge along the top in the item's
-- quality colour (theme border otherwise). Tooltips are secure frames: a tooltip with a NineSlice (every 12.0 tooltip) never
-- gets a script replaced, and OnTooltipSetItem is never touched (it throws on 12.0). Item quality
-- and the player's class colour arrive through TooltipDataProcessor post calls registered at load;
-- a hook on Show returns a tooltip to the theme border. Both do nothing for a tooltip this area did not skin. An old
-- backdrop tooltip without a NineSlice gets one OnShow HookScript for the session; Safe ignores it
-- while the area is off.

local Modern = ns.Modern

-- The queue status panel (the LFG eye's hover panel) and the friends tooltip are tooltip backdrops too.
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "QueueStatusFrame",
    "FriendsTooltip" }
local EDGE = 2
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

local function Top(skin, tip, rgb)
    local edge = skin:Own(tip, "tooltip edge", function()
        local line = tip:CreateTexture(nil, "BORDER", nil, 1)
        line:SetPoint("TOPLEFT", tip, "TOPLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", tip, "TOPRIGHT", 0, 0)
        line:SetHeight(EDGE)
        return line
    end)
    edge:SetColorTexture(unpack(rgb))
    edge:Show()
end

-- Item quality colour from uncommon up, or the theme border.
local function Paint(tip, data)
    local record = skinned[tip]
    if not record or not ns.Usable(tip) then return end
    local link = Link(tip, data)
    local quality = link and Quality(link, ItemID(link, data))
    -- Poor and common items keep the theme border: a white edge reads as glare.
    local color = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    Top(record.skin, tip, color and { color.r, color.g, color.b, 1 } or Modern.Theme().border)
end

local function Safe(tip, data)
    ns.Profiler.Run("modern tooltip", Paint, tip, data)
end

-- The unit health bar is held at alpha 0; it hangs below the tooltip, so no gap is left.
local function Bar(skin, tip)
    local name = tip.GetName and tip:GetName()
    local bar = tip.StatusBar or (name and _G[name .. "StatusBar"])
    if ns.Usable(bar) then skin:Hold(bar) end
end

-- A player's name line in its class colour; Blizzard repaints it on the next unit.
local function Name(tip)
    if not skinned[tip] or not ns.Usable(tip) or type(tip.GetUnit) ~= "function" then return end
    local ok, _, unit = pcall(tip.GetUnit, tip)
    if not ok or type(unit) ~= "string" or ns.IsSecret(unit) then return end
    local player = UnitIsPlayer and UnitIsPlayer(unit)
    if ns.IsSecret(player) or not player then return end
    local _, class = UnitClass(unit)
    if ns.IsSecret(class) then return end
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local line = _G[(tip:GetName() or "") .. "TextLeft1"]
    if color and ns.Usable(line) and line.SetTextColor then line:SetTextColor(color.r, color.g, color.b) end
end

local function SafeName(tip)
    ns.Profiler.Run("modern tooltip name", Name, tip)
end

local function Backdrop(skin, tip)
    local theme = Modern.Theme()
    if tip.SetBackdropColor then
        local old = type(tip.GetBackdropColor) == "function" and { tip:GetBackdropColor() } or nil
        skin:Remember(tip, "backdrop", function() if old then tip:SetBackdropColor(unpack(old)) end end)
        tip:SetBackdropColor(unpack(theme.tip))
    end
    if tip.SetBackdropBorderColor then
        local old = type(tip.GetBackdropBorderColor) == "function" and { tip:GetBackdropBorderColor() } or nil
        skin:Remember(tip, "backdrop border", function() if old then tip:SetBackdropBorderColor(unpack(old)) end end)
        tip:SetBackdropBorderColor(0, 0, 0, 0)
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
    if nine then
        skin:Hold(nine)
        skin:Panel(tip, Modern.Theme().tip)
    else
        Backdrop(skin, tip)
    end
    Bar(skin, tip)
    -- The chat item tooltip's close button takes the windows' thin cross.
    Modern.CloseButton(skin, tip)
    skinned[tip] = { skin = skin }
    Top(skin, tip, Modern.Theme().border)
    Watch(tip, nine ~= nil)
end

if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, Safe)
    if Enum.TooltipDataType.Unit then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, SafeName)
    end
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
