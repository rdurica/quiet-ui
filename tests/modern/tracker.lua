-- Modern quest tracker: the container and module headers lose their banner art for a section strip, the minimize
-- buttons become accent plus / minus signs, modules added later are skinned on the tracker's Update, and restore
-- gives everything back.
local h = ...
local W = h.lib("modern-windows")

-- A texture that remembers its atlas, as the client's does.
local function atlased(texture)
    function texture:SetAtlas(atlas) self._atlas = atlas end
    function texture:GetAtlas() return self._atlas end
    return texture
end

local function header(parent, title, atlas)
    local head = CreateFrame("Frame", nil, parent)
    head:SetSize(260, 26)
    head.Background = W.texture(head, "TrackerHeader", 0.9)
    head.Text = head:CreateFontString(nil, "OVERLAY")
    head.Text:SetText(title)
    local button = CreateFrame("Button", nil, head)
    button:SetSize(16, 16)
    button.normal = atlased(button:CreateTexture(nil, "ARTWORK"))
    button.normal:SetAtlas(atlas)
    button.GetNormalTexture = function() return button.normal end
    head.MinimizeButton = button
    return head
end

local function tracker()
    local frame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
    frame.Header = header(frame, "All Objectives", "ui-questtrackerbutton-collapse-all")
    frame.modules = {}
    function frame:Update() end
    return frame
end

local function module(frame, title)
    local m = CreateFrame("Frame", nil, frame)
    m.Header = header(m, title, "ui-questtrackerbutton-secondary-collapse")
    frame.modules[#frame.modules + 1] = m
    return m
end

-- A shown strip fill, and the count of shown accent strokes of a sign (1 minus, 2 plus).
local function striped(frame, strip)
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == strip[1] and region._shown ~= false then return true end
    end
    return false
end

local function sign(frame, accent)
    local count = 0
    for _, region in ipairs(frame._regions) do
        local col = region._color
        if region._shown and (region._alpha or 1) > 0 and col and col[1] == accent[1]
            and (region._w == 10 or region._h == 10) then count = count + 1 end
    end
    return count
end

h.test("Quest tracker headers become strips with accent signs and follow Blizzard's state", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "tracker")
    local frame = tracker()
    local quests = module(frame, "Quests")
    W.enable(ns)
    local accent = ns.Modern.Theme().accent
    A.alpha(frame.Header.Background, 0, "container banner is held")
    A.alpha(quests.Header.Background, 0, "module banner is held")
    local strip = ns.Modern.Theme().strip
    A.ok(striped(frame.Header, strip), "container header is a strip")
    A.ok(striped(quests.Header, strip), "module header is a strip")
    A.alpha(quests.Header.MinimizeButton.normal, 0, "minimize art is held")
    A.eq(sign(quests.Header.MinimizeButton, accent), 1, "an expanded module shows a minus")
    quests.Header.MinimizeButton.normal:SetAtlas("ui-questtrackerbutton-secondary-expand")
    A.eq(sign(quests.Header.MinimizeButton, accent), 2, "a collapsed module shows a plus")
end)

h.test("Quest tracker modules added later are skinned on Update, and nothing after restore", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "tracker")
    local frame = tracker()
    W.enable(ns)
    local late = module(frame, "Campaign")
    frame:Update()
    A.alpha(late.Header.Background, 0, "a late module header is skinned")
    ns.Modern.Restore()
    A.alpha(frame.Header.Background, 0.9, "container banner is back")
    A.alpha(late.Header.Background, 0.9, "module banner is back")
    A.falsy(striped(frame.Header, ns.Modern.Theme().strip), "the strip is hidden")
    A.alpha(late.Header.MinimizeButton.normal, 1, "minimize art is back")
    local after = module(frame, "Achievements")
    frame:Update()
    A.alpha(after.Header.Background, 0.9, "a restored area skins nothing")
end)
