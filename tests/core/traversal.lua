-- Texture traversal and focus tracking through the public ns API.
local h = ...

h.test("texture traversal reads the region list once", function(t)
    local A = t.assert
    local root = CreateFrame('Frame', nil, UIParent)
    for _ = 1, 8 do root:CreateTexture() end
    t.ns.HideTextures(root)
    A.eq(root._calls.GetRegions, 1, 'Region list reads: ' .. tostring(root._calls.GetRegions))
end)

h.test("focus ignores unrelated windows but preserves tracked hover and fallback", function(t)
    local A = t.assert
    local ns = t.ns
    local bar = CreateFrame('Frame', nil, UIParent)
    local window = CreateFrame('Frame', nil, UIParent)
    local slot = CreateFrame('Button', nil, bar)
    local itemA = CreateFrame('Button', nil, window)
    local itemB = CreateFrame('Button', nil, window)
    local focus = { itemA }
    GetMouseFoci = function() return focus end
    ns.Hit(bar)
    ns.FocusChanged()
    local scans = 0
    for i = 1, 600 do
        focus = { i % 2 == 0 and itemA or itemB }
        if ns.FocusChanged() then scans = scans + 1 end
    end
    A.eq(scans, 0, 'Unrelated hover triggered HUD rescans')
    focus = { slot }; A.ok(ns.FocusChanged() and ns.Hit(bar), 'Button did not reveal its bar')
    focus = { bar }; A.falsy(ns.FocusChanged(), 'Same bar hover caused another rescan')
    focus = { itemA }; A.ok(ns.FocusChanged() and not ns.Hit(bar), 'Leaving bar did not rescan')
    focus = { slot, itemA }; A.ok(ns.FocusChanged() and ns.Hit(bar), 'Multiple foci lost tracked hover')
    focus = {}; A.ok(ns.FocusChanged() and not ns.Hit(bar), 'Empty focus retained hover')
    GetMouseFoci = function() error('Unavailable') end
    bar:SetMouseOver(true)
    A.ok(ns.FocusChanged() == nil and ns.Hit(bar), 'Failed focus API lost fallback hover')
    GetMouseFoci, GetMouseFocus = nil, nil
    A.ok(ns.FocusChanged() == nil and ns.Hit(bar), 'Missing focus API lost fallback')
end)

h.test("a fresh namespace without a focus API falls back to pointer hover", function(t)
    local A = t.assert
    local bar = CreateFrame('Frame', nil, UIParent)
    bar:SetMouseOver(true)
    GetMouseFoci, GetMouseFocus = nil, nil
    A.ok(t.ns.FocusChanged() == nil and t.ns.Hit(bar), 'Missing focus API lost fallback')
end)
