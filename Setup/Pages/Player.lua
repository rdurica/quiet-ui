local _, ns = ...

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

Setup.Pages.player = function(widget, player)
    widget.player = Setup.Section(player, "Player S.frame",
        "Control the player portrait and pet, and whether buffs follow their visibility. Choose Health or Resource and a whole percentage from 1 to 100 to show them below that threshold; empty ignores it. The default is Health below 70%. Resource means mana, focus or energy. Combat and instances still show them regardless of these fields. Death or ghost form hides only the player portrait, except during Glance or Edit Mode; the pet and buffs keep their usual rules. Always show debuffs keeps debuffs visible independently. Require a living target fades the player, pet and target frames for a dead target, except during Glance or in Edit Mode. The selected percentage threshold still shows the player and pet, but not the dead target.")
    widget.player:SetPoint("TOPLEFT", player, "TOPLEFT", 0, 0)
    widget.playerRow = Setup.Choice(player, "Player S.frame", function()
        draft.player = not draft.player
        Setup.Paint()
    end)
    widget.playerRow:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -20)
    widget.playerThresholdKind = Setup.Stepper(player, "Show below", function()
        draft.playerThresholdKind = draft.playerThresholdKind == "health" and "resource" or "health"
        Setup.Paint()
    end)
    widget.playerThresholdKind:SetSize(240, 22)
    widget.playerThresholdKind:SetPoint("TOPLEFT", player, "TOPLEFT", 24, -50)
    widget.playerThresholdKind.value:SetWidth(92)
    widget.playerThresholdPercent = Setup.PercentField(player, "%", "playerThresholdPercent")
    widget.playerThresholdPercent:SetSize(72, 22)
    widget.playerThresholdPercent:SetPoint("TOPLEFT", widget.playerThresholdKind, "TOPRIGHT", 12, 0)
    widget.playerThresholdPercent.edit:SetSize(52, 22)
    widget.playerThresholdPercent.edit:ClearAllPoints()
    widget.playerThresholdPercent.edit:SetPoint("LEFT", 0, 0)
    widget.playerThresholdPercent.label:ClearAllPoints()
    widget.playerThresholdPercent.label:SetPoint("LEFT", widget.playerThresholdPercent.edit, "RIGHT", 4, 0)
    widget.groupAuras = Setup.Choice(player, "Group buffs and debuffs with player S.frame", function()
        draft.groupAuras = not draft.groupAuras
        Setup.Paint()
    end)
    widget.groupAuras:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -84)
    widget.requireLivingTarget = Setup.Choice(player, "Require a living target for player and target frames", function()
        draft.requireLivingTarget = not draft.requireLivingTarget
        Setup.Paint()
    end)
    widget.requireLivingTarget:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -112)
    widget.alwaysShowDebuffs = Setup.Choice(player, "Always show debuffs", function()
        draft.alwaysShowDebuffs = not draft.alwaysShowDebuffs
        Setup.Paint()
    end)
    widget.alwaysShowDebuffs:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -140)
    widget.rangeHeader = Setup.Section(player, "Range",
        "Adds a green indicator to the current target's nameplate health bar while in range. Always visible bar groups do not block it. Choose 10 yards, 28 yards or Spell. An empty spell field uses the longest matching spell on Bar 1.")
    widget.rangeHeader:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -178)
    widget.range = Setup.Choice(player, "In range", function()
        draft.range = not draft.range
        Setup.Paint()
    end)
    widget.range:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -200)
    widget.rangeYards = Setup.Stepper(player, "Within", function(sign)
        Setup.NudgeRangeYards(sign)
    end)
    widget.rangeYards:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -224)
    widget.rangeYards.value:SetWidth(92)
    widget.rangeKind = Setup.Stepper(player, "Who", function()
        Setup.NudgeRangeKind()
    end)
    widget.rangeKind:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -248)
    widget.rangeKind.value:SetWidth(92)
    widget.rangeSpell = Setup.SpellField(player)
    widget.rangeSpell:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -272)

end
