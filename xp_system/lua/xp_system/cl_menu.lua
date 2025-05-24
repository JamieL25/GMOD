-- XP System Client Menu
-- Client-side file for player menu and admin interface
-- Created for JamieL25 on 2025-05-21

XPSystem = XPSystem or {}
XPSystem.Menu = {}

-- Create the player menu
function XPSystem.Menu.Open()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Get player data
    local level = ply:GetNWInt("XPSystem_Level", 1)
    local xp = ply:GetNWInt("XPSystem_XP", 0)
    local prestige = ply:GetNWInt("XPSystem_Prestige", 0)
    local maxXP = ply:GetNWInt("XPSystem_MaxXP", 100)
    local totalXP = ply:GetNWInt("XPSystem_TotalXP", 0)
    
    -- Get rank info
    local rankInfo = XPSystem.GetRankForLevel(level)
    local prestigeInfo = XPSystem.GetPrestigeInfo(prestige)
    
    -- Create frame
    local frame = vgui.Create("DFrame")
    frame:SetSize(1000, 900)
    frame:Center()
    frame:SetTitle("XP & Rank System")
    frame:SetDraggable(true)
    frame:SetSizable(false)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 35, 240))
        draw.RoundedBox(8, 1, 1, w-2, h-2, Color(45, 45, 50, 255))
    end
    
    -- Create tabs
    local tabPanel = vgui.Create("DPropertySheet", frame)
    tabPanel:Dock(FILL)
    tabPanel:DockMargin(5, 5, 5, 5)
    
    -- Style the tabs
    tabPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 40, 200))
    end
    
    -- Stats tab
    local statsPanel = vgui.Create("DPanel", tabPanel)
    statsPanel:Dock(FILL)
    statsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 200))
    end
    
    -- Add stats content
    local scroll = vgui.Create("DScrollPanel", statsPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)
    
    -- Player info section
    local infoPanel = vgui.Create("DPanel", scroll)
    infoPanel:Dock(TOP)
    infoPanel:SetHeight(120)
    infoPanel:DockMargin(0, 0, 0, 10)
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, 200))
    end
    
    -- Avatar
    local avatar = vgui.Create("AvatarImage", infoPanel)
    avatar:SetSize(100, 100)
    avatar:SetPos(10, 10)
    avatar:SetPlayer(ply, 100)
    
    -- Player name
    local nameLabel = vgui.Create("DLabel", infoPanel)
    nameLabel:SetPos(120, 15)
    nameLabel:SetSize(300, 25)
    nameLabel:SetFont("XPSystem_Level")
    nameLabel:SetText(ply:Nick())
    nameLabel:SetTextColor(Color(255, 255, 255))
    
    -- Rank info
    local rankLabel = vgui.Create("DLabel", infoPanel)
    rankLabel:SetPos(120, 45)
    rankLabel:SetSize(300, 20)
    rankLabel:SetFont("XPSystem_Rank")
    rankLabel:SetText("Rank: " .. rankInfo.name)
    rankLabel:SetTextColor(rankInfo.color)
    
    -- Level info
    local levelLabel = vgui.Create("DLabel", infoPanel)
    levelLabel:SetPos(120, 65)
    levelLabel:SetSize(300, 20)
    levelLabel:SetFont("XPSystem_Rank")
    levelLabel:SetText("Level: " .. level)
    levelLabel:SetTextColor(Color(255, 255, 255))
    
    -- Prestige info
    local prestigeLabel = vgui.Create("DLabel", infoPanel)
    prestigeLabel:SetPos(120, 85)
    prestigeLabel:SetSize(300, 20)
    prestigeLabel:SetFont("XPSystem_Rank")
    if prestige > 0 then
        prestigeLabel:SetText("Prestige: " .. prestigeInfo.name .. " (" .. prestige .. ")")
        prestigeLabel:SetTextColor(prestigeInfo.color)
    else
        prestigeLabel:SetText("Prestige: None")
        prestigeLabel:SetTextColor(Color(150, 150, 150))
    end
    
    -- XP progress section
    local xpPanel = vgui.Create("DPanel", scroll)
    xpPanel:Dock(TOP)
    xpPanel:SetHeight(80)
    xpPanel:DockMargin(0, 0, 0, 10)
    xpPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, 200))
        
        -- XP Bar
        draw.RoundedBox(4, 10, 50, w-20, 20, Color(30, 30, 35, 200))
        draw.RoundedBox(4, 10, 50, (w-20) * (xp / maxXP), 20, Color(0, 150, 255, 255))
        
        -- XP Text
        draw.SimpleText("XP: " .. xp .. " / " .. maxXP, "XPSystem_Rank", w/2, 60, 
                        Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- XP Title
    local xpTitle = vgui.Create("DLabel", xpPanel)
    xpTitle:SetPos(10, 10)
    xpTitle:SetSize(300, 25)
    xpTitle:SetFont("XPSystem_Rank")
    xpTitle:SetText("Experience Progress")
    xpTitle:SetTextColor(Color(220, 220, 220))
    
    -- Total XP
    local totalXPLabel = vgui.Create("DLabel", xpPanel)
    totalXPLabel:SetPos(10, 30)
    totalXPLabel:SetSize(300, 20)
    totalXPLabel:SetFont("XPSystem_XP")
    totalXPLabel:SetText("Total XP Earned: " .. totalXP)
    totalXPLabel:SetTextColor(Color(180, 180, 180))
    
    -- Prestige button (if at max level)
    if level >= XPSystem.Config.MaxLevel and prestige < XPSystem.Config.MaxPrestige then
        local prestigeButton = vgui.Create("DButton", scroll)
        prestigeButton:Dock(TOP)
        prestigeButton:SetHeight(40)
        prestigeButton:DockMargin(0, 0, 0, 10)
        prestigeButton:SetText("PRESTIGE TO " .. XPSystem.GetPrestigeInfo(prestige + 1).name:upper())
        prestigeButton:SetFont("XPSystem_Rank")
        prestigeButton:SetTextColor(Color(255, 255, 255))
        
        prestigeButton.Paint = function(self, w, h)
            local hovered = self:IsHovered()
            local color = XPSystem.GetPrestigeInfo(prestige + 1).color
            
            if hovered then
                draw.RoundedBox(8, 0, 0, w, h, Color(color.r, color.g, color.b, 200))
            else
                draw.RoundedBox(8, 0, 0, w, h, Color(color.r, color.g, color.b, 150))
            end
        end
        
        prestigeButton.DoClick = function()
            Derma_Query(
                "Are you sure you want to prestige?\nYou will reset to level 1 but gain prestige benefits!",
                "Confirm Prestige",
                "Yes, Prestige Now",
                function()
                    net.Start("XPSystem_PrestigeRequest")
                    net.SendToServer()
                    frame:Close()
                end,
                "Cancel",
                function() end
            )
        end
    end
    
-- Ranks and levels section
local ranksPanel = vgui.Create("DPanel", scroll)
ranksPanel:Dock(TOP)
ranksPanel:SetHeight(200)
ranksPanel:DockMargin(0, 0, 0, 10)
ranksPanel.Paint = function(self, w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, 200))
end

-- Ranks Title
local ranksTitle = vgui.Create("DLabel", ranksPanel)
ranksTitle:SetPos(10, 10)
ranksTitle:SetSize(300, 25)
ranksTitle:SetFont("XPSystem_Rank")
ranksTitle:SetText("Rank Progression")
ranksTitle:SetTextColor(Color(220, 220, 220))

-- Fixed rank progression list with proper width
local ranksList = vgui.Create("DScrollPanel", ranksPanel)
ranksList:SetPos(10, 40)
ranksList:SetSize(ranksPanel:GetWide() - 20, 150)

-- Ensure the ranksList maintains proper width when parent resizes
ranksPanel.OnSizeChanged = function(self, w, h)
    if IsValid(ranksList) then
        ranksList:SetSize(w - 20, 150)
    end
end

local y = 0
for level, rank in SortedPairs(XPSystem.Ranks.List) do
    local rankItem = vgui.Create("DPanel", ranksList)
    rankItem:Dock(TOP)
    rankItem:SetHeight(25)
    rankItem:DockMargin(0, 0, 0, 2)
    rankItem.Paint = function(self, w, h)
        local alpha = 100
        if level <= LocalPlayer():GetNWInt("XPSystem_Level", 1) then
            alpha = 200
        end
        
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, alpha))
        draw.SimpleText(rank.name, "XPSystem_XP", 10, h/2, rank.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Level " .. level, "XPSystem_XP", w - 10, h/2, Color(255, 255, 255, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    
    y = y + 27
end
    
    -- Rewards tab
    local rewardsPanel = vgui.Create("DPanel", tabPanel)
    rewardsPanel:Dock(FILL)
    rewardsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 200))
    end
    
    -- Add rewards content
    local rewardsScroll = vgui.Create("DScrollPanel", rewardsPanel)
    rewardsScroll:Dock(FILL)
    rewardsScroll:DockMargin(10, 10, 10, 10)
    
    -- Level rewards title
    local levelRewardsTitle = vgui.Create("DLabel", rewardsScroll)
    levelRewardsTitle:Dock(TOP)
    levelRewardsTitle:SetHeight(30)
    levelRewardsTitle:SetFont("XPSystem_Level")
    levelRewardsTitle:SetText("Level Rewards")
    levelRewardsTitle:SetTextColor(Color(220, 220, 220))
    
    -- Level rewards list
    for lvl, reward in SortedPairs(XPSystem.Config.LevelRewards) do
        local rewardItem = vgui.Create("DPanel", rewardsScroll)
        rewardItem:Dock(TOP)
        rewardItem:SetHeight(40)
        rewardItem:DockMargin(0, 5, 0, 0)
        rewardItem.Paint = function(self, w, h)
            local alpha = 100
            if lvl <= LocalPlayer():GetNWInt("XPSystem_Level", 1) then
                alpha = 200
            end
            
            draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, alpha))
            draw.SimpleText("Level " .. lvl, "XPSystem_Rank", 10, h/2, Color(0, 150, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(reward.message, "XPSystem_XP", w/2, 10, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("+" .. reward.currency .. " Currency", "XPSystem_XP", w - 10, h/2, Color(220, 220, 100, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
	
	    -- Prestige rewards title
    local prestigeRewardsTitle = vgui.Create("DLabel", rewardsScroll)
    prestigeRewardsTitle:Dock(TOP)
    prestigeRewardsTitle:SetHeight(40)
    prestigeRewardsTitle:SetFont("XPSystem_Level")
    prestigeRewardsTitle:SetText("Prestige Rewards")
    prestigeRewardsTitle:SetTextColor(Color(220, 220, 220))
    prestigeRewardsTitle:DockMargin(0, 20, 0, 0)
    
    -- Prestige rewards list
    for lvl, reward in SortedPairs(XPSystem.Config.PrestigeRewards) do
        local rewardItem = vgui.Create("DPanel", rewardsScroll)
        rewardItem:Dock(TOP)
        rewardItem:SetHeight(40)
        rewardItem:DockMargin(0, 5, 0, 0)
        rewardItem.Paint = function(self, w, h)
            local alpha = 100
            if lvl <= LocalPlayer():GetNWInt("XPSystem_Prestige", 0) then
                alpha = 200
            end
            
            local prestigeInfo = XPSystem.GetPrestigeInfo(lvl)
            draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, alpha))
            draw.SimpleText(prestigeInfo.name .. " Prestige", "XPSystem_Rank", 10, h/2, prestigeInfo.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(reward.message, "XPSystem_XP", w/2, 10, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("+" .. reward.currency .. " Currency", "XPSystem_XP", w - 10, h/2, Color(220, 220, 100, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    
    -- XP Boost info title
    local boostTitle = vgui.Create("DLabel", rewardsScroll)
    boostTitle:Dock(TOP)
    boostTitle:SetHeight(40)
    boostTitle:SetFont("XPSystem_Level")
    boostTitle:SetText("Donation Rank XP Boosts")
    boostTitle:SetTextColor(Color(220, 220, 220))
    boostTitle:DockMargin(0, 20, 0, 0)
    
    -- XP Boost info list
    for rank, multiplier in SortedPairs(XPSystem.Config.RankBoosts) do
        local boostItem = vgui.Create("DPanel", rewardsScroll)
        boostItem:Dock(TOP)
        boostItem:SetHeight(30)
        boostItem:DockMargin(0, 5, 0, 0)
        boostItem.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 55, 200))
            draw.SimpleText(rank:upper(), "XPSystem_Rank", 10, h/2, Color(220, 180, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("+" .. math.floor((multiplier - 1) * 100) .. "% XP Boost", "XPSystem_XP", w - 10, h/2, Color(100, 220, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    
    -- Add admin tab if player is admin
    if ply:IsAdmin() or ply:IsSuperAdmin() then
        local adminPanel = vgui.Create("DPanel", tabPanel)
        adminPanel:Dock(FILL)
        adminPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 200))
        end
        
        -- Admin controls
        local adminControls = vgui.Create("DPanel", adminPanel)
        adminControls:Dock(TOP)
        adminControls:SetHeight(80)
        adminControls:DockMargin(10, 10, 10, 10)
        adminControls.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(60, 50, 50, 200))
            draw.SimpleText("Admin Controls", "XPSystem_Rank", 10, 10, Color(255, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        
        -- Open admin menu button
        local adminMenuBtn = vgui.Create("DButton", adminControls)
        adminMenuBtn:SetPos(10, 35)
        adminMenuBtn:SetSize(200, 30)
        adminMenuBtn:SetText("Open Admin Menu")
        adminMenuBtn:SetFont("XPSystem_Rank")
        adminMenuBtn.DoClick = function()
            net.Start("XPSystem_OpenAdminMenu")
            net.SendToServer()
            frame:Close()
        end
        
        tabPanel:AddSheet("Admin", adminPanel, "icon16/shield.png")
    end
    
    tabPanel:AddSheet("Stats", statsPanel, "icon16/chart_bar.png")
    tabPanel:AddSheet("Rewards", rewardsPanel, "icon16/star.png")
end

-- Register console command to open the menu
concommand.Add("xp_menu", function(ply, cmd, args)
    XPSystem.Menu.Open()
end)

-- Network message to open the menu
net.Receive("XPSystem_OpenMenu", function()
    XPSystem.Menu.Open()
end)

-- Admin menu (will only open if player is authorized)
net.Receive("XPSystem_OpenAdminMenu", function()
    local isAuthorized = net.ReadBool()
    if not isAuthorized then return end
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(800, 600)
    frame:Center()
    frame:SetTitle("XP System - Admin Panel")
    frame:SetDraggable(true)
    frame:SetSizable(false)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 50, 240))
    end
    
    -- Create tabs
    local tabPanel = vgui.Create("DPropertySheet", frame)
    tabPanel:Dock(FILL)
    tabPanel:DockMargin(5, 5, 5, 5)
    
    -- Player management tab
    local playerPanel = vgui.Create("DPanel", tabPanel)
    playerPanel:Dock(FILL)
    playerPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 55, 200))
    end
    
    -- Player list
    local playerList = vgui.Create("DListView", playerPanel)
    playerList:Dock(LEFT)
    playerList:SetWidth(300)
    playerList:DockMargin(10, 10, 10, 10)
    playerList:AddColumn("Player")
    playerList:AddColumn("Level")
    playerList:AddColumn("Prestige")
    
    -- Populate player list
    for _, ply in pairs(player.GetAll()) do
        playerList:AddLine(
            ply:Nick(), 
            ply:GetNWInt("XPSystem_Level", 1), 
            ply:GetNWInt("XPSystem_Prestige", 0)
        )
    end
    
    -- Player actions panel
    local actionsPanel = vgui.Create("DPanel", playerPanel)
    actionsPanel:Dock(FILL)
    actionsPanel:DockMargin(0, 10, 10, 10)
    actionsPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(55, 55, 60, 200))
    end
    
    -- Player info
    local selectedPlayerLabel = vgui.Create("DLabel", actionsPanel)
    selectedPlayerLabel:SetPos(10, 10)
    selectedPlayerLabel:SetSize(actionsPanel:GetWide() - 20, 30)
    selectedPlayerLabel:SetFont("XPSystem_Rank")
    selectedPlayerLabel:SetText("Select a player from the list")
    selectedPlayerLabel:SetTextColor(Color(220, 220, 220))
    
    -- Actions
    local addXPBtn = vgui.Create("DButton", actionsPanel)
    addXPBtn:SetPos(10, 50)
    addXPBtn:SetSize(200, 30)
    addXPBtn:SetText("Add XP")
    addXPBtn:SetFont("XPSystem_XP")
    addXPBtn:SetEnabled(false)
    
    local setLevelBtn = vgui.Create("DButton", actionsPanel)
    setLevelBtn:SetPos(10, 90)
    setLevelBtn:SetSize(200, 30)
    setLevelBtn:SetText("Set Level")
    setLevelBtn:SetFont("XPSystem_XP")
    setLevelBtn:SetEnabled(false)
    
    local setPrestigeBtn = vgui.Create("DButton", actionsPanel)
    setPrestigeBtn:SetPos(10, 130)
    setPrestigeBtn:SetSize(200, 30)
    setPrestigeBtn:SetText("Set Prestige")
    setPrestigeBtn:SetFont("XPSystem_XP")
    setPrestigeBtn:SetEnabled(false)
    
    local resetPlayerBtn = vgui.Create("DButton", actionsPanel)
    resetPlayerBtn:SetPos(10, 180)
    resetPlayerBtn:SetSize(200, 30)
    resetPlayerBtn:SetText("Reset Player Data")
    resetPlayerBtn:SetFont("XPSystem_XP")
    resetPlayerBtn:SetEnabled(false)
    
    -- Handle player selection
    local selectedPlayer = nil
    playerList.OnRowSelected = function(lst, index, pnl)
        local ply = player.GetAll()[index]
        if not IsValid(ply) then return end
        
        selectedPlayer = ply
        selectedPlayerLabel:SetText("Selected: " .. ply:Nick())
        
        addXPBtn:SetEnabled(true)
        setLevelBtn:SetEnabled(true)
        setPrestigeBtn:SetEnabled(true)
        resetPlayerBtn:SetEnabled(true)
    end
    
    -- Button actions
    addXPBtn.DoClick = function()
        if not IsValid(selectedPlayer) then return end
        
        Derma_StringRequest(
            "Add XP",
            "Enter amount of XP to add to " .. selectedPlayer:Nick(),
            "100",
            function(amount)
                amount = tonumber(amount)
                if not amount then return end
                
                net.Start("XPSystem_AdminAddXP")
                net.WriteEntity(selectedPlayer)
                net.WriteInt(amount, 32)
                net.SendToServer()
            end
        )
    end
    
    setLevelBtn.DoClick = function()
        if not IsValid(selectedPlayer) then return end
        
        Derma_StringRequest(
            "Set Level",
            "Enter level to set for " .. selectedPlayer:Nick(),
            selectedPlayer:GetNWInt("XPSystem_Level", 1),
            function(amount)
                amount = tonumber(amount)
                if not amount then return end
                
                net.Start("XPSystem_AdminSetLevel")
                net.WriteEntity(selectedPlayer)
                net.WriteInt(amount, 16)
                net.SendToServer()
            end
        )
    end
    
    setPrestigeBtn.DoClick = function()
        if not IsValid(selectedPlayer) then return end
        
        Derma_StringRequest(
            "Set Prestige",
            "Enter prestige level to set for " .. selectedPlayer:Nick(),
            selectedPlayer:GetNWInt("XPSystem_Prestige", 0),
            function(amount)
                amount = tonumber(amount)
                if not amount then return end
                
                net.Start("XPSystem_AdminSetPrestige")
                net.WriteEntity(selectedPlayer)
                net.WriteInt(amount, 16)
                net.SendToServer()
            end
        )
    end
    
    resetPlayerBtn.DoClick = function()
        if not IsValid(selectedPlayer) then return end
        
        Derma_Query(
            "Are you sure you want to reset " .. selectedPlayer:Nick() .. "'s data?",
            "Confirm Reset",
            "Yes, Reset Data",
            function()
                net.Start("XPSystem_AdminResetPlayer")
                net.WriteEntity(selectedPlayer)
                net.SendToServer()
            end,
            "Cancel",
            function() end
        )
    end
    
    -- Rewards tab
    local rewardsPanel = vgui.Create("DPanel", tabPanel)
    rewardsPanel:Dock(FILL)
    rewardsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 55, 200))
    end
    
    -- Create a scroll panel for the rewards
    local rewardsScroll = vgui.Create("DScrollPanel", rewardsPanel)
    rewardsScroll:Dock(FILL)
    rewardsScroll:DockMargin(10, 10, 10, 10)
    
    -- Level rewards section
    local levelRewardsHeader = vgui.Create("DLabel", rewardsScroll)
    levelRewardsHeader:Dock(TOP)
    levelRewardsHeader:SetHeight(30)
    levelRewardsHeader:SetFont("XPSystem_Level")
    levelRewardsHeader:SetText("Level Rewards")
    levelRewardsHeader:SetTextColor(Color(220, 220, 220))
    
    -- Level rewards list
    local levelRewardsListPanel = vgui.Create("DPanel", rewardsScroll)
    levelRewardsListPanel:Dock(TOP)
    levelRewardsListPanel:SetHeight(200)
    levelRewardsListPanel:DockMargin(0, 5, 0, 15)
    levelRewardsListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 200))
    end
    
    -- Level rewards list view
    local levelRewardsList = vgui.Create("DListView", levelRewardsListPanel)
    levelRewardsList:Dock(FILL)
    levelRewardsList:DockMargin(5, 5, 5, 5)
    levelRewardsList:AddColumn("Level")
    levelRewardsList:AddColumn("Currency")
    levelRewardsList:AddColumn("Message")
    
    -- Populate level rewards
    for level, reward in SortedPairs(XPSystem.Config.LevelRewards) do
        levelRewardsList:AddLine(level, reward.currency, reward.message)
    end
    
    -- Level reward edit buttons
    local levelRewardsButtonPanel = vgui.Create("DPanel", rewardsScroll)
    levelRewardsButtonPanel:Dock(TOP)
    levelRewardsButtonPanel:SetHeight(40)
    levelRewardsButtonPanel:DockMargin(0, 0, 0, 20)
    levelRewardsButtonPanel.Paint = function() end
    
    local addLevelRewardBtn = vgui.Create("DButton", levelRewardsButtonPanel)
    addLevelRewardBtn:Dock(LEFT)
    addLevelRewardBtn:SetWidth(180)
    addLevelRewardBtn:DockMargin(0, 0, 10, 0)
    addLevelRewardBtn:SetText("Add Level Reward")
    addLevelRewardBtn:SetFont("XPSystem_XP")
    
    local editLevelRewardBtn = vgui.Create("DButton", levelRewardsButtonPanel)
    editLevelRewardBtn:Dock(LEFT)
    editLevelRewardBtn:SetWidth(180)
    editLevelRewardBtn:DockMargin(0, 0, 10, 0)
    editLevelRewardBtn:SetText("Edit Selected Reward")
    editLevelRewardBtn:SetFont("XPSystem_XP")
    editLevelRewardBtn:SetEnabled(false)
    
    -- Prestige rewards section
    local prestigeRewardsHeader = vgui.Create("DLabel", rewardsScroll)
    prestigeRewardsHeader:Dock(TOP)
    prestigeRewardsHeader:SetHeight(30)
    prestigeRewardsHeader:SetFont("XPSystem_Level")
    prestigeRewardsHeader:SetText("Prestige Rewards")
    prestigeRewardsHeader:SetTextColor(Color(220, 220, 220))
    
    -- Prestige rewards list
    local prestigeRewardsListPanel = vgui.Create("DPanel", rewardsScroll)
    prestigeRewardsListPanel:Dock(TOP)
    prestigeRewardsListPanel:SetHeight(200)
    prestigeRewardsListPanel:DockMargin(0, 5, 0, 15)
    prestigeRewardsListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 200))
    end
    
    -- Prestige rewards list view
    local prestigeRewardsList = vgui.Create("DListView", prestigeRewardsListPanel)
    prestigeRewardsList:Dock(FILL)
    prestigeRewardsList:DockMargin(5, 5, 5, 5)
    prestigeRewardsList:AddColumn("Prestige Level")
    prestigeRewardsList:AddColumn("Currency")
    prestigeRewardsList:AddColumn("Message")
    
    -- Populate prestige rewards
    for level, reward in SortedPairs(XPSystem.Config.PrestigeRewards) do
        prestigeRewardsList:AddLine(level, reward.currency, reward.message)
    end
    
    -- Prestige reward edit buttons
    local prestigeRewardsButtonPanel = vgui.Create("DPanel", rewardsScroll)
    prestigeRewardsButtonPanel:Dock(TOP)
    prestigeRewardsButtonPanel:SetHeight(40)
    prestigeRewardsButtonPanel:DockMargin(0, 0, 0, 10)
    prestigeRewardsButtonPanel.Paint = function() end
    
    local addPrestigeRewardBtn = vgui.Create("DButton", prestigeRewardsButtonPanel)
    addPrestigeRewardBtn:Dock(LEFT)
    addPrestigeRewardBtn:SetWidth(180)
    addPrestigeRewardBtn:DockMargin(0, 0, 10, 0)
    addPrestigeRewardBtn:SetText("Add Prestige Reward")
    addPrestigeRewardBtn:SetFont("XPSystem_XP")
    
    local editPrestigeRewardBtn = vgui.Create("DButton", prestigeRewardsButtonPanel)
    editPrestigeRewardBtn:Dock(LEFT)
    editPrestigeRewardBtn:SetWidth(180)
    editPrestigeRewardBtn:DockMargin(0, 0, 10, 0)
    editPrestigeRewardBtn:SetText("Edit Selected Reward")
    editPrestigeRewardBtn:SetFont("XPSystem_XP")
    editPrestigeRewardBtn:SetEnabled(false)
    
    -- Handle level reward selection
    local selectedLevelReward = nil
    levelRewardsList.OnRowSelected = function(lst, index, pnl)
        selectedLevelReward = {
            level = tonumber(pnl:GetValue(1)),
            currency = tonumber(pnl:GetValue(2)),
            message = pnl:GetValue(3)
        }
        editLevelRewardBtn:SetEnabled(true)
    end
    
    -- Handle prestige reward selection
    local selectedPrestigeReward = nil
    prestigeRewardsList.OnRowSelected = function(lst, index, pnl)
        selectedPrestigeReward = {
            level = tonumber(pnl:GetValue(1)),
            currency = tonumber(pnl:GetValue(2)),
            message = pnl:GetValue(3)
        }
        editPrestigeRewardBtn:SetEnabled(true)
    end
    
    -- Add level reward button
    addLevelRewardBtn.DoClick = function()
        local addFrame = vgui.Create("DFrame")
        addFrame:SetSize(350, 200)
        addFrame:Center()
        addFrame:SetTitle("Add Level Reward")
        addFrame:MakePopup()
        
        -- Level input
        local levelLabel = vgui.Create("DLabel", addFrame)
        levelLabel:SetPos(10, 30)
        levelLabel:SetSize(100, 20)
        levelLabel:SetText("Level:")
        
        local levelInput = vgui.Create("DNumberWang", addFrame)
        levelInput:SetPos(120, 30)
        levelInput:SetSize(200, 20)
        levelInput:SetMin(1)
        levelInput:SetMax(XPSystem.Config.MaxLevel)
        levelInput:SetValue(5)
        
        -- Currency input
        local currencyLabel = vgui.Create("DLabel", addFrame)
        currencyLabel:SetPos(10, 60)
        currencyLabel:SetSize(100, 20)
        currencyLabel:SetText("Currency Amount:")
        
        local currencyInput = vgui.Create("DNumberWang", addFrame)
        currencyInput:SetPos(120, 60)
        currencyInput:SetSize(200, 20)
        currencyInput:SetMin(0)
        currencyInput:SetMax(1000000)
        currencyInput:SetValue(1000)
        
        -- Message input
        local messageLabel = vgui.Create("DLabel", addFrame)
        messageLabel:SetPos(10, 90)
        messageLabel:SetSize(100, 20)
        messageLabel:SetText("Message:")
        
        local messageInput = vgui.Create("DTextEntry", addFrame)
        messageInput:SetPos(120, 90)
        messageInput:SetSize(200, 20)
        messageInput:SetValue("Level up reward!")
        
        -- Save button
        local saveBtn = vgui.Create("DButton", addFrame)
        saveBtn:SetPos(120, 130)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local level = levelInput:GetValue()
            local currency = currencyInput:GetValue()
            local message = messageInput:GetValue()
            
            net.Start("XPSystem_AdminSetLevelReward")
            net.WriteInt(level, 16)
            net.WriteInt(currency, 32)
            net.WriteString(message)
            net.SendToServer()
            
            addFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Edit level reward button
    editLevelRewardBtn.DoClick = function()
        if not selectedLevelReward then return end
        
        local editFrame = vgui.Create("DFrame")
        editFrame:SetSize(350, 200)
        editFrame:Center()
        editFrame:SetTitle("Edit Level Reward")
        editFrame:MakePopup()
        
        -- Level display (read-only)
        local levelLabel = vgui.Create("DLabel", editFrame)
        levelLabel:SetPos(10, 30)
        levelLabel:SetSize(100, 20)
        levelLabel:SetText("Level:")
        
        local levelDisplay = vgui.Create("DLabel", editFrame)
        levelDisplay:SetPos(120, 30)
        levelDisplay:SetSize(200, 20)
        levelDisplay:SetText(selectedLevelReward.level)
        
        -- Currency input
        local currencyLabel = vgui.Create("DLabel", editFrame)
        currencyLabel:SetPos(10, 60)
        currencyLabel:SetSize(100, 20)
        currencyLabel:SetText("Currency Amount:")
        
        local currencyInput = vgui.Create("DNumberWang", editFrame)
        currencyInput:SetPos(120, 60)
        currencyInput:SetSize(200, 20)
        currencyInput:SetMin(0)
        currencyInput:SetMax(1000000)
        currencyInput:SetValue(selectedLevelReward.currency)
        
        -- Message input
        local messageLabel = vgui.Create("DLabel", editFrame)
        messageLabel:SetPos(10, 90)
        messageLabel:SetSize(100, 20)
        messageLabel:SetText("Message:")
        
        local messageInput = vgui.Create("DTextEntry", editFrame)
        messageInput:SetPos(120, 90)
        messageInput:SetSize(200, 20)
        messageInput:SetValue(selectedLevelReward.message)
        
        -- Save button
        local saveBtn = vgui.Create("DButton", editFrame)
        saveBtn:SetPos(120, 130)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local level = selectedLevelReward.level
            local currency = currencyInput:GetValue()
            local message = messageInput:GetValue()
            
            net.Start("XPSystem_AdminSetLevelReward")
            net.WriteInt(level, 16)
            net.WriteInt(currency, 32)
            net.WriteString(message)
            net.SendToServer()
            
            editFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Add prestige reward button
    addPrestigeRewardBtn.DoClick = function()
        local addFrame = vgui.Create("DFrame")
        addFrame:SetSize(350, 200)
        addFrame:Center()
        addFrame:SetTitle("Add Prestige Reward")
        addFrame:MakePopup()
        
        -- Level input
        local levelLabel = vgui.Create("DLabel", addFrame)
        levelLabel:SetPos(10, 30)
        levelLabel:SetSize(100, 20)
        levelLabel:SetText("Prestige Level:")
        
        local levelInput = vgui.Create("DNumberWang", addFrame)
        levelInput:SetPos(120, 30)
        levelInput:SetSize(200, 20)
        levelInput:SetMin(1)
        levelInput:SetMax(XPSystem.Config.MaxPrestige)
        levelInput:SetValue(1)
        
        -- Currency input
        local currencyLabel = vgui.Create("DLabel", addFrame)
        currencyLabel:SetPos(10, 60)
        currencyLabel:SetSize(100, 20)
        currencyLabel:SetText("Currency Amount:")
        
        local currencyInput = vgui.Create("DNumberWang", addFrame)
        currencyInput:SetPos(120, 60)
        currencyInput:SetSize(200, 20)
        currencyInput:SetMin(0)
        currencyInput:SetMax(10000000)
        currencyInput:SetValue(100000)
        
        -- Message input
        local messageLabel = vgui.Create("DLabel", addFrame)
        messageLabel:SetPos(10, 90)
        messageLabel:SetSize(100, 20)
        messageLabel:SetText("Message:")
        
        local messageInput = vgui.Create("DTextEntry", addFrame)
        messageInput:SetPos(120, 90)
        messageInput:SetSize(200, 20)
        messageInput:SetValue("Prestige reward!")
        
        -- Save button
        local saveBtn = vgui.Create("DButton", addFrame)
        saveBtn:SetPos(120, 130)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local level = levelInput:GetValue()
            local currency = currencyInput:GetValue()
            local message = messageInput:GetValue()
            
            net.Start("XPSystem_AdminSetPrestigeReward")
            net.WriteInt(level, 16)
            net.WriteInt(currency, 32)
            net.WriteString(message)
            net.SendToServer()
            
            addFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Edit prestige reward button
    editPrestigeRewardBtn.DoClick = function()
        if not selectedPrestigeReward then return end
        
        local editFrame = vgui.Create("DFrame")
        editFrame:SetSize(350, 200)
        editFrame:Center()
        editFrame:SetTitle("Edit Prestige Reward")
        editFrame:MakePopup()
        
        -- Level display (read-only)
        local levelLabel = vgui.Create("DLabel", editFrame)
        levelLabel:SetPos(10, 30)
        levelLabel:SetSize(100, 20)
        levelLabel:SetText("Prestige Level:")
        
        local levelDisplay = vgui.Create("DLabel", editFrame)
        levelDisplay:SetPos(120, 30)
        levelDisplay:SetSize(200, 20)
        levelDisplay:SetText(selectedPrestigeReward.level)
        
        -- Currency input
        local currencyLabel = vgui.Create("DLabel", editFrame)
        currencyLabel:SetPos(10, 60)
        currencyLabel:SetSize(100, 20)
        currencyLabel:SetText("Currency Amount:")
        
        local currencyInput = vgui.Create("DNumberWang", editFrame)
        currencyInput:SetPos(120, 60)
        currencyInput:SetSize(200, 20)
        currencyInput:SetMin(0)
        currencyInput:SetMax(10000000)
        currencyInput:SetValue(selectedPrestigeReward.currency)
        
        -- Message input
        local messageLabel = vgui.Create("DLabel", editFrame)
        messageLabel:SetPos(10, 90)
        messageLabel:SetSize(100, 20)
        messageLabel:SetText("Message:")
        
        local messageInput = vgui.Create("DTextEntry", editFrame)
        messageInput:SetPos(120, 90)
        messageInput:SetSize(200, 20)
        messageInput:SetValue(selectedPrestigeReward.message)
        
        -- Save button
        local saveBtn = vgui.Create("DButton", editFrame)
        saveBtn:SetPos(120, 130)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local level = selectedPrestigeReward.level
            local currency = currencyInput:GetValue()
            local message = messageInput:GetValue()
            
            net.Start("XPSystem_AdminSetPrestigeReward")
            net.WriteInt(level, 16)
            net.WriteInt(currency, 32)
            net.WriteString(message)
            net.SendToServer()
            
            editFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Settings tab
    local settingsPanel = vgui.Create("DPanel", tabPanel)
    settingsPanel:Dock(FILL)
    settingsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 55, 200))
    end
    
    -- General settings scroll
    local settingsScroll = vgui.Create("DScrollPanel", settingsPanel)
    settingsScroll:Dock(FILL)
    settingsScroll:DockMargin(10, 10, 10, 10)
    
    -- Settings header
    local settingsHeader = vgui.Create("DLabel", settingsScroll)
    settingsHeader:Dock(TOP)
    settingsHeader:SetHeight(30)
    settingsHeader:SetFont("XPSystem_Level")
    settingsHeader:SetText("General Settings")
    settingsHeader:SetTextColor(Color(220, 220, 220))
    
    -- General settings form
    local generalSettingsForm = vgui.Create("DForm", settingsScroll)
    generalSettingsForm:Dock(TOP)
    generalSettingsForm:SetName("XP System Settings")
    generalSettingsForm:DockMargin(0, 10, 0, 10)
    
    -- Max level setting
    local maxLevelSlider = generalSettingsForm:NumSlider("Maximum Level", nil, 10, 500, 0)
    maxLevelSlider:SetValue(XPSystem.Config.MaxLevel)
    
    -- Max prestige setting
    local maxPrestigeSlider = generalSettingsForm:NumSlider("Maximum Prestige", nil, 1, 100, 0)
    maxPrestigeSlider:SetValue(XPSystem.Config.MaxPrestige)
    
    -- Base XP setting
    local baseXPSlider = generalSettingsForm:NumSlider("Base XP", nil, 50, 1000, 0)
    baseXPSlider:SetValue(XPSystem.Config.BaseXP)
    
    -- XP Multiplier setting
    local xpMultiplierSlider = generalSettingsForm:NumSlider("XP Multiplier", nil, 1.01, 2.0, 2)
    xpMultiplierSlider:SetValue(XPSystem.Config.XPMultiplier)
    
    -- Save general settings button
    local saveGeneralSettingsBtn = vgui.Create("DButton", settingsScroll)
    saveGeneralSettingsBtn:Dock(TOP)
    saveGeneralSettingsBtn:SetHeight(30)
    saveGeneralSettingsBtn:SetText("Save General Settings")
    saveGeneralSettingsBtn:DockMargin(0, 10, 0, 20)
    
    saveGeneralSettingsBtn.DoClick = function()
        -- Get values from form
        local maxLevel = math.Round(maxLevelSlider:GetValue())
        local maxPrestige = math.Round(maxPrestigeSlider:GetValue())
        local baseXP = math.Round(baseXPSlider:GetValue())
        local xpMultiplier = xpMultiplierSlider:GetValue()
        
        -- Send to server
        net.Start("XPSystem_AdminSetGeneralSettings")
        net.WriteInt(maxLevel, 16)
        net.WriteInt(maxPrestige, 16)
        net.WriteInt(baseXP, 16)
        net.WriteFloat(xpMultiplier)
        net.SendToServer()
        
        -- Notify user
        Derma_Message("General settings saved!", "Settings", "OK")
    end
    
    -- HUD settings header
    local hudSettingsHeader = vgui.Create("DLabel", settingsScroll)
    hudSettingsHeader:Dock(TOP)
    hudSettingsHeader:SetHeight(30)
    hudSettingsHeader:SetFont("XPSystem_Level")
    hudSettingsHeader:SetText("HUD Settings")
    hudSettingsHeader:SetTextColor(Color(220, 220, 220))
    
    -- HUD settings form
    local hudSettingsForm = vgui.Create("DForm", settingsScroll)
    hudSettingsForm:Dock(TOP)
    hudSettingsForm:SetName("XP HUD Settings")
    hudSettingsForm:DockMargin(0, 10, 0, 10)
    
    -- Width setting
    local widthSlider = hudSettingsForm:NumSlider("Width", nil, 200, 1000, 0)
    widthSlider:SetValue(XPSystem.Config.HUD.Width)
    
    -- Height setting
    local heightSlider = hudSettingsForm:NumSlider("Height", nil, 5, 30, 0)
    heightSlider:SetValue(XPSystem.Config.HUD.Height)
    
    -- Bottom margin setting
    local marginSlider = hudSettingsForm:NumSlider("Bottom Margin", nil, 10, 200, 0)
    marginSlider:SetValue(XPSystem.Config.HUD.BottomMargin)
    
    -- Rounded corners setting
    local roundedSlider = hudSettingsForm:NumSlider("Rounded Corners", nil, 0, 16, 0)
    roundedSlider:SetValue(XPSystem.Config.HUD.Rounded)
    
    -- Always show HUD checkbox
    local showAlwaysCheckbox = hudSettingsForm:CheckBox("Always Show HUD")
    showAlwaysCheckbox:SetValue(XPSystem.Config.HUD.ShowAlways)
    
    -- Fade time setting
    local fadeTimeSlider = hudSettingsForm:NumSlider("Fade Time (seconds)", nil, 1, 10, 1)
    fadeTimeSlider:SetValue(XPSystem.Config.HUD.FadeTime)
    
    -- Save HUD settings button
    local saveHUDSettingsBtn = vgui.Create("DButton", settingsScroll)
    saveHUDSettingsBtn:Dock(TOP)
    saveHUDSettingsBtn:SetHeight(30)
    saveHUDSettingsBtn:SetText("Save HUD Settings")
    saveHUDSettingsBtn:DockMargin(0, 10, 0, 20)
    
    saveHUDSettingsBtn.DoClick = function()
        -- Get values from form
        local width = math.Round(widthSlider:GetValue())
        local height = math.Round(heightSlider:GetValue())
        local margin = math.Round(marginSlider:GetValue())
        local rounded = math.Round(roundedSlider:GetValue())
        local showAlways = showAlwaysCheckbox:GetChecked()
        local fadeTime = fadeTimeSlider:GetValue()
        
        -- Send to server
        net.Start("XPSystem_AdminSetHUDSettings")
        net.WriteInt(width, 16)
        net.WriteInt(height, 16)
        net.WriteInt(margin, 16)
        net.WriteInt(rounded, 8)
        net.WriteBool(showAlways)
        net.WriteFloat(fadeTime)
        net.SendToServer()
        
        -- Notify user
        Derma_Message("HUD settings saved!", "Settings", "OK")
    end
    
    -- XP Boosts header
    local boostsHeader = vgui.Create("DLabel", settingsScroll)
    boostsHeader:Dock(TOP)
    boostsHeader:SetHeight(30)
    boostsHeader:SetFont("XPSystem_Level")
    boostsHeader:SetText("Rank XP Boosts")
    boostsHeader:SetTextColor(Color(220, 220, 220))
    
    -- Rank boosts list
    local boostsList = vgui.Create("DListView", settingsScroll)
    boostsList:Dock(TOP)
    boostsList:SetHeight(150)
    boostsList:DockMargin(0, 10, 0, 10)
    boostsList:AddColumn("Rank")
    boostsList:AddColumn("XP Boost")
    
    -- Populate boosts list
    for rank, multiplier in pairs(XPSystem.Config.RankBoosts) do
        boostsList:AddLine(rank, math.floor((multiplier - 1) * 100) .. "%")
    end
    
    -- Rank boost edit buttons
    local boostButtonPanel = vgui.Create("DPanel", settingsScroll)
    boostButtonPanel:Dock(TOP)
    boostButtonPanel:SetHeight(40)
    boostButtonPanel:DockMargin(0, 0, 0, 10)
    boostButtonPanel.Paint = function() end
    
    local addBoostBtn = vgui.Create("DButton", boostButtonPanel)
    addBoostBtn:Dock(LEFT)
    addBoostBtn:SetWidth(150)
    addBoostBtn:DockMargin(0, 0, 10, 0)
    addBoostBtn:SetText("Add Rank Boost")
    
    local editBoostBtn = vgui.Create("DButton", boostButtonPanel)
    editBoostBtn:Dock(LEFT)
    editBoostBtn:SetWidth(150)
    editBoostBtn:DockMargin(0, 0, 10, 0)
    editBoostBtn:SetText("Edit Selected Boost")
    editBoostBtn:SetEnabled(false)
    
    -- Handle boost selection
    local selectedBoost = nil
    boostsList.OnRowSelected = function(lst, index, pnl)
        selectedBoost = {
            rank = pnl:GetValue(1),
            boost = pnl:GetValue(2)
        }
        editBoostBtn:SetEnabled(true)
    end
    
    -- Add boost button
    addBoostBtn.DoClick = function()
        local addFrame = vgui.Create("DFrame")
        addFrame:SetSize(300, 150)
        addFrame:Center()
        addFrame:SetTitle("Add Rank Boost")
        addFrame:MakePopup()
        
        -- Rank input
        local rankLabel = vgui.Create("DLabel", addFrame)
        rankLabel:SetPos(10, 30)
        rankLabel:SetSize(100, 20)
        rankLabel:SetText("Rank Name:")
        
        local rankInput = vgui.Create("DTextEntry", addFrame)
        rankInput:SetPos(120, 30)
        rankInput:SetSize(160, 20)
        rankInput:SetValue("VIP")
        
        -- Boost input
        local boostLabel = vgui.Create("DLabel", addFrame)
        boostLabel:SetPos(10, 60)
        boostLabel:SetSize(100, 20)
        boostLabel:SetText("Boost Percentage:")
        
        local boostInput = vgui.Create("DNumberWang", addFrame)
        boostInput:SetPos(120, 60)
        boostInput:SetSize(160, 20)
        boostInput:SetMin(1)
        boostInput:SetMax(200)
        boostInput:SetValue(15)
        
        -- Save button
        local saveBtn = vgui.Create("DButton", addFrame)
        saveBtn:SetPos(100, 100)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local rank = rankInput:GetValue()
            local boost = boostInput:GetValue() / 100 + 1
            
            net.Start("XPSystem_AdminSetRankBoost")
            net.WriteString(rank)
            net.WriteFloat(boost)
            net.SendToServer()
            
            addFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Edit boost button
    editBoostBtn.DoClick = function()
        if not selectedBoost then return end
        
        local boostValue = tonumber(string.match(selectedBoost.boost, "(%d+)"))
        
        local editFrame = vgui.Create("DFrame")
        editFrame:SetSize(300, 150)
        editFrame:Center()
        editFrame:SetTitle("Edit Rank Boost")
        editFrame:MakePopup()
        
        -- Rank display
        local rankLabel = vgui.Create("DLabel", editFrame)
        rankLabel:SetPos(10, 30)
        rankLabel:SetSize(100, 20)
        rankLabel:SetText("Rank Name:")
        
        local rankDisplay = vgui.Create("DLabel", editFrame)
        rankDisplay:SetPos(120, 30)
        rankDisplay:SetSize(160, 20)
        rankDisplay:SetText(selectedBoost.rank)
        
        -- Boost input
        local boostLabel = vgui.Create("DLabel", editFrame)
        boostLabel:SetPos(10, 60)
        boostLabel:SetSize(100, 20)
        boostLabel:SetText("Boost Percentage:")
        
        local boostInput = vgui.Create("DNumberWang", editFrame)
        boostInput:SetPos(120, 60)
        boostInput:SetSize(160, 20)
        boostInput:SetMin(1)
        boostInput:SetMax(200)
        boostInput:SetValue(boostValue)
        
        -- Save button
        local saveBtn = vgui.Create("DButton", editFrame)
        saveBtn:SetPos(100, 100)
        saveBtn:SetSize(100, 30)
        saveBtn:SetText("Save")
        saveBtn.DoClick = function()
            local rank = selectedBoost.rank
            local boost = boostInput:GetValue() / 100 + 1
            
            net.Start("XPSystem_AdminSetRankBoost")
            net.WriteString(rank)
            net.WriteFloat(boost)
            net.SendToServer()
            
            editFrame:Close()
            
            -- Refresh the list after a short delay
            timer.Simple(0.5, function()
                if IsValid(frame) then
                    frame:Close()
                    net.Start("XPSystem_OpenAdminMenu")
                    net.SendToServer()
                end
            end)
        end
    end
    
    -- Add tabs
    tabPanel:AddSheet("Players", playerPanel, "icon16/user.png")
    tabPanel:AddSheet("Rewards", rewardsPanel, "icon16/star.png")
    tabPanel:AddSheet("Settings", settingsPanel, "icon16/cog.png")
end)