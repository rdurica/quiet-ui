-- Column titles sit on their section's strip. A strip is a child frame and draws over its page's own text,
-- so a title the page owned was hidden under it.
local h = ...

local TITLES = {
    ["Always visible"] = { "Visibility", "Group visibility" },
    ["Only on hover"] = { "Visibility", "Group visibility" },
    Enemy = { "Fade together" }, Friend = { "Fade together" }, Group = { "Fade together" },
}

h.test("table column titles belong to the section strip they sit on", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = {}; QuietUICharDB = {}
    ns.Layout.Choices = function() return {} end
    ns.Setup.Show()
    local found = {}
    for _, frame in ipairs(mock.frames) do
        for _, region in ipairs(frame._regions or {}) do
            local sections = TITLES[region._text]
            if sections then
                local label = frame.label and frame.label._text
                local ok = false
                for _, section in ipairs(sections) do ok = ok or label == section end
                A.ok(ok, region._text .. " is owned by its section, not by " .. tostring(label))
                found[region._text] = (found[region._text] or 0) + 1
            end
        end
    end
    A.eq(found["Always visible"], 2, "Visible and Groups both title their columns")
    A.eq(found["Only on hover"], 2)
    A.eq(found.Enemy, 1); A.eq(found.Friend, 1); A.eq(found.Group, 1)
end)
