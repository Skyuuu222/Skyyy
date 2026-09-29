-- ==============================================================================
-- UNIVERSAL AVATAR & OUTFIT MODIFIER HUB (ALL-IN-ONE)
-- Siap dipakai langsung atau lewat GitHub Raw Loader (loadstring)
-- ==============================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Bersihkan instance GUI lama jika sudah ada
if shared.UniversalAvatarHub then
    pcall(function() shared.UniversalAvatarHub:Destroy() end)
    shared.UniversalAvatarHub = nil
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
    return true, "Avatar " .. avatarUsername .. " dipasang ke " .. target.Name
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
-- MODUL 2: OUTFIT CLONER (Ambil Outfit Tersimpan Roblox)
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
-- GUI SYSTEM: MODERN TABBED HUB INTERFACE
-- ==============================================================================
local function getGuiContainer()
    if gethui then
        return gethui()
    elseif (pcall(function() return CoreGui.Name end)) and CoreGui:FindFirstChild("RobloxGui") then
        return CoreGui
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalAvatarHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiContainer()
shared.UniversalAvatarHub = ScreenGui

-- Window Utama
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 520, 0, 390)
Main.Position = UDim2.new(0.5, -260, 0.5, -195)
Main.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(48, 52, 68)
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

-- Top Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Text = "✨ AVATAR & OUTFIT STUDIO HUB"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 14, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 43, 58)
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -66, 0.5, -14)
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 43, 58)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Body Split Container (Sidebar Nav di Kiri, Tab Content di Kanan)
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, 0, 1, -42)
Body.Position = UDim2.new(0, 0, 0, 42)
Body.BackgroundTransparency = 1
Body.Parent = Main

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Body

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 10)
SidebarPad.PaddingLeft = UDim.new(0, 8)
SidebarPad.PaddingRight = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local PagesContainer = Instance.new("Frame")
PagesContainer.Name = "PagesContainer"
PagesContainer.Size = UDim2.new(1, -140, 1, 0)
PagesContainer.Position = UDim2.new(0, 140, 0, 0)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = Body

-- Helper Fungsi untuk Komponen UI
local function createInput(parent, placeholder, defaultText)
    local box = Instance.new("TextBox")
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(120, 125, 145)
    box.Text = defaultText or ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(245, 245, 255)
    box.BackgroundColor3 = Color3.fromRGB(16, 17, 23)
    box.Size = UDim2.new(1, 0, 0, 32)
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = box

    return box
end

local function createButton(parent, text, color, height)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 100, 245)
    btn.Size = UDim2.new(1, 0, 0, height or 32)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    return btn
end

local function createLabel(parent, text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = color or Color3.fromRGB(160, 165, 185)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Parent = parent
    return lbl
end

-- ==============================================================================
-- SISTEM TAB NAVIGASI
-- ==============================================================================
local tabs = {}
local activeTab = nil

local function registerTab(name, icon, order)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, -24, 1, -20)
    page.Position = UDim2.new(0, 12, 0, 10)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(70, 75, 95)
    page.CanvasSize = UDim2.new(0, 0, 0, 360)
    page.Visible = false
    page.Parent = PagesContainer

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Parent = page

    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "Tab_" .. name
    tabBtn.LayoutOrder = order
    tabBtn.Text = icon .. "  " .. name
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 12
    tabBtn.TextColor3 = Color3.fromRGB(150, 155, 175)
    tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    tabBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
    tabBtn.Size = UDim2.new(1, 0, 0, 34)
    tabBtn.BorderSizePixel = 0
    tabBtn.Parent = Sidebar

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBtn

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 10)
    tabPad.Parent = tabBtn

    local function selectTab()
        for _, t in pairs(tabs) do
            t.Page.Visible = false
            t.Button.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
            t.Button.TextColor3 = Color3.fromRGB(150, 155, 175)
        end
        page.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 64)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        activeTab = name
    end

    tabBtn.MouseButton1Click:Connect(selectTab)
    tabs[name] = { Page = page, Button = tabBtn, Select = selectTab }
    return page
end

-- ==================== TAB 1: AVATAR & SWAP ====================
local PageAvatar = registerTab("Avatar Swap", "👤", 1)

createLabel(PageAvatar, "Pemain Target di Server (Kosong = Diri Sendiri):", Color3.fromRGB(140, 180, 255))
local TargetInput = createInput(PageAvatar, "Nama Pemain di Server (atau kosong)...", "")

createLabel(PageAvatar, "Username Avatar Roblox yang Ingin Disalin:", Color3.fromRGB(140, 180, 255))
local AvatarInput = createInput(PageAvatar, "Ketik Username Avatar...", "usnavatar")

local SwapBtn = createButton(PageAvatar, "Terapkan Avatar", Color3.fromRGB(50, 100, 240))
local ResetSwapBtn = createButton(PageAvatar, "Reset Avatar Normal", Color3.fromRGB(60, 65, 80))
local StatusAvatar = createLabel(PageAvatar, "Status: Siap.")

SwapBtn.MouseButton1Click:Connect(function()
    StatusAvatar.TextColor3 = Color3.fromRGB(240, 200, 80)
    StatusAvatar.Text = "Status: Memproses avatar..."
    task.spawn(function()
        local success, msg = apply_avatar_swap(TargetInput.Text, AvatarInput.Text)
        StatusAvatar.TextColor3 = success and Color3.fromRGB(100, 240, 140) or Color3.fromRGB(255, 100, 100)
        StatusAvatar.Text = "Status: " .. (msg or "")
    end)
end)

ResetSwapBtn.MouseButton1Click:Connect(function()
    local success, msg = reset_avatar_swap(TargetInput.Text)
    StatusAvatar.TextColor3 = Color3.fromRGB(200, 205, 220)
    StatusAvatar.Text = "Status: " .. (msg or "")
end)

-- ==================== TAB 2: OUTFIT CLONER ====================
local PageOutfit = registerTab("Outfit Cloner", "👗", 2)

createLabel(PageOutfit, "Pemilik Outfit Tersimpan (Roblox User):", Color3.fromRGB(140, 180, 255))
local OutfitUser = createInput(PageOutfit, "Username pemilik outfit...", "zhbrxty")

createLabel(PageOutfit, "Nama Outfit atau Angka ID Outfit:", Color3.fromRGB(140, 180, 255))
local OutfitName = createInput(PageOutfit, "Contoh: cp 1 atau ID outfit...", "cp 1")

createLabel(PageOutfit, "Target Pemakai di Server (Kosong = Diri Sendiri):", Color3.fromRGB(140, 180, 255))
local OutfitTarget = createInput(PageOutfit, "Target pemain...", "")

local ApplyOutfitBtn = createButton(PageOutfit, "Pasang Outfit ke Target", Color3.fromRGB(140, 60, 220))
local StatusOutfit = createLabel(PageOutfit, "Status: Siap.")

ApplyOutfitBtn.MouseButton1Click:Connect(function()
    StatusOutfit.TextColor3 = Color3.fromRGB(240, 200, 80)
    StatusOutfit.Text = "Status: Mengambil data outfit..."
    task.spawn(function()
        local success, msg = apply_outfit(OutfitUser.Text, OutfitName.Text, OutfitTarget.Text)
        StatusOutfit.TextColor3 = success and Color3.fromRGB(100, 240, 140) or Color3.fromRGB(255, 100, 100)
        StatusOutfit.Text = "Status: " .. (msg or "")
    end)
end)

-- ==================== TAB 3: ACCESSORY LOADER ====================
local PageAcc = registerTab("Aksesoris", "👑", 3)

createLabel(PageAcc, "Target Pemain (Kosong = Diri Sendiri):", Color3.fromRGB(140, 180, 255))
local AccTarget = createInput(PageAcc, "Target pemain di server...", "")

createLabel(PageAcc, "Roblox Catalog Asset ID:", Color3.fromRGB(140, 180, 255))
local AccIdInput = createInput(PageAcc, "Contoh: 10159600649...", "10159600649")

local AddAccBtn = createButton(PageAcc, "Pasang Aksesoris", Color3.fromRGB(40, 160, 110))
local StatusAcc = createLabel(PageAcc, "Status: Siap.")

AddAccBtn.MouseButton1Click:Connect(function()
    StatusAcc.TextColor3 = Color3.fromRGB(240, 200, 80)
    StatusAcc.Text = "Status: Memuat aksesoris..."
    task.spawn(function()
        local success, msg = add_accessory(AccTarget.Text, AccIdInput.Text)
        StatusAcc.TextColor3 = success and Color3.fromRGB(100, 240, 140) or Color3.fromRGB(255, 100, 100)
        StatusAcc.Text = "Status: " .. (msg or "")
    end)
end)

-- ==================== TAB 4: KORBLOX & HEADLESS ====================
local PageMods = registerTab("Modifikasi", "💀", 4)

createLabel(PageMods, "Pemain Target (Kosong = Diri Sendiri):", Color3.fromRGB(140, 180, 255))
local ModTarget = createInput(PageMods, "Target pemain...", "")

createLabel(PageMods, "Korblox Right Leg (Khusus R6):", Color3.fromRGB(255, 200, 120))
local KorbloxBtn = createButton(PageMods, "Pasang Korblox Leg (R6)", Color3.fromRGB(200, 80, 50))

createLabel(PageMods, "Headless Head (Kepala Buntung):", Color3.fromRGB(255, 200, 120))
local HeadlessRow = Instance.new("Frame")
HeadlessRow.Size = UDim2.new(1, 0, 0, 32)
HeadlessRow.BackgroundTransparency = 1
HeadlessRow.Parent = PageMods

local HeadlessOnBtn = Instance.new("TextButton")
HeadlessOnBtn.Text = "Pasang Headless"
HeadlessOnBtn.Font = Enum.Font.GothamBold
HeadlessOnBtn.TextSize = 12
HeadlessOnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HeadlessOnBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 220)
HeadlessOnBtn.Size = UDim2.new(0.5, -4, 1, 0)
HeadlessOnBtn.BorderSizePixel = 0
HeadlessOnBtn.Parent = HeadlessRow
local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 6); c1.Parent = HeadlessOnBtn

local HeadlessOffBtn = Instance.new("TextButton")
HeadlessOffBtn.Text = "Hapus Headless"
HeadlessOffBtn.Font = Enum.Font.GothamBold
HeadlessOffBtn.TextSize = 12
HeadlessOffBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
HeadlessOffBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
HeadlessOffBtn.Size = UDim2.new(0.5, -4, 1, 0)
HeadlessOffBtn.Position = UDim2.new(0.5, 4, 0, 0)
HeadlessOffBtn.BorderSizePixel = 0
HeadlessOffBtn.Parent = HeadlessRow
local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 6); c2.Parent = HeadlessOffBtn

local StatusMod = createLabel(PageMods, "Status: Siap.")

KorbloxBtn.MouseButton1Click:Connect(function()
    StatusMod.TextColor3 = Color3.fromRGB(240, 200, 80)
    StatusMod.Text = "Status: Memasang Korblox..."
    task.spawn(function()
        local success, msg = apply_korblox(ModTarget.Text, 139607718, 0.7)
        StatusMod.TextColor3 = success and Color3.fromRGB(100, 240, 140) or Color3.fromRGB(255, 100, 100)
        StatusMod.Text = "Status: " .. (msg or "")
    end)
end)

HeadlessOnBtn.MouseButton1Click:Connect(function()
    local success, msg = apply_headless(ModTarget.Text)
    StatusMod.TextColor3 = success and Color3.fromRGB(100, 240, 140) or Color3.fromRGB(255, 100, 100)
    StatusMod.Text = "Status: " .. (msg or "")
end)

HeadlessOffBtn.MouseButton1Click:Connect(function()
    local success, msg = remove_headless(ModTarget.Text)
    StatusMod.TextColor3 = Color3.fromRGB(200, 205, 220)
    StatusMod.Text = "Status: " .. (msg or "")
end)

-- Pilih tab awal
tabs["Avatar Swap"].Select()

-- ==============================================================================
-- KONTROL WINDOW: MINIMIZE, CLOSE, DRAGGABLE & SHORTCUT
-- ==============================================================================
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    Body.Visible = not isMinimized
    Main.Size = isMinimized and UDim2.new(0, 520, 0, 42) or UDim2.new(0, 520, 0, 390)
    MinBtn.Text = isMinimized and "+" or "-"
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    shared.UniversalAvatarHub = nil
end)

-- Dragging
local dragging, dragInput, dragStart, startPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Shortcut Toggle (RightControl)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

print("[OK] Universal Avatar & Outfit Studio Hub berhasil dimuat!")
