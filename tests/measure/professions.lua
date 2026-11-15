-- Run from the repository root: lua5.4 tests/measure/professions.lua
local noop = function() end
local driver, update, walks, chrome = nil, nil, 0, 0
function CreateFrame()
    driver = { Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        SetScript = function(self, _, fn) self.run = fn end }
    return driver
end
function hooksecurefunc(_, _, fn) update = fn end
local function frame(t)
    t = t or {}
    t.HookScript = function(self, _, fn) self.show = fn end
    return t
end
local ns = { Usable = function(x) return type(x) == 'table' end,
    Profiler = { Run = function(_, fn, ...) return fn(...) end }, Modern = {} }
local modern = ns.Modern
modern.Character = { Children = function() walks = walks + 1; return {} end,
    HoldArt = function() chrome = chrome + 1 end, IconTab = noop, ScrollBar = noop }
modern.Shapes = { Field = noop }
modern.Window, modern.Header = noop, noop
assert(loadfile('Features/Modern/Areas/Professions.lua'))('QuietUI', ns)
local box = { Update = noop, ScrollTarget = {} }
local root = frame({ BookPage = frame(), CraftingPage = frame({ RecipeList = { ScrollBox = box } }) })
local undo
local skin = { Remember = function(_, _, _, fn) undo = fn end }
modern.Professions.Apply(skin, root)
local function flush() if driver.shown then driver:run() end end
walks, chrome = 0, 0
for i = 1, 100 do update() end
assert(walks == 0)
flush()
assert(walks == 1 and chrome == 0, 'list bursts must only walk recipes once')
walks = 0
root.show()
root.BookPage.show()
root.CraftingPage.show()
for i = 1, 100 do update() end
flush()
assert(walks == 1 and chrome > 0, 'page shows must win over recipe-only updates')
walks = 0
update()
undo()
flush()
assert(walks == 0, 'restore must cancel pending work')
modern.Professions.Apply(skin, root)
walks = 0
update()
flush()
assert(walks == 1, 'existing hooks must work after reapply')
print('Professions: 100 list updates -> 1 recipe walk; show coalescing, restore and reapply passed')

-- Exercise the real registry-to-windows addon-load route.
local professions, unrelated = 0, 0
local routing = { Profiler = ns.Profiler,
    Settings = { ModernTheme = function() return 'test' end, ModernArea = function() return true end } }
assert(loadfile('Features/Modern/Modern.lua'))('QuietUI', routing)
local m = routing.Modern
m.Skin = function() return {} end
m.Professions = { Apply = function() professions = professions + 1 end }
setmetatable(m, { __index = function() unrelated = unrelated + 1; error('unrelated window visited') end })
-- Windows registration also registers events.
CreateFrame = function() return { SetScript = noop, RegisterEvent = noop } end
assert(loadfile('Features/Modern/Areas/Windows.lua'))('QuietUI', routing)
local area = m.state.byKey.windows
area.applied, area.skin = true, {}
m.AddonLoaded('Blizzard_Professions')
assert(professions == 1 and unrelated == 0)
m.AddonLoaded('Unrelated_Addon')
assert(professions == 1)
print('Addon loading: professions applies once without visiting other windows')
