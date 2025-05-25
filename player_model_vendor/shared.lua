-- shared.lua for player_model_vendor
-- Fixed: 2025-05-11 20:15:24 by JamieL25

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Player Model Vendor"
ENT.Author = "JamieL25"
ENT.Category = "Jamie's NPCs"
ENT.Spawnable = true
ENT.AdminSpawnable = true

print("--- [NPC PlayerModelVendor SCRIPT] shared.lua loading (Owned Models Update) ---")

-- ========================================================================================
-- CONFIGURATION
-- ========================================================================================

-- Set this to false to disable console logging
player_model_vendor = player_model_vendor or {}
player_model_vendor.ENABLE_LOGGING = false

-- Function to get a display name from a model path (used by both server and client)
function player_model_vendor.GetNameFromModelPath(path)
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

    -- Specific common capitalizations (can be expanded)
    name = name:gsub("Female", "Female"):gsub("Male", "Male"):gsub("Citizen", "Citizen")
    name = name:gsub("Police", "Police"):gsub("Combine", "Combine"):gsub("Soldier", "Soldier")
    name = name:gsub("Pmc", "PMC"):gsub("Alyx", "Alyx"):gsub("Barney", "Barney")

    return string.Trim(name)
end

print("--- [NPC PlayerModelVendor SCRIPT] shared.lua finished loading (Owned Models Update) ---")