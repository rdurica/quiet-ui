-- Helpers for tests/modern, loaded with h.lib("modern"). Fake areas are registered through the
-- public ns.Modern.Register, so the tests do not depend on which real areas exist.
local L = {}

-- Lines printed through ns.Report ("<name> error (shown once): ...").
function L.errors(mock)
    local n = 0
    for _, line in ipairs(mock.printed) do
        if line:find("error (shown once)", 1, true) then n = n + 1 end
    end
    return n
end

-- Modernize on (plus extra keys such as { bars = false, opacity = 90 }).
function L.enable(extra)
    local m = { enabled = true }
    for k, v in pairs(extra or {}) do m[k] = v end
    QuietUICharDB = QuietUICharDB or {}
    QuietUICharDB.modernize = m
    return m
end

-- Registers a fake area whose apply zooms its own icon and holds its own art through the skin
-- journal. Returns counters and the objects it touches:
--   c.apply / c.restore / c.event   call counts      c.log   shared ordered log when opts.log is given
--   c.icon, c.art, c.panel          objects (icon TexCoord, art alpha 0.6 held at 0, panel frame)
--   c.skin                          the journal the registry passed to apply
function L.area(t, key, opts)
    opts = opts or {}
    local c = { apply = 0, restore = 0, event = 0, args = nil }
    local holder = CreateFrame("Frame", nil, UIParent)
    c.panel = holder
    c.icon = holder:CreateTexture(nil, "ARTWORK")
    c.icon:SetTexture("Interface\\Icons\\Original-" .. key)
    c.art = holder:CreateTexture(nil, "BACKGROUND")
    c.art:SetAlpha(0.6)
    local spec = {
        key = key,
        label = opts.label or ("Area " .. key),
        apply = opts.apply or function(skin)
            c.apply = c.apply + 1
            c.skin = skin
            if opts.log then opts.log[#opts.log + 1] = "apply:" .. key end
            skin:Icon(c.icon)
            skin:Hold(c.art)
        end,
        events = opts.events,
        addons = opts.addons,
        onEvent = opts.events and function(skin, event, ...)
            c.event = c.event + 1
            c.args = { skin = skin, event = event, ... }
        end or nil,
    }
    if opts.restore then
        spec.restore = function(skin)
            c.restore = c.restore + 1
            if opts.log then opts.log[#opts.log + 1] = "restore:" .. key end
            opts.restore(skin)
        end
    elseif opts.log or opts.countRestore then
        spec.restore = function(skin)
            c.restore = c.restore + 1
            if opts.log then opts.log[#opts.log + 1] = "restore:" .. key end
            skin:Undo()
        end
    end
    if opts.raw then spec = opts.raw(spec) end
    t.assert.type(t.ns.Modern, "table", "ns.Modern")
    t.assert.type(t.ns.Modern.Register, "function", "ns.Modern.Register")
    t.ns.Modern.Register(spec)
    return c
end

function L.zoomed(tex)
    local a, b, c, d = tex:GetTexCoord()
    return a == 0.08 and b == 0.92 and c == 0.08 and d == 0.92
end

-- Index of the entry with this key in ns.Modern.Areas(), or nil.
function L.indexOf(ns, key)
    for i, a in ipairs(ns.Modern.Areas()) do if a.key == key then return i, a end end
end

-- Moves the drag handle of a movable frame as a player would: finds the handle (a child with
-- OnDragStart, else OnMouseDown), starts, moves the frame to the point, stops.
function L.handle(frame)
    local found
    for _, child in ipairs(frame._children) do
        if child._scripts.OnDragStart or child._scripts.OnMouseDown then found = child; break end
    end
    return found
end

function L.drag(frame, point, relativePoint, x, y)
    local handle = L.handle(frame)
    assert(handle, "no drag handle child with OnDragStart / OnMouseDown")
    local startFn = handle._scripts.OnDragStart or handle._scripts.OnMouseDown
    local stopFn = handle._scripts.OnDragStop or handle._scripts.OnMouseUp
    startFn(handle)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    stopFn(handle)
end

-- Simulates Blizzard positioning a panel.
function L.blizzardPoint(frame, point, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end

-- State of a set of frames/regions that skins may touch, for apply-then-restore comparisons.
local function copy(v)
    if type(v) ~= "table" or v._mock then return v end
    local r = {}
    for k, x in pairs(v) do r[k] = copy(x) end
    return r
end
-- Include the observable input and mask state that the minimap and status areas must return.
-- Methods themselves are stable mock methods; the script table records only the scripts an area owns.
local FIELDS = { "_texCoord", "_texture", "_color", "_vertex", "_points", "_alpha", "_backdropColor",
    "_backdropBorder", "_text", "_textColor", "_font", "_w", "_h", "_shown", "_mouse", "_wheel",
    "_mask", "_scripts", "_statusColor" }
-- HookScript (hooksecurefunc-style) is allowed to leave a wrapper on a script name; the mock records
-- those names in f._hooks. Hooked names are left out of the _scripts comparison, because hooks are
-- installed once and stay inert; SetScript on a Blizzard frame is asserted with L.watchScripts instead.
local function scripts(f, extra)
    local list = copy(rawget(f, "_scripts")) or {}
    for name in pairs(rawget(f, "_hooks") or {}) do list[name] = nil end
    for name in pairs(extra or {}) do list[name] = nil end
    return list
end

-- Counts SetScript calls on a frame while it still works: { n = calls, names = { script names } }.
function L.watchScripts(frame)
    local c = { n = 0, names = {} }
    local original = frame.SetScript
    frame.SetScript = function(self, name, fn)
        c.n = c.n + 1
        c.names[#c.names + 1] = tostring(name)
        return original(self, name, fn)
    end
    return c
end

function L.snapshot(frames)
    local snap = {}
    for i, f in ipairs(frames) do
        local s = {}
        for _, k in ipairs(FIELDS) do s[k] = copy(rawget(f, k)) end
        s._scripts = scripts(f)
        s._hooked = {}
        for name in pairs(rawget(f, "_hooks") or {}) do s._hooked[name] = true end
        s._quietLabel = f._name or (f._kind .. "#" .. i)
        snap[f] = s
    end
    return snap
end
local function defaultTexCoord(v)
    if v == nil then return true end
    if type(v) == "table" and v[1] == 0 and v[2] == 1 and v[3] == 0 and v[4] == 1 then return true end
    return false
end

function L.diff(snap)
    local changed = {}
    for f, s in pairs(snap) do
        for _, k in ipairs(FIELDS) do
            local a, b = s[k], rawget(f, k)
            if k == "_scripts" then
                local now = rawget(f, "_hooks") or {}
                a = copy(s._scripts)
                for name in pairs(now) do a[name] = nil end
                b = scripts(f, s._hooked)
            end
            local function same(x, y)
                if type(x) ~= type(y) then return false end
                if type(x) ~= "table" or x == y then return x == y end
                for kk, v in pairs(x) do if not same(v, y[kk]) then return false end end
                for kk in pairs(y) do if x[kk] == nil then return false end end
                return true
            end
            local differs = not same(a, b)
            if differs and k == "_texCoord" and defaultTexCoord(a) and defaultTexCoord(b) then
                differs = false
            end
            if differs then changed[#changed + 1] = s._quietLabel .. "." .. k end
        end
    end
    table.sort(changed)
    return changed
end

return L
