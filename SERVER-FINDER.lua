if not game:IsLoaded() then 
    game.Loaded:Wait() 
end

-- Constants
local GAME_ID = 126884695634066
local TARGET_VERSION = 1233
local BLOODMOON_POSITION = Vector3.new(-83.157, 0.3, -11.295)
local HOP_COOLDOWN = 5
local NOTIFICATION_DURATION = 6

-- Services
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Global variables
local lastHopAttempt = 0
local notificationSystem = nil
local isWaitingForBloodMoon = false

-- Initialize notification system
local function initializeNotifications()
    if notificationSystem then return end
    
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://paste.ee/r/E9tFZ/0"))()
    end)
    
    if success then
        notificationSystem = result
    else
        warn("Failed to load notification system:", result)
    end
end

-- Notification function
local function notify(title, content)
    if notificationSystem then
        notificationSystem:MakeNotification({
            Name = title,
            Content = content,
            Image = "rbxassetid://4483345998",
            Time = NOTIFICATION_DURATION
        })
    else
        print(title .. ": " .. content)
    end
end

-- Enhanced prompt function with better error handling
local function createPrompt(title, text)
    local screenGui = Instance.new("ScreenGui")
    local frame = Instance.new("Frame")
    local uiGradient = Instance.new("UIGradient")
    local uiCorner = Instance.new("UICorner")
    local titleLabel = Instance.new("TextLabel")
    local divider = Instance.new("Frame")
    local messageLabel = Instance.new("TextLabel")
    local buttonHolder = Instance.new("Frame")
    local yesButton = Instance.new("TextButton")
    local yesCorner = Instance.new("UICorner")
    local noButton = Instance.new("TextButton")
    local noCorner = Instance.new("UICorner")
    local closeButton = Instance.new("TextButton")
    local closeCorner = Instance.new("UICorner")
    local glow = Instance.new("ImageLabel")

    -- Setup ScreenGui
    screenGui.Name = "BloodmoonPrompt"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    
    local success, parent = pcall(function()
        return game:GetService("CoreGui")
    end)
    
    if not success then
        parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    screenGui.Parent = parent

    -- Setup Frame with improved styling
    frame.Parent = screenGui
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, 380, 0, 240)
    frame.ZIndex = 2

    -- Gradient
    uiGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
    })
    uiGradient.Rotation = 90
    uiGradient.Parent = frame

    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = frame

    -- Title
    titleLabel.Name = "Title"
    titleLabel.Parent = frame
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 0, 0, 15)
    titleLabel.Size = UDim2.new(0.85, 0, 0, 30)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(220, 90, 90)
    titleLabel.TextSize = 18
    titleLabel.TextTransparency = 0.1
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center

    -- Close button
    closeButton.Name = "CloseButton"
    closeButton.Parent = frame
    closeButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
    closeButton.Position = UDim2.new(0.88, 0, 0.02, 0)
    closeButton.Size = UDim2.new(0.1, 0, 0, 25)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(220, 90, 90)
    closeButton.TextSize = 14

    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton

    -- Divider
    divider.Name = "Divider"
    divider.Parent = frame
    divider.BackgroundColor3 = Color3.fromRGB(220, 90, 90)
    divider.BorderSizePixel = 0
    divider.Position = UDim2.new(0.1, 0, 0.2, 0)
    divider.Size = UDim2.new(0.8, 0, 0, 1)
    divider.ZIndex = 3

    -- Message
    messageLabel.Name = "Message"
    messageLabel.Parent = frame
    messageLabel.BackgroundTransparency = 1
    messageLabel.Position = UDim2.new(0.1, 0, 0.25, 0)
    messageLabel.Size = UDim2.new(0.8, 0, 0.4, 0)
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.Text = text
    messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    messageLabel.TextSize = 14
    messageLabel.TextWrapped = true
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top

    -- Button holder
    buttonHolder.Name = "ButtonHolder"
    buttonHolder.Parent = frame
    buttonHolder.BackgroundTransparency = 1
    buttonHolder.Position = UDim2.new(0.1, 0, 0.7, 0)
    buttonHolder.Size = UDim2.new(0.8, 0, 0, 45)

    -- Yes button
    yesButton.Name = "YesButton"
    yesButton.Parent = buttonHolder
    yesButton.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
    yesButton.Position = UDim2.new(0, 0, 0, 0)
    yesButton.Size = UDim2.new(0.45, 0, 1, 0)
    yesButton.Font = Enum.Font.GothamBold
    yesButton.Text = "YES"
    yesButton.TextColor3 = Color3.fromRGB(240, 240, 240)
    yesButton.TextSize = 14

    yesCorner.CornerRadius = UDim.new(0, 8)
    yesCorner.Parent = yesButton

    -- No button
    noButton.Name = "NoButton"
    noButton.Parent = buttonHolder
    noButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    noButton.Position = UDim2.new(0.55, 0, 0, 0)
    noButton.Size = UDim2.new(0.45, 0, 1, 0)
    noButton.Font = Enum.Font.GothamBold
    noButton.Text = "NO"
    noButton.TextColor3 = Color3.fromRGB(240, 240, 240)
    noButton.TextSize = 14

    noCorner.CornerRadius = UDim.new(0, 8)
    noCorner.Parent = noButton

    -- Glow effect
    glow.Name = "Glow"
    glow.Parent = frame
    glow.BackgroundTransparency = 1
    glow.BorderSizePixel = 0
    glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
    glow.Size = UDim2.new(1.2, 0, 1.2, 0)
    glow.ZIndex = 1
    glow.Image = "rbxassetid://5028857084"
    glow.ImageColor3 = Color3.fromRGB(220, 90, 90)
    glow.ScaleType = Enum.ScaleType.Slice
    glow.SliceCenter = Rect.new(24, 24, 276, 276)
    glow.SliceScale = 0.24
    glow.ImageTransparency = 0.8

    -- Handle user choice
    local choice = nil
    local connections = {}

    connections[1] = yesButton.MouseButton1Click:Connect(function()
        choice = true
        screenGui:Destroy()
    end)

    connections[2] = noButton.MouseButton1Click:Connect(function()
        choice = false
        screenGui:Destroy()
    end)

    connections[3] = closeButton.MouseButton1Click:Connect(function()
        choice = false
        screenGui:Destroy()
    end)

    -- Wait for response or cleanup
    local timeout = 0
    while screenGui.Parent and choice == nil and timeout < 30 do
        task.wait(0.1)
        timeout = timeout + 0.1
    end

    -- Cleanup connections
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end

    if screenGui.Parent then
        screenGui:Destroy()
    end

    return choice or false
end

-- Improved BloodMoon detection
local function checkBloodMoon()
    local success, result = pcall(function()
        local shrine = workspace.Interaction.UpdateItems:FindFirstChild("BloodMoonShrine")
        if shrine and shrine:IsA("Model") then
            local part = shrine.PrimaryPart or shrine:FindFirstChildWhichIsA("BasePart")
            if part then
                return (part.Position - BLOODMOON_POSITION).Magnitude < 0.1
            end
        end
        return false
    end)
    
    return success and result
end

-- Enhanced server hopping with better error handling
local function serverHop()
    if os.time() - lastHopAttempt < HOP_COOLDOWN then
        notify("Please Wait", "Server hop cooldown active...")
        return false
    end
    
    lastHopAttempt = os.time()

    local requestFunction = (syn and syn.request) or 
                          (http and http.request) or 
                          http_request or 
                          (fluxus and fluxus.request) or 
                          request

    if not requestFunction then 
        notify("Error", "HTTP request function not available")
        return false
    end

    notify("Searching", "Looking for available servers...")
    task.wait(math.random(1, 2))

    local success, response = pcall(function()
        return requestFunction({
            Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", GAME_ID),
            Method = "GET"
        })
    end)

    if not success then
        notify("Error", "Failed to fetch server list")
        return false
    end

    if response.StatusCode == 429 then
        notify("Rate Limited", "Please wait before trying again")
        return false
    elseif response.StatusCode ~= 200 then 
        notify("Error", "Server request failed (Code: " .. response.StatusCode .. ")")
        return false 
    end

    local parseSuccess, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not parseSuccess or not data or not data.data then 
        notify("Error", "Failed to parse server data")
        return false
    end

    local validServers = {}
    for _, server in ipairs(data.data) do
        if type(server) == "table" and 
           server.id ~= game.JobId and 
           server.playing < server.maxPlayers then
            table.insert(validServers, server.id)
        end
    end

    if #validServers > 0 then
        notify("Server Hop", "Teleporting to new server...")
        task.wait(0.5)
        
        local teleportSuccess = pcall(function()
            TeleportService:TeleportToPlaceInstance(GAME_ID, validServers[math.random(#validServers)])
        end)
        
        if not teleportSuccess then
            notify("Error", "Failed to teleport")
            return false
        end
        
        return true
    else
        notify("No Servers", "No suitable servers found")
        return false
    end
end

-- Queue script for next server
local function queueScript()
    local queueFunction = (syn and syn.queue_on_teleport) or 
                         queue_on_teleport or 
                         (fluxus and fluxus.queue_on_teleport) or 
                         function() end
    
    local scriptToQueue = [[
        if not _G.scriptExecuted then
            _G.scriptExecuted = true
            repeat task.wait() until game:IsLoaded()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/RehanDias/server-r/refs/heads/main/SERVER-FINDER.lua", true))()
        end
    ]]
    
    queueFunction(scriptToQueue)
end

-- Wait for BloodMoon with improved monitoring
local function waitForBloodMoon()
    if isWaitingForBloodMoon then return end
    
    isWaitingForBloodMoon = true
    notify("Waiting", "Monitoring for Blood Moon event...")
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if checkBloodMoon() then
            connection:Disconnect()
            isWaitingForBloodMoon = false
            notify("BLOOD MOON!", "Blood Moon event detected!")
            
            -- Load main script
            local success = pcall(function()
                loadstring(game:HttpGet("https://paste.ee/r/msCc6gVu/0", true))()
            end)
            
            if not success then
                notify("Error", "Failed to load main script")
            end
        end
    end)
end

-- Main execution logic
local function main()
    -- Validate game
    if game.PlaceId ~= GAME_ID then
        notify("Wrong Game", "This script is for Grow a Garden only!")
        return
    end

    -- Initialize systems
    initializeNotifications()
    queueScript()

    -- Check current server status
    local currentVersion = game.PlaceVersion
    local isOldVersion = currentVersion <= TARGET_VERSION
    local hasBloodMoon = checkBloodMoon()

    notify("Server Info", string.format("Version: %d | Blood Moon: %s", 
           currentVersion, hasBloodMoon and "Active" or "Inactive"))

    if isOldVersion and hasBloodMoon then
        -- Perfect server - old version with blood moon
        notify("Perfect Server!", "Old version + Blood Moon active!")
        loadstring(game:HttpGet("https://paste.ee/r/msCc6gVu/0", true))()
        
    elseif isOldVersion and not hasBloodMoon then
        -- Old server without blood moon
        notify("Old Server Found", "Version: " .. currentVersion)
        
        local shouldHop = createPrompt("OLD SERVER DETECTED", 
                                     "This is an old server but no Blood Moon is active. Would you like to server-hop to find one with Blood Moon, or wait here?")
        
        -- Load main script regardless
        pcall(function()
            loadstring(game:HttpGet("https://paste.ee/r/msCc6gVu/0", true))()
        end)
        
        if shouldHop then
            notify("Server Hopping", "Searching for better server...")
            if not serverHop() then
                task.wait(3)
                serverHop()
            end
        else
            notify("Waiting Mode", "Monitoring for Blood Moon event...")
            waitForBloodMoon()
        end
        
    elseif hasBloodMoon and not isOldVersion then
        -- New server with blood moon
        local shouldHop = createPrompt("BLOOD MOON DETECTED", 
                                     "Blood Moon is active in this new server. Would you like to search for an old server with Blood Moon instead?")
        
        if shouldHop then
            notify("Server Hopping", "Searching for old server...")
            if not serverHop() then
                task.wait(3)
                serverHop()
            end
        else
            notify("Staying", "Using current server for Blood Moon event")
            pcall(function()
                loadstring(game:HttpGet("https://paste.ee/r/msCc6gVu/0", true))()
            end)
        end
        
    else
        -- New server without blood moon
        notify("New Server", "Version: " .. currentVersion .. " - Searching for old server...")
        task.wait(1)
        
        if not serverHop() then
            task.wait(5)
            if not serverHop() then
                notify("Fallback", "Staying in current server and waiting for Blood Moon")
                waitForBloodMoon()
            end
        end
    end
end

-- Execute main function with error handling
local success, error = pcall(main)
if not success then
    warn("Script execution failed:", error)
    if notificationSystem then
        notify("Script Error", "Execution failed - check console for details")
    end
end
