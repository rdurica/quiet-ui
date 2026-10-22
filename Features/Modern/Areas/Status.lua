local _, ns = ...

-- Own XP, rested and watched-reputation bars under Blizzard's status container, which keeps its
-- mouse, text and alpha (so the XP fader still applies). Blizzard's bar art is held at alpha 0.
-- Only a numeric gain animates, and only while it runs. Secret values go straight to the widgets;
-- nothing is added to or compared with them.
local Modern = ns.Modern
local state = { xp = nil, reputation = nil, rested = nil, glow = nil, fx = nil, bubbles = nil, last = nil, target = nil,
    applied = nil, pending = nil }

local function Plain(value)
    return type(value) == "number" and not ns.IsSecret(value)
end

-- Ten segments: dividers twice as far apart as Blizzard's twenty.
local SEGMENTS = 10

local function PlaceDividers(dividers, width)
    if not Plain(width) or width <= 0 then return end
    for i, divider in ipairs(dividers) do
        divider:ClearAllPoints()
        divider:SetPoint("TOP", divider:GetParent(), "TOPLEFT", width * i / SEGMENTS, 0)
        divider:SetPoint("BOTTOM", divider:GetParent(), "BOTTOMLEFT", width * i / SEGMENTS, 0)
    end
end

local function Make(skin, container)
    local base = container:GetFrameLevel() or 1
    local xp = skin:Own(container, "status xp", function()
        -- Centred on Blizzard's bar so its XP text sits on the fill.
        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetHeight(12)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 3)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 3)
        -- The rested bar is a sibling one level below the fill, so XP covers it.
        local rested = CreateFrame("StatusBar", nil, container)
        rested:SetHeight(12)
        rested:SetAllPoints(bar)
        local track = rested:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints(rested)
        local dividers = {}
        for i = 1, SEGMENTS - 1 do
            dividers[i] = bar:CreateTexture(nil, "OVERLAY", nil, 1)
            dividers[i]:SetWidth(1)
        end
        bar:SetScript("OnSizeChanged", function(_, width) PlaceDividers(dividers, width) end)
        -- A 1 px light edge along the top of the fill.
        local shine = bar:CreateTexture(nil, "OVERLAY")
        shine:SetHeight(1)
        local glow = bar:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\AddOns\\QuietUI\\Media\\spark.tga")
        glow:SetBlendMode("ADD")
        glow:SetSize(24, 24)
        local group = glow:CreateAnimationGroup()
        if type(group.CreateAnimation) == "function" then
            local alpha = group:CreateAnimation("Alpha")
            if alpha then
                if alpha.SetFromAlpha then alpha:SetFromAlpha(1) end
                if alpha.SetToAlpha then alpha:SetToAlpha(0) end
                if alpha.SetDuration then alpha:SetDuration(0.25) end
            end
        end
        return { bar = bar, rested = rested, track = track, dividers = dividers, shine = shine, glow = glow,
            group = group, fx = Modern.XPBurst.Make(bar), bubbles = Modern.XPBurst.Bubbles(bar) }
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
    state.fx, state.bubbles = xp.fx, xp.bubbles
    return xp, reputation
end

-- Lighter at the top; a client without gradients gets the flat top colour.
local function Fill(bar)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and type(fill.SetGradient) == "function" and type(CreateColor) == "function"
        and pcall(fill.SetGradient, fill, "VERTICAL", CreateColor(0.18, 0.4, 0.85, 1), CreateColor(0.42, 0.68, 1, 1)) then
        return fill
    end
    bar:SetStatusBarColor(0.42, 0.68, 1)
    return fill
end

local function Style(skin, xp, reputation)
    local theme = Modern.Theme()
    for _, bar in ipairs({ xp.bar, xp.rested, reputation }) do
        if bar.SetStatusBarTexture then bar:SetStatusBarTexture(theme.bar) end
        bar:Show()
    end
    xp.track:SetTexture(theme.bar)
    xp.track:SetVertexColor(unpack(theme.bg))
    local fill = Fill(xp.bar)
    xp.rested:SetStatusBarColor(0.42, 0.68, 1, 0.25)
    reputation:SetStatusBarColor(unpack(theme.accent))
    local border = theme.border
    for _, divider in ipairs(xp.dividers) do
        divider:SetColorTexture(border[1], border[2], border[3], 0.8)
        divider:Show()
    end
    PlaceDividers(xp.dividers, xp.bar:GetWidth())
    xp.shine:ClearAllPoints()
    xp.shine:SetPoint("TOPLEFT", fill or xp.bar, "TOPLEFT", 0, 0)
    xp.shine:SetPoint("TOPRIGHT", fill or xp.bar, "TOPRIGHT", 0, 0)
    xp.shine:SetColorTexture(1, 1, 1, 0.25)
    xp.shine:Show()
    Modern.XPBurst.Fill(xp.bubbles, fill)
    -- The spark marks the end of the fill, not of the bar.
    xp.glow:ClearAllPoints()
    xp.glow:SetPoint("CENTER", fill or xp.bar, "RIGHT", 0, 0)
    skin:Border(xp.bar)
    skin:Border(reputation)
end

-- A secret value is present by definition and is never compared, not even with nil.
local function Present(value)
    return ns.IsSecret(value) or value ~= nil
end

local function SetRange(bar, low, high, value)
    if not bar or not Present(value) then return end
    if Present(low) and Present(high) and bar.SetMinMaxValues then bar:SetMinMaxValues(low, high) end
    bar:SetValue(value)
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

-- Blizzard's "no faction watched" is nil data or factionID 0. Returns true and the values (which
-- may be secret) when a faction is watched.
local function Watched()
    if type(C_Reputation) == "table" and type(C_Reputation.GetWatchedFactionData) == "function" then
        local data = C_Reputation.GetWatchedFactionData()
        if type(data) ~= "table" or not data.factionID or data.factionID == 0 then return false end
        return true, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
    end
    if type(GetWatchedFactionInfo) == "function" then
        local name, _, low, high, value = GetWatchedFactionInfo()
        if name then return true, low, high, value end
    end
    return false
end

local function SetReputation()
    local bar = state.reputation
    if not bar then return end
    local watched, low, high, value = Watched()
    if not watched or not Present(value) then
        bar:Hide()
    else
        SetRange(bar, low, high, value)
        bar:Show()
    end
end

-- The fill eases out over 0.4 s while the gained stretch bursts.
local function Animate(bar, old, value, maximum)
    local elapsed = 0
    state.target = value
    if Plain(maximum) and maximum > 0 then Modern.XPBurst.Play(state.fx, old / maximum, value / maximum) end
    bar:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local p = elapsed / 0.4
        if p >= 1 then
            self:SetValue(value); self:SetScript("OnUpdate", nil)
            state.target = nil
            if state.glow then state.glow:Play() end
        else
            p = 1 - (1 - p) ^ 3
            self:SetValue(old + (value - old) * p)
        end
    end)
end

local function SetXP(animate)
    local bar = state.xp
    if not bar or type(UnitXP) ~= "function" then return end
    local value = UnitXP("player")
    if not Present(value) then return end
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
    -- The range follows a level up even while a gain is still running.
    if Present(maximum) and bar.SetMinMaxValues then bar:SetMinMaxValues(0, maximum) end
    if animate and Plain(old) and value > old then
        Animate(bar, old, value, maximum)
    elseif state.target ~= value then
        -- A gain still running toward this value keeps running.
        bar:SetScript("OnUpdate", nil)
        state.target = nil
        bar:SetValue(value)
    end
    return value, maximum
end

-- True while the art still shows (alpha and vertex alpha above 0); a secret value counts as hidden.
local function Showing(region)
    local alpha = region:GetAlpha()
    if not Plain(alpha) or alpha < 0.01 then return false end
    if type(region.GetVertexColor) ~= "function" then return true end
    local _, _, _, vertex = region:GetVertexColor()
    return vertex == nil or (Plain(vertex) and vertex >= 0.01)
end

-- Blizzard's own art under the container: every texture of the container and of each tracking bar,
-- nested frames included (fill, segment ticks, exhaustion marker). Font strings stay, so the text
-- shows. Bars come and go with the tracked kind and Blizzard may swap a fill texture, so every
-- refresh looks again; holding is idempotent. Returns true when some art was still showing.
local function HoldArt(skin, container)
    local showing = false
    local function walk(frame, depth)
        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do
                if ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" then
                    local shown = Showing(region)
                    skin:Hold(region)
                    -- Blizzard animates this art's alpha past the SetAlpha hook; vertex alpha stays 0.
                    if type(region.GetVertexColor) == "function" then
                        local r, g, b = region:GetVertexColor()
                        skin:Set(region, "SetVertexColor", r or 1, g or 1, b or 1, 0)
                    end
                    -- An already held alpha is not pushed again; art that shows anyway is set directly.
                    if shown then region:SetAlpha(0) end
                    showing = showing or shown
                end
            end
        end
        if depth > 4 or not frame.GetChildren then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child ~= state.xp and child ~= state.rested and child ~= state.reputation and ns.Usable(child) then
                walk(child, depth + 1)
            end
        end
    end
    walk(container, 0)
    return showing
end

-- Blizzard adds tracking bars and dividers in its own handlers after ours, and right after a reload
-- the client drops what we set on art whose atlas is still loading. So the art is looked at again
-- on the next frame and then every 0.25 s while some still shows, at most RETRIES times.
local RETRIES = 40

local function HoldLater(skin, container, tries)
    if state.pending or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return end
    state.pending = true
    tries = tries or 0
    C_Timer.After(tries == 0 and 0 or 0.25, function()
        state.pending = nil
        if not state.applied then return end
        local ok, showing
        ns.Profiler.Run("modern status art", function() ok, showing = pcall(HoldArt, skin, container) end)
        if not ok then ns.Report("modern status", showing); return end
        if showing and tries < RETRIES then HoldLater(skin, container, tries + 1) end
    end)
end

local function Refresh(skin, event)
    local container = MainStatusTrackingBarContainer
    if ns.Usable(container) then
        HoldArt(skin, container)
        HoldLater(skin, container)
    end
    local current, maximum = SetXP(event == "PLAYER_XP_UPDATE")
    SetRested(current, maximum)
    SetReputation()
end

Modern.Register{
    key = "status",
    label = "Modern XP bar",
    events = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION" },
    apply = function(skin)
        local container = MainStatusTrackingBarContainer
        if not ns.Usable(container) then return end
        local xp, reputation = Make(skin, container)
        state.applied = true
        Style(skin, xp, reputation)
        state.last, state.target = nil, nil
        Refresh(skin)
    end,
    restore = function()
        state.applied = nil
        if state.xp then state.xp:SetScript("OnUpdate", nil); state.xp:Hide() end
        if state.reputation then state.reputation:Hide() end
        if state.rested then state.rested:Hide() end
        if state.glow then state.glow:Stop() end
        Modern.XPBurst.Stop(state.fx)
        if state.bubbles then state.bubbles.stop() end
        state.target = nil
    end,
    onEvent = function(skin, event, unit)
        if event ~= "PLAYER_XP_UPDATE" or unit == nil or unit == "player" then Refresh(skin, event) end
    end,
}
