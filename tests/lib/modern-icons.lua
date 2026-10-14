-- Observable Blizzard-shaped controls for the Modern bars and auras contracts.
-- Tests use the public Modern and Bars APIs; this helper only builds client fixtures.
local I = {}

local function art(parent, name)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetTexture("Interface\\Icons\\" .. name)
    texture:SetAlpha(0.7)
    return texture
end

function I.button(mock, name, parent)
    local button = CreateFrame("CheckButton", name, parent)
    _G[name] = button
    button:SetSize(43, 37)
    button.Icon = art(button, name .. "-Icon")
    button.icon = button.Icon
    button.IconTexture = button.Icon
    button.NormalTexture = art(button, name .. "-Normal")
    button.PushedTexture = art(button, name .. "-Pushed")
    button.HighlightTexture = art(button, name .. "-Highlight")
    button.CheckedTexture = art(button, name .. "-Checked")
    button.Border = art(button, name .. "-Border")
    button.SlotBackground = art(button, name .. "-Slot")
    button.GetNormalTexture = function() return button.NormalTexture end
    button.GetPushedTexture = function() return button.PushedTexture end
    button.GetHighlightTexture = function() return button.HighlightTexture end
    button.GetCheckedTexture = function() return button.CheckedTexture end
    button.HotKey = button:CreateFontString(nil, "OVERLAY")
    button.HotKey:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    button.Count = button:CreateFontString(nil, "OVERLAY")
    button.Count:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    return button
end

function I.barArt(parent, name)
    local texture = art(parent, name)
    _G[name] = texture
    return texture
end

function I.aura(mock, name, parent, dispel)
    local button = I.button(mock, name, parent)
    button.Duration = button:CreateFontString(nil, "OVERLAY")
    button.Duration:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    button.DebuffType = dispel
    button.debuffType = dispel
    return button
end

function I.zoomed(texture)
    local a, b, c, d = texture:GetTexCoord()
    return a == 0.08 and b == 0.92 and c == 0.08 and d == 0.92
end

function I.outlined(font)
    local _, _, flags = font:GetFont()
    return type(flags) == "string" and flags:find("OUTLINE", 1, true) ~= nil
end

function I.border(frame)
    local n = 0
    for _, child in ipairs(frame._regions) do
        if child._layer == "BORDER" and child._shown then n = n + 1 end
    end
    return n >= 4
end

function I.watchVisibility(frame)
    local calls = { hide = 0, show = 0 }
    local hide, show = frame.Hide, frame.Show
    frame.Hide = function(self, ...)
        calls.hide = calls.hide + 1
        return hide(self, ...)
    end
    frame.Show = function(self, ...)
        calls.show = calls.show + 1
        return show(self, ...)
    end
    return calls
end

return I
