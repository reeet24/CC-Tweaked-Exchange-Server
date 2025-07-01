-- updater.lua
local Updater = {}

-- Assumes user supplies `sha256(str)` function
local function default_sha256(data)
  if _G.sha256 then return _G.sha256(data)
  else error("No SHA-256 implementation provided") end
end

local function http_get_text(url)
  local res = http.get(url, { ["User-Agent"] = "CCTweaked-Updater" })
  if not res then return nil end
  local content = res.readAll()
  res.close()
  return content
end

local function save_file(path, content)
  local f = fs.open(path, "w")
  f.write(content)
  f.close()
end

function Updater.load_meta()
  if not fs.exists(".ccmeta") then return {} end
  local f = fs.open(".ccmeta", "r")
  local meta = textutils.unserialize(f.readAll())
  f.close()
  return meta or {}
end

function Updater.save_meta(meta)
  local f = fs.open(".ccmeta", "w")
  f.write(textutils.serialize(meta))
  f.close()
end

local function parse_manifest(text)
  local hashes = {}
  for line in text:gmatch("[^\r\n]+") do
    local file, hash = line:match("^(%S+)%s+(%x+)$")
    if file and hash then
      hashes[file] = hash
    end
  end
  return hashes
end

function Updater.get_local_hashes(config)
  assert(config.files, "config.files must be provided")
  local hasher = config.hasher or _G.sha256 or error("No SHA-256 function provided")

  local hashes = {}

  for _, entry in ipairs(config.files) do
    local local_path = type(entry) == "table" and entry.local_path or entry
    if fs.exists(local_path) then
      local f = fs.open(local_path, "r")
      local content = f.readAll()
      f.close()
      hashes[local_path] = hasher(content)
    else
      hashes[local_path] = nil -- not found
    end
  end

  return hashes
end


function Updater.load_server_manifest(base_url)
  local url = base_url .. "/manifest.sha256"
  local text = http_get_text(url)
  if not text then return nil end
  return parse_manifest(text)
end

function Updater.download_file_if_needed(base_url, remote_path, local_path, expected_hash, hasher)
  local current_hash = nil

  if fs.exists(local_path) then
    local file = fs.open(local_path, "r")
    local content = file.readAll()
    file.close()
    current_hash = hasher(content)
    if current_hash == expected_hash then
      return false, current_hash
    end
  end

  local content = http_get_text(base_url .. "/" .. remote_path)
  if not content then
    print("✗ Failed to download " .. remote_path)
    return false, nil
  end

  local new_hash = hasher(content)
  if expected_hash and new_hash ~= expected_hash then
    print("✗ Hash mismatch on " .. remote_path)
    return false, nil
  end

  save_file(local_path, content)
  return true, new_hash
end

function Updater.check_and_update(config)
  assert(config.base_url, "base_url is required")
  assert(config.files, "files list required")

  local hasher = config.hasher or default_sha256
  local meta = Updater.load_meta()
  meta.files = meta.files or {}

  local server_hashes = Updater.load_server_manifest(config.base_url)
  if not server_hashes then
    print("✗ Failed to load manifest.sha256 from server")
    return false
  end

  local updated = false

  for _, entry in ipairs(config.files) do
    local remote_path = type(entry) == "table" and entry.remote or entry
    local local_path = type(entry) == "table" and entry.local_path or remote_path
    local expected_hash = server_hashes[remote_path]

    print("Checking: " .. local_path)
    if not expected_hash then
      print("✗ Missing hash in manifest for: " .. remote_path)
    else
      local changed, hash = Updater.download_file_if_needed(config.base_url, remote_path, local_path, expected_hash, hasher)
      if changed then
        meta.files[local_path] = hash
        updated = true
        print("→ Updated: " .. local_path)
      else
        print("✓ Up to date: " .. local_path)
      end
    end
  end

  if updated then
    meta.last_update_time = os.epoch("utc")
    Updater.save_meta(meta)
    if config.reboot_after then
      print("Update complete. Rebooting...")
      sleep(1)
      os.reboot()
    end
  else
    print("All files already up to date.")
  end

  return updated
end

return Updater