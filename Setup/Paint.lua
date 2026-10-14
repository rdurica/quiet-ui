local _, ns = ...

-- Paints the window from the draft.
local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

local function FadeText(seconds)
    if not seconds or seconds <= 0 then return "Stay" end
    return seconds .. " s"
end


local function RangeYardsText(yards)
    if yards == 10 then return "10" end
    if yards == 28 then return "28" end
    return "Spell"
end

local function RangeKindText(kind)
    if kind == "friendly" then return "Friendly" end
    return "Unfriendly"
end

function Setup.Paint()
    if not S.frame then return end
    if S.frame.presetSelector then
        Setup.ButtonText(S.frame.presetSelector, S.presetName or "<no preset>")
        Setup.ButtonText(S.frame.layoutSelector, ns.Layout.Label and ns.Layout.Label(S.presetLayout)
            or (S.presetLayout and S.presetLayout.layoutName or "Choose layout"))
        if S.presetName then
            S.frame.forceLayout:Hide()
            S.frame.layoutSelector:Show()
            S.frame.renamePreset:Enable()
            if S.selectedPresetId then S.frame.deletePreset:Enable() else S.frame.deletePreset:Disable() end
        else
            S.frame.forceLayout:Show()
            S.frame.layoutSelector:Hide()
            S.frame.renamePreset:Disable()
            S.frame.deletePreset:Disable()
        end
        S.frame.renamePreset:SetAlpha(S.presetName and 1 or 0.45)
        S.frame.deletePreset:SetAlpha(S.selectedPresetId and 1 or 0.45)
    end
    for _, row in ipairs(S.frame.rows) do
        Setup.PaintBox(row.always.box, draft[row.key])
        Setup.PaintBox(row.hover.box, draft.hoverOnly[row.key])
    end
    if S.frame.forceLayout then
        Setup.PaintBox(S.frame.forceLayout.box, draft.forceLayout)
    end
    if S.frame.playerRow then
        Setup.PaintBox(S.frame.playerRow.box, draft.player)
    end
    if S.frame.playerThresholdKind then
        S.frame.playerThresholdKind.value:SetText(draft.playerThresholdKind == "resource" and "Resource" or "Health")
        if draft.player then S.frame.playerThresholdKind:Show() else S.frame.playerThresholdKind:Hide() end
    end
    if S.frame.playerThresholdPercent then
        local row = S.frame.playerThresholdPercent
        if row.edit:GetText() ~= draft.playerThresholdPercent then row.edit:SetText(draft.playerThresholdPercent) end
        if draft.player then row:Show() else row.edit:ClearFocus(); row:Hide() end
    end
    if S.frame.requireLivingTarget then
        Setup.PaintBox(S.frame.requireLivingTarget.box, draft.requireLivingTarget)
    end
    if S.frame.groupAuras then
        Setup.PaintBox(S.frame.groupAuras.box, draft.groupAuras)
    end
    if S.frame.alwaysShowDebuffs then
        Setup.PaintBox(S.frame.alwaysShowDebuffs.box, draft.alwaysShowDebuffs)
    end
    if S.frame.questNotice then
        Setup.PaintBox(S.frame.questNotice.box, draft.questNotice)
    end
    if S.frame.questMobs then Setup.PaintBox(S.frame.questMobs.box, draft.questMobs) end
    if S.frame.chatTabs then
        S.frame.chatTabs.value:SetText(draft.chatTabs == "top" and "Top" or "Bottom")
    end
    if S.frame.questNoticeSize then
        local size = draft.questNoticeSize
        S.frame.questNoticeSize.value:SetText(size == "smaller" and "Smaller" or size == "larger" and "Larger" or "Default")
    end
    if S.frame.highlightHerb then Setup.PaintBox(S.frame.highlightHerb.box, draft.highlightHerb) end
    if S.frame.highlightOre then Setup.PaintBox(S.frame.highlightOre.box, draft.highlightOre) end
    if S.frame.highlightQuest then Setup.PaintBox(S.frame.highlightQuest.box, draft.highlightQuest) end
    if S.frame.chat then
        Setup.PaintBox(S.frame.chat.box, draft.chat)
    end
    if S.frame.fade then
        S.frame.fade.value:SetText(FadeText(draft.chatFade))
    end
    if S.frame.range then
        Setup.PaintBox(S.frame.range.box, draft.range)
    end
    if S.frame.rangeYards then
        S.frame.rangeYards.value:SetText(RangeYardsText(draft.rangeYards))
    end
    if S.frame.rangeKind then
        S.frame.rangeKind.value:SetText(RangeKindText(draft.rangeKind))
    end
    if S.frame.rangeSpell then
        if draft.rangeYards == "spell" then
            S.frame.rangeSpell:Show()
        else
            if S.frame.rangeSpell.edit and S.frame.rangeSpell.edit:HasFocus() then
                S.frame.rangeSpell.edit:ClearFocus()
            end
            S.frame.rangeSpell:Hide()
        end
        if S.frame.rangeSpell.edit and not S.frame.rangeSpell.edit:HasFocus() then
            local text = draft.rangeSpell or ""
            if S.frame.rangeSpell.edit:GetText() ~= text then
                S.frame.rangeSpell.edit:SetText(text)
            end
        end
    end
    if S.frame.groupRows then
        for _, row in ipairs(S.frame.groupRows) do
            row.value:SetText(tostring(draft.groups[row.id]))
            Setup.PaintBox(row.hostile.box, draft.hostile[row.id])
            Setup.PaintBox(row.friendly.box, draft.friendly[row.id])
            local mode = draft.groupVisibility[draft.groups[row.id]]
            for _, button in ipairs({ row.hostile, row.friendly }) do
                if mode then button:Disable() else button:Enable() end
                button:SetAlpha(mode and 0.4 or 1)
                button.mode = mode
                button.group = draft.groups[row.id]
            end
        end
    end
    if S.frame.visibilityRows then
        local members = {}
        for _, bar in ipairs(ns.BAR_ROWS) do
            local group = draft.groups[bar.id]
            members[group] = members[group] or {}
            members[group][#members[group] + 1] = bar.label
        end
        local count = 0
        for group, row in ipairs(S.frame.visibilityRows) do
            if members[group] then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", S.frame.groupContent, "TOPLEFT", 0, -count * 44)
                row.members:SetText(table.concat(members[group], ", "))
                Setup.PaintBox(row.always.box, draft.groupVisibility[group] == "always")
                Setup.PaintBox(row.hover.box, draft.groupVisibility[group] == "hover")
                row:Show()
                count = count + 1
            else row:Hide() end
        end
        S.frame.groupContent:SetHeight(math.max(1, count * 44))
        local max = math.max(0, count * 44 - Setup.GROUP_VIEW_H)
        S.frame.groupScroll:SetVerticalScroll(math.min(S.frame.groupScroll:GetVerticalScroll(), max))
    end
    if S.frame.tabs then
        for _, tab in ipairs(S.frame.tabs) do
            local on = tab.id == S.frame.page
            if tab.SetBackdropBorderColor then
                if on then tab:SetBackdropBorderColor(0.95, 0.75, 0.25, 1)
                else tab:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95) end
            end
            if tab.label and tab.label.SetTextColor then
                if on then tab.label:SetTextColor(0.95, 0.75, 0.25)
                else tab.label:SetTextColor(0.85, 0.85, 0.85) end
            end
        end
    end
end
