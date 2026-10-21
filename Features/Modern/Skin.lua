local _, ns = ...

-- The change journal of one area. Every helper records what it replaced, once per object and
-- property, and Undo replays that in reverse, so restoring an area never touches another one.

local Modern = ns.Modern

local Skin = {}
Skin.__index = Skin
local journals = {}

local EDGES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }
local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

local function Pack(...)
    return { n = select("#", ...), ... }
end

-- A missing frame is skipped silently; a missing method is reported once per helper kind.
local function Ready(kind, obj, ...)
    if obj == nil or not ns.Usable(obj) then return false end
    for i = 1, select("#", ...) do
        local method = select(i, ...)
        if type(obj[method]) ~= "function" then
            ns.Report("modern " .. kind, "missing " .. method)
            return false
        end
    end
    return true
end

-- True the first time this object and property are changed since the last Undo.
local function First(self, obj, prop)
    local seen = self.seen[obj]
    if not seen then
        seen = {}
        self.seen[obj] = seen
    end
    if seen[prop] then return false end
    seen[prop] = true
    return true
end

local function Push(self, undo)
    self.entries[#self.entries + 1] = undo
end

-- Public escape hatch for a client API whose previous state is not exposed by
-- a conventional GetX method.  `undo` is recorded once for this object/key.
function Skin:Remember(obj, key, undo)
    if ns.Usable(obj) and type(key) == "string" and type(undo) == "function" and First(self, obj, key) then
        Push(self, undo)
        return true
    end
    return false
end

function Modern.Skin(key)
    local skin = journals[key]
    if not skin then
        skin = setmetatable({ key = key, entries = {}, seen = setmetatable({}, { __mode = "k" }),
            regions = setmetatable({}, { __mode = "k" }) }, Skin)
        journals[key] = skin
    end
    return skin
end

-- Texture crop that hides the icon's rounded border.
function Skin:Icon(texture)
    if not Ready("Icon", texture, "SetTexCoord", "GetTexCoord") then return end
    if First(self, texture, "texcoord") then
        local prev = Pack(texture:GetTexCoord())
        Push(self, function() texture:SetTexCoord(unpack(prev, 1, prev.n)) end)
    end
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- Any other change: Set(object, "SetX", ...) pairs with GetX for the previous value.
function Skin:Set(obj, method, ...)
    if type(method) ~= "string" then return end
    if not Ready("Set", obj, method) then return end
    if method == "SetPoint" then
        if First(self, obj, method) and type(obj.GetNumPoints) == "function" and type(obj.GetPoint) == "function"
            and type(obj.ClearAllPoints) == "function" then
            local points = {}
            for i = 1, obj:GetNumPoints() do points[i] = Pack(obj:GetPoint(i)) end
            Push(self, function()
                obj:ClearAllPoints()
                for _, p in ipairs(points) do obj:SetPoint(unpack(p, 1, p.n)) end
            end)
        end
        obj:SetPoint(...)
        return
    end
    local getter = "Get" .. method:sub(4)
    if method:sub(1, 3) ~= "Set" or type(obj[getter]) ~= "function" then
        ns.Report("modern Set", method .. " has no " .. getter .. " to remember the old value")
        return
    end
    if First(self, obj, method) then
        local prev = Pack(obj[getter](obj))
        Push(self, function() obj[method](obj, unpack(prev, 1, prev.n)) end)
    end
    obj[method](obj, ...)
end

-- Adds the outline flag to a font object's flags, keeping face and size.
function Skin:Outline(font)
    if not ns.Usable(font) or type(font.GetFont) ~= "function" or type(font.SetFont) ~= "function" then return end
    local ok, face, size, flags = pcall(font.GetFont, font)
    if not ok then return end
    flags = type(flags) == "string" and flags or ""
    if flags:find("OUTLINE", 1, true) then return end
    self:Set(font, "SetFont", face, size, flags == "" and "OUTLINE" or (flags .. ",OUTLINE"))
end

-- Art held at alpha 0 (or the given alpha) against Blizzard's SetAlpha, released by Undo.
function Skin:Hold(texture, alpha)
    if not Ready("Hold", texture, "SetAlpha", "GetAlpha") then return end
    if First(self, texture, "hold") then
        Push(self, function() ns.ReleaseAlpha(texture, true) end)
    end
    ns.HoldAlpha(texture, alpha or 0)
end

-- Own regions are created once per frame, hidden by Undo and reused.
local function OwnRegion(self, frame, name, create)
    local own = self.regions[frame]
    if not own then
        own = {}
        self.regions[frame] = own
    end
    if not own[name] then own[name] = create() end
    return own[name]
end

function Skin:Own(frame, key, create)
    if not ns.Usable(frame) or type(key) ~= "string" or type(create) ~= "function" then return end
    local region = OwnRegion(self, frame, key, create)
    self:Remember(frame, "own:" .. key, function()
        if type(region) == "table" and type(region.Hide) == "function" then
            region:Hide()
        elseif type(region) == "table" then
            for _, item in ipairs(region) do if ns.Usable(item) and type(item.Hide) == "function" then item:Hide() end end
        end
    end)
    return region
end

-- True when `region` is one this journal created on `frame` (Own, Panel or Border).
function Skin:Owns(frame, region)
    for _, own in pairs(self.regions[frame] or {}) do
        if own == region then return true end
        -- A list of regions, not a region itself.
        if type(own) == "table" and own.GetObjectType == nil then
            for _, item in ipairs(own) do if item == region then return true end end
        end
    end
    return false
end

local function Hideable(self, frame, name, regions)
    if First(self, frame, name) then
        Push(self, function()
            for _, region in ipairs(regions) do region:Hide() end
        end)
    end
end

-- A texture cannot create children, so its border belongs to the nearest frame.
local function BorderOwner(frame)
    if not ns.Usable(frame) then return frame end
    local isTexture = type(frame.GetObjectType) == "function" and frame:GetObjectType() == "Texture"
    if (isTexture or type(frame.CreateTexture) ~= "function") and type(frame.GetParent) == "function" then
        local ok, parent = pcall(frame.GetParent, frame)
        return ok and parent or nil
    end
    return frame
end

-- One physical pixel at the line's scale, off the pixel grid: a 1-unit line at a fractional position (a 25.99-unit
-- settings checkbox) or in a scaled-down window can otherwise snap to nothing.
local function Hairline(line)
    local size = 1
    if type(PixelUtil) == "table" and type(PixelUtil.GetNearestPixelSize) == "function"
        and type(line.GetEffectiveScale) == "function" then
        local ok, scaled = pcall(PixelUtil.GetNearestPixelSize, 1, line:GetEffectiveScale(), 1)
        if ok and type(scaled) == "number" and scaled > 0 then size = scaled end
    end
    return size
end

-- The border follows the edges of `anchor` (default: the frame itself).
function Skin:Border(frame, color, anchor)
    anchor = anchor or frame
    local owner = BorderOwner(frame)
    if not Ready("Border", owner, "CreateTexture") or not ns.Usable(anchor) then return end
    local theme = Modern.Theme()
    local edges = OwnRegion(self, owner, "border:" .. tostring(anchor), function()
        local list = {}
        for _, edge in ipairs(EDGES) do
            local line = owner:CreateTexture(nil, "OVERLAY", nil, 7)
            if type(line.SetSnapToPixelGrid) == "function" then pcall(line.SetSnapToPixelGrid, line, false) end
            if type(line.SetTexelSnappingBias) == "function" then pcall(line.SetTexelSnappingBias, line, 0) end
            if edge == "TOP" or edge == "BOTTOM" then
                line:SetHeight(1)
                line:SetPoint(edge .. "LEFT", anchor, edge .. "LEFT", 0, 0)
                line:SetPoint(edge .. "RIGHT", anchor, edge .. "RIGHT", 0, 0)
            else
                line:SetWidth(1)
                line:SetPoint("TOP" .. edge, anchor, "TOP" .. edge, 0, 0)
                line:SetPoint("BOTTOM" .. edge, anchor, "BOTTOM" .. edge, 0, 0)
            end
            list[#list + 1] = line
        end
        return list
    end)
    for index, line in ipairs(edges) do
        local edge = EDGES[index]
        if edge == "TOP" or edge == "BOTTOM" then line:SetHeight(Hairline(line)) else line:SetWidth(Hairline(line)) end
        line:SetColorTexture(unpack(color or theme.border))
        line:Show()
    end
    Hideable(self, owner, "border:" .. tostring(anchor), edges)
end

-- Themed fill (or `color`) behind a frame whose own art is held hidden; returns the fill.
function Skin:Panel(frame, color)
    if not Ready("Panel", frame, "CreateTexture") then return end
    local theme = Modern.Theme()
    local fill = OwnRegion(self, frame, "panel", function()
        local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetAllPoints(frame)
        return texture
    end)
    fill:SetColorTexture(unpack(color or theme.bg))
    fill:Show()
    Hideable(self, frame, "panel", { fill })
    return fill
end

-- Flat button: the Blizzard art is held hidden, a themed fill and border replace it.
function Skin:Button(button)
    if not Ready("Button", button, "CreateTexture") then return end
    for _, getter in ipairs(BUTTON_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and texture then self:Hold(texture) end
        end
    end
    self:Panel(button)
    self:Border(button)
end

function Skin:Undo()
    local entries = self.entries
    self.entries = {}
    self.seen = setmetatable({}, { __mode = "k" })
    for i = #entries, 1, -1 do
        local ok, err = pcall(entries[i])
        if not ok then ns.Report("modern undo " .. tostring(self.key), err) end
    end
end
