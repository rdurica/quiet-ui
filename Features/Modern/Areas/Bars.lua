local _, ns = ...

local Modern = ns.Modern

local function Texture(button, ...)
    for i = 1, select("#", ...) do
        local value = button[select(i, ...)]
        if ns.Usable(value) then return value end
    end
end

-- A mask is a rounded clip on an icon or portrait; the square crop needs it off. Shared with Units.
function Modern.NoMask(skin, icon)
    if type(icon.GetNumMaskTextures) ~= "function" or type(icon.GetMaskTexture) ~= "function"
        or type(icon.RemoveMaskTexture) ~= "function" or type(icon.AddMaskTexture) ~= "function" then return end
    local count = icon:GetNumMaskTextures()
    if type(count) ~= "number" then return end
    local masks = {}
    for i = 1, count do masks[#masks + 1] = icon:GetMaskTexture(i) end
    if #masks == 0 then return end
    if skin:Remember(icon, "masks", function()
        for _, mask in ipairs(masks) do pcall(icon.AddMaskTexture, icon, mask) end
    end) then
        for _, mask in ipairs(masks) do pcall(icon.RemoveMaskTexture, icon, mask) end
    end
end

local function Button(skin, button)
    if not ns.Usable(button) then return end
    local icon = Texture(button, "Icon", "icon", "IconTexture")
    if not icon then return end
    skin:Icon(icon)
    Modern.NoMask(skin, icon)
    for _, name in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Border", "SlotBackground", "SlotArt" }) do
        local art = button[name]
        local getter = button["Get" .. name]
        if not ns.Usable(art) and type(getter) == "function" then
            local ok, value = pcall(getter, button)
            art = ok and value or nil
        end
        if ns.Usable(art) then skin:Hold(art) end
    end
    -- The socket of an empty bag slot, so an empty action slot reads as a slot rather than a hole onto the world.
    local well = Modern.Theme().well
    local fill = skin:Panel(button, well)
    if fill then Modern.Lit(fill, { well[1] * 0.55, well[2] * 0.55, well[3] * 0.55, well[4] }, well[1] * 0.45) end
    skin:Border(button)
    Modern.BarFeedback(skin, button, icon)
    skin:Outline(button.HotKey)
    skin:Outline(button.Count)
end

local function BarArt(skin)
    for _, name in ipairs({ "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
        "MainMenuBarPageNumber", "MainMenuBarArtFrame", "MainActionBarArtFrame" }) do
        local art = _G[name]
        if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
    end
    -- 12.0: BorderArt and the gryphon end caps live on the bar itself.
    for _, name in ipairs({ "MainActionBar", "MainMenuBar" }) do
        local bar = _G[name]
        if ns.Usable(bar) then
            for _, art in ipairs({ bar.BorderArt, bar.EndCaps and bar.EndCaps.LeftEndCap,
                bar.EndCaps and bar.EndCaps.RightEndCap }) do
                if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
            end
        end
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
