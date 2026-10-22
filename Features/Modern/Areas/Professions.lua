local _, ns = ...

-- The Forever 12.0 professions window (ProfessionsFrame): the side tabs, the overview cards of the book page
-- (BookPage.ProfessionsContentFrame) and the frame art of the crafting page. Card art, ornate icon frames and
-- bar frames are held; cards and spell icons stand bare on the panel, bars get a borderless dark track.
-- Side tabs take the character window's slot-sized icon tabs; recipe categories become section strips.
-- The coloured bar fill, the rank text, the spell icons and the recipe details stay; unlearn is a bare cross.

local Modern = ns.Modern
local Professions = {}
Modern.Professions = Professions

local TABS = 7
local CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2",
    "SecondaryProfession3" }
local SPELL_BUTTONS = 4
local RANK_ART = { "BorderLeft", "BorderRight", "BorderMid" }
local GEAR_SLOTS = { "Prof0ToolSlot", "Prof0Gear0Slot", "Prof0Gear1Slot", "Prof1ToolSlot", "Prof1Gear0Slot",
    "Prof1Gear1Slot", "CookingToolSlot", "CookingGear0Slot", "FishingToolSlot" }

local styled = setmetatable({}, { __mode = "k" })  -- ProfessionsFrame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

local function FillOf(bar)
    if ns.Usable(bar.Fill) then return bar.Fill end
    if type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local ok, fill = pcall(bar.GetStatusBarTexture, bar)
    return ok and ns.Usable(fill) and fill or nil
end

-- How far right of the bar frame the fill starts; the fill is as wide as the frame, so it ends that far past it.
local function FillOffset(fill)
    if type(fill.GetPoint) ~= "function" then return 0 end
    local ok, _, _, _, x = pcall(fill.GetPoint, fill, 1)
    if ok and type(x) == "number" and not ns.IsSecret(x) then return x end
    return 0
end

-- A skill bar: its background and frame art go for a borderless dark track under the fill (the fill sits off the
-- frame, so a frame-sized box would cut it); the fill, its flare and the rank text stay.
local function Bar(skin, bar, art)
    if not ns.Usable(bar) then return end
    Hold(skin, bar.Background)
    Hold(skin, bar.Border)
    for _, key in ipairs(art or {}) do Hold(skin, bar[key]) end
    local fill = FillOf(bar)
    if not fill or type(bar.CreateTexture) ~= "function" then return end
    local track = skin:Own(bar, "track", function()
        return bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    end)
    track:ClearAllPoints()
    track:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    track:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
    track:SetPoint("RIGHT", bar, "RIGHT", FillOffset(fill), 0)
    track:SetColorTexture(unpack(Modern.Theme().track))
    track:Show()
end

-- Spell icons stand bare on the panel, square-cropped.
local function Spell(skin, button)
    if not ns.Usable(button) then return end
    Hold(skin, button.IconTextureOverlay)
    local icon = button.IconTexture
    if ns.Usable(icon) then
        skin:Icon(icon)
        Modern.NoMask(skin, icon)
    end
end

-- A card loses its art and stands on the panel; a primary card ends in a quiet rule that parts it from the next.
local function Card(skin, card, primary)
    if not ns.Usable(card) then return end
    Hold(skin, card.Background)
    if primary then Modern.Character.Rule(skin, card) end
    for index = 1, SPELL_BUTTONS do Spell(skin, card["SpellButton" .. index]) end
    Bar(skin, card.StatusBar)
    -- The red unlearn square (Icon, pressed Overlay) becomes the close button's bare cross, red under the mouse.
    local unlearn = card.UnlearnButton
    if ns.Usable(unlearn) then
        Hold(skin, unlearn.Icon)
        Hold(skin, unlearn.Overlay)
        Modern.GlyphButton(skin, unlearn, "unlearn", Modern.CrossParts, "danger")
    end
end

local function Overview(skin, frame)
    local page = frame.BookPage
    local content = ns.Usable(page) and page.ProfessionsContentFrame
    if not ns.Usable(content) then return end
    for _, key in ipairs(CARDS) do Card(skin, content[key], key:find("Primary", 1, true) ~= nil) end
end

-- A pooled recipe list category: the common-button-list art goes for a section strip and an accent plus / minus;
-- the title keeps Blizzard's gold, white under the mouse; a category rank bar gets the skill bar's track.
local function Category(skin, row)
    local collapse = row.CollapseButton
    Modern.Character.HoldArt(skin, row)
    Modern.Strip(skin, row, Modern.Character.STRIP)
    if ns.Usable(collapse) and ns.Usable(collapse.Icon) then
        Modern.Character.HoldArt(skin, collapse, collapse.Icon)
        Modern.Expander(skin, collapse.Icon)
    end
    Bar(skin, row.RankBar, RANK_ART)
end

local function Recipes(skin, list)
    local box = list.ScrollBox
    if not ns.Usable(box) then return end
    for _, row in ipairs(Modern.Character.Children(box.ScrollTarget)) do
        if ns.Usable(row) and row.CollapseButton then Category(skin, row) end
    end
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
        Recipes(skin, list)
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

-- Cards fill in and pages appear when the window opens, recipe rows are pooled; they are skinned again then.
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
    local list = ns.Usable(frame.CraftingPage) and frame.CraftingPage.RecipeList
    local box = ns.Usable(list) and list.ScrollBox
    if ns.Usable(box) and type(box.Update) == "function" then pcall(hooksecurefunc, box, "Update", Again) end
end

function Professions.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern professions", function() styled[frame] = nil end)
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    Modern.Character.IconTab(skin, frame.ProfessionsOverviewTab)
    for index = 1, TABS do Modern.Character.IconTab(skin, frame["Professions" .. index .. "Tab"]) end
    Refresh(skin, frame)
    Watch(frame)
end
