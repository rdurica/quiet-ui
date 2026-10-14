local _, ns = ...

-- Puts every held frame and texture back to the alpha it had before QuietUI.

function ns.RestoreAlpha()
    local Alpha = ns.Alpha
    for _, frame in ipairs(Alpha.hooked) do
        if Alpha.saved[frame] ~= nil then ns.ReleaseAlpha(frame) end
    end
    for tex, alpha in pairs(Alpha.texture) do
        tex._quietApplying = true
        tex:SetAlpha(alpha or 1)
        tex._quietApplying = false
    end
end
