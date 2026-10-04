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
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Wicikk/WMacLib/main/WMacLib.lua"))()
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

    -- TARGET ZONA PUTIH (PERFECT ZONE DEAD CENTER = Goal + 109.0°):
    -- Zona putih berada di 105.0° s/d 113.0°. Titik tengah mutlak adalah 109.0°!
    local centerTarget = (goalRot + 109.0 + autoGenOffset) % 360
    if centerTarget < 0 then centerTarget = centerTarget + 360 end

    -- PREDIKSI POSISI JARUM FRAME BERIKUTNYA (saat keypress diproses game):
    -- Menjamin 100% tepat baik saat jarum berputar lambat maupun super cepat (King's Scourge)!
    local speed = math.abs(rawSpeed)
    local predictedRot = (lineRot + speed * 1.0) % 360

    -- Jarak jarum prediksi menuju titik tengah zona putih
    local distToCenter = (centerTarget - predictedRot) % 360

    -- Tembak jika posisi prediksi tepat mendarat di zona putih:
    -- Untuk kecepatan tinggi (King's Scourge), toleransi mengikuti kecepatan per frame
    local tolerance = math.max(speed * 0.75, 3.5)
    local shouldHit = (distToCenter <= tolerance or distToCenter >= (360 - tolerance))

    if shouldHit then
        hasHitCurrentMinigame = true
        lastHitTick           = tick()
        autoGenHitCount       = autoGenHitCount + 1
        agen_press(spaceObj)

        -- Feedback notifikasi & console (F9)
        pcall(function()
            Window:Notify({
                Title = "Auto Perfect Gen",
                Description = string.format("PERFECT! Selisih: %.1f° (Speed: %.1f°/f)", (lineRot - goalRot) % 360, speed),
                Lifetime = 2
            })
            print(string.format(
                "[AutoGen] PERFECT HIT! Jarum: %.1f° | Goal: %.1f° | Selisih: %.1f° | Prediksi: %.1f° | Speed: %.2f°/f",
                lineRot, goalRot, (lineRot - goalRot) % 360, predictedRot, speed
            ))
        end)
    end
end

local function agen_start()
    if autoGenConn then return end
    autoGenHitCount = 0
    isMinigameActive = false
    hasHitCurrentMinigame = false
    lastLineRotation = nil
    lineMoveCount = 0
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
-- MODUL 5: PLAYER CONTROLS (SPEED & INFINITE YIELD FLY ENGINE)
-- ==============================================================================
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
            Window:Notify({ Title = "Auto Perfect Gen", Description = "Aktif! Otomatis tekan Space pas di zona putih.", Lifetime = 4 })
        else
            agen_stop()
            Window:Notify({ Title = "Auto Perfect Gen", Description = "Dimatikan.", Lifetime = 3 })
        end
    end
})

SecAutoGen:Slider({
    Name = "Timing Offset (Fine Tune)",
    Default = 0,
    Minimum = -25,
    Maximum = 25,
    DisplayMethod = "Round",
    Precision = 0,
    Callback = function(val)
        autoGenOffset = tonumber(val) or 0
    end
})


-- ==============================================================================
-- MODUL CROSSHAIR
-- ==============================================================================
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
-- MODUL ESP Player - Survivor dan Killer
-- ==============================================================================
local espPlayerEnabled = false

local ESP_WHITE  = Color3.fromRGB(255, 255, 255)
local ESP_RED    = Color3.fromRGB(255,  50,  50)
local ESP_YELLOW = Color3.fromRGB(255, 200,  50)
local ESP_ORANGE = Color3.fromRGB(255, 120,  30)
local ESP_PURPLE = Color3.fromRGB(200, 100, 255)
local ESP_GREY   = Color3.fromRGB(150, 150, 150)

local function esp_is_killer(char)
    if not char then return false end
    return char:FindFirstChild("Weapon") ~= nil
end

local function esp_get_status(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return "?", ESP_GREY end
    for _, v in ipairs(char:GetDescendants()) do
        local n = v.Name:lower()
        if (n == "hooked" or n == "onhook" or n == "ishook") and
            ((v:IsA("BoolValue") and v.Value == true) or (v:IsA("IntValue") and v.Value == 1)) then
            return "Hooked", ESP_PURPLE
        end
    end
    for _, k in ipairs({"Hooked","OnHook","IsHooked"}) do
        local v = char:GetAttribute(k)
        if v == true or v == 1 then return "Hooked", ESP_PURPLE end
    end
    local hp, maxHp = hum.Health, hum.MaxHealth
    if maxHp <= 0 then return "?", ESP_GREY end
    local ratio = hp / maxHp
    if ratio <= 0   then return "Knocked", ESP_RED    end
    if ratio < 0.99 then return "Injured",  ESP_ORANGE end
    return "Aman", ESP_YELLOW
end

local function esp_get_item(char)
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then return v.Name end
    end
    local player = Players:GetPlayerFromCharacter(char)
    if player then
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                if v:IsA("Tool") then return v.Name end
            end
        end
    end
    return nil
end

local espDrawings   = {}
local espHighlights = {}

local function esp_new_player_draw(dtype, props)
    local d = Drawing.new(dtype)
    for k, v in pairs(props) do d[k] = v end
    return d
end

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

local function esp_add_player(player)
    if player == LocalPlayer or espDrawings[player] then return end
    espDrawings[player] = {
        name = esp_new_player_draw("Text", {
            Size=13, Center=true, Outline=true,
            Color=ESP_WHITE, OutlineColor=Color3.new(0,0,0), Visible=false,
        }),
        info = esp_new_player_draw("Text", {
            Size=12, Center=true, Outline=true,
            Color=ESP_WHITE, OutlineColor=Color3.new(0,0,0), Visible=false,
        }),
    }
end

local function esp_remove_player(player)
    if espDrawings[player] then
        for _, d in pairs(espDrawings[player]) do pcall(function() d:Remove() end) end
        espDrawings[player] = nil
    end
    esp_remove_highlight_player(player)
end

local function esp_hide_player(player)
    local d = espDrawings[player]
    if not d then return end
    for _, obj in pairs(d) do pcall(function() obj.Visible = false end) end
    esp_remove_highlight_player(player)
end

local function esp_update_player(player)
    local d = espDrawings[player]
    if not d then return end
    if not espPlayerEnabled then esp_hide_player(player); return end

    local char = player.Character
    if not char then esp_hide_player(player); return end

    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then esp_hide_player(player); return end

    local cam   = workspace.CurrentCamera
    local dist  = (cam.CFrame.Position - root.Position).Magnitude
    local head  = char:FindFirstChild("Head")
    local hPos  = head and head.Position or (root.Position + Vector3.new(0, 2.5, 0))
    local sc, vis = cam:WorldToViewportPoint(hPos + Vector3.new(0, 0.5, 0))
    if not vis then esp_hide_player(player); return end

    local sp = Vector2.new(sc.X, sc.Y)

    if esp_is_killer(char) then
        esp_set_highlight_player(player, char, ESP_RED)
        d.name.Text     = "[KILLER] " .. player.DisplayName .. " (" .. math.floor(dist) .. "m)"
        d.name.Position = sp - Vector2.new(0, 10)
        d.name.Color    = ESP_RED
        d.name.Visible  = true
        d.info.Visible  = false
    else
        local status, statusColor = esp_get_status(char)
        local item = esp_get_item(char)
        esp_set_highlight_player(player, char, ESP_WHITE)
        d.name.Text     = player.DisplayName .. " (" .. math.floor(dist) .. "m)"
        d.name.Position = sp - Vector2.new(0, 18)
        d.name.Color    = ESP_WHITE
        d.name.Visible  = true
        local info = status
        if item then info = info .. " | " .. item end
        d.info.Text     = info
        d.info.Position = sp - Vector2.new(0, 5)
        d.info.Color    = statusColor
        d.info.Visible  = true
    end
end

local espPlayerConn = nil

local function start_esp_player()
    if espPlayerConn then return end
    for _, p in ipairs(Players:GetPlayers()) do esp_add_player(p) end
    Players.PlayerAdded:Connect(esp_add_player)
    Players.PlayerRemoving:Connect(esp_remove_player)
    espPlayerConn = RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then esp_update_player(p) end
        end
    end)
end

local function stop_esp_player()
    if espPlayerConn then
        espPlayerConn:Disconnect()
        espPlayerConn = nil
    end
    for p in pairs(espDrawings) do esp_remove_player(p) end
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

local function esp_new_draw(dtype, props)
    local d = Drawing.new(dtype)
    for k, v in pairs(props) do d[k] = v end
    return d
end

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
    -- Jangan daftarkan jika ada ancestor yang sudah terdaftar (hindari duplikat)
    if esp_has_registered_ancestor(gen) then return end
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
    genData_esp[gen] = {
        pct = esp_new_draw("Text", {
            Size         = 13,
            Center       = true,
            Outline      = true,
            Color        = ESP_GEN_COLOR,
            OutlineColor = Color3.new(0,0,0),
            Visible      = false,
        }),
        highlight = h,
    }
end

local function esp_remove_gen(gen)
    local e = genData_esp[gen]
    if not e then return end
    pcall(function() e.pct:Remove() end)
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    genData_esp[gen] = nil
end

local function esp_hide_all()
    for _, e in pairs(genData_esp) do
        pcall(function() e.pct.Visible = false end)
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
    local cam = workspace.CurrentCamera
    local scanTimer = 0
    espConn = RunService.RenderStepped:Connect(function(dt)
        scanTimer += dt
        if scanTimer >= 5 then
            scanTimer = 0
            esp_scan()
        end

        for gen, e in pairs(genData_esp) do
            if not gen.Parent or not espGenEnabled then
                pcall(function() e.pct.Visible = false end)
            else
                local pos = get_gen_pos(gen)
                if not pos then
                    pcall(function() e.pct.Visible = false end)
                else
                    local dist = (cam.CFrame.Position - pos).Magnitude
                    if espMaxDist > 0 and dist > espMaxDist then
                        pcall(function() e.pct.Visible = false end)
                    else
                        local sc, vis = cam:WorldToViewportPoint(pos + Vector3.new(0, 3, 0))
                        if not vis then
                            pcall(function() e.pct.Visible = false end)
                        else
                            local progress = get_gen_progress(gen)
                            local label    = progress and string.format("%.0f%%", progress) or "0%"

                            if e.highlight then
                                e.highlight.FillTransparency    = espHighlight and 0.65 or 1
                                e.highlight.OutlineTransparency = espHighlight and 0   or 1
                            end

                            e.pct.Text     = label
                            e.pct.Position = Vector2.new(sc.X, sc.Y)
                            e.pct.Visible  = true
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

-- ==============================================================================
-- TAB 4: MODIFIKASI (VERTIKAL SCROLL KE BAWAH)
-- ==============================================================================
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

-- ==============================================================================
-- TAB 3: PENGATURAN & TEMA
-- ==============================================================================
tabGroup:Divider()
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
    fpsCount += 1
    fpsElapsed += dt
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

