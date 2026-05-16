-- bridge/server/esx.lua
if Framework ~= 'esx' then return end

-- FIXED: ESX has no shared vehicle table; force 'custom' source server-side.
Config.VehicleSource = 'custom'

Bridge = {}

local ESX = exports['es_extended']:getSharedObject()

local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

function Bridge.GetIdentifier(source)
    local xPlayer = getPlayer(source)
    if not xPlayer then return nil end
    return xPlayer.identifier
end

function Bridge.GetPlayerName(source)
    local xPlayer = getPlayer(source)
    if not xPlayer then return nil end
    return {
        firstname = xPlayer.getName() or 'Unknown',
        lastname  = '',
    }
end

function Bridge.AddMoney(source, account, amount)
    local xPlayer = getPlayer(source)
    if not xPlayer then return false end
    if account == 'cash' then
        xPlayer.addMoney(amount)
    else
        xPlayer.addAccountMoney(account, amount)
    end
    return true
end

function Bridge.RemoveMoney(source, account, amount)
    local xPlayer = getPlayer(source)
    if not xPlayer then return false end
    if account == 'cash' then
        if xPlayer.getMoney() < amount then return false end
        xPlayer.removeMoney(amount)
    else
        local acc = xPlayer.getAccount(account)
        if not acc or acc.money < amount then return false end
        xPlayer.removeAccountMoney(account, amount)
    end
    return true
end

function Bridge.GetMoney(source, account)
    local xPlayer = getPlayer(source)
    if not xPlayer then return 0 end
    if account == 'cash' then
        return xPlayer.getMoney()
    end
    local acc = xPlayer.getAccount(account)
    return acc and acc.money or 0
end

function Bridge.OnPlayerLoaded(cb)
    AddEventHandler('esx:playerLoaded', function(playerId)
        cb(playerId)
    end)
end

function Bridge.OnPlayerDropped(cb)
    AddEventHandler('playerDropped', function()
        cb(source)
    end)
end

function Bridge.RegisterVehicle(source, props, model)
    local xPlayer = getPlayer(source)
    if not xPlayer or not props or not props.plate then return false end
    MySQL.insert.await(
        'INSERT INTO `owned_vehicles` (`owner`, `plate`, `vehicle`, `type`, `job`, `stored`) VALUES (?, ?, ?, ?, ?, ?)',
        { xPlayer.identifier, props.plate, json.encode(props), 'car', 'false', 1 }
    )
    return true
end

function Bridge.GetSharedVehicles()
    -- 'custom' source only for ESX
    if Customs and Customs.VehicleModels then
        local vehicles = {}
        for _, v in ipairs(Customs.VehicleModels) do
            vehicles[#vehicles + 1] = {
                name  = v.name,
                model = v.model,
                price = v.price or 0,
                brand = v.brand,
            }
        end
        return vehicles
    end
    print('[vehicleshops] ESX: no vehicle models found in customs.lua.')
    return {}
end

function Bridge.GetVehiclePropsFromPlate(source, plate)
    local row = MySQL.single.await('SELECT `vehicle` FROM `owned_vehicles` WHERE `plate` = ?', { plate })
    if not row or not row.vehicle then return nil end
    local ok, props = pcall(json.decode, row.vehicle)
    if not ok then return nil end
    return props
end

function Bridge.IsAdmin(source)
    local xPlayer = getPlayer(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    return group == 'admin' or group == 'superadmin'
end