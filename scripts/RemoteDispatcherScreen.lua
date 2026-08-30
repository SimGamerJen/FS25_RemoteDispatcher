-- FS25_RemoteDispatcher v0.2.1.0
-- Management GUI: configure automation and preferred worker; no dispatch action here.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Management screen loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.1.0"

local MOD_DIR = g_currentModDirectory or ""
local LOG = "[RemoteDispatcher/Management] "
local function rdPrint(message) print(LOG .. tostring(message)) end

local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or minimum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function safeText(element, text)
    if element ~= nil and element.setText ~= nil then element:setText(tostring(text or "")) end
end

RemoteDispatcherScreen = {}
local RemoteDispatcherScreen_mt = Class(RemoteDispatcherScreen, MessageDialog)

function RemoteDispatcherScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or RemoteDispatcherScreen_mt)
    self.vehicleRows = {}
    self.selectedVehicleIndex = 1
    self.workerChoices = {}
    self.actionMessage = nil
    self.retryTimer = 0
    return self
end

function RemoteDispatcherScreen:onGuiSetupFinished()
    RemoteDispatcherScreen:superClass().onGuiSetupFinished(self)
    if self.vehicleTable ~= nil then
        self.vehicleTable:setDataSource(self)
        self.vehicleTable:setDelegate(self)
    end
end

function RemoteDispatcherScreen:onCreate()
    RemoteDispatcherScreen:superClass().onCreate(self)
end

function RemoteDispatcherScreen:onOpen()
    RemoteDispatcherScreen:superClass().onOpen(self)
    self.retryTimer = 0
    self:reloadData(true)
    if FocusManager ~= nil and self.vehicleTable ~= nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.vehicleTable)
        self:setSoundSuppressed(false)
    end
end

function RemoteDispatcherScreen:onClose()
    RemoteDispatcherScreen:superClass().onClose(self)
    if RemoteDispatcherGui ~= nil then RemoteDispatcherGui.dialog = nil end
end

function RemoteDispatcherScreen:update(dt)
    RemoteDispatcherScreen:superClass().update(self, dt)
    -- Retry briefly if another script mod published its vehicle/API state later in the frame.
    if #self.vehicleRows == 0 or RemoteDispatcher:getHelperProfilesStatus().available ~= true then
        self.retryTimer = (self.retryTimer or 0) + (dt or 0)
        if self.retryTimer >= 750 then
            self.retryTimer = 0
            self:reloadData(false)
        end
    end
end

function RemoteDispatcherScreen:reloadData(resetMessage)
    RemoteDispatcher:refreshVehicles()
    self.vehicleRows = RemoteDispatcher.vehicles or {}
    self.workerChoices = RemoteDispatcher:getWorkerChoices()

    self.selectedVehicleIndex = clamp(
        RemoteDispatcher.selectedIndex or self.selectedVehicleIndex,
        1,
        math.max(1, #self.vehicleRows)
    )
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher:normalizeProvider()

    if resetMessage then self.actionMessage = nil end
    if self.vehicleTable ~= nil then
        self.vehicleTable:reloadData()
        if self.vehicleTable.setSelectedIndex ~= nil then
            pcall(function() self.vehicleTable:setSelectedIndex(self.selectedVehicleIndex) end)
        end
    end
    self:updateDetails()
end

function RemoteDispatcherScreen:getSelectedVehicle()
    return self.vehicleRows[self.selectedVehicleIndex]
end

function RemoteDispatcherScreen:getNumberOfSections() return 1 end
function RemoteDispatcherScreen:getNumberOfItemsInSection() return #(self.vehicleRows or {}) end

function RemoteDispatcherScreen:populateCellForItemInSection(list, section, index, cell)
    local vehicle = self.vehicleRows[index]
    if vehicle == nil or cell == nil then return end
    local provider = RemoteDispatcher:getProviderAssignment(vehicle) or "-"
    local worker = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    cell:getAttribute("Vehicle"):setText(RemoteDispatcher:getVehicleName(vehicle))
    cell:getAttribute("Auto"):setText(provider)
    cell:getAttribute("State"):setText(RemoteDispatcher:getProviderStatus(vehicle, provider))
    cell:getAttribute("Worker"):setText(tostring(worker.displayName or worker.slot or "AUTO"))
    local task = provider == "AD" and RemoteDispatcher:getAutoDriveDestinationText(vehicle)
        or (provider == "CP" and RemoteDispatcher:getCourseplayCourseText(vehicle) or nil)
    cell:getAttribute("Task"):setText(tostring(task or "-"))
end

function RemoteDispatcherScreen:onListSelectionChanged(list, section, index)
    self.selectedVehicleIndex = clamp(index or 1, 1, math.max(1, #self.vehicleRows))
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher.selectionInitialized = true
    RemoteDispatcher:normalizeProvider()
    self.actionMessage = nil
    self:updateDetails()
end

function RemoteDispatcherScreen:updateDetails()
    local hp = RemoteDispatcher:getHelperProfilesStatus()
    if hp.available and hp.supportsScopedPreferredHire then
        safeText(self.connectionText, string.format("HelperProfiles API v%d connected | Named worker assignments available", hp.apiVersion or 0))
    elseif hp.available then
        safeText(self.connectionText, string.format("HelperProfiles API v%d connected | API v7 required for named dispatch", hp.apiVersion or 0))
    else
        safeText(self.connectionText, "HelperProfiles not detected | AUTO worker selection only")
    end

    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then
        safeText(self.detailText, "No compatible vehicle selected. Retrying discovery...")
        safeText(self.statusText, self.actionMessage or "Management configures vehicles; use the in-game selector for cinematic targeting.")
        if self.providerButton ~= nil then self.providerButton:setText("Automation") end
        if self.workerButton ~= nil then self.workerButton:setText("Worker: AUTO") end
        return
    end

    local provider = RemoteDispatcher:getProviderAssignment(vehicle) or "-"
    local worker = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    local task = provider == "AD" and RemoteDispatcher:getAutoDriveDestinationText(vehicle)
        or (provider == "CP" and RemoteDispatcher:getCourseplayCourseText(vehicle) or nil)

    safeText(self.detailText, string.format(
        "Target: %s | %s | Worker: %s | %s",
        RemoteDispatcher:getVehicleName(vehicle), provider,
        tostring(worker.displayName or worker.slot or "AUTO"), tostring(task or "-")
    ))
    safeText(self.statusText, self.actionMessage or "Select a row to make it the retained target. Configure Automation/Worker here, then close.")

    if self.providerButton ~= nil then self.providerButton:setText("Automation: " .. provider) end
    if self.workerButton ~= nil then self.workerButton:setText("Worker: " .. tostring(worker.displayName or worker.slot or "AUTO")) end
end

function RemoteDispatcherScreen:onClickCycleProvider(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end
    local _, message = RemoteDispatcher:cycleProviderAssignment(vehicle, 1)
    self.actionMessage = message
    RemoteDispatcher:normalizeProvider()
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickCycleWorker(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end

    self.workerChoices = RemoteDispatcher:getWorkerChoices()
    local current = RemoteDispatcher:getWorkerAssignment(vehicle)
    local currentIndex = 1
    for index, row in ipairs(self.workerChoices) do
        if tostring(row.slot) == tostring(current) then currentIndex = index break end
    end

    local nextIndex = (currentIndex % math.max(1, #self.workerChoices)) + 1
    local nextRow = self.workerChoices[nextIndex]
    local success, message = RemoteDispatcher:setWorkerAssignment(vehicle, nextRow ~= nil and nextRow.slot or "AUTO")
    self.actionMessage = tostring(message)
    if success and self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickBack(sender)
    self:close()
end

RemoteDispatcherGui = {
    dialog = nil,
    loaded = false,
    failed = false,
    modDirectory = MOD_DIR
}

function RemoteDispatcherGui:loadMap()
    self.modDirectory = MOD_DIR ~= "" and MOD_DIR or (g_currentModDirectory or self.modDirectory or "")
end

function RemoteDispatcherGui:deleteMap()
    self.dialog = nil
    self.loaded = false
    self.failed = false
end

function RemoteDispatcherGui:loadDialog()
    if self.loaded or self.failed then return self.loaded end
    if g_gui == nil then return false end
    local modDir = self.modDirectory or MOD_DIR or g_currentModDirectory or ""
    local ok, err = pcall(function()
        if g_gui.loadProfiles ~= nil then g_gui:loadProfiles(modDir .. "gui/guiProfiles.xml") end
        local frame = RemoteDispatcherScreen.new(g_i18n)
        g_gui:loadGui(modDir .. "gui/RemoteDispatcherScreen.xml", "RemoteDispatcherDialog", frame)
        self.loaded = true
    end)
    if not ok then
        self.failed = true
        rdPrint("Failed to load GUI: " .. tostring(err))
    end
    return self.loaded
end

function RemoteDispatcherGui:open()
    if not self.loaded then self:loadDialog() end
    if not self.loaded or g_gui == nil then return false end
    RemoteDispatcher:refreshVehicles()
    self.dialog = g_gui:showDialog("RemoteDispatcherDialog")
    return self.dialog ~= nil
end

addModEventListener(RemoteDispatcherGui)
rdPrint("v" .. tostring(RemoteDispatcher.VERSION) .. " management GUI active")
