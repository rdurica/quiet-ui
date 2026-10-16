-- Reset positions is public Modern behaviour: it clears only character window points and puts
-- every tracked Blizzard window back, even if combat delays that placement.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

local function tracked(ns)
    local frame = W.window("ZzResetWindow")
    ns.Modern.MakeMovable(frame, "ZzResetWindow")
    return frame, W.point(frame)
end

h.test("ResetPositions clears saved points, restores tracked originals and keeps Modern settings", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {
        modernize = { enabled = true, opacity = 90, windows = false },
        windowPoints = { ZzResetWindow = { "CENTER", "CENTER", 210, -110 } },
        unrelated = { keep = true },
    }
    QuietUICharDB.windowPoints = nil
    local frame, original = tracked(ns)
    QuietUICharDB.windowPoints = { ZzResetWindow = { "CENTER", "CENTER", 210, -110 } }
    frame:Hide(); frame:Show()
    A.deep(W.point(frame), { "CENTER", "CENTER", 210, -110 }, "saved point applied before reset")
    A.type(ns.Modern.ResetPositions, "function", "public reset API")
    ns.Modern.ResetPositions()
    A.eq(QuietUICharDB.windowPoints, nil, "all saved positions are cleared")
    A.deep(W.point(frame), original, "Blizzard point returns immediately")
    A.deep(QuietUICharDB.modernize, { enabled = true, opacity = 90, windows = false }, "Modern choices stay")
    A.deep(QuietUICharDB.unrelated, { keep = true }, "other character settings stay")
end)

h.test("ResetPositions defers original placement in combat and completes after QuietUI turns off", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    t.boot()
    QuietUICharDB = { modernize = { enabled = true }, windowPoints = { ZzResetWindow = { "CENTER", "CENTER", 4, 5 } } }
    QuietUICharDB.windowPoints = nil
    local frame, original = tracked(ns)
    QuietUICharDB.windowPoints = { ZzResetWindow = { "CENTER", "CENTER", 4, 5 } }
    frame:Hide(); frame:Show()
    mock.state.combat = true
    ns.Modern.ResetPositions()
    A.eq(QuietUICharDB.windowPoints, nil)
    A.deep(W.point(frame), { "CENTER", "CENTER", 4, 5 }, "combat does not set points")
    SlashCmdList.QUIETUI("off")
    mock:drain()
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.deep(W.point(frame), original, "pending reset finishes after QuietUI is off")
end)

h.test("Modern tab Reset positions is visible while enabled and clears points without Save", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUICharDB = { modernize = { enabled = true, opacity = 90 }, windowPoints = { ZzResetWindow = { "CENTER", "CENTER", 1, 2 } } }
    ns.ApplyAll = function() end
    ns.Layout.CurrentRef = function() return { layoutName = "Raid", layoutType = 1 } end
    ns.Layout.Choices = function() return {} end
    ns.Layout.Preview = function() end
    ns.Layout.CommitPreview = function() end
    ns.Layout.CancelPreview = function() end
    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    for _, tab in ipairs(ui.tabs) do if tab.id == "modern" then tab._scripts.OnClick(tab) end end
    local reset
    for _, control in ipairs(mock.frames) do
        if control._kind == "Button" and control.label and control.label._text == "Reset positions" then reset = control end
    end
    A.type(reset, "table", "Reset positions button")
    A.ok(reset:IsVisible(), "shown with Modernize")
    reset._scripts.OnClick(reset)
    A.eq(QuietUICharDB.windowPoints, nil, "cleared immediately, before Save")
    A.deep(QuietUICharDB.modernize, { enabled = true, opacity = 90 }, "other settings remain")
    local modernize
    for _, control in ipairs(mock.frames) do
        if control._kind == "Button" and control.label and control.label._text == "Modernize" then modernize = control end
    end
    modernize._scripts.OnClick(modernize)
    A.falsy(reset:IsVisible(), "hidden while Modernize is unchecked")
end)
