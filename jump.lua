-- LocalScript (StarterPlayerScripts)
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    if not success then
        warn("Failed to get service:", serviceName)
        return nil
    end
    return service
end

local Players = safeGetService("Players")
local UserInputService = safeGetService("UserInputService")
local RunService = safeGetService("RunService")

-- CONFIGURATION
local CONFIG = {
    JUMP_FORCE_Y = 70,
    JUMP_FORCE_FORWARD = 30,
    TELEPORT_COOLDOWN = 1.0, -- Reduced cooldown for faster action
    TELEPORT_HEIGHT = 3,     -- Height above target to teleport
    TELEPORT_RANGE = 1000,   -- Maximum teleport range (0 for unlimited)
    BRING_COOLDOWN = 2.0,    -- Cooldown for bring feature
    BRING_RANGE = 1000       -- Maximum bring range
}

-- STATE
local player = Players.LocalPlayer
local character = player.Character
local humanoid
local rootPart
local state = {
    doubleJumpEnabled = false, -- Start with enhanced jump OFF
    scriptActive = true,
    lastTeleportTime = 0,
    lastBringTime = 0,
    isTeleporting = false,
    godModeEnabled = false,
    bringEnabled = false, -- New bring feature state
    isChargingJump = false,
    jumpChargeStart = 0,
    currentJumpForce = 0,
    forceField = nil
}

-- CONNECTIONS
local connections = {}

-- GUI ELEMENTS
local gui = {
    screenGui = nil,
    statusLabel = nil,
    chargeBar = nil,
    teleportFrame = nil,
    teleportInput = nil,
    playerListFrame = nil
}

-- Function to make a frame draggable
local function makeDraggable(frame)
    local isDragging = false
    local dragStart
    local startPos

    local inputBeganConn = frame:FindFirstChild("TitleBar") or frame

    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end

    local function onInputEnded(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end

    local function onInputChanged(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end

    local success1 = pcall(function()
        inputBeganConn.InputBegan:Connect(onInputBegan)
    end)

    local success2 = pcall(function()
        inputBeganConn.InputEnded:Connect(onInputEnded)
    end)

    local success3 = pcall(function()
        table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
    end)

    if not (success1 and success2 and success3) then
        warn("Failed to make frame draggable")
    end
end

-- Display notification function
local function displayNotification(message, color)
    if not gui.screenGui then return end

    local notification = Instance.new("TextLabel")
    notification.Size = UDim2.new(0, 200, 0, 30)
    notification.Position = UDim2.new(0.5, -100, 0.8, 0)
    notification.BackgroundColor3 = color or Color3.fromRGB(0, 100, 0)
    notification.BackgroundTransparency = 0.3
    notification.TextColor3 = Color3.fromRGB(255, 255, 255)
    notification.TextSize = 16
    notification.Font = Enum.Font.SourceSansBold
    notification.Text = message
    notification.Parent = gui.screenGui

    local cornerRadius = Instance.new("UICorner")
    cornerRadius.CornerRadius = UDim.new(0, 5)
    cornerRadius.Parent = notification

    game:GetService("Debris"):AddItem(notification, 2)
end

-- Teleport to player function with blink-like effect
local function teleportToPlayer(username)
    if not username or username == "" then return end

    -- Check cooldown
    local now = tick()
    if now - state.lastTeleportTime < CONFIG.TELEPORT_COOLDOWN then
        local remaining = math.ceil((CONFIG.TELEPORT_COOLDOWN - (now - state.lastTeleportTime)) * 10) / 10
        displayNotification("Teleport cooldown: " .. remaining .. "s", Color3.fromRGB(255, 150, 0))
        return
    end

    -- Prevent multiple teleports at once
    if state.isTeleporting then return end

    -- Make sure character is loaded
    if not character then
        character = player.Character
        if not character then
            displayNotification("Character not found!", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    -- Find character root part
    if not rootPart then
        rootPart = character:FindFirstChild("HumanoidRootPart") or
            character:FindFirstChild("Torso") or
            character:FindFirstChild("UpperTorso") or
            (character.PrimaryPart or nil)

        if not rootPart then
            displayNotification("Root part not found!", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    -- Find target player with improved matching
    local targetPlayer = nil
    local searchTerm = string.lower(username)
    for _, plr in pairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == searchTerm or
            string.lower(plr.DisplayName) == searchTerm or
            string.lower(plr.Name):find(searchTerm, 1, true) or
            string.lower(plr.DisplayName):find(searchTerm, 1, true) then
            targetPlayer = plr
            break
        end
    end

    if not targetPlayer then
        displayNotification("Player not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    -- Get target character and root
    local targetCharacter = targetPlayer.Character
    if not targetCharacter then
        displayNotification("Target character not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart") or
        targetCharacter:FindFirstChild("Torso") or
        targetCharacter:FindFirstChild("UpperTorso") or
        (targetCharacter.PrimaryPart or nil)

    if not targetRoot then
        displayNotification("Target root part not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    -- Check range if enabled
    if CONFIG.TELEPORT_RANGE > 0 then
        local distance = (targetRoot.Position - rootPart.Position).Magnitude
        if distance > CONFIG.TELEPORT_RANGE then
            displayNotification("Target is too far! (" .. math.floor(distance) .. " studs)", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    state.isTeleporting = true
    state.lastTeleportTime = now

    -- Blink Effect at start position
    local blinkEffect = Instance.new("Part")
    blinkEffect.Anchored = true
    blinkEffect.CanCollide = false
    blinkEffect.Size = Vector3.new(2, 2, 2)
    blinkEffect.Transparency = 0.3
    blinkEffect.Material = Enum.Material.Neon
    blinkEffect.Color = Color3.fromRGB(0, 200, 255)
    blinkEffect.CFrame = rootPart.CFrame
    blinkEffect.Parent = workspace

    -- Instant teleport with slight offset for safety
    local randomOffset = Vector3.new(
        math.random(-10, 10) / 10,
        CONFIG.TELEPORT_HEIGHT,
        math.random(-10, 10) / 10
    )
    rootPart.CFrame = targetRoot.CFrame * CFrame.new(randomOffset)

    -- Blink Effect at end position
    local endBlinkEffect = blinkEffect:Clone()
    endBlinkEffect.CFrame = rootPart.CFrame
    endBlinkEffect.Parent = workspace

    -- Quick flash effect and cleanup
    game:GetService("TweenService"):Create(blinkEffect,
        TweenInfo.new(0.15),
        { Size = Vector3.new(0, 0, 0), Transparency = 1 }
    ):Play()

    game:GetService("TweenService"):Create(endBlinkEffect,
        TweenInfo.new(0.15),
        { Size = Vector3.new(0, 0, 0), Transparency = 1 }
    ):Play()

    game:GetService("Debris"):AddItem(blinkEffect, 0.15)
    game:GetService("Debris"):AddItem(endBlinkEffect, 0.15)

    -- Show distance info
    local distance = math.floor((targetRoot.Position - rootPart.Position).Magnitude)
    displayNotification("Blinked " .. distance .. " studs to " .. targetPlayer.Name, Color3.fromRGB(0, 200, 255))

    -- Reset state immediately since we're not using animations
    state.isTeleporting = false
end

-- Bring player function
local function bringPlayer(username)
    if not username or username == "" then return end

    -- Check cooldown
    local now = tick()
    if now - state.lastBringTime < CONFIG.BRING_COOLDOWN then
        local remaining = math.ceil((CONFIG.BRING_COOLDOWN - (now - state.lastBringTime)) * 10) / 10
        displayNotification("Bring cooldown: " .. remaining .. "s", Color3.fromRGB(255, 150, 0))
        return
    end

    -- Find target player
    local targetPlayer = nil
    local searchTerm = string.lower(username)
    for _, plr in pairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == searchTerm or
            string.lower(plr.DisplayName) == searchTerm then
            targetPlayer = plr
            break
        end
    end

    if not targetPlayer then
        displayNotification("Player not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    -- Get character components
    if not character then
        character = player.Character
        if not character then
            displayNotification("Your character not found!", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    if not rootPart then
        rootPart = character:FindFirstChild("HumanoidRootPart") or
            character:FindFirstChild("Torso") or
            character:FindFirstChild("UpperTorso")
        if not rootPart then
            displayNotification("Root part not found!", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    -- Get target character
    local targetChar = targetPlayer.Character
    if not targetChar then
        displayNotification("Target character not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or
        targetChar:FindFirstChild("Torso") or
        targetChar:FindFirstChild("UpperTorso")
    if not targetRoot then
        displayNotification("Target root part not found!", Color3.fromRGB(200, 0, 0))
        return
    end

    -- Check range
    if CONFIG.BRING_RANGE > 0 then
        local distance = (targetRoot.Position - rootPart.Position).Magnitude
        if distance > CONFIG.BRING_RANGE then
            displayNotification("Target is too far! (" .. math.floor(distance) .. " studs)", Color3.fromRGB(200, 0, 0))
            return
        end
    end

    state.lastBringTime = now

    -- Create teleport effect at target's position
    local effectStart = Instance.new("Part")
    effectStart.Anchored = true
    effectStart.CanCollide = false
    effectStart.Size = Vector3.new(2, 2, 2)
    effectStart.Transparency = 0.3
    effectStart.Material = Enum.Material.Neon
    effectStart.Color = Color3.fromRGB(255, 100, 100)
    effectStart.CFrame = targetRoot.CFrame
    effectStart.Parent = workspace

    -- Teleport target to you
    targetRoot.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3)

    -- Create arrival effect
    local effectEnd = effectStart:Clone()
    effectEnd.CFrame = targetRoot.CFrame
    effectEnd.Parent = workspace

    -- Animate and clean up effects
    game:GetService("TweenService"):Create(effectStart,
        TweenInfo.new(0.15),
        { Size = Vector3.new(0, 0, 0), Transparency = 1 }
    ):Play()

    game:GetService("TweenService"):Create(effectEnd,
        TweenInfo.new(0.15),
        { Size = Vector3.new(0, 0, 0), Transparency = 1 }
    ):Play()

    game:GetService("Debris"):AddItem(effectStart, 0.15)
    game:GetService("Debris"):AddItem(effectEnd, 0.15)

    displayNotification("Brought " .. targetPlayer.Name, Color3.fromRGB(0, 255, 100))
end

-- Update GUI status
local function updateStatus()
    if not gui.statusLabel then return end

    if not state.scriptActive then
        gui.statusLabel.Text = "Enhanced Jump: OFF"
        gui.statusLabel.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    elseif state.doubleJumpEnabled then
        gui.statusLabel.Text = "Enhanced Jump: ON"
        gui.statusLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
    else
        gui.statusLabel.Text = "Enhanced Jump: OFF"
        gui.statusLabel.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    end

    if gui.godModeLabel then
        if state.godModeEnabled then
            gui.godModeLabel.Text = "God Mode: ON"
            gui.godModeLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
        else
            gui.godModeLabel.Text = "God Mode: OFF"
            gui.godModeLabel.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        end
    end
end

-- Instant Jump function
local function triggerInstantJump()
    if not state.doubleJumpEnabled then return end -- Only jump if enabled

    -- Make sure we have all the necessary parts
    if not character then
        character = player.Character
        if not character then return end
    end

    if not humanoid then
        humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
    end

    if not rootPart then
        -- Try to find the root part regardless of character type
        rootPart = character:FindFirstChild("HumanoidRootPart") or
            character:FindFirstChild("Torso") or
            character:FindFirstChild("UpperTorso") or
            (character.PrimaryPart or nil)

        if not rootPart then return end
    end

    -- Get a movement direction - supports different humanoid types
    local moveDir
    if humanoid.MoveDirection.Magnitude > 0 then
        moveDir = humanoid.MoveDirection.Unit
    elseif humanoid:FindFirstChild("CameraDirection") and humanoid.CameraDirection.Magnitude > 0 then
        moveDir = humanoid.CameraDirection.Unit
    else
        -- Fall back to the direction the player is facing
        local lookVector = rootPart.CFrame.LookVector
        moveDir = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
    end

    -- Apply jump force
    local jumpForce = Vector3.new(
        moveDir.X * CONFIG.JUMP_FORCE_FORWARD,
        CONFIG.JUMP_FORCE_Y,
        moveDir.Z * CONFIG.JUMP_FORCE_FORWARD
    )

    -- Apply velocity
    rootPart.Velocity = jumpForce

    -- Visual effect - color based on jump height
    local effectColor = Color3.fromRGB(0, 200, 255) -- Cyan color for instant jump

    local jumpEffect = Instance.new("ParticleEmitter")
    jumpEffect.Texture = "rbxassetid://2581223252"
    jumpEffect.Size = NumberSequence.new(1, 0)
    jumpEffect.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    jumpEffect.Lifetime = NumberRange.new(0.3, 0.5)
    jumpEffect.Speed = NumberRange.new(5, 10)
    jumpEffect.SpreadAngle = Vector2.new(50, 50)
    jumpEffect.Rate = 200
    jumpEffect.EmissionDirection = Enum.NormalId.Bottom
    jumpEffect.Color = ColorSequence.new(effectColor)
    jumpEffect.Parent = rootPart

    -- Remove effect
    game:GetService("Debris"):AddItem(jumpEffect, 0.3)
end

-- God Mode: Complete protection system
local function enableGodMode()
    if not character or not humanoid then return end
    state.godModeEnabled = true

    -- Force Field for visual feedback and extra protection
    if state.forceField then
        pcall(function() state.forceField:Destroy() end)
    end

    state.forceField = Instance.new("ForceField")
    state.forceField.Visible = true
    state.forceField.Parent = character

    -- Comprehensive protection setup
    local function setupProtection()
        -- Maintain max health
        humanoid.Health = humanoid.MaxHealth
        humanoid.MaxHealth = 999999

        -- Prevent damage states
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false

        -- Prevent status effects
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true

        -- Immunity settings
        if humanoid:FindFirstChild("HealthChanged") then
            humanoid.HealthChanged:Connect(function()
                humanoid.Health = humanoid.MaxHealth
            end)
        end

        -- Additional protections
        local function preventDeath()
            if humanoid.Health <= 0 then
                humanoid.Health = humanoid.MaxHealth
            end
        end

        -- Connect to all damage-related events
        local connections = {
            humanoid.Died:Connect(preventDeath),
            humanoid:GetPropertyChangedSignal("Health"):Connect(preventDeath),
            game:GetService("RunService").Heartbeat:Connect(function()
                if state.godModeEnabled then
                    -- Continuous health restoration
                    humanoid.Health = humanoid.MaxHealth

                    -- Reset status effects
                    humanoid.PlatformStand = false
                    humanoid.Sit = false

                    -- Prevent drowning
                    if humanoid:FindFirstChild("Swimming") then
                        humanoid.Swimming.Value = false
                    end
                end
            end)
        }

        -- Store connections for cleanup
        for _, conn in ipairs(connections) do
            table.insert(connections, conn)
        end

        -- Handle character changes that might affect god mode
        local charChangedConn
        charChangedConn = character.ChildAdded:Connect(function(child)
            if state.godModeEnabled then
                task.wait()         -- Wait one frame
                if child:IsA("ForceField") and child ~= state.forceField then
                    child:Destroy() -- Keep only our force field
                end
            end
        end)
        table.insert(connections, charChangedConn)
    end

    -- Setup protection with error handling
    local success, err = pcall(setupProtection)
    if success then
        displayNotification("God Mode enabled - Full Protection Active", Color3.fromRGB(0, 200, 255))
    else
        warn("Error in God Mode setup:", err)
        -- Retry setup
        task.delay(0.5, function()
            pcall(setupProtection)
        end)
    end
end

-- Add function to disable God Mode
local function disableGodMode()
    state.godModeEnabled = false

    if state.forceField then
        pcall(function()
            state.forceField:Destroy()
            state.forceField = nil
        end)
    end

    -- Reset humanoid properties if it exists
    if humanoid then
        humanoid.MaxHealth = 100
        humanoid.Health = 100
        humanoid.BreakJointsOnDeath = true
        humanoid.RequiresNeck = true
    end

    displayNotification("God Mode disabled", Color3.fromRGB(200, 0, 0))
end

-- Add toggle function for God Mode
local function toggleGodMode()
    if state.godModeEnabled then
        disableGodMode()
    else
        enableGodMode()
    end
end

-- Update Player List Function
local function updatePlayerList()
    if not gui.playerListFrame then return end

    -- Clear existing items first
    for _, child in pairs(gui.playerListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    -- Get all players and make sure we have the complete list
    local allPlayers = Players:GetPlayers()

    -- Add players to the list
    local yOffset = 25 -- Start below title bar
    for _, plr in pairs(allPlayers) do
        local playerButton = Instance.new("TextButton")
        playerButton.Size = UDim2.new(1, -10, 0, 25)
        playerButton.Position = UDim2.new(0, 5, 0, yOffset)
        playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerButton.TextSize = 14
        playerButton.Font = Enum.Font.SourceSans
        playerButton.Text = plr.Name
        if plr.Name ~= plr.DisplayName then
            playerButton.Text = plr.Name .. " (" .. plr.DisplayName .. ")"
        end
        playerButton.BorderSizePixel = 0
        playerButton.TextXAlignment = Enum.TextXAlignment.Left
        playerButton.TextTruncate = Enum.TextTruncate.AtEnd
        playerButton.Name = "PlayerButton_" .. plr.Name
        playerButton.Parent = gui.playerListFrame

        -- Add rounded corners
        local cornerRadius = Instance.new("UICorner")
        cornerRadius.CornerRadius = UDim.new(0, 4)
        cornerRadius.Parent = playerButton

        -- Click to fill teleport input
        local success = pcall(function()
            playerButton.MouseButton1Click:Connect(function()
                if gui.teleportInput then
                    gui.teleportInput.Text = plr.Name
                end
            end)
        end)

        -- Double click to teleport immediately
        local lastClickTime = 0
        pcall(function()
            playerButton.MouseButton1Down:Connect(function()
                local now = tick()
                if now - lastClickTime < 0.5 then
                    teleportToPlayer(plr.Name)
                end
                lastClickTime = now
            end)
        end)

        yOffset = yOffset + 30
    end

    -- Update canvas size
    gui.playerListFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- Initialize GUI
local function createGui()
    -- Main ScreenGui
    gui.screenGui = Instance.new("ScreenGui")
    gui.screenGui.Name = "EnhancedControlsGUI"
    gui.screenGui.ResetOnSpawn = false

    pcall(function()
        gui.screenGui.Parent = player:WaitForChild("PlayerGui")
    end)

    -- Main Container
    local mainContainer = Instance.new("Frame")
    mainContainer.Size = UDim2.new(0, 250, 0, 300)
    mainContainer.Position = UDim2.new(0.8, -125, 0.5, -150)
    mainContainer.BackgroundTransparency = 0.2
    mainContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainContainer.BorderSizePixel = 0
    mainContainer.Name = "MainContainer"
    mainContainer.Parent = gui.screenGui

    -- Add rounded corners
    local cornerRadius = Instance.new("UICorner")
    cornerRadius.CornerRadius = UDim.new(0, 8)
    cornerRadius.Parent = mainContainer

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    titleBar.BorderSizePixel = 0
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainContainer

    -- Title Bar corner
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(0.8, 0, 1, 0)
    titleText.BackgroundTransparency = 1
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextSize = 16
    titleText.Font = Enum.Font.SourceSansBold
    titleText.Text = "  Enhanced Controls"
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    -- Features Container
    local featuresContainer = Instance.new("Frame")
    featuresContainer.Size = UDim2.new(1, -20, 1, -40)
    featuresContainer.Position = UDim2.new(0, 10, 0, 35)
    featuresContainer.BackgroundTransparency = 1
    featuresContainer.Name = "FeaturesContainer"
    featuresContainer.Parent = mainContainer

    -- Toggle Buttons
    local function createToggleButton(text, position)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 30)
        button.Position = position
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.SourceSansBold
        button.Text = text .. ": OFF"
        button.Name = text .. "Button"
        button.Parent = featuresContainer

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        return button
    end

    -- Create feature toggle buttons
    local jumpButton = createToggleButton("Enhanced Jump", UDim2.new(0, 0, 0, 0))
    local godModeButton = createToggleButton("God Mode", UDim2.new(0, 0, 0, 40))

    -- Player Actions Section
    local playerSection = Instance.new("Frame")
    playerSection.Size = UDim2.new(1, 0, 0, 160)
    playerSection.Position = UDim2.new(0, 0, 0, 80)
    playerSection.BackgroundTransparency = 1
    playerSection.Name = "PlayerSection"
    playerSection.Parent = featuresContainer

    -- Player input
    gui.teleportInput = Instance.new("TextBox")
    gui.teleportInput.Size = UDim2.new(1, 0, 0, 30)
    gui.teleportInput.Position = UDim2.new(0, 0, 0, 0)
    gui.teleportInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    gui.teleportInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    gui.teleportInput.TextSize = 14
    gui.teleportInput.Font = Enum.Font.SourceSans
    gui.teleportInput.PlaceholderText = "Enter Player Name"
    gui.teleportInput.Text = ""
    gui.teleportInput.Parent = playerSection

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = gui.teleportInput

    -- Action buttons
    local function createActionButton(text, position, color)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.48, 0, 0, 30)
        button.Position = position
        button.BackgroundColor3 = color
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.SourceSansBold
        button.Text = text
        button.Parent = playerSection

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        return button
    end

    local teleportButton = createActionButton("Teleport", UDim2.new(0, 0, 0, 40), Color3.fromRGB(0, 120, 255))
    local bringButton = createActionButton("Bring", UDim2.new(0.52, 0, 0, 40), Color3.fromRGB(255, 80, 80))

    -- Player list
    local playerListLabel = Instance.new("TextLabel")
    playerListLabel.Size = UDim2.new(1, 0, 0, 20)
    playerListLabel.Position = UDim2.new(0, 0, 0, 80)
    playerListLabel.BackgroundTransparency = 1
    playerListLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    playerListLabel.TextSize = 12
    playerListLabel.Font = Enum.Font.SourceSans
    playerListLabel.Text = "Players Online:"
    playerListLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerListLabel.Parent = playerSection

    gui.playerListFrame = Instance.new("ScrollingFrame")
    gui.playerListFrame.Size = UDim2.new(1, 0, 0, 80)
    gui.playerListFrame.Position = UDim2.new(0, 0, 0, 100)
    gui.playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    gui.playerListFrame.BorderSizePixel = 0
    gui.playerListFrame.ScrollBarThickness = 4
    gui.playerListFrame.Parent = playerSection

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = gui.playerListFrame

    -- Connect buttons
    pcall(function()
        jumpButton.MouseButton1Click:Connect(function()
            state.doubleJumpEnabled = not state.doubleJumpEnabled
            jumpButton.Text = "Enhanced Jump: " .. (state.doubleJumpEnabled and "ON" or "OFF")
            jumpButton.BackgroundColor3 = state.doubleJumpEnabled and Color3.fromRGB(0, 120, 0) or
                Color3.fromRGB(60, 60, 60)
        end)

        godModeButton.MouseButton1Click:Connect(function()
            if state.godModeEnabled then
                disableGodMode()
            else
                enableGodMode()
            end
            godModeButton.Text = "God Mode: " .. (state.godModeEnabled and "ON" or "OFF")
            godModeButton.BackgroundColor3 = state.godModeEnabled and Color3.fromRGB(0, 120, 0) or
                Color3.fromRGB(60, 60, 60)
        end)

        teleportButton.MouseButton1Click:Connect(function()
            teleportToPlayer(gui.teleportInput.Text)
        end)

        bringButton.MouseButton1Click:Connect(function()
            bringPlayer(gui.teleportInput.Text)
        end)
    end)

    -- Make window draggable
    makeDraggable(mainContainer)

    -- Initial player list update
    updatePlayerList()
end

-- Setup character with better error handling
local function setupCharacter(char)
    if not char then return end

    character = char

    -- Use pcall to safely get character components
    local success, result = pcall(function()
        -- Wait for humanoid with a timeout
        local startTime = tick()
        while not humanoid and tick() - startTime < 3 do
            humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then break end
            task.wait(0.1)
        end

        -- If we couldn't find a humanoid, try one more time
        if not humanoid then
            humanoid = char:FindFirstChildOfClass("Humanoid")
        end

        -- Try to find root part with multiple options
        rootPart = char:FindFirstChild("HumanoidRootPart") or
            char:FindFirstChild("Torso") or
            char:FindFirstChild("UpperTorso") or
            (char.PrimaryPart or nil)

        if not rootPart and humanoid then
            -- Last resort: Try to find the root part through the humanoid
            if humanoid.RootPart then
                rootPart = humanoid.RootPart
            end
        end

        -- Enable god mode if humanoid was found
        if humanoid then
            enableGodMode()
        end

        return true
    end)

    if not success then
        warn("Error in setupCharacter:", result)
        if gui.screenGui then
            displayNotification("Character setup error. Retrying...", Color3.fromRGB(255, 150, 0))
        end

        -- One more retry with delay
        task.delay(1, function()
            pcall(function()
                if not humanoid then
                    humanoid = char:FindFirstChildOfClass("Humanoid")
                end

                if not rootPart then
                    rootPart = char:FindFirstChild("HumanoidRootPart") or
                        char:FindFirstChild("Torso") or
                        char:FindFirstChild("UpperTorso") or
                        (char.PrimaryPart or nil)
                end

                if humanoid and not root then
                    enableGodMode()
                end
            end)
        end)
    end

    -- Update status after character setup
    updateStatus()
end

-- Handle space bar input for charged jump
local function handleSpaceInput(began)
    if not state.scriptActive or not state.doubleJumpEnabled then return end

    if began then
        -- Start charging jump
        state.isChargingJump = true
        state.jumpChargeStart = tick()
        state.currentJumpForce = CONFIG.JUMP_FORCE_Y

        -- Update charge over time
        local chargeLoop
        chargeLoop = RunService.Heartbeat:Connect(function()
            if not state.isChargingJump then
                chargeLoop:Disconnect()
                return
            end

            local elapsed = tick() - state.jumpChargeStart
            state.currentJumpForce = math.min(
                CONFIG.MAX_JUMP_FORCE_Y,
                CONFIG.JUMP_FORCE_Y + (elapsed * CONFIG.JUMP_CHARGE_RATE * 10)
            )

            updateStatus()
        end)

        table.insert(connections, chargeLoop)
    else
        -- Trigger jump if charging
        if state.isChargingJump then
            triggerInstantJump(true)
        end
    end
end

-- Cleanup
local function cleanupScript()
    -- Safely disconnect all connections
    for _, connection in ipairs(connections) do
        pcall(function()
            if connection.Connected then
                connection:Disconnect()
            end
        end)
    end

    -- Safely destroy GUI elements
    pcall(function()
        if gui.screenGui then
            gui.screenGui:Destroy()
        end
    end)

    -- Reset state
    connections = {}
    gui = {
        screenGui = nil,
        statusLabel = nil,
        chargeBar = nil,
        teleportFrame = nil,
        teleportInput = nil,
        playerListFrame = nil
    }

    state.scriptActive = false
end

-- Initialize
local function initialize()
    -- Setup auto-retry mechanism
    local function attemptInitialize()
        local success, errorMsg = pcall(function()
            createGui()
            updateStatus()

            -- Setup initial character if it exists
            if player.Character then
                setupCharacter(player.Character)
            end

            -- Setup character added event
            local characterAddedConn
            pcall(function()
                characterAddedConn = player.CharacterAdded:Connect(function(char)
                    setupCharacter(char)
                end)
                table.insert(connections, characterAddedConn)
            end)

            -- Setup input events
            local inputBeganConn
            pcall(function()
                inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed or not state.scriptActive then return end

                    -- G key to toggle God Mode
                    if input.KeyCode == Enum.KeyCode.G then
                        toggleGodMode()
                        updateStatus()
                    end

                    -- F key to toggle enhanced jump
                    if input.KeyCode == Enum.KeyCode.F then
                        state.doubleJumpEnabled = not state.doubleJumpEnabled
                        updateStatus()
                    end

                    -- Space key for instant jump when enabled
                    if input.KeyCode == Enum.KeyCode.Space and state.doubleJumpEnabled then
                        triggerInstantJump()
                    end
                end)
                table.insert(connections, inputBeganConn)
            end)

            -- Setup input ended event for space key
            local inputEndedConn
            pcall(function()
                inputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
                    if processed or not state.scriptActive then return end

                    if input.KeyCode == Enum.KeyCode.Space then
                        handleSpaceInput(false)
                    end
                end)
                table.insert(connections, inputEndedConn)
            end)

            -- Setup Players events for player list
            local playerAddedConn, playerRemovingConn
            pcall(function()
                playerAddedConn = Players.PlayerAdded:Connect(function()
                    task.wait(0.5) -- Give time for player data to load
                    updatePlayerList()
                end)
                table.insert(connections, playerAddedConn)

                playerRemovingConn = Players.PlayerRemoving:Connect(function()
                    task.wait(0.5) -- Wait before updating
                    updatePlayerList()
                end)
                table.insert(connections, playerRemovingConn)
            end)

            -- Auto-refresh player list
            task.spawn(function()
                while state.scriptActive do
                    if gui.screenGui and gui.screenGui.Parent then
                        pcall(updatePlayerList)
                    else
                        break
                    end
                    task.wait(5)
                end
            end)

            -- Monitor character/humanoid/rootPart availability
            task.spawn(function()
                while state.scriptActive do
                    if not character or not humanoid or not rootPart then
                        character = player.Character
                        if character then
                            setupCharacter(character)
                        end
                    end
                    task.wait(1)
                end
            end)

            -- Success notification
            displayNotification("Enhanced Jump & Teleport script loaded!", Color3.fromRGB(0, 150, 255))

            return true
        end)

        if not success then
            warn("Script initialization failed:", errorMsg)
            task.wait(2)
            return false
        end

        return true
    end

    -- Try to initialize and retry if failed
    local initSuccess = attemptInitialize()
    if not initSuccess then
        warn("Retrying initialization...")
        task.wait(2)
        attemptInitialize()
    end
end

-- Wrap the entire script in a pcall for extra safety
local scriptSuccess, scriptError = pcall(function()
    initialize()
end)

if not scriptSuccess then
    warn("Script failed to initialize:", scriptError)
    -- Last resort error handler
    task.wait(3)
    pcall(initialize)
end
