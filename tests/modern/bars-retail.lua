-- Modern action bars on the 12.0 client: MainActionBar child art, the button parts of ActionButtonTemplate, the icon
-- mask and the hover / pressed / checked feedback.
local h = ...
local L = h.lib("modern")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bars-retail")
local I = h.lib("modern-icons")

local function fixture(count)
    local bar = B.bar()
    local buttons = {}
    for index = 1, count or 2 do buttons[index] = B.button("ActionButton" .. index, bar) end
    return bar, buttons
end

local function known(button)
    local set = {}
    for _, region in ipairs(button._regions) do set[region] = true end
    return set
end

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

h.test("12.0 bar art (BorderArt and both gryphon end caps) is held at alpha 0 against Blizzard and restored", function(t)
    local A, ns = t.assert, t.ns
    local bar, buttons = fixture()
    local before = L.snapshot(R.all(bar))
    enable(ns)
    for _, art in ipairs({ bar.BorderArt, bar.EndCaps.LeftEndCap, bar.EndCaps.RightEndCap }) do
        A.alpha(art, 0, "bar art held")
        art:SetAlpha(1)
        A.alpha(art, 0, "bar art stays held when Blizzard sets alpha")
    end
    A.alpha(bar, 1, "bar alpha untouched")
    A.alpha(bar.ActionBarPageNumber.Text, 1, "page number text stays")
    A.alpha(buttons[1], 1, "button alpha untouched")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "bar art restores exactly (alpha)")
end)

h.test("12.0 button parts SlotArt, SlotBackground, Border, Flash and the state textures are held and restored", function(t)
    local A, ns = t.assert, t.ns
    local bar, buttons = fixture()
    local list = R.all(bar)
    local before = L.snapshot(list)
    enable(ns)
    for _, button in ipairs(buttons) do
        local name = button:GetName()
        A.ok(I.zoomed(button.icon), name .. " icon is cropped")
        A.alpha(button.icon, 1, name .. " icon stays visible")
        for _, key in ipairs({ "SlotArt", "SlotBackground", "NormalTexture" }) do A.alpha(button[key], 0, name .. " " .. key .. " held") end
        A.ok(I.border(button), name .. " has the one-pixel border")
        A.ok(I.outlined(button.HotKey), name .. " hotkey outlined")
        A.ok(I.outlined(button.Count), name .. " count outlined")
        A.eq(button:GetWidth(), 45); A.eq(button:GetHeight(), 45)
    end
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "every Blizzard part restores exactly")
    for _, button in ipairs(buttons) do A.ok(not I.border(button), button:GetName() .. " own border hidden") end
end)

h.test("12.0 IconMask is taken off the icon so the square crop is not clipped, and put back on restore", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local button = buttons[1]
    A.eq(button.icon:GetNumMaskTextures(), 1, "fixture: the icon carries IconMask")
    enable(ns)
    A.eq(button.icon:GetNumMaskTextures(), 0, "no mask on the icon while the area is on")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.eq(button.icon:GetNumMaskTextures(), 1, "mask is back after restore")
    A.eq(button.icon:GetMaskTexture(1), button.IconMask, "the same IconMask")
end)

h.test("12.0 buttons keep a flat themed hover highlight", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local theme
    local seen = {}
    for _, button in ipairs(buttons) do seen[button] = known(button) end
    enable(ns)
    theme = ns.Modern.Theme()
    for _, button in ipairs(buttons) do
        local own = false
        for region in pairs(B.visibleOwn(button, theme, seen[button])) do
            if region._layer == "HIGHLIGHT" then own = true end
        end
        A.ok(B.visibleFlat(button.HighlightTexture, theme) or own,
            button:GetName() .. " has a visible flat theme-coloured highlight (native texture or own HIGHLIGHT region)")
    end
end)

h.test("12.0 buttons keep visible pressed and checked feedback in theme colours", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local seen = {}
    for _, button in ipairs(buttons) do seen[button] = known(button) end
    enable(ns)
    local theme = ns.Modern.Theme()
    for _, button in ipairs(buttons) do
        local name = button:GetName()
        local idle = B.visibleOwn(button, theme, seen[button])
        if not B.visibleFlat(button.PushedTexture, theme) then
            if button._scripts.OnMouseDown then button._scripts.OnMouseDown(button, "LeftButton") end
            button:SetButtonState("PUSHED")
            local pressed, extra = B.visibleOwn(button, theme, seen[button]), false
            for region in pairs(pressed) do if not idle[region] then extra = true end end
            A.ok(extra, name .. " shows a flat theme-coloured pressed region while pushed")
            button:SetButtonState("NORMAL")
            if button._scripts.OnMouseUp then button._scripts.OnMouseUp(button, "LeftButton") end
        end
        if not B.visibleFlat(button.CheckedTexture, theme) then
            button:SetChecked(true)
            local checked, extra = B.visibleOwn(button, theme, seen[button]), false
            for region in pairs(checked) do if not idle[region] then extra = true end end
            A.ok(extra, name .. " shows a flat theme-coloured checked region while checked")
            button:SetChecked(false)
        end
    end
end)

h.test("12.0 state feedback regions go away when the area is switched off", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local button = buttons[1]
    local seen = known(button)
    enable(ns)
    local theme = ns.Modern.Theme()
    button:SetButtonState("PUSHED"); button:SetChecked(true)
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    button:SetButtonState("PUSHED"); button:SetChecked(true)
    A.deep(B.visibleOwn(button, theme, seen), {}, "no own flat region is visible after restore, even pressed or checked")
    A.falsy(button.HighlightTexture._color, "Blizzard highlight is not recoloured")
end)

h.test("12.0 bars skin without Hide, Show or state drivers and in combat", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar, buttons = fixture()
    local barCalls, buttonCalls, capCalls = I.watchVisibility(bar), I.watchVisibility(buttons[1]), I.watchVisibility(bar.EndCaps)
    local drivers = 0
    _G.RegisterStateDriver = function() drivers = drivers + 1 end
    mock.state.combat = true
    enable(ns)
    A.ok(I.zoomed(buttons[1].icon), "texture work is allowed in combat")
    A.deep(barCalls, { hide = 0, show = 0 })
    A.deep(buttonCalls, { hide = 0, show = 0 })
    A.deep(capCalls, { hide = 0, show = 0 })
    A.eq(drivers, 0, "no state driver")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("12.0 hover feedback is shown again after apply, restore, apply", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local button = buttons[1]
    local seen = known(button)
    enable(ns)
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    QuietUICharDB.modernize.enabled = true
    ns.Modern.Apply()
    local hover = false
    for region in pairs(B.visibleOwn(button, ns.Modern.Theme(), seen)) do
        if region._layer == "HIGHLIGHT" then hover = true end
    end
    A.ok(hover, "own HIGHLIGHT region is visible after re-apply")
end)

h.test("12.0 pressed feedback does not stick after leave, drag start or a NORMAL state", function(t)
    local A, ns = t.assert, t.ns
    local _, buttons = fixture()
    local button = buttons[1]
    local seen = known(button)
    enable(ns)
    local theme = ns.Modern.Theme()
    local idle = B.visibleOwn(button, theme, seen)
    local function stuck()
        for region in pairs(B.visibleOwn(button, theme, seen)) do
            if not idle[region] then return true end
        end
        return false
    end
    for _, script in ipairs({ "OnLeave", "OnDragStart" }) do
        if button._scripts.OnMouseDown then button._scripts.OnMouseDown(button, "LeftButton") end
        A.ok(stuck(), "pressed region visible after mouse down")
        if button._scripts[script] then button._scripts[script](button) end
        A.ok(not stuck(), "pressed region gone after " .. script)
    end
    if button._scripts.OnMouseDown then button._scripts.OnMouseDown(button, "LeftButton") end
    button:SetButtonState("NORMAL")
    A.ok(not stuck(), "pressed region gone after SetButtonState NORMAL")
end)
