local _, ns = ...

-- Hover, pressed and checked feedback for modern action buttons. Blizzard's state textures are held
-- hidden, so the button gets its own flat theme-coloured regions instead. They are driven by
-- secure post-hooks (never SetScript, never a field on the button); the hooks only act on buttons
-- tracked while the area is applied, and the journal hides the regions when it is undone.

local Modern = ns.Modern

local tracked = setmetatable({}, { __mode = "k" })   -- button -> { skin, down, pushed, checked }
local hooked = setmetatable({}, { __mode = "k" })

local function Flat(button, layer, sublevel, anchor)
    local texture = button:CreateTexture(nil, layer, nil, sublevel)
    texture:SetAllPoints(anchor)
    return texture
end

local function Colour(texture, colour, alpha)
    texture:SetColorTexture(colour[1], colour[2], colour[3], alpha)
end

local function Show(region, on)
    if on then region:Show() else region:Hide() end
end

-- 12.0 may return a secret checked state; it goes to the widget and is never tested.
local function ShowChecked(region, checked)
    if ns.IsSecret(checked) then
        region:Show()
        if type(region.SetAlphaFromBoolean) == "function" then
            region:SetAlphaFromBoolean(checked, 1, 0)
        else
            region:Hide()
        end
        return
    end
    region:SetAlpha(1)
    Show(region, checked and true or false)
end

local function Refresh(button)
    local info = tracked[button]
    if not info then return end
    local state = type(button.GetButtonState) == "function" and button:GetButtonState()
    if ns.IsSecret(state) then state = nil end
    local checked = type(button.GetChecked) == "function" and button:GetChecked()
    Show(info.pushed, info.down or state == "PUSHED")
    ShowChecked(info.checked, checked)
end

local function Watch(button)
    if hooked[button] then return end
    hooked[button] = true
    local function Update() ns.Profiler.Run("modern bar feedback", Refresh, button) end
    local function Release()
        local info = tracked[button]
        if info then info.down = nil; Update() end
    end
    if type(button.SetButtonState) == "function" then
        pcall(hooksecurefunc, button, "SetButtonState", function(_, state)
            if state == "NORMAL" then Release() else Update() end
        end)
    end
    if type(button.SetChecked) == "function" then pcall(hooksecurefunc, button, "SetChecked", Update) end
    if type(button.HookScript) == "function" then
        pcall(button.HookScript, button, "OnMouseDown", function()
            local info = tracked[button]
            if info then info.down = true; Update() end
        end)
        for _, script in ipairs({ "OnMouseUp", "OnLeave", "OnDragStart" }) do
            pcall(button.HookScript, button, script, Release)
        end
    end
end

function Modern.BarFeedback(skin, button, anchor)
    if not ns.Usable(button) or not ns.Usable(anchor) or type(button.CreateTexture) ~= "function" then return end
    local theme = Modern.Theme()
    local hover = skin:Own(button, "hover", function() return Flat(button, "HIGHLIGHT", 0, anchor) end)
    local pushed = skin:Own(button, "pushed", function() return Flat(button, "OVERLAY", 5, anchor) end)
    local checked = skin:Own(button, "checked", function() return Flat(button, "OVERLAY", 4, anchor) end)
    if not hover or not pushed or not checked then return end
    -- Regions are cached across applies and hidden by undo: show and re-colour them every time.
    Colour(hover, theme.border, 0.25); hover:Show()
    Colour(pushed, theme.bg, 0.55)
    Colour(checked, theme.accent, 0.35)
    tracked[button] = { pushed = pushed, checked = checked }
    skin:Remember(button, "bar feedback", function() tracked[button] = nil end)
    Watch(button)
    Refresh(button)
end
