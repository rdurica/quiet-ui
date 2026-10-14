local _, ns = ...

-- Feature registry. A feature registers one spec; QuietUI.lua walks the registry for
-- apply, restore and the per-frame phases, and the registry owns the event frame.
--
--   ns.Feature{ name, enabled, apply, restore, events, always, early, required, fade, frame, tick, rescan, hooks }
--   always: events also delivered while the addon is off (once booted).
--   early: events delivered before boot and while off (QuietUI's own boot events).
--   required: events whose failed RegisterEvent is reported once as "<name> events".

local Registry = { booted = false }
ns.Registry = Registry

local features = {}
local byName = {}
local handlers = {}  -- event -> { { feature =, fn = }, ... } in registration order
local frame

local FUNCTIONS = { "enabled", "apply", "restore", "fade", "frame", "tick", "rescan" }
local KNOWN = { name = true, events = true, always = true, hooks = true, required = true, early = true }
for _, key in ipairs(FUNCTIONS) do KNOWN[key] = true end

-- Returns an error text for a bad spec, or nil.
local function Problem(spec)
    if type(spec) ~= "table" then return "the spec must be a table" end
    if type(spec.name) ~= "string" or spec.name == "" then return "name must be a non-empty string" end
    if byName[spec.name] then return "name is already registered" end
    for key in pairs(spec) do
        if not KNOWN[key] then return "unknown field " .. tostring(key) end
    end
    for _, key in ipairs(FUNCTIONS) do
        if spec[key] ~= nil and type(spec[key]) ~= "function" then return key .. " must be a function" end
    end
    for _, key in ipairs({ "events", "hooks" }) do
        local map = spec[key]
        if map ~= nil then
            if type(map) ~= "table" then return key .. " must be a table" end
            for name, fn in pairs(map) do
                if type(name) ~= "string" or type(fn) ~= "function" then
                    return key .. " must map names to functions"
                end
            end
        end
    end
    for _, key in ipairs({ "always", "required", "early" }) do
        local list = spec[key]
        if list ~= nil then
            if type(list) ~= "table" then return key .. " must be a list of event names" end
            for _, event in ipairs(list) do
                if type(event) ~= "string" then return key .. " must be a list of event names" end
            end
        end
    end
end

local function Allowed(entry, event)
    local feature = entry.feature
    if feature.earlySet[event] then return true end
    if not Registry.booted then return false end
    if ns.DB().enabled then return true end
    return feature.alwaysSet[event] == true
end

local function OnEvent(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local entry = list[i]
        if Allowed(entry, event) and Registry.On(entry.feature) then
            -- One label per feature, so a failing feature reports once whatever event it was.
            ns.Profiler.Run(entry.feature.name, entry.fn, ...)
        end
    end
end

-- The one frame of the addon: events here, OnUpdate set by QuietUI.lua.
function Registry.Frame()
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    return frame
end

local function Listen(feature, event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        Registry.Frame()
        -- An unknown event throws on this client, so each one is registered alone.
        local ok, err = pcall(frame.RegisterEvent, frame, event)
        -- Only events a feature cannot work without are reported; the rest fail silently.
        if not ok and feature.requiredSet[event] then ns.Report(feature.name .. " events", err) end
    end
    list[#list + 1] = { feature = feature, fn = fn }
end

local function Hook(feature, global, fn)
    if type(_G[global]) ~= "function" then return end
    feature.labels[global] = feature.labels[global] or (feature.name .. "." .. global)
    local ok = pcall(hooksecurefunc, global, function(...)
        if not ns.DB().enabled then return end
        ns.Profiler.Run(feature.labels[global], fn, ...)
    end)
    if ok then feature.hooked[global] = true end
end

-- Hooks wait for a global that is not loaded yet; QuietUI calls this again when it boots.
function Registry.InstallHooks()
    for _, feature in ipairs(features) do
        for global, fn in pairs(feature.spec.hooks or {}) do
            if not feature.hooked[global] then Hook(feature, global, fn) end
        end
    end
end

function ns.Feature(spec)
    local err = Problem(spec)
    if err then
        ns.Report("feature " .. (type(spec) == "table" and type(spec.name) == "string" and spec.name or "spec"), err)
        return
    end
    local feature = { name = spec.name, spec = spec, alwaysSet = {}, earlySet = {}, requiredSet = {}, hooked = {}, labels = {} }
    -- Profiler labels built once; phases run per frame and per tick.
    for _, key in ipairs(FUNCTIONS) do feature.labels[key] = spec.name .. "." .. key end
    for _, event in ipairs(spec.always or {}) do feature.alwaysSet[event] = true end
    for _, event in ipairs(spec.early or {}) do feature.earlySet[event] = true end
    for _, event in ipairs(spec.required or {}) do feature.requiredSet[event] = true end
    features[#features + 1] = feature
    byName[spec.name] = feature
    -- Sorted so registration of events does not depend on pairs order.
    local names = {}
    for event in pairs(spec.events or {}) do names[#names + 1] = event end
    table.sort(names)
    for _, event in ipairs(names) do Listen(feature, event, spec.events[event]) end
    for global, fn in pairs(spec.hooks or {}) do Hook(feature, global, fn) end
end

function ns.Features()
    local names = {}
    for i, feature in ipairs(features) do names[i] = feature.name end
    return names
end

-- A feature without a gate is always on.
function Registry.On(feature)
    local gate = feature.spec.enabled
    if not gate then return true end
    local ok, on = pcall(gate)
    if not ok then
        ns.Report(feature.name .. ".enabled", on)
        return false
    end
    return on and true or false
end

function Registry.SetBooted(on)
    Registry.booted = on and true or false
end

-- Runs a phase for every feature that has it, in registration order.
function Registry.Phase(phase, ...)
    for i = 1, #features do
        local feature = features[i]
        local fn = feature.spec[phase]
        if fn and Registry.On(feature) then
            ns.Profiler.Run(feature.labels[phase] or (feature.name .. "." .. phase), fn, ...)
        end
    end
end

function Registry.Apply()
    Registry.Phase("apply")
end

-- Reverse order; a feature is restored even when its gate is off.
function Registry.Restore()
    for i = #features, 1, -1 do
        local feature = features[i]
        if feature.spec.restore then
            ns.Profiler.Run(feature.labels.restore, feature.spec.restore)
        end
    end
end
