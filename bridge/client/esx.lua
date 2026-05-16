-- bridge/client/esx.lua
if Framework ~= 'esx' then return end

Bridge = {}

local ESX = exports['es_extended']:getSharedObject()
local playerData = {}
local playerLoaded = false
local onLoadedCallbacks = {}

Config.VehicleSource = 'custom' -- ESX has no shared vehicle table

local function fireCallbacks()
    for i = 1, #onLoadedCallbacks do
        CreateThread(function() onLoadedCallbacks[i]() end)
    end
end

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerData   = xPlayer
    playerLoaded = true
    fireCallbacks()
end)

-- Handle resource restart while player is already in-game.
-- FIXED: fireCallbacks() was missing — without it, Bridge.OnPlayerLoaded handlers
-- (including the shop-data loader in main.lua) never fired after a resource restart,
-- leaving shops/warehouse permanently empty for any player already logged in.
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if ESX.IsPlayerLoaded() then
        playerData   = ESX.GetPlayerData()
        playerLoaded = true
        fireCallbacks()
    end
end)

function Bridge.GetPlayerData()
    if not playerLoaded then
        playerData   = ESX.GetPlayerData()
        playerLoaded = ESX.IsPlayerLoaded()
    end
    return {
        identifier = playerData.identifier,
        citizenid  = playerData.identifier,
    }
end

function Bridge.OnPlayerLoaded(cb)
    if not playerLoaded and ESX.IsPlayerLoaded() then
        playerData   = ESX.GetPlayerData()
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
