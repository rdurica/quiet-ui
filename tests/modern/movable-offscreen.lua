-- A saved window point from a wider or taller screen must not leave the window off-screen
-- after a resolution change: the point is pulled back inside UIParent.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

local SCREEN_W, SCREEN_H = 2132, 1200
local FRAME_W, FRAME_H = 430, 347

-- Geometry for the two points these tests use, so UIParent bounds can be checked.
local function geometry(frame)
    frame:SetSize(FRAME_W, FRAME_H)
    function frame:GetLeft()
        local point, _, relativePoint, x = self:GetPoint(1)
        if point == "BOTTOM" and relativePoint == "BOTTOM" then
            return UIParent:GetWidth() / 2 + x - FRAME_W / 2
        elseif point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT" then
            return x
        end
        return 0
    end
    function frame:GetBottom()
        local point, _, relativePoint, _, y = self:GetPoint(1)
        if point == "BOTTOM" and relativePoint == "BOTTOM" then
            return y
        elseif point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT" then
            return y
        end
        return 0
    end
    function frame:GetRight() return self:GetLeft() + FRAME_W end
    function frame:GetTop() return self:GetBottom() + FRAME_H end
end

local function saved(x, y)
    UIParent:SetSize(SCREEN_W, SCREEN_H)
    QuietUICharDB = { windowPoints = { ZzWindow = { "BOTTOM", "BOTTOM", x, y } } }
end

local function window(ns)
    local frame = CreateFrame("Frame", "ZzWindow", UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    geometry(frame)
    ns.Modern.MakeMovable(frame, "ZzWindow")
    return frame
end

h.test("a saved point beyond the right and top edges is pulled back inside UIParent", function(t)
    local A, ns = t.assert, t.ns
    saved(1344, 1400)
    t.boot()
    local frame = window(ns)
    frame:Hide(); frame:Show()
    A.deep(W.point(frame), { "BOTTOMLEFT", "BOTTOMLEFT", SCREEN_W - FRAME_W, SCREEN_H - FRAME_H },
        "the window sits at the nearest fully visible point")
end)

h.test("a saved point already inside UIParent is left alone", function(t)
    local A, ns = t.assert, t.ns
    saved(100, 100)
    t.boot()
    local frame = window(ns)
    frame:Hide(); frame:Show()
    A.deep(W.point(frame), { "BOTTOM", "BOTTOM", 100, 100 }, "a visible point keeps its anchor")
end)
