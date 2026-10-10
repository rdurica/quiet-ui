local _, ns = ...

-- The quest, gossip and item text windows as clean parchment with flat buttons. The windows
-- stay Blizzard frames: only textures, button points and the addon's own layer change.
local PARCHMENT = "Interface\\AddOns\\QuietUI\\Media\\parchment.tga"
local OVERHANG = 6 -- the torn edge is transparent, so the layer reaches past the window
local INSET_X, INSET_Y = 14, 12
local CLOSE_SIZE, CLOSE_INSET, CROSS_LENGTH = 20, 8, 13
local TRACK_ALPHA = 0.3
local FILL_ALPHA, DISABLED_ALPHA = 0.95, 0.35

local COLORS = {
    primary = { 0.50, 0.11, 0.09 },
    primaryHover = { 0.64, 0.17, 0.13 },
    secondary = { 0.36, 0.35, 0.33 },
    secondaryHover = { 0.47, 0.46, 0.44 },
    close = { 0.22, 0.17, 0.13 },
    closeHover = { 0.50, 0.12, 0.10 },
}

-- Frame keys and global suffixes of the old frame, portrait and sides.
local CHROME_KEYS = { "Bg", "Background", "NineSlice", "Border", "PortraitContainer", "portrait", "Portrait",
    "PortraitFrame", "TopTileStreaks", "TitleBg", "Inset", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder",
    "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight" }
local CHROME_SUFFIXES = { "Bg", "Portrait", "TitleBg", "TopTileStreaks", "BtnCornerLeft", "BtnCornerRight",
    "ButtonBottomBorder" }
local PANEL_KEYS = { "Bg", "SealMaterialBG", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft",
    "MaterialBotRight" }

local function GossipPanel(win)
    return type(win.GreetingPanel) == "table" and win.GreetingPanel or nil
end

local WINDOWS = {
    {
        name = "QuestFrame",
        panels = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" },
        scrolls = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" },
        buttons = {
            { "QuestFrameAcceptButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameDeclineButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameCompleteButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameGoodbyeButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameCompleteQuestButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameCancelButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameGreetingGoodbyeButton", "secondary", "BOTTOMRIGHT" },
        },
    },
    {
        name = "GossipFrame",
        panels = {},
        scrolls = { GossipPanel, "GossipGreetingScrollFrame" },
        buttons = {
            { function(win)
                local panel = GossipPanel(win)
                return panel and panel.GoodbyeButton or _G.GossipFrameGreetingGoodbyeButton
            end, "secondary", "BOTTOMRIGHT" },
        },
    },
    {
        name = "ItemTextFrame",
        panels = {},
        extra = { "ItemTextMaterialTopLeft", "ItemTextMaterialTopRight", "ItemTextMaterialBotLeft",
            "ItemTextMaterialBotRight" },
        scrolls = { "ItemTextScrollFrame" },
        buttons = {
            { "ItemTextPrevPageButton", "secondary", "BOTTOMLEFT", "<" },
            { "ItemTextNextPageButton", "primary", "BOTTOMRIGHT", ">" },
        },
    },
}

local EVENT_WINDOW = {
    QUEST_DETAIL = "QuestFrame",
    QUEST_PROGRESS = "QuestFrame",
    QUEST_COMPLETE = "QuestFrame",
    QUEST_GREETING = "QuestFrame",
    GOSSIP_SHOW = "GossipFrame",
    ITEM_TEXT_READY = "ItemTextFrame",
}

local held = {}    -- texture -> alpha held while active
local saved = {}   -- texture -> alpha before the reskin
local windows = {} -- window -> { layer }
local skins = {}   -- button -> { role, paint, own, hover, points, size }

local function Try(obj, method, ...)
    if type(obj) ~= "table" then return end
    local fn = obj[method]
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, obj, ...)
    if ok then return a, b end
end

local function Active()
    local db = ns.DB and ns.DB()
    if not (db and db.enabled) then return false end
    -- The setting accessor lives in Setup.lua; missing means on.
    if type(ns.Parchment) == "function" then return ns.Parchment() ~= false end
    return true
end

local function Usable(obj)
    return type(obj) == "table" and ns.Usable(obj)
end

local function IsTexture(obj)
    return Usable(obj) and Try(obj, "GetObjectType") == "Texture"
end

local function Regions(frame)
    if not Usable(frame) or type(frame.GetRegions) ~= "function" then return {} end
    local ok, list = pcall(function() return { frame:GetRegions() } end)
    return ok and list or {}
end

local function Resolve(win, ref)
    local obj
    if type(ref) == "function" then obj = ref(win) else obj = _G[ref] end
    if Usable(obj) then return obj end
end

-- Texture alpha -------------------------------------------------------------------------

local function SetHeldAlpha(tex, alpha)
    tex._quietApplying = true
    pcall(tex.SetAlpha, tex, alpha)
    tex._quietApplying = false
end

-- Own hook: it holds the alpha only while the reskin is active, unlike the Core texture hook.
local function Hook(tex)
    if tex._quietParchmentHook then return end
    tex._quietParchmentHook = true
    pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
        local want = held[self]
        if want == nil or self._quietApplying then return end
        local plain = not ns.IsSecret(alpha) and type(alpha) == "number"
        -- Blizzard's latest wish is what restore must bring back, not the alpha from the first hold.
        if plain and saved[self] ~= nil then saved[self] = alpha end
        if not Active() then return end
        if plain and math.abs(alpha - want) < 0.01 then return end
        SetHeldAlpha(self, want)
    end)
end

local function Hold(tex, want)
    if not IsTexture(tex) or type(tex.SetAlpha) ~= "function" then return end
    local alpha = Try(tex, "GetAlpha")
    local secret = ns.IsSecret(alpha)
    if saved[tex] == nil then
        saved[tex] = (not secret and type(alpha) == "number") and alpha or 1
    end
    held[tex] = want
    Hook(tex)
    if secret or type(alpha) ~= "number" or math.abs(alpha - want) >= 0.01 then
        SetHeldAlpha(tex, want)
    end
end

local function ReleaseAll()
    for tex, alpha in pairs(saved) do
        held[tex] = nil
        saved[tex] = nil
        SetHeldAlpha(tex, alpha)
    end
end

-- Hides a texture, or the texture regions of a frame and its NineSlice / Bg.
local function HideChrome(obj, depth)
    if IsTexture(obj) then
        Hold(obj, 0)
        return
    end
    if not Usable(obj) or (depth or 0) > 2 then return end
    for _, region in ipairs(Regions(obj)) do
        if IsTexture(region) then Hold(region, 0) end
    end
    for _, key in ipairs({ "NineSlice", "Bg" }) do
        local child = obj[key]
        if type(child) == "table" then HideChrome(child, (depth or 0) + 1) end
    end
end

local function DimParts(obj, skip)
    if IsTexture(obj) then
        if obj ~= skip then Hold(obj, TRACK_ALPHA) end
        return
    end
    for _, region in ipairs(Regions(obj)) do
        if IsTexture(region) and region ~= skip then Hold(region, TRACK_ALPHA) end
    end
end

-- Track and background only; the thumb stays fully visible.
local function DimScrollBar(owner)
    if not Usable(owner) then return end
    local bar = owner.ScrollBar
    if type(bar) ~= "table" then
        local name = Try(owner, "GetName")
        bar = type(name) == "string" and _G[name .. "ScrollBar"] or nil
    end
    if not Usable(bar) then return end
    local thumb = Try(bar, "GetThumbTexture")
    DimParts(bar, thumb)
    for _, key in ipairs({ "Background", "Backplate", "Track" }) do
        local part = bar[key]
        if type(part) == "table" then DimParts(part, thumb) end
    end
end

-- Buttons -------------------------------------------------------------------------------

local function ButtonTextures(b)
    local list = {}
    local name = Try(b, "GetName")
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local tex = b[key]
        if type(tex) ~= "table" and type(name) == "string" then tex = _G[name .. key] end
        if type(tex) == "table" then list[#list + 1] = tex end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local tex = Try(b, getter)
        if type(tex) == "table" then list[#list + 1] = tex end
    end
    return list
end

local function Enabled(b)
    if type(b.IsEnabled) ~= "function" then return true end
    local ok, value = pcall(b.IsEnabled, b)
    if not ok or ns.IsSecret(value) then return true end
    return value and true or false
end

local function Paint(b)
    local s = skins[b]
    if not s then return end
    local enabled = Enabled(b)
    local c = COLORS[s.role .. ((s.hover and enabled) and "Hover" or "")]
    local alpha = enabled and FILL_ALPHA or DISABLED_ALPHA
    for _, tex in ipairs(s.paint) do
        Try(tex, "SetColorTexture", c[1], c[2], c[3], alpha)
    end
end

local function HasText(b)
    local text = Try(b, "GetText")
    return type(text) == "string" and not ns.IsSecret(text) and text ~= ""
end

local function NewSkin(b, role, glyph)
    local s = { role = role, paint = {}, own = {} }
    if role == "close" then
        for _, angle in ipairs({ 45, -45 }) do
            local line = Try(b, "CreateTexture", nil, "OVERLAY")
            if line then
                Try(line, "SetSize", CROSS_LENGTH, 2)
                Try(line, "SetPoint", "CENTER", b, "CENTER", 0, 0)
                Try(line, "SetRotation", math.rad(angle))
                s.paint[#s.paint + 1] = line
                s.own[#s.own + 1] = line
            end
        end
    else
        local fill = Try(b, "CreateTexture", nil, "BACKGROUND")
        if fill then
            Try(fill, "SetAllPoints", b)
            s.paint[#s.paint + 1] = fill
            s.own[#s.own + 1] = fill
        end
        -- Arrow buttons carry their arrow in the hidden textures, so they get a glyph.
        if glyph and not HasText(b) then
            local fs = Try(b, "CreateFontString", nil, "OVERLAY", "GameFontHighlight")
            if fs then
                Try(fs, "SetPoint", "CENTER", b, "CENTER", 0, 0)
                Try(fs, "SetText", glyph)
                s.own[#s.own + 1] = fs
            end
        end
    end
    local function Hover(on)
        return function()
            s.hover = on
            Paint(b)
        end
    end
    Try(b, "HookScript", "OnEnter", Hover(true))
    Try(b, "HookScript", "OnLeave", Hover(false))
    Try(b, "HookScript", "OnEnable", function() Paint(b) end)
    Try(b, "HookScript", "OnDisable", function() Paint(b) end)
    return s
end

local function RememberPoints(b, s, withSize)
    if not s.points then
        local points = {}
        local n = Try(b, "GetNumPoints") or 0
        for i = 1, n do
            local ok, point, rel, relPoint, x, y = pcall(b.GetPoint, b, i)
            if ok and point then points[#points + 1] = { point, rel, relPoint, x, y } end
        end
        s.points = points
    end
    if withSize and not s.size then
        local w, h = Try(b, "GetSize")
        if type(w) == "number" and type(h) == "number" then s.size = { w, h } end
    end
end

local function Place(b, point, rel, relPoint, x, y)
    Try(b, "ClearAllPoints")
    Try(b, "SetPoint", point, rel, relPoint, x, y)
end

local function SkinButton(win, b, role, side, glyph)
    local s = skins[b]
    if not s then
        s = NewSkin(b, role, glyph)
        skins[b] = s
    end
    for _, tex in ipairs(ButtonTextures(b)) do Hold(tex, 0) end
    RememberPoints(b, s, role == "close")
    if role == "close" then
        Try(b, "SetSize", CLOSE_SIZE, CLOSE_SIZE)
        Place(b, "TOPRIGHT", win, "TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    else
        local x = side:find("LEFT") and INSET_X or -INSET_X
        Place(b, side, win, side, x, INSET_Y)
    end
    for _, obj in ipairs(s.own) do Try(obj, "Show") end
    Paint(b)
end

local function RestoreButton(b, s)
    for _, obj in ipairs(s.own) do Try(obj, "Hide") end
    s.hover = nil
    if s.points then
        Try(b, "ClearAllPoints")
        for _, p in ipairs(s.points) do
            Try(b, "SetPoint", p[1], p[2], p[3], p[4], p[5])
        end
        s.points = nil
    end
    if s.size then
        Try(b, "SetSize", s.size[1], s.size[2])
        s.size = nil
    end
end

-- Windows -------------------------------------------------------------------------------

local SkinWindow

local function ApplyWindow(def)
    local ok, err = pcall(SkinWindow, def)
    if not ok then ns.Report("parchment " .. def.name, err) end
end

function SkinWindow(def)
    local win = _G[def.name]
    if not Usable(win) then return end
    local state = windows[win]
    if not state then
        state = {}
        windows[win] = state
        local layer = Try(win, "CreateTexture", nil, "BACKGROUND", nil, -8)
        if layer then
            Try(layer, "SetTexture", PARCHMENT)
            Try(layer, "SetPoint", "TOPLEFT", win, "TOPLEFT", -OVERHANG, OVERHANG)
            Try(layer, "SetPoint", "BOTTOMRIGHT", win, "BOTTOMRIGHT", OVERHANG, -OVERHANG)
            state.layer = layer
        end
        -- Blizzard resets the portrait and alpha on every open.
        Try(win, "HookScript", "OnShow", function()
            if Active() then ApplyWindow(def) end
        end)
    end
    Try(state.layer, "Show")

    for _, key in ipairs(CHROME_KEYS) do
        local obj = win[key]
        if type(obj) == "table" then HideChrome(obj) end
    end
    for _, suffix in ipairs(CHROME_SUFFIXES) do
        local obj = _G[def.name .. suffix]
        if type(obj) == "table" then HideChrome(obj) end
    end
    for _, name in ipairs(def.extra or {}) do
        Hold(_G[name], 0)
    end
    for _, name in ipairs(def.panels) do
        local panel = _G[name]
        if Usable(panel) then
            for _, key in ipairs(PANEL_KEYS) do Hold(panel[key], 0) end
        end
    end
    for _, ref in ipairs(def.scrolls) do
        DimScrollBar(Resolve(win, ref))
    end
    for _, spec in ipairs(def.buttons) do
        local b = Resolve(win, spec[1])
        if b then SkinButton(win, b, spec[2], spec[3], spec[4]) end
    end
    local close = win.CloseButton
    if type(close) ~= "table" then close = _G[def.name .. "CloseButton"] end
    if Usable(close) then SkinButton(win, close, "close") end
end

function ns.RestoreParchment()
    local ok, err = pcall(function()
        ReleaseAll()
        for _, state in pairs(windows) do Try(state.layer, "Hide") end
        for b, s in pairs(skins) do RestoreButton(b, s) end
    end)
    if not ok then ns.Report("parchment restore", err) end
end

function ns.ApplyParchment()
    if not Active() then
        ns.RestoreParchment()
        return
    end
    for _, def in ipairs(WINDOWS) do ApplyWindow(def) end
end

function ns.ParchmentEvent(event)
    if not Active() then return end
    local name = EVENT_WINDOW[event]
    for _, def in ipairs(WINDOWS) do
        if event == "ADDON_LOADED" then
            -- Load-on-demand windows that did not exist at the last apply.
            local win = _G[def.name]
            if win and not windows[win] then ApplyWindow(def) end
        elseif def.name == name then
            ApplyWindow(def)
        end
    end
end
