local _, ns = ...

-- Aura icons. Retail 12.0 keeps the buttons of BuffFrame and DebuffFrame in `.auraFrames` (private
-- aura anchors among them, flagged `isAuraAnchor`); older clients have named buttons or plain
-- children. Blizzard's update reshows the border art and changes the dispel type, so the frames'
-- UpdateAuraButtons is hooked (inert while the area is off). Only the player's UNIT_AURA matters.

local Modern = ns.Modern

local active = false
local hooked = setmetatable({}, { __mode = "k" })
local AURA_FRAMES = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }
local BORDER_KEYS = { "DebuffBorder", "TempEnchantBorder" }
local LEGACY_PREFIXES = { "BuffButton", "DebuffButton", "TempEnchant" }
local dispelColor = { 0, 0, 0, 1 }

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
        dispelColor[1], dispelColor[2], dispelColor[3] = color:GetRGB()
        return dispelColor
    end
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    if r then
        dispelColor[1], dispelColor[2], dispelColor[3] = r, g, b
        return dispelColor
    end
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
    for i = 1, #BORDER_KEYS do
        local border = button[BORDER_KEYS[i]]
        if Texture(border) then skin:Hold(border) end
    end
    Font(skin, button.Duration or button.duration, icon)
end

local function Scan(skin)
    local listed
    for i = 1, #AURA_FRAMES do
        local frame = _G[AURA_FRAMES[i]]
        if ns.Usable(frame) then
            if type(frame.auraFrames) == "table" then
                listed = true
                local buttons = frame.auraFrames
                for j = 1, #buttons do Aura(skin, buttons[j]) end
            elseif type(frame.GetChildren) == "function" then
                for _, child in ipairs({ frame:GetChildren() }) do Aura(skin, child) end
            end
        end
    end
    if listed then return end
    for i = 1, #LEGACY_PREFIXES do
        local prefix = LEGACY_PREFIXES[i]
        for j = 1, 40 do Aura(skin, _G[prefix .. j]) end
    end
end

local function Updated()
    if active then ns.Profiler.Run("modern auras", Scan, Modern.Skin("auras")) end
end

local function Watch()
    for i = 1, #AURA_FRAMES do
        local frame = _G[AURA_FRAMES[i]]
        if ns.Usable(frame) and not hooked[frame] and type(frame.UpdateAuraButtons) == "function"
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
