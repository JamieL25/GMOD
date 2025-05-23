-- XP System Admin Functions
-- Server-side file for admin commands and settings
-- Created for JamieL25 on 2025-05-21
-- Updated with reward fix on 2025-05-22
-- Fixed reward saving on 2025-05-22 23:11:13 by JamieL25

XPSystem = XPSystem or {}

-- Save config to file
function XPSystem.SaveConfig()
    -- Create directory if it doesn't exist
    if not file.Exists("xp_system", "DATA") then
        file.CreateDir("xp_system")
    end
    
    -- Only save parts of the config that should be persistent
    local configToSave = {
        MaxLevel = XPSystem.Config.MaxLevel,
        MaxPrestige = XPSystem.Config.MaxPrestige,
        BaseXP = XPSystem.Config.BaseXP,
        XPMultiplier = XPSystem.Config.XPMultiplier,
        RankBoosts = XPSystem.Config.RankBoosts,
        LevelRewards = XPSystem.Config.LevelRewards,
        PrestigeRewards = XPSystem.Config.PrestigeRewards,
        HUD = XPSystem.Config.HUD
    }
    
    -- Save to file
    file.Write("xp_system/config.txt", util.TableToJSON(configToSave, true))
    
    -- Debug message
    print("[XP System] Config saved to file")
    
    -- If MySQL is available, also save to database
    if XPSystem.MySQL and XPSystem.MySQL.Connected then
        if XPSystem.SaveConfigToDB then
            XPSystem.SaveConfigToDB()
            print("[XP System] Config also saved to MySQL database")
        end
    end
end

-- Load config from file
function XPSystem.LoadConfig()
    local filename = "xp_system/config.txt"
    if file.Exists(filename, "DATA") then
        local data = util.JSONToTable(file.Read(filename, "DATA"))
        if data then
            -- Apply loaded settings to config
            XPSystem.Config.MaxLevel = data.MaxLevel or XPSystem.Config.MaxLevel
            XPSystem.Config.MaxPrestige = data.MaxPrestige or XPSystem.Config.MaxPrestige
            XPSystem.Config.BaseXP = data.BaseXP or XPSystem.Config.BaseXP
            XPSystem.Config.XPMultiplier = data.XPMultiplier or XPSystem.Config.XPMultiplier
            XPSystem.Config.RankBoosts = data.RankBoosts or XPSystem.Config.RankBoosts
            XPSystem.Config.LevelRewards = data.LevelRewards or XPSystem.Config.LevelRewards
            XPSystem.Config.PrestigeRewards = data.PrestigeRewards or XPSystem.Config.PrestigeRewards
            
            -- HUD settings
            if data.HUD then
                XPSystem.Config.HUD.Width = data.HUD.Width or XPSystem.Config.HUD.Width
                XPSystem.Config.HUD.Height = data.HUD.Height or XPSystem.Config.HUD.Height
                XPSystem.Config.HUD.BottomMargin = data.HUD.BottomMargin or XPSystem.Config.HUD.BottomMargin
                XPSystem.Config.HUD.ShowAlways = data.HUD.ShowAlways or XPSystem.Config.HUD.ShowAlways
            end
            
            -- Debug message
            print("[XP System] Config loaded from file")
        end
    end
    
    -- If MySQL is available, try to load from there too
    if XPSystem.MySQL and XPSystem.MySQL.Connected and XPSystem.LoadConfigFromDB then
        timer.Simple(0.5, function()
            XPSystem.LoadConfigFromDB()
        end)
    end
end

-- Set XP boost for a rank
function XPSystem.SetRankBoost(rank, multiplier)
    if not rank or rank == "" then return false end
    if not multiplier or multiplier < 1 then multiplier = 1 end
    
    -- Update the multiplier
    XPSystem.Config.RankBoosts[rank] = multiplier
    
    -- Save the change to file
    XPSystem.SaveConfig()
    
    return true
end

-- Set general settings
function XPSystem.SetGeneralSettings(maxLevel, maxPrestige, baseXP, xpMultiplier)
    if maxLevel and maxLevel > 0 then
        XPSystem.Config.MaxLevel = maxLevel
    end
    
    if maxPrestige and maxPrestige > 0 then
        XPSystem.Config.MaxPrestige = maxPrestige
    end
    
    if baseXP and baseXP > 0 then
        XPSystem.Config.BaseXP = baseXP
    end
    
    if xpMultiplier and xpMultiplier > 1 then
        XPSystem.Config.XPMultiplier = xpMultiplier
    end
    
    -- Save the changes to file
    XPSystem.SaveConfig()
    
    return true
end

-- Set HUD settings
function XPSystem.SetHUDSettings(width, height, margin, showAlways)
    if width and width > 0 then
        XPSystem.Config.HUD.Width = width
    end
    
    if height and height > 0 then
        XPSystem.Config.HUD.Height = height
    end
    
    if margin and margin > 0 then
        XPSystem.Config.HUD.BottomMargin = margin
    end
    
    if showAlways ~= nil then
        XPSystem.Config.HUD.ShowAlways = showAlways
    end
    
    -- Save the changes to file
    XPSystem.SaveConfig()
    
    return true
end

-- NEW FUNCTION: Give rewards when admin sets player level
-- This processes rewards for each level that was skipped
function XPSystem.ProcessLevelRewards(ply, oldLevel, newLevel)
    -- Skip if levels are the same or going down in level
    if oldLevel >= newLevel then return end
    
    -- Process each level to check for rewards
    for level = oldLevel + 1, newLevel do
        -- Check if this level has a reward defined
        if XPSystem.Config and XPSystem.Config.LevelRewards and XPSystem.Config.LevelRewards[level] then
            -- Call the reward function
            if XPSystem.GiveRewardForLevel then
                XPSystem.GiveRewardForLevel(ply, level)
                
                -- Notify player
                ply:ChatPrint("[XP System] You received rewards for level " .. level)
            end
        end
    end
    
    -- Log that rewards were processed
    print("[XP System] Processed rewards for " .. ply:Nick() .. " from level " .. oldLevel .. " to " .. newLevel)
end

-- NEW FUNCTION: Process prestige rewards
function XPSystem.ProcessPrestigeRewards(ply, oldPrestige, newPrestige)
    -- Skip if prestige is the same or going down
    if oldPrestige >= newPrestige then return end
    
    -- Process each prestige level
    for prestige = oldPrestige + 1, newPrestige do
        -- Check if this prestige has a reward
        if XPSystem.Config and XPSystem.Config.PrestigeRewards and XPSystem.Config.PrestigeRewards[prestige] then
            -- Call the reward function
            if XPSystem.GivePrestigeReward then
                XPSystem.GivePrestigeReward(ply, prestige)
                
                -- Notify player
                ply:ChatPrint("[XP System] You received rewards for prestige " .. prestige)
            end
        end
    end
    
    -- Log
    print("[XP System] Processed prestige rewards for " .. ply:Nick() .. " from prestige " .. oldPrestige .. " to " .. newPrestige)
end

-- Network message handlers
net.Receive("XPSystem_AdminSetRankBoost", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local rank = net.ReadString()
    local multiplier = net.ReadFloat()
    
    if XPSystem.SetRankBoost(rank, multiplier) then
        ply:ChatPrint("[XP System] XP boost for rank '" .. rank .. "' updated to " .. multiplier .. "x")
    end
end)

net.Receive("XPSystem_AdminSetGeneralSettings", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local maxLevel = net.ReadInt(16)
    local maxPrestige = net.ReadInt(16)
    local baseXP = net.ReadInt(16)
    local xpMultiplier = net.ReadFloat()
    
    if XPSystem.SetGeneralSettings(maxLevel, maxPrestige, baseXP, xpMultiplier) then
        ply:ChatPrint("[XP System] General settings updated!")
        
        -- Broadcast the change to all players
        for _, p in pairs(player.GetAll()) do
            XPSystem.UpdatePlayerNetworkedVars(p)
        end
    end
end)

net.Receive("XPSystem_AdminSetHUDSettings", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local width = net.ReadInt(16)
    local height = net.ReadInt(16)
    local margin = net.ReadInt(16)
    local showAlways = net.ReadBool()
    
    if XPSystem.SetHUDSettings(width, height, margin, showAlways) then
        ply:ChatPrint("[XP System] HUD settings updated!")
    end
end)

-- NEW HANDLER: Hook into level setting
-- This will catch when an admin sets a player's level
net.Receive("XPSystem_AdminSetPlayerLevel", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local targetID = net.ReadInt(16)
    local newLevel = net.ReadInt(16)
    
    local target = Player(targetID)
    if IsValid(target) then
        local oldLevel = target:GetNWInt("XPSystem_Level", 1)
        
        -- Handle the actual level setting (assuming this is handled in your core file)
        if XPSystem.SetPlayerLevel then
            XPSystem.SetPlayerLevel(target, newLevel)
        else
            -- Fallback if the function doesn't exist
            target:SetNWInt("XPSystem_Level", newLevel)
            target:SetNWInt("XPSystem_XP", 0) -- Reset XP when setting level directly
        end
        
        -- Process rewards for the level change
        XPSystem.ProcessLevelRewards(target, oldLevel, newLevel)
        
        -- Send confirmation
        ply:ChatPrint("[XP System] Set " .. target:Nick() .. "'s level to " .. newLevel)
    end
end)

-- NEW HANDLER: Hook into prestige setting
-- This will catch when an admin sets a player's prestige
net.Receive("XPSystem_AdminSetPlayerPrestige", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local targetID = net.ReadInt(16)
    local newPrestige = net.ReadInt(16)
    
    local target = Player(targetID)
    if IsValid(target) then
        local oldPrestige = target:GetNWInt("XPSystem_Prestige", 0)
        
        -- Handle the actual prestige setting (assuming this is in your core file)
        if XPSystem.SetPlayerPrestige then
            XPSystem.SetPlayerPrestige(target, newPrestige)
        else
            -- Fallback if the function doesn't exist
            target:SetNWInt("XPSystem_Prestige", newPrestige)
        end
        
        -- Process rewards for the prestige change
        XPSystem.ProcessPrestigeRewards(target, oldPrestige, newPrestige)
        
        -- Send confirmation
        ply:ChatPrint("[XP System] Set " .. target:Nick() .. "'s prestige to " .. newPrestige)
    end
end)

-- HOOK INTO EXISTING LEVEL CHANGE EVENTS
-- This ensures our reward processing works with any other level setting method
hook.Add("XPSystem_PlayerLevelChanged", "XPSystem_ProcessRewards", function(ply, oldLevel, newLevel)
    XPSystem.ProcessLevelRewards(ply, oldLevel, newLevel)
end)

hook.Add("XPSystem_PlayerPrestigeChanged", "XPSystem_ProcessPrestigeRewards", function(ply, oldPrestige, newPrestige)
    XPSystem.ProcessPrestigeRewards(ply, oldPrestige, newPrestige)
end)

-- Load config when the addon starts
hook.Add("Initialize", "XPSystem_LoadConfig", function()
    timer.Simple(1, function()
        XPSystem.LoadConfig()
    end)
end)

-- Save config on server shutdown to ensure no data is lost
hook.Add("ShutDown", "XPSystem_SaveConfigOnShutdown", function()
    print("[XP System] Saving configuration before shutdown...")
    XPSystem.SaveConfig()
end)

-- Load config from MySQL when database is ready
hook.Add("XPSystem_MySQLReady", "XPSystem_LoadConfigAfterMySQL", function()
    timer.Simple(2, function()
        if XPSystem.LoadConfigFromDB then
            XPSystem.LoadConfigFromDB()
            print("[XP System] Loaded config from MySQL database")
        else
            print("[XP System] MySQL config loader not found, using file-based config")
        end
    end)
end)

print("[XP System] Admin module loaded with reward fix (updated 2025-05-22 23:11:13 by JamieL25)")