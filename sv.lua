local postals = nil
local ludb = exports['0xludb-fivem']

CreateThread(function()
    local postalData = LoadResourceFile(GetCurrentResourceName(), 'new-postals.json')
    postals = json.decode(postalData)
    for i, postal in ipairs(postals) do
        postals[i] = { vec(postal.x, postal.y), code = postal.code }
    end
end)

--The fallback may not be necesarry but it prevents crashes on the client side still allowing the player to use the UI with their saved settings. This creates a unique license to that player.)
local function getSanitizedPlayerLicense(playerId)
    local license = GetPlayerIdentifierByType(playerId, "license2")
    if not license then
        return "unknown_license_" .. playerId -- Fallback
    end
    local dbLicense = exports.oxmysql:scalarSync('SELECT license FROM players WHERE license = ?', { license })
    if dbLicense then
        return dbLicense:gsub("[:]", "_")
    else
        return license:gsub("[:]", "_")
    end
end

-- Validate and set default preferences / This is a fail safe when players confirm their settings from the menu to make sure they are correctly saved preventing possible bugs / glitches in the UI.
local function validatePreferences(preferences)
    if type(preferences.fontSize) ~= "number" or preferences.fontSize < 8 or preferences.fontSize > 30 then
        preferences.fontSize = 12 -- Default font size
    end
    if type(preferences.updateInterval) ~= "number" or preferences.updateInterval <= 0 then
        preferences.updateInterval = 1500 -- Default interval in ms
    end
    if type(preferences.postalTextColor) ~= "string" or not preferences.postalTextColor:match("^rgba?%(.+%)$") then
        preferences.postalTextColor = "rgba(245, 245, 245, 1)"
    end
    if type(preferences.distanceColor) ~= "string" or not preferences.distanceColor:match("^rgba?%(.+%)$") then
        preferences.distanceColor = "rgba(0, 255, 0, 1)" -- Default Distance text color
    end
    if type(preferences.gpsParenthesisColor) ~= "string" or not preferences.gpsParenthesisColor:match("^rgba?%(.+%)$") then
        preferences.gpsParenthesisColor = "rgba(245, 245, 245, 1)" -- Default Postal: and Parenthesis text
    end
    if type(preferences.backgroundColor) ~= "string" or not preferences.backgroundColor:match("^rgba?%(.+%)$") then
        preferences.backgroundColor = "rgba(33, 33, 33, 0.9)"
    end
    if type(preferences.position) ~= "table" or type(preferences.position.left) ~= "number" or type(preferences.position.top) ~= "number" then
        preferences.position = { left = 50, top = 50 }
    end
    if type(preferences.distanceUnit) ~= "string" or (preferences.distanceUnit ~= "meters" and preferences.distanceUnit ~= "feet") then
        preferences.distanceUnit = "meters"
    end
    return preferences
end

local function loadPreferences(playerId)
    local key = "players/" .. getSanitizedPlayerLicense(playerId) .. "/postal_preferences"
    local preferences = ludb:retrieveGlobal(key)
    if not preferences then
        preferences = validatePreferences({})
        ludb:saveGlobal(key, preferences)
    end
    return validatePreferences(preferences or {})
end

local function savePreferences(playerId, preferences)
    local key = "players/" .. getSanitizedPlayerLicense(playerId) .. "/postal_preferences"
    preferences = validatePreferences(preferences)
    ludb:saveGlobal(key, preferences)
end

RegisterNetEvent('nearest-postal:loadPreferences', function()
    local playerId = source
    local preferences = loadPreferences(playerId)
    TriggerClientEvent('nearest-postal:receivePreferences', playerId, preferences)
end)

RegisterNetEvent('nearest-postal:savePreferences', function(preferences)
    local playerId = source
    savePreferences(playerId, preferences)
end)

lib.addCommand('togglepu', {
    help = 'Toggles the Postal UI visibility',
}, function(source, args, rawCommand)
    if source == 0 then
        print('[Postal UI] This command must be executed by a player.')
        return
    end
    TriggerClientEvent('nearest-postal:toggleUI', source)
end)
