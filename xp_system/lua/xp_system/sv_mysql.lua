-- XP System MySQL Module
-- Server-side file for database connectivity
-- Created for JamieL25 on 2025-05-22

XPSystem = XPSystem or {}
XPSystem.MySQL = {}

-- Load the MySQLoo module
require("mysqloo")

-- Database configuration - you should change these values
XPSystem.MySQL.Config = {
    host = "208.103.169.52",
    port = 3306,
    database = ",
    user = "",
    password = "",
    charset = "utf8mb4"
}

-- Database connection object
XPSystem.MySQL.Connection = nil

-- Initialize database connection
function XPSystem.MySQL.Initialize()
    -- Create database connection
    XPSystem.MySQL.Connection = mysqloo.connect(
        XPSystem.MySQL.Config.host,
        XPSystem.MySQL.Config.user,
        XPSystem.MySQL.Config.password,
        XPSystem.MySQL.Config.database,
        XPSystem.MySQL.Config.port
    )
    
    -- Set up connection callbacks
    XPSystem.MySQL.Connection.onConnected = function()
        print("[XP System] MySQL connection established successfully!")
        
        -- Create necessary tables
        XPSystem.MySQL.CreateTables()
    end
    
    XPSystem.MySQL.Connection.onConnectionFailed = function(db, err)
        print("[XP System] MySQL connection failed: " .. err)
        
        -- Try to reconnect after a delay
        timer.Simple(60, function()
            print("[XP System] Attempting to reconnect to MySQL...")
            XPSystem.MySQL.Initialize()
        end)
    end
    
    -- Connect to database
    XPSystem.MySQL.Connection:connect()
end

-- Create necessary database tables
function XPSystem.MySQL.CreateTables()
    -- Players table
    local playersQuery = [[
        CREATE TABLE IF NOT EXISTS xp_players (
            steam_id VARCHAR(64) PRIMARY KEY,
            level INT NOT NULL DEFAULT 1,
            xp INT NOT NULL DEFAULT 0,
            total_xp INT NOT NULL DEFAULT 0,
            prestige INT NOT NULL DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]]
    
    -- Config table
    local configQuery = [[
        CREATE TABLE IF NOT EXISTS xp_config (
            config_key VARCHAR(64) PRIMARY KEY,
            config_value TEXT NOT NULL,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]]
    
    -- Execute queries
    XPSystem.MySQL.Query(playersQuery, function()
        print("[XP System] Players table ready")
    end)
    
    XPSystem.MySQL.Query(configQuery, function()
        print("[XP System] Config table ready")
        
        -- Load the configuration after tables are created
        XPSystem.LoadConfigFromDB()
        
        -- Fire event for other modules to know MySQL is ready
        hook.Run("XPSystem_MySQLReady")
    end)
end

-- Execute a MySQL query with error handling
-- Fixed to properly handle varargs
function XPSystem.MySQL.Query(query, callback, ...)
    local args = {...}  -- Store varargs in a local table
    
    if not XPSystem.MySQL.Connection then
        print("[XP System] MySQL Error: No connection available")
        return
    end
    
    if XPSystem.MySQL.Connection:status() ~= mysqloo.DATABASE_CONNECTED then
        print("[XP System] MySQL Error: Connection lost, reconnecting...")
        XPSystem.MySQL.Initialize()
        return
    end
    
    local queryObj = XPSystem.MySQL.Connection:query(query)
    
    queryObj.onSuccess = function(q, data)
        if callback then
            callback(data, unpack(args))  -- Use unpack to pass stored varargs to callback
        end
    end
    
    queryObj.onError = function(q, err, sql)
        print("[XP System] MySQL Error: " .. err)
        print("[XP System] Query: " .. sql)
    end
    
    queryObj:start()
    return queryObj
end

-- Escape a string for SQL
function XPSystem.MySQL.Escape(str)
    if not XPSystem.MySQL.Connection then return "NULL" end
    return "'" .. XPSystem.MySQL.Connection:escape(tostring(str)) .. "'"
end

-- Initialize connection when module is loaded
timer.Simple(1, function()
    XPSystem.MySQL.Initialize()
end)

print("[XP System] MySQL module initialized")
