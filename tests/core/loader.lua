-- Harness loader: file order comes from the .toc, nothing is hard-coded here.
local h = ...

h.test("loader loads the .toc files in order", function(t)
    local expected = t.tocFiles()
    t.assert.ok(#expected > 0, "the .toc lists no files")
    t.assert.deep(t.loaded, expected, "loaded list differs from the .toc")
end)

h.test("every .toc line points to an existing file", function(t)
    for _, name in ipairs(t.tocFiles()) do
        t.assert.ok(t.fileExists(name), "missing file for .toc line: " .. name)
    end
end)

h.test("the last .toc line ends the loaded list", function(t)
    local files = t.tocFiles()
    t.assert.eq(t.loaded[#t.loaded], files[#files], "last loaded file")
    t.assert.eq(#t.loaded, #files, "loaded count")
end)

h.test("loading gives a fresh namespace each time", function(t)
    t.assert.type(t.ns, "table")
    t.assert.eq(t.ns.__marker, nil, "new namespace starts empty of test marks")
    t.ns.__marker = true
end)

h.test("the mock lets the whole addon boot without reporting errors", function(t)
    t.assert.noThrow(t.boot)
end)
