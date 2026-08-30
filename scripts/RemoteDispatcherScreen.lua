-- FS25_RemoteDispatcher v0.2.2.0
-- Management GUI: configure per-vehicle automation and preferred worker.
-- Live Ctrl+Alt+R targeting remains owned by the in-game selector.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Management screen loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.2.0"

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

RemoteDispatcherScreen = {}
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
    self.retryTimer = 0
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
    self.retryTimer = (self.retryTimer or 0) + (dt or 0)
    if self.retryTimer >= 750 then
        self.retryTimer = 0
        local hadVehicles = #self.vehicleRows > 0
        local hpWasAvailable = RemoteDispatcher:getHelperProfilesStatus().available == true
        if not hadVehicles or not hpWasAvailable then
            self:reloadData(false)
        else
            self.workerRows = RemoteDispatcher:getWorkerChoices()
            if self.workerTable ~= nil then self.workerTable:reloadData() end
            self:updateDetails()
        end
    end
end

function RemoteDispatcherScreen:reloadData(resetMessage)
    RemoteDispatcher:refreshVehicles()
    self.vehicleRows = RemoteDispatcher.vehicles or {}
    self.workerRows = RemoteDispatcher:getWorkerChoices()

    self.selectedVehicleIndex = clamp(
        RemoteDispatcher.selectedIndex or self.selectedVehicleIndex,
        1,
        math.max(1, #self.vehicleRows)
    )
    self.selectedWorkerIndex = clamp(self.selectedWorkerIndex, 1, math.max(1, #self.workerRows))
    self:selectAssignedWorkerRow()

    if resetMessage then self.actionMessage = nil end

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
    local assignment = tostring(RemoteDispatcher:getWorkerAssignment(vehicle) or RemoteDispatcher.AUTO_WORKER or "AUTO")
    for index, row in ipairs(self.workerRows or {}) do
        if tostring(row.slot) == assignment then
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

    local provider = RemoteDispatcher:getProviderAssignment(vehicle) or "-"
    local worker = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    cell:getAttribute("Vehicle"):setText(RemoteDispatcher:getVehicleName(vehicle))
    cell:getAttribute("Auto"):setText(provider)
    cell:getAttribute("State"):setText(RemoteDispatcher:getProviderStatus(vehicle, provider))
    cell:getAttribute("Worker"):setText(tostring(worker.displayName or worker.slot or "AUTO"))
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
        self.workerRows = RemoteDispatcher:getWorkerChoices()
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
    local hp = RemoteDispatcher:getHelperProfilesStatus()
    if hp.available and hp.supportsScopedPreferredHire then
        safeText(self.connectionText, string.format(
            "HelperProfiles API v%d connected | Named worker assignments available",
            hp.apiVersion or 0
        ))
    elseif hp.available then
        safeText(self.connectionText, string.format(
            "HelperProfiles API v%d connected | API v7 required for named dispatch",
            hp.apiVersion or 0
        ))
    else
        safeText(self.connectionText, "HelperProfiles not detected | AUTO worker selection only")
    end

    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then
        safeText(self.detailText, "No compatible vehicle selected. Retrying discovery...")
        safeText(self.statusText, self.actionMessage or "Management configures vehicles; the live selector owns the cinematic target.")
        if self.providerButton ~= nil then self.providerButton:setText("Automation") end
        if self.assignButton ~= nil then self.assignButton:setText("Assign Worker") end
        return
    end

    local provider = RemoteDispatcher:getProviderAssignment(vehicle) or "-"
    local assigned = RemoteDispatcher:getWorkerAssignmentData(vehicle)
    local task = self:getProviderDetail(vehicle, provider)
    local selectedWorker = self:getSelectedWorkerRow()

    safeText(self.detailText, string.format(
        "%s | %s | Assigned: %s | %s",
        RemoteDispatcher:getVehicleName(vehicle), provider,
        tostring(assigned.displayName or assigned.slot or "AUTO"), tostring(task or "-")
    ))
    safeText(self.statusText, self.actionMessage or "Choose a worker on the right and Assign. Management does not change the live target.")

    if self.providerButton ~= nil then
        self.providerButton:setText("Automation: " .. tostring(provider))
    end
    if self.assignButton ~= nil then
        self.assignButton:setText("Assign: " .. tostring(selectedWorker ~= nil and selectedWorker.displayName or "AUTO"))
    end
end

function RemoteDispatcherScreen:onClickCycleProvider(sender)
    local vehicle = self:getSelectedVehicle()
    if vehicle == nil then return end

    local _, message = RemoteDispatcher:cycleProviderAssignment(vehicle, 1)
    self.actionMessage = tostring(message)
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
    self:updateDetails()
end

function RemoteDispatcherScreen:onClickAssignWorker(sender)
    local vehicle = self:getSelectedVehicle()
    local worker = self:getSelectedWorkerRow()
    if vehicle == nil or worker == nil then return end

    local success, message = RemoteDispatcher:setWorkerAssignment(vehicle, worker.slot)
    self.actionMessage = tostring(message or (success and "Worker assigned" or "Worker assignment failed"))
    if self.vehicleTable ~= nil then self.vehicleTable:reloadData() end
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
rdPrint("v" .. tostring(RemoteDispatcher.VERSION) .. " two-pane management GUI active")
