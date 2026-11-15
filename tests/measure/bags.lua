unpack = table.unpack or unpack
local baseline = assert(arg[1], 'Pass the baseline Bags.lua path')
local function benchmark(path, bursts)
    local frames, paints, queries, hooks = {}, 0, 0, {}
    local function noop() end
    CreateFrame = function()
        local f = { Hide = noop, Show = noop }
        function f:SetScript(_, fn) self.update = fn end
        frames[#frames + 1] = f
        return f
    end
    hooksecurefunc = function(object, method, callback)
        hooks[object] = hooks[object] or {}
        hooks[object][method] = callback
    end
    local function texture()
        return setmetatable({ GetAtlas = noop, IsShown = function() return false end },
            { __index = function() return noop end })
    end
    local ns = { Modern = {}, Settings = { ModernTheme = function() return 'dark' end } }
    ns.Copy = function(value)
        if type(value) ~= 'table' then return value end
        local result = {}
        for k,v in pairs(value) do result[k] = ns.Copy(v) end
        return result
    end
    ns.Usable = function(value) return type(value) == 'table' end
    ns.IsSecret = function() return false end
    ns.ReleaseAlpha = noop
    ns.Modern.NoMask = noop
    ns.Profiler = { Run = function(_, fn, ...) fn(...) end }
    assert(loadfile('Features/Modern/Theme.lua'))('QuietUI', ns)
    C_Container = { GetContainerItemInfo = function()
        queries = queries + 1
        return nil
    end }
    local skin = { Remember = noop, Icon = noop, Hold = noop, Panel = noop,
        Border = function() paints = paints + 1 end }
    local regions = {}
    function skin:Own(button, key, create)
        regions[button] = regions[button] or create()
        return regions[button]
    end
    assert(loadfile(path))('QuietUI', ns)
    local buttons = {}
    for i = 1, 100 do
        local button = { icon = texture(), IconBorder = texture(), IconQuestTexture = texture(),
            GetID = function() return i end, GetBagID = function() return 0 end,
            CreateTexture = texture }
        buttons[i] = button
        ns.Modern.Bags.Item(skin, button)
    end
    local function flush()
        for _, f in ipairs(frames) do if f.update then f:update() end end
    end
    flush()
    paints, queries = 0, 0
    collectgarbage('collect')
    local start = os.clock()
    for frame = 1, 200 do
        for _, button in ipairs(buttons) do
            for event = 1, bursts do
                hooks[button.icon].SetTexture()
                hooks[button.IconBorder].Show()
                ns.Modern.Bags.Repaint(button)
            end
        end
        flush()
    end
    return { ms = (os.clock() - start) * 1000, paints = paints, queries = queries }
end
for _, bursts in ipairs({1, 3, 10}) do
    local old = benchmark(baseline, bursts)
    local new = benchmark('Features/Modern/Areas/Bags.lua', bursts)
    assert(new.paints == 20000)
    assert(old.paints == 20000 * bursts * 3)
    assert(new.queries == new.paints)
    assert(old.queries == old.paints * 2)
    print(string.format('%d bursts/slot/frame: baseline %.1f ms, optimized %.1f ms; paints %d -> %d; item reads %d -> %d',
        bursts, old.ms, new.ms, old.paints, new.paints, old.queries, new.queries))
end
