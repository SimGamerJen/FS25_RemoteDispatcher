-- FS25_RemoteDispatcher v0.1.0.4
-- Wake remotely dispatched vehicles so AutoDrive/Courseplay can begin updating
-- without requiring the player to approach the vehicle first.
-- v0.3.0.3 also adds passive post-start AutoDrive observation. It never retries
-- or changes AutoDrive state; it only records an unexpected early shutdown.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] v0.1.0.4 activation fix loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.1.0.4"
RemoteDispatcher._wakeUntil = RemoteDispatcher._wakeUntil or {}
RemoteDispatcher._adStartObservations = RemoteDispatcher._adStartObservations or setmetatable({}, {__mode = "k"})
RemoteDispatcher.WAKE_HOLD_MS = 5000
RemoteDispatcher.AD_OBSERVATION_CHECKPOINTS_MS = {250, 500, 1000}

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function readStateValue(state, methodName, fallback)
    if state == nil or type(state[methodName]) ~= "function" then
        return fallback
    end

    local ok, value = pcall(function()
        return state[methodName](state)
    end)
    if ok and value ~= nil then
        return value
    end
    return fallback
end

function RemoteDispatcher:wakeVehicle(vehicle, reason)
    if vehicle == nil then return false end

    local target = vehicle
    if vehicle.getRootVehicle ~= nil then
        local ok, root = pcall(function() return vehicle:getRootVehicle() end)
        if ok and root ~= nil then target = root end
    end

    local woke = false
    if target.raiseActive ~= nil then
        local ok, err = pcall(function() target:raiseActive() end)
        if ok then
            woke = true
        else
            rdWarn("raiseActive failed for '%s': %s", self:getVehicleName(target), tostring(err))
        end
    end

    if woke then
        self._wakeUntil[target] = (g_time or 0) + self.WAKE_HOLD_MS
        rdInfo("Wake requested for '%s' (%s)", self:getVehicleName(target), tostring(reason or "remote dispatch"))
    else
        rdWarn("Vehicle '%s' has no usable raiseActive() method", self:getVehicleName(target))
    end

    return woke
end

function RemoteDispatcher:beginAutoDriveObservation(vehicle)
    if vehicle == nil then return end

    local state = vehicle.ad ~= nil and vehicle.ad.stateModule or nil
    self._adStartObservations[vehicle] = {
        startedAt = g_time or 0,
        nextCheckpoint = 1,
        destinationId = readStateValue(state, "getFirstMarkerId", "?"),
        secondDestinationId = readStateValue(state, "getSecondMarkerId", "?")
    }
end

function RemoteDispatcher:updateAutoDriveObservations(now)
    local checkpoints = self.AD_OBSERVATION_CHECKPOINTS_MS or {}

    for vehicle, observation in pairs(self._adStartObservations) do
        local checkpointIndex = observation.nextCheckpoint or 1
        local checkpoint = checkpoints[checkpointIndex]

        if checkpoint == nil then
            self._adStartObservations[vehicle] = nil
        elseif now - observation.startedAt >= checkpoint then
            local elapsed = math.max(0, now - observation.startedAt)
            local active = self:isAutoDriveActive(vehicle)
            local state = vehicle.ad ~= nil and vehicle.ad.stateModule or nil
            local helperIndex = readStateValue(state, "getCurrentHelperIndex", "n/a")
            local wakeUntil = self._wakeUntil[vehicle] or now
            local wakeRemaining = math.max(0, wakeUntil - now)

            if not active then
                rdWarn(
                    "AD post-start observation '%s': inactive by %dms checkpoint (observed=%dms helperIndex=%s destination=%s secondDestination=%s wakeRemainingMs=%d)",
                    self:getVehicleName(vehicle),
                    checkpoint,
                    elapsed,
                    tostring(helperIndex),
                    tostring(observation.destinationId),
                    tostring(observation.secondDestinationId),
                    wakeRemaining
                )
                self._adStartObservations[vehicle] = nil
            elseif checkpointIndex >= #checkpoints then
                rdInfo(
                    "AD post-start observation '%s': active through %dms helperIndex=%s destination=%s secondDestination=%s",
                    self:getVehicleName(vehicle),
                    checkpoint,
                    tostring(helperIndex),
                    tostring(observation.destinationId),
                    tostring(observation.secondDestinationId)
                )
                self._adStartObservations[vehicle] = nil
            else
                observation.nextCheckpoint = checkpointIndex + 1
            end
        end
    end
end

local previousStartAutoDrive = RemoteDispatcher.startAutoDrive
function RemoteDispatcher:startAutoDrive(vehicle)
    self:wakeVehicle(vehicle, "before AutoDrive start")
    local success, message = previousStartAutoDrive(self, vehicle)
    if success then
        self:wakeVehicle(vehicle, "after AutoDrive start")
        self:beginAutoDriveObservation(vehicle)
    end
    return success, message
end

local previousStopAutoDrive = RemoteDispatcher.stopAutoDrive
if previousStopAutoDrive ~= nil then
    function RemoteDispatcher:stopAutoDrive(vehicle)
        self._adStartObservations[vehicle] = nil
        return previousStopAutoDrive(self, vehicle)
    end
end

local previousStartCourseplay = RemoteDispatcher.startCourseplay
function RemoteDispatcher:startCourseplay(vehicle)
    self:wakeVehicle(vehicle, "before Courseplay start")
    local success, message = previousStartCourseplay(self, vehicle)
    if success then
        self:wakeVehicle(vehicle, "after Courseplay start")
    end
    return success, message
end

local previousUpdate = RemoteDispatcher.update
function RemoteDispatcher:update(dt)
    if previousUpdate ~= nil then
        previousUpdate(self, dt)
    end

    local now = g_time or 0
    for vehicle, untilTime in pairs(self._wakeUntil) do
        if vehicle == nil or now >= untilTime then
            self._wakeUntil[vehicle] = nil
        elseif vehicle.raiseActive ~= nil then
            pcall(function() vehicle:raiseActive() end)
        end
    end

    self:updateAutoDriveObservations(now)
end

local previousDeleteMap = RemoteDispatcher.deleteMap
function RemoteDispatcher:deleteMap()
    self._wakeUntil = {}
    self._adStartObservations = setmetatable({}, {__mode = "k"})
    if previousDeleteMap ~= nil then
        previousDeleteMap(self)
    end
end

rdInfo("v%s remote vehicle wake/activation layer active", RemoteDispatcher.VERSION)
