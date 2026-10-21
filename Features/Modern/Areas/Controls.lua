local _, ns = ...

-- Small controls inside skinned windows. A checkbox loses Blizzard's box and tick for a dark square with a thin
-- border and an accent mark while checked; the border turns accent under the mouse and the square greys out while
-- disabled. The arrows of a minimal scroll bar become bare accent chevrons, grey while they cannot scroll. An
-- expand / collapse icon becomes a bare accent plus or minus, read from the name of Blizzard's art.

local Modern = ns.Modern

local CHECK_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture",
    "GetDisabledTexture", "GetDisabledCheckedTexture" }
local BOX, INSET = 16, 4
local STROKE = 6
-- Descendant depth of a checkbox scan: deep enough for detail panes inside a window's sub-panels.
local DEPTH = 5

local SIGN = 10

local checks = setmetatable({}, { __mode = "k" })  -- checkbox -> journal while applied
local expanders = setmetatable({}, { __mode = "k" }) -- icon or button -> { skin, owner, expanded } while applied
local arrows = setmetatable({}, { __mode = "k" })  -- arrow button -> { skin, dir } while applied
local sliders = setmetatable({}, { __mode = "k" }) -- value slider -> journal while applied
local hovered = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function Enabled(button)
    return type(button.IsEnabled) ~= "function" or button:IsEnabled() and true or false
end

-- Follows Blizzard on `methods` of `button` and on `scripts`; `paint(button)` runs only while the control is applied.
local function Follow(button, methods, paint)
    if hooked[button] then return end
    hooked[button] = true
    for _, method in ipairs(methods) do
        if type(button[method]) == "function" then
            pcall(hooksecurefunc, button, method, function() ns.Profiler.Run("modern controls", paint, button) end)
        end
    end
    if type(button.HookScript) ~= "function" then return end
    for script, over in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function()
            hovered[button] = over
            ns.Profiler.Run("modern controls", paint, button)
        end)
    end
    pcall(button.HookScript, button, "OnClick", function() ns.Profiler.Run("modern controls", paint, button) end)
end

local function PaintCheck(button)
    local skin = checks[button]
    if not skin then return end
    local theme = Modern.Theme()
    local box, mark = unpack(skin:Own(button, "checkbox", function() end))
    local enabled = Enabled(button)
    local edge = not enabled and theme.wellEdge or hovered[button] and theme.accent or theme.border
    skin:Border(button, edge, box)
    mark:SetColorTexture(unpack(enabled and theme.accent or theme.glyph))
    local checked = type(button.GetChecked) == "function" and button:GetChecked()
    mark:SetShown(checked and true or false)
end

function Modern.Checkbox(skin, button)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    for _, getter in ipairs(CHECK_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
        end
    end
    local parts = skin:Own(button, "checkbox", function()
        local box = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        box:SetSize(BOX, BOX)
        box:SetPoint("CENTER", button, "CENTER", 0, 0)
        local mark = button:CreateTexture(nil, "ARTWORK", nil, 7)
        mark:SetPoint("TOPLEFT", box, "TOPLEFT", INSET, -INSET)
        mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -INSET, INSET)
        return { box, mark }
    end)
    parts[1]:SetColorTexture(unpack(Modern.Theme().track))
    parts[1]:Show()
    checks[button] = skin
    skin:Remember(button, "modern checkbox", function()
        checks[button] = nil
        hovered[button] = nil
    end)
    PaintCheck(button)
    Follow(button, { "SetChecked", "Enable", "Disable", "SetEnabled" }, PaintCheck)
end

local function ArtName(button, getter)
    if type(button[getter]) ~= "function" then return nil end
    local ok, texture = pcall(button[getter], button)
    if not ok or not ns.Usable(texture) then return nil end
    for _, read in ipairs({ "GetAtlas", "GetTexture" }) do
        if type(texture[read]) == "function" then
            local okName, name = pcall(texture[read], texture)
            if okName and type(name) == "string" then return name:lower() end
        end
    end
end

-- A CheckButton with a label, or one wearing Blizzard's checkbox art (the group finder's role and activity boxes);
-- icon toggles (the character sidebar tabs, side tabs) are CheckButtons with neither.
function Modern.IsCheckbox(frame)
    if type(frame.GetObjectType) ~= "function" or frame:GetObjectType() ~= "CheckButton" then return false end
    if (frame.Text or frame.text or frame.Label) ~= nil then return true end
    local name = ArtName(frame, "GetNormalTexture")
    return name ~= nil and name:find("checkbox", 1, true) ~= nil
end

-- Every checkbox under a window, scanned once per apply.
function Modern.Checkboxes(skin, frame, depth)
    depth = depth or 0
    if depth > DEPTH or not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return end
    if depth == 0 and not skin:Remember(frame, "modern checkbox scan", function() end) then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) then
            if Modern.IsCheckbox(child) then Modern.Checkbox(skin, child) end
            Modern.Checkboxes(skin, child, depth + 1)
        end
    end
end

-- Two strokes meeting at the tip, pointing `dir` (up, down, left, right).
local function ChevronParts(button, dir)
    if dir == "left" or dir == "right" then
        local angle = dir == "left" and 45 or -45
        return { Modern.GlyphLine(button, STROKE, 2, 0, 2, angle), Modern.GlyphLine(button, STROKE, 2, 0, -2, -angle) }
    end
    local angle = dir == "up" and 45 or -45
    return { Modern.GlyphLine(button, STROKE, 2, -2, 0, angle), Modern.GlyphLine(button, STROKE, 2, 2, 0, -angle) }
end

local function PaintArrow(button)
    local state = arrows[button]
    if not state then return end
    local theme = Modern.Theme()
    local parts = state.skin:Own(button, "scroll arrow", function() return ChevronParts(button, state.dir) end)
    local color = not Enabled(button) and theme.wellEdge or hovered[button] and theme.text or theme.accent
    for _, line in ipairs(parts) do
        line:SetColorTexture(unpack(color))
        line:Show()
    end
end

local ARROW_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local function Arrow(skin, button, dir)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    if ns.Usable(button.Texture) and type(button.Texture.SetAlpha) == "function" then skin:Hold(button.Texture) end
    -- The old slider bar's arrows carry their art as button textures.
    for _, getter in ipairs(ARROW_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
        end
    end
    arrows[button] = { skin = skin, dir = dir }
    skin:Remember(button, "modern scroll arrow", function()
        arrows[button] = nil
        hovered[button] = nil
    end)
    PaintArrow(button)
    Follow(button, { "Enable", "Disable", "SetEnabled" }, PaintArrow)
end

-- The Back (up) and Forward (down) arrows of a minimal scroll bar.
function Modern.ScrollArrows(skin, bar)
    if not ns.Usable(bar) then return end
    Arrow(skin, bar.Back, "up")
    Arrow(skin, bar.Forward, "down")
end

-- UIPanelScrollBarTemplate (a Slider): the up and down buttons become the same chevrons, the knob a flat bar in the
-- border colour that follows it.
function Modern.SliderBar(skin, bar)
    if not ns.Usable(bar) then return end
    Arrow(skin, bar.ScrollUpButton, "up")
    Arrow(skin, bar.ScrollDownButton, "down")
    local knob = bar.ThumbTexture
    if not ns.Usable(knob) and type(bar.GetThumbTexture) == "function" then knob = bar:GetThumbTexture() end
    if not ns.Usable(knob) or type(knob.SetAlpha) ~= "function" or type(bar.CreateTexture) ~= "function" then return end
    skin:Hold(knob)
    local fill = skin:Own(bar, "knob", function()
        local texture = bar:CreateTexture(nil, "OVERLAY")
        texture:SetPoint("TOPLEFT", knob, "TOPLEFT", 5, -2)
        texture:SetPoint("BOTTOMRIGHT", knob, "BOTTOMRIGHT", -5, 2)
        return texture
    end)
    if fill then
        fill:SetColorTexture(unpack(Modern.Theme().border))
        fill:Show()
    end
end

local TRACK, KNOB_W, KNOB_H = 4, 6, 14

local function Held(skin, frame)
    if type(frame.GetRegions) ~= "function" then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
            and not skin:Owns(frame, region) then
            skin:Hold(region)
        end
    end
end

local function PaintSlider(slider)
    local skin = sliders[slider]
    if not skin then return end
    local theme = Modern.Theme()
    local track, fill, knob = unpack(skin:Own(slider, "value slider", function() end))
    local on = Enabled(slider)
    track:SetColorTexture(unpack(theme.track))
    fill:SetColorTexture(unpack(on and theme.accent or theme.wellEdge))
    fill:SetAlpha(0.5)
    knob:SetColorTexture(unpack(not on and theme.wellEdge or hovered[slider] and theme.text or theme.accent))
    for _, part in ipairs({ track, fill, knob }) do part:Show() end
end

-- MinimalSliderWithSteppersTemplate (the settings list): the bar becomes a thin dark track filled in accent up to
-- a flat knob, the Back and Forward steppers bare left and right chevrons. The value text stays.
function Modern.ValueSlider(skin, frame)
    local slider = ns.Usable(frame) and frame.Slider
    if not ns.Usable(slider) or type(slider.CreateTexture) ~= "function" then return end
    local thumb = slider.Thumb
    if not ns.Usable(thumb) and type(slider.GetThumbTexture) == "function" then thumb = slider:GetThumbTexture() end
    if not ns.Usable(thumb) then return end
    Held(skin, slider)
    for _, key in ipairs({ "Back", "Forward" }) do
        if ns.Usable(frame[key]) then Held(skin, frame[key]) end
    end
    skin:Own(slider, "value slider", function()
        local track = slider:CreateTexture(nil, "ARTWORK", nil, 1)
        track:SetHeight(TRACK)
        track:SetPoint("LEFT", slider, "LEFT", 0, 0)
        track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
        local fill = slider:CreateTexture(nil, "ARTWORK", nil, 2)
        fill:SetHeight(TRACK)
        fill:SetPoint("LEFT", track, "LEFT", 0, 0)
        fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
        local knob = slider:CreateTexture(nil, "OVERLAY", nil, 7)
        knob:SetSize(KNOB_W, KNOB_H)
        knob:SetPoint("CENTER", thumb, "CENTER", 0, 0)
        return { track, fill, knob }
    end)
    sliders[slider] = skin
    skin:Remember(slider, "modern value slider", function()
        sliders[slider] = nil
        hovered[slider] = nil
    end)
    PaintSlider(slider)
    Follow(slider, { "Enable", "Disable", "SetEnabled" }, PaintSlider)
    Arrow(skin, frame.Back, "left")
    Arrow(skin, frame.Forward, "right")
end

local function IsValueSlider(frame)
    local slider = rawget(frame, "Slider")
    return ns.Usable(slider) and type(slider.GetObjectType) == "function" and slider:GetObjectType() == "Slider"
        and ns.Usable(rawget(frame, "Back")) and ns.Usable(rawget(frame, "Forward"))
end

-- Checkboxes and value sliders under `frame`, every call: for lists whose pooled rows are refilled.
function Modern.ListControls(skin, frame, depth)
    depth = depth or 0
    if depth > DEPTH or not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) then
            if Modern.IsCheckbox(child) then
                Modern.Checkbox(skin, child)
            elseif IsValueSlider(child) then
                Modern.ValueSlider(skin, child)
            else
                Modern.ListControls(skin, child, depth + 1)
            end
        end
    end
end

-- Expanded (minus) or collapsed (plus) from an atlas or file name; nil when the name says neither.
local function Expanded(name)
    if type(name) ~= "string" then return nil end
    name = name:lower()
    for _, word in ipairs({ "expanded", "minus", "open", "collapse" }) do
        if name:find(word, 1, true) then return true end
    end
    for _, word in ipairs({ "plus", "closed", "expand" }) do
        if name:find(word, 1, true) then return false end
    end
end

local function NameOf(texture)
    if type(texture.GetAtlas) == "function" then
        local ok, atlas = pcall(texture.GetAtlas, texture)
        if ok and type(atlas) == "string" then return atlas end
    end
    if type(texture.GetTexture) == "function" then
        local ok, file = pcall(texture.GetTexture, texture)
        if ok and type(file) == "string" then return file end
    end
end

-- Blizzard's art of `target`; on a pooled button skinned again, the skin's own sign is not part of it.
local function Textures(target, skin)
    if type(target.GetObjectType) == "function" and target:GetObjectType() == "Texture" then return { target } end
    local list = {}
    if type(target.GetRegions) ~= "function" then return list end
    for _, region in ipairs({ target:GetRegions() }) do
        if ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
            and not (skin and skin:Owns(target, region)) then
            list[#list + 1] = region
        end
    end
    return list
end

-- The state of the first texture whose name tells it, preferring the ones Blizzard shows.
local function State(target, skin)
    local fallback
    for _, texture in ipairs(Textures(target, skin)) do
        local expanded = Expanded(NameOf(texture))
        if expanded ~= nil then
            if type(texture.IsShown) ~= "function" or texture:IsShown() then return expanded end
            if fallback == nil then fallback = expanded end
        end
    end
    return fallback
end

local function PaintExpander(target)
    local state = expanders[target]
    if not state then return end
    local expanded = State(target, state.skin)
    if expanded ~= nil then state.expanded = expanded end
    local parts = state.skin:Own(state.owner, "expander", function()
        return { Modern.GlyphLine(state.owner, SIGN, 2, 0, 0), Modern.GlyphLine(state.owner, 2, SIGN, 0, 0) }
    end)
    local bar, stem = parts[1], parts[2]
    for _, line in ipairs({ bar, stem }) do
        line:ClearAllPoints()
        line:SetPoint("CENTER", target, "CENTER", 0, 0)
        line:SetColorTexture(unpack(Modern.Theme().accent))
    end
    bar:Show()
    stem:SetShown(not state.expanded)
end

-- `target` is an expand icon texture (a header's StateIcon) or a toggle button. Its art is held and a plus or minus
-- drawn on its centre; art whose name tells no state is left to Blizzard.
function Modern.Expander(skin, target)
    if not ns.Usable(target) then return end
    local expanded = State(target, skin)
    if expanded == nil then return end
    local textures = Textures(target, skin)
    local owner = #textures == 1 and textures[1] == target and target:GetParent() or target
    if not ns.Usable(owner) or type(owner.CreateTexture) ~= "function" then return end
    for _, texture in ipairs(textures) do skin:Hold(texture) end
    expanders[target] = { skin = skin, owner = owner, expanded = expanded }
    skin:Remember(target, "modern expander", function() expanders[target] = nil end)
    PaintExpander(target)
    if hooked[target] then return end
    hooked[target] = true
    local function Again() ns.Profiler.Run("modern controls", PaintExpander, target) end
    for _, texture in ipairs(textures) do
        for _, method in ipairs({ "SetAtlas", "SetTexture", "Show", "Hide", "SetShown" }) do
            if type(texture[method]) == "function" then pcall(hooksecurefunc, texture, method, Again) end
        end
    end
    if target == owner then
        for _, method in ipairs({ "SetNormalAtlas", "SetNormalTexture", "RefreshIcon" }) do
            if type(target[method]) == "function" then pcall(hooksecurefunc, target, method, Again) end
        end
        if type(target.HookScript) == "function" then pcall(target.HookScript, target, "OnClick", Again) end
    end
end
