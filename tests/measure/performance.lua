-- Measurements for the per-frame smooth update:  lua tests/measure/performance.lua --measure
-- Works from any cwd. Prints the call counts the assertions in tests/faders/player/smooth-updates.lua
-- hold to, once with Modernize off and once with Modernize on (every area applied; the numbers must
-- match, tests/modern/performance.lua asserts it). It asserts nothing itself.
if arg[1] ~= "--measure" then
    print("usage: lua tests/measure/performance.lua --measure")
    os.exit(1)
end
local print = print -- the mock replaces the global print
local script = arg[0] or "tests/measure/performance.lua"
local dir = script:match("^(.*)/[^/]*$") or "."
local libDir = dir .. "/../lib"
local p = io.popen("cd '" .. dir .. "/../..' && pwd")
local root = p:read("*l")
p:close()
local mockLib = assert(loadfile(libDir .. "/mock.lua"))()
local addon = assert(loadfile(libDir .. "/addon.lua"))()
addon.root = root

-- Retail-shaped frames for the Modern minimap, tooltip, aura and status areas.
local function modernWorld(mock, R)
    R.installAuraUtil()
    R.auraFrame(BuffFrame, { { "Buff" }, { "TempEnchant" } })
    R.auraFrame(DebuffFrame, { { "Debuff", "Magic" } })
    R.minimap()
    GameTooltip, GameTooltipStatusBar = R.tooltip("GameTooltip", true)
    ItemRefTooltip = R.tooltip("ItemRefTooltip")
    mock.xp, mock.rested = 0.25, 0.1
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1 end
    GetXPExhaustion = function() return mock.rested end
    C_Reputation = { GetWatchedFactionData = function()
        return { factionID = 72, currentReactionThreshold = 0, nextReactionThreshold = 1000, currentStanding = 500 }
    end }
end

local function measure(label, modern)
    local mock = mockLib.new()
    mock:install()
    local ns = addon.load()
    local S = assert(loadfile(libDir .. "/smooth.lua"))()
    S.dir = libDir
    local s = S.build({ ns = ns, mock = mock })
    local c = s.c
    if modern then
        local R = assert(loadfile(libDir .. "/modern-retail.lua"))()
        modernWorld(mock, R)
        local before = { children = mock.calls.GetChildren or 0, regions = mock.calls.GetRegions or 0 }
        QuietUICharDB.modernize = { enabled = true }
        ns.Modern.Apply()
        print(("%s Apply, all areas: GetChildren=%d GetRegions=%d frames=%d"):format(label,
            (mock.calls.GetChildren or 0) - before.children, (mock.calls.GetRegions or 0) - before.regions,
            #mock.frames))
    end
    s.tick()
    s.reset()
    local walks = { children = mock.calls.GetChildren or 0, regions = mock.calls.GetRegions or 0 }
    for _ = 1, 60 do s.tick() end
    print(("%s Idle 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d")
        :format(label, c.power, c.health, c.type, c.curves, s.writes(PlayerFrame)))
    print(("%s Idle 60 frames: curve edits=%d"):format(label, c.edits))
    print(("%s Idle 60 frames: threshold settings=%d player style=%d aura hover settings=%d grouping settings=%d")
        :format(label, c.threshold, c.style, c.aura, c.grouping))
    print(("%s Idle 60 frames: settled debuff checks=%d"):format(label, c.debuff))
    print(("%s Idle 60 frames: GetChildren=%d GetRegions=%d"):format(label,
        (mock.calls.GetChildren or 0) - walks.children, (mock.calls.GetRegions or 0) - walks.regions))
    local scripts = 0
    for _, f in ipairs(mock.frames) do if f._scripts.OnUpdate then scripts = scripts + 1 end end
    print(("%s Idle 60 frames: frames with an OnUpdate script=%d"):format(label, scripts))
    s.InCombat = true
    s.tick()
    s.reset()
    for _ = 1, 60 do s.tick() end
    print(("%s Combat 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d")
        :format(label, c.power, c.health, c.type, c.curves, s.writes(PlayerFrame)))
    s.InCombat = false
    s.reset()
    for _ = 1, 20 do s.tick() end
    print(("%s First fade, 20 frames: curves=%d"):format(label, c.curves))
    s.InCombat = true
    s.tick()
    s.InCombat = false
    s.reset()
    for _ = 1, 20 do s.tick() end
    print(("%s Repeated fade, 20 frames: curves=%d"):format(label, c.curves))
    s.HasTarget = true
    s.reset()
    s.tick()
    print(("%s Target visible: hover reads=%d"):format(label, c.hover))
    if modern then
        local start = mock.calls.GetChildren or 0
        for _ = 1, 100 do mock:fire("UNIT_AURA", "target") end
        print(("%s 100 UNIT_AURA for another unit: GetChildren=%d"):format(label, (mock.calls.GetChildren or 0) - start))
    end
    if #mock.printed > 0 then print(label .. " reported: " .. table.concat(mock.printed, "; ")) end
end

measure("[Modernize off]", false)
measure("[Modernize on] ", true)
