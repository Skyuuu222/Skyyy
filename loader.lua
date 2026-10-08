local cloneref = cloneref or function(x) return x end
local game = cloneref(game)
local LOADER_NAME = "Zypherax Loader"

local UNIVERSAL_SCRIPT_URL = "https://raw.githubusercontent.com/Skyuuu222/games/main/violence_district.lua"

local ___loaders = {
    [6739698191] = {
        name = "Violence District",
        url  = "https://raw.githubusercontent.com/Skyuuu222/games/main/violence_district.lua",
    },
}
local ___loaders = {
    [10035204815] = {
        name = "Ride A Pet",
        url  = "https://raw.githubusercontent.com/Skyuuu222/games/blob/main/ride_a_pet.lua",
    },
}

local ___place_loaders = {}

local function __load_script(url, script_name)
    local ok, result = pcall(function()
        local script_content = game:HttpGet(url)

        if type(script_content) ~= "string" or #script_content == 0 then
            error("Respons kosong dari: " .. url)
        end

        if script_content:sub(1, 14) == "404: Not Found"
            or script_content:find("<!DOCTYPE html>", 1, true) then
            error("File tidak ditemukan (404) di: " .. url)
        end

        local loaded_function = loadstring(script_content)
        if not loaded_function then
            error("Gagal mengompilasi script: " .. (script_name or "Universal"))
        end

        task.spawn(loaded_function)
        return true
    end)

    if not ok then
        warn("[" .. LOADER_NAME .. "] Gagal memuat " .. (script_name or "script") .. ": " .. tostring(result))
        return false
    end

    return true
end

local place_id    = game.PlaceId
local universe_id = game.GameId

local target_config = ___place_loaders[place_id] or ___loaders[universe_id]
local target_url    = target_config and target_config.url or nil

if not target_url or target_url == "" then
    target_url = UNIVERSAL_SCRIPT_URL
    target_config = nil
end

if target_url and target_url ~= "" then
    __load_script(target_url, target_config and target_config.name or "Universal")
else
    warn("[" .. LOADER_NAME .. "] UNIVERSAL_SCRIPT_URL belum diisi.")
end
