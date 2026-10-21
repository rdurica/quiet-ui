local _, ns = ...

-- The spellbook page of the Forever 12.0 PlayerSpellsFrame (the talents page is Talents). The book pages, category
-- banners and the ornate spell icon frames are held; spells get the square slot of the bags (dark fill, thin
-- border, square icon), category titles a thin rule, search boxes and panel buttons a flat field. The dark ink
-- of names and titles, made for the parchment page, becomes light text of the same hue. Spell icons,
-- names and the paging arrows stay. Spell items are pooled per page, so they are
-- skinned again when the book shows or turns a page.

local Modern = ns.Modern
local Spellbook = {}
Modern.Spellbook = Spellbook

local PAGES = { "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook" }
local ICON_ART = { "Border", "BorderSheen", "BorderShadow", "TrainableShadow", "TrainableBackplate" }
local PAGE_METHODS = { "DisplayViewsForCurrentPage", "SetCurrentPage", "UpdatePages" }

local TEXT_KEYS = { "Name", "SubName", "RequiredLevel" }

local styled = setmetatable({}, { __mode = "k" })  -- PlayerSpellsFrame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function HoldKeys(skin, owner, keys)
    for _, key in ipairs(keys) do
        if ns.Usable(owner[key]) then skin:Hold(owner[key]) end
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
        for _, key in ipairs(TEXT_KEYS) do Modern.Ink(skin, texts[key]) end
    end
end

-- A category header: the banner and the ornate divider go, a thin rule stays under the title.
local function Header(skin, header)
    if ns.Usable(header.Backplate) then skin:Hold(header.Backplate) end
    if ns.Usable(header.Border) then skin:Hold(header.Border) end
    Modern.Character.Rule(skin, header)
    Modern.Ink(skin, header.Text)
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
    if ns.Usable(paging) then Modern.Ink(skin, paging.PageText) end
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
    Refresh(skin, frame)
    Watch(frame)
end
