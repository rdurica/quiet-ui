-- Fixture for the player portrait / pet / grouped-aura tests (faders/player). Test code only.
-- Loaded with h.lib("player"). Exposes the secret health/power API of this client:
-- UnitHealthPercent / UnitPowerPercent evaluate the addon's curve and return a strict secret
-- (any comparison or arithmetic on it raises), as the real client does for tainted code.
local P = {}

local function forbidden() error("Addon attempted arithmetic/comparison on a secret", 2) end
local STRICT = { __lt = forbidden, __le = forbidden, __add = forbidden, __sub = forbidden,
    __mul = forbidden, __div = forbidden, __unm = forbidden }

-- A secret value the addon may only pass on, never inspect.
function P.secret(mock, value)
    local box = setmetatable({ value = value }, STRICT)
    mock.secrets[box] = true
    return box
end

function P.unwrap(v) return type(v) == "table" and v.value or v end

-- Alpha as rendered: own alpha times the parent chain unless the frame ignores parent alpha.
function P.effective(f)
    local own = P.unwrap(f._alpha)
    local parent = f._parent
    if f._ignoreParent or not parent or not parent._alpha then return own end
    return own * P.effective(parent)
end

-- Installs the secret percent API. read("health"|"power") returns the current fraction.
-- Curve points must be plain numbers (secret points are forbidden in tainted code).
function P.installPercents(mock, read, counter)
    Enum.LuaCurveType = { Step = 1, Linear = 0 }
    C_CurveUtil = { CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType(kind) self.kind = kind end
        function curve:ClearPoints() self.points = {} end
        function curve:AddPoint(x, y)
            assert(not issecretvalue(x), "Threshold coordinates must be plain numbers")
            assert(not issecretvalue(y), "Secret point values are forbidden in tainted code")
            self.points[#self.points + 1] = { x, y }
        end
        function curve:evaluate(x)
            local pts = self.points
            for i = 2, #pts do
                if x < pts[i][1] then
                    if self.kind == Enum.LuaCurveType.Step then return P.secret(mock, pts[i - 1][2]) end
                    local a, b = pts[i - 1], pts[i]
                    return P.secret(mock, a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]))
                end
            end
            return P.secret(mock, pts[#pts][2])
        end
        return curve
    end }
    UnitHealthPercent = function(unit, _, curve)
        assert(unit == "player", "Health read for a unit other than the player")
        if counter then counter.reads = counter.reads + 1 end
        return curve:evaluate(read("health"))
    end
    UnitPowerPercent = function(unit, powerKind, _, curve)
        assert(unit == "player" and powerKind ~= false and curve, "Power received health arguments")
        if counter then counter.reads = counter.reads + 1 end
        return curve:evaluate(read("power"))
    end
    UnitPowerType = function() return 0, "MANA" end
end

-- Builds the fixture on the harness context t. opts: inherited (pet is a child of the portrait),
-- preset (an existing shared preset is active), plain (leave every alpha at 1).
-- Returned state s: s.life = "alive"|"dead"|"ghost", s.health, s.power, s.targetDead, world flags
-- (s.InCombat, s.HasTarget, s.Glancing ...), s.tick(elapsed), s.portrait(expected, msg).
function P.env(t, opts)
    opts = opts or {}
    local ns, mock = t.ns, t.mock
    local s = { life = "alive", health = 1, power = 1, targetDead = false, reads = 0 }
    local function child(parent) return CreateFrame("Frame", nil, parent or UIParent) end
    TemporaryEnchantFrame = child()
    local names = { "PlayerFrame", "PetFrame", "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame",
        "TargetFrame", "PersonalResourceDisplayFrame", "StatusTrackingBarManager",
        "EssentialCooldownViewer", "DamageMeter", "PartyFrame", "ObjectiveTrackerFrame" }
    s.names = names
    if not opts.plain then
        PlayerFrame._alpha, PetFrame._alpha, TargetFrame._alpha = 0.8, 0.6, 0.7
    end
    if opts.inherited then
        PetFrame = child(PlayerFrame)
        PetFrame._alpha = 0.6
    end
    PersonalResourceDisplayFrame.HealthBarsContainer = child(PersonalResourceDisplayFrame)
    s.resourcePower = child(PersonalResourceDisplayFrame)
    for _, name in ipairs(names) do
        _G[name].Hide = function() error("Player/pet must be controlled through alpha only") end
        _G[name].Show = _G[name].Hide
    end
    P.installPercents(mock, function(kind) return s[kind] end, s)
    UnitIsDeadOrGhost = function(unit)
        if unit == "target" then return s.targetDead end
        assert(unit == "player", "Life API must read player or target")
        return s.life ~= "alive"
    end
    for _, key in ipairs({ "InEditMode", "InCombat", "InForcedInstance", "InGroup", "InVehicle",
        "HasTarget", "Glancing", "ShowAll", "XPForced" }) do
        ns[key] = function() return s[key] == true end
    end
    ns.Hit = function(obj) return obj and obj.hot == true end
    if opts.preset then
        QuietUIDB.presets = { [1] = { name = "Existing", interfaceStyle = 0,
            settings = { playerThresholdKind = "health", playerThresholdPercent = 70 },
            layout = { name = "Existing", layoutType = 1, interfaceStyle = 0 } } }
        QuietUICharDB.presetId = 1
        ns.Settings() -- establish the existing personal snapshot before testing transitions
    end
    ns.FindFaders(false)
    for i = #mock.printed, 1, -1 do mock.printed[i] = nil end
    s.reports = mock.printed
    function s.tick(elapsed)
        ns.NextFadeTick()
        ns.UpdateSmooth(elapsed or 0.3)
        assert(s.allowReports or #s.reports == 0, "Unexpected addon error: " .. table.concat(s.reports, "; "))
    end
    function s.portrait(expected, msg)
        local got = P.unwrap(PlayerFrame._alpha)
        assert(type(got) == "number" and math.abs(got - expected) < 1e-6,
            (msg or "Portrait alpha") .. ": got " .. tostring(got) .. ", expected " .. expected)
    end
    return s
end

return P
