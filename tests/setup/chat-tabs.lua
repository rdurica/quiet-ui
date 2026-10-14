-- Misc. Tabs stepper under Fade after: Bottom / Top, Bottom stores nothing.
local h = ...

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

local function stepper(mock)
    for _, f in ipairs(mock.frames) do
        if f.label and f.label._text == "Tabs" and f.plus and f.minus and f.value then return f end
    end
    error("no Tabs stepper", 0)
end

local function click(b) b._scripts.OnClick(b) end

h.test("Tabs stepper shows Bottom by default and both buttons cycle Bottom and Top", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    ns.Setup.Show()
    local row = stepper(mock)
    A.eq(row.value._text, "Bottom", "default")
    click(row.plus)
    A.eq(row.value._text, "Top", "plus")
    click(row.plus)
    A.eq(row.value._text, "Bottom", "plus cycles back to Bottom")
    click(row.minus)
    A.eq(row.value._text, "Top", "minus cycles to Top")
    click(row.minus)
    A.eq(row.value._text, "Bottom", "minus cycles to Bottom")
end)

h.test("Saving Top stores chatTabs top and saving Bottom stores nothing", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    ns.Setup.Show()
    local row = stepper(mock)
    click(row.plus)
    A.eq(QuietUICharDB.chatTabs, nil, "draft is not saved yet")
    click(button(mock, "Save"))
    A.eq(QuietUICharDB.chatTabs, "top", "stored")
    A.eq(ns.Settings.ChatTabs(), "top")
    click(row.minus)
    click(button(mock, "Save"))
    A.eq(QuietUICharDB.chatTabs, nil, "Bottom stores no chatTabs")
    A.eq(ns.Settings.ChatTabs(), "bottom")
end)

h.test("Tabs stepper shows a saved Top", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    QuietUICharDB.chatTabs = "top"
    ns.Setup.Show()
    A.eq(stepper(mock).value._text, "Top")
end)
