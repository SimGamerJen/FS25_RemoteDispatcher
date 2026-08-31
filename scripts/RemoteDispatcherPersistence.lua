-- FS25_RemoteDispatcher v0.3.0.1
-- Per-save persistence for vehicle automation/worker assignments and retained target.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Persistence loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.3.0.1"

RemoteDispatcherPersistence = RemoteDispatcherPersistence or {
    initialized = false,
    savegameName = nil,
    savegameDir = nil,
    stateFile = nil,
    version = "1.0",
    recordsById = {},
    selectedVehicleId = nil,
    hydratedVehicles = setmetatable({}, {__mode = "k"})
}

local LOG = "[RemoteDispatcher/Persistence] "
local function rdLog(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function normalizePathSlashes(path)
    if path == nil then return nil end
    return tostring(path):gsub("\\", "/")
end

local function getPathBaseName(path)
    path = normalizePathSlashes(path or "") or ""
    path = path:gsub("/+$", "")
    local base = path:match("([^/]+)$")
    return base ~= nil and base ~= "" and base or nil
end

local function detectSavegameName()
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if missionInfo ~= nil then
        local candidates = {
            missionInfo.savegameDirectory,
            missionInfo.savegameDir,
            missionInfo.savegamePath,
            missionInfo.savegameXMLFilename,
            missionInfo.savegameSavePath
        }
        for _, value in ipairs(candidates) do
            if value ~= nil and tostring(value) ~= "" then
                local path = normalizePathSlashes(value)
                local match = path ~= nil and path:match("(savegame%d+)") or nil
                if match ~= nil and match ~= "" then return match end
                local base = getPathBaseName(path)
                if base ~= nil then return base end
            end
        end

        local index = missionInfo.savegameIndex or missionInfo.savegameNumber
            or missionInfo.saveGameIndex or missionInfo.saveGameNumber
        if tonumber(index) ~= nil then
            return "savegame" .. tostring(math.floor(tonumber(index)))
        end
    end
    return "unknownSavegame"
end

local function ensureFolder(path)
    if path ~= nil and path ~= "" and not fileExists(path) then
        createFolder(path)
    end
end

function RemoteDispatcherPersistence:getVehicleId(vehicle)
    if vehicle == nil then return nil end
    if type(vehicle.getUniqueId) == "function" then
        local ok, value = pcall(vehicle.getUniqueId, vehicle)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    if vehicle.uniqueId ~= nil and tostring(vehicle.uniqueId) ~= "" then
        return tostring(vehicle.uniqueId)
    end
    return nil
end

function RemoteDispatcherPersistence:getRecordCount()
    local count = 0
    for _ in pairs(self.recordsById or {}) do count = count + 1 end
    return count
end

function RemoteDispatcherPersistence:init()
    if self.initialized then return end
    self.initialized = true
    self.recordsById = {}
    self.hydratedVehicles = setmetatable({}, {__mode = "k"})

    local profilePath = getUserProfileAppPath()
    local modSettingsDir = profilePath .. "modSettings/FS25_RemoteDispatcher/"
    local savesDir = modSettingsDir .. "saves/"
    self.savegameName = detectSavegameName()
    self.savegameDir = savesDir .. tostring(self.savegameName) .. "/"
    self.stateFile = self.savegameDir .. "dispatcher.xml"

    ensureFolder(modSettingsDir)
    ensureFolder(savesDir)
    ensureFolder(self.savegameDir)
    self:load()
end

function RemoteDispatcherPersistence:load()
    self.recordsById = {}
    self.selectedVehicleId = nil

    if self.stateFile == nil or not fileExists(self.stateFile) then
        rdLog("No per-save dispatcher state found: %s", tostring(self.stateFile))
        return true
    end

    local xmlFile = loadXMLFile("remoteDispatcherStateRead", self.stateFile)
    if xmlFile == nil or xmlFile == 0 then
        rdLog("Could not read dispatcher state: %s", tostring(self.stateFile))
        return false, "unreadable"
    end

    self.selectedVehicleId = getXMLString(xmlFile, "remoteDispatcherState#selectedVehicleId")
    local index = 0
    while true do
        local key = string.format("remoteDispatcherState.vehicles.vehicle(%d)", index)
        if not hasXMLProperty(xmlFile, key) then break end

        local uniqueId = getXMLString(xmlFile, key .. "#uniqueId")
        if uniqueId ~= nil and tostring(uniqueId) ~= "" then
            self.recordsById[tostring(uniqueId)] = {
                provider = getXMLString(xmlFile, key .. "#provider"),
                worker = getXMLString(xmlFile, key .. "#worker") or "AUTO"
            }
        end
        index = index + 1
    end
    delete(xmlFile)

    rdLog(
        "Loaded per-save state: savegame=%s records=%d selected=%s file=%s",
        tostring(self.savegameName), self:getRecordCount(),
        tostring(self.selectedVehicleId or "none"), tostring(self.stateFile)
    )
    return true
end

function RemoteDispatcherPersistence:write()
    if not self.initialized then self:init() end
    ensureFolder(self.savegameDir)

    local xmlFile = createXMLFile("remoteDispatcherStateWrite", self.stateFile, "remoteDispatcherState")
    if xmlFile == nil or xmlFile == 0 then
        rdLog("Failed to create dispatcher state file: %s", tostring(self.stateFile))
        return false, "create-failed"
    end

    setXMLString(xmlFile, "remoteDispatcherState#version", tostring(self.version))
    setXMLString(xmlFile, "remoteDispatcherState#savegame", tostring(self.savegameName or "unknownSavegame"))
    if self.selectedVehicleId ~= nil then
        setXMLString(xmlFile, "remoteDispatcherState#selectedVehicleId", tostring(self.selectedVehicleId))
    end

    local ids = {}
    for uniqueId in pairs(self.recordsById or {}) do ids[#ids + 1] = uniqueId end
    table.sort(ids)

    for index, uniqueId in ipairs(ids) do
        local record = self.recordsById[uniqueId] or {}
        local key = string.format("remoteDispatcherState.vehicles.vehicle(%d)", index - 1)
        setXMLString(xmlFile, key .. "#uniqueId", tostring(uniqueId))
        if record.provider ~= nil then setXMLString(xmlFile, key .. "#provider", tostring(record.provider)) end
        setXMLString(xmlFile, key .. "#worker", tostring(record.worker or "AUTO"))
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
    return true
end

function RemoteDispatcherPersistence:hydrateVehicle(vehicle)
    if vehicle == nil or self.hydratedVehicles[vehicle] then return end
    if not self.initialized then self:init() end

    local uniqueId = self:getVehicleId(vehicle)
    local record = uniqueId ~= nil and self.recordsById[uniqueId] or nil
    if record ~= nil then
        if record.provider ~= nil and RemoteDispatcher.providerAssignments ~= nil then
            RemoteDispatcher.providerAssignments[vehicle] = tostring(record.provider)
        end
        if RemoteDispatcher.workerAssignments ~= nil then
            RemoteDispatcher.workerAssignments[vehicle] = tostring(record.worker or "AUTO")
        end
    end
    self.hydratedVehicles[vehicle] = true
end

function RemoteDispatcherPersistence:updateRecord(vehicle, provider, worker)
    if vehicle == nil then return false, "no-vehicle" end
    if not self.initialized then self:init() end

    local uniqueId = self:getVehicleId(vehicle)
    if uniqueId == nil then
        rdLog("Cannot persist '%s': vehicle has no stable uniqueId", RemoteDispatcher:getVehicleName(vehicle))
        return false, "no-unique-id"
    end

    local record = self.recordsById[uniqueId] or {}
    if provider ~= nil then record.provider = tostring(provider) end
    if worker ~= nil then record.worker = tostring(worker) end
    self.recordsById[uniqueId] = record
    return self:write()
end

function RemoteDispatcherPersistence:rememberTarget(vehicle)
    if vehicle == nil then return false end
    if not self.initialized then self:init() end
    local uniqueId = self:getVehicleId(vehicle)
    if uniqueId == nil then return false end
    if self.selectedVehicleId == uniqueId then return true end
    self.selectedVehicleId = uniqueId
    self:write()
    return true
end

function RemoteDispatcherPersistence:restoreSelectedTarget()
    if self.selectedVehicleId == nil or RemoteDispatcher.vehicles == nil then return false end
    for index, vehicle in ipairs(RemoteDispatcher.vehicles) do
        if self:getVehicleId(vehicle) == self.selectedVehicleId then
            RemoteDispatcher.selectedIndex = index
            RemoteDispatcher.selectionInitialized = true
            RemoteDispatcher:normalizeProvider()
            rdLog("Restored retained target: %s (%s)", RemoteDispatcher:getVehicleName(vehicle), self.selectedVehicleId)
            return true
        end
    end
    return false
end

-- Lazy hydration lets the state file load independently of FS25's asynchronous vehicle loading.
local previousGetProviderAssignment = RemoteDispatcher.getProviderAssignment
function RemoteDispatcher:getProviderAssignment(vehicle)
    RemoteDispatcherPersistence:hydrateVehicle(vehicle)
    return previousGetProviderAssignment(self, vehicle)
end

local previousSetProviderAssignment = RemoteDispatcher.setProviderAssignment
function RemoteDispatcher:setProviderAssignment(vehicle, provider)
    local success, message = previousSetProviderAssignment(self, vehicle, provider)
    if success then
        RemoteDispatcherPersistence:updateRecord(vehicle, self.providerAssignments[vehicle], nil)
    end
    return success, message
end

local previousGetWorkerAssignment = RemoteDispatcher.getWorkerAssignment
function RemoteDispatcher:getWorkerAssignment(vehicle)
    RemoteDispatcherPersistence:hydrateVehicle(vehicle)
    return previousGetWorkerAssignment(self, vehicle)
end

local previousSetWorkerAssignment = RemoteDispatcher.setWorkerAssignment
function RemoteDispatcher:setWorkerAssignment(vehicle, slot)
    local success, message = previousSetWorkerAssignment(self, vehicle, slot)
    if success then
        RemoteDispatcherPersistence:updateRecord(vehicle, nil, self.workerAssignments[vehicle] or "AUTO")
    end
    return success, message
end

local previousRefreshVehicles = RemoteDispatcher.refreshVehicles
function RemoteDispatcher:refreshVehicles(...)
    local result = previousRefreshVehicles(self, ...)
    if RemoteDispatcherPersistence.initialized then
        for _, vehicle in ipairs(self.vehicles or {}) do RemoteDispatcherPersistence:hydrateVehicle(vehicle) end
        if not self.selectionInitialized then RemoteDispatcherPersistence:restoreSelectedTarget() end
        self:normalizeProvider()
    end
    return result
end

local previousSelectRelative = RemoteDispatcher.selectRelative
function RemoteDispatcher:selectRelative(delta)
    local result = previousSelectRelative(self, delta)
    if result ~= false then RemoteDispatcherPersistence:rememberTarget(self:getSelectedVehicle()) end
    return result
end

local previousSelectNearestVehicle = RemoteDispatcher.selectNearestVehicle
if type(previousSelectNearestVehicle) == "function" then
    function RemoteDispatcher:selectNearestVehicle(...)
        local result = previousSelectNearestVehicle(self, ...)
        if result == true then RemoteDispatcherPersistence:rememberTarget(self:getSelectedVehicle()) end
        return result
    end
end

function RemoteDispatcherPersistence:loadMap()
    self.initialized = false
    self:init()
    RemoteDispatcher:refreshVehicles()
    self:restoreSelectedTarget()
end

function RemoteDispatcherPersistence:deleteMap()
    if self.initialized then self:write() end
    self.initialized = false
    self.savegameName = nil
    self.savegameDir = nil
    self.stateFile = nil
    self.recordsById = {}
    self.selectedVehicleId = nil
    self.hydratedVehicles = setmetatable({}, {__mode = "k"})
end

addModEventListener(RemoteDispatcherPersistence)
rdLog("v%s per-save persistence layer loaded", RemoteDispatcher.VERSION)
