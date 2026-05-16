-- modules/server/purchase.lua
local Database = require 'modules.server.database'
local State    = require 'modules.server.state'

local MAX_PRICE    = 100000000
local MAX_FUNDS_OP = 10000000

-- Normalize plate: trim whitespace, uppercase. GTA pads plates with trailing spaces.
local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    return #plate > 0 and plate or nil
end

-- Customer purchases a shop (takes ownership)
lib.callback.register('vehicleshops:purchaseShop', function(source, shopName)
    if not shopName or type(shopName) ~= 'string' then return false end

    State.acquireLock('shop:' .. shopName)

    local shop = State.shops[shopName]
    if not shop or shop.owner then
        State.releaseLock('shop:' .. shopName)
        return false
    end

    local price = shop.price
    local cash  = Bridge.GetMoney(source, 'cash')
    local bank  = Bridge.GetMoney(source, 'bank')

    if cash >= price then
        Bridge.RemoveMoney(source, 'cash', price)
    elseif bank >= price then
        Bridge.RemoveMoney(source, 'bank', price)
    else
        State.releaseLock('shop:' .. shopName)
        return false
    end

    local identifier = Bridge.GetIdentifier(source)
    if not identifier then
        State.releaseLock('shop:' .. shopName)
        return false
    end

    shop.owner = identifier
    Database.UpdateShopOwner(shopName, identifier)
    State.sync() -- ownership change affects management point visibility for all clients
    State.releaseLock('shop:' .. shopName)
    return true
end)

-- Customer buys a displayed vehicle from a shop
lib.callback.register('vehicleshops:tryBuy', function(source, shopName, vehiclePlate)
    if not shopName or type(shopName) ~= 'string' then return false, 'Invalid request.' end

    vehiclePlate = normalizePlate(vehiclePlate)
    if not vehiclePlate then return false, 'Invalid plate.' end

    local lockKey = 'display:' .. vehiclePlate
    State.acquireLock(lockKey)

    local shop = State.shops[shopName]
    if not shop then
        State.releaseLock(lockKey)
        return false, 'Shop not found.'
    end

    local display = shop.displays[vehiclePlate]
    if not display or not display.price then
        State.releaseLock(lockKey)
        return false, 'Vehicle not for sale.'
    end

    local price = display.price
    local cash  = Bridge.GetMoney(source, 'cash')
    local bank  = Bridge.GetMoney(source, 'bank')

    if cash >= price then
        Bridge.RemoveMoney(source, 'cash', price)
    elseif bank >= price then
        Bridge.RemoveMoney(source, 'bank', price)
    else
        State.releaseLock(lockKey)
        return false, 'Insufficient funds.'
    end

    if not display.vehicle then
        State.releaseLock(lockKey)
        return false, 'Vehicle data missing.'
    end

    Bridge.RegisterVehicle(source, display.vehicle, display.vehicle.model)
    shop.funds = shop.funds + price
    shop.displays[vehiclePlate] = nil

    Database.UpdateShopFundsAndDisplays(shopName, shop.funds, shop.displays)
    -- Send full shops payload in removeDisplay event so clients update Shops table
    TriggerClientEvent('vehicleshops:removeDisplay', -1, shopName, vehiclePlate, State.shops)
    State.releaseLock(lockKey)
    return true
end)

-- Shop owner/employee buys a vehicle from the warehouse for their shop
lib.callback.register('vehicleshops:purchaseStock', function(source, shopName, vehicleIndex)
    if not shopName or type(shopName) ~= 'string' then return false end
    if not State.isOwnerOrEmployee(source, shopName) then return false end

    vehicleIndex = tonumber(vehicleIndex)
    if not State.isValidIndex(vehicleIndex) then return false end

    local lockKey = 'stock:' .. shopName
    State.acquireLock(lockKey)

    local shop = State.shops[shopName]
    if not shop then
        State.releaseLock(lockKey)
        return false
    end

    local stockVeh = State.shopVehicles[vehicleIndex]
    if not stockVeh then
        State.releaseLock(lockKey)
        return false
    end

    if shop.funds < stockVeh.price then
        State.releaseLock(lockKey)
        return false
    end

    shop.funds = shop.funds - stockVeh.price
    Database.UpdateShopFunds(shopName, shop.funds)
    State.syncShop(shopName)
    State.releaseLock(lockKey)
    return true
end)

-- Shop owner/employee drives a stocked vehicle out
lib.callback.register('vehicleshops:driveVehicle', function(source, shopName, vehicleIndex)
    if not shopName or type(shopName) ~= 'string' then return false end
    if not State.isOwnerOrEmployee(source, shopName) then return false end

    vehicleIndex = tonumber(vehicleIndex)
    if not State.isValidIndex(vehicleIndex) then return false end

    -- FIXED: Lock acquired BEFORE index read to eliminate race condition
    local lockKey = 'drive:' .. shopName .. ':' .. tostring(vehicleIndex)
    State.acquireLock(lockKey)

    local shop = State.shops[shopName]
    if not shop then
        State.releaseLock(lockKey)
        return false
    end

    local vehData = shop.stock[vehicleIndex]
    if not vehData or not vehData.vehicle then
        State.releaseLock(lockKey)
        return false
    end

    Bridge.RegisterVehicle(source, vehData.vehicle, vehData.vehicle.model)
    table.remove(shop.stock, vehicleIndex)
    Database.UpdateShopStock(shopName, shop.stock)
    State.syncShop(shopName)
    State.releaseLock(lockKey)
    return true
end)

-- FIXED: Converted to lib.callback for success/fail feedback.
-- FIXED: Uses NetworkId + server-side GetVehicleNumberPlateText instead of client-sent plate.
-- FIXED: Server-side proximity validation to deposit location.
lib.callback.register('vehicleshops:stockVehicle', function(source, netId, shopName, clientProps)
    if not shopName or type(shopName) ~= 'string' then return false end
    if not State.isOwnerOrEmployee(source, shopName) then return false end

    netId = tonumber(netId)
    if not netId or netId <= 0 then return false end

    local shop = State.shops[shopName]
    if not shop then return false end

    -- Server-side proximity check: player must be near the deposit point
    local depositLoc = shop.locations and shop.locations.deposit
    if not depositLoc then return false end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not playerCoords then return false end

    local dist = #(playerCoords - vector3(depositLoc.x, depositLoc.y, depositLoc.z))
    if dist > 15.0 then
        TriggerClientEvent('ox_lib:notify', source, { description = 'Too far from the deposit location.', type = 'error' })
        return false
    end

    -- Authoritative plate from server-side entity (not trusted from client)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local rawPlate = GetVehicleNumberPlateText(entity)
    local plate    = normalizePlate(rawPlate)
    if not plate or #plate > 12 then return false end

    -- Ownership check and delete-from-DB decision
    local owner    = Database.GetVehicleOwner(plate)
    local doDelete = false

    if owner and owner == shop.owner then
        doDelete = true
    elseif not owner then
        if not Config.StockStolenPedVehicles then
            TriggerClientEvent('ox_lib:notify', source, { description = 'Cannot store NPC vehicles.', type = 'error' })
            return false
        end
    else
        if not Config.StockStolenPlayerVehicles then
            TriggerClientEvent('ox_lib:notify', source, { description = 'Cannot store other players\' vehicles.', type = 'error' })
            return false
        end
        doDelete = true
    end

    if doDelete then
        Database.DeleteVehicle(plate)
    end

    -- Build vehicle data: DB props (authoritative) or sanitized client props for NPC vehicles
    local vehicleData = Bridge.GetVehiclePropsFromPlate(source, plate)
    if not vehicleData then
        local safeModel = (type(clientProps) == 'table' and type(clientProps.model) == 'string')
                          and clientProps.model or 'unknown'
        vehicleData = { plate = plate, model = safeModel }
    else
        vehicleData.plate = plate -- ensure server-authoritative plate
    end

    shop.stock[#shop.stock + 1] = { vehicle = vehicleData }
    Database.UpdateShopStock(shopName, shop.stock)
    State.syncShop(shopName)
    return true
end)

-- Add funds to shop
RegisterNetEvent('vehicleshops:addFunds', function(shopName, amount)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwnerOrEmployee(src, shopName) then return end

    amount = tonumber(amount)
    if not amount or amount ~= amount then return end -- NaN guard
    amount = math.clamp(math.floor(amount), 1, MAX_FUNDS_OP)

    local shop = State.shops[shopName]
    if not shop then return end

    local cash = Bridge.GetMoney(src, 'cash')
    local bank = Bridge.GetMoney(src, 'bank')

    if cash >= amount then
        Bridge.RemoveMoney(src, 'cash', amount)
    elseif bank >= amount then
        Bridge.RemoveMoney(src, 'bank', amount)
    else
        TriggerClientEvent('ox_lib:notify', src, { description = 'Insufficient funds.', type = 'error' })
        return
    end

    shop.funds = shop.funds + amount
    Database.UpdateShopFunds(shopName, shop.funds)
    State.syncShop(shopName)
    TriggerClientEvent('ox_lib:notify', src, { description = ('Added $%d to shop funds.'):format(amount), type = 'success' })
end)

-- Withdraw funds from shop (owner only)
RegisterNetEvent('vehicleshops:takeFunds', function(shopName, amount)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwner(src, shopName) then return end

    amount = tonumber(amount)
    if not amount or amount ~= amount then return end -- NaN guard
    amount = math.clamp(math.floor(amount), 1, MAX_FUNDS_OP)

    local lockKey = 'funds:' .. shopName
    State.acquireLock(lockKey)

    local shop = State.shops[shopName]
    if not shop or shop.funds < amount then
        State.releaseLock(lockKey)
        TriggerClientEvent('ox_lib:notify', src, { description = 'Insufficient shop funds.', type = 'error' })
        return
    end

    shop.funds = shop.funds - amount
    Bridge.AddMoney(src, 'bank', amount)
    Database.UpdateShopFunds(shopName, shop.funds)
    State.syncShop(shopName)
    State.releaseLock(lockKey)
    TriggerClientEvent('ox_lib:notify', src, { description = ('Withdrew $%d from shop funds.'):format(amount), type = 'success' })
end)

-- Place vehicle from stock to display
RegisterNetEvent('vehicleshops:setDisplayed', function(shopName, vehicleIndex, pos)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwnerOrEmployee(src, shopName) then return end
    if not State.isValidPos(pos) then return end

    vehicleIndex = tonumber(vehicleIndex)
    if not State.isValidIndex(vehicleIndex) then return end

    local shop = State.shops[shopName]
    if not shop or not shop.stock[vehicleIndex] then return end

    local vehData = lib.table.deepclone(shop.stock[vehicleIndex])
    vehData.location = {
        x       = math.round(pos.x, 2),
        y       = math.round(pos.y, 2),
        z       = math.round(pos.z, 2),
        heading = math.round(tonumber(pos.heading) or 0.0, 2),
    }
    if not vehData.vehicle or not vehData.vehicle.plate then return end

    shop.displays[vehData.vehicle.plate] = vehData
    table.remove(shop.stock, vehicleIndex)
    Database.UpdateShopStockAndDisplays(shopName, shop.stock, shop.displays)
    State.sync() -- display vehicle added: all clients need point rebuild
end)

-- Move vehicle from display back to stock
RegisterNetEvent('vehicleshops:removeDisplay', function(shopName, vehiclePlate)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwnerOrEmployee(src, shopName) then return end
    if not vehiclePlate or type(vehiclePlate) ~= 'string' then return end

    local shop = State.shops[shopName]
    if not shop or not shop.displays[vehiclePlate] then return end

    local vehData    = lib.table.deepclone(shop.displays[vehiclePlate])
    vehData.price    = nil
    vehData.location = nil
    shop.stock[#shop.stock + 1] = vehData
    shop.displays[vehiclePlate] = nil

    Database.UpdateShopStockAndDisplays(shopName, shop.stock, shop.displays)
    -- Sends State.shops payload to trigger client entity despawn + point rebuild
    TriggerClientEvent('vehicleshops:removeDisplay', -1, shopName, vehiclePlate, State.shops)
end)

-- Set price on a displayed vehicle
RegisterNetEvent('vehicleshops:setPrice', function(vehiclePlate, shopName, price)
    local src = source
    if not shopName or type(shopName) ~= 'string' then return end
    if not State.isOwnerOrEmployee(src, shopName) then return end

    vehiclePlate = normalizePlate(vehiclePlate)
    if not vehiclePlate then return end

    price = tonumber(price)
    if not price or price ~= price then return end -- NaN guard
    price = math.clamp(math.floor(price), 1, MAX_PRICE)

    local shop = State.shops[shopName]
    if not shop or not shop.displays[vehiclePlate] then return end

    shop.displays[vehiclePlate].price = price
    Database.UpdateShopDisplays(shopName, shop.displays)
    State.syncShop(shopName) -- partial sync: only price changed
end)