-- Static structure checks over addon sources. Lua 5.1-compatible syntax.
--
-- Every check works on a list of sources, {name = "Core/Base.lua", text = "..."}, so a test
-- can feed synthetic files to prove a check fails. Each check returns a list of problem
-- strings "name:line: message" (empty list = ok). Loaded with h.lib("structure").
--
--   S.undefinedRefs(sources)            ns.X / ns.T.X read or called but never defined
--   S.globalAssignments(sources)        assignment to a global outside S.ALLOWED_GLOBALS
--   S.tocProblems(toc, files, exists)   .lua under the checked folders not in the .toc,
--                                       .toc lines that do not exist
--   S.sizeProblems(sources, max, allow) files over `max` lines (allow[name] = reason)
--   S.captures(sources)                 top-level `local X = ns.Y` of a function from another file
--
-- Heuristics (text based, no Lua parser): comments and string contents are blanked first.
-- A definition is `ns.X =`, `function ns.X(`, `ns.T.X =`, `function ns.T.X(` / `ns.T:X(`,
-- fields of `ns.T = { ... }`, and the same through an alias (`local T = ns.T`, or a local
-- table later assigned `ns.T = T`). `ns.T.X` is only checked when `ns.T` is a table whose
-- fields are all visible (constructor or alias); a table filled from an unknown value or
-- through `T[expr] = ` is opaque and skipped.
local S = {}

S.ALLOWED_GLOBALS = {
    QuietUIDB = true, QuietUICharDB = true, QuietUISetup = true, QuietUIGlance = true,
    BINDING_CATEGORY_QUIETUI = true, BINDING_NAME_QUIETUI_GLANCE = true, GetMinimapShape = true,
}
S.ALLOWED_SLASH_KEYS = { QUIETUI = true }
S.CHECKED_DIRS = { "Core", "Settings", "Features", "Setup", "Layout" }
S.MAX_LINES = 400

------------------------------------------------------------------------------
-- Text helpers
------------------------------------------------------------------------------
local function blank(s) return (s:gsub("[^\n]", " ")) end

-- Same length and newlines; comments and string contents become spaces.
function S.strip(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local j = text:find("[%-\"'%[]", i)
        if not j then out[#out + 1] = text:sub(i); break end
        out[#out + 1] = text:sub(i, j - 1)
        local c = text:sub(j, j)
        if c == "-" then
            if text:sub(j, j + 1) == "--" then
                local eq = text:match("^%-%-%[(=*)%[", j)
                local e
                if eq then
                    local _, close = text:find("]" .. eq .. "]", j, true)
                    e = close or n
                else
                    e = (text:find("\n", j, true) or n + 1) - 1
                end
                out[#out + 1] = blank(text:sub(j, e))
                i = e + 1
            else
                out[#out + 1] = "-"
                i = j + 1
            end
        elseif c == "[" then
            local eq = text:match("^%[(=*)%[", j)
            if eq then
                local _, close = text:find("]" .. eq .. "]", j, true)
                local e = close or n
                out[#out + 1] = blank(text:sub(j, e))
                i = e + 1
            else
                out[#out + 1] = "["
                i = j + 1
            end
        else
            local k = j + 1
            while k <= n do
                local d = text:sub(k, k)
                if d == "\\" then k = k + 2
                elseif d == c or d == "\n" then break
                else k = k + 1 end
            end
            local closed = text:sub(k, k) == c
            out[#out + 1] = c .. blank(text:sub(j + 1, k - 1)) .. (closed and c or "")
            i = closed and k + 1 or k
        end
    end
    return table.concat(out)
end

local function lineIndex(text)
    local starts = { 1 }
    for p in text:gmatch("()\n") do starts[#starts + 1] = p + 1 end
    return function(pos)
        local lo, hi = 1, #starts
        while lo < hi do
            local mid = math.ceil((lo + hi) / 2)
            if starts[mid] <= pos then lo = mid else hi = mid - 1 end
        end
        return lo
    end
end

local function problem(name, line, msg) return string.format("%s:%d: %s", name, line, msg) end

local function lineCount(text)
    local n = 0
    for _ in text:gmatch("\n") do n = n + 1 end
    if text ~= "" and text:sub(-1) ~= "\n" then n = n + 1 end
    return n
end

-- Position of the } matching the { at `open`, or nil.
local function matchBrace(s, open)
    local depth = 0
    for p in s:gmatch("()[{}]", open) do
        if s:sub(p, p) == "{" then depth = depth + 1 else
            depth = depth - 1
            if depth == 0 then return p end
        end
    end
end

------------------------------------------------------------------------------
-- Model of ns: definitions and references
------------------------------------------------------------------------------
-- Returns { defs = {path = {files = {}, fn = bool}}, tables = {path = true},
--           opaque = {path = true}, refs = {{file =, line =, parts = {...}}} }
local function analyse(sources)
    local model = { defs = {}, tables = {}, opaque = {}, refs = {} }
    local perFile = {}

    local function define(path, kind, file)
        local d = model.defs[path]
        if not d then d = { files = {}, fn = false }; model.defs[path] = d end
        d.files[file] = true
        if kind == "function" then d.fn = true end
        local parent = path:match("^(.+)%.[^.]+$")
        while parent and parent ~= "ns" do
            model.tables[parent] = true
            parent = parent:match("^(.+)%.[^.]+$")
        end
    end

    for _, src in ipairs(sources) do
        -- `select(2, ...).X = ` is the file-argument form of `ns.X =`
        local s = S.strip(src.text):gsub("select%(%s*2%s*,%s*%.%.%.%s*%)", "ns")
        local info = { s = s, lineOf = lineIndex(s), alias = {}, localTable = {}, localFn = {} }
        perFile[src] = info
        for name in s:gmatch("local%s+function%s+([%a_][%w_]*)") do info.localFn[name] = true end
        for name in s:gmatch("\nfunction%s+([%a_][%w_]*)%s*%(") do info.localFn[name] = true end
        for name in s:gmatch("local%s+([%a_][%w_]*)%s*=%s*{") do info.localTable[name] = true end
        -- local T = ns.T  (a table, not a call)
        for name, path, after in s:gmatch("local%s+([%a_][%w_]*)%s*=%s*(ns[%w_.]*)%s*()") do
            local c = s:sub(after, after)
            if c ~= "(" and c ~= "[" and c ~= ":" and c ~= "{" then info.alias[name] = path end
        end
        -- ns.T = T  where T is a local table
        for path, name in s:gmatch("(ns[%w_.]*)%s*=%s*([%a_][%w_]*)%s*[\n;]") do
            if info.localTable[name] then info.alias[name] = path end
        end
    end

    local function resolve(info, root, rest)
        if root == "ns" then return "ns" .. rest end
        local target = info.alias[root]
        if target then return target .. rest end
    end

    for _, src in ipairs(sources) do
        local info = perFile[src]
        local s, lineOf = info.s, info.lineOf

        -- Fields of a constructor at `open` ({): depth-1 `name =` entries.
        local function fields(path, open)
            local close = matchBrace(s, open)
            if not close then model.opaque[path] = true; return end
            model.tables[path] = true
            local body = s:sub(open + 1, close - 1)
            local depth, i = 0, 1
            while i <= #body do
                local c = body:sub(i, i)
                local step = 1
                if c == "{" or c == "(" then
                    depth = depth + 1
                elseif c == "}" or c == ")" then
                    depth = depth - 1
                elseif depth == 0 and c:match("[%a_]") then
                    step = #body:match("^[%w_]+", i)
                    local prev = body:sub(1, i - 1):match("([^%s])%s*$")
                    local name, eqEnd = body:match("^([%a_][%w_]*)%s*=%s*()", i)
                    if name and (prev == nil or prev == "," or prev == ";") and body:sub(eqEnd, eqEnd) ~= "=" then
                        local kind = body:match("^function", eqEnd) and "function" or "value"
                        define(path .. "." .. name, kind, src.name)
                    end
                end
                i = i + step
            end
        end

        for name in pairs(info.localTable) do
            local target = info.alias[name]
            if target then
                local open = s:match("local%s+" .. name .. "%s*=%s*(){")
                if open then fields(target, open) end
            end
        end

        for pos, root, rest in s:gmatch("()([%a_][%w_]*)([%.%w_]*)") do
            local before = pos > 1 and s:sub(pos - 1, pos - 1) or ""
            local head = s:sub(math.max(1, pos - 12), pos - 1)
            local declaration = head:match("local%s+$") ~= nil
            if before ~= "." and before ~= ":" and not before:match("[%w_]") and not declaration then
                local endPos = pos + #root + #rest
                local path = resolve(info, root, rest)
                if path and path ~= "ns" then
                    local viaFunction = head:match("function%s+$") ~= nil
                    local method = s:match("^:([%a_][%w_]*)", endPos)
                    local eq = s:match("^%s*=()", endPos)
                    local isAssign = eq and s:sub(eq, eq) ~= "="
                    if viaFunction then
                        define(method and (path .. "." .. method) or path, "function", src.name)
                    elseif isAssign then
                        local kind, tableOpen = "value", nil
                        if s:match("^%s*function[%s%(]", eq) then
                            kind = "function"
                        else
                            tableOpen = s:match("^%s*(){", eq)
                            if not tableOpen then
                                tableOpen = s:match("^%s*" .. path:gsub("%.", "%%.") .. "%s+or%s+(){", eq)
                            end
                            local ident = s:match("^%s*([%a_][%w_]*)%s*[\n;]", eq)
                            if ident and info.localFn[ident] then kind = "function"
                            elseif ident and info.localTable[ident] then model.tables[path] = true end
                        end
                        define(path, kind, src.name)
                        if tableOpen then fields(path, tableOpen) end
                    else
                        local parts = {}
                        for part in path:gmatch("[^.]+") do parts[#parts + 1] = part end
                        model.refs[#model.refs + 1] = { file = src.name, line = lineOf(pos), parts = parts }
                    end
                    -- T[expr] = ... fills the table dynamically
                    if s:sub(endPos, endPos) == "[" then model.opaque[path] = true end
                end
            end
        end
    end
    return model
end

------------------------------------------------------------------------------
-- 1. Undefined ns references
------------------------------------------------------------------------------
function S.undefinedRefs(sources)
    local model = analyse(sources)
    local out, seen = {}, {}
    for _, ref in ipairs(model.refs) do
        local p = ref.parts
        if p[2] then
            local first = "ns." .. p[2]
            local bad
            if not model.defs[first] and not model.tables[first] then
                bad = first
            elseif p[3] and model.tables[first] and not model.opaque[first]
                and not model.defs[first .. "." .. p[3]] and not model.tables[first .. "." .. p[3]] then
                local d = model.defs[first]
                if not d or not d.fn then bad = first .. "." .. p[3] end
            end
            if bad then
                local key = ref.file .. ":" .. ref.line .. ":" .. bad
                if not seen[key] then
                    seen[key] = true
                    out[#out + 1] = problem(ref.file, ref.line, "undefined " .. bad)
                end
            end
        end
    end
    return out
end

------------------------------------------------------------------------------
-- 2. Global assignments
------------------------------------------------------------------------------
function S.globalAssignments(sources)
    local out = {}
    for _, src in ipairs(sources) do
        local s = S.strip(src.text)
        local lineOf = lineIndex(s)
        local locals = {}
        local function addNames(list)
            for name in list:gmatch("[%a_][%w_]*") do locals[name] = true end
        end
        for name in s:gmatch("local%s+function%s+([%a_][%w_]*)") do locals[name] = true end
        for list in s:gmatch("local%s+([%w_ \t,]+)") do addNames(list) end
        for list in s:gmatch("function[%w_.:%s]*%(([^)]*)%)") do addNames(list) end
        for list in s:gmatch("for%s+([%w_ \t,]+)%s+in%f[%s]") do addNames(list) end
        for list in s:gmatch("for%s+([%w_]+)%s*=") do addNames(list) end

        local function allowed(name)
            return S.ALLOWED_GLOBALS[name] or name:match("^SLASH_QUIETUI%d*$") ~= nil
        end
        local function report(pos, name, how)
            out[#out + 1] = problem(src.name, lineOf(pos), how .. " global " .. name)
        end

        -- brace depth at every position: assignments inside constructors are fields
        local depthAt, depth = {}, 0
        for i = 1, #s do
            local c = s:sub(i, i)
            if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
            depthAt[i] = depth
        end

        for pos, name, after in s:gmatch("()([%a_][%w_]*)%s*()") do
            local before = pos > 1 and s:sub(pos - 1, pos - 1) or ""
            if before ~= "." and before ~= ":" and not before:match("[%w_]") then
                local c = s:sub(after, after)
                if c == "=" and s:sub(after + 1, after + 1) ~= "=" and not locals[name]
                    and (depthAt[pos] or 0) == 0 and not allowed(name) then
                    local prevWord = s:sub(1, pos - 1):match("([%a_][%w_]*)%s*$")
                    local prevChar = s:sub(1, pos - 1):match("([^%s])%s*$")
                    if prevWord ~= "local" and prevChar ~= "," then report(pos, name, "assignment to") end
                elseif name == "function" then
                    local fname = s:match("^([%a_][%w_]*)%s*%(", after)
                    if fname and not locals[fname] and not allowed(fname) then
                        report(after, fname, "function definition makes")
                    end
                end
            end
        end
        for pos, key in s:gmatch("()_G%.([%a_][%w_]*)%s*=[^=]") do
            if not allowed(key) then report(pos, key, "assignment to") end
        end
        -- SlashCmdList["KEY"] = ...  (the key is blanked in `s`, so read it from the raw text)
        for pos, keyStart in s:gmatch("()SlashCmdList%[%s*[\"']()") do
            if s:match("^[^%]]*%]%s*=[^=]", keyStart) then
                local key = src.text:match("^[%w_]*", keyStart)
                if not S.ALLOWED_SLASH_KEYS[key] then report(pos, "SlashCmdList." .. key, "assignment to") end
            end
        end
        for pos, key in s:gmatch("()SlashCmdList%.([%a_][%w_]*)%s*=[^=]") do
            if not S.ALLOWED_SLASH_KEYS[key] then report(pos, "SlashCmdList." .. key, "assignment to") end
        end
    end
    return out
end

------------------------------------------------------------------------------
-- 3. .toc coverage
------------------------------------------------------------------------------
-- toc: lines of the .toc; files: .lua paths found under S.CHECKED_DIRS; exists(name) -> bool
function S.tocProblems(toc, files, exists)
    local out, listed = {}, {}
    for _, name in ipairs(toc) do
        listed[name] = true
        if not exists(name) then out[#out + 1] = "QuietUI.toc: lists a file that does not exist: " .. name end
    end
    for _, name in ipairs(files) do
        if not listed[name] then out[#out + 1] = name .. ": not listed in QuietUI.toc" end
    end
    return out
end

------------------------------------------------------------------------------
-- 4. File size
------------------------------------------------------------------------------
function S.sizeProblems(sources, max, allow)
    max, allow = max or S.MAX_LINES, allow or {}
    local out, present = {}, {}
    for _, src in ipairs(sources) do
        present[src.name] = true
        local n = lineCount(src.text)
        local reason = allow[src.name]
        if n > max and not reason then
            out[#out + 1] = problem(src.name, n, string.format("%d lines, limit %d (split it or allowlist it with a reason)", n, max))
        elseif n > max and reason == "" then
            out[#out + 1] = problem(src.name, n, "allowlisted without a reason")
        elseif n <= max and reason then
            out[#out + 1] = problem(src.name, n, string.format("%d lines is within the limit: remove it from the allowlist", n))
        end
    end
    for name in pairs(allow) do
        if not present[name] then out[#out + 1] = name .. ": allowlisted but not a loaded file: remove it from the allowlist" end
    end
    table.sort(out)
    return out
end

------------------------------------------------------------------------------
-- 5. Captured functions of other files
------------------------------------------------------------------------------
function S.captures(sources)
    local model = analyse(sources)
    local out = {}
    for _, src in ipairs(sources) do
        local lineNo = 0
        for line in (S.strip(src.text) .. "\n"):gmatch("([^\n]*)\n") do
            lineNo = lineNo + 1
            local name, path = line:match("^local%s+([%a_][%w_]*)%s*=%s*(ns[%w_.]+)%s*$")
            if not name then name, path = line:match("^local%s+([%a_][%w_]*)%s*=%s*(ns[%w_.]+)%s+or%s") end
            local d = path and model.defs[path]
            if d and d.fn then
                for file in pairs(d.files) do
                    if file ~= src.name then
                        out[#out + 1] = problem(src.name, lineNo, string.format(
                            "local %s captures %s, a function defined in %s; call it through ns at run time",
                            name, path, file))
                        break
                    end
                end
            end
        end
    end
    return out
end

return S
