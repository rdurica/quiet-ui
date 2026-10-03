local _, ns = ...

-- Action bars. Alpha only: Hide(), Show() and state drivers are off limits.

local BUTTON_PREFIX = {
    MainMenuBar = "ActionButton",
    MainActionBar = "ActionButton",
    MultiBarBottomLeft = "MultiBarBottomLeftButton",
    MultiBarBottomRight = "MultiBarBottomRightButton",
    MultiBarRight = "MultiBarRightButton",
    MultiBarLeft = "MultiBarLeftButton",
    MultiBar5 = "MultiBar5Button",
    MultiBar6 = "MultiBar6Button",
    MultiBar7 = "MultiBar7Button",
    StanceBar = "StanceButton",
    StanceBarFrame = "StanceButton",
    ShapeshiftBarFrame = "ShapeshiftButton",
    PetActionBar = "PetActionButton",
    PetActionBarFrame = "PetActionButton",
}

-- Same number fades together. Missing saved values use group.
-- Gamepad follows bar 1 and has no setup row.
ns.BAR_ROWS = {
    { id = "1", label = "Bar 1", group = 1, names = { "MainMenuBar", "MainActionBar", "GamepadMainActionBarFrame" } },
    { id = "2", label = "Bar 2", group = 1, names = { "MultiBarBottomLeft" } },
    { id = "3", label = "Bar 3", group = 1, names = { "MultiBarBottomRight" } },
    { id = "4", label = "Bar 4", group = 2, names = { "MultiBarRight" } },
    { id = "5", label = "Bar 5", group = 2, names = { "MultiBarLeft" } },
    { id = "6", label = "Bar 6", group = 3, names = { "MultiBar5" } },
    { id = "7", label = "Bar 7", group = 4, names = { "MultiBar6" } },
    { id = "8", label = "Bar 8", group = 5, names = { "MultiBar7" } },
    { id = "stance", label = "Stance bar", group = 1, names = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" } },
    { id = "pet", label = "Pet bar", group = 1, names = { "PetActionBar", "PetActionBarFrame" } },
    { id = "totem", label = "Totem bar", group = 1, names = { "MultiCastActionBarFrame", "TotemFrame" } },
    { id = "swing", label = "Swing timer", group = 10, names = {
        "SwingTimerFrame",
        "SwingTimer",
        "MainHandSwingTimer",
        "OffHandSwingTimer",
        "RangedSwingTimer",
        "SwingTimerMainHand",
        "SwingTimerOffHand",
    } },
}

-- Move legacy per-bar pins to group modes, splitting mixed groups to keep their visibility.
function ns.MigrateVisibility(settings)
    if type(settings) ~= "table" then return end
    local visible = settings.visible
    if type(visible) ~= "table" or (visible.bars == nil and visible.swing == nil) then return end
    local buckets, used = {}, {}
    local legacy = visible.bars ~= nil or visible.swing ~= nil
    for _, row in ipairs(ns.BAR_ROWS) do
        if visible[row.id] ~= nil then legacy = true end
        local n = type(settings.groups) == "table" and settings.groups[row.id]
        if type(n) ~= "number" or n ~= n or n < 1 or n > #ns.BAR_ROWS then n = row.group end
        n = math.floor(n)
        used[n] = true
        buckets[n] = buckets[n] or { pinned = {}, normal = {} }
        local pinned = visible[row.id] or (row.id ~= "swing" and visible.bars)
        local list = pinned and buckets[n].pinned or buckets[n].normal
        list[#list + 1] = row.id
    end
    if not legacy then return end
    settings.groupVisibility = type(settings.groupVisibility) == "table" and settings.groupVisibility or {}
    for n = 1, #ns.BAR_ROWS do
        local bucket = buckets[n]
        if bucket and #bucket.pinned > 0 then
            local pinGroup = n
            if #bucket.normal > 0 then
                for candidate = 1, #ns.BAR_ROWS do
                    if not used[candidate] then pinGroup = candidate; used[candidate] = true; break end
                end
                settings.groups = type(settings.groups) == "table" and settings.groups or {}
                for _, id in ipairs(bucket.pinned) do settings.groups[id] = pinGroup end
            end
            settings.groupVisibility[pinGroup] = "always"
        end
    end
    visible.bars = nil
    for _, row in ipairs(ns.BAR_ROWS) do visible[row.id] = nil end
end

function ns.GroupVisibility(group)
    local settings = ns.Settings and ns.Settings() or ns.CharDB()
    local modes = settings.groupVisibility
    local mode = type(modes) == "table" and modes[group]
    if mode == "always" or mode == "hover" then return mode end
end

function ns.AnyBarsAlwaysVisible()
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id ~= "swing" and ns.GroupVisibility(ns.BarGroup(row.id)) == "always" then return true end
    end
    return false
end

function ns.BarGroup(id)
    local fallback = 1
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id == id then
            fallback = row.group
            break
        end
    end
    if type(ns.CharDB) ~= "function" then return fallback end
    local groups = (ns.Settings and ns.Settings() or ns.CharDB()).groups
    local n = type(groups) == "table" and groups[id]
    if type(n) ~= "number" or n ~= n then return fallback end
    n = math.floor(n)
    if n < 1 or n > #ns.BAR_ROWS then return fallback end
    return n
end

-- Missing means off. kind is "hostile" or "friendly".
function ns.BarTarget(id, kind)
    if type(ns.CharDB) ~= "function" then return false end
    local map = (ns.Settings and ns.Settings() or ns.CharDB())[kind]
    return type(map) == "table" and map[id] and true or false
end

local MAIN_BAR = {
    MainMenuBar = true,
    MainActionBar = true,
}

-- Buttons sit several levels deep and outside the root's rect.
local DEEP_HOVER = {
    GamepadMainActionBarFrame = true,
    MultiCastActionBarFrame = true,
    TotemFrame = true,
}

-- Orphan classic art. Children of a bar already follow that bar's alpha.
local BAR_ART = {
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarPageNumber",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarArtFrame",
}

-- Returns fn()'s result, or false when the API is missing or throws.
local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and not ns.IsSecret(result) and result and true or false
end

-- A corpse still counts as attackable. Enemy needs a living target.
local function TargetAlive()
    if type(UnitIsDeadOrGhost) == "function" then
        return not Safe(UnitIsDeadOrGhost, "target")
    end
    if type(UnitIsDead) == "function" then
        return not Safe(UnitIsDead, "target")
    end
    return true
end

local function HostileTarget()
    if type(UnitCanAttack) ~= "function" then return false end
    return Safe(UnitCanAttack, "player", "target") and TargetAlive()
end

local function FriendlyTarget()
    if type(UnitIsFriend) ~= "function" then return false end
    return Safe(UnitIsFriend, "player", "target") and TargetAlive()
end

local world = {
    combat = false,
    instance = false,
    group = false,
    vehicle = false,
    target = false,
    hostile = false,
    friendly = false,
}

function ns.InEditMode()
    local frame = EditModeManagerFrame
    return frame and frame.IsShown and frame:IsShown() and true or false
end

function ns.RefreshWorld()
    local combat = world.combat
    if type(InCombatLockdown) == "function" then
        local ok, locked = pcall(InCombatLockdown)
        if ok then combat = locked and true or false end
    end
    local group = type(IsInGroup) == "function" and Safe(IsInGroup) or false
    local vehicle = type(UnitHasVehicleUI) == "function" and Safe(UnitHasVehicleUI, "player") or false
    local target = type(UnitExists) == "function" and Safe(UnitExists, "target") or false
    local hostile = target and HostileTarget()
    local friendly = target and FriendlyTarget()
    local instance = false
    if type(IsInInstance) == "function" then
        instance = Safe(function()
            local inInstance, kind = IsInInstance()
            return inInstance and (
                kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
            )
        end)
    end
    if combat ~= world.combat or group ~= world.group or vehicle ~= world.vehicle
        or target ~= world.target or instance ~= world.instance
        or hostile ~= world.hostile or friendly ~= world.friendly then
        world.combat, world.group, world.vehicle = combat, group, vehicle
        world.target, world.instance = target, instance
        world.hostile, world.friendly = hostile, friendly
        ns.TouchHud()
    end
end

function ns.NoteCombat(on)
    local nextOn = on and true or false
    if nextOn ~= world.combat then
        world.combat = nextOn
        ns.TouchHud()
    end
end

function ns.InCombat()
    return world.combat
end

function ns.InGroup()
    return world.group
end

function ns.InForcedInstance()
    return world.instance
end

function ns.InVehicle()
    return world.vehicle
end

function ns.HasTarget()
    return world.target
end

-- false means this tick has not read the cursor yet. nil is a real empty cursor.
local cursorKind = false
local hudDirty = true

function ns.TouchHud()
    hudDirty = true
end

function ns.ConsumeHud()
    local dirty = hudDirty
    hudDirty = false
    return dirty
end

function ns.ForgetCursor()
    cursorKind = false
end

function ns.BeginTick(hover)
    if not hover then return end
    cursorKind = false
    ns.RefreshMouse()
end

local function CursorKind()
    if cursorKind ~= false then return cursorKind end
    if type(GetCursorInfo) ~= "function" then
        cursorKind = nil
        return nil
    end
    local ok, kind = pcall(GetCursorInfo)
    cursorKind = ok and kind or nil
    return cursorKind
end

function ns.CursorBusy()
    return CursorKind() ~= nil
end

function ns.CursorHasItem()
    return CursorKind() == "item"
end

local function FlyoutOpen()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end

-- Explicit HUD/bar-editing exceptions also reveal hover-only bars and XP.
function ns.XPForced()
    return ns.InEditMode() or FlyoutOpen() or ns.CursorBusy()
end

-- Action bars are fully visible while this is true.
function ns.ShowAll()
    return world.combat or ns.InEditMode() or world.vehicle or world.instance
        or FlyoutOpen() or ns.CursorBusy()
end

local function Parent(frame)
    if not ns.Usable(frame) or not frame.GetParent then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok then return parent end
end

local function IsAncestor(frame, ancestor)
    local current = Parent(frame)
    local depth = 0
    while current and depth < 8 do
        if current == ancestor then return true end
        current = Parent(current)
        depth = depth + 1
    end
    return false
end

-- frame -> bar id, rebuilt each tick. A bar that parents another stays at
-- alpha 1 or the child would fade with it.
local owner = {}
local resolved = {}
local held = {}
local seenHeld = {}

local function Clear(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function UnderOther(frame, bar)
    for other in pairs(owner) do
        if other ~= bar and IsAncestor(frame, other) then
            return true
        end
    end
    return false
end

local function HostsOther(bar)
    for other in pairs(owner) do
        if other ~= bar and owner[other] ~= owner[bar] and IsAncestor(other, bar) then
            return true
        end
    end
    return false
end

local function LeaveAlone(frame)
    if ns.IsBagRelated(frame) then return true end
    local name = ns.FrameName(frame)
    return name ~= nil and name:find("Micro") ~= nil
end

local function EachOwnButton(bar, fn)
    local seen = {}
    local function consider(button)
        if not ns.Usable(button) or seen[button] or LeaveAlone(button) or UnderOther(button, bar) then return end
        seen[button] = true
        fn(button)
    end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            consider(child)
        end
    end
    local prefix = BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            consider(_G[prefix .. i])
        end
    end
end

local function IsPressable(frame)
    if not ns.Usable(frame) or not frame.GetObjectType then return false end
    local ok, kind = pcall(frame.GetObjectType, frame)
    return ok and (kind == "Button" or kind == "CheckButton")
end

local function EachDeepButton(bar, fn, depth)
    depth = depth or 0
    if depth > 4 or not ns.Usable(bar) or not bar.GetChildren then return end
    for _, child in ipairs({ bar:GetChildren() }) do
        if ns.Usable(child) and not owner[child] and not LeaveAlone(child) then
            if IsPressable(child) then
                if not UnderOther(child, bar) then
                    fn(child)
                end
            else
                EachDeepButton(child, fn, depth + 1)
            end
        end
    end
end

local buttonCache = {}
local deepCache = {}
local regionCache = {}

local function RememberButtons(bar, list, deep)
    local seen = {}
    local function add(button)
        if seen[button] then return end
        seen[button] = true
        list[#list + 1] = button
    end
    EachOwnButton(bar, add)
    if deep then EachDeepButton(bar, add) end
end

local function ButtonsFor(bar, deep)
    local cache = deep and deepCache or buttonCache
    local list = cache[bar]
    if list then return list end
    list = {}
    cache[bar] = list
    RememberButtons(bar, list, deep)
    return list
end

local function RegionsFor(bar)
    local list = regionCache[bar]
    if list then return list end
    list = {}
    regionCache[bar] = list
    if not bar.GetRegions then return list end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region and region.SetAlpha and region.GetObjectType then
            local ok, kind = pcall(region.GetObjectType, region)
            if ok and kind == "Texture" then
                list[#list + 1] = region
            end
        end
    end
    return list
end

function ns.ForgetBarButtons()
    for bar in pairs(buttonCache) do
        buttonCache[bar] = nil
    end
    for bar in pairs(deepCache) do
        deepCache[bar] = nil
    end
    for bar in pairs(regionCache) do
        regionCache[bar] = nil
    end
end

local function ListHovered(list)
    for i = 1, #list do
        if ns.Hit(list[i]) then return true end
    end
    return false
end

-- Gamepad and totem buttons sit outside the bar rect, so the catcher misses them.
local function ButtonsHovered(bar)
    if not DEEP_HOVER[ns.FrameName(bar) or ""] then return false end
    if ListHovered(ButtonsFor(bar, false)) then return true end
    return ListHovered(ButtonsFor(bar, true))
end

-- Empty slots are not mouse frames. The catcher is not a child of the bar:
-- a faded parent would drop the mouse. Clicks stay off so spells keep them.
local catchers = {}
local catcherSeen = {}

local function HideCatchers()
    for _, box in pairs(catchers) do
        box:Hide()
    end
end

function ns.HideBarCatchers()
    HideCatchers()
end

local function EnsureCatcher(bar)
    local box = catchers[bar]
    if box then return box end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:SetAlpha(1)
    created:Hide()
    catchers[bar] = created
    return created
end

local function MatchLevel(box, bar)
    local strata = bar.GetFrameStrata and bar:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = bar.GetFrameLevel and bar:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
end

-- MainMenuBar's own rect is wider than its slots when it hosts other bars.
local function SlotCorner(bar)
    local prefix = BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if not prefix then return end
    local tl, br, tlTop, tlLeft, brBottom, brRight
    for i = 1, 12 do
        local button = _G[prefix .. i]
        if ns.Usable(button) and button.GetLeft then
            local left, right = button:GetLeft(), button.GetRight and button:GetRight()
            local top, bottom = button.GetTop and button:GetTop(), button.GetBottom and button:GetBottom()
            if left and right and top and bottom then
                if not tl or top > tlTop or (top == tlTop and left < tlLeft) then
                    tl, tlTop, tlLeft = button, top, left
                end
                if not br or bottom < brBottom or (bottom == brBottom and right > brRight) then
                    br, brBottom, brRight = button, bottom, right
                end
            end
        end
    end
    if tl and br then return tl, br end
end

local function PlaceCatcher(bar)
    local box = EnsureCatcher(bar)
    if not box then return end
    local slotted = ns.FrameName(bar) == "MainMenuBar" and HostsOther(bar)
    if slotted then
        local tl, br = SlotCorner(bar)
        if not tl then
            box:Hide()
            box._quietSpan = nil
            return
        end
        if box._quietSlotA ~= tl or box._quietSlotB ~= br then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", tl, "TOPLEFT")
            box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
            box._quietSlotA, box._quietSlotB = tl, br
        end
        box._quietSpan = "slots"
    elseif box._quietSpan ~= bar then
        box:ClearAllPoints()
        box:SetAllPoints(bar)
        box._quietSpan = bar
        box._quietSlotA, box._quietSlotB = nil, nil
    end
    MatchLevel(box, bar)
    if not box:IsShown() then box:Show() end
end

local function SyncCatchers()
    for bar in pairs(catcherSeen) do
        catcherSeen[bar] = nil
    end
    for _, entry in ipairs(resolved) do
        for _, bar in ipairs(entry.frames) do
            if ns.Usable(bar) and bar.IsShown and bar:IsShown() then
                PlaceCatcher(bar)
                catcherSeen[bar] = true
            end
        end
    end
    for bar, box in pairs(catchers) do
        if not catcherSeen[bar] then
            box:Hide()
        end
    end
end

local function CatcherHit(bar)
    local box = catchers[bar]
    return box and ns.Hit(box) and true or false
end

-- The bar rectangle, plus buttons that sit outside it on the gamepad and totem bars.
local function DirectHot(bar)
    if CatcherHit(bar) then return true end
    if ButtonsHovered(bar) then return true end
    return ns.Hit(bar)
end

-- Hover on a nested bar belongs to that bar, not the frame behind it.
local function OverNested(bar)
    for other in pairs(owner) do
        if other ~= bar and owner[other] ~= owner[bar] and IsAncestor(other, bar) then
            if DirectHot(other) then return true end
        end
    end
    return false
end

local function BarHovered(bar)
    if OverNested(bar) then return false end
    return DirectHot(bar)
end

-- A bar that parents the bag slots stays visible while those slots are shown.
local function BarCoversBags(bar)
    if not ns.BagsShouldShow() then return false end
    local found = false
    ns.EachBagFrame(function(frame)
        if not found and frame ~= bar and IsAncestor(frame, bar) then
            found = true
        end
    end)
    return found
end

local function FollowArt(alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = Parent(art)
            if not (parent and ns.IsBarFrame(parent)) then
                ns.HoldAlpha(art, alpha)
            end
        end
    end
end

local swingFound = {}
local swingScan = 0

local function LooksLikeSwing(frame)
    if not ns.Usable(frame) or not frame.SetAlpha then return false end
    local name = ns.FrameName(frame)
    if name and name:find("Swing") then return true end
    if type(frame.GetDebugName) ~= "function" then return false end
    local ok, debugName = pcall(frame.GetDebugName, frame)
    return ok and type(debugName) == "string" and debugName:find("Swing") ~= nil
end

-- The swing timer is not one fixed global. Main hand and off hand are separate
-- frames, and only the debug name is stable.
local function WalkSwing(root, depth)
    if depth > 1 or not ns.Usable(root) or type(root.GetChildren) ~= "function" then return end
    local ok, children = pcall(function()
        return { root:GetChildren() }
    end)
    if not ok or type(children) ~= "table" then return end
    for _, child in ipairs(children) do
        if LooksLikeSwing(child) then
            swingFound[child] = true
        end
        local name = ns.FrameName(child)
        if name == "PlayerFrame" or name == "MainActionBar" or name == "MainMenuBar"
            or (name and name:find("Swing")) then
            WalkSwing(child, depth + 1)
        end
    end
end

function ns.ScanSwing()
    local now = type(GetTime) == "function" and GetTime() or 0
    if now < swingScan then return end
    swingScan = now + 1
    for frame in pairs(swingFound) do
        swingFound[frame] = nil
    end
    if UIParent then
        WalkSwing(UIParent, 0)
    end
end

local function Collect()
    Clear(owner)
    for index, row in ipairs(ns.BAR_ROWS) do
        local entry = resolved[index]
        if not entry then
            entry = { frames = {} }
            resolved[index] = entry
        end
        entry.id = row.id
        local frames = entry.frames
        local count = 0
        local seen = {}
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if bar and not seen[bar] then
                seen[bar] = true
                count = count + 1
                frames[count] = bar
            end
        end
        for extra = count + 1, #frames do
            frames[extra] = nil
        end
        for _, bar in ipairs(frames) do
            owner[bar] = row.id
        end
        if row.id == "swing" then
            for frame in pairs(swingFound) do
                if not seen[frame] then
                    count = count + 1
                    frames[count] = frame
                    owner[frame] = row.id
                end
            end
            for extra = count + 1, #frames do
                frames[extra] = nil
            end
        end
    end
end

-- The outer frame of the same bar already carries the alpha.
local function CoveredBySameBar(bar)
    local id = owner[bar]
    for other, otherId in pairs(owner) do
        if other ~= bar and otherId == id and IsAncestor(bar, other) and not HostsOther(other) then
            return true
        end
    end
    return false
end

local function Watch(frame)
    seenHeld[frame] = true
    held[frame] = true
end

-- Shown buttons are released so range fading can set their alpha.
local function FadeButton(button, show, elapsed)
    if not button.IsShown or not button:IsShown() then return end
    if show then
        if held[button] then
            ns.ReleaseAlpha(button)
            held[button] = nil
        end
        return 1
    end
    if button._quietAlpha ~= nil and not held[button] then return end
    Watch(button)
    ns.UpdateFaded(button, false, elapsed)
    return button._quietAlpha
end

-- Parent stays at full alpha so a nested bar can keep its own.
local function FadeHosted(bar, show, elapsed)
    ns.HoldAlpha(bar, 1)
    local alpha
    local list = ButtonsFor(bar, true)
    for i = 1, #list do
        local nextAlpha = FadeButton(list[i], show, elapsed)
        if type(nextAlpha) == "number" then
            alpha = nextAlpha
        end
    end
    if type(alpha) == "number" then
        local regions = RegionsFor(bar)
        for i = 1, #regions do
            Watch(regions[i])
            ns.HoldAlpha(regions[i], alpha)
        end
    end
    return alpha
end

-- Deeper art follows the child frame. Only art parented to the bar itself needs a hold.
local function FadeChildArt(bar, alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha and Parent(art) == bar then
            Watch(art)
            ns.HoldAlpha(art, alpha)
        end
    end
end

local function ApplyBar(bar, show, elapsed)
    if CoveredBySameBar(bar) then
        if bar._quietAlpha ~= nil then
            ns.ReleaseAlpha(bar)
        end
        return
    end
    local name = ns.FrameName(bar) or ""
    local alpha
    if HostsOther(bar) then
        alpha = FadeHosted(bar, show, elapsed)
        if MAIN_BAR[name] and type(alpha) == "number" then
            FadeChildArt(bar, alpha)
        end
    else
        ns.UpdateFaded(bar, show, elapsed)
        alpha = bar._quietAlpha
    end
    return name, alpha
end

local function ReleaseUnwatched()
    for frame in pairs(held) do
        if not seenHeld[frame] then
            ns.ReleaseAlpha(frame)
            held[frame] = nil
        end
    end
    Clear(seenHeld)
end

local showGroup = {}
local barShow = {}
local haveBarShow = false

-- Hover groups skip automatic triggers; explicit HUD and bar editing still show them.
local function RowForced(id, showAllForced)
    local mode = ns.GroupVisibility(ns.BarGroup(id))
    if mode == "always" then return true end
    if mode == "hover" then return ns.XPForced() end
    return showAllForced
end

function ns.UpdateBars(showAll, elapsed, rescan)
    if rescan == nil then rescan = true end
    local showAllForced = showAll or ns.Glancing()
    if rescan or not haveBarShow then
        Collect()
        if ns.InEditMode() or not ns.DB().enabled then
            HideCatchers()
        else
            SyncCatchers()
        end
        for key in pairs(showGroup) do
            showGroup[key] = nil
        end
        local hostile, friendly
        do
            hostile = world.hostile
            friendly = world.friendly
            for _, entry in ipairs(resolved) do
                local group = ns.BarGroup(entry.id)
                for _, bar in ipairs(entry.frames) do
                    if ns.Usable(bar) and bar:IsShown() and (BarHovered(bar) or BarCoversBags(bar)) then
                        showGroup[group] = true
                    end
                end
            end
        end
        for _, entry in ipairs(resolved) do
            local group = ns.BarGroup(entry.id)
            local mode = ns.GroupVisibility(group)
            barShow[entry.id] = RowForced(entry.id, showAllForced) or showGroup[group]
                or (not mode and hostile and ns.BarTarget(entry.id, "hostile"))
                or (not mode and friendly and ns.BarTarget(entry.id, "friendly")) or false
        end
        haveBarShow = true
    end
    local mainAlpha, gamepadAlpha
    for _, entry in ipairs(resolved) do
        local show = RowForced(entry.id, showAllForced) or barShow[entry.id]
        for _, bar in ipairs(entry.frames) do
            if ns.Usable(bar) and bar:IsShown() then
                local name, alpha = ApplyBar(bar, show, elapsed)
                if type(alpha) == "number" then
                    if MAIN_BAR[name] then
                        mainAlpha = alpha
                    elseif name == "GamepadMainActionBarFrame" then
                        gamepadAlpha = alpha
                    end
                end
            end
        end
    end
    local artAlpha = mainAlpha or gamepadAlpha
    if type(artAlpha) == "number" then
        FollowArt(artAlpha)
    end
    ReleaseUnwatched()
end
