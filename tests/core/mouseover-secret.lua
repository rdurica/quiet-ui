-- A frame whose rect depends on secret text (a chat bubble for a secret line) answers IsMouseOver with a secret
-- boolean. Testing it throws on the client, so the hover helpers treat it as not hovered.
local h = ...

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function secretFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Show()
    function frame:IsMouseOver() return SECRET end
    return frame
end

h.test("MouseOver treats a secret IsMouseOver answer as not hovered", function(t)
    local ns, A = t.ns, t.assert
    issecretvalue = function(v) return v == SECRET end
    A.eq(ns.MouseOver(secretFrame()), false, "secret answer is not hovered")
    local plain = CreateFrame("Frame", nil, UIParent)
    plain:Show()
    plain:SetMouseOver(true)
    A.eq(ns.MouseOver(plain), true, "a readable answer still counts")
end)

h.test("Hit treats a secret IsMouseOver answer as not hovered", function(t)
    local ns, A = t.ns, t.assert
    issecretvalue = function(v) return v == SECRET end
    A.eq(ns.Hit(secretFrame()), false, "secret answer is not hovered")
end)
