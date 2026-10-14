local _, ns = ...

-- Draggable windows. The drag handle saves the point to windowPoints; the saved point is put
-- back on every show and after Blizzard positions its panels. In combat nothing is moved.

local Modern = ns.Modern

local HEIGHT = 24
local windows = {}  -- frame -> { key, handle, active, wasMovable, original }
local pending = {}  -- frames whose wanted point waits for the end of combat

local function Points(frame)
    local points = {}
    if type(frame.GetNumPoints) ~= "function" or type(frame.GetPoint) ~= "function" then return points end
    for i = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        if point then points[#points + 1] = { point, relative, relativePoint, x, y } end
    end
    return points
end

local function RestorePoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end

local function Place(frame, entry)
    if not entry.active or frame.IsMoving and frame:IsMoving() then return end
    local point, relativePoint, x, y = ns.Settings.WindowPoint(entry.key)
    if not point then return end
    if InCombatLockdown() then
        pending[frame] = true
        return
    end
    pending[frame] = nil
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
end

local function RestoreOriginal(frame, entry)
    if InCombatLockdown() then
        pending[frame] = "original"
        return
    end
    pending[frame] = nil
    RestorePoints(frame, entry.original)
    entry.reset = nil
end

local function Save(frame, entry)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point and relativePoint and not ns.IsSecret(x) and not ns.IsSecret(y) then
        ns.Settings.SaveWindowPoint(entry.key, point, relativePoint, x, y)
    end
end

local function Arm(frame, entry)
    local handle = entry.handle
    handle:Show()
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        entry.dragging = true
        frame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if entry.dragging then
            entry.dragging = false
            Save(frame, entry)
        end
    end)
end

function Modern.MakeMovable(frame, key)
    if not ns.Usable(frame) or type(key) ~= "string" or type(frame.CreateTexture) ~= "function" then return end
    local entry = windows[frame]
    if not entry then
        -- Capture Blizzard's placement before applying a saved point.  It is the position
        -- ReleaseMovable and ResetPositions must put back.
        entry = { key = key, wasMovable = frame.IsMovable and frame:IsMovable() or false, original = Points(frame) }
        entry.handle = CreateFrame("Frame", nil, frame)
        entry.handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        entry.handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        entry.handle:SetHeight(HEIGHT)
        windows[frame] = entry
        entry.onShow = frame:GetScript("OnShow")
    end
    entry.key = key
    entry.active = true
    frame:SetScript("OnShow", function(self, ...)
        if entry.onShow then entry.onShow(self, ...) end
        Place(self, entry)
    end)
    frame:SetMovable(true)
    Arm(frame, entry)
    if frame:IsShown() then Place(frame, entry) end
end

-- The handle stops working and Blizzard's position is used again; saved points stay.
function Modern.ReleaseMovable(frame)
    local entry = windows[frame]
    if not entry or not entry.active then return end
    entry.active = false
    if entry.dragging then frame:StopMovingOrSizing() end
    entry.dragging = false
    entry.handle:SetScript("OnDragStart", nil)
    entry.handle:SetScript("OnDragStop", nil)
    entry.handle:EnableMouse(false)
    entry.handle:Hide()
    frame:SetScript("OnShow", entry.onShow)
    frame:SetMovable(entry.wasMovable)
    RestoreOriginal(frame, entry)
end

-- Forget saved points and return every tracked window to the Blizzard point captured before
-- the first saved placement.  This is deliberately independent of the setup draft.
function Modern.ResetPositions()
    ns.Settings.ResetWindowPoints()
    for frame, entry in pairs(windows) do
        if entry.dragging then frame:StopMovingOrSizing() end
        entry.dragging = false
        entry.reset = true
        RestoreOriginal(frame, entry)
    end
end

-- Combat ended, or Blizzard positioned its panels: saved or original wanted points go back.
function Modern.PlaceWindows(onlyPending)
    for frame, entry in pairs(windows) do
        if frame:IsShown() and (not onlyPending or pending[frame]) then
            if pending[frame] == "original" or entry.reset then
                ns.Run("modern window " .. entry.key, RestoreOriginal, frame, entry)
            elseif entry.active then
                ns.Run("modern window " .. entry.key, Place, frame, entry)
            end
        end
    end
end
