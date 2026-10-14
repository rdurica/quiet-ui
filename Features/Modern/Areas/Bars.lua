local _, ns = ...

local Modern = ns.Modern

local function Font(skin, font)
    if not ns.Usable(font) or type(font.GetFont) ~= "function" or type(font.SetFont) ~= "function" then return end
    local ok, face, size, flags = pcall(font.GetFont, font)
    if ok then skin:Set(font, "SetFont", face, size, (flags or "") .. "OUTLINE") end
end

local function Texture(button, ...)
    for i = 1, select("#", ...) do
        local value = button[select(i, ...)]
        if ns.Usable(value) then return value end
    end
end

local function Button(skin, button)
    if not ns.Usable(button) then return end
    local icon = Texture(button, "Icon", "icon", "IconTexture")
    if not icon then return end
    skin:Icon(icon)
    for _, name in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Border", "SlotBackground" }) do
        local art = button[name]
        local getter = button["Get" .. name]
        if not ns.Usable(art) and type(getter) == "function" then
            local ok, value = pcall(getter, button)
            art = ok and value or nil
        end
        if ns.Usable(art) then skin:Hold(art) end
    end
    skin:Panel(button)
    skin:Border(button)
    Font(skin, button.HotKey)
    Font(skin, button.Count)
end

local function BarArt(skin)
    for _, name in ipairs({ "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
        "MainMenuBarPageNumber", "MainMenuBarArtFrame", "MainActionBarArtFrame" }) do
        local art = _G[name]
        if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
    end
end

Modern.Register{
    key = "bars", label = "Action bars", addons = { "Blizzard_GamepadActionBars" },
    apply = function(skin)
        if ns.Bars and type(ns.Bars.Buttons) == "function" then
            for _, button in ipairs(ns.Bars.Buttons()) do Button(skin, button) end
        end
        BarArt(skin)
    end,
}
