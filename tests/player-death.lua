-- Run from the addon directory: lua tests/player-death.lua
local failures, cases = 0, 0
local output = print
local unpack = table.unpack or unpack
local function test(name, run)
    cases = cases + 1
    local ok, err = pcall(run)
    print = output
    output((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns) assert(loadfile(file))('QuietUI', ns) end
local function secret(value)
    local function forbidden() error('Addon attempted arithmetic/comparison on a secret') end
    return setmetatable({ secret = true, value = value }, {
        __lt = forbidden, __le = forbidden, __add = forbidden, __sub = forbidden,
        __mul = forbidden, __div = forbidden,
    })
end
local function unwrap(value) return type(value) == 'table' and value.value or value end
local function frame(parent, alpha)
    local obj = { parent = parent, alpha = alpha or 1, children = {}, regions = {}, scripts = {}, ignoring = false }
    if parent then parent.children[#parent.children + 1] = obj end
    function obj:IsForbidden() return false end
    function obj:IsShown() return true end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:GetParent() return self.parent end
    function obj:SetParent(value) self.parent = value end
    function obj:GetChildren() return unpack(self.children) end
    function obj:GetRegions() return unpack(self.regions) end
    function obj:GetName() return self.name end
    function obj:GetWidth() return 100 end
    function obj:GetHeight() return 20 end
    function obj:GetFrameLevel() return 1 end
    function obj:SetIgnoreParentAlpha(value) self.ignoring = value end
    function obj:IsIgnoringParentAlpha() return self.ignoring end
    function obj:GetEffectiveAlpha()
        local own = unwrap(self.alpha)
        return own * ((not self.ignoring and self.parent) and self.parent:GetEffectiveAlpha() or 1)
    end
    function obj:SetScript(name, fn) self.scripts[name] = fn end
    function obj:RegisterEvent() end
    for _, method in ipairs({ 'Hide', 'Show' }) do
        obj[method] = function() error('Player/pet must be controlled through alpha only') end
    end
    for _, method in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel',
        'EnableMouse', 'SetMouseMotionEnabled', 'SetMouseClickEnabled', 'SetSize', 'SetFrameStrata',
        'SetClampedToScreen', 'SetMovable', 'RegisterForDrag', 'RegisterForClicks', 'SetTexture',
        'SetTexCoord', 'SetColorTexture' }) do obj[method] = function() end end
    function obj:CreateTexture() return frame(self) end
    return obj
end
local names = { 'PlayerFrame', 'PetFrame', 'BuffFrame', 'DebuffFrame', 'TemporaryEnchantFrame',
    'TargetFrame', 'PersonalResourceDisplayFrame', 'StatusTrackingBarManager',
    'EssentialCooldownViewer', 'DamageMeter', 'PartyFrame', 'ObjectiveTrackerFrame' }
local function environment(inherited, preset)
    local state = { life = 'alive', health = 1, power = 1, targetDead = false, reports = {} }
    QuietUIDB, QuietUICharDB = { enabled = true }, {}
    UIParent = frame()
    for _, name in ipairs(names) do _G[name] = frame(UIParent); _G[name].name = name end
    PlayerFrame.alpha, PetFrame.alpha, TargetFrame.alpha = 0.8, 0.6, 0.7
    if inherited then PetFrame = frame(PlayerFrame, 0.6) end
    PersonalResourceDisplayFrame.HealthBarsContainer = frame(PersonalResourceDisplayFrame)
    state.resourcePower = frame(PersonalResourceDisplayFrame)
    issecretvalue = function(value) return type(value) == 'table' and value.secret == true end
    Enum = { LuaCurveType = { Step = 1 } }
    C_CurveUtil = { CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType(kind) self.kind = kind end
        function curve:ClearPoints() self.points = {} end
        function curve:AddPoint(x, y)
            assert(not issecretvalue(x) and not issecretvalue(y), 'Curve coordinates must stay plain')
            self.points[#self.points + 1] = { x, y }
        end
        function curve:evaluate(x)
            local points = self.points
            for i = 2, #points do
                if x < points[i][1] then
                    if self.kind == Enum.LuaCurveType.Step then return secret(points[i - 1][2]) end
                    local a, b = points[i - 1], points[i]
                    return secret(a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]))
                end
            end
            return secret(points[#points][2])
        end
        return curve
    end }
    UnitHealthPercent = function(unit, _, curve) assert(unit == 'player'); return curve:evaluate(state.health) end
    UnitPowerPercent = function(unit, _, _, curve) assert(unit == 'player'); return curve:evaluate(state.power) end
    UnitPowerType = function() return 0, 'MANA' end
    UnitIsDead, UnitIsGhost = nil, nil
    UnitIsDeadOrGhost = function(unit)
        if unit == 'target' then return state.targetDead end
        assert(unit == 'player', 'Life API must read player or target')
        return state.life ~= 'alive'
    end
    hooksecurefunc = function(obj, method, hook)
        local original = obj[method]
        obj[method] = function(self, ...)
            local result = original(self, ...)
            hook(self, ...)
            return result
        end
    end
    GetTime = function() return 100 end
    CreateFrame = function(_, _, parent)
        local obj = frame(parent or UIParent)
        -- Catcher visibility is separate from the guarded portrait widgets.
        function obj:Hide() self.hidden = true end
        function obj:Show() self.hidden = false end
        return obj
    end
    local ns = {}
    loadAddon('Core.lua', ns)
    print = function(message) state.reports[#state.reports + 1] = message end
    for _, method in ipairs({ 'InEditMode', 'InCombat', 'InForcedInstance', 'InGroup', 'InVehicle',
        'HasTarget', 'Glancing', 'ShowAll', 'XPForced' }) do
        local key = method
        ns[key] = function() return state[key] == true end
    end
    ns.Hit = function(obj) return obj and obj.hot == true end
    loadAddon('Presets.lua', ns)
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    if preset then
        QuietUIDB.presets = { [1] = { name = 'Existing', interfaceStyle = 0,
            settings = { playerThresholdKind = 'health', playerThresholdPercent = 70 },
            layout = { name = 'Existing', layoutType = 1, interfaceStyle = 0 } } }
        QuietUICharDB.presetId = 1
        ns.Settings() -- Establish the existing personal snapshot before testing transitions.
    end
    ns.FindFaders(false)
    function state.tick(elapsed)
        ns.NextFadeTick()
        ns.UpdateSmooth(elapsed or 0.3)
        assert(state.allowReports or #state.reports == 0, 'Unexpected addon error: ' .. table.concat(state.reports, '; '))
    end
    function state.portrait(expected, message)
        assert(math.abs(unwrap(PlayerFrame.alpha) - expected) < 0.000001,
            (message or 'Portrait alpha') .. ': got ' .. tostring(unwrap(PlayerFrame.alpha)) .. ', expected ' .. expected)
    end
    return ns, state
end
local function serialize(value)
    if type(value) ~= 'table' then return tostring(value) end
    local parts = {}
    for k, v in pairs(value) do parts[#parts + 1] = tostring(k) .. '=' .. serialize(v) end
    table.sort(parts)
    return '{' .. table.concat(parts, ',') .. '}'
end

-- Acceptance 1, 2, 3: ordinary triggers cannot defeat either death state.
for _, life in ipairs({ 'dead', 'ghost' }) do
    test(life .. ' portrait fades in 0.3s despite every ordinary trigger', function()
        local _, s = environment()
        QuietUICharDB.playerThresholdPercent = false
        for _, trigger in ipairs({ 'InCombat', 'InForcedInstance', 'InGroup', 'InVehicle', 'HasTarget', 'hover' }) do
            s.life = 'alive'
            if trigger == 'hover' then PlayerFrame.hot = true else s[trigger] = true end
            s.tick(0); s.portrait(1)
            s.life = life
            s.tick(0.15); s.portrait(0.5, 'Death must start a gradual fade')
            PlayerFrame:SetAlpha(1); s.portrait(0.5, 'Blizzard overwrite must keep the fading alpha')
            s.tick(0.15); s.portrait(0)
            if trigger == 'hover' then PlayerFrame.hot = false else s[trigger] = false end
        end
    end)
end

test('Release to ghost keeps portrait hidden', function()
    local _, s = environment()
    s.InCombat = true; s.tick(0)
    s.life = 'dead'; s.tick(); s.portrait(0)
    s.life = 'ghost'; s.HasTarget = true; s.tick(); s.portrait(0)
end)

-- Acceptance 4: native secret threshold values must transition to numeric fading.
for _, kind in ipairs({ 'health', 'resource' }) do
    test(kind .. ' secret threshold fades on death and returns after revive', function()
        local _, s = environment()
        QuietUICharDB.playerThresholdKind = kind
        s.health, s.power = 0, 0.4
        s.tick(); s.portrait(1)
        assert(issecretvalue(PlayerFrame.alpha), 'Arrange a real secret alpha')
        s.life = 'dead'; s.tick(0.15); s.portrait(0.5, 'Secret alpha must fade rather than vanish')
        s.tick(0.15); s.portrait(0)
        s.life = 'ghost'; s.tick(); s.portrait(0)
        s.life = 'alive'; s.tick(0); s.portrait(1)
        assert(#s.reports == 0, 'Secret transition must not cause Lua errors')
    end)
end

-- Acceptance 5, 6, 7.
for _, life in ipairs({ 'dead', 'ghost' }) do
    test(life .. ' Glance immediately reveals and then fades the portrait', function()
        local _, s = environment()
        s.InCombat = true; s.tick()
        s.life = life; s.tick(); s.portrait(0)
        s.Glancing = true; s.tick(0); s.portrait(1)
        s.Glancing = false; s.tick(0.15); s.portrait(0.5)
        s.tick(0.15); s.portrait(0)
    end)
    test(life .. ' player off ignores Glance but Edit Mode bypasses it', function()
        local _, s = environment()
        QuietUICharDB.player = 'resource'
        s.life, s.Glancing = life, true; s.tick(); s.portrait(0)
        s.InEditMode = true; s.tick(0); s.portrait(1)
        s.InEditMode, s.Glancing = false, false
        s.tick(0.15); s.portrait(0.5); s.tick(0.15); s.portrait(0)
    end)
end

test('Dead-target Glance block and its threshold exception stay independent', function()
    local _, s = environment()
    QuietUICharDB.requireLivingTarget = true
    s.targetDead, s.life, s.Glancing = true, 'dead', true
    s.tick(); s.portrait(0)
    assert(unwrap(PetFrame.alpha) == 0 and TargetFrame.alpha == 0)
    s.health = 0.4; s.tick(); s.portrait(1)
    assert(unwrap(PetFrame.alpha) == 1 and TargetFrame.alpha == 0, 'Threshold only overrides player and pet')
    s.Glancing = false; s.tick(); s.portrait(0)
    assert(unwrap(PetFrame.alpha) == 1 and TargetFrame.alpha == 0, 'Death must not remove pet threshold override')
    QuietUICharDB.player = 'resource'; s.Glancing = true; s.tick(); s.portrait(0)
    assert(unwrap(PetFrame.alpha) == 0 and TargetFrame.alpha == 0)
    s.InEditMode = true; s.tick(0); s.portrait(1)
    assert(TargetFrame.alpha == 0.7, 'Edit Mode releases the target to its original alpha')
end)

for _, life in ipairs({ 'dead', 'ghost' }) do
    test(life .. ' Edit Mode reveals an enabled portrait then fades on exit', function()
        local _, s = environment()
        s.life, s.InCombat = life, true
        s.InEditMode = true; s.tick(0); s.portrait(1)
        s.InEditMode = false; s.tick(0.15); s.portrait(0.5)
        s.tick(0.15); s.portrait(0)
    end)
end

-- Acceptance 8.
test('Revive immediately restores active triggers but remains hidden without them', function()
    local _, s = environment()
    QuietUICharDB.playerThresholdPercent = false
    s.life, s.InCombat = 'dead', true; s.tick(); s.portrait(0)
    s.life = 'alive'; s.tick(0); s.portrait(1)
    s.life = 'ghost'; s.tick(); s.portrait(0)
    s.InCombat, s.life = false, 'alive'; s.tick(0); s.portrait(0)
end)

-- Acceptance 9: the rendered pet alpha matters when its parent is the portrait.
for _, inherited in ipairs({ false, true }) do
    test((inherited and 'Inherited' or 'Separate') .. ' pet and auras keep their original rules during death', function()
        local _, s = environment(inherited)
        QuietUICharDB.alwaysShowDebuffs = false
        for _, life in ipairs({ 'dead', 'ghost' }) do
            s.life, s.HasTarget = 'alive', true; s.tick()
            local pet = PetFrame:GetEffectiveAlpha()
            local buffs, debuffs = unwrap(BuffFrame.alpha), unwrap(DebuffFrame.alpha)
            local health, power = unwrap(PersonalResourceDisplayFrame.HealthBarsContainer.alpha), unwrap(s.resourcePower.alpha)
            s.life = life; s.tick()
            s.portrait(0)
            assert(PetFrame:GetEffectiveAlpha() == pet, 'Pet must not inherit portrait death fade')
            assert(unwrap(BuffFrame.alpha) == buffs and unwrap(DebuffFrame.alpha) == debuffs, 'Grouped auras must remain visible')
            assert(unwrap(PersonalResourceDisplayFrame.HealthBarsContainer.alpha) == health and unwrap(s.resourcePower.alpha) == power)
            s.life, s.HasTarget, s.health, s.power = 'alive', false, 0.4, 0.4; s.tick()
            local thresholdPet = PetFrame:GetEffectiveAlpha()
            s.life = life; s.tick(); s.portrait(0)
            assert(PetFrame:GetEffectiveAlpha() == thresholdPet and unwrap(BuffFrame.alpha) == 1 and unwrap(DebuffFrame.alpha) == 1,
                'Threshold keeps pet and auras visible while dead')
            assert(unwrap(PersonalResourceDisplayFrame.HealthBarsContainer.alpha) == 1 and unwrap(s.resourcePower.alpha) == 1,
                'Low health/power must still reveal the personal resource components')
            s.health, s.power = 1, 1; s.tick()
            assert(PetFrame:GetEffectiveAlpha() == 0 and unwrap(BuffFrame.alpha) == 0 and unwrap(DebuffFrame.alpha) == 0)
        end
        s.life, s.HasTarget = 'alive', true; s.tick(0); s.portrait(1)
    end)
end


test('Default debuffs stay visible even when death blocks only the portrait', function()
    local _, s = environment()
    for _, life in ipairs({ 'dead', 'ghost' }) do
        s.life = life; s.tick()
        assert(unwrap(DebuffFrame.alpha) == 1 and unwrap(BuffFrame.alpha) == 0)
    end
end)

-- Acceptance 10: evaluate the actual independent HUD update paths before and after death.
for _, trigger in ipairs({ 'quiet', 'InCombat', 'InForcedInstance', 'InGroup', 'hover' }) do
    test('Player death leaves other HUD unchanged during ' .. trigger, function()
        local ns, s = environment()
        loadAddon('Frames.lua', ns)
        loadAddon('Bars.lua', ns)
        -- Keep only world observation controlled by the harness; update implementations stay real.
        for _, method in ipairs({ 'InEditMode', 'InCombat', 'InForcedInstance', 'InGroup', 'InVehicle', 'HasTarget' }) do
            local key = method
            ns[key] = function() return s[key] == true end
        end
        ns.ShowAll = function() return s.InCombat or s.InForcedInstance or s.InVehicle or s.InEditMode or false end
        ns.XPForced = function() return false end
        loadAddon('Menu.lua', ns)
        loadAddon('Chat.lua', ns)
        MainActionBar, CharacterMicroButton = frame(UIParent), frame(UIParent)
        MainActionBar.name, CharacterMicroButton.name = 'MainActionBar', 'CharacterMicroButton'
        NUM_CHAT_WINDOWS = 1
        ChatFrame1 = frame(UIParent)
        ChatFrame1.messages = { 'Existing message' }
        ChatFrame1EditBox = frame(UIParent)
        ChatFrame1EditBox._quietEdit, ChatFrame1EditBox._quietWant = true, 1
        QuietUICharDB.autoHideParty = true
        ns.RefreshChrome()
        local bag
        for _, child in ipairs(UIParent.children) do
            if child.scripts.OnDragStart then bag = child end
        end
        assert(bag, 'Fixture must create the actual bag button')
        if trigger == 'hover' then
            MainActionBar.hot, CharacterMicroButton.hot, bag.hot = true, true, true
        elseif trigger ~= 'quiet' then s[trigger] = true end
        ns.RefreshWorld()
        local function hudTick()
            s.tick()
            ns.UpdateBars(ns.ShowAll(), 0.3, true)
            ns.UpdateFaders(0.3)
            ns.UpdateMenuButton(0.3)
            ns.UpdateChat(0.3)
        end
        hudTick()
        local tracked = { TargetFrame, MainActionBar, StatusTrackingBarManager, EssentialCooldownViewer,
            DamageMeter, PartyFrame, ObjectiveTrackerFrame, bag, CharacterMicroButton, ChatFrame1, ChatFrame1EditBox }
        local before = {}
        for i, obj in ipairs(tracked) do before[i] = obj:GetEffectiveAlpha() end
        local messages = serialize(ChatFrame1.messages)
        for _, life in ipairs({ 'dead', 'ghost' }) do
            s.life = life
            ns.RefreshWorld()
            hudTick()
            for i, obj in ipairs(tracked) do
                assert(obj:GetEffectiveAlpha() == before[i], 'Death changed HUD frame ' .. (obj.name or tostring(i)))
            end
            assert(serialize(ChatFrame1.messages) == messages, 'Death changed chat text/history')
        end
        assert(#s.reports == 0, 'HUD fixture must not mask failed update paths: ' .. table.concat(s.reports, '; '))
        MainActionBar, CharacterMicroButton, ChatFrame1, ChatFrame1EditBox = nil, nil, nil, nil
    end)
end

-- Acceptance 11: unsupported/error/secret life checks fail open.
for _, mode in ipairs({ 'missing', 'error', 'secret' }) do
    test('Life API ' .. mode .. ' preserves existing behaviour and reports errors once', function()
        local _, s = environment()
        s.InCombat, s.allowReports = true, mode == 'error'
        if mode == 'missing' then UnitIsDeadOrGhost = nil
        elseif mode == 'error' then UnitIsDeadOrGhost = function() error('life unavailable') end
        else UnitIsDeadOrGhost = function() return secret(true) end end
        for _ = 1, 3 do s.tick(); s.portrait(1) end
        assert(#s.reports <= 1, 'Same life API error must print at most once')
        if mode == 'error' then assert(#s.reports == 1, 'Life API failure must be reported once')
        else assert(#s.reports == 0, 'Unsupported/secret life state must not produce an error') end
    end)
end

-- Acceptance 12: use ApplyAll's actual disabled lifecycle, including pet alpha inheritance.
for _, life in ipairs({ 'dead', 'ghost' }) do
    test('Disable while ' .. life .. ' restores alpha and pet inheritance, then reenable works', function()
        local ns, s = environment(true)
        local ignoring = PetFrame:IsIgnoringParentAlpha()
        s.life, s.InCombat = life, true; s.tick()
        for _, method in ipairs({ 'HideBarCatchers', 'ResetMenu', 'RestoreChat' }) do ns[method] = function() end end
        SlashCmdList = {}
        loadAddon('QuietUI.lua', ns)
        QuietUIDB.enabled = false
        ns.ApplyAll()
        assert(PlayerFrame.alpha == 0.8 and PetFrame.alpha == 0.6 and TargetFrame.alpha == 0.7,
            'Disable must restore all original alpha baselines')
        assert(PetFrame:IsIgnoringParentAlpha() == ignoring, 'Disable must restore the pet inheritance flag')
        for _, name in ipairs(names) do
            if name ~= 'PlayerFrame' and name ~= 'PetFrame' and name ~= 'TargetFrame' then
                assert(_G[name].alpha == 1, 'Disable must restore ' .. name)
            end
        end
        PlayerFrame:SetAlpha(0.9)
        assert(PlayerFrame.alpha == 0.9, 'Disabled hook must leave Blizzard in control')
        QuietUIDB.enabled, s.life = true, 'alive'; s.tick(0); s.portrait(1)
    end)
end

-- Acceptance 13: no new field or preset mutation from automatic visibility.
for _, preset in ipairs({ false, true }) do
    test((preset and 'Existing preset' or 'Personal settings') .. ' uses death rule without saved-data changes', function()
        local _, s = environment(false, preset)
        local before = serialize({ QuietUIDB, QuietUICharDB })
        s.InCombat = true; s.tick()
        for _, life in ipairs({ 'dead', 'ghost' }) do s.life = life; s.tick(); s.portrait(0) end
        s.Glancing = true; s.tick(0); s.portrait(1)
        s.Glancing, s.life = false, 'alive'; s.tick(0); s.portrait(1)
        assert(serialize({ QuietUIDB, QuietUICharDB }) == before, 'Death visibility must not write settings or migrate presets')
    end)
end

output(string.format('%d cases, %d failures', cases, failures))
if failures > 0 then os.exit(1) end
