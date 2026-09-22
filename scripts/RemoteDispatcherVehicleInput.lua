-- FS25_RemoteDispatcher v0.3.0.5
-- Register Remote Dispatcher live actions through the vehicle's own FS25
-- action-event lifecycle. This mirrors the proven HelperProfiles approach and
-- avoids global vehicle-context registration/removal races on specific vehicles.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Vehicle input layer loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.3.0.5"
RemoteDispatcher.vehicleInputHookInstalled = RemoteDispatcher.vehicleInputHookInstalled == true
RemoteDispatcher.vehicleInputMode = "vehicleAddActionEvent"
RemoteDispatcher._vehicleInputLogged = RemoteDispatcher._vehicleInputLogged or setmetatable({}, {__mode = "k"})

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function ensureVehicleSpec(vehicle)
    vehicle.spec_remoteDispatcherInput = vehicle.spec_remoteDispatcherInput or {}
    local spec = vehicle.spec_remoteDispatcherInput
    spec.actionEvents = spec.actionEvents or {}
    return spec
end

local function setEventPresentation(eventId, textKey, visible)
    if eventId == nil or g_inputBinding == nil then return end

    if g_inputBinding.setActionEventText ~= nil then
        local text = g_i18n ~= nil and g_i18n:getText(textKey) or textKey
        g_inputBinding:setActionEventText(eventId, text)
    end

    if g_inputBinding.setActionEventTextVisibility ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, visible == true)
    end
end

local function addVehicleAction(vehicle, spec, actionName, callback, textKey, visible)
    local actionId = InputAction ~= nil and InputAction[actionName] or nil
    if actionId == nil then
        rdWarn("Vehicle input action %s was not registered by modDesc.xml", tostring(actionName))
        return nil
    end

    local callOk, _, eventId = pcall(function()
        return vehicle:addActionEvent(
            spec.actionEvents,
            actionId,
            RemoteDispatcher,
            callback,
            false,
            true,
            false,
            true
        )
    end)

    if not callOk or eventId == nil then
        rdWarn(
            "Vehicle input action registration failed for '%s' action=%s",
            RemoteDispatcher:getVehicleName(vehicle),
            tostring(actionName)
        )
        return nil
    end

    setEventPresentation(eventId, textKey, visible)
    return eventId
end

function RemoteDispatcher:registerVehicleActionEvents(vehicle, isActiveForInput)
    if vehicle == nil or vehicle.addActionEvent == nil or not isActiveForInput then
        return
    end

    local spec = ensureVehicleSpec(vehicle)
    if vehicle.clearActionEventsTable ~= nil then
        pcall(function()
            vehicle:clearActionEventsTable(spec.actionEvents)
        end)
    else
        spec.actionEvents = {}
    end

    local registered = 0
    local function register(actionName, callback, textKey, visible)
        if addVehicleAction(vehicle, spec, actionName, callback, textKey, visible) ~= nil then
            registered = registered + 1
        end
    end

    register("RDC_TOGGLE_SELECTOR", self.onToggleSelector, "input_RDC_TOGGLE_SELECTOR", true)
    register("RDC_OPEN_MANAGEMENT", self.onOpenManagement, "input_RDC_OPEN_MANAGEMENT", true)
    register("RDC_CYCLE_TARGET", self.onCycleTarget, "input_RDC_CYCLE_TARGET", false)
    register("RDC_CYCLE_TARGET_PREVIOUS", self.onCycleTargetPrevious, "input_RDC_CYCLE_TARGET_PREVIOUS", false)
    register("RDC_REMOTE_ACTION", self.onRemoteAction, "input_RDC_REMOTE_ACTION", true)

    if not self._vehicleInputLogged[vehicle] then
        rdInfo(
            "Vehicle action events registered for '%s': count=%d activeForInput=%s",
            self:getVehicleName(vehicle),
            registered,
            tostring(isActiveForInput)
        )
        self._vehicleInputLogged[vehicle] = true
    end
end

function RemoteDispatcher:removeVehicleActionEvents(vehicle)
    if vehicle == nil then return end
    local spec = vehicle.spec_remoteDispatcherInput
    if spec == nil or spec.actionEvents == nil then return end

    if vehicle.clearActionEventsTable ~= nil then
        pcall(function()
            vehicle:clearActionEventsTable(spec.actionEvents)
        end)
    else
        spec.actionEvents = {}
    end
end

function RemoteDispatcher.installVehicleInputHook()
    if RemoteDispatcher.vehicleInputHookInstalled
        or Vehicle == nil
        or Vehicle.registerActionEvents == nil
        or Utils == nil
        or Utils.appendedFunction == nil then
        return
    end

    Vehicle.registerActionEvents = Utils.appendedFunction(
        Vehicle.registerActionEvents,
        function(vehicle, isActiveForInput, isActiveForGUI)
            RemoteDispatcher:registerVehicleActionEvents(vehicle, isActiveForInput == true)
        end
    )

    if Vehicle.removeActionEvents ~= nil then
        Vehicle.removeActionEvents = Utils.appendedFunction(
            Vehicle.removeActionEvents,
            function(vehicle)
                RemoteDispatcher:removeVehicleActionEvents(vehicle)
            end
        )
    end

    RemoteDispatcher.vehicleInputHookInstalled = true
    rdInfo("v%s vehicle action-event lifecycle hook installed", RemoteDispatcher.VERSION)
end

RemoteDispatcher.installVehicleInputHook()
