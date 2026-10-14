local _, ns = ...

-- Hover follows the frame under the cursor, not the pixel. The same chain
-- means the bars do not need another walk. IsMouseOver is the fallback when
-- this client has no focus API.
local focusFallback = false
local focusReady = false
local focusFresh = false
local focusHit = {}
local hoverFrames = setmetatable({}, { __mode = "k" })
local nextHit = {}
local focusChain = {}
local focusCount = 0
local nextChain = {}
local nextCount = 0

local function ReadFoci()
    if type(GetMouseFoci) == "function" then
        local ok, result = pcall(GetMouseFoci)
        if not ok then return nil, false end
        if type(result) == "table" then return result, true end
        return nil, true
    elseif type(GetMouseFocus) == "function" then
        local ok, result = pcall(GetMouseFocus)
        if not ok then return nil, false end
        if result then return { result }, true end
        return nil, true
    end
    focusFallback = true
    return nil, false
end

local function WalkFoci(foci)
    local n = 0
    if foci then
        for i = 1, #foci do
            local frame = foci[i]
            local depth = 0
            while ns.Usable(frame) and depth < 12 do
                n = n + 1
                nextChain[n] = frame
                if type(frame.GetParent) ~= "function" then break end
                local ok, parent = pcall(frame.GetParent, frame)
                if not ok then break end
                frame = parent
                depth = depth + 1
            end
        end
    end
    for i = n + 1, nextCount do
        nextChain[i] = nil
    end
    nextCount = n
    return n
end

local function CommitChain(n)
    for key in pairs(focusHit) do
        focusHit[key] = nil
    end
    for i = 1, n do
        local frame = nextChain[i]
        focusHit[frame] = true
        focusChain[i] = frame
    end
    for i = n + 1, focusCount do
        focusChain[i] = nil
    end
    focusCount = n
    focusReady = true
    focusFresh = true
end

local function SampleFocus()
    if focusFallback then return nil end
    local foci, ok = ReadFoci()
    if focusFallback or not ok then
        focusReady = false
        return nil
    end
    return WalkFoci(foci)
end

local function SameChain(n)
    if n ~= focusCount then return false end
    for i = 1, n do
        if nextChain[i] ~= focusChain[i] then return false end
    end
    return true
end

-- True when a tracked hover changes. Other windows still refresh the focus chain.
-- Nil when this client has no focus API.
-- Zero is a real sample: nothing is under the cursor.
function ns.FocusChanged()
    local n = SampleFocus()
    if n == nil then return nil end
    if SameChain(n) then
        focusReady = true
        return false
    end
    for key in pairs(nextHit) do nextHit[key] = nil end
    for i = 1, n do nextHit[nextChain[i]] = true end
    local changed = not focusReady
    for frame in pairs(hoverFrames) do
        if (focusHit[frame] or false) ~= (nextHit[frame] or false) then
            changed = true
            break
        end
    end
    CommitChain(n)
    return changed
end

function ns.RefreshMouse()
    if focusFresh then
        focusFresh = false
        return
    end
    local n = SampleFocus()
    if n == nil then return end
    CommitChain(n)
    focusFresh = false
end

function ns.Hit(frame)
    if frame then hoverFrames[frame] = true end
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if focusFallback or not focusReady then
        return frame.IsMouseOver and frame:IsMouseOver() and true or false
    end
    return focusHit[frame] and true or false
end
