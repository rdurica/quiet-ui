-- Measurements for the per-frame smooth update:  lua tests/measure/performance.lua --measure
-- Works from any cwd. Prints the call counts the assertions in tests/faders/player/smooth-updates.lua
-- hold to; it asserts nothing itself.
if arg[1] ~= "--measure" then
    print("usage: lua tests/measure/performance.lua --measure")
    os.exit(1)
end
local print = print -- the mock replaces the global print
local script = arg[0] or "tests/measure/performance.lua"
local dir = script:match("^(.*)/[^/]*$") or "."
local libDir = dir .. "/../lib"
local mock = assert(loadfile(libDir .. "/mock.lua"))().new()
mock:install()
local addon = assert(loadfile(libDir .. "/addon.lua"))()
local p = io.popen("cd '" .. dir .. "/../..' && pwd")
addon.root = p:read("*l")
p:close()
local ns = addon.load()
local S = assert(loadfile(libDir .. "/smooth.lua"))()
S.dir = libDir
local s = S.build({ ns = ns, mock = mock })
local c = s.c
s.tick()
s.reset()
for _ = 1, 60 do s.tick() end
print(("Idle 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d")
    :format(c.power, c.health, c.type, c.curves, s.writes(PlayerFrame)))
print(("Idle 60 frames: curve edits=%d"):format(c.edits))
print(("Idle 60 frames: threshold settings=%d player style=%d aura hover settings=%d grouping settings=%d")
    :format(c.threshold, c.style, c.aura, c.grouping))
print(("Idle 60 frames: settled debuff checks=%d"):format(c.debuff))
s.InCombat = true
s.tick()
s.reset()
for _ = 1, 60 do s.tick() end
print(("Combat 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d")
    :format(c.power, c.health, c.type, c.curves, s.writes(PlayerFrame)))
s.InCombat = false
s.reset()
for _ = 1, 20 do s.tick() end
print(("First fade, 20 frames: curves=%d"):format(c.curves))
s.InCombat = true
s.tick()
s.InCombat = false
s.reset()
for _ = 1, 20 do s.tick() end
print(("Repeated fade, 20 frames: curves=%d"):format(c.curves))
s.HasTarget = true
s.reset()
s.tick()
print(("Target visible: hover reads=%d"):format(c.hover))
