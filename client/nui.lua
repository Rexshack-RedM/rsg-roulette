RSGCore = exports['rsg-core']:GetCoreObject()

local localeCache
--- flat locale table for the NUI (rsg:locale convar -> ox:locale -> en, en used as fallback)
function GetLocaleTable()
    if localeCache then return localeCache end
    local function load(lang)
        local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
        return raw and json.decode(raw) or {}
    end
    local lang = GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))
    localeCache = load('en')
    if lang ~= 'en' then
        for k, v in pairs(load(lang)) do localeCache[k] = v end
    end
    return localeCache
end

NUI = {}

local isOpen = false

---@param action string
---@param data? table
function NUI.Send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

---@param data? table
function NUI.Open(data)
    isOpen = true
    SetNuiFocus(true, true)
    NUI.Send('open', data)
end

function NUI.Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    NUI.Send('close')
end

function NUI.IsOpen()
    return isOpen
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
