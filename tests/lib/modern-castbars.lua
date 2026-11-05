-- Cast bar fixtures shaped after retail CastingBarMixin: a StatusBar whose fill Blizzard re-textures with an atlas
-- per cast, Border, TextBorder, Background and Flash art, a Spark, the spell name Text, the spell Icon left of
-- the bar and the cast `barType`.
local C = {}

local function art(bar, key, layer)
    local texture = bar:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\CastingBar\\" .. key)
    texture:SetAlpha(1)
    texture:SetVertexColor(1, 1, 1, 1)
    bar[key] = texture
    return texture
end

function C.castbar(name)
    local bar = CreateFrame("StatusBar", name, UIParent)
    bar:SetSize(208, 11)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("ui-castingbar-filling-standard")
    bar.SetStatusBarTexture = function(_, value) fill:SetTexture(value) end
    bar.GetStatusBarTexture = function() return fill end
    bar._barColor = { 1, 1, 1, 1 }
    bar.SetStatusBarColor = function(self, ...) self._barColor = { ... } end
    bar.GetStatusBarColor = function(self) return unpack(self._barColor) end
    for _, key in ipairs({ "Border", "TextBorder", "Background", "Flash" }) do art(bar, key) end
    art(bar, "Spark", "OVERLAY")
    bar.Text = bar:CreateFontString(nil, "OVERLAY")
    bar.Text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    bar.Text:SetPoint("TOP", bar, "BOTTOM", 0, -1)
    bar.Icon = bar:CreateTexture(nil, "ARTWORK")
    bar.Icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
    bar.Icon:SetSize(16, 16)
    bar.Icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
    bar.Icon:SetAlpha(1)
    function bar:SetLook() end
    bar.barType = "standard"
    return bar, fill
end

-- The own spell icon: a texture of the bar anchored left of it, not Blizzard's Icon.
function C.icon(bar)
    for _, region in ipairs(bar._regions) do
        local p = region._points and region._points[1]
        if region ~= bar.Icon and region._kind == "Texture" and p and p[1] == "RIGHT" and p[2] == bar and p[3] == "LEFT" then
            return region
        end
    end
end

-- The frame carrying the own icon's border.
function C.iconBorder(bar)
    local icon = C.icon(bar)
    for _, child in ipairs(bar._children) do
        if child._kind == "Frame" and icon and child._points and child._points[1] and child._points[1][2] == icon then
            return child
        end
    end
end

return C
