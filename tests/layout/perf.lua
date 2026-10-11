-- Layout retry: idle ticks stay quiet; an open preview keeps retrying.
local h = ...

h.test("Layout retry stays idle without a pending layout or preview", function(t)
    local A, mock = t.assert, t.mock
    local applied = 0
    local real = C_EditMode.SetActiveLayout
    C_EditMode.SetActiveLayout = function(...)
        applied = applied + 1
        return real(...)
    end
    mock.state.cursor = { 4, 4 }
    t.boot()
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function tick(elapsed) events._scripts.OnUpdate(events, elapsed) end
    local before = applied
    tick(0.2)
    tick(0.2)
    A.eq(applied - before, 0, "Idle ticks still ran layout preview")
    -- A preview the client has not applied yet is retried on the next slow tick.
    t.ns.PreviewLayout({ builtin = 2 })
    A.ok(t.ns.LayoutPreviewActive(), "precondition: the preview is open")
    before = applied
    tick(0.2)
    A.eq(applied - before, 1, "An open preview did not keep retrying")
end)
