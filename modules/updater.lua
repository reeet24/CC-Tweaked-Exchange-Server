-- updater.lua
local Updater = {}

local function http_get_json(url)
  local res = http.get(url, {["User-Agent"] = "CCTweaked-Updater"})
  if not res then return nil end
  local data = textutils.unserializeJSON(res.readAll())
  res.close()
  return data
end

local function http_get_text(url)
  local res = http.get(url, {["User-Agent"] = "CCTweaked-Updater"})
  if not res then return nil end
  local content = res.readAll()
  res.close()
  return content
end

function Updater.get_latest_commit_sha(user, repo, branch)
  local url = "https://api.github.com/repos/"..user.."/"..repo.."/commits/"..branch
  local data = http_get_json(url)
  if data and data.sha then
    return data.sha
  end
  return nil
end

function Updater.download_file(user, repo, branch, filepath, save_as)
  local url = "https://raw.githubusercontent.com/"..user.."/"..repo.."/"..branch.."/"..filepath
  local content = http_get_text(url)
  if not content then return false end
  local file = fs.open(save_as or filepath, "w")
  file.write(content)
  file.close()
  return true
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

function Updater.check_and_update(config)
  assert(config.user, "GitHub username required")
  assert(config.repo, "GitHub repo name required")
  assert(config.files, "Files list required")

  local branch = config.branch or "main"
  local user, repo = config.user, config.repo

  local current_sha = Updater.get_latest_commit_sha(user, repo, branch)
  if not current_sha then
    print("Failed to fetch latest commit SHA.")
    return false
  end

  local meta = Updater.load_meta()
  if meta.last_commit == current_sha then
    print("Already up to date.")
    return false
  end

  print("Update available. Downloading...")
  for _, file in ipairs(config.files) do
    local remote_path = type(file) == "table" and file.remote or file
    local local_path = type(file) == "table" and file.local_path or remote_path
    if Updater.download_file(user, repo, branch, remote_path, local_path) then
      print("Updated "..local_path)
    else
      print("Failed to download "..remote_path)
    end
  end

  meta.last_commit = current_sha
  Updater.save_meta(meta)

  if config.reboot_after then
    print("Rebooting...")
    sleep(1)
    os.reboot()
  end

  return true
end

return Updater