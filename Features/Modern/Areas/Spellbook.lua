local _, ns = ...

-- The spellbook page of the Forever 12.0 PlayerSpellsFrame and the talents footer. The book pages, category
-- banners and the ornate spell icon frames are held; spells get the square slot of the bags (dark fill, thin
-- border, square icon), category titles a thin rule, search boxes and panel buttons a flat field. The dark ink
-- of names and titles, made for the parchment page, becomes light text of the same hue. Spell icons,
-- names, the paging arrows and the talent tree itself stay. Spell items are pooled per page, so they are
-- skinned again when the book shows or turns a page.

local Modern = ns.Modern
local Spellbook = {}
Modern.Spellbook = Spellbook

local PAGES = { "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook" }
local ICON_ART = { "Border", "BorderSheen", "BorderShadow", "TrainableShadow", "TrainableBackplate" }
local PAGE_METHODS = { "DisplayViewsForCurrentPage", "SetCurrentPage", "UpdatePages" }
local TALENT_BUTTONS = { "ApplyButton", "InspectCopyButton" }

-- Below this luminance a text colour is ink for the parchment page; grey state colours stay.
local INK = 0.35
local TEXT_KEYS = { "Name", "SubName", "RequiredLevel" }

local styled = setmetatable({}, { __mode = "k" })  -- PlayerSpellsFrame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })
local inked = setmetatable({}, { __mode = "k" })   -- font string -> Blizzard's last ink, or false, while applied
local busy = false

local function HoldKeys(skin, owner, keys)
    for _, key in ipairs(keys) do
        if ns.Usable(owner[key]) then skin:Hold(owner[key]) end
    end
end

local function Luminance(r, g, b)
    return 0.3 * r + 0.59 * g + 0.11 * b
end

-- Dark ink becomes the same hue at the mirrored luminance (brown turns gold), capped at full channel.
local function Lighten(font)
    if busy or inked[font] == nil then return end
    local r, g, b, a = font:GetTextColor()
    if type(r) ~= "number" or ns.IsSecret(r) then return end
    local l = Luminance(r, g, b)
    if l >= INK then return end
    local f = l > 0 and (1 - l) / l or 1
    inked[font] = { r, g, b, a }
    busy = true
    pcall(font.SetTextColor, font, math.min(1, l > 0 and r * f or 1), math.min(1, l > 0 and g * f or 1),
        math.min(1, l > 0 and b * f or 1), a)
    busy = false
end

local function Ink(skin, font)
    if not ns.Usable(font) or type(font.GetTextColor) ~= "function" or type(font.SetTextColor) ~= "function" then
        return
    end
    if inked[font] == nil then
        inked[font] = false
        -- Undo puts back the ink Blizzard set last; a colour that was never ink is left alone.
        skin:Remember(font, "modern ink", function()
            local ink = inked[font]
            inked[font] = nil
            if ink then pcall(font.SetTextColor, font, unpack(ink, 1, 4)) end
        end)
    end
    Lighten(font)
    if hooked[font] then return end
    hooked[font] = true
    for _, method in ipairs({ "SetTextColor", "SetFontObject" }) do
        if type(font[method]) == "function" then
            pcall(hooksecurefunc, font, method, function() ns.Run("modern spellbook", Lighten, font) end)
        end
    end
end

-- A spell: the backplate and the round frame art go, the icon becomes a square slot.
local function Item(skin, item)
    if ns.Usable(item.Backplate) then skin:Hold(item.Backplate) end
    local button = item.Button
    HoldKeys(skin, button, ICON_ART)
    local icon = button.Icon
    if ns.Usable(icon) then
        skin:Icon(icon)
        Modern.NoMask(skin, icon)
    end
    skin:Panel(button)
    skin:Border(button)
    local texts = item.TextContainer
    if ns.Usable(texts) then
        for _, key in ipairs(TEXT_KEYS) do Ink(skin, texts[key]) end
    end
end

-- A category header: the banner and the ornate divider go, a thin rule stays under the title.
local function Header(skin, header)
    if ns.Usable(header.Backplate) then skin:Hold(header.Backplate) end
    if ns.Usable(header.Border) then skin:Hold(header.Border) end
    Modern.Character.Rule(skin, header)
    Ink(skin, header.Text)
end

local function View(skin, view)
    for _, child in ipairs(Modern.Character.Children(view)) do
        if ns.Usable(child) then
            if ns.Usable(child.Button) and child.Button.Icon then
                Item(skin, child)
            elseif child.Text and child.Border then
                Header(skin, child)
            end
        end
    end
end

local function Pages(skin, book)
    local paged = book.PagedSpellsFrame
    if not ns.Usable(paged) then return end
    local paging = paged.PagingControls
    if ns.Usable(paging) then Ink(skin, paging.PageText) end
    for _, key in ipairs({ "View1", "View2" }) do
        if ns.Usable(paged[key]) then View(skin, paged[key]) end
    end
end

local function Refresh(skin, frame)
    local book = frame.SpellBookFrame
    if ns.Usable(book) then Pages(skin, book) end
end

local function Book(skin, book)
    HoldKeys(skin, book, PAGES)
    Modern.TabSystemChrome(skin, book)
    Modern.Field(skin, book.SearchBox)
end

-- The talents footer: search box and the red panel buttons become flat fields; the tree is content.
local function Talents(skin, talents)
    Modern.Field(skin, talents.SearchBox)
    for _, key in ipairs(TALENT_BUTTONS) do Modern.Field(skin, talents[key]) end
    local spec = talents.ActiveSpec
    if ns.Usable(spec) then Modern.Field(skin, spec.ActivateButton) end
    Modern.TabSystemChrome(skin, talents)
end

local function Watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    local function Again()
        local skin = styled[frame]
        if skin then ns.Run("modern spellbook", Refresh, skin, frame) end
    end
    local book = frame.SpellBookFrame
    if ns.Usable(book) and type(book.HookScript) == "function" then pcall(book.HookScript, book, "OnShow", Again) end
    local paged = ns.Usable(book) and book.PagedSpellsFrame
    if not ns.Usable(paged) then return end
    for _, method in ipairs(PAGE_METHODS) do
        if type(paged[method]) == "function" then pcall(hooksecurefunc, paged, method, Again) end
    end
end

function Spellbook.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern spellbook", function() styled[frame] = nil end)
    if ns.Usable(frame.SpellBookFrame) then Book(skin, frame.SpellBookFrame) end
    if ns.Usable(frame.TalentsFrame) then Talents(skin, frame.TalentsFrame) end
    Refresh(skin, frame)
    Watch(frame)
end
