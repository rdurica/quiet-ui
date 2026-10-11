-- Addon loader for the shared test harness. Lua 5.1-compatible syntax.
-- The only place that knows how the addon is put together: it reads QuietUI.toc.
local A = { root = nil, loaded = {} }

local function readLines(path)
    local f = assert(io.open(path, "rb"), "cannot open " .. path)
    local lines = {}
    for line in f:lines() do
        line = line:gsub("\r$", "")
        lines[#lines + 1] = line
    end
    f:close()
    return lines
end

-- Non-empty, non-comment (##) lines of QuietUI.toc, in order.
function A.tocFiles(root)
    root = root or A.root
    local out = {}
    for _, line in ipairs(readLines(root .. "/QuietUI.toc")) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 2) ~= "##" then out[#out + 1] = trimmed end
    end
    return out
end

function A.fileExists(name)
    local f = io.open(A.root .. "/" .. name, "rb")
    if f then f:close() return true end
    return false
end

-- Loads every file of the .toc, in order, into a fresh ns. Returns ns and the loaded list.
-- The mock must already be installed (mock:install()).
function A.load()
    local ns, list = {}, {}
    for _, name in ipairs(A.tocFiles()) do
        local chunk, err = loadfile(A.root .. "/" .. name)
        if not chunk then error("cannot load " .. name .. ": " .. tostring(err), 0) end
        chunk("QuietUI", ns)
        list[#list + 1] = name
    end
    A.loaded = list
    return ns, list
end

-- Fires PLAYER_LOGIN through the real event frame, drains the timer queue and discards
-- what the addon printed while starting. Fails if startup reported an error (mock gap
-- or addon bug); pass strict = false to allow that.
function A.boot(mock, strict)
    local frame = mock:eventFrame("PLAYER_LOGIN")
    if not frame then error("no frame registered PLAYER_LOGIN", 0) end
    local fn = frame:GetScript("OnEvent")
    fn(frame, "PLAYER_LOGIN")
    mock:drain()
    local out = mock.printed
    mock.printed = {}
    if strict ~= false then
        for _, line in ipairs(out) do
            if line:find("error (shown once)", 1, true) then
                error("boot reported: " .. line, 0)
            end
        end
    end
    return out
end

return A
