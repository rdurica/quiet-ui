-- Checkboxes and scroll bar arrows inside skinned windows, shaped after a frame dump of the Forever 12.0 client:
-- the reputation detail checkboxes (checkbox-minimal box art, a checkmark, a Label) and the minimal scroll bar's
-- Back / Forward buttons with a single Texture.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function art(parent, list, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetAlpha(1)
    list[#list + 1] = texture
    return texture
end

local function checkbox(parent, list, label)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(26, 26)
    button.Label = button:CreateFontString(nil, "OVERLAY")
    button.Label:SetText(label)
    local normal, checked = art(button, list), art(button, list, "OVERLAY")
    function button:GetNormalTexture() return normal end
    function button:GetCheckedTexture() return checked end
    return button
end

local function fixture()
    local list = {}
    local frame = R.window("CharacterFrame")
    CharacterFrame = frame
    local detail = CreateFrame("Frame", nil, CreateFrame("Frame", "ReputationFrame", frame))
    local war = checkbox(detail, list, "At War")
    local watch = checkbox(detail, list, "Show as Experience Bar")
    watch:SetChecked(true)
    local icon = CreateFrame("CheckButton", "PaperDollSidebarTab1", frame)
    local pane = CreateFrame("Frame", "CharacterStatsPaneScrollBox", frame)
    CharacterStatsPaneScrollBox = pane
    pane.ScrollBar = CreateFrame("Frame", nil, pane)
    pane.ScrollBar.Track = CreateFrame("Frame", nil, pane.ScrollBar)
    local arrows = {}
    for _, key in ipairs({ "Back", "Forward" }) do
        local button = CreateFrame("Button", nil, pane.ScrollBar)
        button.Texture = art(button, list, "BACKGROUND")
        pane.ScrollBar[key] = button
        arrows[#arrows + 1] = button
    end
    return { frame = frame, art = list, war = war, watch = watch, icon = icon, back = arrows[1], forward = arrows[2] }
end

-- Shown own regions of `button` in a colour.
local function painted(button, color)
    local count = 0
    for _, region in ipairs(button._regions) do
        local c = region._shown and region._color
        if c and math.abs(c[1] - color[1]) < 1e-6 and math.abs(c[2] - color[2]) < 1e-6 then count = count + 1 end
    end
    return count
end

local function mark(button, theme)
    for _, region in ipairs(button._regions) do
        if region._layer == "ARTWORK" and region._color and region._color[1] == theme.accent[1] then
            return region._shown and true or false
        end
    end
    return false
end

h.test("Windows turns checkboxes into a flat box with an accent mark that follows Blizzard, and restores them", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    local before = L.snapshot(R.all(f.frame))
    W.enable(ns)
    local theme = ns.Modern.Theme()
    for _, texture in ipairs({ f.war:GetNormalTexture(), f.war:GetCheckedTexture() }) do
        A.alpha(texture, 0, "Blizzard's box and tick are held")
    end
    A.ok(painted(f.war, theme.track) == 1, "a dark square")
    A.eq(painted(f.war, theme.border), 4, "with a thin border")
    A.ok(mark(f.watch, theme), "a checked box shows the accent mark")
    A.ok(not mark(f.war, theme), "an unchecked one does not")
    f.war:SetChecked(true)
    A.ok(mark(f.war, theme), "the mark follows SetChecked")
    f.war:GetScript("OnEnter")(f.war)
    A.eq(painted(f.war, theme.accent), 5, "the border turns accent under the mouse")
    f.war:GetScript("OnLeave")(f.war)
    f.war:Disable()
    A.eq(painted(f.war, theme.wellEdge), 4, "a disabled box greys out")
    A.eq(painted(f.icon, theme.track), 0, "an icon toggle without a label gets no checkbox")
    ns.Modern.Restore()
    A.ok(not mark(f.war, theme) and painted(f.war, theme.track) == 0, "Restore removes the box and mark")
    A.deep(L.diff(before), {}, "checkboxes restore exactly")
end)

h.test("Windows draws the scroll bar arrows as accent chevrons, grey while they cannot scroll", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.alpha(f.back.Texture, 0, "Blizzard's arrow art is held")
    A.eq(painted(f.back, theme.accent), 2, "the up arrow is an accent chevron")
    A.eq(painted(f.forward, theme.accent), 2, "the down arrow too")
    f.back:Disable()
    A.eq(painted(f.back, theme.wellEdge), 2, "an arrow that cannot scroll greys out")
    f.back:Enable()
    A.eq(painted(f.back, theme.accent), 2, "and lights up again")
    ns.Modern.Restore()
    A.eq(painted(f.back, theme.accent) + painted(f.back, theme.wellEdge), 0, "Restore removes the chevrons")
end)
