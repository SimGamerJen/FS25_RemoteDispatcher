-- FS25_RemoteDispatcher v0.3.0.0
-- Support diagnostics for early alpha testing.

if RemoteDispatcher == nil then return end
RemoteDispatcher.VERSION = "0.3.0.0"

RemoteDispatcherDiagnostics = RemoteDispatcherDiagnostics or {}

local function line(text, ...)
    print("[RemoteDispatcher/Status] " .. string.format(tostring(text), ...))
end

function RemoteDispatcherDiagnostics:status()
    RemoteDispatcher:refreshVehicles()
    local hp = RemoteDispatcher.getHelperProfilesStatus ~= nil and RemoteDispatcher:getHelperProfilesStatus() or {}
    local persistence = rawget(_G, "RemoteDispatcherPersistence")
    local selected = RemoteDispatcher:getSelectedVehicle()

    line("version=%s vehicles=%d selected=%s", tostring(RemoteDispatcher.VERSION), #(RemoteDispatcher.vehicles or {}),
        selected ~= nil and RemoteDispatcher:getVehicleName(selected) or "none")
    line("AutoDrive=%s CourseplayDetected=%s HelperProfiles=%s api=%s scopedHire=%s",
        tostring(AutoDrive ~= nil),
        tostring((function()
            for _, vehicle in ipairs(RemoteDispatcher.vehicles or {}) do
                if RemoteDispatcher:hasCourseplay(vehicle) then return true end
            end
            return false
        end)()),
        tostring(hp.available == true), tostring(hp.apiVersion or 0), tostring(hp.supportsScopedPreferredHire == true))

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
