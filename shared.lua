-- shared.lua
-- This file runs on both server and client.
-- It defines basic gamemode information and inherits from the base "sandbox" gamemode.

DeriveGamemode("sandbox") -- Inherit properties and functions from sandbox
DEFINE_BASECLASS("sandbox") -- Define the base class for potential overrides

-- Basic Gamemode Information
GM.Name    = "BattleGrounds [PvP]" -- Name displayed in menus
GM.Author  = "JamieL" -- Your name/team
GM.Email   = "" -- Contact email (optional)
GM.Website = "" -- Website (optional)

-- This function is called on both client and server when the gamemode initializes.
-- You can put shared setup code here if needed.
function GM:Initialize()
    -- Call the base gamemode's Initialize function if it exists
    if self.BaseClass and self.BaseClass.Initialize then
        self.BaseClass.Initialize(self)
    end
    -- Add any shared initialization logic here
    print("[Gamemode Shared] Initializing BattleGrounds [PvP]...")
end

print("Military Gamemode - shared.lua loaded")
