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
    -- installColours' GetClassColor reads this table, so a secret key raises there too.
    RAID_CLASS_COLORS = strictTable(t, { MAGE = { r = 0.25, g = 0.78, b = 0.92 } })
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

-- On the client type() of a secret token is "string"; only issecretvalue tells it apart.
h.test("a secret UnitClass token that reads as a string keeps Blizzard's name colour", function(t)
    run(t, function()
        local real = issecretvalue
        issecretvalue = function(v) return v == "MAGE" or real(v) end
        UnitClass = function() return "Mage", "MAGE", 8 end
    end)
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

-- A player whose data is not loaded yet: UnitIsPlayer is true but UnitClass has no token.
h.test("a player whose UnitClass has no token yet keeps Blizzard's name colour without an error", function(t)
    run(t, function() UnitClass = function() return nil end end)
end)

h.test("a class token that arrives after the unit colours the name on UNIT_NAME_UPDATE", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    frames[3].Name:SetTextColor(1, 0.82, 0)
    UnitClass = function() return nil end
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.deep({ frames[3].Name:GetTextColor() }, { 1, 0.82, 0, 1 }, "name keeps Blizzard's colour while unknown")
    A.ok(not U.classIcon(frames[3]), "no class icon while unknown")
    UnitClass = function() return "Mage", "MAGE", 8 end
    mock:fire("UNIT_NAME_UPDATE", "nameplate3")
    A.deep({ frames[3].Name:GetTextColor() }, { 1, 0.82, 0, 1 }, "another unit's update changes nothing")
    mock:fire("UNIT_NAME_UPDATE", "target")
    A.deep({ frames[3].Name:GetTextColor() }, { 0.25, 0.78, 0.92, 1 }, "name takes the mage colour")
    A.eq(L.errors(mock), 0, "no error reported")
end)

h.test("an unknown class goes back to the colour Blizzard gave the new unit, not an older one", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    local name = frames[3].Name
    name:SetTextColor(1, 0.82, 0)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.deep({ name:GetTextColor() }, { 0.25, 0.78, 0.92, 1 }, "name takes the mage colour")
    -- The class is unknown and Blizzard did not recolour: the class colour of the old unit must not stay.
    UnitClass = function() return nil end
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep({ name:GetTextColor() }, { 1, 0.82, 0, 1 }, "Blizzard's colour comes back")
    -- Blizzard recolours the name for the next unit.
    UnitClass = function() return "Mage", "MAGE", 8 end
    mock:fire("PLAYER_TARGET_CHANGED")
    name:SetTextColor(0.5, 0.5, 0.5)
    UnitClass = function() return nil end
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep({ name:GetTextColor() }, { 0.5, 0.5, 0.5, 1 }, "Blizzard's newer colour stays")
    ns.Modern.Restore()
    A.deep({ name:GetTextColor() }, { 0.5, 0.5, 0.5, 1 }, "and is what restore gives back")
    A.eq(L.errors(mock), 0, "no error reported")
end)

h.test("a GetClassColor that raises falls back to the class colour table", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    C_ClassColor = { GetClassColor = function() error("GetClassColor is not for this client") end }
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(L.errors(mock), 0, "no error reported")
    A.deep({ frames[3].Name:GetTextColor() }, { 0.25, 0.78, 0.92, 1 }, "name takes the mage colour")
end)
