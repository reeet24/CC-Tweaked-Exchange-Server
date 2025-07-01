-- periphscan.lua
local scan = {}

-- Return all peripheral info: name, type, and methods
function scan.getAll()
    local result = {}
    for _, name in ipairs(peripheral.getNames()) do
        local info = {
            name = name,
            type = peripheral.getType(name),
            methods = peripheral.getMethods(name)
        }
        table.insert(result, info)
    end
    return result
end

-- Return only peripherals matching a given type
function scan.findByType(periphType)
    local result = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == periphType then
            table.insert(result, {
                name = name,
                type = periphType,
                methods = peripheral.getMethods(name)
            })
        end
    end
    return result
end

-- Return peripheral info by exact name
function scan.getByName(periphName)
    if peripheral.isPresent(periphName) then
        return {
            name = periphName,
            type = peripheral.getType(periphName),
            methods = peripheral.getMethods(periphName)
        }
    end
    return nil
end

return scan
