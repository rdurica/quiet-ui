-- Structural contracts only; actual overlap/chrome clipping require /reload in WoW.
-- The window is built over a small frame model that tracks levels, strata, textures and
-- backdrops, because the mock frames do not model stacking.
local h = ...
local M = h.lib("setupmodel")
local same, scenario, opaque, darkControl, nativeAction = M.same, M.scenario, M.opaque, M.darkControl, M.nativeAction
local goldSmall, tint, fillBounds, click, modes = M.goldSmall, M.tint, M.fillBounds, M.click, M.modes

for _, mode in ipairs(modes) do
    h.test('setup window appearance: ' .. mode.name, function(t)
        local failures = {}
        local function expect(value, message)
            if not value then failures[#failures + 1] = message end
        end
        local ns = scenario(t, mode)
        local other = CreateFrame('Frame', nil, UIParent)
        other:SetFrameStrata('DIALOG'); other:SetFrameLevel(500)
        -- Topology from ../ForeverDungeonJournal/ForeverDungeonJournal.lua:
        -- DIALOG root -> homePanel -> homeScroll -> homeCardsContent -> card.
        local home = CreateFrame('Frame', nil, other)
        local scroll = CreateFrame('ScrollFrame', nil, home)
        local content = CreateFrame('Frame', nil, scroll)
        scroll:SetScrollChild(content)
        local card = CreateFrame('Button', nil, content)
        local cover = card:CreateTexture(nil, 'ARTWORK')
        cover:SetColorTexture(1, 0, 0, 1)
        -- A second ordinary DIALOG descendant can have an explicit higher level.
        local raisedContent = CreateFrame('Frame', nil, other)
        raisedContent:SetFrameLevel(other.level + 80)
        local forbidden = CreateFrame('Frame', nil, other)
        forbidden.forbidden = true
        local tooltip = CreateFrame('Frame', nil, UIParent)
        tooltip:SetFrameStrata('TOOLTIP'); tooltip:SetFrameLevel(2000)
        local fullscreen = CreateFrame('Frame', nil, UIParent)
        fullscreen:SetFrameStrata('FULLSCREEN'); fullscreen:SetFrameLevel(3000)
        local otherLevel, otherAlpha = other.level, other.alpha
        local cardLevel, descendantLevel = card.level, raisedContent.level
        local function aboveForeign(window)
            local fill = opaque(window)
            return fill and fill.parent.level > card.level and fill.parent.level > raisedContent.level
        end
        local function preservedForeign()
            return other.level == otherLevel and other.alpha == otherAlpha and other.shown
                and card.level == cardLevel and raisedContent.level == descendantLevel
                and tooltip.level == 2000 and tooltip.strata == 'TOOLTIP' and tooltip.alpha == 1 and tooltip.shown
                and fullscreen.level == 3000 and fullscreen.strata == 'FULLSCREEN' and fullscreen.alpha == 1 and fullscreen.shown
        end
        local function actionStyle(button)
            return mode.nativeButtons == false and darkControl(button) or nativeAction(button)
        end
        ns.Setup.Show()
        local ui = QuietUISetup
        expect(opaque(ui), 'setup has its own opaque dark background independent of SetBackdrop')
        expect(fillBounds(ui, opaque(ui)), 'setup fill stays behind chrome and within window bounds')
        expect(ui:GetFrameStrata() == 'DIALOG' and ui.level > other.level, 'setup opening raises over sibling DIALOG')
        expect(aboveForeign(ui), 'continuous setup fill is above foreign DIALOG descendants, including scroll content')
        expect(ui.save.level > raisedContent.level, 'setup controls are above foreign DIALOG descendants')
        expect(ui:GetFrameLevel() < tooltip.level, 'higher strata do not inflate DIALOG priority')
        expect(preservedForeign(), 'foreign dialog descendants, tooltip and fullscreen state are preserved')
        expect(QuietUIDB.enabled == false, 'setup opening preserves disabled addon')
        if mode.portrait then
            expect(ui.portrait.texture == 'player' and ui.portrait.shown and ui.TitleText.text == 'QuietUI'
                and ui.CloseButton.shown, 'portrait title and close chrome are preserved')
        elseif mode.backdrop then
            expect(ui.backdrop and ui.backdrop.edgeFile:find('Gold'), 'gold fallback keeps gold frame')
        else expect(ui.title and ui.close, 'flat fallback keeps title and usable close') end
        local height, width = ui.height, ui.width
        local labels = { 'General', 'Visible', 'Bars', 'Groups', 'Player', 'Misc.', 'Modern', 'Info' }
        expect(#ui.tabs == 8, 'eight tabs')
        for index, tab in ipairs(ui.tabs) do
            click(tab)
            expect(tab.label.text == labels[index], 'tab order ' .. index)
            expect(same(tab.label.textColor, 0.95, 0.75, 0.25), 'active tab uses gold accent without hover: ' .. labels[index])
            expect(ui.height == height and ui.width == width, 'switching tabs keeps window geometry')
            local pageTop = ui.pages[index].points[1][3]
            local footerTop = height - ui.save.points[1][3] - ui.save.height
            expect(-pageTop + ui.pages[index].height <= footerTop, 'page body does not overlap footer: ' .. labels[index])
            for otherIndex, otherTab in ipairs(ui.tabs) do
                if otherIndex ~= index then
                    expect(not same(otherTab.label.textColor, 0.95, 0.75, 0.25), 'inactive tabs differ from selected gold tab')
                end
            end
            for pageIndex, page in ipairs(ui.pages) do expect(page.shown == (pageIndex == index), 'only selected page is shown') end
        end
        click(ui.tabs[1])
        expect(ui.presetSelector.width == ui.pages[1].width and ui.layoutSelector.width == ui.pages[1].width,
            'General selectors span content width')
        for _, button in ipairs({ ui.presetSelector, ui.layoutSelector, ui.newPreset, ui.renamePreset,
            ui.deletePreset, ui.reset, ui.import, ui.save }) do
            expect(actionStyle(button), 'native action appearance or dark missing-template fallback: ' .. (button.text ~= '' and button.text or button.label.text))
        end
        for _, button in ipairs(ui.tabs) do
            expect(goldSmall(button), 'each small tab retains gold styling')
        end
        for _, button in ipairs({ ui.groupRows[1].minus, ui.groupRows[1].plus }) do
            expect(goldSmall(button), 'small tabs and steppers retain gold styling')
        end
        expect(ui.renamePreset.disabled and ui.deletePreset.disabled, 'unavailable preset actions remain disabled')
        local disabledAlpha, disabledLabelAlpha, disabledColor, disabledFont = tint(ui.renamePreset)
        expect(ui.newPreset.width == ui.renamePreset.width and ui.renamePreset.width == ui.deletePreset.width,
            'preset actions have uniform width')
        expect(ui.newPreset.width >= #'New preset' * 6, 'preset action label fits')
        local left = ui.newPreset.points[1][4]
        local middle = ui.renamePreset.points[1][4]
        local right = ui.pages[1].width + ui.deletePreset.points[1][4] - ui.deletePreset.width
        expect(middle - left - ui.newPreset.width == right - middle - ui.renamePreset.width,
            'General preset action gaps are equal')
        click(ui.presetSelector)
        expect(opaque(ui.presetMenu), 'preset menu has independent opaque fill')
        expect(ui.presetMenu.level > ui.save.level and ui.presetMenu.items[1].level > ui.presetMenu.level,
            'preset menu and entries are above main controls')
        click(ui.presetSelector); expect(not ui.presetMenu.shown, 'selector toggles menu closed')
        click(ui.newPreset)
        local dialog = ui.presetDialog
        expect(opaque(dialog), 'preset dialog has independent opaque fill')
        expect(fillBounds(dialog, opaque(dialog)), 'preset dialog fill stays behind chrome and inside bounds')
        expect(dialog.level > dialog.blocker.level and dialog.blocker.level > ui.save.level
            and dialog.yes.level > dialog.level and dialog.no.level > dialog.level,
            'modal controls and mouse blocker stay above main content')
        expect(dialog.blocker.mouse and dialog.blocker.allPoints == ui and dialog.blocker.shown,
            'modal blocker covers setup and intercepts mouse')
        expect(actionStyle(dialog.yes) and actionStyle(dialog.no), 'modal actions use native appearance or missing-template fallback')
        dialog.edit:SetText('Appearance'); click(dialog.yes); click(ui.save)
        expect(ui.shown and QuietUICharDB.presetId and QuietUIDB.enabled == false, 'Save commits preset and keeps disabled setup open')
        local enabledAlpha, enabledLabelAlpha, enabledColor, enabledFont = tint(ui.renamePreset)
        expect(disabledAlpha ~= enabledAlpha or disabledLabelAlpha ~= enabledLabelAlpha or disabledColor ~= enabledColor or disabledFont ~= enabledFont,
            'disabled actions are visibly distinguished from enabled actions')
        click(ui.layoutSelector)
        expect(opaque(ui.layoutMenu), 'layout menu has independent opaque fill')
        expect(ui.layoutMenu.level > ui.save.level and ui.layoutMenu.items[1].level > ui.layoutMenu.level,
            'layout menu entries stay above owner')
        click(ui.layoutMenu.items[#ui.layoutMenu.items])
        expect(not ui.layoutMenu.shown, 'layout selection closes menu')
        ui:Hide(); other:SetFrameLevel(ui.level + 200)
        raisedContent:SetFrameLevel(other.level + 100)
        otherLevel, cardLevel, descendantLevel = other.level, card.level, raisedContent.level
        ns.Setup.Show()
        expect(ui.level > other.level, 'reopening raises over later sibling dialogs')
        expect(aboveForeign(ui), 'reopening brings the whole setup fill above later foreign descendant escalation')
        expect(preservedForeign(), 'reopening preserves foreign descendant state')
        click(ui.presetSelector)
        expect(ui.presetMenu.level > ui.save.level, 'reused preset menu stays above raised owner')
        click(ui.renamePreset)
        expect(dialog.level > dialog.blocker.level and dialog.blocker.level > ui.save.level
            and dialog.yes.level > dialog.level, 'reused modal stays above raised owner')
        dialog.edit:SetText('Renamed'); click(dialog.yes); click(ui.save)
        expect(ns.Settings.ActivePreset().name == 'Renamed', 'renaming still saves through draft')
        click(ui.deletePreset); click(dialog.no)
        expect(ns.Settings.ActivePreset() ~= nil, 'cancel deletion preserves preset')
        click(ui.deletePreset); click(dialog.yes)
        expect(not ns.Settings.ActivePreset(), 'confirmed deletion remains immediate')
        ui.chat.scripts.OnClick(); ui:Hide(); ns.Setup.Show()
        expect(QuietUICharDB.chat == nil, 'closing discards changed draft')
        local escape = false
        for _, name in ipairs(UISpecialFrames) do if name == 'QuietUISetup' then escape = true end end
        expect(escape, 'Escape retains named-frame closing registration')
        click(ui.reset)
        expect(ui.shown and QuietUICharDB.chat == nil and QuietUICharDB.chatFade == nil,
            'Reset saves defaults and leaves setup open')
        t.assert.eq(#failures, 0, table.concat(failures, '; '))
    end)
end
