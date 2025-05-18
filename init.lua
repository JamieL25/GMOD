-- init.lua (Server-side) - Updated 2025-05-16
-- Version: v1.55 (PvP physgun/toolgun for all)
-- MODIFIED: GivePlayerLoadout to give physgun and toolgun to all players on PvP deploy/respawn.
-- MODIFIED: Added check for ply.IsChangingModelFromVendor in GM:PlayerSpawn
-- ADDED: Q-Menu management system for superadmins

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

--=============================================================================
-- Configuration Variables
--=============================================================================

-- Network Strings
util.AddNetworkString("DeployPlayer")
util.AddNetworkString("SafeTeleportCountdown")
util.AddNetworkString("ConfirmDeploy")
util.AddNetworkString("ConfirmStaySafe")

-- Q-Menu Manager Network Strings
util.AddNetworkString("BG_SyncAllowedProps")
util.AddNetworkString("BG_SyncAllowedTools")
util.AddNetworkString("BG_RequestQMenuLists")
util.AddNetworkString("BG_AdminAddProp")
util.AddNetworkString("BG_AdminRemoveProp")
util.AddNetworkString("BG_AdminAddTool")
util.AddNetworkString("BG_AdminRemoveTool")
util.AddNetworkString("BG_AdminResetProps")
util.AddNetworkString("BG_AdminResetTools")

-- Position Constants
SAFE_SPAWN_POS      = Vector(2127.101318,  168.765152, -12432.550781)
SAFE_SPAWN_ANGLE    = Angle(-1.242542, -178.839386,   0.000000)

-- !!! IMPORTANT: Verify each of these PVP_SPAWNS in-game !!!
-- !!! Ensure none of them are the same as or too close to SAFE_SPAWN_POS !!!
PVP_SPAWNS          = {
    Vector(-2121.186279,-2410.672119,-14571.968750),
    Vector(-3729.331543,-1272.942993,-14511.968750),
    Vector(-3751.061279,1314.375854,-14511.968750),
    Vector(-1464.063354,2510.692139,-14511.968750),
    Vector(-464.353790,973.957520,-14511.968750)
}

-- Original PvP Teleporter NPC Settings (Legacy)
NPC_SPAWN_POS       = Vector(1915.832886, -180.473587, -12495.952734)
NPC_SPAWN_ANGLE     = Angle(3.267001, 88.209541, 0.000000)
NPC_MODEL           = "models/player/PMC_1/PMC__01.mdl"

-- Global table for player equipped weapons (ensure this is populated by your shop system)
_G.WeaponShopEquipped = _G.WeaponShopEquipped or {}

--=============================================================================
-- Q-Menu Management System
--=============================================================================

-- Default allowed props for regular players' custom Q-menu
local BG_DefaultAllowedProps = {
    "models/props_c17/FurnitureTable001a.mdl",
    "models/props_c17/FurnitureChair001a.mdl",
    "models/props_c17/FurnitureCouch001a.mdl",
    "models/props_c17/FurnitureShelf001a.mdl",
    "models/props_debris/wood_board06a.mdl",
    "models/props_debris/wood_board04a.mdl",
    "models/props_wasteland/wood_fence01a.mdl",
    "models/props_wasteland/wood_fence02a.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/items/item_item_crate.mdl",
    "models/props_wasteland/prison_bedframe001b.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_c17/oildrum001_explosive.mdl"
}

-- Default allowed tools for regular players' custom Q-menu
local BG_DefaultAllowedTools = {
    {name = "Weld Tool", command = "weld", description = "Attach props together"},
    {name = "Rope Tool", command = "rope", description = "Create ropes between props"},
    {name = "Axis Tool", command = "axis", description = "Create rotating attachments"},
    {name = "Ballsocket Tool", command = "ballsocket", description = "Create a joint that allows rotation in all directions"}
}

-- Current lists (will be modified by admin commands and saved to files)
local BG_AllowedProps = table.Copy(BG_DefaultAllowedProps)
local BG_AllowedTools = table.Copy(BG_DefaultAllowedTools)

-- File paths for saving Q-menu configuration
local PROPS_FILE = "battlegroundspvp/qmenu_props.txt"
local TOOLS_FILE = "battlegroundspvp/qmenu_tools.txt"

-- Function to save props configuration to file
local function SaveAllowedProps()
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
    end
    
    local jsonData = util.TableToJSON(BG_AllowedProps, true)
    file.Write(PROPS_FILE, jsonData)
    print("[BG Q-Menu] Saved " .. #BG_AllowedProps .. " allowed props to file")
end

-- Function to save tools configuration to file
local function SaveAllowedTools()
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
    end
    
    local jsonData = util.TableToJSON(BG_AllowedTools, true)
    file.Write(TOOLS_FILE, jsonData)
    print("[BG Q-Menu] Saved " .. #BG_AllowedTools .. " allowed tools to file")
end

-- Function to load props configuration from file
local function LoadAllowedProps()
    if not file.Exists(PROPS_FILE, "DATA") then
        print("[BG Q-Menu] Props file not found, using defaults")
        BG_AllowedProps = table.Copy(BG_DefaultAllowedProps)
        SaveAllowedProps() -- Create the file with defaults
        return
    end
    
    local jsonData = file.Read(PROPS_FILE, "DATA")
    local success, props = pcall(util.JSONToTable, jsonData)
    
    if success and props and type(props) == "table" and #props > 0 then
        BG_AllowedProps = props
        print("[BG Q-Menu] Loaded " .. #BG_AllowedProps .. " allowed props from file")
    else
        print("[BG Q-Menu] Error loading props from file, using defaults")
        BG_AllowedProps = table.Copy(BG_DefaultAllowedProps)
        SaveAllowedProps() -- Overwrite corrupted file with defaults
    end
end

-- Function to load tools configuration from file
local function LoadAllowedTools()
    if not file.Exists(TOOLS_FILE, "DATA") then
        print("[BG Q-Menu] Tools file not found, using defaults")
        BG_AllowedTools = table.Copy(BG_DefaultAllowedTools)
        SaveAllowedTools() -- Create the file with defaults
        return
    end
    
    local jsonData = file.Read(TOOLS_FILE, "DATA")
    local success, tools = pcall(util.JSONToTable, jsonData)
    
    if success and tools and type(tools) == "table" and #tools > 0 then
        BG_AllowedTools = tools
        print("[BG Q-Menu] Loaded " .. #BG_AllowedTools .. " allowed tools from file")
    else
        print("[BG Q-Menu] Error loading tools from file, using defaults")
        BG_AllowedTools = table.Copy(BG_DefaultAllowedTools)
        SaveAllowedTools() -- Overwrite corrupted file with defaults
    end
end

-- Initialize the Q-menu system
hook.Add("Initialize", "BG_LoadQMenuSettings", function()
    LoadAllowedProps()
    LoadAllowedTools()
end)

-- Function to sync allowed props to a specific player or all players
function SyncAllowedProps(ply)
    local recipients = ply or player.GetAll()
    
    net.Start("BG_SyncAllowedProps")
    net.WriteUInt(#BG_AllowedProps, 16) -- Space for up to 65535 props
    
    for _, model in ipairs(BG_AllowedProps) do
        net.WriteString(model)
    end
    
    net.Send(recipients)
    
    if ply then
        print("[BG Q-Menu] Synced " .. #BG_AllowedProps .. " allowed props to " .. ply:Nick())
    else
        print("[BG Q-Menu] Synced " .. #BG_AllowedProps .. " allowed props to all players")
    end
end

-- Function to sync allowed tools to a specific player or all players
function SyncAllowedTools(ply)
    local recipients = ply or player.GetAll()
    
    net.Start("BG_SyncAllowedTools")
    net.WriteUInt(#BG_AllowedTools, 8) -- Space for up to 255 tools
    
    for _, tool in ipairs(BG_AllowedTools) do
        net.WriteString(tool.name)
        net.WriteString(tool.command)
        net.WriteString(tool.description or "No description available")
    end
    
    net.Send(recipients)
    
    if ply then
        print("[BG Q-Menu] Synced " .. #BG_AllowedTools .. " allowed tools to " .. ply:Nick())
    else
        print("[BG Q-Menu] Synced " .. #BG_AllowedTools .. " allowed tools to all players")
    end
end

-- Net receivers for Q-menu management
net.Receive("BG_RequestQMenuLists", function(_, ply)
    if IsValid(ply) then
        SyncAllowedProps(ply)
        SyncAllowedTools(ply)
    end
end)

net.Receive("BG_AdminAddProp", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local model = net.ReadString()
    if not model or string.len(model) <= 10 then return end
    
    -- Check if the prop is already in the list
    for _, existingModel in ipairs(BG_AllowedProps) do
        if existingModel == model then
            ply:ChatPrint("This prop is already in the allowed list")
            return
        end
    end
    
    table.insert(BG_AllowedProps, model)
    print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " added prop: " .. model)
    ply:ChatPrint("Added prop to allowed list: " .. model)
    
    SaveAllowedProps()
    SyncAllowedProps()
end)

net.Receive("BG_AdminRemoveProp", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local model = net.ReadString()
    
    for i, existingModel in ipairs(BG_AllowedProps) do
        if existingModel == model then
            table.remove(BG_AllowedProps, i)
            print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " removed prop: " .. model)
            ply:ChatPrint("Removed prop from allowed list: " .. model)
            
            SaveAllowedProps()
            SyncAllowedProps()
            return
        end
    end
    
    ply:ChatPrint("Prop not found in allowed list")
end)

net.Receive("BG_AdminAddTool", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local name = net.ReadString()
    local command = net.ReadString()
    local description = net.ReadString()
    
    if not name or not command or string.len(name) == 0 or string.len(command) == 0 then
        return
    end
    
    -- Check if the tool is already in the list
    for _, existingTool in ipairs(BG_AllowedTools) do
        if existingTool.name == name or existingTool.command == command then
            ply:ChatPrint("A tool with this name or command is already in the allowed list")
            return
        end
    end
    
    local newTool = {
        name = name,
        command = command,
        description = description
    }
    
    table.insert(BG_AllowedTools, newTool)
    print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " added tool: " .. name .. " (" .. command .. ")")
    ply:ChatPrint("Added tool to allowed list: " .. name)
    
    SaveAllowedTools()
    SyncAllowedTools()
end)

net.Receive("BG_AdminRemoveTool", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local name = net.ReadString()
    
    for i, existingTool in ipairs(BG_AllowedTools) do
        if existingTool.name == name then
            table.remove(BG_AllowedTools, i)
            print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " removed tool: " .. name)
            ply:ChatPrint("Removed tool from allowed list: " .. name)
            
            SaveAllowedTools()
            SyncAllowedTools()
            return
        end
    end
    
    ply:ChatPrint("Tool not found in allowed list")
end)

net.Receive("BG_AdminResetProps", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    BG_AllowedProps = table.Copy(BG_DefaultAllowedProps)
    print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " reset props to defaults")
    ply:ChatPrint("Reset props to defaults")
    
    SaveAllowedProps()
    SyncAllowedProps()
end)

net.Receive("BG_AdminResetTools", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    BG_AllowedTools = table.Copy(BG_DefaultAllowedTools)
    print("[BG Q-Menu] SuperAdmin " .. ply:Nick() .. " reset tools to defaults")
    ply:ChatPrint("Reset tools to defaults")
    
    SaveAllowedTools()
    SyncAllowedTools()
end)

--=============================================================================
-- Helper Functions
--=============================================================================

-- Checks if a player has admin privileges or is the listen server host.
local function IsPrivileged(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsListenServerHost())
end

-- Shared function to handle giving weapons to a player.
-- Used for both respawns and deploying from the menu.
local function GivePlayerLoadout(ply, context) -- context is a string like "Respawn" or "Deploy" for logging
    if not IsValid(ply) or not ply:Alive() then
        print("[" .. context .. " Weapons] Player " .. (IsValid(ply) and ply:Nick() or "Unknown") .. " invalid or dead before weapon give.")
        return
    end

    print("[" .. context .. " Weapons] Stripping weapons for " .. ply:Nick())
    ply:StripWeapons();

    local sid = ply:SteamID();
    local equippedList = _G.WeaponShopEquipped and _G.WeaponShopEquipped[sid];
    local gaveWeapon = false;
    local firstWeaponGiven = nil

    -- Give weapons from the player's equipped list
    if equippedList and #equippedList > 0 then
        print("[" .. context .. " Weapons] Player " .. ply:Nick() .. " has equipped list: ", table.concat(equippedList, ", "))
        for i, wepClass in ipairs(equippedList) do
            if wepClass and type(wepClass) == "string" and string.len(wepClass) > 0 then
                print("[" .. context .. " Weapons] Attempting to give equipped (" .. i .. "/" .. #equippedList .. "): " .. wepClass .. " to " .. ply:Nick())
                ply:Give(wepClass);
                if not firstWeaponGiven then firstWeaponGiven = wepClass end
                gaveWeapon = true
                if ply:HasWeapon(wepClass) then
                    print("[" .. context .. " Weapons] Successfully GAVE equipped: " .. wepClass)
                else
                    print("[" .. context .. " Weapons] FAILED to give equipped: " .. wepClass)
                end
            else
                print("[" .. context .. " Weapons] Invalid weapon class in equipped list: ", wepClass)
            end
        end
    else
         print("[" .. context .. " Weapons] No equipped weapon list found for " .. ply:Nick())
    end

    -- Give default pistol if no other weapon was given from the equipped list
    if not gaveWeapon then
        print("[" .. context .. " Weapons] No equipped weapons were given, giving default pistol to " .. ply:Nick())
        ply:Give("weapon_pistol");
        ply:GiveAmmo(60, "Pistol", true)
        if not firstWeaponGiven then firstWeaponGiven = "weapon_pistol" end
        if ply:HasWeapon("weapon_pistol") then print("[" .. context .. " Weapons] Successfully GAVE weapon_pistol") else print("[" .. context .. " Weapons] FAILED to give weapon_pistol") end
    end

    -- *** MODIFICATION START: Give physgun and toolgun to ALL players deploying to PvP or respawning in PvP ***
    -- The context will be "Deploy" or "Respawn" when in PvP.
    if context == "Deploy" or context == "Respawn" then
        print("[" .. context .. " Weapons] Giving physgun and toolgun to " .. ply:Nick() .. " for PvP.")
        ply:Give("weapon_physgun");
        ply:Give("gmod_tool");
        if ply:HasWeapon("weapon_physgun") then print("[" .. context .. " Weapons] Successfully GAVE weapon_physgun for PvP to " .. ply:Nick()) else print("[" .. context .. " Weapons] FAILED to give weapon_physgun for PvP to " .. ply:Nick()) end
        if ply:HasWeapon("gmod_tool") then print("[" .. context .. " Weapons] Successfully GAVE gmod_tool for PvP to " .. ply:Nick()) else print("[" .. context .. " Weapons] FAILED to give gmod_tool for PvP to " .. ply:Nick()) end
    end
    -- *** MODIFICATION END ***

    -- Give admin tools if the player is privileged (this might be redundant for physgun/toolgun if given above for PvP contexts, but harmless and covers other potential contexts)
    if IsPrivileged(ply) then
        print("[" .. context .. " Weapons] Player " .. ply:Nick() .. " is privileged. Ensuring admin tools.")
        if not ply:HasWeapon("weapon_physgun") then
            ply:Give("weapon_physgun")
            print("[" .. context .. " Weapons] Gave weapon_physgun to privileged player " .. ply:Nick())
        end
        if not ply:HasWeapon("gmod_tool") then
            ply:Give("gmod_tool")
            print("[" .. context .. " Weapons] Gave gmod_tool to privileged player " .. ply:Nick())
        end
    end

    -- Attempt to select the first weapon given (usually a combat weapon)
    if firstWeaponGiven then
        print("[" .. context .. " Weapons] Attempting to select weapon: " .. firstWeaponGiven .. " for " .. ply:Nick())
        ply:SelectWeapon(firstWeaponGiven)
    end
    
    -- Delayed check to see what weapons the player actually has
    timer.Simple(0.1, function()
        if IsValid(ply) then
            local weps = ply:GetWeapons()
            local wepNames = {}
            for _,w in ipairs(weps) do table.insert(wepNames, w:GetClass()) end
            local activeWep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "none"
            print("[" .. context .. " Weapons Check] Player " .. ply:Nick() .. " has weapons after 0.1s: " .. table.concat(wepNames, ", ") .. ". Active: " .. activeWep)
        end
    end)
    print("[" .. context .. " Weapons] Finished weapon giving process for " .. ply:Nick())
end

--=============================================================================
-- Gamemode Hooks
--=============================================================================

function GM:Initialize()
    if self.BaseClass and self.BaseClass.Initialize then self.BaseClass.Initialize(self) end
    print("Server Initialized Gamemode: " .. (self.Name or "Unknown"))
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
        print("[SERVER] Created data directory 'battlegroundspvp'.")
    end
end

function GM:PlayerInitialSpawn(ply)
    if self.BaseClass and self.BaseClass.PlayerInitialSpawn then self.BaseClass.PlayerInitialSpawn(self, ply) end
    ply.InSafeZone = true;
    ply.NextSafeTeleportTime = 0;
    ply.HasSpawnedOnceBefore = false -- Flag to differentiate initial spawn from respawns
    print("[Spawn] Initializing variables for: " .. ply:Nick())
    
    -- Give this player the Q-menu lists after a short delay
    timer.Simple(3, function()
        if IsValid(ply) then
            SyncAllowedProps(ply)
            SyncAllowedTools(ply)
        end
    end)
end

function GM:PlayerSpawn(ply)
    -- === ADDED CHECK FOR PLAYER MODEL VENDOR FLAG ===
    if ply.IsChangingModelFromVendor then
        print("[Gamemode PlayerSpawn] Player " .. ply:Nick() .. " is changing model from vendor. Skipping default spawn logic (teleport/weapon reset).")
        -- The Player Model Vendor script will handle setting the player's position and angles via a timer.
        -- We just need to ensure the player is not frozen if the vendor process doesn't explicitly unfreeze.
        ply:Freeze(false)
        return -- Skip the rest of this gamemode's PlayerSpawn logic
    end
    -- === END OF ADDED CHECK ===

    if self.BaseClass and self.BaseClass.PlayerSpawn then self.BaseClass.PlayerSpawn(self, ply) end;

    ply:SetModel("models/player/group01/male_01.mdl"); -- Default player model
    ply:SetWalkSpeed(200);
    ply:SetRunSpeed(400);
    ply:SetJumpPower(200);

    if not ply.HasSpawnedOnceBefore then
        -- Logic for the very first spawn in a session
        print("[Spawn] Player " .. ply:Nick() .. " performing initial spawn routine.")
        ply:StripWeapons();
        ply:SetPos(SAFE_SPAWN_POS);
        ply:SetEyeAngles(SAFE_SPAWN_ANGLE);
        ply.InSafeZone = true;
        ply:SetNWBool("InSafeZone", true);
        if IsPrivileged(ply) then
            timer.Simple(0.1, function()
                if IsValid(ply) then
                    print("[Spawn - Initial] Giving admin tools to " .. ply:Nick())
                    ply:Give("weapon_physgun");
                    ply:Give("gmod_tool")
                end
            end)
        end;
        ply:Freeze(true); -- Freeze player for F2 menu
        print("[Spawn] Player " .. ply:Nick() .. " initial spawn in Safe Zone (Frozen).")
        ply.HasSpawnedOnceBefore = true
    else
        -- Logic for respawns after death
        print("[Spawn] Player " .. ply:Nick() .. " respawning in PvP zone.");
        ply:Freeze(false); -- Ensure player is unfrozen
        ply.InSafeZone = false;
        ply:SetNWBool("InSafeZone", false);

        local chosenPvpSpawn = table.Random(PVP_SPAWNS);
        ply:SetPos(chosenPvpSpawn);
        ply:SetEyeAngles(Angle(0, math.random(0, 360), 0));

        ply:GodEnable(); -- Short invulnerability
        timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end);

        -- Give weapons using the shared function (will now include physgun/toolgun for all)
        timer.Simple(0.15, function() GivePlayerLoadout(ply, "Respawn") end)
    end
end

-- Function called when player deploys from F2 menu
function DoDeploy(ply)
    if not IsValid(ply) or not ply:Alive() then return end;
    print("[Deploy] Player " .. ply:Nick() .. " deploying from menu.");
    ply:Freeze(false);
    ply.InSafeZone = false;
    ply:SetNWBool("InSafeZone", false);

    local chosenPvpSpawn = table.Random(PVP_SPAWNS);
    ply:SetPos(chosenPvpSpawn);
    ply:SetEyeAngles(Angle(0, math.random(0, 360), 0));

    ply:GodEnable(); -- Short invulnerability
    timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end);

    -- Give weapons using the shared function (will now include physgun/toolgun for all)
    timer.Simple(0.15, function() GivePlayerLoadout(ply, "Deploy") end)

    net.Start("ConfirmDeploy");
    net.Send(ply)
end
_G.DoDeploy = DoDeploy -- Expose globally if needed by other scripts (e.g., NPC)

-- Network Receivers
net.Receive("DeployPlayer", function(_, ply)
    if IsValid(ply) and ply:Alive() then
        if ply.InSafeZone then -- Can only deploy if currently in the safe zone
            DoDeploy(ply)
        else
            ply:ChatPrint("You are already deployed!")
        end
    end
end)

net.Receive("ConfirmStaySafe", function(_, ply)
    if IsValid(ply) and ply:Alive() then
        print("[Spawn] "..ply:Nick().." staying safe (Unfreezing).");
        ply:Freeze(false);
        if IsPrivileged(ply) then
            timer.Simple(0.1, function()
                 if IsValid(ply) then
                    ply:Give("weapon_physgun");
                    ply:Give("gmod_tool");
                    ply:SelectWeapon("weapon_physgun") -- Select physgun after staying safe
                end
            end)
        end
    end
end)

-- Chat Commands
hook.Add("PlayerSay", "CombinedChatCommands", function(ply, text, teamChat)
    if not IsValid(ply) then return nil end
    local lowerText = string.lower(text)

    -- !deploy command
    if lowerText == "!deploy" or lowerText == "/deploy" then
        if not ply:GetNWBool("InSafeZone", true) then
            ply:ChatPrint("Already deployed!")
        elseif ply:IsFrozen() then
            ply:ChatPrint("Use the F2 menu to deploy while frozen.")
        else
            DoDeploy(ply)
        end
        return "" -- Handled
    end

    -- !safe command
    if lowerText == "!safe" or lowerText == "/safe" then
        if ply:GetNWBool("InSafeZone", true) then
            ply:ChatPrint("[SAFEZONE] Already safe!")
            return ""
        end;
        if ply.NextSafeTeleportTime and ply.NextSafeTeleportTime > CurTime() then
            local waitTime = math.ceil(ply.NextSafeTeleportTime - CurTime());
            ply:ChatPrint("[SAFEZONE] Cooldown! Wait "..waitTime.."s");
            return ""
        end;

        ply:ChatPrint("[SAFEZONE] Teleporting... Stay still for 4 seconds!");
        net.Start("SafeTeleportCountdown");
        net.Send(ply);

        local startPos = ply:GetPos();
        timer.Simple(4, function()
            if not IsValid(ply) or not ply:Alive() then return end;
            local currentPos = ply:GetPos();
            if currentPos:Distance(startPos) > 50 then -- Check if player moved
                ply:ChatPrint("[SAFEZONE] Teleport cancelled! You moved.");
                ply.NextSafeTeleportTime = CurTime() + 10; -- Short cooldown after cancellation
                return
            end;

            print("[SafeZone - !safe] Player " .. ply:Nick() .. " teleported successfully.");
            ply.InSafeZone = true;
            ply.NextSafeTeleportTime = CurTime() + 120; -- 2 minute cooldown
            ply:SetPos(SAFE_SPAWN_POS);
            ply:SetEyeAngles(SAFE_SPAWN_ANGLE);
            ply:SetNWBool("InSafeZone", true);
            ply:Freeze(false) -- Ensure player is unfrozen after successful !safe

            ply:StripWeapons();
            print("[SafeZone - !safe] Player " .. ply:Nick() .. " weapons stripped.")

            if IsPrivileged(ply) then
                print("[SafeZone - !safe] Player " .. ply:Nick() .. " is privileged. Giving admin tools.")
                ply:Give("weapon_physgun");
                print("[SafeZone - !safe] Gave weapon_physgun to " .. ply:Nick())
                ply:Give("gmod_tool")
                print("[SafeZone - !safe] Gave gmod_tool to " .. ply:Nick())
                
                ply:SelectWeapon("weapon_physgun") -- Attempt to select physgun
                print("[SafeZone - !safe] Attempted to select weapon_physgun for " .. ply:Nick())

                timer.Simple(0.35, function()
                    if IsValid(ply) then
                        local hasToolgun = ply:HasWeapon("gmod_tool")
                        local hasPhysgun = ply:HasWeapon("weapon_physgun")
                        local activeWep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "none"
                        print("[SafeZone - !safe DEBUG] After 0.35s delay: " .. ply:Nick() .. " HasToolgun: " .. tostring(hasToolgun) .. ", HasPhysgun: " .. tostring(hasPhysgun) .. ", Active: " .. activeWep)
                        
                        if not hasPhysgun then print("[SafeZone - !safe DEBUG] Physgun missing for " .. ply:Nick() .. ", attempting to re-give."); ply:Give("weapon_physgun") end
                        if not hasToolgun then print("[SafeZone - !safe DEBUG] Toolgun still missing for " .. ply:Nick() .. ", attempting to re-give."); ply:Give("gmod_tool") end

                        if hasPhysgun and activeWep ~= "weapon_physgun" then
                            print("[SafeZone - !safe DEBUG] Physgun present but not active for " .. ply:Nick() .. ", attempting to select.")
                            ply:SelectWeapon("weapon_physgun")
                        elseif hasToolgun and activeWep ~= "gmod_tool" and activeWep ~= "weapon_physgun" then
                            print("[SafeZone - !safe DEBUG] Physgun not active/present, Toolgun present but not active for " .. ply:Nick() .. ", attempting to select toolgun.")
                            ply:SelectWeapon("gmod_tool")
                        end
                    end
                end)
            else
                print("[SafeZone - !safe] Player " .. ply:Nick() .. " is NOT privileged.")
            end;
            ply:ChatPrint("[SAFEZONE] Arrived safely.")
        end);
        return "" -- Handled
    end

    -- !qadmin command (New Q-menu management command for superadmins)
    if lowerText == "!qadmin" or lowerText == "/qadmin" then
        if ply:IsSuperAdmin() then
            ply:ConCommand("bg_qmenu_manager")
            ply:ChatPrint("[ADMIN] Opening Q-Menu Manager...")
        else
            ply:ChatPrint("This command is only available to superadmins.")
        end
        return "" -- Handled
    end

    -- !forcesafe command (Admin only)
    if lowerText == "!forcesafe" or lowerText == "/forcesafe" then
        if IsPrivileged(ply) then
            ply.InSafeZone = true;
            ply.NextSafeTeleportTime = CurTime();
            ply:SetPos(SAFE_SPAWN_POS);
            ply:SetEyeAngles(SAFE_SPAWN_ANGLE);
            ply:SetNWBool("InSafeZone", true);
            ply:StripWeapons();
            ply:Freeze(false);
            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply:Give("weapon_physgun");
                    ply:Give("gmod_tool");
                    ply:SelectWeapon("weapon_physgun")
                end
            end);
            ply:ChatPrint("[ADMIN] Forced teleport to Safe Zone.")
        else
            ply:ChatPrint("You do not have permission to use this command.")
        end
        return "" -- Handled
    end

    -- Legacy PvP Teleporter NPC Commands (Consider removing if NPC is no longer used)
    if string.sub(lowerText, 1, 9) == "!spawnnpc" then -- Adjusted to match common prefix
        if IsPrivileged(ply) then
            local ent = ents.Create("npcpvpteleporter")
            if IsValid(ent) then
                local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:EyeAngles():Forward() * 200, filter = ply})
                local spawnPos = tr.HitPos + Vector(0, 0, 10); local spawnAng = Angle(0, ply:EyeAngles().y - 180, 0)
                ent:SetPos(spawnPos); ent:SetAngles(spawnAng); ent:SetModel(NPC_MODEL); ent:Spawn()
                local seq = 4; if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then local savedSeq = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA")); if savedSeq and savedSeq > 0 then seq = savedSeq end end; ent:ResetSequence(seq)
                ply:ChatPrint("[ADMIN] PvP Teleporter NPC spawned!"); print("[ADMIN] "..ply:Nick().." spawned PvP Teleporter NPC at "..tostring(spawnPos))
            else ply:ChatPrint("[ERROR] Failed to create PvP Teleporter NPC!"); print("[ERROR] Failed to create PvP Teleporter NPC for "..ply:Nick()) end
        else ply:ChatPrint("No permission.") end
        return ""
    end
    -- ... (Keep other legacy NPC commands if needed, or remove them) ...

    return nil -- Let other hooks process if not handled
end)

-- Weapon Restriction Hook
hook.Remove("PlayerCanUseWeapon", "RestrictWeapons_DEBUG");
hook.Add("PlayerCanUseWeapon", "RestrictWeaponsInSafeZoneOrFrozen", function(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return nil end

    local wepClass = wep:GetClass()
    local isPrivileged = IsPrivileged(ply)

    if ply:IsFrozen() then
        if (wepClass == "gmod_tool" or wepClass == "weapon_physgun") and isPrivileged then -- Allow physgun/toolgun for frozen *admins*
            print("[CanUseWeapon] Allowing '" .. wepClass .. "' for frozen admin: " .. ply:Nick())
            return true
        end
        print("[CanUseWeapon] Blocking weapon '" .. wepClass .. "' for frozen player: " .. ply:Nick())
        return false
    end

    if ply:GetNWBool("InSafeZone", false) then -- Player is in Safe Zone AND NOT FROZEN
        if (wepClass == "gmod_tool" or wepClass == "weapon_physgun") and isPrivileged then
            print("[CanUseWeapon] Allowing '" .. wepClass .. "' for admin " .. ply:Nick() .. " in Safe Zone (not frozen).")
            return true
        end
        if wepClass ~= "gmod_tool" and wepClass ~= "weapon_physgun" then -- Message for combat weapons
             ply:ChatPrint("Cannot use combat weapons in the safe zone.")
        elseif not isPrivileged then -- Message for non-admins trying to use physgun/toolgun in safezone
             ply:ChatPrint("Physgun and Toolgun are restricted in the safe zone.")
        end
        print("[CanUseWeapon] Blocking weapon '" .. wepClass .. "' for " .. ply:Nick() .. " in Safe Zone.")
        return false
    end

    -- If not frozen and not in safe zone (i.e., in PvP zone), allow all weapons.
    print("[CanUseWeapon] Allowing weapon '" .. wepClass .. "' for " .. ply:Nick() .. " in PvP Zone.")
    return true
end)

-- Client-side validation for Q-Menu prop spawning
hook.Add("PlayerSpawnProp", "ValidateQMenuProps", function(ply, model)
    if IsPrivileged(ply) then return true end -- Admins can spawn any prop
    
    -- Regular players can only spawn props from the allowed list
    for _, allowedModel in ipairs(BG_AllowedProps) do
        if model == allowedModel then
            return true
        end
    end
    
    ply:ChatPrint("You can only spawn props from the custom Q-menu")
    return false
end)

-- Legacy PvP Teleporter NPC Management (Consider removing if NPC is no longer used)
function SetNPCAnimationSequence(seqNumber)
    local animNumber = tonumber(seqNumber) or 4
    local count = 0
    for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
        if IsValid(ent) then
            ent:ResetSequence(animNumber)
            count = count + 1
        end
    end
    if count > 0 then
        if not file.Exists("battlegroundspvp", "DATA") then file.CreateDir("battlegroundspvp") end
        file.Write("battlegroundspvp/npc_anim.txt", tostring(animNumber))
        print("[NPC Anim] Animation sequence " .. animNumber .. " saved.")
    end
    print("[NPC Anim] Animation sequence " .. animNumber .. " set on " .. count .. " NPCs")
    return animNumber
end
_G.SetNPCAnimationSequence = SetNPCAnimationSequence

hook.Add("InitPostEntity", "SpawnLegacyPvPTeleporter", function()
    print("[SERVER] Attempting to spawn LEGACY PvP Teleporter NPC...")
    if not file.Exists("battlegroundspvp", "DATA") then file.CreateDir("battlegroundspvp") end

    timer.Simple(5, function()
        local ent = ents.Create("npcpvpteleporter")
        if IsValid(ent) then
            ent:SetPos(NPC_SPAWN_POS); ent:SetAngles(NPC_SPAWN_ANGLE); ent:SetModel(NPC_MODEL); ent:Spawn()
            local seqNumber = 4
            if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                 local savedSeq = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                 if savedSeq and savedSeq > 0 then seqNumber = savedSeq end
            end
            ent:ResetSequence(seqNumber)
            print("[SERVER] Successfully spawned LEGACY PvP Teleporter NPC at " .. tostring(NPC_SPAWN_POS))
        else
            print("[SERVER ERROR] Failed to create LEGACY PvP Teleporter NPC!")
        end
    end)
end)

-- Admin Functions (Legacy NPC and general admin tools)
function GM:CanTool(ply, trace, mode)
    -- Allow privileged players to use tools.
    -- For non-privileged, allow if they are in PvP zone (not frozen, not in safe zone)
    if IsPrivileged(ply) then return true end
    if not ply:IsFrozen() and not ply:GetNWBool("InSafeZone", false) then
        -- Potentially check if 'mode' is a tool they are allowed to use via Q-Menu if further restriction is needed.
        -- For now, if they have the toolgun (given in PvP) and are in PvP, allow.
        return true 
    end
    return false
end

function GM:PlayerSpawnProp(ply, model)
    if IsPrivileged(ply) then return true end
    -- Allow if prop is in BG_AllowedProps AND player is in PvP zone (or safe zone if building is allowed there - current logic restricts to PvP)
    if table.HasValue(BG_AllowedProps, model) then
        -- Add further checks if props should only be spawnable in PvP or also in safe zone by non-admins
        -- For now, matching PlayerCanUseWeapon logic: allow if in PvP
        if not ply:IsFrozen() and not ply:GetNWBool("InSafeZone", false) then
            return true
        end
    end
    return false
end

function GM:PlayerSpawnSWEP(ply, cls, dat) return IsPrivileged(ply) end
function GM:PlayerSpawnEffect(ply, mdl) return IsPrivileged(ply) end
function GM:PlayerSpawnSENT(ply, cls) return IsPrivileged(ply) end
function GM:PlayerSpawnVehicle(ply, m, c, t) return IsPrivileged(ply) end
function GM:AllowPlayerSpawn(ply) return true end

-- Player Disconnect
hook.Add("PlayerDisconnected", "ClearInventoryOnLeave", function(ply)
    print("[Player] Disconnected: "..ply:Nick())
end);

-- Gamemode Shutdown
function GM:ShutDown()
    if self.BaseClass and self.BaseClass.ShutDown then self.BaseClass.ShutDown(self) end;
    print("Gamemode ShutDown.")
end

print("Military Gamemode - init.lua loaded (Server - v1.55 - PvP physgun/toolgun for all)")
