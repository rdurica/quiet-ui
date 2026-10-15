local _, ns = ...

local Modern = ns.Modern
Modern.Parchment = Modern.Parchment or {}
local Parchment = Modern.Parchment

local COLORS = {
    primary = { 0.50, 0.11, 0.09 },
    primaryHover = { 0.64, 0.17, 0.13 },
    secondary = { 0.36, 0.35, 0.33 },
    secondaryHover = { 0.47, 0.46, 0.44 },
    close = { 0.22, 0.17, 0.13 },
    closeHover = { 0.50, 0.12, 0.10 },
}

local INSET_X = 14
Parchment.ROW_CENTER = 15
local ROW_CENTER = Parchment.ROW_CENTER
local SAFE_GAP = 4
local TITLE_INK = { 0.24, 0.16, 0.09 }
local TITLE_GROW = 2
local CLOSE_SIZE, CLOSE_INSET, CROSS_LENGTH = 20, 8, 13
local TRACK_ALPHA = 0.3
local FILL_ALPHA, DISABLED_ALPHA = 0.95, 0.35

function Parchment.State()
    if not Parchment._state then
        Parchment._state = {
            held = {}, saved = {}, skins = {}, lifts = {}, titles = {},
            hooked = setmetatable({}, { __mode = "k" }), active = false,
        }
    end
    return Parchment._state
end

function Parchment.Active()
    return Parchment.State().active
end

-- Shared with Parchment.lua. Every call is guarded: a missing or failing method gives nil.
function Parchment.Try(obj, method, ...)
    if type(obj) ~= "table" then return end
    local fn = obj[method]
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, obj, ...)
    if ok then return a, b, c, d end
end

function Parchment.Usable(obj)
    return type(obj) == "table" and ns.Usable(obj)
end

function Parchment.IsTexture(obj)
    return Parchment.Usable(obj) and Parchment.Try(obj, "GetObjectType") == "Texture"
end

function Parchment.Regions(frame)
    if not Parchment.Usable(frame) or type(frame.GetRegions) ~= "function" then return {} end
    local ok, list = pcall(function() return { frame:GetRegions() } end)
    return ok and list or {}
end

local function SetHeldAlpha(tex, alpha)
    tex._quietApplying = true
    pcall(tex.SetAlpha, tex, alpha)
    tex._quietApplying = false
end

local function Hook(tex)
    if tex._quietParchmentHook then return end
    tex._quietParchmentHook = true
    local st = Parchment.State()
    pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
        local want = st.held[self]
        if want == nil or self._quietApplying then return end
        local plain = not ns.IsSecret(alpha) and type(alpha) == "number"
        if plain and st.saved[self] ~= nil then st.saved[self] = alpha end
        if not Parchment.Active() then return end
        if plain and math.abs(alpha - want) < 0.01 then return end
        SetHeldAlpha(self, want)
    end)
end

function Parchment.Hold(tex, want)
    if not Parchment.IsTexture(tex) or type(tex.SetAlpha) ~= "function" then return end
    local st = Parchment.State()
    local alpha = Parchment.Try(tex, "GetAlpha")
    local secret = ns.IsSecret(alpha)
    if st.saved[tex] == nil then
        st.saved[tex] = (not secret and type(alpha) == "number") and alpha or 1
    end
    st.held[tex] = want
    Hook(tex)
    if secret or type(alpha) ~= "number" or math.abs(alpha - want) >= 0.01 then
        SetHeldAlpha(tex, want)
    end
end

function Parchment.ReleaseAll()
    local st = Parchment.State()
    for tex, alpha in pairs(st.saved) do
        st.held[tex] = nil
        st.saved[tex] = nil
        SetHeldAlpha(tex, alpha)
    end
end

-- One HookScript per frame and script for the whole session; the bodies check Parchment.Active(),
-- so a restore leaves them inert and never touches Blizzard's scripts.
function Parchment.HookScript(frame, name, fn)
    local hooked = Parchment.State().hooked
    local byFrame = hooked[frame]
    if not byFrame then
        byFrame = {}
        hooked[frame] = byFrame
    end
    if byFrame[name] then return end
    byFrame[name] = true
    Parchment.Try(frame, "HookScript", name, function()
        if Parchment.Active() then ns.Run("parchment hook", fn) end
    end)
end

function Parchment.DimScrollBar(owner)
    if not Parchment.Usable(owner) then return end
    local bar = owner.ScrollBar
    if type(bar) ~= "table" then
        local name = Parchment.Try(owner, "GetName")
        bar = type(name) == "string" and _G[name .. "ScrollBar"] or nil
    end
    if not Parchment.Usable(bar) then return end
    local thumb = Parchment.Try(bar, "GetThumbTexture")
    local function dim(obj, skip)
        if Parchment.IsTexture(obj) then
            if obj ~= skip then Parchment.Hold(obj, TRACK_ALPHA) end
            return
        end
        for _, region in ipairs(Parchment.Regions(obj)) do
            if Parchment.IsTexture(region) and region ~= skip then Parchment.Hold(region, TRACK_ALPHA) end
        end
    end
    dim(bar, thumb)
    for _, key in ipairs({ "Background", "Backplate", "Track" }) do
        local part = bar[key]
        if type(part) == "table" then dim(part, thumb) end
    end
end

local function ButtonTextures(b)
    local list = {}
    local name = Parchment.Try(b, "GetName")
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local tex = b[key]
        if type(tex) ~= "table" and type(name) == "string" then tex = _G[name .. key] end
        if type(tex) == "table" then list[#list + 1] = tex end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local tex = Parchment.Try(b, getter)
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
    local st = Parchment.State()
    local s = st.skins[b]
    if not s then return end
    local enabled = Enabled(b)
    local c = COLORS[s.role .. ((s.hover and enabled) and "Hover" or "")]
    local alpha = enabled and FILL_ALPHA or DISABLED_ALPHA
    for _, tex in ipairs(s.paint) do
        Parchment.Try(tex, "SetColorTexture", c[1], c[2], c[3], alpha)
    end
end

local function HasText(b)
    local text = Parchment.Try(b, "GetText")
    return type(text) == "string" and not ns.IsSecret(text) and text ~= ""
end

local function NewSkin(b, role, glyph)
    local st = Parchment.State()
    local s = { role = role, paint = {}, own = {} }
    if role == "close" then
        for _, angle in ipairs({ 45, -45 }) do
            local line = Parchment.Try(b, "CreateTexture", nil, "OVERLAY")
            if line then
                Parchment.Try(line, "SetSize", CROSS_LENGTH, 2)
                Parchment.Try(line, "SetPoint", "CENTER", b, "CENTER", 0, 0)
                Parchment.Try(line, "SetRotation", math.rad(angle))
                s.paint[#s.paint + 1] = line
                s.own[#s.own + 1] = line
            end
        end
    else
        local fill = Parchment.Try(b, "CreateTexture", nil, "BACKGROUND")
        if fill then
            Parchment.Try(fill, "SetAllPoints", b)
            s.paint[#s.paint + 1] = fill
            s.own[#s.own + 1] = fill
        end
        if glyph and not HasText(b) then
            local fs = Parchment.Try(b, "CreateFontString", nil, "OVERLAY", "GameFontHighlight")
            if fs then
                Parchment.Try(fs, "SetPoint", "CENTER", b, "CENTER", 0, 0)
                Parchment.Try(fs, "SetText", glyph)
                s.own[#s.own + 1] = fs
            end
        end
    end
    st.skins[b] = s
    return s
end

local function Points(obj)
    local points = {}
    local n = Parchment.Try(obj, "GetNumPoints") or 0
    for i = 1, n do
        local ok, point, rel, relPoint, x, y = pcall(obj.GetPoint, obj, i)
        if ok and point then points[#points + 1] = { point, rel, relPoint, x, y } end
    end
    return points
end

local function SetPoints(obj, points, lift)
    Parchment.Try(obj, "ClearAllPoints")
    for _, p in ipairs(points) do
        local y = p[5]
        if lift and type(p[1]) == "string" and p[1]:find("BOTTOM") then y = (y or 0) + lift end
        Parchment.Try(obj, "SetPoint", p[1], p[2], p[3], p[4], y)
    end
end

local function RememberPoints(b, s, withSize)
    if not s.points then s.points = Points(b) end
    if withSize and not s.size then
        local w, h = Parchment.Try(b, "GetSize")
        if type(w) == "number" and type(h) == "number" then s.size = { w, h } end
    end
end

local function Place(b, point, rel, relPoint, x, y)
    Parchment.Try(b, "ClearAllPoints")
    Parchment.Try(b, "SetPoint", point, rel, relPoint, x, y)
end

function Parchment.SkinButton(win, b, role, side, glyph)
    local st = Parchment.State()
    local s = st.skins[b]
    if not s then s = NewSkin(b, role, glyph) end
    for _, tex in ipairs(ButtonTextures(b)) do Parchment.Hold(tex, 0) end
    RememberPoints(b, s, role == "close")
    if role == "close" then
        Parchment.Try(b, "SetSize", CLOSE_SIZE, CLOSE_SIZE)
        Place(b, "TOPRIGHT", win, "TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    else
        local x = side:find("LEFT") and INSET_X or -INSET_X
        local h = Parchment.Try(b, "GetHeight")
        if type(h) ~= "number" or ns.IsSecret(h) then h = 22 end
        local y = math.max(0, math.floor(ROW_CENTER - h / 2 + 0.5))
        Place(b, side, win, side, x, y)
        s.top = y + h
    end
    for _, obj in ipairs(s.own) do Parchment.Try(obj, "Show") end
    Paint(b)
    local function Hover(on)
        return function()
            s.hover = on
            Paint(b)
        end
    end
    Parchment.HookScript(b, "OnEnter", Hover(true))
    Parchment.HookScript(b, "OnLeave", Hover(false))
    Parchment.HookScript(b, "OnEnable", function() Paint(b) end)
    Parchment.HookScript(b, "OnDisable", function() Paint(b) end)
end

local function BottomOffset(win, sf, points)
    local sb, wb = Parchment.Try(sf, "GetBottom"), Parchment.Try(win, "GetBottom")
    local ss, ws = Parchment.Try(sf, "GetEffectiveScale"), Parchment.Try(win, "GetEffectiveScale")
    local function plain(v) return type(v) == "number" and not ns.IsSecret(v) end
    if plain(sb) and plain(wb) and plain(ss) and plain(ws) and math.abs(ss - ws) < 0.001 then
        return sb - wb
    end
    local low
    for _, p in ipairs(points) do
        if type(p[1]) == "string" and p[1]:find("BOTTOM") then
            if p[2] ~= win or not plain(p[5]) then return end
            low = math.min(low or p[5], p[5])
        end
    end
    return low
end

function Parchment.LiftScroll(win, sf, bandTop)
    local st = Parchment.State()
    local s = st.lifts[sf]
    if not s then
        s = { points = Points(sf) }
        st.lifts[sf] = s
    end
    if s.lift == nil then
        local offset = BottomOffset(win, sf, s.points)
        if offset == nil then return end
        s.lift = math.max(0, bandTop + SAFE_GAP - offset)
    end
    if s.lift > 0 then SetPoints(sf, s.points, s.lift) end
end

function Parchment.InkTitle(win, def)
    local st = Parchment.State()
    local title = type(win.TitleContainer) == "table" and win.TitleContainer.TitleText or nil
    if type(title) ~= "table" then title = _G[def.name .. "TitleText"] end
    if not Parchment.Usable(title) then return end
    local t = st.titles[title]
    if not t then
        local face, size, flags = Parchment.Try(title, "GetFont")
        local r, g, b, a = Parchment.Try(title, "GetTextColor")
        if type(face) ~= "string" or type(size) ~= "number" or ns.IsSecret(size) or type(r) ~= "number" then return end
        t = { font = { face, size, flags }, color = { r, g, b, a } }
        st.titles[title] = t
    end
    Parchment.Try(title, "SetTextColor", TITLE_INK[1], TITLE_INK[2], TITLE_INK[3], 1)
    Parchment.Try(title, "SetFont", t.font[1], t.font[2] + TITLE_GROW, t.font[3] or "")
end

function Parchment.RestoreTitles()
    local st = Parchment.State()
    for title, t in pairs(st.titles) do
        st.titles[title] = nil
        Parchment.Try(title, "SetFont", t.font[1], t.font[2], t.font[3] or "")
        Parchment.Try(title, "SetTextColor", t.color[1], t.color[2], t.color[3], t.color[4])
    end
end

function Parchment.RestoreLifts()
    local st = Parchment.State()
    for sf, s in pairs(st.lifts) do
        st.lifts[sf] = nil
        if s.lift and s.lift > 0 then SetPoints(sf, s.points) end
    end
end

function Parchment.RestoreButton(b, s)
    for _, obj in ipairs(s.own) do Parchment.Try(obj, "Hide") end
    s.hover = nil
    s.top = nil
    if s.points then
        SetPoints(b, s.points)
        s.points = nil
    end
    if s.size then
        Parchment.Try(b, "SetSize", s.size[1], s.size[2])
        s.size = nil
    end
end
