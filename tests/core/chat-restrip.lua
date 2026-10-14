-- Blizzard chat hooks restrip only what changed: one window, or windows not yet stripped.
local h = ...

-- Counts HideTextures per chat window and Mute of the shared chrome, passing both through.
local function watchStripping(ns)
    local w = { stripped = {}, chrome = 0 }
    local hide, mute = ns.HideTextures, ns.Mute
    ns.HideTextures = function(target, ...)
        local name = type(target) == "table" and target.GetName and target:GetName()
        if name and name:find("^ChatFrame%d+$") then w.stripped[name] = (w.stripped[name] or 0) + 1 end
        return hide(target, ...)
    end
    ns.Mute = function(target, ...)
        if target == ChatFrameMenuButton then w.chrome = w.chrome + 1 end
        return mute(target, ...)
    end
    return w
end

local function reset(w) w.stripped, w.chrome = {}, 0 end

local function booted(t)
    local w = watchStripping(t.ns)
    t.boot()
    return w
end

h.test("FCF_SetWindowColor restrips only the passed chat frame", function(t)
    local A = t.assert
    local w = booted(t)
    A.ok((w.stripped.ChatFrame1 or 0) >= 1 and (w.stripped.ChatFrame3 or 0) >= 1, "login did not strip chat")
    reset(w)
    FCF_SetWindowColor(ChatFrame3, 0, 0, 0)
    A.eq(w.stripped.ChatFrame3, 1, "ChatFrame3 restripped")
    for i = 1, 10 do
        if i ~= 3 then A.eq(w.stripped["ChatFrame" .. i], nil, "ChatFrame" .. i .. " reprocessed") end
    end
    A.eq(w.chrome, 0, "chat chrome muted again")
end)

h.test("FCF_SetWindowColor ignores windows outside ChatCount", function(t)
    local A = t.assert
    local w = booted(t)
    local whisper = CreateFrame("Frame", "ChatFrame11", UIParent)
    ChatFrame11 = whisper
    reset(w)
    FCF_SetWindowColor(whisper, 0, 0, 0)
    A.eq(w.stripped.ChatFrame11, nil, "a window RestoreChat cannot reach was stripped")
end)

h.test("FCF_DockUpdate strips only windows not yet stripped", function(t)
    local A = t.assert
    local w = booted(t)
    -- No public way to add an unstripped window; clear the mark Blizzard's own rebuild would leave.
    ChatFrame2._quietStripped = nil
    reset(w)
    FCF_DockUpdate()
    A.eq(w.stripped.ChatFrame2, 1, "new window ChatFrame2 stripped")
    for i = 1, 10 do
        if i ~= 2 then A.eq(w.stripped["ChatFrame" .. i], nil, "stripped ChatFrame" .. i .. " forced again") end
    end
    A.eq(w.chrome, 0, "chat chrome muted again")
end)
