-- Readers of the friends window tests: what a skin left on a row, header or window, and what Blizzard art is
-- still showing. Everything reads a region's own state (alpha, colour, size, first point), never an ancestor's.
local Q = {}

local function colour(region, want)
    local col = region._color
    return col ~= nil and col[1] == want[1] and col[2] == want[2] and col[3] == want[3]
end

-- Comma list of the textures of `list` that are not held at alpha 0 (own alpha, parents are not looked at).
function Q.unheld(list)
    local names = {}
    for _, t in ipairs(list) do
        if t._alpha ~= 0 then names[#names + 1] = t._label or tostring(t._text) end
    end
    return table.concat(names, ",")
end

-- Comma list of what must stay but was held at alpha 0.
function Q.heldKeep(list)
    local names = {}
    for _, t in ipairs(list) do
        if t._alpha == 0 then names[#names + 1] = t._label or tostring(t._text) end
    end
    return table.concat(names, ",")
end

local function shown(region) return region._shown ~= false and (region._alpha or 1) > 0 end

-- True when the row shows a left edge in the accent colour (a thin line anchored on the left).
function Q.edge(row, theme)
    for _, region in ipairs(row._regions) do
        local first = region._points[1]
        if shown(region) and colour(region, theme.accent) and region._w <= 3 and first and tostring(first[1]):find("LEFT") then
            return true
        end
    end
    return false
end

-- Number of shown one-pixel own lines along the bottom of the row.
function Q.rules(row)
    local count = 0
    for _, region in ipairs(row._regions) do
        local first = region._points[1]
        if shown(region) and region._color and region._h == 1 and first and tostring(first[1]):find("BOTTOM") then
            count = count + 1
        end
    end
    return count
end

-- Number of shown faint own HIGHLIGHT washes of a frame.
function Q.washes(frame)
    local count = 0
    for _, region in ipairs(frame._regions) do
        if region._layer == "HIGHLIGHT" and region._color and region._color[4] and region._color[4] < 0.2
            and region._shown ~= false then
            count = count + 1
        end
    end
    return count
end

-- Accent strokes of a sign under a header (its CollapseButton included): one is a minus, two a plus.
function Q.sign(frame, theme)
    local count = 0
    for _, region in ipairs(frame._regions) do
        if shown(region) and colour(region, theme.accent) and (region._w == 10 or region._h == 10) then count = count + 1 end
    end
    for _, child in ipairs(frame._children) do count = count + Q.sign(child, theme) end
    return count
end

function Q.striped(frame, theme)
    for _, region in ipairs(frame._regions) do
        if shown(region) and colour(region, theme.strip) then return true end
    end
    return false
end

-- Number of shown regions in the theme's border colour.
function Q.edges(frame, theme)
    local count = 0
    for _, region in ipairs(frame._regions) do
        if region._shown and region._color and colour(region, theme.border) then count = count + 1 end
    end
    return count
end

-- A divider is held at alpha 0 or turned into a coloured quiet rule.
function Q.quiet(texture)
    return texture._alpha == 0 or texture._color ~= nil and texture._shown ~= false
end

-- The header band under the title row and the accent hairline beneath it.
function Q.band(frame)
    for _, region in ipairs(frame._regions) do
        if region._layer == "BACKGROUND" and region._shown and region._color and region._h == 23 then return true end
    end
    return false
end

function Q.hairline(frame, theme)
    for _, region in ipairs(frame._regions) do
        if region._shown and region._h == 1 and region._color and region._color[1] == theme.accent[1] then return true end
    end
    return false
end

-- Every frame and region at or under root: leaked own textures show as a growing count.
function Q.count(root)
    local n = #root._regions
    for _, child in ipairs(root._children) do n = n + 1 + Q.count(child) end
    return n
end

return Q
