local currentTableId = nil

local function closeRoulette()
    if not currentTableId then return end
    TriggerServerEvent('rsg-roulette:server:leave', currentTableId)
    currentTableId = nil
    NUI.Close()
end

---@param tableId string
local function openRoulette(tableId)
    if currentTableId or IsPlacingTable() or not RouletteTables[tableId] then return end
    currentTableId = tableId

    TriggerServerEvent('rsg-roulette:server:join', tableId)
    NUI.Open({ tableId = tableId, locale = lib.getLocales() })

    -- auto close if the player walks away or dies while the table is open
    CreateThread(function()
        local coords = RouletteTables[tableId].coords
        local maxDist = Config.InteractDistance + 1.0
        while currentTableId == tableId do
            local ped = cache.ped
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - coords) > maxDist then
                closeRoulette()
                break
            end
            Wait(500)
        end
    end)
end

exports('openRoulette', openRoulette)
OpenRoulette = openRoulette

---------------------------------
-- nui callbacks
---------------------------------
RegisterNUICallback('placeBet', function(data, cb)
    if currentTableId and type(data) == 'table' then
        TriggerServerEvent('rsg-roulette:server:placeBet', currentTableId, data.bet)
    end
    cb('ok')
end)

RegisterNUICallback('removeBet', function(data, cb)
    if currentTableId and type(data) == 'table' then
        TriggerServerEvent('rsg-roulette:server:removeBet', currentTableId, data.bet)
    end
    cb('ok')
end)

RegisterNUICallback('clearBets', function(_, cb)
    if currentTableId then
        TriggerServerEvent('rsg-roulette:server:clearBets', currentTableId)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeRoulette()
    cb('ok')
end)

---------------------------------
-- server -> nui relays
---------------------------------
RegisterNetEvent('rsg-roulette:client:syncState', function(data)
    if not currentTableId or type(data) ~= 'table' or data.tableId ~= currentTableId then return end
    NUI.Send('syncState', data)
end)

local relays = {
    ['rsg-roulette:client:betAccepted']  = 'betAccepted',
    ['rsg-roulette:client:betRejected']  = 'betRejected',
    ['rsg-roulette:client:betsCleared']  = 'betsCleared',
    ['rsg-roulette:client:playerResult'] = 'playerResult',
}

for event, action in pairs(relays) do
    RegisterNetEvent(event, function(data)
        if currentTableId then NUI.Send(action, data) end
    end)
end

RegisterNetEvent('rsg-roulette:client:forceClose', closeRoulette)
