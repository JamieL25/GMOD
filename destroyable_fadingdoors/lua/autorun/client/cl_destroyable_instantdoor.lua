-- Client-side code for Destroyable Instant Door

-- Health display for doors
hook.Add("HUDPaint", "DestroyableInstantDoorHealth", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = ply:GetEyeTrace()
    if not tr.Entity or not tr.Entity:IsValid() then return end
    
    local ent = tr.Entity
    if not ent:GetNWBool("IsInstantDoor", false) then return end
    
    local pos = ent:GetPos():ToScreen()
    local health = ent:GetNWFloat("DoorHealth", 0)
    local maxHealth = 250 -- Fixed for PvP
    local healthPercent = (health / maxHealth) * 250
    
    -- Only show if looking at it closely
    if tr.HitPos:Distance(ply:GetPos()) > 200 then return end
    
    -- Draw health bar background
    draw.RoundedBox(4, pos.x - 50, pos.y - 60, 100, 20, Color(50, 50, 50, 200))
    
    -- Calculate health bar color
    local barColor
    if healthPercent > 70 then
        barColor = Color(0, 255, 0, 200) -- Green
    elseif healthPercent > 30 then
        barColor = Color(255, 255, 0, 200) -- Yellow
    else
        barColor = Color(255, 0, 0, 200) -- Red
    end
    
    -- Draw health bar
    draw.RoundedBox(4, pos.x - 48, pos.y - 58, math.Clamp(healthPercent, 0, 100) * 0.96, 16, barColor)
    
    -- Draw health text
    draw.SimpleText("Health: " .. math.Round(health), "DermaDefault", pos.x, pos.y - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Draw use prompt if door is closed
    if not ent:GetNWBool("DoorOpen", false) and health > 0 then
        -- Draw a key background
        draw.RoundedBox(8, pos.x - 40, pos.y + 20, 80, 40, Color(0, 0, 0, 150))
        
        -- Draw E key
        draw.SimpleText("E", "DermaLarge", pos.x, pos.y + 40, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Draw the prompt text
        draw.SimpleText("PRESS TO OPEN", "DermaDefault", pos.x, pos.y + 55, Color(255, 255, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    elseif ent:GetNWBool("DoorOpen", false) then
        -- Show auto-close timer
        draw.SimpleText("Closing in 2 seconds...", "DermaDefault", pos.x, pos.y - 30, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    elseif health <= 0 then
        draw.SimpleText("Destroyed", "DermaDefault", pos.x, pos.y - 30, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- Visual effects for doors when opened or closed
hook.Add("OnEntityCreated", "InstantDoorEffects", function(ent)
    if not IsValid(ent) then return end
    
    timer.Simple(0.1, function()
        if IsValid(ent) and ent:GetNWBool("IsInstantDoor", false) then
            ent:SetRenderMode(RENDERMODE_TRANSALPHA)
        end
    end)
end)

-- Handle bullet hit effects
net.Receive("DoorBulletHit", function()
    local hitPos = net.ReadVector()
    local hitNormal = net.ReadVector()
    local hitEnt = net.ReadEntity()
    
    if IsValid(hitEnt) then
        -- Multiple effects for better visibility
        
        -- Bullet impact effect
        local effectdata = EffectData()
        effectdata:SetOrigin(hitPos)
        effectdata:SetNormal(hitNormal)
        effectdata:SetEntity(hitEnt)
        effectdata:SetScale(1)
        util.Effect("MetalSpark", effectdata)
        
        -- Add bullet decal
        util.Decal("ManhackCut", hitPos + hitNormal, hitPos - hitNormal)
        
        -- Make sparks
        local effect = EffectData()
        effect:SetOrigin(hitPos)
        effect:SetNormal(hitNormal)
        effect:SetMagnitude(2)
        effect:SetScale(1)
        effect:SetRadius(3)
        util.Effect("Sparks", effect)
        
        -- Flash the door red when hit
        if not hitEnt:GetNWBool("DoorOpen", false) then
            hitEnt:SetColor(Color(255, 100, 100, 255))
            timer.Simple(0.1, function()
                if IsValid(hitEnt) then
                    hitEnt:SetColor(Color(255, 255, 255, 255))
                end
            end)
        end
        
        -- Make impact sound
        sound.Play("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", hitPos, 75, 100)
    end
end)

-- Handle door destroyed effect
net.Receive("DoorDestroyed", function()
    local ent = net.ReadEntity()
    
    if IsValid(ent) then
        -- Create a larger explosion effect
        local effectdata = EffectData()
        effectdata:SetOrigin(ent:GetPos())
        effectdata:SetNormal(Vector(0, 0, 1))
        effectdata:SetMagnitude(5)
        effectdata:SetScale(2)
        effectdata:SetRadius(5)
        util.Effect("Explosion", effectdata)
        
        -- Add debris
        for i = 1, 10 do
            local effectdata = EffectData()
            effectdata:SetOrigin(ent:GetPos() + Vector(math.random(-30, 30), math.random(-30, 30), math.random(0, 50)))
            effectdata:SetNormal(VectorRand() * 100)
            effectdata:SetMagnitude(math.random(5, 10))
            effectdata:SetScale(math.random(2, 5))
            effectdata:SetRadius(math.random(5, 10))
            util.Effect("Sparks", effectdata)
        end
        
        -- Play explosion sound
        sound.Play("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", ent:GetPos(), 100, 100)
    end
end)

-- Damage number effect (shows damage when door is hit)
hook.Add("HUDPaint", "DoorDamageNumbers", function()
    for _, ent in pairs(ents.FindByClass("prop_physics")) do
        if IsValid(ent) and ent:GetNWBool("IsInstantDoor", false) then
            -- Get current and previous health to detect damage
            local health = ent:GetNWFloat("DoorHealth", 0)
            local oldHealth = ent.LastHealth or health
            
            -- If damage was taken
            if health < oldHealth then
                local damage = oldHealth - health
                
                -- Create a new damage number
                local pos = ent:GetPos()
                
                -- Store it for rendering
                if not ent.DamageNumbers then ent.DamageNumbers = {} end
                
                table.insert(ent.DamageNumbers, {
                    pos = pos + Vector(math.random(-20, 20), math.random(-20, 20), math.random(30, 50)),
                    damage = damage,
                    time = CurTime(),
                    color = Color(255, 50, 50, 255)
                })
            end
            
            -- Draw existing damage numbers
            if ent.DamageNumbers then
                for k, v in pairs(ent.DamageNumbers) do
                    -- Age out old numbers
                    if CurTime() - v.time > 1 then
                        ent.DamageNumbers[k] = nil
                        continue
                    end
                    
                    -- Draw the number
                    local pos2d = v.pos:ToScreen()
                    local alpha = 255 * (1 - (CurTime() - v.time))
                    
                    draw.SimpleText(
                        "-" .. math.Round(v.damage), 
                        "DermaLarge", 
                        pos2d.x, 
                        pos2d.y - (CurTime() - v.time) * 50, 
                        Color(v.color.r, v.color.g, v.color.b, alpha),
                        TEXT_ALIGN_CENTER
                    )
                end
            end
            
            -- Update last health
            ent.LastHealth = health
        end
    end
end)

-- Client console command to help open doors
concommand.Add("cl_open_door", function()
    -- Try to open a door the player is looking at
    local tr = LocalPlayer():GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:GetNWBool("IsInstantDoor", false) then
        RunConsoleCommand("use")
    end
end)

-- Add a notification when looking at doors
local nextDoorPrompt = 0
hook.Add("Think", "InstantDoorPromptThink", function()
    if CurTime() < nextDoorPrompt then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) then return end
    
    local ent = tr.Entity
    if not ent:GetNWBool("IsInstantDoor", false) then return end
    
    -- Only show notification if looking directly at a door and close to it
    if tr.HitPos:Distance(ply:GetPos()) < 250 and not ent:GetNWBool("DoorOpen", false) then
        notification.AddLegacy("Press E to open door", NOTIFY_HINT, 1)
        nextDoorPrompt = CurTime() + 3 -- Only show every 3 seconds
    end
end)