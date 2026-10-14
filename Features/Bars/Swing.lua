local _, ns = ...
local Bars = ns.Bars
local S = Bars.state

-- The swing timer is found by scanning, not by a fixed global.

local swingFound = S.swingFound
local swingFullAt = 0


-- Named frames match on that name. GetDebugName is only for frames without one.
local function LooksLikeSwing(frame)
    if not ns.Usable(frame) or not frame.SetAlpha then return false end
    local name = ns.FrameName(frame)
    if name then return name:find("Swing") ~= nil end
    if type(frame.GetDebugName) ~= "function" then return false end
    local ok, debugName = pcall(frame.GetDebugName, frame)
    return ok and type(debugName) == "string" and debugName:find("Swing") ~= nil
end

-- The swing timer is not one fixed global. Main hand and off hand are separate
-- frames. Named ones match on the name; anonymous ones use the debug name.
local function WalkSwing(root, depth)
    if depth > 1 or not ns.Usable(root) or type(root.GetChildren) ~= "function" then return end
    local ok, children = pcall(function()
        return { root:GetChildren() }
    end)
    if not ok or type(children) ~= "table" then return end
    for _, child in ipairs(children) do
        if LooksLikeSwing(child) then
            swingFound[child] = true
        end
        local name = ns.FrameName(child)
        if name == "PlayerFrame" or name == "MainActionBar" or name == "MainMenuBar"
            or (name and name:find("Swing")) then
            WalkSwing(child, depth + 1)
        end
    end
end

-- No timer found is settled too; walking UIParent every second only makes garbage.
local function SwingReady()
    for frame in pairs(swingFound) do
        if not ns.Usable(frame) then return false end
    end
    return true
end

-- A full UIParent walk waits until a found timer disappears or 10s pass.
function Bars.ScanSwing()
    local now = type(GetTime) == "function" and GetTime() or 0
    if SwingReady() and now < swingFullAt then return end
    swingFullAt = now + 10
    for frame in pairs(swingFound) do
        swingFound[frame] = nil
    end
    if UIParent then
        WalkSwing(UIParent, 0)
    end
end
