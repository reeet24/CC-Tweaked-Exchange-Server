-- periph_acl.lua
local acl = {}

-- Access control rules by peripheral name
-- Each entry is a table: [clientID] = { allowedMethods = { "list", "getItemDetail" } }
local rules = {
    ["rs_bridge_0"] = {
        ["07721100"] = { "list", "getItemDetail" }
    },
    ["inventory_manager_0"] = {
        ["07721100"] = {"*"}
    }
}

-- Internal: check if method is in list (or wildcarded)
local function isAllowed(method, allowedList)
    for _, m in ipairs(allowedList) do
        if m == "*" or m == method then
            return true
        end
    end
    return false
end

-- Public: Check if client is allowed to use method on peripheral
function acl.canCall(clientID, periphName, method)
    local periphRules = rules[periphName]
    if not periphRules then return false end

    local clientRules = periphRules[clientID]
    if not clientRules then return false end

    return isAllowed(method, clientRules)
end

-- Public: Get list of visible peripherals for a client
function acl.getVisiblePeripherals(clientID)
    local visible = {}
    for name, clients in pairs(rules) do
        if clients[clientID] then
            table.insert(visible, {
                name = name,
                type = peripheral.getType(name),
                methods = clients[clientID]
            })
        end
    end
    return visible
end

return acl
