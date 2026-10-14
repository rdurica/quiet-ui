local _, ns = ...

-- Draggable windows. The drag handle saves the point to windowPoints; the saved point is put
-- back on every show and after Blizzard positions its panels. In combat nothing is moved.

local Modern = ns.Modern

local HEIGHT = 24
local windows = {}  -- frame -> { key, handle, active, wasMovable }
local pending = {}  -- frames whose saved point waits for the end of combat

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
        entry = { key = key, wasMovable = frame.IsMovable and frame:IsMovable() or false }
        entry.handle = CreateFrame("Frame", nil, frame)
        entry.handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        entry.handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        entry.handle:SetHeight(HEIGHT)
        windows[frame] = entry
        frame:HookScript("OnShow", function(self) Place(self, entry) end)
    end
    entry.key = key
    entry.active = true
    frame:SetMovable(true)
    Arm(frame, entry)
    if frame:IsShown() then Place(frame, entry) end
end

-- The handle stops working and Blizzard's position is used again; saved points stay.
function Modern.ReleaseMovable(frame)
    local entry = windows[frame]
    if not entry or not entry.active then return end
    entry.active = false
    entry.dragging = false
    pending[frame] = nil
    entry.handle:SetScript("OnDragStart", nil)
    entry.handle:SetScript("OnDragStop", nil)
    entry.handle:EnableMouse(false)
    entry.handle:Hide()
    frame:SetMovable(entry.wasMovable)
end

-- Combat ended, or Blizzard positioned its panels: the wanted points go back.
function Modern.PlaceWindows(onlyPending)
    for frame, entry in pairs(windows) do
        if entry.active and frame:IsShown() and (not onlyPending or pending[frame]) then
            ns.Run("modern window " .. entry.key, Place, frame, entry)
        end
    end
end
