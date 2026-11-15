-- The GitHub issue form the /quiet dump link opens: .github/ISSUE_TEMPLATE/bug.yml, checked as plain text (no YAML library).
local h = ...

local PATH = ".github/ISSUE_TEMPLATE/bug.yml"
local IDS = { "what", "expected", "steps", "setup", "report" }

-- The text of each form field block, keyed by its id, and the ids in file order.
local function fields(text)
    local blocks, order, cur = {}, {}, nil
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local id = line:match("^%s*id:%s*[\"']?([%w_%-]+)[\"']?%s*$")
        if id then
            cur = id
            blocks[id] = {}
            order[#order + 1] = id
        end
        if cur then blocks[cur][#blocks[cur] + 1] = line end
    end
    for k, v in pairs(blocks) do blocks[k] = table.concat(v, "\n") end
    return blocks, order
end

local function read(t)
    t.assert.ok(t.fileExists(PATH), PATH .. " exists")
    return t.readFile(PATH)
end

h.test("The bug form has the title Bug: and the label bug", function(t)
    local A = t.assert
    local text = read(t)
    A.ok(text:find("\ntitle:%s*[\"']Bug: [\"']") or text:find("^title:%s*[\"']Bug: [\"']"), "title is 'Bug: '")
    A.ok(text:find("\nlabels:%s*%[%s*[\"']?bug[\"']?%s*%]") or text:find("\nlabels:%s*\n%s*%-%s*[\"']?bug[\"']?%s*\n"),
        "label bug")
end)

h.test("The bug form has the fields what, expected, steps, setup, report in this order", function(t)
    local A = t.assert
    local _, order = fields(read(t))
    A.deep(order, IDS)
end)

h.test("The fields what, expected and report are required, steps and setup are optional", function(t)
    local A = t.assert
    local blocks = fields(read(t))
    for _, id in ipairs({ "what", "expected", "report" }) do
        A.ok(blocks[id], "field " .. id)
        A.ok(blocks[id] and blocks[id]:find("required:%s*true"), id .. " is required")
    end
    for _, id in ipairs({ "steps", "setup" }) do
        A.ok(blocks[id], "field " .. id)
        A.falsy(blocks[id] and blocks[id]:find("required:%s*true"), id .. " is optional")
    end
end)

h.test("The form field kinds: what, expected, steps and report are textareas, setup is an input", function(t)
    local A = t.assert
    local blocks = fields(read(t))
    -- The type line precedes the id line in a form field, so look at the text up to the next field's type line.
    local text = read(t)
    local kinds, last = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local kind = line:match("^%s*%-?%s*type:%s*([%w_%-]+)%s*$")
        if kind then last = kind end
        local id = line:match("^%s*id:%s*[\"']?([%w_%-]+)[\"']?%s*$")
        if id and last then kinds[id] = last end
    end
    for _, id in ipairs({ "what", "expected", "steps", "report" }) do A.eq(kinds[id], "textarea", id .. " kind") end
    A.eq(kinds.setup, "input", "setup kind")
    A.ok(blocks.report, "dependency: report field")
end)

h.test("The report field renders as text", function(t)
    local A = t.assert
    local blocks = fields(read(t))
    A.ok(blocks.report and blocks.report:find("render:%s*[\"']?text[\"']?%s*\n") or
        blocks.report and blocks.report:find("render:%s*[\"']?text[\"']?%s*$"), "report has render: text")
    for _, id in ipairs({ "what", "expected", "steps", "setup" }) do
        A.falsy(blocks[id] and blocks[id]:find("render:"), id .. " has no render")
    end
end)
