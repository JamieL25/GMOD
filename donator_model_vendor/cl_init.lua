-- cl_init.lua for donator_vendor entity
-- Created: 2025-05-25 19:51:38 by JamieL25
-- Updated: 2025-05-25 21:28:52 by JamieL25
-- Part 1: Main functionality

include("shared.lua")
include("cl_admin.lua")

print("--- [NPC DonatorModelVendor SCRIPT] cl_init.lua is being loaded by CLIENT ---")

-- Create bold font for the vendor
surface.CreateFont("DonatorNPCText_Bold", {
    font = "DermaLarge",
    size = 40,
    weight = 800,  -- This makes it bold
    antialias = true,
    shadow = false
})

-- ========================================================================================
-- CONFIGURATION
-- ========================================================================================

-- UI SCALING FACTOR - Makes everything bigger while keeping proportions
local UI_SCALE = 1.3 -- 30% larger than original

local COLOR_BACKGROUND = Color(40, 40, 40, 230)
local COLOR_HEADER = Color(30, 30, 30, 250)
local COLOR_BUTTON = Color(50, 100, 150, 200)
local COLOR_BUTTON_HOVER = Color(70, 120, 170, 200)
local COLOR_BUTTON_DISABLED = Color(30, 70, 100, 150)
local COLOR_SUCCESS = Color(50, 200, 50, 255)
local COLOR_ERROR = Color(200, 50, 50, 255)

-- Tab colors for different ranks
local TAB_COLORS = {
    ["VIP"] = Color(50, 150, 50, 200),
    ["VIP+"] = Color(150, 150, 50, 200),
    ["Legend"] = Color(150, 50, 50, 200),
    ["Admin"] = Color(80, 60, 200, 200)
}

-- Local variables for menu state
local availableModels = {}
local accessibleTabs = {}
local vendorEntity = nil
local isAdminAccess = false
local selectedTab = nil
local selectedModel = nil
local playerBalance = 0

-- ========================================================================================
-- UTILITY FUNCTIONS
-- ========================================================================================

-- Scale sizes based on UI_SCALE
local function scaleSize(size)
    return math.Round(size * UI_SCALE)
end

-- Play a sound
local function playSound(soundPath)
    surface.PlaySound(soundPath)
end

-- Create a notification
local function createNotification(message, color)
    local notification = vgui.Create("DPanel")
    notification:SetSize(scaleSize(300), scaleSize(40))
    notification:SetPos(ScrW() / 2 - scaleSize(150), ScrH() - scaleSize(100))
    notification.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, color)
        draw.SimpleText(message, "DermaDefault", w / 2, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    notification:MoveTo(ScrW() / 2 - scaleSize(150), ScrH() - scaleSize(100) - scaleSize(50), 0.5, 0, -1)
    
    timer.Simple(3, function()
        if IsValid(notification) then
            notification:AlphaTo(0, 0.5, 0, function()
                if IsValid(notification) then
                    notification:Remove()
                end
            end)
        end
    end)
end

-- Format currency
local function formatCurrency(amount)
    return string.Comma(amount) .. " credits"
end

-- ========================================================================================
-- MAIN MENU
-- ========================================================================================

-- Function to refresh model list based on selected tab
function refreshModelList(modelListPanel, modelPreview, filterText)
    if not IsValid(modelListPanel) then return end
    
    -- Clear the list
    modelListPanel:Clear()
    
    -- If admin tab or no tab selected, don't show models
    if selectedTab == "Admin" or not selectedTab then
        return
    end
    
    -- Create model layout
    local modelLayout = vgui.Create("DIconLayout", modelListPanel)
    modelLayout:Dock(FILL)
    modelLayout:SetSpaceY(scaleSize(5))
    modelLayout:SetSpaceX(scaleSize(5))
    
    -- Filter models by selected tab/rank
    local filteredModels = {}
    for _, modelData in ipairs(availableModels) do
        if modelData.Rank == selectedTab then
            table.insert(filteredModels, modelData)
        end
    end
    
    -- Further filter by search text if provided
    if filterText and filterText != "" then
        local lowerFilter = string.lower(filterText)
        local tempFiltered = {}
        
        for _, modelData in ipairs(filteredModels) do
            if string.find(string.lower(modelData.Name), lowerFilter) then
                table.insert(tempFiltered, modelData)
            end
        end
        
        filteredModels = tempFiltered
    end
    
    -- Sort models by name
    table.sort(filteredModels, function(a, b)
        return a.Name < b.Name
    end)
    
    -- Add models to layout
    for i, modelData in ipairs(filteredModels) do
        -- Model panel with frame
        local modelFrame = modelLayout:Add("DPanel")
        modelFrame:SetSize(scaleSize(120), scaleSize(180))
        modelFrame.Paint = function(self, w, h)
            local frameColor = selectedModel and selectedModel.Model == modelData.Model 
                and Color(255, 200, 0, 100) or Color(30, 30, 30, 100)
            draw.RoundedBox(4, 0, 0, w, h, frameColor)
        end
        
        -- Model preview
        local modelPanel = vgui.Create("DModelPanel", modelFrame)
        modelPanel:SetSize(scaleSize(110), scaleSize(130))
        modelPanel:SetPos(scaleSize(5), scaleSize(5))
        modelPanel:SetModel(modelData.Model)
        modelPanel:SetCamPos(Vector(25, 0, 45))
        modelPanel:SetLookAt(Vector(0, 0, 40))
        modelPanel:SetTooltip(modelData.Name)
        
        -- Auto-adjust camera to fit model
        local mn, mx = modelPanel.Entity:GetRenderBounds()
        local size = 0
        size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
        size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
        size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
        
        modelPanel:SetFOV(45)
        modelPanel:SetCamPos(Vector(size * 1.1, 0, size * 0.5))
        modelPanel:SetLookAt((mn + mx) * 0.5)
        
        -- Name label
        local nameLabel = vgui.Create("DLabel", modelFrame)
        nameLabel:SetText(modelData.Name)
        nameLabel:SetFont("DermaDefault")
        nameLabel:SetTextColor(color_white)
        nameLabel:SetContentAlignment(5) -- Center
        nameLabel:Dock(TOP)
        nameLabel:DockMargin(0, scaleSize(140), 0, 0)
        nameLabel:SetHeight(scaleSize(20))
        nameLabel:SetExpensiveShadow(1, Color(0, 0, 0, 200))
        
        -- Price label
        local priceColor = playerBalance >= (modelData.Price or donator_vendor.DEFAULT_PRICE)
            and Color(50, 200, 50) or Color(200, 50, 50)
            
        local priceLabel = vgui.Create("DLabel", modelFrame)
        priceLabel:SetText(formatCurrency(modelData.Price or donator_vendor.DEFAULT_PRICE))
        priceLabel:SetFont("DermaDefault")
        priceLabel:SetTextColor(priceColor)
        priceLabel:SetContentAlignment(5) -- Center
        priceLabel:Dock(TOP)
        priceLabel:DockMargin(0, 0, 0, 0)
        priceLabel:SetHeight(scaleSize(20))
        priceLabel:SetExpensiveShadow(1, Color(0, 0, 0, 200))
        
        modelFrame:SetTooltip(modelData.Name .. "\nPrice: " .. formatCurrency(modelData.Price or donator_vendor.DEFAULT_PRICE))
        
        modelPanel.DoClick = function()
            selectedModel = modelData
            
            -- Update model preview
            if IsValid(modelPreview) then
                modelPreview:SetModel(modelData.Model)
                
                -- Auto-adjust camera to fit model
                local mn, mx = modelPreview.Entity:GetRenderBounds()
                local size = 0
                size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
                size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
                size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
                
                modelPreview:SetFOV(45)
                modelPreview:SetCamPos(Vector(size * 1.1, 0, size * 0.5))
                modelPreview:SetLookAt((mn + mx) * 0.5)
            end
            
            -- Update info text
            local infoPanel = modelPreview:GetParent()
            if IsValid(infoPanel) then
                local infoLabel = infoPanel:GetChildren()[3] -- Info label
                if IsValid(infoLabel) then
                    infoLabel:SetText("Model: " .. modelData.Name .. " (Rank: " .. modelData.Rank .. ")")
                end
                
                local priceLabel = infoPanel:GetChildren()[4] -- Price label
                if IsValid(priceLabel) then
                    local priceColor = playerBalance >= (modelData.Price or donator_vendor.DEFAULT_PRICE)
                        and Color(50, 200, 50) or Color(200, 50, 50)
                    priceLabel:SetText("Price: " .. formatCurrency(modelData.Price or donator_vendor.DEFAULT_PRICE))
                    priceLabel:SetTextColor(priceColor)
                end
                
                -- Enable purchase button if player has enough money
                local purchaseButton = infoPanel:GetChildren()[1] -- Purchase button
                if IsValid(purchaseButton) then
                    purchaseButton:SetEnabled(playerBalance >= (modelData.Price or donator_vendor.DEFAULT_PRICE))
                end
                
                -- Enable equip button for admins
                local equipButton = infoPanel:GetChildren()[2] -- Equip button
                if IsValid(equipButton) then
                    equipButton:SetEnabled(true)
                end
            end
            
            playSound("ui/buttonclickrelease.wav")
            
            -- Force layout refresh to show selection
            modelLayout:Layout()
        end
        
        -- Click on frame also selects the model
        modelFrame.DoClick = function()
            modelPanel:DoClick()
        end
    end
end

-- Create the model menu
function createModelMenu()
    -- Close any existing menu
    if IsValid(_G.DonatorVendorMenu) then
        _G.DonatorVendorMenu:Remove()
    end
    
    -- Set the first tab as default if none selected
    if not selectedTab and #accessibleTabs > 0 then
        selectedTab = accessibleTabs[1]
    end
    
    -- Reset selected model
    selectedModel = nil
    
    -- Create the main menu frame
    local frame = vgui.Create("DFrame")
    frame:SetSize(scaleSize(1000), scaleSize(700))
    frame:Center()
    frame:SetTitle("Donator Model Vendor")
    frame:SetDraggable(true)
    frame:SetSizable(false)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BACKGROUND)
        draw.RoundedBox(8, 0, 0, w, scaleSize(25), COLOR_HEADER)
    end
    
    -- Store globally for easy access
    _G.DonatorVendorMenu = frame
    
    -- Create main panel
    local mainPanel = vgui.Create("DPanel", frame)
    mainPanel:Dock(FILL)
    mainPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
    mainPanel.Paint = function() end
    
    -- Create tab panel
    local tabPanel = vgui.Create("DPanel", mainPanel)
    tabPanel:SetHeight(scaleSize(40))
    tabPanel:Dock(TOP)
    tabPanel:DockMargin(0, 0, 0, scaleSize(5))
    tabPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
    end
    
    -- Add balance display
    local balancePanel = vgui.Create("DPanel", tabPanel)
    balancePanel:SetWidth(scaleSize(200))
    balancePanel:Dock(RIGHT)
    balancePanel:DockMargin(0, scaleSize(5), scaleSize(5), scaleSize(5))
    balancePanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 150))
    end
    
    local balanceLabel = vgui.Create("DLabel", balancePanel)
    balanceLabel:SetText("Balance: " .. formatCurrency(playerBalance))
    balanceLabel:SetFont("DermaDefault")
    balanceLabel:SetTextColor(color_white)
    balanceLabel:SetContentAlignment(5) -- Center
    balanceLabel:Dock(FILL)
    
    -- Add tabs for each accessible category
    local tabButtons = {}
    local tabX = scaleSize(5)
    
    for _, rankName in ipairs(accessibleTabs) do
        local tabButton = vgui.Create("DButton", tabPanel)
        tabButton:SetText(rankName)
        tabButton:SetWidth(scaleSize(100))
        tabButton:SetPos(tabX, scaleSize(5))
        tabButton:SetHeight(scaleSize(30))
        
        -- Store in table for reference
        tabButtons[rankName] = tabButton
        
        tabButton.Paint = function(self, w, h)
            local color = rankName == selectedTab and TAB_COLORS[rankName] or Color(50, 50, 50, 150)
            draw.RoundedBox(4, 0, 0, w, h, color)
        end
        
        tabButton.DoClick = function()
            selectedTab = rankName
            selectedModel = nil
            
            -- Update all tab buttons
            for tab, btn in pairs(tabButtons) do
                btn.Paint = function(self, w, h)
                    local color = tab == selectedTab and TAB_COLORS[tab] or Color(50, 50, 50, 150)
                    draw.RoundedBox(4, 0, 0, w, h, color)
                end
            end
            
            -- Create content panel if not exists
            local contentPanel = mainPanel:GetChildren()[2]
            if not IsValid(contentPanel) then
                contentPanel = vgui.Create("DPanel", mainPanel)
                contentPanel:Dock(FILL)
                contentPanel.Paint = function() end
            end
            
            -- Refresh the main content with model display
            contentPanel:Clear()
            
            -- Left side: model list
            local leftPanel = vgui.Create("DPanel", contentPanel)
            leftPanel:SetWidth(scaleSize(650))
            leftPanel:Dock(LEFT)
            leftPanel:DockMargin(0, 0, scaleSize(5), 0)
            leftPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
            end
            
            -- Right side: model preview
            local rightPanel = vgui.Create("DPanel", contentPanel)
            rightPanel:Dock(FILL)
            rightPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
            end
            
            -- Filter area
            local filterPanel = vgui.Create("DPanel", leftPanel)
            filterPanel:SetHeight(scaleSize(40))
            filterPanel:Dock(TOP)
            filterPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), 0)
            filterPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
            end
            
            -- Filter label
            local filterLabel = vgui.Create("DLabel", filterPanel)
            filterLabel:SetText("Filter:")
            filterLabel:SetFont("DermaDefault")
            filterLabel:SetTextColor(color_white)
            filterLabel:SizeToContents()
            filterLabel:SetPos(scaleSize(10), scaleSize(12))
            
            -- Filter text entry
            local filterEntry = vgui.Create("DTextEntry", filterPanel)
            filterEntry:SetSize(scaleSize(400), scaleSize(25))
            filterEntry:SetPos(scaleSize(50), scaleSize(8))
            filterEntry:SetUpdateOnType(true)
            
            -- Model list area
            local modelListPanel = vgui.Create("DScrollPanel", leftPanel)
            modelListPanel:Dock(FILL)
            modelListPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
            
            -- Info panel in right side
            local infoPanel = vgui.Create("DPanel", rightPanel)
            infoPanel:Dock(FILL)
            infoPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
            infoPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
            end
            
            -- Purchase button
            local purchaseButton = vgui.Create("DButton", infoPanel)
            purchaseButton:SetText("Purchase Model")
            purchaseButton:Dock(BOTTOM)
            purchaseButton:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
            purchaseButton:SetHeight(scaleSize(30))
            purchaseButton:SetEnabled(false)
            
            purchaseButton.Paint = function(self, w, h)
                local bgColor = self:IsEnabled() and (self:IsHovered() and COLOR_BUTTON_HOVER or COLOR_BUTTON) or COLOR_BUTTON_DISABLED
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end
            
            purchaseButton.DoClick = function()
                if not selectedModel then return end
                
                -- Send purchase request to server
                net.Start("DonatorVendor_AttemptPurchase")
                net.WriteEntity(vendorEntity)
                net.WriteString(selectedModel.Model)
                net.SendToServer()
                
                playSound("buttons/button14.wav")
            end
            
            -- Equip button (for admins or already owned models)
            local equipButton = vgui.Create("DButton", infoPanel)
            equipButton:SetText("Equip Model (Admin)")
            equipButton:Dock(BOTTOM)
            equipButton:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), 0)
            equipButton:SetHeight(scaleSize(30))
            equipButton:SetEnabled(false)
            equipButton:SetVisible(isAdminAccess)
            
            equipButton.Paint = function(self, w, h)
                local bgColor = self:IsEnabled() and (self:IsHovered() and COLOR_BUTTON_HOVER or COLOR_BUTTON) or COLOR_BUTTON_DISABLED
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end
            
            equipButton.DoClick = function()
                if not selectedModel then return end
                
                -- Send equip request to server
                net.Start("DonatorVendor_EquipModel")
                net.WriteEntity(vendorEntity)
                net.WriteString(selectedModel.Model)
                net.SendToServer()
                
                playSound("buttons/button14.wav")
            end
            
            -- Model preview
            local modelPreview = vgui.Create("DModelPanel", infoPanel)
            modelPreview:SetSize(scaleSize(270), scaleSize(400))
            modelPreview:Dock(FILL)
            modelPreview:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(100))
            modelPreview:SetModel("")
            modelPreview:SetCamPos(Vector(50, 0, 50))
            modelPreview:SetLookAt(Vector(0, 0, 40))
            modelPreview:SetFOV(70)
            modelPreview.LayoutEntity = function(self, ent)
                if IsValid(ent) then
                    ent:SetAngles(Angle(0, RealTime() * 30, 0))
                end
            end
            
            -- Model info
            local modelInfo = vgui.Create("DLabel", infoPanel)
            modelInfo:SetText("Select a model to view details")
            modelInfo:SetFont("DermaDefault")
            modelInfo:SetTextColor(color_white)
            modelInfo:Dock(BOTTOM)
            modelInfo:DockMargin(scaleSize(5), 0, 0, scaleSize(5))
            modelInfo:SetHeight(scaleSize(20))
            
            -- Price info
            local priceInfo = vgui.Create("DLabel", infoPanel)
            priceInfo:SetText("")
            priceInfo:SetFont("DermaDefault")
            priceInfo:SetTextColor(color_white)
            priceInfo:Dock(BOTTOM)
            priceInfo:DockMargin(scaleSize(5), 0, 0, 0)
            priceInfo:SetHeight(scaleSize(20))
            
            -- Filter change event
            filterEntry.OnValueChange = function(self, value)
                refreshModelList(modelListPanel, modelPreview, value)
            end
            
            -- Initial load of models
            refreshModelList(modelListPanel, modelPreview)
            
            playSound("ui/buttonclick.wav")
        end
        
        tabX = tabX + scaleSize(105)
    end
    
    -- Add admin tab if player has admin access
    if isAdminAccess then
        local adminButton = vgui.Create("DButton", tabPanel)
        adminButton:SetText("Admin")
        adminButton:SetWidth(scaleSize(100))
        adminButton:SetPos(tabX, scaleSize(5))
        adminButton:SetHeight(scaleSize(30))
        
        tabButtons["Admin"] = adminButton
        
        adminButton.Paint = function(self, w, h)
            local color = selectedTab == "Admin" and TAB_COLORS["Admin"] or Color(50, 50, 50, 150)
            draw.RoundedBox(4, 0, 0, w, h, color)
        end
        
        adminButton.DoClick = function()
            selectedTab = "Admin"
            selectedModel = nil
            
            -- Update all tab buttons
            for tab, btn in pairs(tabButtons) do
                btn.Paint = function(self, w, h)
                    local color = tab == selectedTab and TAB_COLORS[tab] or Color(50, 50, 50, 150)
                    draw.RoundedBox(4, 0, 0, w, h, color)
                end
            end
            
            -- Create content panel if not exists
            local contentPanel = mainPanel:GetChildren()[2]
            if not IsValid(contentPanel) then
                contentPanel = vgui.Create("DPanel", mainPanel)
                contentPanel:Dock(FILL)
                contentPanel.Paint = function() end
            else
                contentPanel:Clear()
            end
            
            -- Create admin panel
            createAdminPanel(contentPanel)
            
            playSound("ui/buttonclick.wav")
        end
    end
    
    -- Content panel (will be filled by tab click)
    local contentPanel = vgui.Create("DPanel", mainPanel)
    contentPanel:Dock(FILL)
    contentPanel.Paint = function() end
    
    -- Simulate click on the first tab to initialize content
    if #accessibleTabs > 0 and IsValid(tabButtons[accessibleTabs[1]]) then
        tabButtons[accessibleTabs[1]]:DoClick()
    elseif isAdminAccess and IsValid(tabButtons["Admin"]) then
        tabButtons["Admin"]:DoClick()
    end
end

-- ========================================================================================
-- NETWORK HANDLERS
-- ========================================================================================

-- Handle menu open
net.Receive("DonatorVendor_OpenMenu", function()
    availableModels = net.ReadTable()
    accessibleTabs = net.ReadTable()
    vendorEntity = net.ReadEntity()
    isAdminAccess = net.ReadBool()
    playerBalance = net.ReadInt(32)
    
    -- Create menu
    createModelMenu()
    playSound("ui/buttonclickrelease.wav")
end)

-- Handle purchase result
net.Receive("DonatorVendor_PurchaseResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    if success then
        -- Update player balance if purchase was successful
        playerBalance = net.ReadInt(32)
        
        -- Update balance display in menu if open
        if IsValid(_G.DonatorVendorMenu) then
            local mainPanel = _G.DonatorVendorMenu:GetChildren()[1]
            if IsValid(mainPanel) then
                local tabPanel = mainPanel:GetChildren()[1]
                if IsValid(tabPanel) then
                    local balancePanel = tabPanel:GetChildren()[#tabPanel:GetChildren()]
                    if IsValid(balancePanel) and IsValid(balancePanel:GetChildren()[1]) then
                        balancePanel:GetChildren()[1]:SetText("Balance: " .. formatCurrency(playerBalance))
                    end
                end
            end
        end
        
        playSound("items/pickup.wav")
    else
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Handle equip result
net.Receive("DonatorVendor_EquipResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Play sound based on result
    if success then
        playSound("items/pickup.wav")
    else
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Entity drawing
function ENT:Draw()
    self:DrawModel()
    
    -- Draw vendor title above the NPC
    local pos = self:GetPos() + Vector(0, 0, 80)
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
    
    cam.Start3D2D(pos, ang, 0.1)
        draw.SimpleTextOutlined("Donator Model Vendor", "DonatorNPCText_Bold", 0, 0, Color(255, 215, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    cam.End3D2D()
end

print("--- [NPC DonatorModelVendor SCRIPT] cl_init.lua finished loading by CLIENT ---")