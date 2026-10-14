local _, ns = ...

-- Scroll offset tracking and the wheel.

local Chat = ns.Chat

local function ScrollOffset(frame)
    if type(frame.GetScrollOffset) == "function" then
        local ok, offset = pcall(frame.GetScrollOffset, frame)
        if ok and type(offset) == "number" and not ns.IsSecret(offset) then
            return offset
        end
    end
    if type(frame.scrollOffset) == "number" then
        return frame.scrollOffset
    end
    return frame._quietScroll or 0
end
Chat.ScrollOffset = ScrollOffset

local function AtBottom(frame)
    if type(frame.AtBottom) == "function" then
        local ok, at = pcall(frame.AtBottom, frame)
        if ok then return not not at end
    end
    return ScrollOffset(frame) < 1
end
Chat.AtBottom = AtBottom

local function ClampScroll(frame, value)
    if value < 0 then return 0 end
    local max = frame._quietLines and #frame._quietLines or 0
    if value > max then return max end
    return value
end
Chat.ClampScroll = ClampScroll

local function TrackScroll(frame)
    if frame._quietScrollHook then return end
    frame._quietScrollHook = true
    local native = type(frame.GetScrollOffset) == "function"
    if not native then
        frame._quietScroll = 0
    end
    local function hook(name, fn)
        if type(frame[name]) ~= "function" then return end
        pcall(hooksecurefunc, frame, name, function(self)
            self._quietDirty = true
            if fn then fn(self) end
        end)
    end
    if native then
        hook("ScrollUp")
        hook("ScrollDown")
        hook("PageUp")
        hook("PageDown")
        hook("ScrollToBottom")
    else
        hook("ScrollUp", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) + 1)
        end)
        hook("ScrollDown", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) - 1)
        end)
        hook("PageUp", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) + 10)
        end)
        hook("PageDown", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) - 10)
        end)
        hook("ScrollToBottom", function(self)
            self._quietScroll = 0
        end)
    end
    if frame.HookScript then
        frame:HookScript("OnSizeChanged", function(self)
            self._quietDirty = true
        end)
    end
end
Chat.TrackScroll = TrackScroll

local function MaxLines(frame)
    if type(frame.GetMaxLines) == "function" then
        local ok, n = pcall(frame.GetMaxLines, frame)
        if ok and type(n) == "number" and n > 1 then return math.floor(n) end
    end
    return 128
end
Chat.MaxLines = MaxLines
local function Wheel(frame, delta)
    if not frame or type(delta) ~= "number" then return end
    if delta > 0 and type(frame.ScrollUp) == "function" then
        pcall(frame.ScrollUp, frame)
    elseif delta < 0 and type(frame.ScrollDown) == "function" then
        pcall(frame.ScrollDown, frame)
    end
end
Chat.Wheel = Wheel
