-- Party frames: the alpha tree is not read while autohide is off.
local h = ...

h.test("Party alpha tree stays unread while autohide is off", function(t)
    local A = t.assert
    local party = PartyFrame
    CreateFrame("Frame", nil, party)
    local function walks() return (party._calls.GetChildren or 0) + (party._calls.GetRegions or 0) end
    local before = walks()
    t.ns.FindFaders(false)
    A.eq(walks() - before, 0, "Autohide off still walked party frames")
    QuietUICharDB.autoHideParty = true
    t.ns.FindFaders(false)
    A.ok(walks() - before > 0, "Autohide on did not collect party alphas")
end)
