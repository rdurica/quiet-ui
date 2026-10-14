local _, ns = ...

-- Fade step and easing. Old globals can alias new frames (MainMenuBar may be
-- MainActionBar), so a frame fades at most once per tick or it would fade twice as fast.

local FADE_OUT = 0.3

local fadeTick = 0
local frameHot = false

function ns.NextFadeTick()
    fadeTick = fadeTick + 1
    frameHot = false
end

function ns.FrameHot()
    return frameHot
end

-- Shared fade step: appears at once, fades out over FADE_OUT.
local function StepAlpha(frame, target, elapsed, current)
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    if type(current) ~= "number" then
        current = ns.Alpha.Current(frame) or target
    end
    local nextAlpha = target
    if target < current then
        local step = (elapsed or 0) / FADE_OUT
        if current - target > step then
            nextAlpha = current - step
        end
    end
    if nextAlpha ~= target then frameHot = true end
    ns.PushAlpha(frame, nextAlpha)
end

function ns.UpdateFaded(frame, show, elapsed)
    if frame._quietTick == fadeTick then return end
    frame._quietTick = fadeTick
    local target = show and 1 or 0
    -- Already there. A fade still runs while the value is between 0 and 1.
    if frame._quietAlpha == target then return end
    StepAlpha(frame, target, elapsed, frame._quietAlpha)
end

-- Appears at once and fades out. Same rule as UpdateFaded, without the tick guard.
function ns.EaseAlpha(frame, show, elapsed)
    if not frame or not frame.SetAlpha then return end
    local target = show and 1 or 0
    if frame._quietSecret == nil and frame._quietAlpha == target then return end
    -- A held secret alpha is stale; read the frame instead.
    local current = frame._quietSecret == nil and frame._quietAlpha or nil
    StepAlpha(frame, target, elapsed, current)
end
