-- Unit identity can be secret on 12.0: UnitIsPlayer / UnitClass / UnitReaction may return secret values, which
-- must not be used as a table key or a branch. The name then keeps Blizzard's colour.
local h = ...
local L = h.lib("modern")
local U = h.lib("modern-units")

-- A table that, like the client, raises when it is indexed with a secret value.
local function strictTable(t, entries)
    return setmetatable(entries, { __index = function(_, key)
        if t.mock.secrets[key] then error("secret value used as a table key", 2) end
    end })
end

local function setup(t)
    local frames = U.frames()
    U.installColours(t.mock)
    local secret = U.secrets(t.mock)
    RAID_CLASS_COLORS = strictTable(t, { MAGE = { r = 0.25, g = 0.78, b = 0.92 } })
    C_ClassColor = { GetClassColor = function(token) return RAID_CLASS_COLORS[token] end }
    FACTION_BAR_COLORS = strictTable(t, { [2] = { r = 0.8, g = 0.1, b = 0.1 } })
    return frames, secret
end


local function run(t, mutate)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames, secret = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    frames[3].Name:SetTextColor(1, 0.82, 0)
    mutate(secret)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    local health = U.parts(frames[3]).health
    health:SetStatusBarColor(0, 1, 0)
    A.eq(L.errors(mock), 0, "no error reported")
    A.deep({ frames[3].Name:GetTextColor() }, { 1, 0.82, 0, 1 }, "name keeps Blizzard's colour")
    A.eq(U.statusTexture(health), ns.Modern.Theme().bar, "theme texture still applied")
end

h.test("a secret UnitIsPlayer keeps Blizzard's name colour without an error", function(t)
    run(t, function(secret) UnitIsPlayer = function() return secret(true) end end)
end)

h.test("a secret UnitClass token keeps Blizzard's name colour without an error", function(t)
    run(t, function(secret) UnitClass = function() return "Mage", secret("MAGE"), 8 end end)
end)

h.test("a secret UnitReaction keeps Blizzard's name colour without an error", function(t)
    run(t, function(secret)
        t.mock:setUnit("target", { exists = true, player = false })
        UnitReaction = function() return secret(2) end
    end)
end)

h.test("a secret first UnitReaction result is never tested before the secret check", function(t)
    run(t, function(secret)
        t.mock:setUnit("target", { exists = true, player = false })
        UnitReaction = function(_, other)
            if other == nil then error("fallback UnitReaction call after a secret value") end
            return secret(2)
        end
    end)
end)
