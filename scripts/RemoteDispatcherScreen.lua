-- FS25_RemoteDispatcher v0.2.0.1
-- Compact setup/targeting GUI. Actual cinematic dispatch remains Ctrl+Alt+R
-- after the dialog is closed.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Screen loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.0.1"

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

RemoteDispatcherScreen = RemoteDispatcherScreen or {}
local RemoteDispatcherScreen_mt = Class(RemoteDispatcherScreen, MessageDialog)

function RemoteDispatcherScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or RemoteDispatcherScreen_mt)
    self.vehicleRows = {}
    self.selectedVehicleIndex = 1
    self.vehicleDataSource = VehicleDataSource.new(self)
    self.actionMessage = nil
    return self
end

function RemoteDispatcherScreen:onGuiSetupFinished()
    RemoteDispatcherScreen:superClass().onGuiSetupFinished(self)
    if self.vehicleTable ~= nil then
        self.vehicleTable:setDataSource(self.vehicleDataSource)
        self.vehicleTable:setDelegate(self)
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

    self.selectedVehicleIndex = clamp(
        RemoteDispatcher.selectedIndex or self.selectedVehicleIndex,
        1,
        math.max(1, #self.vehicleRows)
    )
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher.selectionInitialized = #self.vehicleRows > 0
    RemoteDispatcher:normalizeProvider()

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

    local assignment = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    cell:getAttribute("Vehicle"):setText(RemoteDispatcher:getVehicleName(vehicle))
    cell:getAttribute("Auto"):setText(table.concat(providers, "/"))
    cell:getAttribute("State"):setText(RemoteDispatcher:getProviderStatus(vehicle, provider))
    cell:getAttribute("Worker"):setText(tostring(assignment.displayName or assignment.slot or "AUTO"))
    cell:getAttribute("Task"):setText(self:getProviderDetail(vehicle, provider))
end

function RemoteDispatcherScreen:onListSelectionChanged(list, section, index)
    if list ~= self.vehicleTable then return end

    self.selectedVehicleIndex = clamp(index or 1, 1, math.max(1, #self.vehicleRows))
    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher.selectionInitialized = true
    RemoteDispatcher.selectedProvider = nil
    RemoteDispatcher:normalizeProvider()
    self.actionMessage = nil

    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:getNextWorkerChoice(vehicle)
    local choices = RemoteDispatcher:getWorkerChoices()
    if #choices == 0 then return nil end

    local current = tostring(RemoteDispatcher:getWorkerAssignment(vehicle))
    local currentIndex = 1
    for index, row in ipairs(choices) do
        if tostring(row.slot) == current then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #choices then nextIndex = 1 end
    return choices[nextIndex]
end

function RemoteDispatcherScreen:updateDetails()
    local vehicle = self:getSelectedVehicle()
    local hpStatus = RemoteDispatcher:getHelperProfilesStatus()

    if hpStatus.available and hpStatus.apiVersion >= 7 and hpStatus.supportsScopedPreferredHire then
        safeText(self.connectionText, "HelperProfiles connected | Named worker assignment available")
    elseif hpStatus.available then
        safeText(self.connectionText, "HelperProfiles connected | AUTO worker only until API v7")
    else
        safeText(self.connectionText, "HelperProfiles not detected | AUTO worker selection only")
    end

    if vehicle == nil then
        safeText(self.targetText, "No compatible vehicle selected.")
        safeText(self.statusText, self.actionMessage or "Select a vehicle to retain it as the remote target.")
        return
    end

    RemoteDispatcher.selectedIndex = self.selectedVehicleIndex
    RemoteDispatcher:normalizeProvider()

    local provider = RemoteDispatcher.selectedProvider or "-"
    local state = RemoteDispatcher:getProviderStatus(vehicle, provider)
    local task = self:getProviderDetail(vehicle, provider)
    local assignment = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    local workerState = assignment.automatic and "AUTO"
        or (assignment.inUse and "ACTIVE" or (assignment.enabled and "AVAILABLE" or "UNAVAILABLE"))

    safeText(self.targetText, string.format(
        "TARGET: %s  |  %s %s  |  Worker: %s (%s)  |  %s",
        RemoteDispatcher:getVehicleName(vehicle),
        provider,
        state,
        tostring(assignment.displayName or assignment.slot or "AUTO"),
        workerState,
        task
    ))

    safeText(
        self.statusText,
        self.actionMessage or "Close the Dispatcher, position the camera, then press Ctrl+Alt+R to start/stop this target."
    )

    if self.providerButton ~= nil then
        self.providerButton:setText("Automation: " .. tostring(provider))
    end
    if self.workerButton ~= nil then
        self.workerButton:setText("Worker: " .. tostring(assignment.displayName or assignment.slot or "AUTO"))
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

function RemoteDispatcherScreen:onClickCycleWorker(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end

    local nextChoice = self:getNextWorkerChoice(vehicle)
    if nextChoice == nil then
        self.actionMessage = "No worker choices available"
        self:updateDetails()
        return
    end

    local success, message = RemoteDispatcher:setWorkerAssignment(vehicle, nextChoice.slot)
    self.actionMessage = tostring(message or (success and "Worker assigned" or "Worker assignment failed"))

    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
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

-- The GUI is setup only; the world-facing remote trigger remains Ctrl+Alt+R.
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

rdGuiPrint("v" .. tostring(RemoteDispatcher.VERSION) .. " compact cinematic setup GUI active")
