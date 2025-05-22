-- XP System Ranks
-- Shared file for rank definitions and functions
-- Created for JamieL25 on 2025-05-22

XPSystem = XPSystem or {}
XPSystem.Ranks = XPSystem.Ranks or {}

-- Define ranks (level = rank info)
XPSystem.Ranks.List = {
    [1] = {name = "Rookie", color = Color(150, 150, 150)},  
    [5] = {name = "Initiate", color = Color(100, 200, 100)},      
    [10] = {name = "Apprentice", color = Color(100, 200, 200)},    
    [15] = {name = "Challenger", color = Color(100, 100, 200)},   
    [20] = {name = "Specialist", color = Color(150, 100, 200)},   
    [25] = {name = "Veteran", color = Color(200, 100, 200)},
    [30] = {name = "Expert", color = Color(200, 100, 100)},
    [35] = {name = "Ace", color = Color(200, 150, 100)},
    [40] = {name = "Elite", color = Color(200, 200, 100)},
    [45] = {name = "Champion", color = Color(255, 165, 0)},
    [50] = {name = "Master", color = Color(255, 100, 0)},
    [55] = {name = "Grand Master", color = Color(255, 50, 50)},
    [60] = {name = "Virtuoso", color = Color(255, 0, 0)},
    [65] = {name = "Maverick", color = Color(200, 0, 100)},
    [70] = {name = "Heroic", color = Color(150, 0, 150)},
    [75] = {name = "Paragon", color = Color(100, 0, 200)},
    [80] = {name = "Ascendant", color = Color(50, 0, 255)},
    [85] = {name = "Sovereign", color = Color(0, 100, 255)},
    [90] = {name = "Immortal", color = Color(0, 200, 255)},
    [95] = {name = "Celestial", color = Color(0, 255, 200)},
    [100] = {name = "Divine", color = Color(255, 255, 255)}
}

-- Define prestige tiers
XPSystem.Prestiges = {
    [1] = {name = "P1", color = Color(205, 127, 50)},
    [2] = {name = "P2", color = Color(192, 192, 192)},
    [3] = {name = "P3", color = Color(255, 215, 0)},
    [4] = {name = "P4", color = Color(229, 228, 226)},
    [5] = {name = "P5", color = Color(185, 242, 255)},
    [6] = {name = "P6", color = Color(80, 220, 100)},
    [7] = {name = "P7", color = Color(224, 17, 95)},
    [8] = {name = "P8", color = Color(15, 82, 186)},
    [9] = {name = "P9", color = Color(53, 57, 53)},
    [10] = {name = "P10", color = Color(255, 255, 255)}
}

-- Get rank for a specific level - FIXED FUNCTION
function XPSystem.GetRankForLevel(level)
    local highestRank = nil
    local highestLevel = 0
    
    for rankLevel, rankInfo in pairs(XPSystem.Ranks.List) do
        if level >= rankLevel and rankLevel >= highestLevel then
            highestRank = rankInfo
            highestLevel = rankLevel
        end
    end
    
    -- Fallback to lowest rank if no matching rank found
    if not highestRank then
        highestRank = XPSystem.Ranks.List[1]
    end
    
    return highestRank
end

-- Get prestige info
function XPSystem.GetPrestigeInfo(prestige)
    if prestige <= 0 then
        return {name = "None", color = Color(150, 150, 150)}
    end
    
    return XPSystem.Prestiges[prestige] or {name = "Max", color = Color(255, 255, 255)}
end

-- Create fonts
if CLIENT then
    surface.CreateFont("XPSystem_Level", {
        font = "Roboto",
        size = 20,
        weight = 800,
        antialias = true
    })
    
    surface.CreateFont("XPSystem_Rank", {
        font = "Roboto",
        size = 16,
        weight = 600,
        antialias = true
    })
    
    surface.CreateFont("XPSystem_XP", {
        font = "Roboto",
        size = 14,
        weight = 400,
        antialias = true
    })
end

print("[XP System] Ranks module loaded with fixed rank calculation")