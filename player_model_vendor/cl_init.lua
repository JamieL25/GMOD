-- cl_init.lua for player_model_vendor entity
-- Updated: 2025-05-11 18:22:37 by JamieL25
-- Fixed text display issues in all tabs, improved UI scaling

include("shared.lua")

print("--- [NPC PlayerModelVendor SCRIPT] cl_init.lua is being loaded by CLIENT ---")

-- Create bold font for the vendor
surface.CreateFont("NPCText_Bold", {
    font = "DermaLarge",
    size = 40,
    weight = 800,  -- This makes it bold (normal is 400)
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
local COLOR_BUTTON_HOVER = Color(70, 120, 170, 220)
local COLOR_BUTTON_DISABLED = Color(70, 70, 70, 200)
local COLOR_SUCCESS = Color(50, 200, 50)
local COLOR_ERROR = Color(200, 50, 50)
local COLOR_WARNING = Color(240, 180, 0)
local COLOR_SELECTED = Color(70, 170, 70, 100)
local COLOR_BLACKLISTED = Color(200, 50, 50, 100)

-- Tab types
local TAB_BUY = 1
local TAB_OWNED = 2
local TAB_ADMIN = 3

-- Local variables to store data
local availableModels = {}
local ownedModels = {}
local blacklistedModels = {}
local selectedModels = {}
local vendorEntity = nil
local isAdminAccess = false
local currentTab = TAB_BUY
local activeModelPanel = nil
local lastPurchaseTime = 0
local lastEquipTime = 0

-- ========================================================================================
-- UTILITY FUNCTIONS
-- ========================================================================================

-- Scale function for UI elements based on scaling factor
local function scaleSize(size)
    return math.Round(size * UI_SCALE)
end

-- Format money for display
local function formatMoney(amount)
    -- Format money based on your server's economy (now using £ symbol)
    return "£" .. string.Comma(amount)
end

-- Check if a model is selected (for multi-select functionality)
local function isModelSelected(modelPath)
    return selectedModels[modelPath] or false
end

-- Check if a model is in the blacklist
local function isModelBlacklisted(modelPath)
    for _, blacklistedModel in pairs(blacklistedModels) do
        if blacklistedModel.model_path == modelPath then
            return true
        end
    end
    return false
end

-- Find model info by path
local function findModelByPath(modelPath, inList)
    for i, model in ipairs(inList or availableModels) do
        if model.Model == modelPath then
            return model, i
        end
    end
    return nil, -1
end

-- Safely get player money (client-side estimation)
local function getPlayerMoney()
    -- Use Currency system from server
    return LocalPlayer():GetNWInt("Currency", 0)
end

-- Play sound effect
local function playSound(sound)
    surface.PlaySound(sound)
end

-- ========================================================================================
-- UI FRAMEWORK
-- ========================================================================================

-- Create notification popup
local function createNotification(text, color, duration)
    if not IsValid(LocalPlayer()) then return end
    
    color = color or COLOR_SUCCESS
    duration = duration or 4
    
    -- Remove any existing notification
    if IsValid(_G.PMVNotification) then
        _G.PMVNotification:Remove()
    end
    
    -- Create new notification
    local notification = vgui.Create("DPanel")
    _G.PMVNotification = notification
    
    notification:SetSize(scaleSize(300), scaleSize(60))
    notification:SetPos(ScrW() / 2 - scaleSize(150), ScrH() - scaleSize(150))
    notification:SetBackgroundColor(color)
    notification:SetAlpha(0)
    notification:AlphaTo(255, 0.5, 0)
    
    notification.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, color)
        draw.RoundedBox(6, 2, 2, w - 4, h - 4, Color(40, 40, 40))
        
        draw.SimpleText("Player Model Vendor", "DermaDefaultBold", w / 2, scaleSize(15), color, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "DermaDefault", w / 2, scaleSize(35), color_white, TEXT_ALIGN_CENTER)
    end
    
    notification:MoveTo(ScrW() / 2 - scaleSize(150), ScrH() - scaleSize(200), 0.5, 0, -1)
    
    timer.Simple(duration, function()
        if IsValid(notification) then
            notification:AlphaTo(0, 0.5, 0, function()
                if IsValid(notification) then
                    notification:Remove()
                    _G.PMVNotification = nil
                end
            end)
        end
    end)
    
    return notification
end

-- ========================================================================================
-- MAIN MENU SETUP
-- ========================================================================================

-- Main menu frame creation
local function createModelMenu()
    -- Don't create multiple menus
    if IsValid(_G.PlayerModelVendorMenu) then
        _G.PlayerModelVendorMenu:Remove()
    end
    
    local frame = vgui.Create("DFrame")
    _G.PlayerModelVendorMenu = frame
    
    frame:SetSize(scaleSize(900), scaleSize(600))
    frame:Center()
    frame:SetTitle("Player Model Vendor")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    -- Custom paint for the frame
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BACKGROUND)
        surface.SetDrawColor(COLOR_HEADER)
        surface.DrawRect(0, 0, w, 24)
    end
    
    -- Create tabs for different sections
    local tabSheet = vgui.Create("DPropertySheet", frame)
    tabSheet:Dock(FILL)
    tabSheet:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
    
    -- Style the tabs
    tabSheet.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, COLOR_BACKGROUND)
    end
    
    -- Tab 1: Available Models
    local buyTab = vgui.Create("DPanel")
    buyTab.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 100))
    end
    
    -- Tab 2: Owned Models
    local ownedTab = vgui.Create("DPanel")
    ownedTab.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 100))
    end
    
    -- Create the tab items
    tabSheet:AddSheet("Available Models", buyTab, "icon16/basket.png")
    tabSheet:AddSheet("Owned Models", ownedTab, "icon16/user.png")
    
    -- Tab 3: Admin Panel (only for admins)
    local adminTab = nil
    if isAdminAccess then
        adminTab = vgui.Create("DPanel")
        adminTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 100))
        end
        tabSheet:AddSheet("Admin Panel", adminTab, "icon16/wrench.png")
    end
    
    -- Left side: Model list with icons
    local populateBuyTab = function()
        -- Main panel layout
        local mainPanel = vgui.Create("DPanel", buyTab)
        mainPanel:Dock(FILL)
        mainPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        mainPanel.Paint = function() end
        
        -- Left side: model list
        local leftPanel = vgui.Create("DPanel", mainPanel)
        leftPanel:SetWidth(scaleSize(650))
        leftPanel:Dock(LEFT)
        leftPanel:DockMargin(0, 0, scaleSize(5), 0)
        leftPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
        end
        
        -- Right side: model preview and info
        local rightPanel = vgui.Create("DPanel", mainPanel)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(0, 0, 0, 0)
        rightPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
        end
        
        -- Filter area
        local filterPanel = vgui.Create("DPanel", leftPanel)
        filterPanel:SetHeight(scaleSize(30))
        filterPanel:Dock(TOP)
        filterPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        filterPanel.Paint = function() end
        
        local filterLabel = vgui.Create("DLabel", filterPanel)
        filterLabel:SetText("Filter:")
        filterLabel:SetWidth(scaleSize(40))
        filterLabel:Dock(LEFT)
        
        local filterEntry = vgui.Create("DTextEntry", filterPanel)
        filterEntry:Dock(FILL)
        filterEntry:SetPlaceholderText("Type to filter models...")
        
        -- Model list (icon layout)
        local scroll = vgui.Create("DScrollPanel", leftPanel)
        scroll:Dock(FILL)
        scroll:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        
        local iconList = vgui.Create("DIconLayout", scroll)
        iconList:Dock(FILL)
        iconList:SetSpaceX(scaleSize(5))
        iconList:SetSpaceY(scaleSize(5))
        iconList:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        
        -- Details panel inside right side
        local modelPreview = vgui.Create("DModelPanel", rightPanel)
        modelPreview:Dock(FILL)
        modelPreview:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        modelPreview:SetModel("")
        -- UPDATED: Camera settings for closer view
        modelPreview:SetFOV(35) -- Changed from 50 to 35
        modelPreview:SetCamPos(Vector(30, 0, 30)) -- Changed from (50, 0, 50)
        modelPreview:SetLookAt(Vector(0, 0, 30)) -- Adjusted to match
        
        -- Info panel below preview
        local infoPanel = vgui.Create("DPanel", rightPanel)
        infoPanel:SetHeight(scaleSize(100))
        infoPanel:Dock(BOTTOM)
        infoPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        -- Info labels
        local nameLabel = vgui.Create("DLabel", infoPanel)
        nameLabel:SetText("Select a model")
        nameLabel:SetFont("DermaLarge")
        nameLabel:SetTextColor(color_white)
        nameLabel:Dock(TOP)
        nameLabel:SetHeight(scaleSize(30))
        nameLabel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), 0)
        
        local priceLabel = vgui.Create("DLabel", infoPanel)
        priceLabel:SetText("Price: ---")
        priceLabel:SetTextColor(color_white)
        priceLabel:Dock(TOP)
        priceLabel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        
        -- Purchase button
        local purchaseButton = vgui.Create("DButton", infoPanel)
        purchaseButton:SetText("Purchase Model")
        purchaseButton:Dock(BOTTOM)
        purchaseButton:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        purchaseButton:SetHeight(scaleSize(30))
        purchaseButton:SetEnabled(false)
        
        purchaseButton.Paint = function(self, w, h)
            local bgColor = self:IsEnabled() and (self:IsHovered() and COLOR_BUTTON_HOVER or COLOR_BUTTON) or COLOR_BUTTON_DISABLED
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
        
        -- Wallet display
        local walletPanel = vgui.Create("DPanel", leftPanel)
        walletPanel:SetHeight(scaleSize(30))
        walletPanel:Dock(BOTTOM)
        walletPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        walletPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        local walletLabel = vgui.Create("DLabel", walletPanel)
        walletLabel:SetText("Your Credits: " .. formatMoney(getPlayerMoney()))
        walletLabel:SetFont("DermaDefaultBold")
        walletLabel:SetTextColor(color_white)
        walletLabel:SizeToContents()
        walletLabel:Center()
        
        -- Update wallet info periodically
        timer.Create("PMV_WalletUpdate", 1, 0, function()
            if not IsValid(walletLabel) then
                timer.Remove("PMV_WalletUpdate")
                return
            end
            walletLabel:SetText("Your Credits: " .. formatMoney(getPlayerMoney()))
            walletLabel:SizeToContents()
            walletLabel:Center()
        end)
        
        -- Function to update model details in right panel
        local function updateModelDetails(model, index)
            if not model then return end
            
            -- Update active panel
            if IsValid(activeModelPanel) then
                activeModelPanel.selected = false
            end
            
            -- Update preview
            modelPreview:SetModel(model.Model)
            
            -- Adjust camera to fit model
            local mn, mx = modelPreview.Entity:GetRenderBounds()
            local size = 0
            size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
            size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
            size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
            
            -- UPDATED: Camera parameters for a closer view
            modelPreview:SetFOV(35) -- Changed from 50 to 35
            modelPreview:SetCamPos(Vector(size * 0.7, size * 0.3, size * 0.5)) -- Changed from size * 1.2
            modelPreview:SetLookAt((mn + mx) * 0.5)
            
            -- Update info
            nameLabel:SetText(model.Name)
            priceLabel:SetText("Price: " .. formatMoney(model.Price))
            
            -- Check if player can afford it
            local canAfford = model.Price <= getPlayerMoney()
            purchaseButton:SetEnabled(canAfford)
            
            -- Update purchase button action
            purchaseButton.DoClick = function()
                if CurTime() - lastPurchaseTime < 1 then return end -- Prevent spam
                lastPurchaseTime = CurTime()
                
                -- Send purchase request to server
                net.Start("BG_PlayerModelVendor_AttemptPurchase")
                net.WriteEntity(vendorEntity)
                net.WriteUInt(index, 16)
                net.SendToServer()
                
                playSound("buttons/button14.wav")
            end
        end
        
        -- Add filter functionality
        filterEntry.OnChange = function(self)
            local filter = self:GetValue():lower()
            iconList:Clear()
            
            for i, model in ipairs(availableModels) do
                if string.find(model.Name:lower(), filter) or string.find(model.Model:lower(), filter) then
                    -- Create icon item
                    local item = iconList:Add("DButton")
                    item:SetSize(scaleSize(120), scaleSize(150)) -- INCREASED: larger model icons, extra height for text
                    item:SetText("")
                    item.modelData = model
                    item.modelIndex = i
                    item.selected = false
                    
                    -- Model icon
                    local icon = vgui.Create("SpawnIcon", item)
                    icon:SetModel(model.Model)
                    icon:SetSize(scaleSize(110), scaleSize(110)) -- INCREASED: from 90x90
                    icon:SetPos(scaleSize(5), scaleSize(5))
                    icon:SetTooltip(model.Name)
                    
                    -- Check if player already owns this model
                    local alreadyOwned = false
                    for _, owned in ipairs(ownedModels) do
                        if owned.Model == model.Model then
                            alreadyOwned = true
                            break
                        end
                    end
                    
                    -- Custom paint function 
                    item.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, self.selected and COLOR_SELECTED or Color(40, 40, 40, 150))
                        
                        -- Draw name
                        local modelName = model.Name
                        if #modelName > 15 then
                            modelName = string.sub(modelName, 1, 12) .. "..."
                        end
                        draw.SimpleText(modelName, "DermaDefault", w/2, h-40, color_white, TEXT_ALIGN_CENTER)
                        
                        -- Draw price
                        local priceColor = model.Price <= getPlayerMoney() and Color(150, 255, 150) or Color(255, 150, 150)
                        draw.SimpleText(formatMoney(model.Price), "DermaDefault", w/2, h-20, priceColor, TEXT_ALIGN_CENTER)
                        
                        -- Already owned indicator
                        if alreadyOwned then
                            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 150))
                            draw.SimpleText("OWNED", "DermaDefaultBold", w/2, h/2, Color(200, 200, 200), TEXT_ALIGN_CENTER)
                        end
                    end
                    
                    -- On click handler
                    item.DoClick = function(self)
                        activeModelPanel = self
                        self.selected = true
                        updateModelDetails(self.modelData, self.modelIndex)
                        
                        local ownedAlready = false
                        for _, ownedModel in ipairs(ownedModels) do
                            if ownedModel.Model == self.modelData.Model then
                                ownedAlready = true
                                break
                            end
                        end
                        
                        purchaseButton:SetEnabled(not ownedAlready and model.Price <= getPlayerMoney())
                        surface.PlaySound("ui/buttonclick.wav")
                    end
                end
            end
        end
        
        -- Initial population of model list
        filterEntry.OnChange(filterEntry)
    end
    
    -- Populate owned models tab
    local populateOwnedTab = function()
        -- Main layout
        local mainPanel = vgui.Create("DPanel", ownedTab)
        mainPanel:Dock(FILL)
        mainPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        mainPanel.Paint = function() end
        
        -- Left side: model list
        local leftPanel = vgui.Create("DPanel", mainPanel)
        leftPanel:SetWidth(scaleSize(650))
        leftPanel:Dock(LEFT)
        leftPanel:DockMargin(0, 0, scaleSize(5), 0)
        leftPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
        end
        
        -- Right side: model preview
        local rightPanel = vgui.Create("DPanel", mainPanel)
        rightPanel:Dock(FILL)
        rightPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
        end
        
        -- Filter area
        local filterPanel = vgui.Create("DPanel", leftPanel)
        filterPanel:SetHeight(scaleSize(30))
        filterPanel:Dock(TOP)
        filterPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        filterPanel.Paint = function() end
        
        local filterLabel = vgui.Create("DLabel", filterPanel)
        filterLabel:SetText("Filter:")
        filterLabel:SetWidth(scaleSize(40))
        filterLabel:Dock(LEFT)
        
        local filterEntry = vgui.Create("DTextEntry", filterPanel)
        filterEntry:Dock(FILL)
        filterEntry:SetPlaceholderText("Type to filter models...")
        
        -- Model list
        local scroll = vgui.Create("DScrollPanel", leftPanel)
        scroll:Dock(FILL)
        scroll:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        
        local iconList = vgui.Create("DIconLayout", scroll)
        iconList:Dock(FILL)
        iconList:SetSpaceX(scaleSize(5))
        iconList:SetSpaceY(scaleSize(5))
        iconList:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        
        -- Details panel inside right side
        local modelPreview = vgui.Create("DModelPanel", rightPanel)
        modelPreview:Dock(FILL)
        modelPreview:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        modelPreview:SetModel("")
        -- UPDATED: Camera settings for closer view
        modelPreview:SetFOV(35) -- Changed from 50 to 35
        modelPreview:SetCamPos(Vector(30, 0, 30)) -- Changed from (50, 0, 50)
        modelPreview:SetLookAt(Vector(0, 0, 30)) -- Adjusted to match
        
        -- Info panel below preview
        local infoPanel = vgui.Create("DPanel", rightPanel)
        infoPanel:SetHeight(scaleSize(80))
        infoPanel:Dock(BOTTOM)
        infoPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        -- Info labels
        local nameLabel = vgui.Create("DLabel", infoPanel)
        nameLabel:SetText("Select a model")
        nameLabel:SetFont("DermaLarge")
        nameLabel:SetTextColor(color_white)
        nameLabel:Dock(TOP)
        nameLabel:SetHeight(scaleSize(30))
        nameLabel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), 0)
        
        -- Equip button
        local equipButton = vgui.Create("DButton", infoPanel)
        equipButton:SetText("Equip Model")
        equipButton:Dock(BOTTOM)
        equipButton:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        equipButton:SetHeight(scaleSize(30))
        equipButton:SetEnabled(false)
        
        equipButton.Paint = function(self, w, h)
            local bgColor = self:IsEnabled() and (self:IsHovered() and COLOR_BUTTON_HOVER or COLOR_BUTTON) or COLOR_BUTTON_DISABLED
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
        
        -- Currently equipped label
        local equippedPanel = vgui.Create("DPanel", leftPanel)
        equippedPanel:SetHeight(scaleSize(30))
        equippedPanel:Dock(BOTTOM)
        equippedPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        equippedPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        local equippedLabel = vgui.Create("DLabel", equippedPanel)
        equippedLabel:SetText("Currently Equipped: Unknown")
        equippedLabel:SetFont("DermaDefaultBold")
        equippedLabel:SetTextColor(color_white)
        equippedLabel:SizeToContents()
        equippedLabel:Center()
        
        -- Update currently equipped model display
        for _, model in ipairs(ownedModels) do
            if model.Model == LocalPlayer():GetModel() then
                equippedLabel:SetText("Currently Equipped: " .. model.Name)
                equippedLabel:SizeToContents()
                equippedLabel:Center()
                break
            end
        end
        
        -- Function to update model details in right panel
        local function updateOwnedModelDetails(model)
            if not model then return end
            
            -- Update active panel
            if IsValid(activeModelPanel) then
                activeModelPanel.selected = false
            end
            
            -- Update preview
            modelPreview:SetModel(model.Model)
            
            -- Adjust camera to fit model
            local mn, mx = modelPreview.Entity:GetRenderBounds()
            local size = 0
            size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
            size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
            size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
            
            -- UPDATED: Camera parameters for a closer view
            modelPreview:SetFOV(35) -- Changed from 50 to 35
            modelPreview:SetCamPos(Vector(size * 0.7, size * 0.3, size * 0.5)) -- Changed from size * 1.2
            modelPreview:SetLookAt((mn + mx) * 0.5)
            
            -- Update info
            nameLabel:SetText(model.Name)
            
            -- Check if already equipped
            local isEquipped = LocalPlayer():GetModel() == model.Model
            equipButton:SetEnabled(not isEquipped)
            
            -- Update equip button action
            equipButton.DoClick = function()
                if CurTime() - lastEquipTime < 1 then return end -- Prevent spam
                lastEquipTime = CurTime()
                
                -- Send equip request to server
                net.Start("BG_PlayerModelVendor_EquipOwnedModel")
                net.WriteString(model.Model)
                net.SendToServer()
                
                playSound("buttons/button14.wav")
            end
        end
        
        -- Add filter functionality
        filterEntry.OnChange = function(self)
            local filter = self:GetValue():lower()
            iconList:Clear()
            
            for i, model in ipairs(ownedModels) do
                if string.find(model.Name:lower(), filter) or string.find(model.Model:lower(), filter) then
                    -- Create icon item
                    local item = iconList:Add("DButton")
                    item:SetSize(scaleSize(120), scaleSize(150)) -- INCREASED height for better text visibility
                    item:SetText("")
                    item.modelData = model
                    item.selected = false
                    
                    -- Model icon
                    local icon = vgui.Create("SpawnIcon", item)
                    icon:SetModel(model.Model)
                    icon:SetSize(scaleSize(110), scaleSize(110))
                    icon:SetPos(scaleSize(5), scaleSize(5))
                    icon:SetTooltip(model.Name)
                    
                    -- Is this model currently equipped?
                    local isEquipped = LocalPlayer():GetModel() == model.Model
                    
                    -- Custom paint function 
                    item.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, self.selected and COLOR_SELECTED or Color(40, 40, 40, 150))
                        
                        -- If equipped, draw a green line at the top
                        if isEquipped then
                            draw.RoundedBox(0, 0, 0, w, 3, COLOR_SUCCESS)
                        end
                        
                        -- Draw name
                        local modelName = model.Name
                        if #modelName > 15 then
                            modelName = string.sub(modelName, 1, 12) .. "..."
                        end
                        draw.SimpleText(modelName, "DermaDefault", w/2, h-40, color_white, TEXT_ALIGN_CENTER)
                        
                        -- Draw equipped status
                        if isEquipped then
                            draw.SimpleText("EQUIPPED", "DermaDefaultBold", w/2, h-20, COLOR_SUCCESS, TEXT_ALIGN_CENTER)
                        end
                    end
                    
                    -- On click handler
                    item.DoClick = function(self)
                        activeModelPanel = self
                        self.selected = true
                        updateOwnedModelDetails(self.modelData)
                        surface.PlaySound("ui/buttonclick.wav")
                    end
                end
            end
        end
        
        -- Initial population of model list
        filterEntry.OnChange(filterEntry)
    end
    
    -- Populate Admin tab if accessible
    local populateAdminTab = function()
        if not isAdminAccess or not adminTab then return end
        
        -- Main layout
        local mainPanel = vgui.Create("DPanel", adminTab)
        mainPanel:Dock(FILL)
        mainPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        mainPanel.Paint = function() end
        
        -- Create selection mode panel
        local selectionPanel = vgui.Create("DPanel", mainPanel)
        selectionPanel:SetHeight(scaleSize(40))
        selectionPanel:Dock(TOP)
        selectionPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        selectionPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        local titleLabel = vgui.Create("DLabel", selectionPanel)
        titleLabel:SetText("Admin Panel - Multi-Select Mode")
        titleLabel:SetFont("DermaDefaultBold")
        titleLabel:SetTextColor(color_white)
        titleLabel:SizeToContents()
        titleLabel:SetPos(scaleSize(10), scaleSize(12))
        
        local modelCount = vgui.Create("DLabel", selectionPanel)
        modelCount:SetText("Selected Models: 0")
        modelCount:SetFont("DermaDefault")
        modelCount:SetTextColor(color_white)
        modelCount:SizeToContents()
        modelCount:SetPos(scaleSize(200), scaleSize(12))
        
        -- Control Panel at the bottom
        local controlPanel = vgui.Create("DPanel", mainPanel)
        controlPanel:SetHeight(scaleSize(120))
        controlPanel:Dock(BOTTOM)
        controlPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        controlPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
        end
        
        -- Action buttons panel
        local actionPanel = vgui.Create("DPanel", controlPanel)
        actionPanel:SetHeight(scaleSize(40))
        actionPanel:Dock(TOP)
        actionPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        actionPanel.Paint = function() end
        
        -- Action label
        local actionLabel = vgui.Create("DLabel", actionPanel)
        actionLabel:SetText("Actions:")
        actionLabel:SetFont("DermaDefaultBold")
        actionLabel:SetWidth(scaleSize(60))
        actionLabel:Dock(LEFT)
        
        -- Blacklist button
        local blacklistButton = vgui.Create("DButton", actionPanel)
        blacklistButton:SetText("Blacklist Selected")
        blacklistButton:SetIcon("icon16/delete.png")
        blacklistButton:SetWidth(scaleSize(130))
        blacklistButton:Dock(LEFT)
        blacklistButton:DockMargin(0, 0, scaleSize(5), 0)
        blacklistButton:SetEnabled(false)
        
        -- Update prices button
        local updatePricesButton = vgui.Create("DButton", actionPanel)
        updatePricesButton:SetText("Update Prices")
        updatePricesButton:SetIcon("icon16/money.png")
        updatePricesButton:SetWidth(scaleSize(130))
        updatePricesButton:Dock(LEFT)
        updatePricesButton:DockMargin(0, 0, scaleSize(5), 0)
        updatePricesButton:SetEnabled(false)
        
        -- Price field for bulk price updates
        local priceLabel = vgui.Create("DLabel", actionPanel)
        priceLabel:SetText("Price:")
        priceLabel:SetFont("DermaDefault")
        priceLabel:SetWidth(scaleSize(40))
        priceLabel:Dock(LEFT)
        priceLabel:DockMargin(scaleSize(5), 0, 0, 0)
        
        local priceEntry = vgui.Create("DNumberWang", actionPanel)
        priceEntry:SetMin(0)
        priceEntry:SetMax(50000)
        priceEntry:SetValue(1000)
        priceEntry:SetWidth(scaleSize(80))
        priceEntry:Dock(LEFT)
        
        -- Rescan button
        local rescanButton = vgui.Create("DButton", actionPanel)
        rescanButton:SetText("Rescan Models")
        rescanButton:SetIcon("icon16/arrow_refresh.png")
        rescanButton:SetWidth(scaleSize(130))
        rescanButton:Dock(RIGHT)
        rescanButton:DockMargin(scaleSize(5), 0, 0, 0)
        
        -- Blacklist management buttons
        local blacklistManagePanel = vgui.Create("DPanel", controlPanel)
        blacklistManagePanel:SetHeight(scaleSize(30))
        blacklistManagePanel:Dock(TOP)
        blacklistManagePanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        blacklistManagePanel.Paint = function() end
        
        local showBlacklistButton = vgui.Create("DButton", blacklistManagePanel)
        showBlacklistButton:SetText("Show Blacklisted Models")
        showBlacklistButton:SetIcon("icon16/eye.png")
        showBlacklistButton:SetWidth(scaleSize(160))
        showBlacklistButton:Dock(LEFT)
        
        local unblacklistButton = vgui.Create("DButton", blacklistManagePanel)
        unblacklistButton:SetText("Remove from Blacklist")
        unblacklistButton:SetIcon("icon16/delete.png")
        unblacklistButton:SetWidth(scaleSize(160))
        unblacklistButton:Dock(LEFT)
        unblacklistButton:DockMargin(scaleSize(5), 0, 0, 0)
        unblacklistButton:SetEnabled(false)
        
        -- Status panel
        local statusPanel = vgui.Create("DPanel", controlPanel)
        statusPanel:SetHeight(scaleSize(30))
        statusPanel:Dock(BOTTOM)
        statusPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        statusPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 150))
        end
        
        local statusLabel = vgui.Create("DLabel", statusPanel)
        statusLabel:SetText("Select models to perform bulk actions")
        statusLabel:SetFont("DermaDefault")
        statusLabel:SetTextColor(color_white)
        statusLabel:SizeToContents()
        statusLabel:Center()
        
        -- Model list area
        local modelListArea = vgui.Create("DPanel", mainPanel)
        modelListArea:Dock(FILL)
        modelListArea:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        modelListArea.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
        end
        
        -- Filter area
        local filterPanel = vgui.Create("DPanel", modelListArea)
        filterPanel:SetHeight(scaleSize(30))
        filterPanel:Dock(TOP)
        filterPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        filterPanel.Paint = function() end
        
        local filterLabel = vgui.Create("DLabel", filterPanel)
        filterLabel:SetText("Filter:")
        filterLabel:SetWidth(scaleSize(40))
        filterLabel:Dock(LEFT)
        
        local filterEntry = vgui.Create("DTextEntry", filterPanel)
        filterEntry:Dock(FILL)
        filterEntry:SetPlaceholderText("Type to filter models...")
        
        -- View mode selector
        local viewModePanel = vgui.Create("DPanel", filterPanel)
        viewModePanel:SetWidth(scaleSize(120))
        viewModePanel:Dock(RIGHT)
        viewModePanel:DockMargin(scaleSize(5), 0, 0, 0)
        viewModePanel.Paint = function() end
        
        local viewMode = vgui.Create("DComboBox", viewModePanel)
        viewMode:Dock(FILL)
        viewMode:SetValue("Available Models")
        viewMode:AddChoice("Available Models")
        viewMode:AddChoice("Blacklisted Models")
        
        -- Scroll panel for models
        local scroll = vgui.Create("DScrollPanel", modelListArea)
        scroll:Dock(FILL)
        scroll:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
        
        local iconList = vgui.Create("DIconLayout", scroll)
        iconList:Dock(FILL)
        iconList:SetSpaceX(scaleSize(5))
        iconList:SetSpaceY(scaleSize(5))
        iconList:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
        
        -- Initialize empty selected models table
        selectedModels = {}
        
        -- Helper function to count selected models
        local function updateSelectedCount()
            local count = 0
            for _ in pairs(selectedModels) do
                count = count + 1
            end
            
            modelCount:SetText("Selected Models: " .. count)
            modelCount:SizeToContents()
            
            blacklistButton:SetEnabled(count > 0 and viewMode:GetValue() == "Available Models")
            updatePricesButton:SetEnabled(count > 0 and viewMode:GetValue() == "Available Models")
            unblacklistButton:SetEnabled(count > 0 and viewMode:GetValue() == "Blacklisted Models")
        end
        
        -- Function to populate model list based on current view mode
        local function populateModelList(filter)
            iconList:Clear()
            selectedModels = {}
            updateSelectedCount()
            
            -- Check which mode we're in
            local viewingBlacklist = viewMode:GetValue() == "Blacklisted Models"
            local models = viewingBlacklist and blacklistedModels or availableModels
            local modelPaths = {}
            
            if viewingBlacklist then
                -- We need to convert the blacklisted models format
                for _, model in ipairs(models) do
                    modelPaths[model.model_path] = true
                end
            end
            
            -- Lowercase filter for case insensitive matching
            filter = filter:lower()
            
            local displayModels = viewingBlacklist and blacklistedModels or availableModels
            
            for i, model in ipairs(displayModels) do
                local modelPath = viewingBlacklist and model.model_path or model.Model
                local modelName = viewingBlacklist and (model.model_path:match(".+/(.+)%.mdl$") or "Unknown") or model.Name
                
                -- Apply filter if needed
                if filter ~= "" and not (string.find(modelName:lower(), filter) or string.find(modelPath:lower(), filter)) then
                    -- Skip this model if it doesn't match the filter
                    -- We don't use 'continue' as it's not supported in Lua 5.1
                else
                    -- Create icon item
                    local item = iconList:Add("DButton")
                    item:SetSize(scaleSize(120), scaleSize(150))
                    item:SetText("")
                    item.modelData = model
                    item.modelPath = modelPath
                    item.selected = false
                    
                    -- Model icon
                    local icon = vgui.Create("SpawnIcon", item)
                    icon:SetModel(modelPath)
                    icon:SetSize(scaleSize(110), scaleSize(110))
                    icon:SetPos(scaleSize(5), scaleSize(5))
                    icon:SetTooltip(modelPath)
                    
                    -- Custom paint function 
                    item.Paint = function(self, w, h)
                        local bgColor = Color(40, 40, 40, 150)
                        
                        -- If selected, use selection color
                        if selectedModels[self.modelPath] then
                            bgColor = COLOR_SELECTED
                            self.selected = true
                        end
                        
                        draw.RoundedBox(4, 0, 0, w, h, bgColor)
                        
                        -- Draw name (shortened if needed)
                        local displayName = modelName
                        if #displayName > 15 then
                            displayName = string.sub(displayName, 1, 12) .. "..."
                        end
                        draw.SimpleText(displayName, "DermaDefault", w/2, h-40, color_white, TEXT_ALIGN_CENTER)
                        
                        -- Draw additional info based on view mode
                        if viewingBlacklist then
                            -- Show who blacklisted it
                            local addedBy = model.added_by or "Unknown"
                            if #addedBy > 15 then
                                addedBy = string.sub(addedBy, 1, 12) .. "..."
                            end
                            draw.SimpleText("By: " .. addedBy, "DermaDefault", w/2, h-20, Color(255, 150, 150), TEXT_ALIGN_CENTER)
                        else
                            -- Show price
                            draw.SimpleText(formatMoney(model.Price), "DermaDefault", w/2, h-20, color_white, TEXT_ALIGN_CENTER)
                        end
                    end
                    
                    -- On click handler for multi-select
                    item.DoClick = function(self)
                        -- Toggle selection
                        if selectedModels[self.modelPath] then
                            selectedModels[self.modelPath] = nil
                            self.selected = false
                        else
                            selectedModels[self.modelPath] = true
                            self.selected = true
                        end
                        
                        updateSelectedCount()
                        surface.PlaySound("ui/buttonclickrelease.wav")
                    end
                end
            end
        end
        
        -- Add filter functionality
        filterEntry.OnChange = function(self)
            populateModelList(self:GetValue())
        end
        
        -- View mode change handler
        viewMode.OnSelect = function(self, index, value)
            -- First request blacklisted models if needed
            if value == "Blacklisted Models" and #blacklistedModels == 0 then
                net.Start("BG_PlayerModelVendor_Admin_GetBlacklist")
                net.SendToServer()
                
                statusLabel:SetText("Requesting blacklisted models...")
                statusLabel:SizeToContents()
                statusLabel:Center()
                
                -- Delay populating until we receive the data
                timer.Simple(0.5, function()
                    populateModelList(filterEntry:GetValue())
                end)
            else
                populateModelList(filterEntry:GetValue())
            end
            
            -- Update UI elements based on view mode
            blacklistButton:SetEnabled(value == "Available Models" and next(selectedModels) ~= nil)
            updatePricesButton:SetEnabled(value == "Available Models" and next(selectedModels) ~= nil)
            unblacklistButton:SetEnabled(value == "Blacklisted Models" and next(selectedModels) ~= nil)
        end
        
        -- Button actions
        blacklistButton.DoClick = function()
            if next(selectedModels) == nil then return end
            
            -- Create reason input dialog
            local reasonFrame = vgui.Create("DFrame")
            reasonFrame:SetSize(scaleSize(400), scaleSize(150))
            reasonFrame:Center()
            reasonFrame:SetTitle("Blacklist Reason")
            reasonFrame:MakePopup()
            
            local reasonLabel = vgui.Create("DLabel", reasonFrame)
            reasonLabel:SetText("Enter a reason for blacklisting these models:")
            reasonLabel:SetPos(scaleSize(20), scaleSize(40))
            reasonLabel:SizeToContents()
            
            local reasonEntry = vgui.Create("DTextEntry", reasonFrame)
            reasonEntry:SetPos(scaleSize(20), scaleSize(60))
            reasonEntry:SetSize(scaleSize(360), scaleSize(25))
            reasonEntry:SetPlaceholderText("Reason (optional)")
            
            local confirmButton = vgui.Create("DButton", reasonFrame)
            confirmButton:SetPos(scaleSize(270), scaleSize(95))
            confirmButton:SetSize(scaleSize(110), scaleSize(25))
            confirmButton:SetText("Confirm Blacklist")
            
            local cancelButton = vgui.Create("DButton", reasonFrame)
            cancelButton:SetPos(scaleSize(155), scaleSize(95))
            cancelButton:SetSize(scaleSize(110), scaleSize(25))
            cancelButton:SetText("Cancel")
            
            confirmButton.DoClick = function()
                local reason = reasonEntry:GetValue()
                local modelList = {}
                
                for path in pairs(selectedModels) do
                    table.insert(modelList, path)
                end
                
                -- Send bulk action to server
                net.Start("BG_PlayerModelVendor_Admin_BulkAction")
                net.WriteString("blacklist_models")
                net.WriteUInt(#modelList, 16)
                
                for _, path in ipairs(modelList) do
                    net.WriteString(path)
                end
                
                -- Add reason as additional data
                net.WriteBool(true)
                net.WriteTable({reason = reason})
                net.SendToServer()
                
                statusLabel:SetText("Blacklisting " .. #modelList .. " models...")
                statusLabel:SizeToContents()
                statusLabel:Center()
                
                reasonFrame:Close()
                surface.PlaySound("buttons/button14.wav")
            end
            
            cancelButton.DoClick = function()
                reasonFrame:Close()
            end
        end
        
        updatePricesButton.DoClick = function()
            if next(selectedModels) == nil then return end
            
            local modelList = {}
            for path in pairs(selectedModels) do
                table.insert(modelList, path)
            end
            
            -- Send bulk price update to server
            net.Start("BG_PlayerModelVendor_Admin_BulkAction")
            net.WriteString("update_prices")
            net.WriteUInt(#modelList, 16)
            
            for _, path in ipairs(modelList) do
                net.WriteString(path)
            end
            
            -- Add price as additional data
            net.WriteBool(true)
            net.WriteTable({price = priceEntry:GetValue()})
            net.SendToServer()
            
            statusLabel:SetText("Updating prices for " .. #modelList .. " models...")
            statusLabel:SizeToContents()
            statusLabel:Center()
            
            surface.PlaySound("buttons/button14.wav")
        end
        
        rescanButton.DoClick = function()
            net.Start("BG_PlayerModelVendor_Admin_Action")
            net.WriteString("rescan_models")
            net.WriteTable({})
            net.SendToServer()
            
            statusLabel:SetText("Requesting model rescan...")
            statusLabel:SizeToContents()
            statusLabel:Center()
            
            surface.PlaySound("buttons/button14.wav")
        end
        
        unblacklistButton.DoClick = function()
            if next(selectedModels) == nil then return end
            
            local modelList = {}
            for path in pairs(selectedModels) do
                table.insert(modelList, path)
            end
            
            -- Send bulk unblacklist to server
            net.Start("BG_PlayerModelVendor_Admin_BulkAction")
            net.WriteString("unblacklist_models")
            net.WriteUInt(#modelList, 16)
            
            for _, path in ipairs(modelList) do
                net.WriteString(path)
            end
            
            net.WriteBool(false)
            net.SendToServer()
            
            statusLabel:SetText("Removing " .. #modelList .. " models from blacklist...")
            statusLabel:SizeToContents()
            statusLabel:Center()
            
            surface.PlaySound("buttons/button14.wav")
        end
        
        showBlacklistButton.DoClick = function()
            viewMode:ChooseOption("Blacklisted Models")
        end
        
        -- Initial population of model list
        populateModelList("")
    end
    
    -- Populate the tabs
    populateBuyTab()
    populateOwnedTab()
    if isAdminAccess then
        populateAdminTab()
    end
    
    return frame
end

-- ========================================================================================
-- NETWORK HANDLERS
-- ========================================================================================

-- Handle menu open command from server
net.Receive("BG_PlayerModelVendor_OpenMenu", function()
    -- Read data from server
    availableModels = net.ReadTable()
    ownedModels = net.ReadTable()
    vendorEntity = net.ReadEntity()
    isAdminAccess = net.ReadBool()
    
    -- Create menu
    createModelMenu()
    playSound("ui/buttonclickrelease.wav")
end)

-- Handle purchase result
net.Receive("BG_PlayerModelVendor_PurchaseResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Only update models if necessary
    if success then
        availableModels = net.ReadTable()
        ownedModels = net.ReadTable()
        
        -- If we have an open menu, update it
        if IsValid(_G.PlayerModelVendorMenu) then
            _G.PlayerModelVendorMenu:Remove()
            createModelMenu()
        end
        
        -- Play success sound
        playSound("items/pickup.wav")
    else
        -- Play error sound
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Handle equip result
net.Receive("BG_PlayerModelVendor_EquipResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Only update models if necessary
    if success then
        availableModels = net.ReadTable()
        ownedModels = net.ReadTable()
        
        -- If we have an open menu, update it
        if IsValid(_G.PlayerModelVendorMenu) then
            _G.PlayerModelVendorMenu:Remove()
            createModelMenu()
        end
        
        -- Play success sound
        playSound("items/ammopickup.wav")
    else
        -- Play error sound
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Handle admin action result
net.Receive("BG_PlayerModelVendor_Admin_ActionResponse", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
    
    -- Play sound based on result
    playSound(success and "buttons/button3.wav" or "buttons/button10.wav")
end)

-- Handle bulk action result
net.Receive("BG_PlayerModelVendor_Admin_BulkActionResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Only update models if necessary and provided
    if success then
        local newAvailable = net.ReadTable()
        local newOwned = net.ReadTable()
        
        if #newAvailable > 0 then
            availableModels = newAvailable
        end
        
        if #newOwned > 0 then
            ownedModels = newOwned
        end
        
        -- If we have an open menu, update it
        if IsValid(_G.PlayerModelVendorMenu) then
            _G.PlayerModelVendorMenu:Remove()
            createModelMenu()
        end
        
        -- Play success sound
        playSound("buttons/button3.wav")
    else
        -- Play error sound
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Handle blacklist data response
net.Receive("BG_PlayerModelVendor_Admin_BlacklistResponse", function()
    blacklistedModels = net.ReadTable()
    
    -- If we have an open menu with active blacklist view, refresh it
    if IsValid(_G.PlayerModelVendorMenu) then
        local menu = _G.PlayerModelVendorMenu
        if menu.BlacklistViewActive then
            _G.PlayerModelVendorMenu:Remove()
            createModelMenu()
        end
    end
end)

-- ========================================================================================
-- ENTITY DRAWING
-- ========================================================================================

-- Remove the hooks that force visibility
hook.Remove("InitPostEntity", "PMV_SetUpSafeZoneVisibility")
hook.Remove("OnEntityCreated", "PMV_TrackNewVendors")
hook.Remove("PreDrawOpaqueRenderables", "PMV_OverrideSafeZoneHiding")

-- Main drawing function - ONLY draw when in safezone
function ENT:Draw()
    -- Only draw if player is in safe zone
    if LocalPlayer():GetNWBool("InSafeZone", false) then
        self:DrawModel()
        
        -- Draw 3D2D text above the NPC
        local pos = self:GetPos()
        local myPos = LocalPlayer():GetPos()
        
        -- Only draw text when close enough (using teleporter's distance)
        if pos:Distance(myPos) < 1000 then
            -- Calculate position above the NPC's head (teleporter style)
            local textPos = pos + Vector(0, 0, 85)
            
            -- Draw text with bold font and yellow color (teleporter style)
            cam.Start3D2D(textPos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.1)
                draw.SimpleTextOutlined("Player Model Vendor", "NPCText_Bold", 0, 0, Color(255, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
                draw.SimpleTextOutlined("Press E to browse models", "NPCText_Bold", 0, 50, Color(255, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
            cam.End3D2D()
        end
    end
    -- Don't draw anything if not in safezone
end

print("--- [NPC PlayerModelVendor SCRIPT] cl_init.lua finished loading by CLIENT - v1.3 with Fixed Text Display ---")