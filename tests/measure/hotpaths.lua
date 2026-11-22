-- Empirical hot-path benchmark:  lua tests/measure/hotpaths.lua --measure
-- Measures wall-clock time (ms), Lua GC allocations (KB), and mock API call counts across
-- four representative runtime workloads (excluding fixture setup):
--   1. Idle scheduler loop (6,000 OnUpdate frames with Modernize on)
--   2. Skin:Border + Skin:Panel repeat repaints (10,000 calls)
--   3. Modernize UNIT_AURA / UpdateAuraButtons raid burst (500 cycles, 30 buffs + 5 debuffs)
--   4. Modernize unit events burst (500 cycles, Player/Pet/Target/ToT/Focus/Boss1-5/Party1-4 + 20 raid frames)
if arg[1] ~= "--measure" then
    print("usage: lua tests/measure/hotpaths.lua --measure")
    os.exit(1)
end

local print = print
local script = arg[0] or "tests/measure/hotpaths.lua"
local dir = script:match("^(.*)/[^/]*$") or "."
local libDir = dir .. "/../lib"
local p = io.popen("cd '" .. dir .. "/../..' && pwd")
local root = p:read("*l")
p:close()

local mockLib = assert(loadfile(libDir .. "/mock.lua"))()
local addon = assert(loadfile(libDir .. "/addon.lua"))()
addon.root = root

local function measureLoop(name, setupFn)
    local runLoop, reportMetrics = setupFn()
    collectgarbage("collect")
    collectgarbage("stop")
    local mem0 = collectgarbage("count")
    local t0 = os.clock()
    runLoop()
    local elapsedMs = (os.clock() - t0) * 1000
    local mem1 = collectgarbage("count")
    collectgarbage("restart")
    collectgarbage("collect")
    local allocKB = math.max(0, mem1 - mem0)
    local metrics = reportMetrics and reportMetrics() or {}
    local extra = #metrics > 0 and (" | " .. table.concat(metrics, " ")) or ""
    print(("%-34s time=%7.2f ms  alloc=%8.1f KB%s"):format(name, elapsedMs, allocKB, extra))
end

local function newEnv()
    local mock = mockLib.new()
    mock:install()
    local ns = addon.load()
    return mock, ns
end

local function installModernWorld(mock, R)
    R.installAuraUtil()
    local buffs = {}
    for i = 1, 30 do buffs[i] = { "Buff" } end
    local debuffs = {}
    for i = 1, 5 do debuffs[i] = { "Debuff", "Magic" } end
    R.auraFrame(BuffFrame, buffs)
    R.auraFrame(DebuffFrame, debuffs)
    R.minimap()
    GameTooltip, GameTooltipStatusBar = R.tooltip("GameTooltip", true)
    ItemRefTooltip = R.tooltip("ItemRefTooltip")
    mock.xp, mock.rested = 0.25, 0.1
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1 end
    GetXPExhaustion = function() return mock.rested end
    C_Reputation = {
        GetWatchedFactionData = function()
            return { factionID = 72, currentReactionThreshold = 0, nextReactionThreshold = 1000, currentStanding = 500 }
        end,
    }
end

-- 1. Idle scheduler loop (6,000 OnUpdate frames)
measureLoop("1. Idle scheduler (6000 frames)", function()
    local mock, ns = newEnv()
    local R = assert(loadfile(libDir .. "/modern-retail.lua"))()
    local P = assert(loadfile(libDir .. "/player.lua"))()
    P.installPercents(mock, function() return 1 end)
    installModernWorld(mock, R)
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    mock:fire("PLAYER_LOGIN")
    mock:fire("PLAYER_ENTERING_WORLD")
    local f = mock:eventFrame("PLAYER_LOGIN")
    local onUpdate = f._scripts.OnUpdate
    for _ = 1, 10 do
        mock.now = mock.now + (1 / 60)
        onUpdate(f, 1 / 60)
    end
    local unitPowerTypeCalls = 0
    local origPowerType = UnitPowerType
    UnitPowerType = function(...)
        unitPowerTypeCalls = unitPowerTypeCalls + 1
        return origPowerType(...)
    end
    mock.printed = {}
    return function()
        for _ = 1, 6000 do
            mock.now = mock.now + (1 / 60)
            onUpdate(f, 1 / 60)
        end
    end, function()
        return {
            ("UnitPowerType=%d"):format(unitPowerTypeCalls),
            ("errors=%d"):format(#mock.printed),
        }
    end
end)

-- 2. Skin:Border + Skin:Panel repeat repaints (10,000 calls)
measureLoop("2. Skin Border+Panel (10k calls)", function()
    local mock, ns = newEnv()
    local pixelCalls, colorCalls, sizeCalls, showCalls = 0, 0, 0, 0
    PixelUtil = {
        GetNearestPixelSize = function()
            pixelCalls = pixelCalls + 1
            return 1.25
        end,
    }
    local frame = CreateFrame("Frame", "HotpathSkinFrame", UIParent)
    local origCreate = frame.CreateTexture
    frame.CreateTexture = function(self, ...)
        local tex = origCreate(self, ...)
        local origColor, origH, origW, origShow = tex.SetColorTexture, tex.SetHeight, tex.SetWidth, tex.Show
        tex.SetColorTexture = function(s, ...) colorCalls = colorCalls + 1; return origColor(s, ...) end
        tex.SetHeight = function(s, ...) sizeCalls = sizeCalls + 1; return origH(s, ...) end
        tex.SetWidth = function(s, ...) sizeCalls = sizeCalls + 1; return origW(s, ...) end
        tex.Show = function(s, ...) showCalls = showCalls + 1; return origShow(s, ...) end
        return tex
    end
    local skin = ns.Modern.Skin("hotpath")
    skin:Panel(frame)
    skin:Border(frame)
    pixelCalls, colorCalls, sizeCalls, showCalls = 0, 0, 0, 0
    return function()
        for _ = 1, 10000 do
            skin:Panel(frame)
            skin:Border(frame)
        end
    end, function()
        PixelUtil = nil
        return {
            ("SetColorTexture=%d"):format(colorCalls),
            ("SetSize=%d"):format(sizeCalls),
            ("Show=%d"):format(showCalls),
            ("GetNearestPixelSize=%d"):format(pixelCalls),
        }
    end
end)

-- 3. Modernize UNIT_AURA / UpdateAuraButtons raid burst (500 cycles, 30 buffs + 5 debuffs)
measureLoop("3. Aura burst (500x35 auras)", function()
    local mock, ns = newEnv()
    local R = assert(loadfile(libDir .. "/modern-retail.lua"))()
    local pixelCalls, colorCalls, sizeCalls, showCalls = 0, 0, 0, 0
    PixelUtil = {
        GetNearestPixelSize = function()
            pixelCalls = pixelCalls + 1
            return 1
        end,
    }
    installModernWorld(mock, R)
    local function wrapCreate(owner)
        local origCreate = owner.CreateTexture
        owner.CreateTexture = function(self, ...)
            local tex = origCreate(self, ...)
            local origColor, origH, origW, origShow = tex.SetColorTexture, tex.SetHeight, tex.SetWidth, tex.Show
            tex.SetColorTexture = function(s, ...) colorCalls = colorCalls + 1; return origColor(s, ...) end
            tex.SetHeight = function(s, ...) sizeCalls = sizeCalls + 1; return origH(s, ...) end
            tex.SetWidth = function(s, ...) sizeCalls = sizeCalls + 1; return origW(s, ...) end
            tex.Show = function(s, ...) showCalls = showCalls + 1; return origShow(s, ...) end
            return tex
        end
    end
    for _, b in ipairs(BuffFrame.auraFrames) do wrapCreate(b) end
    for _, b in ipairs(DebuffFrame.auraFrames) do wrapCreate(b) end
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    ns.Modern.Apply()
    pixelCalls, colorCalls, sizeCalls, showCalls = 0, 0, 0, 0
    return function()
        for _ = 1, 500 do
            BuffFrame:UpdateAuraButtons()
            DebuffFrame:UpdateAuraButtons()
            mock:fire("UNIT_AURA", "player")
        end
    end, function()
        PixelUtil = nil
        return {
            ("SetColorTexture=%d"):format(colorCalls),
            ("SetSize=%d"):format(sizeCalls),
            ("Show=%d"):format(showCalls),
            ("GetNearestPixelSize=%d"):format(pixelCalls),
        }
    end
end)

-- 4. Modernize unit events burst (500 cycles)
measureLoop("4. Unit events burst (500 cycles)", function()
    local mock, ns = newEnv()
    local U = assert(loadfile(libDir .. "/modern-units.lua"))()
    U.frames()
    for i = 1, 5 do U.target("Boss" .. i .. "TargetFrame", "boss" .. i) end
    U.installColours(mock)
    for i = 1, 4 do
        local pf = CreateFrame("Button", "PartyMemberFrame" .. i, UIParent)
        pf.unit = "party" .. i
        pf.Portrait = pf:CreateTexture(nil, "ARTWORK")
        pf.HealthBar = CreateFrame("StatusBar", nil, pf)
        pf.HealthBar.GetStatusBarTexture = function() return pf.Portrait end
        pf.HealthBar.SetStatusBarTexture = function() end
        pf.HealthBar.SetStatusBarColor = function() end
        pf.HealthBar.GetStatusBarColor = function() return 0, 1, 0, 1 end
        pf.ManaBar = CreateFrame("StatusBar", nil, pf)
        pf.ManaBar.GetStatusBarTexture = function() return pf.Portrait end
        pf.ManaBar.SetStatusBarTexture = function() end
        pf.ManaBar.SetStatusBarColor = function() end
        pf.ManaBar.GetStatusBarColor = function() return 0, 0, 1, 1 end
        pf.Name = pf:CreateFontString(nil, "OVERLAY")
        pf.Name:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    end
    for i = 1, 20 do
        local rf = CreateFrame("Button", "CompactRaidFrame" .. i, UIParent)
        rf.unit = "raid" .. i
        rf.displayedUnit = "raid" .. i
        rf.healthBar = CreateFrame("StatusBar", nil, rf)
        local htex = rf.healthBar:CreateTexture(nil, "ARTWORK")
        rf.healthBar.GetStatusBarTexture = function() return htex end
        rf.healthBar.SetStatusBarTexture = function() end
        rf.healthBar.SetStatusBarColor = function() end
        rf.healthBar.GetStatusBarColor = function() return 0, 1, 0, 1 end
        rf.powerBar = CreateFrame("StatusBar", nil, rf)
        local ptex = rf.powerBar:CreateTexture(nil, "ARTWORK")
        rf.powerBar.GetStatusBarTexture = function() return ptex end
        rf.powerBar.SetStatusBarTexture = function() end
        rf.powerBar.SetStatusBarColor = function() end
        rf.powerBar.GetStatusBarColor = function() return 0, 0, 1, 1 end
        rf.powerBar:SetPoint("BOTTOMRIGHT", rf, "BOTTOMRIGHT", 0, 0)
        rf.healthBar:SetPoint("TOPLEFT", rf, "TOPLEFT", 0, 0)
        rf.healthBar:SetPoint("BOTTOMRIGHT", rf, "BOTTOMRIGHT", 0, 4)
        rf.name = rf:CreateFontString(nil, "OVERLAY")
        rf.statusText = rf:CreateFontString(nil, "OVERLAY")
        rf.statusText:SetPoint("CENTER", rf.healthBar, "CENTER", 0, 0)
    end
    local sbColor, sbTex, setPt, colorTex = 0, 0, 0, 0
    for _, f in ipairs(mock.frames) do
        if f.SetStatusBarColor then
            local origC = f.SetStatusBarColor
            f.SetStatusBarColor = function(s, ...) sbColor = sbColor + 1; return origC(s, ...) end
        end
        if f.SetStatusBarTexture then
            local origT = f.SetStatusBarTexture
            f.SetStatusBarTexture = function(s, ...) sbTex = sbTex + 1; return origT(s, ...) end
        end
        local origPt = f.SetPoint
        f.SetPoint = function(s, ...) setPt = setPt + 1; return origPt(s, ...) end
        if f.CreateTexture then
            local origCreate = f.CreateTexture
            f.CreateTexture = function(self, ...)
                local tex = origCreate(self, ...)
                local origCT = tex.SetColorTexture
                tex.SetColorTexture = function(s, ...) colorTex = colorTex + 1; return origCT(s, ...) end
                return tex
            end
        end
        local origCT = f.SetColorTexture
        if origCT then
            f.SetColorTexture = function(s, ...) colorTex = colorTex + 1; return origCT(s, ...) end
        end
    end
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    ns.Modern.Apply()
    sbColor, sbTex, setPt, colorTex = 0, 0, 0, 0
    return function()
        for _ = 1, 500 do
            mock:fire("PLAYER_TARGET_CHANGED")
            mock:fire("UNIT_FACTION", "target")
            mock:fire("UNIT_CLASSIFICATION_CHANGED", "target")
            mock:fire("UNIT_NAME_UPDATE", "party1")
        end
    end, function()
        return {
            ("SetStatusBarColor=%d"):format(sbColor),
            ("SetStatusBarTexture=%d"):format(sbTex),
            ("SetPoint=%d"):format(setPt),
            ("SetColorTexture=%d"):format(colorTex),
        }
    end
end)
