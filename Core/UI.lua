local _, ns = ...

-- Flat dark chrome for frames the addon creates.

function ns.Flat(widget, alpha)
    if not widget then return end
    if widget.SetBackdrop then
        pcall(function()
            widget:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            widget:SetBackdropColor(0.05, 0.05, 0.05, alpha or 0.92)
            widget:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
        end)
        return
    end
    if widget.CreateTexture and not widget._quietFill then
        local fill = widget:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetVertexColor(0.05, 0.05, 0.05, alpha or 0.92)
        widget._quietFill = fill
    end
end

function ns.Backdropped(kind, name, parent, template)
    if template then
        local ok, widget = pcall(CreateFrame, kind, name, parent, template)
        if ok and widget then return widget end
    end
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end

-- Dialog chrome shared by the Setup window and the Layout prompt.

-- Gold edge for input fields, short tabs and steppers.
function ns.GoldEdge(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        widget:SetBackdropColor(0.08, 0.06, 0.04, 0.92)
        widget:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
    end)
    return ok
end

-- A separate texture keeps every dialog opaque even without BackdropTemplate.
function ns.DialogBackground(widget)
    local fill = widget:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(widget)
    fill:SetColorTexture(0.05, 0.05, 0.05, 1)
    return fill
end

-- Read foreign frames only; their scroll children can out-level the root dialog.
local function DialogRead(widget, method)
    local ok, value = pcall(function()
        if not ns.Usable(widget) or type(widget[method]) ~= "function" then return end
        return widget[method](widget)
    end)
    if ok then return value end
end

function ns.RaiseDialog(widget)
    widget:SetFrameStrata("DIALOG")
    if type(widget.Raise) == "function" then pcall(widget.Raise, widget) end
    local highest = 0
    local visited = {}
    local function Scan(parent)
        if parent == widget or visited[parent] then return end
        visited[parent] = true
        local ok, children = pcall(function()
            if not ns.Usable(parent) or type(parent.GetChildren) ~= "function" then return end
            return { parent:GetChildren() }
        end)
        if not ok or not children then return end
        for _, child in ipairs(children) do
            local shown = child ~= widget and DialogRead(child, "IsShown")
            if type(shown) == "boolean" and not ns.IsSecret(shown) and shown then
                local strata = DialogRead(child, "GetFrameStrata")
                if not ns.IsSecret(strata) and strata == "DIALOG" then
                    local level = DialogRead(child, "GetFrameLevel")
                    if type(level) == "number" and not ns.IsSecret(level)
                        and level == level and level < math.huge then
                        highest = math.max(highest, level)
                    end
                end
                Scan(child)
            end
        end
    end
    Scan(UIParent)
    if widget:GetFrameLevel() <= highest then widget:SetFrameLevel(highest + 1) end
end


function ns.ApplyTitle(widget, text)
    if widget.SetTitle then
        local ok = pcall(widget.SetTitle, widget, text)
        if ok then return end
    end
    local title = widget.TitleText
    if not title and widget.TitleContainer then
        title = widget.TitleContainer.TitleText
    end
    if title and title.SetText then
        title:SetText(text)
    end
end

function ns.DialogGoldWindow(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        widget:SetBackdropColor(1, 1, 1, 1)
        widget:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    return ok
end


function ns.PortraitChrome(widget)
    return widget.SetTitle or widget.TitleText or widget.TitleContainer
        or widget.PortraitContainer or widget.portrait
end
