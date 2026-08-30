-- FS25_RemoteDispatcher v0.2.1.0
-- Persistent runtime configuration shared by the management GUI and active selector.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] State layer loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.1.0"
RemoteDispatcher.providerAssignments = RemoteDispatcher.providerAssignments or setmetatable({}, {__mode = "k"})
RemoteDispatcher.selectorVisible = RemoteDispatcher.selectorVisible == true

local function rdInfo(fmt, ...)
    Logging.info("[RemoteDispatcher] " .. fmt, ...)
end

function RemoteDispatcher:getProviderAssignment(vehicle)
    if vehicle == nil then return nil end
    local providers = self:getProviders(vehicle)
    if #providers == 0 then return nil end

    local assigned = self.providerAssignments[vehicle]
    if assigned ~= nil then
        for _, provider in ipairs(providers) do
            if provider == assigned then return assigned end
        end
    end

    -- Prefer AD for the original cinematic use case where both are present.
    local fallback = providers[1]
    for _, provider in ipairs(providers) do
        if provider == "AD" then
            fallback = provider
            break
        end
    end
    self.providerAssignments[vehicle] = fallback
    return fallback
end

function RemoteDispatcher:setProviderAssignment(vehicle, provider)
    if vehicle == nil then return false, "No vehicle selected" end
    for _, available in ipairs(self:getProviders(vehicle)) do
        if available == provider then
            self.providerAssignments[vehicle] = provider
            if self:getSelectedVehicle() == vehicle then self.selectedProvider = provider end
            rdInfo("Automation assignment '%s' -> %s", self:getVehicleName(vehicle), provider)
            return true, "Automation set to " .. tostring(provider)
        end
    end
    return false, tostring(provider) .. " is unavailable on this vehicle"
end

function RemoteDispatcher:cycleProviderAssignment(vehicle, delta)
    if vehicle == nil then return false, "No vehicle selected" end
    local providers = self:getProviders(vehicle)
    if #providers == 0 then return false, "No automation provider available" end
    if #providers == 1 then return self:setProviderAssignment(vehicle, providers[1]) end

    local current = self:getProviderAssignment(vehicle)
    local currentIndex = 1
    for index, provider in ipairs(providers) do
        if provider == current then currentIndex = index break end
    end
    local step = (delta or 1) >= 0 and 1 or -1
    local nextIndex = ((currentIndex - 1 + step) % #providers) + 1
    return self:setProviderAssignment(vehicle, providers[nextIndex])
end

-- Keep the legacy selectedProvider field synchronized with the per-vehicle assignment.
function RemoteDispatcher:normalizeProvider()
    local vehicle = self:getSelectedVehicle()
    self.selectedProvider = self:getProviderAssignment(vehicle)
end

-- Target cycling is a backend operation. The selector callbacks decide when it
-- is permitted, so it must not depend on the legacy overlay's isOpen flag.
function RemoteDispatcher:selectRelative(delta)
    self.selectionInitialized = true
    if self.vehicles == nil or #self.vehicles == 0 then
        self:refreshVehicles()
        if #self.vehicles == 0 then return false end
    end

    self.selectedIndex = (self.selectedIndex or 1) + (delta or 1)
    if self.selectedIndex < 1 then self.selectedIndex = #self.vehicles end
    if self.selectedIndex > #self.vehicles then self.selectedIndex = 1 end
    self:normalizeProvider()
    return true
end

local previousDeleteMap = RemoteDispatcher.deleteMap
function RemoteDispatcher:deleteMap()
    self.providerAssignments = setmetatable({}, {__mode = "k"})
    self.selectorVisible = false
    if previousDeleteMap ~= nil then previousDeleteMap(self) end
end

rdInfo("v%s per-vehicle dispatcher state active", RemoteDispatcher.VERSION)
