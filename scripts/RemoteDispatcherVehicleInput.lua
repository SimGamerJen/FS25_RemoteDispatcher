-- FS25_RemoteDispatcher v0.3.0.1
-- Register Remote Dispatcher live actions in the FS25 vehicle input context.
--
-- The original dispatcher input hook is attached to PlayerInputComponent and
-- therefore only exists while the local player is on foot. FS25 switches to
-- Vehicle.INPUT_CONTEXT_NAME while the player is controlling a vehicle, so we
-- mirror the same Remote Dispatcher action registration into the active root
-- vehicle's action-event pass.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Vehicle input layer loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.3.0.1"
RemoteDispatcher.vehicleInputHookInstalled = RemoteDispatcher.vehicleInputHookInstalled == true

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function isActiveRootVehicle(vehicle)
    if vehicle == nil then return false end

    local rootVehicle = vehicle.rootVehicle
    if vehicle.getRootVehicle ~= nil then
        local ok, value = pcall(vehicle.getRootVehicle, vehicle)
        if ok and value ~= nil then rootVehicle = value end
    end
    if rootVehicle ~= nil and rootVehicle ~= vehicle then return false end

    if vehicle.getIsActiveForInput ~= nil then
        local ok, active = pcall(vehicle.getIsActiveForInput, vehicle)
        if ok then return active == true end
    end

    if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
        local controlled = g_currentMission.controlledVehicle
        if controlled == vehicle then return true end
        if controlled.getRootVehicle ~= nil then
            local ok, controlledRoot = pcall(controlled.getRootVehicle, controlled)
            if ok and controlledRoot == vehicle then return true end
        end
    end

    return false
end

function RemoteDispatcher.installVehicleInputHook()
    if RemoteDispatcher.vehicleInputHookInstalled
        or Vehicle == nil
        or Vehicle.registerActionEvents == nil then
        return
    end

    local originalRegisterActionEvents = Vehicle.registerActionEvents

    Vehicle.registerActionEvents = function(vehicle, ...)
        originalRegisterActionEvents(vehicle, ...)

        if g_inputBinding == nil
            or Vehicle.INPUT_CONTEXT_NAME == nil
            or not isActiveRootVehicle(vehicle) then
            return
        end

        -- Match the normal vehicle action-event lifecycle. registerActionEvents()
        -- may be called repeatedly by FS25 as vehicle state changes, so the
        -- dispatcher registration routine first removes its previous events and
        -- then recreates them in the currently active vehicle context.
        local modificationOpen = false
        local ok, err = pcall(function()
            g_inputBinding:beginActionEventsModification(Vehicle.INPUT_CONTEXT_NAME)
            modificationOpen = true
            RemoteDispatcher:registerActionEvents()
            g_inputBinding:endActionEventsModification()
            modificationOpen = false
        end)

        if modificationOpen then
            pcall(function() g_inputBinding:endActionEventsModification() end)
        end
        if not ok then
            rdWarn("Vehicle input action registration failed: %s", tostring(err))
        end
    end

    RemoteDispatcher.vehicleInputHookInstalled = true
    rdInfo("v%s vehicle input context hook installed", RemoteDispatcher.VERSION)
end

RemoteDispatcher.installVehicleInputHook()
