local sha256 = require("modules.sha")
local updater = require("modules.updater")

 local config = {
  base_url = "https://github.com/reeet24/CC-Tweaked-Exchange-Server/tree/gh-pages",
  files = {
    "startup.lua",
    "server.lua",
    "client_latest.lua",
    "modules/updater.lua",
    "modules/net.lua",
  },
  hasher = sha256,
  reboot_after = true,
}

local success

local ok, err = pcall(function()
  success = updater.check_and_update(config)
end)
if not ok then
  print("Updater error: " .. tostring(err))
elseif success then
  print("[Updater] Files updated. Manual reboot required.")
else
  print("[Updater] No update needed.")
end