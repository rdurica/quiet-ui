local _, ns = ...

-- Press Glance to show the faded HUD. Press again and the rules apply.
-- The binding system calls a global; down and up both arrive.

ns.Glance = ns.Glance or {}
local Glance = ns.Glance
Glance.state = { active = false }

BINDING_CATEGORY_QUIETUI = "QuietUI"
BINDING_NAME_QUIETUI_GLANCE = "Glance"

function Glance.Toggle()
    if not ns.DB().enabled then return end
    Glance.state.active = not Glance.state.active
end

function QuietUIGlance(keystate)
    if keystate == "down" then Glance.Toggle() end
end

function Glance.Active()
    return Glance.state.active
end
