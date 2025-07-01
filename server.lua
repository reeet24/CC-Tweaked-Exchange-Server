local net = require("modules.net")
local dispatcher = require("modules.dispatcher")
local scan = require("modules.periphscan")
local acl = require("modules.periph_acl")
local ecc = require("modules.ecc")
local users = require("modules.userdata")
local auth = require("modules.auth")
local keyring = require("modules.keyring")

net.setProtocolVersion("v1.0")
rednet.open("right")

local latestClientVersion = "v0.7"
local latestClientPath = "/client_latest.lua"
local latestClientCode = ""

-- Preload latest client code
do
    local f = fs.open(latestClientPath, "r")
    if f then
        latestClientCode = f.readAll()
        f.close()
    else
        error("Missing client_latest.lua")
    end
end

local function hash8(s)
    local hash = 5381
    for i = 1, #s do
        local c = s:byte(i)
        hash = ((hash * 33) % 4294967296 + c) % 4294967296
    end
    return string.format("%08d", hash % 100000000)
end

-- === Handshake: Client Version Control ===
dispatcher.on("handshake", function(sender, packet)
    local version = packet.data.client_version
    print("Handshake from", sender, "version", version)
    if version ~= latestClientVersion then
        print("Client outdated. Sending update.")
        net.send(sender, "response", {
            new_version = latestClientVersion,
            code = latestClientCode
        }, packet.id)
    else
        net.respond(sender, packet.id, {
            status = "ok",
            message = "Welcome, client up-to-date."
        })
    end
end)

-- === User Registration and Key Exchange ===
dispatcher.on("register_user", function(sender, packet)
    local username = packet.data.username
    local keys = ecc.generateKeyPair()
    local publicKey = keys.public
    local privateKey = keys.private

    if not username then
        net.respond(sender, packet.id, {
            success = false,
            error = "Missing 'username'"
        })
        return
    end

    if users.exists(username) then
        net.respond(sender, packet.id, {
            success = false,
            error = "Username already registered"
        })
        return
    end

    -- Register user and store public and private key
    users.set(hash8(username), username, "", publicKey, privateKey)

    net.respond(sender, packet.id, {
        success = true,
        message = "User registered successfully",
        publicKey = publicKey,
        privateKey = privateKey
    })
end)

dispatcher.on("request_challenge", function(sender, packet)
    local pubKey = packet.data.publicKey
    if pubKey == nil then
        net.respond(sender, packet.id, {
            success = false,
            error = "Missing 'publicKey'"
        })
        return
    end
    print("Challenge requested by", sender, "for public key:", pubKey)
    local challenge = auth.createChallenge(packet.data.publicKey)
    net.respond(sender, packet.id, { challenge = challenge })
end)

dispatcher.on("verify_signature", function(sender, packet)
    local pubKey = packet.data.publicKey
    local signature = packet.data.signature

    local valid, reason = auth.verify(pubKey, signature)

    if not valid then
        print("Signature verification failed for", sender, ":", reason)
        net.respond(sender, packet.id, {
            success = false,
            reason = reason
        })
        return
    else
        print("Signature verified for", sender)
        local userId = keyring.resolvePublicKey(pubKey)
        if not userId then
            net.respond(sender, packet.id, {
                success = false,
                reason = "Public key not registered"
            })
            return
        end
        local success, response = auth.createSession(userId)
        if not success then
            net.respond(sender, packet.id, {
                success = false,
                reason = "Failed to create session: " .. response
            })
            return
        else
            print("Session created for", sender)
            net.respond(sender, packet.id, {
                success = valid,
                sessionToken = response,
                message = "Signature verified and session created"
            })
        end
    end
end)

-- === Ping ===
dispatcher.on("ping", function(sender, packet)
    if not packet.data then
        net.respond(sender, packet.id, {
            status = "error",
            message = "Timestamp missing in ping request"
        })
        return
    elseif not packet.data.time then
        net.respond(sender, packet.id, {
            status = "error",
            message = "Timestamp missing in ping request"
        })
        return
    elseif type(packet.data.time) ~= "number" then
        net.respond(sender, packet.id, {
            status = "error",
            message = "Invalid timestamp type in ping request"
        })
        return
    elseif os.epoch("utc") - packet.data.time > 5000 then
        net.respond(sender, packet.id, {
            status = "error",
            message = "Ping request timed out"
        })
        return
    end
    local pingTime = os.epoch("utc") - packet.data.time
    print("Ping received from", sender, "in", pingTime, "ms")

    local pingStatus = "Ping successful in " .. pingTime .. " ms"

    net.respond(sender, packet.id, {
        status = pingStatus,
        message = "Pong from server!"
    })
end)

-- === Client Peripheral Call via Wired Modem ===
dispatcher.on("list_peripherals", function(sender, packet)
    local sessionKey = packet.data.sessionKey
    local userId = keyring.resolvePublicKey(packet.data.publicKey)
    if not userId then
        net.respond(sender, packet.id, {
            success = false,
            error = "Invalid public key"
        })
        return
    end
    local valid, sessionId = auth.sessionExists(sessionKey)
    if not valid then
        net.respond(sender, packet.id, {
            success = false,
            error = sessionId or "Session expired or invalid"
        })
        return
    end
    local visible = acl.getVisiblePeripherals(userId)
    net.respond(sender, packet.id, {
        success = true,
        peripherals = visible
    })
end)

dispatcher.on("call_peripheral", function(sender, packet)
    local target = packet.data.target
    local method = packet.data.method
    local args = packet.data.args or {}

    if not target or not method then
        net.respond(sender, packet.id, {
            success = false,
            error = "Missing 'target' or 'method'"
        })
        return
    end

    if not peripheral.isPresent(target) then
        net.respond(sender, packet.id, {
            success = false,
            error = "Peripheral '" .. target .. "' not found"
        })
        return
    end

    if not acl.canCall(sender, target, method) then
        net.respond(sender, packet.id, {
            success = false,
            error = "Access denied to '" .. method .. "' on " .. target
        })
        return
    end

    local ok, result = pcall(peripheral.call, target, method, table.unpack(args))
    if ok then
        net.respond(sender, packet.id, {
            success = true,
            result = result
        })
    else
        net.respond(sender, packet.id, {
            success = false,
            error = "Call failed: " .. result
        })
    end
end)

-- === Fallback for Unknown Message Types ===
dispatcher.setDefault(function(sender, packet)
    print("Unknown type from", sender, ":", packet.type)
end)

-- === Main Loop ===
while true do
    local sender, packet = net.receive()
    dispatcher.dispatch(sender, packet)
end
