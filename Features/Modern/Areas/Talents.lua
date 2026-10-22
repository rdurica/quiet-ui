local _, ns = ...

-- The talents page of the Forever 12.0 PlayerSpellsFrame: three classic trees on one page. The ornate backdrop, the
-- inner frame, the gilded dividers, the spec rings and the count boxes are held, so the window panel shows round the
-- tree art, which is content and stays inside a thin quiet edge. Each tree title gets a thin rule, the trees quiet
-- lines between them. Spec and talent icons are cropped square; a talent's state border becomes a thin border in the
-- colour of its state. The spec tabs stand without a border. Talent buttons are pooled, so new ones are skinned when the page shows or loads a tree.

local Modern = ns.Modern
local Talents = {}
Modern.Talents = Talents

local ART = { "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight" }
local DIVIDERS = { "DividerVerticalLeft", "DividerVerticalRight" }
local BUTTONS = { "ApplyButton", "InspectCopyButton" }
local SPEC_ART = { "MainRing", "TextBackground" }
local NODE_ART = { "Shadow", "BorderSheen", "StateBorder", "StateBorderHover" }
local LOAD_METHODS = { "LoadTalentTreeInternal", "LoadTalentTree" }
-- Partly spent: the green of Blizzard's state art, toned to the palette.
local GREEN = { 0.3, 0.75, 0.35, 1 }
-- State by the name of Blizzard's state border atlas, first match wins; anything else is an open talent.
local STATES = { { "yellow", "accent" }, { "green", GREEN }, { "red", "danger" }, { "locked", "wellEdge" } }
-- Talents-small-divider draws its line along the bottom of its art; the rule is shorter than the faded ends.
local RULE_INSET, RULE_Y = 20, 2
local STROKE = 6
-- Blizzard's search box spans most of the space beside the tabs.
local SEARCH_WIDTH = 140

local styled = setmetatable({}, { __mode = "k" })  -- TalentsFrame -> journal while applied
local nodes = setmetatable({}, { __mode = "k" })   -- talent button -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function HoldKeys(skin, owner, keys)
    for _, key in ipairs(keys) do
        if ns.Usable(owner[key]) then skin:Hold(owner[key]) end
    end
end

local function SquareIcon(skin, icon)
    if not ns.Usable(icon) then return false end
    skin:Icon(icon)
    Modern.NoMask(skin, icon)
    return true
end

local function StateColor(border)
    local theme = Modern.Theme()
    if not ns.Usable(border) or type(border.GetAtlas) ~= "function" then return theme.border end
    local ok, atlas = pcall(border.GetAtlas, border)
    if not ok or type(atlas) ~= "string" then return theme.border end
    atlas = atlas:lower()
    for _, state in ipairs(STATES) do
        if atlas:find(state[1], 1, true) then
            return type(state[2]) == "string" and theme[state[2]] or state[2]
        end
    end
    return theme.border
end

local function Paint(button)
    local skin = nodes[button]
    if skin then skin:Border(button, StateColor(button.StateBorder), button.Icon) end
end

local function IsNode(button)
    return ns.Usable(button) and ns.Usable(button.Icon) and ns.Usable(button.StateBorder)
end

-- One talent: shadow, sheen and state art go, the icon is cropped and framed in its state colour.
local function Node(skin, button)
    if nodes[button] then
        Paint(button)
        return
    end
    nodes[button] = skin
    skin:Remember(button, "modern talent", function() nodes[button] = nil end)
    HoldKeys(skin, button, NODE_ART)
    SquareIcon(skin, button.Icon)
    Paint(button)
    local border = button.StateBorder
    if hooked[border] then return end
    hooked[border] = true
    for _, method in ipairs({ "SetAtlas", "SetTexture" }) do
        if type(border[method]) == "function" then
            pcall(hooksecurefunc, border, method, function() ns.Profiler.Run("modern talents", Paint, button) end)
        end
    end
end

-- A tree title: ring and count box go, the icon gets a thin border, the count stands outlined on its corner and
-- the ornate divider becomes a thin rule.
local function Spec(skin, spec)
    local theme = Modern.Theme()
    HoldKeys(skin, spec, SPEC_ART)
    if SquareIcon(skin, spec.Icon) then skin:Border(spec, theme.border, spec.Icon) end
    if ns.Usable(spec.Text) then skin:Outline(spec.Text) end
    local divider = spec.Divider
    if not ns.Usable(divider) then return end
    skin:Hold(divider)
    local rule = skin:Own(spec, "rule", function()
        local texture = spec:CreateTexture(nil, "ARTWORK")
        texture:SetHeight(1)
        texture:SetPoint("BOTTOMLEFT", divider, "BOTTOMLEFT", RULE_INSET, RULE_Y)
        texture:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT", -RULE_INSET, RULE_Y)
        return texture
    end)
    if rule then
        rule:SetColorTexture(unpack(theme.border))
        rule:Show()
    end
end

local function IsSpec(frame)
    return ns.Usable(frame) and ns.Usable(frame.MainRing) and ns.Usable(frame.Icon) and frame.Name ~= nil
end

-- The gilded line between two trees becomes a quiet 1 px line over the same span.
local function Divider(skin, talents, key)
    local divider = talents[key]
    if not ns.Usable(divider) then return end
    skin:Hold(divider)
    local line = skin:Own(talents, "divider:" .. key, function()
        local texture = talents:CreateTexture(nil, "OVERLAY")
        texture:SetWidth(1)
        texture:SetPoint("TOP", divider, "TOP", 0, 0)
        texture:SetPoint("BOTTOM", divider, "BOTTOM", 0, 0)
        return texture
    end)
    if line then
        line:SetColorTexture(unpack(Modern.Theme().wellEdge))
        line:Show()
    end
end

local function ChevronParts(button)
    return { Modern.GlyphLine(button, STROKE, 2, -2, 0, -45), Modern.GlyphLine(button, STROKE, 2, 2, 0, 45) }
end

-- The search options button: Blizzard's gold box goes, a bare chevron stays.
local function Options(skin, button)
    if not ns.Usable(button) then return end
    if ns.Usable(button.Arrow) then skin:Hold(button.Arrow) end
    Modern.GlyphButton(skin, button, "options chevron", ChevronParts, "text")
end

local function Refresh(skin, talents)
    local parent = talents.ButtonsParent
    if ns.Usable(parent) and type(parent.GetChildren) == "function" then
        for _, button in ipairs({ parent:GetChildren() }) do
            if IsNode(button) then Node(skin, button) end
        end
    end
    for _, child in ipairs({ talents:GetChildren() }) do
        if IsSpec(child) then Spec(skin, child) end
    end
end

local function Watch(talents)
    if hooked[talents] then return end
    hooked[talents] = true
    local function Again()
        local skin = styled[talents]
        if skin then ns.Profiler.Run("modern talents", Refresh, skin, talents) end
    end
    if type(talents.HookScript) == "function" then pcall(talents.HookScript, talents, "OnShow", Again) end
    for _, method in ipairs(LOAD_METHODS) do
        if type(talents[method]) == "function" then pcall(hooksecurefunc, talents, method, Again) end
    end
end

function Talents.Apply(skin, frame)
    local talents = ns.Usable(frame) and frame.TalentsFrame
    if not ns.Usable(talents) then return end
    styled[talents] = skin
    skin:Remember(talents, "modern talents", function() styled[talents] = nil end)
    HoldKeys(skin, talents, ART)
    if ns.Usable(talents.ClassBackground) then skin:Border(talents, Modern.Theme().wellEdge, talents.ClassBackground) end
    for _, key in ipairs(DIVIDERS) do Divider(skin, talents, key) end
    local currency = talents.ClassCurrencyDisplay
    if ns.Usable(currency) and ns.Usable(currency.Border) then skin:Hold(currency.Border) end
    local search = talents.SearchBox
    Modern.Shapes.Field(skin, search)
    if ns.Usable(search) and type(search.SetWidth) == "function" then skin:Set(search, "SetWidth", SEARCH_WIDTH) end
    Options(skin, talents.SearchOptionsDropdown)
    for _, key in ipairs(BUTTONS) do Modern.Shapes.Field(skin, talents[key]) end
    local spec = talents.ActiveSpec
    if ns.Usable(spec) then Modern.Shapes.Field(skin, spec.ActivateButton) end
    Modern.TabSystemChrome(skin, talents, true)
    Refresh(skin, talents)
    Watch(talents)
end
