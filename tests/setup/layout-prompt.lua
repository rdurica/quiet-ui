-- Structural contracts only; actual overlap/chrome clipping require /reload in WoW.
-- The window is built over a small frame model that tracks levels, strata, textures and
-- backdrops, because the mock frames do not model stacking.
local h = ...
local M = h.lib("setupmodel")
local same, scenario, opaque, darkControl, nativeAction = M.same, M.scenario, M.opaque, M.darkControl, M.nativeAction
local goldSmall, tint, fillBounds, click, modes = M.goldSmall, M.tint, M.fillBounds, M.click, M.modes

for _, mode in ipairs(modes) do
    h.test('layout prompt appearance: ' .. mode.name, function(t)
        local failures = {}
        local function expect(value, message)
            if not value then failures[#failures + 1] = message end
        end
        local ns, objects, layoutState = scenario(t, mode)
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
        -- Later sibling dialogs may have escalated their levels before the prompt opens.
        other:SetFrameLevel(700)
        raisedContent:SetFrameLevel(other.level + 100)
        otherLevel, cardLevel, descendantLevel = other.level, card.level, raisedContent.level
        ns.Setup.Show()
        local ui = QuietUISetup
        -- Prompt must not mutate layouts/hash simply by appearing or hiding.
        ns.Layout.Ensure()
        local prompt
        for _, object in ipairs(objects) do
            if object.parent == UIParent and object.yes and object.no then prompt = object end
        end
        assert(prompt, 'layout prompt fixture did not open')
        local writes = layoutState()
        expect(writes == 0 and QuietUIDB.layoutHash == nil, 'opening layout prompt does not imply consent')
        expect(opaque(prompt), 'layout prompt has independent opaque fill')
        expect(fillBounds(prompt, opaque(prompt)), 'prompt fill stays behind gear/chrome and inside bounds')
        expect(prompt:GetFrameStrata() == 'DIALOG' and prompt.level > other.level, 'layout prompt raises above ordinary sibling dialog')
        expect(prompt.yes.level > prompt.level and prompt.no.level > prompt.level, 'prompt controls are above its fill')
        expect(actionStyle(prompt.yes) and actionStyle(prompt.no), 'layout prompt actions use native appearance or missing-template fallback')
        expect(aboveForeign(prompt), 'layout prompt fill is above foreign DIALOG descendants')
        expect(prompt.yes.level > raisedContent.level, 'layout prompt controls are above foreign DIALOG descendants')
        expect(preservedForeign(), 'layout prompt preserves foreign dialog and higher strata state')
        if mode.portrait then
            expect(prompt.portrait.shown and prompt.portrait.texture ~= nil and prompt.portrait.texture ~= 'player'
                and not prompt.CloseButton.shown, 'gear chrome preserved and unanswered close hidden')
        elseif mode.backdrop then expect(prompt.backdrop and prompt.backdrop.edgeFile:find('Gold'), 'layout prompt keeps gold fallback') end
        prompt:Hide()
        expect(QuietUIDB.layoutHash == nil and layoutState() == writes, 'hiding prompt records no answer')
        prompt:Show(); click(prompt.no)
        expect(QuietUIDB.layoutHash ~= nil and layoutState() == writes, 'Not now records consent answer without writing layout')
        click(ui.import)
        expect(layoutState() == writes + 1, 'Import layout writes immediately after Not now')
        expect(QuietUIDB.enabled == false, 'dialogs and import preserve disabled addon')
        t.assert.eq(#failures, 0, table.concat(failures, '; '))
    end)

    for _, update in ipairs({ false, true }) do
        h.test('layout consent action: ' .. (update and 'Update' or 'Add') .. ', ' .. mode.name, function(t)
            local addNs, addObjects, addState = scenario(t, mode)
            local _, info = addState()
            if update then info.layouts[2] = { layoutName = 'QuietUI', layoutType = 1 } end
            addNs.Layout.Ensure()
            local addPrompt
            for _, object in ipairs(addObjects) do if object.yes and object.no then addPrompt = object end end
            t.assert.ok(addPrompt, 'Add/Update prompt fixture did not open')
            local label = addPrompt.yes.label and addPrompt.yes.label.text or addPrompt.yes.text
            t.assert.eq(label, update and 'Update' or 'Add', 'correct consent action label')
            click(addPrompt.yes)
            t.assert.ok(addState() == 1 and QuietUIDB.layoutHash ~= nil, 'Add/Update writes and records answer once')
        end)
    end
end
