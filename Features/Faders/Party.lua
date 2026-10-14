local _, ns = ...
local Faders = ns.Faders

local PARTY_NAMES = {
    "CompactPartyFrameContainer",
    "CompactRaidFrameContainer",
    "PartyFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
}

local state = Faders.state
local partyFrames = {}
local partyAlphaBlocks = {}
local managedParty = {}

-- Selection highlights and ready-check indicators can ignore container alpha.
local function CollectPartyAlpha(frame, root, found, depth)
    if depth > 8 or not ns.Usable(frame) then return end
    if type(frame.SetAlpha) == "function" then
        local ignoring = false
        if type(frame.IsIgnoringParentAlpha) == "function" then
            local ok, value = pcall(frame.IsIgnoringParentAlpha, frame)
            ignoring = ok and not ns.IsSecret(value) and value == true
        end
        if frame == root or ignoring then found[frame] = root end
    end
    local highlight = frame.selectionHighlight
    if ns.Usable(highlight) and type(highlight.SetAlpha) == "function"
        and type(highlight.IsIgnoringParentAlpha) ~= "function" then
        found[highlight] = root
    end
    for _, method in ipairs({ "GetRegions", "GetChildren" }) do
        if type(frame[method]) == "function" then
            local ok, children = pcall(function() return { frame[method](frame) } end)
            if ok then
                for _, child in ipairs(children) do CollectPartyAlpha(child, root, found, depth + 1) end
            end
        end
    end
end

-- Per root: the frame and its child + region count. A count that cannot be
-- read is a change, so the full scan stays the fallback.
local partySigFrames, partySigCounts = {}, {}

local function ReadCount(frame, method)
    if type(frame[method]) ~= "function" then return nil end
    local ok, value = pcall(frame[method], frame)
    if ok and type(value) == "number" and not ns.IsSecret(value) then return value end
end

local function PartyCount(frame)
    if not ns.Usable(frame) then return -1 end
    local kids, regions = ReadCount(frame, "GetNumChildren"), ReadCount(frame, "GetNumRegions")
    if not kids or not regions then return nil end
    return kids + regions
end

-- Reads the signature and remembers it; true when it moved since the last read.
Faders.PartyChanged = function()
    local changed = false
    for i = 1, #PARTY_NAMES do
        local frame = _G[PARTY_NAMES[i]]
        local count = PartyCount(frame)
        if count == nil or partySigFrames[i] ~= frame or partySigCounts[i] ~= count then
            changed = true
        end
        partySigFrames[i], partySigCounts[i] = frame, count
    end
    return changed
end

Faders.FindParty = function()
    -- Record the signature this scan saw, so the next tick compares against it.
    Faders.PartyChanged()
    local candidates = {}
    Faders.FindNamed(candidates, PARTY_NAMES)
    local roots = {}
    for _, frame in ipairs(candidates) do
        local nested = false
        for _, other in ipairs(candidates) do
            if frame ~= other and Faders.Under(frame, other) then nested = true; break end
        end
        if not nested then roots[frame] = true end
    end
    local alphaFrames = {}
    for frame in pairs(roots) do CollectPartyAlpha(frame, frame, alphaFrames, 0) end
    for frame in pairs(managedParty) do
        if not alphaFrames[frame] then
            ns.ReleaseAlpha(frame, true)
            managedParty[frame] = nil
        end
    end
    partyAlphaBlocks = {}
    for frame, root in pairs(alphaFrames) do
        local block = partyAlphaBlocks[root]
        if not block then block = {}; partyAlphaBlocks[root] = block end
        block[#block + 1] = frame
    end
    for i = #partyFrames, 1, -1 do partyFrames[i] = nil end
    for _, frame in ipairs(candidates) do
        if roots[frame] then
            partyFrames[#partyFrames + 1] = frame
            roots[frame] = nil
        end
    end
end

function Faders.UpdateParty(elapsed)
    local active = ns.DB().enabled and ns.Settings.AutoHideParty and ns.Settings.AutoHideParty() or false
    if not active then
        -- Roster events stop while off; the next FindFaders scans in full.
        state.partyActive = false
        Faders.ParkHover("party")
        for frame in pairs(managedParty) do
            ns.ReleaseAlpha(frame, true)
            managedParty[frame] = nil
        end
        return
    end
    if not ns.World.InGroup() and not ns.World.InCombat() and not ns.World.InForcedInstance()
        and not ns.World.InEditMode() and not ns.Glancing() then
        Faders.ParkHover("party")
        return
    end
    local hovered = Faders.HoverFrames("party", partyFrames, true)
    local show = ns.World.InCombat() or ns.World.InForcedInstance() or ns.World.InEditMode() or ns.Glancing() or hovered
    local target = show and 1 or 0
    for root, block in pairs(partyAlphaBlocks) do
        if ns.Usable(root) and root:IsShown() then
            for _, frame in ipairs(block) do
                local settled = managedParty[frame] and frame._quietSecret == nil and frame._quietAlpha == target
                if not settled and (frame == root or ns.Usable(frame)) then
                    ns.EaseAlpha(frame, show, elapsed)
                    managedParty[frame] = true
                end
            end
        end
    end
end

-- A roster change can swap members without changing the container counts.
function Faders.ScanParty()
    if ns.Settings.AutoHideParty and ns.Settings.AutoHideParty() then
        Faders.FindParty()
        state.partyActive = true
    end
end
