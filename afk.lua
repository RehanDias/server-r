-- ==========================================
--             ARCAN1ST HUB | Anti-AFK
-- ==========================================

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [1] ANTI-AFK CORE LOGIC
-- ==========================================

local isActive   = false
local loopThread = nil

local function disableIdleConnections()
    if not getconnections then return 0 end

    local connections = getconnections(LocalPlayer.Idled)

    for _, conn in pairs(connections) do
        pcall(function() conn:Disable()       end)
        pcall(function() conn:Disconnect()    end)
        pcall(function() conn.Enabled = false end)
    end

    return #connections
end

local function startAntiAFK()
    isActive = true
    disableIdleConnections()

    loopThread = task.spawn(function()
        while isActive and task.wait(30) do
            disableIdleConnections()
        end
    end)
end

local function stopAntiAFK()
    isActive = false

    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

-- ==========================================
-- [2] UI SETUP
-- ==========================================

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/RehanDias/UIR/refs/heads/main/test.lua"
))()

local Window = Library:CreateWindow({
    Title     = "Arcan1st Hub",
    Author    = "Anti-AFK",
    Icon      = "shield-check",
    Size      = UDim2.new(0, 450, 0, 300),
    ToggleKey = Enum.KeyCode.RightControl,
})

-- ==========================================
-- [3] TABS & SECTIONS
-- ==========================================

local MainTab = Window:Tab({
    Title = "Main",
    Icon  = "home",
})

MainTab:Section({
    Title = "🛡️ Server Protection",
})

-- ==========================================
-- [4] COMPONENTS
-- ==========================================

MainTab:Toggle({
    Title    = "Enable Anti AFK",
    Desc     = "Mencegah ter-kick dari game saat AFK (diam) selama 20 menit.",
    Default  = false,
    Callback = function(state)
        if state then
            startAntiAFK()
            Library:Notify({
                Title    = "Anti AFK",
                Content  = "Anti AFK is now ACTIVE ✅",
                Icon     = "check-circle",
                Duration = 3,
            })
        else
            stopAntiAFK()
            Library:Notify({
                Title    = "Anti AFK",
                Content  = "Anti AFK is now OFF ❌",
                Icon     = "x-circle",
                Duration = 3,
            })
        end
    end,
})

-- ==========================================
-- [5] INIT
-- ==========================================

Window:SelectTab("Main")
