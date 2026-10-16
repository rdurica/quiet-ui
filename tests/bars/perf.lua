-- Idle ticks of the bars: rebuild only on a child-count change, swing scan throttling.
local h = ...

-- One real OnUpdate tick of the addon's event frame.
local function tick(t, elapsed)
    local f = t.mock:eventFrame("PLAYER_LOGIN")
    f._scripts.OnUpdate(f, elapsed)
end

-- The gamepad bar reads its buttons through GetChildren only when the button lists are
-- rebuilt, so that call count shows how often the bar buttons are collected.
local function gamepadBar(t)
    local bar = CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
    _G.GamepadMainActionBarFrame = bar
    CreateFrame("Button", nil, bar)
    return bar
end

local function walks(bar) return bar._calls.GetChildren or 0 end

h.test("Periodic bar refresh waits for a child-count change", function(t)
    local A = t.assert
    local bar = gamepadBar(t)
    t.boot()
    tick(t, 1)
    tick(t, 1)
    local before = walks(bar)
    tick(t, 1)
    tick(t, 1)
    A.eq(walks(bar) - before, 0, "Stable bars still rebuilt the bar buttons")
    CreateFrame("Button", nil, bar)
    tick(t, 1)
    tick(t, 1)
    A.eq(walks(bar) - before, 1, "A new child did not rebuild bar buttons")
    A.eq(#t.mock.printed, 0, "Idle tick reported: " .. table.concat(t.mock.printed, "; "))
end)

h.test("Missing child counts rebuild on a five second fallback", function(t)
    local A = t.assert
    local bar = gamepadBar(t)
    bar.GetNumChildren = false
    t.boot()
    tick(t, 1)
    tick(t, 1)
    local before = walks(bar)
    A.eq(walks(bar) - before, 0, "Missing GetNumChildren rebuilt bars before five seconds")
    t.mock.now = t.mock.now + 5
    tick(t, 1)
    tick(t, 1)
    A.eq(walks(bar) - before, 1, "Five second fallback did not rebuild bars")
end)

local function uiWalks(t) return UIParent._calls.GetChildren or 0 end

h.test("Swing scan skips debug names on named frames and keeps a found timer", function(t)
    local A = t.assert
    local named, namedAsked = {}, 0
    for _, child in ipairs(UIParent._children) do
        if child:GetName() then
            named[#named + 1] = child
            child.GetDebugName = function()
                namedAsked = namedAsked + 1
                return "ignored"
            end
        end
    end
    A.ok(#named > 0, "precondition: named frames under UIParent")
    local anon = CreateFrame("Frame", nil, UIParent)
    local debugs = 0
    anon.GetDebugName = function()
        debugs = debugs + 1
        return "OffHandSwingTimer"
    end
    t.mock.now = 50
    local before = uiWalks(t)
    t.ns.Bars.ScanSwing()
    A.eq(debugs, 1, "Anonymous swing frame was not identified")
    A.eq(namedAsked, 0, "Named frames must not ask for a debug name")
    A.eq(uiWalks(t) - before, 1, "The first scan did not walk UIParent")
    t.ns.Bars.ScanSwing()
    A.ok(uiWalks(t) - before == 1 and debugs == 1, "A live swing timer was scanned again inside 10s")
end)

h.test("No swing timer waits 10s before the next UIParent walk", function(t)
    local A = t.assert
    t.mock.now = 100
    local before = uiWalks(t)
    t.ns.Bars.ScanSwing()
    t.mock.now = 101
    t.ns.Bars.ScanSwing()
    A.eq(uiWalks(t) - before, 1, "UIParent was walked again inside 10s without a swing timer")
    t.mock.now = 111
    t.ns.Bars.ScanSwing()
    A.eq(uiWalks(t) - before, 2, "The 10s fallback walk did not run")
end)

-- Hovering runs a bars pass every frame. Once every bar sits at its target alpha and nothing
-- changed, a pass skips the bar walk; a change applies at once and a full pass still runs every 0.2 s.
h.test("Settled bars skip the per-frame walk, react to a change at once and recheck every 0.2 s", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar = CreateFrame("Frame", "MultiBarBottomLeft", UIParent)
    _G.MultiBarBottomLeft = bar
    t.boot()
    ns.Hit = function() return false end
    local function pass(showAll, elapsed)
        ns.NextFadeTick()
        ns.Bars.Update(showAll, elapsed or 1 / 60, false)
    end
    ns.Bars.ForgetButtons()
    for _ = 1, 3 do pass(false, 1) end
    A.eq(bar._alpha, 0, "precondition: the bar faded out")
    local faded = 0
    local update = ns.UpdateFaded
    ns.UpdateFaded = function(...) faded = faded + 1; return update(...) end
    for _ = 1, 10 do pass(false) end
    A.eq(faded, 0, "a settled pass does not walk the bars")
    pass(true)
    A.eq(bar._alpha, 1, "a show change applies at once")
    faded = 0
    for _ = 1, 10 do pass(true) end
    A.eq(faded, 0, "settled again once shown")
    mock.now = mock.now + 0.25
    pass(true)
    A.ok(faded > 0, "a full pass runs again after 0.2 s")
    ns.UpdateFaded = update
end)
