-- XP System Initialization
-- By Jamie's Request - Modern Rank & Prestige System

if SERVER then
    AddCSLuaFile("xp_system/sh_config.lua")
    AddCSLuaFile("xp_system/sh_ranks.lua")
    AddCSLuaFile("xp_system/cl_hud.lua")
    AddCSLuaFile("xp_system/cl_menu.lua")
    
    include("xp_system/sh_config.lua")
    include("xp_system/sh_ranks.lua")
    include("xp_system/sv_core.lua")
    include("xp_system/sv_rewards.lua")
    include("xp_system/sv_admin.lua")
    include("xp_system/sv_sam_integration.lua")
    
    print("[XP System] Server files initialized")
else
    include("xp_system/sh_config.lua")
    include("xp_system/sh_ranks.lua")
    include("xp_system/cl_hud.lua")
    include("xp_system/cl_menu.lua")
    
    print("[XP System] Client files initialized")
end