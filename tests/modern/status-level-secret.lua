-- XP range follows a level up during a running gain; a secret watched reputation goes straight to its bar.
local h = ...

local function enable() QuietUICharDB = { modernize = { enabled = true } } end

local function child(height)
    local function walk(frame)
        for _, c in ipairs(frame._children) do
            if c._kind == "StatusBar" and c._h == height then return c end
            local found = walk(c)
            if found then return found end
        end
    end
    return walk(MainStatusTrackingBarContainer)
end

h.test("a level up that raises XP and maximum together sets the new range while the gain runs", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local xp, max = 100, 1000
    UnitXP = function() return xp end
    UnitXPMax = function() return max end
    GetXPExhaustion = function() return nil end
    enable(); ns.Modern.Apply()
    local bar = child(6)
    xp, max = 150, 2000
    mock:fire("PLAYER_XP_UPDATE", "player")
    mock:fire("PLAYER_LEVEL_UP", 11)
    A.eq(bar._max, 2000, "the bar range follows the new maximum")
end)

h.test("a secret watched reputation is passed to its bar and the bar is shown", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local secret = setmetatable({}, {
        __lt = function() error("secret reputation was compared") end,
        __le = function() error("secret reputation was compared") end,
        __eq = function() error("secret reputation was compared") end,
        __add = function() error("secret reputation was added") end,
    })
    mock.secrets[secret] = true
    UnitXP = function() return 1 end
    UnitXPMax = function() return 2 end
    GetXPExhaustion = function() return nil end
    C_Reputation = { GetWatchedFactionData = function()
        return { factionID = 72, currentReactionThreshold = 0, nextReactionThreshold = 1000, currentStanding = secret }
    end }
    enable(); ns.Modern.Apply()
    local bar = child(4)
    A.ok(bar:IsShown(), "the reputation bar is shown")
    A.eq(bar:GetValue(), secret, "the secret standing reaches the widget itself")
end)
