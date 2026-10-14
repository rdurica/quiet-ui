-- The addon adds only the documented globals (AGENTS.md, Code), including named frames.
local h = ...

local ALLOWED = {
    QuietUIDB = true, QuietUICharDB = true,
    SLASH_QUIETUI1 = true, SLASH_QUIETUI2 = true,
    QuietUISetup = true, QuietUIGlance = true,
    BINDING_CATEGORY_QUIETUI = true, BINDING_NAME_QUIETUI_GLANCE = true,
}

local before, beforeMock
h.test("loading, booting and opening setup add only the documented globals", function(t)
    local extra = {}
    for k in pairs(_G) do
        if not before[k] and not ALLOWED[k] then extra[#extra + 1] = tostring(k) end
    end
    t.boot()
    SlashCmdList.QUIETUI("setup")
    for k in pairs(_G) do
        if not before[k] and not ALLOWED[k] then extra[#extra + 1] = tostring(k) end
    end
    table.sort(extra)
    -- The mock keeps named frames in its own global table.
    for k in pairs(t.mock.G) do
        if not beforeMock[k] and not ALLOWED[k] then extra[#extra + 1] = "frame " .. tostring(k) end
    end
    table.sort(extra)
    t.assert.deep(extra, {}, "undocumented globals: " .. table.concat(extra, ", "))
    t.assert.ok(t.mock:findByName("QuietUISetup") ~= nil, "/quiet setup creates QuietUISetup")
end, { beforeLoad = function(mock)
    beforeMock = {}
    for k in pairs(mock.G) do beforeMock[k] = true end
    before = {}
    for k in pairs(_G) do before[k] = true end
end })
