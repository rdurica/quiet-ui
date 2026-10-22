local _, ns = ...

-- XP gain effect: the gained stretch of the bar flashes and fades, and sparks rise out of it, clipped
-- to the bar. Bigger gains get more sparks. Per-frame work runs only while the effect plays.
local Modern = ns.Modern
local Burst = {}
Modern.XPBurst = Burst

local SPARKS = 24
local DURATION = 1.1
local FLASH = 0.8
local SPARK = "Interface\\AddOns\\QuietUI\\Media\\spark.tga"

function Burst.Make(bar)
    -- Clipping applies to child frames, so the effect regions live one frame below the clip frame.
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetAllPoints(bar)
    if type(clip.SetClipsChildren) == "function" then pcall(clip.SetClipsChildren, clip, true) end
    local layer = CreateFrame("Frame", nil, clip)
    layer:SetAllPoints(clip)
    local flash = layer:CreateTexture(nil, "ARTWORK")
    flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(0.55, 0.8, 1)
    flash:Hide()
    local sparks = {}
    for i = 1, SPARKS do
        local spark = layer:CreateTexture(nil, "OVERLAY")
        spark:SetTexture(SPARK)
        spark:SetBlendMode("ADD")
        spark:SetVertexColor(0.75, 0.9, 1)
        spark:Hide()
        sparks[i] = { texture = spark }
    end
    return { bar = bar, layer = layer, flash = flash, sparks = sparks, active = 0 }
end

function Burst.Stop(fx)
    if not fx then return end
    fx.layer:SetScript("OnUpdate", nil)
    fx.flash:Hide()
    for _, spark in ipairs(fx.sparks) do spark.texture:Hide() end
end

local function Step(fx, dt)
    fx.elapsed = fx.elapsed + dt
    local t = fx.elapsed
    fx.flash:SetAlpha(math.max(0, 0.7 * (1 - t / FLASH)))
    for i = 1, fx.active do
        local spark = fx.sparks[i]
        local age = t - spark.delay
        if age > 0 and age < spark.life then
            local life = age / spark.life
            spark.texture:ClearAllPoints()
            spark.texture:SetPoint("CENTER", fx.layer, "BOTTOMLEFT", spark.x + spark.vx * age, spark.y + spark.vy * age)
            -- Quick fade in, slow fade out.
            spark.texture:SetAlpha(math.min(1, life * 6) * (1 - life))
            spark.texture:Show()
        else
            spark.texture:Hide()
        end
    end
    if t >= DURATION then Burst.Stop(fx) end
end

-- `from` and `to` are plain fractions of the bar (0..1), `to` above `from`.
function Burst.Play(fx, from, to)
    if not fx then return end
    local width, height = fx.bar:GetWidth(), fx.bar:GetHeight()
    if type(width) ~= "number" or ns.IsSecret(width) or width <= 0 then return end
    if type(height) ~= "number" or ns.IsSecret(height) or height <= 0 then return end
    local x0 = width * math.max(0, from)
    local x1 = math.max(x0 + 2, width * math.min(1, to))
    fx.flash:ClearAllPoints()
    fx.flash:SetPoint("TOPLEFT", fx.layer, "TOPLEFT", x0, 0)
    fx.flash:SetPoint("BOTTOMRIGHT", fx.layer, "BOTTOMLEFT", x1, 0)
    fx.flash:SetAlpha(0.7)
    fx.flash:Show()
    fx.active = math.max(6, math.min(SPARKS, math.floor(6 + (to - from) * 80)))
    for i = 1, SPARKS do
        local spark = fx.sparks[i]
        spark.texture:Hide()
        if i <= fx.active then
            local size = 4 + math.random() * 5
            spark.texture:SetSize(size, size)
            spark.x = x0 + math.random() * (x1 - x0)
            spark.y = math.random() * height * 0.6
            spark.vx = 8 + math.random() * 30
            spark.vy = 8 + math.random() * 16
            spark.delay = math.random() * 0.35
            spark.life = 0.45 + math.random() * 0.4
        end
    end
    fx.elapsed = 0
    fx.layer:SetScript("OnUpdate", function(_, dt) Step(fx, dt) end)
end

-- Bubbles: soft dots that keep drifting left to right inside the filled part only (a clip frame ends
-- at the fill). They run as looping animation groups, so no Lua runs per frame; each loop moves a
-- bubble to a new random spot. They play while the bar is shown.
local BUBBLES = 16
local BUBBLE = "Interface\\AddOns\\QuietUI\\Media\\round.tga"

local function Place(bubble, layer)
    local width, height = layer:GetWidth(), layer:GetHeight()
    if type(width) ~= "number" or ns.IsSecret(width) or width <= 0 then return end
    if type(height) ~= "number" or ns.IsSecret(height) or height <= 0 then return end
    bubble:ClearAllPoints()
    bubble:SetPoint("CENTER", layer, "BOTTOMLEFT", math.random() * width, height * (0.2 + math.random() * 0.6))
end

local function Animate(bubble, layer)
    local group = bubble:CreateAnimationGroup()
    if not group or type(group.CreateAnimation) ~= "function" then return nil end
    if group.SetLooping then group:SetLooping("REPEAT") end
    local duration = 2.5 + math.random() * 2
    local delay = math.random() * 2
    local drift = group:CreateAnimation("Translation")
    if drift then
        if drift.SetOffset then drift:SetOffset(40 + math.random() * 80, math.random() * 4 - 2) end
        if drift.SetDuration then drift:SetDuration(duration) end
        if drift.SetStartDelay then drift:SetStartDelay(delay) end
    end
    local fadeIn = group:CreateAnimation("Alpha")
    if fadeIn then
        if fadeIn.SetFromAlpha then fadeIn:SetFromAlpha(0) end
        if fadeIn.SetToAlpha then fadeIn:SetToAlpha(0.6) end
        if fadeIn.SetDuration then fadeIn:SetDuration(duration * 0.3) end
        if fadeIn.SetStartDelay then fadeIn:SetStartDelay(delay) end
    end
    local fadeOut = group:CreateAnimation("Alpha")
    if fadeOut then
        if fadeOut.SetFromAlpha then fadeOut:SetFromAlpha(0.6) end
        if fadeOut.SetToAlpha then fadeOut:SetToAlpha(0) end
        if fadeOut.SetDuration then fadeOut:SetDuration(duration * 0.7) end
        if fadeOut.SetStartDelay then fadeOut:SetStartDelay(delay + duration * 0.3) end
    end
    group:SetScript("OnLoop", function() Place(bubble, layer) end)
    return group
end

function Burst.Bubbles(bar)
    local clip = CreateFrame("Frame", nil, bar)
    if type(clip.SetClipsChildren) == "function" then pcall(clip.SetClipsChildren, clip, true) end
    -- Full bar width, so a bubble keeps its spot while the clip grows with the fill.
    local layer = CreateFrame("Frame", nil, clip)
    layer:SetAllPoints(bar)
    local bubbles = { bar = bar, clip = clip, layer = layer, groups = {} }
    for i = 1, BUBBLES do
        local bubble = layer:CreateTexture(nil, "ARTWORK", nil, 2)
        bubble:SetTexture(BUBBLE)
        bubble:SetBlendMode("ADD")
        bubble:SetVertexColor(0.8, 0.93, 1)
        local size = 2 + math.random() * 2.5
        bubble:SetSize(size, size)
        -- Invisible between loops; the alpha animations show it.
        bubble:SetAlpha(0)
        bubbles.groups[i] = Animate(bubble, layer)
        bubbles[i] = bubble
    end
    local function play()
        for i, group in pairs(bubbles.groups) do
            -- A bubble gets its first spot once the bar has a size; later spots come from OnLoop.
            if not bubbles[i]:GetPoint(1) then Place(bubbles[i], layer) end
            if not group:IsPlaying() then group:Play() end
        end
    end
    local function stop()
        for _, group in pairs(bubbles.groups) do group:Stop() end
    end
    layer:SetScript("OnShow", play)
    layer:SetScript("OnHide", stop)
    bubbles.play, bubbles.stop = play, stop
    return bubbles
end

-- The clip ends where the fill ends; without a fill texture no bubble is shown.
function Burst.Fill(bubbles, fill)
    if not bubbles then return end
    bubbles.clip:ClearAllPoints()
    if not fill then
        bubbles.stop(); bubbles.clip:Hide()
        return
    end
    bubbles.clip:SetPoint("TOPLEFT", bubbles.bar, "TOPLEFT", 0, 0)
    bubbles.clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    bubbles.clip:Show()
    bubbles.play()
end
