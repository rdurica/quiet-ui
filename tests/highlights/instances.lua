-- Highlights are off in party, raid, pvp and arena instances and come back outside.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

local function trigger(w, how)
    if how == "ApplyHighlights" then w.apply() else w.event(how) end
end

local function instanceCase(kind, enter)
    case("Entering a " .. kind .. " instance via " .. enter .. " hides and restores; leaving sets again", function(t, A)
        local w = H.oreShown(t)
        w.instance(kind)
        trigger(w, enter)
        w.assertHidden()
        w.assertCVars(H.ORIGINAL, "Inside " .. kind)
        A.eq(w.saved(), nil, "highlightCVars was not cleared inside " .. kind)
        w.instance("none")
        trigger(w, enter)
        w.assertCVars(H.WANT, "After leaving " .. kind)
        w.assertSaved(H.ORIGINAL)
        return w
    end)
end

for _, kind in ipairs({ "party", "raid", "pvp", "arena" }) do instanceCase(kind, "ApplyHighlights") end
instanceCase("party", "PLAYER_ENTERING_WORLD")
instanceCase("raid", "ZONE_CHANGED_NEW_AREA")

case("A scenario instance is not one of the blocked types", function(t)
    local w = H.world(t, { flags = { ore = true } })
    w.instance("scenario")
    w.apply()
    w.assertCVars(H.IDLE, "In a scenario")
    return w
end)
