-- Run from the addon directory: lua tests/review.lua
local failures = 0
local unpack = table.unpack or unpack
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error('Missing helper: ' .. name)
end
local function frame(parent)
    local obj = { alpha = 1, shown = true, parent = parent, scripts = {}, children = {}, regions = {} }
    function obj:IsForbidden() return false end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:IsShown() return self.shown end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:GetParent() return self.parent end
    function obj:SetParent(value) self.parent = value end
    function obj:GetName() return self.name end
    function obj:GetFrameLevel() return 1 end
    function obj:GetWidth() return 100 end
    function obj:GetHeight() return 10 end
    function obj:GetNumRegions() return #self.regions end
    function obj:GetNumChildren() return #self.children end
    function obj:GetRegions()
        self.regionReads = (self.regionReads or 0) + 1
        return unpack(self.regions)
    end
    function obj:GetChildren()
        self.childReads = (self.childReads or 0) + 1
        return unpack(self.children)
    end
    function obj:SetScript(name, fn) self.scripts[name] = fn end
    function obj:HookScript() end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel',
        'EnableMouse', 'EnableMouseWheel', 'SetIgnoreParentAlpha', 'SetColorTexture' }) do
        obj[name] = function() end
    end
    function obj:CreateTexture() return frame(self) end
    return obj
end
local function namespace()
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    UIParent = frame()
    GetTime = function() return 100 end
    hooksecurefunc = function(obj, method, hook)
        local original = obj[method]
        obj[method] = function(self, ...)
            local result = original(self, ...)
            hook(self, ...)
            return result
        end
    end
    local ns = {}
    loadAddon('Core.lua', ns)
    for _, name in ipairs({ 'InEditMode', 'InCombat', 'InGroup', 'InForcedInstance', 'InVehicle',
        'HasTarget', 'Glancing', 'Pinned', 'OnlyOnHover', 'RequireLivingTarget', 'ShowAll', 'XPForced' }) do
        ns[name] = function() return false end
    end
    ns.VisibilityShow = function(name, usual, hovered)
        return ns.InEditMode() or ns.Glancing() or usual or hovered or false
    end
    ns.CharDB = function() return QuietUICharDB end
    ns.ModernChat = function() return QuietUICharDB.chat ~= false end
    ns.GroupAuras = function() return true end
    ns.PlayerStyle = function() return 'classic' end
    ns.TouchHud = function() end
    return ns
end

test('Native chat stays visible after addon or Modern chat is disabled', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local strip = upvalue(ns.StripAllChat, 'StripChat')
    local bind = upvalue(strip, 'BindBubbles')
    local chat = frame()
    local font = frame(chat)
    function font:GetObjectType() return 'FontString' end
    chat.regions = { font }
    function chat:AddMessage() end
    function chat:HookScript(name, fn) self.scripts[name] = fn end
    local scrolls = 0
    function chat:ScrollUp() scrolls = scrolls + 1 end
    bind(chat)
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Active chat wheel must work')
    chat:AddMessage('enabled')
    assert(font.alpha == 0)
    QuietUICharDB.chat = false
    font.alpha = 1
    chat:AddMessage('modern chat off')
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Wheel hook remained active with Modern chat off')
    assert(font.alpha == 1, 'AddMessage hid native text with Modern chat off')
    QuietUICharDB.chat = nil
    QuietUIDB.enabled = false
    font.alpha = 1
    chat:AddMessage('addon off')
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Wheel hook remained active with addon off')
    assert(font.alpha == 1, 'AddMessage hid native text with addon off')
    assert(#chat._quietLines == 3, 'History must still be collected while disabled')
end)

test('Native chat traversal reads each region and child list once', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local bind = upvalue(upvalue(ns.StripAllChat, 'StripChat'), 'BindBubbles')
    local chat = frame()
    function chat:AddMessage() end
    for i = 1, 8 do
        local font = frame(chat)
        function font:GetObjectType() return 'FontString' end
        chat.regions[i] = font
        chat.children[i] = frame(chat)
    end
    bind(chat)
    chat.regionReads, chat.childReads = 0, 0
    chat:AddMessage('hello')
    assert(chat.regionReads == 1, 'Region list reads: ' .. chat.regionReads)
    assert(chat.childReads == 1, 'Child list reads: ' .. chat.childReads)
end)

test('Chat verifies wrapped history and resized bubbles before going idle', function()
    local ns = namespace()
    ns.ChatFade = function() return 0 end
    loadAddon('Chat.lua', ns)
    local layout = upvalue(ns.UpdateChat, 'LayoutFrame')
    local size = upvalue(layout, 'SizeBubble')
    local function replace(fn, name, value)
        for i = 1, 100 do
            local key = debug.getupvalue(fn, i)
            if key == name then debug.setupvalue(fn, i, value); return end
            if not key then break end
        end
        error('Missing helper: ' .. name)
    end
    -- Three 60px words total 200px with spaces, but need three rows at 100px.
    replace(size, 'UnboundedWidth', function() return 200 end)
    replace(size, 'PlaceLinks', function() end)
    for _, scenario in ipairs({ 'history', 'scroll', 'hover', 'resize', 'secret', 'spacing' }) do
        local msg = { text = 'AAAAAA BBBBBB CCCCCC', born = 100,
            secret = scenario == 'secret' or nil }
        local fs = { reads = 0 }
        function fs:GetFont() return 'test', 14, '' end
        function fs:SetWidth(w) self.width = w end
        function fs:SetText() end
        function fs:SetTextColor() end
        function fs:GetStringHeight()
            self.reads = self.reads + 1
            if scenario == 'secret' and self.reads == 1 then return 0 end
            return self.width >= 200 and 14 or 42
        end
        function fs:GetNumLines() return self.width >= 200 and 1 or 3 end
        function fs:GetLineHeight() return 14 end
        function fs:GetSpacing() return scenario == 'spacing' and 2 or 0 end
        local bubble = frame()
        bubble.text, bubble.msg, bubble._y = fs, msg, 4
        function bubble:SetSize(w, h) self.width, self.height = w, h end
        local chat = frame()
        chat.width = scenario == 'resize' and 318 or 118
        function chat:GetWidth() return self.width end
        function chat:GetHeight() return 200 end
        function chat:GetFont() return 'test', 14, '' end
        chat._quietLines = scenario == 'scroll' and { msg, {} } or { msg }
        chat._quietByMsg = { [msg] = bubble }
        chat._quietDirty = true
        chat._quietHover = scenario == 'hover'
        chat._quietScroll = scenario == 'scroll' and 1 or 0
        layout(chat, 1/60)
        if scenario == 'resize' then
            assert(bubble._quietSizeKey, 'Single row should be cached')
            chat.width = 118
            layout(chat, 1/60)
        end
        assert(chat._quietNext == 0, scenario .. ': missing follow-up measurement')
        layout(chat, 1/60)
        if scenario == 'secret' then
            assert(not bubble._quietSizeKey, 'Zero height must not be cached')
            assert(chat._quietNext == 0, 'Unavailable height needs another measurement')
            layout(chat, 1/60)
        end
        assert(bubble.height >= 52, scenario .. ': last row remains clipped')
        if scenario == 'spacing' then
            local reads = fs.reads
            for _ = 1, 600 do layout(chat, 1/60) end
            print('Idle wrapped chat, 600 frames: extra height reads=' .. (fs.reads - reads))
            assert(fs.reads == reads, 'Line spacing kept remeasuring settled chat every frame')
        end
        assert(bubble._quietSizeKey, scenario .. ': measured size was not cached')
        assert(chat._quietNext == nil, scenario .. ': settled chat keeps waking')
        local reads = fs.reads
        layout(chat, 1/60)
        assert(fs.reads == reads, scenario .. ': idle chat remeasured text')
    end
end)

test('Chat uses rendered hyperlinks without covering wrapped text with buttons', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local layout = upvalue(ns.UpdateChat, 'LayoutFrame')
    local create = upvalue(upvalue(layout, 'AcquireBubble'), 'CreateBubble')
    local bind = upvalue(create, 'BindBubbleLinks')
    local place = upvalue(upvalue(layout, 'SizeBubble'), 'PlaceLinks')
    local bubble = frame()
    bubble.chat, bubble.msg, bubble.links = frame(), { text = 'wrapped item links' }, {}
    function bubble:SetHyperlinksEnabled(value) self.hyperlinks = value end
    bind(bubble)
    assert(bubble.hyperlinks, 'Rendered hyperlink hit testing was not enabled')
    place(bubble, bubble.msg, 100)
    assert(#bubble.links == 0, 'Manual hit rectangles still cover rendered text')
    local oldTooltip, oldRef = GameTooltip, SetItemRef
    local shown, opened = {}, {}
    GameTooltip = {
        SetOwner = function(_, owner) assert(owner == bubble) end,
        SetHyperlink = function(_, link) shown[#shown + 1] = link end,
        Show = function() end,
        Hide = function() shown.hidden = true end,
    }
    SetItemRef = function(link, text, button, chat)
        opened[#opened + 1] = { link, text, button, chat }
    end
    -- The renderer supplies the same link on either row, and distinct adjacent links.
    for _, link in ipairs({ 'item:1', 'item:1', 'item:2' }) do
        bubble.scripts.OnHyperlinkEnter(bubble, link, '[Wrapped item]')
        bubble.scripts.OnHyperlinkClick(bubble, link, '[Wrapped item]', 'LeftButton')
        bubble.scripts.OnHyperlinkLeave(bubble)
        assert(shown[#shown] == link and shown.hidden, 'Tooltip used the wrong item')
        local click = opened[#opened]
        assert(click[1] == link and click[2] == '[Wrapped item]'
            and click[3] == 'LeftButton' and click[4] == bubble.chat)
    end
    bubble.msg = { secret = true }
    place(bubble, bubble.msg, 100)
    assert(not bubble.hyperlinks, 'Secret text still has hyperlink hit testing')
    bubble.scripts.OnHyperlinkEnter(bubble, 'item:3', '[Secret]')
    bubble.scripts.OnHyperlinkClick(bubble, 'item:3', '[Secret]', 'LeftButton')
    assert(#shown == 3 and #opened == 3, 'Secret message opened a link')
    bubble.msg = { text = 'reused bubble' }
    place(bubble, bubble.msg, 200)
    assert(bubble.hyperlinks, 'Reused bubble did not restore hyperlink hit testing')
    bind(frame()) -- Older clients may lack the method.
    GameTooltip, SetItemRef = oldTooltip, oldRef
end)

test('Always show debuffs defaults on and survives saves, presets and reset', function()
    local ns = namespace()
    ns.BAR_ROWS = {}
    loadAddon('Presets.lua', ns)
    loadAddon('Setup.lua', ns)
    local read = upvalue(upvalue(ns.ShowSetup, 'LoadSavedDraft'), 'ReadDraft')
    local saved = upvalue(upvalue(upvalue(ns.ShowSetup, 'CreateSetup'), 'Write'), 'DraftSettings')
    local draft = upvalue(read, 'draft')
    assert(ns.AlwaysShowDebuffs(), 'Missing setting must default on')
    read()
    assert(draft.alwaysShowDebuffs)
    draft.alwaysShowDebuffs = false
    ns.ActivatePreset(nil, saved())
    assert(QuietUICharDB.alwaysShowDebuffs == false and not ns.AlwaysShowDebuffs())
    local id = assert(ns.SavePreset(nil, 'Debuffs fade', {}, saved()))
    ns.ActivatePreset(id)
    assert(not ns.AlwaysShowDebuffs(), 'Preset did not retain opt-out')
    ns.DeletePreset(id)
    assert(not ns.AlwaysShowDebuffs(), 'Deleting preset lost personal snapshot')
    read({})
    ns.ActivatePreset(nil, saved())
    assert(ns.AlwaysShowDebuffs() and QuietUICharDB.alwaysShowDebuffs == nil,
        'Reset must restore default without storing an explicit true')
    read({ alwaysShowDebuffs = false })
    draft.alwaysShowDebuffs = true
    ns.ActivatePreset(nil, saved())
    assert(ns.AlwaysShowDebuffs(), 'Re-enabling did not clear opt-out')
end)

test('Debuffs stay visible alone and opt-out restores aura fading and alpha', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    local update = upvalue(ns.UpdateSmooth, 'UpdateAuras')
    BuffFrame, DebuffFrame, TemporaryEnchantFrame = frame(UIParent), frame(UIParent), frame(UIParent)
    DebuffFrame.alpha = 0.8
    ns.PlayerStyle = function() return 'resource' end
    ns.GroupAuras = function() return false end
    ns.FindFaders(false)
    update(1)
    assert(DebuffFrame.alpha == 1, 'Default did not show debuffs with player frame off')
    assert(BuffFrame.alpha == 0 and TemporaryEnchantFrame.alpha == 0, 'Debuffs revealed buffs')
    DebuffFrame:SetAlpha(0)
    assert(DebuffFrame.alpha == 1, 'Blizzard alpha overwrite was not held')
    QuietUICharDB.alwaysShowDebuffs = false
    update(0.15)
    assert(DebuffFrame.alpha > 0 and DebuffFrame.alpha < 1, 'Opt-out did not fade smoothly')
    update(1)
    assert(DebuffFrame.alpha == 0)
    ns.InCombat = function() return true end
    update(1)
    assert(DebuffFrame.alpha == 1 and BuffFrame.alpha == 1, 'Opt-out broke normal combat visibility')
    QuietUICharDB.alwaysShowDebuffs = nil
    ns.RestoreAlpha()
    QuietUIDB.enabled = false
    assert(DebuffFrame.alpha == 0.8, 'Disable did not restore original alpha')
    DebuffFrame:SetAlpha(0.4)
    assert(DebuffFrame.alpha == 0.4, 'Disabled addon still held debuff alpha')
    BuffFrame, DebuffFrame, TemporaryEnchantFrame = nil, nil, nil
end)

test('Always visible debuffs override the shared power alpha curve', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    local update = upvalue(ns.UpdateSmooth, 'UpdateAuras')
    for i = 1, 100 do
        local name = debug.getupvalue(update, i)
        if name == 'RestingPower' then debug.setupvalue(update, i, function() return 0 end) end
        if name == 'EvalPlayerThresholds' then debug.setupvalue(update, i, function() return 0.25 end) end
        if not name then break end
    end
    BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
    ns.FindFaders(false)
    update(1)
    assert(BuffFrame.alpha == 0.25 and DebuffFrame.alpha == 1)
    QuietUICharDB.alwaysShowDebuffs = false
    update(1)
    assert(DebuffFrame.alpha == 0.25, 'Opt-out did not rejoin the power curve')
    BuffFrame, DebuffFrame = nil, nil
end)

test('Damage meter follows combat, instance, group, edit mode and grace only', function()
    local ns = namespace()
    loadAddon('Faders.lua', ns)
    DamageMeter = frame(UIParent)
    ns.FindFaders(false)
    ns.Hit = function() return true end
    ns.NextFadeTick()
    ns.ShowAll = function() return true end -- flyout or cursor item
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 0, 'Hover or bar showAll revealed meter')
    ns.InGroup = function() return true end
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 1, 'Group did not reveal meter')
    ns.InGroup = function() return false end
    ns.MarkCombatEnd()
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 1, 'Post-combat grace missing')
    GetTime = function() return 111 end
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 0, 'Post-combat grace did not expire')
    DamageMeter = nil
end)

test('Range ignores always-visible groups, keeps forced suppression and detaches', function()
    local ns = namespace()
    loadAddon('Faders.lua', ns)
    ns.Range = function() return 'spell', 'hostile', 'Test' end
    UnitExists = function() return true end
    UnitIsDeadOrGhost = function() return false end
    local distanceReads = 0
    C_Spell = { IsSpellInRange = function() distanceReads = distanceReads + 1; return true end }
    ns.AnyBarsAlwaysVisible = function() return true end
    local plate, health = frame(UIParent), frame()
    plate.UnitFrame = { healthBar = health, IsShown = function() return true end }
    local lookups = 0
    C_NamePlate = { GetNamePlateForUnit = function() lookups = lookups + 1; return plate end }
    local mark
    CreateFrame = function() mark = frame(UIParent); return mark end
    ns.UpdateRange(0.1)
    assert(mark and mark.shown and mark.parent == health and mark.alpha == 1,
        'Always-visible bars must not block the range indicator')
    local reads = distanceReads
    ns.ShowAll = function() return true end
    ns.UpdateRange(0.3)
    assert(not mark.shown and distanceReads == reads, 'Forced visibility must hide range without reading distance')
    ns.ShowAll = function() return false end
    ns.UpdateRange(0.1)
    assert(mark.shown, 'Range did not return after forced visibility ended')
    ns.Glancing = function() return true end
    reads = distanceReads
    ns.UpdateRange(0.3)
    assert(not mark.shown and distanceReads == reads, 'Glance must hide range without reading distance')
    ns.Glancing = function() return false end
    ns.UpdateRange(0.1)
    assert(mark.shown, 'Range did not return after Glance ended')
    ns.Range = function() end
    ns.UpdateRange(0.3)
    assert(not mark.shown and mark.parent == UIParent, 'Invisible gradient stayed on nameplate')
    local before = lookups
    for i = 1, 60 do ns.UpdateRange(1 / 60) end
    assert(lookups == before, 'Hidden gradient still scanned nameplate')
end)

test('Core texture traversal reads the region list once', function()
    local ns = namespace()
    local root = frame()
    for i = 1, 8 do
        local texture = frame(root)
        function texture:GetObjectType() return 'Texture' end
        root.regions[i] = texture
    end
    ns.HideTextures(root)
    assert(root.regionReads == 1, 'Region list reads: ' .. root.regionReads)
end)


test('Target death invalidates cached bars without pointer movement', function()
    local ns = namespace()
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    MainActionBar = frame(UIParent)
    MainActionBar.name = 'MainActionBar'
    CreateFrame = function() return frame(UIParent) end
    ns.Glancing = function() return false end
    ns.BagsShouldShow = function() return false end
    QuietUICharDB.friendly = { ['1'] = true }
    local dead = false
    UnitExists = function() return true end
    UnitIsFriend = function() return true end
    UnitCanAttack = function() return false end
    UnitIsDeadOrGhost = function() return dead end
    ns.RefreshWorld()
    ns.ConsumeHud()
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    assert(MainActionBar.alpha == 1, 'Living friendly target did not show its bar')
    dead = true
    ns.RefreshWorld()
    assert(ns.ConsumeHud(), 'Target death did not invalidate cached bar visibility')
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    assert(MainActionBar.alpha == 0, 'Dead friendly target kept its bar visible')
    MainActionBar = nil
end)

test('Show-all transitions recalculate bars even with a stationary pointer', function()
    local ns = namespace()
    local events
    CreateFrame = function() events = frame(); function events:RegisterEvent() end; return events end
    SlashCmdList = {}
    loadAddon('QuietUI.lua', ns)
    local update = events.scripts.OnUpdate
    for i = 1, 100 do
        local name = debug.getupvalue(update, i)
        if name == 'booted' then debug.setupvalue(update, i, true); break end
    end
    ns.BeginTick = function() end
    ns.FocusChanged = function() return false end
    ns.ConsumeHud = function() return false end
    ns.UpdateFaders = function() end
    ns.UpdateMenuButton = function() end
    ns.UpdateRange = function() end
    ns.UpdateSmooth = function() end
    ns.UpdateChat = function() end
    ns.ForgetCursor = function() end
    GetCursorPosition = function() return 0, 0 end
    SpellFlyout = nil
    local force, scans = false, 0
    ns.ShowAll = function() return force end
    ns.UpdateBars = function(_, _, rescan) if rescan then scans = scans + 1 end end
    update(events, 0.01)
    scans = 0
    force = true
    update(events, 0.01)
    assert(scans == 1, 'Entering edit mode did not recalculate bars')
    scans = 0
    force = false
    update(events, 0.01)
    assert(scans == 1, 'Leaving edit mode did not recalculate bars')
    QuietUIGlance('up')
    assert(not ns.Glancing(), 'Key-up toggled Glance')
    QuietUIGlance('down')
    assert(ns.Glancing(), 'Key-down did not toggle Glance')
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Second key-down did not clear Glance')
    SlashCmdList.QUIETUI('  GlAnCe  ')
    assert(ns.Glancing(), 'Slash command did not toggle Glance')
    assert(QuietUIDB.enabled, 'Glance command disabled the addon')
    scans = 0
    update(events, 0.01)
    assert(scans == 1, 'Glance command did not recalculate bars')
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Key binding did not clear command Glance')
    SlashCmdList.QUIETUI('glance')
    SlashCmdList.QUIETUI('glance')
    assert(not ns.Glancing(), 'Second Glance command did not clear Glance')
    QuietUIDB.enabled = false
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Glance toggled while addon was disabled')
    SlashCmdList.QUIETUI('glance')
    assert(not ns.Glancing(), 'Glance command toggled while addon was disabled')
    assert(not QuietUIDB.enabled, 'Glance command enabled the addon')
    QuietUIDB.enabled = true
    SlashCmdList.QUIETUI('glance')
    for _, name in ipairs({ 'HideQuestCatcher', 'HideRangeMark', 'HideBarCatchers',
        'ResetMenu', 'RestoreChat', 'RestoreAlpha' }) do
        ns[name] = function() end
    end
    ns.ForceQuietLayout = function() return false end
    SlashCmdList.QUIETUI('off')
    assert(not ns.Glancing(), 'Disabling the addon did not clear command Glance')
    assert(not QuietUIDB.enabled, 'Off command did not disable the addon')
end)

test('Group visibility overrides automatic triggers and keeps hover exceptions', function()
    local ns = namespace()
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    loadAddon('Setup.lua', ns)
    MainActionBar, MultiBarBottomLeft, SwingTimer = frame(UIParent), frame(UIParent), frame(UIParent)
    MainActionBar.name, MultiBarBottomLeft.name, SwingTimer.name = 'MainActionBar', 'MultiBarBottomLeft', 'SwingTimer'
    CreateFrame = function() return frame(UIParent) end
    ns.BagsShouldShow = function() return false end
    ns.Hit = function(obj) return obj.hot == true end
    ns.Glancing = function() return false end
    local explicit = false
    ns.XPForced = function() return explicit end
    QuietUICharDB.groups = { swing = 1 }
    QuietUICharDB.groupVisibility = { [1] = 'hover' }
    QuietUICharDB.friendly = { ['1'] = true }
    UnitExists = function() return true end
    UnitIsFriend = function() return true end
    UnitIsDeadOrGhost = function() return false end
    ns.RefreshWorld()
    local function tick(showAll)
        ns.NextFadeTick(); ns.UpdateBars(showAll, 1, true)
    end
    tick(true)
    assert(MainActionBar.alpha == 0 and MultiBarBottomLeft.alpha == 0 and SwingTimer.alpha == 0,
        'Combat/instance or target revealed a hover group')
    MultiBarBottomLeft.hot = true
    tick(true)
    assert(MainActionBar.alpha == 1 and MultiBarBottomLeft.alpha == 1 and SwingTimer.alpha == 1,
        'Hover did not reveal every group member')
    MultiBarBottomLeft.hot = false
    tick(true)
    assert(MainActionBar.alpha == 0)
    explicit = true; tick(false)
    assert(MainActionBar.alpha == 1, 'Edit/flyout/cursor exception failed')
    explicit = false
    ns.Glancing = function() return true end; tick(false)
    assert(MainActionBar.alpha == 1, 'Glance exception failed')
    ns.Glancing = function() return false end
    QuietUICharDB.groupVisibility[1] = 'always'; tick(false)
    assert(MainActionBar.alpha == 1 and SwingTimer.alpha == 1)
    QuietUICharDB.groupVisibility = nil; tick(false)
    assert(MainActionBar.alpha == 1 and MultiBarBottomLeft.alpha == 0,
        'Usual Enemy/Friend rule must show one bar only')
    ns.RestoreAlpha(); QuietUIDB.enabled = false
    assert(MultiBarBottomLeft.alpha == 1, 'Disable did not restore the bar alpha')
    MainActionBar, MultiBarBottomLeft, SwingTimer = nil, nil, nil
end)

test('Legacy pins split mixed groups without changing which bars stay up', function()
    local ns = namespace()
    loadAddon('Bars.lua', ns)
    loadAddon('Presets.lua', ns)
    loadAddon('Setup.lua', ns)
    local source = { visible = { bars = true, quests = true }, groups = { swing = 1 } }
    ns.MigrateVisibility(source)
    assert(source.visible.quests and not source.visible.bars and not source.visible.swing)
    QuietUICharDB = source
    assert(ns.GroupVisibility(ns.BarGroup('1')) == 'always')
    assert(not ns.GroupVisibility(ns.BarGroup('swing')), 'Migration pinned the unpinned swing timer')
    local oldGroup = source.groups['1']
    ns.MigrateVisibility(source)
    assert(source.groups['1'] == oldGroup, 'Migration must be idempotent')
    source = { visible = { swing = true }, groups = { swing = 1 } }
    ns.MigrateVisibility(source); QuietUICharDB = source
    assert(ns.GroupVisibility(ns.BarGroup('swing')) == 'always')
    assert(not ns.GroupVisibility(ns.BarGroup('1')), 'Migration pinned unpinned action bars')
    source.hoverOnly = { meter = true }
    local id = assert(ns.SavePreset(nil, 'Hover', {}, source))
    ns.ActivatePreset(id)
    assert(ns.OnlyOnHover('meter') and ns.GroupVisibility(ns.BarGroup('swing')) == 'always')
    ns.DeletePreset(id)
    assert(ns.OnlyOnHover('meter'), 'Deleting preset lost hover snapshot')
end)

test('Visible hover mode suppresses combat, grace, XP rewards and grouped auras', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    QuietUICharDB.hoverOnly = { xp = true, cooldowns = true, meter = true, auras = true }
    MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter = frame(UIParent), frame(UIParent), frame(UIParent)
    BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
    CreateFrame = function() return frame(UIParent) end
    ns.InCombat = function() return true end
    ns.InGroup = function() return true end
    ns.InForcedInstance = function() return true end
    ns.Hit = function(obj) return obj.hot == true end
    ns.FindFaders(false)
    ns.MarkCombatEnd(); ns.MarkQuestXP(100)
    local updateAuras = upvalue(ns.UpdateSmooth, 'UpdateAuras')
    local function tick()
        ns.NextFadeTick(); ns.UpdateFaders(1); updateAuras(1)
    end
    tick()
    for _, obj in ipairs({ MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter, BuffFrame, DebuffFrame }) do
        assert(obj.alpha == 0, 'Automatic rule overrode Only on hover')
        obj.hot = true
    end
    tick()
    assert(DebuffFrame.alpha == 1 and BuffFrame.alpha == 1 and DamageMeter.alpha == 1
        and EssentialCooldownViewer.alpha == 1 and MainStatusTrackingBarContainer.alpha == 1)
    for _, obj in ipairs({ MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter, BuffFrame, DebuffFrame }) do obj.hot = false end
    ns.Glancing = function() return true end
    tick(); assert(DamageMeter.alpha == 1 and DebuffFrame.alpha == 1)
    ns.Glancing = function() return false end
    ns.InEditMode = function() return true end
    tick(); assert(DamageMeter.alpha == 1 and BuffFrame.alpha == 1)
    ns.InEditMode = function() return false end
    tick(); assert(DamageMeter.alpha == 0 and DebuffFrame.alpha == 0)
    local catchers = upvalue(ns.HideHoverCatchers, 'hoverCatchers')
    local box = catchers.meter[1]
    assert(box.parent == UIParent and box.shown, 'Hover catcher followed faded parent')
    box.hot = true; tick(); assert(DamageMeter.alpha == 1, 'Container gap catcher did not reveal meter')
    ns.HideHoverCatchers(); assert(not box.shown)
    ns.RestoreAlpha(); assert(DamageMeter.alpha == 1)
    MainStatusTrackingBarContainer, EssentialCooldownViewer, DamageMeter, BuffFrame, DebuffFrame = nil, nil, nil, nil, nil
end)

test('Resource hover bypasses secret curves and restores both child and root alpha', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    QuietUICharDB.hoverOnly = { resource = true }
    ns.InCombat = function() return true end
    ns.Hit = function(obj) return obj.hot == true end
    PersonalResourceDisplayFrame = frame(UIParent)
    local root = PersonalResourceDisplayFrame
    local health, power = frame(root), frame(root)
    health.alpha, power.alpha = 0.6, 0.8
    root.HealthBarsContainer = health; root.children = { health, power }
    UnitPowerPercent = function() error('Hover mode read power') end
    UnitHealthPercent = function() error('Hover mode read health') end
    ns.FindFaders(false)
    local update = upvalue(ns.UpdateSmooth, 'UpdateResource')
    update(1)
    assert(root.alpha == 1 and health.alpha == 0 and power.alpha == 0)
    root.hot = true; update(0.01)
    assert(health.alpha == 1 and power.alpha == 1)
    root.hot = false; update(0.15)
    assert(health.alpha > 0 and health.alpha < 1 and power.alpha > 0 and power.alpha < 1)
    update(0.15); assert(health.alpha == 0 and power.alpha == 0)
    ns.Glancing = function() return true end
    update(0.01); assert(health.alpha == 1 and power.alpha == 1)
    ns.Glancing = function() return false end
    root.children = {}; root._quietKids = nil
    update(0.15); update(0.15)
    assert(root.alpha == 0, 'Childless resource root never finished fading')
    ns.RestoreAlpha()
    assert(root.alpha == 1 and health.alpha == 0.6 and power.alpha == 0.8)
    PersonalResourceDisplayFrame, UnitPowerPercent, UnitHealthPercent = nil, nil, nil
end)

test('XP defaults to hover and unchecking persists usual combat visibility', function()
    local ns = namespace()
    loadAddon('Bars.lua', ns)
    loadAddon('Presets.lua', ns)
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    local read = upvalue(upvalue(ns.ShowSetup, 'LoadSavedDraft'), 'ReadDraft')
    local saved = upvalue(upvalue(upvalue(ns.ShowSetup, 'CreateSetup'), 'Write'), 'DraftSettings')
    local draft = upvalue(read, 'draft')
    assert(ns.OnlyOnHover('xp') and not ns.OnlyOnHover('meter'))
    read({}); assert(draft.hoverOnly.xp and not draft.xp)
    draft.hoverOnly.xp = false
    ns.ActivatePreset(nil, saved())
    assert(QuietUICharDB.hoverOnly.xp == false and not ns.OnlyOnHover('xp'), 'Unchecking did not persist')
    read(); assert(not draft.hoverOnly.xp)
    local id = assert(ns.SavePreset(nil, 'Normal XP', {}, saved()))
    ns.ActivatePreset(id); assert(not ns.OnlyOnHover('xp'))
    MainStatusTrackingBarContainer = frame(UIParent)
    ns.FindFaders(false)
    ns.Hit = function() return false end
    local forced = true
    ns.ShowAll = function() return forced end
    ns.XPForced = function() return false end
    local function tick() ns.NextFadeTick(); ns.UpdateFaders(1) end
    tick(); assert(MainStatusTrackingBarContainer.alpha == 1, 'Usual rules did not show XP in combat/vehicle/instance')
    forced = false; tick(); assert(MainStatusTrackingBarContainer.alpha == 0)
    ns.MarkQuestXP(100); tick(); assert(MainStatusTrackingBarContainer.alpha == 1, 'Usual XP reward rule lost')
    ns.DeletePreset(id); assert(not ns.OnlyOnHover('xp'), 'Personal snapshot lost explicit false')
    ns.ActivatePreset(nil, {}); forced = true; tick()
    assert(ns.OnlyOnHover('xp') and MainStatusTrackingBarContainer.alpha == 0, 'Reset did not restore hover default')
    read({ visible = { xp = true } })
    assert(draft.xp and not draft.hoverOnly.xp, 'Existing Always visible XP choice was overwritten')
    ns.ActivatePreset(nil, saved()); tick(); assert(MainStatusTrackingBarContainer.alpha == 1)
    MainStatusTrackingBarContainer = nil
end)

test('Party autohide keeps combat, instance and explicit reveal priorities', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    PartyFrame = frame(UIParent)
    PartyFrame.alpha = 0.6
    CompactRaidFrameContainer = frame(PartyFrame)
    CompactRaidFrameContainer.alpha = 0.8
    PartyMemberFrame1 = frame(PartyFrame)
    PartyMemberFrame1.alpha = 0.7
    CompactPartyFrameContainer = frame(UIParent)
    CompactPartyFrameContainer.alpha = 0.9
    local catchers = {}
    CreateFrame = function()
        local box = frame(UIParent)
        function box:SetMouseMotionEnabled(value) self.motion = value end
        function box:SetMouseClickEnabled(value) self.clicks = value end
        catchers[#catchers + 1] = box
        return box
    end
    ns.Hit = function(obj) return obj and obj.hot == true end
    ns.FindFaders(false)
    ns.UpdateParty(1)
    assert(PartyFrame.alpha == 0.6 and not PartyFrame._quietAlphaHook,
        'Default settings must leave Blizzard alpha untouched')
    assert(#catchers == 0, 'Always visible needs no hover catcher')
    QuietUICharDB.autoHideParty = true
    ns.InGroup = function() return true end
    ns.HasTarget = function() return true end
    ns.UpdateParty(0.1)
    assert(PartyFrame.alpha > 0 and PartyFrame.alpha < 0.6, 'Hide must fade, not disappear immediately')
    ns.UpdateParty(0.3)
    assert(PartyFrame.alpha == 0 and CompactPartyFrameContainer.alpha == 0,
        'Group membership and target must not reveal party frames')
    assert(CompactRaidFrameContainer.alpha == 0.8 and PartyMemberFrame1.alpha == 0.7,
        'Nested frames must inherit their parent fade without being faded twice')
    assert(#catchers == 2 and catchers[1].parent == UIParent)
    for _, box in ipairs(catchers) do
        assert(box.motion and box.clicks == false, 'Hover catcher must not intercept clicks')
    end
    catchers[1].hot = true
    ns.UpdateParty(0)
    assert(PartyFrame.alpha == 1 and CompactPartyFrameContainer.alpha == 1,
        'Hover over a hidden block must reveal all members immediately')
    catchers[1].hot = false
    for _, trigger in ipairs({ 'InCombat', 'InForcedInstance', 'Glancing', 'InEditMode' }) do
        ns.UpdateParty(1)
        assert(PartyFrame.alpha == 0)
        ns[trigger] = function() return true end
        ns.UpdateParty(0)
        assert(PartyFrame.alpha == 1 and CompactPartyFrameContainer.alpha == 1, trigger .. ' must reveal immediately')
        ns[trigger] = function() return false end
    end
    ns.UpdateParty(1)
    PartyFrame:SetAlpha(1)
    assert(PartyFrame.alpha == 0, 'Blizzard writes must not override autohide')
    QuietUICharDB.autoHideParty = nil
    ns.UpdateParty(0)
    assert(PartyFrame.alpha == 0.6 and CompactPartyFrameContainer.alpha == 0.9,
        'Always visible must restore original alpha')
    for _, box in ipairs(catchers) do assert(not box.shown, 'Always visible must hide catchers') end
    PartyFrame:SetAlpha(0.75)
    assert(PartyFrame.alpha == 0.75, 'Always visible must release the alpha hook')
    QuietUICharDB.autoHideParty = true
    ns.UpdateParty(1)
    ns.HideHoverCatchers()
    QuietUIDB.enabled = false
    ns.UpdateParty(0)
    ns.RestoreAlpha()
    assert(PartyFrame.alpha == 0.75 and CompactPartyFrameContainer.alpha == 0.9,
        'Disable must restore alpha captured when autohide was re-enabled')
    for _, box in ipairs(catchers) do assert(not box.shown, 'Disable must hide catchers') end
    PartyFrame:SetAlpha(0.85)
    QuietUIDB.enabled = true
    ns.UpdateParty(1)
    QuietUICharDB.autoHideParty = nil
    ns.UpdateParty(0)
    assert(PartyFrame.alpha == 0.85, 'Re-enabling must capture changes made while the addon was off')
    PartyFrame, CompactRaidFrameContainer, CompactPartyFrameContainer, PartyMemberFrame1 = nil, nil, nil, nil
end)

test('Party frame discovery releases replaced roots and skips forbidden frames', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    QuietUICharDB.autoHideParty = true
    CreateFrame = function() return frame(UIParent) end
    ns.Hit = function() return false end
    PartyFrame = frame(UIParent)
    ns.FindFaders(false); ns.UpdateParty(1)
    local old = PartyFrame
    PartyFrame = frame(UIParent)
    PartyFrame.alpha = 0.7
    ns.FindFaders(false); ns.UpdateParty(1)
    assert(old.alpha == 1 and old._quietAlpha == nil, 'Replacing a container must release the old root')
    assert(PartyFrame.alpha == 0, 'Newly discovered frames must follow autohide')
    local container = frame(UIParent)
    PartyFrame.parent = container
    CompactPartyFrameContainer = container
    CompactRaidFrameContainer = frame(UIParent)
    function CompactRaidFrameContainer:IsForbidden() return true end
    function CompactRaidFrameContainer:IsShown() error('Forbidden frame accessed') end
    ns.FindFaders(false); ns.UpdateParty(1)
    assert(PartyFrame.alpha == 0.7 and PartyFrame._quietAlpha == nil, 'Newly nested frames must stop independent fading')
    assert(container.alpha == 0, 'The outer container must own the fade')
    local forbiddenReads = 0
    function container:IsForbidden() return true end
    function container:SetAlpha() forbiddenReads = forbiddenReads + 1; error('Forbidden alpha write') end
    ns.FindFaders(false)
    assert(forbiddenReads == 0, 'Formerly managed forbidden frames must be released without calling methods')
    ns.RestoreAlpha()
    assert(PartyFrame.alpha == 0.7, 'Disable must not overwrite a released child')
    PartyFrame, CompactPartyFrameContainer, CompactRaidFrameContainer = nil, nil, nil
end)

test('Party selection highlights and independent indicators fade with their block', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    QuietUICharDB.autoHideParty = true
    CreateFrame = function() return frame(UIParent) end
    ns.Hit = function() return false end
    PartyFrame = frame(UIParent)
    local unit = frame(PartyFrame)
    local highlight = frame(unit)
    highlight.alpha = 0.8
    unit.selectionHighlight = highlight
    unit.regions = { highlight }
    local ready = frame(unit)
    function ready:IsIgnoringParentAlpha() return true end
    local icon = frame(ready)
    function icon:IsIgnoringParentAlpha() return true end
    ready.regions = { icon }
    local health = frame(unit)
    health.alpha = 0.5
    unit.children = { ready, health }
    PartyFrame.children = { unit }
    ns.FindFaders(false)
    ns.UpdateParty(1)
    assert(PartyFrame.alpha == 0 and highlight.alpha == 0 and ready.alpha == 0 and icon.alpha == 0,
        'Independent selection and ready-check indicators must disappear with the container')
    assert(health.alpha == 0.5 and not health._quietAlphaHook, 'Ordinary children must inherit container alpha')
    highlight:SetAlpha(1)
    assert(highlight.alpha == 0, 'A Blizzard selection update must not reveal the hidden highlight')
    ns.Glancing = function() return true end
    ns.UpdateParty(0)
    assert(highlight.alpha == 1 and ready.alpha == 1 and icon.alpha == 1, 'Glance must restore independent indicators')
    ns.Glancing = function() return false end
    ns.UpdateParty(1)
    ns.InCombat = function() return true end
    ns.UpdateParty(0)
    assert(highlight.alpha == 1 and ready.alpha == 1, 'Combat must reveal independent indicators immediately')
    QuietUICharDB.autoHideParty = nil
    ns.UpdateParty(0)
    assert(highlight.alpha == 0.8 and highlight._quietAlpha == nil and icon.alpha == 1,
        'Always visible must restore the original indicator alpha')
    PartyFrame = nil
end)


test('Focus ignores unrelated windows but preserves tracked hover and fallback', function()
    local ns = namespace()
    local bar, window = frame(UIParent), frame(UIParent)
    local slot = frame(bar)
    local itemA, itemB = frame(window), frame(window)
    local focus = { itemA }
    GetMouseFoci = function() return focus end
    ns.Hit(bar)
    ns.FocusChanged()
    local scans = 0
    for i = 1, 600 do
        focus = { i % 2 == 0 and itemA or itemB }
        if ns.FocusChanged() then scans = scans + 1 end
    end
    assert(scans == 0, 'Unrelated hover triggered HUD rescans')
    focus = { slot }; assert(ns.FocusChanged() and ns.Hit(bar), 'Button did not reveal its bar')
    focus = { bar }; assert(not ns.FocusChanged(), 'Same bar hover caused another rescan')
    focus = { itemA }; assert(ns.FocusChanged() and not ns.Hit(bar), 'Leaving bar did not rescan')
    focus = { slot, itemA }; assert(ns.FocusChanged() and ns.Hit(bar), 'Multiple foci lost tracked hover')
    focus = {}; assert(ns.FocusChanged() and not ns.Hit(bar), 'Empty focus retained hover')
    GetMouseFoci = function() error('Unavailable') end
    function bar:IsMouseOver() return true end
    assert(ns.FocusChanged() == nil and ns.Hit(bar), 'Failed focus API lost fallback hover')
    GetMouseFoci, GetMouseFocus = nil, nil
    local fallback = namespace()
    assert(fallback.FocusChanged() == nil and fallback.Hit(bar), 'Missing focus API lost fallback')
    print('Unrelated hover, 600 focus changes: HUD rescans=' .. scans)
end)

test('Bar ancestry cache preserves nesting, reparenting, replacement and disable', function()
    local ns = namespace()
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    MainActionBar, MultiBarBottomLeft = frame(UIParent), frame(UIParent)
    MainActionBar.name, MultiBarBottomLeft.name = 'MainActionBar', 'MultiBarBottomLeft'
    CreateFrame = function() return frame(UIParent) end
    ns.BagsShouldShow = function() return false end
    ns.InEditMode = function() return false end
    ns.Hit = function() return false end
    local parentReads = 0
    for _, obj in ipairs({ MainActionBar, MultiBarBottomLeft, UIParent }) do
        function obj:GetParent() parentReads = parentReads + 1; return self.parent end
    end
    local function tick()
        ns.NextFadeTick()
        ns.UpdateBars(false, 1, true)
    end
    tick()
    parentReads = 0
    for _ = 1, 100 do tick() end
    assert(parentReads == 0, 'Stable bars repeated ancestor walks: ' .. parentReads)
    print('Stable bars, 100 rescans: parent reads=' .. parentReads)
    MultiBarBottomLeft:SetParent(MainActionBar)
    assert(ns.ConsumeHud(), 'Reparenting did not invalidate hover visibility')
    tick()
    assert(MainActionBar.alpha == 1 and MultiBarBottomLeft.alpha == 0,
        'Hosting bar must stay opaque so the child fades independently')
    MultiBarBottomLeft:SetParent(UIParent)
    tick()
    assert(MainActionBar.alpha == 0, 'Unnested bar retained cached hosting status')
    local old = MultiBarBottomLeft
    MultiBarBottomLeft = frame(UIParent); MultiBarBottomLeft.name = 'MultiBarBottomLeft'
    ns.ForgetBarButtons(); tick()
    assert(MultiBarBottomLeft.alpha == 0, 'Replacement bar was not discovered')
    ns.RestoreAlpha()
    assert(MainActionBar.alpha == 1 and MultiBarBottomLeft.alpha == 1 and old.alpha == 1,
        'Disable did not restore original alphas')
    MainActionBar, MultiBarBottomLeft = nil, nil
end)

os.exit(failures == 0 and 0 or 1)
