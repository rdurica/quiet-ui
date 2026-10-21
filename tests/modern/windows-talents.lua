-- The Forever 12.0 talents page, shaped after a frame dump of the client: PlayerSpellsFrame.TalentsFrame with the
-- ornate Background, ClassBackground tree art, BackgroundBorder, horizontal and vertical dividers, a
-- ClassCurrencyDisplay box, a SearchOptionsDropdown with a gold Arrow, one spec header per tree (Icon, Name,
-- MainRing, TextBackground, count Text, Divider) and talent buttons under ButtonsParent (Shadow, Icon, StateBorder
-- whose atlas tells the state, StateBorderHover, BorderSheen).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Talents\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function atlas(texture, name)
    function texture:SetAtlas(value) self._atlas = value end
    function texture:GetAtlas() return self._atlas end
    texture:SetAtlas(name)
    return texture
end

local function node(parent, list, state)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(40, 40)
    button.Shadow = art(button, list, "NodeShadow", "BACKGROUND")
    button.Icon = button:CreateTexture(nil, "BORDER")
    button.Icon:SetTexture("Interface\\Icons\\Frostbolt")
    button.Icon:SetTexCoord(0, 1, 0, 1)
    button.StateBorder = atlas(art(button, list, "NodeState"), "talents-node-square-" .. state)
    button.StateBorderHover = art(button, list, "NodeHover")
    button.BorderSheen = art(button, list, "NodeSheen")
    return button
end

local function spec(parent, list, name)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(48, 48)
    frame.Icon = frame:CreateTexture(nil, "BORDER")
    frame.Icon:SetTexture("Interface\\Icons\\" .. name)
    frame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.Name = text(frame, name)
    frame.MainRing = art(frame, list, "MainRing", "OVERLAY")
    frame.TextBackground = art(frame, list, "RingBox", "OVERLAY")
    frame.Text = text(frame, "0")
    frame.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    frame.Divider = art(frame, list, "SmallDivider", "OVERLAY")
    return frame
end

local function talents()
    local list = {}
    local frame = R.window("PlayerSpellsFrame", { inset = false })
    PlayerSpellsFrame = frame
    local page = CreateFrame("Frame", nil, frame)
    frame.TalentsFrame = page
    page.Background = art(page, list, "Background", "BACKGROUND")
    page.ClassBackground = art(page, nil, "TalentTree", "BACKGROUND")
    for _, key in ipairs({ "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight",
        "DividerVerticalLeft", "DividerVerticalRight" }) do
        page[key] = art(page, list, key, "OVERLAY")
    end
    page.ClassCurrencyDisplay = CreateFrame("Frame", nil, page)
    page.ClassCurrencyDisplay.Border = art(page.ClassCurrencyDisplay, list, "SquareBox")
    page.SearchOptionsDropdown = CreateFrame("Button", nil, page)
    page.SearchOptionsDropdown.Arrow = art(page.SearchOptionsDropdown, list, "DropdownButton", "OVERLAY")
    page.ButtonsParent = CreateFrame("Frame", nil, page)
    function page:LoadTalentTreeInternal() end
    return {
        frame = frame, page = page, art = list,
        spec = spec(page, list, "Frost"),
        maxed = node(page.ButtonsParent, list, "yellow"),
        partial = node(page.ButtonsParent, list, "green"),
        locked = node(page.ButtonsParent, list, "locked"),
    }
end

local function visibleArt(c, list)
    local names = {}
    for _, texture in ipairs(list or c.art) do
        if not R.invisible(texture, c.frame) then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

local function bordered(ns, button, key)
    return B.same(B.border(button), ns.Modern.Theme()[key])
end

h.test("Windows flattens the talents page, frames talents by state, keeps the tree art and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = talents()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.eq(visibleArt(c), "", "backdrop, frames, dividers, rings, boxes, gold arrow and talent art are all hidden")
    A.ok(not R.invisible(c.page.ClassBackground, c.frame), "talent tree art is content and stays")
    A.ok(L.zoomed(c.maxed.Icon) and L.zoomed(c.spec.Icon), "talent and spec icons are square-cropped")
    A.ok(not R.invisible(c.maxed.Icon, c.frame), "talent icon stays")
    A.ok(bordered(ns, c.maxed, "accent"), "a maxed talent gets the accent border")
    A.ok(bordered(ns, c.locked, "wellEdge"), "a locked talent gets the quiet border")
    A.ok(B.border(c.partial) ~= nil and not bordered(ns, c.partial, "accent"), "a partly spent talent has its own colour")
    A.ok(not R.invisible(c.spec.Name, c.frame) and not R.invisible(c.spec.Text, c.frame), "tree name and count stay")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "talents page restores exactly")
end)

h.test("Windows follows a talent's state and skins talents of a newly loaded tree", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = talents()
    W.enable(ns)
    c.partial.StateBorder:SetAtlas("talents-node-square-yellow")
    A.ok(bordered(ns, c.partial, "accent"), "the border follows Blizzard's new state art")
    local list = {}
    local late = node(c.page.ButtonsParent, list, "gray")
    c.page:LoadTalentTreeInternal()
    A.eq(visibleArt(c, list), "", "a talent acquired after apply loses its art when the tree loads")
    A.ok(bordered(ns, late, "border"), "an open talent gets the theme border")
    ns.Modern.Restore()
    local after = node(c.page.ButtonsParent, {}, "gray")
    c.page:LoadTalentTreeInternal()
    A.ok(not R.invisible(after.Shadow, c.frame), "the tree hook does nothing while the area is off")
end)
