local _, ns = ...

-- Dark ink made for Blizzard's parchment pages becomes light text of the same hue on the dark panel. The font
-- string keeps Blizzard's colour calls: a hook answers each new ink, Undo puts back the ink Blizzard set last.
-- A SimpleHTML page (item text) is coloured per element. A font inked with a tone takes that colour instead,
-- so body text can be neutral while headings keep the mirrored gold; the headings of a page are its H elements.
-- A plain font also trades the serif parchment face for Arial Narrow with a dark shadow, which reads better on a dark
-- panel; Undo puts back Blizzard's last font object (or face) and shadow.

local Modern = ns.Modern

-- Below this luminance a text colour is ink; grey state colours and gold or white text stay.
local INK = 0.35
local ELEMENTS = { "P", "H1", "H2", "H3" }
-- Descendant depth of an ink scan: deep enough for scroll children and pooled list buttons.
local DEPTH = 7

local inked = setmetatable({}, { __mode = "k" })   -- font -> Blizzard's last ink per element, while applied
local styles = setmetatable({}, { __mode = "k" })  -- font -> { tone, plain }, while applied
local dressed = setmetatable({}, { __mode = "k" }) -- font -> Blizzard's font object or face and shadow, while plain
local hooked = setmetatable({}, { __mode = "k" })
local busy = false

local function Luminance(r, g, b)
    return 0.3 * r + 0.59 * g + 0.11 * b
end

-- The same hue at the mirrored luminance (brown turns gold), capped at full channel; nil when not ink.
local function Light(r, g, b)
    if type(r) ~= "number" or ns.IsSecret(r) or type(g) ~= "number" or type(b) ~= "number" then return end
    local l = Luminance(r, g, b)
    if l >= INK then return end
    if l <= 0 then return 1, 1, 1 end
    local f = (1 - l) / l
    return math.min(1, r * f), math.min(1, g * f), math.min(1, b * f)
end

local function IsHTML(font)
    return type(font.GetObjectType) == "function" and font:GetObjectType() == "SimpleHTML"
end

-- Arial Narrow carries Central European letters (ě, ř, ů), which FRIZQT__ of the enUS client lacks. It looks a
-- point smaller than the parchment faces.
local FACE, GROW = "Fonts\\ARIALN.TTF", 1

local function IsFace(face)
    return type(face) == "string" and face:lower():gsub("/", "\\") == FACE:lower()
end

-- Arial Narrow a point above Blizzard's size, Blizzard's flags, a dark shadow.
local function Dress(font)
    local ok, face, size, flags = pcall(font.GetFont, font)
    if not ok or type(size) ~= "number" or ns.IsSecret(size) then return end
    if not dressed[font] then
        local saved = { font = { face, size, flags } }
        if type(font.GetFontObject) == "function" then
            local okObject, object = pcall(font.GetFontObject, font)
            if okObject then saved.object = object end
        end
        if type(font.GetShadowColor) == "function" then saved.shadow = { font:GetShadowColor() } end
        if type(font.GetShadowOffset) == "function" then saved.offset = { font:GetShadowOffset() } end
        dressed[font] = saved
    end
    if not IsFace(face) then pcall(font.SetFont, font, FACE, size + GROW, flags or "") end
    pcall(font.SetShadowColor, font, 0, 0, 0, 1)
    pcall(font.SetShadowOffset, font, 1, -1)
end

local function Undress(font)
    local saved = dressed[font]
    dressed[font] = nil
    if not saved then return end
    if saved.object then
        pcall(font.SetFontObject, font, saved.object)
    else
        pcall(font.SetFont, font, saved.font[1], saved.font[2], saved.font[3] or "")
    end
    if saved.shadow then pcall(font.SetShadowColor, font, unpack(saved.shadow, 1, 4)) end
    if saved.offset then pcall(font.SetShadowOffset, font, unpack(saved.offset, 1, 2)) end
end

-- `element` is nil for a font string, an element name for a SimpleHTML page.
local function Lighten(font, element)
    local ink = inked[font]
    if busy or not ink then return end
    local ok, r, g, b, a
    if element then
        ok, r, g, b, a = pcall(font.GetTextColor, font, element)
    else
        ok, r, g, b, a = pcall(font.GetTextColor, font)
    end
    if not ok then return end
    local lr, lg, lb = Light(r, g, b)
    if not lr then return end
    local style = styles[font] or {}
    local tone = style.tone
    if tone and (not element or element == "P") then lr, lg, lb = tone[1], tone[2], tone[3] end
    ink[element or 1] = { r, g, b, a }
    busy = true
    if element then
        pcall(font.SetTextColor, font, element, lr, lg, lb, a)
    else
        if style.plain then Dress(font) end
        pcall(font.SetTextColor, font, lr, lg, lb, a)
    end
    busy = false
end

local function LightenAll(font)
    if IsHTML(font) then
        for _, element in ipairs(ELEMENTS) do Lighten(font, element) end
    else
        Lighten(font)
    end
end

local function Hook(font)
    if hooked[font] then return end
    hooked[font] = true
    local html = IsHTML(font)
    pcall(hooksecurefunc, font, "SetTextColor", function(_, element)
        if html then
            if type(element) == "string" then ns.Run("modern ink", Lighten, font, element) end
        else
            ns.Run("modern ink", Lighten, font)
        end
    end)
    if type(font.SetFontObject) == "function" then
        pcall(hooksecurefunc, font, "SetFontObject", function(_, object)
            if busy then return end
            -- Blizzard's new font object is what Undo puts back.
            if dressed[font] then dressed[font].object = object end
            ns.Run("modern ink", LightenAll, font)
        end)
    end
end

-- `tone` (optional) is the colour dark body ink becomes; without it ink is mirrored. `plain` swaps the face.
function Modern.Ink(skin, font, tone, plain)
    if not ns.Usable(font) or type(font.GetTextColor) ~= "function" or type(font.SetTextColor) ~= "function" then
        return
    end
    if not inked[font] then
        inked[font] = {}
        skin:Remember(font, "modern ink", function()
            local ink = inked[font]
            inked[font] = nil
            styles[font] = nil
            busy = true
            Undress(font)
            busy = false
            for key, color in pairs(ink or {}) do
                if key == 1 then
                    pcall(font.SetTextColor, font, unpack(color, 1, 4))
                else
                    pcall(font.SetTextColor, font, key, unpack(color, 1, 4))
                end
            end
        end)
    end
    styles[font] = { tone = tone, plain = plain }
    LightenAll(font)
    Hook(font)
end

local function IsText(obj)
    if type(obj.GetObjectType) ~= "function" then return false end
    local kind = obj:GetObjectType()
    return kind == "FontString" or kind == "SimpleHTML"
end

-- Every font string and SimpleHTML page under `frame`; pooled ones are found again on the next scan.
-- `style` (optional): `tone` and `plain` as for Modern.Ink, and `heading(font)` picking the fonts that keep
-- the mirrored ink.
function Modern.InkTree(skin, frame, style, depth)
    depth = depth or 0
    if depth > DEPTH or not ns.Usable(frame) then return end
    style = style or {}
    local function Ink(font)
        local heading = style.heading and style.heading(font)
        Modern.Ink(skin, font, not heading and style.tone or nil, style.plain)
    end
    if IsText(frame) then Ink(frame) end
    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            if ns.Usable(region) and IsText(region) then Ink(region) end
        end
    end
    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do Modern.InkTree(skin, child, style, depth + 1) end
    end
end
