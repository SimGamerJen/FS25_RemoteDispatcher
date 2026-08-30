-- FS25_RemoteDispatcher v0.2.1.0
-- Lightweight in-game selector. Management configures; selector targets; Ctrl+Alt+R dispatches.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Selector loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.1.0"
RemoteDispatcher.selectorVisible = RemoteDispatcher.selectorVisible == true
RemoteDispatcher.selectorActionEventIds = RemoteDispatcher.selectorActionEventIds or {}

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

function RemoteDispatcher:onToggleSelector(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end
    self.selectorVisible = not self.selectorVisible
    if self.selectorVisible then
        self:refreshVehicles()
        if not self.selectionInitialized and self.selectNearestVehicle ~= nil then
            self:selectNearestVehicle()
            self.selectionInitialized = true
        else
            self:normalizeProvider()
        end
    end
end

function RemoteDispatcher:onOpenManagement(actionName, inputValue)
    if (inputValue or 0) <= 0 then return end
    if RemoteDispatcherGui ~= nil then RemoteDispatcherGui:open() end
end

function RemoteDispatcher:onCycleTarget(actionName, inputValue)
    if (inputValue or 0) <= 0 or not self.selectorVisible then return end
    self:selectRelative(1)
    self:normalizeProvider()
end

function RemoteDispatcher:onCycleTargetPrevious(actionName, inputValue)
    if (inputValue or 0) <= 0 or not self.selectorVisible then return end
    self:selectRelative(-1)
    self:normalizeProvider()
end

function RemoteDispatcher:registerActionEvents()
    if g_inputBinding == nil then return end
    g_inputBinding:removeActionEventsByTarget(self)
    self.actionEventIds = {}

    local function register(actionName, callback, textKey, visible)
        local actionId = InputAction ~= nil and InputAction[actionName] or nil
        if actionId == nil then
            rdWarn("Input action %s was not registered by modDesc.xml", tostring(actionName))
            return
        end
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

    register("RDC_TOGGLE_SELECTOR", self.onToggleSelector, "input_RDC_TOGGLE_SELECTOR", true)
    register("RDC_OPEN_MANAGEMENT", self.onOpenManagement, "input_RDC_OPEN_MANAGEMENT", true)
    register("RDC_CYCLE_TARGET", self.onCycleTarget, "input_RDC_CYCLE_TARGET", false)
    register("RDC_CYCLE_TARGET_PREVIOUS", self.onCycleTargetPrevious, "input_RDC_CYCLE_TARGET_PREVIOUS", false)
    register("RDC_REMOTE_ACTION", self.onRemoteAction, "input_RDC_REMOTE_ACTION", true)
end

function RemoteDispatcher:draw()
    if not self.selectorVisible then return end
    if self.isMainHudVisible ~= nil and not self:isMainHudVisible() then return end
    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil then
        local ok, visible = pcall(function() return g_gui:getIsGuiVisible() end)
        if ok and visible then return end
    end

    -- Keep the list fresh enough to reflect newly active/stopped vehicles without
    -- allowing proximity to change the retained target.
    if self.vehicles == nil or #self.vehicles == 0 then self:refreshVehicles() end

    if self.backgroundOverlay == nil and createImageOverlay ~= nil then
        self.backgroundOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    local x = 0.026
    local topY = 0.770
    local width = 0.455
    local rowHeight = 0.022
    local maxRows = 6
    local visibleRows = math.min(#self.vehicles, maxRows)
    local height = 0.128 + visibleRows * rowHeight

    if self.backgroundOverlay ~= nil and self.backgroundOverlay ~= 0 then
        setOverlayColor(self.backgroundOverlay, 0.02, 0.02, 0.02, 0.84)
        renderOverlay(self.backgroundOverlay, x - 0.010, topY - height + 0.010, width, height)
    end

    local y = topY
    self:drawTextLine(x, y, 0.020, "REMOTE DISPATCHER", 1.0, 0.78, 0.18, 1.0)
    y = y - 0.030

    local colVehicle = x
    local colAuto = x + 0.170
    local colWorker = x + 0.225
    local colState = x + 0.315

    self:drawColumnText(colVehicle, y, 0.0105, "VEHICLE", false, true)
    self:drawColumnText(colAuto, y, 0.0105, "AUTO", false, true)
    self:drawColumnText(colWorker, y, 0.0105, "WORKER", false, true)
    self:drawColumnText(colState, y, 0.0105, "STATE", false, true)
    y = y - 0.020

    if #self.vehicles == 0 then
        self:drawTextLine(x, y, 0.014, "No compatible vehicles found.", 0.93, 0.93, 0.93, 1.0)
        y = y - rowHeight
    else
        local startRow = math.max(1, self.selectedIndex - math.floor(maxRows / 2))
        local endRow = math.min(#self.vehicles, startRow + maxRows - 1)
        if endRow - startRow + 1 < maxRows then startRow = math.max(1, endRow - maxRows + 1) end

        for i = startRow, endRow do
            local vehicle = self.vehicles[i]
            local selected = i == self.selectedIndex
            local provider = self:getProviderAssignment(vehicle) or "-"
            local worker = self:getWorkerAssignmentData(vehicle)
            local status = self:getProviderStatus(vehicle, provider)
            local vehicleText = (selected and "> " or "  ") .. self:getVehicleName(vehicle)

            self:drawColumnText(colVehicle, y, 0.0135, vehicleText, selected, false)
            self:drawColumnText(colAuto, y, 0.0125, provider, selected, false)
            self:drawColumnText(colWorker, y, 0.0125, tostring(worker.displayName or worker.slot or "AUTO"), selected, false)
            self:drawColumnText(colState, y, 0.0125, status, selected, false)
            y = y - rowHeight
        end
    end

    local vehicle = self:getSelectedVehicle()
    if vehicle ~= nil then
        local provider = self:getProviderAssignment(vehicle) or "-"
        local detail = "-"
        if provider == "AD" then detail = self:getAutoDriveDestinationText(vehicle) or "-"
        elseif provider == "CP" then detail = self:getCourseplayCourseText(vehicle) or "-" end
        y = y - 0.004
        self:drawTextLine(x, y, 0.0135, "TARGET: " .. self:getVehicleName(vehicle) .. "  ->  " .. detail, 0.65, 0.85, 1.0, 1.0)
    end

    y = y - 0.026
    self:drawTextLine(x, y, 0.011, "= next   - previous   Ctrl+Alt+R start/stop", 0.78, 0.78, 0.78, 1.0)

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

Logging.info("[RemoteDispatcher] v%s active selector UI loaded", RemoteDispatcher.VERSION)
