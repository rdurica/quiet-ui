-- Player-facing names of the Modern areas.
local h = ...
local L = h.lib("modern")

local function click(b) b._scripts.OnClick(b) end

h.test("the auras area is labelled Buffs and debuffs in the registry", function(t)
    local A, ns = t.assert, t.ns
    local _, area = L.indexOf(ns, "auras")
    A.ok(area, "auras area is registered")
    A.eq(area.label, "Buffs and debuffs")
end)

h.test("the Modern tab shows a Buffs and debuffs checkbox", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = {}; QuietUICharDB = { modernize = { enabled = true } }
    ns.ApplyAll = function() end
    ns.Layout.CurrentRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.Layout.Choices = function() return {} end
    ns.Layout.Preview = function() end
    ns.Layout.CommitPreview = function() end
    ns.Layout.CancelPreview = function() end
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    for _, tab in ipairs(ui.tabs) do if tab.id == "modern" then click(tab) end end
    local found, old
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "Button" and f.box and f.label then
            if f.label._text == "Buffs and debuffs" then found = f end
            if f.label._text == "Auras" then old = f end
        end
    end
    A.ok(found, "checkbox labelled Buffs and debuffs")
    A.eq(old, nil, "the old Auras label is gone")
end)
