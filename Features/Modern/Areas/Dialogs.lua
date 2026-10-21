local _, ns = ...

-- Small dialogs of the Forever UI source: the game menu, static popups, the ready check, the stack split, the colour
-- picker, the raid manager panel and the group loot rolls. They take the dark panel and the shared shapes (a dialog title moves into the
-- header band); popups and loot rolls have no title, so they get no band. Popup text, alert icons, progress bars,
-- roll buttons, item icons and the timer fill stay Blizzard's. Game menu buttons and popup contents are rebuilt
-- when they show, so each is walked again then.

local Modern = ns.Modern
local Dialogs = {}
Modern.Dialogs = Dialogs

local POPUPS = 4
local ROLLS = 4
local SPLIT_ART = { "SingleItemSplitBackground", "MultiItemSplitBackground" }

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

-- A group loot roll: the toast art goes, the item icon is cropped in a thin border, the timer is a flat bar.
local function Roll(skin, frame)
    local icon = frame.IconFrame
    if ns.Usable(icon) then
        Hold(skin, icon.Border)
        if IsTexture(icon.Icon) then
            skin:Icon(icon.Icon)
            skin:Border(icon, nil, icon.Icon)
        end
    end
    local timer = frame.Timer
    if ns.Usable(timer) then
        Hold(skin, timer.Background)
        skin:Panel(timer, Modern.Theme().track)
        skin:Border(timer)
    end
end

local function Split(skin, frame)
    for _, key in ipairs(SPLIT_ART) do Hold(skin, frame[key]) end
end

-- `kind`: dialog (title in the header band), window (portrait frame with a title) or panel (no title).
local DIALOGS = {
    { name = "GameMenuFrame", kind = "dialog" },
    { name = "ColorPickerFrame", kind = "dialog" },
    { name = "ReadyCheckListenerFrame", kind = "window" },
    { name = "StackSplitFrame", kind = "panel", extra = Split },
    { name = "CompactRaidFrameManager", kind = "panel" },
}
for index = 1, POPUPS do DIALOGS[#DIALOGS + 1] = { name = "StaticPopup" .. index, kind = "panel" } end
for index = 1, ROLLS do DIALOGS[#DIALOGS + 1] = { name = "GroupLootFrame" .. index, kind = "panel", extra = Roll } end

local function Skin(def)
    return function(skin, frame)
        if def.kind == "dialog" then
            Modern.Dialog(skin, frame)
        else
            Modern.Window(skin, frame)
            if def.kind == "window" then Modern.Header(skin, frame) end
        end
        if def.extra then def.extra(skin, frame) end
        Modern.Shapes.Walk(skin, frame)
    end
end

function Dialogs.Apply(skin)
    for _, def in ipairs(DIALOGS) do
        ns.Run("modern dialogs", Modern.Shapes.Keep, skin, _G[def.name], "dialogs", Skin(def))
    end
end
