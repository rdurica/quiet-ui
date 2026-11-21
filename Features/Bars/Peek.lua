local _, ns = ...
local Bars = ns.Bars
local S = Bars.state

-- Gamepad peek: while a trigger or shoulder button is held, the faded gamepad bar shows the zone that
-- button drives. Alpha only. The client sends no gamepad button events, so the pad is polled.

local POLL = 0.05
local GAMEPAD = "GamepadMainActionBarFrame"
local PAGE = "GamepadMainActionBarFramePageUnit"

-- Page children by zone. The stance bar hangs under the top anchor but is drawn in the right zone.
local ZONE_OF = {
    LeftCenteredAnchor = "L",
    LeftClassAction = "L",
    RightCenteredAnchor = "R",
    RightClassAction = "R",
    BottomCenteredAnchor = "C",
    PageTracker = "C",
}

S.peekKey = ""
S.peekDirty = false
local pollAcc = 0
local held = {}
local bindingOf = {}

local function Binding(pad, index)
    local name = bindingOf[index]
    if name == nil then
        local ok, value = pcall(pad.ButtonIndexToBinding, index)
        name = ok and type(value) == "string" and value or false
        bindingOf[index] = name
    end
    return name
end

-- Held zones as letters: L (LT), R (RT), C (both triggers, or a shoulder button). "" when none.
local function ReadPad()
    local pad = _G.C_GamePad
    if type(pad) ~= "table" or type(pad.GetActiveDeviceID) ~= "function"
        or type(pad.GetDeviceMappedState) ~= "function" or type(pad.ButtonIndexToBinding) ~= "function" then
        return ""
    end
    local ok, id = pcall(pad.GetActiveDeviceID)
    if not ok or id == nil or ns.IsSecret(id) then return "" end
    local okState, state = pcall(pad.GetDeviceMappedState, id)
    if not okState or type(state) ~= "table" or type(state.buttons) ~= "table" then return "" end
    local lt, rt, shoulder = false, false, false
    for i, down in ipairs(state.buttons) do
        if not ns.IsSecret(down) and down == true then
            local name = Binding(pad, i - 1)
            if name == "PADLTRIGGER" then
                lt = true
            elseif name == "PADRTRIGGER" then
                rt = true
            elseif name == "PADLSHOULDER" or name == "PADRSHOULDER" then
                shoulder = true
            end
        end
    end
    local key = ""
    if lt and not rt then key = "L" end
    if rt and not lt then key = "R" end
    if (lt and rt) or shoulder then key = key .. "C" end
    return key
end

function Bars.PollPad(elapsed)
    pollAcc = pollAcc + (elapsed or 0)
    if pollAcc < POLL then return end
    pollAcc = 0
    local bar = _G[GAMEPAD]
    if not (ns.Usable(bar) and bar:IsShown()) then
        S.peekKey = ""
        if next(held) then Bars.ReleasePeek() end
        return
    end
    if ns.World.ShowAll() then
        S.peekKey = ""
        return
    end
    local key = ReadPad()
    if key == S.peekKey then return end
    S.peekKey = key
    S.peekDirty = true
    ns.World.TouchHud()
end

function Bars.Peeking()
    return S.peekKey ~= ""
end

local function EachZoneFrame(fn)
    for suffix, zone in pairs(ZONE_OF) do
        local frame = _G[PAGE .. suffix]
        if ns.Usable(frame) then fn(frame, zone) end
    end
    local top = _G[PAGE .. "TopCenteredAnchor"]
    if not (ns.Usable(top) and top.GetChildren) then return end
    for _, child in ipairs({ top:GetChildren() }) do
        if ns.Usable(child) then
            local name = ns.FrameName(child) or ""
            fn(child, name:find("StanceBar", 1, true) and "R" or "C")
        end
    end
end

function Bars.ReleasePeek()
    for frame in pairs(held) do
        ns.ReleaseAlpha(frame, true)
        held[frame] = nil
    end
end

function Bars.ResetPeek()
    S.peekKey = ""
    S.peekDirty = false
    pollAcc = 0
    Bars.ReleasePeek()
end

-- show is the bar's usual rule. Only a bar that would fade shows a single zone; the other zones keep
-- alpha 0 until the bar has faded out, so they do not flash while it goes.
function Bars.ApplyPeek(bar, show, alpha)
    local key = S.peekKey
    if show or key == "" then
        local current = type(alpha) == "number" and alpha or (bar._quietAlpha or 0)
        if next(held) and (show or current <= 0) then Bars.ReleasePeek() end
        return
    end
    EachZoneFrame(function(frame, zone)
        held[frame] = true
        ns.HoldAlpha(frame, key:find(zone, 1, true) and 1 or 0)
    end)
end
