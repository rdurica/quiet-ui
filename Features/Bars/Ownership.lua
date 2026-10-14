local _, ns = ...

-- Bar ownership: which frames belong to which row, who parents whom, and the caches that
-- depend on it. Defines the Bars table and its private state; later Bars files share it.

local Bars = {}
ns.Bars = Bars

-- Private to the Bars files. Other features never read it.
local S = {
    ancestorCache = {},
    dirty = true,
    parentHooked = setmetatable({}, { __mode = "k" }),
    -- Frame ownership changes when the UI structure changes. A bar that parents another stays
    -- at alpha 1 or the child would fade with it.
    owner = {},
    -- Built with owner in Collect: hosts[bar] lists nested bars of another row, covered[bar]
    -- marks a bar whose outer frame of the same row already carries the alpha.
    hosts = {},
    covered = {},
    resolved = {},
    swingFound = {},
    buttonCache = {},
    deepCache = {},
    regionCache = {},
}
Bars.state = S

local owner, hosts, covered, resolved = S.owner, S.hosts, S.covered, S.resolved

function S.Parent(frame)
    if not ns.Usable(frame) or not frame.GetParent then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok then return parent end
end
local Parent = S.Parent

function S.WatchParent(frame)
    if not ns.Usable(frame) or S.parentHooked[frame] or type(frame.SetParent) ~= "function" then return end
    local ok = pcall(hooksecurefunc, frame, "SetParent", function()
        Bars.ForgetButtons()
    end)
    if ok then S.parentHooked[frame] = true end
end
local WatchParent = S.WatchParent

function S.IsAncestor(frame, ancestor)
    local chain = S.ancestorCache[frame]
    if chain then return chain[ancestor] or false end
    chain = {}
    S.ancestorCache[frame] = chain
    WatchParent(frame)
    local current = Parent(frame)
    local depth = 0
    while current and depth < 8 do
        chain[current] = true
        WatchParent(current)
        current = Parent(current)
        depth = depth + 1
    end
    return chain[ancestor] or false
end
local IsAncestor = S.IsAncestor

function S.UnderOther(frame, bar)
    for other in pairs(owner) do
        if other ~= bar and IsAncestor(frame, other) then
            return true
        end
    end
    return false
end

function S.HostsOther(bar)
    return hosts[bar] ~= nil
end

function Bars.ForgetButtons()
    S.dirty = true
    S.ancestorCache = {}
    ns.Wipe(hosts)
    ns.Wipe(covered)
    ns.World.TouchHud()
    for _, cache in ipairs({ S.buttonCache, S.deepCache, S.regionCache }) do
        for bar in pairs(cache) do
            cache[bar] = nil
        end
    end
end

-- GetNumChildren is enough to notice a new button. The full rebuild waits for that.
local childCounts = {}
local childPrimed = false
local childFallback = 0
local childArmed = false

local function ChildCount(bar)
    if type(bar.GetNumChildren) ~= "function" then return nil end
    local ok, count = pcall(bar.GetNumChildren, bar)
    if not ok or type(count) ~= "number" or ns.IsSecret(count) then return nil end
    return count
end

function Bars.ChildrenChanged()
    local missing = false
    local changed = false
    local seen = {}
    for _, row in ipairs(ns.BAR_ROWS) do
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if ns.Usable(bar) then
                seen[bar] = true
                local count = ChildCount(bar)
                if count == nil then
                    missing = true
                elseif childCounts[bar] ~= count then
                    if childPrimed then changed = true end
                    childCounts[bar] = count
                end
            end
        end
    end
    for bar in pairs(childCounts) do
        if not seen[bar] then
            childCounts[bar] = nil
            if childPrimed then changed = true end
        end
    end
    childPrimed = true
    if changed then return true end
    if not missing then return false end
    local now = type(GetTime) == "function" and GetTime() or 0
    if not childArmed then
        childArmed = true
        childFallback = now + 5
        return false
    end
    if now < childFallback then return false end
    childFallback = now + 5
    return true
end

function S.Collect()
    if not S.dirty then return end
    S.dirty = false
    ns.Wipe(owner)
    ns.Wipe(hosts)
    ns.Wipe(covered)
    for index, row in ipairs(ns.BAR_ROWS) do
        local entry = resolved[index]
        if not entry then
            entry = { frames = {} }
            resolved[index] = entry
        end
        entry.id = row.id
        local frames = entry.frames
        local count = 0
        local seen = {}
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if ns.Usable(bar) and not seen[bar] then
                WatchParent(bar)
                seen[bar] = true
                count = count + 1
                frames[count] = bar
            end
        end
        for extra = count + 1, #frames do
            frames[extra] = nil
        end
        for _, bar in ipairs(frames) do
            owner[bar] = row.id
        end
        if row.id == "swing" then
            for frame in pairs(S.swingFound) do
                if not seen[frame] then
                    count = count + 1
                    frames[count] = frame
                    owner[frame] = row.id
                end
            end
            for extra = count + 1, #frames do
                frames[extra] = nil
            end
        end
    end
    -- Ownership passes run here once per structure change, not every tick.
    for bar, id in pairs(owner) do
        for other, otherId in pairs(owner) do
            if other ~= bar and otherId ~= id and IsAncestor(other, bar) then
                local list = hosts[bar]
                if not list then
                    list = {}
                    hosts[bar] = list
                end
                list[#list + 1] = other
            end
        end
    end
    for bar, id in pairs(owner) do
        for other, otherId in pairs(owner) do
            if other ~= bar and otherId == id and not hosts[other] and IsAncestor(bar, other) then
                covered[bar] = true
                break
            end
        end
    end
end
