-- modules/server/state.lua
local locks = {}

local State = {
    shops           = {},
    warehouseVehicles = {},
    shopVehicles    = {},
    ready           = false,
}

function State.acquireLock(key)
    while locks[key] do Wait(0) end
    locks[key] = true
end

function State.releaseLock(key)
    locks[key] = nil
end

function State.isOwnerOrEmployee(source, shopName)
    local shop = State.shops[shopName]
    if not shop then return false end
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return false end
    if shop.owner == identifier then return true end
    if not shop.employees then return false end
    for i = 1, #shop.employees do
        if shop.employees[i].identifier == identifier then return true end
    end
    return false
end

function State.isOwner(source, shopName)
    local shop = State.shops[shopName]
    if not shop then return false end
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return false end
    return shop.owner == identifier
end

-- Full sync: rebuilds all client points. Use for structural changes (shop create/purchase/hire/display).
function State.sync()
    TriggerClientEvent('vehicleshops:sync', -1, State.shops)
end

-- Partial sync: updates a single shop's data without full point rebuild.
-- Use for high-frequency operations (funds, stock, price, pay).
function State.syncShop(shopName)
    local shop = State.shops[shopName]
    if not shop then return end
    TriggerClientEvent('vehicleshops:syncShop', -1, shopName, shop)
end

local function isValidPos(pos)
    if type(pos) ~= 'table' then return false end
    if type(pos.x) ~= 'number' or type(pos.y) ~= 'number' or type(pos.z) ~= 'number' then return false end
    if pos.x ~= pos.x or pos.y ~= pos.y or pos.z ~= pos.z then return false end -- NaN check
    if math.abs(pos.x) > 10000 or math.abs(pos.y) > 10000 or math.abs(pos.z) > 2000 then return false end
    return true
end

State.isValidPos = isValidPos

local function isValidIndex(idx)
    return type(idx) == 'number' and idx >= 1 and idx == math.floor(idx)
end

State.isValidIndex = isValidIndex

return State