local _, ns = ...

-- Settings getters: missing values mean the default, only explicit values change it.

function ns.Settings.HoverSetting(settings, name)
    local hover = settings.hoverOnly
    local value
    if type(hover) == "table" then value = hover[name] end
    if type(value) == "boolean" then return value end
    -- XP defaults to hover unless an existing Always visible choice keeps it up.
    return name == "xp" and not (type(settings.visible) == "table" and settings.visible.xp == true)
end

function ns.Settings.OnlyOnHover(name)
    return ns.Settings.HoverSetting(ns.Settings.Effective(), name)
end

function ns.Settings.VisibilityShow(name, usual, hovered)
    if ns.World.InEditMode() or ns.Glance.Active() then return true end
    if ns.Settings.OnlyOnHover(name) then return hovered and true or false end
    return ns.Settings.Pinned(name) or usual or hovered or false
end

function ns.Settings.AutoHideParty()
    return ns.Settings.Effective().autoHideParty == true
end

function ns.Settings.Pinned(name)
    local visible = ns.Settings.Effective().visible
    return type(visible) == "table" and visible[name] and true or false
end

-- Missing means on. Only an explicit "resource" keeps the portrait for edit mode.
function ns.Settings.PlayerStyle()
    if ns.Settings.Effective().player == "resource" then return "resource" end
    return "classic"
end

function ns.Settings.PlayerThreshold()
    local settings = ns.Settings.Effective()
    local kind = settings.playerThresholdKind == "resource" and "resource" or "health"
    local value = settings.playerThresholdPercent
    if value == false then return kind, nil end
    if type(value) == "number" and not ns.IsSecret(value)
        and value >= 1 and value <= 100 and value == math.floor(value) then return kind, value end
    return kind, 70
end

function ns.Settings.RequireLivingTarget()
    return ns.Settings.Effective().requireLivingTarget == true
end

-- Missing means on. Only an explicit false leaves buffs on their own.
function ns.Settings.GroupAuras()
    return ns.Settings.Effective().groupAuras ~= false
end

-- Missing means on. Only an explicit false lets debuffs fade.
function ns.Settings.AlwaysShowDebuffs()
    return ns.Settings.Effective().alwaysShowDebuffs ~= false
end

-- Missing means on. Only an explicit false turns quest update notices off.
function ns.Settings.QuestNoticeEnabled()
    return ns.Settings.Effective().questNotice ~= false
end

-- Missing means on. Only an explicit false turns quest mob icons off.
function ns.Settings.QuestMobs()
    return ns.Settings.Effective().questMobs ~= false
end

-- Missing means all off. Only explicit true values turn a category on.
function ns.Settings.Highlights()
    local stored = ns.Settings.Effective().highlights
    if type(stored) ~= "table" then stored = {} end
    return { herb = stored.herb == true, ore = stored.ore == true, quest = stored.quest == true }
end

-- Missing means the tracker size. Only "smaller" and "larger" change it.
function ns.Settings.QuestNoticeSize()
    local size = ns.Settings.Effective().questNoticeSize
    if size == "smaller" or size == "larger" then return size end
    return "default"
end

-- Missing means below the chat. Only "top" keeps Blizzard's tabs above it.
function ns.Settings.ChatTabs()
    local tabs = ns.Settings.Effective().chatTabs
    if tabs == "top" then return "top" end
    return "bottom"
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.Settings.ModernChat()
    return ns.Settings.Effective().chat ~= false
end

-- Lines sent from the chat input, oldest first. Kept per character, outside presets.
function ns.Settings.ChatHistory()
    local char = ns.Settings.CharDB()
    if type(char.chatHistory) ~= "table" then char.chatHistory = {} end
    return char.chatHistory
end

-- Missing means off. Only an explicit true selects the QuietUI layout when the addon turns on.
function ns.Settings.ForceQuietLayout()
    return (ns.Settings.ActivePreset and ns.Settings.ActivePreset()) ~= nil
        or ns.Settings.Effective().forceLayout == true
end

-- Seconds a line stays at the bottom. Missing means 10. 0 keeps the line.
function ns.Settings.ChatFade()
    local n = ns.Settings.Effective().chatFade
    if type(n) ~= "number" or n ~= n then return 10 end
    if n <= 0 then return 0 end
    n = math.floor(n)
    if n > 60 then n = 60 end
    return math.floor(n / 5) * 5
end

-- Missing means off. yards is 10, 28, or "spell". kind is "hostile" or "friendly".
-- spell is an optional name. Missing means the longest matching spell on bar 1.
function ns.Settings.Range()
    local range = ns.Settings.Effective().range
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
