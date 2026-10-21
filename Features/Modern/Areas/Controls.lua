local _, ns = ...

-- Small controls inside skinned windows. A checkbox loses Blizzard's box and tick for a dark square with a thin
-- border and an accent mark while checked; the border turns accent under the mouse and the square greys out while
-- disabled. The arrows of a minimal scroll bar become bare accent chevrons, grey while they cannot scroll.

local Modern = ns.Modern

local CHECK_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture",
    "GetDisabledTexture", "GetDisabledCheckedTexture" }
local BOX, INSET = 16, 4
local STROKE = 6
-- Descendant depth of a checkbox scan: deep enough for detail panes inside a window's sub-panels.
local DEPTH = 5

local checks = setmetatable({}, { __mode = "k" })  -- checkbox -> journal while applied
local arrows = setmetatable({}, { __mode = "k" })  -- arrow button -> { skin, up } while applied
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
            pcall(hooksecurefunc, button, method, function() ns.Run("modern controls", paint, button) end)
        end
    end
    if type(button.HookScript) ~= "function" then return end
    for script, over in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function()
            hovered[button] = over
            ns.Run("modern controls", paint, button)
        end)
    end
    pcall(button.HookScript, button, "OnClick", function() ns.Run("modern controls", paint, button) end)
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

-- A CheckButton with a label; icon toggles (the character sidebar tabs) are CheckButtons without one.
local function IsCheckbox(frame)
    if type(frame.GetObjectType) ~= "function" or frame:GetObjectType() ~= "CheckButton" then return false end
    return (frame.Text or frame.text or frame.Label) ~= nil
end

-- Every checkbox under a window, scanned once per apply.
function Modern.Checkboxes(skin, frame, depth)
    depth = depth or 0
    if depth > DEPTH or not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return end
    if depth == 0 and not skin:Remember(frame, "modern checkbox scan", function() end) then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) then
            if IsCheckbox(child) then Modern.Checkbox(skin, child) end
            Modern.Checkboxes(skin, child, depth + 1)
        end
    end
end

-- Two strokes meeting at the tip, pointing up or down.
local function ChevronParts(button, up)
    local angle = up and 45 or -45
    return { Modern.GlyphLine(button, STROKE, 2, -2, 0, angle), Modern.GlyphLine(button, STROKE, 2, 2, 0, -angle) }
end

local function PaintArrow(button)
    local state = arrows[button]
    if not state then return end
    local theme = Modern.Theme()
    local parts = state.skin:Own(button, "scroll arrow", function() return ChevronParts(button, state.up) end)
    local color = not Enabled(button) and theme.wellEdge or hovered[button] and theme.text or theme.accent
    for _, line in ipairs(parts) do
        line:SetColorTexture(unpack(color))
        line:Show()
    end
end

local function Arrow(skin, button, up)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    if ns.Usable(button.Texture) and type(button.Texture.SetAlpha) == "function" then skin:Hold(button.Texture) end
    arrows[button] = { skin = skin, up = up }
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
    Arrow(skin, bar.Back, true)
    Arrow(skin, bar.Forward, false)
end
