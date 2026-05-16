-- bridge/detect.lua
Framework = nil

local function detectFramework()
    if GetResourceState('qbx_core') == 'started' or GetResourceState('ox_core') == 'started' then
        return 'qbox'
    end
    if GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    end
    if GetResourceState('es_extended') == 'started' then
        return 'esx'
    end
    return nil
end

Framework = detectFramework()

if not Framework then
    error('[vehicleshops] No supported framework detected. Resource will not start.')
end