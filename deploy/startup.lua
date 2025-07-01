local sha256 = require("modules.sha256")
local updater = require("updater")

local config = {
  base_url = "https://github.com/reeet24/CC-Tweaked-Exchange-Server",
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

updater.check_and_update(config)
