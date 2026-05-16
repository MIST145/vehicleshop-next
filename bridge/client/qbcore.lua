-- bridge/client/qbcore.lua
if Framework ~= 'qbcore' then return end

Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()
local playerData = {}
local playerLoaded = false
local onLoadedCallbacks = {}

Config.VehicleSource = 'framework'

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData   = QBCore.Functions.GetPlayerData()
    playerLoaded = true
    for i = 1, #onLoadedCallbacks do
        CreateThread(function() onLoadedCallbacks[i]() end)
    end
end)

function Bridge.GetPlayerData()
    if not playerLoaded then
        playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.citizenid then
            playerLoaded = true
        end
    end
    return {
        identifier = playerData.citizenid,
        citizenid  = playerData.citizenid,
    }
end

function Bridge.OnPlayerLoaded(cb)
    if not playerLoaded then
        playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.citizenid then
            playerLoaded = true
        end
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