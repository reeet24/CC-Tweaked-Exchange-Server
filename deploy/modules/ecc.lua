-- ecc.lua
local ecc = {}
local sha256 = require("modules.sha")

-- Generate pseudo ECC keys using randomness + SHA256
function ecc.generateKeyPair()
    local entropy = tostring(os.epoch("utc")) .. math.random()
    local private = sha256(entropy)
    local public = sha256(private)
    return { public = public, private = private }
end

-- Simulate signing using HMAC(public ← message)
function ecc.sign(private, message)
    local combined = private .. "::" .. message
    return sha256(combined)
end

-- Simulate verifying by comparing public key hash to reconstructed signature
function ecc.verify(public, message, signature)
    -- In our model, public = sha256(private), so reverse-simulate
    local guessSig = sha256(public .. "::" .. message)
    return guessSig == signature
end

return ecc
