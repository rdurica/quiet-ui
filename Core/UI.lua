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
