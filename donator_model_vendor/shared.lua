-- shared.lua for donator_vendor
-- Created: 2025-05-25 19:51:38 by JamieL25
-- Updated: 2025-05-25 20:26:44 by JamieL25

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Donator Model Vendor"
ENT.Author = "JamieL25"
ENT.Category = "Jamie's NPCs"
ENT.Spawnable = true
ENT.AdminSpawnable = true

print("--- [NPC DonatorModelVendor SCRIPT] shared.lua loading ---")

-- ========================================================================================
-- CONFIGURATION
-- ========================================================================================

-- Set this to false to disable console logging
donator_vendor = donator_vendor or {}
donator_vendor.ENABLE_LOGGING = true

-- Ranks configuration - Define access hierarchy
-- Make sure these names match your SAM ranks exactly
donator_vendor.Ranks = {
    ["VIP"] = {
        name = "VIP",
        can_access = {"VIP"}, -- Can only access VIP tab
        order = 1
    },
    ["VIP+"] = {
        name = "VIP+",
        can_access = {"VIP", "VIP+"}, -- Can access VIP and VIP+ tabs
        order = 2
    },
    ["Legend"] = {
        name = "Legend",
        can_access = {"VIP", "VIP+", "Legend"}, -- Can access all donator tabs
        order = 3
    }
}

-- Function to get a display name from a model path (used by both server and client)
function donator_vendor.GetNameFromModelPath(path)
    if not path or path == "" then return "Unknown Model" end
    local name = string.match(path, "([^/]+)%.mdl$")
    if not name then
        name = string.match(path, "([^/\\]+)$") -- Fallback if no .mdl extension
    end
    name = name or "Unknown Model"

    name = name:gsub("_", " ") -- Replace underscores with spaces

    -- Attempt to capitalize words nicely
    local words = {}
    for word in string.gmatch(name, "%S+") do
        table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2)))
    end
    name = table.concat(words, " ")

    -- Specific common capitalizations
    name = name:gsub("Female", "Female"):gsub("Male", "Male"):gsub("Citizen", "Citizen")
    name = name:gsub("Police", "Police"):gsub("Combine", "Combine"):gsub("Soldier", "Soldier")
    name = name:gsub("Pmc", "PMC"):gsub("Alyx", "Alyx"):gsub("Barney", "Barney")
    name = name:gsub("Vip", "VIP"):gsub("Legend", "Legend")

    return string.Trim(name)
end

print("--- [NPC DonatorModelVendor SCRIPT] shared.lua finished loading ---")