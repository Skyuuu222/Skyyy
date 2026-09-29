-- ==============================================================================
-- UNIVERSAL AVATAR & OUTFIT STUDIO HUB (POWERED BY WMACLIB)
-- Modern MacOS-style UI with Acrylic Blur, Tabs & Animations
-- ==============================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

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

local function cleanup_swap(player)
    local st = SwapState.targets[player]
    if not st then return end
    reset_swap_state(st)
    if st.respawnConn then pcall(function() st.respawnConn:Disconnect() end) end
    SwapState.targets[player] = nil
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
        if part:IsA("BasePart") then
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

    table.insert(st.conns, RunService.Stepped:Connect(function()
        for _, part in ipairs(copyParts) do
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end))

    table.insert(st.conns, RunService.RenderStepped:Connect(function()
        if not hrp.Parent then return end
        local root = hrp.CFrame
        local inv = root:Inverse()
        local lift = CFrame.new(0, heightDiff, 0)
        for _, p in ipairs(mapped) do
            p[2].CFrame = root * lift * (inv * p[1].CFrame)
        end
    end))

    local function hide(d)
        if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart")
            or d:IsA("Decal") or d:IsA("Texture") then
            if st.original[d] == nil then st.original[d] = d.Transparency end
            d.Transparency = 1
        end
    end
    for _, d in ipairs(char:GetDescendants()) do hide(d) end
    table.insert(st.conns, char.DescendantAdded:Connect(hide))

    st.model = model
    return true, "Avatar berhasil dipasang pada " .. player.Name
end

local function apply_avatar_swap(targetName, avatarUsername)
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

local function reset_avatar_swap(targetName)
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

local function apply_outfit(username, outfitQuery, targetName)
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
local function add_accessory(targetName, assetId)
    local target = find_player(targetName)
    if not target then return false, "Pemain tidak ditemukan" end

    local char = target.Character
    if not char then return false, "Karakter tidak ada" end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head then return false, "Humanoid/Head tidak ada" end

    local cleanId = tostring(assetId):match("%d+")
    if not cleanId then return false, "Asset ID tidak valid" end

    local okLoad, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. cleanId)
    end)
    if not okLoad or not objects or #objects == 0 then
        return false, "Gagal memuat aset aksesoris"
    end

    local model = objects[1]
    local accessory = model:IsA("Accessory") and model or model:FindFirstChildOfClass("Accessory")
    if not accessory then return false, "Bukan objek Accessory" end

    local handle = accessory:FindFirstChild("Handle")
    local accAttachment = handle and handle:FindFirstChildOfClass("Attachment")
    if not handle or not accAttachment then return false, "Struktur Handle/Attachment rusak" end

    local headAttachment = head:FindFirstChild(accAttachment.Name) or head:FindFirstChild("HatAttachment")
    accessory.Parent = char

    local weld = Instance.new("Weld")
    weld.Name = "AccessoryWeld"
    weld.Part0 = head
    weld.Part1 = handle
    weld.C0 = headAttachment and headAttachment.CFrame or CFrame.new(0, 0.5, 0)
    weld.C1 = accAttachment.CFrame
    weld.Parent = handle

    return true, "Aksesoris '" .. accessory.Name .. "' dipasang ke " .. target.Name
end

-- ==============================================================================
-- MODUL 4: KORBLOX & HEADLESS MODIFICATIONS
-- ==============================================================================
local function apply_korblox(targetName, assetId, yOffset)
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

    local originalJoint = torso:FindFirstChild("Right Hip")
    if not originalJoint then return false, "Joint 'Right Hip' tidak ditemukan" end

    local cleanId = tostring(assetId or "139607718"):match("%d+")
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

    local originalC0 = originalJoint.C0
    local offsetVal = tonumber(yOffset) or 0.7

    newLimb.CFrame = oldLimb.CFrame * CFrame.new(0, offsetVal, 0)
    newLimb.Name = "Right Leg Korblox"
    newLimb.CanCollide = false
    newLimb.Massless = true
    newLimb.Parent = char

    oldLimb.Transparency = 1
    oldLimb.CanCollide = false
    originalJoint.Part1 = nil

    local weld = Instance.new("Motor6D")
    weld.Name = "Right Hip"
    weld.Part0 = torso
    weld.Part1 = newLimb
    weld.C0 = originalC0
    weld.C1 = newLimb.CFrame:ToObjectSpace(torso.CFrame * originalC0)
    weld.Parent = torso

    return true, "Korblox Right Leg dipasang pada " .. target.Name
end

shared.HeadlessConns = shared.HeadlessConns or {}
local function make_headless_char(char)
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
        end
    end
end

local function apply_headless(targetName)
    local target = find_player(targetName)
    if not target then return false, "Target tidak ditemukan" end

    if shared.HeadlessConns[target] then
        shared.HeadlessConns[target]:Disconnect()
        shared.HeadlessConns[target] = nil
    end

    local function setup(char)
        make_headless_char(char)
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not char.Parent then conn:Disconnect(); return end
            local h = char:FindFirstChild("Head")
            if h and h.Transparency ~= 1 then make_headless_char(char) end
        end)
    end

    if target.Character then setup(target.Character) end
    shared.HeadlessConns[target] = target.CharacterAdded:Connect(setup)

    return true, "Headless diterapkan pada " .. target.Name
end

local function remove_headless(targetName)
    local target = find_player(targetName)
    if not target then return false, "Target tidak ditemukan" end

    if shared.HeadlessConns[target] then
        shared.HeadlessConns[target]:Disconnect()
        shared.HeadlessConns[target] = nil
    end

    if target.Character and target.Character:FindFirstChild("Head") then
        local head = target.Character.Head
        head.Transparency = 0
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
        end
    end
    return true, "Headless dinonaktifkan untuk " .. target.Name
end

-- ==============================================================================
-- WMACLIB UI INITIALIZATION
-- ==============================================================================
local WMacLib = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Wicikk/WMacLib/main/WMacLib.lua"))()

local Window = WMacLib:Window({
    Title = "Sky Hub",
    Subtitle = "Universal Studio",
    Size = UDim2.fromOffset(780, 480),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
    Theme = "Dark",
})

local tabGroup = Window:TabGroup()

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
-- TAB TUNGGAL: MODIFIKASI (ALL-IN-ONE)
-- ==============================================================================
local TabMod = tabGroup:Tab({ Name = "Modifikasi", Image = "lucide/sparkles" })

-- SISI KIRI: AVATAR & OUTFIT
local SecAvatar = TabMod:Section({ Side = "Left" })
SecAvatar:Header({ Name = WMacLib:Gradient("Salin Avatar Pemain", Color3.fromRGB(70, 150, 255), Color3.fromRGB(160, 100, 255)) })

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

local SecOutfit = TabMod:Section({ Side = "Left" })
SecOutfit:Header({ Name = WMacLib:Gradient("Kloning Outfit Tersimpan", Color3.fromRGB(240, 100, 200), Color3.fromRGB(150, 80, 255)) })

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

-- SISI KANAN: AKSESORIS & TUBUH (KORBLOX / HEADLESS)
local SecAcc = TabMod:Section({ Side = "Right" })
SecAcc:Header({ Name = WMacLib:Gradient("Pemuat Aksesoris Catalog", Color3.fromRGB(50, 220, 150), Color3.fromRGB(70, 180, 255)) })

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

SecAcc:Button({
    Name = "Pasang Aksesoris",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Aksesoris", Description = "Memuat aksesoris...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = add_accessory(acc_target, acc_id)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
    end,
})

local SecBody = TabMod:Section({ Side = "Right" })
SecBody:Header({ Name = WMacLib:Gradient("Korblox & Headless", Color3.fromRGB(255, 120, 70), Color3.fromRGB(255, 70, 100)) })

SecBody:Input({
    Name = "Target di Server",
    Default = "",
    Placeholder = "Kosongkan untuk diri sendiri...",
    Callback = function(text) mod_target = text end,
    onChanged = function(text) mod_target = text end,
})

SecBody:Button({
    Name = "Pasang Korblox Leg (Khusus R6)",
    Bold = true,
    Callback = function()
        Window:Notify({ Title = "Korblox", Description = "Memasang Korblox leg...", Lifetime = 3 })
        task.spawn(function()
            local success, msg = apply_korblox(mod_target, 139607718, 0.7)
            Window:Notify({
                Title = success and "Berhasil!" or "Gagal!",
                Description = msg or "",
                Lifetime = 4
            })
        end)
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

-- ==============================================================================
-- TAB PENGATURAN & TEMA
-- ==============================================================================
tabGroup:Divider()
local TabConfig = tabGroup:Tab({ Name = "Pengaturan", Image = "lucide/settings" })
local SecConfig = TabConfig:Section({ Side = "Left" })

SecConfig:Header({ Name = "Pengaturan UI" })

SecConfig:Toggle({
    Name = "Acrylic Blur",
    Default = Window:GetAcrylicBlurState(),
    Callback = function(bool)
        Window:SetAcrylicBlurState(bool)
        Window:Notify({ Title = "Pengaturan", Description = (bool and "Mengaktifkan" or "Mematikan") .. " Blur", Lifetime = 3 })
    end
})

SecConfig:Toggle({
    Name = "Tampilkan Info User",
    Default = Window:GetUserInfoState(),
    Callback = function(bool)
        Window:SetUserInfoState(bool)
    end
})

Window:Notify({
    Title = "Sky Hub",
    Description = "Semua fitur telah disatukan di tab Modifikasi!",
    Lifetime = 5
})

print("[OK] Sky Hub (Modifikasi All-in-One) berhasil dijalankan!")
