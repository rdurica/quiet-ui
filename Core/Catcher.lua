local _, ns = ...

-- Hover catchers: invisible frames that see the mouse over a bar, a menu or a tracker.

local Catcher = {}
ns.Catcher = Catcher

-- Motion without clicks. A catcher can sit under buttons and still see empty slots.
function Catcher.Arm(frame)
    if not frame then return end
    local motion = false
    if type(frame.SetMouseMotionEnabled) == "function" then
        motion = pcall(frame.SetMouseMotionEnabled, frame, true)
    end
    if type(frame.SetMouseClickEnabled) == "function" then
        pcall(frame.SetMouseClickEnabled, frame, false)
    end
    if motion then return end
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if type(frame.SetPassThroughButtons) == "function" then
        pcall(frame.SetPassThroughButtons, frame, "LeftButton", "RightButton")
    end
end

-- A hidden armed frame, or nil when frames cannot be created.
function Catcher.Create()
    local ok, box = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not box then return end
    Catcher.Arm(box)
    box:Hide()
    return box
end

-- Follow the strata of the frame the catcher covers.
function Catcher.Strata(box, source)
    local strata = source.GetFrameStrata and source:GetFrameStrata()
    if type(strata) == "string" and not ns.IsSecret(strata) and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
end

function Catcher.Level(box, level)
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
end
