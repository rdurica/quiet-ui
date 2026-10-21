-- Idle chat ticks: a still pointer does not probe settled bubbles.
local h = ...

h.test("Still pointer does not probe settled chat bubbles", function(t)
    local A, mock = t.assert, t.mock
    t.boot()
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function tick(elapsed) events._scripts.OnUpdate(events, elapsed) end
    local before = #mock.frames
    ChatFrame1:AddMessage("settled chat line", 1, 1, 1)
    tick(1 / 60)
    local bubble
    for i = before + 1, #mock.frames do
        local f = mock.frames[i]
        if f._parent == ChatFrame1 and f._scripts.OnEnter then bubble = f break end
    end
    A.ok(bubble, "precondition: a chat line created a bubble")
    local overs = 0
    function bubble:IsMouseOver()
        overs = overs + 1
        return false
    end
    -- The cursor has not moved since the first tick.
    tick(1 / 60)
    tick(1 / 60)
    overs = 0
    tick(1 / 60)
    A.eq(overs, 0, "Stationary chat still called IsMouseOver")
    -- Hover starts: the line stays hot, and is rechecked for the pointer leaving.
    bubble._scripts.OnEnter(bubble)
    overs = 0
    tick(1 / 60)
    A.ok(overs >= 1, "A hot bubble was not checked for the pointer leaving")
    -- Pointer leaves, the hover settles, then the pointer moves.
    bubble._scripts.OnLeave(bubble)
    mock:advance(0.2)
    tick(1 / 60)
    tick(1 / 60)
    overs = 0
    mock.state.cursor = { 40, 40 }
    tick(1 / 60)
    A.ok(overs >= 1, "A moving pointer skipped bubble hover")
end)

h.test("A still, settled chat runs its full pass at most every 0.1 s and still answers focus at once", function(t)
    local A, mock, ns = t.assert, t.mock, t.ns
    t.boot()
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function tick(elapsed) events._scripts.OnUpdate(events, elapsed) end
    ChatFrame1:AddMessage("settled chat line", 1, 1, 1)
    -- Tabs fade out over 0.3 s of frame time.
    for _ = 1, 30 do tick(1 / 60) end
    mock:advance(0.5)
    tick(1 / 60)
    local eases = 0
    local ease = ns.EaseAlpha
    ns.EaseAlpha = function(...)
        eases = eases + 1
        return ease(...)
    end
    -- The clock does not move: every frame lands inside the calm window.
    for _ = 1, 5 do tick(1 / 60) end
    A.eq(eases, 0, "A still, settled chat eased its tabs and input every frame")
    mock:advance(0.11)
    tick(1 / 60)
    A.ok(eases > 0, "The periodic chat pass stopped running")
    tick(1 / 60)
    local edit = ChatFrame1EditBox
    local before = edit:GetAlpha()
    edit:SetFocus()
    edit._scripts.OnEditFocusGained(edit)
    tick(1 / 60)
    A.ok(edit:GetAlpha() > before, "A focused input waited for the calm window to end")
end)
