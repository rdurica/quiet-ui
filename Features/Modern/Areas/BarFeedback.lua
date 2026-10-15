local _, ns = ...

-- Hover, pressed and checked feedback for modern action buttons. Blizzard's state textures are held
-- hidden, so the button gets its own flat theme-coloured regions instead. They are driven by
-- secure post-hooks (never SetScript, never a field on the button); the hooks only act on buttons
-- tracked while the area is applied, and the journal hides the regions when it is undone.

local Modern = ns.Modern

local tracked = setmetatable({}, { __mode = "k" })   -- button -> { skin, down, pushed, checked }
local hooked = setmetatable({}, { __mode = "k" })

local function Flat(button, layer, sublevel, colour, alpha, anchor)
    local texture = button:CreateTexture(nil, layer, nil, sublevel)
    texture:SetAllPoints(anchor)
    texture:SetColorTexture(colour[1], colour[2], colour[3], alpha)
    return texture
end

local function Show(region, on)
    if on then region:Show() else region:Hide() end
end

local function Refresh(button)
    local info = tracked[button]
    if not info then return end
    local state = type(button.GetButtonState) == "function" and button:GetButtonState()
    local checked = type(button.GetChecked) == "function" and button:GetChecked()
    Show(info.pushed, info.down or state == "PUSHED")
    Show(info.checked, checked and true or false)
end

local function Watch(button)
    if hooked[button] then return end
    hooked[button] = true
    local function Update() ns.Run("modern bar feedback", Refresh, button) end
    for _, method in ipairs({ "SetButtonState", "SetChecked" }) do
        if type(button[method]) == "function" then pcall(hooksecurefunc, button, method, Update) end
    end
    if type(button.HookScript) == "function" then
        pcall(button.HookScript, button, "OnMouseDown", function()
            local info = tracked[button]
            if info then info.down = true; Update() end
        end)
        pcall(button.HookScript, button, "OnMouseUp", function()
            local info = tracked[button]
            if info then info.down = nil; Update() end
        end)
    end
end

function Modern.BarFeedback(skin, button, anchor)
    if not ns.Usable(button) or not ns.Usable(anchor) or type(button.CreateTexture) ~= "function" then return end
    local theme = Modern.Theme()
    skin:Own(button, "hover", function() return Flat(button, "HIGHLIGHT", 0, theme.border, 0.25, anchor) end)
    local pushed = skin:Own(button, "pushed", function() return Flat(button, "OVERLAY", 5, theme.bg, 0.55, anchor) end)
    local checked = skin:Own(button, "checked", function() return Flat(button, "OVERLAY", 4, theme.accent, 0.35, anchor) end)
    if not pushed or not checked then return end
    tracked[button] = { pushed = pushed, checked = checked }
    skin:Remember(button, "bar feedback", function() tracked[button] = nil end)
    Watch(button)
    Refresh(button)
end
