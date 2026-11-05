-- Blizzard's shared templates as the Forever UI source (1.60.1) builds them, for the window shapes. Every builder
-- adds the art Modernize must hold to `c.art` and what must stay to `c.keep`; a texture with an atlas answers
-- GetAtlas. Named pieces (`$parentLeft`) are globals, since the mock keeps no region names.
local P = {}

function P.new()
    return { art = {}, keep = {} }
end

local function texture(c, parent, list, file, layer, opts)
    opts = opts or {}
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    if opts.atlas then
        t._atlas = file
        function t:GetAtlas() return self._atlas end
        function t:SetAtlas(atlas) self._atlas = atlas end
    else
        t:SetTexture("Interface\\Shared\\" .. file)
    end
    t:SetAlpha(0.9)
    t._label = file
    if opts.name then
        _G[opts.name] = t
        function t:GetName() return opts.name end
    end
    if list then c[list][#c[list] + 1] = t end
    return t
end
P.texture = texture

local function text(c, parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    c.keep[#c.keep + 1] = font
    return font
end
P.text = text

-- Button art set through SetNormalTexture and friends, answered by the getters.
local function buttonArt(c, button, files, list)
    local art = {}
    for getter, file in pairs(files) do
        art[getter] = texture(c, button, list, file, getter == "GetHighlightTexture" and "HIGHLIGHT" or "ARTWORK")
    end
    for getter, region in pairs(art) do button[getter] = function() return region end end
    return art
end
P.buttonArt = buttonArt

-- ButtonFrameTemplate: NineSlice, Bg, TopTileStreaks, PortraitContainer, TitleContainer, CloseButton, Inset.
function P.window(c, name, parent)
    local frame = CreateFrame("Frame", name, parent or UIParent)
    frame:SetSize(480, 420)
    frame.NineSlice = CreateFrame("Frame", nil, frame)
    for _, key in ipairs({ "TopLeftCorner", "TopEdge", "Center" }) do
        frame.NineSlice[key] = texture(c, frame.NineSlice, "art", "NineSlice-" .. key, "BORDER")
    end
    frame.Bg = texture(c, frame, "art", "UI-Background-Rock", "BACKGROUND")
    frame.TopTileStreaks = texture(c, frame, "art", "TopTileStreaks", "BORDER")
    frame.PortraitContainer = CreateFrame("Frame", nil, frame)
    frame.PortraitContainer.portrait = texture(c, frame.PortraitContainer, "art", "Portrait", "OVERLAY")
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer.TitleText = text(c, frame.TitleContainer, (name or "Window") .. " title")
    frame.CloseButton = CreateFrame("Button", name and name .. "CloseButton", frame)
    buttonArt(c, frame.CloseButton, { GetNormalTexture = "RedButton-Exit", GetHighlightTexture = "RedButton-Highlight" },
        "art")
    frame.Inset = P.inset(c, frame)
    return frame
end

-- InsetFrameTemplate: its own Bg and NineSlice.
function P.inset(c, parent, name)
    local inset = CreateFrame("Frame", name, parent)
    inset.Bg = texture(c, inset, "art", "Inset-Bg", "BACKGROUND")
    inset.NineSlice = CreateFrame("Frame", nil, inset)
    inset.NineSlice.Center = texture(c, inset.NineSlice, "art", "Inset-Center", "BORDER")
    return inset
end

-- UIPanelButtonTemplate: keyed Left / Right / Middle, a text and a highlight texture.
function P.panelButton(c, parent, label, name)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(104, 22)
    for _, key in ipairs({ "Left", "Right", "Middle" }) do
        button[key] = texture(c, button, "art", "UI-Panel-Button-Up-" .. key, "BACKGROUND")
    end
    buttonArt(c, button, { GetHighlightTexture = "UIPanelButtonHighlightTexture" }, "art")
    button.Text = text(c, button, label)
    return button
end

-- An input box whose pieces are only named (`$parentLeft`, AutoCompleteEditBoxTemplate in the mail window).
function P.namedInput(c, parent, name)
    local box = CreateFrame("EditBox", name, parent)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        texture(c, box, "art", "Common-Input-Border-" .. key, "BACKGROUND", { name = name .. key })
    end
    return box
end

-- ThinGoldEdgeTemplate: the money edge, named Left / Right / Middle in Interface\Common\Moneyframe.
function P.moneyEdge(c, parent, name)
    local edge = CreateFrame("Frame", name, parent)
    for _, key in ipairs({ "Left", "Right", "Middle" }) do
        local piece = texture(c, edge, "art", "x", "BACKGROUND", { name = name .. key })
        piece:SetTexture("Interface\\Common\\Moneyframe")
    end
    return edge
end

-- MinimalScrollBar: Track with Begin / Middle / End and a Thumb, Back and Forward stepper buttons.
function P.scrollBar(c, parent)
    local bar = CreateFrame("EventFrame", nil, parent)
    bar.Track = CreateFrame("Frame", nil, bar)
    bar.Track.Middle = texture(c, bar.Track, "art", "minimal-scrollbar-track-middle")
    bar.Track.Thumb = CreateFrame("Button", nil, bar.Track)
    bar.Track.Thumb.Middle = texture(c, bar.Track.Thumb, "art", "minimal-scrollbar-thumb-middle")
    for _, key in ipairs({ "Back", "Forward" }) do
        bar[key] = CreateFrame("Button", nil, bar)
        bar[key].Texture = texture(c, bar[key], "art", "minimal-scrollbar-arrow-" .. key)
    end
    return bar
end

-- UIPanelScrollBarTemplate: a Slider with ScrollUpButton, ScrollDownButton and ThumbTexture.
function P.sliderBar(c, parent, name)
    local bar = CreateFrame("Slider", name, parent)
    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local button = CreateFrame("Button", nil, bar)
        bar[key] = button
        buttonArt(c, button, { GetNormalTexture = "UI-ScrollBar-" .. key .. "-Up",
            GetPushedTexture = "UI-ScrollBar-" .. key .. "-Down", GetDisabledTexture = "UI-ScrollBar-" .. key .. "-Off",
            GetHighlightTexture = "UI-ScrollBar-" .. key .. "-Highlight" }, "art")
    end
    bar.ThumbTexture = texture(c, bar, "art", "UI-ScrollBar-Knob", "OVERLAY")
    return bar
end

-- An ItemButton (icon, IconBorder, NormalTexture); `slot` adds a named `$parentSlot` texture behind it.
function P.itemButton(c, parent, name, opts)
    opts = opts or {}
    local button = CreateFrame(opts.kind or "ItemButton", name, parent)
    button.icon = texture(c, button, "keep", "Icons\\" .. (name or "Item"), "BORDER")
    button.icon:SetTexCoord(0, 1, 0, 1)
    if opts.Icon then button.Icon = button.icon end
    button.IconBorder = texture(c, button, "art", "WhiteIconFrame", "OVERLAY")
    button.IconBorder:Hide()
    local normal = texture(c, button, "art", "UI-Quickslot2")
    function button:GetNormalTexture() return normal end
    if opts.slot then texture(c, button, "art", "UI-EmptySlot-White", "BACKGROUND", { name = name .. "Slot" }) end
    return button
end

-- A slot card (TradeItemTemplate): SlotTexture, a named NameFrame, a name and an ItemButton.
function P.card(c, parent, name)
    local card = CreateFrame("Frame", name, parent)
    card.SlotTexture = texture(c, card, "art", "UI-EmptySlot", "BACKGROUND")
    texture(c, card, "art", "UI-QuestItemNameFrame", "BACKGROUND", { name = name .. "NameFrame" })
    card.Name = text(c, card, name)
    card.ItemButton = P.itemButton(c, card, name .. "ItemButton")
    return card
end

-- WowStyle1DropdownTemplate: Background, Arrow, Text.
function P.dropdown(c, parent)
    local dropdown = CreateFrame("DropdownButton", nil, parent)
    dropdown.Background = texture(c, dropdown, "art", "common-dropdown-textholder", "BACKGROUND", { atlas = true })
    dropdown.Arrow = texture(c, dropdown, "keep", "common-dropdown-a-button", "OVERLAY", { atlas = true })
    dropdown.Text = text(c, dropdown, "All")
    return dropdown
end

-- UICheckButtonTemplate without a label: checkbox art only.
function P.checkbox(c, parent)
    local box = CreateFrame("CheckButton", nil, parent)
    buttonArt(c, box, { GetNormalTexture = "UI-CheckBox-Up", GetCheckedTexture = "UI-CheckBox-Check",
        GetHighlightTexture = "UI-CheckBox-Highlight" }, "art")
    return box
end

-- A square icon button (UI-SquareButton plates) that keeps its Icon.
function P.squareButton(c, parent)
    local button = CreateFrame("Button", nil, parent)
    button.Icon = texture(c, button, "keep", "UI-RefreshButton")
    buttonArt(c, button, { GetNormalTexture = "UI-SquareButton-Up", GetPushedTexture = "UI-SquareButton-Down",
        GetHighlightTexture = "UI-Common-MouseHilight" }, "art")
    return button
end

-- UIMenuButtonStretchTemplate: nine silver pieces.
function P.stretchButton(c, parent, label)
    local button = CreateFrame("Button", nil, parent)
    for _, key in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
        "BottomMiddle", "MiddleMiddle" }) do
        button[key] = texture(c, button, "art", "UI-Silver-Button-Up-" .. key, "BACKGROUND")
    end
    button.Text = text(c, button, label)
    return button
end

-- LargeSideTabButtonTemplate: Background, Icon, SelectedTexture, TabGlow, HighlightTexture.
function P.sideTab(c, parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab.Background = texture(c, tab, "art", "common-sidetab", "BACKGROUND", { atlas = true })
    tab.Icon = texture(c, tab, "keep", "Icons\\Tab")
    tab.SelectedTexture = texture(c, tab, "art", "common-sidetab-selected", "OVERLAY", { atlas = true })
    tab.TabGlow = texture(c, tab, "art", "common-sidetab-selected", "OVERLAY", { atlas = true })
    tab.HighlightTexture = texture(c, tab, "art", "common-sidetab-hover", "HIGHLIGHT", { atlas = true })
    return tab
end

-- PanelTabButtonTemplate with its three highlight pieces.
function P.tab(c, parent, name)
    local tab = CreateFrame("Button", name, parent)
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight",
        "MiddleHighlight", "RightHighlight" }) do
        tab[key] = texture(c, tab, "art", "uiframe-tab-" .. key, key:find("Highlight") and "HIGHLIGHT" or "BACKGROUND")
    end
    tab.Text = text(c, tab, name)
    return tab
end

-- A 12.0 list row (LFGWhoListButtonTemplate): its plate goes, selection and hover stay.
function P.listRow(c, parent)
    local row = CreateFrame("Button", nil, parent)
    row.Background = texture(c, row, "art", "common-button-list-large", "BACKGROUND", { atlas = true })
    row.Selected = texture(c, row, "keep", "common-button-list-large-selected", "BACKGROUND", { atlas = true })
    row.Name = text(c, row, "Anaxia")
    return row
end

-- A WowScrollBoxList with a ScrollTarget and an Update method Blizzard calls when the list is refilled.
function P.scrollBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.ScrollTarget = CreateFrame("Frame", nil, box)
    function box:Update() end
    parent.ScrollBox = box
    return box
end

-- DialogBorderTemplate and DialogHeaderTemplate on a frame (game menu, raid info, colour picker).
function P.dialog(c, name)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(250, 300)
    frame.Border = CreateFrame("Frame", nil, frame)
    for _, key in ipairs({ "TopLeftCorner", "TopEdge", "Center" }) do
        frame.Border[key] = texture(c, frame.Border, "art", "Dialog-" .. key, "BORDER")
    end
    frame.Border.Bg = texture(c, frame.Border, "art", "UI-DialogBox-Background", "BACKGROUND")
    frame.Header = CreateFrame("Frame", nil, frame)
    for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
        frame.Header[key] = texture(c, frame.Header, "art", "UI-Frame-DiamondMetal-Header-" .. key, "ARTWORK",
            { atlas = true })
    end
    frame.Header.Text = text(c, frame.Header, name)
    frame.Header.Text:SetPoint("CENTER", frame.Header, "CENTER", 0, 0)
    return frame
end

-- Comma list of the labels of art still visible ("" when all is held), for a readable failure.
function P.visibleArt(c, R, stop)
    local names = {}
    for _, t in ipairs(c.art) do
        if not R.invisible(t, stop) then names[#names + 1] = t._label end
    end
    return table.concat(names, ",")
end

-- Comma list of the labels of what must stay but is hidden.
function P.hiddenKeep(c, R, stop)
    local names = {}
    for _, t in ipairs(c.keep) do
        if R.invisible(t, stop) then names[#names + 1] = t._label or tostring(t._text) end
    end
    return table.concat(names, ",")
end

-- True when the button carries QuietUI's hover wash: an own HIGHLIGHT texture with a faint colour.
function P.hasHover(button)
    for _, region in ipairs(button._regions) do
        if region._layer == "HIGHLIGHT" and region._color and region._color[4] and region._color[4] < 0.2
            and region._shown ~= false then
            return true
        end
    end
    return false
end

return P
