local _, ns = ...
local Bars = ns.Bars
local S = Bars.state

-- Bar fading. Alpha only: Hide(), Show() and state drivers are off limits.

local covered, resolved = S.covered, S.resolved
local held = {}
local seenHeld = {}

local MAIN_BAR = {
    MainMenuBar = true,
    MainActionBar = true,
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

local function FollowArt(alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = S.Parent(art)
            if not (parent and Bars.IsBarFrame(parent)) then
                ns.HoldAlpha(art, alpha)
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
    local list = S.ButtonsFor(bar, true)
    for i = 1, #list do
        local nextAlpha = FadeButton(list[i], show, elapsed)
        if type(nextAlpha) == "number" then
            alpha = nextAlpha
        end
    end
    if type(alpha) == "number" then
        local regions = S.RegionsFor(bar)
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
        if art and art.SetAlpha and S.Parent(art) == bar then
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
    if S.HostsOther(bar) then
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

function Bars.Update(showAll, elapsed, rescan)
    if rescan == nil then rescan = true end
    local showAllForced = showAll or ns.Glancing()
    -- ApplyBar reads hosts/covered, which ForgetBarButtons drops between rescans.
    S.Collect()
    if rescan or not haveBarShow then
        if ns.World.InEditMode() or not ns.DB().enabled then
            Bars.HideCatchers()
        else
            S.SyncCatchers()
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
                    if ns.Usable(bar) and bar:IsShown() and (S.BarHovered(bar) or S.BarCoversBags(bar)) then
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
    apply = function() Bars.ForgetButtons() end,
    restore = function() Bars.HideCatchers() end,
    -- The idle pass (no focus change, nothing hot) skips bars.
    fade = function(elapsed, rescan, showAll, idle)
        if not idle then Bars.Update(showAll, elapsed, rescan) end
    end,
    rescan = function(deep)
        Bars.ScanSwing()
        if not deep and Bars.ChildrenChanged() then Bars.ForgetButtons() end
    end,
    events = {
        EDIT_MODE_LAYOUTS_UPDATED = function() Bars.ForgetButtons() end,
    },
})
