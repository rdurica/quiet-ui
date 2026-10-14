local _, ns = ...

-- Lifecycle, events and the per-frame update, and the feature registration.

local Q = ns.QuestNotice
local S = Q.state

local function ClearNotice()
    S.snapshots, S.accepted, S.acceptedShown, S.queue = {}, {}, {}, {}
    S.current, S.baseline, S.dirty, S.hoverDismissed = nil, false, false, false
    Q.Hide()
end

local function Reset()
    ClearNotice()
    S.dirty, S.retryUntil, S.retryAt = true, S.clock + 10, S.clock
end

local function Sync()
    local on = Q.Enabled()
    if on == S.noticesOn then return on end
    S.noticesOn = on
    if on then Reset() else ClearNotice() end
    return on
end

function Q.Apply()
    S.active = true
    Sync()
    Q.InstallCenterFilter()
end

function Q.Restore()
    S.active = false
    S.noticesOn = nil
    ClearNotice()
    Q.ReleaseCenterEvents()
end

function Q.Event(event, first, second)
    if not S.active or not Sync() then return end
    if event == "PLAYER_ENTERING_WORLD" then Reset(); return end
    if event ~= "QUEST_ACCEPTED" and event ~= "QUEST_LOG_UPDATE" and event ~= "QUEST_WATCH_UPDATE" then return end
    if event == "QUEST_ACCEPTED" then
        local id
        if not Q.Secret(second) then id = second end
        if id == nil and not Q.Secret(first) then id = first end
        if Q.Number(id) and id > 0 and not S.acceptedShown[id] then S.accepted[id] = S.clock + 10 end
    end
    S.dirty, S.retryUntil, S.retryAt = true, S.clock + 10, S.clock
end

function Q.Update(elapsed)
    if not S.active then return end
    elapsed = elapsed or 0
    S.clock = S.clock + elapsed
    if not Sync() then return end
    if S.dirty and S.clock >= S.retryAt then
        local settled = Q.ReadChanges()
        S.dirty = not settled and S.clock < S.retryUntil
        S.retryAt = S.clock + 0.2
    end
    if not S.current then Q.Hide(); return end
    if Q.AreaHover() then
        if not S.hoverDismissed then
            S.current = table.remove(S.queue, 1)
            S.drawn, S.drawnWidth = nil, nil
            S.hoverDismissed = true
        end
        Q.Hide()
        return
    end
    S.hoverDismissed = false
    S.current.age = S.current.age + elapsed
    if S.current.age >= 5.3 then
        S.current = table.remove(S.queue, 1)
        if not S.current then Q.Hide(); return end
    end
    Q.Draw(S.current.age <= 5 and 1 or math.max(0, 1 - (S.current.age - 5) / 0.3))
end

local function Forward(event)
    return function(...)
        if type(Q.Event) == "function" then Q.Event(event, ...) end
    end
end

ns.Feature({
    name = "quest notice",
    apply = function() if type(Q.Apply) == "function" then Q.Apply() end end,
    restore = function() if type(Q.Restore) == "function" then Q.Restore() end end,
    frame = function(elapsed) if type(Q.Update) == "function" then Q.Update(elapsed) end end,
    events = {
        PLAYER_ENTERING_WORLD = Forward("PLAYER_ENTERING_WORLD"),
        QUEST_ACCEPTED = Forward("QUEST_ACCEPTED"),
        QUEST_LOG_UPDATE = Forward("QUEST_LOG_UPDATE"),
        QUEST_WATCH_UPDATE = Forward("QUEST_WATCH_UPDATE"),
    },
})
