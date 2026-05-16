-- modules/server/main.lua
local Database = require 'modules.server.database'
local State    = require 'modules.server.state'

local function generatePlate(existingPlates)
    for _ = 1, 100 do
        local plate = string.random('AAA 111')
        if not existingPlates[plate] then
            return plate
        end
    end
    return 'ERR 000'
end

-- FIXED: Fisher-Yates shuffle — O(n) vs previous O(n²) retry loop.
local function shuffleTable(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function refreshWarehouseVehicles()
    local grid = Config.Warehouse.grid
    if not grid or not grid.start then
        print('[vehicleshops] Error: missing Config.Warehouse.grid')
        return
    end
    if #State.warehouseVehicles == 0 then return end

    -- Generate all grid positions
    local positions = {}
    local gx = grid.start.x
    while gx <= grid.start.x + (grid.width * grid.spacingX) + 0.01 do
        local gy = grid.start.y
        while gy <= grid.start.y + (grid.length * grid.spacingY) + 0.01 do
            positions[#positions + 1] = vector4(gx, gy, grid.start.z, grid.heading)
            gy = gy + grid.spacingY
        end
        gx = gx + grid.spacingX
    end

    -- Shuffle vehicle pool for varied selection without expensive retry loops
    local pool = {}
    for _, v in ipairs(State.warehouseVehicles) do
        pool[#pool + 1] = v
    end
    shuffleTable(pool)

    State.shopVehicles = {}
    for i, pos in ipairs(positions) do
        local vehicle   = pool[((i - 1) % #pool) + 1]
        local variation = math.random(Config.Warehouse.randomPriceVariation)
        local price     = vehicle.price + math.floor(vehicle.price * (variation / 100))
        State.shopVehicles[#State.shopVehicles + 1] = {
            model = vehicle.model,
            name  = vehicle.name,
            brand = vehicle.brand,
            price = price,
            pos   = pos,
        }
    end

    TriggerClientEvent('vehicleshops:warehouseRefresh', -1, State.shopVehicles)
end

local function init()
    Database.EnsureTable()
    State.shops           = Database.LoadShops()
    State.warehouseVehicles = Bridge.GetSharedVehicles()

    if #State.warehouseVehicles == 0 then
        print('[vehicleshops] Warning: no shared vehicles found. Warehouse will be empty.')
    end

    State.ready = true
    local count = 0
    for _ in pairs(State.shops) do count = count + 1 end
    print(('[vehicleshops] Ready. Loaded %d shops, %d warehouse vehicles.'):format(count, #State.warehouseVehicles))

    if #State.warehouseVehicles > 0 then
        refreshWarehouseVehicles()
    end
end

local refreshMinutes = math.max(1, math.round(Config.RefreshTimer / 60000))

lib.cron.new(('*/%d * * * *'):format(refreshMinutes), function()
    if not State.ready then return end
    if #State.warehouseVehicles > 0 then
        refreshWarehouseVehicles()
    end
end)

lib.callback.register('vehicleshops:getShopData', function(source)
    while not State.ready do Wait(100) end
    return { shops = State.shops, vehicles = State.shopVehicles }
end)

lib.callback.register('vehicleshops:generatePlate', function(source)
    local plates = Database.GetAllPlates()
    return generatePlate(plates)
end)

CreateThread(init)

RegisterNetEvent('vehicleshops:create', function(name, locations, price)
    local src = source
    if not Bridge.IsAdmin(src) then return end
    if not name or type(name) ~= 'string' or #name < 2 or #name > 50 then return end
    if not locations or type(locations) ~= 'table' then return end
    if not locations.entry or not locations.management or not locations.spawn
        or not locations.purchased or not locations.deposit then return end

    price = tonumber(price)
    if not price or price < 1 then return end
    if State.shops[name] then return end

    Database.CreateShop(name, locations, price)
    State.shops[name] = {
        owner     = nil,
        name      = name,
        locations = locations,
        employees = {},
        stock     = {},
        displays  = {},
        funds     = 0,
        price     = math.max(1, price),
    }
    State.sync()
end)