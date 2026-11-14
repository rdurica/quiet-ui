-- The friends window of the Forever client (SocialUIFrame) for the Modern social tests, as a /qdump of it on
-- 2026-11-14 and the analysis of #32 describe it. Every builder adds the art Modernize must hold to `c.art` (dropdown
-- arrows to `c.arrows`, dividers to `c.dividers`) and what must stay to `c.keep`; the pooled rows keep their own lists
-- in `row.lists`, so a refill can be checked row by row.
--
-- Assumptions (not in the dump), the parent must confirm against the game:
--  * SELECTION: the dump has no selected-row field. Blizzard's friend card is a Button whose HighlightTexture is
--    `friends-card-selected` (HIGHLIGHT layer, always "shown"; the client draws it under the mouse). Retail's friend
--    list marks the selected friend with Button:LockHighlight() and clears the others with UnlockHighlight(), so the
--    fixture models selection as those two calls on the row (Rows.select in modern-social-rows), made by "Blizzard" after the skin is on. The
--    row's highlight texture is not shown or hidden by them. A row selected before the skin first sees it cannot be
--    told apart (no getter exists), so no test depends on that.
--  * The group header collapses through its OnClick; its CollapseButton.Icon swaps `common-button-list-minus` /
--    `common-button-list-plus` with SetAtlas (the collapsed state is the plus).
--  * The side tabs are four unkeyed Buttons on SocialUIFrame (as dumped), selected = SelectedTexture shown.
--  * The Filter dropdown has no Arrow key in the dump; its chevron is baked into `common-dropdown-b-button`.
--  * The hover wash is a faint own HIGHLIGHT texture (the client draws it only under the mouse), as shared buttons do.
--  * The real dump has every page except FriendsList hidden; the fixture keeps that, so checks look at a texture's
--    own alpha, never at its ancestors.
local S = {}
local P  -- modern-shapes, passed through S.use

local Rows  -- modern-social-rows

function S.use(shapes, rows) P, Rows = shapes, rows end

local function atlas(c, parent, list, name, layer)
    return P.texture(c, parent, list, name, layer or "ARTWORK", { atlas = true })
end

local function clickable(button)
    button.clicks = 0
    button:SetScript("OnClick", function() button.clicks = button.clicks + 1 end)
    return button
end

-- The 128 red button: keyed Left / Right / Center plates, an unkeyed highlight, a Text and a gamepad Controller.
local function red(c, f, parent, label)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(200, 32)
    for _, key in ipairs({ "Left", "Right", "Center" }) do
        button[key] = atlas(c, button, "art", "_128-RedButton-" .. key, "BACKGROUND")
    end
    local highlight = atlas(c, button, "art", "128-RedButton-Highlight", "HIGHLIGHT")
    button.GetHighlightTexture = function() return highlight end
    button.Text = P.text(c, button, label)
    button.Controller = CreateFrame("Frame", nil, button)
    f.buttons[#f.buttons + 1] = clickable(button)
    return button
end

local function gold(c, f, parent, label)
    local button = clickable(P.panelButton(c, parent, label))
    f.buttons[#f.buttons + 1] = button
    return button
end

-- DiamondMetal border (DialogBorderTemplate-like) of the notice, broadcast and raid info frames.
local function diamond(c, parent)
    local border = CreateFrame("Frame", nil, parent)
    parent.Border = border
    border.Bg = P.texture(c, border, "art", "Dialog-Bg", "BACKGROUND")
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
        "BottomEdge", "LeftEdge", "RightEdge" }) do
        border[key] = atlas(c, border, "art", "UI-Frame-DiamondMetal-" .. key, "BORDER")
    end
    return border
end

local function chrome(c, f)
    local frame = f.frame
    frame:SetSize(410, 675)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 31, -71)
    -- Held by alpha and never hidden: the checks read these one by one.
    f.chrome = {}
    local function piece(key, parent, name, layer, opts)
        local texture = P.texture(c, parent, "art", name, layer, opts)
        parent[key] = texture
        f.chrome[#f.chrome + 1] = texture
        return texture
    end
    piece("Bg", frame, "SocialUIFrameBg", "BACKGROUND", { name = "SocialUIFrameBg" })
    P.texture(c, frame, "art", "_UI-Frame-TopTileStreaks", "BORDER", { atlas = true }):Hide()
    frame.TopTileStreaks = frame._regions[#frame._regions]
    f.topFade = piece("TopFade", frame, "friends-frame-topTexBG", "ARTWORK", { atlas = true })
    piece("BottomFade", frame, "friends-frame-bottomTexBG", "ARTWORK", { atlas = true })
    frame.NineSlice = CreateFrame("Frame", nil, frame)
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
        "BottomEdge", "LeftEdge", "RightEdge" }) do
        piece(key, frame.NineSlice, "UI-Frame-Metal-" .. key, "OVERLAY", { atlas = true })
    end
    piece("Center", frame.NineSlice, "NineSliceCenter", "ARTWORK")
    frame.PortraitContainer = CreateFrame("Frame", nil, frame)
    f.portrait = piece("portrait", frame.PortraitContainer, "SocialUIFramePortrait", "OVERLAY",
        { name = "SocialUIFramePortrait" })
    frame.FrameGlow = CreateFrame("Frame", nil, frame)
    frame.FrameGlow:Hide()
    piece("GlowTexture", frame.FrameGlow, "gamepad-uiframemetal-largeportrait-focus", "BACKGROUND", { atlas = true })
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer.TitleText = P.text(c, frame.TitleContainer, "Friends")
    -- The gamepad hints are hidden art of their own; only the exact restore looks at them.
    for _, key in ipairs({ "LeftJumpHint", "RightJumpHint", "FocusJumpHint" }) do
        local hint = CreateFrame("Frame", nil, frame)
        hint:Hide()
        frame[key] = hint
        hint.NormalTexture = atlas({ art = {} }, hint, "art", "Gamepad-Xbox1-Trigger-LT-Normal")
    end
    frame.CloseButton = CreateFrame("Button", "SocialUIFrameCloseButton", frame)
    frame.CloseButton:SetSize(28, 28)
    P.buttonArt(c, frame.CloseButton, { GetNormalTexture = "RedButton-Exit", GetHighlightTexture = "RedButton-Highlight" },
        "art")
end

-- BattleNetBar: the plate, the status dropdown, the menu button, the tag with its copy button; the broadcast and
-- unavailable frames sit beside it on SocialUIFrame.
local function battleNet(c, f)
    local frame = f.frame
    local bar = CreateFrame("Frame", nil, frame)
    frame.BattleNetBar = bar
    f.bar = bar
    bar.Background = atlas(c, bar, "art", "friends-frame-infoBG", "BACKGROUND")
    local controls = CreateFrame("Frame", nil, bar)
    bar.ControlsContainer = controls
    controls.BattleNetBackground = P.texture(c, controls, "art", "BattleNetBackground", "BACKGROUND")
    f.status = P.dropdown(c, controls)
    controls.OnlineStatusDropdown = f.status
    f.menu = Rows.square(c, controls, "Icon", "friends-icon-menu")
    controls.BattleNetMenuButton = f.menu
    local tag = CreateFrame("Frame", nil, controls)
    controls.PersonalBattleTagDisplay = tag
    tag.DisplayText = P.text(c, tag, "Anaxim#2500")
    f.copy = clickable(CreateFrame("Button", nil, tag))
    tag.CopyBattleTagToClipboardButton = f.copy
    f.copy.Icon = atlas(c, f.copy, "keep", "friends-icon-battlenet-copy", "ARTWORK")
    f.copy.HighlightTexture = atlas(c, f.copy, "keep", "friends-icon-battlenet-copy", "HIGHLIGHT")

    local notice = CreateFrame("Frame", nil, frame)
    frame.BattleNetUnavailableNoticeFrame = notice
    notice:Hide()
    notice.Text = P.text(c, notice, "Blizzard services are currently unavailable.")
    diamond(c, notice)
    f.notice = notice

    local broadcast = CreateFrame("Frame", nil, frame)
    frame.BattleNetBroadcastFrame = broadcast
    broadcast:Hide()
    broadcast.Title = P.text(c, broadcast, "Broadcast")
    diamond(c, broadcast)
    f.broadcast = broadcast
    local edit = CreateFrame("EditBox", nil, broadcast)
    broadcast.EditBox = edit
    f.edit = edit
    for _, key in ipairs({ "TopLeftBorder", "TopRightBorder", "TopBorder", "BottomLeftBorder", "BottomRightBorder",
        "BottomBorder", "LeftBorder", "RightBorder", "MiddleBorder" }) do
        edit[key] = P.texture(c, edit, "art", "common-input-" .. key, "BACKGROUND")
    end
    edit.PromptText = P.text(c, edit, "Tell your friends what you're doing")
    broadcast.UpdateButton = gold(c, f, broadcast, "Update")
    broadcast.CancelButton = gold(c, f, broadcast, "Cancel")
end

local function searchBar(c, parent)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(230, 20)
    box.Background = atlas(c, box, "art", "common-searchbar-a", "BACKGROUND")
    box.searchIcon = atlas(c, box, "keep", "common-searchbar-icon-a", "OVERLAY")
    box.Instructions = P.text(c, box, "Search for keywords")
    box.clearButton = CreateFrame("Button", nil, box)
    box.clearButton.Icon = atlas(c, box.clearButton, "keep", "common-search-clearbutton", "ARTWORK")
    box.clearButton:Hide()
    return box
end

local function filter(c, parent)
    local dropdown = CreateFrame("Button", nil, parent)
    dropdown:SetSize(135, 30)
    dropdown.Background = atlas(c, dropdown, "art", "common-dropdown-b-button", "BACKGROUND")
    dropdown.Text = P.text(c, dropdown, "Filter")
    dropdown.ResetButton = clickable(CreateFrame("Button", nil, dropdown))
    dropdown.ResetButton:SetSize(23, 23)
    dropdown.ResetButton.Icon = atlas(c, dropdown.ResetButton, "keep", "auctionhouse-ui-filter-redx", "ARTWORK")
    dropdown.ResetButton:Hide()
    return dropdown
end

-- One of the three list pages (FriendsList, RecentAlliesList, FriendRequestsList).
local function listPage(c, f, key, shown)
    local list = CreateFrame("Frame", nil, f.frame)
    f.frame[key] = list
    list:SetSize(409.5, 606)
    list:SetShown(shown)
    list.TopDivider = atlas(c, list, "dividers", "perks-divider-short", "BORDER")
    list.BottomDivider = atlas(c, list, "dividers", "perks-divider-short", "BORDER")
    list.FilterBar = CreateFrame("Frame", nil, list)
    list.FilterBar.SearchBar = searchBar(c, list.FilterBar)
    list.FilterBar.SearchFilterDropdown = filter(c, list.FilterBar)
    list.LoadingSpinner = CreateFrame("Frame", nil, list)
    list.LoadingSpinner:Hide()
    list.LoadingSpinner.Ring = atlas(c, list.LoadingSpinner, "keep", "Spinner_Ring")
    list.ActionButton = red(c, f, list, "Add New Friend")
    P.scrollBox(list)
    list.ScrollBar = P.scrollBar(c, list)
    return list
end

local function sideTabs(c, f)
    f.tabs = {}
    for index = 1, 4 do
        local tab = P.sideTab(c, f.frame, "Button")
        tab:SetSize(55, 55)
        tab:SetPoint("TOPLEFT", f.frame, "TOPRIGHT", 2, -30 - (index - 1) * 60)
        tab.TabGlow:SetAlpha(0)
        tab.SelectedTexture:SetShown(index == 1)
        tab.Count = P.text(c, tab, index == 3 and "3" or "")
        f.tabs[index] = tab
    end
end

local function raid(c, f)
    local page = CreateFrame("Frame", nil, f.frame)
    f.frame.RaidFrame = page
    page:Hide()
    page.RaidDescription = P.text(c, page, "Raids are groups of more than 5 people.")
    f.assist = P.checkbox(c, page)
    page.AllAssistCheckButton = f.assist
    f.assist.Text = P.text(c, f.assist, "")
    f.roles = {}
    for _, key in ipairs({ "TankFrame", "HealerFrame", "DamagerFrame" }) do
        local role = CreateFrame("Frame", nil, page)
        page[key] = role
        role.Count = P.text(c, role, "0")
        role.Icon = atlas(c, role, "keep", "UI-LFG-RoleIcon-" .. key)
        f.roles[#f.roles + 1] = role
    end
    page.RaidInfoButton = red(c, f, page, "Raid Info")
    page.ConvertToRaidButton = red(c, f, page, "Convert To Raid")
    page.GroupsFrame = CreateFrame("Frame", nil, page)
    -- The raid info frame: rock insets with a DiamondMetal edge, its own border, close cross, list and button.
    local info = CreateFrame("Frame", nil, f.frame)
    f.frame.RaidInfoFrame = info
    f.info = info
    info:Hide()
    info:SetSize(345, 250)
    for _, key in ipairs({ "TopInset", "BottomInset" }) do info[key] = P.texture(c, info, "art", "TopInset", "BACKGROUND") end
    info.TopInsetEdge = atlas(c, info, "art", "_UI-Frame-DiamondMetal-EdgeTop", "BACKGROUND")
    diamond(c, info)
    info.CloseButton = CreateFrame("Button", nil, info)
    info.CloseButton:SetSize(24, 24)
    P.buttonArt(c, info.CloseButton, { GetNormalTexture = "RedButton-Exit", GetHighlightTexture = "RedButton-Highlight" },
        "art")
    P.scrollBox(info)
    info.ScrollBar = P.scrollBar(c, info)
    info.ExtendButton = red(c, f, info, "Extend Raid Lock")
end

-- The ignore list window (a ButtonFrameTemplate of its own on SocialUIFrame).
local function ignore(c, f)
    local window = P.window(c, nil, f.frame)
    f.frame.IgnoreListFrame = window
    f.ignore = window
    window:Hide()
    window.BlockButton = gold(c, f, window, "Ignore Player")
    window.UnblockButton = gold(c, f, window, "Remove from list")
    P.scrollBox(window)
    window.ScrollBar = P.scrollBar(c, window)
end

-- The old FriendsFrame, still skinned when a client opens it.
function S.legacy(c)
    local frame = P.window(c, "FriendsFrame")
    P.texture(c, frame, "art", "Battlenet-Portrait", "OVERLAY", { name = "FriendsFrameIcon" })
    P.tab(c, frame, "FriendsFrameTab1")
    return frame
end

-- Builds SocialUIFrame into `c` (P.new()); returns its named pieces. `f.pool` holds the pooled rows.
function S.build(c)
    c.dividers = {}
    local f = { buttons = {}, pool = { header = {}, friend = {} } }
    f.frame = CreateFrame("Frame", "SocialUIFrame", UIParent)
    chrome(c, f)
    battleNet(c, f)
    f.recent = listPage(c, f, "RecentAlliesList", false)
    f.requests = listPage(c, f, "FriendRequestsList", false)
    f.requests.RealIDWarning = CreateFrame("Frame", nil, f.requests)
    f.requests.RealIDWarning.ContinueButton = red(c, f, f.requests.RealIDWarning, "Continue")
    f.list = listPage(c, f, "FriendsList", true)
    f.frame.activeContentFrame = f.list
    f.search, f.filter = f.list.FilterBar.SearchBar, f.list.FilterBar.SearchFilterDropdown
    f.add, f.box = f.list.ActionButton, f.list.ScrollBox
    for _, item in ipairs(Rows.data) do
        local own = P.new()
        if item.kind == "header" then
            f.pool.header[1] = Rows.header(own, f.box.ScrollTarget, item.label)
            CreateFrame("Frame", nil, f.box.ScrollTarget):SetSize(364.5, 2)
        else
            f.pool.friend[#f.pool.friend + 1] = Rows.row(own, f.box.ScrollTarget, item)
        end
    end
    sideTabs(c, f)
    raid(c, f)
    ignore(c, f)
    return f
end

return S
