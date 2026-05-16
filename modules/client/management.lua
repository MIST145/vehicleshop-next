-- modules/client/management.lua
local function getVehicleName(model)
    local hash  = type(model) == 'number' and model or GetHashKey(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    if label == 'NULL' then return tostring(model) end
    return label
end

local function openManagementMenu(shopKey)
    local options = {}
    options[#options + 1] = {
        title    = 'Vehicle Management',
        icon     = 'car',
        onSelect = function() VehShop.openVehicleMenu(shopKey) end,
    }
    if VehShop.isOwner(shopKey) then
        options[#options + 1] = {
            title    = 'Store Management',
            icon     = 'store',
            onSelect = function() VehShop.openShopFundsMenu(shopKey) end,
        }
        options[#options + 1] = {
            title    = 'Employee Management',
            icon     = 'users',
            onSelect = function() VehShop.openEmployeeMenu(shopKey) end,
        }
    end
    lib.registerContext({ id = 'vehshop_mgmt', title = 'Management', options = options })
    lib.showContext('vehshop_mgmt')
end

local function openVehicleMenu(shopKey)
    lib.registerContext({
        id      = 'vehshop_vehicles',
        title   = 'Vehicles',
        menu    = 'vehshop_mgmt',
        options = {
            { title = 'Display Vehicles',    icon = 'eye',   onSelect = function() VehShop.openDisplayMenu(shopKey) end },
            { title = 'Store Vehicles',      icon = 'box',   onSelect = function() VehShop.openStoredMenu(shopKey) end },
            { title = 'Set Vehicle Prices',  icon = 'tag',   onSelect = function() VehShop.openPriceMenu(shopKey) end },
            { title = 'Drive Stock Vehicle', icon = 'key',   onSelect = function() VehShop.openDriveMenu(shopKey) end },
        },
    })
    lib.showContext('vehshop_vehicles')
end

local function openDisplayMenu(shopKey)
    local shop    = VehShop.getShops()[shopKey]
    if not shop then return end
    local options = {}
    for i, vehData in ipairs(shop.stock) do
        if vehData and vehData.vehicle and vehData.vehicle.plate then
            local name = getVehicleName(vehData.vehicle.model)
            options[#options + 1] = {
                title    = ('[%s] %s'):format(vehData.vehicle.plate, name),
                icon     = 'car',
                onSelect = function() VehShop.startPlacement(shopKey, i, vehData) end,
            }
        end
    end
    if #options == 0 then options[#options + 1] = { title = 'No vehicles in stock.', disabled = true } end
    lib.registerContext({ id = 'vehshop_display', title = 'Display Vehicles', menu = 'vehshop_vehicles', options = options })
    lib.showContext('vehshop_display')
end

local function openStoredMenu(shopKey)
    local shop    = VehShop.getShops()[shopKey]
    if not shop then return end
    local options = {}
    for plate, display in pairs(shop.displays) do
        if display and display.vehicle then
            local name = getVehicleName(display.vehicle.model)
            options[#options + 1] = {
                title    = ('[%s] %s'):format(plate, name),
                icon     = 'box-archive',
                onSelect = function() TriggerServerEvent('vehicleshops:removeDisplay', shopKey, plate) end,
            }
        end
    end
    if #options == 0 then options[#options + 1] = { title = 'No vehicles on display.', disabled = true } end
    lib.registerContext({ id = 'vehshop_stored', title = 'Store Vehicles', menu = 'vehshop_vehicles', options = options })
    lib.showContext('vehshop_stored')
end

local function openPriceMenu(shopKey)
    local shop    = VehShop.getShops()[shopKey]
    if not shop then return end
    local options = {}
    for plate, display in pairs(shop.displays) do
        if display and display.vehicle then
            local name = getVehicleName(display.vehicle.model)
            options[#options + 1] = {
                title    = ('[%s] %s - $%s'):format(plate, name, display.price or 'No price'),
                icon     = 'dollar-sign',
                onSelect = function()
                    local input = lib.inputDialog('Set Price', {
                        { type = 'number', label = 'Price', icon = 'dollar-sign', required = true, min = 1 },
                    })
                    if input and input[1] then
                        TriggerServerEvent('vehicleshops:setPrice', plate, shopKey, input[1])
                    end
                end,
            }
        end
    end
    if #options == 0 then options[#options + 1] = { title = 'No vehicles on display.', disabled = true } end
    lib.registerContext({ id = 'vehshop_prices', title = 'Set Prices', menu = 'vehshop_vehicles', options = options })
    lib.showContext('vehshop_prices')
end

local function openDriveMenu(shopKey)
    local shop    = VehShop.getShops()[shopKey]
    if not shop then return end
    local options = {}
    for i, vehData in ipairs(shop.stock) do
        if vehData and vehData.vehicle and vehData.vehicle.plate then
            local name = getVehicleName(vehData.vehicle.model)
            options[#options + 1] = {
                title    = ('[%s] %s'):format(vehData.vehicle.plate, name),
                icon     = 'key',
                onSelect = function()
                    local success = lib.callback.await('vehicleshops:driveVehicle', false, shopKey, i)
                    if success then
                        local props = vehData.vehicle
                        local pos   = shop.locations.purchased
                        if not pos then
                            lib.notify({ description = 'No spawn location configured.', type = 'error' })
                            return
                        end
                        lib.requestModel(props.model)
                        local veh = CreateVehicle(props.model, pos.x, pos.y, pos.z, pos.heading or 0.0, true, true)
                        SetEntityAsMissionEntity(veh, true, true)
                        Bridge.SetVehicleProperties(veh, props)
                        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
                    else
                        lib.notify({ description = 'Could not drive vehicle out.', type = 'error' })
                    end
                end,
            }
        end
    end
    if #options == 0 then options[#options + 1] = { title = 'No vehicles in stock.', disabled = true } end
    lib.registerContext({ id = 'vehshop_drive', title = 'Drive Vehicle', menu = 'vehshop_vehicles', options = options })
    lib.showContext('vehshop_drive')
end

local function openShopFundsMenu(shopKey)
    local shop = VehShop.getShops()[shopKey]
    if not shop then return end
    lib.registerContext({
        id      = 'vehshop_funds',
        title   = ('Store Funds: $%d'):format(shop.funds),
        menu    = 'vehshop_mgmt',
        options = {
            {
                title    = 'Add Funds',
                icon     = 'plus',
                onSelect = function()
                    local input = lib.inputDialog('Add Funds', {
                        { type = 'number', label = 'Amount', icon = 'dollar-sign', required = true, min = 1 },
                    })
                    if input and input[1] then TriggerServerEvent('vehicleshops:addFunds', shopKey, input[1]) end
                end,
            },
            {
                title    = 'Take Funds',
                icon     = 'minus',
                onSelect = function()
                    local input = lib.inputDialog('Take Funds', {
                        { type = 'number', label = 'Amount', icon = 'dollar-sign', required = true, min = 1 },
                    })
                    if input and input[1] then TriggerServerEvent('vehicleshops:takeFunds', shopKey, input[1]) end
                end,
            },
        },
    })
    lib.showContext('vehshop_funds')
end

local function openEmployeeMenu(shopKey)
    lib.registerContext({
        id      = 'vehshop_employees',
        title   = 'Employees',
        menu    = 'vehshop_mgmt',
        options = {
            { title = 'Hire Employee', icon = 'user-plus',  onSelect = function() VehShop.hireEmployee(shopKey) end },
            { title = 'Fire Employee', icon = 'user-minus', onSelect = function() VehShop.fireEmployee(shopKey) end },
            { title = 'Pay Employee',  icon = 'money-bill', onSelect = function() VehShop.payEmployee(shopKey) end },
        },
    })
    lib.showContext('vehshop_employees')
end

local function hireEmployee(shopKey)
    local closest = Bridge.GetClosestPlayer()
    if not closest then
        lib.notify({ description = 'No players nearby.', type = 'error' })
        return
    end
    TriggerServerEvent('vehicleshops:hirePlayer', shopKey, closest)
end

local function fireEmployee(shopKey)
    local shop = VehShop.getShops()[shopKey]
    if not shop or not shop.employees or #shop.employees == 0 then
        lib.notify({ description = 'No employees to fire.', type = 'error' })
        return
    end
    local options = {}
    for _, emp in ipairs(shop.employees) do
        options[#options + 1] = {
            title    = ('%s %s'):format(emp.identity.firstname, emp.identity.lastname),
            icon     = 'user-minus',
            onSelect = function() TriggerServerEvent('vehicleshops:firePlayer', shopKey, emp.identifier) end,
        }
    end
    lib.registerContext({ id = 'vehshop_fire', title = 'Fire Employee', menu = 'vehshop_employees', options = options })
    lib.showContext('vehshop_fire')
end

local function payEmployee(shopKey)
    local shop = VehShop.getShops()[shopKey]
    if not shop or not shop.employees or #shop.employees == 0 then
        lib.notify({ description = 'No employees to pay.', type = 'error' })
        return
    end
    local options = {}
    for _, emp in ipairs(shop.employees) do
        options[#options + 1] = {
            title    = ('%s %s'):format(emp.identity.firstname, emp.identity.lastname),
            icon     = 'money-bill',
            onSelect = function()
                local input = lib.inputDialog('Pay Employee', {
                    { type = 'number', label = 'Amount', icon = 'dollar-sign', required = true, min = 1 },
                })
                if input and input[1] then
                    TriggerServerEvent('vehicleshops:payPlayer', shopKey, emp.identifier, input[1])
                end
            end,
        }
    end
    lib.registerContext({ id = 'vehshop_pay', title = 'Pay Employee', menu = 'vehshop_employees', options = options })
    lib.showContext('vehshop_pay')
end

-- FIXED: Converted to lib.callback (was TriggerServerEvent — no feedback possible).
-- FIXED: Sends NetworkId instead of client-trusted plate.
-- Visual cleanup only happens after server confirms success.
local function depositVehicle(shopKey)
    local plyPed = cache.ped
    if not IsPedInAnyVehicle(plyPed, false) then
        lib.notify({ description = 'You must be in a vehicle.', type = 'error' })
        return
    end

    local vehicle = GetVehiclePedIsUsing(plyPed)
    if GetPedInVehicleSeat(vehicle, -1) ~= plyPed then
        lib.notify({ description = 'You must be the driver.', type = 'error' })
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local props = Bridge.GetVehicleProperties(vehicle) -- fallback for NPC vehicles

    local success = lib.callback.await('vehicleshops:stockVehicle', false, netId, shopKey, props)
    if success then
        TaskLeaveVehicle(plyPed, vehicle, 0)
        Wait(1000)
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
        lib.notify({ description = 'Vehicle deposited into shop stock.', type = 'success' })
    else
        lib.notify({ description = 'Could not deposit vehicle.', type = 'error' })
    end
end

local function purchaseDisplayVehicle(shopKey, plate, vehicleEntity)
    local shops = VehShop.getShops()
    local shop  = shops[shopKey]
    if not shop or not shop.displays[plate] then return end
    if not vehicleEntity or not DoesEntityExist(vehicleEntity) then return end

    local props = Bridge.GetVehicleProperties(vehicleEntity)
    if not props then return end

    local success, msg = lib.callback.await('vehicleshops:tryBuy', false, shopKey, plate)
    if success then
        local pos = shop.locations.purchased
        if not pos then
            lib.notify({ description = 'No spawn location configured.', type = 'error' })
            return
        end
        lib.requestModel(props.model)
        local veh = CreateVehicle(props.model, pos.x, pos.y, pos.z, pos.heading or 0.0, true, true)
        SetEntityAsMissionEntity(veh, true, true)
        Bridge.SetVehicleProperties(veh, props)
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        SetVehicleEngineOn(veh, true, true, false)
        lib.notify({ description = 'Vehicle purchased!', type = 'success' })
    else
        lib.notify({ description = msg or 'Purchase failed.', type = 'error' })
    end
end

-- FIXED: Disables combat controls and provides clear step-by-step UX during shop creation.
local function createNewShop()
    local input = lib.inputDialog('Create Vehicle Shop', {
        { type = 'input',  label = 'Shop Name',  required = true, min = 2, max = 50 },
        { type = 'number', label = 'Shop Price', required = true, min = 1 },
    })
    if not input then return end

    local name  = input[1]
    local price = input[2]

    local locations = {}
    local steps = { 'entry', 'management', 'spawn', 'purchased', 'deposit' }
    local labels = {
        entry      = 'entry/buy location',
        management = 'management menu location',
        spawn      = 'vehicle spawn (inside)',
        purchased  = 'vehicle spawn (outside)',
        deposit    = 'vehicle deposit location',
    }

    local plyPed = cache.ped

    for _, step in ipairs(steps) do
        lib.notify({
            description = ('Walk to the **%s** and press [E].'):format(labels[step]),
            type        = 'info',
            duration    = 10000,
        })

        while true do
            -- Disable combat during setup to prevent accidents
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            Wait(0)
            if IsControlJustReleased(0, 38) then
                local pos     = GetEntityCoords(plyPed)
                local heading = GetEntityHeading(plyPed)
                locations[step] = { x = pos.x, y = pos.y, z = pos.z, heading = heading }
                break
            end
        end

        lib.notify({ description = ('Set: %s ✓'):format(labels[step]), type = 'success', duration = 2000 })
    end

    TriggerServerEvent('vehicleshops:create', name, locations, price)
    lib.notify({ description = ('Shop "%s" created for $%d.'):format(name, price), type = 'success' })
end

VehShop.openManagement   = openManagementMenu
VehShop.openVehicleMenu  = openVehicleMenu
VehShop.openDisplayMenu  = openDisplayMenu
VehShop.openStoredMenu   = openStoredMenu
VehShop.openPriceMenu    = openPriceMenu
VehShop.openDriveMenu    = openDriveMenu
VehShop.openShopFundsMenu = openShopFundsMenu
VehShop.openEmployeeMenu = openEmployeeMenu
VehShop.hireEmployee     = hireEmployee
VehShop.fireEmployee     = fireEmployee
VehShop.payEmployee      = payEmployee
VehShop.depositVehicle   = depositVehicle
VehShop.purchaseDisplay  = purchaseDisplayVehicle
VehShop.createNewShop    = createNewShop