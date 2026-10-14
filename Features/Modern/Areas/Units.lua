local _, ns = ...

local Modern = ns.Modern
local FRAMES = {
    { "PlayerFrame", "player" }, { "PetFrame", "pet" }, { "TargetFrame", "target" },
    { "TargetFrameToT", "targettarget" }, { "FocusFrame", "focus" },
}

local function Value(frame, ...)
    for i = 1, select("#", ...) do
        local value = frame[select(i, ...)]
        if ns.Usable(value) then return value end
    end
end

local function Status(skin, bar)
    if not ns.Usable(bar) or type(bar.SetStatusBarTexture) ~= "function" or type(bar.GetStatusBarTexture) ~= "function" then return end
    if skin:Remember(bar, "status texture", function() end) then
        local old = bar:GetStatusBarTexture()
        if ns.Usable(old) and type(old.GetTexture) == "function" then old = old:GetTexture() end
        skin.entries[#skin.entries] = function() pcall(bar.SetStatusBarTexture, bar, old) end
    end
    pcall(bar.SetStatusBarTexture, bar, Modern.Theme().bar)
    skin:Panel(bar)
    skin:Border(bar)
end

local function Colour(frame, unit)
    if not ns.Settings.ModernClassColors() or not ns.Settings.ModernArea("units") then return end
    local bar = Value(frame, "HealthBar", "healthbar", "healthBar")
    if not ns.Usable(bar) or type(bar.SetStatusBarColor) ~= "function" then return end
    local r, g, b
    if type(UnitIsPlayer) == "function" and UnitIsPlayer(unit) then
        local token
        if type(UnitClass) == "function" then _, token = UnitClass(unit) end
        local c = type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" and C_ClassColor.GetClassColor(token)
        c = c or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token])
        if type(c) == "table" then r, g, b = c.r or c[1], c.g or c[2], c.b or c[3] end
    else
        -- Forever accepts the unit form for the unit-frame update; retain the
        -- two-unit form as a fallback for clients that require it.
        local reaction
        if type(UnitReaction) == "function" then
            reaction = UnitReaction(unit)
            if reaction == nil then reaction = UnitReaction("player", unit) end
        end
        local c = type(FACTION_BAR_COLORS) == "table" and FACTION_BAR_COLORS[reaction]
        if type(c) == "table" then r, g, b = c.r or c[1], c.g or c[2], c.b or c[3] end
    end
    if r and g and b and not bar._quietModernColourApplying then
        bar._quietModernColourApplying = true
        pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
        bar._quietModernColourApplying = nil
    end
end

local function Portrait(skin, frame, unit)
    local portrait = Value(frame, "Portrait", "portrait")
    if not ns.Usable(portrait) then return end
    skin:Icon(portrait)
    if type(portrait.GetNumMaskTextures) == "function" and type(portrait.GetMaskTexture) == "function"
        and type(portrait.RemoveMaskTexture) == "function" and type(portrait.AddMaskTexture) == "function" then
        local masks = {}
        for i = 1, portrait:GetNumMaskTextures() do masks[#masks + 1] = portrait:GetMaskTexture(i) end
        if skin:Remember(portrait, "masks", function()
            for i = 1, #masks do pcall(portrait.AddMaskTexture, portrait, masks[i]) end
        end) then
            for _, mask in ipairs(masks) do pcall(portrait.RemoveMaskTexture, portrait, mask) end
        end
    end
    local color = Modern.Theme().border
    if unit == "target" and type(UnitClassification) == "function" then
        local kind = UnitClassification(unit)
        if kind == "elite" then color = Modern.Theme().accent
        elseif kind == "rare" or kind == "rareelite" then color = { 0.85, 0.85, 0.85, 1 }
        elseif kind == "worldboss" or kind == "boss" then color = { 0.9, 0.15, 0.15, 1 } end
    end
    skin:Border(portrait, color, portrait)
end

local function Unit(skin, spec)
    local frame, unit = _G[spec[1]], spec[2]
    if not ns.Usable(frame) then return end
    for _, name in ipairs({ "Border", "Flash", "Background", "EliteTexture", "Texture", "FrameTexture", "PortraitFrame" }) do
        local art = frame[name]
        if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
    end
    Status(skin, Value(frame, "HealthBar", "healthbar", "healthBar"))
    Status(skin, Value(frame, "ManaBar", "manaBar", "PowerBar", "powerBar"))
    Portrait(skin, frame, unit)
    Colour(frame, unit)
    local health = Value(frame, "HealthBar", "healthbar", "healthBar")
    if ns.Usable(health) and not health._quietModernColourHook and type(hooksecurefunc) == "function"
        and type(health.SetStatusBarColor) == "function" then
        health._quietModernColourHook = true
        pcall(hooksecurefunc, health, "SetStatusBarColor", function() Colour(frame, unit) end)
    end
end

local function Apply(skin)
    for _, spec in ipairs(FRAMES) do Unit(skin, spec) end
end

Modern.Register{
    key = "units", label = "Unit frames", events = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_FACTION" },
    apply = Apply, onEvent = function(skin) Apply(skin) end,
}
