local postals = json.decode(LoadResourceFile(GetCurrentResourceName(), 'new-postals.json'))
local pBlip, pBlipCoords = nil, nil
local cursorEnabled = false
local preferences = nil
local CHECK_INTERVAL = 1500
local isPlayerLoaded = false
local lastPostalCode, lastDistance = nil, nil


CreateThread(function()
    while not isPlayerLoaded do
        if NetworkIsPlayerActive(PlayerId()) and GetEntityCoords(PlayerPedId(), false) ~= vector3(0, 0, 0) then
            isPlayerLoaded = true
            TriggerServerEvent('nearest-postal:loadPreferences')
        end
        Wait(1000)
    end
end)

RegisterNetEvent('nearest-postal:receivePreferences', function(serverPreferences)
    if serverPreferences then
        preferences = serverPreferences
        CHECK_INTERVAL = preferences.updateInterval
        SendNUIMessage({ type = 'loadPreferences', preferences = preferences })
    end
end)

local function savePreferences()
    if preferences then
        TriggerServerEvent('nearest-postal:savePreferences', preferences)
    end
end

RegisterNUICallback('savePosition', function(data)
    if preferences then
        preferences.position = data.position
        savePreferences()
    end
end)

RegisterNUICallback('toggleCursor', function(data)
    cursorEnabled = data.enabled
    SetNuiFocus(cursorEnabled, cursorEnabled)
end)

RegisterNUICallback('closeUI', function()
    cursorEnabled = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggleCursor', enabled = false })
    lib.notify({ title = 'Postal UI', description = 'Cursor deactivated.', type = 'info' })
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

CreateThread(function()
    while true do
        if isPlayerLoaded and preferences then
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
        end
        Wait(CHECK_INTERVAL)
    end
end)

RegisterCommand('postalmenu', function()
    if not preferences then return end

    local input = lib.inputDialog('Postal UI Settings', {
        { type = 'slider', label = 'Update Interval (FPS)', default = math.floor(1000 / preferences.updateInterval), min = 1, max = 60, step = 1 },
        { type = 'slider', label = 'Font Size', default = preferences.fontSize, min = 8, max = 30, step = 1 },
        { type = 'color', label = 'Postal Text Color', default = tostring(preferences.postalTextColor), format = 'rgba' },
        { type = 'color', label = 'Distance Text Color', default = tostring(preferences.distanceColor), format = 'rgba' },
        { type = 'color', label = 'GPS Parenthesis Color', default = tostring(preferences.gpsParenthesisColor), format = 'rgba' },
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
end, false)

RegisterCommand('postal', function(_, args)
    if not isPlayerLoaded then
        lib.notify({ title = 'Postal UI', description = 'Player not fully loaded yet. Please wait.', type = 'error' })
        return
    end

    if #args < 1 then
        if pBlip then
            RemoveBlip(pBlip)
            pBlip = nil
            lib.notify({ title = 'Postal UI', description = 'GPS route cleared.', type = 'info' })
        else
            lib.notify({ title = 'Postal UI', description = 'No GPS route to clear.', type = 'warning' })
        end
        return
    end

    local userPostal = string.upper(args[1])
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
        lib.notify({ title = 'Postal UI', description = 'Invalid postal code.', type = 'error' })
    end
end, false)

CreateThread(function()
    local uiHidden = false
    while true do
        Wait(100)
        if IsPauseMenuActive() then
            if not uiHidden then
                SendNUIMessage({ type = 'hide' })
                uiHidden = true
            end
        else
            if uiHidden then
                SendNUIMessage({ type = 'show' })
                uiHidden = false
            end
        end
    end
end)

RegisterNetEvent('nearest-postal:toggleUI', function()
    local uiHidden = GetResourceKvpString('postalUIHidden') == 'true'
    if uiHidden then
        SendNUIMessage({ type = 'show' })
        SetResourceKvp('postalUIHidden', 'false')
        lib.notify({ title = 'Postal UI', description = 'The Postal UI is now visible.', type = 'success' })
    else
        SendNUIMessage({ type = 'hide' })
        SetResourceKvp('postalUIHidden', 'true')
        lib.notify({ title = 'Postal UI', description = 'The Postal UI is now hidden.', type = 'error' })
    end
end)

exports('hideUI', function()
    SendNUIMessage({ type = 'hide' })
end)

exports('showUI', function()
    SendNUIMessage({ type = 'show' })
end)
