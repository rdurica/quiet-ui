-- The inspect window (InspectFrame, load-on-demand with Blizzard_InspectUI): its right-edge mode tabs (portrait tab
-- and PvP tab, children of InspectFrame.ModeTabs carrying a SelectedTexture and an Icon) become the character
-- window's icon tabs, sized to InspectHeadSlot (fallback 37). On the PvP page (InspectPVPFrame, also reachable as
-- InspectFrame.PVPFrame) the rank title (RankLabel) is anchored below the season label (SeasonLabel), which Blizzard
-- draws on top of each other.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\CharacterInfo\\" .. name)
    texture:SetAlpha(0.95)
    list[#list + 1] = texture
    return texture
end

local function modeTab(parent, list, name, selected)
    local tab = CreateFrame("Frame", name, parent)
    tab:SetSize(44, 44)
    tab.Background = art(tab, list, "SideTab", "BACKGROUND")
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Icon:SetTexture("Interface\\Icons\\" .. name)
    tab.Icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.SelectedTexture = art(tab, list, "SideTabSelected", "OVERLAY")
    tab.SelectedTexture:SetShown(selected)
    tab.HighlightTexture = art(tab, list, "SideTabHover", "HIGHLIGHT")
    return tab
end

-- opts.slot: size of InspectHeadSlot (nil leaves it out); opts.pvp == false leaves the PvP page out; opts.season /
-- opts.rank == false leave that label out; opts.late builds the PvP page's labels only after the first call returns
-- (the caller runs c.build()).
local function inspect(opts)
    opts = opts or {}
    local c = { list = {} }
    local frame = R.window("InspectFrame")
    InspectFrame = frame
    c.frame = frame
    if opts.slot then
        local slot = CreateFrame("ItemButton", "InspectHeadSlot", frame)
        slot:SetSize(opts.slot, opts.slot)
    end
    frame.ModeTabs = CreateFrame("Frame", "InspectFrameModeTabs", frame)
    c.modes = {
        modeTab(frame.ModeTabs, c.list, "InspectFrameModeTab1", true),
        modeTab(frame.ModeTabs, c.list, "InspectFrameModeTab2", false),
    }
    c.modes[1]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, -30)
    c.modes[2]:SetPoint("TOPLEFT", c.modes[1], "BOTTOMLEFT", 0, -4)
    function c.build()
        if opts.pvp == false then return end
        local pvp = CreateFrame("Frame", "InspectPVPFrame", frame)
        InspectPVPFrame = pvp
        frame.PVPFrame = pvp
        c.pvp = pvp
        if opts.season ~= false then
            pvp.SeasonLabel = pvp:CreateFontString(nil, "OVERLAY")
            pvp.SeasonLabel:SetText("Season 1")
            pvp.SeasonLabel:SetPoint("CENTER", pvp, "TOP", 0, -60)
            c.season = pvp.SeasonLabel
        end
        if opts.rank ~= false then
            pvp.RankLabel = pvp:CreateFontString(nil, "OVERLAY")
            pvp.RankLabel:SetText("Civilian")
            pvp.RankLabel:SetPoint("CENTER", pvp, "TOP", 0, -60)
            c.rank = pvp.RankLabel
        end
    end
    if not opts.late then c.build() end
    return c
end

local function snapshot(c)
    return L.snapshot(R.all(c.frame))
end

local function tabsSized(A, c, size)
    for _, tab in ipairs(c.modes) do
        local name = tab:GetName()
        A.deep({ tab:GetSize() }, { size, size }, name .. " takes the equipment slot's size")
        A.eq(tab.Icon:GetNumPoints(), 2, name .. " icon fills the tab")
        A.deep({ tab.Icon:GetPoint(1) }, { "TOPLEFT", tab, "TOPLEFT", 1, -1 }, name .. " icon starts 1 px inside")
        A.deep({ tab.Icon:GetPoint(2) }, { "BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1 }, name .. " icon ends 1 px inside")
        A.ok(L.zoomed(tab.Icon), name .. " icon is cropped square")
    end
end

local function rankBelowSeason(A, c)
    local point, relative, relativePoint, x, y = c.rank:GetPoint(1)
    A.eq(point, "TOP", "the rank title hangs from its top")
    A.eq(relative, c.season, "it is anchored to the season label")
    A.eq(relativePoint, "BOTTOM", "at the season label's bottom")
    A.ok(type(y) == "number" and y <= 0 and y >= -12, "with a small gap below (" .. tostring(y) .. ")")
    A.eq(x or 0, 0, "and no sideways offset")
end

h.test("Inspect mode tabs become icon tabs the size of InspectHeadSlot", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = inspect({ slot = 34 })
    W.enable(ns)
    A.ok(W.isDark(c.frame), "the inspect window is a dark window")
    tabsSized(A, c, 34)
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Inspect mode tabs fall back to 37 when InspectHeadSlot is missing", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = inspect()
    W.enable(ns)
    tabsSized(A, c, 37)
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Inspect marks the selected mode tab as the character window does and follows Blizzard's selection", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = inspect({ slot = 34 })
    W.enable(ns)
    A.ok(W.marked(ns, c.modes[1]), "the selected mode tab gets the accent line and border")
    A.ok(not W.marked(ns, c.modes[2]), "the other mode tab has no accent line")
    c.modes[1].SelectedTexture:Hide()
    c.modes[2].SelectedTexture:Show()
    A.ok(not W.marked(ns, c.modes[1]) and W.marked(ns, c.modes[2]), "the accent line follows SelectedTexture")
    ns.Modern.Restore()
    c.modes[1].SelectedTexture:Show()
    A.ok(not W.marked(ns, c.modes[1]), "the tab hook does nothing while the area is off")
end)

h.test("Inspect PvP page anchors the rank title below the season label and leaves the season label alone", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = inspect({ slot = 34 })
    local seasonPoints = { c.season:GetPoint(1) }
    W.enable(ns)
    rankBelowSeason(A, c)
    A.deep({ c.season:GetPoint(1) }, seasonPoints, "the season label stays where Blizzard puts it")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Inspect skips a missing PvP page, season label or rank title without an error", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local variants = {
        { name = "no PvP page", opts = { slot = 34, pvp = false } },
        { name = "no season label", opts = { slot = 34, season = false } },
        { name = "no rank title", opts = { slot = 34, rank = false } },
        { name = "no labels", opts = { slot = 34, season = false, rank = false } },
    }
    for _, variant in ipairs(variants) do
        local c = inspect(variant.opts)
        local ok = pcall(W.enable, ns)
        A.ok(ok, variant.name .. ": applying does not throw")
        A.eq(#mock.printed, 0, variant.name .. ": nothing reported")
        A.ok(W.isDark(c.frame), variant.name .. ": the window is still skinned")
        tabsSized(A, c, 34)
        ns.Modern.Restore()
        for i = #mock.printed, 1, -1 do mock.printed[i] = nil end
    end
end)

h.test("Inspect restores tab sizes, icon points and the rank title points", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = inspect({ slot = 34 })
    local before = snapshot(c)
    W.enable(ns)
    tabsSized(A, c, 34)
    rankBelowSeason(A, c)
    ns.Modern.Restore()
    for _, tab in ipairs(c.modes) do
        A.deep({ tab:GetSize() }, { 44, 44 }, tab:GetName() .. " returns to Blizzard's size")
        A.eq(tab.Icon:GetNumPoints(), 1, tab:GetName() .. " icon returns to its one point")
        A.deep({ tab.Icon:GetPoint(1) }, { "CENTER", tab, "CENTER", 0, 0 }, tab:GetName() .. " icon point is Blizzard's")
    end
    A.deep({ c.rank:GetPoint(1) }, { "CENTER", c.pvp, "TOP", 0, -60 }, "the rank title returns to Blizzard's point")
    A.eq(c.rank:GetNumPoints(), 1, "with only that point")
    A.deep(L.diff(before), {}, "the inspect window restores exactly")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Inspect opened for the first time after Modern is applied gets the same treatment", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    W.enable(ns)
    A.eq(InspectFrame, nil, "the load-on-demand frame does not exist yet")
    local c = inspect({ slot = 34 })
    InspectFrame:Hide()
    ns.Modern.AddonLoaded("Blizzard_InspectUI")
    tabsSized(A, c, 34)
    A.ok(W.marked(ns, c.modes[1]), "the selected tab is marked")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
end)

h.test("Inspect fixes the PvP page when its regions are built only on the first show", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = inspect({ slot = 34, late = true })
    c.frame:Hide()
    W.enable(ns)
    tabsSized(A, c, 34)
    c.build()
    c.frame:Show()
    t.mock:tick(0)
    rankBelowSeason(A, c)
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep({ c.rank:GetPoint(1) }, { "CENTER", c.pvp, "TOP", 0, -60 }, "undo returns the late rank title to Blizzard's point")
end)

h.test("Inspect inner panels stand bare on the window, without a border", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local B = h.lib("modern-bags")
    W.area(ns, "windows")
    local c = inspect({ slot = 34 })
    local page = CreateFrame("Frame", "InspectPaperDollFrame", c.frame)
    page.NineSlice = R.nineSlice(page, c.list)
    W.enable(ns)
    A.ok(B.border(c.frame.Inset) == nil, "the inset gets no border")
    A.ok(B.border(page) == nil, "an inner page panel gets no border")
    A.eq(#mock.printed, 0, "nothing reported")
end)
