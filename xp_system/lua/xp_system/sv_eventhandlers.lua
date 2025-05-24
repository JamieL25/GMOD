-- XP System Event Handlers
-- Created for JamieL25 on 2025-05-24
-- Handles XP rewards for player kills and other events on a PvP server

-- Track kill streaks for bonus XP
local playerKillStreaks = {}

-- Award XP for player kills
hook.Add("PlayerDeath", "XPSystem_PlayerKillXP", function(victim, inflictor, attacker)
    -- Make sure it's a valid player kill (not suicide or NPC kill)
    if IsValid(victim) and IsValid(attacker) and attacker:IsPlayer() and victim:IsPlayer() and victim ~= attacker then
        -- Base XP for a kill
        local baseXP = 150
        
        -- Bonus XP based on level difference (more XP for killing higher level players)
        local victimLevel = victim:GetNWInt("XPSystem_Level", 1)
        local attackerLevel = attacker:GetNWInt("XPSystem_Level", 1)
        local levelDifference = victimLevel - attackerLevel
        
        -- Calculate level bonus (more XP for killing higher level players)
        local levelBonus = 0
        if levelDifference > 0 then
            -- Bonus for killing higher level players (25% more per level difference)
            levelBonus = math.floor(baseXP * (levelDifference * 0.25))
        end
        
        -- Killstreak tracking and bonuses
        if not playerKillStreaks[attacker] then
            playerKillStreaks[attacker] = 0
        end
        playerKillStreaks[attacker] = playerKillStreaks[attacker] + 1
        
        -- Reset victim's killstreak
        playerKillStreaks[victim] = 0
        
        -- Calculate killstreak bonus
        local streakBonus = 0
        local streak = playerKillStreaks[attacker]
        
        if streak >= 3 then
            streakBonus = math.min(50, streak * 5) -- Cap at 50 XP bonus
        end
        
        -- Headshot bonus
        local headshotBonus = 0
        if victim.LastHitGroup == HITGROUP_HEAD then
            headshotBonus = 10
        end
        
        -- Calculate total XP
        local totalXP = baseXP + levelBonus + streakBonus + headshotBonus
        
        -- Add XP to killer
        XPSystem.AddXP(attacker, totalXP)
        
        -- Notify player with breakdown
        local message = "[XP System] +" .. totalXP .. " XP for killing " .. victim:Nick() .. "!"
        
        if levelBonus > 0 then
            message = message .. " (+" .. levelBonus .. " level diff bonus)"
        end
        
        if streakBonus > 0 then
            message = message .. " (+" .. streakBonus .. " killstreak bonus)"
        end
        
        if headshotBonus > 0 then
            message = message .. " (+" .. headshotBonus .. " headshot bonus)"
        end
        
        attacker:ChatPrint(message)
        
        -- Special message for killstreaks
        if streak == 5 then
            PrintMessage(HUD_PRINTTALK, attacker:Nick() .. " is on a killing spree!")
        elseif streak == 10 then
            PrintMessage(HUD_PRINTTALK, attacker:Nick() .. " is dominating!")
        elseif streak == 15 then
            PrintMessage(HUD_PRINTTALK, attacker:Nick() .. " is unstoppable!")
        elseif streak >= 20 and streak % 5 == 0 then
            PrintMessage(HUD_PRINTTALK, attacker:Nick() .. " is on a " .. streak .. " kill streak!")
        end
    end
end)

-- Reset killstreak when player disconnects
hook.Add("PlayerDisconnected", "XPSystem_ResetKillstreakOnDisconnect", function(ply)
    if playerKillStreaks[ply] then
        playerKillStreaks[ply] = 0
    end
end)

-- Regular activity XP (rewards players for active playtime)
timer.Create("XPSystem_ActivityXP", 600, 0, function()
    for _, ply in pairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local activityXP = 250
            XPSystem.AddXP(ply, activityXP)
            ply:ChatPrint("[XP System] +" .. activityXP .. " XP for active playtime!")
        end
    end
end)

-- Distance-based kill bonus
hook.Add("EntityTakeDamage", "XPSystem_TrackDamageDistance", function(target, dmginfo)
    if IsValid(target) and target:IsPlayer() then
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= target then
            -- Store the distance for this damage
            target.LastAttackerDistance = attacker:GetPos():Distance(target:GetPos())
        end
    end
end)

-- Add this to the PlayerDeath hook to check for long-distance kills
hook.Add("PlayerDeath", "XPSystem_LongDistanceKillBonus", function(victim, inflictor, attacker)
    if IsValid(victim) and IsValid(attacker) and attacker:IsPlayer() and victim:IsPlayer() and victim ~= attacker then
        -- If we have a distance recorded
        if victim.LastAttackerDistance then
            local distance = victim.LastAttackerDistance
            
            -- Long distance kill bonus (over 1000 units)
            if distance > 1000 then
                local distanceBonus = math.floor(distance / 100) -- 1 XP per 100 units
                distanceBonus = math.min(50, distanceBonus) -- Cap at 50 XP
                
                XPSystem.AddXP(attacker, distanceBonus)
                attacker:ChatPrint("[XP System] +" .. distanceBonus .. " XP for long-distance kill! (" .. math.floor(distance) .. " units)")
            end
            
            -- Reset the distance tracker
            victim.LastAttackerDistance = nil
        end
    end
end)

-- Add XP for damaging other players (encourages activity)
local damageXPCooldown = {}

hook.Add("EntityTakeDamage", "XPSystem_DamageXP", function(target, dmginfo)
    if IsValid(target) and target:IsPlayer() then
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= target then
            -- Check cooldown to prevent farming
            local attackerID = attacker:SteamID64()
            local targetID = target:SteamID64()
            local cooldownKey = attackerID .. "_" .. targetID
            
            if damageXPCooldown[cooldownKey] and damageXPCooldown[cooldownKey] > CurTime() then
                return
            end
            
            -- Set cooldown (5 seconds per player)
            damageXPCooldown[cooldownKey] = CurTime() + 5
            
            -- Calculate damage amount
            local damage = dmginfo:GetDamage()
            if damage >= 20 then
                local damageXP = math.min(10, math.floor(damage / 10))
                XPSystem.AddXP(attacker, damageXP)
                -- No chat notification to avoid spam
            end
        end
    end
end)

-- Clean up cooldown table periodically
timer.Create("XPSystem_CleanupDamageCooldowns", 60, 0, function()
    local currentTime = CurTime()
    for key, time in pairs(damageXPCooldown) do
        if time < currentTime then
            damageXPCooldown[key] = nil
        end
    end
end)

print("[XP System] PvP event handlers initialized")