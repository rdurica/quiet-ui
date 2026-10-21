local _, ns = ...

-- Controls of the character window: the model scene buttons (zoom, rotate, reset) and the stats pane toggle. Their
-- gold art does not fit the grey glyphs of the window chrome: a model button loses its square box and keeps its icon
-- desaturated in the glyph grey, light under the mouse; the pane toggle becomes a bare chevron that points left while
-- the stats pane is open (it collapses the window) and right while it is closed.

local Modern = ns.Modern
local Character = Modern.Character

local BOX = { "NormalTexture", "PushedTexture", "HighlightTexture" }
local CHEVRON = 8

local tinted = setmetatable({}, { __mode = "k" })  -- icon -> true while applied
local pointing = setmetatable({}, { __mode = "k" }) -- pane toggle -> { skin, frame } while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Tint(button, over)
    local icon = button.Icon
    if not tinted[icon] then return end
    local theme = Modern.Theme()
    icon:SetVertexColor(unpack(over and theme.text or theme.glyph))
end

local function Desaturate(skin, icon)
    if type(icon.SetDesaturated) ~= "function" then return end
    local was = type(icon.IsDesaturated) == "function" and icon:IsDesaturated() or false
    skin:Remember(icon, "modern desaturated", function() icon:SetDesaturated(was) end)
    icon:SetDesaturated(true)
end

local function ModelButton(skin, button)
    local icon = button.Icon
    if not ns.Usable(icon) or type(icon.SetVertexColor) ~= "function" then return end
    for _, key in ipairs(BOX) do
        if ns.Usable(button[key]) then skin:Hold(button[key]) end
    end
    Desaturate(skin, icon)
    skin:Set(icon, "SetVertexColor", unpack(Modern.Theme().glyph))
    tinted[icon] = true
    skin:Remember(icon, "modern tint", function() tinted[icon] = nil end)
    if hooked[button] or type(button.HookScript) ~= "function" then return end
    hooked[button] = true
    for script, over in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function() ns.Run("modern character", Tint, button, over) end)
    end
end

-- Two strokes meeting at the tip; Point turns them.
local function ChevronParts(button)
    return { Modern.GlyphLine(button, CHEVRON, 2, 0, 2.5), Modern.GlyphLine(button, CHEVRON, 2, 0, -2.5) }
end

local function PaneOpen(frame)
    local host = frame.RightPaneHost
    if not ns.Usable(host) or type(host.IsShown) ~= "function" then return true end
    return host:IsShown() and true or false
end

-- Open: the upper stroke rises to the right, so the tip points left; closed: mirrored.
local function Point(toggle)
    local state = pointing[toggle]
    if not state then return end
    local parts = state.skin:Own(toggle, "pane toggle", function() return ChevronParts(toggle) end)
    local angle = PaneOpen(state.frame) and 45 or -45
    for index, line in ipairs(parts) do
        if type(line.SetRotation) == "function" then
            pcall(line.SetRotation, line, math.rad(index == 1 and angle or -angle))
        end
    end
end

local function PaneToggle(skin, frame, toggle)
    Modern.GlyphButton(skin, toggle, "pane toggle", ChevronParts, "text")
    pointing[toggle] = { skin = skin, frame = frame }
    skin:Remember(toggle, "modern pane toggle", function() pointing[toggle] = nil end)
    Point(toggle)
    if hooked[toggle] then return end
    hooked[toggle] = true
    local function Again() ns.Run("modern character", Point, toggle) end
    if type(toggle.HookScript) == "function" then pcall(toggle.HookScript, toggle, "OnClick", Again) end
    local host = frame.RightPaneHost
    if ns.Usable(host) and type(host.HookScript) == "function" then
        pcall(host.HookScript, host, "OnShow", Again)
        pcall(host.HookScript, host, "OnHide", Again)
    end
end

function Character.Controls(skin, frame)
    local scene = _G.CharacterModelScene
    local controls = ns.Usable(scene) and scene.ControlFrame
    for _, button in ipairs(Character.Children(controls)) do
        if ns.Usable(button) and button.Icon then ModelButton(skin, button) end
    end
    local toggle = frame.RightPaneToggleButton or _G.CharacterFrameRightPaneToggleButton
    if ns.Usable(toggle) then PaneToggle(skin, frame, toggle) end
end
