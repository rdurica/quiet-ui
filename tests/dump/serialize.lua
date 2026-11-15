-- ns.Dump.Serialize: a Lua literal for plain data, placeholders for what cannot be written.
local h = ...

-- Runs Lua text as a chunk in an empty environment (5.1 and later) and returns the chunk's results.
local function run(text, env)
    local fn, err
    if setfenv then
        fn, err = loadstring(text)
        if fn then setfenv(fn, env or {}) end
    else
        fn, err = load(text, "serialized", "t", env or {})
    end
    if not fn then error("serialized text does not load: " .. tostring(err) .. "\n" .. text, 0) end
    return fn()
end

-- A literal for a value, loaded back: the value itself is expected as an expression.
local function load_back(text) return run("return " .. text) end

h.test("Serialize round-trips plain data through the Lua loader", function(t)
    local ns, A = t.ns, t.assert
    local data = {
        1, 2, "three", { 4, 5 },
        name = "Quiet \"UI\"\nline two\\ backslash",
        on = true, off = false, count = 12, negative = -7, half = 0.25, big = 100000,
        nested = { a = { b = { c = "deep" } }, list = { true, false, 3 } },
        ["a b"] = "space key", ["end"] = "reserved word", ["1abc"] = "digit first",
        [10] = "ten", [-1] = "minus one",
    }
    local text = ns.Dump.Serialize(data)
    A.type(text, "string", "Serialize result")
    A.deep(load_back(text), data)
end)

h.test("Serialize an empty table and scalars", function(t)
    local ns, A = t.ns, t.assert
    A.deep(load_back(ns.Dump.Serialize({})), {})
    A.eq(ns.Dump.Serialize("a\"b\nc"), string.format("%q", "a\"b\nc"), "strings are quoted with %q")
    A.eq(ns.Dump.Serialize(5), "5")
    A.eq(ns.Dump.Serialize(true), "true")
    A.eq(ns.Dump.Serialize(false), "false")
end)

h.test("Serialize sorts keys: numbers first ascending, then strings", function(t)
    local ns, A = t.ns, t.assert
    local text = ns.Dump.Serialize({ z = "VZ", a = "VA", m = "VM", [10] = "V10", [2] = "V2", [1] = "V1" })
    local order = {}
    for _, marker in ipairs({ "V1", "V2", "V10", "VA", "VM", "VZ" }) do
        order[#order + 1] = text:find(marker .. '"', 1, true)
        A.ok(order[#order], marker .. " is written in: " .. text)
    end
    for i = 2, #order do A.ok(order[i - 1] < order[i], "key order broken at position " .. i .. " in: " .. text) end
end)

h.test("Serialize output does not depend on insertion order", function(t)
    local ns, A = t.ns, t.assert
    local a, b = {}, {}
    for _, k in ipairs({ "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8" }) do a[k] = { v = k } end
    for i = 8, 1, -1 do b["k" .. i] = { v = "k" .. i } end
    A.eq(ns.Dump.Serialize(a), ns.Dump.Serialize(b))
    A.eq(ns.Dump.Serialize(a), ns.Dump.Serialize(a))
end)

h.test("Serialize writes <secret> for a secret value, at any depth, without looking inside", function(t)
    local ns, A = t.ns, t.assert
    local secret = t.mock:secret("INNER-VALUE")
    local text
    A.noThrow(function() text = ns.Dump.Serialize({ hp = secret, nested = { power = secret }, ok = "fine" }) end)
    A.ok(text:find("<secret>", 1, true), "no <secret> in: " .. tostring(text))
    A.falsy(text:find("INNER-VALUE", 1, true), "the secret was opened")
    A.ok(text:find("fine", 1, true), "plain values stay")
    local _, count = text:gsub("<secret>", "")
    A.eq(count, 2, "both secrets are replaced")
end)

h.test("Serialize writes <function> and <userdata> for those types", function(t)
    local ns, A = t.ns, t.assert
    local text = ns.Dump.Serialize({ fn = function() end, handle = io.stdout })
    A.ok(text:find("<function>", 1, true), "no <function> in: " .. text)
    A.ok(text:find("<userdata>", 1, true), "no <userdata> in: " .. text)
end)

h.test("Serialize writes <cycle> for a self-referencing table without an error", function(t)
    local ns, A = t.ns, t.assert
    local loop = { name = "loop" }
    loop.self = loop
    loop.child = { back = loop }
    local text
    A.noThrow(function() text = ns.Dump.Serialize(loop) end)
    A.ok(text:find("<cycle>", 1, true), "no <cycle> in: " .. tostring(text))
    A.ok(text:find("loop", 1, true), "the rest is still written")
end)

h.test("Serialize writes a table shared twice in full, not as a cycle", function(t)
    local ns, A = t.ns, t.assert
    local shared = { x = 1 }
    local data = { first = shared, second = shared, third = { inner = shared } }
    local text = ns.Dump.Serialize(data)
    A.falsy(text:find("<cycle>", 1, true), "a shared table is not a cycle: " .. text)
    A.deep(load_back(text), { first = { x = 1 }, second = { x = 1 }, third = { inner = { x = 1 } } })
end)

h.test("Serialize reads a table without changing it", function(t)
    local ns, A = t.ns, t.assert
    local data = { 1, "b", c = { d = true } }
    local before = ns.Copy(data)
    ns.Dump.Serialize(data)
    A.deep(data, before)
end)
