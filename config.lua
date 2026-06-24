Config = {}

Config.Debug = false

-- ─── Spawns de Veículos ────────────────────────────────────────────────────────
-- Será configurado dentro de cada ponto de Táxi (Taxi Stands)

Config.CallGenerateInterval = 30 -- Tempo em segundos para gerar uma nova corrida
Config.MaxActiveCalls       = 15 -- Limite máximo de corridas ativas no servidor simultaneamente
Config.TabletItem           = 'tablet_taxi' -- Nome do item usável no inventário
Config.MinimumCallDistance  = 300.0 -- Distância mínima do jogador ao ponto de coleta para a corrida aparecer no tablet

-- ─── Aluguel de Táxi (Por Tempo) ────────────────────────────────────────────────
Config.RentVehicleModel = 'taxi' -- Veículo spawnado no aluguel

Config.TaxiRentOptions = {
    { id = 'rent_30', label = 'Aluguel Rápido', price = 500, duration = 30, image = 'https://docs.fivem.net/vehicles/taxi.webp', desc = 'Aluguel por 30 Minutos' },
    { id = 'rent_60', label = 'Aluguel Padrão', price = 800, duration = 60, image = 'https://docs.fivem.net/vehicles/taxi.webp', desc = 'Aluguel por 1 Hora' },
    { id = 'rent_120',label = 'Aluguel Diário', price = 1400, duration = 120, image = 'https://docs.fivem.net/vehicles/taxi.webp', desc = 'Aluguel por 2 Horas' },
}

-- Veículo padrão para aluguel (todos recebem este modelo)
Config.RentVehicleModel = 'taxi'

-- ─── Táxis Disponíveis para Compra ───────────────────────────────────────────
Config.TaxiBuyOptions = {
    { model = 'taxi',   label = 'Vapid Stanier (Táxi Padrão)', price = 5000,  image = 'https://docs.fivem.net/vehicles/taxi.webp', desc = 'Táxi clássico de Los Santos' },
    { model = 'dynasty',label = 'Ocelot Dynasty (Táxi Retrô)', price = 12000, image = 'https://docs.fivem.net/vehicles/dynasty.webp', desc = 'Táxi retrô de luxo' },
}

-- ─── Parâmetros da Corrida ────────────────────────────────────────────────────
Config.MaxSafeSpeed        = 130    -- km/h máximo sem penalidade de satisfação
Config.SpeedConditionLoss  = 0.002  -- perda de satisfação do cliente por tick acima do limite
Config.ImpactConditionLoss = 0.5    -- multiplicador de perda de satisfação em colisões
Config.TimeBonusPercent    = 0.15   -- bônus de pagamento de 15% (gorjeta por rapidez)

-- ─── Níveis e Títulos ─────────────────────────────────────────────────────────
Config.Levels = {
    [1]  = { xp = 0,      label = "Iniciante",         multiplier = 1.00, color = "#9ca3af" },
    [2]  = { xp = 500,    label = "Motorista",         multiplier = 1.10, color = "#60a5fa" },
    [3]  = { xp = 1500,   label = "Motorista Ágil",    multiplier = 1.25, color = "#34d399" },
    [4]  = { xp = 3000,   label = "Taxista",           multiplier = 1.40, color = "#a78bfa" },
    [5]  = { xp = 5500,   label = "Taxista Noturno",   multiplier = 1.60, color = "#f472b6" },
    [6]  = { xp = 9000,   label = "Taxista Vip",       multiplier = 1.85, color = "#fb923c" },
    [7]  = { xp = 14000,  label = "Chauffeur",         multiplier = 2.10, color = "#fbbf24" },
    [8]  = { xp = 20000,  label = "Chauffeur de Luxo", multiplier = 2.40, color = "#f87171" },
    [9]  = { xp = 28000,  label = "Piloto de Fuga",    multiplier = 2.80, color = "#c084fc" },
    [10] = { xp = 38000,  label = "Rei das Ruas",      multiplier = 3.50, color = "#f59e0b" },
}

-- Bônus de multiplicador no pagamento para os Top 3 do Ranking
Config.TopRankingBuffs = {
    [1] = 1.5, -- Top 1: +50% de lucro
    [2] = 1.3, -- Top 2: +30% de lucro
    [3] = 1.1, -- Top 3: +10% de lucro
}

-- ─── Tipos de Passageiros (Zonas de atuação / "Cargas") ──────────────────────
Config.Zones = {
    centro = {
        label    = "Passageiros do Centro",
        desc     = "Corridas executivas na cidade",
        minLevel = 1,
        color    = "#60a5fa",
        icon     = "💼",
    },
    aeroporto = {
        label    = "Passageiros de LSIA",
        desc     = "Turistas e executivos apressados",
        minLevel = 3,
        color    = "#f59e0b",
        icon     = "✈️",
    },
    norte = {
        label    = "Sandy Shores / Paleto",
        desc     = "Viagens longas pelo estado",
        minLevel = 5,
        color    = "#10b981",
        icon     = "🏜️",
    },
    luxo = {
        label    = "Vinewood Hills / Rockford",
        desc     = "Passageiros de alto padrão",
        minLevel = 7,
        color    = "#c084fc",
        icon     = "🍸",
    },
}

-- ─── Modelos de NPCs (Passageiros) ────────────────────────────────────────────
Config.PassengerModels = {
    "a_m_y_business_01", "a_m_y_business_02", "a_m_y_business_03",
    "a_f_y_business_01", "a_f_y_business_02", "a_f_y_business_03",
    "a_m_y_tourist_01", "a_m_y_tourist_02",
    "a_f_y_tourist_01", "a_f_y_tourist_02",
    "a_m_y_vinewood_01", "a_m_y_vinewood_02",
    "a_f_y_vinewood_01", "a_f_y_vinewood_02",
}

-- ─── Locais de Coleta e Destino (Waypoints) ──────────────────────────────────
-- O sistema sorteará um pickup (A) e um destino (B) dentro da lista da chamada.
Config.Waypoints = {
    -- Centro
    [1] = vector4(189.65, -929.56, 30.68, 142.5),  -- Legion Square
    [2] = vector4(-161.41, -1004.91, 27.27, 252.0), -- Alta St
    [3] = vector4(241.67, -356.12, 44.45, 160.0),  -- Pillbox Hill
    -- Aeroporto
    [4] = vector4(-1034.6, -2733.6, 13.75, 330.0), -- LSIA Terminal 1
    [5] = vector4(-1038.5, -2742.6, 20.16, 330.0), -- LSIA Terminal 2 (Upper)
    -- Norte
    [6] = vector4(1956.4, 3768.1, 32.2, 300.0),    -- Sandy Shores Medical
    [7] = vector4(1705.5, 4927.4, 42.0, 320.0),    -- Grapeseed
    [8] = vector4(124.6, 6614.9, 31.8, 315.0),     -- Paleto Bay Bank
    -- Luxo
    [9] = vector4(-1040.6, -213.9, 37.9, 210.0),   -- Rockford Hills / Lifeinvader
    [10]= vector4(-1218.6, -114.7, 39.0, 140.0),   -- Rockford Luxury
    [11]= vector4(-54.4, 825.2, 235.6, 250.0),     -- Vinewood Hills House
}

-- ─── Tipos de Chamadas (Rotas e Zonas) ────────────────────────────────────────
-- pickupPoints e dropPoints: lista de índices de Config.Waypoints
Config.Calls = {
    {
        id           = 1,
        label        = "Corrida Central",
        zone         = "centro",
        pickupPoints = {1, 2, 3},
        dropPoints   = {1, 2, 3, 9},
        distance     = "Curta / Média",
        basePay      = 1000,
        baseXP       = 100,
        minLevel     = 1,
    },
    {
        id           = 2,
        label        = "Viagem ao Aeroporto",
        zone         = "aeroporto",
        pickupPoints = {4, 5},
        dropPoints   = {1, 2, 3, 9, 10},
        distance     = "Média",
        basePay      = 1500,
        baseXP       = 150,
        minLevel     = 3,
    },
    {
        id           = 3,
        label        = "Viagem ao Norte",
        zone         = "norte",
        pickupPoints = {6, 7, 8},
        dropPoints   = {1, 2, 4, 9},
        distance     = "Longa",
        basePay      = 3000,
        baseXP       = 300,
        minLevel     = 5,
    },
    {
        id           = 4,
        label        = "Passageiro VIP",
        zone         = "luxo",
        pickupPoints = {9, 10, 11},
        dropPoints   = {4, 11, 2},
        distance     = "Média / Longa",
        basePay      = 4000,
        baseXP       = 400,
        minLevel     = 7,
    },
}

-- ─── Pontos de Táxi (Despachantes / Menu) ─────────────────────────────────────
Config.TaxiStands = {
    {
        id          = 1,
        label       = "Central de Táxi (Downtown)",
        coords      = vector4(895.0, -179.3, 74.7, 238.1), -- Local do Despachante
        ped         = "a_m_y_business_02",
        blip        = { sprite = 198, color = 5, label = "Ponto de Táxi" },
        spawnPoint  = { coords = vector3(898.77, -180.1, 73.81), heading = 236.48, radius = 5.0 }, -- Onde o táxi comprado/alugado spawna
    },
    {
        id          = 2,
        label       = "Ponto de Táxi (Aeroporto)",
        coords      = vector4(-1052.1, -2722.5, 13.7, 330.0),
        ped         = "a_m_y_business_01",
        blip        = { sprite = 198, color = 5, label = "Ponto de Táxi" },
        spawnPoint  = { coords = vector3(-1046.8, -2717.3, 13.7), heading = 330.0, radius = 5.0 },
    },
}

-- ─── Falas e Áudios dos Passageiros ───────────────────────────────────────────
-- Os caminhos dos áudios devem ser relativos à pasta 'html'. Exemplo: 'voice/m_speed.ogg' aponta para 'html/voice/m_speed.ogg'
Config.Infractions = {
    speed = {
        male = {
            { text = "Para que essa pressa?", audio = "voice/pressa_m.mp3" },
            { text = "Diminui a velocidade, Maluco!", audio = "voice/diminui_m.mp3" },
        },
        female = {
            { text = "Para que essa pressa?", audio = "voice/pressa_f.mp3" },
            { text = "Vai devagar, Doido!", audio = "voice/vai_devagar.mp3" },
        }
    },
    impact = {
        male = {
            { text = "Tá maluco?! Olha pra frente!", audio = "voice/maluco_m.mp3" },
            { text = "Aí meu pescoço, eu vou te processar!", audio = "voice/pescoco_m.mp3" },
        },
        female = {
            { text = "Quer me matar do coração?", audio = "voice/quer_matar.mp3" },
            { text = "Ai, meu Deus, que motorista péssimo!", audio = "voice/motorista_pessimo.mp3" },
        }
    }
}
