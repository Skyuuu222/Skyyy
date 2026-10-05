-- ==============================================================================
-- REKAMER TRIGGER LENGKAP - VIOLENCE DISTRICT
-- ==============================================================================
--
-- CARA PAKAI:
--   1. Paste file ini ke executor (Jalankan / Execute) saat masih di lobby.
--   2. Rekaman otomatis NYALA begitu file ini di-load.
--   3. MASUK game, lalu escape MANUAL seperti biasa
--      (tarik tuas, jalan ke zona keluar, tunggu sampai escaped).
--   4. Setelah karakter KEMBALI KE LOBBY, rekaman berhenti otomatis
--      dan hasilnya langsung dicetak.
--
-- PERINTAH KONSOL:
--   mulaiRekam()     -> mulai ulang rekaman dari nol
--   stopRekam()      -> hentikan rekaman
--   cetakRekam()     -> cetak hasil tanpa menghapus
--   ringkasRekam()   -> cetak kandidat zona terkuat
--   hapusRekam()     -> kosongkan log
--
-- YANG DICATAT:
--   [REMOTE]  setiap FireServer / InvokeServer dari script game
--   [TOUCH]   setiap part BERBEDA yang disentuh HumanoidRootPart
--   [ZONA]    part baru yang masuk area sekitar pemain (deteksi spatial)
--   [ATRIB]   perubahan attribute penting
--   [JALAN]   posisi karakter tiap 0.5 detik
--   [ACARA]   CharacterAdded / CharacterRemoving / balik lobby
-- ==============================================================================

do
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

-- ---------------------------------------------------------------------------
-- Forward declaration (fungsi di bawah saling memanggil)
-- ---------------------------------------------------------------------------
local stopRekam
local cetakRekam

-- ---------------------------------------------------------------------------
-- State utama
-- ---------------------------------------------------------------------------
local R = {
    log        = {},
    t0         = 0,
    running    = false,
    round      = 0,
    escapeAt   = nil,
    touchSeen  = {},
    zoneSeen   = {},
    attrSeen   = {},
    path       = {},
    pathT      = 0,
    touchConn  = nil,
    charConns  = {},
    query      = nil,
    hookMode   = "belum",
    remoteN    = 0,
    scanN      = 0,
}

local insideSet = {}

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------
local function now()
    return os.clock() - R.t0
end

local function isCharPart(obj, char)
    if not char then return false end
    return obj == char or obj:IsDescendantOf(char)
end

-- Ubah nilai apa pun jadi string yang enak dibaca
local function fmt(v)
    local t = type(v)
    if t == "string" then return '"' .. v .. '"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "nil" then return "nil" end
    if t == "Vector3" or t == "CFrame" then return tostring(v) end
    local okName, nm = pcall(function() return v.Name end)
    if okName and type(nm) == "string" then return "<Instance " .. nm .. ">" end
    if t == "table" then
        local keys = {}
        local n = 0
        for k in pairs(v) do
            n = n + 1
            if n > 6 then break end
            keys[#keys + 1] = tostring(k)
        end
        return "{" .. table.concat(keys, ",") .. (n > 6 and ",..." or "") .. "}"
    end
    return "<" .. t .. ">"
end

local function argsToStr(...)
    local n = select("#", ...)
    if n == 0 then return "" end
    local parts = {}
    for i = 1, n do
        parts[#parts + 1] = "#" .. i .. "=" .. fmt((select(i, ...)))
    end
    return table.concat(parts, ", ")
end

local function posStr(p)
    if not p then return "?" end
    return math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z)
end

local function partFlags(p)
    local s = p.Size
    return string.format("Size %.0fx%.0fx%.0f | Touch=%s Collide=%s",
        s.X, s.Y, s.Z, tostring(p.CanTouch), tostring(p.CanCollide))
end

local function add(kind, name, detail)
    if not R.running then return end
    R.log[#R.log + 1] = { t = now(), kind = kind, name = name, detail = detail or "" }
end

-- ---------------------------------------------------------------------------
-- 1. HOOK REMOTE
-- ---------------------------------------------------------------------------
-- Executor sering tidak punya hookmetamethod, jadi ada 3 cara yang dicoba
-- berurutan. Yang berhasil dipakai, sisanya diabaikan.
local WATCH_METHODS = {
    FireServer            = true,
    FireServerUnreliable = true,
    InvokeServer          = true,
}

local function hookRemotes()
    -- CARA 1: hookmetamethod (paling bersih kalau tersedia)
    if type(hookmetamethod) == "function" then
        local ok = pcall(function()
            for _, m in ipairs({"FireServer", "FireServerUnreliable", "InvokeServer"}) do
                local old
                old = hookmetamethod(game, m, function(self, ...)
                    local okName, nm = pcall(function() return self:GetFullName() end)
                    add("REMOTE", okName and nm or "?", m .. "(" .. argsToStr(...) .. ")")
                    R.remoteN = R.remoteN + 1
                    return old(self, ...)
                end)
            end
        end)
        if ok then
            R.hookMode = "hookmetamethod"
            return true
        end
    end

    -- CARA 2: getnamecallmethod (hampir selalu ada di executor)
    if type(getnamecallmethod) == "function" then
        local ok, old = pcall(function() return getnamecallmethod() end)
        if ok and type(old) == "function" then
            local ok2 = pcall(function()
                getnamecallmethod(function(self, ...)
                    local m = getnamecallmethod()
                    if WATCH_METHODS[m] then
                        local okName, nm = pcall(function() return self:GetFullName() end)
                        if okName and type(nm) == "string" then
                            add("REMOTE", nm, m .. "(" .. argsToStr(...) .. ")")
                            R.remoteN = R.remoteN + 1
                        end
                    end
                    return old(self, ...)
                end)
            end)
            if ok2 then
                R.hookMode = "getnamecallmethod"
                return true
            end
        end
    end

    -- CARA 3: tidak ada hook -> tetap andalkan TOUCH (masih berguna)
    R.hookMode = "TIDAK ADA (hanya TOUCH)"
    return false
end

-- ---------------------------------------------------------------------------
-- 2. TOUCH pada HumanoidRootPart
-- ---------------------------------------------------------------------------
-- Satu koneksi ini cukup: HRP.Touched memberi tahu setiap part yang disentuh
-- karakter - persis seperti yang dicek server.
-- Part yang sama tidak diulang, hanya jumlah sentuhnya yang bertambah.
local function setupTouch()
    if R.touchConn then
        pcall(function() R.touchConn:Disconnect() end)
        R.touchConn = nil
    end
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    R.touchConn = hrp.Touched:Connect(function(hit)
        if not (hit and hit:IsA("BasePart")) then return end
        local c = Players.LocalPlayer and Players.LocalPlayer.Character
        if c and hit:IsDescendantOf(c) then return end

        local detail = partFlags(hit)
            .. string.format(" | jarak %.0f", (hit.Position - hrp.Position).Magnitude)

        local rec = R.touchSeen[hit]
        if rec then
            rec.n = rec.n + 1
        else
            R.touchSeen[hit] = {
                nama   = hit:GetFullName(),
                n      = 1,
                t      = now(),
                detail = detail,
            }
            add("TOUCH", hit:GetFullName(), detail)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- 3. SCAN SPATIAL (cadangan / peta zona sekitar)
-- ---------------------------------------------------------------------------
-- Semua part yang masuk ke kotak 34 stud di sekitar pemain.
-- Ini menangkap volume trigger yang CanQuery-nya aktif.
local function makeQuery()
    if R.query then pcall(function() R.query:Destroy() end) end
    local p = Instance.new("Part")
    p.Name         = "REKAMER_QUERY"
    p.Size         = Vector3.new(34, 34, 34)
    p.Anchored     = true
    p.CanCollide   = false
    p.CanTouch     = false
    p.CanQuery     = true
    p.Transparency = 1
    p.CFrame       = CFrame.new(0, -99999, 0)
    p.Parent       = workspace
    R.query = p
    return p
end

local function scanAround()
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not R.query then return end

    R.query.CFrame = hrp.CFrame

    local ok, parts = pcall(function()
        return workspace:GetPartsInPart(R.query, nil)
    end)
    if not ok or type(parts) ~= "table" then return end

    local nowSet = {}
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") and not isCharPart(p, char) then
            nowSet[p] = true
            if not R.zoneSeen[p] then
                local detail = partFlags(p)
                    .. string.format(" | jarak %.0f", (p.Position - hrp.Position).Magnitude)
                R.zoneSeen[p] = { nama = p:GetFullName(), t = now(), detail = detail }
                add("ZONA", p:GetFullName(), detail)
                R.scanN = R.scanN + 1
            end
        end
    end

    for p in pairs(insideSet) do
        if not nowSet[p] then insideSet[p] = nil end
    end
    for p in pairs(nowSet) do insideSet[p] = true end
end

-- ---------------------------------------------------------------------------
-- 4. ATRIBUTE
-- ---------------------------------------------------------------------------
local ATTR_WATCH = {
    "Escaped", "Escape", "Win", "Winner", "WinState", "Survived", "Alive",
    "Status", "State", "Round", "RoundState", "Dead", "IsKiller", "Role",
    "Exp", "EXP", "Level", "Coins", "Reward", "Screws",
}

local function watchAttrs(obj, label)
    if not obj then return end
    for _, key in ipairs(ATTR_WATCH) do
        local ok, conn = pcall(function()
            local v = obj:GetAttribute(key)
            if v == nil then return false end
            return obj:GetAttributeChangedSignal(key):Connect(function()
                local nv = obj:GetAttribute(key)
                if R.attrSeen[label .. "." .. key] == nv then return end
                R.attrSeen[label .. "." .. key] = nv
                add("ATRIB", label .. "." .. key, tostring(nv))
            end)
        end)
        if ok and conn and conn ~= false then
            local v = obj:GetAttribute(key)
            if v ~= nil then R.attrSeen[label .. "." .. key] = v end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5. REKAM LINTASAN POSISI
-- ---------------------------------------------------------------------------
local function recordPath()
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not hrp then return end
    R.path[#R.path + 1] = { t = now(), p = hrp.Position }
end

-- ---------------------------------------------------------------------------
-- LOOP UTAMA
-- ---------------------------------------------------------------------------
local loopRunning = false

local function mainLoop()
    if loopRunning then return end
    loopRunning = true

    task.spawn(function()
        while R.running do
            scanAround()

            R.pathT = R.pathT + 1
            if R.pathT >= 5 then          -- sekitar 0.5 detik
                R.pathT = 0
                recordPath()
            end

            task.wait(0.1)
        end
        loopRunning = false
    end)
end

-- ---------------------------------------------------------------------------
-- ACARA KARAKTER (escaped / balik lobby)
-- ---------------------------------------------------------------------------
local function setupCharEvents()
    for _, c in ipairs(R.charConns) do pcall(function() c:Disconnect() end) end
    R.charConns = {}

    local lp = Players.LocalPlayer
    if not lp then return end

    R.charConns[#R.charConns + 1] = lp.CharacterAdded:Connect(function(char)
        task.wait(0.4)
        R.round = R.round + 1
        add("ACARA", "CharacterAdded", "round #" .. R.round)

        -- Karakter baru muncul SETELAH escape = bukti escaped berhasil
        if R.escapeAt then
            add("ACARA", "BALIK LOBBY",
                string.format("%.1f detik setelah escape", now() - R.escapeAt))
            add("ACARA", "REKAMAN SELESAI",
                "Escape terdeteksi. Urutan di atas adalah urutan yang benar.")

            -- Hentikan rekaman dulu supaya loop utama berhenti membersihkan data
            stopRekam(true)
            -- Baru cetak hasil, supaya tidak ada yang hilang
            task.wait(0.3)
            cetakRekam()
            ringkasRekam()

            print(">>> INI hasil rekaman lengkap. Salin semua baris di atas "
                .. "dan kirim ke saya untuk dianalisa.")
            print(">>> Kalau hasilnya kepotong, ketik: cetakRekam()")
            return
        end

        watchAttrs(char, "Character")
        setupTouch()
    end)

    R.charConns[#R.charConns + 1] = lp.CharacterRemoving:Connect(function(char)
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if R.escapeAt == nil then
            R.escapeAt = now()
            add("ACARA", "ESCAPE!",
                string.format(" karakter dihapus di Pos %s",
                    hrp and posStr(hrp.Position) or "?"))
            print("\n>>> ESCAPE TERCATAT! Rekaman dilanjut 8 detik "
                .. "untuk menangkap remote hadiah... <<<")
        end
        if R.touchConn then
            pcall(function() R.touchConn:Disconnect() end)
            R.touchConn = nil
        end
    end)
end

-- ---------------------------------------------------------------------------
-- CETAK HASIL
-- ---------------------------------------------------------------------------
cetakRekam = function()
    local touchCount = 0
    for _ in pairs(R.touchSeen) do touchCount = touchCount + 1 end

    print("\n\n========================================================")
    print("  REKAMAN TRIGGER - VIOLENCE DISTRICT")
    print("========================================================")
    print("  Mode hook remote : " .. R.hookMode)
    print("  Remote tercatat  : " .. R.remoteN)
    print("  Part disentuh    : " .. touchCount)
    print("  Zona vicinity    : " .. R.scanN)
    print("  Total timeline   : " .. #R.log)
    print("  Escape tercatat  : " .. (R.escapeAt and
        string.format("ya, di detik %.1f", R.escapeAt) or "BELUM"))
    print("========================================================\n")

    print("---------------- TIMELINE ----------------")
    local shown = 0
    for _, e in ipairs(R.log) do
        shown = shown + 1
        if shown > 600 then
            print("   ... (" .. (#R.log - 600) .. " entri lain disembunyikan)")
            break
        end
        print(string.format("%7.2fs  [%-6s] %-42s  %s", e.t, e.kind, e.name, e.detail))
    end

    print("\n---------------- PART YANG DISENTUH ----------------")
    local list = {}
    for p, rec in pairs(R.touchSeen) do
        list[#list + 1] = rec
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    for i, rec in ipairs(list) do
        if i > 80 then
            print("   ... dan " .. (#list - 80) .. " lainnya")
            break
        end
        print(string.format("%7.2fs  x%-4d %-40s %s", rec.t, rec.n, rec.nama, rec.detail))
    end

    print("\n---------------- LINTASAN POSISI ----------------")
    for i, s in ipairs(R.path) do
        if i > 150 then break end
        print(string.format("%7.2fs  %s", s.t, posStr(s.p)))
    end
    print("\n========================================================\n")
end

local function ringkasRekam()
    print("\n---------------- RINGKASAN KANDIDAT ----------------")

    -- Kandidat zona: part yang disentuh, tidak collide (invisible trigger),
    -- dan namanya mengandung kata kunci keluar.
    local KW = {"exit", "escape", "zone", "trigger", "goal", "win",
                "area", "box", "finish", "teleport", "safe", "outside"}
    local cand = {}
    for p, rec in pairs(R.touchSeen) do
        if p:IsA("BasePart") and p.CanTouch and not p.CanCollide then
            local s = p.Size
            local vol = s.X * s.Y * s.Z
            local score = 0
            local nm = p.Name:lower()
            local parent, depth = p.Parent, 0
            while parent and depth < 3 do
                local pn = parent.Name:lower()
                for _, k in ipairs(KW) do
                    if nm:find(k, 1, true) then score = score + 30 end
                    if pn:find(k, 1, true) then score = score + 20 end
                end
                parent = parent.Parent
                depth = depth + 1
            end
            if vol >= 50 then score = score + 15 end
            cand[#cand + 1] = { rec = rec, score = score }
        end
    end
    table.sort(cand, function(a, b) return a.score > b.score end)

    for i, c in ipairs(cand) do
        if i > 30 then break end
        print(string.format("  #%-2d skor=%-4d %-40s %s", i, c.score, c.rec.nama, c.rec.detail))
    end
    if #cand == 0 then
        print("  (tidak ada kandidat invisible trigger yang disentuh)")
    end
    print("========================================================\n")
end

-- ---------------------------------------------------------------------------
-- KENDALI
-- ---------------------------------------------------------------------------
local function mulaiRekam()
    R.log       = {}
    R.t0        = os.clock()
    R.running   = true
    R.round     = 0
    R.escapeAt  = nil
    R.touchSeen = {}
    R.zoneSeen  = {}
    R.attrSeen  = {}
    R.path      = {}
    R.pathT     = 0
    R.remoteN   = 0
    R.scanN     = 0
    insideSet   = {}

    makeQuery()
    hookRemotes()

    local lp = Players.LocalPlayer
    if lp then
        watchAttrs(lp, "Player")
        if lp.Character then
            watchAttrs(lp.Character, "Character")
            task.defer(setupTouch)
        end
    end
    setupCharEvents()
    mainLoop()

    print("========================================================")
    print("  REKAMAN DIMULAI")
    print("  Hook remote : " .. R.hookMode)
    print("  Hook tidak tersedia, jadi kita andalkan TOUCH.")
    print("  Sekarang masuk game dan escape MANUAL.")
    print("  Ketik cetakRekam()  = lihat timeline + touch + lintasan")
    print("  Ketik ringkasRekam() = kandidat zona terkuat saja")
    print("========================================================")
end

stopRekam = function(silent)
    R.running = false
    if R.query then pcall(function() R.query:Destroy() end) end
    R.query = nil
    if R.touchConn then pcall(function() R.touchConn:Disconnect() end) end
    R.touchConn = nil
    if not silent then
        print(">>> Rekaman dihentikan.")
        cetakRekam()
    end
end

local function hapusRekam()
    R.log      = {}
    R.touchSeen = {}
    R.zoneSeen  = {}
    R.path      = {}
    R.remoteN   = 0
    R.scanN     = 0
    insideSet   = {}
    print(">>> Log rekaman dikosongkan.")
end

-- ---------------------------------------------------------------------------
-- Ekspor ke konsol executor
-- ---------------------------------------------------------------------------
local env = (getgenv and getgenv()) or _G
env.mulaiRekam   = mulaiRekam
env.stopRekam    = stopRekam
env.cetakRekam   = cetakRekam
env.ringkasRekam = ringkasRekam
env.hapusRekam   = hapusRekam

-- Alias huruf besar, buat yang lebih suka pakai versi kapital
env.MULAI_REKAM   = mulaiRekam
env.STOP_REKAM    = stopRekam
env.CETAK_REKAM   = cetakRekam
env.RINGKAS_REKAM = ringkasRekam
env.HAPUS_REKAM   = hapusRekam

-- Mulai otomatis begitu file di-load
mulaiRekam()
end
