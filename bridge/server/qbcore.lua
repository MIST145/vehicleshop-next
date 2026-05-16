-- bridge/server/qbcore.lua
if Framework ~= 'qbcore' then return end

Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()

local function getPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

function Bridge.GetIdentifier(source)
    local player = getPlayer(source)
    if not player then return nil end
    return player.PlayerData.citizenid
end

function Bridge.GetPlayerName(source)
    local player = getPlayer(source)
    if not player then return nil end
    return {
        firstname = player.PlayerData.charinfo and player.PlayerData.charinfo.firstname or 'Unknown',
        lastname  = player.PlayerData.charinfo and player.PlayerData.charinfo.lastname or '',
    }
end

function Bridge.AddMoney(source, account, amount)
    local player = getPlayer(source)
    if not player then return false end
    return player.Functions.AddMoney(account, amount)
end

function Bridge.RemoveMoney(source, account, amount)
    local player = getPlayer(source)
    if not player then return false end
    return player.Functions.RemoveMoney(account, amount)
end

function Bridge.GetMoney(source, account)
    local player = getPlayer(source)
    if not player then return 0 end
    return player.Functions.GetMoney(account)
end

function Bridge.OnPlayerLoaded(cb)
    RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player)
        cb(player.PlayerData.source)
    end)
end

function Bridge.OnPlayerDropped(cb)
    AddEventHandler('playerDropped', function()
        cb(source)
    end)
end

function Bridge.RegisterVehicle(source, props, model)
    local player = getPlayer(source)
    if not player or not props or not props.plate then return false end
    local citizenid    = player.PlayerData.citizenid
    local vehicleModel = type(model) == 'string' and model or tostring(model)
    local vehicleHash  = type(props.model) == 'number' and props.model or GetHashKey(props.model)
    MySQL.insert.await(
        'INSERT INTO `player_vehicles` (`citizenid`, `vehicle`, `hash`, `plate`, `mods`, `state`, `garage`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, vehicleModel, vehicleHash, props.plate, json.encode(props), 0, 'pillboxgarage' }
    )
    return true
end

function Bridge.GetSharedVehicles()
    if Config.VehicleSource == 'custom' and Customs and Customs.VehicleModels then
        local vehicles = {}
        for _, v in ipairs(Customs.VehicleModels) do
            vehicles[#vehicles + 1] = { name = v.name, model = v.model, price = v.price or 0, brand = v.brand }
        end
        return vehicles
    end
    local vehicles = {}
    for _, v in pairs(QBCore.Shared.Vehicles or {}) do
        vehicles[#vehicles + 1] = { name = v.name, model = v.model, price = v.price or 0, brand = v.brand }
    end
    return vehicles
end

function Bridge.GetVehiclePropsFromPlate(source, plate)
    local row = MySQL.single.await('SELECT `mods` FROM `player_vehicles` WHERE `plate` = ?', { plate })
    if not row or not row.mods then return nil end
    local ok, props = pcall(json.decode, row.mods)
    if not ok then return nil end
    return props
end

function Bridge.IsAdmin(source)
    return QBCore.Functions.HasPermission(source, 'admin')
end