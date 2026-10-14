-- Skin journal: helpers record the previous value, Undo replays it, own regions are reused.
local h = ...
local L = h.lib("modern")

local function tex(alpha)
    local f = CreateFrame("Frame", nil, UIParent)
    local x = f:CreateTexture()
    if alpha then x:SetAlpha(alpha) end
    return x, f
end

h.test("Skin(key) returns a journal with the documented helpers", function(t)
    local skin = t.ns.Modern.Skin("zz_a")
    for _, name in ipairs({ "Icon", "Border", "Panel", "Button", "Hold", "Set", "Undo" }) do
        t.assert.type(skin[name], "function", "skin:" .. name)
    end
end)

h.test("Icon zooms the TexCoord and Undo puts the old one back", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    local x = tex()
    x:SetTexCoord(0.1, 0.9, 0.2, 0.8)
    skin:Icon(x)
    A.deep({ x:GetTexCoord() }, { 0.08, 0.92, 0.08, 0.92 })
    skin:Undo()
    A.deep({ x:GetTexCoord() }, { 0.1, 0.9, 0.2, 0.8 })
end)

h.test("Hold keeps alpha 0 against Blizzard SetAlpha and Undo releases it", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    local x = tex(0.6)
    skin:Hold(x)
    A.alpha(x, 0)
    x:SetAlpha(1)
    A.alpha(x, 0, "Blizzard overwrite is put back")
    skin:Undo()
    A.alpha(x, 0.6, "previous alpha restored")
    x:SetAlpha(1)
    A.alpha(x, 1, "hold released")
end)

h.test("Hold is released when the addon is off, like every other hold", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    local x = tex(0.6)
    skin:Hold(x)
    QuietUIDB.enabled = false
    x:SetAlpha(1)
    A.alpha(x, 1, "no hold while QuietUI is off")
end)

h.test("Set records the previous value once per property and Undo restores the first", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    local x = tex()
    x:SetTexture("orig")
    skin:Set(x, "SetTexture", "one")
    A.eq(x:GetTexture(), "one")
    skin:Set(x, "SetTexture", "two")
    A.eq(x:GetTexture(), "two")
    skin:Undo()
    A.eq(x:GetTexture(), "orig")
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(50, 30)
    skin:Set(f, "SetWidth", 99)
    A.eq(f:GetWidth(), 99)
    skin:Undo()
    A.eq(f:GetWidth(), 50)
end)

h.test("Undo clears the journal: a second Undo changes nothing", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    local x = tex()
    x:SetTexture("orig")
    skin:Set(x, "SetTexture", "one")
    skin:Undo()
    x:SetTexture("later")
    skin:Undo()
    A.eq(x:GetTexture(), "later")
end)

h.test("one area's Undo never touches another area's objects", function(t)
    local A, ns = t.assert, t.ns
    local a, b = ns.Modern.Skin("zz_a"), ns.Modern.Skin("zz_b")
    local x, y = tex(0.5), tex(0.5)
    a:Icon(x); a:Hold(x)
    b:Icon(y); b:Hold(y)
    a:Undo()
    A.deep({ x:GetTexCoord() }, { 0, 1, 0, 1 })
    A.alpha(x, 0.5)
    A.deep({ y:GetTexCoord() }, { 0.08, 0.92, 0.08, 0.92 }, "b keeps its skin")
    A.alpha(y, 0)
    y:SetAlpha(1)
    A.alpha(y, 0, "b keeps its hold")
end)

h.test("Skin(key) returns the same journal for the same key", function(t)
    t.assert.eq(t.ns.Modern.Skin("zz_a"), t.ns.Modern.Skin("zz_a"))
end)

local function created(mock, from) 
    local out = {}
    for i = from + 1, #mock.frames do out[#out + 1] = mock.frames[i] end
    return out
end

for _, helper in ipairs({ "Border", "Panel" }) do
    h.test(helper .. " creates its own regions once, hides them on Undo and reuses them", function(t)
        local A, mock = t.assert, t.mock
        local skin = t.ns.Modern.Skin("zz_a")
        local _, frame = tex()
        local before = #mock.frames
        skin[helper](skin, frame)
        local own = created(mock, before)
        A.ok(#own > 0, helper .. " creates its own regions")
        for _, r in ipairs(own) do A.ok(r._shown, "own region shown") end
        skin:Undo()
        for _, r in ipairs(own) do A.falsy(r._shown, "own region hidden after Undo") end
        local count = #mock.frames
        skin[helper](skin, frame)
        A.eq(#mock.frames, count, "regions are reused, none created again")
        for _, r in ipairs(own) do A.ok(r._shown, "own region shown again") end
        skin[helper](skin, frame)
        A.eq(#mock.frames, count, "a second call on the same frame creates nothing")
    end)
end

h.test("Button flattens a button and Undo restores its textures", function(t)
    local A, mock = t.assert, t.mock
    local skin = t.ns.Modern.Skin("zz_a")
    local button = CreateFrame("Button", nil, UIParent)
    local normal = button:CreateTexture()
    normal:SetTexture("blizzard-normal")
    local snap = L.snapshot({ button, normal })
    A.noThrow(function() skin:Button(button) end)
    skin:Undo()
    A.deep(L.diff(snap), {})
end)

h.test("a missing frame is skipped without an error", function(t)
    local A = t.assert
    local skin = t.ns.Modern.Skin("zz_a")
    A.noThrow(function()
        skin:Icon(nil); skin:Hold(nil); skin:Border(nil); skin:Panel(nil); skin:Button(nil)
        skin:Set(nil, "SetTexture", "x")
        skin:Undo()
    end)
end)

h.test("a missing method is reported through one message however often it is skipped", function(t)
    local A, mock = t.assert, t.mock
    local skin = t.ns.Modern.Skin("zz_a")
    mock.printed = {}
    local bare = {}
    for _ = 1, 3 do skin:Icon(bare) end
    A.eq(L.errors(mock), 1, "missing SetTexCoord")
    mock.printed = {}
    for _ = 1, 3 do skin:Set(bare, "NoSuchMethod", 1) end
    A.ok(L.errors(mock) <= 1, "missing method")
    A.noThrow(function() skin:Undo() end)
end)
