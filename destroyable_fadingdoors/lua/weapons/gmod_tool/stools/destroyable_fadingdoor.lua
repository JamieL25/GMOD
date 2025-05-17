TOOL.Category = "Construction"
TOOL.Name = "Destroyable Instant Door"
TOOL.Command = nil
TOOL.ConfigName = ""

-- Fixed settings for PvP server
TOOL.ClientConVar["material"] = "models/props_c17/metalladder001"
TOOL.ClientConVar["health"] = "250" -- Updated default

-- Initialize global settings if not already existing
if SERVER then
    InstantDoor = InstantDoor or {}
    InstantDoor.Config = InstantDoor.Config or {}
    InstantDoor.Config.DefaultHealth = 250 -- Set default to 250
end

if CLIENT then
    language.Add("tool.destroyable_fadingdoor.name", "Destroyable Instant Door")
    language.Add("tool.destroyable_fadingdoor.desc", "Turn props into doors that open instantly with E and close after 2 seconds")
    language.Add("tool.destroyable_fadingdoor.0", "Left-click: Make a prop a destroyable door. Right-click: Remove door properties.")
    
    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Text = "Destroyable Instant Door", Description = "Create doors that open instantly and can be destroyed" })
        
        -- Material selector
        local matSelect = vgui.Create("MatSelect", panel)
        matSelect:SetItemWidth(64)
        matSelect:SetItemHeight(64)
        matSelect:SetConVar("destroyable_fadingdoor_material")
        
        -- Add common materials
        local materials = {
            ["models/props_c17/metalladder001"] = "Metal Ladder",
            ["models/props_c17/frostedglass_01a"] = "Frosted Glass",
            ["models/props_lab/glass_destinyconsole"] = "Glass Panel",
            ["models/props_combine/metal_combinebridge001"] = "Combine Metal",
            ["models/props_debris/metalwall001a"] = "Metal Wall",
            ["models/props_interiors/metalfence007a"] = "Metal Fence",
            ["models/props_wasteland/prison_slidedoor001a"] = "Prison Door",
            ["models/props_combine/combine_fence01a"] = "Combine Fence",
            ["models/props_combine/combine_interface_disp"] = "Combine Display",
            ["models/props_lab/xencrystal_sheet"] = "Crystal Sheet",
            ["models/props_combine/combine_door01_glass"] = "Combine Glass",
            ["models/props_vents/vent_modular_trans"] = "Vent Transparent"
        }
        
        for material, name in pairs(materials) do
            matSelect:AddMaterial(name, material)
        end
        
        panel:AddItem(matSelect)
        
        panel:AddControl("Label", {
            Text = "Door Health: 250 (Fixed for PvP Balance)"
        })
        
        panel:AddControl("Label", {
            Text = "Doors will instantly open with E key"
        })
        
        panel:AddControl("Label", {
            Text = "Doors will automatically close after 2 seconds"
        })
        
        panel:AddControl("Label", {
            Text = "Press Z to undo door creation"
        })
    end
end

-- Check if we can use the entity
function TOOL:CanUseTool(trace)
    if not trace.Entity or not trace.Entity:IsValid() then return false end
    if trace.Entity:IsPlayer() then return false end
    if trace.Entity:IsWorld() then return false end
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    return IsValid(ply) and hook.Run("CanTool", ply, trace, "destroyable_fadingdoor") ~= false
end

-- Setup the door when primary attack
function TOOL:LeftClick(trace)
    if not self:CanUseTool(trace) then return false end
    
    if CLIENT then return true end
    
    local ent = trace.Entity
    local ply = self:GetOwner()
    
    -- Don't allow if already a door
    if ent.IsInstantDoor then
        ply:ChatPrint("This is already an instant door!")
        return false
    end
    
    -- Get settings from tool
    local material = self:GetClientInfo("material")
    
    -- Use the global config value (250 HP)
    local health = InstantDoor.Config.DefaultHealth
    
    -- Store original properties for undo
    local original_data = {
        Material = ent:GetMaterial(),
        Color = ent:GetColor(),
        Solid = ent:GetSolid(),
        CollisionGroup = ent:GetCollisionGroup(),
        RenderMode = ent:GetRenderMode()
    }
    
    -- Set up the door
    ent.IsInstantDoor = true
    ent.DoorHealth = health
    ent.DoorMaxHealth = health
    ent.DoorAutoCloseTime = 2 -- 2 seconds auto-close time
    
    -- Set our direct health storage (bypassing GMod's health system)
    ent.CustomHealth = health
    
    -- Make entity use the custom door functions
    ent:SetNWBool("IsInstantDoor", true)
    ent:SetNWFloat("DoorHealth", health)
    
    -- Store original material and color for restoration
    ent.DoorOriginalMaterial = ent:GetMaterial()
    ent.DoorOriginalColor = ent:GetColor()
    ent.DoorOriginalSolid = ent:GetSolid()
    ent.DoorOriginalCollisionGroup = ent:GetCollisionGroup()
    
    -- Apply the selected material
    ent:SetMaterial(material)
    
    -- Make entity solid for physics and bullets
    ent:SetSolid(SOLID_VPHYSICS)
    ent:SetMoveType(MOVETYPE_VPHYSICS)
    
    -- Initialize physics
    ent:PhysicsInit(SOLID_VPHYSICS)
    
    -- Force collision group
    ent:SetCollisionGroup(COLLISION_GROUP_NONE) -- Fully solid
    
    -- Enable damage taking
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Wake()
    end
    
    -- SIMPLIFIED DOOR OPENING FUNCTION
    ent.OpenDoor = function()
        if not ent:IsValid() or ent.CustomHealth <= 0 or ent.DoorOpen then return end
        
        print("[InstantDoor] Opening door")
        
        -- Set to invisible
        ent:SetColor(Color(255, 255, 255, 0))
        ent:SetRenderMode(RENDERMODE_TRANSALPHA)
        ent:DrawShadow(false)
        
        -- Make non-solid
        ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
        ent:CollisionRulesChanged()
        
        -- Set state flag
        ent.DoorOpen = true
        ent:SetNWBool("DoorOpen", true)
        
        -- Play sound effect
        ent:EmitSound("doors/door_metal_thin_open1.wav", 75, 100)
        
        -- Set timer to close
        timer.Create("DoorAutoClose_" .. ent:EntIndex(), ent.DoorAutoCloseTime, 1, function()
            if IsValid(ent) and ent.DoorOpen and ent.CustomHealth > 0 then
                ent:CloseDoor()
            end
        end)
    end
    
    ent.CloseDoor = function()
        if not ent:IsValid() or not ent.DoorOpen or ent.CustomHealth <= 0 then return end
        
        print("[InstantDoor] Closing door")
        
        -- Cancel timer
        if timer.Exists("DoorAutoClose_" .. ent:EntIndex()) then
            timer.Remove("DoorAutoClose_" .. ent:EntIndex())
        end
        
        -- Restore visibility
        ent:SetColor(Color(255, 255, 255, 255))
        ent:DrawShadow(true)
        
        -- Make solid again
        ent:SetCollisionGroup(COLLISION_GROUP_NONE)
        ent:CollisionRulesChanged()
        
        -- Set state flag
        ent.DoorOpen = false
        ent:SetNWBool("DoorOpen", false)
        
        -- Play sound effect
        ent:EmitSound("doors/door_metal_thin_close2.wav", 75, 100)
    end
    
    -- Direct damage function
    ent.ApplyDirectDamage = function(amount, attacker)
        if not ent:IsValid() or ent.CustomHealth <= 0 then return end
        
        -- Debug the incoming damage amount
        print("[InstantDoor] Damage received: " .. tostring(amount) .. " (Type: " .. type(amount) .. ")")
        
        -- Convert to number and ensure positive value
        local damage = math.abs(tonumber(amount) or 2000)
        
        -- Debug the processed damage
        print("[InstantDoor] Processed damage: " .. damage)
        
        -- Apply damage directly to our custom health
        ent.CustomHealth = ent.CustomHealth - damage
        
        -- Debug the health after damage
        print("[InstantDoor] Door health after damage: " .. ent.CustomHealth)
        
        -- Update networked health for HUD
        ent:SetNWFloat("DoorHealth", ent.CustomHealth)
        
        -- Hit effect
        ent:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav")
        
        -- Check for destruction
        if ent.CustomHealth <= 0 then
            -- Safe check for attacker - CW weapons sometimes pass non-entity attackers
            local attackerName = "unknown"
            if attacker ~= nil then
                if type(attacker) == "Player" or (type(attacker) == "table" or type(attacker) == "userdata") and attacker.IsPlayer and attacker:IsPlayer() then
                    attackerName = attacker:Nick()
                end
            end
            
            print("[InstantDoor] Door destroyed by " .. attackerName)
            
            -- Explosion effect
            local effect = EffectData()
            effect:SetOrigin(ent:GetPos())
            effect:SetMagnitude(3)
            util.Effect("Explosion", effect)
            
            -- Mark as destroyed
            ent.IsInstantDoor = nil
            ent:SetNWBool("IsInstantDoor", false)
            
            -- Remove the door
            timer.Simple(0.1, function()
                if IsValid(ent) then
                    ent:Remove()
                end
            end)
        end
    end
    
    -- ADD USE FUNCTION DIRECTLY TO ENTITY
    ent:SetUseType(SIMPLE_USE)
    
    function ent:Use(activator, caller)
        if IsValid(activator) and activator:IsPlayer() then
            print("[InstantDoor] Direct USE function called by " .. activator:Nick())
            
            if not self.DoorOpen and self.CustomHealth > 0 then
                self:OpenDoor()
            end
        end
    end
    
    -- CREATE UNDO FUNCTION
    local function UndoDoor(_, entity)
        if IsValid(entity) then
            -- Clean up any timers
            timer.Remove("DoorAutoClose_" .. entity:EntIndex())
            
            -- Restore original properties
            entity:SetRenderMode(original_data.RenderMode or RENDERMODE_NORMAL)
            entity:SetMaterial(original_data.Material or "")
            entity:SetColor(original_data.Color or Color(255, 255, 255, 255))
            entity:DrawShadow(true)
            
            -- Restore original collision and solidity
            entity:SetCollisionGroup(original_data.CollisionGroup or COLLISION_GROUP_NONE)
            entity:SetSolid(original_data.Solid or SOLID_VPHYSICS)
            entity:CollisionRulesChanged()
            
            -- Remove all door properties
            entity.IsInstantDoor = nil
            entity.DoorOpen = nil
            entity.OpenDoor = nil
            entity.CloseDoor = nil
            entity.CustomHealth = nil
            entity.ApplyDirectDamage = nil
            entity.DoorHealth = nil
            entity.DoorOriginalMaterial = nil
            entity.DoorOriginalColor = nil
            entity.DoorAutoCloseTime = nil
            entity.DoorOriginalSolid = nil
            entity.DoorOriginalCollisionGroup = nil
            
            -- Remove Use function
            entity:SetUseType(SIMPLE_USE)
            entity.Use = nil
            
            entity:SetNWBool("IsInstantDoor", false)
            entity:SetNWBool("DoorOpen", false)
            
            print("[InstantDoor] Door removed via Undo function")
        end
    end
    
    -- Add to undo list
    undo.Create("Destroyable Door")
        undo.AddFunction(UndoDoor, ent)
        undo.SetPlayer(ply)
    undo.Finish()
    
    ply:ChatPrint("Created a destroyable instant door! Health: " .. health .. " (Press Z to undo)")
    return true
end

-- Remove door properties when right-clicked
function TOOL:RightClick(trace)
    if not self:CanUseTool(trace) then return false end
    
    if CLIENT then return true end
    
    local ent = trace.Entity
    local ply = self:GetOwner()
    
    if not ent.IsInstantDoor then
        ply:ChatPrint("This is not an instant door!")
        return false
    end
    
    -- Clean up timers
    timer.Remove("DoorAutoClose_" .. ent:EntIndex())
    
    -- Restore original appearance
    ent:SetRenderMode(RENDERMODE_NORMAL)
    ent:SetMaterial(ent.DoorOriginalMaterial or "")
    ent:SetColor(ent.DoorOriginalColor or Color(255, 255, 255, 255))
    ent:DrawShadow(true)
    
    -- Restore original collision and solidity
    ent:SetCollisionGroup(ent.DoorOriginalCollisionGroup or COLLISION_GROUP_NONE)
    ent:SetSolid(ent.DoorOriginalSolid or SOLID_VPHYSICS)
    ent:CollisionRulesChanged()
    
    -- Remove all door properties
    ent.IsInstantDoor = nil
    ent.DoorOpen = nil
    ent.OpenDoor = nil
    ent.CloseDoor = nil
    ent.CustomHealth = nil
    ent.ApplyDirectDamage = nil
    ent.DoorHealth = nil
    ent.DoorOriginalMaterial = nil
    ent.DoorOriginalColor = nil
    ent.DoorAutoCloseTime = nil
    ent.DoorOriginalSolid = nil
    ent.DoorOriginalCollisionGroup = nil
    
    -- Remove Use function
    ent:SetUseType(SIMPLE_USE)
    ent.Use = nil
    
    ent:SetNWBool("IsInstantDoor", false)
    ent:SetNWBool("DoorOpen", false)
    
    ply:ChatPrint("Removed instant door properties!")
    return true
end

-- Direct test function with reload key
function TOOL:Reload(trace)
    if not self:CanUseTool(trace) then return false end
    
    if CLIENT then return true end
    
    local ent = trace.Entity
    local ply = self:GetOwner()
    
    if ent.IsInstantDoor then
        -- Manually toggle the door state
        if ent.DoorOpen then
            ent:CloseDoor()
            ply:ChatPrint("Force closed the door!")
        else
            ent:OpenDoor()
            ply:ChatPrint("Force opened the door!")
        end
        return true
    end
    
    return false
end