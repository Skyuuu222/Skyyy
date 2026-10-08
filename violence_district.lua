-- =============================================================================
-- SKYYY UNIVERSAL LOADER v1.0
-- -----------------------------------------------------------------------------
-- Pakai cuma SATU link ini di semua game:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Skyuuu222/Skyyy/main/loader.lua"))()
--
-- Loader otomatis deteksi game (PlaceId) yang sedang kamu mainkan,
-- lalu memanggil script yang sesuai dari repo ini.
--
-- Struktur repo:
--   loader.lua              -> file ini (pemilih script otomatis)
--   violence_district.lua   -> script untuk Violence District
--   ride_a_pet.lua          -> script untuk Ride A Pet
--
-- Cara TAMBAH game baru:
--   1. Upload script game itu ke repo ini, misal: my_game.lua
--   2. Tambah entry di tabel GAMES di bawah dengan PlaceId gamenya
-- =============================================================================

local cloneref = cloneref or function(x) return x end
local game     = cloneref(game)

local StarterGui  = cloneref(game:GetService("StarterGui"))
local HttpService = cloneref(game:GetService("HttpService"))

local BASE = "https://raw.githubusercontent.com/Skyuuu222/Skyyy/main/"

-- ==============================================================================
-- DAFTAR SCRIPT PER GAME (key = PlaceId)
-- ready = false  -> script belum diupload, loader hanya memberi tahu
-- ==============================================================================
local GAMES = {
    -- Violence District
    [93978595733734] = {
        name  = "Violence District",
        url   = BASE .. "violence_district.lua",
        ready = true,
    },
    -- Ride A Pet
    [124216119978534] = {
        name  = "Ride A Pet",
        url   = BASE .. "ride_a_pet.lua",
        ready = false, -- <<< set true setelah ride_a_pet.lua diupload
    },
    -- Contoh menambah game lain:
    -- [6701277882] = { name = "Fish It", url = BASE .. "fish_it.lua", ready = true },
}

-- ==============================================================================
-- UTIL
-- ==============================================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Skyyy Loader",
            Text     = text or "",
            Duration = duration or 4,
        })
    end)
    print(("[Skyyy] %s | %s"):format(title or "Loader", text or ""))
end

local function http_get(url)
    local req = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
        or (krnl and krnl.request)
    if req then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and res and res.Body and #res.Body > 0 then
            return res.Body
        end
        return nil, (ok and "Respons kosong/gagal" or tostring(res))
    end
    -- fallback: HttpGet bawaan
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body and #body > 0 then return body end
    return nil, "Executor tidak mendukung HTTP request!"
end

-- ==============================================================================
-- MAIN: deteksi PlaceId game yang sedang dimainkan -> panggil script-nya
-- ==============================================================================
local placeId = game.PlaceId
local gameName = ""
pcall(function()
    gameName = cloneref(game:GetService("MarketplaceService")):GetProductInfo(placeId).Name
end)
if gameName == "" then gameName = "Unknown Game" end

local entry = GAMES[placeId]

if not entry then
    notify("Game Belum Didukung",
        ("\"%s\" (PlaceId %s) belum ada di loader. Tambahkan PlaceId-nya di loader.lua."):format(gameName, tostring(placeId)), 7)
    return
end

if not entry.ready then
    notify("Script Belum Tersedia",
        ("Script untuk \"%s\" belum diupload ke repo."):format(entry.name), 7)
    return
end

notify("Memuat Script", ("Game terdeteksi: %s"):format(entry.name), 3)

local src, err = http_get(entry.url)
if not src then
    notify("Gagal Memuat", ("Tidak bisa mengunduh script %s: %s"):format(entry.name, tostring(err)), 7)
    return
end

local fn, compileErr = loadstring(src, "@" .. entry.name:gsub("%s", "_"))
if not fn then
    notify("Gagal Compile", tostring(compileErr), 7)
    return
end

local ok, runErr = pcall(fn)
if not ok then
    notify("Script Error", tostring(runErr), 7)
    warn("[Skyyy] Runtime error:", runErr)
    return
end

notify("Berhasil", ("%s siap digunakan!"):format(entry.name), 4)
