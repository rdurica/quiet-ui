local _, ns = ...

-- Window chrome shared by the Windows and Map areas: holds the art that Blizzard's
-- PortraitFrameTemplate / ButtonFrameTemplate, NineSlicePanelTemplate, InsetFrameTemplate and
-- PanelTabButtonTemplate put on a frame. Everything is held through the area journal (alpha),
-- never hidden, so titles and window content stay. The close button keeps its place and click area; only its art
-- becomes a bare thin cross.

local Modern = ns.Modern

local TEXTURE_KEYS = { "chrome", "Bg", "Background", "Border", "Portrait", "portrait", "PortraitFrame", "TitleBg",
    "TopTileStreaks", "InsetBorderTop", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder" }
local NINE_KEYS = { "art", "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner",
    "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
-- Panel tabs (PanelTabButtonTemplate), the character window's side tabs (common-sidetab art) and the
-- spellbook's icon tabs (spellbook-Tab-Frame art).
local TAB_KEYS = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftDisabled",
    "MiddleDisabled", "RightDisabled", "Background", "SelectedTexture", "TabGlow", "HighlightTexture",
    "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow" }
-- The art Blizzard shows on the selected tab, first match wins.
local SELECTED_KEYS = { "SquareBackgroundActive", "LeftActive", "SelectedTexture" }

local CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local CROSS_LENGTH = 12

local tabs = setmetatable({}, { __mode = "k" })    -- tab -> true while its area is applied
local closes = setmetatable({}, { __mode = "k" })  -- close button -> its skin while the area is applied
local hovered = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function HoldKeys(skin, owner, keys)
    if not ns.Usable(owner) then return end
    for _, key in ipairs(keys) do
        local texture = owner[key]
        if IsTexture(texture) then skin:Hold(texture) end
    end
end

-- A frame of nine pieces (or the old single `art`) is chrome only.
local function Slice(skin, slice)
    if IsTexture(slice) then skin:Hold(slice) else HoldKeys(skin, slice, NINE_KEYS) end
end

-- InsetFrameTemplate: a frame with its own Bg and NineSlice. An old single texture is held as is.
local function Inset(skin, inset)
    if IsTexture(inset) then
        skin:Hold(inset)
    elseif ns.Usable(inset) then
        HoldKeys(skin, inset, { "Bg" })
        Slice(skin, inset.NineSlice)
    end
end

function Modern.WindowChrome(skin, frame)
    if not ns.Usable(frame) then return end
    HoldKeys(skin, frame, TEXTURE_KEYS)
    Slice(skin, frame.NineSlice)
    Inset(skin, frame.Inset)
    Inset(skin, frame.InsetRight)    -- the character window's stats pane
    local container = frame.PortraitContainer
    if ns.Usable(container) then HoldKeys(skin, container, { "portrait", "Portrait" }) end
end

-- The accent border marks the selected tab: Blizzard shows the Active (side tab: Selected) art for it.
local function Selected(tab)
    for _, key in ipairs(SELECTED_KEYS) do
        local active = tab[key]
        if ns.Usable(active) and type(active.IsShown) == "function" then return active:IsShown() and true or false end
    end
    return false
end

local function TabBorder(skin, tab)
    local theme = Modern.Theme()
    skin:Border(tab, Selected(tab) and theme.accent or theme.border)
end

function Modern.TabChrome(skin, tab)
    if not ns.Usable(tab) then return end
    HoldKeys(skin, tab, TAB_KEYS)
    skin:Panel(tab)
    TabBorder(skin, tab)
    tabs[tab] = skin
    skin:Remember(tab, "modern tab", function() tabs[tab] = nil end)
    if hooked[tab] then return end
    hooked[tab] = true
    for _, key in ipairs({ "SquareBackgroundActive", "LeftActive", "Left", "SelectedTexture" }) do
        local piece = tab[key]
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            if ns.Usable(piece) and type(piece[method]) == "function" then
                pcall(hooksecurefunc, piece, method, function()
                    local owner = tabs[tab]
                    if owner then ns.Run("modern tab", TabBorder, owner, tab) end
                end)
            end
        end
    end
end

-- Tab buttons of the 12.0 TabSystem (spellbook / talents window) are children of TabSystem
-- (PlayerSpellsFrame and its spellbook name it tabSystem).
function Modern.TabSystemChrome(skin, frame)
    local system = ns.Usable(frame) and (frame.TabSystem or frame.tabSystem)
    if not ns.Usable(system) or type(system.GetChildren) ~= "function" then return end
    for _, tab in ipairs({ system:GetChildren() }) do
        if ns.Usable(tab) and (tab.Left or tab.LeftActive) then Modern.TabChrome(skin, tab) end
    end
end

local function CloseParts(button)
    local parts = {}
    for _, angle in ipairs({ 45, -45 }) do
        local line = button:CreateTexture(nil, "OVERLAY")
        line:SetSize(CROSS_LENGTH, 2)
        line:SetPoint("CENTER", button, "CENTER", 0, 0)
        if type(line.SetRotation) == "function" then pcall(line.SetRotation, line, math.rad(angle)) end
        parts[#parts + 1] = line
    end
    return parts
end

local function Parts(skin, button)
    return skin:Own(button, "close", function() return CloseParts(button) end)
end

local function PaintClose(skin, button)
    local theme = Modern.Theme()
    local parts = Parts(skin, button)
    local color = hovered[button] and theme.danger or theme.glyph
    for _, line in ipairs(parts) do line:SetColorTexture(unpack(color)) end
end

-- PortraitFrameTemplate / ButtonFrameTemplate name it CloseButton; the world map keeps it on BorderFrame.
local function FindClose(frame)
    local name = type(frame.GetName) == "function" and frame:GetName()
    for _, close in ipairs({ frame.CloseButton, ns.Usable(frame.BorderFrame) and frame.BorderFrame.CloseButton,
        type(name) == "string" and _G[name .. "CloseButton"] }) do
        if ns.Usable(close) and type(close.CreateTexture) == "function" then return close end
    end
end

function Modern.CloseButton(skin, frame)
    local button = ns.Usable(frame) and FindClose(frame)
    if not button then return end
    for _, getter in ipairs(CLOSE_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and IsTexture(texture) then skin:Hold(texture) end
        end
    end
    for _, part in ipairs(Parts(skin, button)) do part:Show() end
    closes[button] = skin
    skin:Remember(button, "modern close", function()
        closes[button] = nil
        hovered[button] = nil
    end)
    PaintClose(skin, button)
    if hooked[button] or type(button.HookScript) ~= "function" then return end
    hooked[button] = true
    for script, on in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function()
            local owner = closes[button]
            if not owner then return end
            hovered[button] = on
            ns.Run("modern close", PaintClose, owner, button)
        end)
    end
end

-- Three-piece art (Left, Middle or Center, Right) of a search box, a money bar or a panel button is held. The
-- field becomes a dark fill with a thin border; a bare one keeps only its content.
function Modern.Field(skin, frame, bare)
    if not ns.Usable(frame) then return end
    for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
        if ns.Usable(frame[key]) then skin:Hold(frame[key]) end
    end
    if bare then return end
    skin:Panel(frame)
    skin:Border(frame)
end

-- A window: dark fill and border, Blizzard chrome held, optionally a title drag handle (above `over`).
function Modern.Window(skin, frame, key, over)
    if not ns.Usable(frame) then return end
    skin:Panel(frame)
    skin:Border(frame)
    Modern.WindowChrome(skin, frame)
    Modern.TabSystemChrome(skin, frame)
    Modern.CloseButton(skin, frame)
    if key then
        skin:Remember(frame, "modern movable", function() Modern.ReleaseMovable(frame) end)
        Modern.MakeMovable(frame, key, over)
    end
end
