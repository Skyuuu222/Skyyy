-- ==============================================================================
-- UNIVERSAL AVATAR & OUTFIT STUDIO HUB (POWERED BY WMACLIB)
-- Modern MacOS-style UI with Acrylic Blur, Tabs & Animations
-- ==============================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function add_accessory(targetName, assetId, offX, offY, offZ, scaleVal)
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

local function update_accessory_transform(targetName, assetId, offX, offY, offZ, scaleVal)
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

local function remove_accessory(targetName, assetId)
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

local function remove_all_accessories(targetName)
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

local function remove_korblox(targetName)
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

local function apply_headless(targetName)
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

local function remove_headless(targetName)
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





-- ==============================================================================
-- WMACLIB UI INITIALIZATION
-- ==============================================================================
-- Snapshot ScreenGui yang ada sebelum WMacLib dibuat
local _preExistingGuis = {}
for _, sg in ipairs(CoreGui:GetChildren()) do
    if sg:IsA("ScreenGui") then _preExistingGuis[sg] = true end
end
pcall(function()
    if gethui then
        for _, sg in ipairs(gethui():GetChildren()) do
            if sg:IsA("ScreenGui") then _preExistingGuis[sg] = true end
        end
    end
end)

local ok_wm, WMacLib = pcall(function()
    local src = game:HttpGet("https://raw.githubusercontent.com/Wicikk/WMacLib/main/WMacLib.lua")
    -- [FIX DRAGGING BUG] WMacLib asli menimpa dragInput dengan MouseMovement, sehingga input == dragInput gagal saat MouseButton1 dilepas.
    -- Patch ini menjamin dragging_ langsung false begitu MouseButton1 / Touch dilepas pada Window maupun Slider!
    src = src:gsub(
        "if input == dragInput then",
        "if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then"
    )
    return loadstring(src)()
end)
if not ok_wm or not WMacLib then
    warn("[Sky Hub] Gagal memuat WMacLib: " .. tostring(WMacLib))
    return
end

local Window = WMacLib:Window({
    Title = "Skyyy",
    Subtitle = "Sky anak baik",
    Size = UDim2.fromOffset(560, 430),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
    Theme = "Dark",
})

local tabGroup = Window:TabGroup()

-- Cari ScreenGui yang dibuat oleh WMacLib (yang tidak ada di snapshot sebelumnya)
local wmacGui = nil
task.wait() -- tunggu satu frame agar WMacLib selesai setup GUI-nya
local function findWmacGui()
    -- Cari di CoreGui
    for _, sg in ipairs(CoreGui:GetChildren()) do
        if sg:IsA("ScreenGui") and not _preExistingGuis[sg] then
            wmacGui = sg
            return
        end
    end
    -- Cari di gethui() jika executor mendukung
    pcall(function()
        if gethui then
            for _, sg in ipairs(gethui():GetChildren()) do
                if sg:IsA("ScreenGui") and not _preExistingGuis[sg] then
                    wmacGui = sg
                end
            end
        end
    end)
end
findWmacGui()
-- Fallback: coba lagi setelah 1 detik jika masih belum ketemu
if not wmacGui then
    task.delay(1, findWmacGui)
end

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
-- MODUL AUTO PERFECT GENERATOR (SKILL CHECK AUTOMATION)
-- ==============================================================================
local PlayerGui       = LocalPlayer:WaitForChild("PlayerGui")

local autoGenEnabled  = false
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
        end
        return
    end

    local currentRot = lineObj.Rotation
    local goalRot    = goalObj.Rotation % 360
    if goalRot < 0 then goalRot = goalRot + 360 end

    -- DUKUNGAN KHUSUS KING'S SCOURGE (RAPID-FIRE CHECKS):
    -- 1. Deteksi perpindahan Goal sudut (> 3°) -> ronde baru King's Scourge langsung siap
    if lastGoalRotation ~= nil then
        local goalDiff = math.abs((goalRot - lastGoalRotation + 180) % 360 - 180)
        if goalDiff > 3 then
            hasHitCurrentMinigame = false
            lineMoveCount         = 1
            lastGoalRotation      = goalRot
        end
    else
        lastGoalRotation = goalRot
    end

    -- 2. Auto Re-Arm setelah 0.15 detik jika jarum sudah bergerak keluar dari zona hit sebelumnya
    if hasHitCurrentMinigame and (tick() - lastHitTick > 0.15) then
        local distPast = (currentRot - (goalRot + 109.0)) % 360
        if distPast > 12 and distPast < 340 then
            hasHitCurrentMinigame = false
        end
    end

    -- Minigame baru muncul
    if not isMinigameActive then
        isMinigameActive      = true
        hasHitCurrentMinigame = false
        lastLineRotation      = lineObj.Rotation
        lastGoalRotation      = goalRot
        lineMoveCount         = 0
        return
    end

    -- Hitung kecepatan jarum (derajat per frame, searah jarum jam)
    local rawSpeed = 0
    if lastLineRotation ~= nil then
        rawSpeed = (currentRot - lastLineRotation) % 360
        if rawSpeed > 180 then rawSpeed = rawSpeed - 360 end
    end
    lastLineRotation = currentRot

    -- Jika minigame sedang standby/idle (jarum diam di 0°):
    if math.abs(rawSpeed) < 0.05 and (currentRot % 360 == 0) then
        isMinigameActive      = false
        hasHitCurrentMinigame = false
        lineMoveCount         = 0
        return
    end

    -- Deteksi pergerakan jarum aktif
    if math.abs(rawSpeed) > 0.05 then
        lineMoveCount = lineMoveCount + 1
    end

    -- Tunggu minimal 1 frame pergerakan agar kecepatan terukur (maksimal responsif)
    if lineMoveCount < 1 then return end

    -- Jangan tekan lagi jika sudah pernah hit untuk ronde ini
    if hasHitCurrentMinigame then return end

    -- Normalisasi rotasi needle (0-360)
    local lineRot = currentRot % 360
    if lineRot < 0 then lineRot = lineRot + 360 end

    -- TARGET ZONA PUTIH (100% DEAD CENTER PRESISI):
    -- Titik tengah zona putih Violence District adalah tepat pada Goal.Rotation + 108.3°
    local centerTarget = (goalRot + 108.3) % 360
    if centerTarget < 0 then centerTarget = centerTarget + 360 end

    local speed = math.abs(rawSpeed)

    -- Jarak sudut bertanda dari jarum ke titik tengah target (0.0° = pas di tengah)
    local signedDist = (centerTarget - lineRot) % 360
    if signedDist > 180 then signedDist = signedDist - 360 end

    -- Trigger optimal saat jarum berada tepat di tengah (memperhitungkan latency input 0.5 frame)
    local shouldHit = false
    if rawSpeed >= 0 then
        -- Searah jarum jam (Normal CW): tembak saat signedDist <= speed * 0.65 dan belum melewati tengah
        shouldHit = (signedDist <= (speed * 0.65) and signedDist >= - (speed * 0.35))
    else
        -- Berlawanan jarum jam (Kutukan/Hex CCW)
        shouldHit = (signedDist >= - (speed * 0.65) and signedDist <= (speed * 0.35))
    end

    if shouldHit then
        hasHitCurrentMinigame = true
        lastHitTick           = tick()
        autoGenHitCount       = autoGenHitCount + 1
        agen_press(spaceObj)

        -- Feedback console (F9) saja tanpa popup notifikasi di layar
        pcall(function()
            print(string.format(
                "[AutoGen] PERFECT HIT! Jarum: %.1f° | Goal: %.1f° | Selisih: %.1f° | Prediksi: %.1f° | Speed: %.2f°/f",
                lineRot, goalRot, (lineRot - goalRot) % 360, predictedRot, speed
            ))
        end)
    end
end

local function agen_start()
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

local function agen_stop()
    if autoGenConn then
        autoGenConn:Disconnect()
        autoGenConn = nil
    end
    isMinigameActive = false
    hasHitCurrentMinigame = false
    lastLineRotation = nil
    lineMoveCount = 0
end

-- ==============================================================================
-- MODUL 4.5: AUTO PARRY (PARRYING DAGGER)
-- ==============================================================================
local autoParryEnabled = false
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

LocalPlayer.CharacterAdded:Connect(function()
    cachedParryClient = nil
    cachedParryRemote = nil
    isParrying = false
    lastParryTick = 0
    gameParryCooldownEnd = 0
    cleanup_animator_tracks()
end)

local function execute_perfect_parry(killerModel, killerName, reason, dist)
    local now = tick()
    -- Cek cooldown internal & cooldown dari game
    if isParrying or (now - lastParryTick < PARRY_COOLDOWN) or (now < gameParryCooldownEnd) then
        return
    end

    local myChar = LocalPlayer.Character
    if not myChar then return end
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
    if toKiller.Magnitude > 0 then
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

    pcall(function()
        print(string.format("[AutoParry] PERFECT PARRY! Killer: %s | Jarak: %.1f studs | %s", tostring(killerName), dist or 0, reason))
    end)

    -- Fallback: reset isParrying setelah PARRY_COOLDOWN detik
    -- (event parryResult akan reset lebih cepat jika server merespons)
    task.delay(PARRY_COOLDOWN, function()
        isParrying = false
    end)
end

local function is_killer_entity(model)
    if not model or not model:IsA("Model") then return false end
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
    local p = Players:GetPlayerFromCharacter(model)
    if p then
        local role = p:GetAttribute("CurrentRole") or p:GetAttribute("Role")
        if role and tostring(role):lower() == "killer" then return true end
        if p.Character and p.Character:FindFirstChild("Weapon") then return true end
    end
    return false
end

local function monitorAnimator(animator, ownerModel, ownerName)
    if trackedAnimators[animator] then return end

    local conn = animator.AnimationPlayed:Connect(function(track)
        if not autoParryEnabled then return end
        -- [FIX] Cek SEMUA kondisi cooldown sebelum parry
        local now2 = tick()
        if isParrying or (now2 - lastParryTick < PARRY_COOLDOWN) or (now2 < gameParryCooldownEnd) then return end

        -- [FIX] HANYA AUTO PARRY JIKA ENTITY ADALAH KILLER! JANGAN PARRY JIKA SURVIVOR NEMBAK!
        if not is_killer_entity(ownerModel) then
            return
        end

        local myChar = LocalPlayer and LocalPlayer.Character
        local myHrp = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
        local killerHrp = ownerModel and (ownerModel:FindFirstChild("HumanoidRootPart") or ownerModel:FindFirstChild("Torso"))

        if not myHrp or not killerHrp then return end

        -- [FIX] Skip jika killer sedang MEMBAWA survivor (bukan menyerang kita)
        local killerIsCarrying = ownerModel:GetAttribute("IsCarrying") or ownerModel:GetAttribute("Carrying")
        if killerIsCarrying and killerIsCarrying ~= false and killerIsCarrying ~= 0 then
            return -- Killer sedang bawa survi, bukan menyerang
        end
        -- Juga cek apakah kita sedang di-carry
        if myChar:GetAttribute("IsCarried") then
            return
        end

        local dist = (myHrp.Position - killerHrp.Position).Magnitude
        if dist <= PARRY_DISTANCE then
            -- DIRECTIONAL CHECK: Hanya tangkis jika killer menghadap kita
            local killerLook = killerHrp.CFrame.LookVector
            local killerLookFlat = Vector3.new(killerLook.X, 0, killerLook.Z).Unit
            local toPlayer = (myHrp.Position - killerHrp.Position)
            local toPlayerFlat = Vector3.new(toPlayer.X, 0, toPlayer.Z).Unit

            local facingAngle = killerLookFlat:Dot(toPlayerFlat)
            if facingAngle < 0.45 then
                return -- Killer mengayun ke arah lain / membelakangi
            end

            local anim = track.Animation
            local animId = anim and anim.AnimationId or ""
            local cleanId = tostring(animId):match("%d+")
            local animName = (track.Name or ""):lower()

            -- [FIX] Skip animasi carry / pickup
            local isCarryAnim = animName:find("carry") or animName:find("pickup")
                or animName:find("pick_up") or animName:find("grab") or animName:find("lift")
                or animName:find("drop") or animName:find("throw") or animName:find("release")
            if isCarryAnim then return end

            -- [FIX] Skip animasi tembakan senjata api / flare
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
    local myChar = LocalPlayer and LocalPlayer.Character
    if not myChar then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and is_killer_entity(p.Character) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local anim = hum and hum:FindFirstChildOfClass("Animator")
            if anim then monitorAnimator(anim, p.Character, p.DisplayName or p.Name) end
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar and is_killer_entity(obj) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local anim = hum and hum:FindFirstChildOfClass("Animator")
            if anim then monitorAnimator(anim, obj, obj.Name) end
        end
    end
end

local autoParryDescConn = nil

local function autoparry_start()
    if autoParryConn then return end
    isParrying = false
    lastParryTick = 0
    gameParryCooldownEnd = 0
    -- Scan awal sekali
    scanAllEntities()
    -- Event-driven: pasang listener saat ada child/descendant baru di workspace
    autoParryDescConn = workspace.DescendantAdded:Connect(function(desc)
        if not autoParryEnabled then return end
        if desc:IsA("Animator") then
            local ownerModel = desc.Parent and desc.Parent.Parent
            if ownerModel and is_killer_entity(ownerModel) then
                monitorAnimator(desc, ownerModel, ownerModel.Name)
            end
        end
    end)
    -- Heartbeat hanya untuk re-scan entitas baru secara berkala (jarang)
    local scanTimer2 = 0
    autoParryConn = RunService.Heartbeat:Connect(function(dt)
        if not autoParryEnabled then return end
        scanTimer2 = scanTimer2 + dt
        if scanTimer2 >= 3 then  -- re-scan setiap 3 detik, bukan setiap frame
            scanTimer2 = 0
            scanAllEntities()
        end
    end)
end

local function autoparry_stop()
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

-- Anti-AFK
local VirtualUser = cloneref and cloneref(game:GetService("VirtualUser")) or game:GetService("VirtualUser")
local antiAfkConn = nil

local function toggle_anti_afk(enabled)
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    if enabled then
        antiAfkConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end

-- ==============================================================================
-- TAB 1: PLAYER (SPEED, FLY & ANTI-AFK)
-- ==============================================================================
local TabPlayer = tabGroup:Tab({ Name = "Player", Image = "lucide/user" })

-- SEKSI 1: SPEED PLAYER
local SecSpeed = TabPlayer:Section({})
SecSpeed:Header({ Name = WMacLib:Gradient("Kecepatan Pemain (WalkSpeed)", Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 100, 255)) })

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
SecFly:Header({ Name = WMacLib:Gradient("Terbang (Infinite Yield Fly)", Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 120)) })

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
SecUtil:Header({ Name = WMacLib:Gradient("Player Utility", Color3.fromRGB(100, 240, 160), Color3.fromRGB(60, 180, 255)) })

SecUtil:Toggle({
    Name = "Anti-AFK (Cegah Disconnect 20 Menit)",
    Default = false,
    Callback = function(enabled)
        toggle_anti_afk(enabled)
        Window:Notify({
            Title = "Anti-AFK",
            Description = enabled and "Anti-AFK aktif! Anda tidak akan di-kick karena AFK." or "Anti-AFK dinonaktifkan.",
            Lifetime = 3
        })
    end
})
end -- [End TabPlayer]

-- ==============================================================================

-- TAB 2: MAIN (AUTO PERFECT GENERATOR)
-- ==============================================================================
local TabMain = tabGroup:Tab({ Name = "Main", Image = "lucide/zap" })

local SecAutoGen = TabMain:Section({})
SecAutoGen:Header({ Name = WMacLib:Gradient("Auto Perfect Generator", Color3.fromRGB(100, 255, 180), Color3.fromRGB(60, 180, 255)) })

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

local SecAutoParry = TabMain:Section({})
SecAutoParry:Header({ Name = WMacLib:Gradient("Auto Parry", Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 180, 50)) })

SecAutoParry:Toggle({
    Name = "Aktifkan Auto Parry",
    Default = false,
    Callback = function(enabled)
        autoParryEnabled = enabled
        if enabled then
            autoparry_start()
            Window:Notify({ Title = "Auto Parry", Description = "Aktif! Menangkis serangan killer otomatis.", Lifetime = 3 })
        else
            autoparry_stop()
            Window:Notify({ Title = "Auto Parry", Description = "Auto Parry dimatikan.", Lifetime = 2 })
        end
    end
})


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
-- MODUL 4.6: TWIST OF FATE - ANTI MISS (100% HIT CHANCE) [ULTRA MODE]
-- ==============================================================================
-- STRATEGI KOMPREHENSIF LINTAS ENVIRONMENT:
--   [L1] hookmetamethod __namecall (Tingkat C, intercept Result:Fire & FireServer)
--   [L2] getrenv() math.random & Random hook (mempengaruhi LocalScript game langsung)
--   [L3] ReplicatedStorage.Modules.Items scanner & patch
--   [L4] getgc() scanner & patch tabel/upvalue di memori
--   [L5] Attribute Character & Tool patch tiap Heartbeat
-- ==============================================================================
local tofAntiMissEnabled  = false
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
        tofOrigNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args   = {...}

            local isResult = (tofResultEvent and self == tofResultEvent)
                or (self.Name == "Result" and self.Parent and self.Parent.Name == "Twist of Fate")
            local isFire   = (tofFireEvent and self == tofFireEvent)
                or (self.Name == "Fire" and self.Parent and self.Parent.Name == "Twist of Fate")

            -- Intercept BindableEvent Result:Fire(...) -> ubah miss menjadi hit!
            if tofAntiMissEnabled and isResult and (method == "Fire" or method == "fire") then
                if #args == 0 then
                    return tofOrigNamecall(self, true)
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
                return tofOrigNamecall(self, table.unpack(args))
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
                return tofOrigNamecall(self, table.unpack(args))
            end

            return tofOrigNamecall(self, ...)
        end)
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

local function tof_start()
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

local function tof_stop()
    tof_unhook_namecall()
    tof_unhook_renv()
    if tofUpdateConn then
        tofUpdateConn:Disconnect()
        tofUpdateConn = nil
    end
    tofGunTable = nil
end

-- ==============================================================================
-- TAB 2: COMBAT (CROSSHAIR)
-- ==============================================================================
local TabCombat = tabGroup:Tab({ Name = "Combat", Image = "lucide/crosshair" })

local SecCross = TabCombat:Section({})
SecCross:Header({ Name = WMacLib:Gradient("Crosshair", Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 180, 50)) })

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
SecTOF:Header({ Name = WMacLib:Gradient("Twist of Fate - Anti Miss [ULTRA]", Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 80, 200)) })

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

local CollectionService_ESP = game:GetService("CollectionService")

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
    -- Prioritas utama: EquippedItem dari Attribute Player (paling akurat)
    local player = Players:GetPlayerFromCharacter(char)
    if player then
        local equippedItem = player:GetAttribute("EquippedItem")
        if equippedItem and equippedItem ~= "" then
            return tostring(equippedItem)
        end
        -- Fallback: Cek Backpack
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                if v:IsA("Tool") then return v.Name end
            end
        end
    end
    -- Fallback: Cek Tool yang sedang dipegang di Character
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then return v.Name end
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

    bbg.Parent = head

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
-- MODUL ESP GENERATOR
-- ==============================================================================
local espGenEnabled   = false
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
        pctLbl.TextStrokeTransparency = 0
        pctLbl.Text = "0%"
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

local function start_esp_gen()
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

local function stop_esp_gen()
    if espConn then
        espConn:Disconnect()
        espConn = nil
    end
    esp_hide_all()
end

-- ==============================================================================
-- TAB 3: ESP
-- ==============================================================================
local TabESP = tabGroup:Tab({ Name = "ESP", Image = "lucide/eye" })

local SecESPPlayer = TabESP:Section({})
SecESPPlayer:Header({ Name = WMacLib:Gradient("ESP Player - Survivor dan Killer", Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 80)) })

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
SecESPGen:Header({ Name = WMacLib:Gradient("ESP Generator", Color3.fromRGB(100, 220, 255), Color3.fromRGB(80, 255, 160)) })

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
end -- [End TabESP]

-- ==============================================================================
-- TAB 4: MODIFIKASI (VERTIKAL SCROLL KE BAWAH)
-- ==============================================================================
do
local TabMod = tabGroup:Tab({ Name = "Modifikasi", Image = "lucide/sparkles" })


-- SEKSI 1: SALIN AVATAR PEMAIN
local SecAvatar = TabMod:Section({})
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

-- SEKSI 2: KLONING OUTFIT TERSIMPAN
local SecOutfit = TabMod:Section({})
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

-- SEKSI 3: PEMUAT AKSESORIS CATALOG
local SecAcc = TabMod:Section({})
SecAcc:Header({ Name = WMacLib:Gradient("Pemuat Aksesoris Catalog", Color3.fromRGB(50, 220, 150), Color3.fromRGB(70, 180, 255)) })

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
SecBody:Header({ Name = WMacLib:Gradient("Korblox & Headless", Color3.fromRGB(255, 120, 70), Color3.fromRGB(255, 70, 100)) })

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
SecWin:Header({ Name = WMacLib:Gradient("Jendela & Kontrol", Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 80, 120)) })

-- Watermark & FPS
local watermark = WMacLib:Watermark({ Name = "Sky Hub", Version = "v1.0.0" })
watermark:SetVisible(false)

local fpsCount, fpsElapsed = 0, 0
RunService.Heartbeat:Connect(function(dt)
    fpsCount = fpsCount + 1
    fpsElapsed = fpsElapsed + dt
    if fpsElapsed >= 0.5 then
        pcall(function()
            watermark:Set("FPS", math.round(fpsCount / fpsElapsed) .. " FPS")
        end)
        fpsCount = 0
        fpsElapsed = 0
    end
end)

SecWin:Toggle({
    Name = "Logo Watermark & FPS Overlay",
    Default = false,
    Callback = function(value)
        watermark:SetVisible(value)
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

Window:Notify({
    Title = "Sky Hub",
    Description = "Player, Modifikasi & Pengaturan siap digunakan!",
    Lifetime = 5
})

print("[OK] Sky Hub berhasil dijalankan!")
end -- [End TabConfig]

