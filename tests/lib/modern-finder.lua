-- The vanilla-style group finder (Blizzard_GroupFinder_VanillaStyle of the Forever UI source) for the Modern finder
-- tests: LFGParentFrame with the listing, browse and who pages, side tabs, role buttons, checkboxes, refresh / search
-- / delist buttons, dropdowns, pooled browse results and the minimap LFG eye. Like modern-shapes, every builder adds
-- the art Modernize must hold to `c.art` (dropdown arrows to `c.arrows`) and what must stay to `c.keep`.
--
-- Keys, atlases and file IDs as the Forever client (1.60.1) dumps them (QuietUIDump, LFGParentFrame and its pages).
local F = {}
local P  -- modern-shapes, passed through F.use

function F.use(shapes) P = shapes end

local K = {
    -- LFGParentFramePortrait: a Button with the eye frame (`texture`) and the eye's flipbook frames.
    portrait = "LFGParentFramePortrait", portraitAtlas = "groupfinder-eye-frame",
    -- The three side tabs: Frames keyed on LFGParentFrame with Background / Icon / SelectedTexture / TabGlow.
    tabs = { "ListingTab", "BrowsingTab", "WhoListingTab" },
    listing = "LFGListingFrame", browseBackdrop = "BackgroundArt", browseBackdropAtlas = "groupfinder-background",
    -- SoloRoleButtons: Buttons whose NormalTexture is the role icon, a keyed Background plate, a dim `cover` and a
    -- label-less CheckButton keyed CheckButton; the leader button (NewPlayerFriendlyButton) has no Background.
    roles = { "Tank", "Healer", "DPS" },
    -- Interface\Buttons\UI-CheckBox-*: up, down, highlight, check, by file ID.
    checkFiles = { up = 130755, down = 130752, highlight = 130753, check = 130751 },
    dungeons = "Dungeons", rows = { "Deadmines", "Wailing Caverns", "Shadowfang Keep" },
    levelRanges = "Show All Level Ranges",
    -- RefreshButton (browse): plate by file ID through the getters only, a keyed Icon. WhoSearch (who): a tertiary
    -- square plate. DelistButton (own listing row): a nine-piece stretch button with the red X Icon.
    refreshFiles = { normal = 796424, pushed = 796423, highlight = 130757 }, refreshIcon = 851904,
    stretch = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
        "BottomMiddle", "MiddleMiddle" },
    -- The minimap eye outside the finder (QueueStatus / LFGEye): never touched.
    eye = "QueueStatusButton", eyeFrame = "LFGEye",
}
F.keys = K

local function atlas(c, parent, list, name, layer)
    return P.texture(c, parent, list, name, layer or "ARTWORK", { atlas = true })
end

local function file(c, parent, list, id, layer)
    local t = P.texture(c, parent, list, "x", layer or "ARTWORK")
    t:SetTexture(id)
    return t
end

-- UICheckButtonTemplate as the finder's role and level range boxes use it: art by file ID, no atlas, no label.
local function idCheckbox(c, parent)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    local ids = K.checkFiles
    local art = { GetNormalTexture = file(c, box, "art", ids.up), GetPushedTexture = file(c, box, "art", ids.down),
        GetHighlightTexture = file(c, box, "art", ids.highlight, "HIGHLIGHT"),
        GetCheckedTexture = file(c, box, "art", ids.check, "OVERLAY") }
    for getter, region in pairs(art) do box[getter] = function() return region end end
    return box
end

local function clickable(button)
    button.clicks = 0
    button:SetScript("OnClick", function() button.clicks = button.clicks + 1 end)
    return button
end

-- LFGBrowseFrameRefreshButton: a gold square plate by file ID, answered only by the getters, over a keyed Icon.
local function refreshButton(c, parent)
    local button = CreateFrame("Button", "LFGBrowseFrameRefreshButton", parent)
    button:SetSize(32, 32)
    button.Icon = file(c, button, "keep", K.refreshIcon, "ARTWORK")
    button.Icon:SetVertexColor(1, 1, 1, 1)
    button.Icon:SetDesaturated(false)
    local ids = K.refreshFiles
    local art = { GetNormalTexture = file(c, button, "art", ids.normal), GetPushedTexture = file(c, button, "art", ids.pushed),
        GetHighlightTexture = file(c, button, "art", ids.highlight, "HIGHLIGHT") }
    for getter, region in pairs(art) do button[getter] = function() return region end end
    return clickable(button)
end

-- WhoSearch: a tertiary square plate, keyed and answered by the getters, over a kept search Icon.
local function searchButton(c, parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(36, 36)
    button.Icon = atlas(c, button, "keep", "common-icon-search", "OVERLAY")
    button.Icon:SetVertexColor(1, 1, 1, 1)
    button.Icon:SetDesaturated(false)
    local art = P.buttonArt(c, button, { GetNormalTexture = "common-button-tertiary-square-normal",
        GetPushedTexture = "common-button-tertiary-square-pressed",
        GetHighlightTexture = "common-button-tertiary-square-normal" }, "art")
    button.NormalTexture, button.PushedTexture, button.HighlightTexture =
        art.GetNormalTexture, art.GetPushedTexture, art.GetHighlightTexture
    return clickable(button)
end

-- The own listing's DelistButton (UIMenuButtonStretchTemplate): nine stretch pieces and the red X Icon.
local function delistButton(c, parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(23, 21)
    for _, key in ipairs(K.stretch) do button[key] = file(c, button, "art", 383587, "BACKGROUND") end
    button.Icon = atlas(c, button, "art", "groupfinder-icon-redx")
    return clickable(button)
end

local function labelled(c, parent, label)
    local box = P.checkbox(c, parent)
    box:SetSize(24, 24)
    box.Text = P.text(c, box, label)
    return box
end

local function roleButton(c, parent, role, name, background)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(64, 64)
    local icon = atlas(c, button, "keep", "UI-LFG-RoleIcon-" .. role)
    function button:GetNormalTexture() return icon end
    if background then button.Background = atlas(c, button, "art", "UI-LFG-RoleIcon-" .. role .. "-Background", "BACKGROUND") end
    button.cover = file(c, button, "keep", 337499, "OVERLAY")
    button.CheckButton = idCheckbox(c, button)
    button.CheckButton:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    return button
end

-- The listing page: role buttons, Dungeons, the dungeon rows, Show All Level Ranges, a dropdown and the delist button.
local function listing(c, f)
    local page = P.window(c, K.listing, f.parent)
    page.CloseButton = nil
    f.listing = page
    local solo = CreateFrame("Frame", "LFGListingFrameSoloRoleButtons", page)
    page.SoloRoleButtons = solo
    f.roles = {}
    for _, role in ipairs(K.roles) do
        f.roles[role] = roleButton(c, solo, role, "LFGListingFrameSoloRoleButtonsRoleButton" .. role, true)
        solo[role] = f.roles[role]
    end
    f.roles.Leader = roleButton(c, page, "Leader", "LFGListingFrameNewPlayerFriendlyButton", false)
    page.NewPlayerFriendlyButton = f.roles.Leader
    f.roles.Healer.CheckButton:SetChecked(true)
    f.dungeons = labelled(c, page, K.dungeons)
    f.rows = {}
    local list = CreateFrame("Frame", nil, page)
    for _, name in ipairs(K.rows) do f.rows[#f.rows + 1] = labelled(c, list, name) end
    local levels = CreateFrame("Frame", nil, page)
    page.LevelRangesCheckbox = levels
    levels.Text = P.text(c, levels, K.levelRanges)
    f.levels = idCheckbox(c, levels)
    f.levels.Text = P.text(c, f.levels, "")
    levels.Checkbox = f.levels
    f.levels:SetChecked(true)
    page.ActivityDropdown = P.dropdown(c, page)
end

-- Pooled browse results (Blizzard_LFGVanilla_Browse.xml): a grouping header (common-button-list-collapseExpand with
-- plus / minus icons), a nested listing (common-button-list-mid2 with hover and selection) and a plain one. The
-- listings carry role icons and empty role dots, which stay.
function F.results(c, target)
    local head = CreateFrame("Button", nil, target)
    head:SetSize(312, 36)
    head.ResultBG = atlas(c, head, "art", "common-button-list-collapseExpand", "BACKGROUND")
    head.Highlight = atlas(c, head, "art", "common-button-list-collapseExpand", "HIGHLIGHT")
    head.ExpandIcon = atlas(c, head, "art", "common-button-list-plus")
    head.CollapseIcon = atlas(c, head, "art", "common-button-list-minus")
    head.ExpandIcon:Hide()
    head.CategoryLabel = P.text(c, head, "Groups")
    local nested = CreateFrame("Button", nil, target)
    nested.ResultBG = atlas(c, nested, "art", "common-button-list-mid2", "BACKGROUND")
    nested.Highlight = atlas(c, nested, "art", "common-button-list-mid2-hover", "BACKGROUND")
    nested.Selected = atlas(c, nested, "keep", "common-button-list-mid2-selected", "OVERLAY")
    nested.Name = P.text(c, nested, "Milk Ninja")
    nested.PartyIcon = atlas(c, nested, "keep", "groupfinder-icon-leader")
    nested.RoleIcon = atlas(c, nested, "keep", "groupfinder-icon-role-tank")
    nested.EmptyDot = atlas(c, nested, "keep", "groupfinder-icon-emptyslot")
    local plain = CreateFrame("Button", nil, target)
    plain.ResultBG = atlas(c, plain, "art", "groupfinder-highlightbar", "BACKGROUND")
    plain.Name = P.text(c, plain, "Leif Jorunn")
    plain.RoleIcon = atlas(c, plain, "keep", "groupfinder-icon-role-healer")
    return head, nested, plain
end

local function browse(c, f)
    local page = P.window(c, "LFGBrowseFrame", f.parent)
    f.browse = page
    f.backdrop = atlas(c, page, "art", K.browseBackdropAtlas, "BACKGROUND")
    page[K.browseBackdrop] = f.backdrop
    f.refresh = refreshButton(c, page)
    page.RefreshButton = f.refresh
    page.CategoryDropdown = P.dropdown(c, page)
    f.box = P.scrollBox(page)
    -- The results keep their own lists (f.results), so their tests need not wait for the rest of the finder.
    f.results = P.new()
    f.head, f.nested, f.plain = F.results(f.results, f.box.ScrollTarget)
    -- The own listing row carries the delist button inside its DataDisplay.
    local display = CreateFrame("Frame", nil, f.nested)
    f.nested.DataDisplay = display
    f.delist = delistButton(c, display)
    display.DelistButton = f.delist
end

local function who(c, f)
    local page = P.window(c, "LFGWhoListFrame", f.parent)
    page.CloseButton = nil
    for key, name in pairs({ BackgroundArt = "groupfinder-background", headerBackground = "groupfinder-Stat-StoneBG",
        insideFrame = "common-insideframe", BarTop = "groupfinder-ScrollLine" }) do
        page[key] = P.texture(c, page, "art", name:lower(), "BACKGROUND", { atlas = true })
    end
    page.FilterDropdown = P.dropdown(c, page)
    f.search = searchButton(c, page)
    page.WhoSearch = f.search
    local box = P.scrollBox(page)
    f.row = P.listRow(c, box.ScrollTarget)
    f.who, f.whoBox = page, box
end

-- The round portrait, the close button, tab 3 and the three side tabs (the first is selected).
local function chrome(c, f)
    local parent = f.parent
    -- The portrait is held as a whole: its eye frame and flipbook frames go with it.
    local portrait = CreateFrame("Button", K.portrait, parent)
    portrait:SetSize(64, 64)
    portrait.texture = atlas(c, portrait, nil, K.portraitAtlas)
    portrait.EyeInitial = CreateFrame("Frame", nil, portrait)
    portrait.EyeInitial.EyeInitialTexture = atlas(c, portrait.EyeInitial, nil, "groupfinder-eye-big-flipbook-initial")
    portrait:SetAlpha(0.9)
    f.portrait = portrait
    local close = CreateFrame("Button", "LFGParentFrameCloseButton", parent)
    P.buttonArt(c, close, { GetNormalTexture = "RedButton-Exit" }, "art")
    P.tab(c, parent, "LFGParentFrameTab3")
    f.tabs = {}
    for index = 1, 3 do
        local tab = P.sideTab(c, parent, "Frame")
        parent[K.tabs[index]] = tab
        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, -30 - (index - 1) * 48)
        tab.SelectedTexture:SetShown(index == 1)
        tab.TabGlow:SetShown(index == 1)
        f.tabs[index] = tab
    end
end

-- The minimap LFG eye is not part of the finder; its frames and art must stay as Blizzard has them.
local function eye(c, f)
    local button = CreateFrame("Button", K.eye, UIParent)
    f.eye = button
    button.Background = atlas(c, button, "keep", "groupfinder-eye-frame", "BACKGROUND")
    button.Highlight = atlas(c, button, "keep", "groupfinder-eye-frame-hover", "HIGHLIGHT")
    local inner = CreateFrame("Frame", K.eyeFrame, button)
    inner.Portrait = atlas(c, inner, "keep", "groupfinder-eye-flipbook", "ARTWORK")
    f.eyeFrame = inner
end

-- Builds the whole finder into `c` (P.new()); returns its named pieces.
function F.build(c)
    local f = {}
    f.parent = CreateFrame("Frame", "LFGParentFrame", UIParent)
    f.parent:SetSize(458, 535)
    chrome(c, f)
    listing(c, f)
    browse(c, f)
    who(c, f)
    eye(c, f)
    f.pages = { listing = f.listing, browse = f.browse, who = f.who }
    return f
end

-- Every checked box's accent mark shown (ARTWORK, accent colour), as windows-controls.lua reads it.
function F.mark(button, theme)
    for _, region in ipairs(button._regions) do
        if region._layer == "ARTWORK" and region._color and region._color[1] == theme.accent[1] then
            return region._shown and true or false
        end
    end
    return false
end

-- True when the checkbox has its own dark square with a thin border (a flat Modern checkbox).
function F.flat(button, theme)
    local track, edge = 0, 0
    for _, region in ipairs(button._regions) do
        local c = region._shown and region._color
        if c and c[1] == theme.track[1] and c[3] == theme.track[3] then track = track + 1 end
        if c and c[1] == theme.border[1] and c[3] == theme.border[3] then edge = edge + 1 end
    end
    return track == 1 and edge == 4
end

return F
