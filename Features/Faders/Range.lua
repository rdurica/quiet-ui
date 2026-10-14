local _, ns = ...
local Faders = ns.Faders

local rangeSlot = { at = nil, helpful = nil, slot = nil }
-- Bar 1 changes come as events; the timer only covers a missed one.
local SLOT_FALLBACK = 5

function Faders.PlainNumber(value)
    return type(value) == "number" and not ns.IsSecret(value)
end

local function ActionSpell(slot)
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok or ns.IsSecret(kind) or ns.IsSecret(id) then return nil end
    if kind == "spell" and type(id) == "number" then return id end
    if kind ~= "macro" or type(GetMacroSpell) ~= "function" then return nil end
    local spellOk, spell = pcall(GetMacroSpell, id)
    if not spellOk or ns.IsSecret(spell) then return nil end
    if type(spell) == "number" then return spell end
    if type(spell) == "string" and spell ~= "" then return spell end
end

local function SpellFacts(spellID)
    local name, maxRange
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            if type(info.name) == "string" and not ns.IsSecret(info.name) then name = info.name end
            if Faders.PlainNumber(info.maxRange) then maxRange = info.maxRange end
        end
    end
    if type(GetSpellInfo) == "function" and (not name or not maxRange) then
        local ok, spellName, _, _, _, _, range = pcall(GetSpellInfo, spellID)
        if ok then
            if not name and type(spellName) == "string" and not ns.IsSecret(spellName) then
                name = spellName
            end
            if not maxRange and Faders.PlainNumber(range) then maxRange = range end
        end
    end
    if not name and not maxRange and not (C_Spell and type(C_Spell.GetSpellInfo) == "function")
        and type(GetSpellInfo) ~= "function" then
        ns.Report("range spell", "spell info missing")
    end
    return name, maxRange
end

-- nil means the harm flag could not be read, so the slot is skipped.
local function SpellKind(spellID, name, helpful)
    local modern
    if C_Spell then
        if helpful then modern = C_Spell.IsSpellHelpful else modern = C_Spell.IsSpellHarmful end
    end
    if type(modern) == "function" then
        local ok, result = pcall(modern, spellID)
        if ok and not ns.IsSecret(result) then return result and true or false end
        if ok and ns.IsSecret(result) then return nil end
    end
    local classic = IsHarmfulSpell
    if helpful then classic = IsHelpfulSpell end
    if type(classic) == "function" and type(name) == "string" then
        local ok, result = pcall(classic, name)
        if ok and not ns.IsSecret(result) then return result and true or false end
        if ok and ns.IsSecret(result) then return nil end
    end
    if type(modern) ~= "function" and type(classic) ~= "function" then
        ns.Report("range spell", "spell harm check missing")
    end
end

-- Longest matching spell on bar 1. A tie keeps the left slot.
local function BestSlot(helpful)
    if type(GetActionInfo) ~= "function" then
        ns.Report("range spell", "GetActionInfo missing")
        return nil
    end
    local bestSlot, bestRange
    for slot = 1, 12 do
        local spellID = ActionSpell(slot)
        if spellID then
            local name, maxRange = SpellFacts(spellID)
            local matches = maxRange and maxRange > 0 and SpellKind(spellID, name, helpful)
            if matches and (not bestRange or maxRange > bestRange) then
                bestRange = maxRange
                bestSlot = slot
            end
        end
    end
    return bestSlot
end

-- Bar 1 changes rarely, so the chosen spell is cached. Distance is read every frame.
local function CachedSlot(helpful)
    local now = type(GetTime) == "function" and GetTime() or 0
    if rangeSlot.at and rangeSlot.helpful == helpful and now - rangeSlot.at < SLOT_FALLBACK then
        return rangeSlot.slot
    end
    local slot = BestSlot(helpful)
    rangeSlot.helpful = helpful
    rangeSlot.at = now
    rangeSlot.slot = slot
    return slot
end

-- "in", "out", "no", or "hold". A named spell does not have to sit on bar 1.
local function ReadSpellRange(name)
    local fn = C_Spell and C_Spell.IsSpellInRange
    if type(fn) ~= "function" then fn = IsSpellInRange end
    if type(fn) ~= "function" then
        ns.Report("range check", "IsSpellInRange missing")
        return "no"
    end
    local ok, result = pcall(fn, name, "target")
    if not ok then
        ns.Report("range check", result)
        return "no"
    end
    if result == nil then return "no" end
    if ns.IsSecret(result) then return "hold" end
    if result == 1 or result == true then return "in" end
    if result == 0 or result == false then return "out" end
    return "no"
end

-- "in", "out", "no", or "hold". 0 and 1 both mean the spell can be used on this target.
local function ReadActionRange(slot)
    if type(IsActionInRange) ~= "function" then
        ns.Report("range check", "IsActionInRange missing")
        return "no"
    end
    local ok, result = pcall(IsActionInRange, slot)
    if not ok then
        ns.Report("range check", result)
        return "no"
    end
    if result == nil then return "no" end
    if ns.IsSecret(result) then return "hold" end
    if result == 1 or result == true then return "in" end
    if result == 0 or result == false then return "out" end
    return "no"
end

-- "alive", "hide", or "hold".
local function TargetLife()
    if type(UnitExists) ~= "function" then return "hide" end
    local ok, exists = pcall(UnitExists, "target")
    if not ok or ns.IsSecret(exists) then return ok and "hold" or "hide" end
    if not exists then return "hide" end
    local deadFn = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost
        or (type(UnitIsDead) == "function" and UnitIsDead)
    if not deadFn then return "alive" end
    local deadOk, dead = pcall(deadFn, "target")
    if not deadOk then return "hide" end
    if ns.IsSecret(dead) then return "hold" end
    if dead then return "hide" end
    return "alive"
end

-- "ok", "hide", or "hold". Friendly is reaction 5 and above.
local function FriendlyReaction()
    if type(UnitReaction) ~= "function" then
        ns.Report("range check", "UnitReaction missing")
        return "hide"
    end
    local ok, reaction = pcall(UnitReaction, "player", "target")
    if not ok then return "hide" end
    if ns.IsSecret(reaction) then return "hold" end
    if type(reaction) ~= "number" or reaction < 5 then return "hide" end
    return "ok"
end

-- "show", "hide", or "hold". Automatic bar triggers and Glance suppress the indicator.
function Faders.RangeDecision()
    if type(ns.Settings.Range) ~= "function" then return "hide" end
    local yards, kind, spellName = ns.Settings.Range()
    if not yards then return "hide" end
    if ns.World.ShowAll() or ns.Glance.Active() then return "hide" end
    local life = TargetLife()
    if life ~= "alive" then return life end
    if kind == "friendly" then
        local who = FriendlyReaction()
        if who ~= "ok" then return who end
    end
    local reach
    if spellName then
        reach = ReadSpellRange(spellName)
    else
        local slot = CachedSlot(kind == "friendly")
        if not slot then return "hide" end
        reach = ReadActionRange(slot)
    end
    if reach == "hold" or reach == "no" then return reach == "hold" and "hold" or "hide" end
    if yards == "spell" then return reach == "in" and "show" or "hide" end
    if type(CheckInteractDistance) ~= "function" then
        ns.Report("range distance", "CheckInteractDistance missing")
        return "hide"
    end
    local index = yards == 10 and 2 or 1
    local ok, near = pcall(CheckInteractDistance, "target", index)
    if not ok then
        ns.Report("range distance", near)
        return "hide"
    end
    if ns.IsSecret(near) then return "hold" end
    if near == 1 or near == true then return "show" end
    return "hide"
end

function Faders.ForgetRangeSlot()
    rangeSlot.at = nil
end
