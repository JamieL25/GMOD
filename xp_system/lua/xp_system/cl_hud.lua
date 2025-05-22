-- XP System HUD
-- Client-side file for displaying the XP bar and notifications
-- Updated with top screen positioning on 2025-05-22 22:58

XPSystem = XPSystem or {}
XPSystem.HUD = {}

-- Variables
XPSystem.HUD.LastXP = 0
XPSystem.HUD.IsVisible = true  -- Always start visible
XPSystem.HUD.FadeStart = 0
XPSystem.HUD.CurrentAlpha = 255  -- Full opacity
XPSystem.HUD.TargetAlpha = 255   -- Full opacity target
XPSystem.HUD.XPGainText = nil
XPSystem.HUD.XPGainTime = 0
XPSystem.HUD.Notifications = {}

-- Materials and fonts
surface.CreateFont("XPSystem_Level", {
    font = "Roboto",
    size = 22,
    weight = 700,
    antialias = true,
    shadow = false
})

surface.CreateFont("XPSystem_Rank", {
    font = "Roboto",
    size = 18,
    weight = 600,
    antialias = true,
    shadow = false
})

surface.CreateFont("XPSystem_XP", {
    font = "Roboto",
    size = 14,
    weight = 500,
    antialias = true,
    shadow = false
})

surface.CreateFont("XPSystem_Notification", {
    font = "Roboto",
    size = 20,
    weight = 600,
    antialias = true,
    shadow = true
})

-- Override config to force HUD always visible
timer.Create("XPSystem_ForceHUDVisible", 1, 0, function()
    if XPSystem and XPSystem.Config and XPSystem.Config.HUD then
        -- Force config to always show HUD
        XPSystem.Config.HUD.ShowAlways = true
        
        -- Force HUD variables to be visible
        XPSystem.HUD.IsVisible = true
        XPSystem.HUD.CurrentAlpha = 255
        XPSystem.HUD.TargetAlpha = 255
        XPSystem.HUD.FadeStart = CurTime()
        
        -- Debug print
        print("[XP System] Forcing HUD visibility: " .. tostring(XPSystem.HUD.IsVisible))
    end
end)

-- Initialize HUD when player spawns
hook.Add("PlayerInitialSpawn", "XPSystem_InitHUD", function(ply)
    if ply == LocalPlayer() then
        -- Force HUD visibility
        XPSystem.HUD.IsVisible = true
        XPSystem.HUD.CurrentAlpha = 255
        XPSystem.HUD.TargetAlpha = 255
        XPSystem.HUD.FadeStart = CurTime()
        
        -- Override config
        if XPSystem.Config and XPSystem.Config.HUD then
            XPSystem.Config.HUD.ShowAlways = true
        end
        
        -- Debug message
        print("[XP System] HUD initialized on player spawn")
    end
end)

-- Toggle HUD visibility with keybind
hook.Add("Think", "XPSystem_ToggleHUD", function()
    -- Always force HUD to be visible regardless of key press
    XPSystem.HUD.IsVisible = true
    XPSystem.HUD.TargetAlpha = 255
    
    -- Original toggle logic (disabled but kept for reference)
    --[[
    if input.IsKeyDown(XPSystem.Config.HUD.ToggleKey) and not XPSystem.HUD.KeyPressed then
        XPSystem.HUD.KeyPressed = true
        XPSystem.HUD.IsVisible = not XPSystem.HUD.IsVisible
        if XPSystem.HUD.IsVisible then
            XPSystem.HUD.FadeStart = CurTime()
            XPSystem.HUD.TargetAlpha = 255
        else
            XPSystem.HUD.TargetAlpha = 0
        end
    elseif not input.IsKeyDown(XPSystem.Config.HUD.ToggleKey) then
        XPSystem.HUD.KeyPressed = false
    end
    --]]
end)

-- Handle XP gain notification
net.Receive("XPSystem_GainXP", function()
    local xpGained = net.ReadInt(32)
    local newLevel = net.ReadInt(16)
    local newXP = net.ReadInt(32)
    local maxXP = net.ReadInt(32)
    
    -- Update values
    XPSystem.HUD.LastXP = newXP
    XPSystem.HUD.XPGainText = "+" .. xpGained .. " XP"
    XPSystem.HUD.XPGainTime = CurTime()
    
    -- Show HUD temporarily
    XPSystem.HUD.FadeStart = CurTime()
    XPSystem.HUD.TargetAlpha = 255
    XPSystem.HUD.IsVisible = true
    
    -- Play a sound
    surface.PlaySound("buttons/button9.wav")
    
    -- Debug message
    print("[XP System] XP gained: " .. xpGained)
end)

-- Handle level up notification
net.Receive("XPSystem_LevelUp", function()
    local newLevel = net.ReadInt(16)
    local rewardAmount = net.ReadInt(32)
    local message = net.ReadString()
    
    -- Add notification
    table.insert(XPSystem.HUD.Notifications, {
        text = "LEVEL UP! Level " .. newLevel,
        subtext = message,
        startTime = CurTime(),
        color = Color(50, 200, 50),
        currency = rewardAmount
    })
    
    -- Play a sound
    surface.PlaySound("buttons/button3.wav")
end)

-- Handle prestige notification
net.Receive("XPSystem_Prestige", function()
    local newPrestige = net.ReadInt(16)
    local rewardAmount = net.ReadInt(32)
    local message = net.ReadString()
    local prestigeInfo = XPSystem.GetPrestigeInfo(newPrestige)
    
    -- Add notification
    table.insert(XPSystem.HUD.Notifications, {
        text = "PRESTIGE! " .. prestigeInfo.name .. " Prestige " .. newPrestige,
        subtext = message,
        startTime = CurTime(),
        color = prestigeInfo.color,
        currency = rewardAmount
    })
    
    -- Play a sound
    surface.PlaySound("buttons/button5.wav")
end)

-- Draw rounded rectangle function
local function DrawRoundedBox(radius, x, y, w, h, color)
    draw.RoundedBox(radius, x, y, w, h, color)
end

-- Draw rounded progress bar
local function DrawRoundedProgressBar(radius, x, y, w, h, bgColor, fgColor, progress, borderColor, borderWidth)
    -- Background
    draw.RoundedBox(radius, x, y, w, h, bgColor)
    
    -- Border
    if borderColor and borderWidth and borderWidth > 0 then
        surface.SetDrawColor(borderColor)
        surface.DrawOutlinedRect(x, y, w, h, borderWidth)
    end
    
    -- Foreground (progress)
    local progressW = math.Clamp(w * progress, 0, w - 2)
    if progressW > 0 then
        draw.RoundedBox(radius, x + 1, y + 1, progressW, h - 2, fgColor)
    end
end

-- Draw notifications
local function DrawNotifications()
    local y = ScrH() * 0.3
    local currentTime = CurTime()
    local toRemove = {}
    
    for i, notif in ipairs(XPSystem.HUD.Notifications) do
        local age = currentTime - notif.startTime
        if age > 5 then
            table.insert(toRemove, i)
        else
            local alpha = 255
            if age < 0.5 then
                alpha = alpha * (age * 2)
            elseif age > 4.5 then
                alpha = alpha * (1 - (age - 4.5) * 2)
            end
            
            local w, h = 400, 80
            local x = ScrW() / 2 - w / 2
            
            -- Background
            draw.RoundedBox(8, x, y, w, h, ColorAlpha(Color(30, 30, 30, 230), alpha/255))
            
            -- Border
            surface.SetDrawColor(ColorAlpha(notif.color, alpha/255))
            surface.DrawOutlinedRect(x, y, w, h, 2)
            
            -- Main text
            draw.SimpleText(notif.text, "XPSystem_Notification", ScrW() / 2, y + 25, 
                            ColorAlpha(notif.color, alpha/255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Subtext
            draw.SimpleText(notif.subtext, "XPSystem_XP", ScrW() / 2, y + 50, 
                            ColorAlpha(Color(255, 255, 255), alpha/255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Currency reward
            if notif.currency and notif.currency > 0 then
                draw.SimpleText("+" .. notif.currency .. " Currency", "XPSystem_XP", ScrW() / 2, y + 65, 
                                ColorAlpha(Color(220, 220, 100), alpha/255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            y = y + h + 10
        end
    end
    
    -- Remove old notifications
    for i = #toRemove, 1, -1 do
        table.remove(XPSystem.HUD.Notifications, toRemove[i])
    end
end

-- XP gain animation
local function DrawXPGain()
    if XPSystem.HUD.XPGainText and CurTime() - XPSystem.HUD.XPGainTime < 2 then
        local age = CurTime() - XPSystem.HUD.XPGainTime
        local alpha = 255
        if age > 1.5 then
            alpha = alpha * (1 - (age - 1.5) * 2)
        end
        
        local x = ScrW() / 2
        -- Changed to display above the bar at the top
        local y = 50 
        
        draw.SimpleText(XPSystem.HUD.XPGainText, "XPSystem_Rank", x, y, 
                        ColorAlpha(Color(100, 255, 100), alpha/255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Debug test XP bar
local function DebugDrawTestBar()
    -- Draw a simple test bar at the top of the screen
    draw.RoundedBox(4, 50, 50, 200, 20, Color(255, 0, 0, 200))
    draw.SimpleText("XP SYSTEM TEST BAR", "XPSystem_XP", 150, 60, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Main HUD drawing function
hook.Add("HUDPaint", "XPSystem_DrawHUD", function()
    -- Draw debug test bar to check if HUD drawing is working at all
    DebugDrawTestBar()
    
    local ply = LocalPlayer()
    if not IsValid(ply) then 
        print("[XP System] LocalPlayer not valid")
        return 
    end
    
    -- Get player data
    local level = ply:GetNWInt("XPSystem_Level", 1)
    local xp = ply:GetNWInt("XPSystem_XP", 0)
    local prestige = ply:GetNWInt("XPSystem_Prestige", 0)
    local maxXP = ply:GetNWInt("XPSystem_MaxXP", 100)
    
    -- Debug data
    print("[XP System] Player Data - Level: " .. level .. ", XP: " .. xp .. "/" .. maxXP)
    
    -- Get rank info - with error checking
    local rankInfo = {name = "Unknown", color = Color(255, 255, 255)}
    if XPSystem.GetRankForLevel then
        rankInfo = XPSystem.GetRankForLevel(level) or rankInfo
    else
        print("[XP System] GetRankForLevel function not found")
    end
    
    local prestigeInfo = {name = "Unknown", color = Color(255, 215, 0)}
    if XPSystem.GetPrestigeInfo then
        prestigeInfo = XPSystem.GetPrestigeInfo(prestige) or prestigeInfo
    else
        print("[XP System] GetPrestigeInfo function not found")
    end
    
    -- Skip all fade logic - always visible
    XPSystem.HUD.CurrentAlpha = 255
    XPSystem.HUD.TargetAlpha = 255
    
    -- Calculate HUD position and size
    local cfg = XPSystem.Config.HUD
    local w, h = cfg.Width, cfg.Height
    local x = ScrW() / 2 - w / 2
    
    -- Position at top of screen
    local topMargin = 20 -- 20 pixels from top
    local y = topMargin
    
    -- Draw the XP bar
    DrawRoundedProgressBar(
        cfg.Rounded, x, y, w, h,
        Color(30, 30, 30, 200), -- Background
        Color(0, 150, 255, 255), -- XP bar
        xp / maxXP,
        Color(0, 0, 0, 100), -- Border
        cfg.BorderWidth
    )
    
    -- Draw level text (now below the bar)
    draw.SimpleText(
        "Level " .. level, "XPSystem_Level",
        x + w/2, y + h + 20,
        Color(255, 255, 255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
    
    -- Draw XP text
    draw.SimpleText(
        xp .. " / " .. maxXP .. " XP", "XPSystem_XP",
        x + w/2, y + h/2,
        Color(255, 255, 255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
    
    -- Draw rank
    draw.SimpleText(
        rankInfo.name, "XPSystem_Rank",
        x - 10, y + h/2,
        rankInfo.color,
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )
    
    -- Draw prestige if any
    if prestige > 0 then
        draw.SimpleText(
            prestigeInfo.name .. "", "XPSystem_Rank",
            x + w + 10, y + h/2,
            prestigeInfo.color,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end
    
    -- Draw notifications and XP gain animation
    DrawNotifications()
    DrawXPGain()
end)

-- Remove default HUD elements that we're replacing
hook.Add("HUDShouldDraw", "XPSystem_HideHUD", function(name)
    if name == "CHudSecondaryAmmo" then  -- Using this as an example, we're not actually hiding it
        -- return false -- Uncomment this to hide the secondary ammo HUD
    end
end)

-- Handle config updates from server
net.Receive("XPSystem_ConfigUpdate", function()
    local dataLength = net.ReadUInt(32)
    local compressedData = net.ReadData(dataLength)
    local decodedData = util.Decompress(compressedData)
    
    if not decodedData then
        print("[XP System] Failed to decompress config data")
        return
    end
    
    local configData = util.JSONToTable(decodedData)
    if not configData then
        print("[XP System] Failed to parse config data")
        return
    end
    
    -- Update config values
    XPSystem.Config.MaxLevel = configData.MaxLevel or XPSystem.Config.MaxLevel
    XPSystem.Config.MaxPrestige = configData.MaxPrestige or XPSystem.Config.MaxPrestige
    XPSystem.Config.BaseXP = configData.BaseXP or XPSystem.Config.BaseXP
    XPSystem.Config.XPMultiplier = configData.XPMultiplier or XPSystem.Config.XPMultiplier
    XPSystem.Config.RankBoosts = configData.RankBoosts or XPSystem.Config.RankBoosts
    XPSystem.Config.LevelRewards = configData.LevelRewards or XPSystem.Config.LevelRewards
    XPSystem.Config.PrestigeRewards = configData.PrestigeRewards or XPSystem.Config.PrestigeRewards
    
    -- Update HUD settings if they exist
    if configData.HUD then
        configData.HUD.ShowAlways = true -- Force always show
        XPSystem.Config.HUD = configData.HUD
    end
    
    -- Force show HUD when config is updated
    XPSystem.HUD.IsVisible = true
    XPSystem.HUD.TargetAlpha = 255
    XPSystem.HUD.CurrentAlpha = 255
    XPSystem.HUD.FadeStart = CurTime()
    
    print("[XP System] Received updated config from server - HUD visibility forced ON")
end)

-- Print debug info every 5 seconds
timer.Create("XPSystem_DebugHUD", 5, 0, function()
    if not XPSystem or not XPSystem.HUD then
        print("[XP System DEBUG] XPSystem or XPSystem.HUD is nil!")
        return
    end
    
    print("[XP System DEBUG] HUD Status:")
    print("  IsVisible: " .. tostring(XPSystem.HUD.IsVisible))
    print("  CurrentAlpha: " .. tostring(XPSystem.HUD.CurrentAlpha))
    print("  TargetAlpha: " .. tostring(XPSystem.HUD.TargetAlpha))
    
    if XPSystem.Config and XPSystem.Config.HUD then
        print("  Config.HUD.ShowAlways: " .. tostring(XPSystem.Config.HUD.ShowAlways))
    else
        print("  Config.HUD not found!")
    end
    
    local ply = LocalPlayer()
    if IsValid(ply) then
        print("  Player Level: " .. ply:GetNWInt("XPSystem_Level", 0))
        print("  Player XP: " .. ply:GetNWInt("XPSystem_XP", 0))
        print("  Player Max XP: " .. ply:GetNWInt("XPSystem_MaxXP", 0))
    else
        print("  LocalPlayer not valid!")
    end
end)