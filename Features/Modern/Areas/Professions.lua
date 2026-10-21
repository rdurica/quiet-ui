local _, ns = ...

-- The Forever 12.0 professions window (ProfessionsFrame): the side tabs, the overview cards of the book page
-- (BookPage.ProfessionsContentFrame) and the frame art of the crafting page. Card art, ornate icon frames and
-- bar frames are held; cards become dark panels, spells square slots, bars a dark field with a thin border.
-- The coloured bar fill, the rank text, the spell icons, the unlearn cross and the recipe details stay.

local Modern = ns.Modern
local Professions = {}
Modern.Professions = Professions

local TABS = 7
local CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2",
    "SecondaryProfession3" }
local SPELL_BUTTONS = 4
local GEAR_SLOTS = { "Prof0ToolSlot", "Prof0Gear0Slot", "Prof0Gear1Slot", "Prof1ToolSlot", "Prof1Gear0Slot",
    "Prof1Gear1Slot", "CookingToolSlot", "CookingGear0Slot", "FishingToolSlot" }

local styled = setmetatable({}, { __mode = "k" })  -- ProfessionsFrame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

-- A skill bar: background and frame art go, the fill, its flare and the rank text stay.
local function Bar(skin, bar)
    if not ns.Usable(bar) then return end
    Hold(skin, bar.Background)
    Hold(skin, bar.Border)
    skin:Panel(bar)
    skin:Border(bar)
end

local function Spell(skin, button)
    if not ns.Usable(button) then return end
    Hold(skin, button.IconTextureOverlay)
    local icon = button.IconTexture
    if ns.Usable(icon) then
        skin:Icon(icon)
        Modern.NoMask(skin, icon)
    end
    skin:Panel(button)
    skin:Border(button)
end

local function Card(skin, card)
    if not ns.Usable(card) then return end
    Hold(skin, card.Background)
    skin:Panel(card)
    skin:Border(card)
    for index = 1, SPELL_BUTTONS do Spell(skin, card["SpellButton" .. index]) end
    Bar(skin, card.StatusBar)
end

local function Overview(skin, frame)
    local page = frame.BookPage
    local content = ns.Usable(page) and page.ProfessionsContentFrame
    if not ns.Usable(content) then return end
    for _, key in ipairs(CARDS) do Card(skin, content[key]) end
end

-- The crafting page: its background, the recipe list and schematic frames, search, scroll bar, rank bar,
-- the red create buttons and the profession gear slots.
local function Crafting(skin, page)
    Modern.Character.HoldArt(skin, page)
    local list = page.RecipeList
    if ns.Usable(list) then
        Hold(skin, list.Background)
        Modern.Character.HoldArt(skin, list.BackgroundNineSlice)
        Modern.Shapes.Field(skin, list.SearchBox)
        Modern.Character.ScrollBar(skin, list.ScrollBar)
    end
    local form = page.SchematicForm
    if ns.Usable(form) then
        Modern.Character.HoldArt(skin, form)
        Modern.Character.HoldArt(skin, form.NineSlice)
    end
    Modern.Shapes.Field(skin, page.MinimizedSearchBox)
    Bar(skin, page.RankBar)
    Modern.Shapes.Field(skin, page.CreateButton)
    Modern.Shapes.Field(skin, page.CreateAllButton)
    for _, key in ipairs(GEAR_SLOTS) do
        if ns.Usable(page[key]) then Modern.Bags.Item(skin, page[key]) end
    end
    local divider = page.GearSlotDivider
    if ns.Usable(divider) then Modern.Character.HoldArt(skin, divider) end
end

local function Refresh(skin, frame)
    Overview(skin, frame)
    if ns.Usable(frame.CraftingPage) then Crafting(skin, frame.CraftingPage) end
end

-- Cards fill in and pages appear when the window opens; they are skinned again then.
local function Watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    local function Again()
        local skin = styled[frame]
        if skin then ns.Profiler.Run("modern professions", Refresh, skin, frame) end
    end
    for _, target in ipairs({ frame, frame.BookPage, frame.CraftingPage }) do
        if ns.Usable(target) and type(target.HookScript) == "function" then
            pcall(target.HookScript, target, "OnShow", Again)
        end
    end
end

function Professions.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern professions", function() styled[frame] = nil end)
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    Modern.TabChrome(skin, frame.ProfessionsOverviewTab)
    for index = 1, TABS do Modern.TabChrome(skin, frame["Professions" .. index .. "Tab"]) end
    Refresh(skin, frame)
    Watch(frame)
end
