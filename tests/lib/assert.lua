-- Assertions for the shared test harness. Lua 5.1-compatible syntax.
-- Every function raises a plain-string error (level 0) so the runner prints it verbatim.
local T = {}

local function fail(msg) error(msg, 0) end

local function show(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

function T.ok(cond, msg) if not cond then fail(msg or "expected a truthy value") end end
function T.falsy(cond, msg) if cond then fail(msg or ("expected a falsy value, got " .. show(cond))) end end
function T.eq(actual, expected, msg)
    if actual ~= expected then
        fail((msg and (msg .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual))
    end
end
function T.ne(actual, other, msg)
    if actual == other then fail((msg and (msg .. ": ") or "") .. "did not expect " .. show(other)) end
end
function T.near(actual, expected, eps, msg)
    eps = eps or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        fail((msg and (msg .. ": ") or "") .. "expected ~" .. show(expected) .. ", got " .. show(actual))
    end
end
function T.type(value, expected, msg)
    if type(value) ~= expected then
        fail((msg and (msg .. ": ") or "") .. "expected type " .. expected .. ", got " .. type(value))
    end
end
function T.deep(actual, expected, msg)
    local function same(a, b, path)
        if type(a) ~= type(b) then return false, path end
        if rawequal(a, b) then return true, path end
        if type(a) ~= "table" then return a == b, path end
        for k, v in pairs(a) do
            local ok, p = same(v, b[k], path .. "." .. tostring(k))
            if not ok then return false, p end
        end
        for k in pairs(b) do
            if a[k] == nil then return false, path .. "." .. tostring(k) end
        end
        return true
    end
    local ok, path = same(actual, expected, "")
    if not ok then fail((msg and (msg .. ": ") or "") .. "tables differ at " .. tostring(path)) end
end
function T.alpha(frame, expected, msg)
    local actual = frame._alpha
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        fail((msg and (msg .. ": ") or "") .. "expected alpha " .. show(expected) .. ", got " .. show(actual))
    end
end
function T.shown(frame, expected, msg)
    expected = expected ~= false
    if (frame._shown and true or false) ~= expected then
        fail((msg and (msg .. ": ") or "") .. "expected " .. (expected and "shown" or "hidden"))
    end
end
function T.throws(fn, pattern, ...)
    local ok, err = pcall(fn, ...)
    if ok then fail("expected an error, none raised") end
    if pattern and not tostring(err):find(pattern, 1, true) then
        fail("error " .. show(tostring(err)) .. " does not contain " .. show(pattern))
    end
end
function T.noThrow(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then fail("unexpected error: " .. tostring(err)) end
end
function T.contains(list, value, msg)
    for _, v in ipairs(list) do if v == value then return end end
    fail((msg and (msg .. ": ") or "") .. "list does not contain " .. show(value))
end

-- Runs fn and returns the lines it printed (ns.Print / ns.Report go through print).
function T.capture(mock, fn, ...)
    local before = #mock.printed
    fn(...)
    local out = {}
    for i = before + 1, #mock.printed do out[#out + 1] = mock.printed[i] end
    return out
end

-- printed(mock, pattern [, count]): the number of printed lines containing the plain
-- text `pattern` equals count (default: at least one).
function T.printed(mock, pattern, count)
    local n = 0
    for _, line in ipairs(mock.printed) do
        if line:find(pattern, 1, true) then n = n + 1 end
    end
    if count == nil then
        if n == 0 then fail("nothing printed containing " .. show(pattern)) end
    elseif n ~= count then
        fail("expected " .. count .. " printed line(s) containing " .. show(pattern) .. ", got " .. n)
    end
end

function T.notPrinted(mock, pattern) T.printed(mock, pattern, 0) end

return T
