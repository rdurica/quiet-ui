-- Reputation, Skills and Currency panes of the Forever 12.0 character window, shaped after a frame dump of the client:
-- ReputationFrame / SkillsFrame hold a ScrollBox whose ScrollTarget has pooled header buttons (unnamed
-- common-button-list-collapseExpand art and a StateIcon) and rows with Content.ReputationBar / Content.SkillsBar
-- (unnamed common-stat-bar-BG frame art and a Fill). Keyless ScrollBox children carry long divider lines, and the
-- detail pane has a Divider and a StandingBar / RankBar.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\CharacterInfo\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function bar(parent, list, key, name)
    local status = CreateFrame("StatusBar", nil, parent)
    parent[key] = status
    status:SetSize(180, 18)
    art(status, list, name .. "BarBG", "BACKGROUND")
    status.Fill = art(status, nil, name .. "BarFill", "BORDER")
    status.Fill:SetSize(90, 15)
    status.Text = status:CreateFontString(nil, "OVERLAY")
    status.Text:SetText("36 / 75")
    return status
end

local function header(target, list, name)
    local button = CreateFrame("Button", nil, target)
    button:SetSize(400, 22)
    art(button, list, name .. "HeaderBanner", "BACKGROUND")
    art(button, list, name .. "HeaderHover", "HIGHLIGHT")
    button.StateIcon = art(button, nil, "Minus", "BORDER")
    button.Name = button:CreateFontString(nil, "OVERLAY")
    button.Name:SetText(name)
    button.Name:SetTextColor(1, 0.82, 0, 1)
    return button
end

local function row(target, list, key, name)
    local button = CreateFrame("Button", nil, target)
    button.Content = CreateFrame("Frame", nil, button)
    button.Content.Name = button.Content:CreateFontString(nil, "OVERLAY")
    button.Content.Name:SetText(name)
    bar(button.Content, list, key, name)
    return button
end

local function pane(parent, list, name, key, detailKey, detailBar)
    local frame = CreateFrame("Frame", name, parent)
    _G[name] = frame
    frame.ScrollBox = CreateFrame("Frame", nil, frame)
    frame.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, frame.ScrollBox)
    function frame.ScrollBox:Update() end
    art(CreateFrame("Frame", nil, frame.ScrollBox), list, name .. "ScrollLine", "OVERLAY")
    local p = {
        frame = frame,
        header = header(frame.ScrollBox.ScrollTarget, list, name),
        row = row(frame.ScrollBox.ScrollTarget, list, key, name),
    }
    frame.ScrollBar = CreateFrame("Frame", nil, frame)
    frame.ScrollBar.Track = CreateFrame("Frame", nil, frame.ScrollBar)
    art(frame.ScrollBar.Track, list, name .. "Track")
    local detail = CreateFrame("Frame", nil, frame)
    frame[detailKey] = detail
    detail.Divider = art(detail, list, name .. "Divider", "BORDER")
    p.detailBar = bar(detail, list, detailBar, name .. "Detail")
    return p
end

local function character()
    local list = {}
    local frame = R.window("CharacterFrame")
    CharacterFrame = frame
    return {
        frame = frame, art = list,
        rep = pane(frame, list, "ReputationFrame", "ReputationBar", "ReputationDetailFrame", "StandingBar"),
        skills = pane(frame, list, "SkillsFrame", "SkillsBar", "SkillDetailFrame", "RankBar"),
    }
end

local function visibleArt(c)
    local names = {}
    for _, texture in ipairs(c.art) do
        if not R.invisible(texture, c.frame) then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

h.test("Windows flattens Reputation and Skills headers and bars, keeps fills and texts, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = character()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.eq(visibleArt(c), "", "banners, bar frames, dividers and scroll tracks are all hidden")
    for _, p in ipairs({ c.rep, c.skills }) do
        local name = p.frame:GetName()
        local bars = { p.row.Content.ReputationBar or p.row.Content.SkillsBar, p.detailBar }
        for _, status in ipairs(bars) do
            local well, track = ns.Modern.Theme().track, false
            for _, region in ipairs(status._regions) do
                if region._shown and region._color then
                    track = track or (region._color[1] == well[1] and region._h == 15)
                    A.falsy(region._h == 1 or region._w == 1, name .. " bar has no border")
                end
            end
            A.ok(track, name .. " bar sits on a dark track as tall as its fill")
            A.ok(not R.invisible(status.Fill, c.frame), name .. " bar fill stays")
            A.ok(not R.invisible(status.Text, c.frame), name .. " bar text stays")
        end
        A.ok(R.invisible(p.header.StateIcon, c.frame), name .. " header holds Blizzard's collapse icon for the sign")
        A.ok(not R.invisible(p.header.Name, c.frame), name .. " header keeps its title")
    end
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Reputation and Skills restore exactly")
end)

h.test("Windows skins pooled Reputation rows acquired after apply on the next list update", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = character()
    W.enable(ns)
    local list = {}
    local late = row(c.rep.frame.ScrollBox.ScrollTarget, list, "ReputationBar", "Late")
    c.rep.frame.ScrollBox:Update()
    A.ok(R.invisible(list[1], c.frame), "the new row's bar frame art is hidden")
    local well, track = ns.Modern.Theme().track, false
    for _, region in ipairs(late.Content.ReputationBar._regions) do
        track = track or (region._shown and region._color and region._color[1] == well[1]) or false
    end
    A.ok(track, "the new row's bar gets the dark track")
end)

-- TokenFrame (Currency) and StatisticsFrame: the same pooled headers; rows hold texts (and a currency icon) in Content,
-- with no bar.
h.test("Windows turns Reputation, Currency and Statistics headers into section strips, keeps their rows, and restores them", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = character()
    local list = {}
    local token = CreateFrame("Frame", "TokenFrame", c.frame)
    TokenFrame = token
    token.ScrollBox = CreateFrame("Frame", nil, token)
    token.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, token.ScrollBox)
    local head = header(token.ScrollBox.ScrollTarget, list, "PvP")
    local currency = CreateFrame("Button", nil, token.ScrollBox.ScrollTarget)
    currency.Content = CreateFrame("Frame", nil, currency)
    currency.Content.CurrencyIcon = currency.Content:CreateTexture(nil, "BORDER")
    currency.Content.CurrencyIcon:SetTexture("Interface\\Icons\\Honor")
    local stats = CreateFrame("Frame", "StatisticsFrame", c.frame)
    StatisticsFrame = stats
    stats.ScrollBox = CreateFrame("Frame", nil, stats)
    stats.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, stats.ScrollBox)
    function stats.ScrollBox:Update() end
    local statHead = header(stats.ScrollBox.ScrollTarget, list, "Combat")
    local before = L.snapshot(R.all(c.frame))
    local strip = ns.Modern.Theme().strip
    local function striped(button)
        for _, region in ipairs(button._regions) do
            if region._shown ~= false and (region._alpha or 1) > 0 and region._color and region._color[1] == strip[1]
                and region._h == 22 then
                return true
            end
        end
        return false
    end
    W.enable(ns)
    A.ok(striped(head), "a currency header is a section strip")
    A.ok(striped(c.rep.header), "a reputation header is a section strip")
    A.ok(striped(statHead), "a statistics header is a section strip")
    stats.ScrollBox:Update()
    A.ok(striped(statHead), "the strip survives the list skinning the pooled header again")
    A.ok(R.invisible(list[1], c.frame), "the currency header banner is held")
    A.ok(R.invisible(head.StateIcon, c.frame), "Blizzard's collapse icon gives way to the sign")
    local text = ns.Modern.Theme().text
    A.deep({ head.Name:GetTextColor() }, { text[1], text[2], text[3], 1 }, "the header title is light")
    A.ok(not R.invisible(currency.Content.CurrencyIcon, c.frame), "the currency icon stays")
    ns.Modern.Restore()
    A.ok(not striped(head), "Restore removes the strip")
    A.deep({ head.Name:GetTextColor() }, { 1, 0.82, 0, 1 }, "Restore puts back the gold title")
    A.deep(L.diff(before), {}, "Currency restores exactly")
end)

-- PVPRankFrame.DetailFrame (and SkillDetailFrame) build Content from title banners (Background UI-Character-Info-Title,
-- Label) and icon rows (IconSlot UI-Character-Info-GearSlot, Icon, Label), laid out again for every selection.
h.test("Windows turns detail pane banners into section strips and reward icons into bordered squares", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = character()
    local list = {}
    local pvp = CreateFrame("Frame", "PVPRankFrame", c.frame)
    PVPRankFrame = pvp
    pvp.DetailFrame = CreateFrame("Frame", nil, pvp)
    local content = CreateFrame("Frame", nil, pvp.DetailFrame)
    pvp.DetailFrame.Content = content
    function content:Layout() end
    local function banner(text)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(195, 40)
        row.Background = art(row, list, "Title", "BACKGROUND")
        row.Label = row:CreateFontString(nil, "OVERLAY")
        row.Label:SetText(text)
        return row
    end
    local title = banner("Next Rewards at Rank 1")
    local reward = CreateFrame("Frame", nil, content)
    reward.IconSlot = art(reward, list, "GearSlot", "BACKGROUND")
    reward.Icon = reward:CreateTexture(nil, "ARTWORK")
    reward.Icon:SetTexture("Interface\\Icons\\Tabard")
    reward.Icon:SetTexCoord(0, 1, 0, 1)
    local theme = ns.Modern.Theme()
    local function striped(row)
        for _, region in ipairs(row._regions) do
            if region._shown and (region._alpha or 1) > 0 and region._color and region._color[1] == theme.strip[1]
                and region._h == 22 then return true end
        end
        return false
    end
    local function edges(row)
        local count = 0
        for _, region in ipairs(row._regions) do
            if region._shown and region._color and region._color[1] == theme.border[1] then count = count + 1 end
        end
        return count
    end
    W.enable(ns)
    A.ok(R.invisible(title.Background, c.frame), "the ornate banner is held")
    A.ok(striped(title), "a banner becomes a section strip")
    A.ok(R.invisible(reward.IconSlot, c.frame), "the ornate gear slot is held")
    A.ok(L.zoomed(reward.Icon), "the reward icon is cropped square")
    A.eq(edges(reward), 4, "with a thin border")
    local late = banner("Equal-Level Enemy")
    content:Layout()
    A.ok(striped(late), "a banner laid out for a new selection is a strip too")
    ns.Modern.Restore()
    A.ok(not striped(title) and edges(reward) == 0, "Restore removes strips and borders")
end)

-- Expand / collapse signs: a header StateIcon (common-button-list-plus / -minus) and a statistics sub-header's
-- ToggleCollapseButton (Campaign_HeaderIcon_Open / _Closed art) become an accent plus or minus.
-- A texture that remembers its atlas, as the client's does.
local function atlased(texture)
    function texture:SetAtlas(atlas) self._atlas = atlas end
    function texture:GetAtlas() return self._atlas end
    return texture
end

h.test("Windows draws accent plus and minus signs for expand icons, follows Blizzard and leaves unknown art", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = character()
    local stats = CreateFrame("Frame", "StatisticsFrame", c.frame)
    StatisticsFrame = stats
    stats.ScrollBox = CreateFrame("Frame", nil, stats)
    stats.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, stats.ScrollBox)
    function stats.ScrollBox:Update() end
    local head = header(stats.ScrollBox.ScrollTarget, {}, "Combat")
    atlased(head.StateIcon):SetAtlas("common-button-list-plus")
    local sub = CreateFrame("Button", nil, stats.ScrollBox.ScrollTarget)
    local toggle = CreateFrame("Button", nil, sub)
    sub.ToggleCollapseButton = toggle
    local open = atlased(toggle:CreateTexture(nil, "ARTWORK"))
    open:SetAtlas("Campaign_HeaderIcon_Open")
    local odd = CreateFrame("Button", nil, stats.ScrollBox.ScrollTarget)
    odd.ToggleCollapseButton = CreateFrame("Button", nil, odd)
    local unknown = odd.ToggleCollapseButton:CreateTexture(nil, "ARTWORK")
    unknown:SetTexture(130838)
    unknown:SetAlpha(1)
    local accent = ns.Modern.Theme().accent
    -- Shown accent strokes on `frame`: 1 is a minus, 2 a plus.
    local function sign(frame)
        local count = 0
        for _, region in ipairs(frame._regions) do
            local col = region._color
            if region._shown and (region._alpha or 1) > 0 and col and col[1] == accent[1]
                and (region._w == 2 or region._h == 2)
                and (region._w == 10 or region._h == 10) then count = count + 1 end
        end
        return count
    end
    W.enable(ns)
    A.eq(sign(head), 2, "a collapsed header shows a plus")
    A.eq(sign(toggle), 1, "an open sub-header shows a minus")
    stats.ScrollBox:Update()
    A.eq(sign(toggle), 1, "the sign survives the list skinning the pooled row again")
    A.eq(sign(head), 2, "on a header too")
    A.ok(R.invisible(open, c.frame), "Blizzard's toggle art is held")
    head.StateIcon:SetAtlas("common-button-list-minus")
    A.eq(sign(head), 1, "the sign follows Blizzard's new atlas")
    open:SetAtlas("Campaign_HeaderIcon_Closed")
    A.eq(sign(toggle), 2, "and the toggle's")
    A.eq(sign(odd.ToggleCollapseButton), 0, "art whose name tells no state gets no sign")
    A.alpha(unknown, 1, "and stays Blizzard's")
    ns.Modern.Restore()
    A.eq(sign(head) + sign(toggle), 0, "Restore removes the signs")
    A.alpha(open, 1, "and gives back Blizzard's art")
end)
