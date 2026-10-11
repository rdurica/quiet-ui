-- XP bar defaults to Only on hover; unchecking persists the usual combat visibility.
-- Driven through the setup window (Visible tab) and the fade tick.
local h = ...

-- Button whose own text or label text is exactly `text`.
local function button(mock, text)
    for _, f in ipairs(mock.frames) do
        if f._kind == "Button" then
            if f._text == text then return f end
            for _, r in ipairs(f._regions) do
                if r._text == text then return f end
            end
        end
    end
    error("no button " .. text, 0)
end

-- The Always visible and Only on hover boxes of the Visible tab row labelled `label`.
local function row(mock, label)
    for _, f in ipairs(mock.frames) do
        for _, r in ipairs(f._regions) do
            if r._text == label and #f._children == 2 then
                return { always = f._children[1], hover = f._children[2] }
            end
        end
    end
    error("no row " .. label, 0)
end

local function click(b) b._scripts.OnClick(b) end
local function checked(b) return b.box._checked end

h.test("XP defaults to hover and unchecking persists usual combat visibility", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    A.ok(ns.OnlyOnHover("xp") and not ns.OnlyOnHover("meter"))
    ns.ShowSetup()
    local xp = row(mock, "XP bar")
    A.ok(checked(xp.hover) and not checked(xp.always), "The window must show XP as Only on hover by default")
    click(xp.hover)
    click(button(mock, "Save"))
    A.ok(QuietUICharDB.hoverOnly.xp == false and not ns.OnlyOnHover("xp"), "Unchecking did not persist")
    ns.RefreshSetup()
    A.falsy(checked(row(mock, "XP bar").hover), "The saved choice must stay unchecked")
    local id = assert(ns.SavePreset(nil, "Normal XP", {}, { hoverOnly = { xp = false } }))
    ns.ActivatePreset(id); A.ok(not ns.OnlyOnHover("xp"))
    MainStatusTrackingBarContainer = CreateFrame("Frame", nil, UIParent)
    local bar = MainStatusTrackingBarContainer
    ns.FindFaders(false)
    ns.Hit = function() return false end
    local forced = true
    ns.ShowAll = function() return forced end
    ns.XPForced = function() return false end
    local function tick() ns.NextFadeTick(); ns.UpdateFaders(1) end
    tick(); A.eq(bar._alpha, 1, "Usual rules did not show XP in combat/vehicle/instance")
    forced = false; tick(); A.eq(bar._alpha, 0)
    ns.MarkQuestXP(100); tick(); A.eq(bar._alpha, 1, "Usual XP reward rule lost")
    ns.DeletePreset(id); A.ok(not ns.OnlyOnHover("xp"), "Personal snapshot lost explicit false")
    ns.ActivatePreset(nil, {}); forced = true; tick()
    A.ok(ns.OnlyOnHover("xp") and bar._alpha == 0, "Reset did not restore hover default")
    QuietUICharDB.visible = { xp = true }
    QuietUICharDB.hoverOnly = nil
    ns.RefreshSetup()
    xp = row(mock, "XP bar")
    A.ok(checked(xp.always) and not checked(xp.hover), "Existing Always visible XP choice was overwritten")
    click(button(mock, "Save")); tick(); A.eq(bar._alpha, 1)
end)
