-- net.lua
local json = textutils

local net = {}

local PROTOCOL = "exchange"
local localVersion = "v1.0"

-- Set the protocol version for this endpoint
function net.setProtocolVersion(version)
    localVersion = version
end

-- Return current protocol version
function net.getProtocolVersion()
    return localVersion
end

-- Internal: Wrap a message with metadata
local function wrapPacket(messageType, data, messageID)
    return {
        type = messageType,
        data = data,
        id = messageID or nil,
        version = localVersion
    }
end

-- Send a message to a specific peer
function net.send(targetID, messageType, data, messageID)
    local packet = wrapPacket(messageType, data, messageID)
    rednet.send(targetID, json.serialize(packet), PROTOCOL)
end

-- Broadcast a message to all peers
function net.broadcast(messageType, data)
    local packet = wrapPacket(messageType, data)
    rednet.broadcast(json.serialize(packet), PROTOCOL)
end

-- Wait for a valid message of a given type (or all types if nil)
function net.receive(filterType, timeout)
    local timer = nil
    if timeout then
        timer = os.startTimer(timeout)
    end

    while true do
        local event, id, msg, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == PROTOCOL then
            local ok, packet = pcall(json.unserialize, msg)
            if ok and type(packet) == "table" and packet.type and packet.version then
                if packet.version ~= localVersion then
                    -- Optionally respond with error
                    net.send(id, "protocol_mismatch", {
                        expected = localVersion,
                        received = packet.version
                    }, packet.id)
                else
                    if not filterType or packet.type == filterType then
                        return id, packet
                    end
                end
            end
        elseif event == "timer" and id == timer then
            return nil, "timeout"
        end
    end
end

-- Request-response helper with version check
function net.request(targetID, messageType, data, timeout)
    local id = tostring(math.random(1000000, 9999999))
    net.send(targetID, messageType, data, id)
    local deadline = os.clock() + (timeout or 5)

    while os.clock() < deadline do
        local sender, packet = net.receive(nil, deadline - os.clock())
        if packet then
            if packet.id == id and packet.type == "response" then
                return packet.data
            elseif packet.type == "protocol_mismatch" then
                return nil, "protocol mismatch: expected " .. packet.data.expected .. ", got " .. packet.data.received
            end
        end
    end
    return nil, "timeout"
end

-- Respond to a valid request
function net.respond(targetID, requestID, responseData)
    net.send(targetID, "response", responseData, requestID)
end

return net
