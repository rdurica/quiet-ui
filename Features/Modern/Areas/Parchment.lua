local _, ns = ...

local Modern = ns.Modern
Modern.Parchment = Modern.Parchment or {}
local Parchment = Modern.Parchment

local PARCHMENT = "Interface\\AddOns\\QuietUI\\Media\\parchment.tga"
local OVERHANG = 12
local ROW_CENTER = Parchment.ROW_CENTER

local CHROME_KEYS = { "Bg", "Background", "NineSlice", "Border", "PortraitContainer", "portrait", "Portrait",
    "PortraitFrame", "TopTileStreaks", "TitleBg", "Inset", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder",
    "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight" }
local CHROME_SUFFIXES = { "Bg", "Portrait", "TitleBg", "TopTileStreaks", "BtnCornerLeft", "BtnCornerRight",
    "ButtonBottomBorder" }
local PANEL_KEYS = { "Bg", "SealMaterialBG", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft",
    "MaterialBotRight" }

local function GossipPanel(win)
    return type(win.GreetingPanel) == "table" and win.GreetingPanel or nil
end

local WINDOWS = {
    {
        name = "QuestFrame",
        panels = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" },
        scrolls = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" },
        lifts = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" },
        buttons = {
            { "QuestFrameAcceptButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameDeclineButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameCompleteButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameGoodbyeButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameCompleteQuestButton", "primary", "BOTTOMLEFT" },
            { "QuestFrameCancelButton", "secondary", "BOTTOMRIGHT" },
            { "QuestFrameGreetingGoodbyeButton", "secondary", "BOTTOMRIGHT" },
        },
    },
    {
        name = "GossipFrame",
        panels = {},
        scrolls = { GossipPanel, "GossipGreetingScrollFrame" },
        lifts = { function(win)
            local panel = GossipPanel(win)
            return panel and panel.ScrollBox
        end },
        buttons = {
            { function(win)
                local panel = GossipPanel(win)
                return panel and panel.GoodbyeButton or _G.GossipFrameGreetingGoodbyeButton
            end, "secondary", "BOTTOMRIGHT" },
        },
    },
    {
        name = "ItemTextFrame",
        panels = {},
        extra = { "ItemTextMaterialTopLeft", "ItemTextMaterialTopRight", "ItemTextMaterialBotLeft",
            "ItemTextMaterialBotRight" },
        scrolls = { "ItemTextScrollFrame" },
        lifts = { "ItemTextScrollFrame" },
        buttons = {
            { "ItemTextPrevPageButton", "secondary", "BOTTOMLEFT", "<" },
            { "ItemTextNextPageButton", "primary", "BOTTOMRIGHT", ">" },
        },
    },
}

local EVENT_WINDOW = {
    QUEST_DETAIL = "QuestFrame",
    QUEST_PROGRESS = "QuestFrame",
    QUEST_COMPLETE = "QuestFrame",
    QUEST_GREETING = "QuestFrame",
    GOSSIP_SHOW = "GossipFrame",
    ITEM_TEXT_READY = "ItemTextFrame",
}

local windows = {}

local function Resolve(win, ref)
    local obj
    if type(ref) == "function" then obj = ref(win) else obj = _G[ref] end
    if Parchment.Usable(obj) then return obj end
end

local function HideChrome(obj, depth)
    if Parchment.IsTexture(obj) then
        Parchment.Hold(obj, 0)
        return
    end
    if not Parchment.Usable(obj) or (depth or 0) > 2 then return end
    for _, region in ipairs(Parchment.Regions(obj)) do
        if Parchment.IsTexture(region) then Parchment.Hold(region, 0) end
    end
    for _, key in ipairs({ "NineSlice", "Bg" }) do
        local child = obj[key]
        if type(child) == "table" then HideChrome(child, (depth or 0) + 1) end
    end
end

local ApplyWindow

local function SkinWindow(def)
    local win = _G[def.name]
    if not Parchment.Usable(win) then return end
    local state = windows[win]
    if not state then
        state = {}
        windows[win] = state
        local layer = Parchment.Try(win, "CreateTexture", nil, "BACKGROUND", nil, -8)
        if layer then
            Parchment.Try(layer, "SetTexture", PARCHMENT)
            Parchment.Try(layer, "SetPoint", "TOPLEFT", win, "TOPLEFT", -OVERHANG, OVERHANG)
            Parchment.Try(layer, "SetPoint", "BOTTOMRIGHT", win, "BOTTOMRIGHT", OVERHANG, -OVERHANG)
            state.layer = layer
        end
    end
    Parchment.HookScript(win, "OnShow", function() ApplyWindow(def) end)
    Parchment.Try(state.layer, "Show")

    for _, key in ipairs(CHROME_KEYS) do
        local obj = win[key]
        if type(obj) == "table" then HideChrome(obj) end
    end
    for _, suffix in ipairs(CHROME_SUFFIXES) do
        local obj = _G[def.name .. suffix]
        if type(obj) == "table" then HideChrome(obj) end
    end
    for _, name in ipairs(def.extra or {}) do
        Parchment.Hold(_G[name], 0)
    end
    for _, name in ipairs(def.panels) do
        local panel = _G[name]
        if Parchment.Usable(panel) then
            for _, key in ipairs(PANEL_KEYS) do Parchment.Hold(panel[key], 0) end
        end
    end
    for _, ref in ipairs(def.scrolls) do
        Parchment.DimScrollBar(Resolve(win, ref))
    end
    local st = Parchment.State()
    local bandTop
    for _, spec in ipairs(def.buttons) do
        local b = Resolve(win, spec[1])
        if b then
            Parchment.SkinButton(win, b, spec[2], spec[3], spec[4])
            local top = st.skins[b].top
            if top then bandTop = math.max(bandTop or top, top) end
        end
    end
    bandTop = bandTop or (ROW_CENTER + 11)
    for _, ref in ipairs(def.lifts or {}) do
        local sf = Resolve(win, ref)
        if sf then Parchment.LiftScroll(win, sf, bandTop) end
    end
    Parchment.InkTitle(win, def)
    local close = win.CloseButton
    if type(close) ~= "table" then close = _G[def.name .. "CloseButton"] end
    if Parchment.Usable(close) then Parchment.SkinButton(win, close, "close") end
end

ApplyWindow = function(def)
    local ok, err = pcall(SkinWindow, def)
    if not ok then ns.Report("parchment " .. def.name, err) end
end

function Parchment.Restore()
    Parchment.State().active = false
    local ok, err = pcall(function()
        Parchment.ReleaseAll()
        for _, state in pairs(windows) do Parchment.Try(state.layer, "Hide") end
        local st = Parchment.State()
        for b, s in pairs(st.skins) do Parchment.RestoreButton(b, s) end
        Parchment.RestoreLifts()
        Parchment.RestoreTitles()
    end)
    if not ok then ns.Report("parchment restore", err) end
end

function Parchment.Apply()
    Parchment.State().active = true
    for _, def in ipairs(WINDOWS) do ApplyWindow(def) end
end

function Parchment.Event(event)
    if not Parchment.Active() then return end
    local name = EVENT_WINDOW[event]
    for _, def in ipairs(WINDOWS) do
        if def.name == name then ApplyWindow(def) end
    end
end
