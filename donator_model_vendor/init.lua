-- init.lua for donator_vendor entity
-- Created: 2025-05-25 19:51:38 by JamieL25
-- Updated: 2025-05-25 21:59:48 by JamieL25

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_admin.lua")  -- This line was missing
AddCSLuaFile("shared.lua")

include("shared.lua")

-- ========================================================================================
-- CONFIGURATION
-- ========================================================================================

-- File paths where we'll store data
local MODELS_DATA_FILE = "donator_vendor/models_data.json"
local BLACKLIST_FILE = "donator_vendor/blacklisted_models.json"

-- Default model price if not set
local DEFAULT_MODEL_PRICE = 1000

-- Log function (used throughout)
function logOperation(category, message)
    -- Skip logging if disabled in configuration
    if donator_vendor.ENABLE_LOGGING == false then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S UTC")
    print("[DonatorVendor LOG " .. timestamp .. "] " .. category .. " - " .. message)
end

-- ========================================================================================
-- CURRENCY FUNCTIONS
-- ========================================================================================

-- Function to get player money from your custom currency system
function donator_vendor.GetPlayerMoney(ply)
    if not IsValid(ply) then return 0 end
    
    -- Your custom currency system uses NWInt for storing currency
    return ply:GetNWInt("Currency", 0)
end

-- Function to take money from player
function donator_vendor.TakePlayerMoney(ply, amount)
    if not IsValid(ply) then return false end
    
    -- Get current balance
    local currentBalance = ply:GetNWInt("Currency", 0)
    
    -- Check if player has enough money
    if currentBalance < amount then
        return false
    end
    
    -- Subtract the amount from player's balance
    ply:SetNWInt("Currency", currentBalance - amount)
    
    return true
end

-- ========================================================================================
-- DATA MANAGEMENT
-- ========================================================================================

-- Save models data to file
function saveModelsData(data)
    if not data then return false end
    
    -- Create directory if it doesn't exist
    if not file.Exists("donator_vendor", "DATA") then
        file.CreateDir("donator_vendor")
    end
    
    -- Save to file
    local jsonStr = util.TableToJSON(data, true)
    file.Write(MODELS_DATA_FILE, jsonStr)
    
    return true
end

-- Load models data from file
function loadModelsData()
    if not file.Exists(MODELS_DATA_FILE, "DATA") then
        return {}
    end
    
    local jsonStr = file.Read(MODELS_DATA_FILE, "DATA")
    local data = util.JSONToTable(jsonStr) or {}
    
    return data
end

-- Save blacklist to file
function saveBlacklist(data)
    if not data then return false end
    
    -- Create directory if it doesn't exist
    if not file.Exists("donator_vendor", "DATA") then
        file.CreateDir("donator_vendor")
    end
    
    -- Save to file
    local jsonStr = util.TableToJSON(data, true)
    file.Write(BLACKLIST_FILE, jsonStr)
    
    return true
end

-- Load blacklist from file
function loadBlacklist()
    if not file.Exists(BLACKLIST_FILE, "DATA") then
        return {}
    end
    
    local jsonStr = file.Read(BLACKLIST_FILE, "DATA")
    local data = util.JSONToTable(jsonStr) or {}
    
    return data
end

-- Check if a model is valid player model
function isValidPlayerModel(modelPath)
    -- Make sure it's a .mdl file
    if not string.match(modelPath, "%.mdl$") then
        return false
    end
    
    -- Check if model exists
    if not util.IsValidModel(modelPath) then
        return false
    end
    
    return true
end

-- Initialize storage
donator_vendor.models_data = loadModelsData()
donator_vendor.blacklist = loadBlacklist()

-- ========================================================================================
-- NETWORK SETUP
-- ========================================================================================

-- Register all network messages
util.AddNetworkString("DonatorVendor_OpenMenu")
util.AddNetworkString("DonatorVendor_EquipModel")
util.AddNetworkString("DonatorVendor_EquipResult")
util.AddNetworkString("DonatorVendor_PurchaseModel")
util.AddNetworkString("DonatorVendor_PurchaseResult")
util.AddNetworkString("DonatorVendor_Admin_Action")
util.AddNetworkString("DonatorVendor_Admin_ActionResponse")
util.AddNetworkString("DonatorVendor_Admin_BulkAction")
util.AddNetworkString("DonatorVendor_Admin_BulkActionResult")
util.AddNetworkString("DonatorVendor_Admin_GetBlacklist")
util.AddNetworkString("DonatorVendor_Admin_BlacklistResponse")
util.AddNetworkString("DonatorVendor_FixWeaponVisibility")
util.AddNetworkString("DonatorVendor_Admin_AddModel")

-- ========================================================================================
-- WEAPON VISIBILITY FIX
-- ========================================================================================

-- Function to fix weapon visibility for players (from player_model_vendor)
function donator_vendor.FixPlayerWeapons(ply)
    if not IsValid(ply) then return end
    
    -- Fix all weapons
    for _, weapon in pairs(ply:GetWeapons()) do
        if IsValid(weapon) then
            weapon:SetNoDraw(false)
        end
    end
end

-- Function to fix all players' weapons
function donator_vendor.FixAllPlayersWeapons()
    for _, ply in ipairs(player.GetAll()) do
        donator_vendor.FixPlayerWeapons(ply)
    end
end

-- Add console command to fix weapon visibility
concommand.Add("fix_weapons", function(ply, cmd, args)
    if IsValid(ply) then
        donator_vendor.FixPlayerWeapons(ply)
        ply:ChatPrint("Weapon visibility has been fixed!")
    end
end)

-- Add hook for when players spawn
hook.Add("PlayerSpawn", "DV_FixWeaponsOnSpawn", function(ply)
    -- Short delay to ensure all weapons are given to player
    timer.Simple(0.5, function()
        if IsValid(ply) then
            donator_vendor.FixPlayerWeapons(ply)
        end
    end)
end)

-- Add hook for when players change weapons
hook.Add("PlayerSwitchWeapon", "DV_FixWeaponsOnSwitch", function(ply, oldWeapon, newWeapon)
    -- Fix weapon visibility after weapon switch
    timer.Simple(0.1, function()
        if IsValid(ply) and IsValid(newWeapon) then
            newWeapon:SetNoDraw(false)
        end
    end)
end)

-- ========================================================================================
-- DONATOR RANK FUNCTIONS (SAM INTEGRATION)
-- ========================================================================================

-- Function to check if player has a specific donator rank
function donator_vendor.HasRank(ply, rankName)
    if not IsValid(ply) then return false end
    
    -- Admin or superadmin can access all ranks
    if ply:IsAdmin() or ply:IsSuperAdmin() then
        return true
    end
    
    -- SAM Integration
    if SAM then
        local userGroup = sam.player.get_usergroup(ply)
        
        if not userGroup then return false end
        
        -- Get required rank data
        local requiredRankData = donator_vendor.Ranks[rankName]
        if not requiredRankData then return false end
        
        -- Check if player's SAM rank matches required rank directly
        if userGroup == rankName then
            return true
        end
        
        -- Check if player's SAM rank has equal or higher order than required rank
        local userRankData = donator_vendor.Ranks[userGroup]
        if userRankData and userRankData.order >= requiredRankData.order then
            return true
        end
        
        return false
    else
        -- Fallback if SAM is not available
        return false
    end
end

-- Function to get accessible tabs for a player
function donator_vendor.GetAccessibleTabs(ply)
    if not IsValid(ply) then return {} end
    
    -- Admin or superadmin can access all tabs
    if ply:IsAdmin() or ply:IsSuperAdmin() then
        local allTabs = {}
        for rankName, _ in pairs(donator_vendor.Ranks) do
            table.insert(allTabs, rankName)
        end
        return allTabs
    end
    
    -- SAM Integration
    if SAM then
        local userGroup = sam.player.get_usergroup(ply)
        
        if not userGroup then return {} end
        
        local rankData = donator_vendor.Ranks[userGroup]
        if rankData then
            return rankData.can_access
        end
    end
    
    return {}
end

-- ========================================================================================
-- MODEL MANAGEMENT FUNCTIONS
-- ========================================================================================

-- Function to check if player owns a model
function donator_vendor.PlayerOwnsModel(ply, modelPath)
    if not IsValid(ply) then return false end
    
    -- Admins automatically own all models
    if ply:IsAdmin() or ply:IsSuperAdmin() then
        return true
    end
    
    -- Check if player has purchased this model
    local ownedModelsStr = ply:GetPData("donator_vendor_owned_models", "")
    if ownedModelsStr == "" then
        return false
    end
    
    local ownedModels = util.JSONToTable(ownedModelsStr) or {}
    
    return ownedModels[modelPath] == true
end

-- Function to add a model to player's owned models
function donator_vendor.AddPlayerOwnedModel(ply, modelPath)
    if not IsValid(ply) then return false end
    
    -- Get current owned models
    local ownedModelsStr = ply:GetPData("donator_vendor_owned_models", "")
    local ownedModels = {}
    
    if ownedModelsStr != "" then
        ownedModels = util.JSONToTable(ownedModelsStr) or {}
    end
    
    -- Add the model
    ownedModels[modelPath] = true
    
    -- Save back to PData
    ply:SetPData("donator_vendor_owned_models", util.TableToJSON(ownedModels))
    
    return true
end

-- Function to get all models a player owns
function donator_vendor.GetPlayerOwnedModels(ply)
    if not IsValid(ply) then return {} end
    
    -- Get current owned models
    local ownedModelsStr = ply:GetPData("donator_vendor_owned_models", "")
    local ownedModels = {}
    
    if ownedModelsStr != "" then
        ownedModels = util.JSONToTable(ownedModelsStr) or {}
    end
    
    -- Convert to an array
    local result = {}
    for path, _ in pairs(ownedModels) do
        table.insert(result, path)
    end
    
    return result
end

-- ========================================================================================
-- MODEL SCANNING FUNCTIONS
-- ========================================================================================

-- Scan for models in a specific directory for a rank
function donator_vendor.ScanForModels(rankName, directory)
    if not rankName then return {} end
    
    -- Ensure directory path ends with a slash
    if not string.EndsWith(directory, "/") then
        directory = directory .. "/"
    end
    
    local models = {}
    local modelCount = 0
    local processedPaths = {}
    
    -- Check if there's a blacklist
    local blacklistLookup = {}
    for _, entry in ipairs(donator_vendor.blacklist) do
        blacklistLookup[entry.model_path] = true
    end
    
    -- Find all model files in the directory
    local files, directories = file.Find(directory .. "*.mdl", "GAME")
    
    -- Process found files
    for _, filename in ipairs(files) do
        local path = directory .. filename
        
        -- Skip if already processed
        if processedPaths[path] then
            continue
        end
        
        processedPaths[path] = true
        
        -- Skip if in blacklist
        if blacklistLookup[path] then 
            continue
        end
        
        -- Check if valid player model
        if isValidPlayerModel(path) then
            local name = donator_vendor.GetNameFromModelPath(path)
            
            -- Check if this model is already in our data
            local existingData = nil
            
            for _, modelData in pairs(donator_vendor.models_data) do
                if modelData.Model == path then
                    existingData = modelData
                    break
                end
            end
            
            -- Use existing data or create new
            local modelEntry = existingData or {
                Model = path,
                Name = name,
                Rank = rankName,
                Price = DEFAULT_MODEL_PRICE,
                DateAdded = os.time()
            }
            
            modelEntry.Rank = rankName -- Always update the rank
            
            -- Add to list
            table.insert(models, modelEntry)
            modelCount = modelCount + 1
        end
    end
    
    -- Sort by name
    table.sort(models, function(a, b) return a.Name < b.Name end)
    
    logOperation("SCAN", "Found " .. modelCount .. " valid player models for rank " .. rankName)
    
    return models
end

-- Function to scan models for all ranks
function donator_vendor.ScanAllModels()
    local allModels = {}
    local existingModels = donator_vendor.models_data or {}
    
    -- Directories for each rank
    local rankDirectories = {
        ["VIP"] = "models/player/donator/vip/",
        ["VIP+"] = "models/player/donator/vipplus/",
        ["Legend"] = "models/player/donator/legend/"
    }
    
    -- Scan each rank's directory
    for rankName, directory in pairs(rankDirectories) do
        local rankModels = donator_vendor.ScanForModels(rankName, directory)
        
        -- Add models to master list
        for _, model in ipairs(rankModels) do
            table.insert(allModels, model)
        end
    end
    
    -- Keep manually added models (that might not be in the standard directories)
    for _, modelData in ipairs(existingModels) do
        local found = false
        for _, newModelData in ipairs(allModels) do
            if modelData.Model == newModelData.Model then
                found = true
                break
            end
        end
        
        if not found and modelData.ManuallyAdded then
            -- Keep price and other properties when preserving manually added models
            table.insert(allModels, modelData)
        end
    end
    
    -- Save to storage
    donator_vendor.models_data = allModels
    saveModelsData(allModels)
    
    return allModels
end

-- Function to add a model manually
function donator_vendor.AddModelManually(modelPath, modelName, rankName, price)
    if not isValidPlayerModel(modelPath) then
        return false, "Invalid model path"
    end
    
    if not donator_vendor.Ranks[rankName] then
        return false, "Invalid rank name"
    end
    
    price = tonumber(price) or DEFAULT_MODEL_PRICE
    if price < 0 then
        price = DEFAULT_MODEL_PRICE
    end
    
    -- Check if model exists in database
    for i, modelData in ipairs(donator_vendor.models_data) do
        if modelData.Model == modelPath then
            -- Update existing model
            donator_vendor.models_data[i].Name = modelName
            donator_vendor.models_data[i].Rank = rankName
            donator_vendor.models_data[i].Price = price
            donator_vendor.models_data[i].ManuallyAdded = true
            
            saveModelsData(donator_vendor.models_data)
            return true, "Model updated successfully"
        end
    end
    
    -- Add new model
    local modelEntry = {
        Model = modelPath,
        Name = modelName,
        Rank = rankName,
        Price = price,
        DateAdded = os.time(),
        ManuallyAdded = true
    }
    
    table.insert(donator_vendor.models_data, modelEntry)
    saveModelsData(donator_vendor.models_data)
    
    return true, "Model added successfully"
end

-- Function to get models for a specific rank
function donator_vendor.GetModelsByRank(rankName)
    local models = {}
    
    for _, modelData in pairs(donator_vendor.models_data) do
        if modelData.Rank == rankName then
            table.insert(models, modelData)
        end
    end
    
    return models
end

-- Function to get a specific model by path
function donator_vendor.GetModelByPath(path)
    for _, modelData in pairs(donator_vendor.models_data) do
        if modelData.Model == path then
            return modelData
        end
    end
    return nil
end

-- Function to get models accessible to a specific player
function donator_vendor.GetAccessibleModels(ply)
    if not IsValid(ply) then return {} end
    
    local accessibleModels = {}
    local accessibleTabs = donator_vendor.GetAccessibleTabs(ply)
    
    -- Convert blacklist to lookup for faster checking
    local blacklistLookup = {}
    for _, entry in ipairs(donator_vendor.blacklist) do
        blacklistLookup[entry.model_path] = true
    end
    
    -- Get all owned model paths
    local ownedModels = donator_vendor.GetPlayerOwnedModels(ply)
    local ownedModelsLookup = {}
    for _, path in ipairs(ownedModels) do
        ownedModelsLookup[path] = true
    end
    
    -- Get models for each accessible rank
    for _, rankName in ipairs(accessibleTabs) do
        local rankModels = donator_vendor.GetModelsByRank(rankName)
        
        for _, modelData in ipairs(rankModels) do
            if not blacklistLookup[modelData.Model] then
                -- Add ownership status to model data
                modelData.Owned = ownedModelsLookup[modelData.Model] or false
                table.insert(accessibleModels, modelData)
            end
        end
    end
    
    return accessibleModels
end

-- Function to update model prices in bulk
function donator_vendor.UpdateModelPrices(modelPaths, newPrice)
    local updatedCount = 0
    
    for i, modelData in pairs(donator_vendor.models_data) do
        if table.HasValue(modelPaths, modelData.Model) then
            donator_vendor.models_data[i].Price = newPrice
            updatedCount = updatedCount + 1
        end
    end
    
    if updatedCount > 0 then
        saveModelsData(donator_vendor.models_data)
    end
    
    return updatedCount
end

-- ========================================================================================
-- ENTITY FUNCTIONS
-- ========================================================================================

-- Initialize entity
function ENT:Initialize()
    self:SetModel("models/breen.mdl")
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
    self:SetUseType(SIMPLE_USE)
    
    -- Set animation and position
    self:SetSequence("idle_subtle")
    
    -- Make sure the model database is initialized
    timer.Simple(1, function()
        if IsValid(self) and table.Count(donator_vendor.models_data) == 0 then
            logOperation("STARTUP", "No models data found, running initial scan")
            donator_vendor.ScanAllModels()
        else
            logOperation("STARTUP", "Loaded " .. table.Count(donator_vendor.models_data) .. " models from storage")
        end
        
        -- Fix weapons for all players
        timer.Simple(1, function()
            donator_vendor.FixAllPlayersWeapons()
        end)
    end)
    
    logOperation("INITIALIZE", "Donator Vendor initialized: " .. self:EntIndex())
end

-- Handle player usage (E key press)
function ENT:AcceptInput(name, activator, caller)
    if name != "Use" then return end
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    logOperation("USE", "Player " .. activator:Nick() .. " used the donator vendor")
    
    -- Ensure weapons are visible for the player
    donator_vendor.FixPlayerWeapons(activator)
    
    -- Open the model menu for the player
    self:OpenMenuForPlayer(activator)
    
    return true
end

-- Open vendor menu for player
function ENT:OpenMenuForPlayer(ply)
    if not IsValid(ply) then return end
    
    -- Get models accessible to this player
    local accessibleModels = donator_vendor.GetAccessibleModels(ply)
    
    -- Get accessible tabs
    local accessibleTabs = donator_vendor.GetAccessibleTabs(ply)
    
    -- Check if player has admin access
    local isAdmin = ply:IsAdmin() or ply:IsSuperAdmin()
    
    -- Get player's current balance
    local balance = donator_vendor.GetPlayerMoney(ply)
    
    -- Ensure weapon visibility before opening menu
    donator_vendor.FixPlayerWeapons(ply)
    
    -- Send menu data to client
    net.Start("DonatorVendor_OpenMenu")
    net.WriteTable(accessibleModels)
    net.WriteTable(accessibleTabs)
    net.WriteEntity(self)
    net.WriteBool(isAdmin)
    net.WriteInt(balance, 32) -- Send player's current balance
    net.Send(ply)
    
    logOperation("MENU", "Opened menu for " .. ply:Nick() .. " with " .. #accessibleModels .. " models")
end

-- Equip model attempt from client
net.Receive("DonatorVendor_EquipModel", function(len, ply)
    local vendorEnt = net.ReadEntity()
    local modelPath = net.ReadString()
    
    if not IsValid(vendorEnt) or vendorEnt:GetClass() != "donator_vendor" then
        return 
    end
    
    -- Check if player owns this model or is an admin
    local isAdmin = ply:IsAdmin() or ply:IsSuperAdmin()
    local ownsModel = donator_vendor.PlayerOwnsModel(ply, modelPath)
    
    if not isAdmin and not ownsModel then
        -- Send failure
        net.Start("DonatorVendor_EquipResult")
        net.WriteBool(false)
        net.WriteString("You don't own this model yet. Purchase it first!")
        net.Send(ply)
        
        logOperation("EQUIP_FAIL", "Player " .. ply:Nick() .. " failed to equip model (not owned): " .. modelPath)
        return
    end
    
    -- Process the equip request
    local accessibleModels = donator_vendor.GetAccessibleModels(ply)
    local canEquip = false
    
    -- Check if the model is accessible to this player
    for _, modelData in ipairs(accessibleModels) do
        if modelData.Model == modelPath then
            canEquip = true
            break
        end
    end
    
    if not canEquip then
        -- Send failure
        net.Start("DonatorVendor_EquipResult")
        net.WriteBool(false)
        net.WriteString("You don't have access to this model")
        net.Send(ply)
        
        logOperation("EQUIP_FAIL", "Player " .. ply:Nick() .. " failed to equip model (no access): " .. modelPath)
        return
    end
    
    -- Set the player model
    ply:SetModel(modelPath)
    
    -- Fix weapons visibility
    donator_vendor.FixPlayerWeapons(ply)
    
    -- Send success
    net.Start("DonatorVendor_EquipResult")
    net.WriteBool(true)
    net.WriteString("Model equipped successfully!")
    net.Send(ply)
    
    logOperation("EQUIP", "Player " .. ply:Nick() .. " equipped model: " .. modelPath)
end)

-- Purchase model attempt from client
net.Receive("DonatorVendor_PurchaseModel", function(len, ply)
    local vendorEnt = net.ReadEntity()
    local modelPath = net.ReadString()
    
    if not IsValid(vendorEnt) or vendorEnt:GetClass() != "donator_vendor" then
        return 
    end
    
    -- Check if player already owns this model
    if donator_vendor.PlayerOwnsModel(ply, modelPath) then
        -- Send failure
        net.Start("DonatorVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You already own this model!")
        net.WriteInt(donator_vendor.GetPlayerMoney(ply), 32)
        net.Send(ply)
        
        logOperation("PURCHASE_FAIL", "Player " .. ply:Nick() .. " already owns model: " .. modelPath)
        return
    end
    
    -- Get the model data
    local modelData = donator_vendor.GetModelByPath(modelPath)
    if not modelData then
        -- Send failure
        net.Start("DonatorVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Model not found in database")
        net.WriteInt(donator_vendor.GetPlayerMoney(ply), 32)
        net.Send(ply)
        
        logOperation("PURCHASE_FAIL", "Player " .. ply:Nick() .. " tried to purchase invalid model: " .. modelPath)
        return
    end
    
    -- Check if player can access this model
    local accessibleModels = donator_vendor.GetAccessibleModels(ply)
    local canAccess = false
    
    for _, accModelData in ipairs(accessibleModels) do
        if accModelData.Model == modelPath then
            canAccess = true
            break
        end
    end
    
    if not canAccess then
        -- Send failure
        net.Start("DonatorVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You don't have access to this model")
        net.WriteInt(donator_vendor.GetPlayerMoney(ply), 32)
        net.Send(ply)
        
        logOperation("PURCHASE_FAIL", "Player " .. ply:Nick() .. " failed to purchase model (no access): " .. modelPath)
        return
    end
    
    -- Check if player has enough money
    local price = modelData.Price or DEFAULT_MODEL_PRICE
    local playerMoney = donator_vendor.GetPlayerMoney(ply)
    
    if playerMoney < price then
        -- Send failure
        net.Start("DonatorVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Not enough currency! You need " .. price)
        net.WriteInt(playerMoney, 32)
        net.Send(ply)
        
        logOperation("PURCHASE_FAIL", "Player " .. ply:Nick() .. " failed to purchase model (not enough money): " .. modelPath)
        return
    end
    
    -- Take the money
    if not donator_vendor.TakePlayerMoney(ply, price) then
        -- Send failure
        net.Start("DonatorVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Failed to process payment")
        net.WriteInt(donator_vendor.GetPlayerMoney(ply), 32)
        net.Send(ply)
        
        logOperation("PURCHASE_FAIL", "Player " .. ply:Nick() .. " failed to purchase model (payment process failed): " .. modelPath)
        return
    end
    
    -- Add to owned models
    donator_vendor.AddPlayerOwnedModel(ply, modelPath)
    
    -- Send success
    net.Start("DonatorVendor_PurchaseResult")
    net.WriteBool(true)
    net.WriteString("Successfully purchased model for " .. price .. " currency!")
    net.WriteInt(donator_vendor.GetPlayerMoney(ply), 32)
    net.Send(ply)
    
    logOperation("PURCHASE", "Player " .. ply:Nick() .. " purchased model: " .. modelPath .. " for " .. price)
end)

-- Admin actions
net.Receive("DonatorVendor_Admin_Action", function(len, ply)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    
    local action = net.ReadString()
    local data = net.ReadTable()
    
    if action == "rescan_models" then
        -- Rescan all models
        local models = donator_vendor.ScanAllModels()
        
        net.Start("DonatorVendor_Admin_ActionResponse")
        net.WriteBool(true)
        net.WriteString("Rescanned models: Found " .. #models .. " models")
        net.WriteTable(models)
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " rescanned models")
    elseif action == "get_blacklist" then
        -- Send blacklist to client
        net.Start("DonatorVendor_Admin_BlacklistResponse")
        net.WriteTable(donator_vendor.blacklist)
        net.Send(ply)
    elseif action == "add_model" then
        -- Add or update a model manually
        local modelPath = data.modelPath
        local modelName = data.modelName
        local rankName = data.rankName
        local price = tonumber(data.price) or DEFAULT_MODEL_PRICE
        
        local success, message = donator_vendor.AddModelManually(modelPath, modelName, rankName, price)
        
        net.Start("DonatorVendor_Admin_ActionResponse")
        net.WriteBool(success)
        net.WriteString(message)
        net.WriteTable(success and donator_vendor.models_data or {})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " " .. (success and "added/updated" or "failed to add") .. " model: " .. modelPath)
    end
end)

-- Admin bulk actions
net.Receive("DonatorVendor_Admin_BulkAction", function(len, ply)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    
    local action = net.ReadString()
    local modelCount = net.ReadUInt(16)
    local modelPaths = {}
    
    -- Read all model paths
    for i = 1, modelCount do
        table.insert(modelPaths, net.ReadString())
    end
    
    if action == "blacklist_models" then
        -- Add models to blacklist
        local blacklist = donator_vendor.blacklist or {}
        
        -- Read additional data if available
        local hasAdditionalData = net.ReadBool()
        local additionalData = hasAdditionalData and net.ReadTable() or {}
        local reason = additionalData.reason or "No reason provided"
        
        -- Convert paths to lookup table
        local pathsLookup = {}
        for _, path in ipairs(modelPaths) do
            pathsLookup[path] = true
        end
        
        -- Add new entries to blacklist
        for _, path in ipairs(modelPaths) do
            table.insert(blacklist, {
                model_path = path,
                reason = reason,
                added_by = ply:Nick(),
                added_by_steamid = ply:SteamID(),
                date_added = os.time()
            })
        end
        
        donator_vendor.blacklist = blacklist
        saveBlacklist(blacklist)
        
        -- Send success
        net.Start("DonatorVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Added " .. #modelPaths .. " models to blacklist")
        net.WriteTable({})
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " blacklisted " .. #modelPaths .. " models")
        
    elseif action == "unblacklist_models" then
        -- Remove models from blacklist
        local blacklist = donator_vendor.blacklist or {}
        local newBlacklist = {}
        local removedCount = 0
        
        -- Convert paths to lookup table
        local pathsLookup = {}
        for _, path in ipairs(modelPaths) do
            pathsLookup[path] = true
        end
        
        -- Filter out removed models
        for _, entry in ipairs(blacklist) do
            if not pathsLookup[entry.model_path] then
                table.insert(newBlacklist, entry)
            else
                removedCount = removedCount + 1
            end
        end
        
        donator_vendor.blacklist = newBlacklist
        saveBlacklist(newBlacklist)
        
        -- Send success
        net.Start("DonatorVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Removed " .. removedCount .. " models from blacklist")
        net.WriteTable({})
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " unblacklisted " .. removedCount .. " models")
    elseif action == "change_rank" then
        -- Read additional data
        local hasAdditionalData = net.ReadBool()
        local additionalData = hasAdditionalData and net.ReadTable() or {}
        local newRank = additionalData.rank or "VIP"
        
        local updatedCount = 0
        
        -- Update ranks
        for i, modelData in pairs(donator_vendor.models_data) do
            if table.HasValue(modelPaths, modelData.Model) then
                donator_vendor.models_data[i].Rank = newRank
                updatedCount = updatedCount + 1
            end
        end
        
        saveModelsData(donator_vendor.models_data)
        
        -- Send success
        net.Start("DonatorVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Updated rank to " .. newRank .. " for " .. updatedCount .. " models")
        net.WriteTable(donator_vendor.models_data)
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " updated rank to " .. newRank .. " for " .. updatedCount .. " models")
    elseif action == "update_prices" then
        -- Read additional data
        local hasAdditionalData = net.ReadBool()
        local additionalData = hasAdditionalData and net.ReadTable() or {}
        local newPrice = tonumber(additionalData.price) or DEFAULT_MODEL_PRICE
        
        if newPrice < 0 then
            newPrice = DEFAULT_MODEL_PRICE
        end
        
        -- Update prices
        local updatedCount = donator_vendor.UpdateModelPrices(modelPaths, newPrice)
        
        -- Send success
        net.Start("DonatorVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Updated price to " .. newPrice .. " for " .. updatedCount .. " models")
        net.WriteTable(donator_vendor.models_data)
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " updated price to " .. newPrice .. " for " .. updatedCount .. " models")
    elseif action == "delete_models" then
        -- Remove models from database
        local modelsCopy = table.Copy(donator_vendor.models_data)
        local newModelsList = {}
        local removedCount = 0
        
        -- Convert paths to lookup table
        local pathsLookup = {}
        for _, path in ipairs(modelPaths) do
            pathsLookup[path] = true
        end
        
        -- Filter out removed models
        for _, modelData in ipairs(modelsCopy) do
            if not pathsLookup[modelData.Model] then
                table.insert(newModelsList, modelData)
            else
                removedCount = removedCount + 1
            end
        end
        
        donator_vendor.models_data = newModelsList
        saveModelsData(newModelsList)
        
        -- Send success
        net.Start("DonatorVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Removed " .. removedCount .. " models from database")
        net.WriteTable(donator_vendor.models_data)
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " deleted " .. removedCount .. " models")
    end
end)

-- Add hook for when weapons are given to players
hook.Add("WeaponEquip", "DV_FixWeaponOnEquip", function(weapon, ply)
    if IsValid(weapon) and IsValid(ply) then
        -- Ensure weapon is visible when equipped
        timer.Simple(0.1, function()
            if IsValid(weapon) then
                weapon:SetNoDraw(false)
            end
        end)
    end
end)

-- Make SAM integration debug info hook if needed
hook.Add("PlayerInitialSpawn", "DV_DebugSAMRanks", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) and ply:IsAdmin() then
            -- Only for admins during development
            if SAM then
                local userGroup = sam.player.get_usergroup(ply)
                print("[DonatorVendor] SAM Integration - Player: " .. ply:Nick() .. " Rank: " .. (userGroup or "unknown"))
                
                -- Debug accessible tabs
                local tabs = donator_vendor.GetAccessibleTabs(ply)
                print("[DonatorVendor] Accessible tabs: " .. table.concat(tabs, ", "))
            else
                print("[DonatorVendor] SAM Admin is not installed or not detected")
            end
        end
    end)
end)

print("--- [NPC DonatorModelVendor SCRIPT] init.lua finished loading by SERVER ---")