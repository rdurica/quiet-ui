local _, ns = ...

-- Texture hiding. The original alpha is kept in ns.Alpha.texture for restore.

function ns.ForceTextureHidden(tex)
    if not tex or not tex.SetAlpha or not tex.GetAlpha then return end
    if tex.GetObjectType and tex:GetObjectType() ~= "Texture" then return end
    local textureAlpha = ns.Alpha.texture
    if textureAlpha[tex] == nil then
        local saved = tex:GetAlpha()
        if ns.IsSecret(saved) or type(saved) ~= "number" then saved = 1 end
        textureAlpha[tex] = saved
    end
    if ns.MarkingChat then ns.NoteChat(tex) end
    if not tex._quietTexHook then
        tex._quietTexHook = true
        pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
            if self._quietApplying or not ns.DB().enabled then return end
            if self._quietChat and ns.Settings.ModernChat and not ns.Settings.ModernChat() then return end
            if type(alpha) == "number" and not ns.IsSecret(alpha) and alpha < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    if not ns.DB().enabled then return end
    -- A secret alpha cannot be compared; treat it as visible.
    local alpha = tex:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha >= 0.01 then
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
