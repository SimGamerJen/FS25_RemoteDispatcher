-- FS25_RemoteDispatcher v0.2.0.0
-- Keep legacy backend isOpen guards aligned with the modal dispatcher GUI.

if RemoteDispatcher == nil or RemoteDispatcherGui == nil or RemoteDispatcherScreen == nil then
    return
end

local previousGuiOpen = RemoteDispatcherGui.open
function RemoteDispatcherGui:open(...)
    local opened = previousGuiOpen(self, ...)
    if opened then RemoteDispatcher.isOpen = true end
    return opened
end

local previousScreenClose = RemoteDispatcherScreen.onClose
function RemoteDispatcherScreen:onClose(...)
    RemoteDispatcher.isOpen = false
    return previousScreenClose(self, ...)
end
