-- Party and raid autohide: priorities, discovery of replaced roots, selection highlights.
local h = ...

local function frame(parent) return CreateFrame("Frame", nil, parent) end
-- Listed among the parent's regions only, not its children.
local function region(parent)
    local r = frame(parent)
    parent._children[#parent._children] = nil
    parent._regions[#parent._regions + 1] = r
    return r
end

h.test("Party autohide keeps combat, instance and explicit reveal priorities", function(t)
    local ns, A = t.ns, t.assert
    PartyFrame = frame(UIParent)
    PartyFrame._alpha = 0.6
    CompactRaidFrameContainer = frame(PartyFrame)
    CompactRaidFrameContainer._alpha = 0.8
    PartyMemberFrame1 = frame(PartyFrame)
    PartyMemberFrame1._alpha = 0.7
    CompactPartyFrameContainer = frame(UIParent)
    CompactPartyFrameContainer._alpha = 0.9
    local catchers = {}
    local create = CreateFrame
    CreateFrame = function(...)
        local box = create(...)
        function box:SetMouseMotionEnabled(value) self.motion = value end
        function box:SetMouseClickEnabled(value) self.clicks = value end
        catchers[#catchers + 1] = box
        return box
    end
    ns.Hit = function(obj) return obj and obj.hot == true end
    ns.Faders.Find(false)
    ns.Faders.UpdateParty(1)
    A.alpha(PartyFrame, 0.6, "Default settings must leave Blizzard alpha untouched")
    A.falsy(PartyFrame._quietAlphaHook, "Default settings must not hook alpha")
    A.eq(#catchers, 0, "Always visible needs no hover catcher")
    QuietUICharDB.autoHideParty = true
    ns.Faders.Find(false)
    ns.World.InGroup = function() return true end
    ns.World.HasTarget = function() return true end
    ns.Faders.UpdateParty(0.1)
    A.ok(PartyFrame._alpha > 0 and PartyFrame._alpha < 0.6, "Hide must fade, not disappear immediately")
    ns.Faders.UpdateParty(0.3)
    A.ok(PartyFrame._alpha == 0 and CompactPartyFrameContainer._alpha == 0,
        "Group membership and target must not reveal party frames")
    A.ok(CompactRaidFrameContainer._alpha == 0.8 and PartyMemberFrame1._alpha == 0.7,
        "Nested frames must inherit their parent fade without being faded twice")
    A.ok(#catchers == 2 and catchers[1]._parent == UIParent)
    for _, box in ipairs(catchers) do
        A.ok(box.motion and box.clicks == false, "Hover catcher must not intercept clicks")
    end
    catchers[1].hot = true
    ns.Faders.UpdateParty(0)
    A.ok(PartyFrame._alpha == 1 and CompactPartyFrameContainer._alpha == 1,
        "Hover over a hidden block must reveal all members immediately")
    catchers[1].hot = false
    for _, trigger in ipairs({ "InCombat", "InForcedInstance", "Glancing", "InEditMode" }) do
        local owner = trigger == "Glancing" and ns.Glance or ns.World
        local field = trigger == "Glancing" and "Active" or trigger
        ns.Faders.UpdateParty(1)
        A.eq(PartyFrame._alpha, 0)
        owner[field] = function() return true end
        ns.Faders.UpdateParty(0)
        A.ok(PartyFrame._alpha == 1 and CompactPartyFrameContainer._alpha == 1,
            trigger .. " must reveal immediately")
        owner[field] = function() return false end
    end
    ns.Faders.UpdateParty(1)
    PartyFrame:SetAlpha(1)
    A.eq(PartyFrame._alpha, 0, "Blizzard writes must not override autohide")
    QuietUICharDB.autoHideParty = nil
    ns.Faders.UpdateParty(0)
    A.ok(PartyFrame._alpha == 0.6 and CompactPartyFrameContainer._alpha == 0.9,
        "Always visible must restore original alpha")
    for _, box in ipairs(catchers) do A.falsy(box._shown, "Always visible must hide catchers") end
    PartyFrame:SetAlpha(0.75)
    A.eq(PartyFrame._alpha, 0.75, "Always visible must release the alpha hook")
    QuietUICharDB.autoHideParty = true
    ns.Faders.UpdateParty(1)
    ns.Faders.HideHoverCatchers()
    QuietUIDB.enabled = false
    ns.Faders.UpdateParty(0)
    ns.RestoreAlpha()
    A.ok(PartyFrame._alpha == 0.75 and CompactPartyFrameContainer._alpha == 0.9,
        "Disable must restore alpha captured when autohide was re-enabled")
    for _, box in ipairs(catchers) do A.falsy(box._shown, "Disable must hide catchers") end
    PartyFrame:SetAlpha(0.85)
    QuietUIDB.enabled = true
    ns.Faders.UpdateParty(1)
    QuietUICharDB.autoHideParty = nil
    ns.Faders.UpdateParty(0)
    A.eq(PartyFrame._alpha, 0.85, "Re-enabling must capture changes made while the addon was off")
end)

h.test("Party frame discovery releases replaced roots and skips forbidden frames", function(t)
    local ns, A = t.ns, t.assert
    ns.World.InGroup = function() return true end
    QuietUICharDB.autoHideParty = true
    ns.Hit = function() return false end
    PartyFrame = frame(UIParent)
    ns.Faders.Find(false); ns.Faders.UpdateParty(1)
    local old = PartyFrame
    PartyFrame = frame(UIParent)
    PartyFrame._alpha = 0.7
    ns.Faders.Find(false); ns.Faders.UpdateParty(1)
    A.ok(old._alpha == 1 and old._quietAlpha == nil, "Replacing a container must release the old root")
    A.eq(PartyFrame._alpha, 0, "Newly discovered frames must follow autohide")
    local container = frame(UIParent)
    PartyFrame._parent = container
    CompactPartyFrameContainer = container
    CompactRaidFrameContainer = frame(UIParent)
    function CompactRaidFrameContainer:IsForbidden() return true end
    function CompactRaidFrameContainer:IsShown() error("Forbidden frame accessed") end
    ns.Faders.Find(false); ns.Faders.UpdateParty(1)
    A.ok(PartyFrame._alpha == 0.7 and PartyFrame._quietAlpha == nil,
        "Newly nested frames must stop independent fading")
    A.eq(container._alpha, 0, "The outer container must own the fade")
    local forbiddenReads = 0
    function container:IsForbidden() return true end
    function container:SetAlpha() forbiddenReads = forbiddenReads + 1; error("Forbidden alpha write") end
    ns.Faders.Find(false)
    A.eq(forbiddenReads, 0, "Formerly managed forbidden frames must be released without calling methods")
    ns.RestoreAlpha()
    A.eq(PartyFrame._alpha, 0.7, "Disable must not overwrite a released child")
end)

h.test("Party selection highlights and independent indicators fade with their block", function(t)
    local ns, A = t.ns, t.assert
    ns.World.InGroup = function() return true end
    QuietUICharDB.autoHideParty = true
    ns.Hit = function() return false end
    PartyFrame = frame(UIParent)
    local unit = frame(PartyFrame)
    local highlight = region(unit)
    highlight._alpha = 0.8
    highlight.IsIgnoringParentAlpha = false -- a plain highlight region lacks the method
    unit.selectionHighlight = highlight
    local ready = frame(unit)
    function ready:IsIgnoringParentAlpha() return true end
    local icon = region(ready)
    function icon:IsIgnoringParentAlpha() return true end
    local health = frame(unit)
    health._alpha = 0.5
    ns.Faders.Find(false)
    ns.Faders.UpdateParty(1)
    A.ok(PartyFrame._alpha == 0 and highlight._alpha == 0 and ready._alpha == 0 and icon._alpha == 0,
        "Independent selection and ready-check indicators must disappear with the container")
    A.ok(health._alpha == 0.5 and not health._quietAlphaHook, "Ordinary children must inherit container alpha")
    highlight:SetAlpha(1)
    A.eq(highlight._alpha, 0, "A Blizzard selection update must not reveal the hidden highlight")
    ns.Glance.Active = function() return true end
    ns.Faders.UpdateParty(0)
    A.ok(highlight._alpha == 1 and ready._alpha == 1 and icon._alpha == 1,
        "Glance must restore independent indicators")
    ns.Glance.Active = function() return false end
    ns.Faders.UpdateParty(1)
    ns.World.InCombat = function() return true end
    ns.Faders.UpdateParty(0)
    A.ok(highlight._alpha == 1 and ready._alpha == 1, "Combat must reveal independent indicators immediately")
    QuietUICharDB.autoHideParty = nil
    ns.Faders.UpdateParty(0)
    A.ok(highlight._alpha == 0.8 and highlight._quietAlpha == nil and icon._alpha == 1,
        "Always visible must restore the original indicator alpha")
end)
