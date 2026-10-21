-- HUD frames of the Forever UI source beside the main unit frames: Boss1TargetFrame (BossTargetFrameTemplate, the
-- target frame's shape), the mirror timers (MirrorTimerContainer.mirrorTimers: a cast bar frame, text box and
-- background, a StatusBar whose atlas Blizzard sets in Setup) and the raid manager panel (CompactRaidFrameManager
-- with a Background and a dropdown).
local h = ...
local L = h.lib("modern")
local R = h.lib("modern-windows-retail")
local U = h.lib("modern-units")
local W = h.lib("modern-windows")
local P = h.lib("modern-shapes")

local function timer(container)
    local frame = CreateFrame("Frame", nil, container)
    frame.Border = frame:CreateTexture(nil, "OVERLAY")
    frame.TextBorder = frame:CreateTexture(nil, "BACKGROUND")
    local bar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar = bar
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill._atlas = "ui-castingbar-filling-standard"
    function fill:GetAtlas() return self._atlas end
    bar._statusColor = { 1, 1, 1, 1 }
    function bar:SetStatusBarTexture(v)
        if tostring(v):find("\\") then fill._atlas = nil; fill:SetTexture(v) else fill._atlas, fill._texture = v, nil end
    end
    function bar:GetStatusBarTexture() return fill end
    function bar:SetStatusBarColor(...) self._statusColor = { ... } end
    function bar:GetStatusBarColor() return unpack(self._statusColor) end
    function frame:Setup(kind)
        self.timer = kind
        self.StatusBar:SetStatusBarTexture("ui-castingbar-filling-applyingcrafting")
    end
    return frame
end

h.test("Unit frames gives a boss frame the target's compact box", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    U.frames()
    local boss = U.target("Boss1TargetFrame", "boss1")
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(U.parts(boss).portrait._alpha, 0, "the boss portrait is held")
    A.eq(U.statusTexture(U.parts(boss).health), ns.Modern.Theme().bar, "the boss health bar is flat")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Cast bars flattens the breath bar and repaints it on every Setup, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local container = CreateFrame("Frame", "MirrorTimerContainer", UIParent)
    local breath = timer(container)
    container.mirrorTimers = { breath }
    local before = L.snapshot(R.all(container))
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(breath.Border._alpha, 0, "the cast bar frame is held")
    A.eq(breath.TextBorder._alpha, 0, "the text box is held")
    breath:Setup("BREATH")
    A.eq(breath.StatusBar:GetStatusBarTexture()._texture, ns.Modern.Theme().bar, "the fill is flat after Setup")
    A.eq(breath.StatusBar._statusColor[3], 0.95, "breath is blue")
    A.ok(W.isDark(breath.StatusBar), "the bar sits on the theme panel")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    breath:Setup("BREATH")
    A.eq(breath.StatusBar:GetStatusBarTexture()._atlas, "ui-castingbar-filling-applyingcrafting",
        "after restore Setup keeps Blizzard's fill")
    A.ok(#L.diff(before) <= 2, "only Blizzard's own Setup changes remain")
end)

h.test("Windows darkens the raid manager panel", function(t)
    local A, ns = t.assert, t.ns
    local c = P.new()
    local manager = CreateFrame("Frame", "CompactRaidFrameManager", UIParent)
    manager.Background = P.texture(c, manager, "art", "RaidFrameManager-Background", "ARTWORK")
    manager.displayFrame = CreateFrame("Frame", nil, manager)
    local dropdown = P.dropdown(c, manager.displayFrame)
    W.enable(ns)
    A.ok(W.isDark(manager), "the raid manager is a dark panel")
    A.eq(P.visibleArt(c, R), "", "its background and dropdown art are held")
    A.ok(W.isDark(dropdown), "its dropdown is a flat field")
end)
