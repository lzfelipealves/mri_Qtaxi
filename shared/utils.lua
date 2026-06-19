function GetPlayerLevel(xp)
    local level = 1
    for l = #Config.Levels, 1, -1 do
        if xp >= Config.Levels[l].xp then
            level = l
            break
        end
    end
    return level
end

function GetXPProgress(xp)
    local level = GetPlayerLevel(xp)
    if level >= #Config.Levels then return 100 end
    local cur  = Config.Levels[level].xp
    local next = Config.Levels[level + 1].xp
    return math.floor(((xp - cur) / (next - cur)) * 100)
end

function GetXPToNextLevel(xp)
    local level = GetPlayerLevel(xp)
    if level >= #Config.Levels then return 0 end
    return Config.Levels[level + 1].xp - xp
end

function GetAvailableCalls(playerLevel)
    local calls = {}
    for _, call in ipairs(Config.Calls) do
        if playerLevel >= call.minLevel then
            calls[#calls + 1] = call
        end
    end
    return calls
end

function GetRandomCall(playerLevel)
    local available = GetAvailableCalls(playerLevel)
    if #available == 0 then return nil end
    return available[math.random(#available)]
end

function FormatMoney(amount)
    return string.format("R$ %s", tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end
