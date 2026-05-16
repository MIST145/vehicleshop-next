-- bridge/client/qbox.lua
if Framework ~= 'qbox' then return end

Bridge = {}

local playerLoaded = false
local onLoadedCallbacks = {}

Config.VehicleSource = 'framework'

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    for i = 1, #onLoadedCallbacks do
        CreateThread(function() onLoadedCallbacks[i]() end)
    end
end)

function Bridge.GetPlayerData()
    local pd = exports.qbx_core:GetPlayerData() or {}
    return {
        identifier = pd.citizenid,
        citizenid  = pd.citizenid,
    }
end

function Bridge.OnPlayerLoaded(cb)
    if not playerLoaded and LocalPlayer.state.isLoggedIn then
        playerLoaded = true
    end
    if playerLoaded then
        CreateThread(function() cb() end)
    end
    onLoadedCallbacks[#onLoadedCallbacks + 1] = cb
end

function Bridge.GetVehicleProperties(vehicle)
    return lib.getVehicleProperties(vehicle)
end

function Bridge.SetVehicleProperties(vehicle, props)
    lib.setVehicleProperties(vehicle, props)
end

function Bridge.GetClosestPlayer()
    local players = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 3.0, false)
    if not players or #players == 0 then return nil end
    return GetPlayerServerId(players[1].id)
end