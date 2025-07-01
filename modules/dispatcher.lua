-- dispatcher.lua
local dispatcher = {
    handlers = {},
    defaultHandler = nil
}

-- Register a handler for a specific message type
function dispatcher.on(messageType, handlerFunc)
    dispatcher.handlers[messageType] = handlerFunc
end

-- Register a fallback handler for unknown message types
function dispatcher.setDefault(handlerFunc)
    dispatcher.defaultHandler = handlerFunc
end

-- Dispatch a packet to the appropriate handler
function dispatcher.dispatch(senderID, packet)
    local handler = dispatcher.handlers[packet.type]
    if handler then
        handler(senderID, packet)
    elseif dispatcher.defaultHandler then
        dispatcher.defaultHandler(senderID, packet)
    else
        print("Unhandled message type:", packet.type)
    end
end

return dispatcher
