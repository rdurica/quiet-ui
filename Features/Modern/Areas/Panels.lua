local _, ns = ...

-- The plainer windows of the Forever UI source, one entry each: the dark window and header band, the shared shapes
-- for their controls, and the loose art each one adds (named textures in `art`, atlas or file names in `needles`).
-- `ink` lightens parchment text, `walk = false` keeps the shapes out of a window whose content is not Blizzard's
-- shared templates (the flight map canvas, the settings list), `list(skin, box)` skins a refilled list instead,
-- `map` puts the chrome on BorderFrame, `refresh` names a child and the method that refills its pooled slots (the
-- bank page). Item buttons, models, maps, emblems, icons and texts stay. A window is walked again when it shows or
-- a list updates.

local Modern = ns.Modern
local Panels = {}
Modern.Panels = Panels

-- A pet stable slot (PetStableSlotTemplate): its frame art goes, the pet icon is cropped inside a thin border.
local STABLE_SLOT = { "unlockedBackground", "currentBackground", "lockedBackground" }

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function StableSlot(skin, slot)
    if not IsTexture(slot.lockedBackground) then return false end
    for _, key in ipairs(STABLE_SLOT) do Hold(skin, slot[key]) end
    local name = type(slot.GetName) == "function" and slot:GetName()
    local icon = name and _G[name .. "IconTexture"]
    if IsTexture(icon) then skin:Icon(icon) end
    skin:Panel(slot, Modern.Theme().well)
    skin:Border(slot)
    return true
end

-- The recipient half of the trade window repeats the window chrome and a portrait.
local function Trade(skin, frame)
    local overlay = frame.RecipientOverlay
    if ns.Usable(overlay) then
        Hold(skin, overlay.portrait)
        Hold(skin, overlay.portraitFrame)
    end
end

-- The settings panel: the window, its buttons and search box, its scroll bars, and in the list only checkboxes and
-- value sliders.
local function Settings(skin, frame)
    for _, key in ipairs({ "CloseButton", "ApplyButton" }) do
        if ns.Usable(frame[key]) then Modern.Shapes.Field(skin, frame[key]) end
    end
    if ns.Usable(frame.SearchBox) then Modern.Shapes.Field(skin, frame.SearchBox) end
    Modern.ListControls(skin, frame)
end

local WINDOWS = {
    { name = "TradeFrame", extra = Trade,
        art = { "TradeRecipientBotLeftCorner", "TradeRecipientLeftBorder", "TradeRecipientBG" } },
    { name = "BankFrame", needles = { "bank-divider" }, refresh = { "BankPanel", "RefreshBankPanel" } },
    { name = "TaxiFrame" },
    { name = "FlightMapFrame", map = true, walk = false },
    { name = "MacroFrame", art = { "MacroFramePortrait", "MacroFrameSelectedMacroBackground" },
        needles = { "ui-classtrainer-horizontalbar" } },
    { name = "InspectFrame", needles = { "char-corner", "char-inner" } },
    { name = "DressUpFrame" },
    { name = "TabardFrame", art = { "TabardFramePortrait" }, needles = { "tabardframeouterframe" } },
    { name = "PetitionFrame", art = { "PetitionFramePortrait" }, ink = true },
    { name = "GuildRegistrarFrame", art = { "GuildRegistrarFramePortrait" }, ink = true },
    { name = "PetStableFrame", needles = { "ui-stables-footer-bg", "ui-stables-subheader-bg", "common-insideframe",
        "ui-stables-horz-divider" }, shape = StableSlot },
    { name = "AddonList" },
    { name = "TimeManagerFrame", art = { "TimeManagerGlobe" } },
    { name = "LegacySystemFrame" },
    { name = "SettingsPanel", needles = { "options_innerframe" }, walk = false, extra = Settings,
        list = function(skin, box) Modern.ListControls(skin, box) end },
}

local hooked = setmetatable({}, { __mode = "k" })

local function Skin(def)
    return function(skin, frame)
        Modern.Window(skin, frame)
        Modern.Header(skin, frame)
        if def.map then Modern.WindowChrome(skin, frame.BorderFrame) end
        for _, name in ipairs(def.art or {}) do Hold(skin, _G[name]) end
        if def.needles then Modern.Shapes.HoldArt(skin, frame, def.needles) end
        if def.extra then def.extra(skin, frame) end
        if def.walk ~= false then Modern.Shapes.Walk(skin, frame, { shape = def.shape }) end
        if def.ink then Modern.InkTree(skin, frame, { tone = Modern.Theme().text, plain = true }) end
    end
end

local function Window(skin, def)
    local frame = _G[def.name]
    local Again = Modern.Shapes.Keep(skin, frame, "panels", Skin(def),
        { shape = def.shape, walk = def.walk, list = def.list })
    local child = Again and def.refresh and frame[def.refresh[1]]
    if ns.Usable(child) and not hooked[child] and type(child[def.refresh[2]]) == "function" then
        hooked[child] = true
        pcall(hooksecurefunc, child, def.refresh[2], function() ns.Profiler.Run("modern panels", Again) end)
    end
end

function Panels.Apply(skin)
    for _, def in ipairs(WINDOWS) do ns.Profiler.Run("modern panels", Window, skin, def) end
end
