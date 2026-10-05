local _, ns = ...

-- Shared helpers: saved variables, messages, and the alpha machinery that
-- keeps a wanted alpha even when Blizzard code overwrites it.

local FADE_OUT = 0.3
local PREFIX = "|cff8fd4c8QuietUI|r: "

local hooked = {}
local savedAlpha = {}
local textureAlpha = {}
local reported = {}
local chatHeld = {}

function ns.DB()
    if type(QuietUIDB) ~= "table" then
        QuietUIDB = {}
    end
    if QuietUIDB.enabled == nil then
        QuietUIDB.enabled = true
    end
    return QuietUIDB
end

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

function ns.Report(name, err)
    if reported[name] then return end
    reported[name] = true
    print(PREFIX .. name .. " error (shown once): " .. tostring(err))
end

-- Forbidden frames throw on almost any method call from addon code.
function ns.Usable(frame)
    if type(frame) ~= "table" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

-- Secret values (this client hides unit power even out of combat) cannot be
-- compared or used in arithmetic, only passed on to widgets.
function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

function ns.FrameName(frame)
    if ns.Usable(frame) and frame.GetName then
        return frame:GetName()
    end
end

function ns.MouseOver(frame)
    if not frame or not frame.IsShown or not frame.IsMouseOver then return false end
    if not frame:IsShown() then return false end
    return frame:IsMouseOver() and true or false
end

-- Hover follows the frame under the cursor, not the pixel. The same chain
-- means the bars do not need another walk. IsMouseOver is the fallback when
-- this client has no focus API.
local focusFallback = false
local focusReady = false
local focusFresh = false
local focusHit = {}
local hoverFrames = setmetatable({}, { __mode = "k" })
local nextHit = {}
local focusChain = {}
local focusCount = 0
local nextChain = {}
local nextCount = 0

local function ReadFoci()
    if type(GetMouseFoci) == "function" then
        local ok, result = pcall(GetMouseFoci)
        if not ok then return nil, false end
        if type(result) == "table" then return result, true end
        return nil, true
    elseif type(GetMouseFocus) == "function" then
        local ok, result = pcall(GetMouseFocus)
        if not ok then return nil, false end
        if result then return { result }, true end
        return nil, true
    end
    focusFallback = true
    return nil, false
end

local function WalkFoci(foci)
    local n = 0
    if foci then
        for i = 1, #foci do
            local frame = foci[i]
            local depth = 0
            while ns.Usable(frame) and depth < 12 do
                n = n + 1
                nextChain[n] = frame
                if type(frame.GetParent) ~= "function" then break end
                local ok, parent = pcall(frame.GetParent, frame)
                if not ok then break end
                frame = parent
                depth = depth + 1
            end
        end
    end
    for i = n + 1, nextCount do
        nextChain[i] = nil
    end
    nextCount = n
    return n
end

local function CommitChain(n)
    for key in pairs(focusHit) do
        focusHit[key] = nil
    end
    for i = 1, n do
        local frame = nextChain[i]
        focusHit[frame] = true
        focusChain[i] = frame
    end
    for i = n + 1, focusCount do
        focusChain[i] = nil
    end
    focusCount = n
    focusReady = true
    focusFresh = true
end

local function SampleFocus()
    if focusFallback then return nil end
    local foci, ok = ReadFoci()
    if focusFallback or not ok then
        focusReady = false
        return nil
    end
    return WalkFoci(foci)
end

local function SameChain(n)
    if n ~= focusCount then return false end
    for i = 1, n do
        if nextChain[i] ~= focusChain[i] then return false end
    end
    return true
end

-- True when a tracked hover changes. Other windows still refresh the focus chain.
-- Nil when this client has no focus API.
-- Zero is a real sample: nothing is under the cursor.
function ns.FocusChanged()
    local n = SampleFocus()
    if n == nil then return nil end
    if SameChain(n) then
        focusReady = true
        return false
    end
    for key in pairs(nextHit) do nextHit[key] = nil end
    for i = 1, n do nextHit[nextChain[i]] = true end
    local changed = not focusReady
    for frame in pairs(hoverFrames) do
        if (focusHit[frame] or false) ~= (nextHit[frame] or false) then
            changed = true
            break
        end
    end
    CommitChain(n)
    return changed
end

function ns.RefreshMouse()
    if focusFresh then
        focusFresh = false
        return
    end
    local n = SampleFocus()
    if n == nil then return end
    CommitChain(n)
    focusFresh = false
end

function ns.Hit(frame)
    if frame then hoverFrames[frame] = true end
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if focusFallback or not focusReady then
        return frame.IsMouseOver and frame:IsMouseOver() and true or false
    end
    return focusHit[frame] and true or false
end

-- Motion without clicks. A catcher can sit under buttons and still see empty slots.
function ns.ArmCatcher(frame)
    if not frame then return end
    local motion = false
    if type(frame.SetMouseMotionEnabled) == "function" then
        motion = pcall(frame.SetMouseMotionEnabled, frame, true)
    end
    if type(frame.SetMouseClickEnabled) == "function" then
        pcall(frame.SetMouseClickEnabled, frame, false)
    end
    if motion then return end
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if type(frame.SetPassThroughButtons) == "function" then
        pcall(frame.SetPassThroughButtons, frame, "LeftButton", "RightButton")
    end
end

------------------------------------------------------------------------------
-- Frame alpha
------------------------------------------------------------------------------
function ns.Remember(frame)
    if not frame or savedAlpha[frame] then return end
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" then alpha = 1 end
    savedAlpha[frame] = alpha
end

function ns.EnsureAlphaHook(frame)
    if not frame or frame._quietAlphaHook or not frame.SetAlpha then return end
    frame._quietAlphaHook = true
    hooked[#hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._quietApplying then return end
        if not ns.DB().enabled then return end
        if self._quietChat and ns.ModernChat and not ns.ModernChat() then return end
        local want = self._quietSecret
        if want == nil then
            want = self._quietAlpha
            if type(want) ~= "number" then return end
            if not ns.IsSecret(alpha) and math.abs((alpha or 0) - want) < 0.02 then return end
        end
        self._quietApplying = true
        self:SetAlpha(want)
        self._quietApplying = false
    end)
end

local function CurrentAlpha(frame)
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) then return nil end
    return alpha
end

function ns.PushAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    -- The SetAlpha hook already puts back overwrites. Skip the read when nothing changed.
    if frame._quietSecret == nil and frame._quietAlpha == alpha then return end
    frame._quietAlpha = alpha
    frame._quietSecret = nil
    local current = CurrentAlpha(frame)
    if current and math.abs(current - alpha) < 0.01 then
        return
    end
    frame._quietApplying = true
    frame:SetAlpha(alpha)
    frame._quietApplying = false
end

-- Holds an alpha that may be secret; the fade is skipped since it cannot be read.
function ns.HoldSecretAlpha(frame, alpha)
    if not ns.Usable(frame) or not frame.SetAlpha then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    frame._quietAlpha = nil
    frame._quietSecret = alpha
    frame._quietApplying = true
    frame:SetAlpha(alpha)
    frame._quietApplying = false
end

-- Remember, hook, and set in one go.
function ns.HoldAlpha(frame, alpha)
    if not ns.Usable(frame) then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    if ns.MarkingChat then ns.NoteChat(frame) end
    ns.PushAlpha(frame, alpha)
end

function ns.ReleaseAlpha(frame, forget)
    if not ns.Usable(frame) or type(frame.SetAlpha) ~= "function" then
        if forget then savedAlpha[frame] = nil end
        return
    end
    frame._quietAlpha = nil
    frame._quietSecret = nil
    frame._quietApplying = true
    local ok, err = pcall(frame.SetAlpha, frame, savedAlpha[frame] or 1)
    frame._quietApplying = false
    if not ok then ns.Report("restore alpha", err); return end
    -- Optional fading must capture a fresh baseline when enabled again.
    if forget then savedAlpha[frame] = nil end
end

function ns.NoteChat(obj)
    if not obj or obj._quietChat then return end
    obj._quietChat = true
    chatHeld[#chatHeld + 1] = obj
end

function ns.ReleaseChatHold()
    for i = 1, #chatHeld do
        local obj = chatHeld[i]
        if obj.GetObjectType and obj:GetObjectType() == "Texture" then
            obj._quietApplying = true
            obj:SetAlpha(textureAlpha[obj] or 1)
            obj._quietApplying = false
        else
            ns.ReleaseAlpha(obj)
        end
    end
end

-- Old globals can alias new frames (MainMenuBar may be MainActionBar), so a
-- frame fades at most once per tick or it would fade twice as fast.
local fadeTick = 0
local frameHot = false

function ns.NextFadeTick()
    fadeTick = fadeTick + 1
    frameHot = false
end

function ns.FrameHot()
    return frameHot
end

function ns.UpdateFaded(frame, show, elapsed)
    if frame._quietTick == fadeTick then return end
    frame._quietTick = fadeTick
    local target = show and 1 or 0
    -- Already there. A fade still runs while the value is between 0 and 1.
    if frame._quietAlpha == target then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    local current = frame._quietAlpha
    if type(current) ~= "number" then
        current = CurrentAlpha(frame) or target
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

-- Appears at once and fades out. Same rule as UpdateFaded, without the tick guard.
function ns.EaseAlpha(frame, show, elapsed)
    if not frame or not frame.SetAlpha then return end
    local target = show and 1 or 0
    if frame._quietSecret == nil and frame._quietAlpha == target then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    local current = frame._quietAlpha
    if type(current) ~= "number" or frame._quietSecret ~= nil then
        current = CurrentAlpha(frame)
        if type(current) ~= "number" then current = target end
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

------------------------------------------------------------------------------
-- Textures
------------------------------------------------------------------------------
function ns.ForceTextureHidden(tex)
    if not tex or not tex.SetAlpha or not tex.GetAlpha then return end
    if tex.GetObjectType and tex:GetObjectType() ~= "Texture" then return end
    if textureAlpha[tex] == nil then
        textureAlpha[tex] = tex:GetAlpha()
    end
    if ns.MarkingChat then ns.NoteChat(tex) end
    if not tex._quietTexHook then
        tex._quietTexHook = true
        pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
            if self._quietApplying or not ns.DB().enabled then return end
            if self._quietChat and ns.ModernChat and not ns.ModernChat() then return end
            if (alpha or 0) < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    if not ns.DB().enabled then return end
    if tex:GetAlpha() >= 0.01 then
        tex._quietApplying = true
        tex:SetAlpha(0)
        tex._quietApplying = false
    end
end

function ns.HideTextures(frame)
    if not frame or not frame.GetNumRegions then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        ns.ForceTextureHidden(regions[i])
    end
end

-- Hides a texture, or every texture region of a frame.
function ns.HideBackground(background)
    if not background then return end
    if background.GetObjectType and background:GetObjectType() == "Texture" then
        ns.ForceTextureHidden(background)
    else
        ns.HideTextures(background)
    end
end

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------

function ns.RestoreAlpha()
    for _, frame in ipairs(hooked) do
        if savedAlpha[frame] ~= nil then ns.ReleaseAlpha(frame) end
    end
    for tex, alpha in pairs(textureAlpha) do
        tex._quietApplying = true
        tex:SetAlpha(alpha or 1)
        tex._quietApplying = false
    end
end
