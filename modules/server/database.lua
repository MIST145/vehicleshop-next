-- modules/server/database.lua
local Database = {}

local function safeJsonDecode(str, fallback)
    if not str or str == '' then return fallback end
    local ok, result = pcall(json.decode, str)
    if not ok then return fallback end
    return result
end

-- FIXED: Removed DEFAULT values from TEXT columns for MariaDB compatibility.
function Database.EnsureTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vehicle_shops` (
            `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `owner`     VARCHAR(100) DEFAULT NULL,
            `name`      VARCHAR(50)  NOT NULL,
            `locations` LONGTEXT     NOT NULL,
            `employees` LONGTEXT     NOT NULL,
            `stock`     LONGTEXT     NOT NULL,
            `displays`  LONGTEXT     NOT NULL,
            `funds`     INT          NOT NULL DEFAULT 0,
            `price`     INT          NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

function Database.LoadShops()
    local rows = MySQL.query.await('SELECT * FROM `vehicle_shops`')
    if not rows then return {} end
    local shops = {}
    for i = 1, #rows do
        local row       = rows[i]
        local locations = safeJsonDecode(row.locations, nil)
        if locations then
            shops[row.name] = {
                owner     = (row.owner and row.owner ~= 'none' and row.owner) or nil,
                name      = row.name,
                locations = locations,
                employees = safeJsonDecode(row.employees, {}),
                stock     = safeJsonDecode(row.stock, {}),
                displays  = safeJsonDecode(row.displays, {}),
                funds     = row.funds or 0,
                price     = row.price or 0,
            }
        end
    end
    return shops
end

function Database.CreateShop(name, locations, price)
    MySQL.insert.await(
        'INSERT INTO `vehicle_shops` (`owner`, `name`, `locations`, `employees`, `stock`, `displays`, `funds`, `price`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { 'none', name, json.encode(locations), '[]', '[]', '{}', 0, math.max(1, tonumber(price) or 0) }
    )
end

function Database.UpdateShopOwner(name, owner)
    MySQL.update.await('UPDATE `vehicle_shops` SET `owner` = ? WHERE `name` = ?', { owner, name })
end

function Database.UpdateShopFunds(name, funds)
    MySQL.update.await('UPDATE `vehicle_shops` SET `funds` = ? WHERE `name` = ?', { funds, name })
end

function Database.UpdateShopStock(name, stock)
    MySQL.update.await('UPDATE `vehicle_shops` SET `stock` = ? WHERE `name` = ?', { json.encode(stock), name })
end

function Database.UpdateShopDisplays(name, displays)
    MySQL.update.await('UPDATE `vehicle_shops` SET `displays` = ? WHERE `name` = ?', { json.encode(displays), name })
end

function Database.UpdateShopStockAndDisplays(name, stock, displays)
    MySQL.update.await(
        'UPDATE `vehicle_shops` SET `stock` = ?, `displays` = ? WHERE `name` = ?',
        { json.encode(stock), json.encode(displays), name }
    )
end

function Database.UpdateShopEmployees(name, employees)
    MySQL.update.await('UPDATE `vehicle_shops` SET `employees` = ? WHERE `name` = ?', { json.encode(employees), name })
end

function Database.UpdateShopFundsAndDisplays(name, funds, displays)
    MySQL.update.await(
        'UPDATE `vehicle_shops` SET `funds` = ?, `displays` = ? WHERE `name` = ?',
        { funds, json.encode(displays), name }
    )
end

-- FIXED: Framework-aware table selection (ESX = owned_vehicles, QB/QBox = player_vehicles).
function Database.GetVehicleOwner(plate)
    if not plate or plate == '' then return nil end
    if Framework == 'esx' then
        local row = MySQL.single.await('SELECT `owner` FROM `owned_vehicles` WHERE `plate` = ?', { plate })
        return row and row.owner or nil
    else
        local row = MySQL.single.await('SELECT `citizenid` FROM `player_vehicles` WHERE `plate` = ?', { plate })
        return row and (row.citizenid or row.owner) or nil
    end
end

-- FIXED: Framework-aware delete (ESX = owned_vehicles, QB/QBox = player_vehicles).
function Database.DeleteVehicle(plate)
    if not plate or plate == '' then return end
    if Framework == 'esx' then
        MySQL.update.await('DELETE FROM `owned_vehicles` WHERE `plate` = ?', { plate })
    else
        MySQL.update.await('DELETE FROM `player_vehicles` WHERE `plate` = ?', { plate })
    end
end

-- FIXED: Framework-aware plate lookup for plate uniqueness validation.
function Database.GetAllPlates()
    local query = (Framework == 'esx')
        and 'SELECT `plate` FROM `owned_vehicles`'
        or  'SELECT `plate` FROM `player_vehicles`'
    local rows = MySQL.query.await(query)
    if not rows then return {} end
    local plates = {}
    for i = 1, #rows do
        plates[rows[i].plate] = true
    end
    return plates
end

return Database