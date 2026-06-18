local isMenuOpen    = false
local dispatchPeds  = {}
local dispatchBlips = {}
local rentBlip         = nil

-- Variáveis globais para o taxi.lua acessar
activeJob     = nil
rentedTaxi      = nil
rentedTaxiPlate = nil
rentTimerLeft   = 0
local rentTimerActive = false

-- ─── Utilitários ──────────────────────────────────────────────────────────────

local function getClosestStand()
    local pcoords = GetEntityCoords(PlayerPedId())
    local closest = nil
    local minDist = 99999.0
    for _, stand in ipairs(Config.TaxiStands) do
        local dist = #(pcoords - vector3(stand.coords.x, stand.coords.y, stand.coords.z))
        if dist < minDist then
            minDist = dist
            closest = stand
        end
    end
    return closest, minDist
end

-- ─── NUI ──────────────────────────────────────────────────────────────────────

function openMenu()
    if isMenuOpen then return end
    local playerData = lib.callback.await('mri_Qtaxi:getPlayerData', false)
    local calls      = lib.callback.await('mri_Qtaxi:getCalls', false)
    if not playerData then return end

    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type        = 'show',
        playerData  = playerData,
        calls       = calls,
        zones       = Config.Zones,
        levels      = Config.Levels,
        accentColor = GetConvar('mri:color', '#eab308'),
        rentOptions    = Config.TaxiRentOptions,
        buyOptions     = Config.TaxiBuyOptions,
        ownedTaxis     = playerData.owned_taxis,
        hasRentedTruck = rentedTaxi ~= nil and DoesEntityExist(rentedTaxi),
        activeJob   = activeJob and {
            callId  = activeJob.callId,
        } or nil,
    })
end

function closeMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
end

-- ─── HUD Global ────────────────────────────────────────────────────────────────

function updateHUD()
    if not activeJob and not rentTimerActive then
        SendNUIMessage({ type = 'hideHUD' })
        return
    end
    
    local data = {}
    if activeJob then
        local elapsed   = GetGameTimer() / 1000 - activeJob.startTime
        data.condition = math.floor(activeJob.condition)
        data.elapsed   = elapsed
        data.route     = activeJob.callLabel
        data.timeLeft  = '--:--' -- sem tempo fixo para a corrida
    end
    
    if rentTimerActive then
        local rmins = math.floor(rentTimerLeft / 60)
        local rsecs = math.floor(rentTimerLeft % 60)
        data.rentalTimeLeft = string.format('%02d:%02d', rmins, rsecs)
    end
    
    SendNUIMessage({
        type      = 'updateHUD',
        condition = data.condition,
        timeLeft  = data.timeLeft,
        rentalTimeLeft = data.rentalTimeLeft,
    })
end

-- ─── Timer do Aluguel ─────────────────────────────────────────────────────────

local function startRentTimer(minutes)
    if rentTimerActive then return end
    rentTimerLeft = minutes * 60
    rentTimerActive = true
    
    CreateThread(function()
        while rentTimerActive and rentTimerLeft > 0 do
            Wait(1000)
            rentTimerLeft = rentTimerLeft - 1
            if rentTimerLeft <= 0 then
                -- Acabou o tempo
                lib.notify({ title = 'Aluguel Expirado', description = 'Seu tempo de aluguel acabou. O táxi foi devolvido.', type = 'error' })
                if activeJob then CancelJob() end
                ReturnTaxi()
                break
            end
        end
    end)
    
    -- Atualizador de HUD assíncrono para o timer (se não tiver corrida ativa)
    CreateThread(function()
        while rentTimerActive do
            if not activeJob then
                -- Só precisamos atualizar o hud do rental se não tiver corrida (pq a corrida já chama updateHUD)
                SendNUIMessage({
                    type = 'showHUD',
                    route = 'Livre',
                    cargo = 'Nenhum',
                    condition = 100,
                    timeLeft = '--:--',
                    rentalTimeLeft = string.format('%02d:%02d', math.floor(rentTimerLeft/60), math.floor(rentTimerLeft%60))
                })
            end
            Wait(1000)
        end
        if not activeJob then SendNUIMessage({ type = 'hideHUD' }) end
    end)
end

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────

RegisterNUICallback('closeMenu', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    if not rentedTaxi or not DoesEntityExist(rentedTaxi) then
        rentedTaxi = nil
        lib.notify({ title = 'Sem Táxi', description = 'Alugue ou retire seu táxi antes de aceitar chamadas.', type = 'warning' })
        cb('err'); return
    end
    closeMenu()
    Wait(300)
    StartJob(data.callId)
    cb('ok')
end)

RegisterNUICallback('cancelJob', function(_, cb)
    closeMenu()
    CancelJob()
    cb('ok')
end)

local function clearRentBlip()
    if rentBlip and DoesBlipExist(rentBlip) then
        SetBlipRoute(rentBlip, false)
        RemoveBlip(rentBlip)
    end
    rentBlip = nil
end

local function SpawnTaxiVehicle(model, isRental, durationMins)
    local stand, dist = getClosestStand()
    if dist > 20.0 then
        lib.notify({ title = 'Erro', description = 'Você não está perto de um ponto de táxi.', type = 'error' })
        return false
    end
    
    local SPAWN_COORDS = stand.spawnPoint.coords
    local SPAWN_HEADING = stand.spawnPoint.heading
    local SPAWN_RADIUS = stand.spawnPoint.radius

    -- Condição 1: vaga de spawn ocupada
    local nearVeh = GetClosestVehicle(SPAWN_COORDS.x, SPAWN_COORDS.y, SPAWN_COORDS.z, SPAWN_RADIUS, 0, 70)
    if DoesEntityExist(nearVeh) then
        lib.notify({ title = 'Vaga ocupada', description = 'Há um veículo na vaga do ponto de táxi.', type = 'warning' })
        return false
    end

    local hash  = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        lib.notify({ title = 'Erro', description = 'Modelo de táxi inválido.', type = 'error' })
        return false
    end

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) do
        Wait(100); t = t + 100
        if t > 10000 then return false end
    end

    local taxi = CreateVehicle(hash, SPAWN_COORDS.x, SPAWN_COORDS.y, SPAWN_COORDS.z, SPAWN_HEADING, true, false)
    SetVehicleNumberPlateText(taxi, ('TAXI%04d'):format(math.random(1, 9999)))
    SetEntityAsMissionEntity(taxi, true, true)
    SetModelAsNoLongerNeeded(hash)

    local plate = GetVehicleNumberPlateText(taxi)
    SetVehicleDoorsLocked(taxi, 1)
    exports['mri_Qcarkeys']:GiveTempKeys(plate)

    rentedTaxi      = taxi
    rentedTaxiPlate = plate

    clearRentBlip()
    rentBlip = AddBlipForEntity(taxi)
    SetBlipSprite(rentBlip, 198)
    SetBlipColour(rentBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Seu Táxi')
    EndTextCommandSetBlipName(rentBlip)

    CreateThread(function()
        while DoesEntityExist(taxi) and GetVehiclePedIsIn(PlayerPedId(), false) ~= taxi do
            Wait(500)
        end
        clearRentBlip()
    end)

    if isRental and durationMins then
        startRentTimer(durationMins)
    else
        rentTimerActive = false
        rentTimerLeft = 0
    end

    SendNUIMessage({ type = 'updateRentState', hasRentedTruck = true })
    return true, plate
end

RegisterNUICallback('rentTaxi', function(data, cb)
    if rentedTaxi and DoesEntityExist(rentedTaxi) then
        lib.notify({ title = 'Já em uso', description = 'Devolva seu táxi atual primeiro.', type = 'warning' })
        cb('err'); return
    end
    
    local ok, duration = lib.callback.await('mri_Qtaxi:rentTaxi', false, data.id)
    if not ok then
        lib.notify({ title = 'Falha', description = duration or 'Não foi possível alugar.', type = 'error' })
        cb('err'); return
    end

    closeMenu()
    Wait(300)
    
    local success, plate = SpawnTaxiVehicle(Config.RentVehicleModel, true, duration)
    if success then
        lib.notify({ title = 'Táxi Alugado!', description = 'Veículo liberado na vaga. Placa: '..plate, type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('buyTaxi', function(data, cb)
    local ok, msg = lib.callback.await('mri_Qtaxi:buyTaxi', false, data.model)
    if not ok then
        lib.notify({ title = 'Falha', description = msg or 'Não foi possível comprar.', type = 'error' })
        cb('err'); return
    end
    lib.notify({ title = 'Sucesso', description = 'Veículo comprado com sucesso!', type = 'success' })
    
    -- Atualizar ui
    local playerData = lib.callback.await('mri_Qtaxi:getPlayerData', false)
    if playerData then
        SendNUIMessage({ type = 'updatePlayer', ownedTaxis = playerData.owned_taxis })
    end
    cb('ok')
end)

RegisterNUICallback('useOwnedTaxi', function(data, cb)
    if rentedTaxi and DoesEntityExist(rentedTaxi) then
        lib.notify({ title = 'Já em uso', description = 'Devolva seu táxi atual primeiro.', type = 'warning' })
        cb('err'); return
    end

    closeMenu()
    Wait(300)
    
    local success, plate = SpawnTaxiVehicle(data.model, false, nil)
    if success then
        lib.notify({ title = 'Táxi Retirado!', description = 'Seu táxi está na vaga.', type = 'success' })
    end
    cb('ok')
end)

function ReturnTaxi()
    if not rentedTaxi or not DoesEntityExist(rentedTaxi) then
        rentedTaxi      = nil
        rentedTaxiPlate = nil
        rentTimerActive = false
        clearRentBlip()
        SendNUIMessage({ type = 'updateRentState', hasRentedTruck = false })
        return
    end

    if GetVehiclePedIsIn(PlayerPedId(), false) == rentedTaxi then
        lib.notify({ title = 'Atenção', description = 'Saia do táxi antes de devolvê-lo.', type = 'warning' })
        return false
    end

    if rentedTaxiPlate then
        exports['mri_Qcarkeys']:RemoveTempKeys(rentedTaxiPlate)
        TriggerServerEvent('mm_carkeys:server:removevehiclekeys', rentedTaxiPlate)
    end

    DeleteEntity(rentedTaxi)
    rentedTaxi      = nil
    rentedTaxiPlate = nil
    rentTimerActive = false
    clearRentBlip()
    SendNUIMessage({ type = 'updateRentState', hasRentedTruck = false })
    return true
end

RegisterNUICallback('returnTaxi', function(_, cb)
    if ReturnTaxi() then
        lib.notify({ title = 'Devolvido', description = 'Táxi devolvido/guardado.', type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('randomCall', function(data, cb)
    local level = data.level or 1
    local call = GetRandomCall(level)
    cb(call)
end)

RegisterNUICallback('getRanking', function(data, cb)
    local category = data.category or 'xp'
    local ranking = lib.callback.await('mri_Qtaxi:getRanking', false, category)
    cb(ranking)
end)

-- ─── Resultado da entrega (vindo do servidor) ─────────────────────────────────

RegisterNetEvent('mri_Qtaxi:rideResult', function(result)
    local msg = string.format(
        'Pagamento: R$ %s | XP: +%d | Satisfação: %d%%',
        tostring(result.pay), result.xp, result.condition
    )
    if result.timeBonus > 0 then
        msg = msg .. string.format(' | Gorjeta: +R$ %s', tostring(result.timeBonus))
    end

    lib.notify({ title = '✅ Corrida Concluída!', description = msg, type = 'success', duration = 8000 })

    if result.leveledUp then
        Wait(1000)
        lib.notify({
            title       = '🎉 Nível Aumentado!',
            description = string.format('Você é agora %s (Nível %d)!', result.newLevelLabel, result.newLevel),
            type        = 'success',
            duration    = 6000,
        })
    end
end)

-- ─── Tecla F6: cancelar missão + devolver táxi ───────────────────────────

RegisterCommand('mri_taxi_f6', function()
    local hasTruck = rentedTaxi and DoesEntityExist(rentedTaxi)
    local hasJob   = activeJob ~= nil

    if not hasTruck and not hasJob then
        lib.notify({ title = 'Táxi', description = 'Sem corrida ou táxi ativo.', type = 'inform' })
        return
    end

    if hasJob then
        CancelJob()
    end

    if hasTruck then
        ReturnTaxi()
    end

    local parts = {}
    if hasJob   then parts[#parts + 1] = 'corrida cancelada' end
    if hasTruck then parts[#parts + 1] = 'táxi devolvido' end
    lib.notify({ title = 'F6 — Encerrado', description = table.concat(parts, ' · ') .. '.', type = 'inform' })
end, false)

RegisterKeyMapping('mri_taxi_f6', 'Taxi: cancelar missão e devolver veículo', 'keyboard', 'F6')

-- ─── Despachantes ─────────────────────────────────────────────────────────────

local function spawnDispatcher(dispatcher)
    local hash = GetHashKey(dispatcher.ped)

    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then return end
    end

    local c   = dispatcher.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    PlaceObjectOnGroundProperly(ped)
    SetModelAsNoLongerNeeded(hash)
    dispatchPeds[#dispatchPeds + 1] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            label    = dispatcher.label,
            icon     = 'fas fa-taxi',
            distance = 3.0,
            onSelect = function() openMenu() end,
        }
    })

    local c2  = dispatcher.coords
    local blip = AddBlipForCoord(c2.x, c2.y, c2.z)
    SetBlipSprite(blip, dispatcher.blip.sprite)
    SetBlipColour(blip, dispatcher.blip.color)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(dispatcher.blip.label)
    EndTextCommandSetBlipName(blip)
    dispatchBlips[#dispatchBlips + 1] = blip
end

CreateThread(function()
    Wait(2000)
    for _, d in ipairs(Config.TaxiStands) do
        spawnDispatcher(d)
        Wait(200)
    end
end)

-- ─── Limpeza ──────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(dispatchPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in ipairs(dispatchBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    clearRentBlip()
    if rentedTaxi and DoesEntityExist(rentedTaxi) then
        if rentedTaxiPlate then
            exports['mri_Qcarkeys']:RemoveTempKeys(rentedTaxiPlate)
            TriggerServerEvent('mm_carkeys:server:removevehiclekeys', rentedTaxiPlate)
        end
        DeleteEntity(rentedTaxi)
    end
    rentedTaxi      = nil
    if activeJob then CancelJob() end
    closeMenu()
end)
