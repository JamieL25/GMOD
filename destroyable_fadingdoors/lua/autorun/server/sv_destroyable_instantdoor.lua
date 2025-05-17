-- Server-side configuration for Destroyable Instant Door

-- Global settings that can be changed at runtime
InstantDoor = InstantDoor or {}
InstantDoor.Config = InstantDoor.Config or {}

-- Default door health - set to 250 as requested
InstantDoor.Config.DefaultHealth = 250

-- Console command to change door health
concommand.Add("instantdoor_set_health", function(ply, cmd, args)
    -- Only allow admins to change settings
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("You must be an admin to use this command!")
        return
    end
    
    -- Get the new health value
    local newHealth = tonumber(args[1])
    if not newHealth or newHealth <= 0 then
        if IsValid(ply) then
            ply:ChatPrint("Please specify a valid health value greater than 0")
        else
            print("[InstantDoor] Please specify a valid health value greater than 0")
        end
        return
    end
    
    -- Update the default health
    local oldHealth = InstantDoor.Config.DefaultHealth
    InstantDoor.Config.DefaultHealth = newHealth
    
    -- Notify about the change
    local message = "Door health changed from " .. oldHealth .. " to " .. newHealth
    if IsValid(ply) then
        ply:ChatPrint(message)
    end
    print("[InstantDoor] " .. message)
    
    -- Broadcast to all admins
    for _, admin in pairs(player.GetAll()) do
        if admin:IsAdmin() then
            admin:ChatPrint("[InstantDoor] " .. message .. " by " .. (IsValid(ply) and ply:Nick() or "Console"))
        end
    end
end)

-- Command to update health for existing doors
concommand.Add("instantdoor_update_existing", function(ply, cmd, args)
    -- Only allow admins to change settings
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("You must be an admin to use this command!")
        return
    end
    
    -- Get the health to set for existing doors
    local newHealth = tonumber(args[1])
    if not newHealth or newHealth <= 0 then
        newHealth = InstantDoor.Config.DefaultHealth
    end
    
    -- Count how many doors we update
    local updatedCount = 0
    
    -- Find all existing doors and update their health
    for _, ent in pairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsInstantDoor then
            -- Update the health
            ent.CustomHealth = newHealth
            ent.DoorHealth = newHealth
            ent.DoorMaxHealth = newHealth
            ent:SetNWFloat("DoorHealth", newHealth)
            updatedCount = updatedCount + 1
        end
    end
    
    -- Notify about the update
    local message = "Updated " .. updatedCount .. " existing doors to health: " .. newHealth
    if IsValid(ply) then
        ply:ChatPrint(message)
    end
    print("[InstantDoor] " .. message)
end)

-- Command to check current door health setting
concommand.Add("instantdoor_get_health", function(ply, cmd, args)
    local message = "Current default door health: " .. InstantDoor.Config.DefaultHealth
    if IsValid(ply) then
        ply:ChatPrint(message)
    else
        print("[InstantDoor] " .. message)
    end
end)

-- Print the current config on server start
hook.Add("Initialize", "InstantDoorConfig_Initialize", function()
    print("[InstantDoor] Configuration loaded")
    print("[InstantDoor] Default door health: " .. InstantDoor.Config.DefaultHealth)
    print("[InstantDoor] Use 'instantdoor_set_health <value>' to change")
end)

print("[InstantDoor] Config system loaded with 250 health!")