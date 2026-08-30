-- FS25_RemoteDispatcher v0.2.1.0
-- Optional HelperProfiles API v7 integration.
-- Vehicle -> worker assignments are owned by Remote Dispatcher. HelperProfiles
-- remains authoritative for roster availability and supplies the requested
-- helper only inside a short scoped hire operation.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] HelperProfiles integration loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.1.0"
RemoteDispatcher.workerAssignments = RemoteDispatcher.workerAssignments or setmetatable({}, {__mode = "k"})
RemoteDispatcher.AUTO_WORKER = "AUTO"

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

function RemoteDispatcher:getHelperProfilesAPI()
    local api = rawget(_G, "FS25_HelperProfiles_API") or rawget(_G, "FS25_HelperProfilesAPI")
    if type(api) == "table" then return api end

    if g_currentMission ~= nil then
        api = g_currentMission.fs25HelperProfilesAPI or g_currentMission.helperProfilesAPI
        if type(api) == "table" then return api end
    end

    -- Startup-order fallback: the integration owner may exist briefly before
    -- its public aliases are republished.
    local owner = rawget(_G, "HP_IntegrationAPI")
    if type(owner) == "table" then
        if type(owner.api) == "table" then return owner.api end
        if type(owner.publish) == "function" and g_currentMission ~= nil then
            pcall(owner.publish, owner, "RemoteDispatcherLookup")
            if type(owner.api) == "table" then return owner.api end
        end
    end

    return nil
end

function RemoteDispatcher:getHelperProfilesStatus()
    local api = self:getHelperProfilesAPI()
    if api == nil then
        return {
            available = false,
            apiVersion = 0,
            supportsScopedPreferredHire = false,
            reason = "HelperProfiles not detected"
        }
    end

    local status = nil
    if type(api.getStatus) == "function" then
        local ok, value = pcall(api.getStatus, api)
        if ok and type(value) == "table" then status = value end
    end
    status = status or {}
    status.available = status.available ~= false
    status.apiVersion = tonumber(api.apiVersion or status.apiVersion) or 0
    status.supportsScopedPreferredHire = api.supportsScopedPreferredHire == true
        or status.supportsScopedPreferredHire == true
        or (status.apiVersion >= 7 and type(api.beginPreferredHire) == "function" and type(api.endPreferredHire) == "function")
    return status
end

function RemoteDispatcher:getWorkerAssignment(vehicle)
    if vehicle == nil then return self.AUTO_WORKER end
    local slot = self.workerAssignments[vehicle]
    if slot == nil or slot == "" then return self.AUTO_WORKER end
    return tostring(slot)
end

function RemoteDispatcher:setWorkerAssignment(vehicle, slot)
    if vehicle == nil then return false, "No vehicle selected" end
    slot = slot == nil and self.AUTO_WORKER or tostring(slot)

    if slot == self.AUTO_WORKER then
        self.workerAssignments[vehicle] = self.AUTO_WORKER
        rdInfo("Worker assignment '%s' -> AUTO", self:getVehicleName(vehicle))
        return true, "Worker assignment set to AUTO"
    end

    local api = self:getHelperProfilesAPI()
    if api == nil or type(api.getSlotData) ~= "function" then
        return false, "HelperProfiles API is unavailable"
    end

    local ok, data = pcall(api.getSlotData, api, slot)
    if not ok or type(data) ~= "table" then
        return false, "Worker slot is unavailable"
    end
    if data.enabled ~= true then
        return false, string.format("%s is OFF roster", tostring(data.displayName or slot))
    end

    self.workerAssignments[vehicle] = tostring(data.slot or slot)
    rdInfo(
        "Worker assignment '%s' -> %s (%s)",
        self:getVehicleName(vehicle),
        tostring(data.slot or slot),
        tostring(data.displayName or slot)
    )
    return true, string.format("Assigned %s", tostring(data.displayName or slot))
end

function RemoteDispatcher:getWorkerAssignmentData(vehicle)
    local assignment = self:getWorkerAssignment(vehicle)
    if assignment == self.AUTO_WORKER then
        local status = self:getHelperProfilesStatus()
        local selectedName = nil
        local api = self:getHelperProfilesAPI()
        if api ~= nil and type(api.getSelectedDisplayName) == "function" then
            local ok, value = pcall(api.getSelectedDisplayName, api)
            if ok then selectedName = value end
        end
        return {
            slot = self.AUTO_WORKER,
            displayName = "AUTO",
            enabled = true,
            inUse = false,
            automatic = true,
            detail = status.available
                and (selectedName ~= nil and ("Normal HProfs flow; selected " .. tostring(selectedName)) or "Normal HelperProfiles hiring flow")
                or "Normal game/automation helper selection"
        }
    end

    local api = self:getHelperProfilesAPI()
    if api ~= nil and type(api.getSlotData) == "function" then
        local ok, data = pcall(api.getSlotData, api, assignment)
        if ok and type(data) == "table" then
            data.automatic = false
            return data
        end
    end

    return {
        slot = assignment,
        displayName = assignment,
        enabled = false,
        inUse = false,
        automatic = false,
        detail = "HelperProfiles slot unavailable"
    }
end

function RemoteDispatcher:getWorkerChoices()
    local choices = {
        {
            slot = self.AUTO_WORKER,
            displayName = "AUTO",
            enabled = true,
            inUse = false,
            automatic = true,
            status = "NORMAL"
        }
    }

    local api = self:getHelperProfilesAPI()
    if api == nil or type(api.getEnabledSlots) ~= "function" then
        return choices
    end

    local ok, slots = pcall(api.getEnabledSlots, api)
    if not ok or type(slots) ~= "table" then return choices end

    table.sort(slots, function(a, b)
        return (tonumber(a.stableIndex or a.index) or 999) < (tonumber(b.stableIndex or b.index) or 999)
    end)

    for _, data in ipairs(slots) do
        if type(data) == "table" and data.enabled == true then
            choices[#choices + 1] = {
                slot = tostring(data.slot or "?"),
                displayName = tostring(data.displayName or data.slot or "Helper"),
                enabled = true,
                inUse = data.inUse == true,
                automatic = false,
                appearanceLabel = data.appearanceLabel,
                identityId = data.identityId,
                status = data.inUse == true and "ACTIVE" or "AVAILABLE"
            }
        end
    end

    return choices
end

function RemoteDispatcher:withAssignedWorker(vehicle, callback)
    local assignment = self:getWorkerAssignment(vehicle)
    if assignment == self.AUTO_WORKER then
        local ok, success, message = pcall(callback)
        if not ok then return false, "Dispatch failed: " .. tostring(success) end
        return success, message
    end

    local api = self:getHelperProfilesAPI()
    local hpStatus = self:getHelperProfilesStatus()
    if api == nil or hpStatus.apiVersion < 7 or hpStatus.supportsScopedPreferredHire ~= true
        or type(api.beginPreferredHire) ~= "function" or type(api.endPreferredHire) ~= "function" then
        return false, "Named worker dispatch requires HelperProfiles API v7"
    end

    local token, detail = api:beginPreferredHire(assignment, "FS25_RemoteDispatcher")
    if token == nil then
        local reason = tostring(detail or "worker unavailable")
        local data = self:getWorkerAssignmentData(vehicle)
        return false, string.format("%s unavailable (%s)", tostring(data.displayName or assignment), reason)
    end

    local ok, success, message = pcall(callback)
    local endOk, endReason = api:endPreferredHire(token)
    if endOk ~= true then
        rdWarn("HelperProfiles scoped hire cleanup failed: %s", tostring(endReason))
    end

    if not ok then
        return false, "Dispatch failed: " .. tostring(success)
    end
    return success, message
end

function RemoteDispatcher:executeSelected()
    if #self.vehicles == 0 or self:getSelectedVehicle() == nil then
        self:refreshVehicles()
    end

    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then
        self:notify("Remote Dispatcher: no compatible vehicle selected", true)
        return false
    end

    self:normalizeProvider()
    local provider = self.selectedProvider
    local vehicleName = self:getVehicleName(vehicle)
    local adActive = self:isAutoDriveActive(vehicle)
    local cpActive = self:isCourseplayActive(vehicle)
    local success, message

    if provider == "AD" then
        if adActive then
            success, message = self:stopAutoDrive(vehicle)
        elseif cpActive then
            success, message = false, "Courseplay is already active"
        else
            success, message = self:withAssignedWorker(vehicle, function()
                return self:startAutoDrive(vehicle)
            end)
        end
    elseif provider == "CP" then
        if cpActive then
            success, message = self:stopCourseplay(vehicle)
        elseif adActive then
            success, message = false, "AutoDrive is already active"
        else
            success, message = self:withAssignedWorker(vehicle, function()
                return self:startCourseplay(vehicle)
            end)
        end
    else
        success, message = false, "No supported automation provider"
    end

    self:notify(string.format("%s: %s", vehicleName, tostring(message)), not success)
    return success == true, message
end

local previousDeleteMap = RemoteDispatcher.deleteMap
function RemoteDispatcher:deleteMap()
    self.workerAssignments = setmetatable({}, {__mode = "k"})
    if previousDeleteMap ~= nil then previousDeleteMap(self) end
end

rdInfo("v%s HelperProfiles API integration active", RemoteDispatcher.VERSION)
