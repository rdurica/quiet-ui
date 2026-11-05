-- Retail 12.0 (Midnight) action bar shapes, from Blizzard_ActionBar Mainline/MainActionBar.xml and
-- ActionButtonTemplate.xml: MainActionBar with BorderArt, EndCaps.{LeftEndCap,RightEndCap} and ActionBarPageNumber;
-- buttons with `icon`, IconMask (a MaskTexture on the icon), SlotBackground, SlotArt, Flash, Border, and the
-- Normal / Pushed / Highlight / Checked textures reached through the Get*Texture methods.
local B = {}

local function atlas(parent, name, layer, alpha)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Atlas\\" .. name)
    texture:SetAlpha(alpha or 0.8)
    return texture
end

function B.bar()
    local bar = CreateFrame("Frame", "MainActionBar", UIParent)
    bar:SetSize(454, 35)
    bar.BorderArt = atlas(bar, "UI-HUD-ActionBar-Frame", "BACKGROUND", 0.81)
    bar.EndCaps = CreateFrame("Frame", nil, bar)
    bar.EndCaps.LeftEndCap = atlas(bar.EndCaps, "ui-hud-actionbar-gryphon-left", "OVERLAY", 0.82)
    bar.EndCaps.RightEndCap = atlas(bar.EndCaps, "ui-hud-actionbar-gryphon-right", "OVERLAY", 0.83)
    bar.ActionBarPageNumber = CreateFrame("Frame", nil, bar)
    bar.ActionBarPageNumber.Text = bar.ActionBarPageNumber:CreateFontString(nil, "OVERLAY")
    bar.ActionBarPageNumber.Text:SetText("1")
    bar.ActionBarPageNumber.UpButton = CreateFrame("Button", nil, bar.ActionBarPageNumber)
    bar.ActionBarPageNumber.DownButton = CreateFrame("Button", nil, bar.ActionBarPageNumber)
    return bar
end

-- One state texture of a button: Blizzard sets an atlas, SetXTexture(file) swaps the file.
local function state(button, key, atlasName)
    local texture = atlas(button, atlasName, "ARTWORK", 0.7)
    button[key] = texture
    button["Get" .. key] = function() return texture end
    button["Set" .. key] = function(_, file) texture:SetTexture(file) end
end

function B.button(name, parent)
    local button = CreateFrame("CheckButton", name, parent)
    _G[name] = button
    button:SetSize(45, 45)
    local icon = atlas(button, name .. "-Icon", "BACKGROUND", 1)
    button.icon = icon
    button.IconMask = button:CreateTexture(nil, "BACKGROUND")
    button.IconMask._kind = "MaskTexture"
    button.IconMask:SetTexture("Interface\\Atlas\\UI-HUD-ActionBar-IconFrame-Mask")
    local masks = { button.IconMask }
    function icon:GetNumMaskTextures() return #masks end
    function icon:GetMaskTexture(index) return masks[index] end
    function icon:AddMaskTexture(m) masks[#masks + 1] = m end
    function icon:RemoveMaskTexture(m)
        for i, current in ipairs(masks) do if current == m then table.remove(masks, i); return end end
    end
    button.SlotBackground = atlas(button, "UI-HUD-ActionBar-IconFrame-Background", "BACKGROUND", 0.84)
    button.SlotArt = atlas(button, "ui-hud-actionbar-iconframe-slot", "BACKGROUND", 0.85)
    button.Flash = atlas(button, "UI-HUD-ActionBar-IconFrame-Flash", "ARTWORK", 0.86)
    button.Flash:Hide()
    button.Border = atlas(button, "UI-HUD-ActionBar-IconFrame-Border", "OVERLAY", 0.87)
    button.Border:Hide()
    state(button, "NormalTexture", "UI-HUD-ActionBar-IconFrame")
    state(button, "PushedTexture", "UI-HUD-ActionBar-IconFrame-Down")
    state(button, "HighlightTexture", "UI-HUD-ActionBar-IconFrame-Mouseover")
    state(button, "CheckedTexture", "UI-HUD-ActionBar-IconFrame-Mouseover")
    button.TextOverlayContainer = CreateFrame("Frame", nil, button)
    local container = button.TextOverlayContainer
    container.HotKey = container:CreateFontString(nil, "OVERLAY")
    container.HotKey:SetFont("Fonts\\ARIALN.TTF", 12, "")
    container.Count = container:CreateFontString(nil, "OVERLAY")
    container.Count:SetFont("Fonts\\ARIALN.TTF", 14, "")
    button.HotKey, button.Count = container.HotKey, container.Count     -- ActionButtonTextOverlayContainerMixin:OnLoad
    button.SetButtonState = function(self, value) self._buttonState = value end
    button.GetButtonState = function(self) return self._buttonState or "NORMAL" end
    return button
end

local function rgbOf(color) return color and color[1], color and color[2], color and color[3] end

-- True when a texture shows a theme colour: a solid colour texture, or the theme's flat bar file tinted.
function B.themed(texture, theme)
    local colour = texture._color or (texture._texture == theme.bar and texture._vertex) or nil
    if not colour then return false end
    for _, key in ipairs({ "bg", "border", "accent" }) do
        local r, g, b = rgbOf(theme[key])
        if colour[1] == r and colour[2] == g and colour[3] == b then return true end
    end
    return false
end

-- Flat, themed and visible: alpha above 0, shown, not held.
function B.visibleFlat(texture, theme)
    return texture._shown and (texture._alpha or 1) > 0 and B.themed(texture, theme)
end

-- Own regions of the button (created by the skin, not part of the fixture) that are visible and flat.
function B.visibleOwn(button, theme, known)
    local set = {}
    for _, region in ipairs(button._regions) do
        if not known[region] and B.visibleFlat(region, theme) then set[region] = true end
    end
    return set
end

return B
