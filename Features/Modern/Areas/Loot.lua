local _, ns = ...

-- The Forever 12.0 loot window (LootFrame, ScrollingFlatPanelTemplate), shaped after a frame dump of the client:
-- metal NineSlice, a flat Bg frame, ClosePanelButton, and pooled item cards in ScrollBox.ScrollTarget (NameFrame,
-- BorderFrame and the gold click strokes, an Item button). The window takes the dark template with a header band;
-- card art is held, so the cards stand bare on the panel like the merchant's, and the item button is a bag slot.
-- The quest border, item names, coins and the scroll bar stay Blizzard's. Cards are pooled, so they are skinned
-- again when the window shows, on LOOT_OPENED and when the scroll box updates.

local Modern = ns.Modern
local Loot = {}
Modern.Loot = Loot

local CARD_ART = { "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame" }
-- MasterLooterFrame's item row (a three-piece name plate and an icon ring).
local MASTER_ART = { "NameBorderLeft", "NameBorderRight", "NameBorderMid", "IconBorder" }

local styled = setmetatable({}, { __mode = "k" })  -- window -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

local function Card(skin, card)
    if not ns.Usable(card) then return end
    for _, key in ipairs(CARD_ART) do Hold(skin, card[key]) end
    if ns.Usable(card.Item) then Modern.Bags.Item(skin, card.Item) end
end

local function Cards(skin, frame)
    local target = ns.Usable(frame.ScrollBox) and frame.ScrollBox.ScrollTarget
    if not ns.Usable(target) or type(target.GetChildren) ~= "function" then return end
    for _, card in ipairs({ target:GetChildren() }) do Card(skin, card) end
end

local function Master(skin, master)
    if not ns.Usable(master) then return end
    Modern.Window(skin, master)
    Modern.Header(skin, master)
    if ns.Usable(master.Item) then
        for _, key in ipairs(MASTER_ART) do Hold(skin, master.Item[key]) end
    end
end

local function Skin(skin, frame)
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    Cards(skin, frame)
    Master(skin, _G.MasterLooterFrame)
end

-- Hooks are set once per session and do nothing while the window is not styled.
local function Watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    local function Again()
        local skin = styled[frame]
        if skin then ns.Profiler.Run("modern loot", Cards, skin, frame) end
    end
    if type(frame.HookScript) == "function" then pcall(frame.HookScript, frame, "OnShow", Again) end
    local box = frame.ScrollBox
    if ns.Usable(box) and type(box.Update) == "function" then pcall(hooksecurefunc, box, "Update", Again) end
end

function Loot.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern loot", function() styled[frame] = nil end)
    Skin(skin, frame)
    Watch(frame)
end
