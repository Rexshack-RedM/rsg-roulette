local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local DATA_FILE      = 'data.json'
local BET_COOLDOWN   = 150 -- ms between bet actions per player (fast chip clicking still works)
local HISTORY_SIZE   = 12
local SPINS_PER_SAVE = 5

-- total return INCLUDING the stake (35:1 straight = 36x back)
local PAYOUT = {
    straight = 36, green = 36, split = 18, corner = 9,
    red = 2, black = 2, odd = 2, even = 2, low = 2, high = 2,
    dozen1 = 3, dozen2 = 3, dozen3 = 3,
    column1 = 3, column2 = 3, column3 = 3,
}

local RED = {
    [1] = true, [3] = true, [5] = true, [7] = true, [9] = true, [12] = true,
    [14] = true, [16] = true, [18] = true, [19] = true, [21] = true, [23] = true,
    [25] = true, [27] = true, [30] = true, [32] = true, [34] = true, [36] = true,
}

local function numberColor(n)
    if n == 0 then return 'green' end
    return RED[n] and 'red' or 'black'
end

---------------------------------
-- state
---------------------------------
local Tables = {}          -- [tableId] = { coords, phase, countdown, result, resultColor, bets = {[src] = {...}}, viewers = {[src] = true}, history = {} }
local frequency = {}       -- [num] = count
local lastAction = {}      -- [src] = GetGameTimer()
local spinsSinceSave = 0

local tablesLoaded = false

local function newTable(id, coords, heading, room)
    Tables[id] = {
        id = id,
        coords = coords,
        heading = heading,
        room = room or 0,
        phase = 'waiting',
        countdown = 0,
        bets = {},
        viewers = {},
        history = {},
    }
    return Tables[id]
end

---------------------------------
-- persistence (history + hot numbers)
---------------------------------
local function saveData()
    local history = {}
    for tableId, t in pairs(Tables) do history[tableId] = t.history end

    local freq = {}
    for n = 0, 36 do freq[n + 1] = frequency[n] or 0 end

    SaveResourceFile(GetCurrentResourceName(), DATA_FILE, json.encode({ frequency = freq, history = history }), -1)
end

local function loadData()
    local raw = LoadResourceFile(GetCurrentResourceName(), DATA_FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end

    if type(data.frequency) == 'table' then
        for n = 0, 36 do frequency[n] = tonumber(data.frequency[n + 1]) or 0 end
    end
    if type(data.history) == 'table' then
        for tableId, h in pairs(data.history) do
            if Tables[tableId] and type(h) == 'table' then Tables[tableId].history = h end
        end
    end
end

local function getHottestNumbers(limit)
    local list = {}
    for n = 0, 36 do
        local c = frequency[n] or 0
        if c > 0 then list[#list + 1] = { num = n, count = c, color = numberColor(n) } end
    end
    table.sort(list, function(a, b)
        if a.count == b.count then return a.num < b.num end
        return a.count > b.count
    end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

---------------------------------
-- bet helpers
---------------------------------
local function parseNumbers(value)
    if type(value) ~= 'string' then return nil end
    local nums, seen = {}, {}
    for part in value:gmatch('%d+') do
        local n = tonumber(part)
        if n > 36 or seen[n] then return nil end
        seen[n] = true
        nums[#nums + 1] = n
    end
    table.sort(nums)
    return nums
end

local function isValidSplit(n)
    if not n or #n ~= 2 then return false end
    local a, b = n[1], n[2]
    if a == 0 then return b >= 1 and b <= 3 end
    return (b - a == 3) or (b - a == 1 and a % 3 ~= 0)
end

local function isValidCorner(n)
    if not n or #n ~= 4 then return false end
    local a = n[1]
    return a >= 1 and a % 3 ~= 0 and n[2] == a + 1 and n[3] == a + 3 and n[4] == a + 4
end

--- validates a bet value, returns normalised value or nil + locale key
local function validateBet(betType, value)
    if not PAYOUT[betType] then return nil, 'invalid_bet_type' end

    if betType == 'straight' then
        local n = tonumber(value)
        if not n or n < 0 or n > 36 or n % 1 ~= 0 then return nil, 'invalid_bet_number' end
        return n
    elseif betType == 'split' then
        if not isValidSplit(parseNumbers(value)) then return nil, 'invalid_split_bet' end
        return value
    elseif betType == 'corner' then
        if not isValidCorner(parseNumbers(value)) then return nil, 'invalid_corner_bet' end
        return value
    end
    -- outside bets: value is only a UI label, payout is decided by the type
    if type(value) ~= 'string' or #value > 16 then return nil, 'invalid_bet_data' end
    return value
end

local function betWins(bet, result)
    local t = bet.type
    if t == 'straight' then return bet.value == result end
    if t == 'split' or t == 'corner' then
        for _, n in ipairs(parseNumbers(bet.value)) do
            if n == result then return true end
        end
        return false
    end
    if result == 0 then return t == 'green' end
    if t == 'red' or t == 'black' then return numberColor(result) == t end
    if t == 'odd' then return result % 2 == 1 end
    if t == 'even' then return result % 2 == 0 end
    if t == 'low' then return result <= 18 end
    if t == 'high' then return result >= 19 end
    if t == 'dozen1' then return result <= 12 end
    if t == 'dozen2' then return result >= 13 and result <= 24 end
    if t == 'dozen3' then return result >= 25 end
    if t == 'column1' then return result % 3 == 1 end
    if t == 'column2' then return result % 3 == 2 end
    if t == 'column3' then return result % 3 == 0 end
    return false
end

local function totalOf(bets)
    local total = 0
    for _, b in ipairs(bets) do total = total + b.amount end
    return total
end

---------------------------------
-- networking
---------------------------------
local function snapshot(tableId, full)
    local t = Tables[tableId]
    local data = {
        tableId = tableId,
        phase = t.phase,
        countdown = t.countdown,
        result = t.result,
        resultColor = t.resultColor,
    }
    if full then
        data.history = t.history
        data.hottestNumbers = getHottestNumbers(8)
        data.maxBet = Config.MaxBet
    end
    return data
end

--- only players with this table open receive updates
local function broadcast(tableId, full)
    local data = snapshot(tableId, full)
    for src in pairs(Tables[tableId].viewers) do
        TriggerClientEvent('rsg-roulette:client:syncState', src, data)
    end
end

local function reject(src, key, ...)
    TriggerClientEvent('rsg-roulette:client:betRejected', src, { message = locale(key, ...) })
end

local function isNearTable(src, tableId)
    local t = Tables[tableId]
    if not t then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - t.coords) <= Config.InteractDistance + 2.0 -- small buffer for latency
end

local function rateLimited(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < BET_COOLDOWN then return true end
    lastAction[src] = now
    return false
end

local function playerName(Player)
    local c = Player.PlayerData.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

---------------------------------
-- game loop
---------------------------------
local function hasActivity(t)
    return next(t.viewers) ~= nil or next(t.bets) ~= nil
end

local function startBetting(tableId)
    local t = Tables[tableId]
    t.phase, t.countdown, t.result, t.resultColor, t.bets = 'betting', Config.BettingTime, nil, nil, {}
    broadcast(tableId, true)
end

local function startSpin(tableId)
    local t = Tables[tableId]
    t.phase, t.countdown = 'spinning', Config.SpinTime
    t.result = math.random(0, 36)
    t.resultColor = numberColor(t.result)
    broadcast(tableId, false)
end

local function payout(tableId)
    local t = Tables[tableId]
    local result = t.result
    local totalBets, totalPaid, players = 0, 0, 0

    for src, bets in pairs(t.bets) do
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            local winnings, staked, types = 0, 0, {}
            for _, bet in ipairs(bets) do
                staked = staked + bet.amount
                if betWins(bet, result) then
                    winnings = winnings + bet.amount * PAYOUT[bet.type]
                    types[#types + 1] = bet.type
                end
            end

            totalBets, totalPaid, players = totalBets + staked, totalPaid + winnings, players + 1

            if winnings > 0 then
                Player.Functions.AddMoney('cash', winnings, 'roulette-win')
                local name = playerName(Player)
                WebhookLogWin(name, winnings, table.concat(types, ', '), result, t.resultColor, tableId)
                if result == 0 then WebhookLogJackpot(name, winnings, tableId) end
            end

            TriggerClientEvent('rsg-roulette:client:playerResult', src, {
                won = winnings > 0,
                amount = winnings,
                result = result,
                resultColor = t.resultColor,
            })
        end
    end

    if players > 0 then
        WebhookLogSpin(result, t.resultColor, players, totalBets, totalPaid, tableId)
    end
end

local function startResult(tableId)
    local t = Tables[tableId]
    t.phase, t.countdown = 'result', Config.ResultDisplayTime

    table.insert(t.history, 1, { num = t.result, color = t.resultColor })
    if #t.history > HISTORY_SIZE then t.history[#t.history] = nil end
    frequency[t.result] = (frequency[t.result] or 0) + 1

    spinsSinceSave = spinsSinceSave + 1
    if spinsSinceSave >= SPINS_PER_SAVE then
        spinsSinceSave = 0
        saveData()
    end

    payout(tableId)
    broadcast(tableId, true)
end

local function endRound(tableId)
    local t = Tables[tableId]
    for src in pairs(t.bets) do
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            TriggerClientEvent('rsg-roulette:client:betsCleared', src, {
                cash = Player.Functions.GetMoney('cash'),
                autoClear = true,
            })
        end
    end
    t.bets = {}

    if hasActivity(t) then
        startBetting(tableId)
    else
        t.phase = 'waiting' -- idle tables stop ticking until someone sits down
    end
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_roulette_tables` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `room` BIGINT NOT NULL DEFAULT 0,
            `placed_by` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]])
    -- add the interior room column to tables created by older versions
    if not MySQL.scalar.await("SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_roulette_tables' AND COLUMN_NAME = 'room'") then
        MySQL.query.await('ALTER TABLE rsg_roulette_tables ADD COLUMN `room` BIGINT NOT NULL DEFAULT 0')
    end

    for _, row in ipairs(MySQL.query.await('SELECT id, x, y, z, heading, room FROM rsg_roulette_tables') or {}) do
        newTable('table_' .. row.id, vector3(row.x, row.y, row.z), row.heading + 0.0, tonumber(row.room) or 0)
    end
    tablesLoaded = true
    loadData()
    while true do
        Wait(1000)
        for tableId, t in pairs(Tables) do
            if t.phase ~= 'waiting' then
                t.countdown = t.countdown - 1
                if t.countdown > 0 then
                    broadcast(tableId, false)
                elseif t.phase == 'betting' then
                    startSpin(tableId)
                elseif t.phase == 'spinning' then
                    startResult(tableId)
                elseif t.phase == 'result' then
                    endRound(tableId)
                end
            end
        end
    end
end)

---------------------------------
-- events
---------------------------------
RegisterNetEvent('rsg-roulette:server:join', function(tableId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local t = Tables[tableId]
    if not Player or not t or rateLimited(src) then return end

    if not isNearTable(src, tableId) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('ui_title'), description = locale('too_far'), type = 'error', duration = 5000 })
        TriggerClientEvent('rsg-roulette:client:forceClose', src)
        return
    end

    t.viewers[src] = true
    if t.phase == 'waiting' then
        startBetting(tableId)
    end

    local data = snapshot(tableId, true)
    data.cash = Player.Functions.GetMoney('cash')
    data.bets = t.bets[src] or {}
    TriggerClientEvent('rsg-roulette:client:syncState', src, data)
end)

RegisterNetEvent('rsg-roulette:server:leave', function(tableId)
    local t = Tables[tableId]
    if t then t.viewers[source] = nil end
end)

RegisterNetEvent('rsg-roulette:server:placeBet', function(tableId, bet)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local t = Tables[tableId]
    if not Player or not t then return end

    if rateLimited(src) then return reject(src, 'bet_too_fast') end
    if t.phase ~= 'betting' then return reject(src, 'betting_closed') end
    if not isNearTable(src, tableId) then return reject(src, 'too_far') end
    if type(bet) ~= 'table' then return reject(src, 'invalid_bet_data') end

    local amount = tonumber(bet.amount)
    if not amount or amount ~= amount or amount < Config.MinBet or amount % 1 ~= 0 then
        return reject(src, 'invalid_bet_amount', Config.MinBet)
    end

    local value, err = validateBet(bet.type, bet.value)
    if not value then return reject(src, err) end

    local bets = t.bets[src] or {}
    if totalOf(bets) + amount > Config.MaxBet then
        return reject(src, 'total_bet_exceeds_max', Config.MaxBet)
    end

    -- stakes already placed have been taken, so only the new chip must be covered
    if Player.Functions.GetMoney('cash') < amount or not Player.Functions.RemoveMoney('cash', amount, 'roulette-bet') then
        return reject(src, 'not_enough_cash')
    end

    local existing
    for _, b in ipairs(bets) do
        if b.type == bet.type and b.value == value then existing = b break end
    end
    if existing then
        existing.amount = existing.amount + amount
    else
        bets[#bets + 1] = { type = bet.type, value = value, amount = amount }
    end
    t.bets[src] = bets

    TriggerClientEvent('rsg-roulette:client:betAccepted', src, { bets = bets, cash = Player.Functions.GetMoney('cash') })
end)

RegisterNetEvent('rsg-roulette:server:removeBet', function(tableId, bet)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local t = Tables[tableId]
    if not Player or not t or t.phase ~= 'betting' or type(bet) ~= 'table' then return end
    if rateLimited(src) then return end

    local bets = t.bets[src]
    if not bets then return end

    local value = bet.type == 'straight' and tonumber(bet.value) or bet.value

    for i, b in ipairs(bets) do
        if b.type == bet.type and b.value == value then
            table.remove(bets, i)
            if #bets == 0 then t.bets[src] = nil end
            Player.Functions.AddMoney('cash', b.amount, 'roulette-refund')
            break
        end
    end

    TriggerClientEvent('rsg-roulette:client:betAccepted', src, { bets = t.bets[src] or {}, cash = Player.Functions.GetMoney('cash') })
end)

RegisterNetEvent('rsg-roulette:server:clearBets', function(tableId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local t = Tables[tableId]
    if not Player or not t or t.phase ~= 'betting' then return end
    if rateLimited(src) then return end

    local bets = t.bets[src]
    t.bets[src] = nil -- clear before paying so it can never be refunded twice
    if bets then
        local total = totalOf(bets)
        if total > 0 then Player.Functions.AddMoney('cash', total, 'roulette-refund') end
    end

    TriggerClientEvent('rsg-roulette:client:betsCleared', src, { cash = Player.Functions.GetMoney('cash') })
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastAction[src] = nil
    local Player = RSGCore.Functions.GetPlayer(src)
    for _, t in pairs(Tables) do
        t.viewers[src] = nil
        local bets = t.bets[src]
        if bets then
            t.bets[src] = nil
            -- refund if still in the betting window, otherwise the stake stands (no dodging a losing spin)
            if t.phase == 'betting' and Player then
                Player.Functions.AddMoney('cash', totalOf(bets), 'roulette-refund')
            end
        end
    end
end)

---------------------------------
-- table placement (admin)
---------------------------------
local function clientTable(t)
    return { id = t.id, coords = t.coords, heading = t.heading, room = t.room }
end

lib.callback.register('rsg-roulette:server:getTables', function()
    while not tablesLoaded do Wait(100) end
    local list = {}
    for _, t in pairs(Tables) do list[#list + 1] = clientTable(t) end
    return list
end)

local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command.placeroulette')
end

local function notify(src, key, nType, ...)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('ui_title'), description = locale(key, ...), type = nType, duration = 5000 })
end

local function nearestTable(coords, maxDist)
    local best, bestDist
    for _, t in pairs(Tables) do
        local d = #(coords - t.coords)
        if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = t, d end
    end
    return best
end

lib.addCommand('placeroulette', { help = locale('cmd_place_help'), restricted = 'group.admin' }, function(src)
    TriggerClientEvent('rsg-roulette:client:startPlacement', src)
end)

lib.addCommand('removeroulette', { help = locale('cmd_remove_help'), restricted = 'group.admin' }, function(src)
    local ped = GetPlayerPed(src)
    local t = ped ~= 0 and nearestTable(GetEntityCoords(ped), 3.0)
    if not t then return notify(src, 'no_table_nearby', 'error') end

    -- refund open stakes and kick viewers before removing
    if t.phase == 'betting' or t.phase == 'spinning' then
        for bettor, bets in pairs(t.bets) do
            local Player = RSGCore.Functions.GetPlayer(bettor)
            if Player then Player.Functions.AddMoney('cash', totalOf(bets), 'roulette-refund') end
        end
    end
    for viewer in pairs(t.viewers) do
        TriggerClientEvent('rsg-roulette:client:forceClose', viewer)
    end

    local dbId = tonumber(t.id:match('%d+'))
    MySQL.update.await('DELETE FROM rsg_roulette_tables WHERE id = ?', { dbId })
    Tables[t.id] = nil
    TriggerClientEvent('rsg-roulette:client:removeTable', -1, t.id)
    notify(src, 'table_removed', 'success')
end)

RegisterNetEvent('rsg-roulette:server:placeTable', function(coords, heading, room)
    local src = source
    if not isAdmin(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    heading = tonumber(heading)
    if type(coords) ~= 'vector3' or not heading or heading ~= heading or coords.x ~= coords.x or coords.y ~= coords.y or coords.z ~= coords.z then return end
    heading = heading % 360.0
    room = math.tointeger(tonumber(room)) or 0

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - coords) > Config.Placement.MaxDistance + 2.0 then
        return notify(src, 'placement_too_far', 'error')
    end
    if nearestTable(coords, Config.Placement.MinSpacing) then
        return notify(src, 'placement_too_close', 'error')
    end

    local dbId = MySQL.insert.await('INSERT INTO rsg_roulette_tables (x, y, z, heading, room, placed_by) VALUES (?, ?, ?, ?, ?, ?)', {
        coords.x, coords.y, coords.z, heading, room, Player.PlayerData.citizenid,
    })
    if not dbId then return notify(src, 'placement_failed', 'error') end

    local t = newTable('table_' .. dbId, coords, heading, room)
    TriggerClientEvent('rsg-roulette:client:addTable', -1, clientTable(t))
    notify(src, 'table_placed', 'success')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- refund unsettled stakes so a restart never eats player money
    for _, t in pairs(Tables) do
        if t.phase == 'betting' or t.phase == 'spinning' then
            for src, bets in pairs(t.bets) do
                local Player = RSGCore.Functions.GetPlayer(src)
                if Player then Player.Functions.AddMoney('cash', totalOf(bets), 'roulette-refund') end
            end
        end
        t.bets = {}
    end
    saveData()
end)
