local _, ns = ...

local Glance = ns.Glance

-- A default on the header binding is stored as HEADER_QUIETUI, so ` does nothing.
-- Take that key, or a free `, for QUIETUI_GLANCE. Leave any other action alone.
function Glance.EnsureBinding()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
    if type(GetBindingAction) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local ok, existing = pcall(GetBindingKey, "QUIETUI_GLANCE")
    if ok and type(existing) == "string" and existing ~= "" then return end
    local actionOk, action = pcall(GetBindingAction, "`")
    if not actionOk or type(action) ~= "string" then return end
    if action ~= "" and action ~= "HEADER_QUIETUI" then return end
    local setOk, bound = pcall(SetBinding, "`", "QUIETUI_GLANCE")
    if not setOk or not bound then return end
    if type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then return end
    local setOk2, set = pcall(GetCurrentBindingSet)
    if setOk2 and type(set) == "number" then
        pcall(SaveBindings, set)
    end
end

ns.Feature({
    name = "glance",
    restore = function() Glance.state.active = false end,
})
