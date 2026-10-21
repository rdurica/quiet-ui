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
        A.ok(not R.invisible(p.header.StateIcon, c.frame), name .. " header keeps its collapse icon")
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
    A.ok(not R.invisible(head.StateIcon, c.frame), "the collapse icon stays")
    local text = ns.Modern.Theme().text
    A.deep({ head.Name:GetTextColor() }, { text[1], text[2], text[3], 1 }, "the header title is light")
    A.ok(not R.invisible(currency.Content.CurrencyIcon, c.frame), "the currency icon stays")
    ns.Modern.Restore()
    A.ok(not striped(head), "Restore removes the strip")
    A.deep({ head.Name:GetTextColor() }, { 1, 0.82, 0, 1 }, "Restore puts back the gold title")
    A.deep(L.diff(before), {}, "Currency restores exactly")
end)
