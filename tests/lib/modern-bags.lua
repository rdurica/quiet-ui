-- 12.0 bag shapes: ContainerFrameN / ContainerFrameCombinedBags with Items, EnumerateValidItems and ItemButtons
-- whose texture is button.icon and whose quality border is button.IconBorder, shown and coloured by Blizzard's
-- SetItemButtonQuality (SetShown(asset ~= nil), then SetVertexColor).
local B = {}
local R  -- modern-windows-retail, passed through B.use

function B.use(retail) R = retail end

-- Defines the global Blizzard function the way ItemButtonTemplate.lua does. Call before enabling Modern.
function B.install()
    _G.SetItemButtonQuality = function(button, color)
        button.IconBorder:SetShown(color ~= nil)
        if color then button.IconBorder:SetVertexColor(color[1], color[2], color[3]) end
    end
end

function B.bag(name)
    local bag = R.window(name, { inset = false })
    bag.Items = {}
    function bag:GetBagSize() return #self.Items end
    function bag:EnumerateValidItems()
        return function(container, index)
            index = index + 1
            if index <= #container.Items then return index, container.Items[index] end
        end, self, 0
    end
    function bag:UpdateItems() end
    return bag
end

function B.item(bag, name, color)
    local button = CreateFrame("ItemButton", name, bag)
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetTexture("Interface\\Icons\\" .. name)
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.IconBorder = button:CreateTexture(nil, "OVERLAY")
    button.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    button.IconBorder:Hide()
    bag.Items[#bag.Items + 1] = button
    if color then B.quality(button, color) end
    return button
end

-- Blizzard sets (or clears, with nil) the quality of one item.
function B.quality(button, color)
    _G.SetItemButtonQuality(button, color)
end

-- What opening or updating a bag does around the items: the frame shows, bag events arrive, items update.
function B.refresh(mock, bag)
    bag:Hide(); bag:Show()
    mock:fire("BAG_UPDATE")
    mock:fire("BAG_UPDATE_DELAYED")
    bag:UpdateItems()
    mock:drain()
end

-- Colour {r, g, b} of the visible 1 px border lines the addon drew on the button, or nil.
function B.border(button)
    for _, region in ipairs(button._regions) do
        if (region._layer == "BORDER" or region._layer == "OVERLAY") and region._color and region._shown then
            return { region._color[1], region._color[2], region._color[3] }
        end
    end
end

function B.same(a, b)
    return a ~= nil and b ~= nil and math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6
        and math.abs(a[3] - b[3]) < 1e-6
end

return B
