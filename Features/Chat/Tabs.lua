local _, ns = ...

-- Tab fade and the tabs placed below the chat.

local Chat = ns.Chat

-- ChatFrame1 is the dock itself; other windows say so with isDocked.
local function Docked(window, i)
    if i == 1 then return true end
    local d = window and window.isDocked
    return d == true or (type(d) == "number" and d > 0)
end

-- A tab click leaves the pointer on the tab row, so the row counts as the chat's hover.
local function TabRowHot(frame, i)
    if ns.MouseOver(Chat.Window(i, "Tab")) then return true end
    return Docked(frame, i) and ns.MouseOver(GeneralDockManager)
end
Chat.TabRowHot = TabRowHot

-- Tabs show while the chat or the tab row is hovered, or while a tab flashes for new messages.
local function TabAlerting(tab)
    if tab.alerting then return true end
    local glow = tab.glow
    return glow and glow.IsShown and glow:IsShown() and true or false
end

-- Mouse-over reads wait for a moved pointer, or 0.1 s, like the chat hover. True while a tab still eases.
local overAt

local function FadeTabs(elapsed)
    local now = GetTime()
    local read = not Chat.state.pointerStill or not overAt or now >= overAt
    if read then overAt = now + 0.1 end
    local hot, easing = false, false
    for i = 1, Chat.ChatCount() do
        local frame = Chat.Window(i)
        if frame and frame._quietHover then hot = true end
    end
    if read then Chat.state.dockOver = ns.MouseOver(GeneralDockManager) end
    hot = hot or Chat.state.dockOver
    for i = 1, Chat.ChatCount() do
        local tab = Chat.Window(i, "Tab")
        if tab and ns.Usable(tab) then
            ns.NoteChat(tab)
            if read then tab._quietOver = ns.MouseOver(tab) end
            tab._quietAlerting = tab.alerting and true or false
            local show = hot or tab._quietOver or TabAlerting(tab)
            ns.EaseAlpha(tab, show, elapsed)
            if tab._quietAlpha ~= (show and 1 or 0) then easing = true end
        end
    end
    return easing
end
Chat.FadeTabs = FadeTabs
------------------------------------------------------------------------------
-- Tabs below the chat (Modern chat). Originals are saved once per frame.
------------------------------------------------------------------------------
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN",
    "FULLSCREEN_DIALOG", "TOOLTIP" }
local placingTabs = false

local function Num(n)
    if Chat.UsableNumber(n) then return n end
end

local function SavePoints(frame)
    if frame._quietTabPoints then return end
    local saved = {}
    for i = 1, frame:GetNumPoints() do
        saved[i] = { frame:GetPoint(i) }
    end
    frame._quietTabPoints = saved
end

local function RaiseAbove(edit, tab)
    if not edit.GetFrameStrata or not tab.GetFrameStrata then return end
    local want
    for i, strata in ipairs(STRATA_ORDER) do
        if strata == tab:GetFrameStrata() then want = STRATA_ORDER[i + 1] or strata end
    end
    if not want or edit:GetFrameStrata() == want then return end
    if not edit._quietStrata then edit._quietStrata = edit:GetFrameStrata() end
    edit:SetFrameStrata(want)
end

local function DropEditStrata(edit)
    if edit and edit._quietStrata then
        pcall(edit.SetFrameStrata, edit, edit._quietStrata)
        edit._quietStrata = nil
    end
end

-- wide: the frame takes its width from the window (the dock), so anchor both sides.
local function MoveBelow(tab, window, edit, wide)
    if not ns.Usable(tab) or not ns.Usable(window) then return end
    SavePoints(tab)
    local editH = edit and ns.Usable(edit) and Num(edit:GetHeight()) or 0
    local tabH = Num(tab:GetHeight()) or 0
    local bottom = Num(window:GetBottom())
    local floor = Num(UIParent:GetBottom()) or 0
    tab:ClearAllPoints()
    if bottom and bottom - editH - tabH < floor then
        local left = Num(window:GetLeft()) or 0
        tab:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, 0)
        local right = wide and Num(window:GetRight())
        if right then tab:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, 0) end
        if edit then RaiseAbove(edit, tab) end
    else
        tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, -editH)
        if wide then tab:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -editH) end
        DropEditStrata(edit)
    end
end

local function RestoreTabPoints(list)
    for k = 1, #list do
        local frame = list[k]
        local saved = frame and frame._quietTabPoints
        if saved then
            frame._quietTabPoints = nil
            if ns.Usable(frame) then
                frame:ClearAllPoints()
                for _, p in ipairs(saved) do frame:SetPoint(unpack(p)) end
            end
        end
    end
end

local function PlaceTabs()
    if placingTabs or not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    placingTabs = true
    local ok, err = pcall(function()
        local top = ns.Settings.ChatTabs() == "top"
        local main = _G.ChatFrame1
        if top then
            -- Blizzard's own points: put back what Bottom moved, then leave them alone.
            local list = { GeneralDockManager }
            for i = 1, Chat.ChatCount() do
                list[#list + 1] = _G["ChatFrame" .. i .. "Tab"]
                DropEditStrata(_G["ChatFrame" .. i .. "EditBox"])
            end
            RestoreTabPoints(list)
            return
        end
        if main and GeneralDockManager then
            MoveBelow(GeneralDockManager, main, _G.ChatFrame1EditBox, true)
        end
        for i = 1, Chat.ChatCount() do
            local window = _G["ChatFrame" .. i]
            local tab = _G["ChatFrame" .. i .. "Tab"]
            -- A docked tab lives inside the dock, which moves instead.
            if window and tab and not Docked(window, i) then
                MoveBelow(tab, window, _G["ChatFrame" .. i .. "EditBox"])
            end
        end
    end)
    placingTabs = false
    if not ok then ns.Report("chat", err) end
end
Chat.PlaceTabs = PlaceTabs

local function RestoreTabs()
    local list = { GeneralDockManager }
    for i = 1, Chat.ChatCount() do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        list[#list + 1] = tab
        if tab and tab._quietAlpha ~= nil then ns.ReleaseAlpha(tab) end
        DropEditStrata(_G["ChatFrame" .. i .. "EditBox"])
    end
    RestoreTabPoints(list)
end
Chat.RestoreTabs = RestoreTabs
