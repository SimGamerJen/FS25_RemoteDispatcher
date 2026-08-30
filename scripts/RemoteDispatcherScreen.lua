-- FS25_RemoteDispatcher v0.2.0.0
-- Proper GIANTS GUI screen for vehicle dispatch and HelperProfiles assignment.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Screen loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.0.0"

local MOD_DIR = g_currentModDirectory or ""
local LOG = "[RemoteDispatcher/GUI] "
local function rdGuiPrint(message) print(LOG .. tostring(message)) end

local function safeText(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(text or ""))
    end
end

local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or minimum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local VehicleDataSource = {}
VehicleDataSource.__index = VehicleDataSource
function VehicleDataSource.new(screen)
    return setmetatable({screen = screen}, VehicleDataSource)
end
function VehicleDataSource:getNumberOfSections() return 1 end
function VehicleDataSource:getNumberOfItemsInSection() return #(self.screen.vehicleRows or {}) end
function VehicleDataSource:populateCellForItemInSection(list, section, index, cell)
    self.screen:populateVehicleCell(index, cell)
end

local WorkerDataSource = {}
WorkerDataSource.__index = WorkerDataSource
function WorkerDataSource.new(screen)
    return setmetatable({screen = screen}, WorkerDataSource)
end
function WorkerDataSource:getNumberOfSections() return 1 end
function WorkerDataSource:getNumberOfItemsInSection() return #(self.screen.workerRows or {}) end
function WorkerDataSource:populateCellForItemInSection(list, section, index, cell)
    self.screen:populateWorkerCell(index, cell)
end

RemoteDispatcherScreen = RemoteDispatcherScreen or {}
local RemoteDispatcherScreen_mt = Class(RemoteDispatcherScreen, MessageDialog)

function RemoteDispatcherScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or RemoteDispatcherScreen_mt)
    self.vehicleRows = {}
    self.workerRows = {}
    self.selectedVehicleIndex = 1
    self.selectedWorkerIndex = 1
    self.vehicleDataSource = VehicleDataSource.new(self)
    self.workerDataSource = WorkerDataSource.new(self)
    self.actionMessage = nil
    return self
end

function RemoteDispatcherScreen:onGuiSetupFinished()
    RemoteDispatcherScreen:superClass().onGuiSetupFinished(self)
    if self.vehicleTable ~= nil then
        self.vehicleTable:setDataSource(self.vehicleDataSource)
        self.vehicleTable:setDelegate(self)
    end
    if self.workerTable ~= nil then
        self.workerTable:setDataSource(self.workerDataSource)
        self.workerTable:setDelegate(self)
    end
end

function RemoteDispatcherScreen:onCreate()
    RemoteDispatcherScreen:superClass().onCreate(self)
end

function RemoteDispatcherScreen:onOpen()
    RemoteDispatcherScreen:superClass().onOpen(self)
    self:reloadData()
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

function RemoteDispatcherScreen:reloadData()
    RemoteDispatcher:refreshVehicles()
    self.vehicleRows = RemoteDispatcher.vehicles or {}
    self.workerRows = RemoteDispatcher:getWorkerChoices()

    self.selectedVehicleIndex = clamp(
        RemoteDispatcher.selectedIndex or self.selectedVehicleIndex,
        1,
        math.max(1, #self.vehicleRows)
    )
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher:normalizeProvider()

    self.selectedWorkerIndex = clamp(self.selectedWorkerIndex, 1, math.max(1, #self.workerRows))
    self:selectAssignedWorkerRow()

    if self.vehicleTable ~= nil then
        self.vehicleTable:reloadData()
        if self.vehicleTable.setSelectedIndex ~= nil then
            pcall(function() self.vehicleTable:setSelectedIndex(self.selectedVehicleIndex) end)
        end
    end
    if self.workerTable ~= nil then
        self.workerTable:reloadData()
        if self.workerTable.setSelectedIndex ~= nil then
            pcall(function() self.workerTable:setSelectedIndex(self.selectedWorkerIndex) end)
        end
    end

    self:updateDetails()
end

function RemoteDispatcherScreen:getSelectedVehicle()
    return self.vehicleRows[self.selectedVehicleIndex]
end

function RemoteDispatcherScreen:getSelectedWorkerRow()
    return self.workerRows[self.selectedWorkerIndex]
end

function RemoteDispatcherScreen:selectAssignedWorkerRow()
    local vehicle = self:getSelectedVehicle()
    local assignment = RemoteDispatcher:getWorkerAssignment(vehicle)
    for index, row in ipairs(self.workerRows or {}) do
        if tostring(row.slot) == tostring(assignment) then
            self.selectedWorkerIndex = index
            return
        end
    end
    self.selectedWorkerIndex = 1
end

function RemoteDispatcherScreen:getProviderDetail(vehicle, provider)
    if provider == "AD" then
        return RemoteDispatcher:getAutoDriveDestinationText(vehicle) or "-"
    elseif provider == "CP" then
        return RemoteDispatcher:getCourseplayCourseText(vehicle) or "-"
    end
    return "-"
end

function RemoteDispatcherScreen:populateVehicleCell(index, cell)
    local vehicle = self.vehicleRows[index]
    if vehicle == nil or cell == nil then return end

    local providers = RemoteDispatcher:getProviders(vehicle)
    local provider = index == self.selectedVehicleIndex
        and RemoteDispatcher.selectedProvider
        or providers[1]
    provider = provider or providers[1] or "-"

    local assignmentData = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    cell:getAttribute("Vehicle"):setText(RemoteDispatcher:getVehicleName(vehicle))
    cell:getAttribute("Auto"):setText(table.concat(providers, "/"))
    cell:getAttribute("State"):setText(RemoteDispatcher:getProviderStatus(vehicle, provider))
    cell:getAttribute("Worker"):setText(tostring(assignmentData.displayName or assignmentData.slot or "AUTO"))
    cell:getAttribute("Task"):setText(self:getProviderDetail(vehicle, provider))
end

function RemoteDispatcherScreen:populateWorkerCell(index, cell)
    local row = self.workerRows[index]
    if row == nil or cell == nil then return end

    local slotText = row.automatic and "-" or tostring(row.slot or "-")
    local state = row.automatic and "NORMAL" or (row.inUse and "ACTIVE" or "AVAILABLE")
    cell:getAttribute("Slot"):setText(slotText)
    cell:getAttribute("Worker"):setText(tostring(row.displayName or row.slot or "AUTO"))
    cell:getAttribute("State"):setText(state)
end

function RemoteDispatcherScreen:onListSelectionChanged(list, section, index)
    if list == self.vehicleTable then
        self.selectedVehicleIndex = clamp(index or 1, 1, math.max(1, #self.vehicleRows))
        RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
        RemoteDispatcher.selectionInitialized = true
        RemoteDispatcher.selectedProvider = nil
        RemoteDispatcher:normalizeProvider()
        self:selectAssignedWorkerRow()
        if self.workerTable ~= nil then
            self.workerTable:reloadData()
            if self.workerTable.setSelectedIndex ~= nil then
                pcall(function() self.workerTable:setSelectedIndex(self.selectedWorkerIndex) end)
            end
        end
    elseif list == self.workerTable then
        self.selectedWorkerIndex = clamp(index or 1, 1, math.max(1, #self.workerRows))
    end

    self.actionMessage = nil
    self:updateDetails()
end

function RemoteDispatcherScreen:updateDetails()
    local vehicle = self:getSelectedVehicle()
    local hpStatus = RemoteDispatcher:getHelperProfilesStatus()

    if hpStatus.available and hpStatus.apiVersion >= 7 and hpStatus.supportsScopedPreferredHire then
        safeText(self.connectionText, string.format(
            "HelperProfiles API v%d connected | Named worker dispatch available",
            hpStatus.apiVersion
        ))
    elseif hpStatus.available then
        safeText(self.connectionText, string.format(
            "HelperProfiles API v%d connected | Update to API v7 for named worker dispatch",
            hpStatus.apiVersion
        ))
    else
        safeText(self.connectionText, "HelperProfiles not detected | AUTO worker selection only")
    end

    if vehicle == nil then
        safeText(self.detailText, "No compatible vehicle selected.")
        safeText(self.workerDetailText, "Worker: AUTO")
        safeText(self.statusText, self.actionMessage or "Ready")
        return
    end

    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher:normalizeProvider()
    local provider = RemoteDispatcher.selectedProvider or "-"
    local status = RemoteDispatcher:getProviderStatus(vehicle, provider)
    local task = self:getProviderDetail(vehicle, provider)
    local assignment = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    local assignmentState = assignment.automatic and "NORMAL"
        or (assignment.inUse and "ACTIVE" or (assignment.enabled and "AVAILABLE" or "UNAVAILABLE"))

    safeText(self.detailText, string.format(
        "%s | %s %s | %s",
        RemoteDispatcher:getVehicleName(vehicle), provider, status, task
    ))

    safeText(self.workerDetailText, string.format(
        "Assigned worker: %s | %s",
        assignment.automatic and "AUTO" or ((assignment.slot or "?") .. " - " .. tostring(assignment.displayName or assignment.slot)),
        assignmentState
    ))

    safeText(self.statusText, self.actionMessage or "Select a worker and Assign, then Dispatch.")

    if self.providerButton ~= nil then
        self.providerButton:setText("Automation: " .. tostring(provider))
    end
    if self.assignButton ~= nil then
        local selectedWorker = self:getSelectedWorkerRow()
        self.assignButton:setText("Assign: " .. tostring(selectedWorker ~= nil and selectedWorker.displayName or "AUTO"))
    end
    if self.dispatchButton ~= nil then
        local active = (provider == "AD" and RemoteDispatcher:isAutoDriveActive(vehicle))
            or (provider == "CP" and RemoteDispatcher:isCourseplayActive(vehicle))
        self.dispatchButton:setText(active and "Stop" or "Dispatch")
    end
end

function RemoteDispatcherScreen:onClickCycleProvider(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher:switchProvider()
    self.actionMessage = "Automation set to " .. tostring(RemoteDispatcher.selectedProvider or "-")
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickAssignWorker(sender)
    local vehicle = self:getSelectedVehicle()
    local worker = self:getSelectedWorkerRow()
    if vehicle == nil or worker == nil then return end

    local success, message = RemoteDispatcher:setWorkerAssignment(vehicle, worker.slot)
    self.actionMessage = tostring(message)
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickDispatch(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end

    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher.selectionInitialized = true
    local success, message = RemoteDispatcher:executeSelected()
    self.actionMessage = tostring(message or (success and "Dispatch complete" or "Dispatch failed"))
    self.workerRows = RemoteDispatcher:getWorkerChoices()
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    if self.workerTable ~= nil then self.workerTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickBack(sender)
    self:close()
end

RemoteDispatcherGui = RemoteDispatcherGui or {
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
        rdGuiPrint("Failed to load GUI: " .. tostring(err))
    end
    return self.loaded
end

function RemoteDispatcherGui:open()
    if not self.loaded then self:loadDialog() end
    if not self.loaded or g_gui == nil then return false end

    RemoteDispatcher:refreshVehicles()
    if not RemoteDispatcher.selectionInitialized and RemoteDispatcher.selectNearestVehicle ~= nil then
        RemoteDispatcher:selectNearestVehicle()
        RemoteDispatcher.selectionInitialized = true
    end

    self.dialog = g_gui:showDialog("RemoteDispatcherDialog")
    return self.dialog ~= nil
end

addModEventListener(RemoteDispatcherGui)

-- The proper GUI replaces the old HUD overlay and its in-world navigation.
function RemoteDispatcher:draw() end

function RemoteDispatcher:onToggleUI(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end
    if RemoteDispatcherGui ~= nil then RemoteDispatcherGui:open() end
end

function RemoteDispatcher:registerActionEvents()
    if g_inputBinding == nil then return end
    g_inputBinding:removeActionEventsByTarget(self)
    self.actionEventIds = {}

    local function register(actionName, callback, textKey, visible)
        local actionId = InputAction ~= nil and InputAction[actionName] or actionName
        if actionId == nil then return end
        local ok, eventId = g_inputBinding:registerActionEvent(
            actionId, self, callback, false, true, false, true
        )
        if ok and eventId ~= nil then
            self.actionEventIds[#self.actionEventIds + 1] = eventId
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
    register("RDC_REMOTE_ACTION", self.onRemoteAction, "input_RDC_REMOTE_ACTION", true)
end

rdGuiPrint("v" .. tostring(RemoteDispatcher.VERSION) .. " proper dispatcher GUI active")
