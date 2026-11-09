-- LocalScript in StarterGui
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============ FORCE CLEANUP OLD SCRIPTS ============
if _G.DaCheat_Cleanup then
    _G.DaCheat_Cleanup()
    _G.DaCheat_Cleanup = nil
end

local oldNames = {"DaCheat", "DarkPanel", "CamFollowGui", "ESP_Container"}
for _, gui in ipairs(playerGui:GetChildren()) do
    for _, name in ipairs(oldNames) do
        if gui.Name == name then
            gui:Destroy()
            break
        end
    end
end
local oldEsp = workspace:FindFirstChild("ESP_Container")
if oldEsp then oldEsp:Destroy() end

-- ESP Container
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP_Container"
espFolder.Parent = workspace

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DaCheat"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483647 -- Максимальный приоритет (выше CoreGui)
screenGui.Parent = playerGui

-- ============ COLORS ============
local PANEL_COLOR = Color3.fromRGB(20, 20, 22) 
local BTN_COLOR = Color3.fromRGB(35, 35, 38)   
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TEXT_COLOR_DIM = Color3.fromRGB(180, 180, 180)
local BTN_ACTIVE_COLOR = Color3.fromRGB(0, 140, 70)
local ESP_COLOR = Color3.fromRGB(220, 220, 220)

-- ============ STATE ============
local SMOOTH = 0.15
local following = false
local cameraConnection
local render3DEnabled = true
local espEnabled = false
local espConnections = {}

local infJumpEnabled = false
local flyEnabled = false
local flyConnection
local flySpeed = 50
local bodyVelocity

-- ============ ESP LOGIC ============
local function createESP(targetPlayer)
    if targetPlayer == player then return end
    if not targetPlayer.Character then return end
    if espFolder:FindFirstChild(targetPlayer.Name .. "_Box") then return end

    local char = targetPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = targetPlayer.Name .. "_Box"
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = Vector3.new(4, 6, 2)
    box.Transparency = 0.5
    box.Color3 = ESP_COLOR
    box.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = targetPlayer.Name .. "_Text"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = espFolder

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = targetPlayer.Name
    text.TextColor3 = ESP_COLOR
    text.TextStrokeTransparency = 0
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.Parent = billboard

    local connection = RunService.RenderStepped:Connect(function()
        if hrp and hrp.Parent then box.Adornee = hrp end
    end)

    espConnections[targetPlayer] = { box = box, billboard = billboard, connection = connection }
end

local function removeESP(targetPlayer)
    local box = espFolder:FindFirstChild(targetPlayer.Name .. "_Box")
    if box then box:Destroy() end
    local text = espFolder:FindFirstChild(targetPlayer.Name .. "_Text")
    if text then text:Destroy() end
    
    if espConnections[targetPlayer] then
        if espConnections[targetPlayer].connection then espConnections[targetPlayer].connection:Disconnect() end
        espConnections[targetPlayer] = nil
    end
end

local function toggleESP(state)
    espEnabled = state
    if espEnabled then
        for _, child in ipairs(espFolder:GetChildren()) do child:Destroy() end
        for _, data in pairs(espConnections) do
            if type(data) == "table" and data.connection then data.connection:Disconnect() end
        end
        espConnections = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                createESP(p)
                p.CharacterAdded:Connect(function()
                    if espEnabled then
                        removeESP(p)
                        task.wait(0.5)
                        createESP(p)
                    end
                end)
            end
        end

        espConnections["PlayerAdded"] = Players.PlayerAdded:Connect(function(newPlayer)
            if espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function()
                    if espEnabled then
                        removeESP(newPlayer)
                        task.wait(0.5)
                        createESP(newPlayer)
                    end
                end)
                if newPlayer.Character then createESP(newPlayer) end
            end
        end)
        
        espConnections["PlayerRemoving"] = Players.PlayerRemoving:Connect(function(leavingPlayer)
            removeESP(leavingPlayer)
        end)
    else
        for _, data in pairs(espConnections) do
            if type(data) == "table" and data.connection then
                data.connection:Disconnect()
            elseif type(data) == "RBXScriptConnection" then
                data:Disconnect()
            end
        end
        espConnections = {}
        for _, child in ipairs(espFolder:GetChildren()) do child:Destroy() end
    end
end

-- ============ CAMERA LOGIC ============
local function startFollowing()
    if cameraConnection then return end
    cameraConnection = RunService.RenderStepped:Connect(function()
        local character = player.Character
        if not character or not character.Parent then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local bodyLook = root.CFrame.LookVector
        local flatLook = Vector3.new(bodyLook.X, 0, bodyLook.Z)
        if flatLook.Magnitude < 0.001 then return end
        local targetYaw = math.atan2(-flatLook.X, -flatLook.Z)

        local rx, ry, rz = workspace.CurrentCamera.CFrame:ToOrientation()
        local diff = (targetYaw - ry + math.pi) % (2 * math.pi) - math.pi
        local newYaw = ry + diff * SMOOTH

        workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position)
            * CFrame.fromOrientation(rx, newYaw, rz)
    end)
end

local function stopFollowing()
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
end

-- ============ FLY & INF JUMP LOGIC ============
local jumpConnection = UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

local function stopFly()
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Velocity = Vector3.new(0, 0, 0)
        end
    end
end

local function startFly()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "FlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp

    flyConnection = RunService.RenderStepped:Connect(function()
        local currentChar = player.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local hum = currentChar and currentChar:FindFirstChild("Humanoid")
        
        if not currentHrp or not hum then return end

        local moveDir = hum.MoveDirection
        local camera = workspace.CurrentCamera
        
        if moveDir.Magnitude > 0 then
            local cameraLocalDir = camera.CFrame:VectorToObjectSpace(moveDir)
            
            bodyVelocity.Velocity = (
                camera.CFrame.LookVector * -cameraLocalDir.Z + 
                camera.CFrame.RightVector * cameraLocalDir.X
            ) * flySpeed
        else
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ============ MAIN PANEL ============
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 520)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = PANEL_COLOR
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.ClipsDescendants = true
mainFrame.Visible = false
mainFrame.ZIndex = 1
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = PANEL_COLOR
header.BackgroundTransparency = 0
header.BorderSizePixel = 0
header.ZIndex = 2
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "DaCheat"
title.TextColor3 = TEXT_COLOR
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 11)
closeBtn.BackgroundColor3 = BTN_COLOR
closeBtn.BackgroundTransparency = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = TEXT_COLOR_DIM
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 3
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Content (Scrollable Frame)
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Size = UDim2.new(1, -30, 1, -70)
content.Position = UDim2.new(0, 15, 0, 60)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 0
content.ZIndex = 2
content.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = content

-- ============ BUTTON FACTORY ============
local function createButton(text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = BTN_COLOR
    btn.BackgroundTransparency = 0
    btn.Text = text
    btn.TextColor3 = TEXT_COLOR_DIM
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamMedium
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 3
    btn.Parent = content

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(60, 60, 65)
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.5
    btnStroke.Parent = btn

    btn.MouseEnter:Connect(function() 
        btn.TextColor3 = TEXT_COLOR 
        if btn.BackgroundColor3 ~= BTN_ACTIVE_COLOR then
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        end
    end)
    btn.MouseLeave:Connect(function() 
        btn.TextColor3 = TEXT_COLOR_DIM 
        if btn.BackgroundColor3 ~= BTN_ACTIVE_COLOR then
            btn.BackgroundColor3 = BTN_COLOR
        end
    end)
    btn.MouseButton1Click:Connect(function() if callback then callback(btn) end end)
    return btn
end

createButton("Speed x2", 1, function()
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = 32 end
end)

createButton("Jump x2", 2, function()
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.JumpPower = 100 end
end)

createButton("Reset", 3, function()
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = 16
        char.Humanoid.JumpPower = 50
    end
end)

createButton("Camera Follow: OFF", 4, function(btn)
    following = not following
    if following then
        startFollowing()
        btn.Text = "Camera Follow: ON"
        btn.BackgroundColor3 = BTN_ACTIVE_COLOR
    else
        stopFollowing()
        btn.Text = "Camera Follow: OFF"
        btn.BackgroundColor3 = BTN_COLOR
    end
end)

createButton("3D Render: ON", 5, function(btn)
    render3DEnabled = not render3DEnabled
    local success, err = pcall(function()
        RunService:Set3dRenderingEnabled(render3DEnabled)
    end)
    
    if success then
        if render3DEnabled then
            btn.Text = "3D Render: ON"
            btn.BackgroundColor3 = BTN_COLOR
        else
            btn.Text = "3D Render: OFF"
            btn.BackgroundColor3 = BTN_ACTIVE_COLOR
        end
    else
        render3DEnabled = not render3DEnabled
        btn.Text = "3D Render: Blocked"
        btn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
    end
end)

createButton("ESP: OFF", 6, function(btn)
    if not espEnabled then
        toggleESP(true)
        btn.Text = "ESP: ON"
        btn.BackgroundColor3 = BTN_ACTIVE_COLOR
    else
        toggleESP(false)
        btn.Text = "ESP: OFF"
        btn.BackgroundColor3 = BTN_COLOR
    end
end)

createButton("Inf Jump: OFF", 7, function(btn)
    infJumpEnabled = not infJumpEnabled
    if infJumpEnabled then
        btn.Text = "Inf Jump: ON"
        btn.BackgroundColor3 = BTN_ACTIVE_COLOR
    else
        btn.Text = "Inf Jump: OFF"
        btn.BackgroundColor3 = BTN_COLOR
    end
end)

createButton("Fly: OFF", 8, function(btn)
    flyEnabled = not flyEnabled
    if flyEnabled then
        startFly()
        btn.Text = "Fly: ON"
        btn.BackgroundColor3 = BTN_ACTIVE_COLOR
    else
        stopFly()
        btn.Text = "Fly: OFF"
        btn.BackgroundColor3 = BTN_COLOR
    end
end)

content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)

-- ============ FLOATING ICON ============
local icon = Instance.new("TextButton")
icon.Name = "FloatingIcon"
icon.Size = UDim2.new(0, 52, 0, 52)
icon.Position = UDim2.new(0, 20, 0.5, -26)
icon.BackgroundColor3 = PANEL_COLOR
icon.BackgroundTransparency = 0
icon.Text = "≡"
icon.TextColor3 = TEXT_COLOR
icon.TextSize = 26
icon.Font = Enum.Font.GothamBold
icon.BorderSizePixel = 0
icon.AutoButtonColor = false
icon.ZIndex = 5
icon.AnchorPoint = Vector2.new(0, 0)
icon.Parent = screenGui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 26)
iconCorner.Parent = icon

local floatTween
local function startFloating()
    if floatTween then floatTween:Cancel() end
    floatTween = TweenService:Create(
        icon,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.new(icon.Position.X.Scale, icon.Position.X.Offset, icon.Position.Y.Scale, icon.Position.Y.Offset - 8) }
    )
    floatTween:Play()
end
startFloating()

-- ============ OPEN / CLOSE ANIMATION ============
local isOpen = false
local isAnimating = false

local function openPanel()
    if isOpen or isAnimating then return end
    isAnimating = true

    TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 30, 0, 30),
    }):Play()

    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Visible = true
    mainFrame.Size = UDim2.new(0, 260, 0, 440)
    mainFrame.BackgroundTransparency = 1
    
    for _, v in ipairs(content:GetDescendants()) do
        if v:IsA("TextButton") then 
            v.BackgroundTransparency = 1 
            v.TextTransparency = 1
        end
        if v:IsA("UIStroke") then v.Transparency = 1 end
    end

    task.wait(0.02)

    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 520), BackgroundTransparency = 0,
    }):Play()

    for _, v in ipairs(content:GetDescendants()) do
        if v:IsA("TextButton") then
            TweenService:Create(v, TweenInfo.new(0.25), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
        end
        if v:IsA("UIStroke") then
            TweenService:Create(v, TweenInfo.new(0.25), { Transparency = 0.5 }):Play()
        end
    end

    isOpen = true
    task.wait(0.35)
    isAnimating = false
end

local function closePanel()
    if not isOpen or isAnimating then return end
    isAnimating = true

    TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 260, 0, 440), BackgroundTransparency = 1,
    }):Play()

    for _, v in ipairs(content:GetDescendants()) do
        if v:IsA("TextButton") then
            TweenService:Create(v, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        end
        if v:IsA("UIStroke") then
            TweenService:Create(v, TweenInfo.new(0.2), { Transparency = 1 }):Play()
        end
    end

    task.wait(0.26)
    mainFrame.Visible = false

    TweenService:Create(icon, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0, TextTransparency = 0, Size = UDim2.new(0, 52, 0, 52),
    }):Play()

    startFloating()

    isOpen = false
    task.wait(0.2)
    isAnimating = false
end

closeBtn.MouseButton1Click:Connect(closePanel)

-- ============ DRAG ICON WITH BOUNDS ============
local iconDragging = false
local iconDragStart, iconStartPos, iconMoved = false, nil, nil, false

icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconDragging = true
        iconMoved = false
        iconDragStart = input.Position
        iconStartPos = icon.Position
        if floatTween then floatTween:Cancel() end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if iconDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - iconDragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then iconMoved = true end
        
        local viewport = workspace.CurrentCamera.ViewportSize
        local newX = math.clamp(iconStartPos.X.Offset + delta.X, 0, viewport.X - icon.AbsoluteSize.X)
        local newY = math.clamp(iconStartPos.Y.Offset + delta.Y, 0, viewport.Y - icon.AbsoluteSize.Y)
        
        icon.Position = UDim2.new(0, newX, 0, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if iconDragging then
            iconDragging = false
            if not iconMoved then
                if not isOpen then openPanel() else closePanel() end
            else
                startFloating()
            end
        end
    end
end)

-- ============ DRAG PANEL WITH BOUNDS ============
local dragging = false
local dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        
        local viewport = workspace.CurrentCamera.ViewportSize
        
        local maxX = (viewport.X / 2) - (mainFrame.AbsoluteSize.X / 2)
        local maxY = (viewport.Y / 2) - (mainFrame.AbsoluteSize.Y / 2)
        local minX = -(viewport.X / 2) + (mainFrame.AbsoluteSize.X / 2)
        local minY = -(viewport.Y / 2) + (mainFrame.AbsoluteSize.Y / 2)
        
        newX = math.clamp(newX, minX, maxX)
        newY = math.clamp(newY, minY, maxY)
        
        mainFrame.Position = UDim2.new(0.5, newX, 0.5, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============ REGISTER CLEANUP FUNCTION ============
_G.DaCheat_Cleanup = function()
    stopFollowing()
    stopFly()
    if jumpConnection then jumpConnection:Disconnect() end
    if espEnabled then toggleESP(false) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    local folder = workspace:FindFirstChild("ESP_Container")
    if folder then folder:Destroy() end
    if screenGui then screenGui:Destroy() end
end
