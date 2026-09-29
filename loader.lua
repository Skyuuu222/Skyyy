-- ==============================================================================
-- GITHUB TO LUARMOR LOADER TEMPLATE
-- Jalankan file ini di executor via loadstring GitHub Raw
-- ==============================================================================

local cloneref = cloneref or function(x) return x end

local game         = cloneref(game)
local http_service = cloneref(game:GetService("HttpService"))
local players      = cloneref(game:GetService("Players"))
local starter_gui  = cloneref(game:GetService("StarterGui"))

-- @types
type loader_config = {
    name: string,
    url: string,
    version: string?,
    author: string?,
}

-- ==============================================================================
-- KONFIGURASI SCRIPT
-- ==============================================================================
local LOADER_NAME = "Studio Hub Loader"

-- Masukkan URL script Luarmor Anda di sini untuk mode Universal (berjalan di semua game)
local UNIVERSAL_SCRIPT_URL = "https://api.luarmor.net/files/v4/loaders/GANTI_DENGAN_ID_LUARMOR_ANDA.lua"

-- Daftar loader per UniverseId (GameId) jika ingin membedakan per game
local ___loaders: { [number]: loader_config } = {
    [6701277882] = {
        name    = "Fish It",
        url     = "https://api.luarmor.net/files/v4/loaders/EXAMPLE_ID_1.lua",
        version = "1.0.0",
        author  = "Skyuuu",
    },
    [5750914919] = {
        name    = "Fisch",
        url     = "https://api.luarmor.net/files/v4/loaders/EXAMPLE_ID_2.lua",
        version = "1.0.0",
        author  = "Skyuuu",
    },
}

-- Daftar loader per PlaceId (Khusus sub-tempat / map tertentu)
local ___place_loaders: { [number]: loader_config } = {
    -- [1234567890] = {
    --     name    = "Custom Place",
    --     url     = "https://api.luarmor.net/files/v4/loaders/EXAMPLE_ID_3.lua",
    --     version = "1.0.0",
    --     author  = "You",
    -- },
}

-- ==============================================================================
-- UTILITY NOTIFICATION
-- ==============================================================================
local function __notify(title: string, text: string, duration: number?): ()
    pcall(function()
        starter_gui:SetCore("SendNotification", {
            Title    = title or LOADER_NAME,
            Text     = text or "",
            Duration = duration or 5,
        })
    end)
end

-- ==============================================================================
-- LOADER RUNNER
-- ==============================================================================
local function __load_script(url: string, script_name: string?): boolean
    __notify(LOADER_NAME, "Memuat script: " .. (script_name or "Universal Hub") .. "...", 3)

    local success: boolean, result: any = pcall(function()
        local script_content: string = game:HttpGet(url)
        local loaded_function: any = loadstring(script_content)

        if loaded_function then
            task.spawn(loaded_function)
            return true
        else
            error("Gagal mengompilasi bytecode / script dari Luarmor!")
        end
    end)

    if not success then
        warn("[" .. LOADER_NAME .. "] Error:", result)
        __notify(LOADER_NAME, "Gagal memuat script! Cek console F9.", 5)
        return false
    end

    __notify(LOADER_NAME, (script_name or "Hub") .. " berhasil dimuat!", 4)
    return true
end

-- ==============================================================================
-- MAIN EXECUTION CHECK
-- ==============================================================================
local place_id: number    = game.PlaceId
local universe_id: number = game.GameId

-- Cek apakah game ini ada di daftar spesifik
local target_config: loader_config? = ___place_loaders[place_id] or ___loaders[universe_id]

if target_config then
    -- Jika game cocok dengan daftar spesifik
    __load_script(target_config.url, target_config.name)
elseif UNIVERSAL_SCRIPT_URL and UNIVERSAL_SCRIPT_URL ~= "" and not UNIVERSAL_SCRIPT_URL:find("GANTI_DENGAN_ID") then
    -- Jika tidak ada di daftar khusus, jalankan Universal Studio Hub (script.lua Anda)
    __load_script(UNIVERSAL_SCRIPT_URL, "Universal Avatar Hub")
else
    -- Jika tidak didukung dan tidak ada link universal
    warn("[" .. LOADER_NAME .. "] Game tidak didukung: PlaceId=" .. tostring(place_id) .. ", UniverseId=" .. tostring(universe_id))
    __notify(LOADER_NAME, "Game ini belum didukung oleh script!", 5)
end
