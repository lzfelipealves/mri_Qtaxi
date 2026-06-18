local function dbGetPlayer(citizenid)
    return MySQL.single.await('SELECT * FROM mri_qtaxi_players WHERE citizenid = ?', { citizenid })
end

local function dbCreatePlayer(citizenid)
    MySQL.insert.await('INSERT INTO mri_qtaxi_players (citizenid) VALUES (?)', { citizenid })
    return { citizenid = citizenid, xp = 0, level = 1, total_deliveries = 0, total_earned = 0, history = '[]', owned_taxis = '[]' }
end

local function loadPlayer(citizenid)
    local data = dbGetPlayer(citizenid)
    if not data then data = dbCreatePlayer(citizenid) end
    data.history = json.decode(data.history or '[]')
    data.owned_taxis = json.decode(data.owned_taxis or '[]')
    return data
end

local function savePlayer(data)
    MySQL.update.await(
        'UPDATE mri_qtaxi_players SET xp=?, level=?, total_deliveries=?, total_earned=?, history=?, owned_taxis=? WHERE citizenid=?',
        { data.xp, data.level, data.total_deliveries, data.total_earned, json.encode(data.history), json.encode(data.owned_taxis), data.citizenid }
    )
end

lib.callback.register('mri_Qtaxi:getPlayerData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local data  = loadPlayer(player.PlayerData.citizenid)
    local level = GetPlayerLevel(data.xp)
    data.level  = level
    data.xpProgress    = GetXPProgress(data.xp)
    data.xpToNextLevel = GetXPToNextLevel(data.xp)
    data.levelData     = Config.Levels[level]
    
    local rank = MySQL.scalar.await('SELECT COUNT(*) FROM mri_qtaxi_players WHERE xp > ?', { data.xp }) + 1
    data.rank = rank
    data.rankBuff = Config.TopRankingBuffs and Config.TopRankingBuffs[rank] or nil
    
    return data
end)

lib.callback.register('mri_Qtaxi:getCalls', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local data  = loadPlayer(player.PlayerData.citizenid)
    local xp    = data and data.xp or 0
    local level = GetPlayerLevel(xp)
    return GetAvailableCalls(level)
end)

lib.callback.register('mri_Qtaxi:rentTaxi', function(source, id)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Jogador não encontrado' end

    local option = nil
    for _, opt in ipairs(Config.TaxiRentOptions) do
        if opt.id == id then option = opt break end
    end
    if not option then return false, 'Opção inválida' end

    local price = option.price
    local cash  = player.PlayerData.money['cash']
    local bank  = player.PlayerData.money['bank']

    if cash >= price then
        player.Functions.RemoveMoney('cash', price, 'mri_qtaxi-rent')
        return true, option.duration
    elseif bank >= price then
        player.Functions.RemoveMoney('bank', price, 'mri_qtaxi-rent')
        return true, option.duration
    end

    return false, 'Dinheiro insuficiente'
end)

lib.callback.register('mri_Qtaxi:buyTaxi', function(source, model)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Jogador não encontrado' end

    local option = nil
    for _, opt in ipairs(Config.TaxiBuyOptions) do
        if opt.model == model then option = opt break end
    end
    if not option then return false, 'Opção inválida' end

    local price = option.price
    local cash  = player.PlayerData.money['cash']
    local bank  = player.PlayerData.money['bank']

    local data = loadPlayer(player.PlayerData.citizenid)
    for _, v in ipairs(data.owned_taxis) do
        if v == model then return false, 'Você já possui este veículo' end
    end

    if cash >= price then
        player.Functions.RemoveMoney('cash', price, 'mri_qtaxi-buy')
    elseif bank >= price then
        player.Functions.RemoveMoney('bank', price, 'mri_qtaxi-buy')
    else
        return false, 'Dinheiro insuficiente'
    end

    table.insert(data.owned_taxis, model)
    savePlayer(data)
    return true
end)

lib.callback.register('mri_Qtaxi:getRanking', function(source, category)
    local orderCol = 'xp'
    if category == 'level' then orderCol = 'level'
    elseif category == 'deliveries' then orderCol = 'total_deliveries'
    end

    local query = string.format('SELECT citizenid, xp, level, total_deliveries FROM mri_qtaxi_players ORDER BY %s DESC LIMIT 50', orderCol)
    local playersData = MySQL.query.await(query)

    local ranking = {}
    if not playersData then return ranking end

    for _, v in ipairs(playersData) do
        local name = 'Desconhecido'
        local pData = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { v.citizenid })
        
        if pData and pData.charinfo then
            local charinfo = pData.charinfo
            if type(charinfo) == 'string' then
                local success, result = pcall(json.decode, charinfo)
                if success then charinfo = result else charinfo = nil end
            end
            
            if type(charinfo) == 'table' and charinfo.firstname and charinfo.lastname then
                name = charinfo.firstname .. ' ' .. charinfo.lastname
            end
        end
        table.insert(ranking, {
            citizenid = v.citizenid,
            name = name,
            xp = v.xp,
            level = v.level,
            total_deliveries = v.total_deliveries
        })
    end
    return ranking
end)

RegisterNetEvent('mri_Qtaxi:completeCall', function(payload)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local callId    = payload.callId
    local condition = math.max(0, math.min(100, payload.condition))
    local elapsed   = payload.elapsed

    local call = nil
    for _, r in ipairs(Config.Calls) do
        if r.id == callId then call = r break end
    end
    if not call then return end

    local data  = loadPlayer(player.PlayerData.citizenid)
    local level = GetPlayerLevel(data.xp)
    local mult  = Config.Levels[level].multiplier

    local basePay   = math.floor(call.basePay * mult)

    local condMult = condition / 100
    basePay = math.floor(basePay * condMult)

    local timeBonus = 0
    -- Se o tempo decorrido (elapsed) foi bom, pode dar bônus
    -- Simplificando, se condMult > 0.9, e o user n demorou 1 hora (ex: < 15 min), damos bônus
    if elapsed <= (15 * 60) then
        timeBonus = math.floor(basePay * Config.TimeBonusPercent)
    end
    
    local rank = MySQL.scalar.await('SELECT COUNT(*) FROM mri_qtaxi_players WHERE xp > ?', { data.xp }) + 1
    local rankBuff = Config.TopRankingBuffs and Config.TopRankingBuffs[rank] or 1.0

    local totalPay = math.floor((basePay + timeBonus) * rankBuff)

    local xpGained = call.baseXP
    if elapsed <= (15 * 60) then
        xpGained = math.floor(xpGained * 1.25)
    end
    if condition >= 90 then xpGained = math.floor(xpGained * 1.10) end

    local oldLevel  = level
    data.xp              = data.xp + xpGained
    data.total_deliveries = data.total_deliveries + 1
    data.total_earned    = data.total_earned + totalPay
    data.level           = GetPlayerLevel(data.xp)

    local entry = {
        call      = call.label,
        pay       = totalPay,
        xp        = xpGained,
        condition = condition,
        bonus     = timeBonus,
        date      = os.date('%d/%m %H:%M'),
    }
    table.insert(data.history, 1, entry)
    if #data.history > 20 then table.remove(data.history) end

    savePlayer(data)
    player.Functions.AddMoney('cash', totalPay, 'taxi-ride')

    TriggerClientEvent('mri_Qtaxi:rideResult', src, {
        pay       = totalPay,
        timeBonus = timeBonus,
        xp        = xpGained,
        condition = condition,
        leveledUp = data.level > oldLevel,
        newLevel  = data.level,
        newLevelLabel = Config.Levels[data.level] and Config.Levels[data.level].label or '',
        totalXP   = data.xp,
    })
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mri_qtaxi_players` (
            `citizenid`         VARCHAR(50) NOT NULL,
            `xp`                INT NOT NULL DEFAULT 0,
            `level`             INT NOT NULL DEFAULT 1,
            `total_deliveries`  INT NOT NULL DEFAULT 0,
            `total_earned`      BIGINT NOT NULL DEFAULT 0,
            `owned_taxis`       LONGTEXT DEFAULT '[]',
            `history`           LONGTEXT,
            `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)
