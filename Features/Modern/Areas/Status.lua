local _, ns = ...

-- The custom bars are descendants of Blizzard's container, preserving its
-- mouse, text and alpha ownership.  Only a numeric gain animates.
local Modern = ns.Modern
local state = { xp = nil, reputation = nil, rested = nil, glow = nil, last = nil }

local function Usable(frame) return ns.Usable(frame) end

local function Make(skin, container)
    local xp = skin:Own(container, "status xp", function()
        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetHeight(6)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        local rested = CreateFrame("StatusBar", nil, bar)
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
        bar:SetPoint("BOTTOM", state.xp or xp.bar, "TOP", 0, 2)
        bar:SetPoint("BOTTOMLEFT", state.xp or xp.bar, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", state.xp or xp.bar, "TOPRIGHT", 0, 2)
        return bar
    end)
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

local function SetRested(current, maximum)
    if not state.rested or type(GetXPExhaustion) ~= "function" then return end
    local value = GetXPExhaustion()
    if value == nil then return end
    SetRange(state.rested, 0, maximum, value)
end

local function SetReputation()
    if not state.reputation or type(GetWatchedFactionInfo) ~= "function" then return end
    local _, _, low, high, value = GetWatchedFactionInfo()
    SetRange(state.reputation, low, high, value)
end

local function SetXP(animate)
    if not state.xp or type(UnitXP) ~= "function" then return end
    local value = UnitXP("player")
    if value == nil then return end
    local maximum = type(UnitXPMax) == "function" and UnitXPMax("player") or nil
    if ns.IsSecret(value) then
        state.xp:SetScript("OnUpdate", nil)
        SetRange(state.xp, 0, maximum, value)
        state.last = value
        return value, maximum
    end
    local old = state.last
    state.last = value
    if animate and type(old) == "number" and type(value) == "number" and value > old then
        local elapsed = 0
        state.xp:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local p = elapsed / 0.4
            if p >= 1 then
                self:SetValue(value); self:SetScript("OnUpdate", nil)
                if state.glow then state.glow:Play() end
            else
                self:SetValue(old + (value - old) * p)
            end
        end)
    else
        state.xp:SetScript("OnUpdate", nil)
        SetRange(state.xp, 0, maximum, value)
    end
    return value, maximum
end

local function Refresh(event)
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
        if not Usable(container) then return end
        local xp, reputation = Make(skin, container)
        Style(xp, reputation)
        if container.GetRegions then
            for _, region in ipairs({ container:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then skin:Hold(region) end
            end
        end
        Refresh()
    end,
    restore = function()
        if state.xp then state.xp:SetScript("OnUpdate", nil); state.xp:Hide() end
        if state.reputation then state.reputation:Hide() end
        if state.rested then state.rested:Hide() end
    end,
    onEvent = function(_, event, unit)
        if event ~= "PLAYER_XP_UPDATE" or unit == nil or unit == "player" then Refresh(event) end
    end,
}
