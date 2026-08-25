RemoteDispatcher = RemoteDispatcher or {}
RemoteDispatcher.VERSION = "0.1.0.0"
RemoteDispatcher.isOpen = false
RemoteDispatcher.vehicles = {}
RemoteDispatcher.selectedIndex = 1
RemoteDispatcher.selectedProvider = nil
RemoteDispatcher.inputHookInstalled = false
local function info(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end
local function warn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end
local function call(object, methodName, ...)
    if object == nil or object[methodName] == nil then
        return false, nil
    end
    local args = {...}
    local ok, result = pcall(function()
        return object[methodName](object, unpack(args))
    end)
    if not ok then
        warn("%s failed: %s", tostring(methodName), tostring(result))
        return false, nil
    end
    return true, result
end
function RemoteDispatcher:notify(text, critical)
    info("%s", tostring(text))
    if g_currentMission == nil or g_currentMission.addIngameNotification == nil then
        return
    end
    local notificationType = FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_INFO or nil
    if critical and FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_CRITICAL ~= nil then
        notificationType = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
    end
    if notificationType ~= nil then
        g_currentMission:addIngameNotification(notificationType, tostring(text))
    end
end
function RemoteDispatcher:getLocalFarmId()
    if g_currentMission == nil then
        return nil
    end
    if g_currentMission.getFarmId ~= nil then
        local ok, farmId = pcall(function()
            return g_currentMission:getFarmId()
        end)
        if ok and farmId ~= nil then
            return farmId
        end
    end
    if g_currentMission.playerSystem ~= nil and g_currentMission.playerSystem.getLocalPlayer ~= nil then
        local player = g_currentMission.playerSystem:getLocalPlayer()
        if player ~= nil then
            return player.farmId
        end
    end
    return nil
end
function RemoteDispatcher:getVehicleName(vehicle)
    if vehicle == nil then
        return "Unknown vehicle"
    end
    local ok, name = call(vehicle, "getName")
    if ok and name ~= nil and name ~= "" then
        return tostring(name)
    end
    ok, name = call(vehicle, "getFullName")
    if ok and name ~= nil and name ~= "" then
        return tostring(name)
    end
    return tostring(vehicle.typeName or vehicle.configFileName or "Vehicle")
end
function RemoteDispatcher:isOwnedByLocalFarm(vehicle)
    local localFarmId = self:getLocalFarmId()
    if localFarmId == nil or vehicle == nil or vehicle.getOwnerFarmId == nil then
        return true
    end
    local ok, ownerFarmId = call(vehicle, "getOwnerFarmId")
    return not ok or ownerFarmId == nil or ownerFarmId == localFarmId
end
function RemoteDispatcher:hasAutoDrive(vehicle)
    return vehicle ~= nil
        and AutoDrive ~= nil
        and vehicle.ad ~= nil
        and vehicle.ad.stateModule ~= nil
        and vehicle.ad.stateModule.getCurrentMode ~= nil
end
function RemoteDispatcher:isAutoDriveActive(vehicle)
    if not self:hasAutoDrive(vehicle) then
        return false
    end
    local ok, active = call(vehicle.ad.stateModule, "isActive")
    return ok and active == true
end
function RemoteDispatcher:isAutoDriveReady(vehicle)
    if not self:hasAutoDrive(vehicle) or self:isAutoDriveActive(vehicle) then
        return false
    end
    local ok, mode = call(vehicle.ad.stateModule, "getCurrentMode")
    return ok and mode ~= nil and mode.start ~= nil
end
function RemoteDispatcher:getAutoDriveDetail(vehicle)
    if not self:hasAutoDrive(vehicle) then
        return nil
    end
    local state = vehicle.ad.stateModule
    if state.getFirstMarkerId == nil or ADGraphManager == nil or ADGraphManager.getMapMarkerById == nil then
        return nil
    end
    local ok, markerId = call(state, "getFirstMarkerId")
    if not ok or markerId == nil or markerId < 0 then
        return nil
    end
    local marker = ADGraphManager:getMapMarkerById(markerId)
    return marker ~= nil and marker.name or nil
end
function RemoteDispatcher:startAutoDrive(vehicle)
    if not self:isAutoDriveReady(vehicle) then
        return false, "AutoDrive is not ready"
    end
    local state = vehicle.ad.stateModule
    local destinationId = -1
    local unloadDestinationId = -1
    if state.getFirstMarkerId ~= nil then
        local ok, value = call(state, "getFirstMarkerId")
        if ok and value ~= nil then destinationId = value end
    end
    if state.getSecondMarkerId ~= nil then
        local ok, value = call(state, "getSecondMarkerId")
        if ok and value ~= nil then unloadDestinationId = value end
    end
    if AutoDrive.StartDriving ~= nil then
        local ok, err = pcall(function()
            AutoDrive:StartDriving(vehicle, destinationId, unloadDestinationId, nil, nil, nil)
        end)
        if not ok then
            return false, "AutoDrive start failed: " .. tostring(err)
        end
        return true, "AutoDrive started"
    end
    local ok, mode = call(state, "getCurrentMode")
    if not ok or mode == nil or mode.start == nil then
        return false, "AutoDrive start interface unavailable"
    end
    local modeOk, modeErr = pcall(function() mode:start() end)
    if not modeOk then
        return false, "AutoDrive start failed: " .. tostring(modeErr)
    end
    return true, "AutoDrive started"
end
function RemoteDispatcher:stopAutoDrive(vehicle)
    if not self:isAutoDriveActive(vehicle) then
        return false, "AutoDrive is not active"
    end
    if vehicle.stopAutoDrive == nil then
        return false, "AutoDrive stop interface unavailable"
    end
    local ok, err = pcall(function() vehicle:stopAutoDrive() end)
    if not ok then
        return false, "AutoDrive stop failed: " .. tostring(err)
    end
    return true, "AutoDrive stopped"
end
function RemoteDispatcher:hasCourseplay(vehicle)
    return vehicle ~= nil
        and vehicle.getIsCpActive ~= nil
        and (vehicle.cpStartStopDriver ~= nil
            or vehicle.startCpAtFirstWp ~= nil
            or vehicle.startCpAtLastWp ~= nil)
end
function RemoteDispatcher:isCourseplayActive(vehicle)
    if not self:hasCourseplay(vehicle) then
        return false
    end
    local ok, active = call(vehicle, "getIsCpActive")
    return ok and active == true
end
function RemoteDispatcher:isCourseplayReady(vehicle)
    if not self:hasCourseplay(vehicle) or self:isCourseplayActive(vehicle) then
        return false
    end
    if vehicle.getCpStartableJob ~= nil then
        local ok, job = call(vehicle, "getCpStartableJob", true)
        if ok and job == nil then
            return false
        end
    end
    if vehicle.getCanStartCp ~= nil then
        local ok, canStart = call(vehicle, "getCanStartCp")
        if ok then
            return canStart == true
        end
    end
    if vehicle.hasCpCourse ~= nil then
        local ok, hasCourse = call(vehicle, "hasCpCourse")
        if ok then
            return hasCourse == true
        end
    end
    return true
end
function RemoteDispatcher:getCourseplayDetail(vehicle)
    if not self:hasCourseplay(vehicle) or vehicle.getCurrentCpCourseName == nil then
        return nil
    end
    local ok, name = call(vehicle, "getCurrentCpCourseName")
    return ok and name ~= nil and name ~= "" and tostring(name) or nil
end
function RemoteDispatcher:startCourseplay(vehicle)
    if not self:isCourseplayReady(vehicle) then
        return false, "Courseplay is not ready"
    end
    if vehicle.cpStartStopDriver ~= nil then
        local ok, err = pcall(function() vehicle:cpStartStopDriver(true) end)
        if not ok then
            return false, "Courseplay start failed: " .. tostring(err)
        end
        return true, "Courseplay start requested"
    end
    local fallback = vehicle.startCpAtLastWp ~= nil and "startCpAtLastWp" or "startCpAtFirstWp"
    local ok, result = call(vehicle, fallback)
    if not ok or result == false then
        return false, "Courseplay rejected the start request"
    end
    return true, "Courseplay start requested"
end
function RemoteDispatcher:stopCourseplay(vehicle)
    if not self:isCourseplayActive(vehicle) then
        return false, "Courseplay is not active"
    end
    if AutoDrive ~= nil and AutoDrive.StopCP ~= nil then
        local ok, err = pcall(function() AutoDrive:StopCP(vehicle) end)
        if not ok then
            return false, "Courseplay stop failed: " .. tostring(err)
        end
        return true, "Courseplay stopped"
    end
    if vehicle.cpStartStopDriver ~= nil then
        local ok, err = pcall(function() vehicle:cpStartStopDriver() end)
        if not ok then
            return false, "Courseplay stop failed: " .. tostring(err)
        end
        return true, "Courseplay stopped"
    end
    return false, "Courseplay stop interface unavailable"
end
function RemoteDispatcher:getMissionVehicles()
    if g_currentMission == nil then
        return {}
    end
    if g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles ~= nil then
        return g_currentMission.vehicleSystem.vehicles
    end
    return g_currentMission.vehicles or {}
end
function RemoteDispatcher:isCompatibleVehicle(vehicle)
    if vehicle == nil or not self:isOwnedByLocalFarm(vehicle) then
        return false
    end
    if vehicle.getRootVehicle ~= nil then
        local ok, rootVehicle = call(vehicle, "getRootVehicle")
        if ok and rootVehicle ~= nil and rootVehicle ~= vehicle then
            return false
        end
    end
    return self:hasAutoDrive(vehicle) or self:hasCourseplay(vehicle)
end
function RemoteDispatcher:getSelectedVehicle()
    return #self.vehicles > 0 and self.vehicles[self.selectedIndex] or nil
end
function RemoteDispatcher:getProviders(vehicle)
    local providers = {}
    if self:hasAutoDrive(vehicle) then table.insert(providers, "AD") end
    if self:hasCourseplay(vehicle) then table.insert(providers, "CP") end
    return providers
end
function RemoteDispatcher:normalizeProvider()
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then
        self.selectedProvider = nil
        return
    end
    local providers = self:getProviders(vehicle)
    for _, provider in ipairs(providers) do
        if provider == self.selectedProvider then
            return
        end
    end
    if self:isAutoDriveActive(vehicle) then
        self.selectedProvider = "AD"
    elseif self:isCourseplayActive(vehicle) then
        self.selectedProvider = "CP"
    else
        self.selectedProvider = providers[1]
    end
end
function RemoteDispatcher:refreshVehicles()
    local previous = self:getSelectedVehicle()
    local list = {}
    for _, vehicle in pairs(self:getMissionVehicles()) do
        if self:isCompatibleVehicle(vehicle) then
            table.insert(list, vehicle)
        end
    end
    table.sort(list, function(a, b)
        return string.lower(self:getVehicleName(a)) < string.lower(self:getVehicleName(b))
    end)
    self.vehicles = list
    self.selectedIndex = math.min(math.max(self.selectedIndex or 1, 1), math.max(#list, 1))
    if previous ~= nil then
        for index, vehicle in ipairs(list) do
            if vehicle == previous then
                self.selectedIndex = index
                break
            end
        end
    end
    self:normalizeProvider()
end
function RemoteDispatcher:selectRelative(delta)
    if not self.isOpen then return end
    if #self.vehicles == 0 then self:refreshVehicles() return end
    self.selectedIndex = self.selectedIndex + delta
    if self.selectedIndex < 1 then self.selectedIndex = #self.vehicles end
    if self.selectedIndex > #self.vehicles then self.selectedIndex = 1 end
    self.selectedProvider = nil
    self:normalizeProvider()
end
function RemoteDispatcher:switchProvider()
    if not self.isOpen then return end
    local providers = self:getProviders(self:getSelectedVehicle())
    if #providers < 2 then
        self:normalizeProvider()
        return
    end
    self.selectedProvider = self.selectedProvider == providers[1] and providers[2] or providers[1]
end
function RemoteDispatcher:executeSelected()
    if self:getSelectedVehicle() == nil then
        self:refreshVehicles()
    end
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then
        self:notify("Remote Dispatcher: no compatible vehicle selected", true)
        return
    end
    self:normalizeProvider()
    local vehicleName = self:getVehicleName(vehicle)
    local success, message
    if self.selectedProvider == "AD" then
        if self:isAutoDriveActive(vehicle) then
            success, message = self:stopAutoDrive(vehicle)
        elseif self:isCourseplayActive(vehicle) then
            self:notify(vehicleName .. ": Courseplay is already active", true)
            return
        else
            success, message = self:startAutoDrive(vehicle)
        end
    elseif self.selectedProvider == "CP" then
        if self:isCourseplayActive(vehicle) then
            success, message = self:stopCourseplay(vehicle)
        elseif self:isAutoDriveActive(vehicle) then
            self:notify(vehicleName .. ": AutoDrive is already active", true)
            return
        else
            success, message = self:startCourseplay(vehicle)
        end
    else
        success, message = false, "No supported automation provider"
    end
    self:notify(vehicleName .. ": " .. tostring(message), not success)
end
function RemoteDispatcher:onToggleUI(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end
    self.isOpen = not self.isOpen
    if self.isOpen then self:refreshVehicles() end
end
function RemoteDispatcher:onPreviousVehicle(actionName, inputValue)
    if (inputValue or 0) > 0 then self:selectRelative(-1) end
end
function RemoteDispatcher:onNextVehicle(actionName, inputValue)
    if (inputValue or 0) > 0 then self:selectRelative(1) end
end
function RemoteDispatcher:onSwitchProvider(actionName, inputValue)
    if (inputValue or 0) > 0 then self:switchProvider() end
end
function RemoteDispatcher:onRemoteAction(actionName, inputValue)
    if (inputValue or 0) > 0 then self:executeSelected() end
end
function RemoteDispatcher:registerActionEvents()
    if g_inputBinding == nil then return end
    g_inputBinding:removeActionEventsByTarget(self)
    local function register(actionName, callback, textKey, visible)
        local actionId = InputAction ~= nil and InputAction[actionName] or nil
        if actionId == nil then
            warn("Input action %s is unavailable", tostring(actionName))
            return
        end
        local ok, eventId = g_inputBinding:registerActionEvent(actionId, self, callback, false, true, false, true)
        if ok and eventId ~= nil then
            if g_inputBinding.setActionEventText ~= nil then
                g_inputBinding:setActionEventText(eventId, g_i18n:getText(textKey))
            end
            if g_inputBinding.setActionEventTextVisibility ~= nil then
                g_inputBinding:setActionEventTextVisibility(eventId, visible == true)
            end
        end
    end
    register("RDC_TOGGLE_UI", self.onToggleUI, "input_RDC_TOGGLE_UI", true)
    register("RDC_PREVIOUS_VEHICLE", self.onPreviousVehicle, "input_RDC_PREVIOUS_VEHICLE", false)
    register("RDC_NEXT_VEHICLE", self.onNextVehicle, "input_RDC_NEXT_VEHICLE", false)
    register("RDC_SWITCH_PROVIDER", self.onSwitchProvider, "input_RDC_SWITCH_PROVIDER", false)
    register("RDC_REMOTE_ACTION", self.onRemoteAction, "input_RDC_REMOTE_ACTION", true)
end
function RemoteDispatcher.installInputHook()
    if RemoteDispatcher.inputHookInstalled
        or PlayerInputComponent == nil
        or PlayerInputComponent.registerActionEvents == nil then
        return
    end
    local original = PlayerInputComponent.registerActionEvents
    PlayerInputComponent.registerActionEvents = function(inputComponent, ...)
        original(inputComponent, ...)
        if inputComponent.player == nil or inputComponent.player.isOwner ~= true or g_inputBinding == nil then
            return
        end
        g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
        RemoteDispatcher:registerActionEvents()
        g_inputBinding:endActionEventsModification()
    end
    RemoteDispatcher.inputHookInstalled = true
end
function RemoteDispatcher:getStatus(vehicle, provider)
    if provider == "AD" then
        if self:isAutoDriveActive(vehicle) then return "ACTIVE" end
        if self:isAutoDriveReady(vehicle) then return "READY" end
        return "NOT READY"
    elseif provider == "CP" then
        if self:isCourseplayActive(vehicle) then return "ACTIVE" end
        if self:isCourseplayReady(vehicle) then return "READY" end
        return "NOT READY"
    end
    return "N/A"
end
function RemoteDispatcher:drawLine(x, y, size, text, selected)
    setTextAlignment(RenderText.ALIGN_LEFT)
    if selected then
        setTextColor(1.0, 0.82, 0.20, 1.0)
    else
        setTextColor(0.92, 0.92, 0.92, 1.0)
    end
    renderText(x, y, size, tostring(text))
end
function RemoteDispatcher:draw()
    if not self.isOpen then return end
    local x, y = 0.025, 0.78
    self:drawLine(x, y, 0.021, "REMOTE DISPATCHER", true)
    y = y - 0.032
    if #self.vehicles == 0 then
        self:drawLine(x, y, 0.015, "No owned AutoDrive/Courseplay-capable vehicles found.", false)
    else
        local maxRows = 10
        local first = math.max(1, self.selectedIndex - 4)
        local last = math.min(#self.vehicles, first + maxRows - 1)
        for index = first, last do
            local vehicle = self.vehicles[index]
            local providers = self:getProviders(vehicle)
            local selected = index == self.selectedIndex
            local provider = selected and self.selectedProvider or providers[1]
            local detail = provider == "AD" and self:getAutoDriveDetail(vehicle) or self:getCourseplayDetail(vehicle)
            local line = string.format("%s%s [%s] %s%s",
                selected and "> " or "  ",
                self:getVehicleName(vehicle),
                table.concat(providers, "/"),
                self:getStatus(vehicle, provider),
                detail ~= nil and (" - " .. tostring(detail)) or "")
            self:drawLine(x, y, selected and 0.015 or 0.014, line, selected)
            y = y - 0.024
        end
    end
    y = y - 0.010
    self:drawLine(x, y, 0.012, "PgUp/PgDn vehicle | Home AD/CP | Ctrl+Alt+R start/stop | Ctrl+Alt+D close", false)
    setTextColor(1, 1, 1, 1)
end
function RemoteDispatcher:loadMap(mapName)
    RemoteDispatcher.installInputHook()
    self:refreshVehicles()
    info("v%s loaded", self.VERSION)
end
function RemoteDispatcher:deleteMap()
    self.isOpen = false
    self.vehicles = {}
    self.selectedIndex = 1
    self.selectedProvider = nil
    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
end
function RemoteDispatcher:keyEvent(unicode, sym, modifier, isDown) end
function RemoteDispatcher:mouseEvent(posX, posY, isDown, isUp, button) end
function RemoteDispatcher:update(dt) end
RemoteDispatcher.installInputHook()
addModEventListener(RemoteDispatcher)
