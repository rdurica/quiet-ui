-- Fixtures and observable assertions for the Modern minimap and tooltip areas.
local M = {}

function M.area(ns, key)
    for _, area in ipairs(ns.Modern.Areas()) do
        if area.key == key then return area end
    end
    error("Modern area is not registered: " .. key, 0)
end

function M.enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

function M.minimap(mock)
    local map = Minimap
    map._mask = "Textures\\MinimapMask"
    map.SetMaskTexture = function(self, texture) self._mask = texture end
    map.GetMaskTexture = function(self) return self._mask end
    map.EnableMouseWheel = function(self, enabled) self._wheel = enabled and true or false end
    map.IsMouseWheelEnabled = function(self) return self._wheel == true end
    map._wheel = false
    map:SetScript("OnMouseWheel", function() map._oldWheelCalls = (map._oldWheelCalls or 0) + 1 end)

    local function frame(name)
        return CreateFrame("Frame", name, map)
    end
    local parts = {
        ring = frame("MinimapBorder"), north = frame("MinimapNorthTag"),
        zoomIn = CreateFrame("Button", "MinimapZoomIn", map),
        zoomOut = CreateFrame("Button", "MinimapZoomOut", map),
        queue = frame("QueueStatus"), eye = frame("LFGEye"),
        mail = frame("MiniMapMailFrame"), tracking = frame("MiniMapTracking"),
    }
    for _, f in pairs(parts) do f:EnableMouse(true) end
    parts.ring:SetAlpha(0.6); parts.north:SetAlpha(0.7)
    parts.zoomIn:SetAlpha(0.8); parts.zoomOut:SetAlpha(0.9)
    return map, parts
end

function M.tooltip(name, withNineSlice)
    local tip = CreateFrame("GameTooltip", name, UIParent, "BackdropTemplate")
    local bar = CreateFrame("StatusBar", name .. "StatusBar", tip)
    local texture = bar:CreateTexture(nil, "ARTWORK")
    texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.SetStatusBarTexture = function(_, value) texture:SetTexture(value) end
    bar.GetStatusBarTexture = function() return texture end
    tip.StatusBar = bar
    tip.GetBackdropColor = function(self)
        if self._backdropColor == nil then return end
        return unpack(self._backdropColor)
    end
    tip.GetBackdropBorderColor = function(self)
        if self._backdropBorder == nil then return end
        return unpack(self._backdropBorder)
    end
    if withNineSlice then
        local nine = CreateFrame("Frame", nil, tip)
        nine:SetAlpha(0.65)
        tip.NineSlice = nine
    end
    return tip, bar
end

function M.borderColor(frame)
    if frame._backdropBorder then return frame._backdropBorder end
    for _, child in ipairs(frame._children) do
        if child._color and (child._w == 1 or child._h == 1) then return child._color end
    end
    for _, region in ipairs(frame._regions) do
        if region._color and (region._w == 1 or region._h == 1) then return region._color end
    end
end

-- A tooltip's accent edge: the shown 2 px line along its top.
function M.topColor(frame)
    for _, region in ipairs(frame._regions) do
        if region._color and region._h == 2 and region._shown then return region._color end
    end
end

function M.sameColor(A, actual, expected, label)
    A.ok(type(actual) == "table", (label or "border") .. " has a colour")
    for i = 1, #expected do A.near(actual[i], expected[i], 1e-6, (label or "border") .. " component " .. i) end
end

function M.point(frame)
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    return point, relative, relativePoint, x, y
end

return M
