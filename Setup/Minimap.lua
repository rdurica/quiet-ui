local _, ns = ...

-- Minimap button. Unnamed, parented to Minimap, so the fade walk never sees it.
local Setup = ns.Setup
local S = Setup.state

-- Bottom-left of the minimap, clear of the tracking button.
local MINIMAP_ANGLE = 225
-- On a square map the button sits inside the edge, with the other flat buttons (Features/Modern/Areas/MinimapButtons.lua).
local SQUARE_INSIDE = 14
local minimapButton
local minimapHooked

local function MinimapDegrees()
    local n = ns.DB().minimap
    if type(n) ~= "number" or n ~= n then return MINIMAP_ANGLE end
    n = n % 360
    if n < 0 then n = n + 360 end
    return n
end

local function PlaceMinimap(button)
    local map = Minimap
    if not map or not button then return end
    local rad = math.rad(MinimapDegrees())
    local w = map:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = 140 end
    local h = map:GetHeight()
    if type(h) ~= "number" or h <= 0 then h = w end
    local x, y = math.cos(rad), math.sin(rad)
    local radiusX, radiusY = w / 2 + 5, w / 2 + 5
    if type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE" then
        -- Project the direction onto the square edge instead of the circle.
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
        radiusX, radiusY = w / 2 - SQUARE_INSIDE, h / 2 - SQUARE_INSIDE
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", x * radiusX, y * radiusY)
end

local function CursorDegrees(map)
    if type(GetCursorPosition) ~= "function" or not map.GetCenter then return nil end
    local scale = map.GetEffectiveScale and map:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    local mx, my = map:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(mx) ~= "number" or type(my) ~= "number" then
        return nil
    end
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function ApplyGear(icon)
    if icon.SetAtlas then
        local ok, result = pcall(icon.SetAtlas, icon, "mechagon-projects")
        if ok and result then return end
    end
    if not icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CreateMinimap()
    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(31, 31)
    local level = Minimap:GetFrameLevel()
    button:SetFrameLevel((type(level) == "number" and level or 0) + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    ApplyGear(icon)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnDragStart", function(self)
        self._moved = true
        self:SetScript("OnUpdate", function(owner)
            local angle = CursorDegrees(Minimap)
            if not angle then return end
            ns.DB().minimap = angle
            PlaceMinimap(owner)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnMouseUp", function(self, click)
        if self._moved then
            self._moved = false
            return
        end
        if click == "LeftButton" then
            if S.frame and S.frame:IsShown() then
                S.frame:Hide()
            else
                Setup.Show()
            end
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuietUI", 1, 1, 1)
        GameTooltip:AddLine("Left click: toggle setup", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return button
end

function Setup.EnsureMinimap()
    if not Minimap then return end
    if not minimapHooked and Minimap.HookScript then
        minimapHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            if minimapButton then PlaceMinimap(minimapButton) end
        end)
    end
    if minimapButton then
        PlaceMinimap(minimapButton)
        minimapButton:Show()
        return
    end
    minimapButton = CreateMinimap()
    PlaceMinimap(minimapButton)
    -- The button is created after boot; Modernize may already be applied.
    local Modern = ns.Modern
    if Modern and Modern.MinimapButtonCreated then Modern.MinimapButtonCreated(minimapButton) end
end

function Setup.MinimapButton()
    return minimapButton
end

function Setup.PlaceMinimap()
    if minimapButton then PlaceMinimap(minimapButton) end
end
