local postals = nil
local ludb = exports['0xludb-fivem']

CreateThread(function()
    local postalData = LoadResourceFile(GetCurrentResourceName(), 'new-postals.json')
    postals = json.decode(postalData)
    for i, postal in ipairs(postals) do
        postals[i] = { vec(postal.x, postal.y), code = postal.code }
    end
    print("[Nearest Postal] Postal data successfully loaded.")
end)

local function getSanitizedPlayerLicense(playerId)
    local license = GetPlayerIdentifierByType(playerId, "license2")
    if not license then
        return "unknown_license_" .. playerId
    end

    local dbLicense = exports.oxmysql:scalarSync('SELECT license FROM players WHERE license = ?', { license })
    return (dbLicense or license):gsub("[:]", "_")
end

local function validatePreferences(preferences)
    preferences.fontSize = (type(preferences.fontSize) == "number" and preferences.fontSize >= 8 and preferences.fontSize <= 30) and preferences.fontSize or 12
    preferences.updateInterval = (type(preferences.updateInterval) == "number" and preferences.updateInterval > 0) and preferences.updateInterval or 1500
    preferences.postalTextColor = (type(preferences.postalTextColor) == "string" and preferences.postalTextColor:match("^rgba?%(.+%)$")) and preferences.postalTextColor or "rgba(245, 245, 245, 1)"
    preferences.distanceColor = (type(preferences.distanceColor) == "string" and preferences.distanceColor:match("^rgba?%(.+%)$")) and preferences.distanceColor or "rgba(0, 255, 0, 1)"
    preferences.gpsParenthesisColor = (type(preferences.gpsParenthesisColor) == "string" and preferences.gpsParenthesisColor:match("^rgba?%(.+%)$")) and preferences.gpsParenthesisColor or "rgba(245, 245, 245, 1)"
    preferences.backgroundColor = (type(preferences.backgroundColor) == "string" and preferences.backgroundColor:match("^rgba?%(.+%)$")) and preferences.backgroundColor or "rgba(33, 33, 33, 0.9)"
    preferences.position = (type(preferences.position) == "table" and type(preferences.position.left) == "number" and type(preferences.position.top) == "number") and preferences.position or { left = 50, top = 50 }
    preferences.distanceUnit = (preferences.distanceUnit == "meters" or preferences.distanceUnit == "feet") and preferences.distanceUnit or "meters"
    return preferences
end

RegisterNetEvent('nearest-postal:loadPreferences', function()
    local playerId = source
    local key = "players/" .. getSanitizedPlayerLicense(playerId) .. "/postal_preferences"
    local preferences = ludb:retrieveGlobal(key) or validatePreferences({})
    local uiVisible = ludb:retrieveGlobal(key .. "_uiVisible")
    
    ludb:saveGlobal(key, preferences)
    if uiVisible == nil then
        uiVisible = true
        ludb:saveGlobal(key .. "_uiVisible", uiVisible)
    end

    TriggerClientEvent('nearest-postal:receivePreferences', playerId, preferences, uiVisible)
end)

RegisterNetEvent('nearest-postal:savePreferences', function(preferences, isVisible)
    local playerId = source
    local key = "players/" .. getSanitizedPlayerLicense(playerId) .. "/postal_preferences"
    ludb:saveGlobal(key, preferences)
    if isVisible ~= nil then
        ludb:saveGlobal(key .. "_uiVisible", isVisible)
    end
end)

lib.addCommand('togglepu', {
    help = 'Toggles the Postal UI visibility',
}, function(source)
    if source == 0 then
        return
    end

    TriggerClientEvent('nearest-postal:toggleVisibility', source)
end)

lib.addCommand('postalmenu', {
    help = 'Open the Postal UI settings menu',
}, function(source)
    TriggerClientEvent('nearest-postal:openMenu', source)
end)

lib.addCommand('postal', {
    help = 'Set GPS to a specific postal code or clear the route if no code is provided'
}, function(source, args)
    local postalCode = args[1]

    if not postalCode or postalCode == '' then
        TriggerClientEvent('nearest-postal:clearRoute', source)
        return
    end

    TriggerClientEvent('nearest-postal:setGPS', source, postalCode)
end)

exports('getPostals', function()
    return postals
end)
