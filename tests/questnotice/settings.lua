-- The Quest updates setting and text size: accessors, preset snapshots and the Misc. tab controls.
local h = ...

local function click(b) b._scripts.OnClick(b) end

-- Layout reads are stubbed; ApplyAll records the notice state at the moment it runs.
local function fixture(t)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = {}
    local applied = {}
    ns.CurrentLayoutRef = function() return { layoutName = "Original", layoutType = 1 } end
    ns.LayoutChoices = function() return {} end
    ns.ApplyAll = function()
        applied[#applied + 1] = { enabled = ns.Settings.QuestNoticeEnabled(), saved = QuietUICharDB.questNotice }
    end
    return ns, applied
end

h.test("Quest updates defaults on and only explicit false turns it off", function(t)
    local ns = fixture(t)
    local A = t.assert
    A.eq(ns.Settings.QuestNoticeEnabled(), true, "Missing setting must default on")
    for _, value in ipairs({ true, 0, "off" }) do
        QuietUICharDB.questNotice = value
        A.eq(ns.Settings.QuestNoticeEnabled(), true, "Only false may disable notices")
    end
    QuietUICharDB.questNotice = false
    A.eq(ns.Settings.QuestNoticeEnabled(), false, "Personal false must disable notices")
    local id = ns.Settings.SavePreset(nil, "Default", ns.CurrentLayoutRef(), {})
    ns.Settings.ActivatePreset(id)
    A.eq(ns.Settings.QuestNoticeEnabled(), true, "Effective preset default must override personal off")
    ns.Settings.Presets()[id].settings.questNotice = false
    QuietUICharDB.questNotice = nil
    A.eq(ns.Settings.QuestNoticeEnabled(), false, "Accessor must read active preset settings")
end)

h.test("CopySettings snapshots explicit false and clears omitted defaults", function(t)
    local ns = fixture(t)
    local copy = ns.Settings.CopySettings({ questNotice = false, unrelated = "ignore" })
    t.assert.eq(copy.questNotice, false, "CopySettings whitelist drops notice off")
    t.assert.eq(copy.unrelated, nil, "Settings copy must stay whitelisted")
    local target = { questNotice = false, previousLayout = 3 }
    ns.Settings.CopySettings({}, target)
    t.assert.eq(target.questNotice, nil, "Omitted notice setting must clear a stale false")
    t.assert.eq(target.previousLayout, 3, "CopySettings must preserve layout lifecycle metadata")
end)

h.test("presets preserve off through create, select, save, detach and deletion", function(t)
    local ns = fixture(t)
    local A = t.assert
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questNotice = false })
    local on = ns.Settings.SavePreset(nil, "On", ns.CurrentLayoutRef(), {})
    A.eq(ns.Settings.Presets()[off].settings.questNotice, false, "Preset creation must preserve false")
    ns.Settings.ActivatePreset(off)
    A.ok(QuietUICharDB.questNotice == false and not ns.Settings.QuestNoticeEnabled(), "Select off must snapshot false")
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.ok(not ui.questNotice.box._checked, "Selecting preset must paint its off state")
    click(ui.questNotice); click(ui.save)
    A.ok(ns.Settings.Presets()[off].settings.questNotice == nil and ns.Settings.QuestNoticeEnabled(),
        "Save on must clear active preset false")
    click(ui.questNotice); click(ui.save)
    A.eq(ns.Settings.Presets()[off].settings.questNotice, false, "Save off must update active preset")
    ns.Settings.ActivatePreset(on); ns.Setup.Show()
    A.ok(ui.questNotice.box._checked and QuietUICharDB.questNotice == nil, "Select on clears stale snapshot")
    ns.Settings.ActivatePreset(off); ns.Settings.ActivatePreset(nil)
    A.ok(QuietUICharDB.questNotice == false and not ns.Settings.QuestNoticeEnabled(),
        "Detach must retain last personal snapshot")
    ns.Settings.ActivatePreset(off); ns.Settings.DeletePreset(off)
    A.ok(QuietUICharDB.questNotice == false and not ns.Settings.QuestNoticeEnabled(),
        "Delete active preset retains snapshot")
end)

h.test("a preset selector choice stays a draft; saving the selection applies the notice setting", function(t)
    local ns, applied = fixture(t)
    local A = t.assert
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questNotice = false })
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    A.ok(ui.questNotice and ui.questNotice.box, "Misc. Quest updates choice is missing")
    click(ui.presetSelector); click(ui.presetMenu.items[2])
    A.ok(not ui.questNotice.box._checked and ns.Settings.QuestNoticeEnabled(), "Preset draft must paint off without applying it")
    A.ok(QuietUICharDB.presetId == nil and #applied == 0, "Preset choice must stay unsaved")
    ui:Hide(); ns.Setup.Show()
    A.ok(ui.questNotice.box._checked and not QuietUICharDB.presetId, "Closing discards preset off draft")
    click(ui.presetSelector); click(ui.presetMenu.items[2]); click(ui.save)
    A.ok(QuietUICharDB.presetId == off and not ns.Settings.QuestNoticeEnabled(), "Saving preset selection must apply off")
    A.ok(#applied == 1 and applied[1].enabled == false, "Preset Save applies committed notice state")
end)

h.test("Reset turns notices on, detaches and leaves the shared preset unchanged", function(t)
    local ns, applied = fixture(t)
    local A = t.assert
    local off = ns.Settings.SavePreset(nil, "Off", ns.CurrentLayoutRef(), { questNotice = false })
    ns.Settings.ActivatePreset(off); ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.reset)
    A.ok(QuietUICharDB.presetId == nil and QuietUICharDB.questNotice == nil and ns.Settings.QuestNoticeEnabled(),
        "Reset must detach and save default on")
    A.ok(ui.questNotice.box._checked and ui:IsShown(), "Reset paints on and leaves setup open")
    A.eq(ns.Settings.Presets()[off].settings.questNotice, false, "Reset must not mutate shared preset")
    A.ok(#applied == 1 and applied[1].enabled == true, "Reset immediately applies saved default")
end)

h.test("a draft click and closing discard without changing saved notice state", function(t)
    local ns, applied = fixture(t)
    local A = t.assert
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.questNotice)
    A.ok(not ui.questNotice.box._checked, "Click must paint an off draft")
    A.ok(QuietUICharDB.questNotice == nil and ns.Settings.QuestNoticeEnabled(), "Unsaved draft must not disable live notices")
    A.eq(#applied, 0, "Draft must not apply live changes")
    ui:Hide(); ns.Setup.Show()
    A.ok(ui.questNotice.box._checked and ns.Settings.QuestNoticeEnabled(), "Closing must discard off draft")
    local escape = false
    for _, name in ipairs(UISpecialFrames) do if name == "QuietUISetup" then escape = true end end
    A.ok(escape, "Escape must close the same setup frame and discard drafts")
end)

h.test("Save off stores false, Save on stores nil, both apply immediately", function(t)
    local ns, applied = fixture(t)
    local A = t.assert
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    click(ui.questNotice); click(ui.save)
    A.ok(QuietUICharDB.questNotice == false and not ns.Settings.QuestNoticeEnabled(), "Save off must persist explicit false")
    A.ok(#applied == 1 and applied[1].enabled == false and applied[1].saved == false,
        "Save off must call ApplyAll after committing setting")
    A.ok(ui:IsShown() and not ui.questNotice.box._checked, "Save keeps setup open and paints saved off")
    click(ui.questNotice)
    A.ok(not ns.Settings.QuestNoticeEnabled(), "Unsaved on must leave notices disabled")
    ui:Hide(); ns.Setup.Show()
    A.ok(not ui.questNotice.box._checked, "Closing must discard on draft")
    click(ui.questNotice); click(ui.save)
    A.ok(QuietUICharDB.questNotice == nil and ns.Settings.QuestNoticeEnabled(), "Save on must omit default setting")
    A.ok(#applied == 2 and applied[2].enabled == true and applied[2].saved == nil,
        "Save on must apply after clearing stored false")
end)

h.test("Text size cycles only Smaller, Default and Larger and saves the two offsets", function(t)
    local ns, applied = fixture(t)
    local A = t.assert
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local row = ui.questNoticeSize
    local function label() return row.value:GetText() end
    click(row.minus)
    A.ok(label() == "Smaller" and QuietUICharDB.questNoticeSize == nil, "Smaller stays a draft")
    click(row.minus)
    A.eq(label(), "Smaller", "Minus stops at Smaller")
    click(row.plus); click(row.plus)
    A.eq(label(), "Larger", "Plus moves Smaller, Default, Larger")
    click(row.plus)
    A.eq(label(), "Larger", "Plus stops at Larger")
    A.ok(#applied == 0 and ns.Settings.QuestNoticeSize() == "default", "Unsaved size must not change live notices")
    click(ui.save)
    A.ok(QuietUICharDB.questNoticeSize == "larger" and ns.Settings.QuestNoticeSize() == "larger", "Save keeps Larger")
    click(row.minus); click(ui.save)
    A.ok(QuietUICharDB.questNoticeSize == nil and ns.Settings.QuestNoticeSize() == "default",
        "Default omits the stored size")
    click(row.minus); click(ui.save)
    A.ok(QuietUICharDB.questNoticeSize == "smaller" and ns.Settings.QuestNoticeSize() == "smaller", "Save keeps Smaller")
    QuietUICharDB.questNoticeSize = "huge"
    A.eq(ns.Settings.QuestNoticeSize(), "default", "Only smaller and larger are accepted")
    A.eq(ns.Settings.CopySettings({ questNoticeSize = "larger" }).questNoticeSize, "larger", "Presets keep an explicit text size")
end)

h.test("Quest updates sits on Misc. below chat with a description", function(t)
    local ns = fixture(t)
    local A = t.assert
    ns.Setup.Show()
    local ui = t.mock:findByName("QuietUISetup")
    local choice, page = ui.questNotice, ui.pages[6]
    A.ok(choice and choice.box and choice.label, "Misc. Quest updates choice is missing")
    A.eq(ui.tabs[6].label:GetText(), "Misc.", "Sixth tab is Misc.")
    A.ok(choice:GetParent() == page and choice.label:GetText() == "Quest updates", "Choice belongs on Misc.")
    A.ok(choice.box._checked, "Default choice must be checked")
    A.eq(#ui.tabs, 7, "Adding Quest updates must retain seven tabs")
    local height = ui:GetHeight()
    A.ok(height <= 474, "Quest updates must fit the existing compact setup height")
    local fade, header = ui.fade, ui.questHeader
    A.ok(header and header:GetParent() == page and header._points[1][2] == page, "Quest section belongs on Misc.")
    A.ok(-header._points[1][5] >= -fade._points[1][5] + fade:GetHeight() + 24, "Quest section must sit clear of chat")
    A.ok(header.help, "Quest heading must offer an info button")
    GameTooltip._lines = {}
    header.help._scripts.OnEnter(header.help)
    local bubble = table.concat(GameTooltip._lines, "\n")
    A.ok(bubble:find("accepted", 1, true) and bubble:find("completed", 1, true),
        "Info bubble must say what quest updates do")
    local point = choice._points[1]
    A.ok(point and point[1] == "TOPLEFT" and point[2] == page and point[3] == "TOPLEFT",
        "Choice sits on the Misc. page")
    A.ok(-point[5] >= -header._points[1][5] + header:GetHeight(), "Choice sits under the quest heading")
    local sizeRow = ui.questNoticeSize
    A.ok(sizeRow and sizeRow:GetParent() == page and sizeRow.value:GetText() == "Default", "Text size defaults on Misc.")
    A.ok(-sizeRow._points[1][5] >= -point[5] + choice:GetHeight(), "Text size sits under Quest updates")
    A.ok(-sizeRow._points[1][5] + sizeRow:GetHeight() <= page:GetHeight(), "Text size must fit Misc. content")
    for index, tab in ipairs(ui.tabs) do
        click(tab)
        A.eq(ui:GetHeight(), height, "Tab switch must not resize setup")
        A.ok(ui.pages[index]:IsShown(), "Selected tab must show its page")
        for other, p in ipairs(ui.pages) do
            A.eq(p:IsShown(), index == other, "Only selected page may be shown")
        end
    end
end)
