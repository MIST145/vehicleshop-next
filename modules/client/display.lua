-- modules/client/display.lua (unchanged — placement logic is correct)
local function getInstructionalScaleform()
    local scaleform = RequestScaleformMovie('instructional_buttons')
    lib.requestScaleformMovie(scaleform)

    local controls = Config.Controls
    local buttons  = {
        { controls.xUp,     controls.xDown,    'xPos +/-' },
        { controls.yUp,     controls.yDown,    'yPos +/-' },
        { controls.zUp,     controls.zDown,    'zPos +/-' },
        { controls.rotLeft, controls.rotRight, 'Rotation +/-' },
        { controls.ground,  nil,               'Ground' },
        { controls.cancel,  nil,               'Cancel' },
        { controls.place,   nil,               'Place' },
    }

    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, 'SET_CLEAR_SPACE')
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    for i, btn in ipairs(buttons) do
        PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
        PushScaleformMovieFunctionParameterInt(i - 1)
        ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, btn[1], true))
        if btn[2] then
            ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, btn[2], true))
        end
        BeginTextCommandScaleformString('STRING')
        AddTextComponentScaleform(btn[3])
        EndTextCommandScaleformString()
        PopScaleformMovieFunctionVoid()
    end

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, 'SET_BACKGROUND_COLOUR')
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end

local function startVehiclePlacement(shopKey, vehicleIndex, vehData)
    local shops = VehShop.getShops()
    local shop  = shops[shopKey]
    if not shop then return end

    local props = vehData.vehicle
    local pos   = shop.locations.spawn

    Wait(300)
    lib.requestModel(props.model)
    local displayVeh = CreateVehicle(props.model, pos.x, pos.y, pos.z, pos.heading or 0.0, false, false)
    SetEntityCollision(displayVeh, true, true)
    while not DoesEntityExist(displayVeh) do Wait(0) end
    Bridge.SetVehicleProperties(displayVeh, props)
    Wait(300)

    local scaleform  = getInstructionalScaleform()
    local controls   = Config.Controls
    local targetPos  = vector4(pos.x, pos.y, pos.z, pos.heading or 0.0)

    SetEntityCoordsNoOffset(displayVeh, pos.x, pos.y, pos.z)
    SetVehicleUndriveable(displayVeh, true)
    FreezeEntityPosition(displayVeh, true)

    while true do
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)

        if IsControlJustPressed(0, controls.cancel) then
            SetEntityAsMissionEntity(displayVeh, true, true)
            DeleteVehicle(displayVeh)
            VehShop.openManagement(shopKey)
            return
        end

        if IsControlPressed(0, controls.place) then
            SetEntityAsMissionEntity(displayVeh, true, true)
            DeleteVehicle(displayVeh)
            TriggerServerEvent('vehicleshops:setDisplayed', shopKey, vehicleIndex, {
                x = targetPos.x, y = targetPos.y, z = targetPos.z, heading = targetPos.w,
            })
            VehShop.openManagement(shopKey)
            return
        end

        local right, forward, up = GetEntityMatrix(displayVeh)
        local didMove, didRot    = false, false
        local moveDiv, rotMod    = 25, 0.5

        if IsControlJustPressed(0, controls.ground) then
            SetVehicleOnGroundProperly(displayVeh)
            local c = GetEntityCoords(displayVeh)
            targetPos = vector4(c.x, c.y, c.z, GetEntityHeading(displayVeh))
        end

        if IsControlPressed(0, controls.zUp) then
            local t = targetPos.xyz + (up / 50)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.zDown) then
            local t = targetPos.xyz - (up / 50)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.xUp) then
            local t = targetPos.xyz + (forward / moveDiv)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.xDown) then
            local t = targetPos.xyz - (forward / moveDiv)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.yUp) then
            local t = targetPos.xyz + (right / moveDiv)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.yDown) then
            local t = targetPos.xyz - (right / moveDiv)
            targetPos = vector4(t.x, t.y, t.z, targetPos.w); didMove = true
        end
        if IsControlPressed(0, controls.rotRight) then
            targetPos = vector4(targetPos.x, targetPos.y, targetPos.z, targetPos.w - rotMod); didRot = true
        end
        if IsControlPressed(0, controls.rotLeft) then
            targetPos = vector4(targetPos.x, targetPos.y, targetPos.z, targetPos.w + rotMod); didRot = true
        end

        if didMove then
            FreezeEntityPosition(displayVeh, false)
            SetEntityRotation(displayVeh, 0.0, 0.0, targetPos.w, 2)
            SetEntityCoordsNoOffset(displayVeh, targetPos.xyz)
            FreezeEntityPosition(displayVeh, true)
        end
        if didRot then
            FreezeEntityPosition(displayVeh, false)
            SetEntityHeading(displayVeh, targetPos.w)
            FreezeEntityPosition(displayVeh, true)
        end

        Wait(0)
    end
end

VehShop.startPlacement = startVehiclePlacement