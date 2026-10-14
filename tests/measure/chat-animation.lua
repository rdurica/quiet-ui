-- Measurements for chat animation:  lua tests/measure/chat-animation.lua --measure
-- Works from any cwd. Counts how often animation-only frames rebuild the message stack (each
-- rebuild re-reads every row's font and frame level); tests/chat/animation.lua asserts 0.
if arg[1] ~= "--measure" then
    print("usage: lua tests/measure/chat-animation.lua --measure")
    os.exit(1)
end
local print = print -- the mock replaces the global print
local script = arg[0] or "tests/measure/chat-animation.lua"
local dir = script:match("^(.*)/[^/]*$") or "."
local libDir = dir .. "/../lib"
local mock = assert(loadfile(libDir .. "/mock.lua"))().new()
mock:install()
local addon = assert(loadfile(libDir .. "/addon.lua"))()
local p = io.popen("cd '" .. dir .. "/../..' && pwd")
addon.root = p:read("*l")
p:close()
local ns = addon.load()

QuietUIDB = { enabled = true }
local fade = 0
QuietUICharDB = { chatFade = fade }

local chat = ChatFrame1
local create = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    local makeFont = frame.CreateFontString
    frame.CreateFontString = function(self, ...)
        local fs = makeFont(self, ...)
        function fs:GetStringWidth() return #(self._text or "") * 7 end
        function fs:GetUnboundedStringWidth() return 0 end
        function fs:GetStringHeight()
            local size = self._font and self._font[2] or 14
            return math.ceil(self:GetStringWidth() / self._w) * size
        end
        return fs
    end
    return frame
end
chat:SetSize(340, 360)
chat.scrollOffset = 0
function chat:GetScrollOffset() return self.scrollOffset end
function chat:GetFont() return "test", 14, "" end

local function tick(elapsed)
    elapsed = elapsed or 1 / 60
    mock.now = mock.now + elapsed
    ns.Chat.Update(elapsed)
end

local function bubbles()
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child; break end
        end
    end
    return out
end

local function watchRebuilds()
    local n = 0
    for _, b in ipairs(bubbles()) do
        local level = b.SetFrameLevel
        b.SetFrameLevel = function(...) n = n + 1; return level(...) end
        for _, region in ipairs(b._regions) do
            if region._kind == "FontString" then
                local font = region.GetFont
                region.GetFont = function(...) n = n + 1; return font(...) end
            end
        end
    end
    return function() return n end
end

for i = 1, 8 do chat:AddMessage("Line " .. i) end
ns.Chat.StripAll()
tick()
chat:AddMessage("Incoming message")
tick()
local rebuilds = watchRebuilds()
for _ = 1, 9 do tick() end
print(("Slide/ease, 9 animation frames: history lookups=%d"):format(rebuilds()))

-- One line about to expire while the others stay settled.
QuietUICharDB.chatFade = 10
local born = mock.now
for i = 1, 9 do
    mock.now = i == 4 and born or born + 1
    chat:AddMessage("Line " .. i)
end
for _ = 1, 120 do tick() end
mock.now = born + 9.5
tick()
rebuilds = watchRebuilds()
for _ = 1, 8 do tick() end
print(("One fading line, 8 animation frames: history lookups=%d"):format(rebuilds()))
