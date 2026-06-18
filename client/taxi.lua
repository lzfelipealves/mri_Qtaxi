local passengerPed = nil
local passengerBlip = nil
local jobMonitorRunning = false

-- ─── Utilitários ──────────────────────────────────────────────────────────────

local function removePassengerBlip()
    if passengerBlip and DoesBlipExist(passengerBlip) then RemoveBlip(passengerBlip) end
    passengerBlip = nil
end

local function addPassengerBlip(coords, label, sprite, color)
    removePassengerBlip()
    passengerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(passengerBlip, sprite)
    SetBlipColour(passengerBlip, color)
    SetBlipScale(passengerBlip, 1.0)
    SetBlipAsShortRange(passengerBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(passengerBlip)
    SetBlipRoute(passengerBlip, true)
    SetBlipRouteColour(passengerBlip, color)
end

local function spawnPassenger(coords)
    local modelStr = Config.PassengerModels[math.random(#Config.PassengerModels)]
    local hash = GetHashKey(modelStr)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(100) end
    
    passengerPed = CreatePed(4, hash, coords.x, coords.y, coords.z, coords.w, true, true)
    SetEntityAsMissionEntity(passengerPed, true, true)
    SetBlockingOfNonTemporaryEvents(passengerPed, true)
    SetModelAsNoLongerNeeded(hash)
end

-- ─── Lógica da Missão ────────────────────────────────────────────────────────

local function startJobMonitor()
    if jobMonitorRunning then return end
    jobMonitorRunning = true

    CreateThread(function()
        local lastHealth = 1000.0
        while activeJob do
            local taxi = GetVehiclePedIsIn(PlayerPedId(), false)
            if taxi and taxi ~= 0 and DoesEntityExist(taxi) then
                local speedMs  = GetEntitySpeed(taxi)
                local speedKmh = speedMs * 3.6
                if speedKmh > Config.MaxSafeSpeed then
                    activeJob.condition = math.max(0, activeJob.condition - Config.SpeedConditionLoss)
                end

                local health = GetVehicleBodyHealth(taxi)
                if health < lastHealth then
                    local diff = (lastHealth - health) / 1000.0
                    activeJob.condition = math.max(0, activeJob.condition - diff * Config.ImpactConditionLoss * 100)
                end
                lastHealth = health
            end
            
            -- Lógica da viagem
            if activeJob.state == 'pickup' then
                local pcoords = GetEntityCoords(PlayerPedId())
                local pickup = activeJob.pickupCoords
                local dist = #(pcoords - vector3(pickup.x, pickup.y, pickup.z))
                
                if dist < 20.0 and taxi and taxi ~= 0 then
                    -- Fazer o ped entrar
                    if passengerPed and DoesEntityExist(passengerPed) and not IsPedInAnyVehicle(passengerPed, false) then
                        TaskEnterVehicle(passengerPed, taxi, -1, 2, 1.0, 1, 0)
                        activeJob.state = 'waiting_to_enter'
                        lib.notify({ title = 'Passageiro', description = 'Aguarde o passageiro entrar.', type = 'info' })
                    end
                end
            elseif activeJob.state == 'waiting_to_enter' then
                if passengerPed and IsPedInVehicle(passengerPed, taxi, false) then
                    activeJob.state = 'dropoff'
                    addPassengerBlip(activeJob.dropCoords, "Destino do Passageiro", 280, 5)
                    lib.notify({ title = 'Nova Rota', description = 'Leve o passageiro ao destino em segurança.', type = 'info' })
                end
            elseif activeJob.state == 'dropoff' then
                local pcoords = GetEntityCoords(PlayerPedId())
                local drop = activeJob.dropCoords
                local dist = #(pcoords - vector3(drop.x, drop.y, drop.z))
                
                if dist < 10.0 and taxi and taxi ~= 0 and GetEntitySpeed(taxi) < 1.0 then
                    activeJob.state = 'finished'
                    TaskLeaveVehicle(passengerPed, taxi, 0)
                    lib.notify({ title = 'Chegou', description = 'Passageiro entregue.', type = 'success' })
                    
                    Wait(3000)
                    CompleteJob()
                end
            end

            updateHUD()
            Wait(500)
        end
        jobMonitorRunning = false
    end)
end

function StartJob(callId)
    if activeJob then
        lib.notify({ title = 'Atenção', description = 'Você já tem uma corrida ativa.', type = 'warning' })
        return
    end

    local call = nil
    for _, r in ipairs(Config.Calls) do
        if r.id == callId then call = r break end
    end
    if not call then return end

    local pickupPoints = call.pickupPoints or {}
    local dropPoints   = call.dropPoints or {}
    if #pickupPoints == 0 or #dropPoints == 0 then return end
    
    local pickup = Config.Waypoints[pickupPoints[math.random(#pickupPoints)]]
    local drop   = Config.Waypoints[dropPoints[math.random(#dropPoints)]]
    
    -- Evitar que pickup e drop sejam iguais
    local maxRetries = 5
    while drop == pickup and maxRetries > 0 do
        drop = Config.Waypoints[dropPoints[math.random(#dropPoints)]]
        maxRetries = maxRetries - 1
    end

    spawnPassenger(pickup)

    activeJob = {
        callId       = callId,
        callLabel    = call.label,
        condition    = 100.0,
        startTime    = GetGameTimer() / 1000,
        pickupCoords = pickup,
        dropCoords   = drop,
        state        = 'pickup',
    }

    addPassengerBlip(pickup, "Buscar Passageiro", 280, 3)

    SendNUIMessage({
        type      = 'showHUD',
        route     = call.label,
        condition = 100,
        timeLeft  = '--:--',
    })

    lib.notify({
        title       = 'Corrida Aceita',
        description = 'Siga para o local indicado no GPS para buscar o passageiro.',
        type        = 'info',
        duration    = 6000,
    })

    startJobMonitor()
end

function CompleteJob()
    if not activeJob then return end

    local elapsed = GetGameTimer() / 1000 - activeJob.startTime
    local job     = activeJob
    activeJob     = nil

    removePassengerBlip()
    SendNUIMessage({ type = 'hideHUD' })
    
    -- Deleta passageiro após 10 segs (caminhando embora)
    if passengerPed and DoesEntityExist(passengerPed) then
        TaskWanderStandard(passengerPed, 10.0, 10)
        SetEntityAsNoLongerNeeded(passengerPed)
        passengerPed = nil
    end

    TriggerServerEvent('mri_Qtaxi:completeCall', {
        callId    = job.callId,
        condition = job.condition,
        elapsed   = elapsed,
    })
end

function CancelJob()
    if not activeJob then return end
    activeJob = nil
    
    removePassengerBlip()
    SendNUIMessage({ type = 'hideHUD' })
    
    if passengerPed and DoesEntityExist(passengerPed) then
        if IsPedInAnyVehicle(passengerPed, false) then
            TaskLeaveAnyVehicle(passengerPed, 0, 0)
        end
        TaskWanderStandard(passengerPed, 10.0, 10)
        SetEntityAsNoLongerNeeded(passengerPed)
        passengerPed = nil
    end

    lib.notify({ title = 'Corrida cancelada', description = 'Você abandonou o passageiro.', type = 'error' })
end
