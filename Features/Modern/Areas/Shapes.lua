local _, ns = ...

-- Blizzard's shared templates inside a window, recognised by their keys (Forever UI source, 1.60.1): panel and side
-- tabs, minimal and old slider scroll bars, item buttons and the slot cards around them, three-piece buttons, input
-- boxes and money edges, nine-piece input borders, dropdowns, square icon buttons, checkboxes, inner panels and
-- nested windows. A window is walked once per apply and again when it shows or one of its lists updates, so an
-- area names only what is particular to its window. Content art (icons, models, maps, tree and page art) has none
-- of these shapes and stays.
--
--   Shapes.Walk(skin, frame, opts)  opts: bare = { [frame] = true } (art held, no fill or border),
--                                         shape(skin, frame) -> true when the area handled the frame itself
--   Shapes.Watch(root, key, again, list)  again() on root's OnShow, list(box) on every list update under it
--   Shapes.Keep(skin, frame, key, fn, opts)  fn(skin, frame) now and on every show, a walk of a list when it
--                                           updates, while applied

local Modern = ns.Modern
local Shapes = {}
Modern.Shapes = Shapes

local MAX_DEPTH = 12
local PIECES = { "Left", "Middle", "Center", "Right", "left", "middle", "right" }
-- The nine pieces of an input scroll frame (InputScrollFrameTemplate) and of the friends broadcast box.
local INPUT_KEYS = { "TopLeftTex", "TopRightTex", "TopTex", "BottomLeftTex", "BottomRightTex", "BottomTex", "LeftTex",
    "RightTex", "MiddleTex", "TopLeftBorder", "TopRightBorder", "TopBorder", "BottomLeftBorder", "BottomRightBorder",
    "BottomBorder", "LeftBorder", "RightBorder", "MiddleBorder" }
-- UIMenuButtonStretchTemplate: a nine-piece silver button (decline, delist).
local STRETCH_KEYS = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
    "BottomMiddle", "MiddleMiddle" }
-- Buttons whose whole art is one plate, by atlas or file name: square icon plates and the static popup buttons.
local SQUARE_ART = { "squarebutton", "button-tertiary-square", "ui-dialogbox-button" }
-- The plate of a 12.0 list row (who list, group finder): rows stand bare, their hover and selection stay.
local ROW_ART = "common-button-list"
-- Slot art around an item button that the button itself does not own.
local SLOT_KEYS = { "EmptyBackground", "Background", "SlotTexture" }
local SLOT_SUFFIXES = { "Slot", "SlotTexture", "NameFrame" }
local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
-- Flat buttons light up under the mouse: a faint wash in their own HIGHLIGHT layer.
local HOVER = { 1, 1, 1, 0.07 }

local hooked = setmetatable({}, { __mode = "k" })
local kept = setmetatable({}, { __mode = "k" })    -- window -> { skin, fn } while its area is applied

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function KindOf(frame)
    return type(frame.GetObjectType) == "function" and frame:GetObjectType() or nil
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function NameOf(frame)
    local name = type(frame.GetName) == "function" and frame:GetName()
    return type(name) == "string" and name or nil
end

-- A keyed piece, or the named one (`<name>Left`) of templates that only name their art.
local function Piece(frame, key)
    if IsTexture(rawget(frame, key)) then return frame[key] end
    local name = NameOf(frame)
    if name and IsTexture(_G[name .. key]) then return _G[name .. key] end
end

local function FileOf(texture)
    if not IsTexture(texture) then return nil end
    for _, getter in ipairs({ "GetAtlas", "GetTexture" }) do
        if type(texture[getter]) == "function" then
            local ok, value = pcall(texture[getter], texture)
            if ok and type(value) == "string" then return value:lower() end
        end
    end
end

local function Art(button, getter)
    if type(button[getter]) ~= "function" then return nil end
    local ok, texture = pcall(button[getter], button)
    return ok and IsTexture(texture) and texture or nil
end

local function Children(frame)
    if type(frame.GetChildren) ~= "function" then return {} end
    return { frame:GetChildren() }
end

-- Blizzard's highlight goes; a faint wash in the button's own HIGHLIGHT layer shows under the mouse instead.
function Shapes.Hover(skin, button)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    Hold(skin, Art(button, "GetHighlightTexture"))
    local wash = skin:Own(button, "hover", function()
        local texture = button:CreateTexture(nil, "HIGHLIGHT")
        texture:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        return texture
    end)
    if wash then
        wash:SetColorTexture(unpack(HOVER))
        wash:Show()
    end
end

function Shapes.IsField(frame)
    return Piece(frame, "Left") ~= nil and Piece(frame, "Right") ~= nil
        or IsTexture(rawget(frame, "left")) and IsTexture(rawget(frame, "right"))
end

-- A three-piece button, input box or status bar: its pieces are held, the rest becomes a dark field with a thin border
-- (a button also lights up under the mouse). A bare one keeps only its content; a money edge (ThinGoldEdgeTemplate)
-- is always bare, so coins stand as text on the panel.
function Shapes.Field(skin, frame, bare)
    if not ns.Usable(frame) then return end
    bare = bare or (FileOf(Piece(frame, "Left")) or ""):find("moneyframe", 1, true) ~= nil
    for _, key in ipairs(PIECES) do Hold(skin, Piece(frame, key)) end
    if KindOf(frame) == "StatusBar" then Hold(skin, Piece(frame, "Background")) end
    if bare then return end
    skin:Panel(frame)
    skin:Border(frame)
    if KindOf(frame) == "Button" then Shapes.Hover(skin, frame) end
end

local function Any(frame, keys)
    for _, key in ipairs(keys) do
        if IsTexture(rawget(frame, key)) then return true end
    end
    return false
end

-- A button whose whole art is a square plate (the refresh and options buttons): it keeps its icon.
local function IsSquare(button)
    local file = FileOf(Art(button, "GetNormalTexture"))
    if not file then return false end
    for _, needle in ipairs(SQUARE_ART) do
        if file:find(needle, 1, true) then return true end
    end
    return false
end

function Shapes.Square(skin, button)
    if not ns.Usable(button) then return end
    for _, getter in ipairs(BUTTON_ART) do Hold(skin, Art(button, getter)) end
    skin:Panel(button)
    skin:Border(button)
    Shapes.Hover(skin, button)
end

-- An item button and the slot art that sits around it.
local function Item(skin, button)
    for _, key in ipairs(SLOT_KEYS) do Hold(skin, rawget(button, key)) end
    local name = NameOf(button)
    if name then
        for _, suffix in ipairs(SLOT_SUFFIXES) do
            local texture = _G[name .. suffix]
            if texture ~= (button.icon or button.Icon) then Hold(skin, texture) end
        end
    end
    -- Equipment slots (inspect) carry their gear-slot art on a BorderFrame.
    if ns.Usable(rawget(button, "BorderFrame")) then Modern.Character.HoldArt(skin, button.BorderFrame) end
    Modern.Bags.Item(skin, button)
end

-- A slot card (trade, merchant style): the slot and name plate go, the name and the item button stay.
local function Card(skin, card)
    Hold(skin, card.SlotTexture)
    local name = NameOf(card)
    if name then Hold(skin, _G[name .. "NameFrame"]) end
end

-- A tooltip-like frame inside a window (FriendsTooltip) keeps Blizzard's backdrop: it floats over the content.
local function IsTip(frame)
    local name = NameOf(frame)
    return name ~= nil and name:find("Tooltip", 1, true) ~= nil
end

-- An inner panel: its chrome is held and a thin border keeps the sections apart. A nested window (a portrait frame
-- inside the window) gets the whole window treatment; a popout in a dialog border (the friends broadcast box)
-- floats over the content, so it keeps a dark panel of its own.
local function Panel(skin, frame, bare)
    if ns.Usable(frame.PortraitContainer) or ns.Usable(frame.TitleContainer) and ns.Usable(frame.CloseButton) then
        Modern.Window(skin, frame)
        Modern.Header(skin, frame)
        return
    end
    if ns.Usable(rawget(frame, "Border")) and not IsTexture(frame.Border) and not ns.Usable(rawget(frame, "NineSlice")) then
        Modern.Window(skin, frame)
        return
    end
    Modern.WindowChrome(skin, frame)
    if not bare then skin:Border(frame) end
end

-- One frame by its shape; true when its children need no walk.
function Shapes.One(skin, frame, opts)
    local bare = opts.bare and opts.bare[frame]
    if opts.shape and opts.shape(skin, frame) then return true end
    if IsTip(frame) then return true end
    local kind = KindOf(frame)
    if IsTexture(rawget(frame, "LeftActive")) and IsTexture(rawget(frame, "Left")) then
        Modern.TabChrome(skin, frame)
        return true
    end
    if ns.Usable(rawget(frame, "Track")) then
        Modern.Character.ScrollBar(skin, frame)
        return true
    end
    if ns.Usable(rawget(frame, "ScrollUpButton")) and ns.Usable(rawget(frame, "ScrollDownButton")) then
        Modern.SliderBar(skin, frame)
        return true
    end
    if IsTexture(rawget(frame, "IconBorder")) and (IsTexture(rawget(frame, "icon")) or IsTexture(rawget(frame, "Icon"))) then
        Item(skin, frame)
        return true
    end
    if kind == "CheckButton" and Modern.IsCheckbox(frame) then
        Modern.Checkbox(skin, frame)
        return true
    end
    if IsTexture(rawget(frame, "SlotTexture")) then Card(skin, frame) end
    -- A field's children are walked too: a column header can carry a dropdown, an input box its clear button.
    if Shapes.IsField(frame) then
        Shapes.Field(skin, frame, bare)
    elseif Any(frame, INPUT_KEYS) then
        for _, key in ipairs(INPUT_KEYS) do Hold(skin, rawget(frame, key)) end
        if not bare then
            skin:Panel(frame, Modern.Theme().track)
            skin:Border(frame)
        end
    elseif kind == "Button" and Any(frame, STRETCH_KEYS) then
        for _, key in ipairs(STRETCH_KEYS) do Hold(skin, rawget(frame, key)) end
        skin:Panel(frame)
        skin:Border(frame)
        Shapes.Hover(skin, frame)
    elseif (kind == "Button" or kind == "DropdownButton") and IsTexture(rawget(frame, "Background"))
        and not frame.NineSlice and not IsTexture(rawget(frame, "SelectedTexture")) then
        skin:Hold(frame.Background)
        if (FileOf(frame.Background) or ""):find(ROW_ART, 1, true) then return false end
        -- A dropdown: its text holder goes behind a dark field, the arrow and the reset button stay.
        skin:Panel(frame)
        skin:Border(frame)
        Shapes.Hover(skin, frame)
        return true
    elseif kind == "Button" and IsSquare(frame) then
        Shapes.Square(skin, frame)
    elseif IsTexture(rawget(frame, "SelectedTexture")) and IsTexture(rawget(frame, "Background")) then
        -- A large side tab (common-sidetab art) keeps its icon inside a flat tab.
        Modern.TabChrome(skin, frame)
        return true
    end
    if ns.Usable(rawget(frame, "TabSystem")) then Modern.TabSystemChrome(skin, frame) end
    if ns.Usable(rawget(frame, "NineSlice")) or ns.Usable(rawget(frame, "Border")) and not IsTexture(frame.Border) then
        Panel(skin, frame, bare)
    end
    return false
end

-- Every texture under `frame` whose atlas or file name contains one of `needles` (loose art that templates do not
-- key: parchment, stationery, divider bars, stone backdrops).
function Shapes.HoldArt(skin, frame, needles, depth)
    depth = depth or 0
    if not ns.Usable(frame) or depth > MAX_DEPTH then return end
    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            local file = FileOf(region)
            if file then
                for _, needle in ipairs(needles) do
                    if file:find(needle, 1, true) then
                        skin:Hold(region)
                        break
                    end
                end
            end
        end
    end
    for _, child in ipairs(Children(frame)) do Shapes.HoldArt(skin, child, needles, depth + 1) end
end

function Shapes.Walk(skin, frame, opts, depth)
    depth = depth or 0
    if not ns.Usable(frame) or depth > MAX_DEPTH then return end
    opts = opts or {}
    -- The window itself is skinned by its area; the walk starts with its children.
    if depth > 0 and Shapes.One(skin, frame, opts) then return end
    for _, child in ipairs(Children(frame)) do Shapes.Walk(skin, child, opts, depth + 1) end
end

local function WatchLists(frame, list, depth)
    if not ns.Usable(frame) or depth > MAX_DEPTH then return end
    local box = rawget(frame, "ScrollBox")
    if ns.Usable(box) and not hooked[box] and type(box.Update) == "function" then
        hooked[box] = true
        pcall(hooksecurefunc, box, "Update", function() list(box) end)
    end
    for _, child in ipairs(Children(frame)) do WatchLists(child, list, depth + 1) end
end

-- Hooks are set once per session per frame; `again` and `list` must do nothing while their area is off. A list
-- updates on every scroll, so it is walked alone (`list(box)`, the whole window again when `list` is omitted).
function Shapes.Watch(root, key, again, list)
    if not ns.Usable(root) then return end
    local label = "modern " .. key
    local function Run() ns.Profiler.Run(label, again) end
    if not hooked[root] then
        hooked[root] = true
        if type(root.HookScript) == "function" then pcall(root.HookScript, root, "OnShow", Run) end
    end
    WatchLists(root, list and function(box) ns.Profiler.Run(label, list, box) end or Run, 0)
end

-- A window skinned by `fn(skin, frame)` now and again whenever it shows or a list under it updates, until its area
-- is restored. Returns the function that skins it again, for an area's own refill hooks.
function Shapes.Keep(skin, frame, key, fn, opts)
    if not ns.Usable(frame) then return end
    kept[frame] = { skin = skin, fn = fn, opts = opts }
    skin:Remember(frame, "modern kept", function() kept[frame] = nil end)
    fn(skin, frame)
    local function Again()
        local entry = kept[frame]
        if entry then entry.fn(entry.skin, frame) end
    end
    Shapes.Watch(frame, key, Again, function(box)
        local entry = kept[frame]
        if entry then Shapes.Walk(entry.skin, box, entry.opts) end
    end)
    return Again
end
