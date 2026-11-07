-- A secret chat line (player chat in an instance or battleground) cannot be measured: the
-- height, line count and line height of a secret string are secret values too. Its bubble
-- therefore follows its text through anchors instead of a computed height, and the bubble
-- above sits on that bubble's top edge. Nothing of a secret value is compared or used in math.
local h = ...

local SECRET = "SECRET instance line"
local PAD = 5
local LINE = 14

-- Frames of the window that carry a text region, in creation order.
local function bubbles(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child break end
        end
    end
    return out
end

local function textOf(bubble)
    for _, region in ipairs(bubble._regions) do
        if region._kind == "FontString" then return region end
    end
end

-- Shown bubble that holds the given text.
local function bubbleFor(chat, text)
    for _, bubble in ipairs(bubbles(chat)) do
        local fs = textOf(bubble)
        if bubble._shown and fs and fs._text == text then return bubble end
    end
end

local function shownCount(chat)
    local n = 0
    for _, bubble in ipairs(bubbles(chat)) do
        if bubble._shown then n = n + 1 end
    end
    return n
end

-- Anchors of a frame or region as { point, rel, relPoint, x, y }; a missing relative frame
-- means the parent, like the client.
local function points(frame)
    local out = {}
    for _, p in ipairs(frame._points) do
        local rel = p[2]
        if type(rel) == "string" then rel = _G[rel] end
        if type(rel) ~= "table" then rel = frame._parent end
        local relPoint = type(p[2]) == "table" and p[3] or p[1]
        local x, y = p[4], p[5]
        if type(p[2]) ~= "table" and type(p[2]) ~= "string" then
            x, y = p[2], p[3]
            relPoint = p[1]
        end
        out[#out + 1] = { point = p[1], rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
    end
    return out
end

local function anchoredTo(frame, target)
    local out = {}
    for _, p in ipairs(points(frame)) do
        if p.rel == target then out[#out + 1] = p end
    end
    return out
end

-- True when `frame` depends, through its anchors, on `target`.
local function dependsOn(frame, target, seen)
    seen = seen or {}
    if seen[frame] then return false end
    seen[frame] = true
    for _, p in ipairs(points(frame)) do
        if p.rel == target or (p.rel and dependsOn(p.rel, target, seen)) then return true end
    end
    return false
end

-- Window with a secret line text and secret measurements. Any arithmetic or comparison on a
-- secret measurement is counted.
local function chatWith(t, height)
    local ns = t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local state = { violations = 0, hyper = {} }
    local function trip() state.violations = state.violations + 1; error("secret value used", 2) end
    local measure = setmetatable({}, {
        __lt = trip, __le = trip, __add = trip, __sub = trip, __mul = trip, __div = trip,
        __mod = trip, __pow = trip, __unm = trip, __concat = trip,
    })
    issecretvalue = function(v) return v == SECRET or rawequal(v, measure) end

    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        local makeFont = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
            local fs = makeFont(self, ...)
            local function secret(self2) return self2._text == SECRET end
            function fs:GetFont() return "test", LINE, "" end
            function fs:GetStringWidth()
                if secret(self) then return measure end
                return #tostring(self._text) * 6
            end
            function fs:GetStringHeight() if secret(self) then return measure end return LINE end
            function fs:GetNumLines() if secret(self) then return measure end return 1 end
            function fs:GetLineHeight() if secret(self) then return measure end return LINE end
            function fs:GetSpacing() return 0 end
            return fs
        end
        if parent == ChatFrame1 then
            function frame:SetHyperlinksEnabled(value) self.hyperlinks = value end
        end
        return frame
    end

    local chat = ChatFrame1
    chat:SetSize(300, height or 300)
    function chat:GetFont() return "test", LINE, "" end
    ns.Chat.StripAll()
    return chat, state
end

local function settle(ns)
    for _ = 1, 4 do ns.Chat.Update(1 / 60) end
end

h.test("A secret line's bubble follows its text by anchors, not a four-row height", function(t)
    local ns, A = t.ns, t.assert
    local chat, state = chatWith(t)
    chat:AddMessage(SECRET)
    settle(ns)
    local bubble = bubbleFor(chat, SECRET)
    A.ok(bubble, "no bubble was laid out for the secret line")
    local text = textOf(bubble)
    local tied = anchoredTo(bubble, text)
    A.ok(#tied > 0, "the bubble has no anchor to its text, so its height cannot follow the text")
    local padded = false
    for _, p in ipairs(tied) do
        if math.abs(p.y) == PAD then padded = true end
    end
    A.ok(padded, "the bubble does not keep the padding between its edge and the text")
    A.ne(bubble:GetHeight(), LINE * 4 + PAD * 2, "the secret bubble still has the fixed four-row height")
    A.eq(bubble:GetWidth(), 300 - 8, "a secret line keeps the full chat width")
    A.eq(state.violations, 0, "a secret measurement was compared or used in math")
    A.eq(#t.mock.printed, 0, "something was reported: " .. table.concat(t.mock.printed, " | "))
end)

h.test("A secret bubble's text does not depend on the bubble that follows it", function(t)
    local ns, A = t.ns, t.assert
    local chat = chatWith(t)
    chat:AddMessage(SECRET)
    settle(ns)
    local bubble = bubbleFor(chat, SECRET)
    A.ok(bubble, "no bubble was laid out for the secret line")
    local text = textOf(bubble)
    A.ok(#points(text) > 0, "the text of a secret line has no anchor")
    A.ok(#anchoredTo(bubble, text) > 0, "the bubble does not follow its text")
    A.falsy(dependsOn(text, bubble), "the text depends on its bubble: an anchor cycle")
    for _, region in ipairs(bubble._regions) do
        if region ~= text then
            A.falsy(dependsOn(text, region), "the text depends on a region of its bubble: an anchor cycle")
        end
    end
end)

h.test("A line above a secret line sits on the secret bubble's top edge with the usual gap", function(t)
    local ns, A = t.ns, t.assert
    local chat, state = chatWith(t)
    chat:AddMessage("older plain line")
    chat:AddMessage(SECRET)
    settle(ns)
    local older, secret = bubbleFor(chat, "older plain line"), bubbleFor(chat, SECRET)
    A.ok(older and secret, "both lines were laid out")
    local onTop
    for _, p in ipairs(anchoredTo(older, secret)) do
        if p.point:find("^BOTTOM") and p.relPoint:find("^TOP") and p.y == ns.Chat.GAP then onTop = p end
    end
    A.ok(onTop, "the line above is not anchored from its bottom to the secret bubble's top with the gap")
    for _, p in ipairs(anchoredTo(older, chat)) do
        A.falsy(p.point:find("^BOTTOM"), "the line above still has a computed offset from the window bottom")
    end
    A.eq(state.violations, 0, "a secret measurement was compared or used in math")
end)

h.test("Secret lines stack on each other's top edge", function(t)
    local ns, A = t.ns, t.assert
    local chat = chatWith(t)
    chat:AddMessage(SECRET)
    chat:AddMessage(SECRET)
    chat:AddMessage(SECRET)
    settle(ns)
    local list = {}
    for _, bubble in ipairs(bubbles(chat)) do
        if bubble._shown then list[#list + 1] = bubble end
    end
    A.eq(#list, 3, "three secret lines are shown")
    -- Every bubble but the lowest rests on another secret bubble's top edge.
    local resting = 0
    for _, bubble in ipairs(list) do
        for _, other in ipairs(list) do
            for _, p in ipairs(anchoredTo(bubble, other)) do
                if p.point:find("^BOTTOM") and p.relPoint:find("^TOP") and p.y == ns.Chat.GAP then
                    resting = resting + 1
                    break
                end
            end
        end
    end
    A.eq(resting, 2, "the upper secret bubbles do not rest on the top edge of the one below")
end)

h.test("A secret line above a plain line rests on it with the usual gap", function(t)
    local ns, A = t.ns, t.assert
    local chat = chatWith(t)
    chat:AddMessage(SECRET)
    chat:AddMessage("newer plain line")
    settle(ns)
    local secret, plain = bubbleFor(chat, SECRET), bubbleFor(chat, "newer plain line")
    A.ok(secret and plain, "both lines were laid out")
    A.eq(plain:GetHeight(), LINE + PAD * 2, "the plain line keeps its fixed one-row size")
    local ok
    for _, p in ipairs(anchoredTo(secret, chat)) do
        if p.point:find("^BOTTOM") and p.y == 4 + plain:GetHeight() + ns.Chat.GAP then ok = true end
    end
    for _, p in ipairs(anchoredTo(secret, plain)) do
        if p.point:find("^BOTTOM") and p.relPoint:find("^TOP") and p.y == ns.Chat.GAP then ok = true end
    end
    A.ok(ok, "the secret bubble does not sit one gap above the plain line")
end)

h.test("A secret line moves on its anchors when a newer line arrives", function(t)
    local ns, A = t.ns, t.assert
    local chat = chatWith(t)
    chat:AddMessage(SECRET)
    settle(ns)
    chat:AddMessage("newer plain line")
    settle(ns)
    local secret, plain = bubbleFor(chat, SECRET), bubbleFor(chat, "newer plain line")
    A.ok(secret and plain, "both lines were laid out")
    local lifted
    for _, p in ipairs(anchoredTo(secret, chat)) do
        if p.point:find("^BOTTOM") and p.y == 4 + plain:GetHeight() + ns.Chat.GAP then lifted = true end
    end
    for _, p in ipairs(anchoredTo(secret, plain)) do
        if p.point:find("^BOTTOM") and p.relPoint:find("^TOP") and p.y == ns.Chat.GAP then lifted = true end
    end
    A.ok(lifted, "the secret bubble kept its old bottom anchor under the new line")
end)

h.test("Plain lines keep their fixed size and offsets from the window bottom", function(t)
    local ns, A = t.ns, t.assert
    local chat, state = chatWith(t)
    chat:AddMessage("older plain line")
    chat:AddMessage("newer plain line")
    settle(ns)
    local older, newer = bubbleFor(chat, "older plain line"), bubbleFor(chat, "newer plain line")
    A.ok(older and newer, "both lines were laid out")
    for _, bubble in ipairs({ older, newer }) do
        A.eq(bubble:GetHeight(), LINE + PAD * 2, "a plain line must stay one fixed row")
        A.eq(#anchoredTo(bubble, textOf(bubble)), 0, "a plain bubble must not be anchored to its text")
    end
    local function bottomY(bubble)
        for _, p in ipairs(anchoredTo(bubble, chat)) do
            if p.point == "BOTTOMLEFT" then return p.y end
        end
    end
    A.eq(bottomY(newer), 4, "newest plain line sits at the window bottom")
    A.eq(bottomY(older), 4 + LINE + PAD * 2 + ns.Chat.GAP, "older plain line is stacked by offset")
    A.eq(state.violations, 0)
end)

h.test("A secret line counts one row plus padding in the height budget", function(t)
    local ns, A = t.ns, t.assert
    -- 4 + 27 * 3 = 85: three one-row estimates fit under 100, a four-row estimate (66) fits once.
    local chat = chatWith(t, 100)
    for _ = 1, 6 do chat:AddMessage(SECRET) end
    settle(ns)
    A.eq(shownCount(chat), 3, "the window must stop after three secret lines of one row plus padding")
end)

h.test("A reused bubble for a plain line loses the secret anchors and keeps normal behaviour", function(t)
    local ns, A = t.ns, t.assert
    local chat = chatWith(t)
    chat:AddMessage(SECRET)
    settle(ns)
    local secret = bubbleFor(chat, SECRET)
    A.ok(secret, "no bubble was laid out for the secret line")
    A.falsy(secret.hyperlinks, "a secret line must not get link hit testing")
    t.ns.Chat.CopyLine(secret)
    A.eq(#t.mock.printed, 0, "copying a secret line printed something")

    chat:Clear()
    settle(ns)
    chat:AddMessage("reused plain line")
    settle(ns)
    local reused = bubbleFor(chat, "reused plain line")
    A.ok(reused, "no bubble shows the plain line")
    A.eq(#bubbles(chat), 1, "the pooled bubble was not reused")
    A.eq(reused:GetHeight(), LINE + PAD * 2, "the reused bubble has no normal fixed height")
    local text = textOf(reused)
    A.eq(#anchoredTo(reused, text), 0, "the reused bubble is still anchored to its text")
    for _, p in ipairs(points(reused)) do
        A.eq(p.rel, chat, "the reused bubble keeps an anchor to something other than the window")
    end
    local pts = points(text)
    A.ok(#pts > 0, "the reused text lost its anchor")
    for _, p in ipairs(pts) do
        A.eq(p.rel, reused, "the reused text is anchored away from its bubble")
    end
    A.ok(reused.hyperlinks, "the reused bubble did not get link hit testing back")
end)

h.test("A secret bubble leaves the native chat untouched when Modern chat is off", function(t)
    local ns, A = t.ns, t.assert
    local chat = ChatFrame1
    local native = chat:CreateFontString(nil, "ARTWORK")
    chatWith(t)
    chat:AddMessage(SECRET)
    settle(ns)
    A.ok(bubbleFor(chat, SECRET), "no bubble was laid out for the secret line")
    local chatPoints, nativePoints = #chat._points, #native._points
    QuietUICharDB.chat = false
    native:SetAlpha(1)
    chat:AddMessage("modern chat off")
    settle(ns)
    A.alpha(native, 1, "native text was hidden with Modern chat off")
    A.eq(#chat._points, chatPoints, "the native chat frame was re-anchored")
    A.eq(#native._points, nativePoints, "the native text was re-anchored")
end)
