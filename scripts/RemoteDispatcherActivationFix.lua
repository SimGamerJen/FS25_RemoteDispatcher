-- FS25_RemoteDispatcher v0.1.0.4
-- Wake remotely dispatched vehicles so AutoDrive/Courseplay can begin updating
-- without requiring the player to approach the vehicle first.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] v0.1.0.4 activation fix loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.1.0.4"
RemoteDispatcher._wakeUntil = RemoteDispatcher._wakeUntil or {}
RemoteDispatcher.WAKE_HOLD_MS = 5000

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
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

local previousStartAutoDrive = RemoteDispatcher.startAutoDrive
function RemoteDispatcher:startAutoDrive(vehicle)
    self:wakeVehicle(vehicle, "before AutoDrive start")
    local success, message = previousStartAutoDrive(self, vehicle)
    if success then
        self:wakeVehicle(vehicle, "after AutoDrive start")
    end
    return success, message
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
end

local previousDeleteMap = RemoteDispatcher.deleteMap
function RemoteDispatcher:deleteMap()
    self._wakeUntil = {}
    if previousDeleteMap ~= nil then
        previousDeleteMap(self)
    end
end

rdInfo("v%s remote vehicle wake/activation layer active", RemoteDispatcher.VERSION)
