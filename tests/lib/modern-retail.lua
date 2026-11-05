-- Fixtures that mirror the retail 12.0 frame shapes (Gethe/wow-ui-source, branch live) for the
-- Modern minimap, tooltip, aura and status areas. Test code only, loaded with h.lib("modern-retail").
--   Minimap.xml            MinimapCluster.BorderTop, Minimap.ZoomIn / ZoomOut (parentKey, no global name),
--                          MinimapBackdrop > MinimapCompassTexture, ZoneTextButton > MinimapZoneText;
--                          points and sizes as dumped in game (WoW Forever beta)
--   SharedTooltipTemplates TooltipBackdropTemplate: NineSlice child; colours go through NineSlice
--   BuffFrame.lua          BuffFrame / DebuffFrame .auraFrames, AuraButtonArtTemplate keys
--   ReputationBar.lua      C_Reputation.GetWatchedFactionData(); StatusTrackingBar.xml children
local R = {}

-- 12.0 has no Minimap:GetMaskTexture, so restore can only put back this well-known round mask (verify in game).
local ROUND_MASK = "Textures\\MinimapMask"

-- Region helper: a texture with a known alpha and path.
local function texture(parent, path, layer, alpha)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(path)
    t:SetAlpha(alpha or 1)
    return t
end

-- Minimap ---------------------------------------------------------------------------------------

function R.minimap()
    local cluster, map = MinimapCluster, Minimap
    local parts = { cluster = cluster }
    map._mask = ROUND_MASK
    map.SetMaskTexture = function(self, value) self._mask = value; self._maskCalls = (self._maskCalls or 0) + 1 end
    map.GetMaskTexture = nil -- 12.0 has no getter
    map.EnableMouseWheel = function(self, enabled) self._wheel = enabled and true or false end
    map.IsMouseWheelEnabled = function(self) return self._wheel == true end
    map._zoom = 0
    map.GetZoom = function(self) return self._zoom end
    map.SetZoom = function(self, value) self._zoom = value end
    -- Blizzard's MinimapMixin:OnMouseWheel, wired from XML (OnMouseWheel method="OnMouseWheel").
    Minimap_ZoomIn = function() map._zoom = map._zoom + 1 end
    Minimap_ZoomOut = function() map._zoom = math.max(0, map._zoom - 1) end
    map._wheel = true
    parts.nativeWheel = function(_, delta)
        if delta > 0 then Minimap_ZoomIn() elseif delta < 0 then Minimap_ZoomOut() end
    end
    map:SetScript("OnMouseWheel", parts.nativeWheel)
    local container = CreateFrame("Frame", nil, cluster)
    cluster.MinimapContainer, container.Minimap = container, map
    container:SetSize(253, 253)
    container:SetPoint("TOP", cluster, "TOP", 11.1, -33.3)
    map:SetSize(198, 198)
    map:SetPoint("CENTER", container, "CENTER", 0, 0)
    parts.container = container
    parts.dial = CreateFrame("Frame", nil, container)
    parts.dial:SetSize(42, 42)
    parts.dial:SetPoint("CENTER", container, "CENTER", 49.5, 77.4)
    local dayCycle = parts.dial:CreateTexture(nil, "BACKGROUND")
    dayCycle.GetAtlas = function() return "UI-HUD-Minimap-DayCycle" end
    dayCycle:SetAlpha(1)
    dayCycle:SetSize(33, 33)
    dayCycle:SetPoint("CENTER", parts.dial, "CENTER", 0, 0)
    parts.dial.Background = dayCycle
    parts.dialRing = parts.dial:CreateTexture(nil, "OVERLAY")
    parts.dialRing.GetAtlas = function() return "UI-HUD-Minimap-FrameCycle" end
    parts.dialRing:SetAlpha(1)

    -- BorderTop: NineSliceCodeTemplate, pieces are textures of the frame.
    parts.border = CreateFrame("Frame", nil, cluster)
    cluster.BorderTop = parts.border
    parts.borderPieces = {}
    for i = 1, 3 do parts.borderPieces[i] = texture(parts.border, "Interface\\Minimap\\BorderTop" .. i, "ARTWORK", 0.9) end

    parts.zoneButton = CreateFrame("Button", nil, cluster)
    cluster.ZoneTextButton = parts.zoneButton
    parts.zoneButton:SetSize(152, 23)
    parts.zoneButton:SetPoint("TOP", cluster, "TOP", 10, 0)
    parts.zone = parts.zoneButton:CreateFontString(nil, "OVERLAY")
    parts.zone:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    parts.zone:SetPoint("CENTER", parts.zoneButton, "CENTER", 0, 1)
    _G.MinimapZoneText = parts.zone

    parts.zoomIn = CreateFrame("Button", nil, map)
    parts.zoomOut = CreateFrame("Button", nil, map)
    map.ZoomIn, map.ZoomOut = parts.zoomIn, parts.zoomOut
    map.ZoomHitArea = CreateFrame("Frame", nil, map)
    for _, b in ipairs({ parts.zoomIn, parts.zoomOut }) do
        b:EnableMouse(true)
        b:Hide() -- hidden="true" in the XML, Blizzard shows them in OnEnter
        b:SetAlpha(0.8)
    end

    parts.backdrop = CreateFrame("Frame", "MinimapBackdrop", map)
    parts.compass = texture(parts.backdrop, "Interface\\Minimap\\Frame", "OVERLAY", 1)
    _G.MinimapCompassTexture = parts.compass
    parts.backdrop.StaticOverlayTexture = texture(parts.backdrop, "Interface\\Minimap\\Housing", "OVERLAY", 1)
    parts.landing = CreateFrame("Button", "ExpansionLandingPageMinimapButton", parts.backdrop)
    parts.landing:EnableMouse(true)

    parts.queue = QueueStatusButton
    cluster.Tracking = CreateFrame("Frame", nil, cluster)
    cluster.Tracking:SetPoint("RIGHT", parts.zoneButton, "LEFT", 0, 0)
    cluster.Tracking.Button = CreateFrame("Button", nil, cluster.Tracking)
    parts.calendar = CreateFrame("Button", "GameTimeFrame", cluster)
    parts.calendar:SetPoint("TOPLEFT", parts.zoneButton, "TOPRIGHT", -4, 0)
    parts.compartment = CreateFrame("Button", "AddonCompartmentFrame", cluster)
    parts.compartment:SetPoint("TOP", parts.calendar, "BOTTOM", 0, 1)
    cluster.IndicatorFrame = CreateFrame("Frame", nil, cluster)
    cluster.IndicatorFrame.MailFrame = CreateFrame("Frame", nil, cluster.IndicatorFrame)
    parts.tracking, parts.mail = cluster.Tracking, cluster.IndicatorFrame.MailFrame
    for _, f in ipairs({ parts.queue, parts.tracking, parts.mail, parts.landing }) do f:EnableMouse(true) end
    return map, parts
end

-- True when a frame's art is invisible: its own alpha or every texture piece at 0.
function R.heldHidden(frame)
    if frame._alpha == 0 then return true end
    if #frame._regions == 0 then return false end
    for _, region in ipairs(frame._regions) do
        if region._alpha ~= 0 then return false end
    end
    return true
end

-- Tooltips ---------------------------------------------------------------------------------------

-- A TooltipBackdropTemplate tooltip: no BackdropTemplate, colours delegate to the NineSlice child.
-- Counters tip._setScript and tip._badGet record forbidden calls; tip._native counts Blizzard's OnShow.
function R.tooltip(name, withStatusBar)
    local tip = CreateFrame("GameTooltip", name, UIParent, "TooltipBackdropTemplate")
    local nine = CreateFrame("Frame", nil, tip)
    nine:SetAlpha(0.65)
    nine.SetBorderColor = function(self, ...) self._border = { ... } end
    nine.SetCenterColor = function(self, ...) self._center = { ... } end
    tip.NineSlice = nine
    tip.SetBackdropColor = function(self, ...) self.NineSlice:SetCenterColor(...) end
    tip.SetBackdropBorderColor = function(self, ...) self.NineSlice:SetBorderColor(...) end
    tip.GetBackdropColor = function(self) return unpack(self.NineSlice._center or {}) end
    tip.GetBackdropBorderColor = function(self) return unpack(self.NineSlice._border or {}) end
    nine:SetBorderColor(1, 1, 1, 1)
    nine:SetCenterColor(0.1, 0.1, 0.1, 1)
    tip._native, tip._setScript, tip._badGet = 0, 0, 0
    tip:SetScript("OnShow", function(self) self._native = self._native + 1 end)
    local set, get = tip.SetScript, tip.GetScript
    tip.SetScript = function(self, ...) self._setScript = self._setScript + 1; return set(self, ...) end
    tip.GetScript = function(self, script)
        if script == "OnTooltipSetItem" then
            self._badGet = self._badGet + 1
            error("OnTooltipSetItem is not a tooltip script on 12.0", 0)
        end
        return get(self, script)
    end
    tip.GetItem = function(self) if self._item then return self._item[1], self._item[2] end end
    if withStatusBar then
        local bar = CreateFrame("StatusBar", name .. "StatusBar", tip)
        local fill = bar:CreateTexture(nil, "ARTWORK")
        fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar.SetStatusBarTexture = function(_, value) fill:SetTexture(value) end
        bar.GetStatusBarTexture = function() return fill end
        tip.StatusBar = bar
        return tip, bar
    end
    return tip
end

-- Fake TooltipDataProcessor, installed through the harness' beforeLoad so the area's load-time
-- registration is observable. mock.postCalls lists { type, fn } in registration order.
function R.dataProcessor(mock)
    mock.postCalls = {}
    _G.Enum = _G.Enum or {}
    _G.Enum.TooltipDataType = { Item = 0, Unit = 2 }
    _G.TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, fn) mock.postCalls[#mock.postCalls + 1] = { kind = kind, fn = fn } end,
    }
end

function R.itemPostCalls(mock)
    local list = {}
    for _, call in ipairs(mock.postCalls or {}) do
        if call.kind == Enum.TooltipDataType.Item then list[#list + 1] = call.fn end
    end
    return list
end

-- Shows an item on the tooltip as Blizzard does: data first, then the post call with the data.
function R.showItem(mock, tip, quality)
    C_Item = C_Item or {}
    C_Item.GetItemQualityByID = function() return quality end
    local link = "|cffa335ee|Hitem:12345::::::::|h[Item]|h|r"
    tip._item = { "Item", link }
    tip:Show()
    for _, fn in ipairs(R.itemPostCalls(mock)) do
        fn(tip, { type = Enum.TooltipDataType.Item, id = 12345, hyperlink = link })
    end
end

-- A region or child with this colour in its colour (first three components).
function R.hasColor(frame, rgb)
    local function match(c)
        return type(c) == "table" and math.abs(c[1] - rgb[1]) < 1e-6 and math.abs(c[2] - rgb[2]) < 1e-6
            and math.abs(c[3] - rgb[3]) < 1e-6
    end
    for _, region in ipairs(frame._regions) do if match(region._color) and region._shown then return true end end
    return false
end

-- Auras ------------------------------------------------------------------------------------------

local function dispelColor(kind)
    local colors = {
        Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 },
        Poison = { 0, 0.6, 0 }, None = { 0.8, 0, 0 },
    }
    local c = colors[kind] or colors.None
    return { r = c[1], g = c[2], b = c[3], a = 1,
        GetRGB = function(self) return self.r, self.g, self.b end,
        GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
end
R.dispelColor = dispelColor

-- 12.0 has no global DebuffTypeColor; AuraUtil.GetAuraBorderColor(dispelType) returns a ColorMixin.
function R.installAuraUtil()
    _G.DebuffTypeColor = nil
    _G.AuraUtil = { GetAuraBorderColor = function(kind) return dispelColor(kind) end }
end

-- AuraButtonArtTemplate keys: Icon, Duration, Count, Symbol, DebuffBorder, TempEnchantBorder.
function R.auraButton(container, auraType, dispel)
    local button = CreateFrame("Button", nil, container)
    button.Icon = texture(button, "Interface\\Icons\\INV_Misc_QuestionMark", "BACKGROUND", 1)
    button.Duration = button:CreateFontString(nil, "BACKGROUND")
    button.Duration:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    button.Count = button:CreateFontString(nil, "OVERLAY")
    button.Count:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    button.Symbol = button:CreateFontString(nil, "OVERLAY")
    button.DebuffBorder = texture(button, "Interface\\Buttons\\debuff-border", "OVERLAY", 1)
    button.TempEnchantBorder = texture(button, "Interface\\Buttons\\UI-TempEnchant-Border", "OVERLAY", 1)
    button.DebuffBorder:Hide()
    button.TempEnchantBorder:Hide()
    button.buttonInfo = auraType and { auraType = auraType, debuffType = dispel } or nil
    -- Blizzard: AuraButtonMixin:UpdateAuraType / Update show the border art of the aura type.
    button.Update = function(self, info)
        self.buttonInfo = info
        self.auraType = info.auraType
        if info.auraType == "Debuff" then self.DebuffBorder:Show() else self.DebuffBorder:Hide() end
        if info.auraType == "TempEnchant" then self.TempEnchantBorder:Show() else self.TempEnchantBorder:Hide() end
    end
    button:Hide()
    return button
end

-- BuffFrame / DebuffFrame: AuraContainer child, .auraFrames list, UpdateAuraButtons that walks
-- self.auraInfo like AuraFrameMixin:UpdateAuraButtons. kinds: { {auraType, dispel}, ... }
function R.auraFrame(frame, kinds)
    frame.AuraContainer = CreateFrame("Frame", nil, frame)
    frame.auraFrames = {}
    frame.auraInfo = {}
    for _, kind in ipairs(kinds) do
        local button = R.auraButton(frame.AuraContainer, kind[1], kind[2])
        frame.auraFrames[#frame.auraFrames + 1] = button
        frame.auraInfo[#frame.auraInfo + 1] = button.buttonInfo
        button:Show()
    end
    frame.UpdateAuraButtons = function(self)
        for i, button in ipairs(self.auraFrames) do
            local info = self.auraInfo[i]
            if info and not button.isAuraAnchor then
                button:Show()
                button:Update(info)
            elseif not button.isAuraAnchor then
                button:Hide()
            end
        end
    end
    frame.Update = function(self) self:UpdateAuraButtons() end
    frame:UpdateAuraButtons()
    return frame.auraFrames
end

-- BuffFramePrivateAuraAnchorTemplate: Icon and Duration are plain frames, never textures.
function R.privateAnchor(frame)
    local anchor = CreateFrame("Frame", nil, frame)
    anchor.isAuraAnchor = true
    anchor.Icon = CreateFrame("Frame", nil, anchor)
    anchor.Duration = CreateFrame("Frame", nil, anchor)
    frame.auraFrames[#frame.auraFrames + 1] = anchor
    return anchor
end

-- Adds a button after the area was applied, as the aura info grows.
function R.addAura(frame, auraType, dispel)
    local button = R.auraButton(frame.AuraContainer, auraType, dispel)
    frame.auraFrames[#frame.auraFrames + 1] = button
    frame.auraInfo[#frame.auraInfo + 1] = button.buttonInfo
    return button
end

-- A copy of mock.calls for before/after comparisons of frame walks.
function R.calls(mock)
    local copy = {}
    for k, v in pairs(mock.calls) do copy[k] = v end
    return copy
end

function R.sameCalls(A, before, after, label)
    for k, v in pairs(after) do A.eq(v, before[k] or 0, (label or "calls") .. ": " .. k) end
end

return R
