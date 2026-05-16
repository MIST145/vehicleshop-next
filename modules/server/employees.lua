-- modules/server/employees.lua
local Database = require 'modules.server.database'
local State    = require 'modules.server.state'

RegisterNetEvent('vehicleshops:hirePlayer', function(shopName, targetServerId)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwner(src, shopName) then return end

    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId <= 0 then return end

    local shop = State.shops[shopName]
    if not shop then return end

    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    if not targetIdentifier then return end

    local nameData = Bridge.GetPlayerName(targetServerId)
    if not nameData then return end

    for i = 1, #shop.employees do
        if shop.employees[i].identifier == targetIdentifier then
            TriggerClientEvent('ox_lib:notify', src, { description = 'Player is already an employee.', type = 'error' })
            return
        end
    end

    shop.employees[#shop.employees + 1] = { identifier = targetIdentifier, identity = nameData }
    Database.UpdateShopEmployees(shopName, shop.employees)
    State.sync() -- hire affects management/warehouse point visibility for new employee
    TriggerClientEvent('ox_lib:notify', src, {
        description = ('Hired %s %s.'):format(nameData.firstname, nameData.lastname),
        type = 'success',
    })
end)

RegisterNetEvent('vehicleshops:firePlayer', function(shopName, targetIdentifier)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwner(src, shopName) then return end
    if not targetIdentifier or type(targetIdentifier) ~= 'string' then return end

    local shop = State.shops[shopName]
    if not shop then return end

    for i = #shop.employees, 1, -1 do
        if shop.employees[i].identifier == targetIdentifier then
            table.remove(shop.employees, i)
            break
        end
    end
    Database.UpdateShopEmployees(shopName, shop.employees)
    State.sync() -- fire affects point visibility for removed employee
end)

RegisterNetEvent('vehicleshops:payPlayer', function(shopName, targetIdentifier, amount)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwner(src, shopName) then return end
    if not targetIdentifier or type(targetIdentifier) ~= 'string' then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local shop = State.shops[shopName]
    if not shop then return end

    if shop.funds < amount then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Insufficient shop funds.', type = 'error' })
        return
    end

    local targetSrc
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if Bridge.GetIdentifier(pid) == targetIdentifier then
            targetSrc = pid
            break
        end
    end

    if not targetSrc then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Employee is not online.', type = 'error' })
        return
    end

    Bridge.AddMoney(targetSrc, 'bank', amount)
    shop.funds = shop.funds - amount
    Database.UpdateShopFunds(shopName, shop.funds)
    State.syncShop(shopName) -- partial sync: only funds changed

    local nameData = Bridge.GetPlayerName(targetSrc)
    if nameData then
        TriggerClientEvent('ox_lib:notify', src, {
            description = ('Paid %s %s $%d.'):format(nameData.firstname, nameData.lastname, amount),
            type = 'success',
        })
    end
end)