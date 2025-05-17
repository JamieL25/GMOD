-- Emergency fix for door opening issues
print("[InstantDoor] Loading door opening fix...")

-- Global settings
InstantDoor = InstantDoor or {}
InstantDoor.Config = InstantDoor.Config or {}
InstantDoor.Config.DefaultHealth = InstantDoor.Config.DefaultHealth or 250

-- Debug helper
local function DebugPrint(msg)
    print("[InstantDoor Debug] " .. msg)
end

-- Global function to open any door
local function OpenInstantDoor(door, ply)
    if not IsValid(door) then return false end
    if not door:GetNWBool("IsInstantDoor", false) then return false end
    
    -- Check if door is already open
    if door:GetNWBool("DoorOpen", false) then return false end
    
    -- Check if door has health
    local health = door.CustomHealth
    if not health or health <= 0 then
        DebugPrint("Door has no health or is destroyed")
        return false
    end
    
    DebugPrint("Opening door with ID " .. door:EntIndex())
    
    -- Try the built-in method first
    if door.OpenDoor and type(door.OpenDoor) == "function" then
        DebugPrint("Using door's OpenDoor method")
        door:OpenDoor()
        return true
    end
    
    -- Backup direct method
    DebugPrint("Using backup opening method")
    
    -- Set to invisible
    door:SetColor(Color(255, 255, 255, 0))
    door:SetRenderMode(RENDERMODE_TRANSALPHA)
    door:DrawShadow(false)
    
    -- Make non-solid
    door:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
    door:CollisionRulesChanged()
    
    -- Set state flag
    door.DoorOpen = true
    door:SetNWBool("DoorOpen", true)
    
    -- Play sound effect
    door:EmitSound("doors/door_metal_thin_open1.wav", 75, 100)
    
    -- Schedule door close
    DebugPrint("Setting door to close in 2 seconds")
    timer.Create("DoorAutoClose_" .. door:EntIndex(), 2, 1, function()
        if IsValid(door) and (door.DoorOpen or door:GetNWBool("DoorOpen", false)) then
            CloseInstantDoor(door)
        end
    end)
    
    return true
end

-- Global function to close any door
function CloseInstantDoor(door)
    if not IsValid(door) then return false end
    
    DebugPrint("Closing door with ID " .. door:EntIndex())
    
    -- Try the built-in method first
    if door.CloseDoor and type(door.CloseDoor) == "function" then
        DebugPrint("Using door's CloseDoor method")
        door:CloseDoor()
        return true
    end
    
    -- Backup direct method
    DebugPrint("Using backup closing method")
    
    -- Cancel timer
    if timer.Exists("DoorAutoClose_" .. door:EntIndex()) then
        timer.Remove("DoorAutoClose_" .. door:EntIndex())
    end
    
    -- Restore visibility
    door:SetColor(Color(255, 255, 255, 255))
    door:DrawShadow(true)
    
    -- Make solid again
    door:SetCollisionGroup(COLLISION_GROUP_NONE)
    door:CollisionRulesChanged()
    
    -- Set state flag
    door.DoorOpen = false
    door:SetNWBool("DoorOpen", false)
    
    -- Play sound effect
    door:EmitSound("doors/door_metal_thin_close2.wav", 75, 100)
    
    return true
end

-- Function to try to open a door that player is looking at
local function TryOpenDoorPlayerIsLookingAt(ply)
    if not IsValid(ply) then return false end
    
    -- Get what player is looking at
    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) then return false end
    
    -- Check if it's within reach
    if tr.HitPos:Distance(ply:GetShootPos()) > 100 then return false end
    
    -- Check if it's a door
    if tr.Entity:GetNWBool("IsInstantDoor", false) or tr.Entity.IsInstantDoor then
        DebugPrint(ply:Nick() .. " attempting to open door")
        return OpenInstantDoor(tr.Entity, ply)
    end
    
    return false
end

-- PRIMARY METHOD: USE KEY DETECTION

-- Method 1: PlayerUse hook
hook.Add("PlayerUse", "FixedInstantDoorUse", function(ply, ent)
    if not IsValid(ent) then return end
    
    if ent:GetNWBool("IsInstantDoor", false) or ent.IsInstantDoor then
        DebugPrint("PlayerUse hook detected on door")
        
        if OpenInstantDoor(ent, ply) then
            return true
        end
    end
end)

-- Method 2: KeyPress hook
hook.Add("KeyPress", "FixedInstantDoorKeyPress", function(ply, key)
    if key ~= IN_USE then return end
    
    DebugPrint(ply:Nick() .. " pressed USE key")
    TryOpenDoorPlayerIsLookingAt(ply)
end)

-- Method 3: Think hook for continuous checking
local nextThink = 0
hook.Add("Think", "FixedInstantDoorThink", function()
    if CurTime() < nextThink then return end
    nextThink = CurTime() + 0.1 -- Check every 0.1 seconds
    
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or not ply:KeyDown(IN_USE) then continue end
        
        local tr = ply:GetEyeTrace()
        if not IsValid(tr.Entity) then continue end
        
        if tr.Entity:GetNWBool("IsInstantDoor", false) or tr.Entity.IsInstantDoor then
            if tr.HitPos:Distance(ply:GetShootPos()) < 100 then
                OpenInstantDoor(tr.Entity, ply)
            end
        end
    end
end)

-- SECONDARY METHODS: DIRECT COMMANDS

-- Console command for opening doors
concommand.Add("door_open", function(ply)
    if IsValid(ply) then
        TryOpenDoorPlayerIsLookingAt(ply)
    end
end)

-- Entity-specific functions replacement
hook.Add("InitPostEntity", "InstantDoorFixReplaceFunctions", function()
    timer.Simple(1, function()
        for _, ent in pairs(ents.GetAll()) do
            if not IsValid(ent) then continue end
            
            if ent:GetNWBool("IsInstantDoor", false) or ent.IsInstantDoor then
                -- Replace or add open/close functions
                ent.OpenDoor = function()
                    OpenInstantDoor(ent)
                end
                
                ent.CloseDoor = function()
                    CloseInstantDoor(ent)
                end
                
                -- Add direct USE functionality
                ent:SetUseType(SIMPLE_USE)
                ent.Use = function(self, activator, caller)
                    if IsValid(activator) and activator:IsPlayer() then
                        DebugPrint("Direct USE called by " .. activator:Nick())
                        OpenInstantDoor(self)
                    end
                end
            end
        end
        
        DebugPrint("Replaced door functions on all existing doors")
    end)
end)

-- Fix any newly created doors
hook.Add("OnEntityCreated", "InstantDoorFixNewDoors", function(ent)
    if not IsValid(ent) then return end
    
    timer.Simple(0.1, function()
        if not IsValid(ent) then return end
        
        if ent:GetNWBool("IsInstantDoor", false) or ent.IsInstantDoor then
            DebugPrint("Fixed new door with ID " .. ent:EntIndex())
            
            -- Add open/close functions
            ent.OpenDoor = function()
                OpenInstantDoor(ent)
            end
            
            ent.CloseDoor = function()
                CloseInstantDoor(ent)
            end
            
            -- Add direct USE functionality
            ent:SetUseType(SIMPLE_USE)
            ent.Use = function(self, activator, caller)
                if IsValid(activator) and activator:IsPlayer() then
                    DebugPrint("Direct USE called by " .. activator:Nick())
                    OpenInstantDoor(self)
                end
            end
        end
    end)
end)

-- Add a client command for players
util.AddNetworkString("InstantDoorOpenCommand")

hook.Add("PlayerSay", "InstantDoorChatCommand", function(ply, text)
    if text == "!door" or text == "!opendoor" then
        TryOpenDoorPlayerIsLookingAt(ply)
        return ""
    end
end)

-- Network command handler
net.Receive("InstantDoorOpenCommand", function(len, ply)
    if IsValid(ply) then
        TryOpenDoorPlayerIsLookingAt(ply)
    end
end)

print("[InstantDoor] Door opening fix loaded with multiple detection methods!")