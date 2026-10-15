local TABLE_MODEL = joaat('p_roulettetable01x')

---@type table<string, { coords: vector3, heading: number, entity?: number, zone?: number, blip?: number, point?: table }>
RouletteTables = {}

local function spawnProp(t)
    t.inRange = true
    if t.spawning or (t.entity and DoesEntityExist(t.entity)) then return end
    t.spawning = true
    if not lib.requestModel(TABLE_MODEL, 10000) then
        print('[rsg-roulette] ERROR: roulette table model failed to load')
        t.spawning = false
        return
    end
    -- tables inside buildings must be put in the right interior room or they are culled
    local interior = t.room ~= 0 and GetInteriorAtCoords(t.coords.x, t.coords.y, t.coords.z) or 0
    if interior ~= 0 then
        local timeout = GetGameTimer() + 5000
        while not IsInteriorReady(interior) and GetGameTimer() < timeout do Wait(50) end
    end

    -- local (non-networked) prop: every client spawns its own, so no duplicates
    local entity = CreateObject(TABLE_MODEL, t.coords.x, t.coords.y, t.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(TABLE_MODEL)
    t.spawning = false
    if entity == 0 then return end
    -- player left range (or the table was removed) while we waited for the interior
    if not t.inRange then
        DeleteEntity(entity)
        return
    end
    SetEntityHeading(entity, t.heading)
    FreezeEntityPosition(entity, true)
    if interior ~= 0 then
        ForceRoomForEntity(entity, interior, t.room)
    end
    t.entity = entity
end

local function deleteProp(t)
    t.inRange = false
    if t.entity and DoesEntityExist(t.entity) then DeleteEntity(t.entity) end
    t.entity = nil
end

local function removeTable(tableId)
    local t = RouletteTables[tableId]
    if not t then return end
    deleteProp(t)
    if t.blip and DoesBlipExist(t.blip) then RemoveBlip(t.blip) end
    if t.zone then exports.ox_target:removeZone(t.zone) end
    if t.point then t.point:remove() end
    RouletteTables[tableId] = nil
end

local function addTable(data)
    if RouletteTables[data.id] then removeTable(data.id) end
    local t = { coords = data.coords, heading = data.heading, room = data.room or 0 }
    RouletteTables[data.id] = t

    if Config.Blip.Enabled then
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, t.coords.x, t.coords.y, t.coords.z) -- BlipAddForCoords
        SetBlipSprite(blip, joaat(Config.Blip.Sprite), true)
        SetBlipScale(blip, Config.Blip.Scale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, locale('blip_label')) -- SetBlipName
        t.blip = blip
    end

    t.zone = exports.ox_target:addSphereZone({
        coords = t.coords,
        radius = 1.5,
        options = {
            {
                name = 'rsg_roulette_' .. data.id,
                label = locale('play_roulette'),
                icon = 'fas fa-dice',
                distance = Config.InteractDistance,
                onSelect = function() OpenRoulette(data.id) end,
            },
        },
    })

    t.point = lib.points.new({
        coords = t.coords,
        distance = Config.SpawnDistance,
        onEnter = function() spawnProp(t) end,
        onExit = function() deleteProp(t) end,
    })
end

RegisterNetEvent('rsg-roulette:client:addTable', addTable)
RegisterNetEvent('rsg-roulette:client:removeTable', removeTable)

CreateThread(function()
    for _, data in ipairs(lib.callback.await('rsg-roulette:server:getTables', false) or {}) do
        addTable(data)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for tableId in pairs(RouletteTables) do removeTable(tableId) end
end)
