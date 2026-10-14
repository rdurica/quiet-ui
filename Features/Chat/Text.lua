local _, ns = ...

-- Native chat text kept at alpha 0, and the measuring of line text.

local Chat = ns.Chat

local measureWide
local function HoldFont(frame, fs)
    if not fs or not fs.SetAlpha or not fs.GetObjectType then return end
    if fs:GetObjectType() ~= "FontString" then return end
    local saved = frame._quietFontAlpha
    if not saved then
        saved = {}
        frame._quietFontAlpha = saved
    end
    if saved[fs] == nil then
        local alpha = fs.GetAlpha and fs:GetAlpha()
        if ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha < 0.05 then alpha = 1 end
        saved[fs] = alpha
    end
    -- Chat fade writes alpha back after OnUpdate. Hold 0 the same way textures do.
    if not fs._quietHoldHook then
        fs._quietHoldHook = true
        pcall(hooksecurefunc, fs, "SetAlpha", function(self, alpha)
            if self._quietApplying or not ns.DB().enabled then return end
            if ns.Settings.ModernChat and not ns.Settings.ModernChat() then return end
            if type(alpha) == "number" and not ns.IsSecret(alpha) and alpha < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    local alpha = fs:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha >= 0.01 then
        fs._quietApplying = true
        fs:SetAlpha(0)
        fs._quietApplying = false
    end
end

local function SkipChild(child)
    if not child or child._quietBubble or child._quietPlate or child._quietEdit then
        return true
    end
    local name = child.GetName and child:GetName()
    if type(name) == "string" and (name:find("EditBox", 1, true) or name:find("Tab", 1, true)) then
        return true
    end
    return false
end

local function Forbidden(obj)
    if not obj or not obj.IsForbidden then return false end
    local ok, forbidden = pcall(obj.IsForbidden, obj)
    return ok and forbidden or false
end

-- A previous build shrank this font to hide the native lines and the client
-- stored that size. Put a normal size back once, without hooking SetFont.
local function RepairTinyFont(frame)
    if frame._quietFontRepaired or not frame.GetFont or not frame.SetFont then return end
    frame._quietFontRepaired = true
    local ok, font, size, flags = pcall(frame.GetFont, frame)
    if not ok or type(size) ~= "number" or size > 2 then return end
    pcall(frame.SetFont, frame, font or "Fonts\\FRIZQT__.TTF", 14, flags or "")
end
Chat.RepairTinyFont = RepairTinyFont

local function ShapeCount(obj)
    local regions = obj.GetNumRegions and obj:GetNumRegions()
    local children = obj.GetNumChildren and obj:GetNumChildren()
    if type(regions) ~= "number" or type(children) ~= "number" then return nil end
    if ns.IsSecret(regions) or ns.IsSecret(children) then return nil end
    return regions + children
end

-- Regions and children of the frame and its direct children. Nil means unknown.
local function TextSignature(frame, children)
    local sum = ShapeCount(frame)
    if not sum then return nil end
    for i = 1, #children do
        local child = children[i]
        if ns.Usable(child) then
            local count = ShapeCount(child)
            if not count then return nil end
            sum = sum + count
        end
    end
    return sum
end

local function HideNativeText(frame, force)
    if not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    if Forbidden(frame) then return end
    -- The root child list is read once and shared by the signature and the walk.
    local okKids, rootKids = pcall(function()
        return frame.GetChildren and { frame:GetChildren() } or {}
    end)
    if not okKids then rootKids = {} end
    local okSig, sig = pcall(TextSignature, frame, rootKids)
    if not okSig then sig = nil end
    if not force and sig ~= nil and sig == frame._quietTextSig then return end
    frame._quietTextSig = sig
    local function walk(obj, depth, kids)
        if not obj or depth > 5 or Forbidden(obj) then return end
        if obj.GetNumRegions then
            local regions = { obj:GetRegions() }
            for i = 1, #regions do
                local region = regions[i]
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    HoldFont(frame, region)
                end
            end
        end
        if not obj.GetNumChildren then return end
        local children = kids or { obj:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if ns.Usable(child) and not SkipChild(child) then
                walk(child, depth + 1)
            end
        end
    end
    pcall(walk, frame, 0, rootKids)
end
Chat.HideNativeText = HideNativeText

local function RestoreFonts(frame)
    local saved = frame._quietFontAlpha
    if saved then
        for fs, alpha in pairs(saved) do
            if fs then
                if fs.SetAlpha then
                    fs._quietApplying = true
                    fs:SetAlpha(alpha or 1)
                    fs._quietApplying = false
                end
            end
        end
    end
    frame._quietFontAlpha = nil
end
Chat.RestoreFonts = RestoreFonts
local function StripCodes(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function PlainText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|H.-|h(.-)|h", function(display)
        return StripCodes(display)
    end)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|n", "\n")
    return text
end
Chat.PlainText = PlainText

local function TextureWidth(spec)
    local w = tonumber(spec:match(":(%d+)"))
    if w and w > 0 then return w end
    return 16
end

local function AddPlain(segs, chunk)
    local pos = 1
    while pos <= #chunk do
        local space, finish = chunk:find("%s+", pos)
        if space == pos then
            segs[#segs + 1] = { text = chunk:sub(space, finish) }
            pos = finish + 1
        else
            local wordEnd = (space or (#chunk + 1)) - 1
            local word = chunk:sub(pos, wordEnd)
            if word ~= "" then
                segs[#segs + 1] = { text = word }
            end
            pos = wordEnd + 1
        end
    end
end

local function Segments(text)
    local segs = {}
    if type(text) ~= "string" or text == "" then return segs end
    local i = 1
    local n = #text
    local guard = 0
    while i <= n and guard <= n do
        guard = guard + 1
        local rest = text:sub(i)
        local start = i
        local color = rest:match("^|c%x%x%x%x%x%x%x%x")
        if color then
            i = i + 10
        elseif rest:sub(1, 2) == "|r" or rest:sub(1, 2) == "|n" then
            if rest:sub(1, 2) == "|n" then
                segs[#segs + 1] = { br = true }
            end
            i = i + 2
        elseif rest:sub(1, 1) == "\n" then
            segs[#segs + 1] = { br = true }
            i = i + 1
        else
            local link, display = rest:match("^|H(.-)|h(.-)|h")
            if link then
                i = i + #("|H" .. link .. "|h" .. display .. "|h")
                segs[#segs + 1] = { link = link, text = StripCodes(display) }
            else
                local tex = rest:match("^|T(.-)|t")
                if tex then
                    i = i + #tex + 4
                    segs[#segs + 1] = { text = "", width = TextureWidth(tex) }
                else
                    local pipe = rest:find("|", 2, true)
                    local nl = rest:find("\n", 2, true)
                    local stop
                    if pipe and nl then
                        stop = math.min(pipe, nl)
                    else
                        stop = pipe or nl
                    end
                    local chunk = stop and rest:sub(1, stop - 1) or rest
                    if chunk ~= "" then
                        AddPlain(segs, chunk)
                    end
                    i = i + #chunk
                end
            end
        end
        if i <= start then i = start + 1 end
    end
    return segs
end
Chat.Segments = Segments

-- A hidden font string reports 0. Alpha 0 still lays the text out.
-- The host is wider than a chat line so the unwrapped width is not clipped.
local function EnsureMeasure()
    if measureWide then return measureWide end
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetAlpha(0)
    host:EnableMouse(false)
    host:SetSize(8192, 64)
    host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 4000)
    host:Show()
    measureWide = host:CreateFontString(nil, "OVERLAY")
    measureWide:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    measureWide:SetJustifyH("LEFT")
    measureWide:SetJustifyV("TOP")
    if measureWide.SetWordWrap then measureWide:SetWordWrap(false) end
    if measureWide.SetNonSpaceWrap then measureWide:SetNonSpaceWrap(false) end
    measureWide:SetWidth(8000)
    return measureWide
end

local function PrepareProbe(fs, probe)
    local font, size, flags = fs:GetFont()
    pcall(probe.SetFont, probe, font or "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    if fs.GetSpacing and probe.SetSpacing then
        local spacing = fs:GetSpacing()
        if type(spacing) == "number" then
            probe:SetSpacing(spacing)
        end
    end
    return probe
end

-- Wrap stays off, so a long line is not reported as the width of its first row.
local function UnboundedWidth(fs, text)
    local probe = PrepareProbe(fs, EnsureMeasure())
    probe:SetWidth(8000)
    probe:SetText(text or "")
    local wide = 0
    local w = probe:GetStringWidth()
    if type(w) == "number" and not ns.IsSecret(w) and w > 0 then wide = w end
    if probe.GetUnboundedStringWidth then
        local ok, uw = pcall(probe.GetUnboundedStringWidth, probe)
        if ok and type(uw) == "number" and not ns.IsSecret(uw) and uw > wide then
            wide = uw
        end
    end
    return wide
end
Chat.UnboundedWidth = UnboundedWidth
