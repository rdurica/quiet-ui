local _, ns = ...

-- The breath, fatigue and feign death bars (MirrorTimerContainer.mirrorTimers, Forever UI source) take the cast bar
-- look: their cast bar frame, text box and background are held, the bar sits on the theme panel with a thin border
-- and a flat fill in the timer's colour. Blizzard sets the fill atlas on every Setup, so Setup is followed by a
-- repaint; the hook does nothing while the area is off. Label and time text stay.

local Modern = ns.Modern
local MirrorTimers = {}
Modern.MirrorTimers = MirrorTimers

local COLOURS = {
    BREATH = { 0.25, 0.55, 0.95, 1 },
    EXHAUSTION = { 0.95, 0.6, 0.2, 1 },
    FEIGNDEATH = { 0.30, 0.75, 0.35, 1 },
    DEATH = { 0.6, 0.6, 0.6, 1 },
}

local tracked = setmetatable({}, { __mode = "k" }) -- timer -> true while applied
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Paint(timer, kind)
    local bar = tracked[timer] and timer.StatusBar
    if not ns.Usable(bar) then return end
    bar:SetStatusBarTexture(Modern.Theme().bar)
    local colour = type(kind) == "string" and not ns.IsSecret(kind) and COLOURS[kind]
    bar:SetStatusBarColor(unpack(colour or Modern.Theme().accent))
end

local function Timer(skin, timer)
    local bar = ns.Usable(timer) and timer.StatusBar
    if not ns.Usable(bar) or type(bar.SetStatusBarTexture) ~= "function" then return end
    for _, region in ipairs({ timer:GetRegions() }) do
        if IsTexture(region) then skin:Hold(region) end
    end
    skin:Panel(bar)
    skin:Border(bar)
    local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
    local atlas = ns.Usable(fill) and type(fill.GetAtlas) == "function" and fill:GetAtlas()
    if type(atlas) == "string" then
        skin:Remember(bar, "mirror fill", function() pcall(bar.SetStatusBarTexture, bar, atlas) end)
    end
    if type(bar.GetStatusBarColor) == "function" then
        local r, g, b, a = bar:GetStatusBarColor()
        skin:Remember(bar, "mirror colour", function() pcall(bar.SetStatusBarColor, bar, r, g, b, a) end)
    end
    tracked[timer] = true
    Paint(timer, timer.timer)
    if hooked[timer] or type(timer.Setup) ~= "function" then return end
    hooked[timer] = true
    pcall(hooksecurefunc, timer, "Setup", function(self, kind) ns.Profiler.Run("modern mirror timers", Paint, self, kind) end)
end

function MirrorTimers.Apply(skin)
    local container = _G.MirrorTimerContainer
    if not ns.Usable(container) or type(container.mirrorTimers) ~= "table" then return end
    for _, timer in ipairs(container.mirrorTimers) do Timer(skin, timer) end
end

-- Before the journal is undone, so Blizzard's fill goes back without the hook answering.
function MirrorTimers.Release()
    for timer in pairs(tracked) do tracked[timer] = nil end
end
