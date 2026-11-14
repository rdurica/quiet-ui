local _, ns = ...

-- The pooled rows of the friends list: a friend card stands bare (card and highlight held) with a quiet rule under
-- it, a faint wash under the mouse and an accent edge on the left while Blizzard marks it selected (the row's locked
-- highlight, followed through LockHighlight / UnlockHighlight). The group header becomes a section strip with an
-- accent minus, a plus while collapsed (the atlas of its CollapseButton icon).

local Modern = ns.Modern
local Rows = {}
Modern.SocialRows = Rows

local SIGN = 10
local EDGE = 2

local selected = setmetatable({}, { __mode = "k" })  -- row -> true while Blizzard marks it selected
local rows = setmetatable({}, { __mode = "k" })      -- row -> skin while applied
local signs = setmetatable({}, { __mode = "k" })     -- header -> skin while applied
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function Plates(skin, button)
    if ns.Usable(button) then Modern.SocialWindow.HoldPlates(skin, button) end
end

local function PaintEdge(row)
    local skin = rows[row]
    if not skin then return end
    local edge = skin:Own(row, "friend edge", function()
        local texture = row:CreateTexture(nil, "OVERLAY")
        texture:SetWidth(EDGE)
        texture:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        texture:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        return texture
    end)
    if not edge then return end
    edge:SetColorTexture(unpack(Modern.Theme().accent))
    edge:SetShown(selected[row] == true)
end

local function Follow(row)
    if hooked[row] then return end
    hooked[row] = true
    local function Set(value)
        return function()
            if not rows[row] then return end
            selected[row] = value
            ns.Profiler.Run("modern social", PaintEdge, row)
        end
    end
    pcall(hooksecurefunc, row, "LockHighlight", Set(true))
    pcall(hooksecurefunc, row, "UnlockHighlight", Set(false))
end

-- A friend card: keyed Background, a FriendName and a highlight getter.
local function IsRow(frame)
    return IsTexture(rawget(frame, "Background")) and ns.Usable(rawget(frame, "PartyButton"))
        and rawget(frame, "FriendName") ~= nil and type(frame.LockHighlight) == "function"
end

function Rows.Row(skin, frame)
    if not IsRow(frame) then return false end
    Hold(skin, frame.Background)
    Modern.Shapes.Hover(skin, frame)
    Plates(skin, rawget(frame, "PartyButton"))
    local rule = skin:Own(frame, "friend rule", function()
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetHeight(1)
        texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        return texture
    end)
    if rule then
        rule:SetColorTexture(unpack(Modern.Theme().border))
        rule:Show()
    end
    rows[frame] = skin
    skin:Remember(frame, "friend row", function()
        rows[frame] = nil
        selected[frame] = nil
    end)
    Follow(frame)
    PaintEdge(frame)
    return true
end

local function IsPlus(icon)
    if type(icon.GetAtlas) ~= "function" then return false end
    local ok, atlas = pcall(icon.GetAtlas, icon)
    return ok and type(atlas) == "string" and atlas:lower():find("plus", 1, true) ~= nil
end

local function PaintSign(header)
    local skin = signs[header]
    if not skin then return end
    local button = header.CollapseButton
    local parts = skin:Own(button, "friend sign", function()
        return { Modern.GlyphLine(button, SIGN, 2), Modern.GlyphLine(button, 2, SIGN) }
    end)
    for _, line in ipairs(parts) do line:SetColorTexture(unpack(Modern.Theme().accent)) end
    parts[1]:Show()
    parts[2]:SetShown(IsPlus(button.Icon))
end

-- A group header (Friends List 1/6): a CollapseButton whose Icon swaps minus / plus.
function Rows.Header(skin, frame)
    local button = rawget(frame, "CollapseButton")
    if not ns.Usable(button) or not IsTexture(rawget(button, "Icon")) or rawget(frame, "ButtonText") == nil then
        return false
    end
    Plates(skin, frame)
    Plates(skin, button)
    Hold(skin, button.Icon)
    Modern.Strip(skin, frame)
    signs[frame] = skin
    skin:Remember(frame, "friend header", function() signs[frame] = nil end)
    PaintSign(frame)
    if not hooked[frame] then
        hooked[frame] = true
        pcall(hooksecurefunc, button.Icon, "SetAtlas", function()
            if signs[frame] then ns.Profiler.Run("modern social", PaintSign, frame) end
        end)
    end
    return true
end

function Rows.Pool(skin, box)
    local target = ns.Usable(box) and rawget(box, "ScrollTarget")
    if not ns.Usable(target) or type(target.GetChildren) ~= "function" then return end
    for _, child in ipairs({ target:GetChildren() }) do
        if ns.Usable(child) and not Rows.Row(skin, child) then Rows.Header(skin, child) end
    end
end
