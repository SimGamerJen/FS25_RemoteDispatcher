-- FS25_RemoteDispatcher v0.3.0.1
-- Support diagnostics for early alpha testing.

if RemoteDispatcher == nil then return end
RemoteDispatcher.VERSION = "0.3.0.1"

RemoteDispatcherDiagnostics = RemoteDispatcherDiagnostics or {}

local function line(text, ...)
    print("[RemoteDispatcher/Status] " .. string.format(tostring(text), ...))
end

function RemoteDispatcherDiagnostics:status()
    RemoteDispatcher:refreshVehicles()
    local hp = RemoteDispatcher.getHelperProfilesStatus ~= nil and RemoteDispatcher:getHelperProfilesStatus() or {}
    local persistence = rawget(_G, "RemoteDispatcherPersistence")
    local selected = RemoteDispatcher:getSelectedVehicle()

    local autoDriveCount = 0
    local courseplayCount = 0
    for _, vehicle in ipairs(RemoteDispatcher.vehicles or {}) do
        if RemoteDispatcher:hasAutoDrive(vehicle) then autoDriveCount = autoDriveCount + 1 end
        if RemoteDispatcher:hasCourseplay(vehicle) then courseplayCount = courseplayCount + 1 end
    end

    line("version=%s vehicles=%d selected=%s", tostring(RemoteDispatcher.VERSION), #(RemoteDispatcher.vehicles or {}),
        selected ~= nil and RemoteDispatcher:getVehicleName(selected) or "none")
    line("AutoDriveDetected=%s AutoDriveVehicles=%d AutoDriveGlobal=%s CourseplayDetected=%s CourseplayVehicles=%d HelperProfiles=%s api=%s scopedHire=%s vehicleInputHook=%s",
        tostring(autoDriveCount > 0), autoDriveCount, tostring(AutoDrive ~= nil),
        tostring(courseplayCount > 0), courseplayCount,
        tostring(hp.available == true), tostring(hp.apiVersion or 0), tostring(hp.supportsScopedPreferredHire == true),
        tostring(RemoteDispatcher.vehicleInputHookInstalled == true))

    if persistence ~= nil then
        line("savegame=%s stateFile=%s records=%d selectedId=%s",
            tostring(persistence.savegameName), tostring(persistence.stateFile),
            persistence:getRecordCount(), tostring(persistence.selectedVehicleId or "none"))
    end

    for index, vehicle in ipairs(RemoteDispatcher.vehicles or {}) do
        local provider = RemoteDispatcher:getProviderAssignment(vehicle) or "-"
        local worker = RemoteDispatcher:getWorkerAssignmentData(vehicle)
        local uniqueId = persistence ~= nil and persistence:getVehicleId(vehicle) or "?"
        line("%s%02d name='%s' id=%s provider=%s worker=%s state=%s",
            index == RemoteDispatcher.selectedIndex and ">" or " ", index,
            RemoteDispatcher:getVehicleName(vehicle), tostring(uniqueId), tostring(provider),
            tostring(worker.displayName or worker.slot or "AUTO"),
            RemoteDispatcher:getProviderStatus(vehicle, provider))
    end
    return "Remote Dispatcher status written to log"
end

if addConsoleCommand ~= nil then
    addConsoleCommand("rdStatus", "Print Remote Dispatcher alpha diagnostics", "status", RemoteDispatcherDiagnostics)
end

line("v%s diagnostics ready (console: rdStatus)", RemoteDispatcher.VERSION)
