-- remote.lua
local remote = {
    cache = {},
    alias = {}
}

-- Clear cache
function remote.clear()
    remote.cache = {}
end

-- Assign a local alias to a remote peripheral
function remote.setAlias(alias, remoteName)
    remote.alias[alias] = remoteName
end

-- Internal: Resolve alias or passthrough
local function resolve(name)
    return remote.alias[name] or name
end

-- Discover all remote peripherals on the network
function remote.discover()
    return peripheral.getNames()
end

-- Get all peripherals of a given type
function remote.findByType(peripheralType)
    local result = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == peripheralType then
            table.insert(result, name)
        end
    end
    return result
end

-- Get or cache a wrapped remote peripheral
function remote.get(name)
    local resolved = resolve(name)
    if not remote.cache[resolved] then
        if peripheral.isPresent(resolved) then
            remote.cache[resolved] = peripheral.wrap(resolved)
        else
            error("Remote peripheral not found: " .. resolved)
        end
    end
    return remote.cache[resolved]
end

-- Call a method on a remote peripheral safely
function remote.call(name, method, ...)
    local resolved = resolve(name)
    if not peripheral.isPresent(resolved) then
        return nil, "Peripheral '" .. resolved .. "' not present"
    end
    local ok, result = pcall(peripheral.call, resolved, method, ...)
    if not ok then
        return nil, "Call failed: " .. result
    end
    return result
end

-- Check if a peripheral of a given type is present
function remote.hasType(name, expectedType)
    local resolved = resolve(name)
    return peripheral.getType(resolved) == expectedType
end

return remote
