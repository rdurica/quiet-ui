local _, ns = ...

-- The class and profession trainer (ClassTrainerFrame, Blizzard_TrainerUI, Forever UI source): the dark window with
-- the shared shapes, the trainer background and money border held, category headers as section strips with an
-- accent plus / minus, and skill rows that lose their plate and show a square spell icon in a thin border. The
-- selection mark, disabled shading, lock icon, costs and the skill bar fill stay Blizzard's. Rows are pooled, so
-- the window is walked again when the list updates.

local Modern = ns.Modern
local Trainer = {}
Modern.Trainer = Trainer

local HEADER_PIECES = { "LeftPiece", "RightPiece", "CenterPiece" }
local ART = { "ClassTrainerFrameMoneyBg", "ClassTrainerFrameBg" }

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function Category(skin, header)
    for _, key in ipairs(HEADER_PIECES) do Hold(skin, header[key]) end
    Modern.Strip(skin, header)
    if IsTexture(header.CollapseIcon) then
        Hold(skin, header.CollapseIconAlphaAdd)
        Modern.Expander(skin, header.CollapseIcon)
    end
end

local function Skill(skin, row)
    if type(row.GetNormalTexture) == "function" then Hold(skin, row:GetNormalTexture()) end
    local icon = row.icon
    if not IsTexture(icon) then return end
    skin:Icon(icon)
    skin:Border(row, nil, icon)
end

-- The rows the shared shapes do not know.
local function Particular(skin, frame)
    if IsTexture(frame.LeftPiece) and IsTexture(frame.CenterPiece) then
        Category(skin, frame)
        return true
    end
    if IsTexture(frame.icon) and IsTexture(frame.selectedTex) then
        Skill(skin, frame)
    end
    return false
end

local OPTIONS = { shape = Particular }

local function Skin(skin, frame)
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    Hold(skin, frame.BG)
    for _, name in ipairs(ART) do Hold(skin, _G[name]) end
    Modern.Shapes.Walk(skin, frame, OPTIONS)
end

function Trainer.Apply(skin, frame)
    Modern.Shapes.Keep(skin, frame, "trainer", Skin)
end
