local _, ns = ...

-- The draft the window edits. Save writes it; closing or switching preset reloads it.

local Setup = {}
ns.Setup = Setup

-- Private to the Setup files. Other features never read it.
local S = { frame = nil, selectedPresetId = nil, presetName = nil, presetLayout = nil }
Setup.state = S
Setup.draft = {}
Setup.Pages = {}
local draft = Setup.draft

Setup.CONTENT_W = 700
-- Two columns of a page, and the left edge of the right one.
Setup.COLUMN_W = 330
Setup.RIGHT_X = Setup.CONTENT_W - Setup.COLUMN_W
Setup.GROUP_VIEW_H = 352
-- Centres of the Always visible and Only on hover columns (Visible and Groups tabs).
Setup.ALWAYS_X = Setup.CONTENT_W - 220
Setup.HOVER_X = Setup.CONTENT_W - 90

Setup.ROWS = {
    { key = "xp", label = "XP bar" },
    { key = "cooldowns", label = "Cooldown manager" },
    { key = "meter", label = "Damage meter" },
    { key = "resource", label = "Personal resource" },
    { key = "quests", label = "Quest tracker" },
    { key = "auras", label = "Buffs and debuffs" },
    { key = "menu", label = "Bag button" },
    { key = "micro", label = "Micro menu" },
    { key = "party", label = "Party and raid frames", noHover = true },
}

local RANGE_YARDS = { 10, 28, "spell" }

local OPACITIES = { 50, 75, 90 }

local function ReadModern(source)
    local stored = type(source.modernize) == "table" and source.modernize or {}
    draft.modernize = stored.enabled == true
    draft.modernTheme = "dark"
    for _, name in ipairs(ns.Modern.Themes()) do
        if name == stored.theme then draft.modernTheme = name end
    end
    draft.modernOpacity = 75
    for _, percent in ipairs(OPACITIES) do
        if stored.opacity == percent then draft.modernOpacity = percent end
    end
    draft.modernClassColors = stored.classColors ~= false
    draft.modernXPGain = stored.xpGain ~= false
    draft.modernAreas = {}
    for _, area in ipairs(ns.Modern.Areas()) do draft.modernAreas[area.key] = stored[area.key] ~= false end
end

-- Only values that differ from the defaults are stored. Unchecked Modernize keeps the rest.
local function WriteModern()
    local stored
    local function put(key, value)
        stored = stored or {}
        stored[key] = value
    end
    if draft.modernize then put("enabled", true) end
    if draft.modernTheme ~= "dark" then put("theme", draft.modernTheme) end
    if draft.modernOpacity ~= 75 then put("opacity", draft.modernOpacity) end
    if not draft.modernClassColors then put("classColors", false) end
    if not draft.modernXPGain then put("xpGain", false) end
    for _, area in ipairs(ns.Modern.Areas()) do
        if draft.modernAreas[area.key] == false then put(area.key, false) end
    end
    return stored
end

function Setup.ReadDraft(source)
    if S.frame and S.frame.rangeSpell and S.frame.rangeSpell.edit:HasFocus() then S.frame.rangeSpell.edit:ClearFocus() end
    source = source or (ns.Settings.Effective())
    if ns.Settings.MigrateOnce then ns.Settings.MigrateOnce(source) end
    draft.hoverOnly = {}
    for _, row in ipairs(Setup.ROWS) do
        draft.hoverOnly[row.key] = ns.Settings.HoverSetting(source, row.key)
        if row.noHover then
            draft.hoverOnly[row.key] = false
            draft[row.key] = source.autoHideParty ~= true
        else
            draft[row.key] = type(source.visible) == "table" and source.visible[row.key] == true and not draft.hoverOnly[row.key]
        end
    end
    draft.forceLayout = source.forceLayout == true
    draft.player = source.player ~= "resource"
    draft.playerThresholdKind = source.playerThresholdKind == "resource" and "resource" or "health"
    local value = source.playerThresholdPercent
    if value == false then draft.playerThresholdPercent = ""
    elseif type(value) == "number" and not ns.IsSecret(value)
        and value >= 1 and value <= 100 and value == math.floor(value) then draft.playerThresholdPercent = tostring(value)
    else draft.playerThresholdPercent = "70" end
    if S.frame and S.frame.playerThresholdPercent then S.frame.playerThresholdPercent.edit:ClearFocus() end
    draft.requireLivingTarget = source.requireLivingTarget == true
    draft.groupAuras = source.groupAuras ~= false
    draft.alwaysShowDebuffs = source.alwaysShowDebuffs ~= false
    draft.questNotice = source.questNotice ~= false
    draft.questMobs = source.questMobs ~= false
    local noticeSize = source.questNoticeSize
    draft.questNoticeSize = (noticeSize == "smaller" or noticeSize == "larger") and noticeSize or "default"
    draft.chatTabs = source.chatTabs == "top" and "top" or nil
    local highlights = type(source.highlights) == "table" and source.highlights or {}
    draft.highlightHerb = highlights.herb == true
    draft.highlightOre = highlights.ore == true
    draft.highlightQuest = highlights.quest == true
    draft.chat = source.chat ~= false
    local fade = source.chatFade
    draft.chatFade = type(fade) == "number" and fade == fade and math.floor(math.max(0, math.min(60, fade)) / 5) * 5 or 10
    local range = type(source.range) == "table" and source.range or {}
    draft.range = range.yards == 10 or range.yards == 28 or range.yards == "spell"
    draft.rangeYards = draft.range and range.yards or "spell"
    draft.rangeKind = range.kind == "friendly" and "friendly" or "hostile"
    draft.rangeSpell = type(range.spell) == "string" and not ns.IsSecret(range.spell) and range.spell or ""
    draft.groupVisibility = {}
    for group = 1, #ns.BAR_ROWS do
        local mode = type(source.groupVisibility) == "table" and source.groupVisibility[group]
        if mode == "always" or mode == "hover" then draft.groupVisibility[group] = mode end
    end
    ReadModern(source)
    draft.groups, draft.hostile, draft.friendly = {}, {}, {}
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = type(source.groups) == "table" and source.groups[row.id]
        draft.groups[row.id] = type(n) == "number" and n == n and n >= 1 and n <= #ns.BAR_ROWS and math.floor(n) or row.group
        draft.hostile[row.id] = type(source.hostile) == "table" and source.hostile[row.id] == true
        draft.friendly[row.id] = type(source.friendly) == "table" and source.friendly[row.id] == true
    end
end

function Setup.NudgeModernTheme(sign)
    local names = ns.Modern.Themes()
    local index = 1
    for i, name in ipairs(names) do
        if name == draft.modernTheme then index = i end
    end
    index = math.max(1, math.min(#names, index + sign))
    draft.modernTheme = names[index]
    Setup.Paint()
end

function Setup.NudgeModernOpacity(sign)
    local index = 2
    for i, percent in ipairs(OPACITIES) do
        if percent == draft.modernOpacity then index = i end
    end
    draft.modernOpacity = OPACITIES[math.max(1, math.min(#OPACITIES, index + sign))]
    Setup.Paint()
end

function Setup.LoadSavedDraft()
    Setup.ReadDraft()
    local preset = ns.Settings.ActivePreset()
    S.selectedPresetId = preset and ns.Settings.CharDB().presetId or nil
    S.presetName = preset and preset.name or nil
    S.presetLayout = preset and ns.Copy(preset.layout) or nil
end

-- Only checked bar ids are stored. A missing map means every box is off.
local function SavedFlags(flags)
    local saved
    for _, row in ipairs(ns.BAR_ROWS) do
        if flags[row.id] then
            saved = saved or {}
            saved[row.id] = true
        end
    end
    return saved
end

local function DraftSettings()
    local db = {}
    local visible
    for _, row in ipairs(Setup.ROWS) do
        if not row.noHover and draft[row.key] then
            visible = visible or {}
            visible[row.key] = true
        end
    end
    db.visible = visible
    if not draft.party then db.autoHideParty = true end
    for _, row in ipairs(Setup.ROWS) do
        if not row.noHover and (draft.hoverOnly[row.key] or (row.key == "xp" and not draft[row.key])) then
            db.hoverOnly = db.hoverOnly or {}
            db.hoverOnly[row.key] = draft.hoverOnly[row.key] and true or false
        end
    end
    for _, row in ipairs(ns.BAR_ROWS) do
        local group = draft.groups[row.id]
        if draft.groupVisibility[group] then
            db.groupVisibility = db.groupVisibility or {}
            db.groupVisibility[group] = draft.groupVisibility[group]
        end
    end
    if draft.forceLayout then
        db.forceLayout = true
    else
        db.forceLayout = nil
    end
    if draft.player then
        db.player = nil
    else
        db.player = "resource"
    end
    if draft.playerThresholdKind == "resource" then db.playerThresholdKind = "resource" end
    local text = draft.playerThresholdPercent:match("^%s*(.-)%s*$")
    if text == "" then db.playerThresholdPercent = false
    else
        local n = tonumber(text)
        if not text:match("^%d+$") or not n or n < 1 or n > 100 then
            return nil, "Enter a whole percentage from 1 to 100, or leave the field empty."
        end
        if n ~= 70 then db.playerThresholdPercent = n end
    end
    db.requireLivingTarget = draft.requireLivingTarget and true or nil
    if draft.groupAuras then
        db.groupAuras = nil
    else
        db.groupAuras = false
    end
    if not draft.alwaysShowDebuffs then db.alwaysShowDebuffs = false end
    if not draft.questNotice then db.questNotice = false end
    if not draft.questMobs then db.questMobs = false end
    if draft.questNoticeSize == "smaller" or draft.questNoticeSize == "larger" then
        db.questNoticeSize = draft.questNoticeSize
    end
    if draft.chatTabs == "top" then db.chatTabs = "top" end
    if draft.highlightHerb or draft.highlightOre or draft.highlightQuest then
        db.highlights = { herb = draft.highlightHerb or nil, ore = draft.highlightOre or nil,
            quest = draft.highlightQuest or nil }
    end
    if draft.chat then
        db.chat = nil
    else
        db.chat = false
    end
    if draft.chatFade == 10 then
        db.chatFade = nil
    else
        db.chatFade = draft.chatFade
    end
    if draft.range then
        local spell = type(draft.rangeSpell) == "string" and draft.rangeSpell:match("^%s*(.-)%s*$") or ""
        db.range = {
            yards = draft.rangeYards or "spell",
            kind = draft.rangeKind == "friendly" and "friendly" or "hostile",
        }
        if spell ~= "" then db.range.spell = spell end
    else
        db.range = nil
    end
    local groups
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = draft.groups[row.id]
        if n ~= row.group then
            groups = groups or {}
            groups[row.id] = n
        end
    end
    db.groups = groups
    db.hostile = SavedFlags(draft.hostile)
    db.friendly = SavedFlags(draft.friendly)
    db.modernize = WriteModern()
    if S.presetName then db.forceLayout = nil end
    return db
end

function Setup.Write()
    local settings, err = DraftSettings()
    if not settings then ns.Print(err); return end
    if S.presetName then
        if not S.presetLayout then ns.Print("Choose an Edit Mode layout before saving."); return end
        local id, err = ns.Settings.SavePreset(S.selectedPresetId, S.presetName, S.presetLayout, settings)
        if not id then ns.Print(err); return end
        if ns.Layout.CommitPreview then ns.Layout.CommitPreview(true) end
        ns.Settings.ActivatePreset(id)
    else
        if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
        ns.Settings.ActivatePreset(nil, settings)
    end
    Setup.LoadSavedDraft()
    Setup.Paint()
    if ns.Layout.SettingsChanged then ns.Layout.SettingsChanged() end
    if ns.ApplyAll then ns.ApplyAll() end
end

local NOTICE_SIZES = { "smaller", "default", "larger" }

function Setup.NudgeNoticeSize(sign)
    local index = 2
    for i, size in ipairs(NOTICE_SIZES) do
        if size == draft.questNoticeSize then index = i break end
    end
    index = index + sign
    if index < 1 then index = 1 end
    if index > #NOTICE_SIZES then index = #NOTICE_SIZES end
    draft.questNoticeSize = NOTICE_SIZES[index]
    Setup.Paint()
end

function Setup.CycleChatTabs()
    draft.chatTabs = draft.chatTabs ~= "top" and "top" or nil
    Setup.Paint()
end

function Setup.NudgeFade(delta)
    local n = (draft.chatFade or 10) + delta
    if n < 0 then n = 0 end
    if n > 60 then n = 60 end
    draft.chatFade = n
    Setup.Paint()
end

function Setup.NudgeRangeYards(sign)
    local index = 3
    for i, yards in ipairs(RANGE_YARDS) do
        if yards == draft.rangeYards then
            index = i
            break
        end
    end
    index = index + sign
    if index < 1 then index = #RANGE_YARDS end
    if index > #RANGE_YARDS then index = 1 end
    draft.rangeYards = RANGE_YARDS[index]
    Setup.Paint()
end

function Setup.NudgeRangeKind()
    draft.rangeKind = draft.rangeKind == "friendly" and "hostile" or "friendly"
    Setup.Paint()
end

function Setup.NudgeGroup(id, delta)
    local n = (draft.groups[id] or 1) + delta
    local max = #ns.BAR_ROWS
    if n < 1 then n = 1 end
    if n > max then n = max end
    draft.groups[id] = n
    Setup.Paint()
end
