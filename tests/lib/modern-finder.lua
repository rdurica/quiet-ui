-- The vanilla-style group finder (Blizzard_GroupFinder_VanillaStyle of the Forever UI source) for the Modern finder
-- tests: LFGParentFrame with the listing, browse and who pages, side tabs, role buttons, checkboxes, refresh / search
-- / delist buttons, dropdowns, pooled browse results and the minimap LFG eye. Like modern-shapes, every builder adds
-- the art Modernize must hold to `c.art` (dropdown arrows to `c.arrows`) and what must stay to `c.keep`.
--
-- VERIFIED keys (they came from the first finder fixture, built from the source): LFGParentFrame,
-- LFGParentFrameCloseButton, LFGParentFrameTab3, LFGWhoListFrame (BackgroundArt, headerBackground, insideFrame,
-- BarTop), LFGBrowseFrame, results with ResultBG / Highlight / CollapseIcon / ExpandIcon.
--
-- ASSUMED, NOT VERIFIED AGAINST SOURCE (the source is not on the test machine): everything in K below. When the real
-- keys differ, correct them here, in one place, and the tests follow.
local F = {}
local P  -- modern-shapes, passed through F.use

function F.use(shapes) P = shapes end

local K = {
    -- The round portrait on LFGParentFrame: keys as WindowChrome's TEXTURE_KEYS hold them, atlases name a portrait.
    portrait = "Portrait", portraitAtlas = "groupfinder-eye-portrait",
    portraitFrame = "PortraitFrame", portraitFrameAtlas = "groupfinder-eye-portraitframe",
    -- The three side tabs at the right edge: CheckButtons named <prefix>1..3 with Icon / SelectedTexture / Background.
    tabPrefix = "LFGParentFrameSideTab",
    -- The pages (the browse and who names are verified) and the browse stone backdrop (a texture on the page).
    listing = "LFGListingFrame", browseBackdrop = "BackgroundArt", browseBackdropAtlas = "groupfinder-browse-stone",
    -- Role buttons on the listing page: Button with `icon`, a round `Border`, a NormalTexture box and a CheckButton
    -- child without Text wearing checkbox art, small, bottom-left of the icon.
    roles = { "Tank", "Healer", "Damage", "Leader" }, rolePrefix = "LFGListingFrameRole",
    roleBorderAtlas = "groupfinder-roles-border", roleBoxAtlas = "groupfinder-role-box",
    -- Labelled checkboxes of the listing page.
    dungeons = "Dungeons", rows = { "Deadmines", "Wailing Caverns", "Shadowfang Keep" },
    levelRanges = "Show All Level Ranges",
    -- Gold icon buttons: RefreshButton on browse, SearchButton on who, DelistButton (red plate) on the listing.
    refresh = "RefreshButton", search = "SearchButton", delist = "DelistButton",
    goldAtlas = "common-iconbutton-gold", redAtlas = "common-iconbutton-red",
    -- The minimap eye outside the finder (QueueStatus / LFGEye): never touched.
    eye = "QueueStatusButton", eyeFrame = "LFGEye",
}
F.keys = K

local function atlas(c, parent, list, name, layer)
    return P.texture(c, parent, list, name, layer or "ARTWORK", { atlas = true })
end

-- A Button wearing gold (or red) square plates: keyed and answered by the getters, over a kept Icon.
-- `iconList`: where the icon belongs (kept, or held when a glyph replaces it).
local function plateButton(c, parent, name, plate, iconAtlas, iconList)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(24, 24)
    button.Icon = atlas(c, button, iconList or "keep", iconAtlas, "ARTWORK")
    button.Icon:SetVertexColor(1, 1, 1, 1)
    button.Icon:SetDesaturated(false)
    local art = P.buttonArt(c, button, { GetNormalTexture = plate .. "-up", GetPushedTexture = plate .. "-down",
        GetHighlightTexture = plate .. "-highlight" }, "art")
    button.NormalTexture, button.PushedTexture, button.HighlightTexture =
        art.GetNormalTexture, art.GetPushedTexture, art.GetHighlightTexture
    button.clicks = 0
    button:SetScript("OnClick", function() button.clicks = button.clicks + 1 end)
    return button
end

local function labelled(c, parent, label)
    local box = P.checkbox(c, parent)
    box:SetSize(24, 24)
    box.Text = P.text(c, box, label)
    return box
end

local function roleButton(c, parent, role)
    local button = CreateFrame("Button", K.rolePrefix .. role .. "Button", parent)
    button:SetSize(64, 64)
    button.icon = atlas(c, button, "keep", "groupfinder-icon-role-large-" .. role:lower(), "ARTWORK")
    button.Border = atlas(c, button, "art", K.roleBorderAtlas, "OVERLAY")
    P.buttonArt(c, button, { GetNormalTexture = K.roleBoxAtlas }, "art")
    button.check = P.checkbox(c, button)
    button.check:SetSize(20, 20)
    button.check:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT", 0, 0)
    return button
end

-- The listing page: role buttons, Dungeons, the dungeon rows, Show All Level Ranges, a dropdown and the delist button.
local function listing(c, f)
    local page = P.window(c, K.listing, f.parent)
    page.CloseButton = nil
    f.listing = page
    f.roles = {}
    for _, role in ipairs(K.roles) do f.roles[role] = roleButton(c, page, role) end
    f.roles.Healer.check:SetChecked(true)
    f.dungeons = labelled(c, page, K.dungeons)
    f.rows = {}
    local list = CreateFrame("Frame", nil, page)
    for _, name in ipairs(K.rows) do f.rows[#f.rows + 1] = labelled(c, list, name) end
    f.levels = labelled(c, page, K.levelRanges)
    f.levels:SetChecked(true)
    page.ActivityDropdown = P.dropdown(c, page)
    f.delist = plateButton(c, page, K.listing .. K.delist, K.redAtlas, "common-icon-redx", "art")
    page[K.delist] = f.delist
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
    f.refresh = plateButton(c, page, "LFGBrowseFrameRefreshButton", K.goldAtlas, "groupfinder-icon-refresh")
    page[K.refresh] = f.refresh
    page.CategoryDropdown = P.dropdown(c, page)
    f.box = P.scrollBox(page)
    -- The results keep their own lists (f.results), so their tests need not wait for the rest of the finder.
    f.results = P.new()
    f.head, f.nested, f.plain = F.results(f.results, f.box.ScrollTarget)
end

local function who(c, f)
    local page = P.window(c, "LFGWhoListFrame", f.parent)
    page.CloseButton = nil
    for key, name in pairs({ BackgroundArt = "groupfinder-background", headerBackground = "groupfinder-Stat-StoneBG",
        insideFrame = "common-insideframe", BarTop = "groupfinder-ScrollLine" }) do
        page[key] = P.texture(c, page, "art", name:lower(), "BACKGROUND", { atlas = true })
    end
    page.FilterDropdown = P.dropdown(c, page)
    f.search = plateButton(c, page, "LFGWhoListFrameSearchButton", K.goldAtlas, "groupfinder-icon-search")
    page[K.search] = f.search
    local box = P.scrollBox(page)
    f.row = P.listRow(c, box.ScrollTarget)
    f.who, f.whoBox = page, box
end

-- The round portrait, the close button, tab 3 and the three side tabs (the first is selected).
local function chrome(c, f)
    local parent = f.parent
    parent[K.portrait] = atlas(c, parent, "art", K.portraitAtlas, "ARTWORK")
    parent[K.portraitFrame] = atlas(c, parent, "art", K.portraitFrameAtlas, "OVERLAY")
    f.portrait, f.portraitFrame = parent[K.portrait], parent[K.portraitFrame]
    local close = CreateFrame("Button", "LFGParentFrameCloseButton", parent)
    P.buttonArt(c, close, { GetNormalTexture = "RedButton-Exit" }, "art")
    P.tab(c, parent, "LFGParentFrameTab3")
    f.tabs = {}
    for index = 1, 3 do
        local tab = P.sideTab(c, parent, "CheckButton", K.tabPrefix .. index)
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
