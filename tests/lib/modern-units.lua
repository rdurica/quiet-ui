-- Client-shaped unit-frame fixtures for the public Modern area contract.
local U = {}

local function texture(parent, name)
    local art = parent:CreateTexture(nil, "ARTWORK")
    art:SetTexture("Interface\\TargetingFrame\\" .. name)
    art:SetAlpha(0.7)
    return art
end

local function bar(parent, name)
    local value = CreateFrame("StatusBar", nil, parent)
    value:SetSize(91, 11)
    local statusTexture = texture(value, name .. "Texture")
    statusTexture:SetTexture("Interface\\TargetingFrame\\" .. name)
    value._statusColor = { 0.2, 0.4, 0.6, 1 }
    function value:SetStatusBarTexture(v) statusTexture:SetTexture(v) end
    function value:GetStatusBarTexture() return statusTexture end
    function value:SetStatusBarColor(...) self._statusColor = { ... } end
    function value:GetStatusBarColor() return unpack(self._statusColor) end
    return value
end

local function portrait(parent, name)
    local icon = texture(parent, name .. "Portrait")
    -- Textures cannot own regions; their mask API exposes texture objects instead.
    icon.CreateTexture = nil
    local mask = texture(UIParent, name .. "PortraitMask")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    local masks = { mask }
    function icon:GetNumMaskTextures() return #masks end
    function icon:GetMaskTexture(index) return masks[index] end
    function icon:AddMaskTexture(nextMask) masks[#masks + 1] = nextMask end
    function icon:RemoveMaskTexture(mask)
        for i, current in ipairs(masks) do
            if current == mask then table.remove(masks, i); return end
        end
    end
    return icon
end

local function frame(name, unit)
    local f = CreateFrame("Frame", name, UIParent)
    f.unit = unit
    f:SetSize(170, 48)
    f.Border = texture(f, name .. "Border")
    f.Flash = texture(f, name .. "Flash")
    f.Background = texture(f, name .. "Background")
    f.EliteTexture = texture(f, name .. "Elite")
    f.HealthBar = bar(f, name .. "Health")
    f.ManaBar = bar(f, name .. "Power")
    f.Portrait = portrait(f, name)
    f.Name = f:CreateFontString(nil, "OVERLAY")
    f.Level = f:CreateFontString(nil, "OVERLAY")
    return f
end

function U.frames()
    local frames = {
        frame("PlayerFrame", "player"),
        frame("PetFrame", "pet"),
        frame("TargetFrame", "target"),
        frame("TargetFrameToT", "targettarget"),
        frame("FocusFrame", "focus"),
    }
    for _, f in ipairs(frames) do _G[f:GetName()] = f end
    return frames
end

-- Small public fixture surface for the generic registry contract.
function U.fixture()
    local frames = U.frames()
    return { frames = frames, player = frames[1], pet = frames[2], target = frames[3],
        targetTarget = frames[4], focus = frames[5] }
end

function U.hidden(frame)
    for _, art in ipairs({ frame.Border, frame.Flash, frame.Background, frame.EliteTexture }) do
        if art:GetAlpha() ~= 0 then return false end
    end
    return true
end

function U.border(frame)
    local count = 0
    for _, region in ipairs(frame._regions) do
        if region._layer == "BORDER" and region._shown then count = count + 1 end
    end
    return count >= 4
end

function U.portraitBorder(frame)
    local count = 0
    for _, region in ipairs(frame._regions) do
        if region._layer == "BORDER" and region._shown then
            for _, point in ipairs(region._points) do
                if point[2] == frame.Portrait then count = count + 1; break end
            end
        end
    end
    return count >= 4
end

function U.portraitBorderColor(frame)
    for _, region in ipairs(frame._regions) do
        if region._layer == "BORDER" and region._shown and region._color then
            for _, point in ipairs(region._points) do
                if point[2] == frame.Portrait then return region._color end
            end
        end
    end
end

function U.panel(frame)
    for _, region in ipairs(frame._regions) do
        if region._layer == "BACKGROUND" and region._shown and region._color then return true end
    end
    return false
end

function U.colour(bar)
    return bar._statusColor[1], bar._statusColor[2], bar._statusColor[3], bar._statusColor[4]
end

function U.statusTexture(bar)
    local texture = bar:GetStatusBarTexture()
    return texture and texture:GetTexture()
end

function U.classify(mock, kind)
    mock:setUnit("target", { exists = true, player = kind == "player", classification = kind })
end

return U
