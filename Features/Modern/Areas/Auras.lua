local _, ns = ...

local Modern = ns.Modern

local function Font(skin, font)
    if not ns.Usable(font) or type(font.GetFont) ~= "function" or type(font.SetFont) ~= "function" then return end
    local ok, face, size, flags = pcall(font.GetFont, font)
    if ok then
        skin:Set(font, "SetFont", face, size, (flags or "") .. "OUTLINE")
        skin:Set(font, "SetPoint", "TOP", font:GetParent(), "BOTTOM", 0, -1)
    end
end

local function Dispel(button)
    local kind = button.DebuffType or button.debuffType
    local colours = _G.DebuffTypeColor
    local c = type(colours) == "table" and colours[kind]
    if type(c) == "table" then return { c.r or c[1], c.g or c[2], c.b or c[3], 1 } end
end

local function Aura(skin, button)
    if not ns.Usable(button) then return end
    local icon = button.Icon or button.icon or button.IconTexture
    if not ns.Usable(icon) then return end
    skin:Icon(icon)
    skin:Border(button, Dispel(button))
    Font(skin, button.Duration or button.duration)
end

local function Scan(skin)
    local prefixes = { "BuffButton", "DebuffButton", "TemporaryEnchantFrame", "TempEnchant" }
    for _, prefix in ipairs(prefixes) do
        for i = 1, 40 do Aura(skin, _G[prefix .. i]) end
    end
    for _, frame in ipairs({ _G.BuffFrame, _G.DebuffFrame, _G.TemporaryEnchantFrame }) do
        if ns.Usable(frame) and type(frame.GetChildren) == "function" then
            for _, child in ipairs({ frame:GetChildren() }) do Aura(skin, child) end
        end
    end
end

Modern.Register{
    key = "auras", label = "Auras", events = { "PLAYER_ENTERING_WORLD", "UNIT_AURA" },
    apply = Scan, onEvent = function(skin) Scan(skin) end,
}
