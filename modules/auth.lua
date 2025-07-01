-- auth.lua
local auth = {}
local ecc = require("modules.ecc")
local sha256 = require("modules.sha")
local keyring = require("modules.keyring")
local userdata = require("modules.userdata")

local activeChallenges = {}
local activeSessions = {}

-- Create a new challenge string (nonce) for a public key
function auth.createChallenge(pubKey)
    local nonce = sha256(tostring(os.epoch("utc")) .. pubKey .. math.random())
    activeChallenges[pubKey] = nonce
    return nonce
end

-- Verify signature against active challenge
function auth.verify(pubKey, signature)
    local challenge = activeChallenges[pubKey]
    if not challenge then
        return false, "no challenge issued"
    end

    local valid = ecc.verify(pubKey, challenge, signature)
    if valid then
        activeChallenges[pubKey] = nil  -- invalidate after use
        return true
    else
        return false, "invalid signature"
    end
end

function auth.hasChallenge(pubKey)
    return activeChallenges[pubKey] ~= nil
end

-- Create a new session for a user ID
function auth.createSession(id)
    local user = userdata.get(id)
    if not user or not user.PrivateKey then
        return false, "no private key found for user"
    end
    local sessionKey = sha256(tostring(os.epoch("utc")) .. user.PrivateKey .. id)
    activeSessions[sessionKey] = {id=id, created=os.epoch("utc")}
    return true, sessionKey
end

-- Check if a session exists and is still valid
function auth.sessionExists(sessionKey)
    local session = activeSessions[sessionKey]
    if not session then return false, "session doesn't exist" end
    local maxAge = 30 * 60 * 1000  -- 30 minutes
    if (os.epoch("utc") - session.created) < maxAge then
        return true, session.id
    else
        activeSessions[sessionKey] = nil  -- remove expired session
        return false, "session expired"
    end
end
-- Check if session belongs to a given user
function auth.verifySession(sessionKey, id)
    if not sessionKey or not id then
        return false, "sessionKey and id are required"
    end
    local userId = activeSessions[sessionKey]
    if not userId then
        return false, "invalid session key"
    end
    if userId ~= id then
        return false, "session does not belong to this user"
    end
    return true, userId
end

-- Revoke a session key
function auth.revokeSession(sessionKey)
    activeSessions[sessionKey] = nil
    return activeSessions[sessionKey] == nil
end

-- (Optional) Get user ID from session
function auth.getUserIdFromSession(sessionKey)
    return activeSessions[sessionKey]
end

return auth