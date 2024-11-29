local postals = json.decode(LoadResourceFile(GetCurrentResourceName(), 'new-postals.json'))
local pBlip, pBlipCoords = nil, nil
local cursorEnabled = false
local preferences = nil
local CHECK_INTERVAL = 1500
local isPlayerLoaded = false
local lastPostalCode, lastDistance = nil, nil
local uiHidden = false
local uiHiddenForPause = false

CreateThread(function()
    repeat
        Wait(1000)
        if NetworkIsPlayerActive(PlayerId()) and GetEntityCoords(PlayerPedId(), false) ~= vector3(0, 0, 0) then
            isPlayerLoaded = true
            TriggerServerEvent('nearest-postal:loadPreferences')
        end
    until isPlayerLoaded
end)

local function findNearestPostal(playerCoords)
    local nearestPostal, nearestDistance = nil, math.huge
    for _, postal in ipairs(postals) do
        local distance = #(playerCoords - vector3(postal.x, postal.y, 0))
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPostal = postal
        end
    end
    return nearestPostal, nearestDistance
end

local function updatePostalInfo()
    if not (isPlayerLoaded and preferences) then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestPostal, distance = findNearestPostal(playerCoords)

    if nearestPostal and (lastPostalCode ~= nearestPostal.code or math.abs(lastDistance - distance) > 1) then
        lastPostalCode = nearestPostal.code
        lastDistance = distance
        local displayDistance = preferences.distanceUnit == 'feet' and (distance * 3.28084) or distance
        local unit = preferences.distanceUnit == 'feet' and 'ft' or 'm'

        SendNUIMessage({
            type = 'updatePostal',
            postal = nearestPostal.code,
            distance = string.format('%.2f %s', displayDistance, unit)
        })
    end

    if pBlip and pBlipCoords then
        local distToBlip = #(playerCoords - pBlipCoords)
        if distToBlip < 50.0 then
            if DoesBlipExist(pBlip) then
                SetBlipRoute(pBlip, false)
                RemoveBlip(pBlip)
            end
            pBlip, pBlipCoords = nil, nil
        end
    end

    SetTimeout(CHECK_INTERVAL, updatePostalInfo)
end

RegisterNetEvent('nearest-postal:receivePreferences', function(serverPreferences, isVisible)
    if serverPreferences then
        preferences = serverPreferences
        CHECK_INTERVAL = preferences.updateInterval
        SendNUIMessage({ type = 'loadPreferences', preferences = preferences })

        uiHidden = not isVisible
        if uiHidden then
            SendNUIMessage({ type = 'hide' })
        else
            SendNUIMessage({ type = 'show' })
        end

        updatePostalInfo()
    end
end)

local function savePreferences()
    if preferences then
        TriggerServerEvent('nearest-postal:savePreferences', preferences)
    end
end

RegisterNUICallback('savePosition', function(data, cb)
    if preferences then
        preferences.position = data.position
        savePreferences()
    end
    cb('ok')
end)

RegisterNUICallback('toggleCursor', function(data)
    cursorEnabled = data.enabled
    SetNuiFocus(cursorEnabled, cursorEnabled)
end)

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleCursor', enabled = false })
    lib.notify({ title = 'Postal UI', description = 'Cursor deactivated.', type = 'info' })
    cb('ok')
end)

local function saveToggleState()
    TriggerServerEvent('nearest-postal:savePreferences', preferences, not uiHidden)
end

RegisterNetEvent('nearest-postal:toggleVisibility', function()
    uiHidden = not uiHidden

    if uiHidden then
        SendNUIMessage({ type = 'hide' })
        lib.notify({ title = 'Postal UI', description = 'Postal UI is now hidden.', type = 'error' })
    else
        SendNUIMessage({ type = 'show' })
        lib.notify({ title = 'Postal UI', description = 'Postal UI is now visible.', type = 'success' })
    end

    saveToggleState()
end)

RegisterNetEvent('nearest-postal:openMenu', function()
    if not preferences then return end

    local input = lib.inputDialog('Postal UI Settings', {
        { type = 'slider', label = 'FPS (Lower is Recommended)', default = math.floor(1000 / preferences.updateInterval), min = 1, max = 60, step = 1 },
        { type = 'slider', label = 'Font Size', default = preferences.fontSize, min = 8, max = 30, step = 1 },
        { type = 'color', label = 'Postal Text Color', default = tostring(preferences.postalTextColor), format = 'rgba' },
        { type = 'color', label = 'Distance Text Color', default = tostring(preferences.distanceColor), format = 'rgba' },
        { type = 'color', label = 'Postal & Parenthesis Color', default = tostring(preferences.gpsParenthesisColor), format = 'rgba' },
        { type = 'color', label = 'Background Color', default = tostring(preferences.backgroundColor), format = 'rgba' },
        { type = 'select', label = 'Distance Unit', options = { { value = 'meters', label = 'Meters' }, { value = 'feet', label = 'Feet' } }, default = preferences.distanceUnit },
        { type = 'checkbox', label = 'Enable Cursor for Dragging', checked = cursorEnabled },
    })

    if input then
        preferences.fontSize = input[2]
        preferences.postalTextColor = input[3]
        preferences.distanceColor = input[4]
        preferences.gpsParenthesisColor = input[5]
        preferences.backgroundColor = input[6]
        preferences.updateInterval = math.floor(1000 / input[1])
        preferences.distanceUnit = input[7]

        cursorEnabled = input[8]
        SetNuiFocus(cursorEnabled, cursorEnabled)

        CHECK_INTERVAL = preferences.updateInterval
        savePreferences()

        SendNUIMessage({
            type = 'updateConfig',
            fontSize = preferences.fontSize,
            postalTextColor = preferences.postalTextColor,
            distanceColor = preferences.distanceColor,
            gpsParenthesisColor = preferences.gpsParenthesisColor,
            backgroundColor = preferences.backgroundColor,
            distanceUnit = preferences.distanceUnit
        })
    end
end)

RegisterNetEvent('nearest-postal:clearRoute', function()
    if pBlip then
        RemoveBlip(pBlip)
        pBlip = nil
        lib.notify({ title = 'Postal UI', description = 'GPS route cleared.', type = 'info' })
    else
        lib.notify({ title = 'Postal UI', description = 'No GPS route to clear.', type = 'warning' })
    end
end)

RegisterNetEvent('nearest-postal:setGPS', function(postalCode)
    if not postals then
        lib.notify({ title = 'Postal UI', description = 'Postal data is missing. Please reload the resource.', type = 'error' })
        return
    end

    local userPostal = string.upper(postalCode)
    local foundPostal = nil

    for _, postal in ipairs(postals) do
        if string.upper(postal.code) == userPostal then
            foundPostal = postal
            break
        end
    end

    if foundPostal then
        if pBlip then
            RemoveBlip(pBlip)
        end

        pBlipCoords = vector3(foundPostal.x, foundPostal.y, 0.0)
        pBlip = AddBlipForCoord(pBlipCoords)
        SetBlipSprite(pBlip, 8)
        SetBlipColour(pBlip, 3)
        SetBlipScale(pBlip, 1.0)
        SetBlipRoute(pBlip, true)
        SetBlipRouteColour(pBlip, 3)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(string.format('Postal Route %s', foundPostal.code))
        EndTextCommandSetBlipName(pBlip)

        lib.notify({ title = 'Postal UI', description = string.format('GPS route set to postal %s.', foundPostal.code), type = 'success' })
    else
        lib.notify({ title = 'Postal UI', description = 'Invalid postal code provided.', type = 'error' })
    end
end)

local function checkPauseMenu()
    if IsPauseMenuActive() then
        if not uiHiddenForPause then
            SendNUIMessage({ type = 'hide' })
            uiHiddenForPause = true
        end
    else
        if uiHiddenForPause then
            SendNUIMessage({ type = 'show' })
            uiHiddenForPause = false
        end
    end

    SetTimeout(200, checkPauseMenu)
end

checkPauseMenu()

exports('hideUI', function() SendNUIMessage({ type = 'hide' }) end)

exports('showUI', function() SendNUIMessage({ type = 'show' }) end)
