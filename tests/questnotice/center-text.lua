-- The default center-screen quest text is dropped only while quest updates are on.
local h = ...
local Q = h.lib("questnotice")

h.test("center quest text is dropped only while notices are on", function(t)
    Q.fixture(t.mock, t.ns)
    local shown, registered = {}, { UI_INFO_MESSAGE = true, UI_ERROR_MESSAGE = true }
    UIErrorsFrame = {
        RegisterEvent = function(_, event) registered[event] = true end,
        UnregisterEvent = function(_, event) registered[event] = nil end,
        GetScript = function()
            return function(_, _, messageType, message) shown[#shown + 1] = messageType .. ":" .. tostring(message) end
        end,
    }
    t.ns.ApplyQuestNotice()
    local proxy
    for _, f in ipairs(t.mock.frames) do
        if f._events.UI_INFO_MESSAGE and f._scripts.OnEvent then proxy = f end
    end
    t.assert.ok(proxy, "Center filter must listen for info messages")
    t.assert.ok(not registered.UI_INFO_MESSAGE and not registered.UI_ERROR_MESSAGE,
        "Default error frame must release these events")
    local function saw(kind) return table.concat(shown, "|"):find(kind .. ":", 1, true) end
    local function send(event, ...) proxy._scripts.OnEvent(proxy, event, ...) end
    send("UI_INFO_MESSAGE", 305, "Wolves slain: 1/8")
    send("UI_INFO_MESSAGE", 179, "Quest accepted: Bears")
    send("UI_INFO_MESSAGE", 180, "Bears completed.")
    send("UI_INFO_MESSAGE", 196, "Experience gained: 100")
    send("UI_INFO_MESSAGE", 50, "Not enough mana")
    send("UI_ERROR_MESSAGE", 181, "Quest failed")
    t.assert.ok(not saw(305) and not saw(179) and not saw(180),
        "Quest progress, acceptance and completion must leave the center")
    t.assert.ok(saw(196) and saw(50) and saw(181), "Rewards, other info and quest failures must stay")
    QuietUICharDB.questNotice = false
    send("UI_INFO_MESSAGE", 305, "Wolves slain: 2/8")
    t.assert.ok(saw(305), "Notices off must restore center quest text")
    t.ns.RestoreQuestNotice()
    t.assert.ok(registered.UI_INFO_MESSAGE and registered.UI_ERROR_MESSAGE,
        "Disable must return events to the error frame")
    t.assert.ok(not proxy._events.UI_INFO_MESSAGE, "Disable must stop the filter")
end)
