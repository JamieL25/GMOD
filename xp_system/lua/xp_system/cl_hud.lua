-- XP System HUD
-- Client-side file for displaying the XP bar and notifications
-- Updated with MySQL support on 2025-05-22

XPSystem = XPSystem or {}
XPSystem.HUD = {}

-- Variables
XPSystem.HUD.LastXP = 0
XPSystem.HUD.IsVisible = false
XPSystem.HUD.FadeStart = 0
XPSystem.HUD.CurrentAlpha = 0
XPSystem.HUD.TargetAlpha = 0
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

-- Toggle HUD visibility with keybind
hook.Add("Think", "XPSystem_ToggleHUD", function()
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
        local y = ScrH() - XPSystem.Config.HUD.BottomMargin - 50
        
        draw.SimpleText(XPSystem.HUD.XPGainText, "XPSystem_Rank", x, y, 
                        ColorAlpha(Color(100, 255, 100), alpha/255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Main HUD drawing function
hook.Add("HUDPaint", "XPSystem_DrawHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Get player data
    local level = ply:GetNWInt("XPSystem_Level", 1)
    local xp = ply:GetNWInt("XPSystem_XP", 0)
    local prestige = ply:GetNWInt("XPSystem_Prestige", 0)
    local maxXP = ply:GetNWInt("XPSystem_MaxXP", 100)
    
    -- Get rank info
    local rankInfo = XPSystem.GetRankForLevel(level)
    local prestigeInfo = XPSystem.GetPrestigeInfo(prestige)
    
    -- Determine if HUD should be visible
    if XPSystem.Config.HUD.ShowAlways then
        XPSystem.HUD.TargetAlpha = 255
    elseif XPSystem.HUD.IsVisible then
        if CurTime() - XPSystem.HUD.FadeStart > XPSystem.Config.HUD.FadeTime then
            XPSystem.HUD.TargetAlpha = 0
            XPSystem.HUD.IsVisible = false
        else
            XPSystem.HUD.TargetAlpha = 255
        end
    end
    
    -- Smooth alpha transition
    XPSystem.HUD.CurrentAlpha = Lerp(FrameTime() * 5, XPSystem.HUD.CurrentAlpha, XPSystem.HUD.TargetAlpha)
    
    -- Skip drawing if almost invisible
    if XPSystem.HUD.CurrentAlpha < 1 then return end
    
    -- Calculate HUD position and size
    local cfg = XPSystem.Config.HUD
    local w, h = cfg.Width, cfg.Height
    local x = ScrW() / 2 - w / 2
    local y = ScrH() - cfg.BottomMargin
    
    -- Draw the XP bar
    DrawRoundedProgressBar(
        cfg.Rounded, x, y, w, h,
        ColorAlpha(cfg.BackgroundColor, XPSystem.HUD.CurrentAlpha/255),
        ColorAlpha(cfg.XPBarColor, XPSystem.HUD.CurrentAlpha/255),
        xp / maxXP,
        ColorAlpha(cfg.BorderColor, XPSystem.HUD.CurrentAlpha/255),
        cfg.BorderWidth
    )
    
    -- Draw level text
    draw.SimpleText(
        "Level " .. level, "XPSystem_Level",
        x + w/2, y - 25,
        ColorAlpha(cfg.TextColor, XPSystem.HUD.CurrentAlpha/255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
    
    -- Draw XP text
    draw.SimpleText(
        xp .. " / " .. maxXP .. " XP", "XPSystem_XP",
        x + w/2, y + h/2,
        ColorAlpha(Color(255, 255, 255), XPSystem.HUD.CurrentAlpha/255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
    
    -- Draw rank
    draw.SimpleText(
        rankInfo.name, "XPSystem_Rank",
        x - 10, y,
        ColorAlpha(rankInfo.color, XPSystem.HUD.CurrentAlpha/255),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )
    
    -- Draw prestige if any
    if prestige > 0 then
        draw.SimpleText(
            prestigeInfo.name .. " Prestige", "XPSystem_Rank",
            x + w + 10, y,
            ColorAlpha(prestigeInfo.color, XPSystem.HUD.CurrentAlpha/255),
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
        XPSystem.Config.HUD = configData.HUD
    end
    
    print("[XP System] Received updated config from server")
end)