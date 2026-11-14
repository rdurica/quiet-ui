-- The pooled rows of the friends list (group header and friend cards), their refill and the selection, for the
-- friends window fixture (tests/lib/modern-social.lua, whose key block lists the assumptions: selection is
-- LockHighlight / UnlockHighlight on the row, the header's Icon swaps minus / plus with SetAtlas).
local Rows = {}
local P  -- modern-shapes

function Rows.use(shapes) P = shapes end

Rows.texts = { "FriendName", "Name", "Level", "Class", "Location" }
local COLOURS = { FriendName = { 0.51, 0.77, 1 }, Name = { 1, 0.82, 0 }, Level = { 1, 1, 1 },
    Class = { 0.67, 0.83, 0.45 }, Location = { 0.49, 0.52, 0.54 } }

local function atlas(c, parent, list, name, layer)
    return P.texture(c, parent, list, name, layer or "ARTWORK", { atlas = true })
end

local function clickable(button)
    button.clicks = 0
    button:SetScript("OnClick", function() button.clicks = button.clicks + 1 end)
    return button
end

-- A tertiary square button (BattleNetMenuButton, a row's PartyButton): keyed plates answered by the getters, over
-- an icon that stays.
function Rows.square(c, parent, iconKey, iconAtlas)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(34, 34)
    button[iconKey] = atlas(c, button, "keep", iconAtlas, "OVERLAY")
    local art = P.buttonArt(c, button, { GetNormalTexture = "common-button-tertiary-square-normal",
        GetPushedTexture = "common-button-tertiary-square-pressed",
        GetHighlightTexture = "common-button-tertiary-square-normal" }, "art")
    button.NormalTexture, button.PushedTexture, button.HighlightTexture =
        art.GetNormalTexture, art.GetPushedTexture, art.GetHighlightTexture
    return clickable(button)
end

-- A group header row (common-button-list-collapseExpand): its art by the getters, a text and a CollapseButton whose
-- Icon swaps minus / plus. Blizzard's OnClick collapses it.
function Rows.header(c, target, label)
    local head = CreateFrame("Button", nil, target)
    head:SetSize(364.5, 24)
    head.lists = c
    local normal = atlas(c, head, "art", "common-button-list-collapseExpand", "ARTWORK")
    local highlight = atlas(c, head, "art", "common-button-list-collapseExpand", "HIGHLIGHT")
    head.GetNormalTexture = function() return normal end
    head.GetHighlightTexture = function() return highlight end
    head.ButtonText = P.text(c, head, label)
    local button = CreateFrame("Button", nil, head)
    head.CollapseButton = button
    button:SetSize(20, 20)
    button.Icon = atlas(c, button, "art", "common-button-list-minus", "ARTWORK")
    local hover = atlas(c, button, "art", "common-button-list-minus", "HIGHLIGHT")
    button.GetHighlightTexture = function() return hover end
    head.collapsed, head.clicks = false, 0
    local function toggle()
        head.clicks = head.clicks + 1
        head.collapsed = not head.collapsed
        local name = head.collapsed and "common-button-list-plus" or "common-button-list-minus"
        button.Icon:SetAtlas(name)
        hover:SetAtlas(name)
    end
    head:SetScript("OnClick", toggle)
    button:SetScript("OnClick", toggle)
    return head
end

-- A friend card (a Button): Background, the unkeyed `friends-card-selected` highlight, five texts in Blizzard's
-- colours, the presence icon, a PartyButton, and the holders. LockHighlight / UnlockHighlight mark the selection.
function Rows.row(c, target, data)
    local row = CreateFrame("Button", nil, target)
    row:SetSize(364.5, 70)
    row.lists = c
    row.Background = atlas(c, row, "art", data.online and "friends-card-battleNet" or "friends-card-disabled",
        "BACKGROUND")
    row.highlight = atlas(c, row, "art", "friends-card-selected", "HIGHLIGHT")
    row.GetHighlightTexture = function() return row.highlight end
    for _, key in ipairs(Rows.texts) do
        row[key] = P.text(c, row, data[key] or key)
        row[key]:SetTextColor(unpack(COLOURS[key]))
    end
    row.PresenceHolder = CreateFrame("Frame", nil, row)
    row.PresenceHolder.PresenceIcon = atlas(c, row.PresenceHolder, "keep", "friends-status-online", "OVERLAY")
    row.PartyButton = Rows.square(c, row, "ActionIcon", "friends-icon-friendsAvailable-dis")
    row.GameIconHolder = CreateFrame("Frame", nil, row)
    row.TextHolder = CreateFrame("Frame", nil, row)
    row.StateDisplay = CreateFrame("Frame", nil, row)
    row.StateDisplay:Hide()
    row.StateDisplay.FavoriteDisplay = CreateFrame("Frame", nil, row.StateDisplay)
    row.StateDisplay.FavoriteDisplay.Icon = atlas(c, row.StateDisplay.FavoriteDisplay, "keep", "friends-icon-favorites")
    function row:LockHighlight() self.locked = true end
    function row:UnlockHighlight() self.locked = false end
    return row
end

local function fill(row, data)
    row.Background:SetAtlas(data.online and "friends-card-battleNet" or "friends-card-disabled")
    for _, key in ipairs(Rows.texts) do row[key]:SetText(data[key] or key) end
    row:UnlockHighlight()
end

Rows.data = {
    { kind = "header", label = "Friends List 1/6" },
    { kind = "friend", FriendName = "Ks6", Name = "Mok Goll", Level = "Lvl 21", Class = "Hunter", Location = "The Barrens",
        online = true },
    { kind = "friend", FriendName = "Ks2", Name = "Aldrin", Level = "Lvl 12", Class = "Priest", Location = "Elwynn",
        online = false },
    { kind = "friend", FriendName = "Ks3", Name = "Brenna", Level = "Lvl 60", Class = "Mage", Location = "Orgrimmar",
        online = false },
}

-- The pooled refill: rows are reused in order and new ones created for the rest, then the ScrollBox updates (the
-- hook point Blizzard's list gives). Returns the lists of the new rows (`.rows` are the rows themselves).
function Rows.refill(f, data)
    local box = f.box
    local used = { header = 0, friend = 0 }
    local fresh = P.new()
    fresh.rows = {}
    for _, item in ipairs(data) do
        used[item.kind] = used[item.kind] + 1
        local row = f.pool[item.kind][used[item.kind]]
        if row then
            if item.kind == "friend" then fill(row, item) end
        else
            local own = P.new()
            row = item.kind == "header" and Rows.header(own, box.ScrollTarget, item.label)
                or Rows.row(own, box.ScrollTarget, item)
            f.pool[item.kind][used[item.kind]] = row
            fresh.rows[#fresh.rows + 1] = row
            for _, list in ipairs({ "art", "keep", "arrows" }) do
                for _, object in ipairs(own[list]) do fresh[list][#fresh[list] + 1] = object end
            end
        end
        row:Show()
    end
    for kind, rows in pairs(f.pool) do
        for index = used[kind] + 1, #rows do rows[index]:Hide() end
    end
    box:Update()
    return fresh
end

-- Blizzard marks the selected friend: the others are unlocked, this one locked.
function Rows.select(f, row)
    for _, other in ipairs(f.pool.friend) do other:UnlockHighlight() end
    if row then row:LockHighlight() end
end

return Rows
