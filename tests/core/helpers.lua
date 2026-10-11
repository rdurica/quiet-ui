-- Shared helpers Run, Flat and Backdropped (single implementation in the core).
local h = ...

h.test("Run does not throw and reports once on error", function(t)
    local ns, A = t.ns, t.assert
    local reports = {}
    ns.Report = function(label, err) reports[#reports + 1] = { label, err } end
    A.type(ns.Run, "function", "ns.Run")
    A.noThrow(ns.Run, "x", error, "boom")
    A.eq(#reports, 1, "Report calls")
    A.eq(reports[1][1], "x", "Report label")
    A.ok(tostring(reports[1][2]):find("boom", 1, true), "Report error text")
end)

h.test("Run passes arguments through and stays quiet on success", function(t)
    local ns, A = t.ns, t.assert
    local reports, seen = 0, nil
    ns.Report = function() reports = reports + 1 end
    A.type(ns.Run, "function", "ns.Run")
    ns.Run("x", function(a, b) seen = a + b end, 2, 3)
    A.eq(seen, 5, "arguments reach the function")
    A.eq(reports, 0, "Report calls")
end)

h.test("Flat with SetBackdrop applies backdrop and colors, default alpha 0.92", function(t)
    local A = t.assert
    A.type(t.ns.Flat, "function", "ns.Flat")
    local w = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t.ns.Flat(w)
    A.ok(w._backdrop, "SetBackdrop was not called")
    A.eq(w._backdrop.bgFile, "Interface\\Buttons\\WHITE8X8")
    A.eq(w._backdrop.edgeFile, "Interface\\Buttons\\WHITE8X8")
    A.eq(w._backdrop.edgeSize, 1)
    A.deep(w._backdropColor, { 0.05, 0.05, 0.05, 0.92 })
    A.deep(w._backdropBorder, { 0.85, 0.85, 0.85, 0.35 })
    t.ns.Flat(w, 0.5)
    A.deep(w._backdropColor, { 0.05, 0.05, 0.05, 0.5 })
end)

h.test("Flat without SetBackdrop creates one _quietFill texture", function(t)
    local A = t.assert
    A.type(t.ns.Flat, "function", "ns.Flat")
    local w = CreateFrame("Frame", nil, UIParent)
    A.eq(w.SetBackdrop, nil, "precondition: no SetBackdrop")
    t.ns.Flat(w)
    local fill = w._quietFill
    A.ok(fill, "_quietFill was not created")
    A.eq(fill._texture, "Interface\\Buttons\\WHITE8X8")
    A.deep(fill._vertex, { 0.05, 0.05, 0.05, 0.92 })
    t.ns.Flat(w, 0.5)
    A.eq(w._quietFill, fill, "second call keeps the same fill")
    A.eq(w:GetNumRegions(), 1, "regions after two calls")
end)

h.test("Flat ignores a missing widget", function(t)
    t.assert.type(t.ns.Flat, "function", "ns.Flat")
    t.assert.noThrow(t.ns.Flat, nil)
end)

h.test("Backdropped without template creates with BackdropTemplate", function(t)
    local A, mock = t.assert, t.mock
    A.type(t.ns.Backdropped, "function", "ns.Backdropped")
    local parent = CreateFrame("Frame", nil, UIParent)
    local before = #mock.createLog
    local w = t.ns.Backdropped("Frame", "QuietTestBox", parent)
    A.eq(#mock.createLog, before + 1, "CreateFrame calls")
    local call = mock.createLog[#mock.createLog]
    A.eq(call.kind, "Frame")
    A.eq(call.name, "QuietTestBox")
    A.eq(call.parent, parent)
    A.eq(call.template, "BackdropTemplate")
    A.eq(w:GetName(), "QuietTestBox")
end)

h.test("Backdropped falls back to a plain frame when the template fails", function(t)
    local A, mock = t.assert, t.mock
    A.type(t.ns.Backdropped, "function", "ns.Backdropped")
    mock.rejectTemplates.BackdropTemplate = true
    local w = t.ns.Backdropped("Frame", nil, UIParent)
    A.ok(w, "no frame returned")
    local call = mock.createLog[#mock.createLog]
    A.eq(call.template, nil, "last CreateFrame uses no template")
end)

h.test("Backdropped with template tries it first, then BackdropTemplate", function(t)
    local A, mock = t.assert, t.mock
    A.type(t.ns.Backdropped, "function", "ns.Backdropped")
    local before = #mock.createLog
    t.ns.Backdropped("Button", nil, UIParent, "UIPanelButtonTemplate")
    A.eq(#mock.createLog, before + 1, "CreateFrame calls when the template works")
    A.eq(mock.createLog[#mock.createLog].template, "UIPanelButtonTemplate")

    mock.rejectTemplates.UIPanelButtonTemplate = true
    before = #mock.createLog
    t.ns.Backdropped("Button", nil, UIParent, "UIPanelButtonTemplate")
    A.eq(#mock.createLog, before + 2, "CreateFrame calls when the template fails")
    A.eq(mock.createLog[before + 1].template, "UIPanelButtonTemplate")
    A.eq(mock.createLog[before + 2].template, "BackdropTemplate")
end)
