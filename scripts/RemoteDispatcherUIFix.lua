-- FS25_RemoteDispatcher v0.1.0.3
-- Persistent remote target UI/input/HUD integration layer.

if RemoteDispatcher == nil then
    Logging.error("[RemoteDispatcher] v0.1.0.3 UI fix loaded before RemoteDispatcher.lua")
    return
end

RemoteDispatcher.VERSION = "0.1.0.3"
RemoteDispatcher._lastRawInputAt = RemoteDispatcher._lastRawInputAt or 0

local function rdWarn(fmt, ...)
    Logging.warning("[RemoteDispatcher] " .. fmt, ...)
end

local function rdCall(object, methodName, ...)
    if object == nil or object[methodName] == nil then return false, nil end
    local args = {...}
    local ok, result = pcall(function()
        return object[methodName](object, unpack(args))
    end)
    if not ok then
        rdWarn("%s failed: %s", tostring(methodName), tostring(result))
        return false, nil
    end
    return true, result
end

-- Compatibility helpers so a repository checkout works with the original
-- controller as well as the packaged 0.1.0.2 controller.
function RemoteDispatcher:getCourseplayCourseText(vehicle)
    if vehicle == nil then return nil end
    if vehicle.getCurrentCpCourseName ~= nil then
        local ok, name = rdCall(vehicle, "getCurrentCpCourseName")
        if ok and name ~= nil and name ~= "" then return tostring(name) end
    end
    if self.getCourseplayDetail ~= nil then
        local ok, value = pcall(self.getCourseplayDetail, self, vehicle)
        if ok then return value end
    end
    return nil
end

function RemoteDispatcher:getProviderStatus(vehicle, provider)
    if provider == "AD" then
        if self:isAutoDriveActive(vehicle) then return "ACTIVE" end
        if self:isAutoDriveReady(vehicle) then return "READY" end
        return "NOT READY"
    elseif provider == "CP" then
        if self:isCourseplayActive(vehicle) then return "ACTIVE" end
        if self:isCourseplayReady(vehicle) then return "READY" end
        return "NOT READY"
    end
    return "N/A"
end

function RemoteDispatcher:drawTextLine(x, y, size, text, r, g, b, a)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(r or 1, g or 1, b or 1, a or 1)
    renderText(x, y, size, tostring(text or ""))
end

-- The selected vehicle is already retained by the 0.1.0.2 discovery layer.
-- Distance is display-only: no remote action checks player-to-vehicle range.

function RemoteDispatcher:isMainHudVisible()
    if g_currentMission == nil or g_currentMission.hud == nil then return false end

    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil then
        local ok, visible = pcall(function() return g_gui:getIsGuiVisible() end)
        if ok and visible then return false end
    end

    local hud = g_currentMission.hud

    for _, methodName in ipairs({"getIsVisible", "getVisible"}) do
        if hud[methodName] ~= nil then
            local ok, visible = rdCall(hud, methodName)
            if ok and visible ~= nil then return visible == true end
        end
    end

    for _, fieldName in ipairs({"isVisible", "visible"}) do
        if hud[fieldName] ~= nil then return hud[fieldName] == true end
    end

    -- Standard FS25 hide-HUD also hides GameInfoDisplay, making it a useful
    -- fallback when the HUD root itself has no public visibility accessor.
    local gameInfoDisplay = hud.gameInfoDisplay
    if gameInfoDisplay ~= nil and gameInfoDisplay.getVisible ~= nil then
        local ok, visible = rdCall(gameInfoDisplay, "getVisible")
        if ok and visible ~= nil then return visible == true end
    end

    return true
end

-- Only global open/close and cinematic remote trigger remain ordinary FS25
-- actions. Up/Down/Left/Right/Enter are captured directly while the panel is
-- visible, avoiding gameplay/action-context conflicts.
function RemoteDispatcher:registerActionEvents()
    if g_inputBinding == nil then return end

    g_inputBinding:removeActionEventsByTarget(self)
    self.actionEventIds = {}

    local function register(actionName, callback, textKey, visible)
        local actionId = InputAction ~= nil and InputAction[actionName] or actionName
        if actionId == nil then
            rdWarn("Input action %s was not registered by modDesc.xml", tostring(actionName))
            return
        end

        local ok, eventId = g_inputBinding:registerActionEvent(
            actionId, self, callback, false, true, false, true
        )
        if ok and eventId ~= nil then
            table.insert(self.actionEventIds, eventId)
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

function RemoteDispatcher:keyEvent(unicode, sym, modifier, isDown)
    if not isDown or not self.isOpen or Input == nil then return false end
    if not self:isMainHudVisible() then return false end

    local now = g_time or 0
    if now - (self._lastRawInputAt or 0) < 80 then return false end

    local used = false
    if sym == Input.KEY_up then
        self:selectRelative(-1)
        used = true
    elseif sym == Input.KEY_down then
        self:selectRelative(1)
        used = true
    elseif sym == Input.KEY_left or sym == Input.KEY_right then
        self:switchProvider()
        used = true
    elseif sym == Input.KEY_return
        or (Input.KEY_KP_enter ~= nil and sym == Input.KEY_KP_enter) then
        self.selectionInitialized = true
        self:executeSelected()
        used = true
    end

    if used then
        self._lastRawInputAt = now
        return true
    end
    return false
end

function RemoteDispatcher:drawColumnText(x, y, size, text, selected, muted)
    setTextAlignment(RenderText.ALIGN_LEFT)
    if selected then
        setTextColor(1.0, 0.82, 0.20, 1.0)
    elseif muted then
        setTextColor(0.72, 0.72, 0.72, 1.0)
    else
        setTextColor(0.93, 0.93, 0.93, 1.0)
    end
    renderText(x, y, size, tostring(text or ""))
end

function RemoteDispatcher:draw()
    if not self.isOpen or not self:isMainHudVisible() then return end

    if self.backgroundOverlay == nil and createImageOverlay ~= nil then
        self.backgroundOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    local x = 0.025
    local topY = 0.765
    local panelWidth = 0.585
    local rowHeight = 0.023
    local maxRows = 10
    local visibleRows = math.min(#self.vehicles, maxRows)
    local panelHeight = 0.150 + visibleRows * rowHeight

    if self.backgroundOverlay ~= nil and self.backgroundOverlay ~= 0 then
        setOverlayColor(self.backgroundOverlay, 0.02, 0.02, 0.02, 0.86)
        renderOverlay(self.backgroundOverlay, x - 0.010, topY - panelHeight + 0.010, panelWidth, panelHeight)
    end

    local colVehicle = x
    local colMode = x + 0.190
    local colStatus = x + 0.255
    local colTarget = x + 0.335
    local colDistance = x + 0.535

    local y = topY
    self:drawTextLine(x, y, 0.021, "REMOTE DISPATCHER", 1.0, 0.78, 0.18, 1.0)
    y = y - 0.031

    self:drawColumnText(colVehicle, y, 0.011, "VEHICLE", false, true)
    self:drawColumnText(colMode, y, 0.011, "AUTO", false, true)
    self:drawColumnText(colStatus, y, 0.011, "STATE", false, true)
    self:drawColumnText(colTarget, y, 0.011, "TARGET / COURSE", false, true)
    self:drawColumnText(colDistance, y, 0.011, "DIST", false, true)
    y = y - 0.021

    if #self.vehicles == 0 then
        self:drawTextLine(x, y, 0.015, "No owned AutoDrive/Courseplay-capable vehicles found.", 0.93, 0.93, 0.93, 1.0)
        y = y - rowHeight
    else
        local startRow = math.max(1, self.selectedIndex - math.floor(maxRows / 2))
        local endRow = math.min(#self.vehicles, startRow + maxRows - 1)
        if endRow - startRow + 1 < maxRows then
            startRow = math.max(1, endRow - maxRows + 1)
        end

        for i = startRow, endRow do
            local vehicle = self.vehicles[i]
            local providers = self:getProviders(vehicle)
            local selected = i == self.selectedIndex
            local rowProvider = selected and self.selectedProvider or providers[1]
            local providerText = table.concat(providers, "/")
            local status = self:getProviderStatus(vehicle, rowProvider)
            local detail = "-"
            if rowProvider == "AD" then
                detail = self:getAutoDriveDestinationText(vehicle) or "-"
            elseif rowProvider == "CP" then
                detail = self:getCourseplayCourseText(vehicle) or "-"
            end

            local distance = self:getVehicleDistance(vehicle)
            local distanceText = distance ~= nil and string.format("%.0fm", distance) or "-"
            local vehicleText = (selected and "> " or "  ") .. self:getVehicleName(vehicle)

            self:drawColumnText(colVehicle, y, 0.014, vehicleText, selected, false)
            self:drawColumnText(colMode, y, 0.013, providerText, selected, false)
            self:drawColumnText(colStatus, y, 0.013, status, selected, false)
            self:drawColumnText(colTarget, y, 0.013, detail, selected, false)
            self:drawColumnText(colDistance, y, 0.013, distanceText, selected, false)
            y = y - rowHeight
        end
    end

    y = y - 0.006
    local selectedVehicle = self:getSelectedVehicle()
    if selectedVehicle ~= nil then
        local distance = self:getVehicleDistance(selectedVehicle)
        local distanceText = distance ~= nil and string.format("%.0fm away", distance) or "distance unknown"
        self:drawTextLine(
            x, y, 0.014,
            string.format("TARGET  %s   |   %s   |   %s", self:getVehicleName(selectedVehicle), tostring(self.selectedProvider or "-"), distanceText),
            0.65, 0.85, 1.0, 1.0
        )
    end

    y = y - 0.026
    self:drawTextLine(
        x, y, 0.0115,
        "Up/Down Select    Left/Right AD/CP    Enter Start/Stop    Ctrl+Alt+R Remote    Ctrl+Alt+D Close",
        0.78, 0.78, 0.78, 1.0
    )

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

Logging.info("[RemoteDispatcher] v%s UI/input/HUD integration active", RemoteDispatcher.VERSION)
