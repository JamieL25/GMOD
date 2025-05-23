-- XP System Configuration
-- Shared file (accessible on both client and server)

XPSystem = XPSystem or {}
XPSystem.Config = {}

-- General settings
XPSystem.Config.MaxLevel = 100         -- Maximum level before prestige is required
XPSystem.Config.MaxPrestige = 10       -- Maximum prestige level
XPSystem.Config.BaseXP = 100           -- Base XP needed for level 1
XPSystem.Config.XPMultiplier = 1.1     -- How much more XP is needed for each level

-- XP Boost for donation ranks (SAM ranks)
XPSystem.Config.RankBoosts = {
    ["VIP"] = 1.15,         -- 15% more XP
    ["VIP+"] = 1.25,       -- 25% more XP
    ["Legend"] = 1.35,         -- 35% more XP
}

-- Default rewards for levels (can be edited in-game by SuperAdmins)
XPSystem.Config.LevelRewards = {
    [5] = {currency = 1000, message = "Reached level 5!"},
    [10] = {currency = 2500, message = "Reached level 10!"},
    [25] = {currency = 7500, message = "Reached level 25!"},
    [50] = {currency = 20000, message = "Reached level 50!"},
    [75] = {currency = 50000, message = "Reached level 75!"},
    [100] = {currency = 100000, message = "Maximum level reached!"},
}

-- Default rewards for prestige (can be edited in-game by SuperAdmins)
XPSystem.Config.PrestigeRewards = {
    [1] = {currency = 150000, message = "First prestige achieved!"},
    [5] = {currency = 500000, message = "Halfway to max prestige!"},
    [10] = {currency = 1000000, message = "Maximum prestige reached!"},
}

-- HUD configuration
XPSystem.Config.HUD = {
    Width = 600,               -- Width of XP bar
    Height = 15,               -- Height of XP bar
    BottomMargin = 50,         -- Distance from bottom of screen
    BackgroundColor = Color(30, 30, 30, 200),
    XPBarColor = Color(0, 150, 255, 255),
    PrestigeColor = Color(255, 215, 0, 255),
    TextColor = Color(255, 255, 255, 255),
    BorderColor = Color(0, 0, 0, 100),
    BorderWidth = 2,
    Rounded = 4,               -- Rounded corners radius
    ShowAlways = false,        -- If false, only shows when gaining XP or pressing key
    FadeTime = 3,              -- Time in seconds before HUD fades after XP gain
    ToggleKey = KEY_F5,        -- Key to toggle HUD visibility
}

-- Calculate XP needed for a specific level
function XPSystem.GetXPForLevel(level)
    return math.floor(XPSystem.Config.BaseXP * (XPSystem.Config.XPMultiplier ^ (level - 1)))
end

-- Calculate total XP needed to reach a specific level from level 1
function XPSystem.GetTotalXPForLevel(level)
    local total = 0
    for i = 1, level - 1 do
        total = total + XPSystem.GetXPForLevel(i)
    end
    return total
end