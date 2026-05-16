-- modules/client/main.lua
local Shops          = {}
local WarehouseVehicles = {}
local SpawnedVehicles   = {}
local shopBlips      = {}
local shopPoints     = {}
local displayPoints  = {}
local isSpawning     = {} -- FIXED: per-shop spawn guard to prevent double-spawning
local insideWarehouse = false

VehShop = {}

VehShop.getShops          = function() return Shops end
VehShop.setShops          = function(s) Shops = s end
VehShop.getWarehouseVehicles = function() return WarehouseVehicles end
VehShop.isInsideWarehouse = function() return insideWarehouse end
VehShop.setInsideWarehouse = function(v) insideWarehouse = v end

local function isOwnerOrEmployee(shopKey)
    local pd   = Bridge.GetPlayerData()
    local shop = Shops[shopKey]
    if not shop then return false end
    if shop.owner == pd.identifier or shop.owner == pd.citizenid then return true end
    if not shop.employees then return false end
    for i = 1, #shop.employees do
        local emp = shop.employees[i]
        if emp.identifier == pd.identifier or emp.identifier == pd.citizenid then
            return true
        end
    end
    return false
end

local function isOwner(shopKey)
    local pd   = Bridge.GetPlayerData()
    local shop = Shops[shopKey]
    if not shop then return false end
    return shop.owner == pd.identifier or shop.owner == pd.citizenid
end

VehShop.isOwnerOrEmployee = isOwnerOrEmployee
VehShop.isOwner           = isOwner

local function drawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetDrawOrigin(x, y, z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

VehShop.drawText3D = drawText3D

local function cleanupBlipsAndPoints()
    for _, blip in pairs(shopBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    shopBlips = {}
    for _, point in pairs(shopPoints) do point:remove() end
    shopPoints = {}
    for _, point in pairs(displayPoints) do point:remove() end
    displayPoints = {}
end

local function cleanupDisplayPoints()
    for _, point in pairs(displayPoints) do point:remove() end
    displayPoints = {}
end

-- FIXED: isSpawning guard prevents concurrent spawns for the same shop
local function spawnDisplayVehicles(shopKey)
    if isSpawning[shopKey] then return end
    isSpawning[shopKey] = true

    local shop = Shops[shopKey]
    if not shop or not shop.displays then
        isSpawning[shopKey] = false
        return
    end

    for plate, display in pairs(shop.displays) do
        if not SpawnedVehicles[plate] and display.location then
            local loc  = display.location
            local hash = type(display.vehicle.model) == 'number'
                         and display.vehicle.model
                         or GetHashKey(display.vehicle.model)

            lib.requestModel(hash)
            local veh = CreateVehicle(hash, loc.x, loc.y, loc.z, loc.heading or 0.0, false, false)
            FreezeEntityPosition(veh, true)
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleUndriveable(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetEntityProofs(veh, true, true, true, true, true, true, true, true)
            SetVehicleTyresCanBurst(veh, false)
            SetModelAsNoLongerNeeded(hash)
            Bridge.SetVehicleProperties(veh, display.vehicle)
            display.entity = veh
            SpawnedVehicles[plate] = veh

            if display.price then
                local vehLabel = GetLabelText(GetDisplayNameFromVehicleModel(hash))
                if vehLabel == 'NULL' then vehLabel = tostring(display.vehicle.model) end

                local _, max = GetModelDimensions(hash)
                local textZ  = max and max.z or 1.5

                local dp = lib.points.new({
                    coords        = vec3(loc.x, loc.y, loc.z),
                    distance      = 5.0,
                    _shopKey      = shopKey,
                    _plate        = plate,
                    _label        = vehLabel,
                    _price        = display.price,
                    _textZ        = textZ,
                })
                function dp:nearby()
                    drawText3D(
                        self.coords.x, self.coords.y, self.coords.z + self._textZ,
                        ('%s ~n~$~g~%d~s~~n~[~g~E~s~] Buy'):format(self._label, self._price)
                    )
                    if self.currentDistance < 3.0 and IsControlJustReleased(0, 38) then
                        local confirm = lib.alertDialog({
                            header  = 'Purchase Vehicle',
                            content = ('Buy **%s** for **$%d**?'):format(self._label, self._price),
                            centered = true,
                            cancel  = true,
                        })
                        if confirm == 'confirm' then
                            VehShop.purchaseDisplay(self._shopKey, self._plate, SpawnedVehicles[self._plate])
                        end
                    end
                end
                displayPoints[plate] = dp
            end
        end
    end

    isSpawning[shopKey] = false
end

local function despawnDisplayVehicles()
    cleanupDisplayPoints()
    for plate, veh in pairs(SpawnedVehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end
    SpawnedVehicles = {}
end

VehShop.spawnDisplayVehicles  = spawnDisplayVehicles
VehShop.despawnDisplayVehicles = despawnDisplayVehicles

local function setupShopPoints()
    cleanupBlipsAndPoints()

    local hasShop = false
    for k in pairs(Shops) do
        if isOwnerOrEmployee(k) then hasShop = true; break end
    end

    if hasShop then
        local whPos = Config.Warehouse.entry
        local blip  = AddBlipForCoord(whPos.x, whPos.y, whPos.z)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Vehicle Warehouse')
        EndTextCommandSetBlipName(blip)
        shopBlips[#shopBlips + 1] = blip

        local whPoint = lib.points.new({ coords = vec3(whPos.x, whPos.y, whPos.z), distance = 2.0 })
        function whPoint:onEnter() lib.showTextUI('[E] Enter Warehouse') end
        function whPoint:onExit()  lib.hideTextUI() end
        function whPoint:nearby()
            if self.currentDistance < 1.5 and IsControlJustReleased(0, 38) then
                lib.hideTextUI()
                VehShop.enterWarehouse()
            end
        end
        shopPoints[#shopPoints + 1] = whPoint
    end

    for shopKey, shop in pairs(Shops) do
        local loc = shop.locations
        if loc and loc.entry then
            local blip = AddBlipForCoord(loc.entry.x, loc.entry.y, loc.entry.z)
            SetBlipSprite(blip, 225)
            SetBlipColour(blip, shop.owner and 5 or 0)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('Vehicle Shop')
            EndTextCommandSetBlipName(blip)
            shopBlips[#shopBlips + 1] = blip

            SetAllVehicleGeneratorsActiveInArea(
                loc.entry.x - 50, loc.entry.y - 50, loc.entry.z - 50,
                loc.entry.x + 50, loc.entry.y + 50, loc.entry.z + 50,
                false, false
            )

            local zone = lib.zones.sphere({
                coords  = vec3(loc.entry.x, loc.entry.y, loc.entry.z),
                radius  = 100.0,
                onEnter = function() spawnDisplayVehicles(shopKey) end,
                onExit  = function()
                    cleanupDisplayPoints()
                    for plate, veh in pairs(SpawnedVehicles) do
                        if DoesEntityExist(veh) then
                            SetEntityAsMissionEntity(veh, true, true)
                            DeleteVehicle(veh)
                        end
                    end
                    SpawnedVehicles = {}
                    isSpawning[shopKey] = false
                end,
            })
            shopPoints[#shopPoints + 1] = zone

            if not shop.owner then
                local buyPt = lib.points.new({ coords = vec3(loc.entry.x, loc.entry.y, loc.entry.z), distance = 3.0 })
                function buyPt:onEnter() lib.showTextUI(('[E] Buy Shop - $%d'):format(shop.price)) end
                function buyPt:onExit()  lib.hideTextUI() end
                function buyPt:nearby()
                    if self.currentDistance < 2.0 and IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        local confirm = lib.alertDialog({
                            header   = 'Purchase Shop',
                            content  = ('Buy this vehicle shop for **$%d**?'):format(shop.price),
                            centered = true,
                            cancel   = true,
                        })
                        if confirm == 'confirm' then
                            local success = lib.callback.await('vehicleshops:purchaseShop', false, shopKey)
                            if success then
                                lib.notify({ description = 'Shop purchased!', type = 'success' })
                            else
                                lib.notify({ description = 'Cannot afford this shop.', type = 'error' })
                            end
                        end
                    end
                end
                shopPoints[#shopPoints + 1] = buyPt
            else
                if isOwnerOrEmployee(shopKey) then
                    if loc.management then
                        local mgmt = lib.points.new({ coords = vec3(loc.management.x, loc.management.y, loc.management.z), distance = 3.0 })
                        function mgmt:onEnter() lib.showTextUI('[E] Management') end
                        function mgmt:onExit()  lib.hideTextUI() end
                        function mgmt:nearby()
                            if self.currentDistance < 2.0 and IsControlJustReleased(0, 38) then
                                lib.hideTextUI()
                                VehShop.openManagement(shopKey)
                            end
                        end
                        shopPoints[#shopPoints + 1] = mgmt
                    end
                    if loc.deposit then
                        local dep = lib.points.new({ coords = vec3(loc.deposit.x, loc.deposit.y, loc.deposit.z), distance = 3.0 })
                        function dep:onEnter() lib.showTextUI('[E] Deposit Vehicle') end
                        function dep:onExit()  lib.hideTextUI() end
                        function dep:nearby()
                            if self.currentDistance < 2.0 and IsControlJustReleased(0, 38) then
                                lib.hideTextUI()
                                VehShop.depositVehicle(shopKey)
                            end
                        end
                        shopPoints[#shopPoints + 1] = dep
                    end
                end
            end
        end
    end
end

-- Full sync: structural change (shop create/purchase/hire/display placement)
RegisterNetEvent('vehicleshops:sync', function(data)
    despawnDisplayVehicles()
    Shops     = data
    isSpawning = {} -- reset all spawn guards
    setupShopPoints()
end)

-- Partial sync: data-only update (funds, stock, price, pay)
-- Display points update prices live without needing a full rebuild
RegisterNetEvent('vehicleshops:syncShop', function(shopName, shopData)
    Shops[shopName] = shopData
    -- Update display point prices live for players already in zone
    if shopData and shopData.displays then
        for plate, display in pairs(shopData.displays) do
            if displayPoints[plate] and display.price then
                displayPoints[plate]._price = display.price
            end
        end
    end
end)

RegisterNetEvent('vehicleshops:removeDisplay', function(shopName, plate, data)
    if SpawnedVehicles[plate] then
        if DoesEntityExist(SpawnedVehicles[plate]) then
            SetEntityAsMissionEntity(SpawnedVehicles[plate], true, true)
            DeleteVehicle(SpawnedVehicles[plate])
        end
        SpawnedVehicles[plate] = nil
    end
    if displayPoints[plate] then
        displayPoints[plate]:remove()
        displayPoints[plate] = nil
    end
    Shops     = data
    isSpawning = {}
    setupShopPoints()
end)

RegisterNetEvent('vehicleshops:warehouseRefresh', function(data)
    WarehouseVehicles = data
    if insideWarehouse then
        lib.notify({ description = 'Warehouse stock refreshed. Please re-enter.', type = 'info' })
        VehShop.leaveWarehouse()
    end
end)

RegisterNetEvent('vehicleshops:createNew', function()
    VehShop.createNewShop()
end)

Bridge.OnPlayerLoaded(function()
    local result = lib.callback.await('vehicleshops:getShopData', false)
    Shops             = result.shops or {}
    WarehouseVehicles = result.vehicles or {}
    setupShopPoints()
end)