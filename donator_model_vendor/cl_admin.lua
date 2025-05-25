-- cl_admin.lua for donator_vendor entity
-- Created: 2025-05-25 21:36:18 by JamieL25
-- Part 2: Admin panel functionality

-- ========================================================================================
-- UTILITY FUNCTIONS
-- ========================================================================================

-- Format currency (already defined in cl_init.lua, but included here for completeness)
local function formatCurrency(amount)
    return string.Comma(amount) .. " credits"
end

-- Show confirmation dialog
local function showConfirmDialog(title, message, onYes, onNo)
    local confirmFrame = vgui.Create("DFrame")
    confirmFrame:SetSize(scaleSize(350), scaleSize(150))
    confirmFrame:Center()
    confirmFrame:SetTitle(title)
    confirmFrame:SetDraggable(true)
    confirmFrame:ShowCloseButton(true)
    confirmFrame:MakePopup()
    
    confirmFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BACKGROUND)
        draw.RoundedBox(8, 0, 0, w, scaleSize(25), COLOR_HEADER)
    end
    
    local messageLabel = vgui.Create("DLabel", confirmFrame)
    messageLabel:SetText(message)
    messageLabel:SetFont("DermaDefault")
    messageLabel:SetTextColor(color_white)
    messageLabel:SetContentAlignment(5) -- Center
    messageLabel:Dock(TOP)
    messageLabel:DockMargin(scaleSize(10), scaleSize(20), scaleSize(10), scaleSize(20))
    messageLabel:SetWrap(true)
    messageLabel:SetAutoStretchVertical(true)
    
    local buttonPanel = vgui.Create("DPanel", confirmFrame)
    buttonPanel:SetHeight(scaleSize(30))
    buttonPanel:Dock(BOTTOM)
    buttonPanel:DockMargin(scaleSize(10), 0, scaleSize(10), scaleSize(10))
    buttonPanel.Paint = function() end
    
    local noButton = vgui.Create("DButton", buttonPanel)
    noButton:SetText("Cancel")
    noButton:SetWidth(scaleSize(100))
    noButton:Dock(RIGHT)
    noButton:DockMargin(scaleSize(5), 0, 0, 0)
    
    local yesButton = vgui.Create("DButton", buttonPanel)
    yesButton:SetText("Confirm")
    yesButton:SetWidth(scaleSize(100))
    yesButton:Dock(RIGHT)
    yesButton:DockMargin(0, 0, scaleSize(5), 0)
    
    yesButton.DoClick = function()
        if onYes then onYes() end
        confirmFrame:Close()
    end
    
    noButton.DoClick = function()
        if onNo then onNo() end
        confirmFrame:Close()
    end
    
    return confirmFrame
end

-- Create add model dialog
local function createAddModelDialog()
    local addFrame = vgui.Create("DFrame")
    addFrame:SetSize(scaleSize(450), scaleSize(250))
    addFrame:Center()
    addFrame:SetTitle("Add/Edit Model")
    addFrame:SetDraggable(true)
    addFrame:ShowCloseButton(true)
    addFrame:MakePopup()
    
    addFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BACKGROUND)
        draw.RoundedBox(8, 0, 0, w, scaleSize(25), COLOR_HEADER)
    end
    
    -- Model path
    local pathLabel = vgui.Create("DLabel", addFrame)
    pathLabel:SetText("Model Path:")
    pathLabel:SetFont("DermaDefault")
    pathLabel:SetTextColor(color_white)
    pathLabel:SetContentAlignment(4) -- Left-center
    pathLabel:SetPos(scaleSize(10), scaleSize(40))
    pathLabel:SetSize(scaleSize(80), scaleSize(20))
    
    local pathEntry = vgui.Create("DTextEntry", addFrame)
    pathEntry:SetPos(scaleSize(100), scaleSize(40))
    pathEntry:SetSize(scaleSize(300), scaleSize(25))
    pathEntry:SetPlaceholderText("models/player/example.mdl")
    
    -- Model name
    local nameLabel = vgui.Create("DLabel", addFrame)
    nameLabel:SetText("Display Name:")
    nameLabel:SetFont("DermaDefault")
    nameLabel:SetTextColor(color_white)
    nameLabel:SetContentAlignment(4) -- Left-center
    nameLabel:SetPos(scaleSize(10), scaleSize(80))
    nameLabel:SetSize(scaleSize(80), scaleSize(20))
    
    local nameEntry = vgui.Create("DTextEntry", addFrame)
    nameEntry:SetPos(scaleSize(100), scaleSize(80))
    nameEntry:SetSize(scaleSize(300), scaleSize(25))
    nameEntry:SetPlaceholderText("Custom Player Model")
    
    -- Rank selection
    local rankLabel = vgui.Create("DLabel", addFrame)
    rankLabel:SetText("Rank:")
    rankLabel:SetFont("DermaDefault")
    rankLabel:SetTextColor(color_white)
    rankLabel:SetContentAlignment(4) -- Left-center
    rankLabel:SetPos(scaleSize(10), scaleSize(120))
    rankLabel:SetSize(scaleSize(80), scaleSize(20))
    
    local rankCombo = vgui.Create("DComboBox", addFrame)
    rankCombo:SetPos(scaleSize(100), scaleSize(120))
    rankCombo:SetSize(scaleSize(140), scaleSize(25))
    rankCombo:SetValue("VIP")
    
    -- Add rank options
    for rankName, rankData in pairs(donator_vendor.Ranks) do
        rankCombo:AddChoice(rankName)
    end
    
    -- Price input
    local priceLabel = vgui.Create("DLabel", addFrame)
    priceLabel:SetText("Price:")
    priceLabel:SetFont("DermaDefault")
    priceLabel:SetTextColor(color_white)
    priceLabel:SetContentAlignment(4) -- Left-center
    priceLabel:SetPos(scaleSize(260), scaleSize(120))
    priceLabel:SetSize(scaleSize(40), scaleSize(20))
    
    local priceEntry = vgui.Create("DNumberWang", addFrame)
    priceEntry:SetPos(scaleSize(310), scaleSize(120))
    priceEntry:SetSize(scaleSize(90), scaleSize(25))
    priceEntry:SetMin(0)
    priceEntry:SetMax(100000)
    priceEntry:SetValue(donator_vendor.DEFAULT_PRICE)
    
    -- Preview panel
    local previewPanel = vgui.Create("DModelPanel", addFrame)
    previewPanel:SetPos(scaleSize(10), scaleSize(155))
    previewPanel:SetSize(scaleSize(120), scaleSize(80))
    previewPanel:SetModel("")
    previewPanel:SetCamPos(Vector(50, 0, 50))
    previewPanel:SetLookAt(Vector(0, 0, 40))
    previewPanel:SetFOV(70)
    previewPanel.LayoutEntity = function(self, ent)
        if IsValid(ent) then
            ent:SetAngles(Angle(0, RealTime() * 30, 0))
        end
    end
    
    -- Update preview when path changes
    pathEntry.OnValueChange = function(self, value)
        if util.IsValidModel(value) then
            previewPanel:SetModel(value)
            
            -- Auto-generate name if empty
            if nameEntry:GetValue() == "" then
                nameEntry:SetValue(donator_vendor.GetNameFromModelPath(value))
            end
            
            -- Auto-adjust camera to fit model
            if IsValid(previewPanel.Entity) then
                local mn, mx = previewPanel.Entity:GetRenderBounds()
                local size = 0
                size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
                size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
                size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
                
                previewPanel:SetFOV(45)
                previewPanel:SetCamPos(Vector(size * 1.1, 0, size * 0.5))
                previewPanel:SetLookAt((mn + mx) * 0.5)
            end
        end
    end
    
    -- Buttons panel
    local buttonPanel = vgui.Create("DPanel", addFrame)
    buttonPanel:SetPos(scaleSize(140), scaleSize(155))
    buttonPanel:SetSize(scaleSize(300), scaleSize(80))
    buttonPanel.Paint = function() end
    
    local statusLabel = vgui.Create("DLabel", buttonPanel)
    statusLabel:SetText("")
    statusLabel:SetFont("DermaDefault")
    statusLabel:SetTextColor(color_white)
    statusLabel:SetContentAlignment(4) -- Left-center
    statusLabel:SetPos(scaleSize(5), scaleSize(5))
    statusLabel:SetSize(scaleSize(290), scaleSize(20))
    
    local cancelButton = vgui.Create("DButton", buttonPanel)
    cancelButton:SetText("Cancel")
    cancelButton:SetPos(scaleSize(5), scaleSize(35))
    cancelButton:SetSize(scaleSize(140), scaleSize(30))
    
    local saveButton = vgui.Create("DButton", buttonPanel)
    saveButton:SetText("Add Model")
    saveButton:SetPos(scaleSize(155), scaleSize(35))
    saveButton:SetSize(scaleSize(140), scaleSize(30))
    
    cancelButton.DoClick = function()
        addFrame:Close()
    end
    
    saveButton.DoClick = function()
        local modelPath = pathEntry:GetValue()
        local modelName = nameEntry:GetValue()
        local rankName = rankCombo:GetValue()
        local price = priceEntry:GetValue()
        
        -- Validate inputs
        if modelPath == "" then
            statusLabel:SetText("Error: Model path is required")
            return
        end
        
        if not util.IsValidModel(modelPath) then
            statusLabel:SetText("Error: Invalid model path")
            return
        end
        
        if modelName == "" then
            statusLabel:SetText("Error: Model name is required")
            return
        end
        
        -- Send add model request to server
        net.Start("DonatorVendor_Admin_Action")
        net.WriteString("add_model")
        net.WriteTable({
            modelPath = modelPath,
            modelName = modelName,
            rankName = rankName,
            price = price
        })
        net.SendToServer()
        
        statusLabel:SetText("Adding model...")
        saveButton:SetEnabled(false)
        
        -- Close after 1 second
        timer.Simple(1, function()
            if IsValid(addFrame) then
                addFrame:Close()
            end
        end)
    end
    
    return addFrame
end

-- Create price change dialog
local function createPriceDialog(models, onConfirm)
    local priceFrame = vgui.Create("DFrame")
    priceFrame:SetSize(scaleSize(300), scaleSize(150))
    priceFrame:Center()
    priceFrame:SetTitle("Set Price")
    priceFrame:SetDraggable(true)
    priceFrame:ShowCloseButton(true)
    priceFrame:MakePopup()
    
    priceFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BACKGROUND)
        draw.RoundedBox(8, 0, 0, w, scaleSize(25), COLOR_HEADER)
    end
    
    -- Info about how many models will be affected
    local infoLabel = vgui.Create("DLabel", priceFrame)
    local count = 0
    for _ in pairs(models) do count = count + 1 end
    infoLabel:SetText("Set price for " .. count .. " model" .. (count > 1 and "s" or "") .. ":")
    infoLabel:SetFont("DermaDefault")
    infoLabel:SetTextColor(color_white)
    infoLabel:SetContentAlignment(5) -- Center
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(scaleSize(10), scaleSize(20), scaleSize(10), 0)
    
    -- Price input
    local pricePanel = vgui.Create("DPanel", priceFrame)
    pricePanel:SetHeight(scaleSize(30))
    pricePanel:Dock(TOP)
    pricePanel:DockMargin(scaleSize(10), scaleSize(10), scaleSize(10), 0)
    pricePanel.Paint = function() end
    
    local priceEntry = vgui.Create("DNumberWang", pricePanel)
    priceEntry:SetHeight(scaleSize(25))
    priceEntry:SetWidth(scaleSize(120))
    priceEntry:Dock(FILL)
    priceEntry:SetMin(0)
    priceEntry:SetMax(100000)
    priceEntry:SetValue(donator_vendor.DEFAULT_PRICE)
    
    -- Buttons panel
    local buttonPanel = vgui.Create("DPanel", priceFrame)
    buttonPanel:SetHeight(scaleSize(30))
    buttonPanel:Dock(BOTTOM)
    buttonPanel:DockMargin(scaleSize(10), scaleSize(10), scaleSize(10), scaleSize(10))
    buttonPanel.Paint = function() end
    
    local cancelButton = vgui.Create("DButton", buttonPanel)
    cancelButton:SetText("Cancel")
    cancelButton:SetWidth(scaleSize(100))
    cancelButton:Dock(RIGHT)
    cancelButton:DockMargin(scaleSize(5), 0, 0, 0)
    
    local saveButton = vgui.Create("DButton", buttonPanel)
    saveButton:SetText("Set Price")
    saveButton:SetWidth(scaleSize(100))
    saveButton:Dock(RIGHT)
    saveButton:DockMargin(0, 0, scaleSize(5), 0)
    
    cancelButton.DoClick = function()
        priceFrame:Close()
    end
    
    saveButton.DoClick = function()
        local price = priceEntry:GetValue()
        if price < 0 then price = 0 end
        
        -- Call the callback with the price
        if onConfirm then
            onConfirm(price)
        end
        
        priceFrame:Close()
    end
    
    return priceFrame
end

-- ========================================================================================
-- ADMIN PANEL
-- ========================================================================================

-- Create admin panel
function createAdminPanel(parent)
    -- Check if parent is valid
    if not IsValid(parent) then 
        print("Error: Invalid parent panel in createAdminPanel")
        return
    end
    
    -- Clear the parent first
    parent:Clear()
    
    -- Main panel
    local mainPanel = vgui.Create("DPanel", parent)
    mainPanel:Dock(FILL)
    mainPanel.Paint = function() end
    
    -- Create tab control
    local adminTabs = vgui.Create("DPropertySheet", mainPanel)
    adminTabs:Dock(FILL)
    adminTabs:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
    
    -- Create Models tab
    local modelsPanel = vgui.Create("DPanel")
    modelsPanel:Dock(FILL)
    modelsPanel.Paint = function() end
    
    -- Create control panel at the top
    local controlPanel = vgui.Create("DPanel", modelsPanel)
    controlPanel:SetHeight(scaleSize(100))
    controlPanel:Dock(TOP)
    controlPanel:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
    controlPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150))
    end
    
    -- Title
    local titleLabel = vgui.Create("DLabel", controlPanel)
    titleLabel:SetText("Model Management")
    titleLabel:SetFont("Trebuchet24")
    titleLabel:SetTextColor(color_white)
    titleLabel:SizeToContents()
    titleLabel:SetPos(scaleSize(10), scaleSize(10))
    
    -- Buttons panel
    local buttonsPanel = vgui.Create("DPanel", controlPanel)
    buttonsPanel:SetPos(scaleSize(10), scaleSize(40))
    buttonsPanel:SetSize(scaleSize(500), scaleSize(50))
    buttonsPanel.Paint = function() end
    
    -- Rescan button
    local rescanButton = vgui.Create("DButton", buttonsPanel)
    rescanButton:SetText("Rescan All Models")
    rescanButton:SetIcon("icon16/arrow_refresh.png")
    rescanButton:SetSize(scaleSize(150), scaleSize(30))
    rescanButton:SetPos(0, 0)
    
    -- Add model button
    local addModelButton = vgui.Create("DButton", buttonsPanel)
    addModelButton:SetText("Add Model Manually")
    addModelButton:SetIcon("icon16/add.png")
    addModelButton:SetSize(scaleSize(150), scaleSize(30))
    addModelButton:SetPos(scaleSize(160), 0)
    
    -- Delete selected button
    local deleteButton = vgui.Create("DButton", buttonsPanel)
    deleteButton:SetText("Delete Selected")
    deleteButton:SetIcon("icon16/delete.png")
    deleteButton:SetSize(scaleSize(150), scaleSize(30))
    deleteButton:SetPos(scaleSize(320), 0)
    deleteButton:SetEnabled(false)
    
    -- Set price button
    local setPriceButton = vgui.Create("DButton", buttonsPanel)
    setPriceButton:SetText("Set Price")
    setPriceButton:SetIcon("icon16/coins.png")
    setPriceButton:SetSize(scaleSize(150), scaleSize(30))
    setPriceButton:SetPos(0, scaleSize(35))
    setPriceButton:SetEnabled(false)
    
    -- Rank management panel
    local rankManagePanel = vgui.Create("DPanel", controlPanel)
    rankManagePanel:SetSize(scaleSize(500), scaleSize(50))
    rankManagePanel:SetPos(scaleSize(10), scaleSize(40))
    rankManagePanel:SetVisible(false) -- Hidden initially
    rankManagePanel.Paint = function() end
    
    -- Change rank label
    local rankLabel = vgui.Create("DLabel", rankManagePanel)
    rankLabel:SetText("Change Rank:")
    rankLabel:SetFont("DermaDefault")
    rankLabel:SetTextColor(color_white)
    rankLabel:SizeToContents()
    rankLabel:SetPos(0, scaleSize(5))
    
    -- Rank combo box
    local rankCombo = vgui.Create("DComboBox", rankManagePanel)
    rankCombo:SetSize(scaleSize(120), scaleSize(25))
    rankCombo:SetPos(scaleSize(70), 0)
    rankCombo:SetValue("VIP")
    
    -- Add rank options
    for rankName, rankData in pairs(donator_vendor.Ranks) do
        rankCombo:AddChoice(rankName)
    end
    
    -- Apply rank button
    local applyRankButton = vgui.Create("DButton", rankManagePanel)
    applyRankButton:SetText("Apply to Selected")
    applyRankButton:SetSize(scaleSize(120), scaleSize(25))
    applyRankButton:SetPos(scaleSize(200), 0)
    applyRankButton:SetEnabled(false)
    
    -- Cancel button
    local cancelButton = vgui.Create("DButton", rankManagePanel)
    cancelButton:SetText("Cancel")
    cancelButton:SetSize(scaleSize(80), scaleSize(25))
    cancelButton:SetPos(scaleSize(330), 0)
    
    -- Selected models count
    local selectedCount = vgui.Create("DLabel", controlPanel)
    selectedCount:SetText("No models selected")
    selectedCount:SetFont("DermaDefault")
    selectedCount:SetTextColor(color_white)
    selectedCount:SizeToContents()
    selectedCount:SetPos(scaleSize(520), scaleSize(10))
    
    -- Filter panel
    local filterPanel = vgui.Create("DPanel", modelsPanel)
    filterPanel:SetHeight(scaleSize(40))
    filterPanel:Dock(TOP)
    filterPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
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
    filterEntry:SetSize(scaleSize(200), scaleSize(25))
    filterEntry:SetPos(scaleSize(50), scaleSize(8))
    filterEntry:SetUpdateOnType(true)
    
    -- Rank filter label
    local rankFilterLabel = vgui.Create("DLabel", filterPanel)
    rankFilterLabel:SetText("Rank:")
    rankFilterLabel:SetFont("DermaDefault")
    rankFilterLabel:SetTextColor(color_white)
    rankFilterLabel:SizeToContents()
    rankFilterLabel:SetPos(scaleSize(260), scaleSize(12))
    
    -- Rank filter combo
    local rankFilterCombo = vgui.Create("DComboBox", filterPanel)
    rankFilterCombo:SetSize(scaleSize(100), scaleSize(25))
    rankFilterCombo:SetPos(scaleSize(300), scaleSize(8))
    rankFilterCombo:SetValue("All Ranks")
    rankFilterCombo:AddChoice("All Ranks")
    
    -- Add rank options
    for rankName, _ in pairs(donator_vendor.Ranks) do
        rankFilterCombo:AddChoice(rankName)
    end
    
    -- Model list area
    local modelListArea = vgui.Create("DPanel", modelsPanel)
    modelListArea:Dock(FILL)
    modelListArea:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
    modelListArea.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
    end
    
    -- Status panel at the bottom
    local statusPanel = vgui.Create("DPanel", modelsPanel)
    statusPanel:SetHeight(scaleSize(30))
    statusPanel:Dock(BOTTOM)
    statusPanel:DockMargin(scaleSize(5), 0, scaleSize(5), scaleSize(5))
    statusPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 150))
    end
    
    local statusLabel = vgui.Create("DLabel", statusPanel)
    statusLabel:SetText("Select models to perform actions")
    statusLabel:SetFont("DermaDefault")
    statusLabel:SetTextColor(color_white)
    statusLabel:SizeToContents()
    statusLabel:Center()
    
    -- Create model list with checkboxes for all models
    local modelList = vgui.Create("DListView", modelListArea)
    modelList:Dock(FILL)
    modelList:DockMargin(scaleSize(5), scaleSize(5), scaleSize(5), scaleSize(5))
    modelList:SetMultiSelect(true)
    
    -- Add columns
    modelList:AddColumn("Selected")
    modelList:AddColumn("Model Name")
    modelList:AddColumn("Rank")
    modelList:AddColumn("Price")
    modelList:AddColumn("Model Path")
    modelList:AddColumn("Added")
    
    -- Function to refresh the model list
    local function refreshModelList(filter, rankFilter)
        modelList:Clear()
        local filteredModels = {}
        
        -- Apply filter
        for _, modelData in ipairs(availableModels) do
            local matchesFilter = true
            local matchesRank = true
            
            -- Text filter
            if filter and filter ~= "" then
                local lowerFilter = string.lower(filter)
                local lowerName = string.lower(modelData.Name or "")
                local lowerPath = string.lower(modelData.Model or "")
                
                if not (string.find(lowerName, lowerFilter) or string.find(lowerPath, lowerFilter)) then
                    matchesFilter = false
                end
            end
            
            -- Rank filter
            if rankFilter and rankFilter ~= "All Ranks" then
                if modelData.Rank ~= rankFilter then
                    matchesRank = false
                end
            end
            
            if matchesFilter and matchesRank then
                table.insert(filteredModels, modelData)
            end
        end
        
        -- Sort by name
        table.sort(filteredModels, function(a, b)
            if a.Rank == b.Rank then
                return a.Name < b.Name
            else
                return a.Rank < b.Rank
            end
        end)
        
        -- Add models to list
        for _, modelData in ipairs(filteredModels) do
            local dateStr = "Unknown"
            if modelData.DateAdded then
                dateStr = os.date("%Y-%m-%d %H:%M", modelData.DateAdded)
            end
            
            local manualStr = ""
            if modelData.ManuallyAdded then
                manualStr = " (Manual)"
            end
            
            local price = modelData.Price or donator_vendor.DEFAULT_PRICE
            
            modelList:AddLine("", modelData.Name, modelData.Rank, formatCurrency(price), modelData.Model, dateStr .. manualStr)
        end
    end
    
    -- Initial load of models
    refreshModelList()
    
    -- Selected models table
    local selectedModels = {}
    
    -- Handle selection
    modelList.OnRowSelected = function(parent, lineID, line)
        local modelPath = line:GetValue(5)
        
        if selectedModels[modelPath] then
            selectedModels[modelPath] = nil
            line:SetValue(1, "")
        else
            selectedModels[modelPath] = true
            line:SetValue(1, "✓")
        end
        
        -- Update selected count
        local count = 0
        for _ in pairs(selectedModels) do count = count + 1 end
        selectedCount:SetText(count .. " models selected")
        selectedCount:SizeToContents()
        
        -- Enable/disable buttons
        deleteButton:SetEnabled(count > 0)
        applyRankButton:SetEnabled(count > 0)
        setPriceButton:SetEnabled(count > 0)
    end
    
    -- Filter change event
    filterEntry.OnValueChange = function(self, value)
        refreshModelList(value, rankFilterCombo:GetValue())
    end
    
    -- Rank filter change event
    rankFilterCombo.OnSelect = function(self, index, value)
        refreshModelList(filterEntry:GetValue(), value)
    end
    
    -- Button click events
    rescanButton.DoClick = function()
        -- Show confirmation dialog
        showConfirmDialog(
            "Rescan Models", 
            "This will scan for new models in the default directories. Manually added models will be preserved. Continue?",
            function()
                -- Send rescan request to server
                net.Start("DonatorVendor_Admin_Action")
                net.WriteString("rescan_models")
                net.WriteTable({})
                net.SendToServer()
                
                playSound("ui/buttonclick.wav")
                statusLabel:SetText("Rescanning models...")
            end
        )
    end
    
    addModelButton.DoClick = function()
        createAddModelDialog()
    end
    
    deleteButton.DoClick = function()
        local modelList = {}
        for path in pairs(selectedModels) do
            table.insert(modelList, path)
        end
        
        if #modelList == 0 then return end
        
        -- Show confirmation dialog
        showConfirmDialog(
            "Delete Models", 
            "Are you sure you want to delete " .. #modelList .. " models from the database? This operation cannot be undone.",
            function()
                -- Send delete request to server
                net.Start("DonatorVendor_Admin_BulkAction")
                net.WriteString("delete_models")
                net.WriteUInt(#modelList, 16)
                
                for _, path in ipairs(modelList) do
                    net.WriteString(path)
                end
                
                net.SendToServer()
                
                statusLabel:SetText("Deleting " .. #modelList .. " models...")
                selectedModels = {}
                
                playSound("buttons/button14.wav")
            end
        )
    end
    
    -- Set price button
    setPriceButton.DoClick = function()
        local modelList = {}
        for path in pairs(selectedModels) do
            table.insert(modelList, path)
        end
        
        if #modelList == 0 then return end
        
        -- Create price dialog
        createPriceDialog(selectedModels, function(price)
            -- Send price update request to server
            net.Start("DonatorVendor_Admin_BulkAction")
            net.WriteString("update_prices")
            net.WriteUInt(#modelList, 16)
            
            for _, path in ipairs(modelList) do
                net.WriteString(path)
            end
            
            net.WriteBool(true)
            net.WriteTable({price = price})
            net.SendToServer()
            
            statusLabel:SetText("Updating price for " .. #modelList .. " models...")
            
            playSound("buttons/button14.wav")
        end)
    end
    
    -- Rank change button
    local rankChangeButton = vgui.Create("DButton", buttonsPanel)
    rankChangeButton:SetText("Change Rank")
    rankChangeButton:SetIcon("icon16/tag_blue.png")
    rankChangeButton:SetSize(scaleSize(150), scaleSize(30))
    rankChangeButton:SetPos(scaleSize(160), scaleSize(35))
    
    rankChangeButton.DoClick = function()
        -- Show rank management panel, hide buttons panel
        buttonsPanel:SetVisible(false)
        rankManagePanel:SetVisible(true)
        
        playSound("ui/buttonclick.wav")
    end
    
    -- Cancel button for rank change
    cancelButton.DoClick = function()
        -- Show buttons panel, hide rank management panel
        buttonsPanel:SetVisible(true)
        rankManagePanel:SetVisible(false)
        
        playSound("ui/buttonclick.wav")
    end
    
    -- Apply rank to selected models
    applyRankButton.DoClick = function()
        local selectedRank = rankCombo:GetValue()
        if selectedRank == "Select Rank" then return end
        
        local modelList = {}
        for path in pairs(selectedModels) do
            table.insert(modelList, path)
        end
        
        if #modelList == 0 then return end
        
        -- Send change rank request to server
        net.Start("DonatorVendor_Admin_BulkAction")
        net.WriteString("change_rank")
        net.WriteUInt(#modelList, 16)
        
        for _, path in ipairs(modelList) do
            net.WriteString(path)
        end
        
        net.WriteBool(true)
        net.WriteTable({rank = selectedRank})
        net.SendToServer()
        
        statusLabel:SetText("Changing rank for " .. #modelList .. " models...")
        
        -- Show buttons panel, hide rank management panel
        buttonsPanel:SetVisible(true)
        rankManagePanel:SetVisible(false)
        
        playSound("buttons/button14.wav")
    end
    
    -- Settings tab
    local settingsPanel = vgui.Create("DPanel")
    settingsPanel:Dock(FILL)
    settingsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 100))
    end
    
    -- Settings title
    local settingsTitle = vgui.Create("DLabel", settingsPanel)
    settingsTitle:SetText("Donator Vendor Settings")
    settingsTitle:SetFont("Trebuchet24")
    settingsTitle:SetTextColor(color_white)
    settingsTitle:SizeToContents()
    settingsTitle:SetPos(scaleSize(20), scaleSize(20))
    
    -- Help text
    local helpText = vgui.Create("DLabel", settingsPanel)
    helpText:SetText("Donator Vendor Usage Instructions:")
    helpText:SetFont("DermaDefaultBold")
    helpText:SetTextColor(color_white)
    helpText:SizeToContents()
    helpText:SetPos(scaleSize(20), scaleSize(70))
    
    local helpContent = vgui.Create("DLabel", settingsPanel)
    helpContent:SetText(
        "- To add models, place them in the appropriate directory:\n" ..
        "  • VIP models: models/player/donator/vip/\n" ..
        "  • VIP+ models: models/player/donator/vipplus/\n" ..
        "  • Legend models: models/player/donator/legend/\n\n" ..
        "- You can add models manually using the 'Add Model Manually' button\n" ..
        "- Set model prices using the 'Set Price' button\n" ..
        "- Prices are based on your server's Currency system (GetNWInt)\n" ..
        "- SAM Admin ranks are automatically used to determine access"
    )
    helpContent:SetFont("DermaDefault")
    helpContent:SetTextColor(color_white)
    helpContent:SetSize(scaleSize(700), scaleSize(200))
    helpContent:SetPos(scaleSize(20), scaleSize(90))
    helpContent:SetContentAlignment(7) -- Top-left
    helpContent:SetWrap(true)
    
    -- Default price setting
    local defaultPriceLabel = vgui.Create("DLabel", settingsPanel)
    defaultPriceLabel:SetText("Default Price for New Models:")
    defaultPriceLabel:SetFont("DermaDefaultBold")
    defaultPriceLabel:SetTextColor(color_white)
    defaultPriceLabel:SizeToContents()
    defaultPriceLabel:SetPos(scaleSize(20), scaleSize(220))
    
    local defaultPriceEntry = vgui.Create("DNumberWang", settingsPanel)
    defaultPriceEntry:SetPos(scaleSize(180), scaleSize(220))
    defaultPriceEntry:SetSize(scaleSize(100), scaleSize(20))
    defaultPriceEntry:SetValue(donator_vendor.DEFAULT_PRICE)
    defaultPriceEntry:SetMin(0)
    defaultPriceEntry:SetMax(100000)
    
    local defaultPriceButton = vgui.Create("DButton", settingsPanel)
    defaultPriceButton:SetText("Update")
    defaultPriceButton:SetPos(scaleSize(290), scaleSize(220))
    defaultPriceButton:SetSize(scaleSize(60), scaleSize(20))
    
    defaultPriceButton.DoClick = function()
        local newPrice = defaultPriceEntry:GetValue()
        donator_vendor.DEFAULT_PRICE = newPrice
        
        createNotification("Default price updated to " .. formatCurrency(newPrice), COLOR_SUCCESS)
        playSound("ui/buttonclick.wav")
    end
    
    -- Add tabs
    adminTabs:AddSheet("Models", modelsPanel, "icon16/brick.png")
    adminTabs:AddSheet("Settings", settingsPanel, "icon16/cog.png")
    
    return adminTabs
end

-- Handle admin action response
net.Receive("DonatorVendor_Admin_ActionResponse", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    local data = net.ReadTable()
    
    if success then
        -- Update models if new data was sent
        if data and #data > 0 then
            availableModels = data
        end
        
        -- Refresh admin panel if open
        if IsValid(_G.DonatorVendorMenu) and selectedTab == "Admin" then
            -- Find the content panel first
            local mainPanel = _G.DonatorVendorMenu:GetChildren()[1]
            if IsValid(mainPanel) then
                local contentPanel = mainPanel:GetChildren()[2]  -- This should be the content panel
                if IsValid(contentPanel) then
                    createAdminPanel(contentPanel)
                end
            end
        end
        
        playSound("ui/achievement_earned.wav")
    else
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)

-- Handle bulk action result
net.Receive("DonatorVendor_Admin_BulkActionResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    local newModelsData = net.ReadTable()
    
    if success then
        -- Update models if new data was sent
        if newModelsData and #newModelsData > 0 then
            availableModels = newModelsData
        end
        
        -- Refresh admin panel if open
        if IsValid(_G.DonatorVendorMenu) and selectedTab == "Admin" then
            -- Find the content panel first
            local mainPanel = _G.DonatorVendorMenu:GetChildren()[1]
            if IsValid(mainPanel) then
                local contentPanel = mainPanel:GetChildren()[2]  -- This should be the content panel
                if IsValid(contentPanel) then
                    createAdminPanel(contentPanel)
                end
            end
        end
        
        playSound("ui/achievement_earned.wav")
    else
        playSound("buttons/button10.wav")
    end
    
    -- Show notification
    createNotification(message, success and COLOR_SUCCESS or COLOR_ERROR)
end)