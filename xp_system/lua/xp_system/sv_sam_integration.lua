-- XP System SAM Admin Integration
-- Server-side file for integration with SAM Admin mod
-- Created for JamieL25 on 2025-05-21

XPSystem = XPSystem or {}

-- Check if SAM is installed
local isSAMInstalled = sam ~= nil

-- Setup SAM integration if available
if isSAMInstalled then
    print("[XP System] SAM Admin detected - Setting up integration")
    
    -- Function to get player's rank from SAM
    function XPSystem.GetPlayerSAMRank(ply)
        if not IsValid(ply) then return nil end
        
        return sam.player.get_rank(ply)
    end
    
    -- Event hook for when a player's rank changes in SAM
    hook.Add("SAM.RankUpdated", "XPSystem_RankUpdate", function(ply, oldRank, newRank)
        if not IsValid(ply) then return end
        
        -- Check if the new rank has an XP boost
        local boost = XPSystem.Config.RankBoosts[newRank] or 1
        
        -- Notify player about XP boost
        if boost > 1 then
            local boostPercentage = math.floor((boost - 1) * 100)
            ply:ChatPrint("[XP System] Your new rank '" .. newRank .. "' gives you a +" .. boostPercentage .. "% XP boost!")
        end
    end)
    
    -- Add SAM commands
    if sam.command then
        sam.command.new("xp_add")
            :SetPermission("xp_admin")
            :SetCategory("XP System")
            :AddArg("player")
            :AddArg("number", {hint = "amount", min = 1, max = 100000})
            :Help("Add XP to a player")
            :OnExecute(function(ply, targets, amount)
                for i, target in ipairs(targets) do
                    XPSystem.AddXP(target, amount)
                    
                    if sam.is_command_silent then
                        sam.player.send_message(nil, "{A} gave {T} " .. amount .. " XP", {
                            A = ply, T = target
                        })
                    end
                end
            end)
        
        sam.command.new("xp_setlevel")
            :SetPermission("xp_admin")
            :SetCategory("XP System")
            :AddArg("player")
            :AddArg("number", {hint = "level", min = 1, max = XPSystem.Config.MaxLevel})
            :Help("Set a player's level")
            :OnExecute(function(ply, targets, level)
                for i, target in ipairs(targets) do
                    XPSystem.SetLevel(target, level)
                    
                    if sam.is_command_silent then
                        sam.player.send_message(nil, "{A} set {T}'s level to " .. level, {
                            A = ply, T = target
                        })
                    end
                end
            end)
        
        sam.command.new("xp_setprestige")
            :SetPermission("xp_admin")
            :SetCategory("XP System")
            :AddArg("player")
            :AddArg("number", {hint = "prestige", min = 0, max = XPSystem.Config.MaxPrestige})
            :Help("Set a player's prestige level")
            :OnExecute(function(ply, targets, prestige)
                for i, target in ipairs(targets) do
                    XPSystem.SetPrestige(target, prestige)
                    
                    if sam.is_command_silent then
                        sam.player.send_message(nil, "{A} set {T}'s prestige to " .. prestige, {
                            A = ply, T = target
                        })
                    end
                end
            end)
        
        sam.command.new("xp_reset")
            :SetPermission("xp_admin")
            :SetCategory("XP System")
            :AddArg("player")
            :Help("Reset a player's XP data")
            :OnExecute(function(ply, targets)
                for i, target in ipairs(targets) do
                    XPSystem.ResetPlayer(target)
                    
                    if sam.is_command_silent then
                        sam.player.send_message(nil, "{A} reset {T}'s XP data", {
                            A = ply, T = target
                        })
                    end
                end
            end)
        
        sam.command.new("xp_menu")
            :SetCategory("XP System")
            :Help("Open the XP System menu")
            :OnExecute(function(ply)
                if not IsValid(ply) then return end
                XPSystem.OpenMenu(ply)
            end)
    end
else
    print("[XP System] SAM Admin not detected - Integration disabled")
end