local Services = {
    Players      = game:GetService("Players"),
    TweenService = game:GetService("TweenService"),
    UserInput    = game:GetService("UserInputService"),
    StarterGui   = game:GetService("StarterGui"),
}

local LocalPlayer = Services.Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 5)

local isActive    = false
local loopThread  = nil
local connections = {}

local function disableIdleConnections()
    if getconnections then
        local list = getconnections(LocalPlayer.Idled)
        for _, connection in pairs(list) do
            pcall(function() connection:Disable() end)
            pcall(function() connection:Disconnect() end)
            pcall(function() connection.Enabled = false end)
        end
        return #list
    end
    return 0
end

local function startAntiAFK()
    isActive = true
    disableIdleConnections()
    loopThread = task.spawn(function()
        while isActive and task.wait(30) do
            disableIdleConnections()
        end
    end)
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title    = "Anti AFK",
            Text     = "Anti AFK is now ACTIVE",
            Duration = 3,
        })
    end)
end

local function stopAntiAFK()
    isActive = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title    = "Anti AFK",
            Text     = "Anti AFK is now OFF",
            Duration = 3,
        })
    end)
end

local function cleanupConnections()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFKGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 95)
Frame.Position = UDim2.new(0, 20, 1, -115)
Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local Stroke = Instance.new("UIStroke", Frame)
Stroke.Color = Color3.fromRGB(55, 55, 75)
Stroke.Thickness = 1

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 32)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🛡️  Anti AFK"
Title.TextColor3 = Color3.fromRGB(210, 210, 230)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold

local StatusLabel = Instance.new("TextLabel", Frame)
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Position = UDim2.new(0, 0, 0, 30)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: OFF ❌"
StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham

local Button = Instance.new("TextButton", Frame)
Button.Size = UDim2.new(0, 165, 0, 30)
Button.Position = UDim2.new(0.5, -82, 0, 56)
Button.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
Button.Text = "ENABLE"
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.TextSize = 12
Button.Font = Enum.Font.GothamBold
Button.BorderSizePixel = 0
Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 6)

local function tween(obj, props, dur)
    Services.TweenService:Create(obj, TweenInfo.new(dur or 0.25), props):Play()
end

local conn = Button.MouseButton1Click:Connect(function()
    if not isActive then
        startAntiAFK()
        tween(Button, { BackgroundColor3 = Color3.fromRGB(40, 190, 90) })
        tween(Frame,  { BackgroundColor3 = Color3.fromRGB(10, 22, 12) })
        Stroke.Color = Color3.fromRGB(40, 170, 70)
        Button.Text = "DISABLE"
        StatusLabel.Text = "Status: ON ✅"
        StatusLabel.TextColor3 = Color3.fromRGB(60, 240, 110)
    else
        stopAntiAFK()
        tween(Button, { BackgroundColor3 = Color3.fromRGB(200, 60, 60) })
        tween(Frame,  { BackgroundColor3 = Color3.fromRGB(12, 12, 18) })
        Stroke.Color = Color3.fromRGB(55, 55, 75)
        Button.Text = "ENABLE"
        StatusLabel.Text = "Status: OFF ❌"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
    end
end)
table.insert(connections, conn)

local dragging = false
local dragOffsetX, dragOffsetY = 0, 0

local dc1 = Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragOffsetX = input.Position.X - Frame.AbsolutePosition.X
        dragOffsetY = input.Position.Y - Frame.AbsolutePosition.Y
    end
end)

local dc2 = Services.UserInput.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        Frame.Position = UDim2.new(0, input.Position.X - dragOffsetX, 0, input.Position.Y - dragOffsetY)
    end
end)

local dc3 = Services.UserInput.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

table.insert(connections, dc1)
table.insert(connections, dc2)
table.insert(connections, dc3)

ScreenGui.AncestryChanged:Connect(function()
    if not ScreenGui.Parent then
        stopAntiAFK()
        cleanupConnections()
    end
end)
