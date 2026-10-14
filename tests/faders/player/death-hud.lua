-- Player death changes only the portrait: bars, menu, bag, chat, meter, party and the other
-- fader targets keep their rendered alpha through the real per-frame update paths.
local h = ...
local P = h.lib("player")

local function serialize(lines) return table.concat(lines or {}, "\n") end

for _, trigger in ipairs({ "quiet", "InCombat", "InForcedInstance", "InGroup", "hover" }) do
    h.test("Player death leaves other HUD unchanged during " .. trigger, function(t)
        local A = t.assert
        local ns = t.ns
        local s = P.env(t)
        ns.ShowAll = function() return s.InCombat or s.InForcedInstance or s.InVehicle or s.InEditMode or false end
        ns.XPForced = function() return false end
        CharacterMicroButton = CreateFrame("Button", "CharacterMicroButton", UIParent)
        ChatFrame1:AddMessage("Existing message")
        ChatFrame1EditBox:SetFocus()
        QuietUICharDB.autoHideParty = true
        ns.RefreshChrome()
        local bag
        for _, f in ipairs(t.mock.frames) do
            if f._scripts.OnDragStart then bag = f end
        end
        A.ok(bag, "Fixture must create the actual bag button")
        if trigger == "hover" then
            MainActionBar.hot, CharacterMicroButton.hot, bag.hot = true, true, true
        elseif trigger ~= "quiet" then s[trigger] = true end
        ns.RefreshWorld()
        local function hudTick()
            s.tick()
            ns.UpdateBars(ns.ShowAll(), 0.3, true)
            ns.UpdateFaders(0.3)
            ns.UpdateMenuButton(0.3)
            ns.UpdateChat(0.3)
        end
        hudTick()
        local tracked = { TargetFrame, MainActionBar, StatusTrackingBarManager, EssentialCooldownViewer,
            DamageMeter, PartyFrame, ObjectiveTrackerFrame, bag, CharacterMicroButton, ChatFrame1, ChatFrame1EditBox }
        local before = {}
        for i, obj in ipairs(tracked) do before[i] = P.effective(obj) end
        local messages = serialize(ChatFrame1._lines)
        for _, life in ipairs({ "dead", "ghost" }) do
            s.life = life
            ns.RefreshWorld()
            hudTick()
            for i, obj in ipairs(tracked) do
                A.eq(P.effective(obj), before[i], "Death changed HUD frame " .. tostring(obj._name or i))
            end
            A.eq(serialize(ChatFrame1._lines), messages, "Death changed chat text/history")
        end
        A.eq(#s.reports, 0, "HUD fixture must not mask failed update paths: " .. table.concat(s.reports, "; "))
    end)
end
