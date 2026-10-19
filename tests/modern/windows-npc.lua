-- NPC quest, gossip and item text windows take the dark window template: chrome held, flat action buttons, the
-- close button in place, and Blizzard's dark ink turned into light text, also on pooled gossip options.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

local INK = { 0.18, 0.12, 0.06, 1 }

local function ink(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    font:SetFont("Fonts\\MORPHEUS.TTF", 13, "")
    font:SetTextColor(unpack(INK))
    return font
end

local function light(font)
    local r, g, b = font:GetTextColor()
    return 0.3 * r + 0.59 * g + 0.11 * b > 0.5
end

local function fixture()
    local quest, gossip, itemText = W.window("QuestFrame"), W.window("GossipFrame"), W.window("ItemTextFrame")
    QuestFrame, GossipFrame, ItemTextFrame = quest, gossip, itemText
    local accept = W.button(quest, "QuestFrameAcceptButton")
    accept.Left = W.texture(accept, "QuestFrameAcceptButtonLeft")
    local close = W.button(quest, "QuestFrameCloseButton")
    quest.CloseButton = close
    local detail = CreateFrame("Frame", "QuestFrameDetailPanel", quest)
    detail.SealMaterialBG = W.texture(detail, "SealMaterialBG", 0.8)
    local scroll = CreateFrame("ScrollFrame", "QuestDetailScrollFrame", detail)
    local child = CreateFrame("Frame", nil, scroll)
    local description = ink(child, "Bring me ten wolf pelts.")
    local panel = CreateFrame("Frame", nil, gossip)
    gossip.GreetingPanel = panel
    panel.GoodbyeButton = W.button(panel, "GossipGoodbye")
    panel.ScrollBox = CreateFrame("Frame", nil, panel)
    local target = CreateFrame("Frame", nil, panel.ScrollBox)
    local option = CreateFrame("Button", nil, target)
    local optionText = ink(option, "Auction House")
    local greeting = CreateFrame("Frame", nil, target)
    greeting.GreetingText = ink(greeting, "What do you need directions to?")
    return { greeting = greeting.GreetingText, quest = quest, gossip = gossip, itemText = itemText, accept = accept, close = close, detail = detail,
        description = description, panel = panel, target = target, optionText = optionText }
end

h.test("Windows gives NPC windows the dark template, light text and flat buttons, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local f = fixture()
    local title = f.quest.TitleContainer.TitleText
    title:SetTextColor(1, 0.82, 0, 1)
    local closePoint = W.point(f.close)
    local before = L.snapshot({ f.quest, f.quest.chrome, f.accept, f.accept.normal, f.accept.Left, f.close,
        f.detail.SealMaterialBG, f.description, f.optionText, f.greeting, title, f.gossip, f.itemText })
    W.enable(ns)
    for _, frame in ipairs({ f.quest, f.gossip, f.itemText }) do
        A.ok(W.isDark(frame), (frame:GetName() or "NPC window") .. " is a dark window")
        A.alpha(frame.chrome, 0, "old chrome is held")
        A.ok(not W.hasTexture(mock, frame, "parchment"), "no parchment layer")
    end
    A.alpha(f.detail.SealMaterialBG, 0, "panel material is held")
    A.ok(W.isDark(f.accept), "accept is a flat field")
    A.alpha(f.accept.normal, 0, "button art is held")
    A.alpha(f.accept.Left, 0, "three-piece button art is held")
    A.deep(W.point(f.close), closePoint, "the close button keeps its place")
    A.ok(light(f.description), "quest text ink becomes light")
    A.ok(light(f.optionText), "gossip option ink becomes light")
    local text = ns.Modern.Theme().text
    A.deep({ f.optionText:GetTextColor() }, { text[1], text[2], text[3], 1 }, "body text is the neutral theme text")
    local r, g, b = f.greeting:GetTextColor()
    A.ok(light(f.greeting) and r > b + 0.3 and r ~= g, "the greeting keeps gold ink")
    A.deep({ title:GetTextColor() }, { 1, 0.82, 0, 1 }, "the gold title stays")
    local face, size = f.optionText:GetFont()
    A.eq(face, "Fonts\\ARIALN.TTF", "inked text takes Arial Narrow, which has Czech letters")
    A.eq(size, 14, "a point above Blizzard's size")
    A.eq((title:GetFont()), "Fonts\\FRIZQT__.TTF", "the title keeps its font")
    A.eq(f.description:GetText(), "Bring me ten wolf pelts.", "text stays Blizzard's")
    f.description:SetTextColor(unpack(INK))
    A.ok(light(f.description), "Blizzard repainting the ink is answered with light text")
    A.eq(select(2, f.description:GetFont()), 14, "the size does not grow on a repaint")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "NPC windows restore exactly")
end)

h.test("pooled gossip options are lightened on show and on GOSSIP_SHOW, and hooks are inert after restore", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local f = fixture()
    W.enable(ns)
    local late = ink(CreateFrame("Button", nil, f.target), "Inn")
    f.gossip:Hide(); f.gossip:Show()
    A.ok(light(late), "an option built after apply is lightened on show")
    local later = ink(CreateFrame("Button", nil, f.target), "Bank")
    mock:fire("GOSSIP_SHOW")
    A.ok(light(later), "an option built after apply is lightened on GOSSIP_SHOW")
    ns.Modern.Restore()
    A.deep({ late:GetTextColor() }, INK, "the ink returns on restore")
    local after = ink(CreateFrame("Button", nil, f.target), "Stable")
    f.gossip:Hide(); f.gossip:Show()
    mock:fire("GOSSIP_SHOW")
    late:SetTextColor(unpack(INK))
    A.deep({ after:GetTextColor() }, INK, "show and events do nothing after restore")
    A.deep({ late:GetTextColor() }, INK, "a Blizzard repaint is not answered after restore")
end)

h.test("NPC windows never call SetScript and hook each script once however often applied", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local f = fixture()
    local frames = { f.quest, f.gossip, f.itemText, f.accept, f.close }
    local spies, hooks = {}, {}
    for _, frame in ipairs(frames) do
        spies[frame] = L.watchScripts(frame)
        local hook = frame.HookScript
        frame.HookScript = function(self, name, fn)
            hooks[self] = hooks[self] or {}
            hooks[self][name] = (hooks[self][name] or 0) + 1
            return hook(self, name, fn)
        end
    end
    W.enable(ns)
    ns.Modern.Apply()
    ns.Modern.Restore()
    W.enable(ns)
    mock:fire("QUEST_DETAIL")
    for _, frame in ipairs(frames) do
        A.eq(spies[frame].n, 0, (frame:GetName() or "frame") .. " SetScript calls")
        for name, n in pairs(hooks[frame] or {}) do A.eq(n, 1, (frame:GetName() or "frame") .. " " .. name) end
    end
    A.ok(hooks[f.quest] and hooks[f.quest].OnShow == 1, "the window rescans on show through a hook")
end)

h.test("an item text page lightens its dark elements and restores them", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local f = fixture()
    local page = CreateFrame("SimpleHTML", "ItemTextPageText", f.itemText)
    local colors = { P = INK, H1 = { 1, 1, 1, 1 } }
    page.SetTextColor = function(_, element, r, g, b, a) colors[element] = { r, g, b, a } end
    page.GetTextColor = function(_, element)
        local c = colors[element] or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4]
    end
    W.enable(ns)
    local r, g, b = page:GetTextColor("P")
    A.ok(0.3 * r + 0.59 * g + 0.11 * b > 0.5, "paragraph ink becomes light")
    A.deep(colors.H1, { 1, 1, 1, 1 }, "a light element stays")
    ns.Modern.Restore()
    A.deep(colors.P, INK, "paragraph ink returns on restore")
end)
