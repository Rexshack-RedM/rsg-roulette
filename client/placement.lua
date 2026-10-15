local TABLE_MODEL = joaat('p_roulettetable01x')

-- RedM frontend controls (arrow keys / enter / backspace)
local KEY_UP     = 0x6319DB71
local KEY_DOWN   = 0x05CA7C52
local KEY_LEFT   = 0xA65EBAB4
local KEY_RIGHT  = 0xDEB34313
local KEY_ENTER  = 0xC7B5340A
local KEY_CANCEL = 0x156F7119
local KEYS = { KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_CANCEL }

local placing = false
local ghost

--- used by the roulette UI so it can't be opened mid placement
function IsPlacingTable() return placing end

local function nearestTableDistance(coords)
    local best
    for _, t in pairs(RouletteTables) do
        local d = #(coords - t.coords)
        if not best or d < best then best = d end
    end
    return best
end

--- where the camera (mouse) is pointing, ignoring the player
local function aimPoint(ped, range)
    local camPos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local dest = camPos + dir * (range + #(camPos - GetEntityCoords(ped)))

    local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 1 | 16, ped, 7)
    local _, hit, endCoords = GetShapeTestResult(ray)
    return hit == 1, endCoords
end

local function startPlacement()
    if placing or NUI.IsOpen() then return end
    if not lib.requestModel(TABLE_MODEL, 10000) then return end
    Wait(250) -- let the chat box close and release the Enter key

    local cfg = Config.Placement
    local ped = cache.ped
    local heading = GetEntityHeading(ped)
    local height = 0.0

    ghost = CreateObject(TABLE_MODEL, GetEntityCoords(ped), false, false, false)
    SetModelAsNoLongerNeeded(TABLE_MODEL)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    placing = true
    local lastSent = {}
    -- the Enter used to send the chat command is still "just pressed" on the first frames,
    -- so ignore confirm/cancel until both keys have been released
    local armed = false
    local room, lastRoom = 0, 0
    local coords = GetEntityCoords(ped)

    while placing do
        Wait(0)

        for _, key in ipairs(KEYS) do DisableControlAction(0, key, true) end

        if IsDisabledControlPressed(0, KEY_LEFT) then heading = (heading + cfg.RotateStep) % 360.0 end
        if IsDisabledControlPressed(0, KEY_RIGHT) then heading = (heading - cfg.RotateStep) % 360.0 end
        if IsDisabledControlPressed(0, KEY_UP) then height = math.min(height + cfg.HeightStep, cfg.MaxHeight) end
        if IsDisabledControlPressed(0, KEY_DOWN) then height = math.max(height - cfg.HeightStep, -cfg.MaxHeight) end

        -- follow the mouse / camera aim
        local hit, hitCoords = aimPoint(ped, cfg.MaxDistance)
        local status = 'ok'
        if hit then
            coords = vector3(hitCoords.x, hitCoords.y, hitCoords.z + height)
            if #(GetEntityCoords(ped) - coords) > cfg.MaxDistance then
                status = 'too_far'
            else
                local nearest = nearestTableDistance(coords)
                if nearest and nearest < cfg.MinSpacing then status = 'too_close' end
            end
        else
            status = 'no_ground'
        end

        SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, status == 'ok' and 200 or 90, false)

        -- keep the preview in the same interior room as the admin, otherwise it is culled indoors
        local interior = GetInteriorFromEntity(ped)
        room = interior ~= 0 and GetRoomKeyFromEntity(ped) or 0
        if room ~= lastRoom then
            if room ~= 0 then
                ForceRoomForEntity(ghost, interior, room)
            else
                ClearRoomForEntity(ghost)
            end
            lastRoom = room
        end

        local hud = {
            visible = true,
            heading = math.floor(heading + 0.5) % 360,
            height = math.floor(height * 100 + 0.5) / 100,
            status = status,
        }
        if not lastSent.status then hud.locale = lib.getLocales() end
        if hud.heading ~= lastSent.heading or hud.height ~= lastSent.height or hud.status ~= lastSent.status then
            NUI.Send('placement', hud)
            lastSent = hud
        end

        if not armed then
            armed = not IsDisabledControlPressed(0, KEY_ENTER) and not IsDisabledControlPressed(0, KEY_CANCEL)
        elseif IsDisabledControlJustPressed(0, KEY_ENTER) then
            if status == 'ok' then
                TriggerServerEvent('rsg-roulette:server:placeTable', coords, heading, room)
                placing = false
            else
                lib.notify({ title = locale('ui_title'), description = locale('placement_invalid'), type = 'error', duration = 3000 })
            end
        end

        if armed and IsDisabledControlJustPressed(0, KEY_CANCEL) or IsEntityDead(ped) then
            lib.notify({ title = locale('ui_title'), description = locale('placement_cancelled'), type = 'inform', duration = 3000 })
            placing = false
        end
    end

    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil
    NUI.Send('placement', { visible = false })
end

RegisterNetEvent('rsg-roulette:client:startPlacement', function()
    CreateThread(startPlacement)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    placing = false
    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
end)
