-- FS25_RemoteDispatcher v0.1.0.1
-- Discovery hotfix and diagnostics.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Discovery fix loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.1.0.1"

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

    -- Remote Dispatcher is primarily used while on foot, so prefer the
    -- local player's explicit farm assignment over mission context.
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
    -- The vehicle-level state is sufficient to establish that AutoDrive has
    -- been injected into this vehicle. Do not require the global AutoDrive
    -- table merely to list the vehicle.
    return vehicle ~= nil
        and vehicle.ad ~= nil
        and vehicle.ad.stateModule ~= nil
        and vehicle.ad.stateModule.getCurrentMode ~= nil
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
        if ok and value ~= nil then
            destinationId = value
        end
    end

    if state.getSecondMarkerId ~= nil then
        local ok, value = rdCall(state, "getSecondMarkerId")
        if ok and value ~= nil then
            unloadDestinationId = value
        end
    end

    if AutoDrive ~= nil and AutoDrive.StartDriving ~= nil then
        local ok, err = pcall(function()
            AutoDrive:StartDriving(vehicle, destinationId, unloadDestinationId, nil, nil, nil)
        end)
        if not ok then
            return false, "AutoDrive start failed: " .. tostring(err)
        end
        return true, "AutoDrive started"
    end

    -- Fallback to the mode object already attached to the AD-enabled vehicle.
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

    return true, "AutoDrive started"
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

            local ownerFarmId = nil
            if vehicle ~= nil and vehicle.getOwnerFarmId ~= nil then
                local ok, value = rdCall(vehicle, "getOwnerFarmId")
                if ok then
                    ownerFarmId = value
                end
            end

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

            if rawAd or cpCapable then
                rdInfo(
                    "Discovery candidate '%s': localFarm=%s ownerFarm=%s owned=%s ad=%s adState=%s adCapable=%s cpCapable=%s",
                    self:getVehicleName(vehicle),
                    tostring(localFarmId),
                    tostring(ownerFarmId),
                    tostring(owned),
                    tostring(rawAd),
                    tostring(adState),
                    tostring(adCapable),
                    tostring(cpCapable)
                )
            end

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

rdInfo("v%s discovery hotfix active", RemoteDispatcher.VERSION)
