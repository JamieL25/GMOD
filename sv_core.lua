-- XP System Core Functionality
-- Server-side file for core XP system logic
-- Created for JamieL25 on 2025-05-21
-- Updated with MySQL support on 2025-05-22
-- Fixed rewards saving issue on 2025-05-22 23:11:13 by JamieL25

XPSystem = XPSystem or {}
XPSystem.PlayerData = XPSystem.PlayerData or {}

-- Create network strings
util.AddNetworkString("XPSystem_GainXP")
util.AddNetworkString("XPSystem_LevelUp")
util.AddNetworkString("XPSystem_Prestige")
util.AddNetworkString("XPSystem_OpenMenu")
util.AddNetworkString("XPSystem_OpenAdminMenu")
util.AddNetworkString("XPSystem_PrestigeRequest")
util.AddNetworkString("XPSystem_AdminAddXP")
util.AddNetworkString("XPSystem_AdminSetLevel")
util.AddNetworkString("XPSystem_AdminSetPrestige")
util.AddNetworkString("XPSystem_AdminResetPlayer")
util.AddNetworkString("XPSystem_AdminSetLevelReward")
util.AddNetworkString("XPSystem_AdminSetPrestigeReward")
util.AddNetworkString("XPSystem_AdminSetRankBoost")
util.AddNetworkString("XPSystem_AdminSetGeneralSettings")
util.AddNetworkString("XPSystem_AdminSetHUDSettings")
util.AddNetworkString("XPSystem_ConfigUpdate")

-- Default settings that will be saved/loaded
XPSystem.DefaultData = {
    level = 1,
    xp = 0,
    totalXP = 0,
    prestige = 0
}

-- Load player data from MySQL
function XPSystem.LoadPlayer(ply)
    if not IsValid(ply) then return end
    
    -- Create unique identifier for this player
    local steamID = ply:SteamID64()
    
    -- Initialize player data table with defaults
    XPSystem.PlayerData[steamID] = table.Copy(XPSystem.DefaultData)
    
    -- Query database for player data
    local query = "SELECT * FROM xp_players WHERE steam_id = " .. XPSystem.MySQL.Escape(steamID)
    
    XPSystem.MySQL.Query(query, function(data)
        if data and data[1] then
            -- Player found in database, use stored data
            XPSystem.PlayerData[steamID] = {
                level = tonumber(data[1].level),
                xp = tonumber(data[1].xp),
                totalXP = tonumber(data[1].total_xp),
                prestige = tonumber(data[1].prestige)
            }
            
            print("[XP System] Loaded player data from MySQL for " .. ply:Nick())
        else
            -- Player not found, create new record
            local insertQuery = string.format(
                "INSERT INTO xp_players (steam_id, level, xp, total_xp, prestige) VALUES (%s, %d, %d, %d, %d)",
                XPSystem.MySQL.Escape(steamID),
                XPSystem.DefaultData.level,
                XPSystem.DefaultData.xp,
                XPSystem.DefaultData.totalXP,
                XPSystem.DefaultData.prestige
            )
            
            XPSystem.MySQL.Query(insertQuery, function()
                print("[XP System] Created new player record in MySQL for " .. ply:Nick())
            end)
        end
        
        -- Update networked variables
        XPSystem.UpdatePlayerNetworkedVars(ply)
    end)
end

-- Save player data to MySQL
function XPSystem.SavePlayer(ply)
    if not IsValid(ply) then return end
    
    -- Get player ID
    local steamID = ply:SteamID64()
    
    -- Ensure we have data to save
    if not XPSystem.PlayerData[steamID] then return end
    
    -- Get player data
    local data = XPSystem.PlayerData[steamID]
    
    -- Update database record
    local query = string.format(
        "INSERT INTO xp_players (steam_id, level, xp, total_xp, prestige) VALUES (%s, %d, %d, %d, %d) " ..
        "ON DUPLICATE KEY UPDATE level = %d, xp = %d, total_xp = %d, prestige = %d",
        XPSystem.MySQL.Escape(steamID),
        data.level, data.xp, data.totalXP, data.prestige,
        data.level, data.xp, data.totalXP, data.prestige
    )
    
    XPSystem.MySQL.Query(query, function()
        -- Debug message
        print("[XP System] Saved player data to MySQL for " .. ply:Nick())
    end)
end

-- Update player networked variables
function XPSystem.UpdatePlayerNetworkedVars(ply)
    if not IsValid(ply) then return end
    
    -- Get player data
    local steamID = ply:SteamID64()
    local data = XPSystem.PlayerData[steamID]
    
    if not data then return end
    
    -- Set networked variables
    ply:SetNWInt("XPSystem_Level", data.level)
    ply:SetNWInt("XPSystem_XP", data.xp)
    ply:SetNWInt("XPSystem_TotalXP", data.totalXP)
    ply:SetNWInt("XPSystem_Prestige", data.prestige)
    
    -- Calculate max XP needed for current level
    local maxXP = XPSystem.GetXPForLevel(data.level)
    ply:SetNWInt("XPSystem_MaxXP", maxXP)
end

-- Get XP required for a level
function XPSystem.GetXPForLevel(level)
    -- Base XP required for level 1
    local baseXP = XPSystem.Config.BaseXP
    
    -- If level is 1, return base XP
    if level <= 1 then return baseXP end
    
    -- Calculate XP required with multiplier for higher levels
    local multiplier = XPSystem.Config.XPMultiplier
    return math.floor(baseXP * (multiplier ^ (level - 1)))
end

-- Add XP to player
function XPSystem.AddXP(ply, amount)
    if not IsValid(ply) then return end
    if amount <= 0 then return end
    
    -- Get player data
    local steamID = ply:SteamID64()
    local data = XPSystem.PlayerData[steamID]
    
    if not data then return end
    
    -- Apply XP boost based on donation rank from SAM
    local originalAmount = amount
    local boostMultiplier = XPSystem.GetPlayerBoostMultiplier(ply)
    amount = math.floor(amount * boostMultiplier)
    
    -- Add XP
    data.xp = data.xp + amount
    data.totalXP = data.totalXP + amount
    
    -- Check if should level up
    local leveledUp = false
    local maxXP = XPSystem.GetXPForLevel(data.level)
    
    while data.xp >= maxXP and data.level < XPSystem.Config.MaxLevel do
        data.xp = data.xp - maxXP
        data.level = data.level + 1
        leveledUp = true
        
        -- Get new max XP for next level
        maxXP = XPSystem.GetXPForLevel(data.level)
        
        -- Check for level rewards
        XPSystem.CheckLevelRewards(ply, data.level)
    end
    
    -- Update networked vars
    XPSystem.UpdatePlayerNetworkedVars(ply)
    
    -- Save player data
    XPSystem.SavePlayer(ply)
    
    -- Send XP gain notification to client
    net.Start("XPSystem_GainXP")
    net.WriteInt(amount, 32)
    net.WriteInt(data.level, 16)
    net.WriteInt(data.xp, 32)
    net.WriteInt(maxXP, 32)
    net.Send(ply)
    
    -- Return if the player leveled up
    return leveledUp
end

-- Get player's XP boost multiplier based on rank (FIXED FUNCTION)
function XPSystem.GetPlayerBoostMultiplier(ply)
    if not IsValid(ply) then return 1 end
    
    -- Check if SAM is installed
    if not sam then return 1 end
    
    -- Make sure we have a valid SteamID
    local steamID = ply:SteamID()
    if not steamID or not sam.is_steamid(steamID) then
        return 1 -- Return default multiplier if no valid SteamID
    end
    
    -- Try to get player's rank safely
    local success, rank = pcall(function()
        return sam.player.get_rank(ply)
    end)
    
    if not success or not rank then
        return 1 -- Return default multiplier if there's an error
    end
    
    -- Check if rank has a boost
    return XPSystem.Config.RankBoosts[rank] or 1
end

-- Set player level
function XPSystem.SetLevel(ply, level)
    if not IsValid(ply) then return end
    if level < 1 then level = 1 end
    if level > XPSystem.Config.MaxLevel then level = XPSystem.Config.MaxLevel end
    
    -- Get player data
    local steamID = ply:SteamID64()
    local data = XPSystem.PlayerData[steamID]
    
    if not data then return end
    
    -- Set level and reset XP
    data.level = level
    data.xp = 0
    
    -- Update networked vars
    XPSystem.UpdatePlayerNetworkedVars(ply)
    
    -- Save player data
    XPSystem.SavePlayer(ply)
end

-- Set player prestige
function XPSystem.SetPrestige(ply, prestige)
    if not IsValid(ply) then return end
    if prestige < 0 then prestige = 0 end
    if prestige > XPSystem.Config.MaxPrestige then prestige = XPSystem.Config.MaxPrestige end
    
    -- Get player data
    local steamID = ply:SteamID64()
    local data = XPSystem.PlayerData[steamID]
    
    if not data then return end
    
    -- Set prestige
    data.prestige = prestige
    
    -- Update networked vars
    XPSystem.UpdatePlayerNetworkedVars(ply)
    
    -- Save player data
    XPSystem.SavePlayer(ply)
end

-- Reset player data
function XPSystem.ResetPlayer(ply)
    if not IsValid(ply) then return end
    
    -- Get player ID
    local steamID = ply:SteamID64()
    
    -- Reset to default data
    XPSystem.PlayerData[steamID] = table.Copy(XPSystem.DefaultData)
    
    -- Update networked vars
    XPSystem.UpdatePlayerNetworkedVars(ply)
    
    -- Save player data
    XPSystem.SavePlayer(ply)
end

-- Prestige player
function XPSystem.PrestigePlayer(ply)
    if not IsValid(ply) then return end
    
    -- Get player data
    local steamID = ply:SteamID64()
    local data = XPSystem.PlayerData[steamID]
    
    if not data then return end
    
    -- Check if they can prestige
    if data.level < XPSystem.Config.MaxLevel then
        ply:ChatPrint("[XP System] You need to reach level " .. XPSystem.Config.MaxLevel .. " to prestige!")
        return false
    end
    
    if data.prestige >= XPSystem.Config.MaxPrestige then
        ply:ChatPrint("[XP System] You have already reached the maximum prestige level!")
        return false
    end
    
    -- Increase prestige, reset level and XP
    data.prestige = data.prestige + 1
    data.level = 1
    data.xp = 0
    
    -- Update networked vars
    XPSystem.UpdatePlayerNetworkedVars(ply)
    
    -- Save player data
    XPSystem.SavePlayer(ply)
    
    -- Check for prestige rewards
    XPSystem.CheckPrestigeRewards(ply, data.prestige)
    
    return true
end

-- Open XP menu
function XPSystem.OpenMenu(ply)
    if not IsValid(ply) then return end
    
    net.Start("XPSystem_OpenMenu")
    net.Send(ply)
end

-- Open admin menu
function XPSystem.OpenAdminMenu(ply)
    if not IsValid(ply) then return end
    
    -- Check if player is admin/superadmin
    if not ply:IsAdmin() and not ply:IsSuperAdmin() then
        net.Start("XPSystem_OpenAdminMenu")
        net.WriteBool(false)  -- Not authorized
        net.Send(ply)
        return
    end
    
    net.Start("XPSystem_OpenAdminMenu")
    net.WriteBool(true)  -- Authorized
    net.Send(ply)
end

-- Save config to MySQL
function XPSystem.SaveConfig()
    -- Convert tables to JSON
    local levelRewards = util.TableToJSON(XPSystem.Config.LevelRewards)
    local prestigeRewards = util.TableToJSON(XPSystem.Config.PrestigeRewards)
    local rankBoosts = util.TableToJSON(XPSystem.Config.RankBoosts)
    local hudSettings = util.TableToJSON(XPSystem.Config.HUD)
    
    -- Save general settings
    local generalSettings = {
        MaxLevel = XPSystem.Config.MaxLevel,
        MaxPrestige = XPSystem.Config.MaxPrestige,
        BaseXP = XPSystem.Config.BaseXP,
        XPMultiplier = XPSystem.Config.XPMultiplier
    }
    local generalSettingsJSON = util.TableToJSON(generalSettings)
    
    -- Save to file first (backup)
    if not file.Exists("xp_system", "DATA") then
        file.CreateDir("xp_system")
    end
    
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
    
    file.Write("xp_system/config.txt", util.TableToJSON(configToSave, true))
    print("[XP System] Config saved to file")
    
    -- Now save to MySQL if available
    if XPSystem.MySQL and XPSystem.MySQL.Connected then
        -- Save each config item
        local queries = {
            string.format(
                "INSERT INTO xp_config (config_key, config_value) VALUES ('level_rewards', %s) ON DUPLICATE KEY UPDATE config_value = %s",
                XPSystem.MySQL.Escape(levelRewards), XPSystem.MySQL.Escape(levelRewards)
            ),
            string.format(
                "INSERT INTO xp_config (config_key, config_value) VALUES ('prestige_rewards', %s) ON DUPLICATE KEY UPDATE config_value = %s",
                XPSystem.MySQL.Escape(prestigeRewards), XPSystem.MySQL.Escape(prestigeRewards)
            ),
            string.format(
                "INSERT INTO xp_config (config_key, config_value) VALUES ('rank_boosts', %s) ON DUPLICATE KEY UPDATE config_value = %s",
                XPSystem.MySQL.Escape(rankBoosts), XPSystem.MySQL.Escape(rankBoosts)
            ),
            string.format(
                "INSERT INTO xp_config (config_key, config_value) VALUES ('hud_settings', %s) ON DUPLICATE KEY UPDATE config_value = %s",
                XPSystem.MySQL.Escape(hudSettings), XPSystem.MySQL.Escape(hudSettings)
            ),
            string.format(
                "INSERT INTO xp_config (config_key, config_value) VALUES ('general_settings', %s) ON DUPLICATE KEY UPDATE config_value = %s",
                XPSystem.MySQL.Escape(generalSettingsJSON), XPSystem.MySQL.Escape(generalSettingsJSON)
            )
        }
        
        -- Execute all queries
        for _, query in ipairs(queries) do
            XPSystem.MySQL.Query(query, function(data, error)
                if error then
                    print("[XP System] MySQL Error: " .. error)
                end
            end)
        end
        
        print("[XP System] Config saved successfully to MySQL!")
    else
        print("[XP System] MySQL not connected, config saved to file only")
    end
    
    -- Broadcast config to all clients
    XPSystem.BroadcastConfig()
end

-- Load config from MySQL
function XPSystem.LoadConfigFromDB()
    -- Query all config values
    local query = "SELECT config_key, config_value FROM xp_config"
    
    XPSystem.MySQL.Query(query, function(data)
        if not data or #data == 0 then
            print("[XP System] No config found in database, using defaults")
            -- Save default config to database
            XPSystem.SaveConfig()
            return
        end
        
        -- Process each config item
        for _, row in ipairs(data) do
            local key = row.config_key
            local value = row.config_value
            
            if key == "level_rewards" then
                local rewards = util.JSONToTable(value)
                if rewards then XPSystem.Config.LevelRewards = rewards end
            elseif key == "prestige_rewards" then
                local rewards = util.JSONToTable(value)
                if rewards then XPSystem.Config.PrestigeRewards = rewards end
            elseif key == "rank_boosts" then
                local boosts = util.JSONToTable(value)
                if boosts then XPSystem.Config.RankBoosts = boosts end
            elseif key == "hud_settings" then
                local hudSettings = util.JSONToTable(value)
                if hudSettings then XPSystem.Config.HUD = hudSettings end
            elseif key == "general_settings" then
                local settings = util.JSONToTable(value)
                if settings then
                    XPSystem.Config.MaxLevel = settings.MaxLevel or XPSystem.Config.MaxLevel
                    XPSystem.Config.MaxPrestige = settings.MaxPrestige or XPSystem.Config.MaxPrestige
                    XPSystem.Config.BaseXP = settings.BaseXP or XPSystem.Config.BaseXP
                    XPSystem.Config.XPMultiplier = settings.XPMultiplier or XPSystem.Config.XPMultiplier
                end
            end
        end
        
        print("[XP System] Config loaded successfully from MySQL!")
        
        -- Broadcast config to all clients
        XPSystem.BroadcastConfig()
    end)
end

-- Broadcast config to clients
function XPSystem.BroadcastConfig()
    -- Prepare config data to send to clients
    local configToSend = {
        MaxLevel = XPSystem.Config.MaxLevel,
        MaxPrestige = XPSystem.Config.MaxPrestige,
        BaseXP = XPSystem.Config.BaseXP,
        XPMultiplier = XPSystem.Config.XPMultiplier,
        RankBoosts = XPSystem.Config.RankBoosts,
        LevelRewards = XPSystem.Config.LevelRewards,
        PrestigeRewards = XPSystem.Config.PrestigeRewards,
        HUD = XPSystem.Config.HUD
    }
    
    -- Serialize the data
    local encodedData = util.TableToJSON(configToSend)
    local compressedData = util.Compress(encodedData)
    local dataLength = #compressedData
    
    -- Send to all clients
    net.Start("XPSystem_ConfigUpdate")
    net.WriteUInt(dataLength, 32)
    net.WriteData(compressedData, dataLength)
    net.Broadcast()
    
    print("[XP System] Config broadcasted to all clients")
end

-- Event hooks
hook.Add("PlayerInitialSpawn", "XPSystem_PlayerInit", function(ply)
    -- Delay data loading slightly to ensure player is fully initialized
    timer.Simple(1, function()
        if IsValid(ply) then
            XPSystem.LoadPlayer(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "XPSystem_PlayerDisconnect", function(ply)
    if IsValid(ply) then
        XPSystem.SavePlayer(ply)
    end
end)

hook.Add("ShutDown", "XPSystem_ServerShutdown", function()
    for _, ply in pairs(player.GetAll()) do
        if IsValid(ply) then
            XPSystem.SavePlayer(ply)
        end
    end
    
    -- Save configuration before shutdown to ensure no data is lost
    XPSystem.SaveConfig()
    print("[XP System] Configuration saved before shutdown")
end)

-- Network message handlers
net.Receive("XPSystem_PrestigeRequest", function(len, ply)
    if not IsValid(ply) then return end
    
    -- Attempt to prestige player
    XPSystem.PrestigePlayer(ply)
end)

net.Receive("XPSystem_OpenAdminMenu", function(len, ply)
    if not IsValid(ply) then return end
    
    -- Open admin menu
    XPSystem.OpenAdminMenu(ply)
end)

-- Admin commands
net.Receive("XPSystem_AdminAddXP", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local target = net.ReadEntity()
    local amount = net.ReadInt(32)
    
    if IsValid(target) and amount > 0 then
        XPSystem.AddXP(target, amount)
        ply:ChatPrint("[XP System] Added " .. amount .. " XP to " .. target:Nick())
        target:ChatPrint("[XP System] An admin added " .. amount .. " XP to your account")
    end
end)

net.Receive("XPSystem_AdminSetLevel", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local target = net.ReadEntity()
    local level = net.ReadInt(16)
    
    if IsValid(target) and level > 0 then
        XPSystem.SetLevel(target, level)
        ply:ChatPrint("[XP System] Set " .. target:Nick() .. "'s level to " .. level)
        target:ChatPrint("[XP System] An admin set your level to " .. level)
    end
end)

net.Receive("XPSystem_AdminSetPrestige", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local target = net.ReadEntity()
    local prestige = net.ReadInt(16)
    
    if IsValid(target) and prestige >= 0 then
        XPSystem.SetPrestige(target, prestige)
        ply:ChatPrint("[XP System] Set " .. target:Nick() .. "'s prestige to " .. prestige)
        target:ChatPrint("[XP System] An admin set your prestige to " .. prestige)
    end
end)

net.Receive("XPSystem_AdminResetPlayer", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local target = net.ReadEntity()
    
    if IsValid(target) then
        XPSystem.ResetPlayer(target)
        ply:ChatPrint("[XP System] Reset " .. target:Nick() .. "'s XP data")
        target:ChatPrint("[XP System] An admin reset your XP data")
    end
end)

-- Admin settings network handlers
net.Receive("XPSystem_AdminSetGeneralSettings", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    -- Read data
    local maxLevel = net.ReadInt(16)
    local maxPrestige = net.ReadInt(16)
    local baseXP = net.ReadInt(16)
    local xpMultiplier = net.ReadFloat()
    
    -- Update config
    XPSystem.Config.MaxLevel = maxLevel
    XPSystem.Config.MaxPrestige = maxPrestige
    XPSystem.Config.BaseXP = baseXP
    XPSystem.Config.XPMultiplier = xpMultiplier
    
    -- Save and broadcast
    XPSystem.SaveConfig()
    
    -- Notify admin
    ply:ChatPrint("[XP System] General settings updated!")
end)

net.Receive("XPSystem_AdminSetHUDSettings", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    -- Read data
    local width = net.ReadInt(16)
    local height = net.ReadInt(16)
    local margin = net.ReadInt(16)
    local rounded = net.ReadInt(8)
    local showAlways = net.ReadBool()
    local fadeTime = net.ReadFloat()
    
    -- Update config
    XPSystem.Config.HUD.Width = width
    XPSystem.Config.HUD.Height = height
    XPSystem.Config.HUD.BottomMargin = margin
    XPSystem.Config.HUD.Rounded = rounded
    XPSystem.Config.HUD.ShowAlways = showAlways
    XPSystem.Config.HUD.FadeTime = fadeTime
    
    -- Save and broadcast
    XPSystem.SaveConfig()
    
    -- Notify admin
    ply:ChatPrint("[XP System] HUD settings updated!")
end)

net.Receive("XPSystem_AdminSetRankBoost", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    -- Read data
    local rank = net.ReadString()
    local boost = net.ReadFloat()
    
    -- Update config
    XPSystem.Config.RankBoosts[rank] = boost
    
    -- Save and broadcast
    XPSystem.SaveConfig()
    
    -- Notify admin
    ply:ChatPrint("[XP System] Rank boost for " .. rank .. " set to " .. math.floor((boost - 1) * 100) .. "%!")
end)

-- Add XP commands
concommand.Add("xp_add", function(ply, cmd, args)
    -- Only server console or admins can use this
    if IsValid(ply) and not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
    
    -- Check args
    local targetName = args[1]
    local amount = tonumber(args[2])
    
    if not targetName or not amount then
        if IsValid(ply) then
            ply:ChatPrint("[XP System] Usage: xp_add <player> <amount>")
        else
            print("[XP System] Usage: xp_add <player> <amount>")
        end
        return
    end
    
    -- Find target player
    local target = nil
    for _, p in pairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then
            target = p
            break
        end
    end
    
    if not IsValid(target) then
        if IsValid(ply) then
            ply:ChatPrint("[XP System] Player not found: " .. targetName)
        else
            print("[XP System] Player not found: " .. targetName)
        end
        return
    end
    
    -- Add XP
    XPSystem.AddXP(target, amount)
    
    -- Notify
    if IsValid(ply) then
        ply:ChatPrint("[XP System] Added " .. amount .. " XP to " .. target:Nick())
    else
        print("[XP System] Added " .. amount .. " XP to " .. target:Nick())
    end
end)

-- Load player data when MySQL is ready
hook.Add("XPSystem_MySQLReady", "XPSystem_LoadPlayersAfterMySQL", function()
    -- Load data for all existing players
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            XPSystem.LoadPlayer(ply)
        end
    end
    
    -- Also load configuration from MySQL
    timer.Simple(1, function()
        XPSystem.LoadConfigFromDB()
    end)
end)

-- Log when addon is loaded
print("[XP System] Server files initialized (updated 2025-05-22 23:11:13 by JamieL25)")