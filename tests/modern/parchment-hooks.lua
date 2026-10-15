-- Parchment (NPC quest, gossip and item text windows) must not replace Blizzard scripts: it hooks them once
-- and the hooks do nothing once the Windows area is off.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

local function fixture()
    local quest, gossip, itemText = W.window("QuestFrame"), W.window("GossipFrame"), W.window("ItemTextFrame")
    QuestFrame, GossipFrame, ItemTextFrame = quest, gossip, itemText
    local buttons = {
        W.button(quest, "QuestFrameAcceptButton"), W.button(quest, "QuestFrameDeclineButton"),
        W.button(itemText, "ItemTextNextPageButton"), W.button(itemText, "ItemTextPrevPageButton"),
    }
    quest.CloseButton = W.button(quest, "QuestFrameCloseButton")
    local all = { quest, gossip, itemText, quest.CloseButton }
    for _, b in ipairs(buttons) do all[#all + 1] = b end
    return quest, gossip, itemText, all
end

-- Counts SetScript and HookScript calls per frame and script name.
local function watch(frames)
    local w = { set = 0, setNames = {}, hooks = {} }
    for _, f in ipairs(frames) do
        local spy = L.watchScripts(f)
        w[f] = spy
        local hook = f.HookScript
        f.HookScript = function(self, name, fn)
            w.hooks[self] = w.hooks[self] or {}
            w.hooks[self][name] = (w.hooks[self][name] or 0) + 1
            return hook(self, name, fn)
        end
    end
    function w.setCalls()
        local names = {}
        for _, f in ipairs(frames) do
            for _, n in ipairs(w[f].names) do names[#names + 1] = (f:GetName() or "frame") .. "." .. n end
        end
        return names
    end
    return w
end

h.test("parchment apply and restore never call SetScript on Blizzard frames", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local _, _, _, all = fixture()
    local w = watch(all)
    W.enable(ns)
    ns.Modern.Restore()
    W.enable(ns)
    ns.Modern.Restore()
    A.eq(#w.setCalls(), 0, "SetScript on: " .. table.concat(w.setCalls(), ",", 1, math.min(#w.setCalls(), 4)) .. " (" .. #w.setCalls() .. " calls)")
end)

h.test("parchment hooks each frame script once, however often the area is applied again", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local quest, _, _, all = fixture()
    local w = watch(all)
    W.enable(ns)
    ns.Modern.Apply()
    ns.Modern.Restore()
    W.enable(ns)
    t.mock:fire("QUEST_DETAIL")
    local hooked = 0
    for _, f in ipairs(all) do
        for name, n in pairs(w.hooks[f] or {}) do
            hooked = hooked + 1
            A.eq(n, 1, (f:GetName() or "frame") .. " " .. name .. " hooked once")
        end
    end
    A.ok(w.hooks[quest] and w.hooks[quest].OnShow, "the window repaints on show through a hook")
    A.ok(hooked > 0, "something is hooked")
end)

h.test("after restore parchment hooks are inert: no repaint on show, no hover colours", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local quest, gossip, itemText, all = fixture()
    W.enable(ns)
    ns.Modern.Restore()
    quest.chrome:SetAlpha(1)
    local snap = L.snapshot({ quest, quest.chrome, gossip, itemText, unpack(all) })
    for _, f in ipairs(all) do f:Hide(); f:Show() end
    for _, f in ipairs(all) do
        for _, name in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
            local fn = f._scripts[name]
            if fn then fn(f) end
        end
    end
    A.alpha(quest.chrome, 1, "Blizzard chrome is not held again by a late show")
    A.deep(L.diff(snap), {}, "nothing changes on show, hover or enable after restore")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("parchment works again when the area is re-enabled after a restore", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local quest = fixture()
    W.enable(ns)
    ns.Modern.Restore()
    W.enable(ns)
    quest.chrome:SetAlpha(1)
    quest:Hide(); quest:Show()
    A.ok(W.hasTexture(mock, quest, "Media\\parchment.tga"), "parchment layer exists")
    A.alpha(quest.chrome, 0, "a show repaints the chrome hold while the area is on")
    local accept = QuestFrameAcceptButton
    A.eq(accept:GetPoint(), "BOTTOMLEFT", "buttons are in the band again")
end)

-- One alpha hold per texture: Blizzard art on parchment windows is held only through the skin journal
-- (ns.HoldAlpha), so each texture carries at most the one shared SetAlpha hook.
local function alphaHooks(mock, tex)
    local n = 0
    for _, hook in ipairs(mock.hooks) do
        if hook.obj == tex and hook.method == "SetAlpha" then n = n + 1 end
    end
    return n
end

local function textures(mock, all)
    local list = {}
    for _, object in ipairs(mock.frames) do
        if object._kind == "Texture" then list[#list + 1] = object end
    end
    return list
end

h.test("parchment windows hold each Blizzard texture once, however often the area is applied", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local quest, _, _, all = fixture()
    W.enable(ns)
    ns.Modern.Apply()
    ns.Modern.Restore()
    W.enable(ns)
    quest:Hide(); quest:Show()
    t.mock:fire("QUEST_DETAIL")
    local held = 0
    for _, tex in ipairs(textures(mock, all)) do
        local n = alphaHooks(mock, tex)
        A.ok(n <= 1, (tex._name or "texture") .. " has " .. n .. " SetAlpha hooks, expected at most 1")
        if tex._quietAlphaHook then held = held + 1 end
    end
    A.ok(held > 0, "the shared alpha hold is on the Blizzard art")
    A.ok(alphaHooks(mock, quest.chrome) == 1, "quest chrome has exactly the shared hold")
end)

h.test("parchment art stays at alpha 0 after Blizzard repaints, and restore returns the alpha from before the hold", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local quest, _, _, all = fixture()
    local normal = QuestFrameAcceptButton.normal
    W.enable(ns)
    A.alpha(quest.chrome, 0, "chrome held")
    A.alpha(normal, 0, "button art held")
    quest.chrome:SetAlpha(0.9)
    normal:SetAlpha(0.5)
    A.alpha(quest.chrome, 0, "repaint is put back")
    A.alpha(normal, 0, "button repaint is put back")
    quest:Hide(); quest:Show()
    A.alpha(quest.chrome, 0, "still held after show")
    ns.Modern.Restore()
    A.alpha(quest.chrome, 0.61, "chrome returns to the alpha it had when first held")
    A.alpha(normal, 0.7, "button art returns to its baseline")
end)

h.test("parchment holds never error or compare a secret alpha", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local quest = fixture()
    W.enable(ns)
    local secret = mock:secret(0.4)
    A.noThrow(function() quest.chrome:SetAlpha(secret) end)
    A.noThrow(function() ns.Modern.Restore() end)
    A.eq(#mock.printed, 0, "nothing reported")
end)
