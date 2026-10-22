-- Character window sub-panels on 12.0 (Blizzard_UIPanels_Game CharacterFrame.xml, ReputationFrame.xml,
-- Blizzard_TokenUI.xml): ReputationFrame and TokenFrame are global children of CharacterFrame, and the
-- right-hand stats pane sits on CharacterFrame.InsetRight (also CharacterFrameInsetRight), hidden until the pane
-- opens; the fixture has it shown so that held chrome is observable.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function character()
    local frame = R.window("CharacterFrame")
    CharacterFrame = frame
    frame.InsetRight = R.inset(frame, frame.chromeList)
    CharacterFrameInsetRight = frame.InsetRight
    ReputationFrame = CreateFrame("Frame", "ReputationFrame", frame)
    ReputationFrame:SetAllPoints(frame)
    TokenFrame = CreateFrame("Frame", "TokenFrame", frame)
    TokenFrame:SetAllPoints(frame)
    frame.TokenFrame = TokenFrame
    return frame
end

h.test("Windows skins the 12.0 ReputationFrame and TokenFrame sub-panels and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local frame = character()
    local before = L.snapshot({ frame, ReputationFrame, TokenFrame })
    W.enable(ns)
    A.ok(W.isDark(ReputationFrame), "ReputationFrame gets a dark panel")
    A.ok(W.isDark(TokenFrame), "TokenFrame gets a dark panel")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "sub-panels restore exactly")
end)

h.test("Windows holds CharacterFrame.InsetRight chrome, also against Blizzard's SetAlpha, and restores it", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local frame = character()
    local before = L.snapshot(R.all(frame))
    W.enable(ns)
    A.eq(R.visibleChrome(frame), "", "Bg and NineSlice of Inset and InsetRight are all hidden")
    frame.InsetRight.Bg:SetAlpha(1); frame.InsetRight.NineSlice.TopEdge:SetAlpha(1)
    A.eq(R.visibleChrome(frame), "", "InsetRight chrome stays hidden when Blizzard repaints it")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "InsetRight chrome restores exactly")
end)
