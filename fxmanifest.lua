fx_version "cerulean"
game "gta5"

client_script "client.lua"

shared_scripts {
    "config.lua",
    "shared/exports.lua",
    "wrappers/**.lua"
}

files {
    "shared/wrapper.lua"
}