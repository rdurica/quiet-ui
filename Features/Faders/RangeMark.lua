local _, ns = ...
local Faders = ns.Faders

-- A green gradient over the target nameplate health bar. A flat tint turns the red bar grey. Secret results are left as they were.
-- Strong on the left, fading out to the right, so the health bar still reads.
local rangeMark

local function EnsureRangeMark()
    if rangeMark then return rangeMark end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    local tex = created:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 1, 1, 1)
    local painted = false
    if type(CreateColor) == "function" and type(tex.SetGradient) == "function" then
        local gradientOk = pcall(tex.SetGradient, tex, "HORIZONTAL",
            CreateColor(0.15, 0.82, 0.22, 0.9),
            CreateColor(0.55, 0.95, 0.4, 0.15))
        painted = gradientOk
    end
    if not painted and type(tex.SetGradientAlpha) == "function" then
        painted = pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", 0.15, 0.82, 0.22, 0.9, 0.55, 0.95, 0.4, 0.15)
    end
    if not painted then
        tex:SetColorTexture(0.2, 0.78, 0.28, 0.75)
    end
    created:EnableMouse(false)
    if type(created.SetMouseClickEnabled) == "function" then
        pcall(created.SetMouseClickEnabled, created, false)
    end
    if type(created.SetMouseMotionEnabled) == "function" then
        pcall(created.SetMouseMotionEnabled, created, false)
    end
    created:SetAlpha(0)
    created._quietAlpha = 0
    created:Hide()
    rangeMark = created
    return created
end

function Faders.HideRangeMark()
    if not rangeMark then return end
    rangeMark._quietAlpha = 0
    rangeMark._quietSecret = nil
    rangeMark._quietApplying = true
    rangeMark:SetAlpha(0)
    rangeMark._quietApplying = false
    rangeMark:Hide()
    local parentOk, parent = pcall(rangeMark.GetParent, rangeMark)
    if not parentOk or parent ~= UIParent then
        pcall(rangeMark.SetParent, rangeMark, UIParent)
    end
end

-- The visible bar, when the nameplate root is only the click area.
-- Nameplate GetRect is empty or in world scale, so the gradient is a child of the
-- health bar and is moved back to UIParent when it hides. The plate's alpha is left alone.
local function ShownBox(frame)
    if not ns.Usable(frame) or not frame.IsShown then return nil end
    local shownOk, shown = pcall(frame.IsShown, frame)
    if not shownOk or not shown then return nil end
    return frame
end

-- A health bar is wide and short. The nameplate click area is tall, and that box is what irritates.
local function BarArea(frame)
    if not ShownBox(frame) or not frame.GetWidth or not frame.GetHeight then return nil end
    local widthOk, width = pcall(frame.GetWidth, frame)
    local heightOk, height = pcall(frame.GetHeight, frame)
    if not widthOk or not heightOk then return nil end
    if not Faders.PlainNumber(width) or not Faders.PlainNumber(height) then return nil end
    if width < 40 or width > 320 or height < 4 or height > 20 then return nil end
    return width * height
end

local function ChildrenOf(frame)
    if not ns.Usable(frame) or not frame.GetChildren then return nil end
    local ok, list = pcall(function() return { frame:GetChildren() } end)
    if ok then return list end
end

local function TightestBar(root)
    local best, bestArea
    local function visit(frame, depth)
        if not frame or depth > 5 then return end
        local area = BarArea(frame)
        if area and (not bestArea or area < bestArea) then
            best, bestArea = frame, area
        end
        local list = ChildrenOf(frame)
        if not list then return end
        for i = 1, #list do
            visit(list[i], depth + 1)
        end
    end
    visit(root, 0)
    return best
end

-- The last found bar, kept while the target keeps the same plate.
local cachedPlate, cachedUnit, cachedBar

function Faders.ForgetRangePlate()
    cachedPlate, cachedUnit, cachedBar = nil, nil, nil
end

local function PlateUnit(plate)
    return plate.UnitFrame or plate.unitFrame or plate
end

local function TargetPlate()
    local finder = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if type(finder) ~= "function" then finder = GetNamePlateForUnit end
    if type(finder) ~= "function" then
        ns.Report("range nameplate", "GetNamePlateForUnit missing")
        return nil
    end
    local ok, plate = pcall(finder, "target")
    if not ok or not ns.Usable(plate) then return nil end
    if cachedBar and cachedPlate == plate and ShownBox(cachedUnit) and ShownBox(cachedBar) then
        return cachedBar, plate
    end
    cachedPlate, cachedUnit, cachedBar = nil, nil, nil
    local unitOk, unit = pcall(PlateUnit, plate)
    if not unitOk or not ShownBox(unit) then return nil end
    local namedOk, named = pcall(function()
        return unit.healthBar or unit.HealthBar or unit.HealthBarsContainer
    end)
    local bar
    if namedOk and named then
        if BarArea(named) then
            bar = named
        else
            bar = TightestBar(named)
        end
    end
    bar = bar or TightestBar(unit)
    if not bar then return nil end
    cachedPlate, cachedUnit, cachedBar = plate, unit, bar
    return bar, plate
end

-- true when placed, false when the nameplate is gone.
-- The gradient fills the health bar. Parenting to the plate would cover the name too.
local function PlaceRangeMark(mark)
    local bar = TargetPlate()
    if not bar then return false end
    local parentOk, parent = pcall(mark.GetParent, mark)
    if parentOk and parent == bar then return true end
    local moved = pcall(function()
        mark:SetParent(bar)
        mark:ClearAllPoints()
        mark:SetAllPoints(bar)
        if mark.SetIgnoreParentAlpha then mark:SetIgnoreParentAlpha(true) end
    end)
    if not moved then
        ns.Report("range nameplate", "could not anchor to the nameplate")
        return false
    end
    local levelOk, level = pcall(bar.GetFrameLevel, bar)
    if not levelOk or not Faders.PlainNumber(level) then level = 1 end
    pcall(mark.SetFrameLevel, mark, level + 20)
    return true
end

function Faders.UpdateRange(elapsed)
    local state = Faders.RangeDecision()
    if state == "hold" then return end
    if state ~= "show" then
        if not rangeMark or not rangeMark:IsShown() then return end
        local placed = PlaceRangeMark(rangeMark)
        if not placed then
            Faders.HideRangeMark()
            return
        end
        ns.EaseAlpha(rangeMark, false, elapsed)
        if rangeMark._quietAlpha == 0 then Faders.HideRangeMark() end
        return
    end
    local mark = EnsureRangeMark()
    if not mark then return end
    local placed = PlaceRangeMark(mark)
    if not placed then
        Faders.HideRangeMark()
        return
    end
    if not mark:IsShown() then
        mark._quietApplying = true
        mark:SetAlpha(0)
        mark._quietApplying = false
        mark._quietAlpha = 0
        mark:Show()
    end
    ns.EaseAlpha(mark, true, elapsed)
end
