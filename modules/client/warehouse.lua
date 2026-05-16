-- modules/client/warehouse.lua
local ShopEntities           = {}
local warehouseExitPoint     = nil
local warehouseVehiclePoints = {}

local function cleanupWarehousePoints()
    for _, point in pairs(warehouseVehiclePoints) do point:remove() end
    warehouseVehiclePoints = {}
end

local function despawnWarehouseVehicles()
    cleanupWarehousePoints()
    for _, v in pairs(ShopEntities) do
        if DoesEntityExist(v.ent) then
            SetEntityAsMissionEntity(v.ent, true, true)
            DeleteEntity(v.ent)
        end
    end
    ShopEntities = {}
end

local function spawnWarehouseVehicles()
    despawnWarehouseVehicles()
    local vehicles = VehShop.getWarehouseVehicles()

    -- FIXED: Wait(0) → Wait(100) — interior check doesn't need per-frame polling
    local startTime = GetGameTimer()
    while not IsInteriorReady(GetInteriorAtCoords(GetEntityCoords(cache.ped)))
          and GetGameTimer() - startTime < 5000 do
        Wait(100)
    end

    for i = 1, #vehicles do
        local v    = vehicles[i]
        local hash = GetHashKey(v.model)
        lib.requestModel(hash)

        if HasModelLoaded(hash) then
            local veh = CreateVehicle(hash, v.pos.x, v.pos.y, v.pos.z, v.pos.w, false, false)
            FreezeEntityPosition(veh, true)
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleUndriveable(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleEngineOn(veh, true, true, false)

            local entityData = {
                ent   = veh,
                pos   = v.pos,
                price = v.price,
                name  = v.name,
                brand = v.brand,
                model = v.model,
                key   = i,
            }
            ShopEntities[i] = entityData

            local _, max   = GetModelDimensions(hash)
            local textZ    = max and max.z or 1.5
            local label    = v.brand and (v.brand .. ' | ' .. v.name) or v.name

            local vehPoint = lib.points.new({
                coords      = vec3(v.pos.x, v.pos.y, v.pos.z),
                distance    = 5.0,
                _entityData = entityData,
                _label      = label,
                _textZ      = textZ,
            })
            function vehPoint:nearby()
                VehShop.drawText3D(
                    self.coords.x, self.coords.y, self.coords.z + self._textZ,
                    ('%s ~n~$~g~%d~s~~n~[~g~E~s~] Buy'):format(self._label, self._entityData.price)
                )
                if self.currentDistance < 3.0 and IsControlJustReleased(0, 38) then
                    purchaseStockVehicle(self._entityData)
                end
            end
            warehouseVehiclePoints[i] = vehPoint
        end
        SetModelAsNoLongerNeeded(hash)
    end
end

local function leaveWarehouse()
    local plyPed = cache.ped
    SetEntityCoordsNoOffset(plyPed, Config.Warehouse.entry.x, Config.Warehouse.entry.y, Config.Warehouse.entry.z)
    SetEntityHeading(plyPed, Config.Warehouse.entry.w)
    despawnWarehouseVehicles()
    VehShop.setInsideWarehouse(false)
    if warehouseExitPoint then
        warehouseExitPoint:remove()
        warehouseExitPoint = nil
    end
end

local function enterWarehouse()
    local plyPed = cache.ped
    lib.notify({ description = 'Loading warehouse...', type = 'info' })
    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoordsNoOffset(plyPed, Config.Warehouse.exit.x, Config.Warehouse.exit.y, Config.Warehouse.exit.z)
    SetEntityHeading(plyPed, Config.Warehouse.exit.w)
    spawnWarehouseVehicles()
    DoScreenFadeIn(500)
    VehShop.setInsideWarehouse(true)

    warehouseExitPoint = lib.points.new({
        coords   = vec3(Config.Warehouse.exit.x, Config.Warehouse.exit.y, Config.Warehouse.exit.z),
        distance = 3.0,
    })
    function warehouseExitPoint:onEnter() lib.showTextUI('[E] Leave Warehouse') end
    function warehouseExitPoint:onExit()  lib.hideTextUI() end
    function warehouseExitPoint:nearby()
        if self.currentDistance < 1.5 and IsControlJustReleased(0, 38) then
            lib.hideTextUI()
            leaveWarehouse()
        end
    end
end

local doPurchaseStock

function purchaseStockVehicle(vehicleData)
    local shops = VehShop.getShops()
    local pd    = Bridge.GetPlayerData()
    local options = {}

    for key, shop in pairs(shops) do
        local id = pd.identifier or pd.citizenid
        if shop.owner == id then
            options[#options + 1] = {
                title       = ('[$%d] %s'):format(shop.funds, shop.name),
                description = 'Owner',
                onSelect    = function() doPurchaseStock(vehicleData, key) end,
            }
        elseif shop.employees then
            for _, emp in ipairs(shop.employees) do
                if emp.identifier == id then
                    options[#options + 1] = {
                        title       = ('[$%d] %s'):format(shop.funds, shop.name),
                        description = 'Employee',
                        onSelect    = function() doPurchaseStock(vehicleData, key) end,
                    }
                    break
                end
            end
        end
    end

    if #options == 0 then
        lib.notify({ description = 'You don\'t own or work at any shop.', type = 'error' })
        return
    end

    lib.registerContext({ id = 'vehshop_select_shop', title = 'Select Shop', options = options })
    lib.showContext('vehshop_select_shop')
end

-- FIXED: No longer reads vehicle props from the warehouse entity.
-- Uses vehicleData.model directly — warehouse vehicles have no custom props.
-- This eliminates the stale-entity crash if a warehouse refresh occurs mid-purchase.
doPurchaseStock = function(vehicleData, shopKey)
    local shops = VehShop.getShops()
    local shop  = shops[shopKey]
    if not shop or shop.funds < vehicleData.price then
        lib.notify({ description = 'Insufficient shop funds.', type = 'error' })
        return
    end

    local success = lib.callback.await('vehicleshops:purchaseStock', false, shopKey, vehicleData.key)
    if not success then
        lib.notify({ description = 'Purchase failed.', type = 'error' })
        return
    end

    lib.notify({ description = ('Purchased %s for $%d'):format(vehicleData.name, vehicleData.price), type = 'success' })

    DoScreenFadeOut(500)
    Wait(500)

    local newPlate = lib.callback.await('vehicleshops:generatePlate', false)
    if not newPlate then
        DoScreenFadeIn(500)
        return
    end

    -- Spawn using model name only — safe even if warehouse entity was already despawned
    local model  = vehicleData.model
    local spawns = Config.Warehouse.purchasedSpawns
    local pos    = spawns[math.random(#spawns)]
    local plyPed = cache.ped

    lib.requestModel(model)
    local newVeh = CreateVehicle(model, pos.x, pos.y, pos.z, pos.w, true, true)
    SetEntityAsMissionEntity(newVeh, true, true)
    SetVehicleNumberPlateText(newVeh, newPlate) -- set authoritative plate for later deposit
    TaskWarpPedIntoVehicle(plyPed, newVeh, -1)
    Wait(200)
    SetVehicleOnGroundProperly(newVeh)
    SetModelAsNoLongerNeeded(model)
    DoScreenFadeIn(500)

    VehShop.setInsideWarehouse(false)
    despawnWarehouseVehicles()
    if warehouseExitPoint then
        warehouseExitPoint:remove()
        warehouseExitPoint = nil
    end
end

VehShop.enterWarehouse = enterWarehouse
VehShop.leaveWarehouse = leaveWarehouse