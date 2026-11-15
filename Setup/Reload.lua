local _, ns = ...
local Setup = ns.Setup

-- A button whose click may end in /reload. ReloadUI from addon code is blocked on this client, so the reload is a
-- secure /reload macro, armed in PreClick at the moment of the click and only out of combat: nothing stays armed
-- that a later combat could leave running with nothing saved. PostClick disarms it again.
-- The template acts on one event of a physical click only (the press with ActionButtonUseKeyDown, else the
-- release), but both reach PreClick and PostClick, so only that event is handled: the other would see the work
-- already done and disarm nothing it armed.
-- run() does the click's work and returns handled, wantsReload; after(reloading) runs in PostClick when handled.
local function Acts(down)
    local keyDown = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown") or false
    return (down and true or false) == (keyDown and true or false)
end

function Setup.ReloadButton(parent, text, run, after)
    local button = Setup.Button(parent, text, nil, "SecureActionButtonTemplate")
    if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("AnyUp", "AnyDown") end
    button:SetScript("PreClick", function(_, _, down)
        if not Acts(down) then return end
        local handled, wants = run()
        button.handled = handled
        button.reloading = (handled and wants and not InCombatLockdown()) or false
        if InCombatLockdown() then return end
        button:SetAttribute("macrotext", "/reload")
        button:SetAttribute("type", button.reloading and "macro" or nil)
    end)
    button:SetScript("PostClick", function(_, _, down)
        if not Acts(down) then return end
        local handled, reloading = button.handled, button.reloading
        button.handled, button.reloading = nil, nil
        if reloading and not InCombatLockdown() then button:SetAttribute("type", nil) end
        if handled and after then after(reloading) end
    end)
    return button
end
