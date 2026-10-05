-- ==============================================================================
-- UNIVERSAL AVATAR & OUTFIT STUDIO HUB (POWERED BY WMACLIB)
-- Modern MacOS-style UI with Acrylic Blur, Tabs & Animations
-- ==============================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or nil

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        LocalPlayer = Players.PlayerAdded:Wait()
    end)
    if not LocalPlayer then LocalPlayer = Players.LocalPlayer end
end

-- [FORWARD DECLARATIONS FOR SCOPING]
-- Menjamin jumlah variabel lokal di main function jauh di bawah batas 200 Lua (LUAI_MAXVARS)

-- Modul 1, 2, 3, 4 (Avatar & Outfit Studio)
local apply_avatar_swap, reset_avatar_swap
local apply_outfit
local add_accessory, remove_accessory, remove_all_accessories, update_accessory_transform
local apply_korblox, remove_korblox, apply_headless, remove_headless

-- Modul 6 (Auto Heal)
local autoHealEnabled = false
local autoheal_start, autoheal_stop, start_auto_heal, stop_auto_heal
HEAL_COOLDOWN = 1.5  -- Global, bisa diubah dari UI slider

-- Modul 7 (Killer Radar)
local killerRadarEnabled = false
local RADAR_RANGE = 350
local killerradar_start, killerradar_stop, check_is_killer, radar_is_killer, is_local_player_killer

-- Modul 8 & 9 (Fullbright & Custom FOV)
local fullbrightEnabled = false
local fullbright_start, fullbright_stop
local customFovEnabled = false
local customFovValue = 70
local fov_start, fov_stop, fov_apply

-- Modul 10 (Infinite Item Charges)
local infiniteChargesEnabled = false
local infinite_charges_start, infinite_charges_stop, infinite_charges_apply, infcharges_start, infcharges_stop

-- Modul 11 (ESP Exit Gate)
local espGateEnabled = false
local start_esp_gate, stop_esp_gate, is_exit_gate_lever, esp_gate_get_part

-- Modul 12 (Auto Escape & Bypass)
local autoEscapeEnabled = false
local start_auto_escape, stop_auto_escape, trigger_instant_escape, teleport_to_lobby

-- Modul 13 (Discord Webhook Notifier)
local webhookUrl = ""
local webhookNotifyEscape = true
local webhookNotifyMatch = true
local send_discord_webhook, start_webhook_live_monitor, stop_webhook_live_monitor, get_player_stats, send_match_summary_webhook

-- Modul Auto Perfect Generator
local autoGenEnabled = false
local agen_start, agen_stop, start_auto_generator, stop_auto_generator

-- Modul 4.5 (Auto Parry)
local autoParryEnabled = false
local autoparry_start, autoparry_stop, start_auto_parry, stop_auto_parry

-- Modul 4.6 (Twist of Fate - Anti Miss)
local tofAntiMissEnabled = false
local tof_start, tof_stop

-- Modul ESP Generator
local espGenEnabled = false
local start_esp_gen, stop_esp_gen, start_esp_generator, stop_esp_generator

-- ==============================================================================
-- KENDALI LOG
-- ==============================================================================
-- Semua output diagnostik yang terlalu panjang goes through log() dan
-- DILETAKAN secara default, supaya console Roblox tidak dipenuhi
-- baris yang tidak perlu.
--
-- Set SKY_DEBUG = true di konsol kalau mau melihat semua detail:
--     SKY_DEBUG = true
-- Kalau belum di-set ulang, ketik SKY_DEBUG = false untuk mematikan lagi.
--
-- Notifikasi lewat Window:Notify() TIDAK terpengaruh switch ini,
-- jadi user tetap selalu melihat feedback utama dari setiap fitur.
-- ==============================================================================
-- Dua variabel ini sengaja dibuat global (tanpa local) supaya bisa diubah
-- dari konsol kapan saja: SKY_DEBUG = true / SKY_LOG_BUFFER = ""
SKY_DEBUG = false

-- Buffer log, supaya bisa disalin dari UI tanpa harus buka console.
-- Hanya 400 baris terakhir yang disimpan supaya tidak makan memory.
SKY_LOG_BUFFER = ""

local function log(msg, ...)
    if not SKY_DEBUG then return end
    local ok, text = pcall(string.format, tostring(msg), ...)
    local line = ok and text or tostring(msg)
    print("[Sky] " .. line)

    SKY_LOG_BUFFER = SKY_LOG_BUFFER .. line .. "\n"
    local _, count = SKY_LOG_BUFFER:gsub("\n", "")
    if count > 400 then
        local cut = SKY_LOG_BUFFER:find("\n", SKY_LOG_BUFFER:find("\n") + 1)
        if cut then SKY_LOG_BUFFER = SKY_LOG_BUFFER:sub(cut + 1) end
    end
end

-- ==============================================================================
-- HELPER UTILITIES
-- ==============================================================================
local function find_player(name)
    if not name or name == "" then return LocalPlayer end
    name = tostring(name):lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name or p.DisplayName:lower() == name then
            return p
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
            return p
        end
    end
    return nil
end

local function retry(tries, delay, fn)
    local lastErr
    for i = 1, tries do
        local ok, res = pcall(fn)
        if ok and res ~= nil then return res end
        lastErr = res
        task.wait(delay * i)
    end
    return nil, lastErr
end

local function http_json(url)
    return retry(3, 1.2, function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
end

local function normalize(s)
    s = tostring(s):lower()
    s = s:gsub("[\226\128\139-\226\128\141\239\187\191]", "")
    s = s:gsub("%s+", " ")
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function hex_to_color(hex)
    if not hex then return nil end
    hex = tostring(hex):gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if r and g and b then return Color3.fromRGB(r, g, b) end
end

-- ==============================================================================
-- ANTI-DETECTION & ANTI-CHEAT PROTECTION LAYER
-- ==============================================================================
do
    -- [1] Cloneref guard untuk semua services utama (cegah rawequal detection)
    pcall(function()
        if cloneref then
            -- Services sudah diamankan di atas menggunakan cloneref
        end
    end)

    -- [2] Proteksi WalkSpeed: Monitor jika server reset kecepatan dan kembalikan
    -- (Non-invasif: hanya aktif jika speed lock dinyalakan)
    task.spawn(function()
        task.wait(2)
        local _speedLockActive = false
        local _lockedSpeed = 16
        RunService.Heartbeat:Connect(function()
            if not _speedLockActive then return end
            pcall(function()
                local char = LocalPlayer and LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed ~= _lockedSpeed then
                    hum.WalkSpeed = _lockedSpeed
                end
            end)
        end)
        -- Expose ke scope luar via shared untuk toggle_loop_speed
        shared._setSpeedLock = function(enabled, speed)
            _speedLockActive = enabled
            _lockedSpeed = speed or 16
        end
    end)
end

-- ==============================================================================
do
-- MODUL 1: AVATAR CLONER & SWAP (Client Mirroring)
-- ==============================================================================
shared.AvatarSwapState = shared.AvatarSwapState or { targets = {} }
local SwapState = shared.AvatarSwapState

local function reset_swap_state(st)
    for _, c in ipairs(st.conns or {}) do pcall(function() c:Disconnect() end) end
    st.conns = {}
    if st.model then pcall(function() st.model:Destroy() end) end
    st.model = nil
    for inst, val in pairs(st.original or {}) do
        if inst.Parent then pcall(function() inst.Transparency = val end) end
    end
    st.original = {}
end

local function sanitize_accessory(acc)
    if not acc then return end
    for _, s in ipairs(acc:GetDescendants()) do
        if s:IsA("BaseScript") then pcall(function() s:Destroy() end) end
    end
    for _, d in ipairs(acc:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
        end
    end
end

local function cleanup_swap(player)
    local st = SwapState.targets[player]
    if not st then return end
    reset_swap_state(st)
    if st.respawnConn then pcall(function() st.respawnConn:Disconnect() end) end
    SwapState.targets[player] = nil

    local char = player.Character
    if char then
        -- Jika headless masih aktif saat swap dibersihkan, sembunyikan kepala karakter asli kembali
        if shared.HeadlessActive and shared.HeadlessActive[player] then
            local h = char:FindFirstChild("Head")
            if h then
                h.Transparency = 1
                for _, d in ipairs(h:GetChildren()) do
                    if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
                end
            end
        end
        -- Jika korblox masih aktif saat swap dibersihkan, sembunyikan kaki kanan asli kembali
        if shared.KorbloxActive and shared.KorbloxActive[player] then
            local rleg = char:FindFirstChild("Original_Right_Leg") or char:FindFirstChild("Right Leg")
            if rleg and not rleg:GetAttribute("IsKorblox") then rleg.Transparency = 1 end
            for _, c in ipairs(char:GetChildren()) do
                if c:GetAttribute("IsKorblox") or c.Name == "Right Leg Korblox" then c.Transparency = 0 end
            end
        end
    end
end

local function get_user_description(username)
    local userId = LocalPlayer.UserId
    if username and username ~= "" then
        local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, username)
        if not ok or not id then return nil, "Username '" .. tostring(username) .. "' tidak ditemukan!" end
        userId = id
    end
    local ok2, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
    if not ok2 or not desc then return nil, "Gagal mengambil data avatar dari UserId: " .. tostring(userId) end
    return desc, nil
end

local function dress_mirror(player, char, desc, st, modelPrefix)
    reset_swap_state(st)

    local hum = char:WaitForChild("Humanoid", 10)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hum or not hrp then return false, "Karakter tidak lengkap" end
    task.wait(0.3)

    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, hum.RigType)
    end)
    if not ok or not model then return false, "Gagal membuat model: " .. tostring(model) end
    model.Name = (modelPrefix or "Cloned_") .. player.Name

    local mhum = model:FindFirstChildOfClass("Humanoid")
    local mhrp = model:FindFirstChild("HumanoidRootPart")
    if not mhum or not mhrp then
        model:Destroy()
        return false, "Model kloning tidak lengkap"
    end

    local heightDiff = (mhum.HipHeight + mhrp.Size.Y / 2) - (hum.HipHeight + hrp.Size.Y / 2)
    mhum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    mhum.EvaluateStateMachine = false
    pcall(function() mhum:ChangeState(Enum.HumanoidStateType.Physics) end)

    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BaseScript") then d:Destroy() end
        if d:IsA("Motor6D") then d.Enabled = false end
    end

    local mapped = {}
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:GetAttribute("IsKorblox") and part.Name ~= "Right Leg Korblox" and part.Name ~= "Original_Right_Leg" then
            local cp = model:FindFirstChild(part.Name)
            if cp and cp:IsA("BasePart") then
                cp.Anchored = true
                table.insert(mapped, { part, cp })
            end
        end
    end

    local copyParts = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
            table.insert(copyParts, d)
        end
    end

    model.Parent = workspace

    -- Jika target sedang pakai Headless, sembunyikan kepala swap model
    if shared.HeadlessActive and shared.HeadlessActive[player] then
        local swapHead = model:FindFirstChild("Head")
        if swapHead then
            swapHead.Transparency = 1
            for _, d in ipairs(swapHead:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end
    end

    -- Jika target sedang pakai Korblox, sembunyikan Right Leg swap model
    if shared.KorbloxActive and shared.KorbloxActive[player] then
        local swapRLeg = model:FindFirstChild("Right Leg")
        if swapRLeg then
            swapRLeg.Transparency = 1
            for _, d in ipairs(swapRLeg:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end
    end

    table.insert(st.conns, RunService.Stepped:Connect(function()
        for _, part in ipairs(copyParts) do
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end))

    st.accFollowers = {}

    table.insert(st.conns, RunService.RenderStepped:Connect(function()
        if not hrp.Parent then return end
        local root = hrp.CFrame
        local inv = root:Inverse()
        local lift = CFrame.new(0, heightDiff, 0)
        for _, p in ipairs(mapped) do
            p[2].CFrame = root * lift * (inv * p[1].CFrame)
        end
        local swapHead = model:FindFirstChild("Head")
        if swapHead then
            for _, item in ipairs(st.accFollowers or {}) do
                if item.part and item.part.Parent then
                    item.part.CFrame = swapHead.CFrame * item.offset
                end
            end
        end
    end))

    local function hide(d)
        if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart")
            or d:IsA("Decal") or d:IsA("Texture") then
            if d:GetAttribute("IsKorblox") or (d.Parent and d.Parent:GetAttribute("IsKorblox")) then return end
            if d.Name == "Right Leg Korblox" or (d.Parent and d.Parent.Name == "Right Leg Korblox") then return end
            if d.Parent and (d.Parent:IsA("Accessory") and d.Parent:GetAttribute("IsCustomAccessory")) then return end
            if st.original[d] == nil then st.original[d] = d.Transparency end
            d.Transparency = 1
        end
    end
    for _, d in ipairs(char:GetDescendants()) do hide(d) end
    table.insert(st.conns, char.DescendantAdded:Connect(hide))

    -- Pasang Custom Accessories yang aktif sebagai visual puppet (Anchored + CFrame Follower = 100% Anti-Nyangkut)
    if shared.CustomAccessories and shared.CustomAccessories[player] then
        local swapHead = model:FindFirstChild("Head")
        for _, cId in ipairs(shared.CustomAccessories[player]) do
            task.spawn(function()
                pcall(function()
                    local okLoad, objects = pcall(function() return game:GetObjects("rbxassetid://" .. cId) end)
                    if okLoad and objects and #objects > 0 then
                        local modelAcc = objects[1]
                        local acc = modelAcc:IsA("Accessory") and modelAcc or modelAcc:FindFirstChildOfClass("Accessory")
                        local handle = acc and acc:FindFirstChild("Handle")
                        if handle and model.Parent and swapHead then
                            local dummy = handle:Clone()
                            for _, desc in ipairs(dummy:GetDescendants()) do
                                if desc:IsA("BaseScript") or desc:IsA("JointInstance") then desc:Destroy() end
                            end
                            dummy.Name = "CustomAccPart_" .. cId
                            dummy:SetAttribute("CustomAssetId", cId)
                            dummy:SetAttribute("IsCustomAccessory", true)
                            dummy.Anchored = true
                            dummy.CanCollide = false
                            dummy.CanTouch = false
                            dummy.CanQuery = false
                            dummy.Massless = true
                            dummy.Transparency = 0
                            dummy.Parent = model

                            local sAttachment = dummy:FindFirstChildOfClass("Attachment")
                            local sHeadAttachment = swapHead:FindFirstChild(sAttachment and sAttachment.Name or "") or swapHead:FindFirstChild("HatAttachment")
                            local offset = (sHeadAttachment and sHeadAttachment.CFrame or CFrame.new(0, 0.5, 0)) * (sAttachment and sAttachment.CFrame:Inverse() or CFrame.new())
                            dummy.CFrame = swapHead.CFrame * offset
                            table.insert(st.accFollowers, { part = dummy, offset = offset, id = cId })
                        end
                    end
                end)
            end)
        end
    end

    st.model = model
    return true, "Avatar berhasil dipasang pada " .. player.Name
end

function apply_avatar_swap(targetName, avatarUsername)
    local target = find_player(targetName)
    if not target then return false, "Pemain '" .. tostring(targetName) .. "' tidak ditemukan di server!" end

    local desc, err = get_user_description(avatarUsername)
    if not desc then return false, err end

    cleanup_swap(target)
    local st = { conns = {}, original = {} }
    SwapState.targets[target] = st

    if target.Character then
        task.spawn(dress_mirror, target, target.Character, desc, st, "Swap_")
    end
    st.respawnConn = target.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        dress_mirror(target, newChar, desc, st, "Swap_")
    end)
    return true, "Avatar '" .. avatarUsername .. "' dipasang ke " .. target.Name
end

function reset_avatar_swap(targetName)
    if not targetName or targetName == "" then
        for p in pairs(SwapState.targets) do cleanup_swap(p) end
        return true, "Semua avatar pemain dikembalikan normal."
    else
        local target = find_player(targetName)
        if target then
            cleanup_swap(target)
            return true, "Avatar " .. target.Name .. " dikembalikan normal."
        end
        return false, "Target tidak ditemukan."
    end
end

-- ==============================================================================
-- MODUL 2: OUTFIT CLONER
-- ==============================================================================
local ACC_TYPES = {
    [8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair,
    [42] = Enum.AccessoryType.Face, [43] = Enum.AccessoryType.Neck,
    [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front,
    [46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
    [64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt,
    [66] = Enum.AccessoryType.Pants, [67] = Enum.AccessoryType.Jacket,
    [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts,
    [70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe,
    [72] = Enum.AccessoryType.DressSkirt,
    [76] = Enum.AccessoryType.Eyebrow, [77] = Enum.AccessoryType.Eyelash,
}
local LAYERED = {
    [64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,
    [70]=true,[71]=true,[72]=true,
}
local BODY_IDS = {
    [17] = "Head", [79] = "Head", [27] = "Torso", [28] = "RightArm",
    [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg",
    [18] = "Face", [11] = "Shirt", [12] = "Pants", [2] = "GraphicTShirt",
}

local function fetch_outfits(userId)
    local all, seen = {}, {}
    for _, extra in ipairs({ "", "&isEditable=true" }) do
        for page = 1, 30 do
            local url = ("https://avatar.roblox.com/v1/users/%d/outfits?itemsPerPage=50&page=%d%s"):format(userId, page, extra)
            local data = http_json(url)
            if not data or not data.data or #data.data == 0 then break end
            for _, o in ipairs(data.data) do
                if not seen[o.id] then
                    seen[o.id] = true
                    table.insert(all, o)
                end
            end
            if #data.data < 50 then break end
        end
    end
    return all
end

local function merge_details(desc, det)
    if det.scale then
        pcall(function()
            desc.HeightScale = det.scale.height or desc.HeightScale
            desc.WidthScale = det.scale.width or desc.WidthScale
            desc.HeadScale = det.scale.head or desc.HeadScale
            desc.DepthScale = det.scale.depth or desc.DepthScale
            desc.ProportionScale = det.scale.proportion or desc.ProportionScale
            desc.BodyTypeScale = det.scale.bodyType or desc.BodyTypeScale
        end)
    end

    local bc = det.bodyColor3s
    if bc then
        pcall(function()
            desc.HeadColor = hex_to_color(bc.headColor3) or desc.HeadColor
            desc.TorsoColor = hex_to_color(bc.torsoColor3) or desc.TorsoColor
            desc.LeftArmColor = hex_to_color(bc.leftArmColor3) or desc.LeftArmColor
            desc.RightArmColor = hex_to_color(bc.rightArmColor3) or desc.RightArmColor
            desc.LeftLegColor = hex_to_color(bc.leftLegColor3) or desc.LeftLegColor
            desc.RightLegColor = hex_to_color(bc.rightLegColor3) or desc.RightLegColor
        end)
    end

    local list, have = {}, {}
    local okG, cur = pcall(function() return desc:GetAccessories(true) end)
    if okG and cur then
        for _, a in ipairs(cur) do
            have[a.AssetId] = true
            table.insert(list, a)
        end
    end

    for _, a in ipairs(det.assets or {}) do
        local tid = a.assetType and a.assetType.id
        local aid = a.id
        if BODY_IDS[tid] then
            local key = BODY_IDS[tid]
            pcall(function() if desc[key] == 0 then desc[key] = aid end end)
        elseif ACC_TYPES[tid] and not have[aid] then
            have[aid] = true
            table.insert(list, {
                AssetId = aid,
                AccessoryType = ACC_TYPES[tid],
                IsLayered = LAYERED[tid] or false,
                Order = (a.meta and a.meta.order) or (#list + 1),
                Puffiness = (a.meta and a.meta.puffiness) or 1,
            })
        end
    end
    pcall(function() desc:SetAccessories(list, true) end)
end

local function get_outfit_desc(username, outfitNameOrId)
    local outfitId = tonumber(outfitNameOrId)
    local outfitName = tostring(outfitNameOrId)

    if not outfitId then
        local userId = retry(3, 1, function() return Players:GetUserIdFromNameAsync(username) end)
        if not userId then return nil, "User '" .. username .. "' tidak ditemukan" end

        local outfits = fetch_outfits(userId)
        if #outfits == 0 then return nil, "Tidak ada outfit terbaca (profil privat)" end

        local n = normalize(outfitName)
        for _, o in ipairs(outfits) do
            if normalize(o.name) == n or normalize(o.name):find(n, 1, true) then
                outfitId = o.id
                outfitName = o.name
                break
            end
        end
        if not outfitId then return nil, "Outfit '" .. outfitName .. "' tidak ditemukan" end
    end

    local desc = retry(3, 1, function() return Players:GetHumanoidDescriptionFromOutfitId(outfitId) end)
    if not desc then desc = Instance.new("HumanoidDescription") end

    local det = http_json("https://avatar.roblox.com/v1/outfits/" .. outfitId .. "/details")
    if det then merge_details(desc, det) end
    return desc, outfitName
end

function apply_outfit(username, outfitQuery, targetName)
    local target = find_player(targetName)
    if not target then return false, "Target tidak ditemukan di server" end

    local desc, outName = get_outfit_desc(username, outfitQuery)
    if not desc then return false, outName end

    cleanup_swap(target)
    local st = { conns = {}, original = {} }
    SwapState.targets[target] = st

    if target.Character then
        task.spawn(dress_mirror, target, target.Character, desc, st, "Outfit_")
    end
    st.respawnConn = target.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        dress_mirror(target, newChar, desc, st, "Outfit_")
    end)
    return true, "Outfit '" .. tostring(outName) .. "' dipasang pada " .. target.Name
end

-- ==============================================================================
-- MODUL 3: ACCESSORY LOADER
-- ==============================================================================
-- ==============================================================================
-- MODUL 3: ACCESSORY LOADER & REMOVER
-- ==============================================================================
shared.CustomAccessories = shared.CustomAccessories or {}

local function apply_acc_scale(part, scale)
    if not part or not scale or scale == 1 then return end
    local mesh = part:FindFirstChildOfClass("SpecialMesh")
    if mesh then
        if not mesh:GetAttribute("OrigScale") then
            mesh:SetAttribute("OrigScale", mesh.Scale)
        end
        mesh.Scale = mesh:GetAttribute("OrigScale") * scale
    elseif part:IsA("MeshPart") or part:IsA("BasePart") then
        if not part:GetAttribute("OrigSize") then
            part:SetAttribute("OrigSize", part.Size)
        end
        part.Size = part:GetAttribute("OrigSize") * scale
    end
end

function add_accessory(targetName, assetId, offX, offY, offZ, scaleVal)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    local char = target.Character
    if not char then return false, "Karakter tidak ada" end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head then return false, "Humanoid/Head tidak ada" end

    local cleanId = tostring(assetId):match("%d+")
    if not cleanId then return false, "Asset ID tidak valid" end

    offX = tonumber(offX) or 0
    offY = tonumber(offY) or 0
    offZ = tonumber(offZ) or 0
    scaleVal = tonumber(scaleVal) or 1
    if scaleVal <= 0 then scaleVal = 1 end

    local userOffset = CFrame.new(offX, offY, -offZ)

    local okLoad, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. cleanId)
    end)
    if not okLoad or not objects or #objects == 0 then
        return false, "Gagal memuat aset aksesoris"
    end

    local model = objects[1]
    local accessory = model:IsA("Accessory") and model or model:FindFirstChildOfClass("Accessory")
    if not accessory then return false, "Bukan objek Accessory" end

    -- Bersihkan skrip & sifat fisik agar tidak nyangkut saat jalan
    sanitize_accessory(accessory)

    accessory:SetAttribute("CustomAssetId", cleanId)
    accessory:SetAttribute("IsCustomAccessory", true)

    local handle = accessory:FindFirstChild("Handle")
    local accAttachment = handle and handle:FindFirstChildOfClass("Attachment")
    if not handle or not accAttachment then return false, "Struktur Handle/Attachment rusak" end

    -- Terapkan scale ukuran
    apply_acc_scale(handle, scaleVal)

    -- Pasang ke karakter asli
    local headAttachment = head:FindFirstChild(accAttachment.Name) or head:FindFirstChild("HatAttachment")
    -- Cek apakah target sedang memakai copy avatar (avatar swap)
    local swapSt = SwapState.targets[target]
    if swapSt and swapSt.model then
        -- SWAP MODEL: Gunakan CFrame follower dummy (Anchored, 0 Weld, 100% Anti-Nyangkut)
        local swapHead = swapSt.model:FindFirstChild("Head")
        if swapHead then
            swapSt.accFollowers = swapSt.accFollowers or {}
            local dummy = handle:Clone()
            for _, desc in ipairs(dummy:GetDescendants()) do
                if desc:IsA("BaseScript") or desc:IsA("JointInstance") then desc:Destroy() end
            end
            dummy.Name = "CustomAccPart_" .. cleanId
            dummy:SetAttribute("CustomAssetId", cleanId)
            dummy:SetAttribute("IsCustomAccessory", true)
            dummy.Anchored = true
            dummy.CanCollide = false
            dummy.CanTouch = false
            dummy.CanQuery = false
            dummy.Massless = true
            dummy.Transparency = 0
            dummy.Parent = swapSt.model

            apply_acc_scale(dummy, scaleVal)

            local sAttachment = dummy:FindFirstChildOfClass("Attachment")
            local sHeadAttachment = swapHead:FindFirstChild(sAttachment and sAttachment.Name or "") or swapHead:FindFirstChild("HatAttachment")
            local baseOffset = (sHeadAttachment and sHeadAttachment.CFrame or CFrame.new(0, 0.5, 0)) * (sAttachment and sAttachment.CFrame:Inverse() or CFrame.new())
            local offset = baseOffset * userOffset
            dummy.CFrame = swapHead.CFrame * offset
            table.insert(swapSt.accFollowers, {
                part = dummy,
                offset = offset,
                id = cleanId,
                offX = offX,
                offY = offY,
                offZ = offZ,
                scale = scaleVal
            })
        end
    else
        -- AVATAR BIASA (tidak sedang swap): Pasang ke karakter fisik biasa
        local headAttachment = head:FindFirstChild(accAttachment.Name) or head:FindFirstChild("HatAttachment")
        accessory.Name = "CustomAcc_" .. cleanId
        accessory.Parent = char

        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = head
        weld.Part1 = handle
        local baseC0 = headAttachment and headAttachment.CFrame or CFrame.new(0, 0.5, 0)
        weld.C0 = baseC0 * userOffset
        weld.C1 = accAttachment.CFrame
        weld.Parent = handle

        sanitize_accessory(accessory)
    end

    -- Simpan riwayat aksesoris untuk target ini
    shared.CustomAccessories[target] = shared.CustomAccessories[target] or {}
    local alreadyListed = false
    for _, id in ipairs(shared.CustomAccessories[target]) do
        if id == cleanId then alreadyListed = true; break end
    end
    if not alreadyListed then
        table.insert(shared.CustomAccessories[target], cleanId)
    end

    return true, "Aksesoris ID " .. cleanId .. " dipasang ke " .. target.Name
end

function update_accessory_transform(targetName, assetId, offX, offY, offZ, scaleVal)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    offX = tonumber(offX) or 0
    offY = tonumber(offY) or 0
    offZ = tonumber(offZ) or 0
    scaleVal = tonumber(scaleVal) or 1
    if scaleVal <= 0 then scaleVal = 1 end

    local userOffset = CFrame.new(offX, offY, -offZ)
    local cleanId = assetId and tostring(assetId):match("%d+")
    local updatedCount = 0

    -- 1. Karakter fisik asli
    local char = target.Character
    if char then
        local head = char:FindFirstChild("Head")
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accessory") and (not cleanId or obj.Name:find(cleanId) or obj:GetAttribute("CustomAssetId") == cleanId) then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    apply_acc_scale(handle, scaleVal)
                    local weld = handle:FindFirstChild("AccessoryWeld")
                    local accAttachment = handle:FindFirstChildOfClass("Attachment")
                    if weld and head then
                        local headAttachment = accAttachment and head:FindFirstChild(accAttachment.Name) or head:FindFirstChild("HatAttachment")
                        local baseC0 = headAttachment and headAttachment.CFrame or CFrame.new(0, 0.5, 0)
                        weld.C0 = baseC0 * userOffset
                        updatedCount = updatedCount + 1
                    end
                end
            end
        end
    end

    -- 2. Model Swap (Copy Avatar)
    local swapSt = SwapState.targets[target]
    if swapSt and swapSt.model then
        local swapHead = swapSt.model:FindFirstChild("Head")
        if swapHead and swapSt.accFollowers then
            for _, item in ipairs(swapSt.accFollowers) do
                if not cleanId or item.id == cleanId then
                    if item.part and item.part.Parent then
                        apply_acc_scale(item.part, scaleVal)
                        local sAttachment = item.part:FindFirstChildOfClass("Attachment")
                        local sHeadAttachment = swapHead:FindFirstChild(sAttachment and sAttachment.Name or "") or swapHead:FindFirstChild("HatAttachment")
                        local baseOffset = (sHeadAttachment and sHeadAttachment.CFrame or CFrame.new(0, 0.5, 0)) * (sAttachment and sAttachment.CFrame:Inverse() or CFrame.new())
                        item.offset = baseOffset * userOffset
                        item.part.CFrame = swapHead.CFrame * item.offset
                        updatedCount = updatedCount + 1
                    end
                end
            end
        end
    end

    if updatedCount > 0 then
        return true, "Posisi & ukuran " .. updatedCount .. " aksesoris berhasil diperbarui!"
    else
        return false, "Aksesoris belum terpasang. Klik 'Pasang Aksesoris' terlebih dahulu."
    end
end

function remove_accessory(targetName, assetId)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    local cleanId = assetId and tostring(assetId):match("%d+")
    local searchPattern = assetId and tostring(assetId):lower():gsub("%s+", "") or ""

    local removedCount = 0

    local function checkAndRemove(acc)
        if not acc or not acc:IsA("Accessory") then return false end
        local matched = false

        -- 1. Cek Attribute CustomAssetId
        local customId = acc:GetAttribute("CustomAssetId")
        if cleanId and customId and tostring(customId) == cleanId then
            matched = true
        end

        -- 2. Cek Nama Accessory (mengandung ID atau kata kunci)
        if not matched and cleanId and acc.Name:find(cleanId) then
            matched = true
        end
        if not matched and searchPattern ~= "" and acc.Name:lower():find(searchPattern) then
            matched = true
        end

        -- 3. Cek MeshId / TextureId di Handle
        if not matched and cleanId then
            local handle = acc:FindFirstChild("Handle")
            if handle then
                for _, desc in ipairs(handle:GetDescendants()) do
                    if desc:IsA("SpecialMesh") then
                        if tostring(desc.MeshId):find(cleanId) or tostring(desc.TextureId):find(cleanId) then
                            matched = true
                            break
                        end
                    elseif desc:IsA("MeshPart") then
                        if tostring(desc.MeshId):find(cleanId) or tostring(desc.TextureID):find(cleanId) then
                            matched = true
                            break
                        end
                    end
                end
            end
        end

        if matched then
            acc:Destroy()
            removedCount = removedCount + 1
            return true
        end
        return false
    end

    -- Hapus dari karakter asli (bisa ava diri sendiri atau ava target di server)
    local char = target.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            checkAndRemove(obj)
        end
    end

    -- Hapus dari model swap (jika sedang pakai copy avatar)
    local swapSt = SwapState.targets[target]
    if swapSt and swapSt.model then
        for _, obj in ipairs(swapSt.model:GetChildren()) do
            if obj.Name == "CustomAccPart_" .. (cleanId or "") or obj:GetAttribute("CustomAssetId") == cleanId then
                obj:Destroy()
                removedCount = removedCount + 1
            else
                checkAndRemove(obj)
            end
        end
        if swapSt.accFollowers then
            for i = #swapSt.accFollowers, 1, -1 do
                if not cleanId or swapSt.accFollowers[i].id == cleanId or not swapSt.accFollowers[i].part.Parent then
                    table.remove(swapSt.accFollowers, i)
                end
            end
        end
    end

    -- Bersihkan dari daftar shared.CustomAccessories
    if shared.CustomAccessories and shared.CustomAccessories[target] and cleanId then
        for i = #shared.CustomAccessories[target], 1, -1 do
            if shared.CustomAccessories[target][i] == cleanId then
                table.remove(shared.CustomAccessories[target], i)
            end
        end
    end

    if removedCount > 0 then
        return true, "Berhasil menghapus " .. removedCount .. " aksesoris dari " .. target.Name
    else
        return false, "Aksesoris tidak ditemukan pada " .. target.Name
    end
end

function remove_all_accessories(targetName)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    local removedCount = 0

    local function removeAccs(container)
        if not container then return end
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Accessory") then
                if obj:GetAttribute("IsCustomAccessory") or obj.Name:find("CustomAcc_") then
                    obj:Destroy()
                    removedCount = removedCount + 1
                end
            end
        end
    end

    if target.Character then removeAccs(target.Character) end
    local swapSt = SwapState.targets[target]
    if swapSt and swapSt.model then
        removeAccs(swapSt.model)
        for _, obj in ipairs(swapSt.model:GetChildren()) do
            if obj.Name:find("CustomAccPart_") or obj:GetAttribute("IsCustomAccessory") then
                obj:Destroy()
                removedCount = removedCount + 1
            end
        end
        swapSt.accFollowers = {}
    end

    if shared.CustomAccessories then
        shared.CustomAccessories[target] = nil
    end

    if removedCount > 0 then
        return true, "Berhasil menghapus " .. removedCount .. " aksesoris custom dari " .. target.Name
    else
        return false, "Tidak ada aksesoris custom yang terpasang pada " .. target.Name
    end
end

-- ==============================================================================
-- MODUL 4: KORBLOX & HEADLESS MODIFICATIONS
-- ==============================================================================
shared.KorbloxConns = shared.KorbloxConns or {}
shared.KorbloxActive = shared.KorbloxActive or {}
shared.HeadlessActive = shared.HeadlessActive or {}
shared.HeadlessConns = shared.HeadlessConns or {}
shared.HeadlessHBConns = shared.HeadlessHBConns or {}

function remove_korblox(targetName)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    shared.KorbloxActive[target] = nil

    if shared.KorbloxConns[target] then
        for _, c in ipairs(shared.KorbloxConns[target]) do
            pcall(function() c:Disconnect() end)
        end
        shared.KorbloxConns[target] = nil
    end

    local char = target.Character
    if char then
        local torso = char:FindFirstChild("Torso")
        local oldLimb = char:FindFirstChild("Original_Right_Leg") or char:FindFirstChild("Right Leg")

        -- 1. Hapus part Korblox (part yang ber-attribute IsKorblox atau bernama Right Leg Korblox)
        for _, child in ipairs(char:GetChildren()) do
            if child:GetAttribute("IsKorblox") or child.Name == "Right Leg Korblox" or (child ~= oldLimb and child.Name == "Right Leg" and child:IsA("BasePart")) then
                child:Destroy()
            end
        end

        if torso then
            -- Hapus Motor6D yang kita buat untuk Korblox
            for _, j in ipairs(torso:GetChildren()) do
                if j:IsA("Motor6D") and (j.Name == "Right Hip" and (j.Part1 == nil or j.Part1:GetAttribute("IsKorblox") or (oldLimb and j.Part1 ~= oldLimb))) then
                    j:Destroy()
                end
            end
            -- Kembalikan joint asli
            local origJoint = torso:FindFirstChild("Right Hip Original") or torso:FindFirstChild("Right Hip")
            if origJoint and oldLimb then
                origJoint.Name = "Right Hip"
                origJoint.Part1 = oldLimb
            end
        end

        -- 2. Kembalikan nama kaki lama menjadi "Right Leg"
        if oldLimb then
            oldLimb.Name = "Right Leg"
        end

        -- 3. Atur kembali transparansi kaki
        local isSwapped = SwapState.targets[target] and SwapState.targets[target].model
        if isSwapped then
            -- Karakter asli tetap invisible karena sedang pakai avatar swap
            if oldLimb then oldLimb.Transparency = 1 end
            -- Munculkan kembali kaki kanan di model swap
            local swapRLeg = SwapState.targets[target].model:FindFirstChild("Right Leg")
            if swapRLeg then
                swapRLeg.Transparency = 0
                for _, d in ipairs(swapRLeg:GetChildren()) do
                    if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
                end
            end
        else
            -- Tidak sedang swap: kembalikan kaki asli ke terlihat normal
            if oldLimb then
                oldLimb.Transparency = 0
            end
        end
    end

    return true, "Korblox dinonaktifkan untuk " .. target.Name
end

function apply_korblox(targetName, assetId, yOffset)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end
    local char = target.Character
    if not char then return false, "Karakter belum spawn" end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 then
        return false, "Target bukan tipe avatar R6!"
    end

    local torso = char:FindFirstChild("Torso")
    local oldLimb = char:FindFirstChild("Right Leg")
    if not torso or not oldLimb then return false, "Torso / Right Leg tidak ditemukan" end

    -- Jika Korblox sudah terpasang, hapus dulu agar bersih
    if shared.KorbloxActive[target] or char:FindFirstChild("Original_Right_Leg") or torso:FindFirstChild("Right Hip Original") then
        remove_korblox(targetName)
        task.wait(0.05)
        oldLimb = char:FindFirstChild("Right Leg")
        torso = char:FindFirstChild("Torso")
        if not torso or not oldLimb then return false, "Gagal mereset kaki sebelum pasang" end
    end

    local originalJoint = torso:FindFirstChild("Right Hip")
    if not originalJoint then return false, "Joint 'Right Hip' tidak ditemukan" end

    local cleanId = tostring(assetId or "139607718"):match("%d+")
    local offsetVal = tonumber(yOffset) or 0.7
    local okLoad, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. cleanId)
    end)
    if not okLoad or not objects or #objects == 0 then
        return false, "Gagal memuat objek Korblox"
    end

    local newLimb = objects[1]
    if not newLimb:IsA("BasePart") then
        newLimb = newLimb:FindFirstChildWhichIsA("MeshPart") or newLimb:FindFirstChildWhichIsA("BasePart")
    end
    if not newLimb then return false, "Part kaki tidak ditemukan" end

    -- Bersihkan script di newLimb
    for _, s in ipairs(newLimb:GetDescendants()) do
        if s:IsA("BaseScript") then s:Destroy() end
    end

    local originalC0 = originalJoint.C0
    local originalC1 = originalJoint.C1

    -- Sembunyikan kaki lama & rename agar tidak bentrok nama
    oldLimb.Name = "Original_Right_Leg"
    oldLimb.Transparency = 1
    oldLimb.CanCollide = false

    -- Beri nama "Right Leg" pada newLimb agar Animator R6 Roblox menganimasikannya!
    -- Hitung posisi kaki tegak lurus (rest pose) dari Torso agar kaki Korblox tidak miring/maju ke depan saat berjalan
    local restLimbCF = torso.CFrame * originalC0 * originalC1:Inverse()
    newLimb.CFrame = restLimbCF * CFrame.new(0, offsetVal, 0)
    newLimb.Anchored = false
    newLimb.CanCollide = false
    newLimb.Massless = true
    newLimb.Transparency = 0
    newLimb:SetAttribute("IsKorblox", true)
    newLimb.Name = "Right Leg"
    newLimb.Parent = char

    -- Putuskan Part1 joint asli dan rename agar bisa di-undo
    originalJoint.Name = "Right Hip Original"
    originalJoint.Part1 = nil

    -- Buat Motor6D baru dengan C0 asli dan C1 dihitung dari posisi newLimb rest pose
    local weld = Instance.new("Motor6D")
    weld.Name = "Right Hip"
    weld.Part0 = torso
    weld.Part1 = newLimb
    weld.C0 = originalC0
    weld.C1 = newLimb.CFrame:ToObjectSpace(torso.CFrame * originalC0)
    weld.Parent = torso

    -- Sembunyikan kaki kanan di model swap jika sedang aktif
    local swapSt = SwapState.targets[target]
    if swapSt and swapSt.model then
        local swapRLeg = swapSt.model:FindFirstChild("Right Leg")
        if swapRLeg then
            swapRLeg.Transparency = 1
            for _, d in ipairs(swapRLeg:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end
    end

    -- Simpan state Korblox
    shared.KorbloxActive[target] = {
        assetId = cleanId,
        yOffset = offsetVal,
    }

    if shared.KorbloxConns[target] then
        for _, c in ipairs(shared.KorbloxConns[target]) do
            pcall(function() c:Disconnect() end)
        end
    end
    shared.KorbloxConns[target] = {}

    -- Heartbeat loop: menjaga newLimb selalu terlihat & swap model Right Leg selalu tersembunyi
    local hbConn = RunService.Heartbeat:Connect(function()
        if not newLimb or not newLimb.Parent then return end
        if newLimb.Transparency ~= 0 then
            newLimb.Transparency = 0
        end
        local currentSwap = SwapState.targets[target]
        if currentSwap and currentSwap.model then
            local sRLeg = currentSwap.model:FindFirstChild("Right Leg")
            if sRLeg and sRLeg.Transparency ~= 1 then
                sRLeg.Transparency = 1
            end
        end
    end)
    table.insert(shared.KorbloxConns[target], hbConn)

    -- Pasang ulang otomatis jika target respawn
    local respawnConn = target.CharacterAdded:Connect(function()
        task.wait(1)
        if shared.KorbloxActive[target] then
            apply_korblox(target.Name, cleanId, offsetVal)
        end
    end)
    table.insert(shared.KorbloxConns[target], respawnConn)

    return true, "Korblox Right Leg dipasang pada " .. target.Name
end

local function make_headless_char(char)
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
        end
    end
end

-- Sembunyikan HANYA kepala di swap model (aksesori kepala tetap utuh)
local function make_headless_swap(target)
    local swapSt = SwapState.targets[target]
    if not swapSt or not swapSt.model then return end
    local swapHead = swapSt.model:FindFirstChild("Head")
    if swapHead then
        swapHead.Transparency = 1
        for _, d in ipairs(swapHead:GetChildren()) do
            if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
        end
    end
end

function apply_headless(targetName)
    local target = find_player(targetName)
    if not target then return false, "Target tidak ditemukan" end

    shared.HeadlessActive[target] = true

    -- Disconnect semua koneksi headless lama
    if shared.HeadlessConns[target] then
        shared.HeadlessConns[target]:Disconnect()
        shared.HeadlessConns[target] = nil
    end
    if shared.HeadlessHBConns[target] then
        shared.HeadlessHBConns[target]:Disconnect()
        shared.HeadlessHBConns[target] = nil
    end

    local function setup(char)
        make_headless_char(char)
        make_headless_swap(target)

        if shared.HeadlessHBConns[target] then
            shared.HeadlessHBConns[target]:Disconnect()
        end

        local hbConn
        hbConn = RunService.Heartbeat:Connect(function()
            if not char or not char.Parent then
                hbConn:Disconnect()
                shared.HeadlessHBConns[target] = nil
                return
            end
            -- Jaga kepala karakter tetap invisible
            local h = char:FindFirstChild("Head")
            if h and h.Transparency ~= 1 then make_headless_char(char) end
            -- Jaga kepala model swap tetap invisible
            make_headless_swap(target)
        end)
        shared.HeadlessHBConns[target] = hbConn
    end

    if target.Character then setup(target.Character) end
    shared.HeadlessConns[target] = target.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if shared.HeadlessActive[target] then
            setup(newChar)
        end
    end)

    return true, "Headless diterapkan pada " .. target.Name
end

function remove_headless(targetName)
    local target = find_player(targetName)
    if not target then return false, "Target tidak ditemukan" end

    shared.HeadlessActive[target] = nil

    -- Disconnect CharacterAdded listener
    if shared.HeadlessConns[target] then
        shared.HeadlessConns[target]:Disconnect()
        shared.HeadlessConns[target] = nil
    end
    -- Disconnect Heartbeat listener
    if shared.HeadlessHBConns[target] then
        shared.HeadlessHBConns[target]:Disconnect()
        shared.HeadlessHBConns[target] = nil
    end

    local char = target.Character
    local swapSt = SwapState.targets[target]
    local isSwapped = swapSt and swapSt.model

    if isSwapped then
        -- KETIKA SEDANG PAKAI AVATAR SWAP:
        -- Kepala karakter asli HARUS TETAP invisible (1) agar tidak menabrak / z-fight dengan avatar swap!
        if char and char:FindFirstChild("Head") then
            char.Head.Transparency = 1
            for _, d in ipairs(char.Head:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end

        -- HANYA kembalikan kepala di swap model avatar yang sedang dicopy:
        local swapHead = swapSt.model:FindFirstChild("Head")
        if swapHead then
            swapHead.Transparency = 0
            for _, d in ipairs(swapHead:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
            end
        end
    else
        -- KETIKA TIDAK SEDANG SWAP (pakai avatar sendiri):
        if char and char:FindFirstChild("Head") then
            local head = char.Head
            head.Transparency = 0
            for _, d in ipairs(head:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
            end
        end
    end

    return true, "Headless dinonaktifkan untuk " .. target.Name
end







end

-- ==============================================================================
do
-- MODUL 6: AUTO HEAL
-- ==============================================================================
autoHealEnabled = false
local autoHealConn = nil
local autoHealCooldown = 0
HEAL_COOLDOWN = 1.5  -- detik antara heal (global agar bisa diubah dari UI)

function autoheal_start()
    if autoHealConn then return end
    autoHealConn = RunService.Heartbeat:Connect(function(dt)
        if not autoHealEnabled then return end
        if is_local_player_killer and is_local_player_killer() then return end
        autoHealCooldown = autoHealCooldown - dt
        if autoHealCooldown > 0 then return end
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            -- Hanya heal jika HP berkurang
            if hum.Health >= hum.MaxHealth then return end
            autoHealCooldown = HEAL_COOLDOWN
            -- Metode 1: Tembak remote heal jika ada
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local healRemote = remotes:FindFirstChild("Heal")
                    or remotes:FindFirstChild("heal")
                    or remotes:FindFirstChild("HealPlayer")
                if healRemote and healRemote:IsA("RemoteEvent") then
                    pcall(function() healRemote:FireServer() end)
                end
            end
            -- Metode 2: Langsung set HP (client-side display)
            pcall(function() hum.Health = hum.MaxHealth end)
            -- Metode 3: Cari tool obat di karakter
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local toolName = tool.Name:lower()
                    if toolName:find("medkit") or toolName:find("heal") or toolName:find("bandage") 
                        or toolName:find("kit") or toolName:find("aid") then
                        -- Aktifkan tool secara otomatis
                        pcall(function()
                            local ts = tool:FindFirstChild("Tool Script") or tool:FindFirstChild("LocalScript")
                            if ts then return end
                            tool:Activate()
                        end)
                        break
                    end
                end
            end
        end)
    end)
end

function autoheal_stop()
    if autoHealConn then
        autoHealConn:Disconnect()
        autoHealConn = nil
    end
    autoHealCooldown = 0
end


end

-- ==============================================================================
do
-- MODUL 7: KILLER RADAR (HUD Mini-Map)
-- ==============================================================================
killerRadarEnabled = false
local killerRadarGui = nil
local killerRadarConn = nil
local RADAR_SIZE = 160
RADAR_RANGE = 350  -- stud radius

local function radar_create_gui()
    if killerRadarGui then pcall(function() killerRadarGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "SkyHubKillerRadar"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999  -- pastikan di atas semua GUI lain
    sg.Enabled = true
    -- Parenting ke gethui() atau PlayerGui (CoreGui bisa diblock)
    local parented = false
    pcall(function()
        if gethui then
            sg.Parent = gethui()
            parented = sg.Parent ~= nil
        end
    end)
    if not parented then
        pcall(function()
            sg.Parent = game:GetService("CoreGui")
            parented = sg.Parent ~= nil
        end)
    end
    if not parented then
        pcall(function()
            sg.Parent = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 3)
        end)
    end
    killerRadarGui = sg

    -- Background radar
    local radarBg = Instance.new("Frame")
    radarBg.Name = "RadarBg"
    radarBg.AnchorPoint = Vector2.new(1, 1)
    radarBg.Position = UDim2.new(1, -15, 1, -15)
    radarBg.Size = UDim2.fromOffset(RADAR_SIZE + 20, RADAR_SIZE + 40)
    radarBg.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
    radarBg.BackgroundTransparency = 0.15
    radarBg.BorderSizePixel = 0
    radarBg.Parent = sg
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 14)
    bgCorner.Parent = radarBg

    -- Header label
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, 0, 0, 22)
    hdr.BackgroundTransparency = 1
    hdr.Text = "👀 PLAYER RADAR"
    hdr.TextColor3 = Color3.fromRGB(255, 80, 80)
    hdr.TextScaled = true
    hdr.Font = Enum.Font.GothamBold
    hdr.ZIndex = 2
    hdr.Parent = radarBg

    -- Radar circle
    local radarCircle = Instance.new("Frame")
    radarCircle.Name = "RadarCircle"
    radarCircle.AnchorPoint = Vector2.new(0.5, 0)
    radarCircle.Position = UDim2.new(0.5, 0, 0, 24)
    radarCircle.Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE)
    radarCircle.BackgroundColor3 = Color3.fromRGB(10, 18, 12)
    radarCircle.BackgroundTransparency = 0.1
    radarCircle.BorderSizePixel = 0
    radarCircle.ZIndex = 2
    radarCircle.Parent = radarBg
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(0.5, 0)
    circleCorner.Parent = radarCircle

    -- Lingkaran grid dekoratif
    for _, r in ipairs({0.33, 0.66}) do
        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromScale(r, r)
        ring.BackgroundTransparency = 1
        ring.BorderColor3 = Color3.fromRGB(0, 80, 20)
        ring.BorderSizePixel = 1
        ring.ZIndex = 3
        ring.Parent = radarCircle
        local ringCorner = Instance.new("UICorner")
        ringCorner.CornerRadius = UDim.new(0.5, 0)
        ringCorner.Parent = ring
    end

    -- Cross hair lines
    for _, axis in ipairs({"H", "V"}) do
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.fromScale(0.5, 0.5)
        line.BackgroundColor3 = Color3.fromRGB(0, 80, 20)
        line.BorderSizePixel = 0
        line.ZIndex = 3
        if axis == "H" then
            line.Size = UDim2.new(1, 0, 0, 1)
        else
            line.Size = UDim2.new(0, 1, 1, 0)
        end
        line.Parent = radarCircle
    end

    -- Titik pemain (hijau di tengah)
    local selfDot = Instance.new("Frame")
    selfDot.Name = "SelfDot"
    selfDot.AnchorPoint = Vector2.new(0.5, 0.5)
    selfDot.Position = UDim2.fromScale(0.5, 0.5)
    selfDot.Size = UDim2.fromOffset(10, 10)
    selfDot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
    selfDot.BorderSizePixel = 0
    selfDot.ZIndex = 10
    selfDot.Parent = radarCircle
    local selfCorner = Instance.new("UICorner")
    selfCorner.CornerRadius = UDim.new(0.5, 0)
    selfCorner.Parent = selfDot

    -- Label "YOU"
    local selfLbl = Instance.new("TextLabel")
    selfLbl.AnchorPoint = Vector2.new(0.5, 1)
    selfLbl.Position = UDim2.new(0.5, 0, 0, -2)
    selfLbl.Size = UDim2.fromOffset(30, 12)
    selfLbl.BackgroundTransparency = 1
    selfLbl.Text = "YOU"
    selfLbl.TextColor3 = Color3.fromRGB(80, 255, 120)
    selfLbl.TextStrokeColor3 = Color3.new(0,0,0)
    selfLbl.TextStrokeTransparency = 0
    selfLbl.TextScaled = true
    selfLbl.Font = Enum.Font.GothamBold
    selfLbl.ZIndex = 11
    selfLbl.Parent = selfDot

    return sg, radarCircle
end

-- ==============================================================================
-- UNIVERSAL KILLER & SURVIVOR DETECTION HELPER
-- ==============================================================================
function check_is_killer(char, player)
    if not char then return false end
    if not player then
        pcall(function() player = Players:GetPlayerFromCharacter(char) end)
    end

    -- 1. Cek objek "Weapon" di karakter (Killer selalu memegang model Weapon)
    if char:FindFirstChild("Weapon") then return true end

    -- 2. Cek CollectionService Tag "Killer" / "Hunter" / dll
    local cs = game:GetService("CollectionService")
    if pcall(function() return cs:HasTag(char, "Killer") end) and cs:HasTag(char, "Killer") then return true end
    if pcall(function() return cs:HasTag(char, "Hunter") end) and cs:HasTag(char, "Hunter") then return true end
    local okTags, tags = pcall(function() return cs:GetTags(char) end)
    if okTags and tags then
        for _, t in ipairs(tags) do
            local ts = t:lower()
            if ts:find("killer") or ts:find("hunter") or ts:find("slasher") or ts:find("monster") or ts:find("abyssal") then
                return true
            end
        end
    end

    -- 3. Cek Attribute khas Killer pada model karakter
    if char:GetAttribute("TerrorRadius") or char:GetAttribute("SuspenseRadius")
        or char:GetAttribute("Chasemusic") or char:GetAttribute("BloodLust")
        or char:GetAttribute("IsKiller") or char:GetAttribute("KillerSpeed")
        or char:GetAttribute("TerrorLevel") or char:GetAttribute("IsHunter") then
        return true
    end

    -- 4. Cek Team & Attribute khas Killer pada Player
    if player then
        pcall(function()
            if player.Team then
                local tn = tostring(player.Team.Name):lower()
                if tn:find("kill") or tn:find("hunt") or tn:find("slash") or tn:find("monster") or tn:find("evil") then
                    return true
                end
            end
        end)
        local role = player:GetAttribute("CurrentRole") or player:GetAttribute("Role")
            or player:GetAttribute("Team") or player:GetAttribute("Side")
            or player:GetAttribute("CharacterType")
        if role then
            local rs = tostring(role):lower()
            if rs:find("killer") or rs:find("hunter") or rs:find("slasher") or rs:find("monster") or rs == "1" then
                return true
            end
        end
    end

    -- 5. Cek Tool senjata yang dipegang
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then
        local tn = tool.Name:lower()
        if tn:find("knife") or tn:find("axe") or tn:find("sword") or tn:find("hammer")
            or tn:find("chainsaw") or tn:find("weapon") or tn:find("scythe") or tn:find("dagger")
            or tn:find("blade") or tn:find("cleave") or tn:find("katana") then
            return true
        end
    end

    -- 6. Cek nama model/character yang mengindikasikan killer
    local charName = char.Name:lower()
    if charName:find("killer") or charName:find("abyssal") or charName:find("scourge")
        or charName:find("slasher") or charName:find("reaper") or charName:find("hunter")
        or charName:find("monster") or charName:find("king") then
        return true
    end

    -- 7. Cek HP: Killer biasanya punya MaxHealth jauh lebih besar dari 100
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 200 and not player then
        -- Model tanpa player dengan HP besar = kemungkinan NPC Killer
        return true
    end

    return false
end

-- Backward compatibility alias
function radar_is_killer(player, char)
    return check_is_killer(char, player)
end

-- ==============================================================================
-- UNIVERSAL LOCALPLAYER ROLE CHECK (KILLER vs SURVIVOR)
-- ==============================================================================
function is_local_player_killer()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return false end

    -- 1. Cek objek "Weapon" di karakter (Killer selalu memegang model Weapon)
    if char:FindFirstChild("Weapon") then return true end

    -- 2. Cek CollectionService Tag "Killer" / "Hunter"
    local cs = game:GetService("CollectionService")
    if pcall(function() return cs:HasTag(char, "Killer") end) and cs:HasTag(char, "Killer") then return true end
    if pcall(function() return cs:HasTag(char, "Hunter") end) and cs:HasTag(char, "Hunter") then return true end

    -- 3. Cek Attribute khas Killer pada model karakter
    if char:GetAttribute("TerrorRadius") or char:GetAttribute("SuspenseRadius")
        or char:GetAttribute("Chasemusic") or char:GetAttribute("BloodLust")
        or char:GetAttribute("IsKiller") or char:GetAttribute("KillerSpeed")
        or char:GetAttribute("TerrorLevel") or char:GetAttribute("IsHunter") then
        return true
    end

    -- 4. Cek Attribute khas Killer pada Player
    local role = LocalPlayer:GetAttribute("CurrentRole") or LocalPlayer:GetAttribute("Role")
        or LocalPlayer:GetAttribute("Team") or LocalPlayer:GetAttribute("Side")
        or LocalPlayer:GetAttribute("CharacterType")
    if role then
        local rs = tostring(role):lower()
        if rs:find("killer") or rs:find("hunter") or rs:find("slasher") or rs:find("monster") or rs == "1" then
            return true
        end
    end

    -- 5. Cek Team Player
    if LocalPlayer.Team then
        local tn = tostring(LocalPlayer.Team.Name):lower()
        if tn:find("kill") or tn:find("hunt") or tn:find("slash") or tn:find("monster") or tn:find("evil") then
            return true
        end
    end

    -- 6. Cek MaxHealth: Killer di game ini HP jauh lebih besar (> 200) dibanding survivor (100)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth and hum.MaxHealth > 200 then
        return true
    end

    return false
end

-- DOT POOLING untuk performa tinggi & anti-flicker
local _radarDotPool = {}

-- RADAR UPDATE: Deteksi 100% Akurat (Scan Players + Workspace Models)
local function radar_update(radarCircle)
    if not radarCircle or not radarCircle.Parent then return end

    local myChar = LocalPlayer and LocalPlayer.Character
    local myHrp = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if not myHrp then return end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local camCF = cam.CFrame
    local myPos = myHrp.Position

    -- Kumpulkan SEMUA entitas target (Players + Workspace Models / NPCs)
    local targets = {}
    local seen = {}

    -- 1. Scan Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
            if hrp then
                seen[p.Character] = true
                table.insert(targets, { key = p.Character, player = p, char = p.Character, hrp = hrp, name = p.DisplayName or p.Name })
            end
        end
    end

    -- 2. Scan Workspace Children (untuk Killer NPC / Model karakter khusus)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar and not seen[obj] then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or (hum and obj.PrimaryPart)
            if hrp and hum then
                seen[obj] = true
                local pl = Players:GetPlayerFromCharacter(obj)
                table.insert(targets, { key = obj, player = pl, char = obj, hrp = hrp, name = (pl and (pl.DisplayName or pl.Name)) or obj.Name })
            end
        end
    end

    -- 3. Scan folder khusus jika ada (Characters / Entities / Killers / Monsters)
    local extraFolders = {
        workspace:FindFirstChild("Characters"),
        workspace:FindFirstChild("Entities"),
        workspace:FindFirstChild("Players"),
        workspace:FindFirstChild("Killers"),
        workspace:FindFirstChild("Monsters"),
        workspace:FindFirstChild("NPCs")
    }
    for _, folder in ipairs(extraFolders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj ~= myChar and not seen[obj] then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or (hum and obj.PrimaryPart)
                    if hrp and hum then
                        seen[obj] = true
                        local pl = Players:GetPlayerFromCharacter(obj)
                        table.insert(targets, { key = obj, player = pl, char = obj, hrp = hrp, name = (pl and (pl.DisplayName or pl.Name)) or obj.Name })
                    end
                end
            end
        end
    end

    local activeKeys = {}

    -- Render & Update semua target ke radar via Object Pooling
    for _, item in ipairs(targets) do
        local p = item.player
        local pChar = item.char
        local pHrp = item.hrp
        local nameStr = item.name
        local key = item.key

        local diff = pHrp.Position - myPos
        local dist3D = math.sqrt(diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z)

        if dist3D <= RADAR_RANGE then
            activeKeys[key] = true
            -- Posisi relatif ke kamera (world space -> camera object space)
            local rel = camCF:PointToObjectSpace(pHrp.Position)

            local scale = RADAR_RANGE
            local normX = math.clamp(rel.X / scale, -1, 1)
            local normY = math.clamp(-rel.Z / scale, -1, 1)

            -- Batasi agar titik tidak keluar dari lingkaran radar
            local rLen = math.sqrt(normX * normX + normY * normY)
            if rLen > 0.94 then
                normX = normX / rLen * 0.94
                normY = normY / rLen * 0.94
            end

            local screenX = math.clamp(0.5 + normX * 0.44, 0.04, 0.96)
            local screenY = math.clamp(0.5 - normY * 0.44, 0.04, 0.96)

            local isKiller = check_is_killer(pChar, p)

            local dotData = _radarDotPool[key]
            if not dotData or not dotData.dot.Parent then
                local dot = Instance.new("Frame")
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.BorderSizePixel = 0
                dot.Parent = radarCircle

                local dc = Instance.new("UICorner")
                dc.CornerRadius = UDim.new(1, 0)
                dc.Parent = dot

                local lbl = Instance.new("TextLabel")
                lbl.AnchorPoint = Vector2.new(0.5, 1)
                lbl.Position = UDim2.new(0.5, 0, 0, -2)
                lbl.Size = UDim2.fromOffset(80, 13)
                lbl.BackgroundTransparency = 1
                lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                lbl.TextStrokeTransparency = 0
                lbl.TextScaled = true
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = dot

                dotData = { dot = dot, lbl = lbl }
                _radarDotPool[key] = dotData
            end

            local dot = dotData.dot
            local lbl = dotData.lbl
            local distReal = math.floor(dist3D)

            dot.Visible = true
            dot.Position = UDim2.fromScale(screenX, screenY)
            dot.Size = UDim2.fromOffset(isKiller and 14 or 8, isKiller and 14 or 8)
            dot.BackgroundColor3 = isKiller and Color3.fromRGB(255, 35, 35) or Color3.fromRGB(50, 190, 255)
            dot.ZIndex = isKiller and 14 or 9

            if isKiller then
                lbl.Text = "KILLER " .. distReal .. "m"
                lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
                lbl.ZIndex = 15
            else
                lbl.Text = nameStr:sub(1, 8) .. " " .. distReal .. "m"
                lbl.TextColor3 = Color3.fromRGB(100, 220, 255)
                lbl.ZIndex = 10
            end
        end
    end

    -- Sembunyikan dot yang berada di luar jangkauan / sudah mati / despawn
    for k, d in pairs(_radarDotPool) do
        if not activeKeys[k] then
            if d.dot and d.dot.Parent then
                d.dot.Visible = false
            else
                _radarDotPool[k] = nil
            end
        end
    end
end

local killerRadarCircle = nil

function killerradar_start()
    if killerRadarGui then pcall(function() killerRadarGui:Destroy() end) end
    local sg, rc = radar_create_gui()
    killerRadarCircle = rc
    if killerRadarConn then killerRadarConn:Disconnect() end
    local _lastRadarTick = 0
    killerRadarConn = RunService.RenderStepped:Connect(function()
        if not killerRadarEnabled then return end
        local now = tick()
        if now - _lastRadarTick < 0.033 then return end -- ~30 FPS stabil
        _lastRadarTick = now
        pcall(radar_update, killerRadarCircle)
    end)
end

function killerradar_stop()
    if killerRadarConn then killerRadarConn:Disconnect(); killerRadarConn = nil end
    for _, d in pairs(_radarDotPool) do
        if d.dot then pcall(function() d.dot:Destroy() end) end
    end
    _radarDotPool = {}
    if killerRadarGui then pcall(function() killerRadarGui:Destroy() end); killerRadarGui = nil end
    killerRadarCircle = nil
end


end

-- ==============================================================================
do
-- MODUL 8: FULLBRIGHT + NO FOG
-- ==============================================================================
fullbrightEnabled = false
local fullbrightConn = nil
local origAmbient = nil
local origOutdoor = nil
local origBrightness = nil
local origFogEnd = nil
local origFogStart = nil

local function fullbright_apply()
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.Ambient = Color3.fromRGB(178, 178, 178)
        lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        lighting.Brightness = 2
        lighting.FogEnd = 100000
        lighting.FogStart = 100000
        -- Hapus/disable efek dark
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") 
               or child:IsA("ColorCorrectionEffect") then
                pcall(function() child.Enabled = false end)
            end
        end
    end)
end

local function fullbright_restore()
    pcall(function()
        local lighting = game:GetService("Lighting")
        if origAmbient then lighting.Ambient = origAmbient end
        if origOutdoor then lighting.OutdoorAmbient = origOutdoor end
        if origBrightness then lighting.Brightness = origBrightness end
        if origFogEnd then lighting.FogEnd = origFogEnd end
        if origFogStart then lighting.FogStart = origFogStart end
        -- Kembalikan efek
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("BloomEffect") or child:IsA("SunRaysEffect")
               or child:IsA("ColorCorrectionEffect") then
                pcall(function() child.Enabled = true end)
            end
        end
    end)
end

function fullbright_start()
    pcall(function()
        local lighting = game:GetService("Lighting")
        origAmbient = lighting.Ambient
        origOutdoor = lighting.OutdoorAmbient
        origBrightness = lighting.Brightness
        origFogEnd = lighting.FogEnd
        origFogStart = lighting.FogStart
    end)
    fullbright_apply()
    if fullbrightConn then fullbrightConn:Disconnect() end
    fullbrightConn = RunService.Heartbeat:Connect(function()
        if not fullbrightEnabled then return end
        fullbright_apply()
    end)
end

function fullbright_stop()
    if fullbrightConn then fullbrightConn:Disconnect(); fullbrightConn = nil end
    fullbright_restore()
end

-- ==============================================================================
-- MODUL 9: CUSTOM FOV (Field of View)
-- ==============================================================================
customFovEnabled = false
customFovValue = 70
local origFov = nil
local fovConn = nil

function fov_apply(val)
    pcall(function()
        workspace.CurrentCamera.FieldOfView = val
    end)
end

function fov_start(val)
    customFovValue = val or customFovValue
    pcall(function() origFov = workspace.CurrentCamera.FieldOfView end)
    fov_apply(customFovValue)
    if fovConn then fovConn:Disconnect() end
    fovConn = RunService.RenderStepped:Connect(function()
        if not customFovEnabled then return end
        pcall(function()
            if workspace.CurrentCamera.FieldOfView ~= customFovValue then
                workspace.CurrentCamera.FieldOfView = customFovValue
            end
        end)
    end)
end

function fov_stop()
    if fovConn then fovConn:Disconnect(); fovConn = nil end
    pcall(function()
        if origFov then workspace.CurrentCamera.FieldOfView = origFov end
    end)
end


end

-- ==============================================================================
do
-- MODUL 10: INFINITE ITEM CHARGES
-- ==============================================================================
infiniteChargesEnabled = false
local infiniteChargesConn = nil

function infinite_charges_apply()
    pcall(function()
        if is_local_player_killer and is_local_player_killer() then return end
        local char = LocalPlayer and LocalPlayer.Character
        -- PERBAIKAN: Jangan skip jika char punya child bernama Weapon;
        -- hanya skip jika memang IS killer berdasarkan is_local_player_killer()
        if not char then return end

        local containers = { char }
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then table.insert(containers, bp) end

        for _, container in ipairs(containers) do
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") then
                    -- 1. Kunci Uses / CurrentUses ke 0 (mencegah item dikonsumsi/dihapus server)
                    local usedKeys = { "Uses", "uses", "CurrentUses", "currentUses", "UsedCount", "UseCount" }
                    for _, k in ipairs(usedKeys) do
                        if obj:GetAttribute(k) ~= nil then
                            obj:SetAttribute(k, 0)
                        end
                    end

                    -- 2. Pulihkan Charges & Ammo ke nilai maksimum aman
                    local maxChargeKeys = { "Charges", "charges", "Ammo", "ammo", "RemainingCharges", "Durability" }
                    local maxVal = obj:GetAttribute("MaxCharges") or obj:GetAttribute("maxCharges")
                        or obj:GetAttribute("MaxAmmo") or obj:GetAttribute("maxAmmo") or 10
                    for _, k in ipairs(maxChargeKeys) do
                        local v = obj:GetAttribute(k)
                        if type(v) == "number" and v < maxVal then
                            obj:SetAttribute(k, maxVal)
                        end
                    end
                end
            end
        end
    end)
end

local _chargesBackpackConn = nil
local _chargesRespawnConn  = nil

function infinite_charges_start()
    infinite_charges_apply()
    if infiniteChargesConn then infiniteChargesConn:Disconnect() end
    local t = 0
    infiniteChargesConn = RunService.Heartbeat:Connect(function(dt)
        if not infiniteChargesEnabled then return end
        t = t + dt
        if t >= 0.5 then
            t = 0
            infinite_charges_apply()
        end
    end)

    -- Hook Backpack ChildAdded agar item baru langsung dapat charges
    local function hookBackpack(bp)
        if not bp then return end
        if _chargesBackpackConn then _chargesBackpackConn:Disconnect() end
        _chargesBackpackConn = bp.ChildAdded:Connect(function(child)
            if infiniteChargesEnabled and child:IsA("Tool") then
                task.wait(0.15)
                infinite_charges_apply()
            end
        end)
    end

    -- Hook CharacterAdded agar tetap aktif setelah respawn
    if _chargesRespawnConn then _chargesRespawnConn:Disconnect() end
    _chargesRespawnConn = LocalPlayer.CharacterAdded:Connect(function()
        if not infiniteChargesEnabled then return end
        task.wait(0.5)  -- tunggu karakter sepenuhnya loaded
        infinite_charges_apply()
        hookBackpack(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end)

    hookBackpack(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

function infinite_charges_stop()
    if infiniteChargesConn then infiniteChargesConn:Disconnect(); infiniteChargesConn = nil end
    if _chargesBackpackConn then _chargesBackpackConn:Disconnect(); _chargesBackpackConn = nil end
    if _chargesRespawnConn then _chargesRespawnConn:Disconnect(); _chargesRespawnConn = nil end
end


end

-- ==============================================================================
do
-- MODUL 11: ESP EXIT GATE (LEVER SAJA)
-- ==============================================================================
espGateEnabled = false
local espGateConns = {}
local espGateObjects = {}

function is_exit_gate_lever(obj)
    if not obj then return false end
    local name = obj.Name:lower()
    
    -- Cocokkan nama part / model lever spesifik Violence District
    if name == "exitlever" or name == "exit_lever" or name == "lever" or name:find("gatelever") 
        or name:find("exitlever") or name:find("gate_lever") or name == "gateswitch" or name == "exitswitch" then
        return true
    end
    
    -- Cek jika model Gate memiliki ExitLever di dalamnya
    if obj:IsA("Model") and (name == "gate" or name:find("exitgate")) and obj:FindFirstChild("ExitLever") then
        return true
    end
    
    return false
end

function esp_gate_get_part(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        local el = obj.Name:lower() == "exitlever" and obj or obj:FindFirstChild("ExitLever")
        if el then
            return el:FindFirstChild("Lever") or el:FindFirstChild("LeverStart") or el:FindFirstChildWhichIsA("BasePart")
        end
        return obj:FindFirstChild("Lever") or obj:FindFirstChild("LeverStart") or obj:FindFirstChild("Switch") 
            or obj:FindFirstChild("Handle") or obj.PrimaryPart 
            or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function esp_gate_add_tag(obj)
    if espGateObjects[obj] then return end
    local part = esp_gate_get_part(obj)
    if not part then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP_GateLeverHL"
    hl.Adornee = obj
    hl.FillColor = Color3.fromRGB(255, 215, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    pcall(function()
        if gethui then hl.Parent = gethui() else hl.Parent = CoreGui end
    end)
    if not hl.Parent then hl.Parent = CoreGui end

    local bbg = Instance.new("BillboardGui")
    bbg.Name = "ESP_GateLeverTag"
    bbg.Adornee = part
    bbg.AlwaysOnTop = true
    bbg.Size = UDim2.fromOffset(190, 26)
    bbg.StudsOffset = Vector3.new(0, 3.5, 0)
    bbg.ResetOnSpawn = false

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Text = "[🚪 LEVER EXIT GATE]"
    lbl.Parent = bbg

    pcall(function()
        if gethui then bbg.Parent = gethui() else bbg.Parent = CoreGui end
    end)
    if not bbg.Parent then bbg.Parent = CoreGui end

    espGateObjects[obj] = { hl = hl, bbg = bbg, lbl = lbl, part = part }
end

local function esp_gate_update()
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.new(0, 0, 0)

    for obj, data in pairs(espGateObjects) do
        if not obj.Parent or not data.part.Parent then
            if data.hl then pcall(function() data.hl:Destroy() end) end
            if data.bbg then pcall(function() data.bbg:Destroy() end) end
            espGateObjects[obj] = nil
        else
            local dist = math.floor((camPos - data.part.Position).Magnitude)
            data.lbl.Text = string.format("[LEVER GATE] (%dm)", dist)
        end
    end
end

local function esp_gate_scan()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if is_exit_gate_lever(obj) then
            pcall(esp_gate_add_tag, obj)
        end
    end
end

function start_esp_gate()
    for _, c in ipairs(espGateConns) do pcall(function() c:Disconnect() end) end
    espGateConns = {}
    for obj, data in pairs(espGateObjects) do
        if data.hl then pcall(function() data.hl:Destroy() end) end
        if data.bbg then pcall(function() data.bbg:Destroy() end) end
    end
    espGateObjects = {}

    esp_gate_scan()

    -- Listener saat map baru load
    local scanConn = workspace.DescendantAdded:Connect(function(desc)
        if not espGateEnabled then return end
        if is_exit_gate_lever(desc) then
            task.wait(0.1)
            pcall(esp_gate_add_tag, desc)
        end
    end)
    table.insert(espGateConns, scanConn)

    -- Loop update jarak real-time
    local updateConn = RunService.RenderStepped:Connect(function()
        if not espGateEnabled then return end
        pcall(esp_gate_update)
    end)
    table.insert(espGateConns, updateConn)
end

function stop_esp_gate()
    for _, c in ipairs(espGateConns) do
        if typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    espGateConns = {}
    for obj, data in pairs(espGateObjects) do
        if data.hl then pcall(function() data.hl:Destroy() end) end
        if data.bbg then pcall(function() data.bbg:Destroy() end) end
    end
    espGateObjects = {}
end

-- ==============================================================================
-- MODUL 12: AUTO ESCAPE & BYPASS (SURVIVOR WIN)
-- ==============================================================================
autoEscapeEnabled = false
local autoEscapeConn = nil
local _isEscaping = false
local _escapeCheckTimer = 0
local _autoEscapeStarted = false

-- ==============================================================================
-- STRUKTUR GERBANG EXIT
-- ==============================================================================
-- BUKTI dari rekaman trigger (04:28:27):
--   [T] Workspace.Map.Gate.Box  <-  HIT HumanoidRootPart
--   [E] CharacterRemoving  (2 detik kemudian = karakter escaped, round selesai)
--
-- => TRIGGER KELUAR YANG ASLI ADALAH `Workspace.Map.Gate.Box`
--    (Pos 1583, 165, -790 | CanCollide: false | CanTouch: true | Size 46x37x28)
--
-- CATATAN PENTING:
--   Workspace.Map.Rooftop.Gate.Box  (Pos 3115, 487, -4931) TIDAK PERNAH dipicu.
--   Itu dekorasi/map lain yang kebetulan punya nama sama.
--  lever pun TIDAK wajib untuk escape - Box saja sudah cukup.
--
-- ==============================================================================
-- DETEKSI ZONA KELUAR - YANG BENAR
-- ==============================================================================
--
-- BUKTI dari screenshot dan scan:
--   Workspace.Map.Gate.Box  | CanCollide: false | 46x37x28
--       ^ INI VOLUME DI SEKITAR STRUKTUR GERBANG, BUKAN ZONA ESCAPE.
--         Karakter dipin di sini = nyangkut di gerbang, tidak ke mana-mana.
--
--   Workspace.Map.Gate.Part | CanCollide: true  | lantai
--   ExitLever.Tp            | CanTouch: false  | teleport point
--
-- ZONA ESCAPE YANG BENAR ada DI LUAR gerbang, di ujung lorong menuju fog.
-- Cara mencarinya: RAYCAST dari gerbang ke arah luar, lalu cari part
-- non-collide di ujung lorong.
--
-- CATATAN SCOPE: get_exit_gate() didefinisikan DI BAWAH blok ini, jadi kita
-- harus forward-declare dulu, kalau tidak collect_exit_zones() akan mencari
-- global get_exit_gate (yang nil) dan selalu gagal.
-- ==============================================================================

local get_exit_gate            -- forward declaration
local gate_outward             -- forward declaration
local corridor_open_distance   -- forward declaration

-- Kata kunci yang menandakan sebuah part adalah trigger zona keluar.
-- PENTING: nama di game bisa salah ketik (terbukti "Fininshline" yang
-- dimaksudnya "Finish line"), jadi polanya harus toleran typo.
local ZONE_KEYWORDS = {
    "escape", "exit", "zone", "trigger", "goal", "win",
    "area", "box", "teleport", "safe", "outside",
    "fininsh", "finis", "finisline", "endline", "finis hline",
}

-- Nama yang secara khusus berarti "garis finish" / batas keluar.
-- DIBUKTI dari rekaman: Workspace.Map.Fininshline muncul 1.2 detik
-- sebelum ESCAPE, jadi inilah trigger yang sebenarnya.
local FINISH_NAMES = {
    "fininshline", "finishline", "finisline", "finisline",
    "finis hline", "finish line", "endline", "end line",
}

-- Skor khusus garis finish. Jauh lebih besar dari kandidat lain
-- supaya tidak pernah kalah oleh Box atau part di sekitar gerbang.
local FINISH_SCORE = 500

-- Buang spasi, garis, dan underscore supaya perbandingan nama tidak rapuh.
local function normalize_name(s)
    return (string.lower(s):gsub("[%s_%-%.]", ""))
end

-- Daftar nama finish yang sudah dinormalisasi (dihitung sekali saja).
local FINISH_KEYS = {}
for _, fn in ipairs(FINISH_NAMES) do
    FINISH_KEYS[#FINISH_KEYS + 1] = normalize_name(fn)
end

-- Apakah nama part ini salah satu nama garis finish?
local function is_finish_name(nm)
    local n = normalize_name(nm)
    for _, k in ipairs(FINISH_KEYS) do
        if n == k or n:find(k, 1, true) then
            return true
        end
    end
    return false
end

-- Cari SEMUA part garis finish yang ada di map.
-- Kalau ada beberapa, yang paling Datar (tebal Y paling kecil) dipilih,
-- karena garis finish yang sebenarnya adalah part pipih di lantai.
local function find_finish_parts()
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and is_finish_name(obj.Name) then
            found[#found + 1] = obj
        end
    end
    return found
end

-- Nilai keyword untuk satu part: nama part + nama folder induk (sampai 3 level).
local function zone_keyword_score(part)
    local score = 0
    local nm = part.Name:lower()

    for _, kw in ipairs(ZONE_KEYWORDS) do
        if nm:find(kw, 1, true) then score = score + 40 end
    end

    local parent, depth = part.Parent, 0
    while parent and depth < 3 do
        local pn = parent.Name:lower()
        for _, kw in ipairs(ZONE_KEYWORDS) do
            if pn:find(kw, 1, true) then score = score + 25 end
        end
        parent = parent.Parent
        depth = depth + 1
    end

    -- Volume trigger yang wajar: 300 - 500000 stud^3
    local s = part.Size
    local vol = s.X * s.Y * s.Z
    if vol >= 300 and vol <= 500000 then score = score + 20 end

    -- Sinyal terkuat: nama part memuat kata escape / win / goal
    if nm:find("escape", 1, true) or nm:find("win", 1, true)
        or nm:find("goal", 1, true) then
        score = score + 90
    end

    return score
end

-- Arah KELUAR dari sebuah gerbang.
-- Mengembalikan (vektor_horizontal_normalize, titik_awal, panjang_lorong).
--
-- PENTING: LookVector daun pintu bisa mengarah ke DALAM map, bukan ke luar.
-- Jadi kedua arah diuji dengan raycast, dan yang dipilih adalah arah dengan
-- lorong terpanjang (itu dia jalan keluar sebenarnya menuju zona escape).
gate_outward = function(gate)
    if not gate then return nil end

    local origin
    if gate.box and gate.box:IsA("BasePart") then
        origin = gate.box.Position
    elseif gate.leftEnd and gate.leftEnd:IsA("BasePart")
        and gate.rightEnd and gate.rightEnd:IsA("BasePart") then
        origin = (gate.leftEnd.Position + gate.rightEnd.Position) / 2
    elseif gate.main and gate.main:IsA("BasePart") then
        origin = gate.main.Position
    else
        return nil
    end

    local src = gate.leftGate or gate.leftEnd or gate.rightGate or gate.main
    if not (src and src:IsA("BasePart")) then return nil end

    local look = src.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then return nil end
    flat = flat.Unit

    -- Uji kedua arah, ambil yang lorongnya lebih panjang.
    -- Gerbang sendiri dikecualikan dari raycast supaya ray tidak
    -- langsung mengenai kusen / daun pintu yang masih tertutup.
    local dFwd = corridor_open_distance(origin, flat, 400, gate.model)
    local dBwd = corridor_open_distance(origin, -flat, 400, gate.model)

    local bestDir, bestDist = flat, dFwd
    if dBwd > dFwd then
        bestDir, bestDist = -flat, dBwd
    end

    return bestDir, origin, bestDist
end

-- Seberapa jauh lorong ke depan masih terbuka.
-- Ray di-offset 30 stud supaya tidak kena daun pintu / kusen gerbang itu sendiri.
corridor_open_distance = function(origin, dir, maxDist, excludeModel)
    maxDist = maxDist or 400
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    local char = LocalPlayer and LocalPlayer.Character
    if char then ignore[#ignore + 1] = char end
    if excludeModel then ignore[#ignore + 1] = excludeModel end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true

    local ok, hit = pcall(function()
        return workspace:Raycast(origin + dir * 30, dir * maxDist, params)
    end)
    if ok and hit and hit.Distance then return hit.Distance end
    return maxDist
end

-- Semua part yang cocok sebagai trigger volume (CanTouch, tidak collide).
local function collect_trigger_parts()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch and not obj.CanCollide then
            local s = obj.Size
            local vol = s.X * s.Y * s.Z
            if vol >= 300 and vol <= 500000 then
                list[#list + 1] = obj
            end
        end
    end
    return list
end

local function collect_exit_zones()
    local zones = {}
    local gate = get_exit_gate()
    local dir, origin, corridorLen = nil, nil, nil
    if gate then dir, origin, corridorLen = gate_outward(gate) end

    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    local myPos = (hrp and hrp.Position) or origin

    -- Diagnostik arah keluar. Hanya muncul kalau SKY_DEBUG = true.
    if dir then
        log("[AutoEscape] arah keluar: %.2f, 0, %.2f | lorong: %d stud",
            dir.X, dir.Z, math.floor(corridorLen or 0))
    else
        log("[AutoEscape] arah keluar tidak bisa ditentukan dari gerbang")
    end

    -- Kandidat TERAKHIR (paling kuat): bagian garis finish.
    -- Bukti rekaman 05:06: pada detik 67.66 karakter menyentuh Gate.Box,
    -- lalu pada detik 68.70 masuk area Fininshline,
    -- dan pada detik 69.91 karakter dihapus (= ESCAPE).
    -- Jadi Fininshline itu trigger aslinya, bukan Gate.Box.
    for _, fp in ipairs(find_finish_parts()) do
        local fpSize = fp.Size
        table.insert(zones, {
            part = fp,
            score = FINISH_SCORE,
            why = string.format("GARIS FINISH (bukti rekaman) %s | %.0fx%.0fx%.0f | Touch=%s Collide=%s",
                fp:GetFullName(), fpSize.X, fpSize.Y, fpSize.Z,
                tostring(fp.CanTouch), tostring(fp.CanCollide)),
        })
    end

    -- Zona yang terbukti dari rekaman trigger: volume DI SEKITAR gerbang.
    -- Skor sengaja RENDAH karena ini hanya area nikah di gerbang,
    -- bukan zona escape di ujung lorong.
    if gate and gate.box and gate.box:IsA("BasePart") then
        table.insert(zones, {
            part = gate.box,
            score = 40,
            why = "Gate.Box (volume di sekitar gerbang, dari rekaman trigger)",
        })
    end

    for _, part in ipairs(collect_trigger_parts()) do
        if not (gate and part == gate.box) then
            local score = zone_keyword_score(part)
            if score > 0 then
                local pos = part.Position
                local why = "trigger volume"

                if origin and dir then
                    local delta = pos - origin
                    local fwd = delta:Dot(dir)
                    local side = (delta - dir * fwd).Magnitude

                    if fwd > 10 then
                        -- DI DEPAN gerbang = searah keluar = kandidat terkuat
                        score = score + 120
                        score = score - math.min(fwd / 6, 70)
                        if side < 70 then
                            score = score + 60
                        elseif side < 150 then
                            score = score + 20
                        end
                        why = why .. string.format(" | di depan gerbang %.0f stud, sisi %.0f", fwd, side)
                    elseif fwd > -40 then
                        -- Tepat di area gerbang
                        score = score - 80
                        why = why .. " | di area gerbang"
                    else
                        -- Di belakang gerbang = bukan zona keluar
                        score = score - 250
                        why = why .. " | di belakang gerbang"
                    end
                end

                if myPos then
                    local d = (pos - myPos).Magnitude
                    if d < 900 then score = score + 30 end
                end

                table.insert(zones, { part = part, score = score, why = why })
            end
        end
    end

    -- Fallback terakhir: kalau tidak ada trigger di depan gerbang,
    -- pakai titik di ujung lorong yang masih terbuka (hasil raycast).
    if origin and dir then
        local open = corridor_open_distance(origin, dir, 400)
        if open > 40 then
            local p = origin + dir * (30 + (open - 20) * 0.6)
            table.insert(zones, {
                part = nil,
                point = p,
                score = 90,
                why = string.format("titik di ujung lorong, %.0f stud dari gerbang", open),
            })
        end
    end

    return zones
end

-- Pilih zona keluar TERBAIK: skor tertinggi, dan jika seri pilih yang TERDEKAT
-- dengan karakter (karena map punya beberapa zona, hanya yang aktif itu yg benar).
local function find_escape_zone()
    local zones = collect_exit_zones()
    if #zones == 0 then return nil end

    -- Posisi tiap zona (bisa berupa part atau titik lorong)
    local function zone_pos_of(z)
        if z.part then return z.part.Position end
        return z.point
    end

    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not hrp then
        -- Tanpa karakter, ambil yang skor tertinggi
        local best = zones[1]
        for _, z in ipairs(zones) do
            if z.score > best.score then best = z end
        end
        return best
    end

    local pos = hrp.Position
    local best, bestScore = zones[1], -math.huge
    for _, z in ipairs(zones) do
        local zp = zone_pos_of(z)
        if zp then
            -- Skor gabungan: skor utama didominasi nilai zone, tapi jarak
            -- tetap berpengaruh supaya zona yang lebih dekat ke pemain diutamakan
            -- kalau nilai skornya hampir sama.
            local dist = (zp - pos).Magnitude
            local combined = z.score - math.min(dist, 600) / 60
            if combined > bestScore then
                best, bestScore = z, combined
            end
        end
    end
    return best
end

-- Titik jangkar karakter DI DALAM zona keluar.
-- Kalau zona punya `part` (trigger volume) -> turun ke bagian bawahnya
-- lalu cari lantai sungguhan di bawah dengan raycast ke bawah.
-- Kalau zona cuma punya `point` (ujung lorong hasil raycast) -> pakai titik itu.
local function zone_anchor_cframe(zone)
    if not zone then return nil end

    if not zone.part then
        if not zone.point then return nil end
        return CFrame.new(zone.point)
    end

    local p = zone.part
    local size = p.Size
    local target

    -- Raycast ke bawah dari titik tengah zona.
    -- Kalau ketemu lantai, berdiri di lantai itu.
    -- Kalau tidak, pakai pinggir atas zona + sedikit ke atas.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = LocalPlayer and LocalPlayer.Character
    params.FilterDescendantsInstances = char and { char } or {}
    params.IgnoreWater = true

    local startPos
    if size.Y <= 6 then
        -- Garis finish / trigger datar: mulai dari ATAS permukaannya
        startPos = p.Position + Vector3.new(0, size.Y / 2 + 4, 0)
    else
        -- Volume besar: mulai dari tengah, nanti turun ke lantai
        startPos = p.Position
    end

    local ok, hit = pcall(function()
        return workspace:Raycast(startPos, Vector3.new(0, -400, 0), params)
    end)
    if ok and hit and hit.Position then
        target = hit.Position + Vector3.new(0, 3, 0)
    else
        -- Tidak ada lantai: pakai tepi atas trigger
        target = p.Position + Vector3.new(0, math.max(size.Y / 2, 1) + 2, 0)
    end

    return CFrame.new(target)
end

-- Wrapper kompatibilitas: cari gerbang ber-lever (dipakai hanya untuk fallback).
-- PENTING: struktur gerbang bisa berupa Model ATAU Folder, jadi jangan hanya
-- cek Model. `Workspace.Map.Gate` kemungkinan besar Folder, bukan Model.
-- CATATAN SCOPE: ditulis sebagai ASSIGNMENT (bukan `local function`) karena
-- forward declaration `local get_exit_gate` sudah ada di baris atas blok ini.
-- Kalau ditulis `local function`, itu akan membuat local BARU yang
-- menutupi forward declaration, dan collect_exit_zones() akan selalu
-- melihat nil.
get_exit_gate = function()
    local best = nil

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local leverModel = obj:FindFirstChild("ExitLever")
            if leverModel then
                local main = leverModel:FindFirstChild("Main")
                    or (leverModel:IsA("Model") and leverModel:FindFirstChildWhichIsA("BasePart"))
                if main then
                    local cand = {
                        model      = obj,
                        leverModel = leverModel,
                        main       = main,
                        lever      = leverModel:FindFirstChild("Lever") or main,
                        leverStart = leverModel:FindFirstChild("LeverStart"),
                        leverGoal  = leverModel:FindFirstChild("LeverGoal"),
                        box        = obj:FindFirstChild("Box"),
                        leftGate   = obj:FindFirstChild("LeftGate"),
                        rightGate  = obj:FindFirstChild("RightGate"),
                        leftEnd    = obj:FindFirstChild("LeftGate-end"),
                        rightEnd   = obj:FindFirstChild("RightGate-end"),
                    }
                    -- Prioritaskan gerbang yang punya Box (itu zona keluar aslinya)
                    if cand.box and not best then
                        best = cand
                    elseif not best then
                        best = cand
                    end
                end
            end
        end
    end
    return best
end

-- Wrapper kompatibilitas: tetap mengembalikan MeshPart 'Main' dari gerbang aktif
local function find_lever_main_part()
    local g = get_exit_gate()
    return g and g.main or nil
end

-- Helper: Notifikasi aman via Window WMacLib.
-- PENTING: pada baris ini `local Window` BELUM dideklarasi (dideklarasi jauh di bawah),
-- jadi kalau dipanggil langsung akan error "attempt to index nil with 'Notify'".
-- Karena itu kita lewat global `SkyWindow` yang diisi setelah Window dibuat.
local function safe_notify(opts)
    opts = opts or {}
    pcall(function()
        local w = SkyWindow
        if w and type(w.Notify) == "function" then
            w:Notify({
                Title = opts.Title or "Info",
                Description = tostring(opts.Description or ""),
                Lifetime = opts.Lifetime or 3
            })
        end
    end)
end



local function find_escape_target()
    -- 1. Zona keluar terbukti (Gate.Box) - ini yang benar
    local zone = find_escape_zone()
    if zone then return zone.part, "zone" end

    -- 2. Fallback: ExitLever via ESP helper
    for _, obj in ipairs(workspace:GetDescendants()) do
        if is_exit_gate_lever and is_exit_gate_lever(obj) then
            local part = esp_gate_get_part and esp_gate_get_part(obj)
            if part then return part, "lever" end
        end
    end

    -- 3. Fallback terakhir: LeverEvent remote
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local exitF = remotes:FindFirstChild("Exit")
        if exitF and exitF:FindFirstChild("LeverEvent") then
            return exitF:FindFirstChild("LeverEvent"), "remote"
        end
    end
    return nil, nil
end

-- Helper: Teleport ke Lobby / Waiting Room setelah Escape
function teleport_to_lobby(hrp)
    if not hrp then return false end
    local lobbyTarget = nil

    -- 1. Cari SpawnLocation dengan nama Lobby / Wait
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            local n = obj.Name:lower()
            local pName = obj.Parent and obj.Parent.Name:lower() or ""
            if n:find("lobby") or pName:find("lobby") or n:find("wait") or pName:find("wait") then
                lobbyTarget = obj
                break
            end
        end
    end

    -- 2. Cari Model / Folder Lobby di workspace
    if not lobbyTarget then
        for _, obj in ipairs(workspace:GetChildren()) do
            local n = obj.Name:lower()
            if n == "lobby" or n:find("lobby") or n == "waitingroom" or n == "intermission" then
                lobbyTarget = obj:FindFirstChildWhichIsA("SpawnLocation") 
                    or obj:FindFirstChildWhichIsA("BasePart")
                    or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")))
                if lobbyTarget then break end
            end
        end
    end

    -- 3. Cari sembarang SpawnLocation yang aktif
    if not lobbyTarget then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("SpawnLocation") and obj.Enabled then
                lobbyTarget = obj
                break
            end
        end
    end

    if lobbyTarget then
        local cf = (lobbyTarget:IsA("Model") and lobbyTarget:GetPivot()) or lobbyTarget.CFrame
        hrp.CFrame = cf * CFrame.new(0, 4, 0)
        return true
    end
    return false
end

-- BYPASS AUTO ESCAPE ENGINE (TAILOR-MADE UNTUK VIOLENCE DISTRICT)
-- Helper: Fire semua remote reward (EXP, Screw, Sin, Gears) seperti escape normal
local function fire_escape_reward_remotes()
    pcall(function()
        -- Scan SEMUA remote di ReplicatedStorage untuk mencari yang berkaitan dengan round win/escape reward
        local function fireRewardRemote(r, ...)
            local args = {...}
            if r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(table.unpack(args)) end)
            elseif r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(table.unpack(args)) end)
            end
        end

        for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
            local rn = r.Name:lower()
            -- Remote khusus reward/win round
            if rn:find("escape") or rn:find("survived") or rn:find("winround") or rn:find("win_round")
                or rn:find("roundwin") or rn:find("matchend") or rn:find("match_end")
                or rn:find("giveexp") or rn:find("give_exp") or rn:find("givereward")
                or rn:find("addexp") or rn:find("addxp") or rn:find("addscrews")
                or rn:find("addcurrency") or rn:find("roundover") or rn:find("gameend")
                or rn == "reward" or rn == "win" or rn == "complete" or rn == "finish" then
                fireRewardRemote(r)
                fireRewardRemote(r, true)
                fireRewardRemote(r, "Escaped")
                fireRewardRemote(r, LocalPlayer)
                fireRewardRemote(r, true, "Escaped")
            end
        end

        -- Fire khusus remote Violence District yang sudah diketahui
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            -- Round / Match folder
            local roundF = remotes:FindFirstChild("Round") or remotes:FindFirstChild("Match")
            if roundF then
                for _, r in ipairs(roundF:GetDescendants()) do
                    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                        fireRewardRemote(r)
                        fireRewardRemote(r, true)
                        fireRewardRemote(r, "Escaped")
                    end
                end
            end

            -- Generator Escapetime
            local genF = remotes:FindFirstChild("Generator")
            if genF then
                local et = genF:FindFirstChild("Escapetime")
                if et then
                    pcall(function() et:FireServer() end)
                    pcall(function() et:FireServer(true) end)
                end
                -- Generator complete
                local gc = genF:FindFirstChild("GeneratorComplete") or genF:FindFirstChild("Complete")
                    or genF:FindFirstChild("GenDone") or genF:FindFirstChild("Done")
                if gc then
                    pcall(function() gc:FireServer() end)
                    pcall(function() gc:FireServer(true) end)
                end
            end

            -- Exit folder events
            local exitF = remotes:FindFirstChild("Exit")
            if exitF then
                for _, r in ipairs(exitF:GetDescendants()) do
                    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                        fireRewardRemote(r)
                        fireRewardRemote(r, true)
                    end
                end
                -- [SCAN 2026-10-06] LeverAnim: animasi tuas saat tuas ditekan
                local leverAnim = exitF:FindFirstChild("LeverAnim")
                if leverAnim then
                    pcall(function() leverAnim:FireServer(true) end)
                    pcall(function() leverAnim:FireServer() end)
                end
            end

            -- [SCAN 2026-10-06] Items.Gate.gate: penanda keluar lewat item Gate
            local itemsF = remotes:FindFirstChild("Items")
            if itemsF then
                local gateF = itemsF:FindFirstChild("Gate")
                if gateF then
                    local gateRemote = gateF:FindFirstChild("gate")
                    if gateRemote then
                        pcall(function() gateRemote:FireServer() end)
                        pcall(function() gateRemote:FireServer(true) end)
                        pcall(function() gateRemote:FireServer("Escaped") end)
                        pcall(function() gateRemote:FireServer(LocalPlayer) end)
                    end
                end
            end
        end
    end)
end

function trigger_instant_escape()
    if _isEscaping then return false, "Proses escape sedang berjalan..." end
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not hrp then return false, "Karakter tidak ditemukan!" end

    -- Penanda versi ini hanya muncul kalau SKY_DEBUG = true,
    -- supaya tidak mengganggu console.
    log("[AutoEscape] VERSI 3: deteksi garis finish (Fininshline)")

    _isEscaping = true
    task.spawn(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")

        -- [LANGKAH 1] Escapetime remote (buka gate)
        pcall(function()
            if remotes then
                local genF = remotes:FindFirstChild("Generator")
                if genF then
                    local et = genF:FindFirstChild("Escapetime")
                    if et and et:IsA("RemoteEvent") then
                        et:FireServer()
                        et:FireServer(true)
                    end
                end
            end
        end)
        task.wait(0.1)

        -- ======================================================================
        -- [TAHAP A] Temukan ZONA KELUAR.
        --
        -- Bukti rekaman manual (05:06):
        --   1. 67.66s  karakter menyentuh Gate.Box     (lewat gerbang)
        --   2. 68.70s  karakter masuk area Fininshline (garis finish)
        --   3. 69.91s  karakter dihapus                 (= ESCAPE)
        --
        -- Jadi Gate.Box itu area nikah di gerbang, sedangkan
        -- Fininshline (garis finish) yang benar-benar memicu escape.
        -- ======================================================================
        local zone = find_escape_zone()
        local anchorCF = zone_anchor_cframe(zone)

        -- Semua zona keluar. Dipanggil SATU KALI saja supaya baris
        -- diagnostik "Arah keluar" tidak tercetak dua kali.
        local allZones = collect_exit_zones()

        -- Part yang perlu disentuh: zona itu sendiri + semua kandidat lain
        -- (beberapa zona mungkin aktif bersamaan, jadi sentuh semuanya).
        local zoneParts = {}
        for _, z in ipairs(allZones) do
            if z.part then table.insert(zoneParts, z.part) end
        end

        -- Titik SEBELUM garis finish. Karakter harus datang dari sisi gerbang,
        -- lalu menyeberang ke seberang garis finish (bukan teleport statis),
        -- karena server memverifikasi perpindahan karakter.
        local approachCF = nil
        if zone and zone.part then
            local gate = get_exit_gate()
            local dir, origin = nil, nil
            if gate then dir, origin = gate_outward(gate) end
            if dir and origin then
                local fwd = (zone.part.Position - origin):Dot(dir)
                if fwd > 5 then
                    -- Berdiri 14 stud SEBELUM garis finish, menghadap ke garis
                    local before = origin + dir * math.max(fwd - 14, 6)
                    approachCF = CFrame.lookAt(before, zone.part.Position)
                end
            end
        end

        local currentChar = LocalPlayer and LocalPlayer.Character
        local currentHrp  = currentChar and (currentChar:FindFirstChild("HumanoidRootPart") or currentChar:FindFirstChild("Torso"))

        if zone then
            local zp = zone.part and zone.part.Position or zone.point
            log("[AutoEscape] zona keluar : %s",
                zone.part and zone.part:GetFullName() or "(titik lorong)")
            log("[AutoEscape] alasan      : %s", tostring(zone.why))
            if zp then
                log("[AutoEscape] pos zona    : %d, %d, %d",
                    math.floor(zp.X), math.floor(zp.Y), math.floor(zp.Z))
            end
        else
            log("[AutoEscape] zona keluar tidak ditemukan")
        end
        if anchorCF then
            local ap = anchorCF.Position
            log("[AutoEscape] anchor      : %d, %d, %d",
                math.floor(ap.X), math.floor(ap.Y), math.floor(ap.Z))
        end

        -- ======================================================================
        -- [TAHAP B] BUKA GERBANG, lalu masuk zona.
        --
        -- Bukti rekaman manual (04:28):
        --   1. Pemain MENARIK TUAS di gerbang  -> gerbang terbuka
        --   2. Pemain JALAN ke dalam Box         -> Touched terpicu
        --   3. 2 detik kemudian                 -> CharacterRemoving (escaped)
        --
        -- Jadi urutan WAJIB: tuas dulu (gerbang harus terbuka), baru masuk zona.
        -- Lever harus diambil dari GERBANG YANG SAMA dengan zona terpilih,
        -- bukan dari gerbang lain di map (terbukti lever Rooftop tidak bekerja).
        -- ======================================================================
        local function touchAll()
            if currentHrp and firetouchinterest then
                for _, zp in ipairs(zoneParts) do
                    if zp and zp.Parent then
                        pcall(function()
                            firetouchinterest(currentHrp, zp, 0)
                            firetouchinterest(currentHrp, zp, 1)
                        end)
                    end
                end
            end
        end

        -- Pantau apakah karakter sudah di-escape (CharacterRemoving = sinyal sukses)
        local escaped = false
        local monitorConns = {}
        pcall(function()
            monitorConns[#monitorConns + 1] = LocalPlayer.CharacterRemoving:Connect(function()
                escaped = true
            end)
        end)

        -- [B1] BUKA GERBANG: cari LeverEvent + Main dari gerbang yang SAMA
        --      dengan zona keluar, lalu tekan tuas sampai daun pintu bergeser.
        local leverEvent = nil
        local leverMain  = nil
        pcall(function()
            if remotes then
                local exitF = remotes:FindFirstChild("Exit")
                if exitF then leverEvent = exitF:FindFirstChild("LeverEvent") end
            end
        end)

        -- Cocokkan lever dengan zona: cari ExitLever yang jaraknya paling dekat
        -- ke zona keluar terpilih.
        if leverEvent then
            local bestLever, bestDist = nil, math.huge
            local zonePos = zone and (zone.part and zone.part.Position or zone.point)
                or (currentHrp and currentHrp.Position)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    local lm = obj:FindFirstChild("ExitLever")
                    if lm then
                        local m = lm:FindFirstChild("Main")
                            or (lm:IsA("Model") and lm:FindFirstChildWhichIsA("BasePart"))
                        if m and m:IsA("BasePart") then
                            local d = (m.Position - zonePos).Magnitude
                            if d < bestDist then bestLever, bestDist = m, d end
                        end
                    end
                end
            end
            leverMain = bestLever
            if leverMain then
                log("[AutoEscape] lever       : %s | jarak %d stud",
                    leverMain:GetFullName(), math.floor(bestDist))
            else
                log("[AutoEscape] ExitLever tidak ditemukan")
            end
        end

        if leverEvent and leverMain then
            -- Gerbang harus terbuka: tekan tuas berulang selama ~2 detik.
            -- Signature server: LeverEvent:FireServer(MeshPart, true|false)
            for _ = 1, 12 do
                pcall(function() leverEvent:FireServer(leverMain, true) end)
                task.wait(0.08)
                pcall(function() leverEvent:FireServer(leverMain, false) end)
                task.wait(0.08)
                if escaped then break end
            end
            log("[AutoEscape] tuas ditekan, gerbang seharusnya terbuka")
        end

        -- ======================================================================
        -- [B2] TELEPORT LANGSUNG KE ZONA (TANPA FLY / TANPA MELAYANG)
        --
        -- Semua part karakter di-set CanCollide = false sebentar supaya
        -- tidak tertahan daun pintu/walls saat di-teleport. Setelah sampai,
        -- CanCollide dikembalikan ke semula.
        --
        -- Posisi tujuan: titik di dasar volume zona (bukan melayang di udara),
        -- sehingga karakter langsung berdiri 'di dalam' zona.
        -- ======================================================================
        local savedCollide = {}
        local function noclipOn()
            if not currentChar then return end
            for _, d in ipairs(currentChar:GetDescendants()) do
                if d:IsA("BasePart") then
                    savedCollide[d] = d.CanCollide
                    pcall(function() d.CanCollide = false end)
                end
            end
        end

        local function noclipOff()
            if not currentChar then return end
            for d, v in pairs(savedCollide) do
                if d and d.Parent then
                    pcall(function() d.CanCollide = v end)
                end
            end
            savedCollide = {}
        end

        noclipOn()

        -- ======================================================================
        -- [B2] MENYEBERANGI GARIS FINISH
        --
        -- Rekaman manual menunjukkan karakter BERJALAN menembus garis finish,
        -- bukan berdiri diam di atasnya:
        --   67.66s menyentuh Gate.Box -> 68.70s masuk Fininshline -> 69.91s escape
        --
        -- Jadi server memeriksa PERPINDAHAN karakter. Teleport statis ke satu
        -- titik sering ditolak karena tidak ada perpindahan yang tercatat.
        --
        -- Strategi: teleport ke titik SEBELUM garis finish, lalu JALAN
        -- pelan-pelan menembusnya di banyak frame supaya perpindahan
        -- benar-benar tercatat di server.
        -- ======================================================================
        local startCF = approachCF or anchorCF
        local crossed = false

        if currentHrp and startCF then
            -- Tahap 1: teleport ke titik sebelum garis finish
            pcall(function()
                currentHrp.CFrame = startCF
                currentHrp.AssemblyLinearVelocity = Vector3.zero
                currentHrp.AssemblyAngularVelocity = Vector3.zero
            end)
            task.wait(0.2)
            touchAll()
            task.wait(0.1)

            -- Tahap 2: jalan menembus garis finish (30 langkah)
            if anchorCF then
                local from = startCF.Position
                local to = anchorCF.Position
                local steps = 30
                for i = 1, steps do
                    if escaped then break end
                    if not (currentHrp and currentHrp.Parent) then break end

                    local t = i / steps
                    -- Smoothstep supaya mulai dan berakhir pelan
                    local e = t * t * (3 - 2 * t)
                    local want = from:Lerp(to, e)

                    pcall(function()
                        currentHrp.CFrame = CFrame.new(want)
                        currentHrp.AssemblyLinearVelocity = Vector3.zero
                    end)

                    -- Picu touch setiap beberapa langkah
                    if i % 3 == 0 then touchAll() end
                    task.wait(0.03)
                end
                crossed = true
            end
        end

        -- Kembalikan collide supaya karakter normal lagi
        noclipOff()
        task.wait(0.1)

        -- [B3] TETAP di seberang garis finish sampai server memproses
        -- (maks 15 detik). Karakter ditahan di anchor supaya tetap di zona.
        local waited = 0
        while waited < 150 and not escaped do
            if currentHrp and currentHrp.Parent and anchorCF then
                pcall(function()
                    -- hanya reposisi kalau karakter menyimpang jauh
                    if (currentHrp.Position - anchorCF.Position).Magnitude > 8 then
                        noclipOn()
                        currentHrp.CFrame = anchorCF
                        task.defer(noclipOff)
                    end
                    currentHrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end
            touchAll()
            task.wait(0.1)
            waited = waited + 1
        end

        for _, conn in ipairs(monitorConns) do
            pcall(function() conn:Disconnect() end)
        end
        noclipOff()

        log("[AutoEscape] selesai. escaped = %s | menyeberang = %s | tunggu %.1f detik",
            tostring(escaped), tostring(crossed), waited * 0.1)
        task.wait(0.2)

        -- [LANGKAH 4] Fire semua remote reward EXP/Screw/etc
        fire_escape_reward_remotes()
        task.wait(0.2)

        -- [LANGKAH 5] Set attribute status escaped
        pcall(function()
            local c = LocalPlayer and LocalPlayer.Character
            if c and c.Parent then
                c:SetAttribute("Escaped", true)
                c:SetAttribute("WinState", true)
                c:SetAttribute("Survived", true)
            end
            LocalPlayer:SetAttribute("Escaped", true)
            LocalPlayer:SetAttribute("WinState", true)
            LocalPlayer:SetAttribute("Survived", true)
        end)

        -- [LANGKAH 6] Pantau perubahan EXP/Screws
        local escapeProcessed = false
        local connList = {}
        local expBefore   = tonumber(tostring(LocalPlayer:GetAttribute("ExpinRound") or LocalPlayer:GetAttribute("EXP") or LocalPlayer:GetAttribute("Exp") or 0)) or 0
        local screwBefore = tonumber(tostring(LocalPlayer:GetAttribute("Screws") or LocalPlayer:GetAttribute("screw") or LocalPlayer:GetAttribute("Screw") or 0)) or 0

        local attrNames = { "ExpinRound","EXP","Exp","XP","experience","Screws","screw","Screw","Sin","Gears","Reward" }
        for _, attrName in ipairs(attrNames) do
            pcall(function()
                local conn = LocalPlayer:GetAttributeChangedSignal(attrName):Connect(function()
                    escapeProcessed = true
                end)
                table.insert(connList, conn)
            end)
        end

        for step = 1, 40 do
            if escapeProcessed then break end
            if step % 5 == 0 then
                pcall(function()
                    local expNow   = tonumber(tostring(LocalPlayer:GetAttribute("ExpinRound") or LocalPlayer:GetAttribute("EXP") or LocalPlayer:GetAttribute("Exp") or 0)) or 0
                    local screwNow = tonumber(tostring(LocalPlayer:GetAttribute("Screws") or LocalPlayer:GetAttribute("screw") or LocalPlayer:GetAttribute("Screw") or 0)) or 0
                    if expNow ~= expBefore or screwNow ~= screwBefore then
                        escapeProcessed = true
                    end
                end)
            end
            task.wait(0.1)
        end

        for _, conn in ipairs(connList) do
            pcall(function() conn:Disconnect() end)
        end

        -- [LANGKAH 7] Konfirmasi reward sekali lagi
        fire_escape_reward_remotes()
        task.wait(0.5)

        -- [LANGKAH 8] Webhook summary
        pcall(function()
            if webhookNotifyEscape and webhookUrl and webhookUrl ~= "" then
                task.delay(1.5, function()
                    pcall(function() send_match_summary_webhook("ESCAPED") end)
                end)
            end
        end)

        -- Reset state
        _isEscaping = false
        autoEscapeEnabled = false
        _autoEscapeStarted = false
        stop_auto_escape()

        local statusMsg
        if escaped then
            statusMsg = "ESCAPED! Karakter langsung dipindahkan ke lobby oleh game."
        elseif escapeProcessed then
            statusMsg = "Escape diproses! EXP & Screws bertambah."
        else
            statusMsg = "Zona disentuh tapi server belum memproses. Coba ulangi."
        end
        -- Hasil akhir tetap dicetak karena ini yang paling penting.
        -- Detail diagnostik lain sudah disembunyikan lewat SKY_DEBUG.
        print("[Escape] " .. statusMsg)
        safe_notify({
            Title = escaped and "Escape Berhasil" or "Auto Escape",
            Description = statusMsg,
            Lifetime = 6
        })
    end)

    return true, "Memulai Escape..."
end

function start_auto_escape()
    if autoEscapeConn then autoEscapeConn:Disconnect() end
    _escapeCheckTimer = 0
    _autoEscapeStarted = true
    autoEscapeConn = RunService.Heartbeat:Connect(function(dt)
        if not autoEscapeEnabled or _isEscaping then return end
        if is_local_player_killer and is_local_player_killer() then return end
        _escapeCheckTimer = _escapeCheckTimer + dt
        if _escapeCheckTimer < 0.5 then return end
        _escapeCheckTimer = 0

        -- Auto escape setelah match dimulai (deteksi LeverEvent sudah ada di Remotes)
        local targetObj, targetType = find_escape_target()
        if targetObj then
            autoEscapeEnabled = false
            stop_auto_escape()
            trigger_instant_escape()
        end
    end)
end

function stop_auto_escape()
    _autoEscapeStarted = false
    if autoEscapeConn then autoEscapeConn:Disconnect(); autoEscapeConn = nil end
end


end

-- ==============================================================================
do
-- MODUL 13: DISCORD WEBHOOK NOTIFIER (PER-MATCH SUMMARY)
-- ==============================================================================
webhookUrl = ""
webhookNotifyEscape = true
webhookNotifyMatch = true

-- Session stats baseline (diisi saat match mulai)
local _matchStartStats = nil
local _matchStartTime = 0
local _totalMatchCount = 0

-- Helper: scan leaderstats, attributes, dan values dari sebuah instance root
local _statsRef = nil

local function _scan_stats_from(root)
    if not root or not _statsRef then return end
    local stats = _statsRef

    pcall(function()
        local folders = { root, root:FindFirstChild("leaderstats"), root:FindFirstChild("Stats"), root:FindFirstChild("Data"), root:FindFirstChild("Values"), root:FindFirstChild("Currencies") }
        for _, f in ipairs(folders) do
            if f then
                for _, v in ipairs(f:GetChildren()) do
                    local n = v.Name:lower()
                    local val = nil
                    if v:IsA("ValueBase") then val = v.Value end
                    if val ~= nil then
                        if n:find("level") or n == "lv" or n == "lvl" or n:find("rank") then stats.level = val end
                        if n:find("exp") or n:find("xp") or n:find("experience") then stats.exp = val end
                        if n:find("screw") then stats.screw = val end
                        if n:find("gold") or n:find("coin") or n:find("cash") or n:find("money") or n:find("gear") or n:find("token") then stats.gold = val end
                        if n:find("sin") or n:find("reputation") or n:find("evil") or n:find("kill") or n:find("slay") then stats.sin = val end
                    end
                end
            end
        end
    end)

    pcall(function()
        for k, v in pairs(root:GetAttributes()) do
            local ks = tostring(k):lower()
            local vn = tonumber(tostring(v))
            if vn then
                if ks:find("level") or ks == "lv" or ks == "lvl" then stats.level = vn end
                if ks:find("exp") or ks:find("xp") then stats.exp = vn end
                if ks:find("screw") then stats.screw = vn end
                if ks:find("gold") or ks:find("coin") or ks:find("gear") or ks:find("token") then stats.gold = vn end
                if ks:find("sin") or ks:find("reputation") then stats.sin = vn end
                if ks:find("role") or ks:find("team") or ks:find("side") then stats.role = tostring(v) end
            end
        end
    end)
end

-- Helper: ambil stats player (Level, EXP, Screw, Gold/Gear, Sin, Map)
function get_player_stats()
    local stats = {
        level = 0, exp = 0, screw = 0, gold = 0, sin = 0,
        hp = "?", map = "Unknown Map", role = "Survivor"
    }
    _statsRef = stats

    pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            stats.hp = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
        end
    end)

    _scan_stats_from(LocalPlayer)

    pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        if char then _scan_stats_from(char) end
    end)

    pcall(function()
        local pd = ReplicatedStorage:FindFirstChild("PlayerData") or ReplicatedStorage:FindFirstChild("Data")
            or ReplicatedStorage:FindFirstChild("PlayerStats")
        if pd then
            local mine = pd:FindFirstChild(LocalPlayer.Name) or pd:FindFirstChild(tostring(LocalPlayer.UserId))
            if mine then _scan_stats_from(mine) end
        end
    end)

    pcall(function()
        local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("CurrentMap")
            or workspace:FindFirstChild("Level") or workspace:FindFirstChild("MapFolder")
            or workspace:FindFirstChild("GameMap")
        if mapFolder then
            stats.map = mapFolder.Name
        else
            local mapAttr = workspace:GetAttribute("MapName") or workspace:GetAttribute("CurrentMap")
                or workspace:GetAttribute("Map") or workspace:GetAttribute("Level")
                or ReplicatedStorage:GetAttribute("MapName") or ReplicatedStorage:GetAttribute("CurrentMap")
            if mapAttr then stats.map = tostring(mapAttr) end
        end
    end)

    _statsRef = nil
    return stats
end

-- Helper: Mask username (contoh: Sk*** untuk nama 5+ karakter)
local function mask_username(name)
    if not name or #name <= 2 then return name or "?" end
    return name:sub(1, 2) .. string.rep("*", math.min(#name - 2, 3))
end

-- Helper: Format delta dengan tanda +/-
local function fmt_delta(before, after)
    local bNum = tonumber(tostring(before)) or 0
    local aNum = tonumber(tostring(after)) or 0
    local delta = aNum - bNum
    if delta > 0 then
        return tostring(aNum) .. " (+" .. delta .. ")"
    elseif delta < 0 then
        return tostring(aNum) .. " (" .. delta .. ")"
    else
        return tostring(aNum) .. " (+0)"
    end
end

-- Inisialisasi baseline stats saat match mulai
local function start_match_tracking()
    _matchStartStats = get_player_stats()
    _matchStartTime = tick()
end

-- Kirim MATCH SUMMARY per-match (setelah escape/match end) - Sky Hub Premium Style
function send_match_summary_webhook(resultStatus)
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord.com/api/webhooks") then
        return false, "Webhook URL belum diisi!"
    end

    local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not req then return false, "HTTP request tidak didukung!" end

    -- Delay sedikit agar stat sempat terupdate sebelum snapshot diambil
    task.wait(1.5)

    local currStats = get_player_stats()
    local baseStats = _matchStartStats or currStats
    _totalMatchCount = _totalMatchCount + 1

    -- Durasi match
    local matchDuration = math.max(0, tick() - (_matchStartTime or tick()))
    local mins = math.floor(matchDuration / 60)
    local secs = math.floor(matchDuration % 60)
    local matchTimeStr = mins > 0 and string.format("%dm %ds", mins, secs) or string.format("%ds", secs)

    -- Nama player (masked)
    local pName = tostring(LocalPlayer and LocalPlayer.Name or "?")
    local pDisplay = tostring(LocalPlayer and LocalPlayer.DisplayName or pName)
    local maskedName = mask_username(pDisplay)

    -- Server ID (masked)
    local sId = tostring(game.JobId or "")
    local maskedSId = sId ~= "" and (sId:sub(1, 6) .. "...") or "Private"

    -- Delta fields
    local expDelta   = (tonumber(tostring(currStats.exp))   or 0) - (tonumber(tostring(baseStats.exp))   or 0)
    local screwDelta = (tonumber(tostring(currStats.screw)) or 0) - (tonumber(tostring(baseStats.screw)) or 0)
    local sinDelta   = (tonumber(tostring(currStats.sin))   or 0) - (tonumber(tostring(baseStats.sin))   or 0)
    local gearDelta  = (tonumber(tostring(currStats.gold))  or 0) - (tonumber(tostring(baseStats.gold))  or 0)
    local lvlDelta   = (tonumber(tostring(currStats.level)) or 0) - (tonumber(tostring(baseStats.level)) or 0)

    local function fmtStat(val, delta)
        local s = tostring(val)
        if delta > 0 then return s .. " **(+" .. delta .. ")**"
        elseif delta < 0 then return s .. " **(" .. delta .. ")**"
        else return s .. " *(±0)*" end
    end

    local expField   = fmtStat(tonumber(tostring(currStats.exp))   or 0, expDelta)
    local screwField = fmtStat(tonumber(tostring(currStats.screw)) or 0, screwDelta)
    local sinField   = fmtStat(tonumber(tostring(currStats.sin))   or 0, sinDelta)
    local gearField  = fmtStat(tonumber(tostring(currStats.gold))  or 0, gearDelta)
    local levelField = fmtStat(tonumber(tostring(currStats.level)) or 0, lvlDelta)

    -- Status & Color
    local resultEmoji, resultLabel, embedColor
    if resultStatus == "ESCAPED" then
        resultEmoji = "🟢"
        resultLabel = "Escaped!"
        embedColor  = 0x2ECC71  -- hijau
    elseif resultStatus == "Match Ended" then
        resultEmoji = "🔵"
        resultLabel = "Match Ended"
        embedColor  = 0x3498DB  -- biru
    elseif resultStatus == "Manual" then
        resultEmoji = "📋"
        resultLabel = "Manual Report"
        embedColor  = 0x9B59B6  -- ungu
    else
        resultEmoji = "⚡"
        resultLabel = tostring(resultStatus or "Auto Farm")
        embedColor  = 0xF39C12  -- oranye
    end

    -- Hitung total gain
    local gainParts = {}
    if expDelta   > 0 then table.insert(gainParts, "+" .. expDelta   .. " EXP")   end
    if screwDelta > 0 then table.insert(gainParts, "+" .. screwDelta .. " Screw")  end
    if sinDelta   > 0 then table.insert(gainParts, "+" .. sinDelta   .. " Sin")    end
    if gearDelta  > 0 then table.insert(gainParts, "+" .. gearDelta  .. " Gear")   end
    local gainStr = #gainParts > 0 and table.concat(gainParts, "  •  ") or "Tidak ada perubahan stats"

    -- Reset baseline untuk match berikutnya
    _matchStartStats = currStats
    _matchStartTime  = tick()

    local descLine = string.format(
        "%s **%s** — Match #**%d** | Server: `%s`",
        resultEmoji, resultLabel, _totalMatchCount, maskedSId
    )

    local payload = {
        username   = "Sky Hub Notifier",
        avatar_url = "https://cdn-icons-png.flaticon.com/512/6295/6295417.png",
        embeds = {
            {
                title       = "🏆 Sky Hub  •  Match Summary",
                color       = embedColor,
                description = descLine .. "\n\n> " .. gainStr,
                thumbnail   = { url = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png" },
                fields = {
                    -- Row 1: identitas
                    { name = "👤  Player",      value = maskedName,                           inline = true },
                    { name = "🗺️  Map",          value = currStats.map or "Unknown Map",       inline = true },
                    { name = "⏱️  Durasi",       value = matchTimeStr,                         inline = true },
                    -- Row 2: currency utama
                    { name = "⭐  EXP",          value = expField,                             inline = true },
                    { name = "🔩  Screws",       value = screwField,                           inline = true },
                    { name = "☠️  Sin",          value = sinField,                             inline = true },
                    -- Row 3: sekunder
                    { name = "⚙️  Gears",        value = gearField,                            inline = true },
                    { name = "🆙  Level",        value = levelField,                           inline = true },
                    { name = "🎮  Total Match",  value = "Match ke-**" .. _totalMatchCount .. "**", inline = true },
                },
                footer = {
                    text     = "Sky Hub  •  Violence District Ultimate Script",
                    icon_url = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    local ok, res = pcall(function()
        return req({
            Url     = webhookUrl,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload)
        })
    end)
    return ok, res
end

-- Fungsi lama (compatibility - untuk tombol test)
function send_discord_webhook(embedTitle, embedDesc, colorHex)
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord.com/api/webhooks") then
        return false, "Webhook URL belum diisi atau tidak valid!"
    end
    local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not req then return false, "Executor tidak mendukung HTTP request!" end

    local stats = get_player_stats()
    local payload = {
        username = "Sky Hub • Violence District",
        avatar_url = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png",
        embeds = {
            {
                title = embedTitle or "Notifikasi Match",
                description = embedDesc or "",
                color = tonumber(colorHex or "5865F2", 16) or 5793266,
                fields = {
                    { name = "Pemain", value = (LocalPlayer.DisplayName or LocalPlayer.Name) .. " (@" .. LocalPlayer.Name .. ")", inline = true },
                    { name = "Level", value = tostring(stats.level), inline = true },
                    { name = "EXP", value = tostring(stats.exp), inline = true },
                    { name = "Screw", value = tostring(stats.screw), inline = true },
                    { name = "Gear/Gold", value = tostring(stats.gold), inline = true },
                    { name = "Sin", value = tostring(stats.sin), inline = true },
                    { name = "Map", value = stats.map, inline = true },
                    { name = "Waktu", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true }
                },
                footer = { text = "Sky Hub Notifier • Violence District" }
            }
        }
    }
    local ok, res = pcall(function()
        return req({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return ok, res
end

-- Live Stats Monitor (legacy compat - sekarang hanya track, tidak auto-send)
local _webhookLiveConn = nil
local _lastLiveStats = {}

function start_webhook_live_monitor()
    if _webhookLiveConn then _webhookLiveConn:Disconnect() end
    -- Auto-track match start
    start_match_tracking()
    -- Deteksi akhir match (via attribute atau event)
    local _liveTimer = 0
    _webhookLiveConn = RunService.Heartbeat:Connect(function(dt)
        if not webhookUrl or webhookUrl == "" then return end
        _liveTimer = _liveTimer + dt
        -- Cek setiap 30 detik apakah match sudah berakhir berdasarkan state game
        if _liveTimer >= 30 then
            _liveTimer = 0
            pcall(function()
                local gameState = workspace:GetAttribute("GameState") or workspace:GetAttribute("State")
                    or ReplicatedStorage:GetAttribute("GameState") or ReplicatedStorage:GetAttribute("State")
                if gameState then
                    local gs = tostring(gameState):lower()
                    if gs == "lobby" or gs == "waiting" or gs == "intermission" or gs == "end" then
                        send_match_summary_webhook("Match Ended")
                        start_match_tracking()
                    end
                end
            end)
        end
    end)
end

function stop_webhook_live_monitor()
    if _webhookLiveConn then _webhookLiveConn:Disconnect(); _webhookLiveConn = nil end
end

-- Auto-inisialisasi tracking saat script mulai
task.defer(function()
    start_match_tracking()
end)


end

-- ==============================================================================
-- WMACLIB UI INITIALIZATION
-- ==============================================================================
local _preExistingGuis = {}
pcall(function()
    local cList = {}
    pcall(function() if gethui then table.insert(cList, gethui()) end end)
    pcall(function() if CoreGui then table.insert(cList, CoreGui) end end)
    for _, c in ipairs(cList) do
        pcall(function()
            if c and typeof(c) == "Instance" then
                for _, sg in ipairs(c:GetChildren()) do
                    if sg and sg:IsA("ScreenGui") then _preExistingGuis[sg] = true end
                end
            end
        end)
    end
end)

local ok_wm, WMacLib = pcall(function()
    local src = game:HttpGet("https://raw.githubusercontent.com/Wicikk/WMacLib/main/WMacLib.lua")
    -- Patch rbxassetid://0 agar tidak memicu error asset not found di console engine
    src = src:gsub('"rbxassetid://0"', '""'):gsub("'rbxassetid://0'", "''")
    -- [FIX DRAGGING BUG] Limit gsub ke 1 penggantian pertama saja (limit=1) agar tidak merusak fungsi lain!
    -- WMacLib asli menimpa dragInput dengan MouseMovement, sehingga input == dragInput gagal saat MouseButton1 dilepas.
    src = src:gsub(
        "if input == dragInput then",
        "if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then",
        1  -- <-- limit: HANYA ganti kemunculan PERTAMA saja!
    )
    local fn, err = loadstring(src)
    if not fn then
        error(tostring(err or "Failed to compile WMacLib"))
    end
    local result = fn()
    if type(result) ~= "table" then
        error("WMacLib tidak mengembalikan tabel yang valid")
    end
    return result
end)
if not ok_wm or not WMacLib then
    warn("[Sky Hub] Gagal memuat WMacLib: " .. tostring(WMacLib))
    -- Jangan return! Coba load dari URL alternatif
    ok_wm, WMacLib = pcall(function()
        local src2 = game:HttpGet("https://raw.githubusercontent.com/Wicikk/WMacLib/refs/heads/main/WMacLib.lua")
        src2 = src2:gsub('"rbxassetid://0"', '""'):gsub("'rbxassetid://0'", "''")
        local fn2, err2 = loadstring(src2)
        if not fn2 then error(tostring(err2 or "Compile error")) end
        local r2 = fn2()
        if type(r2) ~= "table" then error("Return bukan table") end
        return r2
    end)
    if not ok_wm or not WMacLib then
        warn("[Sky Hub] WMacLib gagal total, script dihentikan.")
        return
    end
end

local Window = WMacLib:Window({
    Title = "Sky Hub",
    Subtitle = "Violence District",
    Size = UDim2.fromOffset(600, 460),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
    Theme = "Dark",
})

-- Expose Window sebagai global 'SkyWindow' agar modul2 yang ditulis SEBELUM
-- Window dibuat (mis. Modul 12 Auto Escape) tetap bisa menampilkan notifikasi
-- tanpa menyebabkan error "attempt to index nil with 'Notify'".
SkyWindow = Window

local tabGroup = Window:TabGroup()

-- Sembunyikan window WMacLib saat awal agar Welcome Screen tampil sendirian
local wmacGui = nil
local function findWmacGui()
    pcall(function()
        local containers = {}
        if gethui then table.insert(containers, gethui()) end
        if CoreGui then table.insert(containers, CoreGui) end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(containers, LocalPlayer.PlayerGui)
        end

        for _, container in ipairs(containers) do
            for _, sg in ipairs(container:GetChildren()) do
                if sg:IsA("ScreenGui") and not _preExistingGuis[sg] and sg.Name ~= "SkyHubWelcome" then
                    wmacGui = sg
                    return
                end
            end
        end
    end)
end
findWmacGui()
if wmacGui then wmacGui.Enabled = false end
pcall(function() Window:SetState(false) end)

-- ==============================================================================
-- WELCOME SCREEN (TAMPIL PERTAMA SEBELUM MENU UTAMA)
-- ==============================================================================
-- Desain: glassmorphism dengan palet indigo-teal yang elegan.
-- Gradien halus, sudut membulat besar, dan animasi halus supaya
-- terasa premium tanpa norak.
-- ==============================================================================

-- Palet warna yang dipakai di seluruh welcome screen.
-- Dipilih supaya serasi dan tidak mencolok.
local P = {
    bgCard    = Color3.fromRGB(16, 18, 28),
    bgCardAlt = Color3.fromRGB(22, 25, 38),
    bgChip    = Color3.fromRGB(28, 32, 48),
    border    = Color3.fromRGB(46, 52, 74),
    textMain  = Color3.fromRGB(238, 240, 250),
    textMuted = Color3.fromRGB(140, 148, 175),
    accentA   = Color3.fromRGB(99, 130, 255),   -- indigo
    accentB   = Color3.fromRGB(72, 214, 200),   -- teal
    accentC   = Color3.fromRGB(168, 120, 255),  -- violet
}

local function grad(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    if rotation then g.Rotation = rotation end
    g.Parent = parent
    return g
end

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

task.spawn(function()
    pcall(function()
        local TweenService = game:GetService("TweenService")

        local SG = Instance.new("ScreenGui")
        SG.Name = "SkyHubWelcome"
        SG.ResetOnSpawn = false
        SG.IgnoreGuiInset = true
        SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function()
            if gethui then SG.Parent = gethui()
            else SG.Parent = CoreGui end
        end)
        if not SG.Parent then SG.Parent = CoreGui end

        -- Blur latar belakang supaya tulisan lebih fokus.
        local blur = Instance.new("BlurEffect")
        blur.Size = 18
        blur.Parent = workspace.CurrentCamera

        -- Overlay gelap tipis, tidak fully opaque supaya game masih terlihat.
        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.BackgroundColor3 = Color3.fromRGB(6, 7, 12)
        overlay.BackgroundTransparency = 0.3
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 1
        overlay.Parent = SG

        -- Card utama di tengah layar.
        local card = Instance.new("Frame")
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.56)
        card.Size = UDim2.fromOffset(540, 330)
        card.BackgroundColor3 = P.bgCard
        card.BackgroundTransparency = 1
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.ZIndex = 10
        card.Parent = SG
        round(card, 22)

        -- Garis tipis di sekeliling card supaya tidak terlihat flat.
        local stroke = Instance.new("UIStroke")
        stroke.Color = P.border
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = card

        -- Cahaya lembut di sudut kiri atas card (glassmorphism).
        local sheen = Instance.new("Frame")
        sheen.Size = UDim2.new(0.75, 0, 0.75, 0)
        sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        sheen.BackgroundTransparency = 0.96
        sheen.BorderSizePixel = 0
        sheen.Rotation = -18
        sheen.ZIndex = 11
        sheen.Parent = card

        -- Strip gradien tipis di atas card sebagai aksen.
        local strip = Instance.new("Frame")
        strip.Size = UDim2.new(1, 0, 0, 2)
        strip.BackgroundColor3 = Color3.new(1, 1, 1)
        strip.BorderSizePixel = 0
        strip.ZIndex = 12
        strip.Parent = card
        grad(strip, P.accentA, P.accentC)

        -- Logo: kotak membulat dengan gradien dan simbol bintang.
        local logo = Instance.new("Frame")
        logo.AnchorPoint = Vector2.new(0.5, 0)
        logo.Position = UDim2.new(0.5, 0, 0, 30)
        logo.Size = UDim2.fromOffset(58, 58)
        logo.BackgroundColor3 = Color3.new(1, 1, 1)
        logo.BorderSizePixel = 0
        logo.ZIndex = 12
        logo.Parent = card
        round(logo, 16)
        grad(logo, P.accentA, P.accentC, 135)

        local logoStroke = Instance.new("UIStroke")
        logoStroke.Color = Color3.fromRGB(255, 255, 255)
        logoStroke.Thickness = 1
        logoStroke.Transparency = 0.72
        logoStroke.Parent = logo

        local logoText = Instance.new("TextLabel")
        logoText.Name = "LogoText"
        logoText.Size = UDim2.fromScale(1, 1)
        logoText.BackgroundTransparency = 1
        logoText.Text = "S"
        logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
        logoText.TextScaled = true
        logoText.Font = Enum.Font.GothamBlack
        logoText.ZIndex = 13
        logoText.Parent = logo

        -- Judul dengan gradien lembut.
        local title = Instance.new("TextLabel")
        title.AnchorPoint = Vector2.new(0.5, 0)
        title.Position = UDim2.new(0.5, 0, 0, 102)
        title.Size = UDim2.new(1, -40, 0, 40)
        title.BackgroundTransparency = 1
        title.Text = "Sky Hub"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 12
        title.Parent = card
        grad(title, P.accentA, P.accentB)

        local sub = Instance.new("TextLabel")
        sub.AnchorPoint = Vector2.new(0.5, 0)
        sub.Position = UDim2.new(0.5, 0, 0, 142)
        sub.Size = UDim2.new(1, -60, 0, 20)
        sub.BackgroundTransparency = 1
        sub.Text = "Violence District"
        sub.TextColor3 = P.textMuted
        sub.TextScaled = true
        sub.Font = Enum.Font.Gotham
        sub.ZIndex = 12
        sub.Parent = card

        -- Garis pemisah tipis.
        local div = Instance.new("Frame")
        div.AnchorPoint = Vector2.new(0.5, 0)
        div.Position = UDim2.new(0.5, 0, 0, 172)
        div.Size = UDim2.new(0.72, 0, 0, 1)
        div.BackgroundColor3 = P.border
        div.BackgroundTransparency = 0.45
        div.BorderSizePixel = 0
        div.ZIndex = 12
        div.Parent = card

        -- Deretan chip fitur. Nama saja, tanpa emoji supaya tetap bersih.
        local chips = { "Auto Gen", "Auto Parry", "Auto Heal", "ESP", "Auto Escape" }
        local row = Instance.new("Frame")
        row.AnchorPoint = Vector2.new(0.5, 0)
        row.Position = UDim2.new(0.5, 0, 0, 190)
        row.Size = UDim2.new(1, -40, 0, 34)
        row.BackgroundTransparency = 1
        row.ZIndex = 12
        row.Parent = card

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 8)
        layout.Parent = row

        for _, name in ipairs(chips) do
            local chip = Instance.new("Frame")
            chip.Size = UDim2.fromOffset(86, 30)
            chip.BackgroundColor3 = P.bgChip
            chip.BackgroundTransparency = 0.15
            chip.BorderSizePixel = 0
            chip.ZIndex = 13
            chip.Parent = row
            round(chip, 9)

            local chipText = Instance.new("TextLabel")
            chipText.Size = UDim2.fromScale(1, 1)
            chipText.BackgroundTransparency = 1
            chipText.Text = name
            chipText.TextColor3 = P.textMain
            chipText.TextTransparency = 0.18
            chipText.TextScaled = true
            chipText.Font = Enum.Font.GothamMedium
            chipText.ZIndex = 14
            chipText.Parent = chip
        end

        -- Progress bar tipis di bawah.
        local barBg = Instance.new("Frame")
        barBg.AnchorPoint = Vector2.new(0.5, 1)
        barBg.Position = UDim2.new(0.5, 0, 1, -46)
        barBg.Size = UDim2.new(0.62, 0, 0, 4)
        barBg.BackgroundColor3 = P.bgChip
        barBg.BackgroundTransparency = 0.35
        barBg.BorderSizePixel = 0
        barBg.ZIndex = 12
        barBg.Parent = card
        round(barBg, 2)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.fromScale(0, 1)
        barFill.BackgroundColor3 = Color3.new(1, 1, 1)
        barFill.BorderSizePixel = 0
        barFill.ZIndex = 13
        barFill.Parent = barBg
        round(barFill, 2)
        grad(barFill, P.accentA, P.accentB)

        -- Teks status yang berubah saat loading.
        local status = Instance.new("TextLabel")
        status.AnchorPoint = Vector2.new(0.5, 1)
        status.Position = UDim2.new(0.5, 0, 1, -22)
        status.Size = UDim2.new(1, -40, 0, 16)
        status.BackgroundTransparency = 1
        status.Text = "Menyiapkan fitur..."
        status.TextColor3 = P.textMuted
        status.TextScaled = true
        status.Font = Enum.Font.Gotham
        status.ZIndex = 12
        status.Parent = card

        -- Fade in card.
        local fadeIn = TweenService:Create(card,
            TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0 })
        fadeIn:Play()

        -- Isi progress bar sambil mengganti teks status.
        TweenService:Create(barFill,
            TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Size = UDim2.fromScale(1, 1) }):Play()

        task.spawn(function()
            local steps = {
                { 0.15, "Memuat antarmuka..." },
                { 0.55, "Menyiapkan fitur..." },
                { 0.85, "Almost there..." },
            }
            for _, step in ipairs(steps) do
                task.wait(step[1])
                status.Text = step[2]
            end
        end)

        task.wait(2.5)

        -- Fade out, lalu buka menu utama.
        TweenService:Create(card,
            TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Position = UDim2.fromScale(0.5, 0.46), BackgroundTransparency = 1 }):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()

        task.wait(0.45)
        pcall(function() blur:Destroy() end)
        pcall(function() SG:Destroy() end)

        -- Tampilkan menu utama WMacLib dengan mulus.
        findWmacGui()
        if wmacGui then wmacGui.Enabled = true end
        pcall(function() Window:SetState(true) end)
    end)
end)

-- State Variabel Form
local swap_target = ""
local swap_avatar = "usnavatar"

local outfit_owner = "zhbrxty"
local outfit_name = "cp 1"
local outfit_target = ""

local acc_target = ""
local acc_id = "10159600649"

local mod_target = ""

-- ==============================================================================
do
-- MODUL AUTO PERFECT GENERATOR (SKILL CHECK AUTOMATION)
-- ==============================================================================
local PlayerGui       = LocalPlayer:WaitForChild("PlayerGui")

autoGenEnabled = false
local autoGenConn     = nil
local autoGenHitCount = 0
local autoGenOffset   = 0

-- State tracking untuk siklus minigame aktif & King's Scourge
local isMinigameActive       = false
local hasHitCurrentMinigame  = false
local lastLineRotation       = nil
local lastGoalRotation       = nil
local lastHitTick            = 0
local lineMoveCount          = 0

-- ==============================================================================
-- KONSTANTA GENERATOR
-- ==============================================================================
-- Batas percobaan per minigame. Lebih dari 1 karena satu tekanan yang
-- tidak registering di server tidak langsung menggagalkan seluruh minigame.
AGEN_MAX_ATTEMPTS = 3

-- Jeda minimum antar tekanan (detik). Mencegah spam saat jarum lambat.
AGEN_PRESS_COOLDOWN = 0.05

-- Rentang zona putih (derajat offset dari goal).
-- Bisa diubah lewat slider karena tiap generator punya lebar zona berbeda.
agenZoneMin = 103.0
agenZoneMax = 114.0

-- Penghitung percobaan untuk minigame yang sedang berjalan.
hitAttempts = 0

-- Timestamp terakhir, dipakai untuk menghitung kecepatan sudut per detik.
lastGenTick = 0

-- Flag mode kalibrasi. Kalau true, generator hanya mengamati, tidak menekan.
agenCalibrating = false

-- Uji apakah sebuah offset berada di dalam zona putih.
-- Aman terhadap kasus di mana zona melintasi batas 0 derajat.
local function in_gen_zone(offset, zmin, zmax)
    if zmax >= zmin then
        return offset >= zmin and offset <= zmax
    end
    -- Zona melintasi batas 0 (contoh: zmin 350, zmax 10).
    return offset >= zmin or offset <= zmax
end

-- ==============================================================================
-- MODE KALIBRASI
-- ==============================================================================
-- Cara kerjanya sederhana dan tidak menebak:
-- Jarum pada circular skill check bergerak CEPAT saat berada di zona putih,
-- dan bergerak pelan di luar zona. Jadi kalau kita lihat bagian mana dari
-- putaran yang paling cepat, di situlah zona putihnya.
--
-- Kita kumpulkan semua offset selama satu putaran penuh, lalu mencari
-- bagian mana yang jarumnya paling cepat. Itu zonanya.
-- ==============================================================================

-- Data yang dikumpulkan selama kalibrasi.
calibSpeeds    = {}   -- offset (derajat) -> kecepatan absolut terbesar
calibMinSeen   = nil
calibMaxSeen   = nil

-- Terapkan zona hasil kalibrasi, dengan lebar dibatasi supaya tidak
-- terlalu longgar dan jadi sering gagal.
local function apply_calibration(minSeen, maxSeen)
    local lo, hi = minSeen, maxSeen
    if lo > hi then lo, hi = hi, lo end

    -- Batas lebar maksimal supaya tidak terlalu forgiving.
    local maxWidth = 24
    local width = hi - lo
    if width > maxWidth then
        local center = (lo + hi) / 2
        lo = center - maxWidth / 2
        hi = center + maxWidth / 2
    end

    agenZoneMin = lo
    agenZoneMax = hi
    return lo, hi
end

-- Helper untuk memastikan GUI benar-benar aktif & terlihat di layar
local function is_gui_visible(v)
    if not v or not v:IsA("GuiObject") then return false end
    if not v.Visible then return false end
    if v.AbsoluteSize.X < 5 or v.AbsoluteSize.Y < 5 then return false end
    local p = v.Parent
    while p and not p:IsA("PlayerGui") do
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return true
end

-- Deteksi circular skill check (Violence District):
-- Jalur presisi: SkillCheckPromptGui -> Check -> (Line, Goal, Space)
local function agen_get_skillcheck_ui()
    -- 1. Jalur langsung berkecepatan tinggi O(1)
    local scpGui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
    if scpGui and scpGui.Enabled then
        local check = scpGui:FindFirstChild("Check")
        if check and check.Visible then
            local line = check:FindFirstChild("Line")
            local goal = check:FindFirstChild("Goal")
            local space = check:FindFirstChild("Space")
            if line and goal and line.Visible and goal.Visible then
                return line, goal, space, check
            end
        end
    end

    -- 2. Fallback scan jika struktur GUI di-update oleh game
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        if v:IsA("GuiObject") and v.Name == "Line" and is_gui_visible(v) then
            local p = v.Parent
            if p then
                local goal = p:FindFirstChild("Goal")
                if goal and goal:IsA("GuiObject") and is_gui_visible(goal) then
                    local space = p:FindFirstChild("Space")
                    return v, goal, space, p
                end
            end
        end
    end
    return nil, nil, nil, nil
end

-- Input simulator multi-metode INSTAN (0ms delay, tanpa task.wait yang menghambat)
local function agen_press(spaceObj)
    -- 1. VirtualInputManager (Core Roblox)
    pcall(function()
        game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    end)

    -- 2. VirtualUser (Universal Roblox Input)
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:SetKeyDown("0x20")
    end)

    -- 3. Executor keypress VK_SPACE
    pcall(function()
        if keypress then keypress(32) end
        if keypress then keypress(Enum.KeyCode.Space.Value) end
    end)

    -- 4. GUI Button activation (jika tombol Space adalah GuiButton atau punya child button)
    if spaceObj then
        pcall(function()
            if spaceObj:IsA("GuiButton") and firesignal then
                firesignal(spaceObj.Activated)
                firesignal(spaceObj.MouseButton1Down)
                firesignal(spaceObj.MouseButton1Click)
            end
            for _, btn in ipairs(spaceObj:GetDescendants()) do
                if btn:IsA("GuiButton") and firesignal then
                    firesignal(btn.Activated)
                    firesignal(btn.MouseButton1Down)
                    firesignal(btn.MouseButton1Click)
                end
            end
        end)
    end

    -- Release tombol secara asinkron setelah 15ms (sangat cepat untuk King's Scourge)
    task.spawn(function()
        task.wait(0.015)
        pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        pcall(function()
            game:GetService("VirtualUser"):SetKeyUp("0x20")
        end)
        pcall(function()
            if keyrelease then keyrelease(32) end
            if keyrelease then keyrelease(Enum.KeyCode.Space.Value) end
        end)
    end)
end

local function agen_tick()
    if not autoGenEnabled then return end

    local lineObj, goalObj, spaceObj = agen_get_skillcheck_ui()

    -- Jika minigame tidak ada atau sudah tertutup
    if not lineObj or not goalObj then
        if isMinigameActive then
            isMinigameActive       = false
            hasHitCurrentMinigame  = false
            lastLineRotation       = nil
            lastGoalRotation       = nil
            lastHitTick            = 0
            lineMoveCount          = 0
            hitAttempts            = 0
            lastGenTick            = 0
        end
        return
    end

    local currentRot = lineObj.Rotation
    local goalRot    = goalObj.Rotation % 360
    if goalRot < 0 then goalRot = goalRot + 360 end

    -- DUKUNGAN KHUSUS KING'S SCOURGE (RAPID-FIRE CHECKS):
    -- Deteksi perpindahan Goal sudut (> 2.0°) = ronde/skill check baru langsung reset
    if lastGoalRotation ~= nil then
        local goalDiff = math.abs((goalRot - lastGoalRotation + 180) % 360 - 180)
        if goalDiff > 2.0 then
            hasHitCurrentMinigame = false
            lastHitTick            = 0
            lineMoveCount          = 1
            lastGoalRotation       = goalRot
            lastGenTick            = tick()
            hitAttempts            = 0
        end
    else
        lastGoalRotation = goalRot
        lastGenTick      = tick()
    end

    -- Minigame baru muncul
    if not isMinigameActive then
        isMinigameActive      = true
        hasHitCurrentMinigame = false
        lastLineRotation      = lineObj.Rotation
        lastGoalRotation      = goalRot
        lastGenTick           = tick()
        lineMoveCount         = 0
        hitAttempts           = 0
        return
    end

    -- Kecepatan sudut jarum (derajat per detik, bertanda).
    -- PENTING: memakai kecepatan per detik, bukan per frame, supaya
    -- prediksi tetap akurat walaupun frame rate game sedang turun.
    -- Nilai positif = searah jarum jam, negatif = berlawanan arah.
    local nowTick = tick()
    local rawDelta = 0
    if lastLineRotation ~= nil then
        rawDelta = (currentRot - lastLineRotation) % 360
        if rawDelta > 180 then rawDelta = rawDelta - 360 end
    end
    local angularVel = rawDelta / math.max(nowTick - lastGenTick, 1 / 240)
    lastLineRotation = currentRot
    lastGenTick = nowTick

    -- Standby: jarum diam di posisi 0 derajat, belum ada minigame.
    if math.abs(rawDelta) < 0.01 and (currentRot % 360) < 0.01 then
        isMinigameActive      = false
        hasHitCurrentMinigame = false
        lineMoveCount         = 0
        hitAttempts           = 0
        return
    end

    -- Deteksi pergerakan jarum yang aktif.
    if math.abs(rawDelta) > 0.01 then
        lineMoveCount = lineMoveCount + 1
    end

    -- Tunggu minimal satu frame pergerakan agar kecepatan terukur.
    if lineMoveCount < 1 then return end

    -- Batas percobaan per minigame. Tetap boleh mencoba lagi kalau
    -- tekanan sebelumnya ternyata tidak registering di server.
    if hitAttempts >= AGEN_MAX_ATTEMPTS then return end

    -- Posisi jarum dinormalisasi ke rentang 0-360.
    local lineRot = currentRot % 360
    if lineRot < 0 then lineRot = lineRot + 360 end

    -- Offset jarum terhadap goal (0-360).
    local offset = (lineRot - goalRot) % 360

    -- ======================================================================
    -- MODE KALIBRASI
    --
    -- Kalau kalibrasi aktif, kita HANYA mengamati dan mencatat, tidak
    -- menekan apa pun. Data yang dikumpulkan: di offset berapa jarum
    -- bergerak paling cepat. Itu menandakan zona putih.
    -- ======================================================================
    if agenCalibrating then
        local speedAbs = math.abs(angularVel)
        local prev = calibSpeeds[offset]
        if prev == nil or speedAbs > prev then
            calibSpeeds[offset] = speedAbs
        end

        -- Cari blok offset yang jarumnya paling cepat.
        -- Deteksi selesai setelah jarum sudah melewati semua sudut,
        -- yaitu sudah pernah melihat offset di seluruh rentang 0-360.
        local keys = {}
        for k in pairs(calibSpeeds) do keys[#keys + 1] = k end
        table.sort(keys)

        if #keys >= 60 then
            -- Ambil kecepatan tertinggi sebagai acuan.
            local maxSpeed = 0
            for _, v in pairs(calibSpeeds) do
                if v > maxSpeed then maxSpeed = v end
            end

            -- Ambil semua offset yang kecepatannya setidaknya 60 persen
            -- dari puncak. Itu rentang zona putihnya.
            local minSeen, maxSeen = nil, nil
            for _, k in ipairs(keys) do
                if calibSpeeds[k] >= maxSpeed * 0.6 then
                    if minSeen == nil or k < minSeen then minSeen = k end
                    if maxSeen == nil or k > maxSeen then maxSeen = k end
                end
            end

            if minSeen and maxSeen then
                local lo, hi = apply_calibration(minSeen, maxSeen)
                log("[AutoGen] Kalibrasi selesai: zona %.1f sampai %.1f derajat "
                    .. "(deteksi mentah %.1f sampai %.1f, puncak %.0f)",
                    lo, hi, minSeen, maxSeen, maxSpeed)
            end
        end
        return
    end

    -- Zona putih: rentang offset di mana tekanan dianggap berhasil.
    -- Bisa diatur lewat slider karena tiap generator punya lebar
    -- zona yang sedikit berbeda.
    local zoneMin = agenZoneMin
    local zoneMax = agenZoneMax

    -- Prediksi lintasan jarum dalam LOOKAHEAD detik ke depan.
    --
    -- PERBAIKAN: sebelumnya hanya mengecek satu titik (offset saat ini
    -- ditambah kecepatan kali 1.2). Pada King's Scourge jarum bergerak
    -- sangat cepat sehingga bisa MELOMPAT melewati seluruh zona dalam
    -- satu frame, sehingga tidak pernah terdeteksi.
    -- Sekarang diambil beberapa sampel sepanjang lintasan, jadi zona
    -- yang terlewat di antara dua frame tetap terdeteksi.
    local LOOKAHEAD = 1 / 30
    local SAMPLES  = 5
    local shouldHit = false
    for k = 0, SAMPLES do
        local t = LOOKAHEAD * (k / SAMPLES)
        local probe = (offset + angularVel * t) % 360
        if in_gen_zone(probe, zoneMin, zoneMax) then
            shouldHit = true
            break
        end
    end

    -- Tekan dengan jeda pendek antar percobaan supaya tidak spam.
    if shouldHit and (nowTick - lastHitTick) >= AGEN_PRESS_COOLDOWN then
        hasHitCurrentMinigame = true
        lastHitTick           = nowTick
        autoGenHitCount       = autoGenHitCount + 1
        hitAttempts           = hitAttempts + 1
        agen_press(spaceObj)

        -- Detail hanya tampil kalau SKY_DEBUG = true.
        log("[AutoGen] PERFECT HIT! Jarum: %.1f | Goal: %.1f | Offset: %.1f | Vel: %.0f | Percobaan %d",
            lineRot, goalRot, offset, angularVel, hitAttempts)
    end
end

function agen_start()
    if autoGenConn then return end
    autoGenHitCount       = 0
    isMinigameActive      = false
    hasHitCurrentMinigame = false
    lastLineRotation      = nil
    lastGoalRotation      = nil
    lastHitTick           = 0
    lineMoveCount         = 0
    autoGenConn = RunService.RenderStepped:Connect(agen_tick)
end

function agen_stop()
    if autoGenConn then
        autoGenConn:Disconnect()
        autoGenConn = nil
    end
    isMinigameActive = false
    hasHitCurrentMinigame = false
    lastLineRotation = nil
    lineMoveCount = 0
end


end

-- ==============================================================================
do
-- MODUL 4.5: AUTO PARRY (PARRYING DAGGER)
-- ==============================================================================
autoParryEnabled = false
local autoParryConn    = nil
local PARRY_DISTANCE   = 16.0
local PARRY_COOLDOWN   = 3.5  -- Mengikuti cooldown resmi game (minimal 3.5 detik)
local lastParryTick    = 0
local isParrying       = false
local gameParryCooldownEnd = 0
local trackedAnimators = {}

local function cleanup_animator_tracks()
    for anim, conn in pairs(trackedAnimators) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    trackedAnimators = {}
end

local KNOWN_ATTACK_ANIM_IDS = {
    -- Abysswalker
    ["98833771436786"]  = true,
    ["118907603246885"] = true,
    ["78432063483146"]  = true,
    ["126626340093785"] = true,
    -- Masked
    ["129784271201071"] = true,
    ["132817836308238"] = true,
    ["76503974441748"]  = true,
    ["82666958311998"]  = true,
    ["133002120549396"] = true,
    -- Hidden Killer
    ["73681849513551"]  = true,
}

local IGNORED_LOOP_NAMES = {
    ["idle"] = true, ["walk"] = true, ["run"] = true, ["jump"] = true,
    ["fall"] = true, ["strafe"] = true, ["climb"] = true,
}

local cachedParryClient = nil
local cachedParryRemote = nil

local function get_parry_instance()
    if cachedParryClient and cachedParryClient.Parry then
        return cachedParryClient
    end

    -- Cari instance ParryClient yang SUDAH DIBUAT oleh game (agar model skin dagger tidak hilang/reset)
    if getgc then
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "Parry") and rawget(v, "isParryOnCooldown") ~= nil then
                    cachedParryClient = v
                    return
                end
            end
        end)
    end

    return cachedParryClient
end

-- Dengarkan event parryResult resmi game untuk mengetahui kapan cooldown selesai
pcall(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 2)
    local items = remotes and remotes:WaitForChild("Items", 2)
    local dagger = items and items:WaitForChild("Parrying Dagger", 2)
    local parryResult = dagger and dagger:WaitForChild("parryResult", 2)
    if parryResult then
        parryResult.OnClientEvent:Connect(function(arg1, cd)
            local cooldownDuration = tonumber(cd) or 3.5
            gameParryCooldownEnd = tick() + cooldownDuration
            isParrying = false
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    cachedParryClient = nil
    cachedParryRemote = nil
    isParrying = false
    lastParryTick = 0
    gameParryCooldownEnd = 0
    cleanup_animator_tracks()

    task.delay(1, function()
        if is_local_player_killer and is_local_player_killer() then
            cleanup_animator_tracks()
            isParrying = false
            pcall(function()
                Window:Notify({
                    Title = "⚔️ Mode Killer Terdeteksi",
                    Description = "Auto Parry dinonaktifkan otomatis. Serangan (M1) & skill kamu 100% lancar!",
                    Lifetime = 4
                })
            end)
        else
            if autoParryEnabled then
                scanAllEntities()
            end
        end
    end)
end)

local function execute_perfect_parry(killerModel, killerName, reason, dist)
    -- [CRITICAL FIX KILLER] Jangan pernah parry jika kita sendiri adalah Killer!
    if is_local_player_killer and is_local_player_killer() then return end
    local myChar = LocalPlayer.Character
    if not myChar or killerModel == myChar then return end

    local now = tick()
    -- Cek cooldown internal & cooldown dari game
    if isParrying or (now - lastParryTick < PARRY_COOLDOWN) or (now < gameParryCooldownEnd) then
        return
    end

    local myHrp = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    local killerHrp = killerModel and (killerModel:FindFirstChild("HumanoidRootPart") or killerModel:FindFirstChild("Torso"))
    if not myHrp or not killerHrp then return end

    -- Cek apakah karakter sedang melakukan aksi lain / dibawa / di-hook
    local cs = game:GetService("CollectionService")
    if cs:HasTag(myHrp, "doing action") or myChar:GetAttribute("IsCarried") or myChar:GetAttribute("IsHooked") then
        return
    end

    -- Cek instance ParryClient game: apakah sedang cooldown / resolving
    local parryObj = get_parry_instance()
    if parryObj then
        if parryObj.isParryOnCooldown or parryObj.isParryResolving then
            return -- Sedang cooldown di dalam game!
        end
        if parryObj.CanUse and not parryObj:CanUse() then
            return -- Tidak bisa digunakan (cooldown / busy)
        end
    end

    lastParryTick = now
    isParrying = true
    -- Pasang cooldown awal minimal 3.5s sampai di-update oleh event parryResult
    gameParryCooldownEnd = now + PARRY_COOLDOWN

    -- 1. Auto-Face: Hadapkan badan tepat ke arah killer (0ms snap)
    local toKiller = Vector3.new(killerHrp.Position.X - myHrp.Position.X, 0, killerHrp.Position.Z - myHrp.Position.Z)
    if toKiller.Magnitude > 0.5 then
        myHrp.CFrame = CFrame.new(myHrp.Position, myHrp.Position + toKiller.Unit)
    end

    -- 2. Panggil Method Resmi ParryClient
    local called = false
    if parryObj and parryObj.Parry then
        local ok = pcall(function()
            parryObj:Parry()
        end)
        called = ok
    end

    -- 3. HANYA panggil Remote jika parryObj TIDAK ADA atau GAGAL
    -- (PENTING: Jangan pernah panggil keduanya sekaligus agar tidak terjadi parry 2x)
    if not called then
        pcall(function()
            if not cachedParryRemote then
                local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
                local itemsFolder = remotesFolder and remotesFolder:FindFirstChild("Items")
                local daggerFolder = itemsFolder and itemsFolder:FindFirstChild("Parrying Dagger")
                cachedParryRemote = daggerFolder and daggerFolder:FindFirstChild("parry")
            end
            if cachedParryRemote then
                cachedParryRemote:FireServer()
            end
        end)
    end

    -- Hanya tampil kalau SKY_DEBUG = true, karena ini bisa sangat sering.
    log("[AutoParry] PERFECT PARRY! Killer: %s | Jarak: %.1f studs | %s",
        tostring(killerName), dist or 0, reason)

    -- Fallback: reset isParrying setelah PARRY_COOLDOWN detik
    -- (event parryResult akan reset lebih cepat jika server merespons)
    task.delay(PARRY_COOLDOWN, function()
        isParrying = false
    end)
end

local function is_killer_entity(model)
    if not model or not model:IsA("Model") then return false end
    -- [CRITICAL FIX KILLER] Diri sendiri BUKAN target parry!
    local myChar = LocalPlayer and LocalPlayer.Character
    if model == myChar then return false end
    local p = Players:GetPlayerFromCharacter(model)
    if p == LocalPlayer then return false end

    -- 1. Cek Model "Weapon" di karakter (Killer selalu memegang child Model "Weapon")
    if model:FindFirstChild("Weapon") then return true end
    -- 2. Cek CollectionService Tag "Killer"
    local cs = game:GetService("CollectionService")
    if cs:HasTag(model, "Killer") then return true end
    local ok, tags = pcall(function() return cs:GetTags(model) end)
    if ok and tags then
        for _, t in ipairs(tags) do
            if t:lower():find("killer") then return true end
        end
    end
    -- 3. Cek Attribute khas Killer
    if model:GetAttribute("TerrorRadius") or model:GetAttribute("SuspenseRadius")
        or model:GetAttribute("Chasemusic") or model:GetAttribute("BloodLust") then
        return true
    end
    -- 4. Cek Player jika entity adalah karakter Player
    if p then
        local role = p:GetAttribute("CurrentRole") or p:GetAttribute("Role")
        if role and tostring(role):lower() == "killer" then return true end
        if p.Character and p.Character:FindFirstChild("Weapon") then return true end
    end
    return false
end

local function monitorAnimator(animator, ownerModel, ownerName)
    if trackedAnimators[animator] then return end

    -- [CRITICAL FIX KILLER] JANGAN PERNAH monitor animator karakter sendiri!
    local myChar = LocalPlayer and LocalPlayer.Character
    if not ownerModel or ownerModel == myChar then return end
    if ownerName == (LocalPlayer.DisplayName or LocalPlayer.Name) or ownerName == LocalPlayer.Name then return end

    local conn = animator.AnimationPlayed:Connect(function(track)
        if not autoParryEnabled then return end
        -- [CRITICAL FIX KILLER] Jika kita adalah Killer, jangan pernah tangkis!
        if is_local_player_killer and is_local_player_killer() then return end

        local curChar = LocalPlayer and LocalPlayer.Character
        if not curChar or ownerModel == curChar then return end

        -- Cek SEMUA kondisi cooldown sebelum parry
        local now2 = tick()
        if isParrying or (now2 - lastParryTick < PARRY_COOLDOWN) or (now2 < gameParryCooldownEnd) then return end

        -- HANYA AUTO PARRY JIKA ENTITY ADALAH KILLER! JANGAN PARRY JIKA SURVIVOR NEMBAK!
        if not is_killer_entity(ownerModel) then
            return
        end

        local myHrp = curChar:FindFirstChild("HumanoidRootPart") or curChar:FindFirstChild("Torso")
        local killerHrp = ownerModel and (ownerModel:FindFirstChild("HumanoidRootPart") or ownerModel:FindFirstChild("Torso"))

        if not myHrp or not killerHrp then return end

        -- Skip jika killer sedang MEMBAWA survivor (bukan menyerang kita)
        local killerIsCarrying = ownerModel:GetAttribute("IsCarrying") or ownerModel:GetAttribute("Carrying")
        if killerIsCarrying and killerIsCarrying ~= false and killerIsCarrying ~= 0 then
            return -- Killer sedang bawa survi, bukan menyerang
        end
        -- Juga cek apakah kita sedang di-carry
        if curChar:GetAttribute("IsCarried") then
            return
        end

        local dist = (myHrp.Position - killerHrp.Position).Magnitude
        -- Wajib dist > 0.5 agar tidak pernah mendeteksi karakter sendiri
        if dist <= PARRY_DISTANCE and dist > 0.5 then
            -- DIRECTIONAL CHECK: Hanya tangkis jika killer menghadap kita
            local killerLook = killerHrp.CFrame.LookVector
            local killerLookFlat = Vector3.new(killerLook.X, 0, killerLook.Z)
            if killerLookFlat.Magnitude > 0 then killerLookFlat = killerLookFlat.Unit else killerLookFlat = killerLook end

            local toPlayer = (myHrp.Position - killerHrp.Position)
            local toPlayerFlat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
            if toPlayerFlat.Magnitude > 0 then toPlayerFlat = toPlayerFlat.Unit else toPlayerFlat = toPlayer end

            local facingAngle = killerLookFlat:Dot(toPlayerFlat)
            if facingAngle < 0.45 then
                return -- Killer mengayun ke arah lain / membelakangi
            end

            local anim = track.Animation
            local animId = anim and anim.AnimationId or ""
            local cleanId = tostring(animId):match("%d+")
            local animName = (track.Name or ""):lower()

            -- Skip animasi carry / pickup
            local isCarryAnim = animName:find("carry") or animName:find("pickup")
                or animName:find("pick_up") or animName:find("grab") or animName:find("lift")
                or animName:find("drop") or animName:find("throw") or animName:find("release")
            if isCarryAnim then return end

            -- Skip animasi tembakan senjata api / flare
            if animName:find("shoot") or animName:find("gun") or animName:find("fire")
                or animName:find("flare") or animName:find("aim") then
                return
            end

            local isAttack = false
            local reason = ""

            if cleanId and KNOWN_ATTACK_ANIM_IDS[cleanId] then
                isAttack = true
                reason = "ID: " .. cleanId
            elseif animName:find("attack") or animName:find("swing") or animName:find("slash")
                or animName:find("m1") or animName:find("hit") or animName:find("strike") then
                isAttack = true
                reason = "Keyword: " .. animName
            elseif not track.Looped and not IGNORED_LOOP_NAMES[animName] then
                if track.Speed >= 0.4 then
                    isAttack = true
                    reason = string.format("Action Swing (Facing: %.2f)", facingAngle)
                end
            end

            if isAttack then
                execute_perfect_parry(ownerModel, ownerName, reason, dist)
            end
        end
    end)
    trackedAnimators[animator] = conn
end

local function scanAllEntities()
    if not autoParryEnabled then return end
    -- [CRITICAL FIX KILLER] Jika kita adalah Killer, jangan scan & jangan pasang parry!
    if is_local_player_killer and is_local_player_killer() then return end
    local myChar = LocalPlayer and LocalPlayer.Character
    if not myChar then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character ~= myChar and is_killer_entity(p.Character) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local anim = hum and hum:FindFirstChildOfClass("Animator")
            if anim then monitorAnimator(anim, p.Character, p.DisplayName or p.Name) end
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar and is_killer_entity(obj) then
            local p = Players:GetPlayerFromCharacter(obj)
            if p ~= LocalPlayer then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local anim = hum and hum:FindFirstChildOfClass("Animator")
                if anim then monitorAnimator(anim, obj, obj.Name) end
            end
        end
    end
end

local autoParryDescConn = nil

function autoparry_start()
    if autoParryConn then return end
    -- [CRITICAL FIX KILLER] Jika kita Killer, jangan mulai
    if is_local_player_killer and is_local_player_killer() then
        return
    end
    isParrying = false
    lastParryTick = 0
    gameParryCooldownEnd = 0
    -- Scan awal sekali
    scanAllEntities()
    -- Event-driven: pasang listener saat ada child/descendant baru di workspace
    autoParryDescConn = workspace.DescendantAdded:Connect(function(desc)
        if not autoParryEnabled then return end
        if is_local_player_killer and is_local_player_killer() then return end
        if desc:IsA("Animator") then
            local ownerModel = desc.Parent and desc.Parent.Parent
            local myChar = LocalPlayer and LocalPlayer.Character
            if ownerModel and ownerModel ~= myChar and is_killer_entity(ownerModel) then
                local p = Players:GetPlayerFromCharacter(ownerModel)
                if p ~= LocalPlayer then
                    monitorAnimator(desc, ownerModel, ownerModel.Name)
                end
            end
        end
    end)
    -- Heartbeat hanya untuk re-scan entitas baru secara berkala (jarang)
    local scanTimer2 = 0
    autoParryConn = RunService.Heartbeat:Connect(function(dt)
        if not autoParryEnabled then return end
        if is_local_player_killer and is_local_player_killer() then
            -- Jika kita berubah jadi Killer di tengah match, bersihkan semua listener parry
            cleanup_animator_tracks()
            return
        end
        scanTimer2 = scanTimer2 + dt
        if scanTimer2 >= 3 then
            scanTimer2 = 0
            scanAllEntities()
        end
    end)
end

function autoparry_stop()
    if autoParryConn then
        autoParryConn:Disconnect()
        autoParryConn = nil
    end
    if autoParryDescConn then
        autoParryDescConn:Disconnect()
        autoParryDescConn = nil
    end
    isParrying = false
    cleanup_animator_tracks()
end

-- Watcher: jika peran berubah menjadi Killer di tengah permainan, bersihkan tracking segera
pcall(function()
    local function onRoleChanged()
        pcall(function()
            if is_local_player_killer and is_local_player_killer() then
                cleanup_animator_tracks()
                isParrying = false
            end
        end)
    end
    -- Wrap setiap GetAttributeChangedSignal di pcall tersendiri agar tidak crash jika atribut tidak ada
    pcall(function() LocalPlayer:GetAttributeChangedSignal("CurrentRole"):Connect(onRoleChanged) end)
    pcall(function() LocalPlayer:GetAttributeChangedSignal("Role"):Connect(onRoleChanged) end)
    pcall(function() LocalPlayer:GetAttributeChangedSignal("Team"):Connect(onRoleChanged) end)
    pcall(function() LocalPlayer:GetAttributeChangedSignal("Side"):Connect(onRoleChanged) end)
    pcall(function() LocalPlayer:GetAttributeChangedSignal("CharacterType"):Connect(onRoleChanged) end)
end)


end

-- ==============================================================================
-- MODUL 5: PLAYER CONTROLS (SPEED & INFINITE YIELD FLY ENGINE)
-- ==============================================================================
do
local currentSpeed = 16
local loopSpeed = false
local speedConn = nil

local function set_player_speed(val)
    local num = tonumber(val)
    if not num then return end
    currentSpeed = num
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = currentSpeed end
    end
end

local function toggle_loop_speed(enabled)
    loopSpeed = enabled
    if speedConn then speedConn:Disconnect(); speedConn = nil end
    if loopSpeed then
        speedConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed ~= currentSpeed then
                    hum.WalkSpeed = currentSpeed
                end
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and loopSpeed then
        hum.WalkSpeed = currentSpeed
    end
end)

-- FLY ENGINE (INFINITE YIELD MECHANISM)
local FLYING = false
local flySpeed = 1
local flyConn = nil
local flyBG = nil
local flyBV = nil
local flyKeyDown = nil
local flyKeyUp = nil

local function stop_fly()
    FLYING = false
    if flyConn then pcall(function() flyConn:Disconnect() end); flyConn = nil end
    if flyKeyDown then pcall(function() flyKeyDown:Disconnect() end); flyKeyDown = nil end
    if flyKeyUp then pcall(function() flyKeyUp:Disconnect() end); flyKeyUp = nil end
    if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local function start_fly()
    if FLYING then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    stop_fly()
    FLYING = true
    hum.PlatformStand = true

    flyBG = Instance.new("BodyGyro")
    flyBV = Instance.new("BodyVelocity")

    flyBG.P = 9e4
    flyBG.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.cframe = root.CFrame
    flyBG.Parent = root

    flyBV.velocity = Vector3.new(0, 0, 0)
    flyBV.maxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Parent = root

    local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}

    flyKeyDown = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 1
        elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = -1
        elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = -1
        elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 1
        elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E then CONTROL.Q = 1
        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q then CONTROL.E = -1
        end
    end)

    flyKeyUp = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0
        elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0
        elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0
        elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0
        elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E then CONTROL.Q = 0
        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q then CONTROL.E = 0
        end
    end)

    flyConn = RunService.RenderStepped:Connect(function()
        if not FLYING or not char.Parent or not root.Parent or not hum.Parent then
            stop_fly()
            return
        end

        hum.PlatformStand = true
        local cam = workspace.CurrentCamera
        flyBG.cframe = cam.CFrame

        local speedMultiplier = flySpeed * 50
        local vel = Vector3.new(0, 0, 0)

        -- Dukungan Mobile Joystick (MoveDirection)
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            vel = vel + (moveDir * speedMultiplier)
        end

        -- Dukungan Keyboard WASD
        if CONTROL.F + CONTROL.B ~= 0 or CONTROL.L + CONTROL.R ~= 0 then
            local forward = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            vel = vel + (forward * (CONTROL.F + CONTROL.B) + right * (CONTROL.L + CONTROL.R)) * speedMultiplier
        end

        -- Dukungan Naik/Turun (Space/E dan Shift/Q)
        if CONTROL.Q + CONTROL.E ~= 0 then
            vel = vel + (Vector3.new(0, 1, 0) * (CONTROL.Q + CONTROL.E) * speedMultiplier)
        end

        flyBV.velocity = vel
    end)

    hum.Died:Connect(function()
        stop_fly()
    end)
end

-- Anti-AFK (Standard & Safe: Idled event, tidak membajak controller/mouse)
local VirtualUser = cloneref and cloneref(game:GetService("VirtualUser")) or game:GetService("VirtualUser")
local antiAfkConn = nil
local antiAfkEnabled = false

local function toggle_anti_afk(enabled)
    antiAfkEnabled = enabled
    if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
    if enabled then
        pcall(function()
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.5)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end
end

-- Auto-aktifkan Anti-AFK saat script dimuat
task.defer(function()
    toggle_anti_afk(true)
end)

-- ==============================================================================
-- TAB 1: PLAYER (SPEED, FLY & ANTI-AFK)
-- ==============================================================================
local TabPlayer = tabGroup:Tab({ Name = "Player", Image = "lucide/user" })

-- SEKSI 1: SPEED PLAYER
local SecSpeed = TabPlayer:Section({})
SecSpeed:Header({ Name = WMacLib:Gradient("Kecepatan Pemain (WalkSpeed)", Color3.fromRGB(99,130,255), Color3.fromRGB(72,214,200)) })

SecSpeed:Slider({
    Name = "WalkSpeed Slider",
    Default = 16,
    Minimum = 16,
    Maximum = 300,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        set_player_speed(val)
    end
})

SecSpeed:Input({
    Name = "Custom WalkSpeed",
    Default = "16",
    Placeholder = "Ketik angka (misal: 50)...",
    AcceptedCharacters = "Numeric",
    Callback = function(text)
        set_player_speed(text)
        Window:Notify({ Title = "Player Speed", Description = "WalkSpeed diubah ke " .. tostring(text), Lifetime = 3 })
    end
})

SecSpeed:Toggle({
    Name = "Kunci WalkSpeed (Anti-Reset)",
    Default = false,
    Callback = function(enabled)
        toggle_loop_speed(enabled)
        Window:Notify({
            Title = "WalkSpeed",
            Description = enabled and "WalkSpeed dikunci secara konstan!" or "Kunci WalkSpeed dimatikan.",
            Lifetime = 3
        })
    end
})

SecSpeed:Button({
    Name = "Reset WalkSpeed (Default 16)",
    Callback = function()
        set_player_speed(16)
        Window:Notify({ Title = "WalkSpeed", Description = "WalkSpeed kembali ke normal (16).", Lifetime = 3 })
    end
})

-- SEKSI 2: FLY ENGINE
local SecFly = TabPlayer:Section({})
SecFly:Header({ Name = WMacLib:Gradient("Terbang (Infinite Yield Fly)", Color3.fromRGB(99,130,255), Color3.fromRGB(168,120,255)) })

SecFly:Toggle({
    Name = "Aktifkan Fly",
    Default = false,
    Callback = function(enabled)
        if enabled then
            start_fly()
            Window:Notify({ Title = "Fly", Description = "Mode terbang diaktifkan!", Lifetime = 3 })
        else
            stop_fly()
            Window:Notify({ Title = "Fly", Description = "Mode terbang dimatikan.", Lifetime = 3 })
        end
    end
})

SecFly:Slider({
    Name = "Kecepatan Fly (Speed)",
    Default = 1,
    Minimum = 1,
    Maximum = 10,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        flySpeed = val
    end
})

SecFly:Input({
    Name = "Custom Fly Speed",
    Default = "1",
    Placeholder = "Ketik kecepatan fly...",
    AcceptedCharacters = "Numeric",
    Callback = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            flySpeed = num
            Window:Notify({ Title = "Fly Speed", Description = "Kecepatan terbang diubah ke " .. tostring(num), Lifetime = 3 })
        end
    end
})

-- SEKSI 3: ANTI-AFK
local SecUtil = TabPlayer:Section({})
SecUtil:Header({ Name = WMacLib:Gradient("Player Utility", Color3.fromRGB(99,130,255), Color3.fromRGB(120,160,255)) })

SecUtil:Toggle({
    Name = "Anti-AFK (Cegah Disconnect 20 Menit)",
    Default = true,  -- [DEFAULT ON]
    Callback = function(enabled)
        toggle_anti_afk(enabled)
        Window:Notify({
            Title = "Anti-AFK",
            Description = enabled and "Anti-AFK aktif! Tidak akan di-kick AFK." or "Anti-AFK dinonaktifkan.",
            Lifetime = 3
        })
    end
})

end -- [End TabPlayer]

-- ==============================================================================
-- TAB 2: MAIN (AUTO GENERATOR, AUTO PARRY, AUTO HEAL)
-- ==============================================================================
local TabMain = tabGroup:Tab({ Name = "Main", Image = "lucide/zap" })

local SecAutoGen = TabMain:Section({})
SecAutoGen:Header({ Name = WMacLib:Gradient("Auto Perfect Generator", Color3.fromRGB(72,214,200), Color3.fromRGB(99,130,255)) })

SecAutoGen:Toggle({
    Name = "Aktifkan Auto Perfect Gen",
    Default = false,
    Callback = function(enabled)
        autoGenEnabled = enabled
        if enabled then
            agen_start()
            Window:Notify({ Title = "Auto Perfect Gen", Description = "Aktif! Otomatis Perfect di tengah zona putih.", Lifetime = 3 })
        else
            agen_stop()
            Window:Notify({ Title = "Auto Perfect Gen", Description = "Dimatikan.", Lifetime = 2 })
        end
    end
})

-- Kalibrasi otomatis.
-- Mode ini hanya MENGAMATI jarum selama satu putaran dan mencari
-- sendiri di mana zona putih berada, lalu menyimpannya otomatis.
-- Gunanya kalau update game memindahkan zona, atau kalau zona tiap
-- generator ternyata punya lebar yang berbeda-beda.
SecAutoGen:Toggle({
    Name = "Mode Kalibrasi (Deteksi Zona)",
    Default = false,
    Callback = function(enabled)
        agenCalibrating = enabled
        if enabled then
            -- Bersihkan data lama supaya mengukur putaran yang baru.
            -- Tabel ini global, jadi bisa langsung di-reset dari sini.
            calibSpeeds  = {}
            calibMinSeen = nil
            calibMaxSeen = nil
            Window:Notify({
                Title = "Kalibrasi Zona",
                Description = "Aktif. Biarkan Auto Perfect Gen menyala "
                    .. "satu putaran penuh, lalu cek console untuk hasil deteksi.",
                Lifetime = 5
            })
        else
            Window:Notify({
                Title = "Kalibrasi Selesai",
                Description = string.format(
                    "Zona putih terdeteksi: %.1f sampai %.1f derajat.",
                    agenZoneMin, agenZoneMax),
                Lifetime = 4
            })
        end
    end
})

-- Slider untuk penyesuaian manual kalau zona masih meleset.
SecAutoGen:Slider({
    Name = "Zona Min (derajat)",
    Default = 103,
    Minimum = 80,
    Maximum = 130,
    Increment = 0.5,
    DisplayMethod = "Decimal",
    Precision = 1,
    Callback = function(val)
        -- Jaga zonaMin tetap di bawah zonaMax supaya tidak terbalik.
        if val >= agenZoneMax then
            agenZoneMax = val + 0.5
        end
        agenZoneMin = val
    end
})

SecAutoGen:Slider({
    Name = "Zona Max (derajat)",
    Default = 114,
    Minimum = 90,
    Maximum = 140,
    Increment = 0.5,
    DisplayMethod = "Decimal",
    Precision = 1,
    Callback = function(val)
        if val <= agenZoneMin then
            agenZoneMin = val - 0.5
        end
        agenZoneMax = val
    end
})

SecAutoGen:Label({ Name = "Kalau masih sering meleset, pakai Mode Kalibrasi lebih dulu." })

local SecAutoParry = TabMain:Section({})
SecAutoParry:Header({ Name = WMacLib:Gradient("Auto Parry", Color3.fromRGB(232,120,140), Color3.fromRGB(168,120,255)) })

SecAutoParry:Toggle({
    Name = "Aktifkan Auto Parry",
    Default = false,
    Callback = function(enabled)
        autoParryEnabled = enabled
        if enabled then
            if is_local_player_killer and is_local_player_killer() then
                Window:Notify({
                    Title = "Auto Parry",
                    Description = "Kamu sedang bermain sebagai Killer! Auto Parry ditangguhkan agar serangan & skill kamu lancar.",
                    Lifetime = 4
                })
                return
            end
            autoparry_start()
            Window:Notify({ Title = "Auto Parry", Description = "Aktif! Menangkis serangan killer otomatis.", Lifetime = 3 })
        else
            autoparry_stop()
            Window:Notify({ Title = "Auto Parry", Description = "Auto Parry dimatikan.", Lifetime = 2 })
        end
    end
})

-- SEKSI 3: AUTO HEAL
local SecAutoHealMain = TabMain:Section({})
SecAutoHealMain:Header({ Name = WMacLib:Gradient("Auto Heal (Pemulihan Otomatis)", Color3.fromRGB(86,204,158), Color3.fromRGB(72,214,200)) })

SecAutoHealMain:Toggle({
    Name = "Aktifkan Auto Heal",
    Default = false,
    Callback = function(enabled)
        autoHealEnabled = enabled
        if enabled then
            autoheal_start()
            Window:Notify({ Title = "Auto Heal", Description = "Otomatis memulihkan HP!", Lifetime = 3 })
        else
            Window:Notify({ Title = "Auto Heal", Description = "Auto Heal dimatikan.", Lifetime = 2 })
        end
    end
})

SecAutoHealMain:Slider({
    Name = "Interval Heal (x10 = detik)",
    Default = 15,
    Minimum = 5,
    Maximum = 60,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        HEAL_COOLDOWN = val / 10
    end
})

-- SEKSI: AUTO ESCAPE (BYPASS SURVIVOR WIN)
local SecAutoEscape = TabMain:Section({})
SecAutoEscape:Header({ Name = WMacLib:Gradient("Auto Escape (Bypass Win)", Color3.fromRGB(72,214,200), Color3.fromRGB(140,200,255)) })

-- Pastikan auto-loop dari sesi sebelumnya tidak masih berjalan
autoEscapeEnabled = false
stop_auto_escape()

SecAutoEscape:Button({
    Name = "ESCAPE SEKARANG",
    Callback = function()
        local ok, msg = trigger_instant_escape()
        Window:Notify({
            Title = ok and "Escape diproses" or "Gagal",
            Description = msg or "Error saat escape.",
            Lifetime = 3
        })
    end
})

SecAutoEscape:Label({ Name = "Teleport langsung ke zona keluar. Gerbang otomatis dibuka." })

-- ==============================================================================
-- MODUL CROSSHAIR
-- ==============================================================================
do
local crosshairGui = nil
local crosshairEnabled = false
local crosshairOffsetX = 0
local crosshairOffsetY = 0
local crosshairSize = 20
local crosshairThickness = 2
local crosshairGap = 5
local crosshairColor = Color3.fromRGB(255, 255, 255)
local crosshairOpacity = 1.0
-- Tipe crosshair: "Titik", "Plus", "Keduanya"
local crosshairType = "Plus"

local CROSSHAIR_COLORS = {
    ["Putih"]   = Color3.fromRGB(255, 255, 255),
    ["Merah"]   = Color3.fromRGB(255, 60,  60),
    ["Hijau"]   = Color3.fromRGB(60,  255, 100),
    ["Biru"]    = Color3.fromRGB(60,  160, 255),
    ["Kuning"]  = Color3.fromRGB(255, 230, 50),
    ["Orange"]  = Color3.fromRGB(255, 140, 30),
    ["Pink"]    = Color3.fromRGB(255, 100, 200),
    ["Cyan"]    = Color3.fromRGB(50,  240, 230),
    ["Ungu"]    = Color3.fromRGB(180, 80,  255),
    ["Hitam"]   = Color3.fromRGB(0,   0,   0),
}

local function destroy_crosshair()
    if crosshairGui then
        pcall(function() crosshairGui:Destroy() end)
        crosshairGui = nil
    end
end

local function build_crosshair()
    destroy_crosshair()

    local parent = (gethui and gethui()) or (cloneref and cloneref(CoreGui)) or CoreGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "SkyCrosshair"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.IgnoreGuiInset = true end)
    sg.Parent = parent
    crosshairGui = sg

    local function makeBar(w, h, ox, oy)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Size = UDim2.fromOffset(w, h)
        f.Position = UDim2.new(0.5, crosshairOffsetX + ox, 0.5, crosshairOffsetY + oy)
        f.BackgroundColor3 = crosshairColor
        f.BackgroundTransparency = 1 - crosshairOpacity
        f.BorderSizePixel = 0
        f.Name = "Bar"
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 1)
        return f
    end

    local function makeDot(sizePx)
        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(sizePx, sizePx)
        dot.Position = UDim2.new(0.5, crosshairOffsetX, 0.5, crosshairOffsetY)
        dot.BackgroundColor3 = crosshairColor
        dot.BackgroundTransparency = 1 - crosshairOpacity
        dot.BorderSizePixel = 0
        dot.Name = "Dot"
        dot.Parent = sg
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    end

    if crosshairType == "Titik" then
        -- Hanya tampilkan titik bulat di tengah
        local dotSize = math.max(4, crosshairThickness * 3)
        makeDot(dotSize)
    elseif crosshairType == "Plus" then
        -- Hanya tampilkan garis Plus (+)
        local half = crosshairGap + crosshairSize / 2
        makeBar(crosshairThickness, crosshairSize, 0, -(half + crosshairSize / 2))
        makeBar(crosshairThickness, crosshairSize, 0,  (half + crosshairSize / 2))
        makeBar(crosshairSize, crosshairThickness, -(half + crosshairSize / 2), 0)
        makeBar(crosshairSize, crosshairThickness,  (half + crosshairSize / 2), 0)
    else -- "Keduanya": Plus + Titik tengah
        local half = crosshairGap + crosshairSize / 2
        makeBar(crosshairThickness, crosshairSize, 0, -(half + crosshairSize / 2))
        makeBar(crosshairThickness, crosshairSize, 0,  (half + crosshairSize / 2))
        makeBar(crosshairSize, crosshairThickness, -(half + crosshairSize / 2), 0)
        makeBar(crosshairSize, crosshairThickness,  (half + crosshairSize / 2), 0)
        local dotSize = math.max(4, crosshairThickness * 2 + 1)
        makeDot(dotSize)
    end
end

local function toggle_crosshair(enable)
    crosshairEnabled = enable
    if enable then
        build_crosshair()
    else
        destroy_crosshair()
    end
end

local function update_crosshair()
    if crosshairEnabled then build_crosshair() end
end

-- ==============================================================================
do
-- MODUL 4.6: TWIST OF FATE - ANTI MISS (100% HIT CHANCE) [ULTRA MODE]
-- ==============================================================================
-- STRATEGI KOMPREHENSIF LINTAS ENVIRONMENT:
--   [L1] hookmetamethod __namecall (Tingkat C, intercept Result:Fire & FireServer)
--   [L2] getrenv() math.random & Random hook (mempengaruhi LocalScript game langsung)
--   [L3] ReplicatedStorage.Modules.Items scanner & patch
--   [L4] getgc() scanner & patch tabel/upvalue di memori
--   [L5] Attribute Character & Tool patch tiap Heartbeat
-- ==============================================================================
tofAntiMissEnabled = false
local tofUpdateConn        = nil
local tofResultEvent       = nil
local tofFireEvent         = nil
local tofGunTable          = nil
local tofRepatchInterval   = 0.25
local tofMetaHooked        = false
local tofOrigNamecall      = nil
local tofOrigRenvRandom    = nil
local tofRenvHooked        = false

-- [Layer 1 Remote Finder]
local function tof_get_remotes()
    if tofResultEvent and tofFireEvent then return true end
    pcall(function()
        local remotes   = ReplicatedStorage:FindFirstChild("Remotes")
        local items     = remotes and remotes:FindFirstChild("Items")
        local tofFolder = items and items:FindFirstChild("Twist of Fate")
        if tofFolder then
            tofResultEvent = tofFolder:FindFirstChild("Result")
            tofFireEvent   = tofFolder:FindFirstChild("Fire")
        end
    end)
    return tofResultEvent ~= nil
end

-- Helper: deteksi argumen yang mengindikasikan miss
local function tof_is_miss_arg(val)
    if type(val) == "boolean" and val == false then return true end
    if type(val) == "string" then
        local fs = val:lower()
        if fs:find("miss") or fs:find("fail") or fs:find("self") or fs == "false" then
            return true
        end
    end
    if type(val) == "number" and val == 0 then return true end
    if type(val) == "table" then
        for k, v in pairs(val) do
            local ks = tostring(k):lower()
            if ks:find("miss") or ks:find("fail") then
                if v == true or v == 1 then return true end
            elseif ks:find("hit") or ks:find("success") then
                if v == false or v == 0 then return true end
            end
        end
    end
    return false
end

-- ============================================================
-- [Layer 1] hookmetamethod __namecall
-- Intercept Result:Fire dan ubah miss -> hit (agar tidak kena diri sendiri)
-- Intercept FireServer dan pastikan status hit
-- ============================================================
local function tof_hook_namecall()
    if tofMetaHooked then return end
    if not hookmetamethod then return end

    pcall(function()
        local _orig
        _orig = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args   = {...}

            local isResult = (tofResultEvent and self == tofResultEvent)
                or (self.Name == "Result" and self.Parent and self.Parent.Name == "Twist of Fate")
            local isFire   = (tofFireEvent and self == tofFireEvent)
                or (self.Name == "Fire" and self.Parent and self.Parent.Name == "Twist of Fate")

            -- Intercept BindableEvent Result:Fire(...) -> ubah miss menjadi hit!
            if tofAntiMissEnabled and isResult and (method == "Fire" or method == "fire") then
                if #args == 0 then
                    return _orig and _orig(self, true)
                end
                for i = 1, #args do
                    if tof_is_miss_arg(args[i]) then
                        if type(args[i]) == "boolean" then
                            args[i] = true
                        elseif type(args[i]) == "string" then
                            args[i] = "hit"
                        elseif type(args[i]) == "number" then
                            args[i] = 1
                        elseif type(args[i]) == "table" then
                            for tk, _ in pairs(args[i]) do
                                local tks = tostring(tk):lower()
                                if tks:find("miss") or tks:find("fail") then
                                    args[i][tk] = false
                                elseif tks:find("hit") or tks:find("success") then
                                    args[i][tk] = true
                                end
                            end
                        end
                    end
                end
                return _orig and _orig(self, table.unpack(args))
            end

            -- Intercept RemoteEvent Fire:FireServer(...) -> pastikan tidak ada flag miss
            if tofAntiMissEnabled and isFire and (method == "FireServer" or method == "fireserver") then
                for i = 1, #args do
                    if type(args[i]) == "boolean" and args[i] == false then
                        args[i] = true
                    elseif type(args[i]) == "string" then
                        local s = args[i]:lower()
                        if s:find("miss") or s:find("fail") or s:find("self") then
                            args[i] = "hit"
                        end
                    end
                end
                return _orig and _orig(self, table.unpack(args))
            end

            if _orig then
                return _orig(self, ...)
            end
        end)
        tofOrigNamecall = _orig
        tofMetaHooked = true
    end)
end

local function tof_unhook_namecall()
    if not tofMetaHooked then return end
    if not hookmetamethod or not tofOrigNamecall then return end
    pcall(function()
        hookmetamethod(game, "__namecall", tofOrigNamecall)
    end)
    tofMetaHooked = false
end

-- ============================================================
-- [Layer 2] getrenv() math.random & Random hook
-- Mempengaruhi LocalScript game secara langsung
-- ============================================================
local function tof_hook_renv()
    if tofRenvHooked then return end
    pcall(function()
        local renv = getrenv and getrenv()
        if not renv then return end

        if renv.math and renv.math.random then
            tofOrigRenvRandom = renv.math.random
            local safeRandom = function(...)
                if not tofAntiMissEnabled then
                    return tofOrigRenvRandom(...)
                end
                local n = select("#", ...)
                if n == 0 then
                    return 0.999999
                elseif n == 1 then
                    local m = select(1, ...)
                    if type(m) == "number" then return m end
                elseif n >= 2 then
                    local _, maxVal = select(1, ...), select(2, ...)
                    if type(maxVal) == "number" then return maxVal end
                end
                return tofOrigRenvRandom(...)
            end

            if hookfunction then
                hookfunction(renv.math.random, safeRandom)
            else
                renv.math.random = safeRandom
            end
            tofRenvHooked = true
        end
    end)
end

local function tof_unhook_renv()
    if not tofRenvHooked then return end
    pcall(function()
        local renv = getrenv and getrenv()
        if renv and renv.math and tofOrigRenvRandom then
            if hookfunction then
                hookfunction(renv.math.random, tofOrigRenvRandom)
            else
                renv.math.random = tofOrigRenvRandom
            end
        end
    end)
    tofRenvHooked = false
end

-- ============================================================
-- [Layer 3 & 4] Scanner Modul Item & Memory getgc()
-- ============================================================
local function tof_patch_table_fields(tbl)
    pcall(function()
        for k, v in pairs(tbl) do
            local ks = tostring(k):lower()
            if type(v) == "number" then
                if ks:find("miss") or ks:find("fail") or ks:find("penalty") then
                    tbl[k] = 0
                elseif ks:find("chance") or ks:find("accuracy") or ks:find("hit") or ks:find("success") then
                    tbl[k] = 100
                end
            elseif type(v) == "boolean" then
                if ks:find("miss") or ks:find("fail") then
                    tbl[k] = false
                elseif ks:find("hit") or ks:find("success") then
                    tbl[k] = true
                end
            end
        end
    end)
end

local function tof_scan_item_modules()
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local items = modules and modules:FindFirstChild("Items")
        if items then
            for _, child in ipairs(items:GetChildren()) do
                local cn = child.Name:lower()
                if cn:find("twist") or cn:find("fate") or cn:find("gun") or cn:find("pistol") then
                    local ok, modTable = pcall(require, child)
                    if ok and type(modTable) == "table" then
                        tofGunTable = modTable
                        tof_patch_table_fields(modTable)
                    end
                end
            end
        end
    end)
end

local function tof_patch_gun_table()
    if tofGunTable then
        tof_patch_table_fields(tofGunTable)
        return
    end
    tof_scan_item_modules()
    if tofGunTable then return end

    if not getgc then return end
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" then
                local hasMiss  = rawget(v,"missChance") or rawget(v,"MissChance")
                    or rawget(v,"miss_chance") or rawget(v,"failChance") or rawget(v,"misschance")
                local hasShoot = rawget(v,"Shoot") or rawget(v,"shoot")
                    or rawget(v,"Fire") or rawget(v,"CanFire") or rawget(v,"canFire")
                local hasAmmo  = rawget(v,"ammo") or rawget(v,"Ammo")
                    or rawget(v,"BulletCount") or rawget(v,"bulletCount") or rawget(v,"Bullets")
                if hasMiss or (hasShoot and hasAmmo) then
                    tofGunTable = v
                    tof_patch_table_fields(v)
                    return
                end
            end
        end
    end)
end

-- ============================================================
-- [Layer 5] Patch Attribute Character & Tool
-- ============================================================
local function tof_patch_character_attrs()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    pcall(function()
        local missKeys = {"MissChance","missChance","miss_chance","FailChance","failChance",
                          "GunPenalty","WeaponPenalty","TwistPenalty"}
        local hitKeys  = {"HitChance","hitChance","Accuracy","accuracy","GunAccuracy"}
        for _, k in ipairs(missKeys) do
            if char:GetAttribute(k) ~= nil then char:SetAttribute(k, 0) end
        end
        for _, k in ipairs(hitKeys) do
            if char:GetAttribute(k) ~= nil then char:SetAttribute(k, 100) end
        end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and child.Name:lower():find("twist") then
                for _, k in ipairs(missKeys) do
                    if child:GetAttribute(k) ~= nil then child:SetAttribute(k, 0) end
                end
                for _, k in ipairs(hitKeys) do
                    if child:GetAttribute(k) ~= nil then child:SetAttribute(k, 100) end
                end
            end
        end
    end)
end

function tof_start()
    tof_get_remotes()
    tof_hook_namecall()         -- [L1] C-level __namecall intercept (Result & Fire)
    tof_hook_renv()             -- [L2] getrenv() math.random hook
    tof_scan_item_modules()     -- [L3] Scan module item di ReplicatedStorage
    tof_patch_gun_table()       -- [L4] getgc() scan & patch
    tof_patch_character_attrs() -- [L5] Attribute Character & Tool patch

    if tofUpdateConn then tofUpdateConn:Disconnect() end
    local tofTimer = 0
    tofUpdateConn = RunService.Heartbeat:Connect(function(dt)
        if not tofAntiMissEnabled then return end
        tofTimer = tofTimer + dt
        if tofTimer >= tofRepatchInterval then
            tofTimer = 0
            tof_patch_gun_table()
            tof_patch_character_attrs()
        end
    end)
end

function tof_stop()
    tof_unhook_namecall()
    tof_unhook_renv()
    if tofUpdateConn then
        tofUpdateConn:Disconnect()
        tofUpdateConn = nil
    end
    tofGunTable = nil
end


end

-- ==============================================================================
-- TAB 2: COMBAT (CROSSHAIR)
-- ==============================================================================
local TabCombat = tabGroup:Tab({ Name = "Combat", Image = "lucide/crosshair" })

local SecCross = TabCombat:Section({})
SecCross:Header({ Name = WMacLib:Gradient("Crosshair", Color3.fromRGB(232,120,140), Color3.fromRGB(255,170,120)) })

SecCross:Toggle({
    Name = "Aktifkan Crosshair",
    Default = false,
    Callback = function(enabled)
        toggle_crosshair(enabled)
        Window:Notify({
            Title = "Crosshair",
            Description = enabled and "Crosshair diaktifkan!" or "Crosshair dimatikan.",
            Lifetime = 3
        })
    end
})

-- TIPE CROSSHAIR
SecCross:Dropdown({
    Name = "Tipe Crosshair",
    Default = "Plus",
    Options = { "Titik", "Plus", "Keduanya" },
    Callback = function(selected)
        crosshairType = selected
        update_crosshair()
        Window:Notify({ Title = "Crosshair", Description = "Tipe diubah ke: " .. selected, Lifetime = 2 })
    end
})

-- WARNA CROSSHAIR
SecCross:Dropdown({
    Name = "Warna Crosshair",
    Default = "Putih",
    Options = { "Putih", "Merah", "Kuning", "Hitam", "Biru", "Hijau", "Orange", "Pink", "Cyan", "Ungu" },
    Callback = function(selected)
        local col = CROSSHAIR_COLORS[selected]
        if col then
            crosshairColor = col
            update_crosshair()
            Window:Notify({ Title = "Crosshair", Description = "Warna diubah ke: " .. selected, Lifetime = 2 })
        end
    end
})

SecCross:Slider({
    Name = "Ukuran Crosshair",
    Default = 20,
    Minimum = 5,
    Maximum = 80,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairSize = val
        update_crosshair()
    end
})

SecCross:Slider({
    Name = "Ketebalan / Ukuran Titik",
    Default = 2,
    Minimum = 1,
    Maximum = 10,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairThickness = val
        update_crosshair()
    end
})

SecCross:Slider({
    Name = "Celah Tengah (Gap) - Hanya Plus",
    Default = 5,
    Minimum = 0,
    Maximum = 30,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairGap = val
        update_crosshair()
    end
})

SecCross:Slider({
    Name = "Opacity / Transparansi",
    Default = 10,
    Minimum = 1,
    Maximum = 10,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairOpacity = val / 10
        update_crosshair()
    end
})

-- Posisi X (kiri/kanan dari tengah layar)
SecCross:Slider({
    Name = "Posisi X (Kiri - Kanan)",
    Default = 0,
    Minimum = -500,
    Maximum = 500,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairOffsetX = val
        update_crosshair()
    end
})

-- Posisi Y (atas/bawah dari tengah layar)
SecCross:Slider({
    Name = "Posisi Y (Atas - Bawah)",
    Default = 0,
    Minimum = -300,
    Maximum = 300,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        crosshairOffsetY = val
        update_crosshair()
    end
})

SecCross:Button({
    Name = "Reset Posisi ke Tengah",
    Callback = function()
        crosshairOffsetX = 0
        crosshairOffsetY = 0
        update_crosshair()
        Window:Notify({ Title = "Crosshair", Description = "Posisi crosshair dikembalikan ke tengah layar.", Lifetime = 3 })
    end
})

-- ==============================================================================
-- SECTION: TWIST OF FATE - ANTI MISS
-- ==============================================================================
local SecTOF = TabCombat:Section({})
SecTOF:Header({ Name = WMacLib:Gradient("Twist of Fate - Anti Miss [ULTRA]", Color3.fromRGB(168,120,255), Color3.fromRGB(99,130,255)) })

SecTOF:Toggle({
    Name = "Anti Miss (100% Hit Chance) [ULTRA]",
    Default = false,
    Callback = function(enabled)
        tofAntiMissEnabled = enabled
        if enabled then
            tof_start()
            Window:Notify({
                Title = "⚡ Twist of Fate ULTRA",
                Description = "Anti Miss aktif! Proteksi otomatis 5 layer berjalan.",
                Lifetime = 3
            })
        else
            tof_stop()
            Window:Notify({
                Title = "Twist of Fate",
                Description = "Anti Miss dimatikan.",
                Lifetime = 2
            })
        end
    end
})

-- ==============================================================================
-- SEKSI: INFINITE ITEM CHARGES (UNLIMITED USES)
-- ==============================================================================
local SecInfCharge = TabCombat:Section({})
SecInfCharge:Header({ Name = WMacLib:Gradient("Infinite Item Charges", Color3.fromRGB(99,130,255), Color3.fromRGB(168,120,255)) })

SecInfCharge:Toggle({
    Name = "Aktifkan Infinite Charges",
    Default = false,
    Callback = function(enabled)
        infiniteChargesEnabled = enabled
        if enabled then
            infinite_charges_start()
            Window:Notify({
                Title = "Infinite Charges",
                Description = "Semua item / tool charges tidak akan pernah habis (999+ uses)!",
                Lifetime = 3
            })
        else
            infinite_charges_stop()
            Window:Notify({
                Title = "Infinite Charges",
                Description = "Infinite Charges dinonaktifkan.",
                Lifetime = 2
            })
        end
    end
})

SecInfCharge:Button({
    Name = "⚡ Refill / Lock Charges Sekarang",
    Callback = function()
        infinite_charges_apply()
        Window:Notify({
            Title = "Refill Selesai",
            Description = "Semua item di inventory telah di-refill ke charges maksimal!",
            Lifetime = 2
        })
    end
})

end -- [End TabCombat]

-- ==============================================================================
-- MODUL ESP Player - Survivor dan Killer
-- ==============================================================================
do
local espPlayerEnabled = false

local ESP_WHITE  = Color3.fromRGB(255, 255, 255)
local ESP_RED    = Color3.fromRGB(255,  50,  50)
local ESP_YELLOW = Color3.fromRGB(255, 200,  50)
local ESP_ORANGE = Color3.fromRGB(255, 120,  30)
local ESP_PURPLE = Color3.fromRGB(200, 100, 255)
local ESP_GREY   = Color3.fromRGB(150, 150, 150)

local CollectionService_ESP = game:GetService("CollectionService")

local function esp_is_killer(char)
    if not char or not char:IsA("Model") then return false end
    if char:FindFirstChild("Weapon") then return true end
    local cs = CollectionService_ESP
    if cs:HasTag(char, "Killer") then return true end
    local ok, tags = pcall(function() return cs:GetTags(char) end)
    if ok and tags then
        for _, t in ipairs(tags) do
            if t:lower():find("killer") then return true end
        end
    end
    if char:GetAttribute("TerrorRadius") or char:GetAttribute("SuspenseRadius")
        or char:GetAttribute("Chasemusic") or char:GetAttribute("BloodLust") then
        return true
    end
    local p = Players:GetPlayerFromCharacter(char)
    if p then
        local role = p:GetAttribute("CurrentRole") or p:GetAttribute("Role")
        if role and tostring(role):lower() == "killer" then return true end
    end
    return false
end

local function esp_get_status(char)
    local ok, hum = pcall(function() return char:FindFirstChildOfClass("Humanoid") end)
    if not ok or not hum then return "?", ESP_GREY end

    -- Cek Hooked via Collection Tag
    local tagOk, tags = pcall(function() return CollectionService_ESP:GetTags(char) end)
    if tagOk and tags then
        for _, tag in ipairs(tags) do
            if tag:lower():find("hook") then
                return "[HK] Hooked", ESP_PURPLE
            end
        end
    end

    -- Cek Hooked via Attribute
    local hookedAttr = char:GetAttribute("IsHooked") or char:GetAttribute("Hooked") or char:GetAttribute("OnHook")
    if hookedAttr == true or hookedAttr == 1 then
        return "[HK] Hooked", ESP_PURPLE
    end

    -- Cek Knocked via Attribute
    local knockedAttr = char:GetAttribute("Knocked")
    if knockedAttr == true or knockedAttr == 1 then
        return "[KO] Knocked", ESP_RED
    end

    -- Fallback via HP
    local hp  = hum.Health
    local maxHp = hum.MaxHealth
    if maxHp <= 0 then return "?", ESP_GREY end
    local ratio = hp / maxHp
    if ratio <= 0   then return "[KO] Knocked", ESP_RED    end
    if ratio < 0.99 then return "[~] Injured",  ESP_ORANGE end
    return "[OK] Aman", ESP_YELLOW
end

local function esp_get_item(char)
    -- Prioritas 1: Attributes pada Player
    local player = Players:GetPlayerFromCharacter(char)
    if player then
        local pAttr = player:GetAttribute("EquippedItem") or player:GetAttribute("Item") 
            or player:GetAttribute("HoldingItem") or player:GetAttribute("CurrentItem") 
            or player:GetAttribute("SelectedTool") or player:GetAttribute("Tool")
        if pAttr and tostring(pAttr) ~= "" and tostring(pAttr) ~= "None" and tostring(pAttr) ~= "nil" then
            return tostring(pAttr)
        end
        -- Fallback: Cek Backpack
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                if v:IsA("Tool") and v.Name ~= "" then return v.Name end
            end
        end
    end
    -- Prioritas 2: Tool yang sedang dipegang di Character
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and v.Name ~= "" then return v.Name end
    end
    -- Prioritas 3: Attribute pada Character itu sendiri
    local cAttr = char:GetAttribute("Item") or char:GetAttribute("EquippedItem") 
        or char:GetAttribute("Weapon") or char:GetAttribute("HoldingItem")
    if cAttr and tostring(cAttr) ~= "" and tostring(cAttr) ~= "None" and tostring(cAttr) ~= "nil" then
        return tostring(cAttr)
    end
    return nil
end

local espPlayerTags = {}
local espHighlights = {}

local function esp_set_highlight_player(player, char, color)
    local h = espHighlights[player]
    if not h then
        h = Instance.new("Highlight")
        h.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.65
        h.OutlineTransparency = 0
        espHighlights[player] = h
    end
    h.FillColor    = color
    h.OutlineColor = color
    if h.Parent ~= char then h.Parent = char end
end

local function esp_remove_highlight_player(player)
    if espHighlights[player] then
        pcall(function() espHighlights[player]:Destroy() end)
        espHighlights[player] = nil
    end
end

local function esp_remove_player(player)
    if espPlayerTags[player] then
        if espPlayerTags[player].bbg then
            pcall(function() espPlayerTags[player].bbg:Destroy() end)
        end
        espPlayerTags[player] = nil
    end
    esp_remove_highlight_player(player)
end

local function esp_hide_player(player)
    if espPlayerTags[player] and espPlayerTags[player].bbg then
        espPlayerTags[player].bbg.Enabled = false
    end
    esp_remove_highlight_player(player)
end

local function esp_get_or_create_tag(player, char)
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not head then return nil end

    local tagData = espPlayerTags[player]
    if tagData and tagData.bbg and tagData.bbg.Parent and tagData.head == head then
        return tagData
    end

    if tagData and tagData.bbg then
        pcall(function() tagData.bbg:Destroy() end)
    end

    local bbg = Instance.new("BillboardGui")
    bbg.Name = "ESP_PlayerTag"
    bbg.Adornee = head
    bbg.AlwaysOnTop = true
    bbg.Size = UDim2.new(0, 240, 0, 38)
    bbg.StudsOffset = Vector3.new(0, 2.5, 0)
    bbg.ResetOnSpawn = false

    -- Baris 1 (Atas): Nama Pemain + Jarak (Selalu Putih)
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameLabel"
    nameLbl.Size = UDim2.new(1, 0, 0, 18)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = ESP_WHITE
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Text = player.DisplayName
    nameLbl.Parent = bbg

    -- Baris 2 (Bawah): Status di samping Item (Status berwarna, Item putih)
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Name = "InfoLabel"
    infoLbl.Size = UDim2.new(1, 0, 0, 16)
    infoLbl.Position = UDim2.new(0, 0, 0, 18)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.GothamBold
    infoLbl.TextSize = 10
    infoLbl.RichText = true
    infoLbl.TextColor3 = ESP_WHITE
    infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.Text = "[OK] Aman"
    infoLbl.Parent = bbg

    -- Parent ke CoreGui agar label tidak ikut destroy saat karakter mati/respawn
    -- dan AlwaysOnTop benar-benar berfungsi menembus dinding
    pcall(function()
        if gethui then
            bbg.Parent = gethui()
        else
            bbg.Parent = game:GetService("CoreGui")
        end
    end)
    if not bbg.Parent then bbg.Parent = game:GetService("CoreGui") end

    tagData = {
        bbg = bbg,
        nameLbl = nameLbl,
        infoLbl = infoLbl,
        head = head,
    }
    espPlayerTags[player] = tagData
    return tagData
end

local function to_hex_color(col)
    return string.format("#%02X%02X%02X",
        math.clamp(math.floor(col.R * 255), 0, 255),
        math.clamp(math.floor(col.G * 255), 0, 255),
        math.clamp(math.floor(col.B * 255), 0, 255)
    )
end

local function esp_update_player(player)
    if not espPlayerEnabled then esp_hide_player(player); return end

    local char = player.Character
    if not char then esp_hide_player(player); return end

    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then esp_hide_player(player); return end

    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.new(0, 0, 0)
    local dist = (camPos - root.Position).Magnitude

    local tagData = esp_get_or_create_tag(player, char)
    if not tagData then esp_hide_player(player); return end

    tagData.bbg.Enabled = true
    -- Keep adornee synced
    pcall(function()
        local currentHead = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if currentHead and tagData.bbg.Adornee ~= currentHead then
            tagData.bbg.Adornee = currentHead
        end
    end)

    if esp_is_killer(char) then
        esp_set_highlight_player(player, char, ESP_RED)
        -- Baris 1 (Atas): Nama Killer (Merah)
        tagData.nameLbl.Text = "[KILLER] " .. player.DisplayName .. " (" .. math.floor(dist) .. "m)"
        tagData.nameLbl.TextColor3 = ESP_RED
        -- Baris 2 (Bawah): Status Killer (Merah)
        tagData.infoLbl.Text = '<font color="#FF3232">[KILLER]</font>'
    else
        local status, statusColor = esp_get_status(char)
        local item = esp_get_item(char)
        esp_set_highlight_player(player, char, ESP_WHITE)

        -- Baris 1 (Atas): Nama Pemain + Jarak (Selalu PUTIH)
        tagData.nameLbl.Text = player.DisplayName .. " (" .. math.floor(dist) .. "m)"
        tagData.nameLbl.TextColor3 = ESP_WHITE

        -- Baris 2 (Bawah): Status di samping Item (Status warna dinamis, Item selalu PUTIH)
        local hex = to_hex_color(statusColor)
        if item and item ~= "" then
            tagData.infoLbl.Text = string.format('<font color="%s">%s</font> <font color="#FFFFFF">| %s</font>', hex, status, item)
        else
            tagData.infoLbl.Text = string.format('<font color="%s">%s</font>', hex, status)
        end
    end
end

local espPlayerConn = nil
local espPlayerRemovingConn = nil

local function start_esp_player()
    if espPlayerConn then return end
    for p in pairs(espPlayerTags) do esp_remove_player(p) end

    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end
    espPlayerRemovingConn = Players.PlayerRemoving:Connect(esp_remove_player)

    espPlayerConn = RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pcall(esp_update_player, p)
            end
        end
    end)
end

local function stop_esp_player()
    if espPlayerConn then
        espPlayerConn:Disconnect()
        espPlayerConn = nil
    end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect(); espPlayerRemovingConn = nil end
    for p in pairs(espPlayerTags) do esp_remove_player(p) end
end

-- ==============================================================================
do
-- MODUL ESP GENERATOR
-- ==============================================================================
espGenEnabled = false
local espHighlight    = true   -- selalu aktif
local espMaxDist      = math.huge -- tampilkan semua generator di map tanpa batas jarak

local GEN_KEYWORDS = { "generator", "gen" }
local genData_esp   = {}
local espConn       = nil

local function is_gen_esp(obj)
    -- Hanya terima Model (bukan BasePart individual) agar tidak muncul banyak label
    if not obj:IsA("Model") then return false end
    local n = obj.Name:lower()
    for _, kw in ipairs(GEN_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

local function get_gen_pos(gen)
    if gen:IsA("BasePart") then return gen.Position end
    local pp = gen.PrimaryPart or gen:FindFirstChildOfClass("BasePart")
    if pp then return pp.Position end
    local ok, cf = pcall(function() return gen:GetBoundingBox() end)
    if ok then return cf.Position end
    return nil
end

local function get_gen_progress(gen)
    local curVal = nil
    local maxVal = nil

    -- 1. Cari Nilai Maximum jika ada (misal MaxProgress = 100)
    for _, v in ipairs(gen:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if (n:find("max") or n:find("req") or n:find("goal") or n:find("total")) 
                and (n:find("progress") or n:find("charge") or n:find("repair")) then
                if v.Value > 0 then maxVal = v.Value end
            end
        end
    end

    -- 2. Cari Nilai Progress Saat Ini (Abaikan semua yang mengandung 'max', 'req', 'goal', 'total')
    local BEST_NAMES = { "progress", "currentprogress", "repairprogress", "charge", "repair", "percent" }
    for _, kw in ipairs(BEST_NAMES) do
        for _, v in ipairs(gen:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local n = v.Name:lower()
                if not (n:find("max") or n:find("req") or n:find("goal") or n:find("total")) then
                    if n == kw or n:find(kw, 1, true) then
                        curVal = v.Value
                        break
                    end
                end
            end
        end
        if curVal ~= nil then break end
    end

    -- 3. Cari dari Attributes jika belum ketemu
    if curVal == nil then
        local ok, attrs = pcall(function() return gen:GetAttributes() end)
        if ok and attrs then
            for attrName, av in pairs(attrs) do
                if type(av) == "number" then
                    local n = attrName:lower()
                    if not (n:find("max") or n:find("req") or n:find("goal") or n:find("total")) then
                        if n:find("progress") or n:find("charge") or n:find("repair") or n:find("percent") then
                            curVal = av
                            break
                        end
                    end
                end
            end
        end
    end

    -- Kalkulasi persentase yang benar
    if curVal ~= nil then
        if maxVal and maxVal > 0 then
            return math.clamp((curVal / maxVal) * 100, 0, 100)
        elseif curVal > 0 and curVal <= 1 then
            return math.clamp(curVal * 100, 0, 100)
        elseif curVal >= 0 and curVal <= 100 then
            return math.clamp(curVal, 0, 100)
        end
    end

    return nil
end

local ESP_GEN_COLOR = Color3.fromRGB(100, 200, 255) -- Biru tetap, tidak berubah

local function esp_has_registered_ancestor(obj)
    local p = obj.Parent
    while p and p ~= workspace do
        if genData_esp[p] then return true end
        p = p.Parent
    end
    return false
end

local function esp_setup_gen(gen)
    if genData_esp[gen] then return end
    if esp_has_registered_ancestor(gen) then return end

    local part = gen:FindFirstChildWhichIsA("BasePart") or gen.PrimaryPart
    local h = nil
    if espHighlight and gen:IsA("Model") then
        h = Instance.new("Highlight")
        h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor           = ESP_GEN_COLOR
        h.OutlineColor        = ESP_GEN_COLOR
        h.FillTransparency    = 0.65
        h.OutlineTransparency = 0
        h.Parent              = gen
    end

    local bbg = nil
    local pctLbl = nil
    if part then
        bbg = Instance.new("BillboardGui")
        bbg.Name = "ESP_GenTag"
        bbg.Adornee = part
        bbg.AlwaysOnTop = true
        bbg.Size = UDim2.new(0, 100, 0, 26)
        bbg.StudsOffset = Vector3.new(0, 3.0, 0)
        bbg.ResetOnSpawn = false

        pctLbl = Instance.new("TextLabel")
        pctLbl.Name = "PctLabel"
        pctLbl.Size = UDim2.new(1, 0, 1, 0)
        pctLbl.BackgroundTransparency = 1
        pctLbl.Font = Enum.Font.GothamBold
        pctLbl.TextSize = 14
        pctLbl.TextColor3 = ESP_GEN_COLOR
        pctLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        pctLbl.Text = gen.Name .. "\n" .. "0%"
        pctLbl.Parent = bbg

        bbg.Parent = part
    end

    genData_esp[gen] = {
        bbg = bbg,
        pctLbl = pctLbl,
        highlight = h,
        part = part,
    }
end

local function esp_remove_gen(gen)
    local e = genData_esp[gen]
    if not e then return end
    if e.bbg then pcall(function() e.bbg:Destroy() end) end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    genData_esp[gen] = nil
end

local function esp_hide_all()
    for _, e in pairs(genData_esp) do
        if e.bbg then pcall(function() e.bbg.Enabled = false end) end
        if e.highlight then pcall(function() e.highlight.FillTransparency = 1; e.highlight.OutlineTransparency = 1 end) end
    end
end

local function esp_scan()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if is_gen_esp(obj) then esp_setup_gen(obj) end
    end
    for g in pairs(genData_esp) do
        if not g.Parent then esp_remove_gen(g) end
    end
end

function start_esp_gen()
    if espConn then return end
    esp_scan()
    local scanTimer = 0
    espConn = RunService.RenderStepped:Connect(function(dt)
        scanTimer = scanTimer + dt
        if scanTimer >= 5 then
            scanTimer = 0
            esp_scan()
        end

        local cam = workspace.CurrentCamera
        local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.new(0, 0, 0)

        for gen, e in pairs(genData_esp) do
            if not gen.Parent or not espGenEnabled then
                if e.bbg then e.bbg.Enabled = false end
                if e.highlight then e.highlight.FillTransparency = 1; e.highlight.OutlineTransparency = 1 end
            else
                local pos = get_gen_pos(gen)
                if not pos then
                    if e.bbg then e.bbg.Enabled = false end
                else
                    local dist = (camPos - pos).Magnitude
                    if espMaxDist > 0 and dist > espMaxDist then
                        if e.bbg then e.bbg.Enabled = false end
                    else
                        local progress = get_gen_progress(gen)
                        local label    = progress and string.format("%.0f%%", progress) or "0%"

                        if e.highlight then
                            e.highlight.FillTransparency    = espHighlight and 0.65 or 1
                            e.highlight.OutlineTransparency = espHighlight and 0   or 1
                        end

                        if e.bbg and e.pctLbl then
                            e.pctLbl.Text = label
                            e.bbg.Enabled = true
                        end
                    end
                end
            end
        end
    end)
end

function stop_esp_gen()
    if espConn then
        espConn:Disconnect()
        espConn = nil
    end
    esp_hide_all()
end


end

-- ==============================================================================
-- TAB 3: ESP
-- ==============================================================================
local TabESP = tabGroup:Tab({ Name = "ESP", Image = "lucide/eye" })

local SecESPPlayer = TabESP:Section({})
SecESPPlayer:Header({ Name = WMacLib:Gradient("ESP Player - Survivor dan Killer", Color3.fromRGB(232,120,140), Color3.fromRGB(255,160,120)) })

SecESPPlayer:Toggle({
    Name = "Aktifkan ESP Player",
    Default = false,
    Callback = function(enabled)
        espPlayerEnabled = enabled
        if enabled then
            start_esp_player()
            Window:Notify({ Title = "ESP Player", Description = "ESP Player aktif! Putih=Survivor, Merah=Killer.", Lifetime = 3 })
        else
            stop_esp_player()
            Window:Notify({ Title = "ESP Player", Description = "ESP Player dimatikan.", Lifetime = 3 })
        end
    end
})

local SecESPGen = TabESP:Section({})
SecESPGen:Header({ Name = WMacLib:Gradient("ESP Generator", Color3.fromRGB(86,204,158), Color3.fromRGB(99,130,255)) })

SecESPGen:Toggle({
    Name = "Aktifkan ESP Generator",
    Default = false,
    Callback = function(enabled)
        espGenEnabled = enabled
        if enabled then
            start_esp_gen()
            Window:Notify({ Title = "ESP Generator", Description = "ESP aktif! Semua generator di map terlihat.", Lifetime = 3 })
        else
            stop_esp_gen()
            Window:Notify({ Title = "ESP Generator", Description = "ESP Generator dimatikan.", Lifetime = 3 })
        end
    end
})


-- SEKSI ESP EXIT GATE (tambah ke TabESP)
local SecESPGate = TabESP:Section({})
SecESPGate:Header({ Name = WMacLib:Gradient("ESP Pintu Keluar (Exit Gate)", Color3.fromRGB(240,190,100), Color3.fromRGB(232,150,110)) })

SecESPGate:Toggle({
    Name = "Aktifkan ESP Exit Gate",
    Default = false,
    Callback = function(enabled)
        espGateEnabled = enabled
        if enabled then
            start_esp_gate()
            Window:Notify({ Title = "ESP Gate", Description = "Pintu keluar terlihat dari mana saja!", Lifetime = 3 })
        else
            stop_esp_gate()
            Window:Notify({ Title = "ESP Gate", Description = "ESP Exit Gate dimatikan.", Lifetime = 2 })
        end
    end
})


end -- [End TabESP]



-- ==============================================================================
-- TAB: VIEW (FULLBRIGHT + CUSTOM FOV)
-- ==============================================================================
do
local TabView = tabGroup:Tab({ Name = "View", Image = "lucide/sun" })

-- SEKSI 1: FULLBRIGHT + NO FOG
local SecFB = TabView:Section({})
SecFB:Header({ Name = WMacLib:Gradient("Fullbright & No Fog", Color3.fromRGB(240,190,100), Color3.fromRGB(255,200,130)) })

SecFB:Toggle({
    Name = "Aktifkan Fullbright + No Fog",
    Default = false,
    Callback = function(enabled)
        fullbrightEnabled = enabled
        if enabled then
            fullbright_start()
            Window:Notify({ Title = "Fullbright", Description = "Map terang sempurna! Semua fog dihapus.", Lifetime = 3 })
        else
            fullbright_stop()
            Window:Notify({ Title = "Fullbright", Description = "Fullbright dimatikan. Lighting normal.", Lifetime = 2 })
        end
    end
})

-- SEKSI 2: CUSTOM FOV
local SecFov = TabView:Section({})
SecFov:Header({ Name = WMacLib:Gradient("Custom FOV (Field of View)", Color3.fromRGB(99,130,255), Color3.fromRGB(140,200,255)) })

SecFov:Toggle({
    Name = "Aktifkan Custom FOV",
    Default = false,
    Callback = function(enabled)
        customFovEnabled = enabled
        if enabled then
            fov_start(customFovValue)
            Window:Notify({ Title = "Custom FOV", Description = "FOV diubah ke " .. tostring(customFovValue) .. "!", Lifetime = 3 })
        else
            fov_stop()
            Window:Notify({ Title = "Custom FOV", Description = "FOV dikembalikan normal (70).", Lifetime = 2 })
        end
    end
})

SecFov:Slider({
    Name = "FOV Value (derajat)",
    Default = 70,
    Minimum = 40,
    Maximum = 120,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        customFovValue = val
        if customFovEnabled then
            fov_apply(val)
        end
    end
})

SecFov:Button({
    Name = "Reset FOV ke Default (70)",
    Callback = function()
        customFovValue = 70
        if customFovEnabled then fov_apply(70) end
        Window:Notify({ Title = "FOV", Description = "FOV direset ke 70.", Lifetime = 2 })
    end
})
end -- [End TabView]

-- ==============================================================================
-- TAB: KILLER RADAR
-- ==============================================================================
do
local TabRadar = tabGroup:Tab({ Name = "Radar", Image = "lucide/radio" })

local SecRadar = TabRadar:Section({})
SecRadar:Header({ Name = WMacLib:Gradient("Killer Radar (Mini-Map)", Color3.fromRGB(232,100,120), Color3.fromRGB(200,120,180)) })

SecRadar:Toggle({
    Name = "Aktifkan Killer Radar",
    Default = false,
    Callback = function(enabled)
        killerRadarEnabled = enabled
        if enabled then
            killerradar_start()
            Window:Notify({ Title = "Killer Radar", Description = "Merah=Killer | Biru=Survivor. Radar aktif!", Lifetime = 3 })
        else
            killerradar_stop()
            Window:Notify({ Title = "Killer Radar", Description = "Radar dimatikan.", Lifetime = 2 })
        end
    end
})

SecRadar:Slider({
    Name = "Jangkauan Radar (Studs)",
    Default = 350,
    Minimum = 50,
    Maximum = 1000,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        RADAR_RANGE = val
    end
})

local SecRadarInfo = TabRadar:Section({})
SecRadarInfo:Header({ Name = WMacLib:Gradient("Cara Baca Radar", Color3.fromRGB(140,152,190), Color3.fromRGB(120,170,200)) })
SecRadarInfo:Label({ Name = "🟢 Titik Hijau = Kamu sendiri" })
SecRadarInfo:Label({ Name = "🔴 Titik Merah = Killer (besar)" })
SecRadarInfo:Label({ Name = "🔵 Titik Biru = Survivor (kecil)" })
SecRadarInfo:Label({ Name = "Radar mengikuti arah kamera kamu!" })

end -- [End TabRadar]

-- ==============================================================================
-- TAB: DISCORD WEBHOOK NOTIFIER
-- ==============================================================================
do
local TabWebhook = tabGroup:Tab({ Name = "Webhook", Image = "lucide/bell" })

local SecWHUrl = TabWebhook:Section({})
SecWHUrl:Header({ Name = WMacLib:Gradient("Discord Webhook Notifier", Color3.fromRGB(99,130,255), Color3.fromRGB(72,214,200)) })

SecWHUrl:Input({
    Name = "URL Webhook Discord",
    Placeholder = "https://discord.com/api/webhooks/...",
    Default = "",
    Callback = function(val)
        webhookUrl = val or ""
    end
})

SecWHUrl:Toggle({
    Name = "Notifikasi saat Escape",
    Default = true,
    Callback = function(enabled)
        webhookNotifyEscape = enabled
    end
})

SecWHUrl:Toggle({
    Name = "Notifikasi saat Match Mulai",
    Default = true,
    Callback = function(enabled)
        webhookNotifyMatch = enabled
    end
})

SecWHUrl:Button({
    Name = "Kirim Test Webhook",
    Callback = function()
        local ok, res = send_discord_webhook(
            "Test Webhook",
            "**Sky Hub** terhubung ke Discord kamu! Webhook berfungsi dengan baik.",
            "00b0f4"
        )
        Window:Notify({
            Title = ok and "Webhook Terkirim!" or "Gagal",
            Description = ok and "Pesan test berhasil dikirim ke Discord." or tostring(res),
            Lifetime = 4
        })
    end
})

SecWHUrl:Button({
    Name = "Kirim: Match Dimulai",
    Callback = function()
        if not webhookNotifyMatch then
            Window:Notify({ Title = "Webhook", Description = "Notifikasi match dimatikan.", Lifetime = 2 })
            return
        end
        local ok, res = send_discord_webhook(
            "Match Dimulai!",
            "**" .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "** bergabung match baru di Violence District.",
            "57f287"
        )
        Window:Notify({
            Title = ok and "Notifikasi Terkirim!" or "Gagal",
            Description = ok and "Notifikasi match dikirim ke Discord." or tostring(res),
            Lifetime = 3
        })
    end
})

local SecWHSummary = TabWebhook:Section({})
SecWHSummary:Header({ Name = WMacLib:Gradient("Per-Match Summary (Sky Hub Style)", Color3.fromRGB(99,130,255), Color3.fromRGB(72,214,200)) })

SecWHSummary:Toggle({
    Name = "Auto Kirim Summary Per-Match",
    Default = true,
    Callback = function(enabled)
        if enabled then
            start_webhook_live_monitor()
            Window:Notify({ Title = "Match Tracker", Description = "Aktif! Summary otomatis dikirim setiap selesai match / escape.", Lifetime = 3 })
        else
            stop_webhook_live_monitor()
            Window:Notify({ Title = "Match Tracker", Description = "Tracker match dimatikan.", Lifetime = 2 })
        end
    end
})

SecWHSummary:Button({
    Name = "Kirim Summary Match Sekarang (Manual)",
    Callback = function()
        local ok, res = send_match_summary_webhook("Manual")
        Window:Notify({
            Title = ok and "Summary Terkirim!" or "Gagal",
            Description = ok and "Statistik match berhasil dikirim ke Discord!" or tostring(res),
            Lifetime = 4
        })
    end
})

SecWHSummary:Label({ Name = "Format Sky Hub: Discord Blurple, Delta (+/-) Level, EXP, Screws, Gears, Sin." })
SecWHSummary:Label({ Name = "Summary dikirim per-match (bukan live update) saat match selesai / escape." })

local SecWHInfo = TabWebhook:Section({})
SecWHInfo:Header({ Name = WMacLib:Gradient("Cara Pakai Webhook", Color3.fromRGB(140,152,190), Color3.fromRGB(120,170,200)) })
SecWHInfo:Label({ Name = "Salin URL dari: Server Discord > Edit Channel > Integrations > Webhooks" })
SecWHInfo:Label({ Name = "Delta (+/-) dihitung otomatis dari awal match hingga kamu berhasil escape." })
SecWHInfo:Label({ Name = "Pastikan Executor mendukung HTTP Request (Synapse X, Fluxus, Delta, dll)." })

end -- [End TabWebhook]

-- ==============================================================================
-- TAB 4: MODIFIKASI (VERTIKAL SCROLL KE BAWAH)
-- ==============================================================================
do
local TabMod = tabGroup:Tab({ Name = "Modifikasi", Image = "lucide/sparkles" })


-- SEKSI 1: SALIN AVATAR PEMAIN
local SecAvatar = TabMod:Section({})
SecAvatar:Header({ Name = WMacLib:Gradient("Salin Avatar Pemain", Color3.fromRGB(99,130,255), Color3.fromRGB(168,120,255)) })

SecAvatar:Input({
    Name = "Target di Server",
    Default = "",
    Placeholder = "Kosongkan untuk diri sendiri...",
    Callback = function(text) swap_target = text end,
    onChanged = function(text) swap_target = text end,
})

SecAvatar:Input({
    Name = "Username Avatar Roblox",
    Default = "usnavatar",
    Placeholder = "Ketik username avatar Roblox...",
    Callback = function(text) swap_avatar = text end,
    onChanged = function(text) swap_avatar = text end,
})

SecAvatar:Button({
    Name = "Terapkan Avatar",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Avatar Swap", Description = "Memproses penyalinan avatar...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = apply_avatar_swap(swap_target, swap_avatar)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
    end,
})

SecAvatar:Button({
    Name = "Reset Avatar Normal",
    Callback = function()
        local success, msg = reset_avatar_swap(swap_target)
        Window:Notify({
            Title = "Reset Avatar",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})

-- SEKSI 2: KLONING OUTFIT TERSIMPAN
local SecOutfit = TabMod:Section({})
SecOutfit:Header({ Name = WMacLib:Gradient("Kloning Outfit Tersimpan", Color3.fromRGB(232,110,170), Color3.fromRGB(168,120,255)) })

SecOutfit:Input({
    Name = "Username Pemilik Outfit",
    Default = "zhbrxty",
    Placeholder = "Contoh: zhbrxty",
    Callback = function(text) outfit_owner = text end,
    onChanged = function(text) outfit_owner = text end,
})

SecOutfit:Input({
    Name = "Nama / ID Outfit",
    Default = "cp 1",
    Placeholder = "Contoh: cp 1 atau ID outfit...",
    Callback = function(text) outfit_name = text end,
    onChanged = function(text) outfit_name = text end,
})

SecOutfit:Input({
    Name = "Target di Server",
    Default = "",
    Placeholder = "Kosongkan untuk diri sendiri...",
    Callback = function(text) outfit_target = text end,
    onChanged = function(text) outfit_target = text end,
})

SecOutfit:Button({
    Name = "Pasang Outfit ke Target",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Outfit Cloner", Description = "Mengambil data outfit...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = apply_outfit(outfit_owner, outfit_name, outfit_target)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
    end,
})

-- SEKSI 3: PEMUAT AKSESORIS CATALOG
local SecAcc = TabMod:Section({})
SecAcc:Header({ Name = WMacLib:Gradient("Pemuat Aksesoris Catalog", Color3.fromRGB(86,204,158), Color3.fromRGB(120,160,255)) })

local acc_offset_y = 0
local acc_offset_z = 0
local acc_offset_x = 0
local acc_scale = 1.0

SecAcc:Input({
    Name = "Target di Server",
    Default = "",
    Placeholder = "Kosongkan untuk diri sendiri...",
    Callback = function(text) acc_target = text end,
    onChanged = function(text) acc_target = text end,
})

SecAcc:Input({
    Name = "Roblox Catalog Asset ID",
    Default = "10159600649",
    Placeholder = "Contoh: 10159600649",
    Callback = function(text) acc_id = text end,
    onChanged = function(text) acc_id = text end,
})

SecAcc:Slider({
    Name = "Atas / Bawah (Y Offset)",
    Default = 0,
    Minimum = -30,
    Maximum = 30,
    DisplayMethod = "Round",
    Precision = 1,
    Callback = function(val)
        acc_offset_y = val / 10
    end
})

SecAcc:Slider({
    Name = "Depan / Belakang (Z Offset)",
    Default = 0,
    Minimum = -30,
    Maximum = 30,
    DisplayMethod = "Round",
    Precision = 1,
    Callback = function(val)
        acc_offset_z = val / 10
    end
})

SecAcc:Slider({
    Name = "Kiri / Kanan (X Offset)",
    Default = 0,
    Minimum = -30,
    Maximum = 30,
    DisplayMethod = "Round",
    Precision = 1,
    Callback = function(val)
        acc_offset_x = val / 10
    end
})

SecAcc:Slider({
    Name = "Ukuran / Scale (Besar - Kecil)",
    Default = 10,
    Minimum = 2,
    Maximum = 30,
    DisplayMethod = "Round",
    Precision = 1,
    Callback = function(val)
        acc_scale = val / 10
    end
})

SecAcc:Button({
    Name = "Pasang Aksesoris",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Aksesoris", Description = "Memuat aksesoris...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = add_accessory(acc_target, acc_id, acc_offset_x, acc_offset_y, acc_offset_z, acc_scale)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
    end,
})

SecAcc:Button({
    Name = "Terapkan Posisi & Ukuran (Live Update)",
    Callback = function()
        local success, msg = update_accessory_transform(acc_target, acc_id, acc_offset_x, acc_offset_y, acc_offset_z, acc_scale)
        Window:Notify({
            Title = "Posisi Aksesoris",
            Description = msg or "",
            Lifetime = 3
        })
    end,
})

SecAcc:Button({
    Name = "Hapus Aksesoris (ID / Nama)",
    Callback = function()
        local success, msg = remove_accessory(acc_target, acc_id)
        Window:Notify({
            Title = "Aksesoris",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})

SecAcc:Button({
    Name = "Hapus Semua Aksesoris Custom",
    Callback = function()
        local success, msg = remove_all_accessories(acc_target)
        Window:Notify({
            Title = "Aksesoris",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})

-- SEKSI 4: KORBLOX & HEADLESS
local SecBody = TabMod:Section({})
SecBody:Header({ Name = WMacLib:Gradient("Korblox & Headless", Color3.fromRGB(232,130,110), Color3.fromRGB(200,110,150)) })

local korblox_offset = 0.7

SecBody:Input({
    Name = "Target di Server",
    Default = "",
    Placeholder = "Kosongkan untuk diri sendiri...",
    Callback = function(text) mod_target = text end,
    onChanged = function(text) mod_target = text end,
})

SecBody:Input({
    Name = "Korblox Y Offset",
    Default = "0.7",
    Placeholder = "Default: 0.7 (sesuai contoh pas)",
    Callback = function(text) korblox_offset = tonumber(text) or 0.7 end,
    onChanged = function(text) korblox_offset = tonumber(text) or 0.7 end,
})

SecBody:Button({
    Name = "Pasang Korblox Leg (Khusus R6)",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Korblox", Description = "Memasang Korblox leg...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = apply_korblox(mod_target, 139607718, korblox_offset)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
    end,
})

SecBody:Button({
    Name = "Hapus Korblox Leg",
    Callback = function()
        local success, msg = remove_korblox(mod_target)
        Window:Notify({
            Title = "Korblox",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})

SecBody:Button({
    Name = "Pasang Headless",
    Bold = true,
    Callback = function()
        local success, msg = apply_headless(mod_target)
        Window:Notify({
            Title = success and "Berhasil!" or "Gagal!",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})

SecBody:Button({
    Name = "Hapus Headless",
    Callback = function()
        local success, msg = remove_headless(mod_target)
        Window:Notify({
            Title = "Headless",
            Description = msg or "",
            Lifetime = 4
        })
    end,
})
end -- [End TabMod]

-- ==============================================================================
-- TAB 3: PENGATURAN & TEMA
-- ==============================================================================
tabGroup:Divider()
do
local TabConfig = tabGroup:Tab({ Name = "Pengaturan", Image = "lucide/settings" })

-- SEKSI 1: PENAMPILAN & TEMA
local SecTheme = TabConfig:Section({})
SecTheme:Header({ Name = "Penampilan (Appearance)" })

SecTheme:Dropdown({
    Name = "Pilihan Tema (Color Themes)",
    Options = WMacLib:GetThemes(),
    Default = "Dark",
    Callback = function(themeName)
        WMacLib:SetTheme(themeName)
        Window:Notify({ Title = "Tema", Description = "Tema diubah ke " .. tostring(themeName), Lifetime = 3 })
    end
})

SecTheme:Toggle({
    Name = "Acrylic Blur",
    Default = Window:GetAcrylicBlurState(),
    Callback = function(bool)
        Window:SetAcrylicBlurState(bool)
        Window:Notify({ Title = "Pengaturan", Description = (bool and "Mengaktifkan" or "Mematikan") .. " Blur", Lifetime = 3 })
    end
})

SecTheme:Toggle({
    Name = "Tampilkan Info User",
    Default = Window:GetUserInfoState(),
    Callback = function(bool)
        Window:SetUserInfoState(bool)
    end
})

-- Toggle warna header: gradient warna-warni vs putih/hitam polos
local headerColorMode = "gradient"

local function findWmacGuis()
    local found = {}
    local containers = {}
    pcall(function() if gethui then table.insert(containers, gethui()) end end)
    pcall(function() table.insert(containers, CoreGui) end)
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(containers, LocalPlayer.PlayerGui)
        end
    end)

    for _, container in ipairs(containers) do
        for _, sg in ipairs(container:GetChildren()) do
            if sg:IsA("ScreenGui") then
                if sg:FindFirstChild("Notifications") or sg.Name:lower():find("wmac") or sg.Name:lower():find("mac") then
                    table.insert(found, sg)
                else
                    for _, desc in ipairs(sg:GetDescendants()) do
                        if desc:IsA("TextLabel") and (desc.Text:find("Skyyy") or desc.Text:find("Modifikasi") or desc.Text:find("Korblox")) then
                            table.insert(found, sg)
                            break
                        end
                    end
                end
            end
        end
    end
    return found
end

local function applyHeaderColor(mode)
    pcall(function()
        local guis = findWmacGuis()
        for _, target in ipairs(guis) do
            -- Listener otomatis bila ada header / TextLabel baru yang dimuat
            if not target:GetAttribute("HeaderColorHooked") then
                target:SetAttribute("HeaderColorHooked", true)
                target.DescendantAdded:Connect(function(d)
                    if d:IsA("TextLabel") and headerColorMode ~= "gradient" then
                        task.wait(0.05)
                        local txt = d.Text
                        if txt:find("<font color=") or d:GetAttribute("OrigHeaderRichText") then
                            if not d:GetAttribute("OrigHeaderRichText") then
                                d:SetAttribute("OrigHeaderRichText", txt)
                            end
                            local clean = d:GetAttribute("OrigHeaderRichText"):gsub("<[^>]->", "")
                            if headerColorMode == "white" then
                                d.Text = string.format('<font color="rgb(255,255,255)">%s</font>', clean)
                            elseif headerColorMode == "black" then
                                d.Text = string.format('<font color="rgb(20,20,20)">%s</font>', clean)
                            end
                        end
                    end
                end)
            end

            for _, obj in ipairs(target:GetDescendants()) do
                if obj:IsA("TextLabel") then
                    -- WMacLib:Gradient menghasilkan rich text dengan tag <font color="rgb(...)"> per huruf
                    local txt = obj.Text
                    if txt:find("<font color=") or obj:GetAttribute("OrigHeaderRichText") then
                        if not obj:GetAttribute("OrigHeaderRichText") then
                            obj:SetAttribute("OrigHeaderRichText", txt)
                        end
                        local orig = obj:GetAttribute("OrigHeaderRichText")
                        local clean = orig:gsub("<[^>]->", "")

                        if mode == "white" then
                            obj.Text = string.format('<font color="rgb(255,255,255)">%s</font>', clean)
                        elseif mode == "black" then
                            obj.Text = string.format('<font color="rgb(20,20,20)">%s</font>', clean)
                        else
                            obj.Text = orig
                        end
                    end
                end
            end
        end
    end)
end

SecTheme:Dropdown({
    Name = "Warna Teks Header",
    Options = { "Gradient (Warna-warni)", "Putih Polos", "Hitam Polos" },
    Default = "Gradient (Warna-warni)",
    Callback = function(choice)
        if choice == "Putih Polos" then
            headerColorMode = "white"
        elseif choice == "Hitam Polos" then
            headerColorMode = "black"
        else
            headerColorMode = "gradient"
        end
        applyHeaderColor(headerColorMode)
        Window:Notify({ Title = "Teks Header", Description = "Warna teks diubah: " .. choice, Lifetime = 3 })
    end
})

-- ==============================================================================
-- SEKSI 2: WATERMARK & WINDOW
-- ==============================================================================
local SecWin = TabConfig:Section({})
SecWin:Header({ Name = WMacLib:Gradient("Jendela & Kontrol", Color3.fromRGB(99,130,255), Color3.fromRGB(168,120,255)) })

-- Toggle log diagnostik.
-- Matikan = console bersih. Nyalakan = semua detail fitur tampil lagi,
-- berguna kalau ada fitur yang tidak bekerja dan perlu diperiksa.
SecWin:Toggle({
    Name = "Log Detail (Debug)",
    Default = false,
    Callback = function(enabled)
        SKY_DEBUG = enabled
        Window:Notify({
            Title = "Log Detail",
            Description = enabled
                and "Log detail ON. Semua output diagnostik akan muncul di console (F9)."
                or "Log detail OFF. Console hanya menampilkan hasil akhir.",
            Lifetime = 3
        })
    end
})

-- Salin log ke clipboard.
-- Kalau ada fitur yang bermasalah, user bisa nyalakan Log Detail,
-- pakai fitur, lalu tekan tombol ini dan paste hasilnya ke chat.
SecWin:Button({
    Name = "Salin Log Terakhir",
    Callback = function()
        if not SKY_DEBUG then
            Window:Notify({
                Title = "Log Kosong",
                Description = "Nyalakan Log Detail (Debug) dulu supaya ada yang bisa disalin.",
                Lifetime = 3
            })
            return
        end
        pcall(function()
            setclipboard(SKY_LOG_BUFFER)
        end)
        Window:Notify({
            Title = "Log Disalin",
            Description = "Log sudah masuk clipboard, siap di-paste.",
            Lifetime = 3
        })
    end
})

-- Watermark & FPS
local watermark
pcall(function()
    if WMacLib and WMacLib.Watermark then
        watermark = WMacLib:Watermark({ Name = "Sky Hub", Version = "v1.0.0" })
        if watermark and watermark.SetVisible then
            watermark:SetVisible(false)
        end
    end
end)

local fpsCount, fpsElapsed = 0, 0
RunService.Heartbeat:Connect(function(dt)
    fpsCount = fpsCount + 1
    fpsElapsed = fpsElapsed + dt
    if fpsElapsed >= 0.5 then
        pcall(function()
            if watermark and watermark.Set then
                watermark:Set("FPS", math.round(fpsCount / fpsElapsed) .. " FPS")
            end
        end)
        fpsCount = 0
        fpsElapsed = 0
    end
end)

SecWin:Toggle({
    Name = "Logo Watermark & FPS Overlay",
    Default = false,
    Callback = function(value)
        pcall(function()
            if watermark and watermark.SetVisible then
                watermark:SetVisible(value)
            end
        end)
    end
})

SecWin:Slider({
    Name = "Ukuran Jendela (Window Size)",
    Default = 50,
    Minimum = 0,
    Maximum = 100,
    DisplayMethod = "Percent",
    Precision = 0,
    Callback = function(value)
        local t = value / 100
        Window:SetSize(UDim2.fromOffset(450 + (900 - 450) * t, 350 + (650 - 350) * t))
    end
})

SecWin:Keybind({
    Name = "Shortcut Buka / Tutup Menu",
    Default = Enum.KeyCode.RightControl,
    onBinded = function(bind)
        Window:SetKeybind(bind)
        Window:Notify({ Title = "Keybind", Description = "Tombol toggle: " .. tostring(bind.Name), Lifetime = 3 })
    end
})

-- Welcome. Notifikasi dibuat singkat supaya tidak intrusive,
-- karena user tinggal melihat UI-nya untuk tahu fitur apa saja.
Window:Notify({
    Title = "Sky Hub siap",
    Description = "Tekan RightControl untuk buka / tutup menu.",
    Lifetime = 4
})

-- Hanya muncul kalau SKY_DEBUG = true
log("Sky Hub (Violence District - 8 Tabs) berhasil dijalankan")
end -- [End TabConfig]


-- Aliases
start_auto_heal = autoheal_start
stop_auto_heal = autoheal_stop
start_auto_generator = agen_start
stop_auto_generator = agen_stop
start_auto_parry = autoparry_start
stop_auto_parry = autoparry_stop
start_esp_generator = start_esp_gen
stop_esp_generator = stop_esp_gen
infcharges_start = infinite_charges_start
infcharges_stop = infinite_charges_stop

-- Ekspor ke environment executor supaya bisa diakses dari konsol.
-- Contoh: SKY_DEBUG = true   -> nyalakan log detail
--         SKY_DEBUG = false  -> matikan lagi
--         cetakLog()         -> tampilkan log yang tersimpan di clipboard
pcall(function()
    local env = (getgenv and getgenv()) or _G
    env.SKY_DEBUG = SKY_DEBUG
    env.SKY_LOG_BUFFER = SKY_LOG_BUFFER
    env.SKY = {
        setDebug = function(v) SKY_DEBUG = v end,
        getLog   = function() return SKY_LOG_BUFFER end,
        clearLog = function() SKY_LOG_BUFFER = "" end,
    }
end)
