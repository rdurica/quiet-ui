-- Test runner:  lua tests/run.lua [filter]      (works from any cwd; Lua 5.1-compatible syntax)
--
-- filter: substring of "area/file" (e.g. "core/loader"), of a legacy script name
-- ("review"), or of a test name. No filter runs everything. A filter that matches
-- nothing prints a message and exits 1. Exit code is 1 when any test fails.
--
-- NEW TESTS live in tests/<area>/**.lua (any subdirectory except tests/lib). The file is
-- a chunk that receives the harness as `...` and declares its tests:
--
--     local h = ...
--     h.test("Pinned reads saved visibility", function(t)
--         t.mock.cvars.foo = "1"           -- t.mock : fresh WoW mock (tests/lib/mock.lua)
--         QuietUICharDB.visible = { xp = true }
--         t.assert.eq(t.ns.Pinned("xp"), true)
--     end)
--
-- Each test case runs with clean state: _G is snapshotted and restored, a fresh mock is
-- installed, and the whole addon is loaded anew into a fresh `t.ns` (top-level code of
-- every file runs, nothing is booted). Context `t`:
--     t.ns            fresh addon namespace            t.mock     the mock (see mock.lua header)
--     t.assert        eq/ne/ok/falsy/near/type/deep/alpha/shown/throws/noThrow/contains/
--                     capture/printed/notPrinted (see assert.lua)
--     t.boot([strict])  fire PLAYER_LOGIN through the real event frame, drain C_Timer,
--                     discard startup output; errors if startup reported one
--     t.loaded        list of files the loader loaded, in order
--     t.tocFiles()    the .toc file lines read independently;  t.fileExists(name)
-- New tests must not call loadfile/dofile and must not name production files; only the
-- loader (tests/lib/addon.lua) reads QuietUI.toc.
--
-- LEGACY scripts tests/*.lua (except run.lua) run as `lua <script> <root>` subprocesses
-- with cwd at the addon root. Pass = exit code 0 and no output line starting with FAIL.
-- Legacy performance.lua / chat-animation.lua run in assertion mode (no --measure).

local print, tostring, ipairs, pairs, pcall = print, tostring, ipairs, pairs, pcall
local realIO, realOS = io, os

local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function capture(cmd)
    local p = realIO.popen(cmd, "r")
    local out = p:read("*a")
    p:close()
    return out
end

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)/[^/]*$") or "."
local luaBin = (arg and arg[-1]) or "lua"
local root = capture("cd " .. shq(testsDir .. "/..") .. " && pwd"):gsub("%s+$", "")
if root == "" then root = testsDir .. "/.." end
testsDir = root .. "/tests"

local filter = arg and arg[1]
if filter == "" then filter = nil end

local function matches(...)
    if not filter then return true end
    for i = 1, select("#", ...) do
        local s = select(i, ...)
        if s and tostring(s):find(filter, 1, true) then return true end
    end
    return false
end

local function lines(cmd)
    local out = {}
    for line in capture(cmd):gmatch("[^\r\n]+") do out[#out + 1] = line end
    table.sort(out)
    return out
end

local mockLib = assert(loadfile(testsDir .. "/lib/mock.lua"))()
local addon = assert(loadfile(testsDir .. "/lib/addon.lua"))()
local assertLib = assert(loadfile(testsDir .. "/lib/assert.lua"))()
addon.root = root

local passed, failed = 0, 0
local failures = {}

local function record(ok, id, detail)
    if ok then
        passed = passed + 1
        print("PASS " .. id)
    else
        failed = failed + 1
        failures[#failures + 1] = id
        print("FAIL " .. id)
        if detail and detail ~= "" then
            print("     " .. tostring(detail):gsub("\n", "\n     "))
        end
    end
end

local matched = 0

------------------------------------------------------------------------------
-- New tests
------------------------------------------------------------------------------
local function snapshotG()
    local snap = {}
    for k, v in pairs(_G) do snap[k] = v end
    return snap
end

local function restoreG(snap)
    for k in pairs(_G) do
        if snap[k] == nil then _G[k] = nil end
    end
    for k, v in pairs(snap) do
        if _G[k] ~= v then _G[k] = v end
    end
end

local areaFiles = lines("find " .. shq(testsDir) .. " -mindepth 2 -name '*.lua' -not -path "
    .. shq(testsDir .. "/lib/*"))

local function runCase(case)
    local snap = snapshotG()
    local ok, err = pcall(function()
        local mock = mockLib.new()
        mock:install()
        local ns, list = addon.load()
        local t = {
            ns = ns, mock = mock, assert = assertLib, loaded = list,
            tocFiles = function() return addon.tocFiles() end,
            fileExists = addon.fileExists,
            boot = function(strict) return addon.boot(mock, strict) end,
        }
        case.fn(t)
    end)
    restoreG(snap)
    return ok, err
end

for _, path in ipairs(areaFiles) do
    local rel = path:sub(#testsDir + 2)
    local id = rel:gsub("%.lua$", "")
    local cases = {}
    local h = {
        test = function(name, fn)
            cases[#cases + 1] = { name = name, fn = fn }
        end,
    }
    local chunk, err = loadfile(path)
    local loadOk = chunk ~= nil
    if loadOk then loadOk, err = pcall(chunk, h) end
    if not loadOk then
        if matches(id) then
            matched = matched + 1
            record(false, id .. " (file does not load)", err)
        end
    else
        for _, case in ipairs(cases) do
            local full = id .. ": " .. case.name
            if matches(id, case.name, full) then
                matched = matched + 1
                local ok, e = runCase(case)
                record(ok, full, e)
            end
        end
    end
end

------------------------------------------------------------------------------
-- Legacy scripts
------------------------------------------------------------------------------
local legacy = lines("find " .. shq(testsDir) .. " -maxdepth 1 -name '*.lua' -not -name 'run.lua'")
for _, path in ipairs(legacy) do
    local name = path:match("([^/]*)$")
    if matches((name:gsub("%.lua$", "")), name) then
        matched = matched + 1
        local cmd = "cd " .. shq(root) .. " && " .. shq(luaBin) .. " " .. shq(path) .. " " .. shq(root)
            .. " 2>&1; echo \"__EXIT:$?\""
        local out = capture(cmd)
        local code = tonumber(out:match("__EXIT:(%d+)%s*$"))
        out = out:gsub("__EXIT:%d+%s*$", "")
        local bad = {}
        for line in out:gmatch("[^\r\n]+") do
            if line:find("^FAIL") then bad[#bad + 1] = line end
        end
        local ok = code == 0 and #bad == 0
        local detail
        if not ok then
            if #bad > 0 then detail = table.concat(bad, "\n")
            else detail = "exit code " .. tostring(code) .. "\n" .. out:sub(-1500) end
        end
        record(ok, "legacy/" .. name, detail)
    end
end

------------------------------------------------------------------------------
if matched == 0 then
    print("No tests match filter '" .. tostring(filter) .. "'")
    realOS.exit(1)
end

print("")
print(string.format("%d passed, %d failed, %d total", passed, failed, passed + failed))
if failed > 0 then
    print("Failed:")
    for _, id in ipairs(failures) do print("  " .. id) end
    realOS.exit(1)
end
realOS.exit(0)
