local _, ns = ...

-- Cast bars of the player, pet, target and focus (and, through MirrorTimers, the breath and fatigue bars) (retail CastingBarMixin parts, with the classic
-- `<name>Icon` style globals as fallbacks). The frame art is held, the bar is taller with the theme
-- panel, border and flat fill, and the spell name and cast time sit inside it. Blizzard keeps the
-- player's spell icon hidden but still sets its texture, so an own square icon left of the bar
-- mirrors that texture and Blizzard's icon is held at alpha 0. Blizzard re-textures the fill on every
-- cast and re-anchors the parts in SetLook, so those are hooked; the hooks only act on tracked bars
-- and are inert while the area is off. Nameplate cast bars are recycled across units and stay Blizzard's.

local Modern = ns.Modern

local FRAMES = { "PlayerCastingBarFrame", "CastingBarFrame", "PetCastingBarFrame", "TargetFrameSpellBar",
    "FocusFrameSpellBar" }
local ART = { "Border", "BorderShield", "TextBorder", "Background", "Flash", "ChannelShadow", "StandardGlow",
    "CraftGlow", "InterruptGlow", "Shine" }

-- Fill colour per retail `barType`; a client without it keeps Blizzard's colours.
local COLOURS = {
    standard = "accent", empowered = "accent", applyingcrafting = "accent", applyingtalents = "accent",
    channel = { 0.30, 0.75, 0.35, 1 },
    uninterruptable = { 0.55, 0.55, 0.55, 1 },
    interrupted = "danger",
}

local PLAYER = { PlayerCastingBarFrame = true, CastingBarFrame = true }
local PLAYER_HEIGHT, OTHER_HEIGHT = 18, 14
local GAP = 2   -- between the icon and the bar
local INSET = 4 -- text inside the bar's ends

local tracked = setmetatable({}, { __mode = "k" })  -- bar -> { texture, theme }
local hooked = setmetatable({}, { __mode = "k" })
local mirrors = setmetatable({}, { __mode = "k" })  -- Blizzard icon -> own icon while applied
local laid = setmetatable({}, { __mode = "k" })     -- bar -> journal while laid out
local looks = setmetatable({}, { __mode = "k" })    -- bars whose SetLook is hooked

local function Part(bar, key)
    local part = bar[key]
    if part == nil and type(bar.GetName) == "function" then
        local name = bar:GetName()
        if type(name) == "string" then part = _G[name .. key] end
    end
    if ns.Usable(part) then return part end
end

local function Colour(bar, theme)
    local kind = bar.barType
    if type(kind) ~= "string" or ns.IsSecret(kind) then return end
    local colour = COLOURS[kind] or COLOURS.standard
    if type(colour) == "string" then colour = theme[colour] end
    return colour
end

local function Paint(bar, retexture)
    local info = tracked[bar]
    if not info or info.busy then return end
    info.busy = true
    ns.Profiler.Run("modern castbars", function()
        if retexture then bar:SetStatusBarTexture(info.texture) end
        local colour = Colour(bar, info.theme)
        if colour then bar:SetStatusBarColor(colour[1], colour[2], colour[3], 1) end
    end)
    info.busy = nil
end

local function Hook(bar)
    if hooked[bar] then return end
    hooked[bar] = true
    pcall(hooksecurefunc, bar, "SetStatusBarColor", function() Paint(bar, false) end)
    pcall(hooksecurefunc, bar, "SetStatusBarTexture", function(_, texture)
        local info = tracked[bar]
        if info and texture ~= info.texture then Paint(bar, true) end
    end)
end

local function CurrentTexture(bar)
    local fill = bar:GetStatusBarTexture()
    if not ns.Usable(fill) then return end
    local atlas = type(fill.GetAtlas) == "function" and fill:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then return atlas end
    if type(fill.GetTexture) == "function" then return fill:GetTexture() end
end

local function Fill(skin, bar)
    if type(bar.SetStatusBarTexture) ~= "function" or type(bar.GetStatusBarTexture) ~= "function"
        or type(bar.SetStatusBarColor) ~= "function" then return end
    if type(bar.GetStatusBarColor) == "function" then
        local r, g, b, a = bar:GetStatusBarColor()
        skin:Remember(bar, "cast colour", function() pcall(bar.SetStatusBarColor, bar, r, g, b, a) end)
    end
    local old = CurrentTexture(bar)
    if old then skin:Remember(bar, "cast texture", function() pcall(bar.SetStatusBarTexture, bar, old) end) end
    skin:Remember(bar, "cast tracked", function() tracked[bar] = nil end)
    local theme = Modern.Theme()
    tracked[bar] = { texture = theme.bar, theme = theme }
    Hook(bar)
    Paint(bar, true)
end

-- Blizzard animates the flash and glows past SetAlpha, so their vertex alpha goes to 0 as well.
local function Hide(skin, region)
    skin:Hold(region)
    if type(region.GetVertexColor) == "function" and type(region.SetVertexColor) == "function" then
        local r, g, b = region:GetVertexColor()
        skin:Set(region, "SetVertexColor", r or 1, g or 1, b or 1, 0)
    end
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

-- Puts a region on new points; the first call per apply remembers Blizzard's.
local function Anchor(skin, region, ...)
    local saved = {}
    for i = 1, region:GetNumPoints() do saved[i] = Pack(region:GetPoint(i)) end
    skin:Remember(region, "cast points", function()
        region:ClearAllPoints()
        for _, p in ipairs(saved) do region:SetPoint(unpack(p, 1, p.n)) end
    end)
    region:ClearAllPoints()
    region:SetPoint(...)
end

local function Mirror(icon, texture)
    local own = mirrors[icon]
    if own then own:SetTexture(texture) end
end

local function Icon(skin, bar, height)
    local own = skin:Own(bar, "cast icon", function()
        local texture = bar:CreateTexture(nil, "ARTWORK")
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetAllPoints(texture)
        return { texture, holder }
    end)
    if not own then return end
    local texture, holder = own[1], own[2]
    texture:ClearAllPoints()
    texture:SetPoint("RIGHT", bar, "LEFT", -GAP, 0)
    texture:SetSize(height, height)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    texture:Show()
    holder:Show()
    skin:Border(holder)
    local icon = Part(bar, "Icon")
    if not icon then return end
    skin:Hold(icon)
    mirrors[icon] = texture
    skin:Remember(icon, "cast icon", function() mirrors[icon] = nil end)
    if not hooked[icon] and type(icon.SetTexture) == "function" then
        hooked[icon] = true
        pcall(hooksecurefunc, icon, "SetTexture", Mirror)
    end
    if type(icon.GetTexture) == "function" then texture:SetTexture(icon:GetTexture()) end
end

local function Layout(skin, bar)
    local height = PLAYER[bar:GetName() or ""] and PLAYER_HEIGHT or OTHER_HEIGHT
    skin:Set(bar, "SetHeight", height)
    local text = Part(bar, "Text")
    if text then
        skin:Outline(text)
        Anchor(skin, text, "LEFT", bar, "LEFT", INSET, 0)
        if type(text.SetJustifyH) == "function" then skin:Set(text, "SetJustifyH", "LEFT") end
    end
    local time = Part(bar, "CastTimeText")
    if time then
        skin:Outline(time)
        Anchor(skin, time, "RIGHT", bar, "RIGHT", -INSET, 0)
    end
    Icon(skin, bar, height)
end

-- Blizzard's SetLook puts the parts back where its look wants them.
local function Relayout(bar)
    local skin = laid[bar]
    if skin then ns.Profiler.Run("modern castbars", Layout, skin, bar) end
end

local function Bar(skin, bar)
    if not ns.Usable(bar) then return end
    for _, key in ipairs(ART) do
        local art = Part(bar, key)
        if art and type(art.SetAlpha) == "function" then Hide(skin, art) end
    end
    skin:Panel(bar)
    skin:Border(bar)
    Fill(skin, bar)
    laid[bar] = skin
    skin:Remember(bar, "cast laid", function() laid[bar] = nil end)
    Layout(skin, bar)
    if not looks[bar] and type(bar.SetLook) == "function" then
        looks[bar] = true
        pcall(hooksecurefunc, bar, "SetLook", Relayout)
    end
end

Modern.Register{
    key = "castbars",
    label = "Cast bars",
    addons = { "Blizzard_MirrorTimer" },
    apply = function(skin)
        for _, name in ipairs(FRAMES) do Bar(skin, _G[name]) end
        Modern.MirrorTimers.Apply(skin)
    end,
    restore = function() Modern.MirrorTimers.Release() end,
}
