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

local function Parent(frame)
    if not ns.Usable(frame) or not frame.GetParent then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok then return parent end
end

local ancestorCache = {}
local structureDirty = true
local parentHooked = setmetatable({}, { __mode = "k" })

local function WatchParent(frame)
    if not ns.Usable(frame) or parentHooked[frame] or type(frame.SetParent) ~= "function" then return end
    local ok = pcall(hooksecurefunc, frame, "SetParent", function()
        ns.ForgetBarButtons()
    end)
    if ok then parentHooked[frame] = true end
end

local function IsAncestor(frame, ancestor)
    local chain = ancestorCache[frame]
    if chain then return chain[ancestor] or false end
    chain = {}
    ancestorCache[frame] = chain
    WatchParent(frame)
    local current = Parent(frame)
    local depth = 0
    while current and depth < 8 do
        chain[current] = true
        WatchParent(current)
        current = Parent(current)
        depth = depth + 1
    end
    return chain[ancestor] or false
end

-- Frame ownership changes when the UI structure changes. A bar that parents another stays at
-- alpha 1 or the child would fade with it.
local owner = {}
-- Built with owner in Collect: hosts[bar] lists nested bars of another row, covered[bar]
-- marks a bar whose outer frame of the same row already carries the alpha.
local hosts = {}
local covered = {}
local resolved = {}
local held = {}
local seenHeld = {}

local function UnderOther(frame, bar)
    for other in pairs(owner) do
        if other ~= bar and IsAncestor(frame, other) then
            return true
        end
    end
    return false
end

local function HostsOther(bar)
    return hosts[bar] ~= nil
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
    structureDirty = true
    ancestorCache = {}
    ns.Wipe(hosts)
    ns.Wipe(covered)
    ns.World.TouchHud()
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

-- GetNumChildren is enough to notice a new button. The full rebuild waits for that.
local childCounts = {}
local childPrimed = false
local childFallback = 0
local childArmed = false

local function ChildCount(bar)
    if type(bar.GetNumChildren) ~= "function" then return nil end
    local ok, count = pcall(bar.GetNumChildren, bar)
    if not ok or type(count) ~= "number" or ns.IsSecret(count) then return nil end
    return count
end

function ns.BarChildrenChanged()
    local missing = false
    local changed = false
    local seen = {}
    for _, row in ipairs(ns.BAR_ROWS) do
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if ns.Usable(bar) then
                seen[bar] = true
                local count = ChildCount(bar)
                if count == nil then
                    missing = true
                elseif childCounts[bar] ~= count then
                    if childPrimed then changed = true end
                    childCounts[bar] = count
                end
            end
        end
    end
    for bar in pairs(childCounts) do
        if not seen[bar] then
            childCounts[bar] = nil
            if childPrimed then changed = true end
        end
    end
    childPrimed = true
    if changed then return true end
    if not missing then return false end
    local now = type(GetTime) == "function" and GetTime() or 0
    if not childArmed then
        childArmed = true
        childFallback = now + 5
        return false
    end
    if now < childFallback then return false end
    childFallback = now + 5
    return true
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
    local created = ns.Catcher.Create()
    if not created then return end
    created:SetAlpha(1)
    catchers[bar] = created
    return created
end

local function MatchLevel(box, bar)
    ns.Catcher.Strata(box, bar)
    local level = bar.GetFrameLevel and bar:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    ns.Catcher.Level(box, level)
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
    local nested = hosts[bar]
    if not nested then return false end
    for i = 1, #nested do
        if DirectHot(nested[i]) then return true end
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
local swingFullAt = 0

-- Named frames match on that name. GetDebugName is only for frames without one.
local function LooksLikeSwing(frame)
    if not ns.Usable(frame) or not frame.SetAlpha then return false end
    local name = ns.FrameName(frame)
    if name then return name:find("Swing") ~= nil end
    if type(frame.GetDebugName) ~= "function" then return false end
    local ok, debugName = pcall(frame.GetDebugName, frame)
    return ok and type(debugName) == "string" and debugName:find("Swing") ~= nil
end

-- The swing timer is not one fixed global. Main hand and off hand are separate
-- frames. Named ones match on the name; anonymous ones use the debug name.
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

-- No timer found is settled too; walking UIParent every second only makes garbage.
local function SwingReady()
    for frame in pairs(swingFound) do
        if not ns.Usable(frame) then return false end
    end
    return true
end

-- A full UIParent walk waits until a found timer disappears or 10s pass.
function ns.ScanSwing()
    local now = type(GetTime) == "function" and GetTime() or 0
    if SwingReady() and now < swingFullAt then return end
    swingFullAt = now + 10
    for frame in pairs(swingFound) do
        swingFound[frame] = nil
    end
    if UIParent then
        WalkSwing(UIParent, 0)
    end
end

local function Collect()
    if not structureDirty then return end
    structureDirty = false
    ns.Wipe(owner)
    ns.Wipe(hosts)
    ns.Wipe(covered)
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
            if ns.Usable(bar) and not seen[bar] then
                WatchParent(bar)
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
    -- Ownership passes run here once per structure change, not every tick.
    for bar, id in pairs(owner) do
        for other, otherId in pairs(owner) do
            if other ~= bar and otherId ~= id and IsAncestor(other, bar) then
                local list = hosts[bar]
                if not list then
                    list = {}
                    hosts[bar] = list
                end
                list[#list + 1] = other
            end
        end
    end
    for bar, id in pairs(owner) do
        for other, otherId in pairs(owner) do
            if other ~= bar and otherId == id and not hosts[other] and IsAncestor(bar, other) then
                covered[bar] = true
                break
            end
        end
    end
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
    if covered[bar] then
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
    ns.Wipe(seenHeld)
end

local showGroup = {}
local barShow = {}
local haveBarShow = false

-- Hover groups skip automatic triggers; explicit HUD and bar editing still show them.
local function RowForced(id, showAllForced)
    local mode = ns.Settings.GroupVisibility(ns.Settings.BarGroup(id))
    if mode == "always" then return true end
    if mode == "hover" then return ns.World.XPForced() or ns.Glancing() end
    return showAllForced
end

function ns.UpdateBars(showAll, elapsed, rescan)
    if rescan == nil then rescan = true end
    local showAllForced = showAll or ns.Glancing()
    -- ApplyBar reads hosts/covered, which ForgetBarButtons drops between rescans.
    Collect()
    if rescan or not haveBarShow then
        if ns.World.InEditMode() or not ns.DB().enabled then
            HideCatchers()
        else
            SyncCatchers()
        end
        for key in pairs(showGroup) do
            showGroup[key] = nil
        end
        local hostile, friendly
        do
            hostile = ns.World.HostileTarget()
            friendly = ns.World.FriendlyTarget()
            for _, entry in ipairs(resolved) do
                local group = ns.Settings.BarGroup(entry.id)
                for _, bar in ipairs(entry.frames) do
                    if ns.Usable(bar) and bar:IsShown() and (BarHovered(bar) or BarCoversBags(bar)) then
                        showGroup[group] = true
                    end
                end
            end
        end
        for _, entry in ipairs(resolved) do
            local group = ns.Settings.BarGroup(entry.id)
            local mode = ns.Settings.GroupVisibility(group)
            barShow[entry.id] = RowForced(entry.id, showAllForced) or showGroup[group]
                or (not mode and hostile and ns.Settings.BarTarget(entry.id, "hostile"))
                or (not mode and friendly and ns.Settings.BarTarget(entry.id, "friendly")) or false
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

ns.Feature({
    name = "bars",
    apply = function() ns.ForgetBarButtons() end,
    restore = function() ns.HideBarCatchers() end,
    -- The idle pass (no focus change, nothing hot) skips bars.
    fade = function(elapsed, rescan, showAll, idle)
        if not idle then ns.UpdateBars(showAll, elapsed, rescan) end
    end,
    rescan = function(deep)
        ns.ScanSwing()
        if not deep and ns.BarChildrenChanged() then ns.ForgetBarButtons() end
    end,
    events = {
        EDIT_MODE_LAYOUTS_UPDATED = function() ns.ForgetBarButtons() end,
    },
})
