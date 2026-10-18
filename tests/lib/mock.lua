-- WoW API mock for the shared test harness. Lua 5.1-compatible syntax.
--
--   Loaded with `loadfile` by tests/run.lua. mock.new() returns a fresh mock;
--   mock:install() writes its globals into _G.
--
-- What a test can use (all reached through the harness context `t.mock`):
--   mock.frames                 every frame/texture/fontstring created, in order
--   mock.createLog              {kind, name, parent, template} per CreateFrame call
--   mock:eventFrame(event)      the frame that registered `event` (e.g. "PLAYER_LOGIN")
--   mock:fire(event, ...)       OnEvent on every frame registered for `event`
--   mock:tick(elapsed)          OnUpdate on every shown frame that has one
--   mock:find(pred)             frames matching a predicate; mock:findByName(name)
--   mock:control(kind, text)    button/checkbox/etc. whose text/label contains `text`
--   mock:advance(seconds)       move the clock, running due C_Timer callbacks
--   mock:drain()                run queued C_Timer callbacks (and those they add)
--   mock.now                    GetTime(); mock.profile = debugprofilestop() value
--   mock.calls                  counters: GetAlpha, GetChildren, GetRegions, GetNamePlateForUnit
--   mock.printed                lines written through print() (ns.Print / ns.Report)
--   mock.cvars, mock.units (setUnit), mock.state (combat, instance, group, cursor, focus)
--   mock:secret(v) / issecretvalue; mock.unknown = methods hit through the no-op fallback
-- Frame methods are real methods on a shared class, plus a no-op fallback for the long
-- tail of widget API (logged in mock.unknown). Add explicit methods when a test needs the
-- value back. Probed optional methods are listed in ABSENT so `if w.SetBackdrop` is honest.
local unpack = table.unpack or unpack

local M = {}
M.__index = M

local CHAR_W, LINE_H = 6, 12
-- Methods that real frames only have with a template; fallback must not invent them.
local ABSENT = {
    SetBackdrop = true, SetBackdropColor = true, SetBackdropBorderColor = true,
    GetBackdrop = true, ApplyBackdrop = true,
}

local Frame = {}
Frame.__index = function(self, key)
    local absent = rawget(self, "_absent")
    if absent and absent[key] then return nil end
    local v = Frame[key]
    if v ~= nil then return v end
    if type(key) ~= "string" or ABSENT[key] then return nil end
    if Frame.isVerb(key) then
        local mock = rawget(self, "_mock")
        return function()
            if mock then mock.unknown[key] = (mock.unknown[key] or 0) + 1 end
        end
    end
end

-- Only verb-named members fall back to a no-op; `frame.TitleText` style children stay nil.
local VERBS = { Set = 1, Get = 1, Is = 1, Has = 1, Can = 1, Enable = 1, Disable = 1, Register = 1,
    Unregister = 1, Create = 1, Hide = 1, Show = 1, Clear = 1, Add = 1, Lock = 1, Unlock = 1,
    Stop = 1, Play = 1, Raise = 1, Lower = 1, Start = 1, Click = 1, Update = 1, Apply = 1,
    Toggle = 1, Make = 1, Cancel = 1, Finish = 1, Pause = 1, Remove = 1,
    Insert = 1, Rotate = 1, Reset = 1, Sync = 1, Resume = 1, Refresh = 1,
    SetPropagate = 1, Animate = 1, Flash = 1, Notify = 1, Send = 1 }
Frame.isVerb = function(key)
    local head = key:match("^(%u%l+)")
    return head ~= nil and VERBS[head] ~= nil
end

local function newFrame(mock, kind, name, parent, template)
    local f = setmetatable({
        _mock = mock, _kind = kind, _name = name, _parent = parent, _template = template,
        _alpha = 1, _shown = true, _scripts = {}, _hooks = {}, _events = {}, _children = {},
        _regions = {}, _points = {}, _w = 100, _h = 20, _level = 1, _strata = "MEDIUM",
        _scale = 1, _text = "", _calls = {}, _forbidden = false, _mouse = false,
    }, Frame)
    mock.frames[#mock.frames + 1] = f
    if name then mock.G[name] = f end
    if parent and parent._children then parent._children[#parent._children + 1] = f end
    if template and tostring(template):find("BackdropTemplate", 1, true) then
        f.SetBackdrop = function(self, spec) self._backdrop = spec end
        f.SetBackdropColor = function(self, ...)
            if select("#", ...) == 0 then self._backdropColor = nil else self._backdropColor = { ... } end
        end
        f.SetBackdropBorderColor = function(self, ...)
            if select("#", ...) == 0 then self._backdropBorder = nil else self._backdropBorder = { ... } end
        end
    end
    return f
end

local function bump(self, key)
    self._calls[key] = (self._calls[key] or 0) + 1
    self._mock.calls[key] = (self._mock.calls[key] or 0) + 1
end

function Frame:IsForbidden() return self._forbidden end
function Frame:GetAlpha() bump(self, "GetAlpha"); return self._alpha end
function Frame:GetEffectiveAlpha()
    local a, p = self._alpha, self._parent
    while p and p._alpha do a = a * p._alpha; p = p._parent end
    return a
end
function Frame:SetAlpha(v) bump(self, "SetAlpha"); self._alpha = v end
-- 12.0: sets the alpha without going through SetAlpha, so a SetAlpha hook does not see it.
function Frame:SetAlphaFromBoolean(on, yes, no) bump(self, "SetAlphaFromBoolean"); self._alpha = on and (yes or 1) or (no or 0) end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
    local p = self
    while p do
        if not p._shown then return false end
        p = p._parent
    end
    return true
end
function Frame:Show()
    local was = self._shown
    self._shown = true
    if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function Frame:Hide()
    local was = self._shown
    self._shown = false
    if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p) self._parent = p
    if p and p._children then p._children[#p._children + 1] = self end
end
function Frame:GetName() return self._name end
function Frame:GetObjectType() return self._kind end
function Frame:IsObjectType(kind) return self._kind == kind end
function Frame:GetFrameLevel() return self._level end
function Frame:SetFrameLevel(v) self._level = v end
function Frame:GetFrameStrata() return self._strata end
function Frame:SetFrameStrata(v) self._strata = v end
function Frame:GetWidth() return self._w end
function Frame:GetHeight() return self._h end
function Frame:SetWidth(v) self._w = v end
function Frame:SetHeight(v) self._h = v end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:GetSize() return self._w, self._h end
function Frame:GetScale() return self._scale end
function Frame:SetScale(v) self._scale = v end
function Frame:GetEffectiveScale() return self._scale end
function Frame:ClearAllPoints() self._points = {} end
function Frame:SetPoint(...) self._points[#self._points + 1] = { ... } end
function Frame:SetAllPoints(...) self._points = { { "ALL", ... } } end
function Frame:GetNumPoints() return #self._points end
function Frame:GetPoint(i)
    local p = self._points[i or 1]
    if not p then return nil end
    return unpack(p)
end
function Frame:GetLeft() return 0 end
function Frame:GetBottom() return 0 end
function Frame:GetRight() return self._w end
function Frame:GetTop() return self._h end
function Frame:GetCenter() return self._w / 2, self._h / 2 end
function Frame:EnableMouse(v) self._mouse = v and true or false end
function Frame:IsMouseEnabled() return self._mouse end
function Frame:IsMouseOver() return self._mouseOver and true or false end
function Frame:SetMouseOver(v) self._mouseOver = v end -- test helper
function Frame:GetNumChildren() return #self._children end
function Frame:GetChildren() bump(self, "GetChildren"); return unpack(self._children) end
function Frame:GetNumRegions() return #self._regions end
function Frame:GetRegions() bump(self, "GetRegions"); return unpack(self._regions) end
function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:HookScript(name, fn)
    local list = self._hooks[name]
    if not list then
        list = {}
        self._hooks[name] = list
        local prior = self._scripts[name]
        self._scripts[name] = function(f, ...)
            if prior then prior(f, ...) end
            for i = 1, #list do list[i](f, ...) end
        end
    end
    list[#list + 1] = fn
end
function Frame:HasScript(name) return self._scripts[name] ~= nil end
function Frame:RegisterEvent(event)
    if self._mock.badEvents[event] then error("Unknown event: " .. tostring(event), 2) end
    self._events[event] = true
end
function Frame:RegisterUnitEvent(event) self:RegisterEvent(event) end
function Frame:UnregisterEvent(event) self._events[event] = nil end
function Frame:UnregisterAllEvents() self._events = {} end
function Frame:IsEventRegistered(event) return self._events[event] == true end
-- Alpha inheritance: SetIgnoreParentAlpha / IsIgnoringParentAlpha keep a flag; SetAbsent(name)
-- makes a method read back as nil on that one frame (probed optional API missing).
function Frame:SetIgnoreParentAlpha(v) self._ignoreParent = v and true or false end
function Frame:IsIgnoringParentAlpha() return self._ignoreParent or false end
function Frame:SetAbsent(name) self._absent = self._absent or {}; self._absent[name] = true end

local function newRegion(self, kind, layer)
    local r = newFrame(self._mock, kind, nil, self)
    -- regions are not children
    self._children[#self._children] = nil
    r._layer = layer
    self._regions[#self._regions + 1] = r
    return r
end
function Frame:CreateTexture(name, layer) return newRegion(self, "Texture", layer) end
function Frame:CreateFontString(name, layer) return newRegion(self, "FontString", layer) end
function Frame:GetDrawLayer() return self._layer end
function Frame:CreateAnimationGroup()
    local group = newFrame(self._mock, "AnimationGroup", nil, nil)
    group._owner = self
    return group
end
-- Animation group state: _owner (frame it was created on), _looping, _playing, _plays (Play count).
function Frame:SetLooping(v) self._looping = v end
function Frame:GetLooping() return self._looping end
function Frame:Play() self._playing = true; self._plays = (self._plays or 0) + 1 end
function Frame:Stop() self._playing = false end
function Frame:IsPlaying() return self._playing == true end
function Frame:SetTexture(v) self._texture = v end
function Frame:GetTexture() return self._texture end
function Frame:SetColorTexture(...) self._color = { ... } end
-- On a texture the vertex alpha is the texture's alpha, set past any SetAlpha hook.
function Frame:SetVertexColor(...)
    self._vertex = { ... }
    local a = select(4, ...)
    if self._kind == "Texture" and a ~= nil then self._alpha = a end
end
function Frame:SetTexCoord(...) self._texCoord = { ... } end
function Frame:GetTexCoord()
    local c = self._texCoord or { 0, 1, 0, 1 }
    return unpack(c)
end
function Frame:GetVertexColor()
    local c = self._vertex or { 1, 1, 1, 1 }
    return unpack(c)
end
-- Dragging: StartMoving / StopMovingOrSizing keep a flag; a test moves the frame between the two
-- with ClearAllPoints + SetPoint, as the client would. SetMovable / RegisterForDrag only record.
function Frame:SetMovable(v) self._movable = v and true or false end
function Frame:IsMovable() return self._movable == true end
function Frame:RegisterForDrag(...) self._dragButtons = { ... } end
function Frame:StartMoving() self._moving = true end
function Frame:StopMovingOrSizing() self._moving = false end
function Frame:IsMoving() return self._moving == true end
function Frame:SetBlendMode(v) self._blend = v end
function Frame:SetText(v) self._text = v == nil and "" or v end
function Frame:GetText() return self._text end
function Frame:SetFont(face, size, flags) self._font = { face, size, flags } end
function Frame:GetFont()
    local f = self._font or { "Fonts\\FRIZQT__.TTF", 12, "" }
    return f[1], f[2], f[3]
end
function Frame:SetFontObject(v) self._fontObject = v end
function Frame:SetTextColor(...) self._textColor = { ... } end
function Frame:GetTextColor()
    local c = self._textColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end
function Frame:SetJustifyH(v) self._justifyH = v end
function Frame:GetJustifyH() return self._justifyH end
function Frame:SetJustifyV(v) self._justifyV = v end
-- Deterministic text: width = chars * CHAR_W, one fixed line, no wrapping.
function Frame:GetStringWidth()
    return #tostring(self._text or "") * CHAR_W
end
function Frame:GetStringHeight() return LINE_H end
function Frame:GetUnboundedStringWidth() return self:GetStringWidth() end
function Frame:GetNumLines() return 1 end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked end
function Frame:Click(...)
    local fn = self._scripts.OnClick
    if fn then fn(self, ...) end
end
function Frame:SetValue(v) self._value = v end
function Frame:GetValue() return self._value end
function Frame:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:IsEnabled() return self._enabled ~= false end
function Frame:SetCursorPosition() end
function Frame:HighlightText() end
function Frame:SetFocus() self._mock.state.focus = self end
function Frame:ClearFocus() if self._mock.state.focus == self then self._mock.state.focus = nil end end
function Frame:HasFocus() return self._mock.state.focus == self end
-- Chat frame surface.
function Frame:AddMessage(text, ...)
    self._lines = self._lines or {}
    self._lines[#self._lines + 1] = text
end
function Frame:GetNumMessages() return self._lines and #self._lines or 0 end
function Frame:GetMessageInfo(i) return self._lines and self._lines[i] end
function Frame:IsMouseWheelEnabled() return false end
-- Scroll frame surface (the setup window reads it back).
function Frame:SetVerticalScroll(v) self._vscroll = v end
function Frame:GetVerticalScroll() return self._vscroll or 0 end

------------------------------------------------------------------------------

function M.new()
    local mock = setmetatable({}, M)
    mock.G = {}            -- globals to install
    mock.frames = {}
    mock.createLog = {}
    mock.calls = { GetAlpha = 0, GetChildren = 0, GetRegions = 0, GetNamePlateForUnit = 0 }
    mock.unknown = {}
    mock.printed = {}
    mock.cvars = {}
    mock.cvarLog = {}
    mock.units = {}
    mock.state = { combat = false, instance = false, instanceType = "none", group = false,
        raid = false, cursor = { 0, 0 }, focus = nil, mouseFocus = nil, vehicle = false }
    mock.badEvents = {}
    mock.now = 1000
    mock.profile = 0
    mock.timers = {}
    mock.secrets = setmetatable({}, { __mode = "k" })
    mock.hooks = {}
    mock.nameplates = {}
    mock.rejectTemplates = {}
    mock.slash = {}
    mock:build()
    return mock
end

function M:build()
    local mock, G = self, self.G
    local function frame(kind, name, parent, template) return newFrame(mock, kind, name, parent, template) end

    G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        mock.printed[#mock.printed + 1] = table.concat(parts, " ")
    end
    G.UIParent = frame("Frame", "UIParent", nil)
    G.WorldFrame = frame("Frame", "WorldFrame", nil)
    G.CreateFrame = function(kind, name, parent, template)
        mock.createLog[#mock.createLog + 1] = { kind = kind, name = name, parent = parent, template = template }
        if template and mock.rejectTemplates[template] then
            error("Unknown template: " .. tostring(template), 2)
        end
        local f = frame(kind, name, parent or G.UIParent, template)
        if type(name) == "string" and name ~= "" then
            G[name] = f
            _G[name] = f
        end
        return f
    end
    G.hooksecurefunc = function(a, b, c)
        local obj, method, hook
        if type(a) == "string" then obj, method, hook = _G, a, b else obj, method, hook = a, b, c end
        local original = obj[method]
        if type(original) ~= "function" then error("hooksecurefunc: missing " .. tostring(method), 2) end
        mock.hooks[#mock.hooks + 1] = { obj = obj, method = method }
        obj[method] = function(...)
            local r = { original(...) }
            hook(...)
            return unpack(r)
        end
    end
    G.pcall = pcall

    -- Time
    G.GetTime = function() return mock.now end
    G.debugprofilestop = function() return mock.profile end
    G.GetServerTime = function() return 1700000000 + math.floor(mock.now) end
    G.time = os.time
    G.date = os.date
    G.C_Timer = {
        After = function(delay, fn)
            mock.timers[#mock.timers + 1] = { at = mock.now + (delay or 0), fn = fn, seq = #mock.timers + 1 }
        end,
        NewTimer = function(delay, fn)
            local t = { cancelled = false }
            G.C_Timer.After(delay, function() if not t.cancelled then fn(t) end end)
            t.Cancel = function(self) self.cancelled = true end
            return t
        end,
    }

    -- CVars
    G.GetCVar = function(name) return mock.cvars[name] end
    G.GetCVarBool = function(name) local v = mock.cvars[name]; return v == "1" or v == 1 or v == true end
    G.SetCVar = function(name, value)
        mock.cvars[name] = value == nil and nil or tostring(value)
        mock.cvarLog[#mock.cvarLog + 1] = { name, value }
        return true
    end
    G.C_CVar = {
        GetCVar = G.GetCVar, SetCVar = G.SetCVar, GetCVarBool = G.GetCVarBool,
        GetCVarDefault = function() return nil end,
    }

    -- Game state
    G.InCombatLockdown = function() return mock.state.combat end
    G.UnitAffectingCombat = function() return mock.state.combat end
    G.IsInInstance = function() return mock.state.instance, mock.state.instanceType end
    G.IsInGroup = function() return mock.state.group end
    G.IsInRaid = function() return mock.state.raid end
    G.GetNumGroupMembers = function() return mock.state.group and 2 or 0 end
    G.GetCursorPosition = function() return mock.state.cursor[1], mock.state.cursor[2] end
    G.GetMouseFocus = function() return mock.state.mouseFocus end
    G.GetMouseFoci = function() return { mock.state.mouseFocus } end
    G.IsShiftKeyDown = function() return false end
    G.IsControlKeyDown = function() return false end
    G.IsAltKeyDown = function() return false end
    G.GetCursorInfo = function() return nil end
    G.UnitInVehicle = function() return mock.state.vehicle end
    G.HasVehicleActionBar = function() return mock.state.vehicle end
    G.IsMounted = function() return false end
    G.GetLocale = function() return "enUS" end
    G.GetBuildInfo = function() return "1.0.0", "16001", "Jan 1 2026", 16001 end
    G.IsLoggedIn = function() return true end
    G.IsAddOnLoaded = function(name) return mock.loadedAddons and mock.loadedAddons[name] or false end
    G.C_AddOns = { IsAddOnLoaded = G.IsAddOnLoaded, LoadAddOn = function() return false end,
        GetAddOnMetadata = function() return "0.0.0" end }
    G.LoadAddOn = function() return false end
    G.GetAddOnMetadata = function() return "0.0.0" end
    G.GetFramerate = function() return 60 end
    G.GetScreenWidth = function() return 1920 end
    G.GetScreenHeight = function() return 1080 end
    G.issecurevariable = function() return false end
    G.CopyTable = function(t)
        local function copy(v)
            if type(v) ~= "table" then return v end
            local r = {}
            for k, x in pairs(v) do r[k] = copy(x) end
            return r
        end
        return copy(t)
    end
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.tinsert = table.insert
    G.tremove = table.remove
    G.strsplit = function(sep, s, n)
        local out, pos = {}, 1
        while true do
            local a, b = s:find(sep, pos, true)
            if not a or (n and #out >= n - 1) then out[#out + 1] = s:sub(pos); break end
            out[#out + 1] = s:sub(pos, a - 1)
            pos = b + 1
        end
        return unpack(out)
    end
    G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    G.format = string.format
    G.unpack = unpack
    G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
    G.strmatch, G.strsub, G.strlen, G.strrep = string.match, string.sub, string.len, string.rep
    G.strbyte, G.strchar = string.byte, string.char
    G.strlower = string.lower
    G.strupper = string.upper
    G.strfind = string.find
    G.gsub = string.gsub
    G.floor = math.floor
    G.ceil = math.ceil
    G.max = math.max
    G.min = math.min
    G.abs = math.abs
    G.sort = table.sort
    G.getn = function(t) return #t end
    G.PlaySound = function() end
    G.SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
    G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
    G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0, GetRGB = function() return 1, 0.82, 0 end }
    G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    G.GameFontNormal = frame("Font", "GameFontNormal", nil)
    G.Enum = setmetatable({}, { __index = function(t, k)
        local v = setmetatable({}, { __index = function() return 0 end })
        rawset(t, k, v)
        return v
    end })
    G.Mixin = function(obj, ...)
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do obj[k] = v end end
        return obj
    end
    G.CreateFromMixins = function(...) return G.Mixin({}, ...) end
    G.GetNumShapeshiftForms = function() return 0 end
    G.GetNumTrackingTypes = function() return 0 end
    G.GetRealmName = function() return "Realm" end
    G.UnitName = function(unit) local u = mock.units[unit]; return u and u.name or nil end

    -- Saved variables (tests may overwrite)
    G.QuietUIDB = { enabled = true }
    G.QuietUICharDB = {}
    G.SlashCmdList = mock.slash
    G.SLASH_QUIETUI1 = nil

    -- Secret values and curves
    G.issecretvalue = function(v) return type(v) == "table" and mock.secrets[v] == true end
    G.issecrettable = function() return false end
    G.C_CurveUtil = {
        CreateCurve = function()
            local curve = { points = {}, kind = nil }
            function curve:SetType(v) self.kind = v end
            function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
            function curve:ClearPoints() self.points = {} end
            function curve:GetPointCount() return #self.points end
            function curve:Evaluate(x)
                local pts, last = self.points, nil
                for i = 1, #pts do
                    if pts[i][1] <= x then last = pts[i][2] end
                end
                return last
            end
            return curve
        end,
        CreateColorCurve = function() return G.C_CurveUtil.CreateCurve() end,
    }

    -- Units: mock.units[token] = { exists, name, guid, dead, attackable, health, healthMax,
    -- power, powerMax, level, classification, creatureType, player }
    G.UnitExists = function(u) local x = mock.units[u]; return x ~= nil and x.exists ~= false end
    G.UnitGUID = function(u) local x = mock.units[u]; return x and x.guid end
    G.UnitIsDead = function(u) local x = mock.units[u]; return x and x.dead or false end
    G.UnitIsDeadOrGhost = G.UnitIsDead
    G.UnitCanAttack = function(_, u) local x = mock.units[u]; return x and x.attackable or false end
    G.UnitIsPlayer = function(u) local x = mock.units[u]; return x and x.player or false end
    G.UnitIsUnit = function(a, b) return a == b or (mock.units[a] ~= nil and mock.units[a] == mock.units[b]) end
    G.UnitHealth = function(u) local x = mock.units[u]; return x and x.health or 0 end
    G.UnitHealthMax = function(u) local x = mock.units[u]; return x and x.healthMax or 0 end
    G.UnitPower = function(u) local x = mock.units[u]; return x and x.power or 0 end
    G.UnitPowerMax = function(u) local x = mock.units[u]; return x and x.powerMax or 0 end
    G.UnitPowerType = function() return 0, "MANA" end
    G.UnitHealthPercent = function(u, _, curve)
        local x = mock.units[u]
        local pct = x and x.healthMax and x.healthMax > 0 and (x.health / x.healthMax) or 0
        if curve and curve.Evaluate then return curve:Evaluate(pct) end
        return pct
    end
    G.UnitPowerPercent = function(u, _, _, curve)
        local x = mock.units[u]
        local pct = x and x.powerMax and x.powerMax > 0 and (x.power / x.powerMax) or 0
        if curve and curve.Evaluate then return curve:Evaluate(pct) end
        return pct
    end
    G.UnitLevel = function(u) local x = mock.units[u]; return x and x.level or 1 end
    G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
    G.UnitClassification = function(u) local x = mock.units[u]; return x and x.classification or "normal" end
    G.UnitReaction = function() return 4 end
    G.UnitIsFriend = function() return false end
    G.UnitPlayerControlled = function() return false end
    G.UnitThreatSituation = function() return nil end
    G.UnitInRange = function() return true end
    G.UnitCastingInfo = function() return nil end
    G.UnitChannelInfo = function() return nil end
    G.UnitAura = function() return nil end
    G.UnitBuff = function() return nil end
    G.UnitDebuff = function() return nil end
    G.GetUnitName = function(u) return G.UnitName(u) end
    G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end,
        GetUnitAuras = function() return {} end }
    G.C_NamePlate = {
        GetNamePlateForUnit = function(unit)
            mock.calls.GetNamePlateForUnit = mock.calls.GetNamePlateForUnit + 1
            return mock.nameplates[unit]
        end,
        GetNamePlates = function()
            local out = {}
            for _, p in pairs(mock.nameplates) do out[#out + 1] = p end
            return out
        end,
    }

    -- Range / spells / bars
    G.C_Spell = { IsSpellInRange = function() return nil end, GetSpellInfo = function() return nil end,
        IsSpellUsable = function() return true end }
    G.C_Item = { IsItemInRange = function() return nil end }
    G.C_ActionBar = { IsActionInRange = function() return nil end, HasAction = function() return false end }
    G.IsActionInRange = function() return nil end
    G.HasAction = function() return false end
    G.GetActionInfo = function() return nil end
    G.GetSpellInfo = function() return nil end
    G.IsSpellInRange = function() return nil end
    G.C_QuestLog = { GetNumQuestLogEntries = function() return 0, 0 end,
        GetInfo = function() return nil end, GetTitleForQuestID = function() return nil end,
        IsQuestFlaggedCompleted = function() return false end,
        GetNumQuestWatches = function() return 0 end, GetQuestIDForQuestWatchIndex = function() return nil end,
        GetQuestObjectives = function() return {} end, IsOnQuest = function() return false end,
        GetQuestLogIndexForQuestID = function() return nil end,
        IsQuestTask = function() return false end }
    G.C_TooltipInfo = {}
    G.GetQuestLogTitle = function() return nil end
    G.GetNumQuestLogEntries = function() return 0, 0 end
    G.C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end }
    G.C_PetBattles = { IsInBattle = function() return false end }
    G.C_EditMode = {
        GetLayouts = function() return { layouts = {}, activeLayout = 1 } end,
        SetActiveLayout = function() end, OnLayoutAdded = function() end,
        GetLayoutInfo = function() return nil end,
        ConvertStringToLayoutInfo = function(s) return { layoutName = "", layoutType = 1, source = s } end,
        ConvertLayoutInfoToString = function() return "" end, SaveLayouts = function() end,
        IsEditModeActive = function() return false end,
    }
    G.EditModeManagerFrame = frame("Frame", "EditModeManagerFrame", G.UIParent)
    G.EditModeManagerFrame:Hide()
    G.EditModeManagerFrame.IsEditModeActive = function() return false end
    G.EditModeManagerFrame.GetActiveLayoutInfo = function() return nil end
    G.C_Container = { GetContainerNumSlots = function() return 0 end,
        GetContainerItemInfo = function() return nil end, GetContainerNumFreeSlots = function() return 0 end }
    G.GetContainerNumSlots = function() return 0 end
    G.NUM_BAG_SLOTS = 4
    G.NUM_CHAT_WINDOWS = 10
    G.GetInventoryItemID = function() return nil end

    -- Global frames named in AGENTS.md and the ones the code probes at load
    local named = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
        "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
        "OverrideActionBar", "ExtraActionBarFrame", "ZoneAbilityFrame", "MicroMenu", "BagsBar",
        "MainMenuBarBackpackButton", "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer", "PlayerFrame", "PetFrame", "TargetFrame",
        "FocusFrame", "PartyFrame", "CompactRaidFrameContainer", "CompactPartyFrame",
        "BuffFrame", "DebuffFrame", "ObjectiveTrackerFrame", "QuestWatchFrame", "MinimapCluster",
        "Minimap", "QueueStatusButton", "GameTooltip", "ChatFrameMenuButton", "QuickJoinToastButton",
        "ChatFrameChannelButton", "GeneralDockManager", "EssentialCooldownViewer",
        "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer",
        "PersonalResourceDisplayFrame", "DamageMeter", "MainMenuBar", "TalkingHeadFrame",
        "TargetFrameToT", "FocusFrameToT" }
    for _, n in ipairs(named) do
        G[n] = frame("Frame", n, G.UIParent)
    end
    G.StanceBar = G.StanceBar
    G.GameTooltip.SetOwner = function(self, owner) self._owner = owner end
    G.GameTooltip.AddLine = function(self, text) self._lines = self._lines or {}; self._lines[#self._lines + 1] = text end
    G.GameTooltip.SetText = function(self, text) self._lines = { text } end
    G.GameTooltip.ClearLines = function(self) self._lines = {} end
    G.GameTooltip.SetHyperlink = function(self, link) self._link = link end
    G.GameTooltip:Hide()
    G.Minimap.GetZoom = function() return 0 end
    G.DEFAULT_CHAT_FRAME = nil

    -- Chat: ChatFrame1..N with tab, edit box, button frame, scroll bar.
    for i = 1, G.NUM_CHAT_WINDOWS do
        local name = "ChatFrame" .. i
        local cf = frame("ScrollingMessageFrame", name, G.UIParent)
        cf.GetID = function() return i end
        cf.GetNumMessages = Frame.GetNumMessages
        cf.SetFading = function() end
        G[name .. "Tab"] = frame("Button", name .. "Tab", G.UIParent)
        G[name .. "EditBox"] = frame("EditBox", name .. "EditBox", cf)
        G[name .. "ButtonFrame"] = frame("Frame", name .. "ButtonFrame", cf)
        G[name .. "Background"] = frame("Texture", name .. "Background", cf)
        G[name .. "ResizeButton"] = frame("Button", name .. "ResizeButton", cf)
        G[name .. "EditBoxLeft"] = frame("Texture", name .. "EditBoxLeft", cf)
        G[name .. "EditBoxMid"] = frame("Texture", name .. "EditBoxMid", cf)
        G[name .. "EditBoxRight"] = frame("Texture", name .. "EditBoxRight", cf)
        G[name .. "EditBoxFocusLeft"] = frame("Texture", name .. "EditBoxFocusLeft", cf)
        G[name .. "EditBoxFocusMid"] = frame("Texture", name .. "EditBoxFocusMid", cf)
        G[name .. "EditBoxFocusRight"] = frame("Texture", name .. "EditBoxFocusRight", cf)
    end
    G.DEFAULT_CHAT_FRAME = G.ChatFrame1
    G.SELECTED_CHAT_FRAME = G.ChatFrame1
    G.FCF_SetWindowAlpha = function() end
    G.FCF_SetWindowColor = function() end
    G.FCF_DockUpdate = function() end
    G.FCF_SetTabPosition = function() end
    G.FCF_RestorePositionAndDimensions = function() end
    G.FCF_OpenTemporaryWindow = function() end
    G.UpdateMicroButtons = function() end
    G.ChatFrame_OnHyperlinkShow = function(...) mock.hyperlinkShown = { ... } end
    G.SetItemRef = function(...) mock.itemRef = { ... } end
    G.ChatEdit_ActivateChat = function() end
    G.ChatEdit_GetActiveWindow = function() return nil end
    G.ChatFrame_OpenChat = function() end
    G.ChatTypeInfo = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
    G.CHAT_FRAMES = {}
    for i = 1, G.NUM_CHAT_WINDOWS do G.CHAT_FRAMES[i] = "ChatFrame" .. i end
    G.MouseIsOver = function() return false end
    G.GetCurrentKeyBoardFocus = function() return mock.state.focus end

    -- Misc names probed at load
    G.Settings = nil
    G.C_Timer.NewTicker = function(delay, fn)
        local t = { cancelled = false }
        t.Cancel = function(self) self.cancelled = true end
        return t
    end
    G.GetNumGroupMembers = G.GetNumGroupMembers
    G.UISpecialFrames = {}
    G.StaticPopupDialogs = {}
    G.StaticPopup_Show = function() end
    G.ReloadUI = function() end
    G.GetBindingKey = function() return nil end
    G.GetBindingAction = function() return "" end
    G.SetBinding = function() end
    G.SaveBindings = function() end
    G.IsLeftShiftKeyDown = function() return false end
    G.C_Map = { GetBestMapForUnit = function() return nil end }
    G.C_PlayerInteractionManager = {}
    G.GetSoftTargetInfo = nil
    G.UIDropDownMenu_Initialize = function() end
    G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGBA = function() return r, g, b, a end } end
    G.Spell = nil
end

-- Install mock globals into _G (the runner snapshots/restores _G around each test).
function M:install()
    for k, v in pairs(self.G) do _G[k] = v end
    return self
end

------------------------------------------------------------------------------
-- Test helpers

function M:secret(value)
    local box = { value = value }
    self.secrets[box] = true
    return box
end

function M:setUnit(token, fields)
    local u = self.units[token] or { exists = true }
    for k, v in pairs(fields or {}) do u[k] = v end
    self.units[token] = u
    return u
end

function M:find(pred)
    local out = {}
    for _, f in ipairs(self.frames) do
        if pred(f) then out[#out + 1] = f end
    end
    return out
end

function M:findByName(name) return self.G[name] end

function M:eventFrame(event)
    for _, f in ipairs(self.frames) do
        if f._events[event] then return f end
    end
end

function M:fire(event, ...)
    local fired = 0
    for _, f in ipairs(self.frames) do
        if f._events[event] and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
            fired = fired + 1
        end
    end
    return fired
end

function M:tick(elapsed)
    for _, f in ipairs(self.frames) do
        local fn = f._scripts.OnUpdate
        if fn and f._shown then fn(f, elapsed) end
    end
end

-- First button/checkbox/etc. whose own text, or a child region's text, contains `text`.
function M:control(kind, text)
    for _, f in ipairs(self.frames) do
        if not kind or f._kind == kind then
            local label = f._text
            if (not label or label == "") and f.Text then label = f.Text._text end
            if type(label) ~= "string" or label == "" then
                for _, r in ipairs(f._regions) do
                    if type(r._text) == "string" and r._text ~= "" then label = r._text; break end
                end
            end
            if type(label) == "string" and label:find(text, 1, true) then return f end
        end
    end
end

local function runDue(self, limit)
    local ran = 0
    while true do
        local pick, idx
        for i, t in ipairs(self.timers) do
            if t.at <= limit and (not pick or t.at < pick.at or (t.at == pick.at and t.seq < pick.seq)) then
                pick, idx = t, i
            end
        end
        if not pick then break end
        table.remove(self.timers, idx)
        if pick.at > self.now then self.now = pick.at end
        pick.fn()
        ran = ran + 1
        if ran > 10000 then error("C_Timer queue does not settle") end
    end
    return ran
end

function M:advance(seconds)
    local target = self.now + seconds
    runDue(self, target)
    self.now = target
end

-- Run every queued timer regardless of delay (and timers they queue). Clock moves to the last one.
function M:drain()
    return runDue(self, math.huge)
end

function M:pendingTimers() return #self.timers end

------------------------------------------------------------------------------
-- Quest mob world (tests/questmobs): attackable/related nameplate units with tooltip lines
-- and quest objectives, call counters for the client APIs the feature reads, and the
-- invariants every such test ends with (w.check). Call after mock:install().
--   w.addPlate(token, spec, opts)   spec: attack, related, lines (+ noAttack, noRelated flags);
--                                   opts: noHealthBar, barHeight; returns the plate (mock.nameplates)
--   w.removePlate(token)            w.iconOn(plate) -> "kill" | "loot" | nil (at most one visible)
--   w.roots(plate)                  icon frames attached below plate;  w.nothingShown()
--   w.calls[name][arg], w.total[name]: UnitCanAttack, Related, GetUnit, Objectives, GetNamePlates
--   w.objectives[questID]           w.tooltipUsed / w.violations: GameTooltip use, plate mutations
function M:questWorld()
    local mock = self
    local w = { calls = {}, total = {}, objectives = {}, violations = {}, tooltipUsed = 0,
        base = #mock.frames, timers0 = #mock.timers, TITLE = 17, OBJECTIVE = 8 }
    local function rec(name, arg)
        w.calls[name] = w.calls[name] or {}
        w.calls[name][arg] = (w.calls[name][arg] or 0) + 1
        w.total[name] = (w.total[name] or 0) + 1
    end
    function w.count(name, arg) return (w.calls[name] or {})[arg] or 0 end
    function w.quest(id, title) return { type = w.TITLE, id = id, leftText = title or ("Quest " .. id) } end
    function w.objective(text) return { type = w.OBJECTIVE, leftText = text } end
    function w.pending() return #mock.timers - w.timers0 end

    _G.GameTooltip = setmetatable({}, { __index = function()
        return function() w.tooltipUsed = w.tooltipUsed + 1 end
    end })
    _G.C_QuestLog.UnitIsRelatedToActiveQuest = function(unit)
        rec("Related", unit)
        local u = mock.units[unit]
        if u then return u.related end
        return false
    end
    _G.C_QuestLog.GetQuestObjectives = function(id) rec("Objectives", id); return w.objectives[id] end
    _G.C_TooltipInfo = { GetUnit = function(unit)
        rec("GetUnit", unit)
        local u = mock.units[unit]
        if not u or u.lines == nil then return nil end
        return { lines = u.lines }
    end }
    local canAttack, getPlates = _G.UnitCanAttack, _G.C_NamePlate.GetNamePlates
    _G.UnitCanAttack = function(a, b)
        rec("UnitCanAttack", b)
        if a ~= "player" then w.violations[#w.violations + 1] = "UnitCanAttack asked for " .. tostring(a) end
        return canAttack(a, b)
    end
    _G.C_NamePlate.GetNamePlates = function() rec("GetNamePlates", "all"); return getPlates() end

    local function guard(f, label)
        f._plate = true
        for _, m in ipairs({ "SetAlpha", "SetPoint", "ClearAllPoints", "Show", "Hide" }) do
            local orig = f[m]
            f[m] = function(self, ...)
                w.violations[#w.violations + 1] = label .. ":" .. m
                return orig(self, ...)
            end
        end
    end
    function w.addPlate(token, spec, opts)
        spec, opts = spec or {}, opts or {}
        local plate = CreateFrame("Frame", nil, UIParent)
        local unitFrame = CreateFrame("Frame", nil, plate)
        unitFrame.unit = token
        plate.UnitFrame, plate.namePlateUnitToken = unitFrame, token
        guard(plate, token); guard(unitFrame, token .. ".UnitFrame")
        if not opts.noHealthBar then
            local bar = CreateFrame("StatusBar", nil, unitFrame)
            bar:SetHeight(opts.barHeight or 8)
            unitFrame.healthBar, plate.bar = bar, bar
            guard(bar, token .. ".healthBar")
        end
        local u = { exists = true, attackable = true, related = true, lines = spec.lines }
        if spec.attack ~= nil or spec.noAttack then u.attackable = spec.attack end
        if spec.related ~= nil or spec.noRelated then u.related = spec.related end
        mock.units[token], mock.nameplates[token] = u, plate
        return plate
    end
    function w.removePlate(token) mock.units[token], mock.nameplates[token] = nil, nil end

    local function kindOf(path)
        if type(path) ~= "string" then return end
        path = path:lower():gsub("\\", "/")
        if path:find("media/quest%-kill") then return "kill" end
        if path:find("media/quest%-loot") then return "loot" end
    end
    local function within(f, root)
        for _ = 1, 50 do
            if not f then return false end
            if f == root then return true end
            f = f._parent
        end
        return false
    end
    local function visible(f)
        for _ = 1, 50 do
            if not f then return true end
            if f._shown == false or (type(f._alpha) == "number" and f._alpha <= 0) then return false end
            f = f._parent
        end
        return true
    end
    w.within, w.visible = within, visible
    -- The visible quest icon texture on plate, never more than one.
    function w.iconOn(plate)
        local kind, tex, n = nil, nil, 0
        for _, f in ipairs(mock.frames) do
            local k = f._kind == "Texture" and kindOf(f._texture)
            if k and within(f, plate) and visible(f) then n = n + 1; kind, tex = k, f end
        end
        if n > 1 then error("expected at most one quest icon on a plate, got " .. n, 0) end
        return kind, tex
    end
    function w.roots(plate)
        local list = {}
        for i = w.base + 1, #mock.frames do
            local f = mock.frames[i]
            if f._kind == "Frame" and not f._plate and f._parent and f._parent ~= UIParent
                and within(f._parent, plate) then
                list[#list + 1] = f
            end
        end
        return list
    end
    function w.nothingShown()
        for _, f in ipairs(mock.frames) do
            if f._kind == "Texture" and kindOf(f._texture) and visible(f) then return false end
        end
        return true
    end
    function w.reports()
        local n = 0
        for _, line in ipairs(mock.printed) do if line:find("error", 1, true) then n = n + 1 end end
        return n
    end
    -- End-of-test invariants: plates untouched, no OnUpdate, no GameTooltip, no stray output,
    -- every visible icon sits on a current plate. allowOutput skips the chat-output rule.
    function w.check(allowOutput)
        if #w.violations > 0 then error("plate frames were touched: " .. table.concat(w.violations, ", "), 0) end
        for i = w.base + 1, #mock.frames do
            if mock.frames[i]._scripts.OnUpdate then error("an OnUpdate script was set on a created frame", 0) end
        end
        if w.tooltipUsed > 0 then error("GameTooltip was used " .. w.tooltipUsed .. " times", 0) end
        if not allowOutput and #mock.printed > 0 then
            error("unexpected chat output: " .. table.concat(mock.printed, " | "), 0)
        end
        for _, f in ipairs(mock.frames) do
            if f._kind == "Texture" and kindOf(f._texture) and visible(f) then
                local home = false
                for _, plate in pairs(mock.nameplates) do if within(f, plate) then home = true end end
                if not home then error("a visible quest icon is not on any current nameplate", 0) end
            end
        end
    end
    return w
end

return M
