-- Blizzard-shaped window fixtures for the public Modern Windows and Map contracts.
local W = {}

function W.area(ns, key)
    for _, item in ipairs(ns.Modern.Areas()) do
        if item.key == key then return item end
    end
    error("Modern area is not registered: " .. key, 0)
end

function W.enable(ns, extra)
    QuietUICharDB = { modernize = { enabled = true } }
    for key, value in pairs(extra or {}) do QuietUICharDB.modernize[key] = value end
    ns.Modern.Apply()
end

function W.texture(parent, name, alpha)
    local texture = parent:CreateTexture(name, "ARTWORK")
    texture:SetTexture("Interface\\Blizzard\\" .. (name or "Art"))
    texture:SetAlpha(alpha or 0.7)
    return texture
end

function W.window(name)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(480, 420)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 31, -71)
    frame.chrome = W.texture(frame, name .. "Chrome", 0.61)
    frame.NineSlice = CreateFrame("Frame", nil, frame)
    frame.NineSlice.art = W.texture(frame.NineSlice, name .. "NineSlice", 0.62)
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString(nil, "OVERLAY")
    frame.TitleContainer.TitleText:SetText(name .. " title")
    frame.TitleContainer.TitleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    frame.TitleContainer.TitleText.GetTextColor = function(self)
        return unpack(self._textColor or { 1, 1, 1, 1 })
    end
    return frame
end

function W.tab(parent, name)
    local tab = CreateFrame("Button", name, parent)
    tab.art = W.texture(tab, name .. "Art")
    return tab
end

function W.button(parent, name)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(90, 22)
    button:SetPoint("BOTTOM", parent, "BOTTOM", 0, 8)
    button.normal = W.texture(button, name .. "Normal")
    button.GetNormalTexture = function() return button.normal end
    button.Text = button:CreateFontString(nil, "OVERLAY")
    button.Text:SetText(name)
    return button
end

function W.icon(parent, name, quality)
    local button = CreateFrame("Button", name, parent)
    button.Icon = W.texture(button, name .. "Icon")
    button.Icon:SetTexCoord(0, 1, 0, 1)
    button.Quality = W.texture(button, name .. "Quality")
    button.Quality:SetVertexColor(quality[1], quality[2], quality[3], 1)
    return button
end

function W.point(frame)
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    return { point, relativePoint, x, y }, relative
end

function W.isDark(frame)
    if frame._backdropColor and frame._backdropColor[1] == 0.05 then return true end
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == 0.05 then return true end
    end
    for _, child in ipairs(frame._children) do
        if child._color and child._color[1] == 0.05 then return true end
    end
    return false
end

function W.hasTexture(mock, parent, needle)
    for _, object in ipairs(mock.frames) do
        local current = object
        for _ = 1, 8 do
            if not current then break end
            if current == parent then
                if type(object._texture) == "string" and object._texture:find(needle, 1, true) then return true end
                break
            end
            current = current._parent
        end
    end
    return false
end

return W
