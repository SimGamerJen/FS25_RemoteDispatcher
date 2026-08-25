-- FS25_RemoteDispatcher v0.1.0.2
-- Discovery, target-selection and input usability hotfix.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] v0.1.0.2 hotfix loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.1.0.2"
RemoteDispatcher.selectionInitialized = RemoteDispatcher.selectionInitialized or false

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function rdCall(object, methodName, ...)
    if object == nil or object[methodName] == nil then
        return false, nil
    end

    local args = {...}
    local ok, result = pcall(function()
        return object[methodName](object, unpack(args))
    end)

    if not ok then
        rdWarn("%s failed: %s", tostring(methodName), tostring(result))
        return false, nil
    end

    return true, result
end

function RemoteDispatcher:getLocalFarmId()
    if g_currentMission == nil then
        return nil
    end

    if g_currentMission.playerSystem ~= nil
        and g_currentMission.playerSystem.getLocalPlayer ~= nil then
        local ok, player = pcall(function()
            return g_currentMission.playerSystem:getLocalPlayer()
        end)
        if ok and player ~= nil and player.farmId ~= nil then
            return player.farmId
        end
    end

    if g_currentMission.getFarmId ~= nil then
        local ok, farmId = pcall(function()
            return g_currentMission:getFarmId()
        end)
        if ok and farmId ~= nil then
            return farmId
        end
    end

    return nil
end

function RemoteDispatcher:hasAutoDrive(vehicle)
    return vehicle ~= nil
        and vehicle.ad ~= nil
        and vehicle.ad.stateModule ~= nil
        and vehicle.ad.stateModule.getCurrentMode ~= nil
end

function RemoteDispatcher:getAutoDriveDestinationText(vehicle)
    if not self:hasAutoDrive(vehicle) then
        return nil
    end

    local state = vehicle.ad.stateModule
    if state.getFirstMarkerName ~= nil then
        local ok, markerName = rdCall(state, "getFirstMarkerName")
        if ok and markerName ~= nil and markerName ~= "" then
            return tostring(markerName)
        end
    end

    if state.getFirstMarkerId == nil
        or ADGraphManager == nil
        or ADGraphManager.getMapMarkerById == nil then
        return nil
    end

    local ok, markerId = rdCall(state, "getFirstMarkerId")
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
        local ok, value = rdCall(state, "getFirstMarkerId")
        if ok and value ~= nil then destinationId = value end
    end

    if state.getSecondMarkerId ~= nil then
        local ok, value = rdCall(state, "getSecondMarkerId")
        if ok and value ~= nil then unloadDestinationId = value end
    end

    rdInfo(
        "AD start request '%s': destination=%s secondDestination=%s activeBefore=%s",
        self:getVehicleName(vehicle),
        tostring(destinationId),
        tostring(unloadDestinationId),
        tostring(self:isAutoDriveActive(vehicle))
    )

    if AutoDrive ~= nil and AutoDrive.StartDriving ~= nil then
        local ok, err = pcall(function()
            AutoDrive:StartDriving(vehicle, destinationId, unloadDestinationId, nil, nil, nil)
        end)
        if not ok then
            return false, "AutoDrive start failed: " .. tostring(err)
        end
    else
        local ok, mode = rdCall(state, "getCurrentMode")
        if not ok or mode == nil or mode.start == nil then
            return false, "AutoDrive start interface unavailable"
        end

        local modeOk, modeErr = pcall(function()
            mode:start()
        end)
        if not modeOk then
            return false, "AutoDrive start failed: " .. tostring(modeErr)
        end
    end

    local helperIndex = "n/a"
    if state.getCurrentHelperIndex ~= nil then
        local ok, value = rdCall(state, "getCurrentHelperIndex")
        if ok then helperIndex = tostring(value) end
    end

    rdInfo(
        "AD start returned '%s': activeAfter=%s helperIndex=%s",
        self:getVehicleName(vehicle),
        tostring(self:isAutoDriveActive(vehicle)),
        helperIndex
    )

    return true, "AutoDrive start requested"
end

function RemoteDispatcher:refreshVehicles()
    local previous = self:getSelectedVehicle()
    local list = {}
    local localFarmId = self:getLocalFarmId()
    local stats = {
        total = 0,
        roots = 0,
        owned = 0,
        rawAd = 0,
        adState = 0,
        adCapable = 0,
        cpCapable = 0,
        accepted = 0
    }

    for _, vehicle in pairs(self:getMissionVehicles()) do
        stats.total = stats.total + 1

        local isRoot = true
        if vehicle ~= nil and vehicle.getRootVehicle ~= nil then
            local ok, rootVehicle = rdCall(vehicle, "getRootVehicle")
            if ok and rootVehicle ~= nil and rootVehicle ~= vehicle then
                isRoot = false
            end
        end

        if isRoot then
            stats.roots = stats.roots + 1
            local owned = self:isOwnedByLocalFarm(vehicle)
            local rawAd = vehicle ~= nil and vehicle.ad ~= nil
            local adState = rawAd and vehicle.ad.stateModule ~= nil
            local adCapable = self:hasAutoDrive(vehicle)
            local cpCapable = self:hasCourseplay(vehicle)

            if owned then stats.owned = stats.owned + 1 end
            if rawAd then stats.rawAd = stats.rawAd + 1 end
            if adState then stats.adState = stats.adState + 1 end
            if adCapable then stats.adCapable = stats.adCapable + 1 end
            if cpCapable then stats.cpCapable = stats.cpCapable + 1 end

            if owned and (adCapable or cpCapable) then
                table.insert(list, vehicle)
                stats.accepted = stats.accepted + 1
            end
        end
    end

    rdInfo(
        "Discovery census: mission=%d roots=%d owned=%d rawAD=%d adState=%d AD=%d CP=%d accepted=%d localFarm=%s AutoDriveGlobal=%s",
        stats.total,
        stats.roots,
        stats.owned,
        stats.rawAd,
        stats.adState,
        stats.adCapable,
        stats.cpCapable,
        stats.accepted,
        tostring(localFarmId),
        tostring(AutoDrive ~= nil)
    )

    table.sort(list, function(a, b)
        return string.lower(self:getVehicleName(a)) < string.lower(self:getVehicleName(b))
    end)

    self.vehicles = list
    self.selectedIndex = math.min(
        math.max(self.selectedIndex or 1, 1),
        math.max(#list, 1)
    )

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

function RemoteDispatcher:getPlayerWorldPosition()
    if g_currentMission == nil or getWorldTranslation == nil then
        return nil, nil, nil
    end

    local player = nil
    if g_currentMission.playerSystem ~= nil
        and g_currentMission.playerSystem.getLocalPlayer ~= nil then
        local ok, result = pcall(function()
            return g_currentMission.playerSystem:getLocalPlayer()
        end)
        if ok then player = result end
    end

    player = player or g_currentMission.player
    if player == nil then return nil, nil, nil end

    local node = player.rootNode or player.node
    if node == nil or node == 0 then return nil, nil, nil end

    return getWorldTranslation(node)
end

function RemoteDispatcher:getVehicleWorldPosition(vehicle)
    if vehicle == nil or getWorldTranslation == nil then
        return nil, nil, nil
    end

    local node = vehicle.rootNode
    if (node == nil or node == 0)
        and vehicle.components ~= nil
        and vehicle.components[1] ~= nil then
        node = vehicle.components[1].node
    end

    if node == nil or node == 0 then return nil, nil, nil end
    return getWorldTranslation(node)
end

function RemoteDispatcher:getVehicleDistance(vehicle)
    local px, _, pz = self:getPlayerWorldPosition()
    local vx, _, vz = self:getVehicleWorldPosition(vehicle)
    if px == nil or pz == nil or vx == nil or vz == nil then
        return nil
    end

    local dx = vx - px
    local dz = vz - pz
    return math.sqrt(dx * dx + dz * dz)
end

function RemoteDispatcher:selectNearestVehicle()
    if self.vehicles == nil or #self.vehicles == 0 then
        return false
    end

    local bestIndex = nil
    local bestDistance = math.huge
    for index, vehicle in ipairs(self.vehicles) do
        local distance = self:getVehicleDistance(vehicle)
        if distance ~= nil and distance < bestDistance then
            bestIndex = index
            bestDistance = distance
        end
    end

    if bestIndex == nil then
        return false
    end

    self.selectedIndex = bestIndex
    self.selectedProvider = nil
    self:normalizeProvider()

    rdInfo(
        "Initial target selected by proximity: '%s' distance=%.1fm",
        self:getVehicleName(self.vehicles[bestIndex]),
        bestDistance
    )

    return true
end

local originalSelectRelative = RemoteDispatcher.selectRelative
function RemoteDispatcher:selectRelative(delta)
    self.selectionInitialized = true
    return originalSelectRelative(self, delta)
end

function RemoteDispatcher:onToggleUI(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end

    self.isOpen = not self.isOpen
    if self.isOpen then
        self:refreshVehicles()
        if not self.selectionInitialized then
            self:selectNearestVehicle()
            self.selectionInitialized = true
        end
    end
end

function RemoteDispatcher:onRemoteAction(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end
    self.selectionInitialized = true
    self:executeSelected()
end

function RemoteDispatcher:onConfirm(actionName, inputValue)
    if (inputValue or 0) <= 0 or not self.isOpen then return end
    self.selectionInitialized = true
    self:executeSelected()
end

function RemoteDispatcher:registerActionEvents()
    if g_inputBinding == nil then return end

    g_inputBinding:removeActionEventsByTarget(self)
    self.actionEventIds = {}

    local function register(actionName, callback, textKey, visible)
        local actionId = InputAction ~= nil and InputAction[actionName] or actionName
        if actionId == nil then
            rdWarn("Input action %s was not registered by modDesc.xml", tostring(actionName))
            return
        end

        local ok, eventId = g_inputBinding:registerActionEvent(
            actionId,
            self,
            callback,
            false,
            true,
            false,
            true
        )

        if ok and eventId ~= nil then
            table.insert(self.actionEventIds, eventId)
            if g_inputBinding.setActionEventText ~= nil then
                local text = g_i18n ~= nil and g_i18n:getText(textKey) or actionName
                g_inputBinding:setActionEventText(eventId, text)
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
    register("RDC_CONFIRM", self.onConfirm, "input_RDC_CONFIRM", false)
    register("RDC_REMOTE_ACTION", self.onRemoteAction, "input_RDC_REMOTE_ACTION", true)
end

function RemoteDispatcher:draw()
    if not self.isOpen then return end

    if self.backgroundOverlay == nil and createImageOverlay ~= nil then
        self.backgroundOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    local x = 0.025
    local y = 0.765
    local width = 0.55
    local lineHeight = 0.024
    local maxRows = 10
    local height = 0.115 + math.min(#self.vehicles, maxRows) * lineHeight

    if self.backgroundOverlay ~= nil and self.backgroundOverlay ~= 0 then
        setOverlayColor(self.backgroundOverlay, 0.02, 0.02, 0.02, 0.86)
        renderOverlay(self.backgroundOverlay, x - 0.010, y - height + 0.008, width, height)
    end

    self:drawTextLine(x, y, 0.021, "REMOTE DISPATCHER", 1.0, 0.78, 0.18, 1.0)
    y = y - 0.030

    if #self.vehicles == 0 then
        self:drawTextLine(
            x, y, 0.016,
            "No owned AutoDrive/Courseplay-capable vehicles found.",
            1, 1, 1, 1
        )
        y = y - 0.026
    else
        local startRow = math.max(1, self.selectedIndex - math.floor(maxRows / 2))
        local endRow = math.min(#self.vehicles, startRow + maxRows - 1)
        if endRow - startRow + 1 < maxRows then
            startRow = math.max(1, endRow - maxRows + 1)
        end

        for i = startRow, endRow do
            local vehicle = self.vehicles[i]
            local providers = self:getProviders(vehicle)
            local providerText = table.concat(providers, "/")
            local selected = i == self.selectedIndex
            local rowProvider = selected and self.selectedProvider or providers[1]
            local status = self:getProviderStatus(vehicle, rowProvider)
            local detail = self:getProviderDetail(vehicle, rowProvider)
            local distance = self:getVehicleDistance(vehicle)
            local distanceText = distance ~= nil and string.format("  %.0fm", distance) or ""
            local prefix = selected and "> " or "  "
            local text = string.format(
                "%s%s  [%s]  %s%s%s",
                prefix,
                self:getVehicleName(vehicle),
                providerText,
                status,
                detail,
                distanceText
            )

            if selected then
                self:drawTextLine(x, y, 0.015, text, 1.0, 0.82, 0.20, 1.0)
            else
                self:drawTextLine(x, y, 0.014, text, 0.92, 0.92, 0.92, 1.0)
            end
            y = y - lineHeight
        end
    end

    local selectedVehicle = self:getSelectedVehicle()
    if selectedVehicle ~= nil then
        local distance = self:getVehicleDistance(selectedVehicle)
        local distanceText = distance ~= nil and string.format(" / %.0fm away", distance) or ""
        self:drawTextLine(
            x,
            y - 0.004,
            0.015,
            string.format(
                "TARGET: %s / %s%s",
                self:getVehicleName(selectedVehicle),
                tostring(self.selectedProvider or "-"),
                distanceText
            ),
            0.65, 0.85, 1.0, 1.0
        )
    end

    y = y - 0.030
    self:drawTextLine(
        x,
        y,
        0.012,
        "Up/Down vehicle   Left/Right AD/CP   Enter start/stop   Ctrl+Alt+R remote   Ctrl+Alt+D close",
        0.78, 0.78, 0.78, 1.0
    )

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

local originalLoadMap = RemoteDispatcher.loadMap
function RemoteDispatcher:loadMap(mapName)
    originalLoadMap(self, mapName)
    self.selectionInitialized = false
end

local originalDeleteMap = RemoteDispatcher.deleteMap
function RemoteDispatcher:deleteMap()
    self.selectionInitialized = false
    originalDeleteMap(self)
end

rdInfo("v%s target-selection/input hotfix active", RemoteDispatcher.VERSION)
