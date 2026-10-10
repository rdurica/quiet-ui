local _, ns = ...

-- One window: layout, HUD visibility, bars, group visibility, player, chat, quest updates and Glance.
-- The frame is named so UISpecialFrames can close it on Escape.
-- The window keeps the tallest page, so switching tabs does not resize it.

local ROWS = {
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

local CONTENT_W = 560
local GROUP_VIEW_H = 264
-- Bottom-left of the minimap, clear of the tracking button.
local MINIMAP_ANGLE = 225

local draft = {}
local selectedPresetId, presetName, presetLayout
local LoadSavedDraft
local frame
local minimapButton
local minimapHooked

-- Per character. An older build kept this on the account; the first character
-- to load keeps that copy, then the account keys are dropped.
local accountMoved = false

function ns.CharDB()
    if type(QuietUICharDB) ~= "table" then
        QuietUICharDB = {}
    end
    if not accountMoved then
        accountMoved = true
        local account = ns.DB()
        if account.visible ~= nil or account.player ~= nil then
            if QuietUICharDB.visible == nil and QuietUICharDB.player == nil then
                QuietUICharDB.visible = account.visible
                QuietUICharDB.player = account.player
            end
            account.visible = nil
            account.player = nil
        end
    end
    if ns.MigrateOnce then ns.MigrateOnce(QuietUICharDB) end
    return QuietUICharDB
end

function ns.HoverSetting(settings, name)
    local hover = settings.hoverOnly
    local value
    if type(hover) == "table" then value = hover[name] end
    if type(value) == "boolean" then return value end
    -- XP defaults to hover unless an existing Always visible choice keeps it up.
    return name == "xp" and not (type(settings.visible) == "table" and settings.visible.xp == true)
end

function ns.OnlyOnHover(name)
    return ns.HoverSetting(ns.Settings and ns.Settings() or ns.CharDB(), name)
end

function ns.VisibilityShow(name, usual, hovered)
    if ns.InEditMode() or ns.Glancing() then return true end
    if ns.OnlyOnHover(name) then return hovered and true or false end
    return ns.Pinned(name) or usual or hovered or false
end

function ns.AutoHideParty()
    return (ns.Settings and ns.Settings() or ns.CharDB()).autoHideParty == true
end

function ns.Pinned(name)
    local visible = (ns.Settings and ns.Settings() or ns.CharDB()).visible
    return type(visible) == "table" and visible[name] and true or false
end

-- Missing means on. Only an explicit "resource" keeps the portrait for edit mode.
function ns.PlayerStyle()
    if (ns.Settings and ns.Settings() or ns.CharDB()).player == "resource" then return "resource" end
    return "classic"
end

function ns.PlayerThreshold()
    local settings = ns.Settings and ns.Settings() or ns.CharDB()
    local kind = settings.playerThresholdKind == "resource" and "resource" or "health"
    local value = settings.playerThresholdPercent
    if value == false then return kind, nil end
    if type(value) == "number" and not ns.IsSecret(value)
        and value >= 1 and value <= 100 and value == math.floor(value) then return kind, value end
    return kind, 70
end

function ns.RequireLivingTarget()
    return (ns.Settings and ns.Settings() or ns.CharDB()).requireLivingTarget == true
end

-- Missing means on. Only an explicit false leaves buffs on their own.
function ns.GroupAuras()
    return (ns.Settings and ns.Settings() or ns.CharDB()).groupAuras ~= false
end

-- Missing means on. Only an explicit false lets debuffs fade.
function ns.AlwaysShowDebuffs()
    return (ns.Settings and ns.Settings() or ns.CharDB()).alwaysShowDebuffs ~= false
end

-- Missing means on. Only an explicit false turns quest update notices off.
function ns.QuestNoticeEnabled()
    return (ns.Settings and ns.Settings() or ns.CharDB()).questNotice ~= false
end

-- Missing means on. Only an explicit false turns quest mob icons off.
function ns.QuestMobs()
    return (ns.Settings and ns.Settings() or ns.CharDB()).questMobs ~= false
end

-- Missing means on. Only an explicit false keeps the original quest, dialog and book windows.
function ns.Parchment()
    return (ns.Settings and ns.Settings() or ns.CharDB()).parchment == true
end

-- Missing means all off. Only explicit true values turn a category on.
function ns.Highlights()
    local stored = (ns.Settings and ns.Settings() or ns.CharDB()).highlights
    if type(stored) ~= "table" then stored = {} end
    return { herb = stored.herb == true, ore = stored.ore == true, quest = stored.quest == true }
end

-- Missing means the tracker size. Only "smaller" and "larger" change it.
function ns.QuestNoticeSize()
    local size = (ns.Settings and ns.Settings() or ns.CharDB()).questNoticeSize
    if size == "smaller" or size == "larger" then return size end
    return "default"
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.ModernChat()
    return (ns.Settings and ns.Settings() or ns.CharDB()).chat ~= false
end

-- Missing means off. Only an explicit true selects the QuietUI layout when the addon turns on.
function ns.ForceQuietLayout()
    return (ns.ActivePreset and ns.ActivePreset()) ~= nil
        or (ns.Settings and ns.Settings() or ns.CharDB()).forceLayout == true
end

-- Seconds a line stays at the bottom. Missing means 10. 0 keeps the line.
function ns.ChatFade()
    local n = (ns.Settings and ns.Settings() or ns.CharDB()).chatFade
    if type(n) ~= "number" or n ~= n then return 10 end
    if n <= 0 then return 0 end
    n = math.floor(n)
    if n > 60 then n = 60 end
    return math.floor(n / 5) * 5
end

-- Missing means off. yards is 10, 28, or "spell". kind is "hostile" or "friendly".
-- spell is an optional name. Missing means the longest matching spell on bar 1.
function ns.Range()
    local range = (ns.Settings and ns.Settings() or ns.CharDB()).range
    if type(range) ~= "table" then return nil end
    local yards = range.yards
    if yards ~= 10 and yards ~= 28 and yards ~= "spell" then return nil end
    local kind = range.kind == "friendly" and "friendly" or "hostile"
    local spell = range.spell
    if type(spell) ~= "string" or ns.IsSecret(spell) then return yards, kind end
    spell = spell:match("^%s*(.-)%s*$")
    if not spell or spell == "" then return yards, kind end
    return yards, kind, spell
end

local function FadeText(seconds)
    if not seconds or seconds <= 0 then return "Stay" end
    return seconds .. " s"
end

local RANGE_YARDS = { 10, 28, "spell" }

local function RangeYardsText(yards)
    if yards == 10 then return "10" end
    if yards == 28 then return "28" end
    return "Spell"
end

local function RangeKindText(kind)
    if kind == "friendly" then return "Friendly" end
    return "Unfriendly"
end

local function Flat(widget, alpha)
    if not widget.SetBackdrop then return end
    widget:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    widget:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    widget:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
end

local function Backdropped(kind, name, parent, template)
    if template then
        local ok, widget = pcall(CreateFrame, kind, name, parent, template)
        if ok and widget then return widget end
    end
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end

-- Gold edge for input fields, short tabs and steppers.
local function GoldEdge(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        widget:SetBackdropColor(0.08, 0.06, 0.04, 0.92)
        widget:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
    end)
    return ok
end

-- A separate texture keeps every dialog opaque even without BackdropTemplate.
function ns.DialogBackground(widget)
    local fill = widget:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(widget)
    fill:SetColorTexture(0.05, 0.05, 0.05, 1)
    return fill
end

-- Read foreign frames only; their scroll children can out-level the root dialog.
local function DialogRead(widget, method)
    local ok, value = pcall(function()
        if not ns.Usable(widget) or type(widget[method]) ~= "function" then return end
        return widget[method](widget)
    end)
    if ok then return value end
end

function ns.RaiseDialog(widget)
    widget:SetFrameStrata("DIALOG")
    if type(widget.Raise) == "function" then pcall(widget.Raise, widget) end
    local highest = 0
    local visited = {}
    local function Scan(parent)
        if parent == widget or visited[parent] then return end
        visited[parent] = true
        local ok, children = pcall(function()
            if not ns.Usable(parent) or type(parent.GetChildren) ~= "function" then return end
            return { parent:GetChildren() }
        end)
        if not ok or not children then return end
        for _, child in ipairs(children) do
            local shown = child ~= widget and DialogRead(child, "IsShown")
            if type(shown) == "boolean" and not ns.IsSecret(shown) and shown then
                local strata = DialogRead(child, "GetFrameStrata")
                if not ns.IsSecret(strata) and strata == "DIALOG" then
                    local level = DialogRead(child, "GetFrameLevel")
                    if type(level) == "number" and not ns.IsSecret(level)
                        and level == level and level < math.huge then
                        highest = math.max(highest, level)
                    end
                end
                Scan(child)
            end
        end
    end
    Scan(UIParent)
    if widget:GetFrameLevel() <= highest then widget:SetFrameLevel(highest + 1) end
end

local function SkinSmall(button, gold)
    if gold == nil then gold = true end
    if not gold or not GoldEdge(button) then Flat(button, 1) end
    ns.DialogBackground(button)
    -- Texture edges also work when SetBackdrop is unavailable.
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = button:CreateTexture(nil, "BORDER")
        if gold then line:SetColorTexture(0.75, 0.6, 0.28, 0.95)
        else line:SetColorTexture(0.85, 0.85, 0.85, 0.35) end
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetHeight(1)
            line:SetPoint(edge .. "LEFT", 0, 0)
            line:SetPoint(edge .. "RIGHT", 0, 0)
        else
            line:SetWidth(1)
            line:SetPoint("TOP" .. edge, 0, 0)
            line:SetPoint("BOTTOM" .. edge, 0, 0)
        end
    end
    if button.label and button.label.SetTextColor then
        if gold then button.label:SetTextColor(0.95, 0.75, 0.25)
        else button.label:SetTextColor(0.9, 0.9, 0.9) end
    end
    if type(button.HookScript) == "function" then
        button:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
        button:HookScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    end
end

local function PaintBox(box, on)
    if not box then return end
    if box.SetChecked then
        box:SetChecked(on and true or false)
        return
    end
    if not box.check then return end
    if on then box.check:Show() else box.check:Hide() end
end

local function ButtonText(button, text)
    if button.label then button.label:SetText(text) end
    if button.SetText then button:SetText(text) end
end

local function Paint()
    if not frame then return end
    if frame.presetSelector then
        ButtonText(frame.presetSelector, presetName or "<no preset>")
        ButtonText(frame.layoutSelector, ns.LayoutLabel and ns.LayoutLabel(presetLayout)
            or (presetLayout and presetLayout.layoutName or "Choose layout"))
        if presetName then
            frame.forceLayout:Hide()
            frame.layoutSelector:Show()
            frame.renamePreset:Enable()
            if selectedPresetId then frame.deletePreset:Enable() else frame.deletePreset:Disable() end
        else
            frame.forceLayout:Show()
            frame.layoutSelector:Hide()
            frame.renamePreset:Disable()
            frame.deletePreset:Disable()
        end
        frame.renamePreset:SetAlpha(presetName and 1 or 0.45)
        frame.deletePreset:SetAlpha(selectedPresetId and 1 or 0.45)
    end
    for _, row in ipairs(frame.rows) do
        PaintBox(row.always.box, draft[row.key])
        PaintBox(row.hover.box, draft.hoverOnly[row.key])
    end
    if frame.forceLayout then
        PaintBox(frame.forceLayout.box, draft.forceLayout)
    end
    if frame.playerRow then
        PaintBox(frame.playerRow.box, draft.player)
    end
    if frame.playerThresholdKind then
        frame.playerThresholdKind.value:SetText(draft.playerThresholdKind == "resource" and "Resource" or "Health")
        if draft.player then frame.playerThresholdKind:Show() else frame.playerThresholdKind:Hide() end
    end
    if frame.playerThresholdPercent then
        local row = frame.playerThresholdPercent
        if row.edit:GetText() ~= draft.playerThresholdPercent then row.edit:SetText(draft.playerThresholdPercent) end
        if draft.player then row:Show() else row.edit:ClearFocus(); row:Hide() end
    end
    if frame.requireLivingTarget then
        PaintBox(frame.requireLivingTarget.box, draft.requireLivingTarget)
    end
    if frame.groupAuras then
        PaintBox(frame.groupAuras.box, draft.groupAuras)
    end
    if frame.alwaysShowDebuffs then
        PaintBox(frame.alwaysShowDebuffs.box, draft.alwaysShowDebuffs)
    end
    if frame.questNotice then
        PaintBox(frame.questNotice.box, draft.questNotice)
    end
    if frame.questMobs then PaintBox(frame.questMobs.box, draft.questMobs) end
    if frame.parchment then PaintBox(frame.parchment.box, draft.parchment) end
    if frame.questNoticeSize then
        local size = draft.questNoticeSize
        frame.questNoticeSize.value:SetText(size == "smaller" and "Smaller" or size == "larger" and "Larger" or "Default")
    end
    if frame.highlightHerb then PaintBox(frame.highlightHerb.box, draft.highlightHerb) end
    if frame.highlightOre then PaintBox(frame.highlightOre.box, draft.highlightOre) end
    if frame.highlightQuest then PaintBox(frame.highlightQuest.box, draft.highlightQuest) end
    if frame.chat then
        PaintBox(frame.chat.box, draft.chat)
    end
    if frame.fade then
        frame.fade.value:SetText(FadeText(draft.chatFade))
    end
    if frame.range then
        PaintBox(frame.range.box, draft.range)
    end
    if frame.rangeYards then
        frame.rangeYards.value:SetText(RangeYardsText(draft.rangeYards))
    end
    if frame.rangeKind then
        frame.rangeKind.value:SetText(RangeKindText(draft.rangeKind))
    end
    if frame.rangeSpell then
        if draft.rangeYards == "spell" then
            frame.rangeSpell:Show()
        else
            if frame.rangeSpell.edit and frame.rangeSpell.edit:HasFocus() then
                frame.rangeSpell.edit:ClearFocus()
            end
            frame.rangeSpell:Hide()
        end
        if frame.rangeSpell.edit and not frame.rangeSpell.edit:HasFocus() then
            local text = draft.rangeSpell or ""
            if frame.rangeSpell.edit:GetText() ~= text then
                frame.rangeSpell.edit:SetText(text)
            end
        end
    end
    if frame.groupRows then
        for _, row in ipairs(frame.groupRows) do
            row.value:SetText(tostring(draft.groups[row.id]))
            PaintBox(row.hostile.box, draft.hostile[row.id])
            PaintBox(row.friendly.box, draft.friendly[row.id])
            local mode = draft.groupVisibility[draft.groups[row.id]]
            for _, button in ipairs({ row.hostile, row.friendly }) do
                if mode then button:Disable() else button:Enable() end
                button:SetAlpha(mode and 0.4 or 1)
                button.mode = mode
                button.group = draft.groups[row.id]
            end
        end
    end
    if frame.visibilityRows then
        local members = {}
        for _, bar in ipairs(ns.BAR_ROWS) do
            local group = draft.groups[bar.id]
            members[group] = members[group] or {}
            members[group][#members[group] + 1] = bar.label
        end
        local count = 0
        for group, row in ipairs(frame.visibilityRows) do
            if members[group] then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame.groupContent, "TOPLEFT", 0, -count * 44)
                row.members:SetText(table.concat(members[group], ", "))
                PaintBox(row.always.box, draft.groupVisibility[group] == "always")
                PaintBox(row.hover.box, draft.groupVisibility[group] == "hover")
                row:Show()
                count = count + 1
            else row:Hide() end
        end
        frame.groupContent:SetHeight(math.max(1, count * 44))
        local max = math.max(0, count * 44 - GROUP_VIEW_H)
        frame.groupScroll:SetVerticalScroll(math.min(frame.groupScroll:GetVerticalScroll(), max))
    end
    if frame.tabs then
        for _, tab in ipairs(frame.tabs) do
            local on = tab.id == frame.page
            if tab.SetBackdropBorderColor then
                if on then tab:SetBackdropBorderColor(0.95, 0.75, 0.25, 1)
                else tab:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95) end
            end
            if tab.label and tab.label.SetTextColor then
                if on then tab.label:SetTextColor(0.95, 0.75, 0.25)
                else tab.label:SetTextColor(0.85, 0.85, 0.85) end
            end
        end
    end
end

local function ReadDraft(source)
    if frame and frame.rangeSpell and frame.rangeSpell.edit:HasFocus() then frame.rangeSpell.edit:ClearFocus() end
    source = source or (ns.Settings and ns.Settings() or ns.CharDB())
    if ns.MigrateOnce then ns.MigrateOnce(source) end
    draft.hoverOnly = {}
    for _, row in ipairs(ROWS) do
        draft.hoverOnly[row.key] = ns.HoverSetting(source, row.key)
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
    if frame and frame.playerThresholdPercent then frame.playerThresholdPercent.edit:ClearFocus() end
    draft.requireLivingTarget = source.requireLivingTarget == true
    draft.groupAuras = source.groupAuras ~= false
    draft.alwaysShowDebuffs = source.alwaysShowDebuffs ~= false
    draft.questNotice = source.questNotice ~= false
    draft.questMobs = source.questMobs ~= false
    draft.parchment = source.parchment == true
    local noticeSize = source.questNoticeSize
    draft.questNoticeSize = (noticeSize == "smaller" or noticeSize == "larger") and noticeSize or "default"
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
    draft.groups, draft.hostile, draft.friendly = {}, {}, {}
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = type(source.groups) == "table" and source.groups[row.id]
        draft.groups[row.id] = type(n) == "number" and n == n and n >= 1 and n <= #ns.BAR_ROWS and math.floor(n) or row.group
        draft.hostile[row.id] = type(source.hostile) == "table" and source.hostile[row.id] == true
        draft.friendly[row.id] = type(source.friendly) == "table" and source.friendly[row.id] == true
    end
end

LoadSavedDraft = function()
    ReadDraft()
    local preset = ns.ActivePreset()
    selectedPresetId = preset and ns.CharDB().presetId or nil
    presetName = preset and preset.name or nil
    presetLayout = preset and ns.Copy(preset.layout) or nil
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
    for _, row in ipairs(ROWS) do
        if not row.noHover and draft[row.key] then
            visible = visible or {}
            visible[row.key] = true
        end
    end
    db.visible = visible
    if not draft.party then db.autoHideParty = true end
    for _, row in ipairs(ROWS) do
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
    if draft.parchment then db.parchment = true end
    if draft.questNoticeSize == "smaller" or draft.questNoticeSize == "larger" then
        db.questNoticeSize = draft.questNoticeSize
    end
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
    if presetName then db.forceLayout = nil end
    return db
end

local function Write()
    local settings, err = DraftSettings()
    if not settings then ns.Print(err); return end
    if presetName then
        if not presetLayout then ns.Print("Choose an Edit Mode layout before saving."); return end
        local id, err = ns.SavePreset(selectedPresetId, presetName, presetLayout, settings)
        if not id then ns.Print(err); return end
        if ns.CommitLayoutPreview then ns.CommitLayoutPreview(true) end
        ns.ActivatePreset(id)
    else
        if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
        ns.ActivatePreset(nil, settings)
    end
    LoadSavedDraft()
    Paint()
    if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
    if ns.ApplyAll then ns.ApplyAll() end
end

local function ActionButton(parent, text, onClick)
    local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not button then
        button = Backdropped("Button", nil, parent)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetPoint("CENTER")
        if type(button.SetFontString) == "function" then button:SetFontString(button.label) end
        SkinSmall(button, false)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    elseif type(button.GetFontString) == "function" then
        button.label = button:GetFontString()
    end
    button:SetSize(112, 22)
    ButtonText(button, text)
    button:SetScript("OnClick", onClick)
    return button
end

-- Layout resolves this at run time, after Setup has loaded.
ns.DialogButton = ActionButton

local function CheckMark(parent)
    -- The loose checkbox textures draw only the tick on this client. The template keeps the box.
    local ok, box = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if ok and box and box.SetChecked then
        box:SetSize(22, 22)
        box:EnableMouse(false)
        if box.Text then box.Text:Hide() end
        local text = box.GetFontString and box:GetFontString()
        if text then text:Hide() end
        return box
    end
    box = parent:CreateTexture(nil, "ARTWORK")
    box:SetSize(20, 20)
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box.check = parent:CreateTexture(nil, "OVERLAY")
    box.check:SetAllPoints(box)
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:Hide()
    return box
end

local function Choice(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(CONTENT_W, 22)
    button.box = CheckMark(button)
    button.box:SetPoint("LEFT", 0, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.box, "RIGHT", 4, 0)
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.12)
    button:SetScript("OnClick", onClick)
    return button
end

local NOTICE_SIZES = { "smaller", "default", "larger" }

local function NudgeNoticeSize(sign)
    local index = 2
    for i, size in ipairs(NOTICE_SIZES) do
        if size == draft.questNoticeSize then index = i break end
    end
    index = index + sign
    if index < 1 then index = 1 end
    if index > #NOTICE_SIZES then index = #NOTICE_SIZES end
    draft.questNoticeSize = NOTICE_SIZES[index]
    Paint()
end

local function NudgeFade(delta)
    local n = (draft.chatFade or 10) + delta
    if n < 0 then n = 0 end
    if n > 60 then n = 60 end
    draft.chatFade = n
    Paint()
end

local function NudgeRangeYards(sign)
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
    Paint()
end

local function NudgeRangeKind()
    draft.rangeKind = draft.rangeKind == "friendly" and "hostile" or "friendly"
    Paint()
end

local function NudgeGroup(id, delta)
    local n = (draft.groups[id] or 1) + delta
    local max = #ns.BAR_ROWS
    if n < 1 then n = 1 end
    if n > max then n = max end
    draft.groups[id] = n
    Paint()
end

local function Mini(parent, text, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 22)
    button.box = CheckMark(button)
    button.box:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        if self.mode and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Controlled by Group " .. self.group .. ": "
                .. (self.mode == "hover" and "Only on hover" or "Always visible"))
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    return button
end

local function Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    row.plus = Mini(row, "+", function() onDelta(1) end)
    row.minus = Mini(row, "-", function() onDelta(-1) end)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetWidth(44)
    row.value:SetJustifyH("CENTER")
    row.plus:SetPoint("RIGHT", 0, 0)
    row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
    row.minus:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
    return row
end

-- Empty means bar 1. Escape only leaves the field, so the window stays open.
local function SpellField(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText("Spell")
    local box = Backdropped("EditBox", nil, row)
    box:SetSize(144, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(48)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if box.SetTextColor then box:SetTextColor(1, 0.95, 0.8, 1) end
    local gold = GoldEdge(box)
    if not gold then Flat(box, 0.9) end
    box._quietGold = gold and true or false
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("Bar 1")
    box.hint = hint
    local function ShowHint(self)
        local text = self:GetText() or ""
        if text == "" and not self:HasFocus() then
            hint:Show()
        else
            hint:Hide()
        end
    end
    box:SetScript("OnTextChanged", function(self)
        draft.rangeSpell = self:GetText() or ""
        ShowHint(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.86, 0.4, 1)
        end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
        end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ShowHint(box)
    row.edit = box
    return row
end

local function PercentField(parent, label, key)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    local box = Backdropped("EditBox", nil, row)
    box:SetSize(72, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(16)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if not GoldEdge(box) then Flat(box, 0.9) end
    box:SetScript("OnTextChanged", function(self) draft[key] = self:GetText() or "" end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.edit = box
    return row
end

local function Help(parent, label, title, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)
    button:SetPoint("LEFT", label, "RIGHT", 4, 0)
    button:SetNormalTexture("Interface\\Common\\help-i")
    button:SetHighlightTexture("Interface\\Common\\help-i")
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    button:SetScript("OnHide", function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return button
end

local function Section(parent, text, help)
    -- Gold title only. The old group-indicator bar is the classic paperdoll and collides with the column titles.
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 16)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetText(text)
    if help then row.help = Help(row, row.label, text, help) end
    return row
end

local function Body(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetWidth(CONTENT_W)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end

local function ColumnLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    return label
end

local TABS = {
    { id = "general", label = "General", height = 224 },
    { id = "visible", label = "Visible", height = 262 },
    { id = "bars", label = "Bars", height = 308 },
    { id = "groups", label = "Groups", height = 320 },
    { id = "player", label = "Player", height = 306 },
    { id = "chat", label = "Misc.", height = 320 },
    { id = "info", label = "Info", height = 148 },
}

-- Portrait frame needs room under the portrait. Gold dialog needs room inside the thick edge.
local CHROME = {
    portrait = { width = 612, side = 26, tabY = -74, pageY = -102, footer = 52, buttonY = 16 },
    gold = { width = 636, side = 38, tabY = -56, pageY = -88, footer = 64, buttonY = 28, titleY = -30, closeX = -18, closeY = -16 },
    flat = { width = 592, side = 16, tabY = -40, pageY = -76, footer = 52, buttonY = 16, titleY = -14, closeX = -10, closeY = -10 },
}

local function MaxPage()
    local max = 0
    for _, info in ipairs(TABS) do
        if info.height > max then max = info.height end
    end
    return max
end

local function TabButton(parent, text, width, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(width, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.15)
    button:SetScript("OnClick", onClick)
    return button
end

local function Page(parent, id, height, metrics)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(CONTENT_W, height)
    page:SetPoint("TOPLEFT", metrics.side, metrics.pageY)
    page:SetFrameLevel(parent:GetFrameLevel() + 20)
    page:Hide()
    return page
end

local function ShowPage(widget, id)
    if widget.presetMenu then widget.presetMenu:Hide() end
    if widget.layoutMenu then widget.layoutMenu:Hide() end
    widget.page = id
    for _, page in ipairs(widget.pages) do
        if page.id == id then page:Show() else page:Hide() end
    end
    Paint()
end

local function EnsureEscape(widget)
    local name = widget:GetName()
    if not name or not UISpecialFrames then return end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = name
end

local function ApplyTitle(widget, text)
    if widget.SetTitle then
        local ok = pcall(widget.SetTitle, widget, text)
        if ok then return end
    end
    local title = widget.TitleText
    if not title and widget.TitleContainer then
        title = widget.TitleContainer.TitleText
    end
    if title and title.SetText then
        title:SetText(text)
    end
end

local function ApplyPortrait(widget)
    pcall(function()
        if widget.SetPortraitToUnit then
            widget:SetPortraitToUnit("player")
            return
        end
        if type(SetPortraitTexture) ~= "function" then return end
        local texture = widget.portrait
        if not texture and widget.PortraitContainer then
            texture = widget.PortraitContainer.portrait
        end
        if texture then
            SetPortraitTexture(texture, "player")
        end
    end)
end

local function GoldWindow(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        widget:SetBackdropColor(1, 1, 1, 1)
        widget:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    return ok
end

ns.DialogGoldWindow = GoldWindow

local function CloseButton(parent, metrics)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button:SetPoint("TOPRIGHT", metrics.closeX, metrics.closeY)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText("X")
    SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", function()
        parent:Hide()
    end)
    return button
end

local function PortraitChrome(widget)
    return widget.SetTitle or widget.TitleText or widget.TitleContainer
        or widget.PortraitContainer or widget.portrait
end

local function SelectMenu(owner, key, anchor, entries)
    local menu = owner[key]
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = Backdropped("Frame", nil, owner)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(owner:GetFrameLevel() + 60)
        Flat(menu, 1)
        ns.DialogBackground(menu)
        if menu.SetBackdropBorderColor then menu:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.7) end
        menu:EnableMouse(true)
        menu.items = {}
        owner[key] = menu
    end
    for _, item in ipairs(menu.items) do item:Hide() end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    menu:SetSize(300, 12 + 28 * math.min(#entries, 8))
    if not menu.scroll then
        menu.scroll = CreateFrame("ScrollFrame", nil, menu)
        menu.scroll:SetPoint("TOPLEFT", 6, -6)
        menu.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        menu.content = CreateFrame("Frame", nil, menu.scroll)
        menu.content:SetWidth(288)
        menu.scroll:SetScrollChild(menu.content)
        menu.scroll:EnableMouseWheel(true)
        menu.scroll:SetScript("OnMouseWheel", function(_, delta)
            menu.offset = math.max(0, math.min(menu.maximum or 0, (menu.offset or 0) - delta * 28))
            menu.scroll:SetVerticalScroll(menu.offset)
        end)
    end
    menu.content:SetHeight(math.max(28, #entries * 28))
    menu.maximum = math.max(0, (#entries - 8) * 28)
    menu.offset = 0
    menu.scroll:SetVerticalScroll(0)
    for index, entry in ipairs(entries) do
        local item = menu.items[index]
        if not item then
            item = CreateFrame("Button", nil, menu.content)
            item:RegisterForClicks("LeftButtonUp")
            item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            item.label:SetPoint("LEFT", 18, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            item.selected = item:CreateTexture(nil, "BACKGROUND")
            item.selected:SetAllPoints()
            item.selected:SetColorTexture(0.95, 0.75, 0.25, 0.12)
            item.mark = item:CreateTexture(nil, "ARTWORK")
            item.mark:SetSize(2, 14)
            item.mark:SetPoint("LEFT", 6, 0)
            item.mark:SetColorTexture(0.95, 0.75, 0.25, 1)
            local hover = item:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.95, 0.75, 0.25, 0.16)
            menu.items[index] = item
        end
        item:SetSize(288, 26)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        ButtonText(item, entry.name)
        if entry.selected then
            item.selected:Show()
            item.mark:Show()
            item.label:SetTextColor(0.95, 0.75, 0.25)
        else
            item.selected:Hide()
            item.mark:Hide()
            item.label:SetTextColor(0.9, 0.9, 0.9)
        end
        item:SetScript("OnClick", function() menu:Hide(); entry.select() end)
        item:Show()
    end
    menu:Show()
end

local function PresetDialog(owner, title, text, accept)
    local dialog = owner.presetDialog
    if not dialog then
        local blocker = CreateFrame("Frame", nil, owner)
        blocker:SetAllPoints(owner)
        blocker:SetFrameLevel(owner:GetFrameLevel() + 75)
        blocker:EnableMouse(true)
        local ok, widget = pcall(CreateFrame, "Frame", nil, blocker, "PortraitFrameTemplate")
        local side, bodyY, editY, buttonY = 26, -96, -154, 18
        if ok and widget and PortraitChrome(widget) then
            dialog = widget
            ApplyTitle(dialog, "Shared preset")
            ApplyPortrait(dialog)
            dialog:SetSize(420, 244)
        else
            dialog = ok and widget or Backdropped("Frame", nil, blocker)
            if GoldWindow(dialog) then
                side, bodyY, editY, buttonY = 28, -56, -114, 28
                dialog:SetSize(420, 214)
            else
                Flat(dialog, 1)
                side, bodyY, editY, buttonY = 16, -40, -98, 16
                dialog:SetSize(380, 186)
            end
            dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dialog.title:SetText("Shared preset")
            dialog.title:SetPoint("TOP", 0, -26)
        end
        ns.DialogBackground(dialog)
        dialog.blocker = blocker
        dialog:SetScript("OnHide", function() blocker:Hide() end)
        dialog:SetPoint("CENTER")
        dialog:SetFrameLevel(owner:GetFrameLevel() + 80)
        dialog:EnableMouse(true)
        local close = dialog.CloseButton or dialog.closeButton
        if close then close:SetScript("OnClick", function() dialog:Hide() end) end
        dialog.body = Body(dialog, "")
        local contentWidth = (side == 16 and 380 or 420) - 2 * side
        dialog.body:SetWidth(contentWidth)
        dialog.body:SetPoint("TOPLEFT", side, bodyY)
        dialog.edit = Backdropped("EditBox", nil, dialog)
        if not GoldEdge(dialog.edit) then Flat(dialog.edit, 1) end
        dialog.edit:SetSize(contentWidth, 24)
        dialog.edit:SetPoint("TOPLEFT", side, editY)
        dialog.edit:SetFontObject("GameFontHighlightSmall")
        dialog.edit:SetAutoFocus(false)
        dialog.edit:SetMaxLetters(64)
        dialog.edit:SetTextInsets(6, 6, 0, 0)
        dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.edit:SetScript("OnEnterPressed", function() dialog.yes:GetScript("OnClick")() end)
        dialog.yes = ActionButton(dialog, "Confirm", function() end)
        dialog.yes:SetPoint("BOTTOMRIGHT", -side, buttonY)
        dialog.no = ActionButton(dialog, "Cancel", function() dialog:Hide() end)
        dialog.no:SetPoint("BOTTOMLEFT", side, buttonY)
        owner.presetDialog = dialog
    end
    dialog.body:SetText(title)
    if text ~= nil then dialog.edit:SetText(text); dialog.edit:Show() else dialog.edit:Hide() end
    dialog.yes:SetScript("OnClick", function()
        local ok, err = accept(dialog.edit:GetText())
        if ok then dialog:Hide(); Paint() else dialog.body:SetText(err) end
    end)
    if owner.presetMenu then owner.presetMenu:Hide() end
    if owner.layoutMenu then owner.layoutMenu:Hide() end
    dialog.blocker:Show()
    dialog:Show()
    if text ~= nil then dialog.edit:SetFocus(); dialog.edit:HighlightText() end
end

local function CreateSetup()
    local ok, widget = pcall(CreateFrame, "Frame", "QuietUISetup", UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and widget and PortraitChrome(widget) then
        kind = "portrait"
        widget._quietPortrait = true
        ApplyTitle(widget, "QuietUI")
        ApplyPortrait(widget)
    else
        if not (ok and widget) then
            widget = Backdropped("Frame", "QuietUISetup", UIParent)
        end
        if GoldWindow(widget) then
            kind = "gold"
        else
            Flat(widget, 0.9)
        end
    end
    local metrics = CHROME[kind]
    widget:ClearAllPoints()
    widget:SetSize(metrics.width, -metrics.pageY + MaxPage() + metrics.footer)
    widget:SetPoint("CENTER")
    widget:SetFrameStrata("DIALOG")
    ns.DialogBackground(widget)
    widget:EnableMouse(true)
    widget:Hide()
    EnsureEscape(widget)

    if kind ~= "portrait" then
        widget.title = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        widget.title:SetText("QuietUI")
        widget.title:SetPoint("TOP", 0, metrics.titleY)
        widget.close = CloseButton(widget, metrics)
    end

    widget.tabs = {}
    widget.pages = {}
    -- Keep every tab on one centered row.
    local tabW, gap = 68, 4
    local total = #TABS * tabW + (#TABS - 1) * gap
    local x = -total / 2
    for _, info in ipairs(TABS) do
        local id = info.id
        local tab = TabButton(widget, info.label, tabW, function()
            ShowPage(widget, id)
        end)
        tab.id = id
        tab:SetFrameLevel(widget:GetFrameLevel() + 20)
        tab:SetPoint("TOP", widget, "TOP", x + tabW / 2, metrics.tabY)
        x = x + tabW + gap
        widget.tabs[#widget.tabs + 1] = tab
        widget.pages[#widget.pages + 1] = Page(widget, id, info.height, metrics)
    end

    local general = widget.pages[1]
    widget.presetHeader = Section(general, "Shared preset",
        "Share settings and an Edit Mode layout across characters. Save updates the selected preset for everyone using it. Without a preset, settings belong to this character.")
    widget.presetHeader:SetPoint("TOPLEFT", general, "TOPLEFT", 0, 0)
    widget.presetSelector = ActionButton(general, "<no preset>", function()
        if widget.layoutMenu then widget.layoutMenu:Hide() end
        local entries = { { name = "<no preset>", selected = presetName == nil, select = function()
            if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
            selectedPresetId, presetName, presetLayout = nil, nil, nil
            Paint()
        end } }
        for _, item in ipairs(ns.PresetList()) do
            local id = item.id
            entries[#entries + 1] = { name = item.name, selected = selectedPresetId == id, select = function()
                local preset = ns.Presets()[id]
                if not preset then return end
                if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
                ReadDraft(preset.settings)
                selectedPresetId, presetName, presetLayout = id, preset.name, ns.Copy(preset.layout)
                Paint()
            end }
        end
        SelectMenu(widget, "presetMenu", widget.presetSelector, entries)
    end)
    widget.presetSelector:SetSize(CONTENT_W, 24)
    widget.presetSelector:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -24)
    widget.newPreset = ActionButton(general, "New preset", function()
        PresetDialog(widget, "Name the new shared preset.", "", function(name)
            local valid, err = ns.PresetName(name)
            if not valid then return false, err end
            selectedPresetId, presetName = nil, valid
            presetLayout = ns.CurrentLayoutRef()
            return true
        end)
    end)
    widget.newPreset:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -58)
    widget.renamePreset = ActionButton(general, "Rename", function()
        PresetDialog(widget, "Rename this shared preset.", presetName, function(name)
            local valid, err = ns.PresetName(name, selectedPresetId)
            if not valid then return false, err end
            presetName = valid
            return true
        end)
    end)
    widget.renamePreset:SetPoint("TOPLEFT", general, "TOPLEFT", (CONTENT_W - 112) / 2, -58)
    widget.deletePreset = ActionButton(general, "Delete", function()
        local id = selectedPresetId
        if not id then return end
        PresetDialog(widget, 'Delete "' .. presetName .. '" for all characters? They will keep their last settings.', nil, function()
            if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
            ns.DeletePreset(id)
            LoadSavedDraft()
            if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
            if ns.ApplyAll then ns.ApplyAll() end
            return true
        end)
    end)
    widget.deletePreset:SetPoint("TOPRIGHT", general, "TOPRIGHT", 0, -58)
    widget.layoutHeader = Section(general, "Layout",
        "A preset uses the selected Edit Mode layout. Choosing one previews it immediately; Save keeps it, while closing cancels the preview. Without a preset, Force QuietUI layout selects the bundled layout on enable and restores your previous layout on disable.")
    widget.layoutHeader:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -104)
    widget.layoutSelector = ActionButton(general, "Choose layout", function()
        if widget.presetMenu then widget.presetMenu:Hide() end
        local entries = {}
        for _, choice in ipairs(ns.LayoutChoices()) do
            local ref = choice.ref
            entries[#entries + 1] = { name = choice.name, selected = presetLayout and (
                ref.builtin and ref.builtin == presetLayout.builtin
                or not ref.builtin and ref.layoutName == presetLayout.layoutName
                    and ref.layoutType == presetLayout.layoutType), select = function()
                presetLayout = ns.Copy(ref)
                if ns.PreviewLayout then ns.PreviewLayout(presetLayout) end
                Paint()
            end }
        end
        if #entries == 0 then ns.Print("Edit Mode layouts are not available yet."); return end
        SelectMenu(widget, "layoutMenu", widget.layoutSelector, entries)
    end)
    widget.layoutSelector:SetSize(CONTENT_W, 24)
    widget.layoutSelector:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -128)
    widget.forceLayout = Choice(general, "Force QuietUI layout", function()
        draft.forceLayout = not draft.forceLayout
        Paint()
    end)
    widget.forceLayout:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -128)
    widget.presetHelp = Body(general, "Save updates the selected preset for every character. Without a preset, settings belong to this character.")
    widget.presetHelp:SetWidth(CONTENT_W)
    widget.presetHelp:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -174)

    local visible = widget.pages[2]
    widget.always = Section(visible, "Visibility",
        "Always visible keeps an element on screen. Only on hover overrides its automatic triggers; Glance and Edit Mode still reveal it. With both unchecked, its usual rules apply. Party and raid frames use their own exploration fade rules.")
    widget.always:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, 0)
    local alwaysHeader = ColumnLabel(visible, "Always visible")
    alwaysHeader:SetPoint("TOP", visible, "TOPLEFT", 380, 0)
    local hoverHeader = ColumnLabel(visible, "Only on hover")
    hoverHeader:SetPoint("TOP", visible, "TOPLEFT", 484, 0)
    widget.rows = {}
    local y = -20
    for _, info in ipairs(ROWS) do
        local key = info.key
        local row = CreateFrame("Frame", nil, visible)
        row:SetSize(CONTENT_W, 22)
        row.label = Body(row, info.label)
        row.label:SetWidth(308)
        row.label:SetPoint("LEFT", 2, 0)
        row.always = TargetBox(row, function()
            draft[key] = not draft[key]
            if draft[key] then draft.hoverOnly[key] = false end
            Paint()
        end)
        row.hover = TargetBox(row, function()
            if info.noHover then return end
            draft.hoverOnly[key] = not draft.hoverOnly[key]
            if draft.hoverOnly[key] then draft[key] = false end
            Paint()
        end)
        row.always:SetPoint("CENTER", row, "LEFT", 380, 0)
        row.hover:SetPoint("CENTER", row, "LEFT", 484, 0)
        row.key = key
        if info.noHover then
            row.hover:Disable()
            row.hover:SetAlpha(0.35)
            local width = row.label.GetStringWidth and row.label:GetStringWidth()
            row.label:SetWidth(type(width) == "number" and width or 180)
            row.help = Help(row, row.label, "Party and raid frames",
                "Uncheck Always visible to fade these frames while exploring.\nCombat, instances, hover, Glance and Edit Mode reveal them.")
        end
        row:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y)
        y = y - 24
        widget.rows[#widget.rows + 1] = row
    end

    local bars = widget.pages[3]
    widget.groupHeader = Section(bars, "Fade together",
        "Bars with the same Group number appear together on hover and fade together. Enemy and Friend keep an individual bar visible for a matching living target. Use the Groups tab to control visibility for the entire group.")
    widget.groupHeader:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, 0)
    widget.groupRows = {}
    y = -20
    for _, info in ipairs(ns.BAR_ROWS) do
        local id = info.id
        local row = Stepper(bars, info.label, function(sign)
            NudgeGroup(id, sign)
        end)
        row.id = id
        row.hostile = TargetBox(row, function()
            draft.hostile[id] = not draft.hostile[id]
            Paint()
        end)
        row.friendly = TargetBox(row, function()
            draft.friendly[id] = not draft.friendly[id]
            Paint()
        end)
        row.friendly:SetPoint("RIGHT", row.minus, "LEFT", -8, 0)
        row.hostile:SetPoint("RIGHT", row.friendly, "LEFT", -4, 0)
        -- Spans the stepper so the column title uses the button top, same as Enemy and Friend.
        row.step = CreateFrame("Frame", nil, row)
        row.step:SetPoint("TOPLEFT", row.minus, "TOPLEFT", 0, 0)
        row.step:SetPoint("BOTTOMRIGHT", row.plus, "BOTTOMRIGHT", 0, 0)
        row:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, y)
        y = y - 24
        widget.groupRows[#widget.groupRows + 1] = row
    end
    local first = widget.groupRows[1]
    widget.enemyHeader = ColumnLabel(bars, "Enemy")
    widget.friendHeader = ColumnLabel(bars, "Friend")
    widget.groupColumn = ColumnLabel(bars, "Group")
    -- The first row starts 20px under "Fade together", so these titles share that line.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 20)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 20)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 20)

    local groups = widget.pages[4]
    widget.visibilityHeader = Section(groups, "Group visibility",
        "Always visible keeps every member of the group on screen. Only on hover reveals the whole group when any member is hovered and overrides automatic triggers. Glance, Edit Mode, spell flyouts and cursor items still reveal it. Group modes override Enemy and Friend.")
    widget.visibilityHeader:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, 0)
    local groupAlwaysHeader = ColumnLabel(groups, "Always visible")
    groupAlwaysHeader:SetPoint("TOP", groups, "TOPLEFT", 380, 0)
    local groupHoverHeader = ColumnLabel(groups, "Only on hover")
    groupHoverHeader:SetPoint("TOP", groups, "TOPLEFT", 484, 0)
    widget.groupScroll = CreateFrame("ScrollFrame", nil, groups)
    widget.groupScroll:SetSize(CONTENT_W - 28, GROUP_VIEW_H)
    widget.groupScroll:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24)
    widget.groupContent = CreateFrame("Frame", nil, widget.groupScroll)
    widget.groupContent:SetSize(CONTENT_W - 28, 1)
    widget.groupScroll:SetScrollChild(widget.groupContent)
    local function ScrollGroups(delta)
        local max = math.max(0, widget.groupContent:GetHeight() - GROUP_VIEW_H)
        widget.groupScroll:SetVerticalScroll(math.max(0, math.min(max,
            widget.groupScroll:GetVerticalScroll() + delta)))
    end
    widget.groupScroll:EnableMouseWheel(true)
    widget.groupScroll:SetScript("OnMouseWheel", function(_, delta) ScrollGroups(-delta * 44) end)
    widget.groupUp = Mini(groups, "^", function() ScrollGroups(-44) end)
    widget.groupUp:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24)
    widget.groupDown = Mini(groups, "v", function() ScrollGroups(44) end)
    widget.groupDown:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24 - GROUP_VIEW_H + 22)
    widget.visibilityRows = {}
    for group = 1, #ns.BAR_ROWS do
        local id = group
        local row = CreateFrame("Frame", nil, widget.groupContent)
        row:SetSize(CONTENT_W - 28, 44)
        row.label = Section(row, "Group " .. id)
        row.label:SetPoint("TOPLEFT", 2, -2)
        row.members = Body(row, "")
        row.members:SetWidth(308)
        row.members:SetPoint("TOPLEFT", 2, -18)
        row.always = TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "always" and "always" or nil
            Paint()
        end)
        row.hover = TargetBox(row, function()
            draft.groupVisibility[id] = draft.groupVisibility[id] ~= "hover" and "hover" or nil
            Paint()
        end)
        row.always:SetPoint("CENTER", row, "TOPLEFT", 380, -16)
        row.hover:SetPoint("CENTER", row, "TOPLEFT", 484, -16)
        widget.visibilityRows[group] = row
    end
    local help = Body(groups, "Both unchecked: usual rules. Glance and Edit Mode still show hover-only frames.")
    help:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24 - GROUP_VIEW_H - 10)

    local player = widget.pages[5]
    widget.player = Section(player, "Player frame",
        "Control the player portrait and pet, and whether buffs follow their visibility. Choose Health or Resource and a whole percentage from 1 to 100 to show them below that threshold; empty ignores it. The default is Health below 70%. Resource means mana, focus or energy. Combat and instances still show them regardless of these fields. Death or ghost form hides only the player portrait, except during Glance or Edit Mode; the pet and buffs keep their usual rules. Always show debuffs keeps debuffs visible independently. Require a living target fades the player, pet and target frames for a dead target, except in Edit Mode. The selected percentage threshold still shows the player and pet, but not the dead target.")
    widget.player:SetPoint("TOPLEFT", player, "TOPLEFT", 0, 0)
    widget.playerRow = Choice(player, "Player frame", function()
        draft.player = not draft.player
        Paint()
    end)
    widget.playerRow:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -20)
    widget.playerThresholdKind = Stepper(player, "Show below", function()
        draft.playerThresholdKind = draft.playerThresholdKind == "health" and "resource" or "health"
        Paint()
    end)
    widget.playerThresholdKind:SetSize(240, 22)
    widget.playerThresholdKind:SetPoint("TOPLEFT", player, "TOPLEFT", 24, -50)
    widget.playerThresholdKind.value:SetWidth(92)
    widget.playerThresholdPercent = PercentField(player, "%", "playerThresholdPercent")
    widget.playerThresholdPercent:SetSize(72, 22)
    widget.playerThresholdPercent:SetPoint("TOPLEFT", widget.playerThresholdKind, "TOPRIGHT", 12, 0)
    widget.playerThresholdPercent.edit:SetSize(52, 22)
    widget.playerThresholdPercent.edit:ClearAllPoints()
    widget.playerThresholdPercent.edit:SetPoint("LEFT", 0, 0)
    widget.playerThresholdPercent.label:ClearAllPoints()
    widget.playerThresholdPercent.label:SetPoint("LEFT", widget.playerThresholdPercent.edit, "RIGHT", 4, 0)
    widget.groupAuras = Choice(player, "Group buffs and debuffs with player frame", function()
        draft.groupAuras = not draft.groupAuras
        Paint()
    end)
    widget.groupAuras:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -84)
    widget.requireLivingTarget = Choice(player, "Require a living target for player and target frames", function()
        draft.requireLivingTarget = not draft.requireLivingTarget
        Paint()
    end)
    widget.requireLivingTarget:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -112)
    widget.alwaysShowDebuffs = Choice(player, "Always show debuffs", function()
        draft.alwaysShowDebuffs = not draft.alwaysShowDebuffs
        Paint()
    end)
    widget.alwaysShowDebuffs:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -140)
    widget.rangeHeader = Section(player, "Range",
        "Adds a green indicator to the current target's nameplate health bar while in range. Always visible bar groups do not block it. Choose 10 yards, 28 yards or Spell. An empty spell field uses the longest matching spell on Bar 1.")
    widget.rangeHeader:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -178)
    widget.range = Choice(player, "In range", function()
        draft.range = not draft.range
        Paint()
    end)
    widget.range:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -200)
    widget.rangeYards = Stepper(player, "Within", function(sign)
        NudgeRangeYards(sign)
    end)
    widget.rangeYards:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -224)
    widget.rangeYards.value:SetWidth(92)
    widget.rangeKind = Stepper(player, "Who", function()
        NudgeRangeKind()
    end)
    widget.rangeKind:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -248)
    widget.rangeKind.value:SetWidth(92)
    widget.rangeSpell = SpellField(player)
    widget.rangeSpell:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -272)

    local chat = widget.pages[6]
    widget.chatHeader = Section(chat, "Chat",
        "Modern chat replaces the chat chrome with fading message bubbles. Fade after controls how long new lines remain visible; 0 keeps them. Hover and scrolling reveal older messages. Turning Modern chat off restores the original chat.")
    widget.chatHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
    widget.chat = Choice(chat, "Modern chat", function()
        draft.chat = not draft.chat
        Paint()
    end)
    widget.chat:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -18)
    widget.fade = Stepper(chat, "Fade after", function(sign)
        NudgeFade(sign * 5)
    end)
    widget.fade:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -42)
    widget.questHeader = Section(chat, "Quests",
        "Shows the quest you just accepted, changed, or completed at the top of the quest area for a few seconds. The rest of the tracker stays hidden, and WoW's center-screen quest text stays hidden while this is on.")
    widget.questHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -88)
    widget.questNotice = Choice(chat, "Quest updates", function()
        draft.questNotice = not draft.questNotice
        Paint()
    end)
    widget.questNotice:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -106)
    widget.questNoticeSize = Stepper(chat, "Text size", function(sign)
        NudgeNoticeSize(sign)
    end)
    widget.questNoticeSize:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -130)
    widget.questNoticeSize.value:SetWidth(72)
    widget.highlightHeader = Section(chat, "Highlights",
        "The object the game picks for the Interact key glows: herbs green, ore gold, interact objects white. Set that key in Key Bindings as Interact With Target. Interact objects includes anything with the gear icon, not just quest objects. QuietUI widens soft targeting, hides the highlighted icon and any icon you had turned off, and restores your settings when turned off.")
    widget.highlightHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -162)
    widget.highlightNote = Body(chat, "Turns on soft targeting for the Interact key, so nearby NPCs show their names.")
    widget.highlightNote:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -180)
    local highlightChoices = {
        { key = "highlightHerb", label = "Herbs" },
        { key = "highlightOre", label = "Ore" },
        { key = "highlightQuest", label = "Interact objects" },
    }
    for i, choice in ipairs(highlightChoices) do
        local button = Choice(chat, choice.label, function()
            draft[choice.key] = not draft[choice.key]
            Paint()
        end)
        button:SetWidth(120)
        button:SetPoint("TOPLEFT", chat, "TOPLEFT", (i - 1) * 124, -196)
        widget[choice.key] = button
    end
    widget.questMobsHeader = Section(chat, "Quest mobs",
        "A gold exclamation mark shows left of the nameplate of mobs you need to kill for a quest, and a pouch for mobs that drop a quest item. Only mobs you can attack are marked, and the icon disappears once the objective is complete.")
    widget.questMobsHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -228)
    widget.questMobs = Choice(chat, "Quest mobs", function()
        draft.questMobs = not draft.questMobs
        Paint()
    end)
    widget.questMobs:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -246)
    widget.parchmentHeader = Section(chat, "Parchment windows",
        "Quest, NPC dialog and book windows show as clean parchment with their buttons inside. Off by default.")
    widget.parchmentHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -278)
    widget.parchment = Choice(chat, "Parchment windows", function()
        draft.parchment = not draft.parchment
        Paint()
    end)
    widget.parchment:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -296)

    local info = widget.pages[7]
    widget.about = Section(info, "About")
    widget.about:SetPoint("TOPLEFT", info, "TOPLEFT", 0, 0)
    widget.aboutBody = Body(info, "While you explore, fewer frames stay on screen. They come back when you need them: talking to someone, a quest, a dungeon, or PvP.")
    widget.aboutBody:SetPoint("TOPLEFT", widget.about, "BOTTOMLEFT", 0, -4)
    widget.glanceHeader = Section(info, "Glance",
        "Press the Glance binding or use /quiet glance to reveal the hidden HUD, including hover-only elements. Press again to return to the usual visibility rules. Chat is unchanged and Glance is not saved.")
    widget.glanceHeader:SetPoint("TOPLEFT", widget.aboutBody, "BOTTOMLEFT", 0, -12)
    widget.glanceBody = Body(info, "Press ` to show what has faded. Press it again and the choices on the other tabs apply. Change the key under QuietUI in Key Bindings. You can also use /quiet glance in a macro for your controller.")
    widget.glanceBody:SetPoint("TOPLEFT", widget.glanceHeader, "BOTTOMLEFT", 0, -4)

    widget.reset = ActionButton(widget, "Reset default", function()
        if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
        ns.ActivatePreset(nil, {})
        LoadSavedDraft()
        Paint()
        if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
        if ns.ApplyAll then ns.ApplyAll() end
    end)
    widget.import = ActionButton(widget, "Import layout", function()
        ns.ForceLayout()
    end)
    widget.save = ActionButton(widget, "Save", function()
        Write()
    end)
    widget.reset:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.import:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.save:SetFrameLevel(widget:GetFrameLevel() + 20)

    widget.reset:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    widget.import:SetPoint("BOTTOM", 0, metrics.buttonY)
    widget.save:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    widget:SetScript("OnHide", function()
        if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
        for _, key in ipairs({ "presetMenu", "layoutMenu", "presetDialog" }) do
            if widget[key] then widget[key]:Hide() end
        end
    end)
    ShowPage(widget, "general")
    return widget
end

function ns.RefreshSetup()
    if not frame or not frame:IsShown() then return end
    for _, key in ipairs({ "presetMenu", "layoutMenu", "presetDialog" }) do
        if frame[key] then frame[key]:Hide() end
    end
    LoadSavedDraft()
    Paint()
end

function ns.ShowSetup()
    if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
    frame = frame or CreateSetup()
    LoadSavedDraft()
    if frame._quietPortrait then
        ApplyPortrait(frame)
    end
    frame:Show()
    ns.RaiseDialog(frame)
    ShowPage(frame, frame.page or "general")
end

------------------------------------------------------------------------------
-- Minimap button. Unnamed, parented to Minimap, so the fade walk never sees it.
------------------------------------------------------------------------------

local function MinimapDegrees()
    local n = ns.DB().minimap
    if type(n) ~= "number" or n ~= n then return MINIMAP_ANGLE end
    n = n % 360
    if n < 0 then n = n + 360 end
    return n
end

local function PlaceMinimap(button)
    local map = Minimap
    if not map or not button then return end
    local rad = math.rad(MinimapDegrees())
    local w = map:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = 140 end
    local radius = w / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function CursorDegrees(map)
    if type(GetCursorPosition) ~= "function" or not map.GetCenter then return nil end
    local scale = map.GetEffectiveScale and map:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    local mx, my = map:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(mx) ~= "number" or type(my) ~= "number" then
        return nil
    end
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function ApplyGear(icon)
    if icon.SetAtlas then
        local ok, result = pcall(icon.SetAtlas, icon, "mechagon-projects")
        if ok and result then return end
    end
    if not icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CreateMinimap()
    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(31, 31)
    local level = Minimap:GetFrameLevel()
    button:SetFrameLevel((type(level) == "number" and level or 0) + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    ApplyGear(icon)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnDragStart", function(self)
        self._moved = true
        self:SetScript("OnUpdate", function(owner)
            local angle = CursorDegrees(Minimap)
            if not angle then return end
            ns.DB().minimap = angle
            PlaceMinimap(owner)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnMouseUp", function(self, click)
        if self._moved then
            self._moved = false
            return
        end
        if click == "LeftButton" then
            if frame and frame:IsShown() then
                frame:Hide()
            else
                ns.ShowSetup()
            end
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuietUI", 1, 1, 1)
        GameTooltip:AddLine("Left click: toggle setup", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return button
end

function ns.EnsureMinimap()
    if not Minimap then return end
    if not minimapHooked and Minimap.HookScript then
        minimapHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            if minimapButton then PlaceMinimap(minimapButton) end
        end)
    end
    if minimapButton then
        PlaceMinimap(minimapButton)
        minimapButton:Show()
        return
    end
    minimapButton = CreateMinimap()
    PlaceMinimap(minimapButton)
end
