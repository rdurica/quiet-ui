-- Always show debuffs: default on, survives saves, presets and reset (through the setup window).
local h = ...

-- Button whose own text or label text is exactly `text`.
local function button(mock, text)
    for _, f in ipairs(mock.frames) do
        if f._kind == "Button" then
            if f._text == text then return f end
            for _, r in ipairs(f._regions) do
                if r._text == text then return f end
            end
        end
    end
    error("no button " .. text, 0)
end

local function click(b) b._scripts.OnClick(b) end

h.test("Always show debuffs defaults on and survives saves, presets and reset", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    A.ok(ns.Settings.AlwaysShowDebuffs(), "Missing setting must default on")
    ns.Setup.Show()
    local choice = button(mock, "Always show debuffs")
    A.eq(choice.box._checked, true, "The window must show the default as checked")
    click(choice)
    click(button(mock, "Save"))
    A.ok(QuietUICharDB.alwaysShowDebuffs == false and not ns.Settings.AlwaysShowDebuffs(),
        "Unchecking and saving must persist the opt-out")
    local id = assert(ns.Settings.SavePreset(nil, "Debuffs fade", {}, { alwaysShowDebuffs = false }))
    ns.Settings.ActivatePreset(id)
    A.ok(not ns.Settings.AlwaysShowDebuffs(), "Preset did not retain opt-out")
    ns.Settings.DeletePreset(id)
    A.ok(not ns.Settings.AlwaysShowDebuffs(), "Deleting preset lost personal snapshot")
    ns.Setup.Refresh()
    click(button(mock, "Reset default"))
    A.ok(ns.Settings.AlwaysShowDebuffs() and QuietUICharDB.alwaysShowDebuffs == nil,
        "Reset must restore default without storing an explicit true")
    QuietUICharDB.alwaysShowDebuffs = false
    ns.Setup.Refresh()
    A.eq(button(mock, "Always show debuffs").box._checked, false, "The window must show the saved opt-out")
    click(button(mock, "Always show debuffs"))
    click(button(mock, "Save"))
    A.ok(ns.Settings.AlwaysShowDebuffs(), "Re-enabling did not clear opt-out")
end)
