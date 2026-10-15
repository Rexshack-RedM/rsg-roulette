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
