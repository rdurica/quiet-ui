local _, ns = ...

-- Aura icons. Retail 12.0 keeps the buttons of BuffFrame and DebuffFrame in `.auraFrames` (private
-- aura anchors among them, flagged `isAuraAnchor`); older clients have named buttons or plain
-- children. Blizzard's update reshows the border art and changes the dispel type, so the frames'
-- UpdateAuraButtons is hooked (inert while the area is off). Only the player's UNIT_AURA matters.

local Modern = ns.Modern

local active = false
local hooked = setmetatable({}, { __mode = "k" })

local function Texture(region)
    return ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function Font(skin, font, icon)
    if not ns.Usable(font) or type(font.GetFont) ~= "function" or type(font.SetFont) ~= "function" then return end
    skin:Outline(font)
    skin:Set(font, "SetPoint", "TOP", icon, "BOTTOM", 0, -1)
end

local function Rgb(color)
    if type(color) ~= "table" then return end
    if type(color.GetRGB) == "function" then
        local r, g, b = color:GetRGB()
        return { r, g, b, 1 }
    end
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    if r then return { r, g, b, 1 } end
end

-- The dispel colour of a debuff; nil for everything else (the theme border).
local function Dispel(button)
    local info = button.buttonInfo
    local kind = type(info) == "table" and info.debuffType or button.DebuffType or button.debuffType
    if kind == nil and type(info) == "table" and info.auraType == "Debuff" then kind = "None" end
    if kind == nil or ns.IsSecret(kind) then return end
    if type(AuraUtil) == "table" and type(AuraUtil.GetAuraBorderColor) == "function" then
        local ok, color = pcall(AuraUtil.GetAuraBorderColor, kind)
        local rgb = ok and Rgb(color)
        if rgb then return rgb end
    end
    local colours = _G.DebuffTypeColor
    return Rgb(type(colours) == "table" and colours[kind])
end

local function Aura(skin, button)
    if not ns.Usable(button) or button.isAuraAnchor then return end
    local icon = button.Icon or button.icon or button.IconTexture
    if not Texture(icon) then return end
    skin:Icon(icon)
    skin:Border(button, Dispel(button), icon)
    for _, key in ipairs({ "DebuffBorder", "TempEnchantBorder" }) do
        if Texture(button[key]) then skin:Hold(button[key]) end
    end
    Font(skin, button.Duration or button.duration, icon)
end

local function Frames()
    local list = {}
    for _, name in ipairs({ "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }) do
        if ns.Usable(_G[name]) then list[#list + 1] = _G[name] end
    end
    return list
end

local function Scan(skin)
    local listed
    for _, frame in ipairs(Frames()) do
        if type(frame.auraFrames) == "table" then
            listed = true
            for _, button in ipairs(frame.auraFrames) do Aura(skin, button) end
        elseif type(frame.GetChildren) == "function" then
            for _, child in ipairs({ frame:GetChildren() }) do Aura(skin, child) end
        end
    end
    if listed then return end
    for _, prefix in ipairs({ "BuffButton", "DebuffButton", "TempEnchant" }) do
        for i = 1, 40 do Aura(skin, _G[prefix .. i]) end
    end
end

local function Updated()
    if active then ns.Run("modern auras", Scan, Modern.Skin("auras")) end
end

local function Watch()
    for _, frame in ipairs(Frames()) do
        if not hooked[frame] and type(frame.UpdateAuraButtons) == "function"
            and pcall(hooksecurefunc, frame, "UpdateAuraButtons", Updated) then
            hooked[frame] = true
        end
    end
end

Modern.Register{
    key = "auras", label = "Buffs and debuffs", events = { "PLAYER_ENTERING_WORLD", "UNIT_AURA" },
    apply = function(skin)
        active = true
        Watch()
        Scan(skin)
    end,
    restore = function() active = false end,
    onEvent = function(skin, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        Watch()
        Scan(skin)
    end,
}
