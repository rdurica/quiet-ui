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

function Modern.Skin(key)
    local skin = journals[key]
    if not skin then
        skin = setmetatable({ key = key, entries = {}, seen = {}, regions = {} }, Skin)
        skin.seen = setmetatable({}, { __mode = "k" })
        skin.regions = setmetatable({}, { __mode = "k" })
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

-- Art held at alpha 0 against Blizzard's SetAlpha, released by Undo.
function Skin:Hold(texture)
    if not Ready("Hold", texture, "SetAlpha", "GetAlpha") then return end
    if First(self, texture, "hold") then
        Push(self, function() ns.ReleaseAlpha(texture, true) end)
    end
    ns.HoldAlpha(texture, 0)
end

-- Own regions are created once per frame, hidden by Undo and reused.
local function Own(self, frame, name, create)
    local own = self.regions[frame]
    if not own then
        own = {}
        self.regions[frame] = own
    end
    if not own[name] then own[name] = create() end
    return own[name]
end

local function Hideable(self, frame, name, regions)
    if First(self, frame, name) then
        Push(self, function()
            for _, region in ipairs(regions) do region:Hide() end
        end)
    end
end

function Skin:Border(frame)
    if not Ready("Border", frame, "CreateTexture") then return end
    local theme = Modern.Theme()
    local edges = Own(self, frame, "border", function()
        local list = {}
        for _, edge in ipairs(EDGES) do
            local line = frame:CreateTexture(nil, "BORDER")
            if edge == "TOP" or edge == "BOTTOM" then
                line:SetHeight(1)
                line:SetPoint(edge .. "LEFT", frame, edge .. "LEFT", 0, 0)
                line:SetPoint(edge .. "RIGHT", frame, edge .. "RIGHT", 0, 0)
            else
                line:SetWidth(1)
                line:SetPoint("TOP" .. edge, frame, "TOP" .. edge, 0, 0)
                line:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge, 0, 0)
            end
            list[#list + 1] = line
        end
        return list
    end)
    for _, line in ipairs(edges) do
        line:SetColorTexture(unpack(theme.border))
        line:Show()
    end
    Hideable(self, frame, "border", edges)
end

-- Themed fill behind a frame whose own art is held hidden.
function Skin:Panel(frame)
    if not Ready("Panel", frame, "CreateTexture") then return end
    local theme = Modern.Theme()
    local fill = Own(self, frame, "panel", function()
        local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetAllPoints(frame)
        return texture
    end)
    fill:SetColorTexture(unpack(theme.bg))
    fill:Show()
    Hideable(self, frame, "panel", { fill })
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
