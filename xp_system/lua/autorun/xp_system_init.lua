-- XP System Server Loader
-- Server-side file to load the addon
-- Created for JamieL25 on 2025-05-21
-- Updated with MySQL support on 2025-05-22

if SERVER then
    -- Load shared files first
    AddCSLuaFile("xp_system/sh_config.lua")
    AddCSLuaFile("xp_system/sh_ranks.lua")
    include("xp_system/sh_config.lua")
    include("xp_system/sh_ranks.lua")
    
    -- Load MySQL module first
    include("xp_system/sv_mysql.lua")
    
    -- Then load other server files
    include("xp_system/sv_core.lua")
    include("xp_system/sv_rewards.lua")
    
    -- Send client files
    AddCSLuaFile("xp_system/cl_hud.lua")
    AddCSLuaFile("xp_system/cl_menu.lua")
end

if CLIENT then
    -- Load shared files
    include("xp_system/sh_config.lua")
    include("xp_system/sh_ranks.lua")
    
    -- Load client files
    include("xp_system/cl_hud.lua")
    include("xp_system/cl_menu.lua")
end

print("[XP System] Loader initialized")