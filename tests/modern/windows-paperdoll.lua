-- The Forever 12.0 character window, shaped after a frame dump of the client: LeftPaneHost / RightPaneHost
-- backgrounds, PaperDollFrame.TopBackgroundStripHost behind the level text, equipment slots in
-- PaperDollItemsFrame (icon, IconBorder, NormalTexture, BorderFrame art), CharacterModelScene.ControlFrame
-- buttons, CharacterStatsPaneScrollBox (pooled category and stat rows, minimal scroll bar), the vertical
-- CharacterFrame.ModeTabs (common-sidetab art) and PaperDollSidebarTab1..3 (unnamed StatTab art).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer, atlas)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\CharacterInfo\\" .. name)
    texture:SetAlpha(0.95)
    function texture:GetAtlas() return atlas end
    list[#list + 1] = texture
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function statLine(target, list, title)
    local line = CreateFrame("Frame", nil, target)
    line:SetSize(220, 20)
    line.Background = art(line, list, title and "Title" or "Line", "BACKGROUND")
    if title then line.Title = text(line, title) else line.Label = text(line, "Stamina:") end
    return line
end

local function sideTab(parent, list, name, selected)
    local tab = CreateFrame("Frame", name, parent)
    tab:SetSize(40, 40)
    tab.Background = art(tab, list, "SideTab", "BACKGROUND")
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.SelectedTexture = art(tab, list, "SideTabSelected", "OVERLAY")
    tab.SelectedTexture:SetShown(selected)
    tab.HighlightTexture = art(tab, list, "SideTabHover", "HIGHLIGHT")
    return tab
end

local function sidebarTab(parent, list, name, selected)
    local tab = CreateFrame("CheckButton", name, parent)
    tab:SetSize(32, 32)
    tab.Icon = tab:CreateTexture(nil, "BACKGROUND")
    tab.Icon:SetTexture("Interface\\Icons\\Portrait")
    art(tab, list, "StatTab", "BORDER", "UI-Character-Info-StatTab")
    tab.marker = art(tab, list, "StatTabSelected", "OVERLAY", "UI-Character-Info-StatTab-Selected")
    tab.marker:SetShown(selected)
    _G[name] = tab
    return tab
end

local function character()
    local list = {}
    local frame = R.window("CharacterFrame")
    CharacterFrame = frame
    frame.LeftPaneHost = CreateFrame("Frame", "CharacterFrameLeftPaneHost", frame)
    art(frame.LeftPaneHost, list, "GeneralBG", "BACKGROUND")
    frame.RightPaneHost = CreateFrame("Frame", "CharacterFrameRightPaneHost", frame)
    art(frame.RightPaneHost, list, "StatBG", "BACKGROUND")
    frame.RightPaneHost.StoneBg = art(frame.RightPaneHost, list, "StoneBG")
    art(CreateFrame("Frame", nil, frame.RightPaneHost), list, "Divider", "OVERLAY")

    local paperdoll = CreateFrame("Frame", "PaperDollFrame", frame)
    PaperDollFrame = paperdoll
    paperdoll.TopBackgroundStripHost = CreateFrame("Frame", nil, paperdoll)
    art(paperdoll.TopBackgroundStripHost, list, "TopStrip")
    local level = text(CreateFrame("Frame", "PaperDollLevelInfo", paperdoll), "Level 20 Mage")

    local items = CreateFrame("Frame", "PaperDollItemsFrame", paperdoll)
    PaperDollItemsFrame = items
    local slot = CreateFrame("ItemButton", "CharacterHeadSlot", items)
    slot:SetSize(36, 36)
    slot.icon = slot:CreateTexture(nil, "BORDER")
    slot.icon:SetTexture("Interface\\Icons\\Helm")
    slot.icon:SetTexCoord(0, 1, 0, 1)
    slot.IconBorder = art(slot, list, "IconBorder", "OVERLAY")
    slot.NormalTexture = art(slot, list, "SlotNormal")
    slot.BorderFrame = CreateFrame("Frame", nil, slot)
    art(slot.BorderFrame, list, "GearSlot", "BACKGROUND")

    local scene = CreateFrame("ModelScene", "CharacterModelScene", paperdoll)
    CharacterModelScene = scene
    scene.backdrop = scene:CreateTexture(nil, "BACKGROUND")
    scene.backdrop:SetTexture("Interface\\CharacterInfo\\RaceBackground")
    scene.backdrop:SetAlpha(0.9)
    scene.ControlFrame = CreateFrame("Frame", nil, scene)
    local zoom = CreateFrame("Button", nil, scene.ControlFrame)
    scene.ControlFrame.zoomInButton = zoom
    zoom.Icon = zoom:CreateTexture(nil, "OVERLAY")
    zoom.Icon:SetTexture("Interface\\Common\\ZoomIn")
    zoom.NormalTexture = art(zoom, list, "SquareButton")

    local pane = CreateFrame("Frame", "CharacterStatsPaneScrollBox", frame)
    CharacterStatsPaneScrollBox = pane
    pane.Border = art(pane, list, "InsideFrame", "BORDER")
    pane.ScrollBox = CreateFrame("Frame", nil, pane)
    pane.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, pane.ScrollBox)
    function pane.ScrollBox:Update() end
    local category = statLine(pane.ScrollBox.ScrollTarget, list, "General")
    local row = statLine(pane.ScrollBox.ScrollTarget, list)
    local bar = CreateFrame("Frame", nil, pane)
    pane.ScrollBar = bar
    bar.Track = CreateFrame("Frame", nil, bar)
    for _, key in ipairs({ "Begin", "Middle", "End" }) do bar.Track[key] = art(bar.Track, list, "Track" .. key) end
    bar.Track.Thumb = CreateFrame("Button", nil, bar.Track)
    for _, key in ipairs({ "Begin", "Middle", "End" }) do
        bar.Track.Thumb[key] = art(bar.Track.Thumb, list, "Thumb" .. key)
    end

    frame.ModeTabs = CreateFrame("Frame", "CharacterFrameModeTabs", frame)
    local modeOne = sideTab(frame.ModeTabs, list, "CharacterFrameModeTab1", true)
    local modeTwo = sideTab(frame.ModeTabs, list, "CharacterFrameModeTab2", false)
    local sidebar = CreateFrame("Frame", "PaperDollSidebarTabs", frame)
    local sideOne = sidebarTab(sidebar, list, "PaperDollSidebarTab1", true)
    local sideTwo = sidebarTab(sidebar, list, "PaperDollSidebarTab2", false)
    return {
        frame = frame, art = list, level = level, slot = slot, scene = scene, zoom = zoom, pane = pane,
        category = category, row = row, thumb = bar.Track.Thumb, modes = { modeOne, modeTwo },
        sidebar = { sideOne, sideTwo },
    }
end

local function visibleArt(c)
    local names = {}
    for _, texture in ipairs(c.art) do
        if not R.invisible(texture, c.frame) and texture._layer ~= "HIGHLIGHT" then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

local function accent(ns, frame)
    return B.same(B.border(frame), ns.Modern.Theme().accent)
end

-- The selected sidebar tab: a shown 2 px accent line, and no border around the tab.
local function marked(ns, tab)
    for _, region in ipairs(tab._regions) do
        if region._shown and region._h == 2 and B.same(region._color, ns.Modern.Theme().accent) then return true end
    end
    return false
end

h.test("Windows replaces the character window art with flat chrome, keeps content and restores it exactly", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = character()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.eq(visibleArt(c), "", "pane, slot, model button, stats, scroll bar and tab art are all hidden")
    for _, tab in ipairs(c.modes) do
        A.ok(tab.HighlightTexture._alpha == 0, tab:GetName() .. " gold hover art is held")
    end
    A.ok(L.zoomed(c.slot.icon), "equipment icon is square-cropped")
    A.ok(B.border(c.slot) ~= nil, "equipment slot gets a flat border")
    A.ok(W.isDark(c.zoom), "model control button becomes a dark flat button")
    A.ok(not R.invisible(c.zoom.Icon, c.frame), "model control icon stays")
    A.ok(not R.invisible(c.scene.backdrop, c.frame), "model scene backdrop is content and stays")
    A.ok(not R.invisible(c.level, c.frame), "level text stays")
    A.ok(not R.invisible(c.category.Title, c.frame), "stat category title stays")
    local theme = ns.Modern.Theme()
    local strip, edge = false, false
    for _, region in ipairs(c.category._regions) do
        if region._shown ~= false and region._color then
            strip = strip or (region._color[1] == theme.strip[1] and region._h == 22)
            edge = edge or (region._w == 2 and region._color[1] == theme.accent[1])
        end
    end
    A.ok(strip and edge, "a stat category is a 22 px section strip with an accent edge")
    A.ok(not R.invisible(c.row.Label, c.frame), "stat label stays")
    for _, tab in ipairs(c.modes) do
        A.deep({ tab:GetSize() }, { 36, 36 }, tab:GetName() .. " takes the equipment slot's measured size")
        A.eq(tab.Icon:GetNumPoints(), 2, tab:GetName() .. " icon fills the tab")
        A.ok(L.zoomed(tab.Icon), tab:GetName() .. " icon is cropped square")
    end
    A.ok(accent(ns, c.modes[1]), "selected mode tab gets the accent border")
    A.ok(not accent(ns, c.modes[2]), "other mode tab keeps the theme border")
    A.ok(marked(ns, c.sidebar[1]), "selected sidebar tab gets the accent line")
    A.ok(not marked(ns, c.sidebar[2]), "other sidebar tab has no line")
    for _, tab in ipairs(c.sidebar) do
        for _, region in ipairs(tab._regions) do
            A.falsy(region._shown and region._color and (region._h == 1 or region._w == 1), "sidebar tabs have no border")
        end
    end
    A.ok(not R.invisible(c.sidebar[1].Icon, c.frame), "sidebar tab icon stays")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "character window restores exactly")
end)

h.test("Windows moves the accent border with Blizzard's tab selection and skins pooled stat rows", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = character()
    W.enable(ns)
    c.modes[1].SelectedTexture:Hide()
    c.modes[2].SelectedTexture:Show()
    A.ok(not accent(ns, c.modes[1]) and accent(ns, c.modes[2]), "mode tab accent follows SelectedTexture")
    c.sidebar[1].marker:Hide()
    c.sidebar[2].marker:Show()
    A.ok(not marked(ns, c.sidebar[1]) and marked(ns, c.sidebar[2]), "sidebar accent line follows the selected art")
    local list = {}
    local late = statLine(c.pane.ScrollBox.ScrollTarget, list)
    c.pane.ScrollBox:Update()
    A.ok(R.invisible(late.Background, c.frame), "a row acquired after apply loses its stripe on the next update")
    ns.Modern.Restore()
    c.modes[1].SelectedTexture:Show()
    A.ok(not accent(ns, c.modes[1]), "the tab hook does nothing while the area is off")
end)

h.test("Windows frames equipped items in their quality colour, also slots nested below PaperDollItemsFrame", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = character()
    local GREEN, BLUE = { 0.12, 1, 0 }, { 0, 0.44, 0.87 }
    ITEM_QUALITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },
        [2] = { r = GREEN[1], g = GREEN[2], b = GREEN[3] },
        [3] = { r = BLUE[1], g = BLUE[2], b = BLUE[3] },
    }
    local quality = { [1] = 0, [11] = 2 }
    GetInventoryItemQuality = function(unit, id) return unit == "player" and quality[id] or nil end
    PaperDollItemSlotButton_Update = function() end
    function c.slot:GetID() return 1 end
    local column = CreateFrame("Frame", nil, PaperDollItemsFrame)
    local ring = CreateFrame("ItemButton", "CharacterFinger0Slot", column)
    ring.icon = ring:CreateTexture(nil, "BORDER")
    ring.icon:SetTexture("Interface\\Icons\\Ring")
    function ring:GetID() return 11 end
    W.enable(ns)
    local theme = ns.Modern.Theme().border
    A.ok(B.same(B.border(ring), GREEN), "a nested equipment slot is framed in its quality colour")
    A.ok(B.same(B.border(c.slot), theme), "a poor equipped item keeps the theme border")
    quality[11] = 3
    mock:fire("PLAYER_EQUIPMENT_CHANGED")
    mock:drain()
    A.ok(B.same(B.border(ring), BLUE), "the border follows a changed item")
    quality[1] = 2
    PaperDollItemSlotButton_Update(c.slot)
    A.ok(B.same(B.border(c.slot), GREEN), "Blizzard's slot update repaints the border")
    ns.Modern.Restore()
    A.ok(B.border(ring) == nil, "restore removes the border")
end)
