-- UNIT_FACTION and UNIT_CLASSIFICATION_CHANGED fire for every unit; the unit frames only skin again for their own.
local h = ...
local U = h.lib("modern-units")

h.test("unit events for other units do no work, events for skinned units skin again", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.frames()
    U.installColours(mock)
    local calls = 0
    UnitClassification = function() calls = calls + 1; return "normal" end
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    local applied = calls
    A.ok(applied > 0, "the target health border reads the classification")
    mock:fire("UNIT_CLASSIFICATION_CHANGED", "nameplate3")
    mock:fire("UNIT_FACTION", "party2")
    A.eq(calls, applied, "other units cause no re-skin")
    mock:fire("UNIT_CLASSIFICATION_CHANGED", "target")
    A.eq(calls, applied + 1, "the target re-skins")
    mock:fire("PLAYER_TARGET_CHANGED")
    A.eq(calls, applied + 2, "a target change re-skins")
end)
