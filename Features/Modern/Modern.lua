local _, ns = ...

-- Modernize: the area registry, apply / restore and event routing. An area is one file under
-- Areas/ registered through ns.Modern.Register; Theme, Skin and Movable are the shared tools.
--
--   ns.Modern.Register{ key, label, apply(skin), restore(skin), events, onEvent(skin, event, ...), addons }

local Modern = {}
ns.Modern = Modern

-- Private to the Modern files. Other features never read it.
local S = { areas = {}, byKey = {}, events = {}, frame = nil, signature = nil }
Modern.state = S

-- Settings keys of the modernize table that an area key must not shadow.
local RESERVED = { enabled = true, theme = true, opacity = true, xpGain = true }

local function Problem(spec)
    if type(spec) ~= "table" then return "the spec must be a table" end
    if type(spec.key) ~= "string" or spec.key == "" then return "key must be a non-empty string" end
    if RESERVED[spec.key] then return "key is reserved" end
    if S.byKey[spec.key] then return "key is already registered" end
    if type(spec.label) ~= "string" or spec.label == "" then return "label must be a non-empty string" end
    if type(spec.apply) ~= "function" then return "apply must be a function" end
    for _, name in ipairs({ "restore", "onEvent" }) do
        if spec[name] ~= nil and type(spec[name]) ~= "function" then return name .. " must be a function" end
    end
    for _, name in ipairs({ "events", "addons" }) do
        local list = spec[name]
        if list ~= nil then
            if type(list) ~= "table" then return name .. " must be a list of names" end
            for _, item in ipairs(list) do
                if type(item) ~= "string" then return name .. " must be a list of names" end
            end
        end
    end
end

local function OnEvent(_, event, ...)
    for _, area in ipairs(S.areas) do
        if area.applied and area.eventSet[event] and area.onEvent then
            ns.Profiler.Run("modern " .. area.key, area.onEvent, area.skin, event, ...)
        end
    end
end

-- An unknown event throws on this client, so each one is registered alone and once.
local function Listen(event)
    if S.events[event] then return end
    S.events[event] = true
    if not S.frame then
        S.frame = CreateFrame("Frame")
        S.frame:SetScript("OnEvent", OnEvent)
    end
    pcall(S.frame.RegisterEvent, S.frame, event)
end

function Modern.Register(spec)
    local err = Problem(spec)
    if err then
        ns.Report("modern area " .. (type(spec) == "table" and tostring(spec.key) or "spec"), err)
        return
    end
    local area = { key = spec.key, label = spec.label, apply = spec.apply, restore = spec.restore,
        onEvent = spec.onEvent, addons = spec.addons or {}, eventSet = {}, applied = false }
    for _, event in ipairs(spec.events or {}) do
        area.eventSet[event] = true
        Listen(event)
    end
    S.areas[#S.areas + 1] = area
    S.byKey[area.key] = area
end

-- Registration order: the Modern tab lists the areas in this order.
function Modern.Areas()
    local list = {}
    for i, area in ipairs(S.areas) do list[i] = { key = area.key, label = area.label } end
    return list
end

local function Restore(area)
    area.applied = false
    local skin = Modern.Skin(area.key)
    if area.restore then ns.Profiler.Run("modern " .. area.key, area.restore, skin) end
    -- Whatever the area did not undo itself goes back too.
    ns.Profiler.Run("modern " .. area.key, skin.Undo, skin)
end

-- A changed theme or background skins the applied areas again.
local function Signature()
    return ns.Settings.ModernTheme() .. "|" .. ns.Settings.ModernOpacity()
end

function Modern.Apply()
    local signature = Signature()
    if S.signature ~= signature then
        for i = #S.areas, 1, -1 do
            if S.areas[i].applied then Restore(S.areas[i]) end
        end
        S.signature = signature
    end
    for _, area in ipairs(S.areas) do
        local want = ns.Settings.ModernArea(area.key)
        if want and not area.applied then
            area.skin = Modern.Skin(area.key)
            area.applied = true
            ns.Profiler.Run("modern " .. area.key, area.apply, area.skin)
        elseif not want and area.applied then
            Restore(area)
        end
    end
end

function Modern.Restore()
    for i = #S.areas, 1, -1 do
        if S.areas[i].applied then Restore(S.areas[i]) end
    end
    S.signature = nil
end

-- A listed addon finished loading: its frames exist now, so the applied area skins them.
function Modern.AddonLoaded(name)
    for _, area in ipairs(S.areas) do
        if area.applied then
            for _, addon in ipairs(area.addons) do
                if addon == name then
                    ns.Profiler.Run("modern " .. area.key, area.apply, area.skin)
                    break
                end
            end
        end
    end
end
