-- init.lua for player_model_vendor entity
-- Updated: 2025-05-11 21:46:17 by JamieL25
-- Enhanced model scanning system with custom currency integration
-- Fixed weapon visibility issues globally

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- ========================================================================================
-- CONFIGURATION
-- ========================================================================================

-- Default price for models if not specifically set
local DEFAULT_MODEL_PRICE = 1000

-- File paths where we'll store data
local MODELS_DATA_FILE = "playermodelvendor/models_data.json"
local OWNED_MODELS_FILE = "playermodelvendor/owned_models.json"
local BLACKLIST_FILE = "playermodelvendor/blacklisted_models.json"

-- Log function (used throughout)
function logOperation(category, message)
    -- Skip logging if disabled in configuration
    if player_model_vendor.ENABLE_LOGGING == false then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S UTC")
    print("[PlayerModelVendor LOG " .. timestamp .. "] " .. category .. " - " .. message)
end

-- ========================================================================================
-- STORAGE SETUP
-- ========================================================================================

-- Ensure data directory exists
if not file.IsDir("playermodelvendor", "DATA") then
    file.CreateDir("playermodelvendor")
    logOperation("STORAGE", "Created data directory")
end

-- Load models data
local function loadModelsData()
    if file.Exists(MODELS_DATA_FILE, "DATA") then
        local data = file.Read(MODELS_DATA_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, data)
        
        if success and result then
            logOperation("STORAGE", "Loaded models data: " .. table.Count(result) .. " entries")
            return result
        else
            logOperation("ERROR", "Failed to parse models data JSON")
            return {}
        end
    else
        logOperation("STORAGE", "No models data file found, will create on first scan")
        return {}
    end
end

-- Save models data
local function saveModelsData(data)
    if not data then return false end
    
    local json = util.TableToJSON(data, true) -- Pretty print
    file.Write(MODELS_DATA_FILE, json)
    logOperation("STORAGE", "Saved models data: " .. table.Count(data) .. " entries")
    return true
end

-- Load owned models
local function loadOwnedModels()
    if file.Exists(OWNED_MODELS_FILE, "DATA") then
        local data = file.Read(OWNED_MODELS_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, data)
        
        if success and result then
            logOperation("STORAGE", "Loaded owned models data")
            return result
        else
            logOperation("ERROR", "Failed to parse owned models JSON")
            return {}
        end
    else
        logOperation("STORAGE", "No owned models file found, creating new")
        return {}
    end
end

-- Save owned models
local function saveOwnedModels(data)
    if not data then return false end
    
    local json = util.TableToJSON(data, true) -- Pretty print
    file.Write(OWNED_MODELS_FILE, json)
    logOperation("STORAGE", "Saved owned models data")
    return true
end

-- Load blacklist
local function loadBlacklist()
    if file.Exists(BLACKLIST_FILE, "DATA") then
        local data = file.Read(BLACKLIST_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, data)
        
        if success and result then
            logOperation("STORAGE", "Loaded blacklist: " .. table.Count(result) .. " entries")
            return result
        else
            logOperation("ERROR", "Failed to parse blacklist JSON")
            return {}
        end
    else
        logOperation("STORAGE", "No blacklist file found, creating new")
        return {}
    end
end

-- Save blacklist
local function saveBlacklist(data)
    if not data then return false end
    
    local json = util.TableToJSON(data, true)
    file.Write(BLACKLIST_FILE, json)
    logOperation("STORAGE", "Saved blacklist: " .. table.Count(data) .. " entries")
    return true
end

-- Initialize storage
player_model_vendor.models_data = loadModelsData()
player_model_vendor.owned_models = loadOwnedModels()
player_model_vendor.blacklist = loadBlacklist()

-- ========================================================================================
-- NETWORK SETUP
-- ========================================================================================

-- Register all network messages
util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")
util.AddNetworkString("BG_PlayerModelVendor_EquipOwnedModel")
util.AddNetworkString("BG_PlayerModelVendor_EquipResult")
util.AddNetworkString("BG_PlayerModelVendor_Admin_Action")
util.AddNetworkString("BG_PlayerModelVendor_Admin_ActionResponse")
util.AddNetworkString("BG_PlayerModelVendor_Admin_BulkAction")
util.AddNetworkString("BG_PlayerModelVendor_Admin_BulkActionResult")
util.AddNetworkString("BG_PlayerModelVendor_Admin_GetBlacklist")
util.AddNetworkString("BG_PlayerModelVendor_Admin_BlacklistResponse")
util.AddNetworkString("BG_PlayerModelVendor_FixWeaponVisibility")

-- ========================================================================================
-- WEAPON VISIBILITY FIX
-- ========================================================================================

-- Add a weapon visibility fix function
function player_model_vendor.FixPlayerWeapons(ply)
    if not IsValid(ply) then return end
    
    -- Fix all weapons for the player
    for _, wep in pairs(ply:GetWeapons()) do
        if IsValid(wep) then
            -- Make sure weapon is visible
            wep:SetNoDraw(false)
        end
    end
    
    -- Make sure active weapon is visible
    local activeWeapon = ply:GetActiveWeapon()
    if IsValid(activeWeapon) then
        activeWeapon:SetNoDraw(false)
    end
    
    logOperation("WEAPON_FIX", "Fixed weapon visibility for " .. ply:Nick())
end

-- Global fix for all players
function player_model_vendor.FixAllPlayersWeapons()
    for _, ply in ipairs(player.GetAll()) do
        player_model_vendor.FixPlayerWeapons(ply)
    end
    
    logOperation("WEAPON_FIX", "Fixed weapon visibility for all players")
end

-- Console command to fix weapon visibility
concommand.Add("fix_weapons", function(ply)
    if IsValid(ply) then
        player_model_vendor.FixPlayerWeapons(ply)
        ply:ChatPrint("Weapon visibility has been fixed!")
    end
end)

-- Add hook for when players spawn
hook.Add("PlayerSpawn", "PMV_FixWeaponsOnSpawn", function(ply)
    -- Short delay to ensure all weapons are given to player
    timer.Simple(0.5, function()
        if IsValid(ply) then
            player_model_vendor.FixPlayerWeapons(ply)
        end
    end)
end)

-- Add hook for when players change weapons
hook.Add("PlayerSwitchWeapon", "PMV_FixWeaponsOnSwitch", function(ply, oldWeapon, newWeapon)
    -- Fix weapon visibility after weapon switch
    timer.Simple(0.1, function()
        if IsValid(ply) and IsValid(newWeapon) then
            newWeapon:SetNoDraw(false)
        end
    end)
end)

-- Add network message for client to request weapon fix
net.Receive("BG_PlayerModelVendor_FixWeaponVisibility", function(len, ply)
    if IsValid(ply) then
        player_model_vendor.FixPlayerWeapons(ply)
    end
end)

-- Fix weapons periodically to ensure they stay visible
timer.Create("PMV_PeriodicWeaponFix", 10, 0, function()
    player_model_vendor.FixAllPlayersWeapons()
end)

-- ========================================================================================
-- MODEL DISCOVERY & MANAGEMENT
-- ========================================================================================

-- Helper function to extract model name from path
function player_model_vendor.GetNameFromModelPath(path)
    -- Extract filename without extension
    local filename = string.match(path, ".+/(.+)%.mdl$") or "Unknown Model"
    
    -- Clean up the name
    filename = string.gsub(filename, "_", " ") -- Replace underscores with spaces
    
    -- Capitalize first letter of each word
    filename = string.gsub(filename, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    
    return filename
end

-- Recursively find model files
local function findModelsRecursive(baseDir, foundModels)
    local files, folders = file.Find(baseDir .. "/*", "GAME")
    
    -- Add all .mdl files in current directory
    for _, mdlFile in ipairs(files or {}) do
        if string.EndsWith(mdlFile, ".mdl") then
            table.insert(foundModels, baseDir .. "/" .. mdlFile)
        end
    end
    
    -- Recursively search subdirectories
    for _, folder in ipairs(folders or {}) do
        findModelsRecursive(baseDir .. "/" .. folder, foundModels)
    end
    
    return foundModels
end

-- Check if a model is a valid player model
local function isValidPlayerModel(modelPath)
    -- Skip certain obviously non-player models
    if string.find(modelPath, "hands%.mdl") or 
       string.find(modelPath, "gibs") or 
       string.find(modelPath, "error") or 
       string.find(modelPath, "_physics") or
       string.find(modelPath, "props_") or
       string.find(modelPath, "items_") or 
       string.find(modelPath, "weapons_") or
       string.find(modelPath, "/w_") or
       string.find(modelPath, "/c_") or
       string.find(modelPath, "shell") or
       string.find(modelPath, "/prop_") or
       string.find(modelPath, "/cs_") or
       string.find(modelPath, "/ph_") then
        return false
    end
    
    -- Try to get model info
    local modelInfo = util.GetModelInfo(modelPath)
    if not modelInfo then return false end
    
    -- Check if this is a common player model path
    local isCommonPlayerPath = false
    
    local playerPaths = {
        "/player/",
        "/humans/",
        "/characters/",
        "/pmc/", 
        "/PMC/",
        "/group",
        "/police",
        "/combine_",
        "/alyx",
        "/barney",
        "/breen",
        "/eli",
        "/gman",
        "/kleiner",
        "/monk",
        "/mossman",
        "/odessa",
        "/citizen",
        "/refugee",
        "/hostage",
        "/survivors",
        "/male_",
        "/female_"
    }
    
    for _, path in ipairs(playerPaths) do
        if string.find(modelPath, path) then
            isCommonPlayerPath = true
            break
        end
    end
    
    -- If it's not in a common player path, do more rigorous checks
    if not isCommonPlayerPath then
        -- Additional checks to exclude non-player models
        local fileSize = file.Size(modelPath, "GAME") or 0
        if fileSize < 20000 then
            -- Very small models are likely not player models
            return false
        end
        
        -- Try to check sequences (some models don't have animations)
        local validSequences = {"idle", "walk", "run", "sit"}
        
        local hasValidSequence = false
        for _, sequence in ipairs(validSequences) do
            if modelInfo.KeyValues and modelInfo.KeyValues.sequence and
               string.find(string.lower(modelInfo.KeyValues.sequence), sequence) then
                hasValidSequence = true
                break
            end
        end
        
        if not hasValidSequence then
            return false
        end
    end
    
    return true
end

-- Check mounted content
local function checkMounted(path, findPattern, foundModels)
    local mountedGames = engine.GetGames() or {}
    
    for _, game in ipairs(mountedGames) do
        if game.mounted then
            local files = file.Find(path .. findPattern, game.title) or {}
            
            for _, mdlFile in ipairs(files) do
                local fullPath = path .. mdlFile
                table.insert(foundModels, fullPath)
            end
            
            logOperation("SCAN", "Checked mounted content: " .. game.title .. " - Found " .. #files .. " models")
        end
    end
end

-- Aggressively scan for models
function player_model_vendor.ScanForModels()
    local models = {}
    local modelCount = 0
    local allModelFiles = {}
    local blacklist = player_model_vendor.blacklist or {}
    
    -- Convert blacklist to lookup table for faster checking
    local blacklistLookup = {}
    for _, entry in ipairs(blacklist) do
        blacklistLookup[entry.model_path] = true
    end
    
    -- FOLDER-BASED SCANNING
    -- Player models are typically in these folders (comprehensive list)
    local modelFolders = {
        "models/player",
        "models/humans",
        "models/characters",
        "models/alyx",
        "models/barney",
        "models/breen",
        "models/eli",
        "models/gman",
        "models/kleiner",
        "models/monk",
        "models/mossman",
        "models/odessa",
        "models/police",
        "models/combine_soldier",
        "models/combine_super_soldier",
        "models/vortigaunt",
        "models/zombie",
        "models/group01",
        "models/group02",
        "models/group03",
        "models/hostage",
        "models/coach",
        "models/ellis",
        "models/nick",
        "models/rochelle",
        "models/survivors",
        "models/pmc",     
        "models/PMC"      
    }
    
    -- First try the known player model folders
    for _, folder in ipairs(modelFolders) do
        if file.Exists(folder, "GAME") then
            local before = #allModelFiles
            findModelsRecursive(folder, allModelFiles)
            local after = #allModelFiles
            logOperation("SCAN", "Folder scan: " .. folder .. " - Found " .. (after - before) .. " models")
        end
    end
    
    -- DIRECT PATH SCANNING
    -- Special patterns (CSS, TF2, etc.)
    local patterns = {
        "models/player/*/*.mdl",
        "models/humans/*/*.mdl",
        "models/characters/*/*.mdl",
        "models/pmc/*/*.mdl",
        "models/PMC/*/*.mdl",
    }
    
    for _, pattern in ipairs(patterns) do
        local files, _ = file.Find(pattern, "GAME")
        for _, mdlFile in ipairs(files or {}) do
            local fullPath = pattern:gsub("%*%/%*%.mdl", "") .. mdlFile
            table.insert(allModelFiles, fullPath)
        end
        logOperation("SCAN", "Pattern scan: " .. pattern .. " - Found " .. #(files or {}) .. " models")
    end
    
    -- MOUNTED CONTENT SCANNING
    -- Check mounted content (CSS, TF2, etc)
    checkMounted("models/player/", "*.mdl", allModelFiles)
    checkMounted("models/player/", "*/*.mdl", allModelFiles)
    
    -- ADDON SCANNING
    -- Check all addon folders
    local addons = {}
    local _, addonDirs = file.Find("addons/*", "GAME")
    
    for _, addonDir in ipairs(addonDirs or {}) do
        if file.Exists("addons/" .. addonDir .. "/models", "GAME") then
            local modelFiles = {}
            findModelsRecursive("addons/" .. addonDir .. "/models", modelFiles)
            for _, model in ipairs(modelFiles) do
                -- Fixed: Use only the first return value from gsub
                local fixedPath = model:gsub("addons/" .. addonDir .. "/", "")
                table.insert(allModelFiles, fixedPath)
            end
            logOperation("SCAN", "Addon scan: " .. addonDir .. " - Found " .. #modelFiles .. " models")
        end
    end
    
    -- WORKSHOP CONTENT SCANNING
    -- Workshop content may be in a different location
    if file.Exists("workshop", "GAME") then
        local workshopModelFiles = {}
        findModelsRecursive("workshop", workshopModelFiles)
        for _, model in ipairs(workshopModelFiles) do
            if string.find(model, ".mdl") then
                table.insert(allModelFiles, model)
            end
        end
        logOperation("SCAN", "Workshop scan - Found " .. #workshopModelFiles .. " models")
    end
    
    -- PROCESS ALL FOUND MODELS
    -- Process each model
    local processedPaths = {} -- Track to avoid duplicates
    
    logOperation("SCAN", "Total models to process: " .. #allModelFiles)
    
    for _, path in ipairs(allModelFiles) do
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
            local name = player_model_vendor.GetNameFromModelPath(path)
            
            -- Check if this model is already in our data
            local existingData = nil
            
            for _, modelData in pairs(player_model_vendor.models_data) do
                if modelData.Model == path then
                    existingData = modelData
                    break
                end
            end
            
            -- Use existing data or create new
            local modelEntry = existingData or {
                Model = path,
                Name = name,
                Price = DEFAULT_MODEL_PRICE,
                DateAdded = os.time()
            }
            
            -- Add to list
            table.insert(models, modelEntry)
            modelCount = modelCount + 1
        end
    end
    
    -- Sort by name
    table.sort(models, function(a, b) return a.Name < b.Name end)
    
    -- Save to storage
    player_model_vendor.models_data = models
    saveModelsData(models)
    
    logOperation("SCAN", "Found " .. modelCount .. " valid player models")
    
    return models
end

-- Function to get a model by path
function player_model_vendor.GetModelByPath(path)
    for _, modelData in pairs(player_model_vendor.models_data) do
        if modelData.Model == path then
            return modelData
        end
    end
    return nil
end

-- ========================================================================================
-- ECONOMY INTEGRATION
-- ========================================================================================

-- Function to get player money from your custom currency system
function player_model_vendor.GetPlayerMoney(ply)
    if not IsValid(ply) then return 0 end
    
    -- Your custom currency system uses NWInt for storing currency
    return ply:GetNWInt("Currency", 0)
end

-- Function to take money from player
function player_model_vendor.TakePlayerMoney(ply, amount)
    if not IsValid(ply) then return false end
    
    -- Get current balance
    local currentBalance = ply:GetNWInt("Currency", 0)
    
    -- Check if player has enough money
    if currentBalance < amount then
        return false
    end
    
    -- Calculate new balance
    local newBalance = currentBalance - amount
    
    -- Update currency in the networked variable
    ply:SetNWInt("Currency", newBalance)
    
    -- Send update to client
    net.Start("UpdateCurrency")
        net.WriteInt(newBalance, 32)
    net.Send(ply)
    
    -- Update the database
    sql.Query("REPLACE INTO player_currency (steamid, currency) VALUES ("
        .. sql.SQLStr(ply:SteamID()) .. ", " .. newBalance .. ");")
    
    -- Log the transaction
    logOperation("PURCHASE", "Player " .. ply:Nick() .. " spent £" .. amount .. 
                 " (New balance: £" .. newBalance .. ")")
    
    return true
end

-- Format money for display
function player_model_vendor.FormatMoney(amount)
    return "£" .. string.Comma(amount)
end

-- ========================================================================================
-- OWNED MODELS MANAGEMENT
-- ========================================================================================

-- Get models owned by player (returns array of model data)
function player_model_vendor.GetPlayerOwnedModels(ply)
    if not IsValid(ply) then return {} end
    
    local steamID = ply:SteamID()
    local ownedModels = player_model_vendor.owned_models[steamID] or {}
    
    -- Format as array of model data for client
    local result = {}
    for path, _ in pairs(ownedModels) do
        local modelData = player_model_vendor.GetModelByPath(path)
        if modelData then
            table.insert(result, modelData)
        end
    end
    
    return result
end

-- Check if player owns a model
function player_model_vendor.PlayerOwnsModel(ply, modelPath)
    if not IsValid(ply) then return false end
    
    local steamID = ply:SteamID()
    local ownedModels = player_model_vendor.owned_models[steamID] or {}
    
    return ownedModels[modelPath] or false
end

-- Add model to player's owned list
function player_model_vendor.AddPlayerOwnedModel(ply, modelPath)
    if not IsValid(ply) then return false end
    
    local steamID = ply:SteamID()
    
    -- Initialize if needed
    player_model_vendor.owned_models[steamID] = player_model_vendor.owned_models[steamID] or {}
    
    -- Add model with timestamp
    player_model_vendor.owned_models[steamID][modelPath] = {
        purchased_at = os.time(),
        model_path = modelPath
    }
    
    -- Save to storage
    saveOwnedModels(player_model_vendor.owned_models)
    
    return true
end

-- ========================================================================================
-- ENTITY IMPLEMENTATION
-- ========================================================================================

-- Store the current animation sequence 
local CURRENT_SEQUENCE = 3

-- Initialize entity with improved animation handling
function ENT:Initialize()
    -- Important: Use same model as teleporter for consistent animation
    self:SetModel("models/player/breen.mdl") 
    
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_IDLE)
    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)
    self:SetBloodColor(BLOOD_COLOR_RED)
    
    -- Add NPC capabilities
    self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
    
    -- Force the entity to stay in place
    self:SetMoveType(MOVETYPE_NONE)
    
    -- Force specific sequence (PMC model works with sequence 1)
    self:ResetSequence(CURRENT_SEQUENCE)
    
    -- Fix T-Pose by directly setting ALL pose parameters to 0
    for i=0, self:GetNumPoseParameters()-1 do
        local poseName = self:GetPoseParameterName(i)
        if poseName then
            self:SetPoseParameter(poseName, 0)
        end
    end
    
    -- Extra visibility settings from teleporter
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:DrawShadow(true)
    
    -- Make sure we have models data
    if table.Count(player_model_vendor.models_data) == 0 then
        player_model_vendor.ScanForModels()
    end
    
    -- Fix weapons for all players on initialization
    timer.Simple(1, function()
        player_model_vendor.FixAllPlayersWeapons()
    end)
    
    logOperation("INITIALIZE", "Player Model Vendor initialized: " .. self:EntIndex())
end

-- Handle player usage (E key press)
function ENT:AcceptInput(name, activator, caller)
    if name != "Use" then return end
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    logOperation("USE", "Player " .. activator:Nick() .. " used the vendor")
    
    -- Ensure weapons are visible for the player
    player_model_vendor.FixPlayerWeapons(activator)
    
    -- Open the model menu for the player
    self:OpenMenuForPlayer(activator)
    
    return true
end

-- Open vendor menu for player
function ENT:OpenMenuForPlayer(ply)
    if not IsValid(ply) then return end
    
    -- Get all available models (excluding blacklisted ones)
    local availableModels = {}
    
    -- Convert blacklist to lookup for faster checking
    local blacklistLookup = {}
    for _, entry in ipairs(player_model_vendor.blacklist) do
        blacklistLookup[entry.model_path] = true
    end
    
    -- Filter out blacklisted models
    for _, modelData in pairs(player_model_vendor.models_data) do
        if not blacklistLookup[modelData.Model] then
            table.insert(availableModels, modelData)
        end
    end
    
    -- Get models owned by this player
    local ownedModels = player_model_vendor.GetPlayerOwnedModels(ply)
    
    -- Check if player has admin access for additional tabs
    local isAdmin = ply:IsAdmin() or ply:IsSuperAdmin()
    
    -- Ensure weapon visibility before opening menu
    player_model_vendor.FixPlayerWeapons(ply)
    
    -- Send menu data to client
    net.Start("BG_PlayerModelVendor_OpenMenu")
    net.WriteTable(availableModels)
    net.WriteTable(ownedModels)
    net.WriteEntity(self)
    net.WriteBool(isAdmin)
    net.Send(ply)
    
    logOperation("MENU", "Opened menu for " .. ply:Nick() .. " with " .. #availableModels .. " models")
end

-- Purchase attempt from client
net.Receive("BG_PlayerModelVendor_AttemptPurchase", function(len, ply)
    local vendorEnt = net.ReadEntity()
    local modelIndex = net.ReadUInt(16)
    
    if not IsValid(vendorEnt) or vendorEnt:GetClass() != "player_model_vendor" then
        return 
    end
    
    -- Process the purchase
    local availableModels = {}
    
    -- Convert blacklist to lookup for faster checking
    local blacklistLookup = {}
    for _, entry in ipairs(player_model_vendor.blacklist) do
        blacklistLookup[entry.model_path] = true
    end
    
    -- Filter out blacklisted models
    for _, modelData in pairs(player_model_vendor.models_data) do
        if not blacklistLookup[modelData.Model] then
            table.insert(availableModels, modelData)
        end
    end
    
    -- Check if modelIndex is valid
    if not availableModels[modelIndex] then
        -- Send failure
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Invalid model selected")
        net.Send(ply)
        return
    end
    
    local selectedModel = availableModels[modelIndex]
    
    -- Check if player already owns this model
    if player_model_vendor.PlayerOwnsModel(ply, selectedModel.Model) then
        -- Send failure
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You already own this model")
        net.Send(ply)
        return
    end
    
    -- Check if player can afford it
    local playerMoney = player_model_vendor.GetPlayerMoney(ply)
    if playerMoney < selectedModel.Price then
        -- Send failure
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You cannot afford this model")
        net.Send(ply)
        return
    end
    
    -- Process purchase
    if player_model_vendor.TakePlayerMoney(ply, selectedModel.Price) then
        -- Add to owned models
        player_model_vendor.AddPlayerOwnedModel(ply, selectedModel.Model)
        
        -- Get updated owned models list
        local ownedModels = player_model_vendor.GetPlayerOwnedModels(ply)
        
        -- Send success
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Successfully purchased " .. selectedModel.Name)
        net.WriteTable(availableModels)
        net.WriteTable(ownedModels)
        net.Send(ply)
        
        logOperation("PURCHASE", "Player " .. ply:Nick() .. " purchased model: " .. selectedModel.Model)
    else
        -- Send failure
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Failed to process payment")
        net.Send(ply)
    end
end)

-- Equip model request from client
net.Receive("BG_PlayerModelVendor_EquipOwnedModel", function(len, ply)
    local modelPath = net.ReadString()
    
    -- Check if player owns this model
    if not player_model_vendor.PlayerOwnsModel(ply, modelPath) then
        -- Send failure
        net.Start("BG_PlayerModelVendor_EquipResult")
        net.WriteBool(false)
        net.WriteString("You don't own this model")
        net.Send(ply)
        return
    end
    
    -- Store current weapon information
    local activeWeaponClass = nil
    local weaponStates = {}
    
    if IsValid(ply:GetActiveWeapon()) then
        activeWeaponClass = ply:GetActiveWeapon():GetClass()
    end
    
    for _, wep in pairs(ply:GetWeapons()) do
        if IsValid(wep) then
            weaponStates[wep:GetClass()] = {
                visible = not wep:GetNoDraw(),
                active = (activeWeaponClass == wep:GetClass())
            }
        end
    end
    
    -- Set the player's model
    ply:SetModel(modelPath)
    
    -- Fix weapon visibility after change
    timer.Simple(0.1, function()
        if IsValid(ply) then
            -- First make all weapons visible
            for _, wep in pairs(ply:GetWeapons()) do
                if IsValid(wep) then
                    wep:SetNoDraw(false)
                end
            end
            
            -- Re-equip active weapon to fix viewmodels
            if activeWeaponClass then
                ply:SelectWeapon(activeWeaponClass)
            end
            
            -- Make sure player can see hands
            if ply.wOS_MX_UpdateModel then
                ply:wOS_MX_UpdateModel()  -- Support for wOS Hands systems if available
            end
        end
    end)
    
    -- Send success
    net.Start("BG_PlayerModelVendor_EquipResult")
    net.WriteBool(true)
    net.WriteString("Model equipped successfully")
    net.WriteTable({})
    net.WriteTable(player_model_vendor.GetPlayerOwnedModels(ply))
    net.Send(ply)
    
    logOperation("EQUIP", "Player " .. ply:Nick() .. " equipped model: " .. modelPath)
end)

-- Function for maintaining proper animation, copied EXACTLY from teleporter
function ENT:Think()
    -- Keep the animation going
    self:SetPlaybackRate(1.0)
    
    -- Make sure we're using the correct sequence
    if self:GetSequence() ~= CURRENT_SEQUENCE then
        self:ResetSequence(CURRENT_SEQUENCE)
    end
    
    -- Keep resetting pose parameters to prevent T-pose
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
    
    -- Force visibility
    self:DrawShadow(true)
    
    -- Use exact think interval from teleporter
    self:NextThink(CurTime() + 0.1)
    return true
end

-- We don't need PhysicsUpdate since we're using MOVETYPE_NONE
-- But to maintain compatibility with your existing code:
function ENT:PhysicsUpdate(phys)
    -- No need to do anything here since MOVETYPE_NONE
end

-- Force entity to always transmit to clients (from teleporter)
function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

-- Debug function for animation troubleshooting 
function ENT:DebugSequences()
    print("[PMV DEBUG] Beginning sequence debug for vendor model:")
    print("- Entity Valid: " .. tostring(IsValid(self)))
    print("- Model: " .. self:GetModel())
    print("- Current Sequence: " .. self:GetSequence())
    print("- Current Global Sequence: " .. CURRENT_SEQUENCE)
    
    local count = 0
    for i=0, 100 do
        local name = self:GetSequenceName(i)
        if name and name ~= "" then
            count = count + 1
            print("  Seq " .. i .. ": " .. name)
        end
    end
    
    print("[PMV DEBUG] Found " .. count .. " named sequences")
    return count
end

-- ========================================================================================
-- ADMIN FUNCTIONS
-- ========================================================================================

-- Get blacklist request from client
net.Receive("BG_PlayerModelVendor_Admin_GetBlacklist", function(len, ply)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    
    -- Send blacklist to client
    net.Start("BG_PlayerModelVendor_Admin_BlacklistResponse")
    net.WriteTable(player_model_vendor.blacklist or {})
    net.Send(ply)
    
    logOperation("ADMIN", "Sent blacklist to " .. ply:Nick())
end)

-- Process bulk action request from client
net.Receive("BG_PlayerModelVendor_Admin_BulkAction", function(len, ply)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    
    local action = net.ReadString()
    local modelCount = net.ReadUInt(16)
    local modelPaths = {}
    
    -- Read model paths
    for i = 1, modelCount do
        table.insert(modelPaths, net.ReadString())
    end
    
    -- Additional data
    local hasAdditionalData = net.ReadBool()
    local additionalData = {}
    
    if hasAdditionalData then
        additionalData = net.ReadTable()
    end
    
    -- Process action
    if action == "blacklist_models" then
        -- Add models to blacklist
        local reason = additionalData.reason or "No reason provided"
        local blacklist = player_model_vendor.blacklist or {}
        
        for _, path in ipairs(modelPaths) do
            table.insert(blacklist, {
                model_path = path,
                reason = reason,
                added_by = ply:Nick(),
                added_by_steamid = ply:SteamID(),
                date_added = os.time()
            })
        end
        
        player_model_vendor.blacklist = blacklist
        saveBlacklist(blacklist)
        
        -- Send success
        net.Start("BG_PlayerModelVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Added " .. #modelPaths .. " models to blacklist")
        net.WriteTable({})
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " blacklisted " .. #modelPaths .. " models")
        
    elseif action == "unblacklist_models" then
        -- Remove models from blacklist
        local blacklist = player_model_vendor.blacklist or {}
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
        
        player_model_vendor.blacklist = newBlacklist
        saveBlacklist(newBlacklist)
        
        -- Send success
        net.Start("BG_PlayerModelVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Removed " .. removedCount .. " models from blacklist")
        net.WriteTable({})
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " unblacklisted " .. removedCount .. " models")
        
    elseif action == "update_prices" then
        -- Update model prices
        local newPrice = tonumber(additionalData.price) or DEFAULT_MODEL_PRICE
        local updatedCount = 0
        
        -- Convert paths to lookup table
        local pathsLookup = {}
        for _, path in ipairs(modelPaths) do
            pathsLookup[path] = true
        end
        
        -- Update prices
        for i, modelData in pairs(player_model_vendor.models_data) do
            if pathsLookup[modelData.Model] then
                player_model_vendor.models_data[i].Price = newPrice
                updatedCount = updatedCount + 1
            end
        end
        
        saveModelsData(player_model_vendor.models_data)
        
        -- Send success
        net.Start("BG_PlayerModelVendor_Admin_BulkActionResult")
        net.WriteBool(true)
        net.WriteString("Updated prices for " .. updatedCount .. " models")
        net.WriteTable(player_model_vendor.models_data)
        net.WriteTable({})
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " updated prices for " .. updatedCount .. " models")
    end
end)

-- Process admin action request from client
net.Receive("BG_PlayerModelVendor_Admin_Action", function(len, ply)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    
    local action = net.ReadString()
    local data = net.ReadTable()
    
    if action == "rescan_models" then
        -- Rescan all models
        player_model_vendor.ScanForModels()
        
        -- Send success
        net.Start("BG_PlayerModelVendor_Admin_ActionResponse")
        net.WriteBool(true)
        net.WriteString("Rescanned models: " .. table.Count(player_model_vendor.models_data) .. " models found")
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " rescanned models")
    elseif action == "fix_all_weapons" then
        -- Fix weapon visibility for all players
        player_model_vendor.FixAllPlayersWeapons()
        
        -- Send success
        net.Start("BG_PlayerModelVendor_Admin_ActionResponse")
        net.WriteBool(true)
        net.WriteString("Fixed weapon visibility for all players")
        net.Send(ply)
        
        logOperation("ADMIN", "Player " .. ply:Nick() .. " fixed all weapons")
    end
end)

-- Initial scan if no models data exists
hook.Add("Initialize", "PMV_InitialModelScan", function()
    timer.Simple(5, function()
        if table.Count(player_model_vendor.models_data) == 0 then
            logOperation("STARTUP", "No models data found, running initial scan")
            player_model_vendor.ScanForModels()
        else
            logOperation("STARTUP", "Loaded " .. table.Count(player_model_vendor.models_data) .. " models from storage")
        end
        
        -- Fix weapons for all players
        timer.Simple(1, function()
            player_model_vendor.FixAllPlayersWeapons()
        end)
    end)
end)

-- Add hook for when weapons are given to players
hook.Add("WeaponEquip", "PMV_FixWeaponOnEquip", function(weapon, ply)
    if IsValid(weapon) and IsValid(ply) then
        -- Ensure weapon is visible when equipped
        timer.Simple(0.1, function()
            if IsValid(weapon) then
                weapon:SetNoDraw(false)
            end
        end)
    end
end)

print("--- [NPC PlayerModelVendor SCRIPT] init.lua finished loading by SERVER ---")