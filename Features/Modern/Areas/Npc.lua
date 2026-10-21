local _, ns = ...

-- NPC quest, gossip and item text windows take the dark window template: chrome, parchment backgrounds and
-- panel materials are held, action buttons become flat fields, and the dark ink of their text becomes light:
-- neutral body text, gold headings and greetings, in the standard UI face with a shadow.
-- Text, rewards, gossip options and scripts stay Blizzard's. Gossip options and quest rewards are pooled, so the
-- ink is scanned again when a window shows, on its events and when its content is rebuilt.

local Modern = ns.Modern
local Npc = {}
Modern.Npc = Npc

-- Loose named chrome (`<window><suffix>`) that the common keys miss on the classic variants.
local SUFFIXES = { "Bg", "Portrait", "TitleBg", "TopTileStreaks", "BtnCornerLeft", "BtnCornerRight",
    "ButtonBottomBorder" }
local PANEL_KEYS = { "Bg", "SealMaterialBG", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft",
    "MaterialBotRight" }
local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
-- Headings and greetings keep the gold ink: named quest headers, and the keyed greeting or header of a frame.
local HEADING_NAMES = { QuestInfoTitleHeader = true, QuestInfoDescriptionHeader = true,
    QuestInfoObjectivesHeader = true, QuestProgressTitleText = true, QuestInfoRewardsFrameHeader = true,
    GreetingText = true, CurrentQuestsText = true, AvailableQuestsText = true, GossipGreetingText = true }
local HEADING_KEYS = { "GreetingText", "Header", "TitleHeader" }

local function GossipPanel(win)
    return ns.Usable(win.GreetingPanel) and win.GreetingPanel or nil
end

local WINDOWS = {
    QuestFrame = {
        panels = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel",
            "QuestFrameGreetingPanel" },
        buttons = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
            "QuestFrameGoodbyeButton", "QuestFrameCompleteQuestButton", "QuestFrameCancelButton",
            "QuestFrameGreetingGoodbyeButton" },
    },
    GossipFrame = {
        panels = {},
        buttons = { function(win)
            local panel = GossipPanel(win)
            return panel and panel.GoodbyeButton or _G.GossipFrameGreetingGoodbyeButton
        end },
    },
    ItemTextFrame = {
        panels = {},
        art = { "ItemTextMaterialTopLeft", "ItemTextMaterialTopRight", "ItemTextMaterialBotLeft",
            "ItemTextMaterialBotRight" },
        buttons = { "ItemTextPrevPageButton", "ItemTextNextPageButton" },
    },
}
local ORDER = { "QuestFrame", "GossipFrame", "ItemTextFrame" }

local EVENT_WINDOW = {
    QUEST_DETAIL = "QuestFrame",
    QUEST_PROGRESS = "QuestFrame",
    QUEST_COMPLETE = "QuestFrame",
    QUEST_GREETING = "QuestFrame",
    GOSSIP_SHOW = "GossipFrame",
    ITEM_TEXT_READY = "ItemTextFrame",
}

local styled = setmetatable({}, { __mode = "k" })  -- window -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function Resolve(win, ref)
    local obj
    if type(ref) == "function" then obj = ref(win) else obj = _G[ref] end
    if ns.Usable(obj) then return obj end
end

-- Also used for the quest details page of the map's quest log, which shows the same QuestInfo text.
function Npc.Heading(font)
    local name = type(font.GetName) == "function" and font:GetName()
    if type(name) == "string" and HEADING_NAMES[name] then return true end
    local parent = type(font.GetParent) == "function" and font:GetParent()
    if type(parent) ~= "table" then return false end
    for _, key in ipairs(HEADING_KEYS) do
        if rawget(parent, key) == font then return true end
    end
    return false
end

local function Button(skin, button)
    for _, getter in ipairs(BUTTON_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok then Hold(skin, texture) end
        end
    end
    Modern.Shapes.Field(skin, button)
end

local function Skin(skin, name)
    local win, def = _G[name], WINDOWS[name]
    if not ns.Usable(win) then return end
    Modern.Window(skin, win)
    Modern.Header(skin, win)
    for _, suffix in ipairs(SUFFIXES) do Hold(skin, _G[name .. suffix]) end
    for _, art in ipairs(def.art or {}) do Hold(skin, _G[art]) end
    for _, panelName in ipairs(def.panels) do
        local panel = _G[panelName]
        if ns.Usable(panel) then
            for _, key in ipairs(PANEL_KEYS) do Hold(skin, panel[key]) end
        end
    end
    for _, ref in ipairs(def.buttons) do
        local button = Resolve(win, ref)
        if button then Button(skin, button) end
    end
    Modern.InkTree(skin, win, { tone = Modern.Theme().text, heading = Npc.Heading, plain = true })
end

-- Hooks are set once per session and do nothing while the window is not styled.
local function Watch(win, name)
    if hooked[win] then return end
    hooked[win] = true
    local function Again()
        local skin = styled[win]
        if skin then ns.Profiler.Run("modern npc", Skin, skin, name) end
    end
    if type(win.HookScript) == "function" then pcall(win.HookScript, win, "OnShow", Again) end
    local panel = GossipPanel(win)
    local box = panel and panel.ScrollBox
    if ns.Usable(box) and type(box.Update) == "function" then pcall(hooksecurefunc, box, "Update", Again) end
    if name == "QuestFrame" and type(_G.QuestInfo_Display) == "function" then
        pcall(hooksecurefunc, "QuestInfo_Display", Again)
    end
end

local function Window(skin, name)
    local win = _G[name]
    if not ns.Usable(win) then return end
    styled[win] = skin
    skin:Remember(win, "modern npc", function() styled[win] = nil end)
    Skin(skin, name)
    Watch(win, name)
end

function Npc.Apply(skin)
    for _, name in ipairs(ORDER) do ns.Profiler.Run("modern npc", Window, skin, name) end
end

function Npc.Event(skin, event)
    local name = EVENT_WINDOW[event]
    if name then ns.Profiler.Run("modern npc", Window, skin, name) end
end
