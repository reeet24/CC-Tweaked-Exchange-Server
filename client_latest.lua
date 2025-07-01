local net = require("modules.net")
local ecc = require("modules.ecc")
net.setProtocolVersion("v1.0")
peripheral.find("modem", rednet.open)
local json = textutils

local selfPath = shell.getRunningProgram() -- or hardcoded path to client
local clientVersion = "v0.7"

local dbPath = "userdata.txt"
local UserData = {}
local sessionToken = nil

local function save(data)
    local f = fs.open(dbPath, "w")
    f.write(json.serialize(data))
    f.close()
end

-- Perform handshake
local serverID = 0 -- Replace with discovered or fixed ID

local function load()
    if fs.exists(dbPath) then
        local f = fs.open(dbPath, "r")
        local raw = f.readAll()
        f.close()
        local ok, result = pcall(json.unserialize, raw)
        if ok and type(result) == "table" then
            UserData = result
        else
            error("Failed to load userdata: corrupted format")
        end
    else
        print("No user data found. Please Enter a new username.")
        local input = io.input(io.stdin).read(io.stdin)
        local response, err = net.request(serverID, "register_user", {
            username = input
        }, 5)
        if not response then
            print("Registration failed:", err)
            return
        else
            print("Registration successful! Username:", input)
            UserData = {
                Username = input,
                PublicKey = response.publicKey,
                PrivateKey = response.privateKey
            }
            save(UserData)
        end
    end
end



local response, err = net.request(serverID, "handshake", {
    client_version = clientVersion
}, 5)

if not response then
    print("Handshake failed:", err)
    return
end

load()

local function list_peripherals()
    local response, err = net.request(serverID, "list_peripherals", {}, 5)

    if response and response.success then
        for _, p in ipairs(response.peripherals) do
            print("Peripheral:", p.name)
            print("  Type:    ", p.type)
            print("  Methods: ", table.concat(p.methods, ", "))
        end 
    else
        print("Failed to list peripherals:", err)
    end
end

if response.new_version and response.code then
    print("Update received! Writing new version...")

    local f = fs.open(selfPath, "w")
    f.write(response.code)
    f.close()

    print("Update complete. Rebooting...")
    sleep(2)
    os.reboot()
else
    print("Handshake OK:", response.message)
    -- Step 1: Get challenge
    print("Requesting challenge...")
    local response, err = net.request(serverID, "request_challenge", { publicKey = UserData.PublicKey }, 5)
    if not response then
        print("Failed to get challenge:", err or "No response from server")
        return
    end
    local challenge = response.challenge
    if not challenge then
        print("Failed to get challenge:", err or "No challenge received")
        return
    else
        print("Challenge received:", challenge)
    end
    -- Step 2: Sign challenge
    local signature = ecc.sign(UserData.PrivateKey, challenge)

    -- Step 3: Send back signed challenge
    local verify, err = net.request(serverID, "verify_signature", {
        publicKey = UserData.PublicKey,
        signature = signature
    }, 5)

    if not verify then
        print("Authentication failed:", err or "No response from server")
        return
    end

    if verify.success then
        print("Authentication successful")
        sessionToken = verify.sessionToken
        print("Session Token:", sessionToken)
    else
        print("Failed:", verify.reason)
    end
end
