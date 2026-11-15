local _, ns = ...

-- /quiet dump: one plain-text report of the setup, client, errors and state for a bug report.
-- Reads state only; it never changes alpha, settings or frames. Each section is built under pcall.

local Dump = {}
ns.Dump = Dump

local REPO_URL = "https://github.com/rdurica/quiet-ui/issues/new"
local PASTE = "Paste the /quiet dump report below, then describe what you did and what you expected."
local MODULES = { "fading", "modernize", "chat", "helpers", "layout" }
local FRAMES = { "MainActionBar", "PlayerFrame", "PetFrame", "TargetFrame", "Minimap", "ChatFrame1",
    "PersonalResourceDisplayFrame", "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
    "BuffBarCooldownViewer", "GamepadMainActionBarFrame" }
local RESERVED = {}
for word in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while")
    :gmatch("%a+") do RESERVED[word] = true end

-- Serialize ------------------------------------------------------------------------------------

local function KeyRank(key)
    local kind = type(key)
    if kind == "number" then return 1 end
    if kind == "string" then return 2 end
    return 3
end

local function KeyLess(a, b)
    local ra, rb = KeyRank(a), KeyRank(b)
    if ra ~= rb then return ra < rb end
    if ra == 3 then return tostring(a) < tostring(b) end
    return a < b
end

local function Number(value)
    if value ~= value then return "(0/0)" end
    if value == math.huge then return "(1e999)" end
    if value == -math.huge then return "(-1e999)" end
    if value == math.floor(value) and math.abs(value) < 1e15 then return string.format("%d", value) end
    local text = string.format("%.14g", value)
    if tonumber(text) ~= value then text = string.format("%.17g", value) end
    return text
end

local function KeyText(key)
    if type(key) == "number" then return "[" .. Number(key) .. "]" end
    if type(key) == "string" then
        if key:match("^[%a_][%w_]*$") and not RESERVED[key] then return key end
        return "[" .. string.format("%q", key) .. "]"
    end
    return "[<" .. type(key) .. ">]"
end

local function Write(value, indent, active)
    if ns.IsSecret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" then return Number(value) end
    if kind == "boolean" then return tostring(value) end
    if kind == "function" then return "<function>" end
    if kind == "userdata" then return "<userdata>" end
    if kind ~= "table" then return "<" .. kind .. ">" end
    if active[value] then return "<cycle>" end
    active[value] = true
    local keys, count = {}, 0
    for key in pairs(value) do
        if not ns.IsSecret(key) then keys[#keys + 1] = key end
        count = count + 1
    end
    if #keys == 0 then
        active[value] = nil
        return "{}"
    end
    table.sort(keys, KeyLess)
    local inner = indent .. "  "
    local parts = {}
    local sequence = #value
    for _, key in ipairs(keys) do
        local text = Write(value[key], inner, active)
        if type(key) == "number" and key >= 1 and key <= sequence and key == math.floor(key) then
            parts[#parts + 1] = inner .. text
        else
            parts[#parts + 1] = inner .. KeyText(key) .. " = " .. text
        end
    end
    active[value] = nil
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- A Lua literal for the value; placeholders for secrets, functions, userdata and cycles.
function Dump.Serialize(value)
    return Write(value, "", {})
end

-- QuietUI's own version from the toc; "?" when the client has no metadata call.
function Dump.Version()
    local get = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(get) ~= "function" then return "?" end
    local ok, value = pcall(get, "QuietUI", "Version")
    if ok and type(value) == "string" then return value end
    return "?"
end

-- Small readers --------------------------------------------------------------------------------

-- Any value as report text; a secret is never opened.
local function Show(value)
    if ns.IsSecret(value) then return "<secret>" end
    if value == nil then return "?" end
    if type(value) == "number" and value ~= math.floor(value) then return string.format("%.2f", value) end
    return tostring(value)
end

local function OnOff(value)
    if ns.IsSecret(value) then return "<secret>" end
    return value and "on" or "off"
end

local function YesNo(value)
    if ns.IsSecret(value) then return "<secret>" end
    return value and "yes" or "no"
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function ClientInfo()
    local version, build, date_, toc = Call(GetBuildInfo)
    return Show(version), Show(build), Show(date_), Show(toc)
end

local function Preset()
    local preset = ns.Settings.ActivePreset and ns.Settings.ActivePreset()
    if type(preset) == "table" and preset.name then return tostring(preset.name) end
    return "<no preset>"
end

local function InterfaceMode()
    local pad = type(C_GamePad) == "table" and Call(C_GamePad.IsEnabled)
    if pad == nil then pad = Call(GetCVar, "GamePadEnable") == "1" end
    return pad and "gamepad" or "mouse and keyboard"
end

local function ModuleList()
    local parts = {}
    for _, name in ipairs(MODULES) do parts[#parts + 1] = name .. " " .. OnOff(ns.Settings.Module(name)) end
    return parts
end

-- Sections -------------------------------------------------------------------------------------

local function Header()
    local version, build, date_, toc = ClientInfo()
    local lines = {
        "QuietUI: " .. Dump.Version(),
        "Client: " .. version .. " (build " .. build .. ", " .. date_ .. "), interface " .. toc,
        "Locale: " .. Show(Call(GetLocale)),
        "Time: " .. Show(Call(date, "%Y-%m-%d %H:%M:%S")),
    }
    local class = Call(UnitClass, "player")
    local race = Call(UnitRace, "player")
    lines[#lines + 1] = "Character: " .. Show(class) .. ", " .. Show(race) .. ", level " .. Show(Call(UnitLevel, "player"))
    lines[#lines + 1] = "Enabled: " .. OnOff(ns.DB().enabled)
    lines[#lines + 1] = "Preset: " .. Preset()
    lines[#lines + 1] = "Interface mode: " .. InterfaceMode()
    lines[#lines + 1] = "Modules:"
    for _, text in ipairs(ModuleList()) do lines[#lines + 1] = "  " .. text:gsub(" ", ": ", 1) end
    return table.concat(lines, "\n")
end

local function Errors()
    local list = ns.DB().errors
    if type(list) ~= "table" or #list == 0 then return "none" end
    local lines = {}
    for _, entry in ipairs(list) do
        if type(entry) == "table" then
            lines[#lines + 1] = string.format("%s x%s, %s, QuietUI %s", Show(entry.name), Show(entry.count),
                Show(entry.time), Show(entry.version))
            lines[#lines + 1] = "  " .. Show(entry.message):gsub("\n", "\n  ")
            local stack = Show(entry.stack)
            if stack ~= "" and stack ~= "?" then lines[#lines + 1] = "  " .. stack:gsub("\n", "\n  ") end
        end
    end
    return table.concat(lines, "\n")
end

-- A block of State lines; a failing source becomes one <error: ...> line.
local function Guard(fn)
    local ok, text = pcall(fn)
    if ok then return text end
    return "<error: " .. tostring(text) .. ">"
end

local function Features()
    local lines = { "Features:" }
    for _, name in ipairs(ns.Features()) do
        lines[#lines + 1] = "  " .. name .. ": " .. OnOff(ns.Registry.IsOn(name))
    end
    return table.concat(lines, "\n")
end

local function Areas()
    local lines = { "Modern areas:" }
    for _, area in ipairs(ns.Modern.Areas()) do
        lines[#lines + 1] = "  " .. area.key .. " (" .. tostring(area.label) .. "): " .. OnOff(ns.Settings.ModernArea(area.key))
    end
    return table.concat(lines, "\n")
end

local function World()
    local W = ns.World
    return table.concat({
        "World: combat " .. YesNo(W.InCombat()), "group " .. YesNo(W.InGroup()),
        "forced instance " .. YesNo(W.InForcedInstance()), "vehicle " .. YesNo(W.InVehicle()),
        "edit mode " .. YesNo(W.InEditMode()), "target " .. YesNo(W.HasTarget()),
    }, ", ")
end

local function Screen()
    local scale = ns.Usable(UIParent) and Call(UIParent.GetEffectiveScale, UIParent)
    return "UI scale " .. Show(scale or nil) .. ", screen " .. Show(Call(GetScreenWidth)) .. "x" .. Show(Call(GetScreenHeight))
end

local function FrameLine(name)
    local frame = _G[name]
    if frame == nil then return "  " .. name .. ": missing" end
    if not ns.Usable(frame) then return "  " .. name .. ": skipped (forbidden)" end
    return "  " .. name .. ": shown " .. YesNo(Call(frame.IsShown, frame)) .. ", alpha " .. Show(Call(frame.GetAlpha, frame))
end

local function Frames()
    local lines = { "Frames:" }
    for _, name in ipairs(FRAMES) do lines[#lines + 1] = Guard(function() return FrameLine(name) end) end
    return table.concat(lines, "\n")
end

local function State()
    return table.concat({
        Guard(Features), Guard(Areas),
        Guard(function() return "Layout: " .. Show(ns.Layout.Status()) end),
        Guard(World), Guard(Screen), Frames(),
    }, "\n")
end

local function LastProfile()
    local saved = ns.DB().lastProfile
    if type(saved) ~= "table" or #saved == 0 then return nil end
    local lines = {}
    for _, line in ipairs(saved) do lines[#lines + 1] = Show(line) end
    return table.concat(lines, "\n")
end

local function Plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|", "||"))
end

local function AddonList()
    local C = type(C_AddOns) == "table" and C_AddOns or {}
    local count = Call(C.GetNumAddOns or GetNumAddOns)
    local info = C.GetAddOnInfo or GetAddOnInfo
    if type(count) ~= "number" or type(info) ~= "function" then return "unavailable" end
    local meta = C.GetAddOnMetadata or GetAddOnMetadata
    local state = C.GetAddOnEnableState or GetAddOnEnableState
    local lines = {}
    for i = 1, count do
        local name, title, _, loadable = Call(info, i)
        if type(name) == "string" and name ~= "QuietUI" then
            local enabled = Call(state, nil, name)
            if enabled == nil then enabled = Call(state, name) end
            if enabled == nil then enabled = loadable and 2 or 0 end
            if type(enabled) == "boolean" then enabled = enabled and 2 or 0 end
            if enabled > 0 then
                lines[#lines + 1] = Plain(title or name) .. " " .. Show(Call(meta, name, "Version"))
            end
        end
    end
    if #lines == 0 then return "none" end
    return table.concat(lines, "\n")
end

local function Settings()
    local db = {}
    for key, value in pairs(ns.DB()) do
        if key ~= "lastDump" and key ~= "errors" then db[key] = value end
    end
    local char = type(QuietUICharDB) == "table" and QuietUICharDB or {}
    return "QuietUICharDB = " .. Dump.Serialize(char) .. "\nQuietUIDB = " .. Dump.Serialize(db)
end

-- Report ---------------------------------------------------------------------------------------

-- Builds the report, keeps it in QuietUIDB.lastDump and returns it.
function Dump.Build()
    local sections = {
        { "Header", Header }, { "Errors", Errors }, { "State", State },
        { "Last profile", LastProfile, optional = true }, { "Addons", AddonList }, { "Settings", Settings },
    }
    local parts = {}
    for _, section in ipairs(sections) do
        local ok, body = pcall(section[2])
        if not ok then
            body = "<error: " .. tostring(body) .. ">"
        end
        if body ~= nil then
            parts[#parts + 1] = "== " .. section[1] .. " ==\n" .. body .. "\n"
        end
    end
    local text = table.concat(parts, "\n")
    ns.DB().lastDump = text
    return text
end

local function Encode(text)
    return (text:gsub("[^A-Za-z0-9%-_%.~]", function(char) return string.format("%%%02X", char:byte()) end))
end

-- The link to a new GitHub issue with a short summary; the player pastes the report.
function Dump.IssueURL()
    local version, build = ClientInfo()
    local function try(fn, fallback)
        local ok, text = pcall(fn)
        return ok and text or fallback
    end
    local modules = try(function() return table.concat(ModuleList(), ", ") end, "?")
    local body = table.concat({
        "QuietUI: " .. Dump.Version(),
        "Client: " .. version .. " (build " .. build .. ")",
        "Interface mode: " .. InterfaceMode(),
        "Preset: " .. try(Preset, "?"),
        "Modules: " .. modules,
        "",
        PASTE,
    }, "\n")
    return REPO_URL .. "?title=" .. Encode("Bug: ") .. "&body=" .. Encode(body)
end
