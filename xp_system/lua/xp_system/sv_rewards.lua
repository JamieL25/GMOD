-- XP System Rewards
-- Server-side file for handling level-up and prestige rewards
-- Created for JamieL25 on 2025-05-21

XPSystem = XPSystem or {}

-- Check for level rewards
function XPSystem.CheckLevelRewards(ply, level)
    if not IsValid(ply) then return end
    
    -- Check if level has a reward
    local reward = XPSystem.Config.LevelRewards[level]
    if not reward then return end
    
    -- Apply currency reward
    if reward.currency and reward.currency > 0 then
        -- Add currency using your currency system
        ply:SetNWInt("Currency", ply:GetNWInt("Currency", 0) + reward.currency)
        
        -- Send level up notification
        net.Start("XPSystem_LevelUp")
        net.WriteInt(level, 16)
        net.WriteInt(reward.currency, 32)
        net.WriteString(reward.message or "Level up reward!")
        net.Send(ply)
        
        -- Notify in chat
        ply:ChatPrint("[XP System] You reached level " .. level .. " and received " .. reward.currency .. " currency!")
    end
end

-- Check for prestige rewards
function XPSystem.CheckPrestigeRewards(ply, prestigeLevel)
    if not IsValid(ply) then return end
    
    -- Check if prestige level has a reward
    local reward = XPSystem.Config.PrestigeRewards[prestigeLevel]
    if not reward then return end
    
    -- Apply currency reward
    if reward.currency and reward.currency > 0 then
        -- Add currency using your currency system
        ply:SetNWInt("Currency", ply:GetNWInt("Currency", 0) + reward.currency)
        
        -- Get prestige info
        local prestigeInfo = XPSystem.GetPrestigeInfo(prestigeLevel)
        
        -- Send prestige notification
        net.Start("XPSystem_Prestige")
        net.WriteInt(prestigeLevel, 16)
        net.WriteInt(reward.currency, 32)
        net.WriteString(reward.message or "Prestige reward!")
        net.Send(ply)
        
        -- Notify in chat
        ply:ChatPrint("[XP System] You reached " .. prestigeInfo.name .. " Prestige " .. prestigeLevel .. " and received " .. reward.currency .. " currency!")
    end
end

-- Set level reward (admin function)
function XPSystem.SetLevelReward(level, currency, message)
    if not level or level < 1 then return false end
    
    -- Update the reward
    XPSystem.Config.LevelRewards[level] = {
        currency = currency or 0,
        message = message or "Level up reward!"
    }
    
    -- Save the change to file
    XPSystem.SaveConfig()
    
    return true
end

-- Set prestige reward (admin function)
function XPSystem.SetPrestigeReward(level, currency, message)
    if not level or level < 1 then return false end
    
    -- Update the reward
    XPSystem.Config.PrestigeRewards[level] = {
        currency = currency or 0,
        message = message or "Prestige reward!"
    }
    
    -- Save the change to file
    XPSystem.SaveConfig()
    
    return true
end

-- Network message handlers
net.Receive("XPSystem_AdminSetLevelReward", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local level = net.ReadInt(16)
    local currency = net.ReadInt(32)
    local message = net.ReadString()
    
    if XPSystem.SetLevelReward(level, currency, message) then
        ply:ChatPrint("[XP System] Level " .. level .. " reward updated!")
    end
end)

net.Receive("XPSystem_AdminSetPrestigeReward", function(len, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    
    local level = net.ReadInt(16)
    local currency = net.ReadInt(32)
    local message = net.ReadString()
    
    if XPSystem.SetPrestigeReward(level, currency, message) then
        ply:ChatPrint("[XP System] Prestige " .. level .. " reward updated!")
    end
end)

-- Log when addon is loaded
print("[XP System] Rewards system initialized")