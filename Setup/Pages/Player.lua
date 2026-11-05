local _, ns = ...

local Setup = ns.Setup
local draft = Setup.draft

-- Steppers stay short on this wide page, so a label sits near its controls.
local STEPPER_W = 360
local INDENT = 28

Setup.Pages.player = function(widget, player)
    local column = Setup.Column(player, 0, Setup.CONTENT_W)
    widget.player = column:Add(Setup.Section(player, "Player frame",
        "Control the player portrait and pet, and whether buffs follow their visibility. Choose Health or Resource and a whole percentage from 1 to 100 to show them below that threshold; empty ignores it. The default is Health below 70%. Resource means mana, focus or energy. Combat and instances still show them regardless of these fields. Death or ghost form hides only the player portrait, except during Glance or Edit Mode; the pet and buffs keep their usual rules. Always show debuffs keeps debuffs visible independently. Require a living target fades the player, pet and target frames for a dead target, except during Glance or in Edit Mode. The selected percentage threshold still shows the player and pet, but not the dead target."), 30)
    widget.playerRow = column:Add(Setup.Choice(player, "Player frame", function()
        draft.player = not draft.player
        Setup.Paint()
    end))
    widget.playerThresholdKind = Setup.Stepper(player, "Show below", function()
        draft.playerThresholdKind = draft.playerThresholdKind == "health" and "resource" or "health"
        Setup.Paint()
    end)
    widget.playerThresholdKind.value:SetWidth(92)
    widget.playerThresholdPercent = Setup.PercentField(player, "%", "playerThresholdPercent")
    widget.playerThresholdPercent:SetSize(80, 24)
    widget.playerThresholdPercent:SetPoint("LEFT", widget.playerThresholdKind, "RIGHT", 12, 0)
    widget.playerThresholdPercent.edit:SetSize(56, 24)
    widget.playerThresholdPercent.edit:ClearAllPoints()
    widget.playerThresholdPercent.edit:SetPoint("LEFT", 0, 0)
    widget.playerThresholdPercent.label:ClearAllPoints()
    widget.playerThresholdPercent.label:SetPoint("LEFT", widget.playerThresholdPercent.edit, "RIGHT", 6, 0)
    column:Add(widget.playerThresholdKind, Setup.ROW, INDENT, STEPPER_W - INDENT)
    widget.groupAuras = column:Add(Setup.Choice(player, "Group buffs and debuffs with player frame", function()
        draft.groupAuras = not draft.groupAuras
        Setup.Paint()
    end))
    widget.requireLivingTarget = column:Add(Setup.Choice(player, "Require a living target for player and target frames", function()
        draft.requireLivingTarget = not draft.requireLivingTarget
        Setup.Paint()
    end))
    widget.alwaysShowDebuffs = column:Add(Setup.Choice(player, "Always show debuffs", function()
        draft.alwaysShowDebuffs = not draft.alwaysShowDebuffs
        Setup.Paint()
    end))
    column:Gap()
    widget.rangeHeader = column:Add(Setup.Section(player, "Range",
        "Adds a green indicator to the current target's nameplate health bar while in range. Always visible bar groups do not block it. Choose 10 yards, 28 yards or Spell. An empty spell field uses the longest matching spell on Bar 1."), 30)
    widget.range = column:Add(Setup.Choice(player, "In range", function()
        draft.range = not draft.range
        Setup.Paint()
    end))
    widget.rangeYards = column:Add(Setup.Stepper(player, "Within", function(sign)
        Setup.NudgeRangeYards(sign)
    end), Setup.ROW, INDENT, STEPPER_W - INDENT)
    widget.rangeYards.value:SetWidth(92)
    widget.rangeKind = column:Add(Setup.Stepper(player, "Who", function()
        Setup.NudgeRangeKind()
    end), Setup.ROW, INDENT, STEPPER_W - INDENT)
    widget.rangeKind.value:SetWidth(92)
    widget.rangeSpell = column:Add(Setup.SpellField(player), Setup.ROW, INDENT, STEPPER_W - INDENT)
end
