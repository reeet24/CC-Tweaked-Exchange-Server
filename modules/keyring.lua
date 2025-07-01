-- keyring.lua
local userdata = require("modules.userdata")

local keyring = {}

-- Public: Get public key from user ID
function keyring.getPublicKeyByID(id)
    local user = userdata.get(id)
    if user then
        return user.PublicKey
    end
    return nil
end

-- Public: Get public key from username
function keyring.getPublicKeyByUsername(username)
    userdata.load()
    for id, user in pairs(userdata.all()) do
        if user.Username == username then
            return user.PublicKey, id
        end
    end
    return nil, nil
end

-- Public: Check if a public key exists in the system
function keyring.publicKeyExists(pubkey)
    userdata.load()
    for _, user in pairs(userdata.all()) do
        if user.PublicKey == pubkey then
            return true
        end
    end
    return false
end

-- Public: Get user ID associated with a public key
function keyring.resolvePublicKey(pubkey)
    userdata.load()
    for id, user in pairs(userdata.all()) do
        if user.PublicKey == pubkey then
            return id
        end
    end
    return nil
end

-- Public: Verify if this public key belongs to this user ID
function keyring.verifyOwnership(id, pubkey)
    userdata.load()
    local user = userdata.get(id)
    return user and user.PublicKey == pubkey
end

return keyring
