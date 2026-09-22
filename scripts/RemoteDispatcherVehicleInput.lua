-- FS25_RemoteDispatcher 0.3.0.4-alpha.5 vehicle-input diagnostic
-- Observes the existing Alpha 5 vehicle input registration path without
-- changing its register/skip decision.
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

local DIAG_VERSION = "0.3.0.4-alpha.5-inputdiag1"
local _diagStateByVehicle = setmetatable({}, {__mode = "k"})

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function safeGetRootVehicle(vehicle)
    if vehicle == nil then return nil, "nil" end

    local rootVehicle = vehicle.rootVehicle
    if vehicle.getRootVehicle ~= nil then
        local ok, value = pcall(vehicle.getRootVehicle, vehicle)
        if ok and value ~= nil then
            rootVehicle = value
        elseif not ok then
            return rootVehicle, "error:" .. tostring(value)
        end
    end
    return rootVehicle, "ok"
end

local function safeGetActiveForInput(vehicle)
    if vehicle == nil or vehicle.getIsActiveForInput == nil then
        return nil, "unavailable"
    end

    local ok, active = pcall(vehicle.getIsActiveForInput, vehicle)
    if not ok then
        return nil, "error:" .. tostring(active)
    end
    return active == true, tostring(active)
end

local function vehicleName(vehicle)
    if vehicle == nil then return "nil" end
    if vehicle.getName ~= nil then
        local ok, name = pcall(vehicle.getName, vehicle)
        if ok and name ~= nil and name ~= "" then
            return tostring(name)
        end
    end
    return tostring(vehicle.typeName or "vehicle")
end

local function vehiclePath(vehicle)
    if vehicle == nil then return "nil" end
    return tostring(vehicle.configFileName or vehicle.configFile or "unknown")
end

local function vehicleId(vehicle)
    if vehicle == nil then return "nil" end
    return tostring(vehicle)
end

local function inspectRegistrationState(vehicle, callbackActive, callbackGui)
    local rootVehicle, rootStatus = safeGetRootVehicle(vehicle)
    local reportedActive, reportedRaw = safeGetActiveForInput(vehicle)

    local controlled = g_currentMission ~= nil and g_currentMission.controlledVehicle or nil
    local controlledRoot, controlledRootStatus = safeGetRootVehicle(controlled)

    local isRoot = rootVehicle == nil or rootVehicle == vehicle
    local controlledIsVehicle = controlled == vehicle
    local controlledRootIsVehicle = controlledRoot == vehicle
    local controlledRootMatchesRoot = controlledRoot ~= nil and rootVehicle ~= nil and controlledRoot == rootVehicle

    local legacyDecision = false
    local legacyReason = "no-match"

    if vehicle == nil then
        legacyReason = "vehicle-nil"
    elseif not isRoot then
        legacyReason = "not-root"
    elseif vehicle.getIsActiveForInput ~= nil then
        if reportedRaw:sub(1, 6) == "error:" then
            if controlledIsVehicle or controlledRootIsVehicle then
                legacyDecision = true
                legacyReason = "getIsActiveForInput-error->controlled-fallback"
            else
                legacyReason = "getIsActiveForInput-error->no-controlled-match"
            end
        else
            legacyDecision = reportedActive == true
            legacyReason = legacyDecision
                and "getIsActiveForInput=true"
                or "getIsActiveForInput=false->early-return"
        end
    elseif controlledIsVehicle or controlledRootIsVehicle then
        legacyDecision = true
        legacyReason = "controlled-fallback"
    else
        legacyReason = "no-active-method-and-no-controlled-match"
    end

    local bindingAvailable = g_inputBinding ~= nil
    local contextAvailable = Vehicle ~= nil and Vehicle.INPUT_CONTEXT_NAME ~= nil
    local finalDecision = bindingAvailable and contextAvailable and legacyDecision

    return {
        callbackActive = callbackActive,
        callbackGui = callbackGui,
        rootVehicle = rootVehicle,
        rootStatus = rootStatus,
        reportedActive = reportedActive,
        reportedRaw = reportedRaw,
        controlled = controlled,
        controlledRoot = controlledRoot,
        controlledRootStatus = controlledRootStatus,
        isRoot = isRoot,
        controlledIsVehicle = controlledIsVehicle,
        controlledRootIsVehicle = controlledRootIsVehicle,
        controlledRootMatchesRoot = controlledRootMatchesRoot,
        bindingAvailable = bindingAvailable,
        contextAvailable = contextAvailable,
        legacyDecision = legacyDecision,
        legacyReason = legacyReason,
        finalDecision = finalDecision
    }
end

local function logDiagnosticState(vehicle, state)
    if vehicle == nil or state == nil then return end

    local signature = table.concat({
        tostring(state.callbackActive),
        tostring(state.callbackGui),
        tostring(state.isRoot),
        tostring(state.reportedActive),
        tostring(state.reportedRaw),
        tostring(state.controlledIsVehicle),
        tostring(state.controlledRootIsVehicle),
        tostring(state.controlledRootMatchesRoot),
        tostring(state.bindingAvailable),
        tostring(state.contextAvailable),
        tostring(state.finalDecision),
        tostring(state.legacyReason),
        vehicleId(state.controlled),
        vehicleId(state.controlledRoot)
    }, "|")

    if _diagStateByVehicle[vehicle] == signature then return end
    _diagStateByVehicle[vehicle] = signature

    rdInfo(
        "[VehicleInputDiag] vehicle='%s' ref=%s config='%s' callbackInput=%s callbackGUI=%s " ..
        "root=%s rootRef=%s rootStatus=%s reportedActive=%s reportedRaw=%s " ..
        "controlled='%s' controlledRef=%s controlledConfig='%s' controlledRoot='%s' " ..
        "controlledRootRef=%s controlledRootStatus=%s controlledIsVehicle=%s " ..
        "controlledRootIsVehicle=%s controlledRootMatchesRoot=%s inputBinding=%s context=%s " ..
        "decision=%s reason=%s",
        vehicleName(vehicle),
        vehicleId(vehicle),
        vehiclePath(vehicle),
        tostring(state.callbackActive),
        tostring(state.callbackGui),
        tostring(state.isRoot),
        vehicleId(state.rootVehicle),
        tostring(state.rootStatus),
        tostring(state.reportedActive),
        tostring(state.reportedRaw),
        vehicleName(state.controlled),
        vehicleId(state.controlled),
        vehiclePath(state.controlled),
        vehicleName(state.controlledRoot),
        vehicleId(state.controlledRoot),
        tostring(state.controlledRootStatus),
        tostring(state.controlledIsVehicle),
        tostring(state.controlledRootIsVehicle),
        tostring(state.controlledRootMatchesRoot),
        tostring(state.bindingAvailable),
        tostring(state.contextAvailable),
        state.finalDecision and "REGISTER" or "SKIP",
        tostring(state.legacyReason)
    )
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

    Vehicle.registerActionEvents = function(vehicle, isActiveForInput, isActiveForGUI, ...)
        originalRegisterActionEvents(vehicle, isActiveForInput, isActiveForGUI, ...)

        local diagState = inspectRegistrationState(vehicle, isActiveForInput, isActiveForGUI)
        logDiagnosticState(vehicle, diagState)

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
        else
            local eventCount = RemoteDispatcher.actionEventIds ~= nil and #RemoteDispatcher.actionEventIds or -1
            rdInfo(
                "[VehicleInputDiag] REGISTERED actions vehicle='%s' ref=%s config='%s' eventCount=%d",
                vehicleName(vehicle),
                vehicleId(vehicle),
                vehiclePath(vehicle),
                eventCount
            )
        end
    end

    RemoteDispatcher.vehicleInputHookInstalled = true
    rdInfo("v%s vehicle input context hook installed", RemoteDispatcher.VERSION)
    rdInfo("[VehicleInputDiag] diagnostic=%s observation-only=true", DIAG_VERSION)
end

RemoteDispatcher.installVehicleInputHook()
