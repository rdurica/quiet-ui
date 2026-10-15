local _, ns = ...

-- Own XP, rested and watched-reputation bars under Blizzard's status container, which keeps its
-- mouse, text and alpha (so the XP fader still applies). Blizzard's bar art is held at alpha 0.
-- Only a numeric gain animates, and only while it runs. Secret values go straight to the widgets;
-- nothing is added to or compared with them.
local Modern = ns.Modern
local state = { xp = nil, reputation = nil, rested = nil, glow = nil, last = nil, target = nil }

local ART_KEYS = { "Background", "Underlay", "Overlay" }

local function Make(skin, container)
    local base = container:GetFrameLevel() or 1
    local xp = skin:Own(container, "status xp", function()
        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetHeight(6)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        -- The rested bar is a sibling one level below the fill, so XP covers it.
        local rested = CreateFrame("StatusBar", nil, container)
        rested:SetHeight(6)
        rested:SetAllPoints(bar)
        local glow = bar:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\AddOns\\QuietUI\\Media\\spark.tga")
        glow:SetBlendMode("ADD")
        glow:SetSize(18, 18); glow:SetPoint("CENTER", bar, "RIGHT", 0, 0)
        local group = glow:CreateAnimationGroup()
        if type(group.CreateAnimation) == "function" then
            local alpha = group:CreateAnimation("Alpha")
            if alpha then
                if alpha.SetFromAlpha then alpha:SetFromAlpha(1) end
                if alpha.SetToAlpha then alpha:SetToAlpha(0) end
                if alpha.SetDuration then alpha:SetDuration(0.25) end
            end
        end
        return { bar = bar, rested = rested, glow = glow, group = group }
    end)
    local reputation = skin:Own(container, "status reputation", function()
        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetHeight(4)
        bar:SetPoint("BOTTOM", xp.bar, "TOP", 0, 2)
        bar:SetPoint("BOTTOMLEFT", xp.bar, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", xp.bar, "TOPRIGHT", 0, 2)
        return bar
    end)
    xp.rested:SetFrameLevel(base + 1)
    xp.bar:SetFrameLevel(base + 2)
    reputation:SetFrameLevel(base + 2)
    state.xp, state.reputation, state.rested, state.glow = xp.bar, reputation, xp.rested, xp.group
    return xp, reputation
end

local function Style(xp, reputation)
    local theme = Modern.Theme()
    for _, bar in ipairs({ xp.bar, xp.rested, reputation }) do
        if bar.SetStatusBarTexture then bar:SetStatusBarTexture(theme.bar) end
        bar:Show()
    end
    xp.rested:SetStatusBarColor(0.7, 0.85, 1, 0.6)
    reputation:SetStatusBarColor(unpack(theme.accent))
end

local function SetRange(bar, low, high, value)
    if not bar or value == nil then return end
    if low ~= nil and high ~= nil and bar.SetMinMaxValues then bar:SetMinMaxValues(low, high) end
    bar:SetValue(value)
end

local function Plain(value)
    return type(value) == "number" and not ns.IsSecret(value)
end

-- Rested XP covers xp .. xp + exhaustion, capped at the maximum. A secret value skips the math.
local function SetRested(current, maximum)
    local bar = state.rested
    if not bar then return end
    local exhaustion = type(GetXPExhaustion) == "function" and GetXPExhaustion() or nil
    if Plain(current) and Plain(maximum) and Plain(exhaustion) and exhaustion > 0 then
        SetRange(bar, 0, maximum, math.min(current + exhaustion, maximum))
    else
        SetRange(bar, 0, 1, 0)
    end
end

-- Blizzard's "no faction watched" is nil data or factionID 0.
local function Watched()
    if type(C_Reputation) == "table" and type(C_Reputation.GetWatchedFactionData) == "function" then
        local data = C_Reputation.GetWatchedFactionData()
        if type(data) ~= "table" or not data.factionID or data.factionID == 0 then return end
        return data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
    end
    if type(GetWatchedFactionInfo) == "function" then
        local name, _, low, high, value = GetWatchedFactionInfo()
        if name then return low, high, value end
    end
end

local function SetReputation()
    local bar = state.reputation
    if not bar then return end
    local low, high, value = Watched()
    if value == nil then
        bar:Hide()
    elseif Plain(low) and Plain(high) and Plain(value) then
        SetRange(bar, low, high, value)
        bar:Show()
    end
end

local function Animate(bar, old, value)
    local elapsed = 0
    state.target = value
    bar:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local p = elapsed / 0.4
        if p >= 1 then
            self:SetValue(value); self:SetScript("OnUpdate", nil)
            state.target = nil
            if state.glow then state.glow:Play() end
        else
            self:SetValue(old + (value - old) * p)
        end
    end)
end

local function SetXP(animate)
    local bar = state.xp
    if not bar or type(UnitXP) ~= "function" then return end
    local value = UnitXP("player")
    if value == nil then return end
    local maximum = type(UnitXPMax) == "function" and UnitXPMax("player") or nil
    if ns.IsSecret(value) then
        bar:SetScript("OnUpdate", nil)
        state.target = nil
        SetRange(bar, 0, maximum, value)
        state.last = value
        return value, maximum
    end
    local old = state.last
    state.last = value
    if animate and Plain(old) and Plain(value) and value > old then
        Animate(bar, old, value)
    elseif state.target ~= value then
        -- A gain still running toward this value keeps running.
        bar:SetScript("OnUpdate", nil)
        state.target = nil
        SetRange(bar, 0, maximum, value)
    end
    return value, maximum
end

-- Blizzard's own art under the container: the frame art and, per tracking bar, the status bar's
-- Background / Underlay / Overlay and fill. Bars come and go with the tracked kind, so every
-- refresh looks again; holding is idempotent.
local function HoldArt(skin, container)
    local function hold(region)
        if ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" then
            skin:Hold(region)
        end
    end
    hold(container.BarFrameTexture)
    if container.GetRegions then
        for _, region in ipairs({ container:GetRegions() }) do hold(region) end
    end
    if not container.GetChildren then return end
    for _, bar in ipairs({ container:GetChildren() }) do
        if bar ~= state.xp and bar ~= state.rested and bar ~= state.reputation and ns.Usable(bar) then
            hold(bar.BarFrameTexture)
            local status = bar.StatusBar
            if ns.Usable(status) then
                for _, key in ipairs(ART_KEYS) do hold(status[key]) end
                if type(status.GetStatusBarTexture) == "function" then hold(status:GetStatusBarTexture()) end
            end
        end
    end
end

local function Refresh(skin, event)
    local container = MainStatusTrackingBarContainer
    if ns.Usable(container) then HoldArt(skin, container) end
    local current, maximum = SetXP(event == "PLAYER_XP_UPDATE")
    SetRested(current, maximum)
    SetReputation()
end

Modern.Register{
    key = "status",
    label = "XP and reputation",
    events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION" },
    apply = function(skin)
        local container = MainStatusTrackingBarContainer
        if not ns.Usable(container) then return end
        local xp, reputation = Make(skin, container)
        Style(xp, reputation)
        state.last, state.target = nil, nil
        Refresh(skin)
    end,
    restore = function()
        if state.xp then state.xp:SetScript("OnUpdate", nil); state.xp:Hide() end
        if state.reputation then state.reputation:Hide() end
        if state.rested then state.rested:Hide() end
        state.target = nil
    end,
    onEvent = function(skin, event, unit)
        if event ~= "PLAYER_XP_UPDATE" or unit == nil or unit == "player" then Refresh(skin, event) end
    end,
}
