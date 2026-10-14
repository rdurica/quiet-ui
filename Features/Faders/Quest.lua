local _, ns = ...
local Faders = ns.Faders

local questFrames = Faders.state.questFrames

-- The tracker container is not mouse-enabled, so the gaps between quests are
-- not hover. This frame is not its child: a faded parent would drop the mouse.
local questCatcher
local questCatcherTarget

local function ShownQuest()
    for i = 1, #questFrames do
        local frame = questFrames[i]
        if ns.Usable(frame) and frame:IsShown() then
            return frame
        end
    end
end

local function EnsureQuestCatcher()
    if questCatcher then return questCatcher end
    local created = ns.Catcher.Create()
    if not created then return end
    questCatcher = created
    return created
end

function Faders.PlaceQuestCatcher()
    local box = EnsureQuestCatcher()
    if not box then return end
    local target = ShownQuest()
    if not target or ns.World.InEditMode() or not ns.DB().enabled then
        box:Hide()
        questCatcherTarget = nil
        return
    end
    if questCatcherTarget ~= target then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(target)
        questCatcherTarget = target
        -- SetParent can move strata and level, so write them again.
        box._quietStrata, box._quietLevel = nil, nil
    end
    ns.Catcher.Strata(box, target)
    local level = target.GetFrameLevel and target:GetFrameLevel() or 1
    if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
    ns.Catcher.Level(box, math.max(level - 1, 0))
    if not box:IsShown() then box:Show() end
end

function Faders.QuestTrackerHovered()
    return questCatcher and ns.Hit(questCatcher) or false
end

function Faders.HideQuestCatcher()
    if not questCatcher then return end
    questCatcher:Hide()
    questCatcherTarget = nil
end
