local _, ns = ...

-- The alpha machinery that keeps a wanted alpha even when Blizzard code overwrites it.
-- State is shared with Fade, Textures and Restore.

local Alpha = {
    hooked = {},
    saved = {},
    texture = {},
    chat = {},
}
ns.Alpha = Alpha

function Alpha.Current(frame)
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) then return nil end
    return alpha
end

function ns.Remember(frame)
    if not frame or Alpha.saved[frame] then return end
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" then alpha = 1 end
    Alpha.saved[frame] = alpha
end

function ns.EnsureAlphaHook(frame)
    if not frame or frame._quietAlphaHook or not frame.SetAlpha then return end
    frame._quietAlphaHook = true
    Alpha.hooked[#Alpha.hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._quietApplying then return end
        if not ns.DB().enabled then return end
        if self._quietChat and ns.Settings.ModernChat and not ns.Settings.ModernChat() then return end
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

function ns.PushAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    -- The SetAlpha hook already puts back overwrites. Skip the read when nothing changed.
    if frame._quietSecret == nil and frame._quietAlpha == alpha then return end
    frame._quietAlpha = alpha
    frame._quietSecret = nil
    local current = Alpha.Current(frame)
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
        if forget then Alpha.saved[frame] = nil end
        return
    end
    frame._quietAlpha = nil
    frame._quietSecret = nil
    frame._quietApplying = true
    local ok, err = pcall(frame.SetAlpha, frame, Alpha.saved[frame] or 1)
    frame._quietApplying = false
    if not ok then ns.Report("restore alpha", err); return end
    -- Optional fading must capture a fresh baseline when enabled again.
    if forget then Alpha.saved[frame] = nil end
end

function ns.NoteChat(obj)
    if not obj or obj._quietChat then return end
    obj._quietChat = true
    Alpha.chat[#Alpha.chat + 1] = obj
end

function ns.ReleaseChatHold()
    for i = 1, #Alpha.chat do
        local obj = Alpha.chat[i]
        if obj.GetObjectType and obj:GetObjectType() == "Texture" then
            obj._quietApplying = true
            obj:SetAlpha(Alpha.texture[obj] or 1)
            obj._quietApplying = false
        else
            ns.ReleaseAlpha(obj)
        end
    end
end
