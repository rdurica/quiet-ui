local _, ns = ...
local Setup = ns.Setup

-- A button whose click may end in /reload. ReloadUI from addon code is blocked on this client, so the reload is a
-- secure /reload macro, armed in PreClick at the moment of the click and only out of combat: nothing stays armed
-- that a later combat could leave running with nothing saved. PostClick disarms it again.
-- run() does the click's work and returns handled, wantsReload; after(reloading) runs in PostClick when handled.
function Setup.ReloadButton(parent, text, run, after)
    local button = Setup.Button(parent, text, nil, "SecureActionButtonTemplate")
    if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("AnyUp", "AnyDown") end
    button:SetScript("PreClick", function()
        local handled, wants = run()
        button.handled = handled
        button.reloading = (handled and wants and not InCombatLockdown()) or false
        if InCombatLockdown() then return end
        button:SetAttribute("macrotext", "/reload")
        button:SetAttribute("type", button.reloading and "macro" or nil)
    end)
    button:SetScript("PostClick", function()
        local handled, reloading = button.handled, button.reloading
        button.handled, button.reloading = nil, nil
        if reloading and not InCombatLockdown() then button:SetAttribute("type", nil) end
        if handled and after then after(reloading) end
    end)
    return button
end
