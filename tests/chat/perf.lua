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
