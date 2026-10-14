local _, ns = ...

-- Visibility migration: legacy per-bar pins become group modes.

-- Move legacy per-bar pins to group modes, splitting mixed groups to keep their visibility.
function ns.Settings.MigrateVisibility(settings)
    if type(settings) ~= "table" then return end
    local visible = settings.visible
    if type(visible) ~= "table" or (visible.bars == nil and visible.swing == nil) then return end
    local buckets, used = {}, {}
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = type(settings.groups) == "table" and settings.groups[row.id]
        if type(n) ~= "number" or n ~= n or n < 1 or n > #ns.BAR_ROWS then n = row.group end
        n = math.floor(n)
        used[n] = true
        buckets[n] = buckets[n] or { pinned = {}, normal = {} }
        local pinned
        if row.id == "swing" then pinned = visible.swing else pinned = visible.bars end
        local list = pinned and buckets[n].pinned or buckets[n].normal
        list[#list + 1] = row.id
    end
    settings.groupVisibility = type(settings.groupVisibility) == "table" and settings.groupVisibility or {}
    for n = 1, #ns.BAR_ROWS do
        local bucket = buckets[n]
        if bucket and #bucket.pinned > 0 then
            local pinGroup = n
            if #bucket.normal > 0 then
                for candidate = 1, #ns.BAR_ROWS do
                    if not used[candidate] then pinGroup = candidate; used[candidate] = true; break end
                end
                settings.groups = type(settings.groups) == "table" and settings.groups or {}
                for _, id in ipairs(bucket.pinned) do settings.groups[id] = pinGroup end
            end
            settings.groupVisibility[pinGroup] = "always"
        end
    end
    visible.bars = nil
    visible.swing = nil
end

-- Migration runs once per visible table; a replaced table migrates again.
local migrated = setmetatable({}, { __mode = "k" })

function ns.Settings.MigrateOnce(settings)
    if type(settings) ~= "table" then return end
    local visible = settings.visible
    if type(visible) ~= "table" or migrated[visible] then return end
    migrated[visible] = true
    ns.Settings.MigrateVisibility(settings)
end
