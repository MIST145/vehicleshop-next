-- config.lua
Config = {}

Config.Debug = false

--[[
    Vehicle source for warehouse stock:
    'custom'    = use Customs.VehicleModels from customs.lua (ALL frameworks)
    'framework' = use QBCore.Shared.Vehicles (QBCore/QBox ONLY)

    ESX SERVERS: The ESX bridge forces 'custom' automatically.
    You do NOT need to change this for ESX.
--]]
Config.VehicleSource = 'framework'

Config.StockStolenPedVehicles    = true
Config.StockStolenPlayerVehicles = true

Config.RefreshTimer = 5 * 60 * 1000 -- ms

Config.Warehouse = {
    entry  = vector4(-281.71, -2656.73, 6.41, 46.00),
    exit   = vector4(-1243.92, -3023.24, -48.48, 90.00),

    grid = {
        start    = vector3(-1281.30, -3042.80, -48.48),
        heading  = 0.0,
        width    = 7,
        length   = 6,
        spacingX = 4.98,
        spacingY = 8.00,
    },

    randomPriceVariation = 10,

    purchasedSpawns = {
        vector4(-283.40, -2647.91, 6.0, 46.0),
        vector4(-286.43, -2649.76, 6.0, 46.0),
        vector4(-288.64, -2652.12, 6.0, 46.0),
        vector4(-290.94, -2654.26, 6.0, 46.0),
        vector4(-293.12, -2656.53, 6.0, 46.0),
    },
}

Config.Controls = {
    zUp      = 314,
    zDown    = 315,
    xUp      = 125,
    xDown    = 124,
    yUp      = 127,
    yDown    = 126,
    rotLeft  = 117,
    rotRight = 118,
    ground   = 113,
    cancel   = 101,
    place    = 305,
}