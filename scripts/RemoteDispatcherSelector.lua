-- FS25_RemoteDispatcher v0.2.2.0
-- Lightweight in-game target selector, styled after HelperProfiles' measured HUD table.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] Selector loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.2.2.0"
RemoteDispatcher.selectorVisible = RemoteDispatcher.selectorVisible == true
RemoteDispatcher.selectorActionEventIds = RemoteDispatcher.selectorActionEventIds or {}

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function safeGetTextWidth(size, text)
    text = tostring(text or "")
    if getTextWidth ~= nil then
        local ok, width = pcall(getTextWidth, size, text)
        if ok and type(width) == "number" then return width end
    end
    return #text * size * 0.52
end

local function safeRect(x, y, width, height, r, g, b, a)
    if drawFilledRect ~= nil then
        drawFilledRect(x, y, width, height, r, g, b, a)
        return true
    end
    return false
end

local function fitText(text, size, maximumWidth)
    text = tostring(text or "")
    if safeGetTextWidth(size, text) <= maximumWidth then return text end
    local suffix = "..."
    local value = text
    while #value > 1 and safeGetTextWidth(size, value .. suffix) > maximumWidth do
        value = string.sub(value, 1, #value - 1)
    end
    return value .. suffix
end

local function measureColumns(columnKeys, headers, rows, fontSize, gap)
    local widths = {}
    local total = 0
    for _, key in ipairs(columnKeys) do
        widths[key] = safeGetTextWidth(fontSize, headers[key] or "")
        for _, row in ipairs(rows or {}) do
            widths[key] = math.max(widths[key], safeGetTextWidth(fontSize, row[key] or ""))
        end
        total = total + widths[key]
    end
    if #columnKeys > 1 then total = total + gap * (#columnKeys - 1) end
    return widths, total
end

local function buildColumnPositions(left, columnKeys, widths, gap)
    local positions = {}
    local x = left
    for _, key in ipairs(columnKeys) do
        positions[key] = x
        x = x + (widths[key] or 0) + gap
    end
    return positions
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

    if self.vehicles == nil or #self.vehicles == 0 then self:refreshVehicles() end

    local maxRows = 8
    local startRow = 1
    local endRow = math.min(#self.vehicles, maxRows)
    if #self.vehicles > maxRows then
        startRow = math.max(1, self.selectedIndex - math.floor(maxRows / 2))
        endRow = math.min(#self.vehicles, startRow + maxRows - 1)
        if endRow - startRow + 1 < maxRows then startRow = math.max(1, endRow - maxRows + 1) end
    end

    local rows = {}
    for i = startRow, endRow do
        local vehicle = self.vehicles[i]
        local selected = i == self.selectedIndex
        local provider = self:getProviderAssignment(vehicle) or "-"
        local worker = self:getWorkerAssignmentData(vehicle)
        rows[#rows + 1] = {
            marker = selected and "»" or "",
            vehicle = self:getVehicleName(vehicle),
            auto = provider,
            worker = tostring(worker.displayName or worker.slot or "AUTO"),
            state = self:getProviderStatus(vehicle, provider),
            selected = selected
        }
    end

    local selectedVehicle = self:getSelectedVehicle()
    local selectedProvider = selectedVehicle ~= nil and (self:getProviderAssignment(selectedVehicle) or "-") or "-"
    local selectedWorker = selectedVehicle ~= nil and self:getWorkerAssignmentData(selectedVehicle) or {displayName = "-"}
    local selectedState = selectedVehicle ~= nil and self:getProviderStatus(selectedVehicle, selectedProvider) or "-"
    local selectedName = selectedVehicle ~= nil and self:getVehicleName(selectedVehicle) or "None"

    local detail = "No compatible vehicles found."
    if selectedVehicle ~= nil then
        if selectedProvider == "AD" then
            detail = "Route: " .. tostring(self:getAutoDriveDestinationText(selectedVehicle) or "-")
        elseif selectedProvider == "CP" then
            detail = "Course: " .. tostring(self:getCourseplayCourseText(selectedVehicle) or "-")
        else
            detail = "Task: -"
        end
    end

    local title = "REMOTE DISPATCHER"
    local summary = string.format(
        "Target: %s   |   %s   |   %s   |   %s",
        selectedName,
        selectedProvider,
        tostring(selectedWorker.displayName or selectedWorker.slot or "AUTO"),
        selectedState
    )
    local footer = "- previous   |   = next   |   Ctrl+Alt+R start/stop"

    local fontSize = 0.0130
    local headerSize = 0.0105
    local titleSize = 0.0150
    local metaSize = 0.0115
    local pad = 0.006
    local rowGap = 0.005
    local columnGap = 0.010
    local lineHeight = fontSize + rowGap
    local maxWidth = 0.58

    local columnKeys = {"marker", "vehicle", "auto", "worker", "state"}
    local headers = {marker = "", vehicle = "VEHICLE", auto = "AUTO", worker = "WORKER", state = "STATE"}
    local widths, tableWidth = measureColumns(columnKeys, headers, rows, fontSize, columnGap)
    widths.marker = math.max(widths.marker or 0, safeGetTextWidth(fontSize, "»"))
    tableWidth = 0
    for _, key in ipairs(columnKeys) do tableWidth = tableWidth + (widths[key] or 0) end
    tableWidth = tableWidth + columnGap * (#columnKeys - 1)

    local contentWidth = math.max(
        tableWidth,
        safeGetTextWidth(metaSize, summary),
        safeGetTextWidth(metaSize, detail),
        safeGetTextWidth(metaSize, footer),
        safeGetTextWidth(titleSize, title)
    )
    local width = clamp(contentWidth + pad * 2, 0.285, maxWidth)
    local innerWidth = width - pad * 2

    summary = fitText(summary, metaSize, innerWidth)
    detail = fitText(detail, metaSize, innerWidth)
    footer = fitText(footer, metaSize, innerWidth)

    local rowCount = math.max(1, #rows)
    local titleGap = 0.006
    local sectionGap = 0.004
    local height = pad * 2
        + titleSize + titleGap
        + metaSize + sectionGap
        + headerSize + rowGap
        + rowCount * lineHeight
        + sectionGap + metaSize
        + sectionGap + metaSize

    local left = 0.025
    local top = 0.795
    local bottom = top - height

    if not safeRect(left, bottom, width, height, 0.02, 0.02, 0.02, 0.46) then
        if self.backgroundOverlay == nil and createImageOverlay ~= nil then
            self.backgroundOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
        end
        if self.backgroundOverlay ~= nil and self.backgroundOverlay ~= 0 then
            setOverlayColor(self.backgroundOverlay, 0.02, 0.02, 0.02, 0.46)
            renderOverlay(self.backgroundOverlay, left, bottom, width, height)
        end
    end

    local x = left + pad
    local y = top - pad - titleSize

    self:drawTextLine(x, y, titleSize, title, 1.0, 0.78, 0.18, 1.0)
    y = y - titleGap - metaSize
    self:drawTextLine(x, y, metaSize, summary, 0.92, 0.92, 0.92, 1.0)
    y = y - sectionGap - headerSize

    local positions = buildColumnPositions(x, columnKeys, widths, columnGap)
    for _, key in ipairs(columnKeys) do
        self:drawColumnText(positions[key], y, headerSize, headers[key], false, true)
    end
    y = y - rowGap - fontSize

    if #rows == 0 then
        self:drawTextLine(x, y, fontSize, "No compatible vehicles found.", 0.93, 0.93, 0.93, 1.0)
        y = y - lineHeight
    else
        for _, row in ipairs(rows) do
            if row.selected then
                safeRect(left + 0.002, y - 0.002, width - 0.004, lineHeight, 0.38, 0.52, 0.05, 0.32)
            end
            for _, key in ipairs(columnKeys) do
                self:drawColumnText(positions[key], y, fontSize, row[key], row.selected, false)
            end
            y = y - lineHeight
        end
    end

    y = y - sectionGap
    self:drawTextLine(x, y, metaSize, detail, 0.65, 0.85, 1.0, 1.0)
    y = y - metaSize - sectionGap
    self:drawTextLine(x, y, metaSize, footer, 0.78, 0.78, 0.78, 1.0)

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

Logging.info("[RemoteDispatcher] v%s measured active selector UI loaded", RemoteDispatcher.VERSION)
