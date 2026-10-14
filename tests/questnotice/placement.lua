-- Where the notice sits and how it looks: text only, first quest slot of the native tracker,
-- tracker fonts and colors, Edit Mode scale and the three text sizes.
local h = ...
local Q = h.lib("questnotice")
local function env(t, opts) return Q.fixture(t.mock, t.ns, opts) end

local function trackerOrigin(s, actual, tracker)
    if math.abs(s.left(actual) * s.scale(actual) - s.left(tracker) * s.scale(tracker)) >= 0.01 then
        error("Failed module placement must use the tracker left", 0)
    end
    if math.abs(s.top(actual) * s.scale(actual) - s.top(tracker) * s.scale(tracker)) >= 0.01 then
        error("Failed module placement must use the tracker top", 0)
    end
end

h.test("the notice is on UIParent, takes the tracker width and never captures clicks", function(t)
    local s = env(t)
    s.change(1)
    local f = s.notice()
    t.assert.eq(f._parent, UIParent)
    t.assert.eq(f._w, s.tracker._w, "Notice width follows the tracker")
    t.assert.ok(f._mouse ~= true and f._click ~= true, "Notice must not intercept clicks")
    t.assert.ok(#f._points > 0, "Must position notice")
    t.assert.eq(f._points[1][2], s.tracker, "Without a quest module the notice sits at the tracker")
end)

h.test("the notice is text only without background, border or backdrop template", function(t)
    local s = env(t)
    s.change(1)
    local f = s.notice()
    t.assert.ok(not f._template or not tostring(f._template):find("BackdropTemplate", 1, true), "Must not request BackdropTemplate")
    t.assert.ok(not f._backdrop and not f._backdropColor and not f._backdropBorder, "Must not create backdrop")
    for _, r in ipairs(f._regions) do t.assert.ne(r._kind, "Texture", "Must not create background or border textures") end
    t.assert.ok(f._parent == UIParent and f._mouse ~= true and f._click ~= true and f._motion ~= true,
        "Text must remain independent and nonclickable")
end)

for _, classic in ipairs({ false, true }) do
    h.test((classic and "classic" or "modern") .. " notice is the first quest slot with tracker fonts", function(t)
        local s = env(t, { classic = classic })
        local module = s.nativeModule(classic)
        s.trackerFonts()
        s.change(3)
        local title = s.textRegion("Quest 1")
        s.slotLocation(title, module)
        s.sameFont(title, ObjectiveTrackerHeaderFont)
        s.sameFont(s.textRegion("Wolves 3/8"), ObjectiveTrackerFont)
        t.assert.ok(s.top(title) * s.scale(title) < s.top(module.Header.Text) * s.scale(module.Header.Text),
            "First slot must lie below the quest section header")
        t.assert.eq(s.notice()._parent, UIParent, "First-slot placement must not reparent notice")
    end)
end

h.test("module offset changes refresh the first slot without a new quest event", function(t)
    local s = env(t)
    local module = s.nativeModule()
    s.trackerFonts()
    s.change(1)
    s.slotLocation(s.textRegion("Quest 1"), module)
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont)
    module.ContentsFrame._left, module.ContentsFrame._top = 130, 400
    module.blockOffsetX, module.fromHeaderOffsetY = 48, -28
    ObjectiveTrackerHeaderFont:SetFont("Fonts/reflow.ttf", 17, "")
    ObjectiveTrackerHeaderFont._textColor = { 0.5, 0.6, 0.7, 1 }
    s.tick()
    s.slotLocation(s.textRegion("Quest 1"), module)
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont)
end)

h.test("tracker header fallback places the text below the header when no quest module exists", function(t)
    local s = env(t)
    local header = t.mock:findByName("ObjectiveTrackerFrame") and s.tracker
    header.Header = CreateFrame("Frame", nil, s.tracker)
    header.Header.Text = header.Header:CreateFontString()
    local text = header.Header.Text
    text._left, text._top, text._h = 115, 490, 22
    s.prepare(text)
    s.change(1)
    local title = s.textRegion("Quest 1")
    t.assert.ok(s.top(title) <= s.bottom(text), "Must not draw over tracker header")
    t.assert.ok(s.top(title) > s.bottom(s.tracker), "Fallback must stay within quest area")
end)

h.test("a replacement tracker uses the new module first slot", function(t)
    local s = env(t)
    local module = s.nativeModule()
    s.change(1)
    s.slotLocation(s.textRegion("Quest 1"), module)
    local replacement = s.prepare(CreateFrame("Frame", nil, UIParent), true)
    s.tracker = replacement
    ObjectiveTrackerFrame = replacement
    local newModule = s.nativeModule()
    newModule.ContentsFrame._left, newModule.ContentsFrame._top = 160, 380
    newModule.blockOffsetX, newModule.fromHeaderOffsetY = 12, -16
    s.tick()
    s.slotLocation(s.textRegion("Quest 1"), newModule)
end)

for _, failure in ipairs({ "missing", "throwing", "forbidden", "secret" }) do
    h.test(failure .. " module slot metadata falls back to the tracker origin", function(t)
        local s = env(t)
        local module = s.nativeModule()
        if failure == "missing" then
            module.ContentsFrame = nil
        elseif failure == "throwing" then
            module.ContentsFrame.GetLeft = function() error("Contents unavailable") end
        elseif failure == "forbidden" then
            module.ContentsFrame._forbidden = true
        else
            local box = setmetatable({}, {
                __lt = function() error("Secret compared") end,
                __add = function() error("Secret arithmetic") end,
            })
            t.mock.secrets[box] = true
            module.blockOffsetX = box
        end
        s.change(1)
        s.has("Wolves 1/8")
        trackerOrigin(s, s.textRegion("Quest 1"), s.tracker)
    end)
end

h.test("unavailable native font getters keep a usable text fallback", function(t)
    local s = env(t)
    local module = s.nativeModule()
    s.trackerFonts()
    ObjectiveTrackerHeaderFont.GetFont = function() error("Font unavailable") end
    local box = {}
    t.mock.secrets[box] = true
    ObjectiveTrackerFont.GetTextColor = function() return box end
    s.change(1)
    s.has("Quest 1"); s.has("Wolves 1/8")
    s.slotLocation(s.textRegion("Quest 1"), module)
    t.assert.type(s.textRegion("Quest 1"):GetFont(), "string", "Must retain a usable font fallback")
end)

h.test("the first slot keeps its physical position and font size under Edit Mode scale", function(t)
    local s = env(t)
    s.tracker._scale = 1.25
    local module = s.nativeModule()
    s.trackerFonts()
    s.change(1)
    local title = s.textRegion("Quest 1")
    s.slotLocation(title, module)
    local _, size = title:GetFont()
    local _, nativeSize = ObjectiveTrackerHeaderFont:GetFont()
    t.assert.near(size * s.scale(title), nativeSize * s.scale(module.ContentsFrame), 0.01,
        "Default size must match the tracker font under Edit Mode scale")
end)

h.test("text size offers default, a little smaller and the larger notice", function(t)
    local s = env(t)
    s.nativeModule()
    s.trackerFonts()
    s.change(1)
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont, 1)
    s.sameFont(s.textRegion("Wolves 1/8"), ObjectiveTrackerFont, 1)
    QuietUICharDB.questNoticeSize = "smaller"; s.tick()
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont, 0.9)
    QuietUICharDB.questNoticeSize = "larger"; s.tick()
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont, 1.2)
    QuietUICharDB.questNoticeSize = "huge"; s.tick()
    s.sameFont(s.textRegion("Quest 1"), ObjectiveTrackerHeaderFont, 1)
end)
