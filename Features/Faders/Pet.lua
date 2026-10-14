local _, ns = ...
local Faders = ns.Faders

local inheritedPets = {}

local petAnchor = setmetatable({}, { __mode = "k" })

local function WatchPetParent(pet)
    if pet._quietParentHook or type(pet.SetParent) ~= "function" or type(hooksecurefunc) ~= "function" then
        return pet._quietParentHook and true or false
    end
    local ok = pcall(hooksecurefunc, pet, "SetParent", function(self)
        petAnchor[self] = nil
    end)
    if ok then pet._quietParentHook = true end
    return pet._quietParentHook and true or false
end

function Faders.PetUnderPlayer(pet, player)
    if not ns.Usable(pet) or not player or type(pet.GetParent) ~= "function" then return false end
    local known = petAnchor[pet]
    if known and known.player == player then return known.under end
    local ok, parent = pcall(pet.GetParent, pet)
    if not ok then return false end
    local direct = parent == player or parent == UIParent or parent == nil
    local under = parent == player or (not direct and Faders.Under(pet, player)) or false
    -- Intermediate ancestors can move without the pet's SetParent hook firing.
    if direct and WatchPetParent(pet) then
        petAnchor[pet] = { player = player, under = under }
    end
    return under
end

function Faders.IsolatePet(pet, player, show)
    if inheritedPets[pet] then return inheritedPets[pet], true end
    if type(pet.IsIgnoringParentAlpha) ~= "function" then
        ns.Report("pet alpha inheritance", "Inheritance getter missing")
        return nil, false
    end
    local ok, ignoring = pcall(pet.IsIgnoringParentAlpha, pet)
    if not ok then ns.Report("pet alpha inheritance", ignoring); return nil, false end
    if ns.IsSecret(ignoring) then return nil, false end
    if ignoring then return nil, true end
    if type(pet.SetIgnoreParentAlpha) ~= "function" or type(pet.GetAlpha) ~= "function" then
        ns.Report("pet alpha inheritance", "Inheritance setter or alpha getter missing")
        return nil, false
    end
    local read, alpha = pcall(pet.GetAlpha, pet)
    if not read then ns.Report("pet alpha inheritance", alpha); return nil, false end
    if ns.IsSecret(alpha) then return nil, false end
    if type(alpha) ~= "number" then
        ns.Report("pet alpha inheritance", "Pet alpha unavailable")
        return nil, false
    end
    local weight = player._quietAlpha
    if type(weight) ~= "number" and type(player.GetAlpha) == "function" then
        local readPlayer, value = pcall(player.GetAlpha, player)
        if not readPlayer then ns.Report("player alpha", value)
        elseif not ns.IsSecret(value) then weight = value end
    end
    if ns.IsSecret(weight) or type(weight) ~= "number" then weight = show and 1 or 0 end
    local changed, err = pcall(pet.SetIgnoreParentAlpha, pet, true)
    if not changed then ns.Report("pet alpha inheritance", err); return nil, false end
    local saved = { ignoring = ignoring, alpha = alpha, weight = weight }
    inheritedPets[pet] = saved
    return saved, true
end

function Faders.RestorePets()
    for pet, saved in pairs(inheritedPets) do
        if ns.Usable(pet) and type(pet.SetIgnoreParentAlpha) == "function" then
            local ok, err = pcall(pet.SetIgnoreParentAlpha, pet, saved.ignoring)
            if not ok then ns.Report("restore pet inheritance", err) end
        end
        inheritedPets[pet] = nil
    end
end
