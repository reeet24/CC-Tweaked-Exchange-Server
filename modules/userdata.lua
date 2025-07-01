-- userdata.lua
local json = textutils or require("json")

local userdata = {}
local dbPath = "/userdata.db"
local data = {}

-- Default schema template
local function defaultUser(id, username, inventoryID, pub, priv)
    return {
        Username = username or "Unnamed",
        Balance = 0,
        Promisies = {},
        InventoryServerId = inventoryID or "",
        PublicKey = pub or "",
        PrivateKey = priv or ""
    }
end

-- Internal: Load database from disk
local function load()
    if fs.exists(dbPath) then
        local f = fs.open(dbPath, "r")
        local raw = f.readAll()
        f.close()
        local ok, result = pcall(json.unserialize, raw)
        if ok and type(result) == "table" then
            data = result
        else
            error("Failed to load userdata: corrupted format")
        end
    else
        data = {}
    end
end

-- Internal: Save database to disk
local function save()
    local f = fs.open(dbPath, "w")
    f.write(json.serialize(data))
    f.close()
end

-- Public: Manually set database path (must call load() again if changed)
function userdata.setPath(path)
    dbPath = path
end

-- Public: Load from file
function userdata.load()
    load()
end

-- Public: Save to file
function userdata.save()
    save()
end

-- Public: Get a user by ID
function userdata.get(id)
    return data[id]
end

-- Public: Get all users
function userdata.all()
    return data
end

-- Public: Create or overwrite a user
function userdata.set(id, username, inventoryID, pub, priv)
    data[id] = defaultUser(id, username, inventoryID, pub, priv)
    save()
end

-- Public: Update a user's balance
function userdata.setBalance(id, amount)
    if data[id] then
        data[id].Balance = amount
        save()
        return true
    end
    return false
end

-- Public: Add to a user's balance
function userdata.addBalance(id, delta)
    if data[id] then
        data[id].Balance = data[id].Balance + delta
        save()
        return true
    end
    return false
end

-- Public: Delete a user
function userdata.remove(id)
    data[id] = nil
    save()
end

-- Public: Check if a user exists
function userdata.exists(id)
    return data[id] ~= nil
end

-- Public: Get a shallow copy of user data (safe export)
function userdata.export(id)
    local u = data[id]
    if u then
        return {
            Username = u.Username,
            Balance = u.Balance,
            Promisies = u.Promisies,
            InventoryServerId = u.InventoryServerId,
            PublicKey = u.PublicKey
        }
    end
    return nil
end

return userdata
