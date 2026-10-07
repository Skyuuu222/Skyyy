-- ==============================================================================
-- ZYPHERAX UI - MODERN MACOS ENTERPRISE EDITION (v3.5)
-- Modern MacOS-Style Acrylic GUI Library for Roblox
-- Features:
--   * MacOS Traffic Lights Window Controls (Red: Close, Yellow: Minimize, Green: Maximize)
--   * Smooth, Uninterrupted Global Dragging (UIS-based, never disconnects)
--   * Dynamic Real-Time Theme Engine (Dark, Light, Midnight, Rose)
--   * Full Config Manager (Create Save, Overwrite, Delete Mode, Set/Reset Autoload)
--   * Elegant Draggable Watermark with Real-Time FPS and Minimize/Close
--   * Clean Section Architecture with Zero Generic "SECTION" Text Overlaps
--   * Anti-Collision Control Layouts (Toggles, Sliders, Dropdowns, Inputs, Buttons)
-- ==============================================================================

local ZypheraxUI = {}
ZypheraxUI.Version = "Enterprise 3.6.0"
ZypheraxUI.Flags = {}
ZypheraxUI.Controls = {}

-- // SERVICES \ --
local Players      = game:GetService("Players")
local Player       = Players.LocalPlayer
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local CoreGui
pcall(function()
    CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
end)

-- Safe Anti-AFK
local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
function ZypheraxUI:EnableAntiAFK()
    if not Player then return end
    pcall(function()
        Player.Idled:Connect(function()
            if VirtualUser then
                pcall(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end)
            end
        end)
    end)
end
ZypheraxUI:EnableAntiAFK()

-- // SAFE CORE GUI RESOLVER \ --
local function GetCore()
    if RunService:IsStudio() then return Player:WaitForChild("PlayerGui") end
    local ok, h = pcall(function() return gethui() end)
    if ok and h then return h end
    if CoreGui then return CoreGui end
    return Player:WaitForChild("PlayerGui")
end

-- // THEMES REGISTRY \ --
local Themes = {
    Dark = {
        Background       = Color3.fromRGB(15, 17, 23),
        Background2      = Color3.fromRGB(11, 12, 17),
        Surface          = Color3.fromRGB(20, 23, 31),
        Surface2         = Color3.fromRGB(26, 30, 42),
        Surface3         = Color3.fromRGB(34, 40, 56),
        Accent           = Color3.fromRGB(0, 200, 255),
        AccentDark       = Color3.fromRGB(0, 120, 190),
        AccentGradient   = Color3.fromRGB(130, 120, 255),
        Text             = Color3.fromRGB(242, 244, 250),
        TextMuted        = Color3.fromRGB(145, 152, 170),
        TextDim          = Color3.fromRGB(90, 96, 112),
        Stroke           = Color3.fromRGB(38, 43, 58),
        StrokeHover      = Color3.fromRGB(55, 62, 84),
        StrokeActive     = Color3.fromRGB(0, 200, 255),
        Success          = Color3.fromRGB(60, 215, 120),
        Warning          = Color3.fromRGB(255, 189, 46),
        Error            = Color3.fromRGB(255, 95, 86),
        SidebarBg        = Color3.fromRGB(12, 13, 18),
        SectionBg        = Color3.fromRGB(17, 19, 27),
        SectionHeader    = Color3.fromRGB(22, 25, 36),
    },
    Light = {
        Background       = Color3.fromRGB(244, 246, 250),
        Background2      = Color3.fromRGB(235, 238, 244),
        Surface          = Color3.fromRGB(255, 255, 255),
        Surface2         = Color3.fromRGB(238, 241, 248),
        Surface3         = Color3.fromRGB(224, 228, 238),
        Accent           = Color3.fromRGB(0, 150, 240),
        AccentDark       = Color3.fromRGB(0, 110, 180),
        AccentGradient   = Color3.fromRGB(90, 110, 230),
        Text             = Color3.fromRGB(25, 28, 36),
        TextMuted        = Color3.fromRGB(105, 112, 128),
        TextDim          = Color3.fromRGB(150, 155, 168),
        Stroke           = Color3.fromRGB(216, 222, 234),
        StrokeHover      = Color3.fromRGB(190, 198, 214),
        StrokeActive     = Color3.fromRGB(0, 150, 240),
        Success          = Color3.fromRGB(40, 180, 100),
        Warning          = Color3.fromRGB(240, 160, 30),
        Error            = Color3.fromRGB(240, 70, 70),
        SidebarBg        = Color3.fromRGB(232, 235, 242),
        SectionBg        = Color3.fromRGB(255, 255, 255),
        SectionHeader    = Color3.fromRGB(240, 243, 249),
    },
    Midnight = {
        Background       = Color3.fromRGB(9, 11, 16),
        Background2      = Color3.fromRGB(6, 7, 11),
        Surface          = Color3.fromRGB(14, 17, 26),
        Surface2         = Color3.fromRGB(20, 25, 38),
        Surface3         = Color3.fromRGB(28, 35, 54),
        Accent           = Color3.fromRGB(75, 140, 255),
        AccentDark       = Color3.fromRGB(40, 95, 210),
        AccentGradient   = Color3.fromRGB(145, 95, 255),
        Text             = Color3.fromRGB(240, 244, 255),
        TextMuted        = Color3.fromRGB(130, 142, 170),
        TextDim          = Color3.fromRGB(80, 90, 115),
        Stroke           = Color3.fromRGB(32, 40, 60),
        StrokeHover      = Color3.fromRGB(48, 60, 90),
        StrokeActive     = Color3.fromRGB(75, 140, 255),
        Success          = Color3.fromRGB(50, 210, 130),
        Warning          = Color3.fromRGB(255, 190, 45),
        Error            = Color3.fromRGB(255, 90, 85),
        SidebarBg        = Color3.fromRGB(8, 9, 14),
        SectionBg        = Color3.fromRGB(12, 15, 22),
        SectionHeader    = Color3.fromRGB(16, 20, 30),
    },
    Rose = {
        Background       = Color3.fromRGB(18, 14, 18),
        Background2      = Color3.fromRGB(13, 10, 13),
        Surface          = Color3.fromRGB(25, 19, 25),
        Surface2         = Color3.fromRGB(34, 25, 34),
        Surface3         = Color3.fromRGB(46, 34, 46),
        Accent           = Color3.fromRGB(255, 75, 125),
        AccentDark       = Color3.fromRGB(200, 45, 90),
        AccentGradient   = Color3.fromRGB(255, 135, 175),
        Text             = Color3.fromRGB(252, 242, 247),
        TextMuted        = Color3.fromRGB(175, 142, 160),
        TextDim          = Color3.fromRGB(115, 88, 104),
        Stroke           = Color3.fromRGB(56, 38, 52),
        StrokeHover      = Color3.fromRGB(80, 54, 75),
        StrokeActive     = Color3.fromRGB(255, 75, 125),
        Success          = Color3.fromRGB(70, 215, 140),
        Warning          = Color3.fromRGB(255, 195, 60),
        Error            = Color3.fromRGB(255, 90, 95),
        SidebarBg        = Color3.fromRGB(14, 11, 14),
        SectionBg        = Color3.fromRGB(22, 17, 22),
        SectionHeader    = Color3.fromRGB(28, 21, 28),
    }
}

-- Current active theme
ZypheraxUI.CurrentThemeName = "Dark"
ZypheraxUI.Theme = {}
for k, v in pairs(Themes.Dark) do ZypheraxUI.Theme[k] = v end

-- Common styles
ZypheraxUI.Theme.FontBold    = Enum.Font.GothamBold
ZypheraxUI.Theme.Font        = Enum.Font.GothamMedium
ZypheraxUI.Theme.FontRegular = Enum.Font.Gotham
ZypheraxUI.Theme.CornerLg    = UDim.new(0, 12)
ZypheraxUI.Theme.CornerMd    = UDim.new(0, 8)
ZypheraxUI.Theme.CornerSm    = UDim.new(0, 6)

local T = ZypheraxUI.Theme

-- Theme subscriber system
local ThemeSubscribers = {}
local function RegisterThemeColor(obj, prop, themeKey)
    table.insert(ThemeSubscribers, { obj = obj, prop = prop, key = themeKey })
    pcall(function() obj[prop] = T[themeKey] end)
end

local ActiveWindows = {}

function ZypheraxUI:SetTheme(themeName)
    local preset = Themes[themeName]
    if not preset then return end
    ZypheraxUI.CurrentThemeName = themeName
    for k, v in pairs(preset) do T[k] = v end

    -- (A) Update all registered theme subscribers
    for _, item in ipairs(ThemeSubscribers) do
        if item.obj and item.obj.Parent and T[item.key] then
            pcall(function()
                TweenService:Create(item.obj, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
                    [item.prop] = T[item.key]
                }):Play()
            end)
        end
    end

    -- (B) Comprehensive scan on all active UI windows to guarantee text color matches theme
    local isLight = (themeName == "Light")
    pcall(function()
        for _, winObj in ipairs(ActiveWindows) do
            if winObj and winObj._gui and winObj._gui.Parent then
                for _, desc in ipairs(winObj._gui:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                        -- Check if element has explicit theme tag or determine by brightness
                        local curColor = desc.TextColor3
                        if isLight then
                            -- On Light theme, all bright text must turn to dark text
                            if (curColor.R + curColor.G + curColor.B) > 1.8 then
                                TweenService:Create(desc, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
                                    TextColor3 = preset.Text
                                }):Play()
                            end
                        else
                            -- On Dark themes, any dark text must turn back to bright text
                            if (curColor.R + curColor.G + curColor.B) < 0.9 then
                                TweenService:Create(desc, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
                                    TextColor3 = preset.Text
                                }):Play()
                            end
                        end
                    end
                end
            end
        end
    end)
end

function ZypheraxUI:GetThemes()
    return { "Dark", "Light", "Midnight", "Rose" }
end

-- // UTILITY CORE \ --
local U = {}

function U.New(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    -- // ANTI-OVERFLOW SAFETY NET \ --
    -- Label satu baris otomatis dipotong rapi (AtEnd) agar tulisan tidak
    -- pernah menabrak elemen lain atau keluar dari kotaknya. Label yang
    -- memang multibaris (AutomaticSize.Y + TextWrapped) dibiarkan utuh.
    pcall(function()
        if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
            local autoY   = props and (props.AutomaticSize == Enum.AutomaticSize.Y or props.AutomaticSize == Enum.AutomaticSize.XY)
            local wrapped = props and props.TextWrapped == true
            local scaled  = props and props.TextScaled == true
            local hasTrunc = props and props.TextTruncate ~= nil
            if not autoY and not wrapped and not scaled and not hasTrunc then
                inst.TextTruncate = Enum.TextTruncate.AtEnd
            end
        end
    end)
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

function U.Corner(parent, radius)
    return U.New("UICorner", { CornerRadius = radius or T.CornerMd, Parent = parent })
end

function U.Stroke(parent, color, thickness, transparency)
    local s = U.New("UIStroke", {
        Color = color or T.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
    return s
end

function U.Gradient(parent, c1, c2, rot)
    return U.New("UIGradient", {
        Color = ColorSequence.new(c1, c2),
        Rotation = rot or 0,
        Parent = parent
    })
end

-- Safe Tween: filters out Enum properties that Roblox cannot interpolate
function U.Tween(obj, duration, props, style, dir)
    local clean = {}
    for k, v in pairs(props or {}) do
        if typeof(v) == "EnumItem" then
            pcall(function() obj[k] = v end)
        else
            clean[k] = v
        end
    end
    local tw = TweenService:Create(obj, TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), clean)
    tw:Play()
    return tw
end

function U.Ripple(btn, x, y)
    task.spawn(function()
        local ripple = U.New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x - btn.AbsolutePosition.X, y - btn.AbsolutePosition.Y),
            Size = UDim2.fromOffset(0, 0),
            ZIndex = btn.ZIndex + 2,
            Parent = btn
        })
        U.Corner(ripple, UDim.new(1, 0))
        local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.5
        local tw = U.Tween(ripple, 0.45, {
            Size = UDim2.fromOffset(maxSize, maxSize),
            BackgroundTransparency = 1
        })
        tw.Completed:Connect(function() ripple:Destroy() end)
    end)
end

-- // NOTIFICATIONS SYSTEM (Elegant, Modern, Non-Colliding) \\ --
local NotifGui = nil
local NotifSeq = 0
local ActiveNotif = {}

local function ensureNotifGui()
    if NotifGui and NotifGui.Parent then return NotifGui end
    NotifGui = U.New("ScreenGui", {
        Name = "ZypheraxNotifs",
        DisplayOrder = 10000,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = GetCore()
    })
    local container = U.New("Frame", {
        Name = "Container",
        AnchorPoint = Vector2.new(1, 1),
        Size = UDim2.new(0, 330, 1, -24),
        Position = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = NotifGui
    })
    U.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 10),
        Parent = container
    })
    return NotifGui
end

local function notifSlideOut(wrap, card)
    if not (wrap and wrap.Parent) then return end
    local h = (wrap.AbsoluteSize and wrap.AbsoluteSize.Y) or 0
    if h <= 0 then h = 64 end
    wrap.AutomaticSize = Enum.AutomaticSize.None
    wrap.Size = UDim2.new(1, 0, 0, h)
    card.AutomaticSize = Enum.AutomaticSize.None
    card.Size = UDim2.new(1, 0, 0, h)
    U.Tween(card, 0.28, {
        Position = UDim2.new(1, 34, 0, 0),
        BackgroundTransparency = 1
    }, Enum.EasingStyle.Quart)
    local tw = U.Tween(wrap, 0.3, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quart)
    tw.Completed:Connect(function()
        ActiveNotif[wrap] = nil
        if wrap and wrap.Parent then wrap:Destroy() end
    end)
end

function ZypheraxUI:Notify(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "Notifikasi"
    local desc  = cfg.Description or cfg.Text or cfg.Content or ""
    local life  = tonumber(cfg.Lifetime or cfg.Duration) or 4
    local accent = cfg.Accent or T.Accent

    local gui = ensureNotifGui()
    local holder = gui and gui:FindFirstChild("Container")
    if not holder then return end

    NotifSeq = NotifSeq + 1

    local wrap = U.New("Frame", {
        Name = "Notif",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = NotifSeq,
        Parent = holder
    })

    local card = U.New("Frame", {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = wrap
    })
    U.Corner(card, T.CornerMd)
    local stroke = U.Stroke(card, T.Stroke, 1, 0.35)
    RegisterThemeColor(card, "BackgroundColor3", "Surface")
    RegisterThemeColor(stroke, "Color", "Stroke")

    local bar = U.New("Frame", {
        Name = "AccentBar",
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = card
    })
    U.Gradient(bar, accent, T.AccentGradient, 90)

    local body = U.New("Frame", {
        Name = "Body",
        Size = UDim2.new(1, -4, 0, 0),
        Position = UDim2.new(0, 4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card
    })
    U.New("UIPadding", {
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 11),
        PaddingBottom = UDim.new(0, 14),
        Parent = body
    })
    U.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = body
    })

    local head = U.New("Frame", {
        Name = "Head",
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = body
    })
    local dot = U.New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, 0, 0.5, -4),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = head
    })
    U.Corner(dot, UDim.new(1, 0))

    local tLbl = U.New("TextLabel", {
        Text = title,
        Font = T.FontBold,
        TextSize = 13,
        TextColor3 = T.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(1, -18, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = head
    })
    RegisterThemeColor(tLbl, "TextColor3", "Text")

    if desc ~= "" then
        local dLbl = U.New("TextLabel", {
            Text = desc,
            Font = T.FontRegular,
            TextSize = 12,
            TextColor3 = T.TextMuted,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.None,
            LayoutOrder = 2,
            Parent = body
        })
        RegisterThemeColor(dLbl, "TextColor3", "TextMuted")
    end

    local track = U.New("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = T.Stroke,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        Parent = body
    })
    U.Corner(track, UDim.new(1, 0))
    local prog = U.New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = track
    })
    U.Corner(prog, UDim.new(1, 0))

    card.Position = UDim2.new(0, 34, 0, 0)
    card.BackgroundTransparency = 1
    stroke.Transparency = 1
    U.Tween(card, 0.34, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.08 }, Enum.EasingStyle.Quart)
    U.Tween(stroke, 0.34, { Transparency = 0.35 })
    U.Tween(prog, life, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)

    ActiveNotif[wrap] = true

    local btn = U.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
        Parent = card
    })
    btn.MouseButton1Click:Connect(function()
        notifSlideOut(wrap, card)
    end)

    task.delay(life, function() notifSlideOut(wrap, card) end)
end
-- // WATERMARK SYSTEM (Draggable, Minimizable, Realtime FPS) \ --
local ActiveWatermark = nil
function ZypheraxUI:Watermark(cfg)
    -- Inert watermark: safely cleanup existing widgets and return dummy methods
    pcall(function()
        local core = GetCore()
        local oldWm = core:FindFirstChild("ZypheraxWatermarkGui")
        if oldWm then oldWm:Destroy() end
        local oldFt = core:FindFirstChild("ZypheraxFloatingToggle")
        if oldFt then oldFt:Destroy() end
    end)
    return {
        Set = function() end,
        SetVisible = function() end,
        Destroy = function() end,
    }
end

-- // MAIN WINDOW BUILDER (MacOS Traffic Lights + Double Column) \ --
function ZypheraxUI:CreateWindow(config)
    config = config or {}
    local title   = config.Title or config.Name or "Zypherax Hub"
    local sub     = config.Description or config.SubName or "Violence District"
    local size    = config.Size or UDim2.fromOffset(760, 560)
    local keybind = config.Keybind or Enum.KeyCode.RightControl

    local core = GetCore()
    local connections = {}
    local function track(c) table.insert(connections, c); return c end

    local gui = U.New("ScreenGui", {
        Name = "ZypheraxApp_" .. title,
        DisplayOrder = 100,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = core
    })

    -- Drag anchor frame (Clean, no drop-shadow)
    local shadow = U.New("Frame", {
        Name = "WindowAnchor",
        Size = size,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = gui
    })

    -- Main window frame
    local main = U.New("Frame", {
        Name = "MainWindow",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = T.Background,
        BackgroundTransparency = 0.04,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = shadow
    })
    U.Corner(main, T.CornerLg)
    local mainStroke = U.Stroke(main, T.Stroke, 1.2, 0)
    RegisterThemeColor(main, "BackgroundColor3", "Background")
    RegisterThemeColor(mainStroke, "Color", "Stroke")

    -- Window Object
    local Win = { Tabs = {}, Pages = {}, _currentTab = nil, _connections = connections, _gui = gui }
    table.insert(ActiveWindows, Win)

    -- // SIDEBAR \ --
    local SIDEBAR_W = 168
    local sidebar = U.New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = T.SidebarBg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = main
    })
    U.Corner(sidebar, T.CornerLg)
    RegisterThemeColor(sidebar, "BackgroundColor3", "SidebarBg")

    -- Right border separator of sidebar
    local sideDiv = U.New("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = T.Stroke,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = sidebar
    })
    RegisterThemeColor(sideDiv, "BackgroundColor3", "Stroke")

    -- // SIDEBAR HEADER (MacOS Traffic Lights + Titles) \ --
    local sidebarHeader = U.New("Frame", {
        Name = "SidebarHeader",
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = sidebar
    })

    -- MacOS Traffic Light Buttons (🔴 Red, 🟡 Yellow, 🟢 Green - Compact)
    local trafficContainer = U.New("Frame", {
        Name = "MacOSTrafficLights",
        Size = UDim2.new(0, 48, 0, 12),
        Position = UDim2.new(0, 14, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = sidebarHeader
    })
    local tLayout = U.New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = trafficContainer
    })

    local function makeTrafficDot(color, hoverColor, onClick)
        local dot = U.New("TextButton", {
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 6,
            Parent = trafficContainer
        })
        U.Corner(dot, UDim.new(1, 0))
        track(dot.MouseEnter:Connect(function()
            U.Tween(dot, 0.15, { BackgroundColor3 = hoverColor })
        end))
        track(dot.MouseLeave:Connect(function()
            U.Tween(dot, 0.15, { BackgroundColor3 = color })
        end))
        track(dot.MouseButton1Click:Connect(function()
            if onClick then onClick() end
        end))
        return dot
    end

    -- 🔴 Close: smoothly closes window
    makeTrafficDot(Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 120, 110), function()
        Win:ToggleVisibility(false)
    end)

    -- 🟡 Minimize: minimizes window
    makeTrafficDot(Color3.fromRGB(255, 189, 46), Color3.fromRGB(255, 210, 80), function()
        Win:ToggleVisibility(false)
    end)

    -- 🟢 Maximize: toggles size
    local isMaximized = false
    makeTrafficDot(Color3.fromRGB(39, 201, 63), Color3.fromRGB(60, 225, 90), function()
        isMaximized = not isMaximized
        local targetSize = isMaximized and UDim2.fromOffset(860, 640) or size
        U.Tween(shadow, 0.3, { Size = targetSize }, Enum.EasingStyle.Quart)
    end)

    -- Window Title & Subtitle below traffic lights
    local titleLbl = U.New("TextLabel", {
        Text = string.upper(title),
        Font = T.FontBold,
        TextSize = 13,
        TextColor3 = T.Accent,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 32),
        Size = UDim2.new(1, -24, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = sidebarHeader
    })
    RegisterThemeColor(titleLbl, "TextColor3", "Accent")

    local subLbl = U.New("TextLabel", {
        Text = sub,
        Font = T.FontRegular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 48),
        Size = UDim2.new(1, -24, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = sidebarHeader
    })
    RegisterThemeColor(subLbl, "TextColor3", "TextMuted")

    -- Horizontal divider under sidebar header
    local hDiv = U.New("Frame", {
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.new(0, 12, 1, -1),
        BackgroundColor3 = T.Stroke,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = sidebarHeader
    })
    RegisterThemeColor(hDiv, "BackgroundColor3", "Stroke")

    -- // SMOOTH UNINTERRUPTED GLOBAL DRAGGING \ --
    local dragging = false
    local dragStart, startPos = nil, nil
    track(sidebarHeader.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = shadow.Position
        end
    end))
    track(UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            shadow.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
    track(UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    -- // SIDEBAR TAB LIST (Pill-style) \ --
    local tabList = U.New("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -78 - 54),
        Position = UDim2.new(0, 0, 0, 78),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 3,
        Parent = sidebar
    })
    local tabLayout = U.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = tabList
    })
    U.New("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8),
        Parent = tabList
    })

    -- // SIDEBAR FOOTER (User card) \ --
    local footer = U.New("Frame", {
        Name = "SidebarFooter",
        Size = UDim2.new(1, 0, 0, 54),
        Position = UDim2.new(0, 0, 1, -54),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = sidebar
    })
    RegisterThemeColor(footer, "BackgroundColor3", "Surface")
    local fStroke = U.Stroke(footer, T.Stroke, 1, 0.4)
    RegisterThemeColor(fStroke, "Color", "Stroke")

    local uName = Player and Player.DisplayName or "User"
    local uHandle = Player and ("@" .. Player.Name) or "@user"

    local fLbl = U.New("TextLabel", {
        Text = uName,
        Font = T.FontBold,
        TextSize = 12,
        TextColor3 = T.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -32, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = footer
    })
    local hLbl = U.New("TextLabel", {
        Text = uHandle,
        Font = T.FontRegular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -32, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = footer
    })

    -- // CONTENT AREA (Double Column) \ --
    local contentArea = U.New("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, 0),
        Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = main
    })

    -- Visibility Toggle Method
    function Win:ToggleVisibility(visible)
        if visible == nil then visible = not gui.Enabled end
        if visible then
            gui.Enabled = true
            main.Size = UDim2.fromScale(0.95, 0.95)
            main.BackgroundTransparency = 0.4
            U.Tween(main, 0.28, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.04 }, Enum.EasingStyle.Quart)
        else
            U.Tween(main, 0.2, { Size = UDim2.fromScale(0.95, 0.95), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart).Completed:Connect(function()
                gui.Enabled = false
            end)
        end
    end

    function Win:SetTheme(name)
        ZypheraxUI:SetTheme(name)
    end

    function Win:Destroy()
        for _, c in ipairs(connections) do
            if c and c.Connected then pcall(function() c:Disconnect() end) end
        end
        if gui then gui:Destroy() end
    end

    -- Keybind listener
    track(UIS.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == keybind then
            Win:ToggleVisibility()
        end
    end))

    -- // TAB CREATOR \ --
    function Win:CreateTab(tabCfg)
        local tabName = type(tabCfg) == "table" and (tabCfg.Name or tabCfg.Title) or tabCfg or "Tab"
        local tabIcon = type(tabCfg) == "table" and tabCfg.Icon or nil

        -- Tab button
        local tabBtn = U.New("TextButton", {
            Name = "TabBtn_" .. tabName,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = T.Surface2,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 4,
            Parent = tabList
        })
        U.Corner(tabBtn, T.CornerMd)
        local btnStroke = U.Stroke(tabBtn, T.Stroke, 1, 1)

        -- Active indicator bar
        local activeBar = U.New("Frame", {
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.new(0, 5, 0.5, -8),
            BackgroundColor3 = T.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,
            Parent = tabBtn
        })
        U.Corner(activeBar, UDim.new(1, 0))
        RegisterThemeColor(activeBar, "BackgroundColor3", "Accent")

        local tabLbl = U.New("TextLabel", {
            Text = tabName,
            Font = T.FontRegular,
            TextSize = 12,
            TextColor3 = T.TextMuted,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 0),
            Size = UDim2.new(1, -18, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
            Parent = tabBtn
        })
        RegisterThemeColor(tabLbl, "TextColor3", "TextMuted")

        -- Double Column Container for this Tab
        local pageFrame = U.New("Frame", {
            Name = "Page_" .. tabName,
            Size = UDim2.new(1, -20, 1, -20),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 3,
            Parent = contentArea
        })

        local function makeColumn(posX)
            local col = U.New("ScrollingFrame", {
                Size = UDim2.new(0.5, -6, 1, 0),
                Position = UDim2.new(posX, 0, 0, 0),
                BackgroundTransparency = 1,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = T.Accent,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ZIndex = 3,
                Parent = pageFrame
            })
            U.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = col })
            U.New("UIPadding", { PaddingBottom = UDim.new(0, 16), Parent = col })
            return col
        end

        local leftCol  = makeColumn(0)
        local rightCol = makeColumn(0.5)

        local function activateTab()
            for _, t in ipairs(Win.Tabs) do
                t.page.Visible = false
                U.Tween(t.btn, 0.15, { BackgroundTransparency = 1 })
                U.Tween(t.stroke, 0.15, { Transparency = 1 })
                U.Tween(t.lbl, 0.15, { TextColor3 = T.TextMuted, Font = T.FontRegular })
                U.Tween(t.bar, 0.15, { BackgroundTransparency = 1 })
            end
            pageFrame.Visible = true
            U.Tween(tabBtn, 0.18, { BackgroundColor3 = T.Surface2, BackgroundTransparency = 0.4 })
            U.Tween(btnStroke, 0.18, { Transparency = 0.5, Color = T.Accent })
            U.Tween(tabLbl, 0.18, { TextColor3 = T.Accent, Font = T.FontBold })
            U.Tween(activeBar, 0.18, { BackgroundTransparency = 0 })
            Win._currentTab = tabName
        end

        track(tabBtn.MouseButton1Click:Connect(activateTab))
        track(tabBtn.MouseEnter:Connect(function()
            if Win._currentTab ~= tabName then
                U.Tween(tabBtn, 0.12, { BackgroundColor3 = T.Surface, BackgroundTransparency = 0.5 })
                U.Tween(tabLbl, 0.12, { TextColor3 = T.Text })
            end
        end))
        track(tabBtn.MouseLeave:Connect(function()
            if Win._currentTab ~= tabName then
                U.Tween(tabBtn, 0.15, { BackgroundTransparency = 1 })
                U.Tween(tabLbl, 0.15, { TextColor3 = T.TextMuted })
            end
        end))

        if #Win.Tabs == 0 then activateTab() end

        local tabEntry = { btn = tabBtn, stroke = btnStroke, lbl = tabLbl, bar = activeBar, page = pageFrame, name = tabName }
        table.insert(Win.Tabs, tabEntry)

        -- // SECTION BUILDER (Zero Generic "SECTION" Text Overlaps) \ --
        local TabObj = {}
        function TabObj:CreateSection(secCfg)
            local rawName = type(secCfg) == "table" and (secCfg.Name or secCfg.Title) or secCfg
            local side    = type(secCfg) == "table" and (secCfg.Side or 1) or 1
            local targetCol = (side == 2) and rightCol or leftCol

            -- Check if name is generic
            local isGeneric = (rawName == nil or rawName == "" or rawName == "Section" or rawName == "SECTION")
            local displayName = isGeneric and "" or tostring(rawName)

            local sectionBox = U.New("Frame", {
                Name = "SectionBox_" .. (displayName ~= "" and displayName or "Card"),
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = T.SectionBg,
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 4,
                Parent = targetCol
            })
            U.Corner(sectionBox, T.CornerMd)
            local sStroke = U.Stroke(sectionBox, T.Stroke, 1, 0.4)
            RegisterThemeColor(sectionBox, "BackgroundColor3", "SectionBg")
            RegisterThemeColor(sStroke, "Color", "Stroke")

            -- Section Header Frame (Only visible if real name exists)
            local secHeader = U.New("Frame", {
                Name = "Header",
                Size = UDim2.new(1, 0, 0, displayName ~= "" and 28 or 0),
                BackgroundColor3 = T.SectionHeader,
                Visible = (displayName ~= ""),
                ZIndex = 5,
                Parent = sectionBox
            })
            U.Corner(secHeader, T.CornerMd)
            RegisterThemeColor(secHeader, "BackgroundColor3", "SectionHeader")

            local hLine = U.New("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = T.Accent,
                BorderSizePixel = 0,
                ZIndex = 6,
                Parent = secHeader
            })
            U.Gradient(hLine, T.Accent, T.Background, 0)

            local hTitle = U.New("TextLabel", {
                Text = displayName,
                Font = T.FontBold,
                TextSize = 11,
                TextColor3 = T.Accent,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 6,
                Parent = secHeader
            })

            -- Elements Container inside Section
            local secContainer = U.New("Frame", {
                Name = "Container",
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.new(0, 8, 0, displayName ~= "" and 34 or 8),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 5,
                Parent = sectionBox
            })
            U.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = secContainer })
            U.New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = secContainer })

            local SectionObj = {}

            -- Header updater (Sets section title without duplicate labels)
            function SectionObj:Header(hCfg)
                local txt = type(hCfg) == "table" and (hCfg.Name or hCfg[1]) or tostring(hCfg)
                if txt and txt ~= "" then
                    local clean = txt:gsub("<[^>]->", "")
                    hTitle.Text = clean
                    secHeader.Visible = true
                    secHeader.Size = UDim2.new(1, 0, 0, 28)
                    secContainer.Position = UDim2.new(0, 8, 0, 34)
                end
            end

            local function makeBase(height, isButton)
                local cls = isButton and "TextButton" or "Frame"
                local base = U.New(cls, {
                    Size = UDim2.new(1, 0, 0, height or 38),
                    BackgroundColor3 = T.Surface2,
                    BackgroundTransparency = 0.25,
                    BorderSizePixel = 0,
                    ZIndex = 5,
                    Parent = secContainer
                })
                if isButton then
                    base.Text = ""
                    base.AutoButtonColor = false
                end
                U.Corner(base, T.CornerSm)
                local bStroke = U.Stroke(base, T.Stroke, 1, 0)
                RegisterThemeColor(base, "BackgroundColor3", "Surface2")
                RegisterThemeColor(bStroke, "Color", "Stroke")
                return base, bStroke
            end

            -- // TOGGLE (Anti-Collision: TextTruncate + Dedicated Switch Area) \ --
            function SectionObj:CreateToggle(cfg)
                local nm      = cfg.Name or "Toggle"
                local flag    = cfg.Flag
                local default = cfg.Default == true
                local cb      = cfg.Callback or function() end
                local toggled = default

                if flag then ZypheraxUI.Flags[flag] = toggled end

                local base, stroke = makeBase(38)

                -- Label has generous space, cannot collide with switch
                local lbl = U.New("TextLabel", {
                    Text = nm,
                    Font = T.FontRegular,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -56, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                -- Switch pill
                local track = U.New("Frame", {
                    Size = UDim2.new(0, 34, 0, 18),
                    Position = UDim2.new(1, -44, 0.5, -9),
                    BackgroundColor3 = toggled and T.Accent or T.Surface3,
                    ZIndex = 6,
                    Parent = base
                })
                U.Corner(track, UDim.new(1, 0))
                local tStroke = U.Stroke(track, toggled and T.Accent or T.Stroke, 1, 0)

                local knob = U.New("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, toggled and 18 or 2, 0.5, -7),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    ZIndex = 7,
                    Parent = track
                })
                U.Corner(knob, UDim.new(1, 0))

                local btn = U.New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8, Parent = base })

                local function setVal(v, silent)
                    toggled = v
                    if flag then ZypheraxUI.Flags[flag] = toggled end
                    U.Tween(track, 0.2, { BackgroundColor3 = toggled and T.Accent or T.Surface3 })
                    U.Tween(tStroke, 0.2, { Color = toggled and T.Accent or T.Stroke })
                    U.Tween(knob, 0.22, { Position = UDim2.new(0, toggled and 18 or 2, 0.5, -7) }, Enum.EasingStyle.Quart)
                    if not silent then pcall(cb, toggled) end
                end

                track(btn.MouseButton1Click:Connect(function()
                    U.Ripple(btn, Player:GetMouse().X, Player:GetMouse().Y)
                    setVal(not toggled)
                end))

                if default then pcall(cb, true) end
                local ret = {
                    Set = function(_, v) setVal(v == true, false) end,
                    Get = function() return toggled end
                }
                if flag then ZypheraxUI.Controls[flag] = ret end
                return ret
            end
            SectionObj.Toggle = SectionObj.CreateToggle

            -- // SLIDER (Anti-Collision: Two-Row Layout) \ --
            function SectionObj:CreateSlider(cfg)
                local nm      = cfg.Name or "Slider"
                local flag    = cfg.Flag
                local mn      = cfg.Min or cfg.Minimum or 0
                local mx      = cfg.Max or cfg.Maximum or 100
                local default = math.clamp(cfg.Default or mn, mn, mx)
                local suffix  = cfg.Suffix or ""
                local cb      = cfg.Callback or function() end
                local value   = default

                if flag then ZypheraxUI.Flags[flag] = value end

                local base, stroke = makeBase(48)

                -- Title top-left
                local lbl = U.New("TextLabel", {
                    Text = nm,
                    Font = T.FontRegular,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 4),
                    Size = UDim2.new(1, -70, 0, 18),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                -- Value readout top-right
                local valLbl = U.New("TextLabel", {
                    Text = tostring(default) .. suffix,
                    Font = T.FontBold,
                    TextSize = 11,
                    TextColor3 = T.Accent,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -55, 0, 4),
                    Size = UDim2.new(0, 45, 0, 18),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 6,
                    Parent = base
                })

                -- Track bottom
                local trackBar = U.New("Frame", {
                    Size = UDim2.new(1, -20, 0, 4),
                    Position = UDim2.new(0, 10, 0, 32),
                    BackgroundColor3 = T.Surface3,
                    ZIndex = 6,
                    Parent = base
                })
                U.Corner(trackBar, UDim.new(1, 0))

                local ratio = (default - mn) / math.max(mx - mn, 1)
                local fill = U.New("Frame", {
                    Size = UDim2.new(ratio, 0, 1, 0),
                    BackgroundColor3 = T.Accent,
                    ZIndex = 7,
                    Parent = trackBar
                })
                U.Corner(fill, UDim.new(1, 0))
                U.Gradient(fill, T.Accent, T.AccentGradient, 0)

                local knob = U.New("Frame", {
                    Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.new(1, -6, 0.5, -6),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    ZIndex = 8,
                    Parent = fill
                })
                U.Corner(knob, UDim.new(1, 0))

                local btn = U.New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 9, Parent = base })

                local function updateSlider(mouseX)
                    local rel = math.clamp((mouseX - trackBar.AbsolutePosition.X) / trackBar.AbsoluteSize.X, 0, 1)
                    value = math.floor(mn + (mx - mn) * rel)
                    if flag then ZypheraxUI.Flags[flag] = value end
                    valLbl.Text = tostring(value) .. suffix
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    pcall(cb, value)
                end

                local sDragging = false
                track(btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        sDragging = true
                        updateSlider(inp.Position.X)
                    end
                end))
                track(UIS.InputChanged:Connect(function(inp)
                    if sDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                        updateSlider(inp.Position.X)
                    end
                end))
                track(UIS.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        sDragging = false
                    end
                end))

                local ret = {
                    Set = function(_, v)
                        v = math.clamp(v, mn, mx)
                        value = v
                        local r = (v - mn) / math.max(mx - mn, 1)
                        fill.Size = UDim2.new(r, 0, 1, 0)
                        valLbl.Text = tostring(v) .. suffix
                        pcall(cb, v)
                    end,
                    Get = function() return value end
                }
                if flag then ZypheraxUI.Controls[flag] = ret end
                return ret
            end
            SectionObj.Slider = SectionObj.CreateSlider

            -- // DROPDOWN \ --
            function SectionObj:CreateDropdown(cfg)
                local nm      = cfg.Name or "Dropdown"
                local items   = cfg.Options or cfg.Items or {}
                local default = cfg.Default or (items[1] or "")
                local cb      = cfg.Callback or function() end
                local selected = default
                local isOpen  = false

                local base, stroke = makeBase(36)

                local lbl = U.New("TextLabel", {
                    Text = nm .. ": " .. tostring(selected),
                    Font = T.FontRegular,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -40, 0, 36),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                local chevron = U.New("TextLabel", {
                    Text = "▼",
                    Font = T.FontBold,
                    TextSize = 10,
                    TextColor3 = T.TextMuted,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -26, 0, 0),
                    Size = UDim2.new(0, 20, 0, 36),
                    ZIndex = 6,
                    Parent = base
                })

                local listFrame = U.New("Frame", {
                    Size = UDim2.new(1, -16, 0, 0),
                    Position = UDim2.new(0, 8, 0, 38),
                    BackgroundColor3 = T.Surface3,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 7,
                    Parent = base
                })
                U.Corner(listFrame, T.CornerSm)
                local dLayout = U.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = listFrame })

                local function rebuild()
                    for _, c in ipairs(listFrame:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for _, it in ipairs(items) do
                        local iBtn = U.New("TextButton", {
                            Size = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = (it == selected) and T.Accent or T.Surface3,
                            BackgroundTransparency = (it == selected) and 0.4 or 1,
                            Text = tostring(it),
                            Font = T.FontRegular,
                            TextSize = 11,
                            TextColor3 = (it == selected) and T.Accent or T.Text,
                            ZIndex = 8,
                            Parent = listFrame
                        })
                        U.Corner(iBtn, UDim.new(0, 4))
                        track(iBtn.MouseButton1Click:Connect(function()
                            selected = it
                            lbl.Text = nm .. ": " .. tostring(selected)
                            isOpen = false
                            listFrame.Visible = false
                            U.Tween(base, 0.2, { Size = UDim2.new(1, 0, 0, 36) })
                            chevron.Text = "▼"
                            pcall(cb, selected)
                            rebuild()
                        end))
                    end
                end
                rebuild()

                local toggleBtn = U.New("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", ZIndex = 9, Parent = base })
                track(toggleBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        listFrame.Visible = true
                        local h = #items * 28 + 4
                        U.Tween(base, 0.2, { Size = UDim2.new(1, 0, 0, 42 + h) })
                        U.Tween(listFrame, 0.2, { Size = UDim2.new(1, -16, 0, h) })
                        chevron.Text = "▲"
                    else
                        U.Tween(base, 0.2, { Size = UDim2.new(1, 0, 0, 36) })
                        U.Tween(listFrame, 0.2, { Size = UDim2.new(1, -16, 0, 0) }).Completed:Connect(function()
                            listFrame.Visible = false
                        end)
                        chevron.Text = "▼"
                    end
                end))

                return {
                    Set = function(_, v)
                        selected = v
                        lbl.Text = nm .. ": " .. tostring(selected)
                        pcall(cb, selected)
                        rebuild()
                    end,
                    Get = function() return selected end
                }
            end
            SectionObj.Dropdown = SectionObj.CreateDropdown

            -- // BUTTON \ --
            function SectionObj:CreateButton(cfg)
                local nm = type(cfg) == "table" and (cfg.Name or cfg.Text) or tostring(cfg)
                local cb = type(cfg) == "table" and cfg.Callback or function() end

                local base, stroke = makeBase(34, true)
                local lbl = U.New("TextLabel", {
                    Text = nm,
                    Font = T.FontBold,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                track(base.MouseEnter:Connect(function()
                    U.Tween(base, 0.15, { BackgroundColor3 = T.Surface3 })
                    U.Tween(stroke, 0.15, { Color = T.Accent })
                end))
                track(base.MouseLeave:Connect(function()
                    U.Tween(base, 0.2, { BackgroundColor3 = T.Surface2 })
                    U.Tween(stroke, 0.2, { Color = T.Stroke })
                end))
                track(base.MouseButton1Click:Connect(function()
                    U.Ripple(base, Player:GetMouse().X, Player:GetMouse().Y)
                    pcall(cb)
                end))

                return {
                    SetText = function(_, t) lbl.Text = tostring(t) end
                }
            end
            SectionObj.Button = SectionObj.CreateButton

            -- // INPUT \ --
            function SectionObj:CreateInput(cfg)
                local nm      = cfg.Name or "Input"
                local ph      = cfg.Placeholder or "Ketik..."
                local default = cfg.Default or ""
                local cb      = cfg.Callback or function() end

                local base, stroke = makeBase(36)

                local lbl = U.New("TextLabel", {
                    Text = nm,
                    Font = T.FontRegular,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(0.45, 0, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                local box = U.New("TextBox", {
                    Text = default,
                    PlaceholderText = ph,
                    Font = T.FontRegular,
                    TextSize = 11,
                    TextColor3 = T.Text,
                    PlaceholderColor3 = T.TextDim,
                    BackgroundColor3 = T.Surface3,
                    Position = UDim2.new(0.48, 0, 0.5, -12),
                    Size = UDim2.new(0.5, -6, 0, 24),
                    ClearTextOnFocus = false,
                    ZIndex = 6,
                    Parent = base
                })
                U.Corner(box, UDim.new(0, 4))
                local bStroke = U.Stroke(box, T.Stroke, 1, 0)

                track(box.FocusLost:Connect(function(enter)
                    pcall(cb, box.Text, enter)
                end))

                return {
                    Set = function(_, v) box.Text = tostring(v) end,
                    Get = function() return box.Text end
                }
            end
            SectionObj.Input = SectionObj.CreateInput

            -- // LABEL \ --
            function SectionObj:CreateLabel(textOrCfg)
                local txt = type(textOrCfg) == "table" and (textOrCfg.Name or textOrCfg.Text or textOrCfg[1]) or tostring(textOrCfg)
                local lbl = U.New("TextLabel", {
                    Text = txt,
                    Font = T.FontRegular,
                    TextSize = 11,
                    TextColor3 = T.TextMuted,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 5,
                    Parent = secContainer
                })
                U.New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = lbl })
                return {
                    Set = function(_, t) lbl.Text = tostring(t) end
                }
            end
            SectionObj.Label = SectionObj.CreateLabel

            -- // KEYBIND \ --
            function SectionObj:CreateKeybind(cfg)
                local nm      = cfg.Name or "Keybind"
                local default = cfg.Default or Enum.KeyCode.RightControl
                local cb      = cfg.Callback or function() end
                local current = default
                local binding = false

                local base, stroke = makeBase(36)

                local lbl = U.New("TextLabel", {
                    Text = nm,
                    Font = T.FontRegular,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -85, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 6,
                    Parent = base
                })

                local badge = U.New("TextButton", {
                    Text = current.Name,
                    Font = T.FontBold,
                    TextSize = 11,
                    TextColor3 = T.Accent,
                    BackgroundColor3 = T.Surface3,
                    Position = UDim2.new(1, -72, 0.5, -11),
                    Size = UDim2.new(0, 64, 0, 22),
                    ZIndex = 6,
                    Parent = base
                })
                U.Corner(badge, UDim.new(0, 4))
                local bStroke = U.Stroke(badge, T.Stroke, 1, 0)

                local bindConn = nil
                track(badge.MouseButton1Click:Connect(function()
                    binding = true
                    badge.Text = "..."
                    bStroke.Color = T.Accent
                    if bindConn then bindConn:Disconnect() end
                    bindConn = UIS.InputBegan:Connect(function(inp, gp)
                        if gp then return end
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            binding = false
                            current = inp.KeyCode
                            badge.Text = current.Name
                            bStroke.Color = T.Stroke
                            if bindConn then bindConn:Disconnect(); bindConn = nil end
                            pcall(cb, current)
                        end
                    end)
                end))

                return {
                    Set = function(_, k) current = k; badge.Text = k.Name end,
                    Get = function() return current end
                }
            end
            SectionObj.Keybind = SectionObj.CreateKeybind

            -- // BUILT-IN CONFIG MANAGER SYSTEM (Matching Image 4 & 5) \ --
            function SectionObj:CreateConfigSystem()
                local FOLDER = "ZypheraxHub"
                local CONFIGS_FOLDER = FOLDER .. "/Configs"
                local AUTOLOAD_FILE = FOLDER .. "/autoload.txt"

                pcall(function()
                    if makefolder and isfolder then
                        if not isfolder(FOLDER) then makefolder(FOLDER) end
                        if not isfolder(CONFIGS_FOLDER) then makefolder(CONFIGS_FOLDER) end
                    end
                end)

                local selectedSave = nil
                local deleteMode = false

                -- Header row with icon + "Config"
                local confBox = U.New("Frame", {
                    Name = "ConfigManager",
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = T.Surface,
                    BackgroundTransparency = 0.3,
                    ZIndex = 5,
                    Parent = secContainer
                })
                U.Corner(confBox, T.CornerMd)
                U.Stroke(confBox, T.Stroke, 1, 0.4)
                local pad = U.New("UIPadding", {
                    PaddingTop = UDim.new(0, 10),
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 10),
                    PaddingRight = UDim.new(0, 10),
                    Parent = confBox
                })
                local cLayout = U.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = confBox })

                -- Title
                local topRow = U.New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = confBox })
                U.New("TextLabel", {
                    Text = "⚙  Config Manager",
                    Font = T.FontBold,
                    TextSize = 13,
                    TextColor3 = T.Accent,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -20, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = topRow
                })

                -- Search box ("Search Saves Loader...")
                local searchBox = U.New("TextBox", {
                    PlaceholderText = "Search Saves Loader...",
                    Font = T.FontRegular,
                    TextSize = 11,
                    TextColor3 = T.Text,
                    PlaceholderColor3 = T.TextDim,
                    BackgroundColor3 = T.Surface2,
                    Size = UDim2.new(1, 0, 0, 28),
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = confBox
                })
                U.Corner(searchBox, UDim.new(0, 5))
                U.Stroke(searchBox, T.Stroke, 1, 0)
                U.New("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = searchBox })

                -- Saves list container
                local saveListFrame = U.New("ScrollingFrame", {
                    Size = UDim2.new(1, 0, 0, 110),
                    BackgroundColor3 = T.Background2,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = T.Accent,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ClipsDescendants = true,
                    Parent = confBox
                })
                U.Corner(saveListFrame, UDim.new(0, 6))
                U.Stroke(saveListFrame, T.Stroke, 1, 0.2)
                local sListLayout = U.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = saveListFrame })
                U.New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = saveListFrame })

                local emptyLbl = U.New("TextLabel", {
                    Text = "+",
                    Font = T.FontBold,
                    TextSize = 22,
                    TextColor3 = T.TextDim,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Visible = true,
                    Parent = saveListFrame
                })

                -- Input box ("Enter save name...")
                local nameInput = U.New("TextBox", {
                    PlaceholderText = "Enter save name...",
                    Font = T.FontRegular,
                    TextSize = 11,
                    TextColor3 = T.Text,
                    PlaceholderColor3 = T.TextDim,
                    BackgroundColor3 = T.Surface2,
                    Size = UDim2.new(1, 0, 0, 28),
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = confBox
                })
                U.Corner(nameInput, UDim.new(0, 5))
                U.Stroke(nameInput, T.Stroke, 1, 0)
                U.New("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = nameInput })

                local function getConfigFiles()
                    local t = {}
                    pcall(function()
                        if listfiles and isfolder and isfolder(CONFIGS_FOLDER) then
                            for _, f in ipairs(listfiles(CONFIGS_FOLDER)) do
                                local bName = f:gsub("\\", "/"):match("([^/]+)%.json$")
                                if bName then table.insert(t, bName) end
                            end
                        end
                    end)
                    return t
                end

                local function refreshSaveList(filterText)
                    filterText = (filterText or ""):lower()
                    for _, c in ipairs(saveListFrame:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    local allSaves = getConfigFiles()
                    local count = 0
                    for _, sName in ipairs(allSaves) do
                        if filterText == "" or sName:lower():find(filterText) then
                            count = count + 1
                            local isSel = (sName == selectedSave)
                            local sBtn = U.New("TextButton", {
                                Size = UDim2.new(1, 0, 0, 24),
                                BackgroundColor3 = isSel and T.Accent or T.Surface3,
                                BackgroundTransparency = isSel and 0.3 or 0.7,
                                Text = "  " .. sName,
                                Font = isSel and T.FontBold or T.FontRegular,
                                TextSize = 11,
                                TextColor3 = isSel and T.Accent or T.Text,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 6,
                                Parent = saveListFrame
                            })
                            U.Corner(sBtn, UDim.new(0, 4))
                            sBtn.MouseButton1Click:Connect(function()
                                if deleteMode then
                                    pcall(function()
                                        if delfile then delfile(CONFIGS_FOLDER .. "/" .. sName .. ".json") end
                                    end)
                                    if selectedSave == sName then selectedSave = nil end
                                    refreshSaveList(searchBox.Text)
                                    ZypheraxUI:Notify({ Title = "Config", Description = "Save '" .. sName .. "' dihapus." })
                                else
                                    selectedSave = sName
                                    nameInput.Text = sName
                                    refreshSaveList(searchBox.Text)
                                    -- Auto load this save
                                    pcall(function()
                                        if readfile and isfile and isfile(CONFIGS_FOLDER .. "/" .. sName .. ".json") then
                                            local raw = readfile(CONFIGS_FOLDER .. "/" .. sName .. ".json")
                                            local data = HttpService:JSONDecode(raw)
                                            for fKey, val in pairs(data) do
                                                if ZypheraxUI.Controls[fKey] and ZypheraxUI.Controls[fKey].Set then
                                                    ZypheraxUI.Controls[fKey]:Set(val)
                                                end
                                            end
                                            ZypheraxUI:Notify({ Title = "Config Loaded", Description = "Konfigurasi '" .. sName .. "' diterapkan!" })
                                        end
                                    end)
                                end
                            end)
                        end
                    end
                    emptyLbl.Visible = (count == 0)
                end

                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    refreshSaveList(searchBox.Text)
                end)

                -- Button Grid (2 rows of 2 buttons + 1 full button)
                local grid1 = U.New("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = confBox })
                local grid1Layout = U.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = grid1 })

                local function makeGridBtn(parent, text, onClick)
                    local btn = U.New("TextButton", {
                        Size = UDim2.new(0.5, -4, 1, 0),
                        BackgroundColor3 = T.Surface2,
                        Text = text,
                        Font = T.FontBold,
                        TextSize = 11,
                        TextColor3 = T.Text,
                        ZIndex = 6,
                        Parent = parent
                    })
                    U.Corner(btn, UDim.new(0, 5))
                    U.Stroke(btn, T.Stroke, 1, 0)
                    btn.MouseButton1Click:Connect(function()
                        U.Ripple(btn, Player:GetMouse().X, Player:GetMouse().Y)
                        if onClick then onClick() end
                    end)
                    return btn
                end

                -- Create Save
                makeGridBtn(grid1, "Create Save", function()
                    local sName = nameInput.Text
                    if not sName or sName == "" then
                        ZypheraxUI:Notify({ Title = "Config", Description = "Nama save tidak boleh kosong!" })
                        return
                    end
                    pcall(function()
                        local toSave = {}
                        for k, v in pairs(ZypheraxUI.Flags) do toSave[k] = v end
                        local json = HttpService:JSONEncode(toSave)
                        if writefile then
                            writefile(CONFIGS_FOLDER .. "/" .. sName .. ".json", json)
                            ZypheraxUI:Notify({ Title = "Config Saved", Description = "Save '" .. sName .. "' berhasil dibuat!" })
                            selectedSave = sName
                            refreshSaveList(searchBox.Text)
                        end
                    end)
                end)

                -- Delete Mode Button
                local delBtn
                delBtn = makeGridBtn(grid1, "Delete Mode: OFF", function()
                    deleteMode = not deleteMode
                    delBtn.Text = "Delete Mode: " .. (deleteMode and "ON" or "OFF")
                    delBtn.TextColor3 = deleteMode and T.Error or T.Text
                end)

                local grid2 = U.New("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = confBox })
                local grid2Layout = U.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = grid2 })

                -- Overwrite
                makeGridBtn(grid2, "Overwrite", function()
                    local sName = selectedSave or nameInput.Text
                    if not sName or sName == "" then
                        ZypheraxUI:Notify({ Title = "Config", Description = "Pilih config untuk ditimpa!" })
                        return
                    end
                    pcall(function()
                        local toSave = {}
                        for k, v in pairs(ZypheraxUI.Flags) do toSave[k] = v end
                        local json = HttpService:JSONEncode(toSave)
                        if writefile then
                            writefile(CONFIGS_FOLDER .. "/" .. sName .. ".json", json)
                            ZypheraxUI:Notify({ Title = "Config Overwritten", Description = "Save '" .. sName .. "' diperbarui!" })
                        end
                    end)
                end)

                -- Set Autoload
                makeGridBtn(grid2, "Set Autoload", function()
                    local sName = selectedSave or nameInput.Text
                    if not sName or sName == "" then
                        ZypheraxUI:Notify({ Title = "Config", Description = "Pilih save untuk Autoload!" })
                        return
                    end
                    pcall(function()
                        if writefile then
                            writefile(AUTOLOAD_FILE, sName)
                            ZypheraxUI:Notify({ Title = "Autoload", Description = "Autoload diset ke: " .. sName })
                        end
                    end)
                end)

                -- Reset Autoload (Full Width)
                local resetBtn = U.New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = T.Surface2,
                    Text = "Reset Autoload",
                    Font = T.FontBold,
                    TextSize = 11,
                    TextColor3 = T.TextMuted,
                    ZIndex = 6,
                    Parent = confBox
                })
                U.Corner(resetBtn, UDim.new(0, 5))
                U.Stroke(resetBtn, T.Stroke, 1, 0)
                resetBtn.MouseButton1Click:Connect(function()
                    U.Ripple(resetBtn, Player:GetMouse().X, Player:GetMouse().Y)
                    pcall(function()
                        if delfile and isfile and isfile(AUTOLOAD_FILE) then
                            delfile(AUTOLOAD_FILE)
                            ZypheraxUI:Notify({ Title = "Autoload", Description = "Autoload direset (dimatikan)." })
                        end
                    end)
                end)

                refreshSaveList("")
            end

            return SectionObj
        end

        return TabObj
    end

    return Win
end

return ZypheraxUI
