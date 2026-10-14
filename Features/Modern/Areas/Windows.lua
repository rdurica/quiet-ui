local _, ns = ...

-- Named runtime lookups support both Forever's classic and newer window variants.
local Modern = ns.Modern

local function Usable(frame)
    return ns.Usable(frame)
end

function Modern.WindowChrome(skin, frame)
    if not Usable(frame) then return end
    for _, key in ipairs({ "chrome", "Bg", "Background", "Border", "BorderFrame", "Portrait", "TitleBg", "Inset",
        "TopTileStreaks", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder" }) do
        local texture = frame[key]
        if Usable(texture) and type(texture.GetObjectType) == "function" and texture:GetObjectType() == "Texture" then
            skin:Hold(texture)
        end
    end
    local slice = frame.NineSlice
    if Usable(slice) then
        for _, key in ipairs({ "art", "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner",
            "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }) do
            local texture = slice[key]
            if Usable(texture) and type(texture.GetObjectType) == "function" and texture:GetObjectType() == "Texture" then
                skin:Hold(texture)
            end
        end
    end
end

local function Window(skin, frame, movable)
    if not Usable(frame) then return end
    skin:Panel(frame)
    skin:Border(frame)
    Modern.WindowChrome(skin, frame)
    if movable then
        skin:Remember(frame, "modern movable", function() Modern.ReleaseMovable(frame) end)
        Modern.MakeMovable(frame, frame:GetName())
    end
end

local function Named(first, second)
    return _G[first] or _G[second]
end

local function Character(skin)
    Window(skin, _G.CharacterFrame, true)
    for index = 1, 5 do Window(skin, _G["CharacterFrameTab" .. index]) end
    Window(skin, _G.CharacterFrameReputationFrame)
    Window(skin, _G.CharacterFrameCurrencyFrame)
end

local function Bags(skin)
    local function Items(bag)
        local list, seen = {}, {}
        local function Add(button)
            if Usable(button) and not seen[button] then seen[button] = true; list[#list + 1] = button end
        end
        for _, group in ipairs({ bag.items, bag.itemSlots }) do
            if type(group) == "table" then for _, button in pairs(group) do Add(button) end end
        end
        if type(bag.GetChildren) == "function" then for _, button in ipairs({ bag:GetChildren() }) do Add(button) end end
        return list
    end
    local function Item(button)
        if Usable(button.Icon) then skin:Icon(button.Icon) end
        local quality = button.Quality
        if Usable(quality) then
            local r, g, b, a = quality:GetVertexColor()
            if type(r) == "number" then skin:Border(button, { r, g, b, a or 1 }) end
            skin:Hold(quality)
        end
    end
    for index = 1, 20 do
        local bag = _G["ContainerFrame" .. index]
        if Usable(bag) then
            Window(skin, bag)
            for _, button in ipairs(Items(bag)) do Item(button) end
        end
    end
    local combined = _G.ContainerFrameCombinedBags
    if Usable(combined) then
        Window(skin, combined)
        for _, button in ipairs(Items(combined)) do Item(button) end
    end
end

local function Apply(skin)
    Character(skin)
    Window(skin, Named("SpellBookFrame", "PlayerSpellsFrame"), true)
    Window(skin, Named("PlayerTalentFrame", "ClassTalentFrame"), true)
    Window(skin, Named("QuestLogFrame", "QuestMapFrame"), true)
    Bags(skin)
    -- Parchment owns the replacement layer and button band; the common journal holds
    -- the Blizzard chrome as well so it remains hidden when the client repaints it.
    for _, name in ipairs({ "QuestFrame", "GossipFrame", "ItemTextFrame" }) do
        local frame = _G[name]
        if Usable(frame) then Modern.WindowChrome(skin, frame) end
    end
    if Modern.Parchment then Modern.Parchment.Apply(skin) end
end

Modern.Register{
    key = "windows",
    label = "Windows",
    apply = Apply,
    restore = function()
        if Modern.Parchment then Modern.Parchment.Restore() end
    end,
    addons = { "Blizzard_TalentUI", "Blizzard_PlayerSpells", "Blizzard_SpellBookUI", "Blizzard_QuestUI" },
    events = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW", "ITEM_TEXT_READY" },
    onEvent = function(_, event)
        if Modern.Parchment then Modern.Parchment.Event(event) end
    end,
}
