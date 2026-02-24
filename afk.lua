--// Anti AFK Standalone Script

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- Jika executor support getconnections (lebih efektif)
if getconnections then
    for _, connection in pairs(getconnections(player.Idled)) do
        if connection.Disable then
            connection:Disable()
        elseif connection.Disconnect then
            connection:Disconnect()
        end
    end
else
    -- Fallback method (universal)
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

print("Anti AFK Enabled")
