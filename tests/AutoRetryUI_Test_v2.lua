-- NexusPlay Auto Retry UI Test v2
-- TESTING ONLY: instruments the normal Retry TextButton's activation path.
-- Does not invoke remotes or bypass server validation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

local active = true
local lastEnd = 0
local retryAttempted = false

local function log(msg)
    print("[Auto Retry UI Test v2] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function getRetryButton()
    local hud = PlayerGui:FindFirstChild("RaidHUD")
    if not hud then return nil end

    local frame = hud:FindFirstChild("Frame")
    local inner = frame and frame:FindFirstChild("Frame")
    local button = inner and inner:FindFirstChild("TextButton")

    if button and button:IsA("TextButton") then
        return button
    end

    return nil
end

local function inspectButton(button)
    log("BUTTON | " .. button:GetFullName())
    log("BUTTON | Class=" .. button.ClassName)
    log("BUTTON | Visible=" .. tostring(button.Visible))
    log("BUTTON | Active=" .. tostring(button.Active))
    log("BUTTON | AutoButtonColor=" .. tostring(button.AutoButtonColor))
    log("BUTTON | Text=" .. tostring(button.Text))

    local props = {
        "Selectable",
        "Modal",
        "Interactable",
        "Style",
        "LayoutOrder",
        "ZIndex"
    }

    for _, p in ipairs(props) do
        local ok, value = pcall(function()
            return button[p]
        end)
        if ok then
            log("BUTTON PROP | " .. p .. "=" .. tostring(value))
        end
    end

    for _, child in ipairs(button:GetDescendants()) do
        local text = ""
        pcall(function() text = child.Text end)
        log("CHILD | " .. child:GetFullName()
            .. " | Class=" .. child.ClassName
            .. " | Text=" .. tostring(text))
    end
end

local function attempt(button)
    if not button or retryAttempted then return end
    retryAttempted = true

    inspectButton(button)

    local events = {"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}

    for _, eventName in ipairs(events) do
        local ok, signal = pcall(function()
            return button[eventName]
        end)
        log("SIGNAL CHECK | " .. eventName .. " | exists=" .. tostring(ok and signal ~= nil))
    end

    log("NOTE | GuiButton:Activate() is unavailable in this game's runtime")
    log("NEXT | waiting for source/UI instrumentation; no synthetic click is generated")
end

local function scan()
    local b = getRetryButton()
    if b then
        attempt(b)
        return true
    end
    return false
end

local raidEndConn
for _, obj in ipairs(RaidsService:GetChildren()) do
    if obj:IsA("RemoteEvent") and obj.Name == "RaidEnded_Signal" then
        raidEndConn = obj.OnClientEvent:Connect(function(success)
            if not success then return end

            lastEnd = os.clock()
            retryAttempted = false
            log("RAID END | success=true | scanning Retry UI")

            for i = 1, 20 do
                if not active or os.clock() - lastEnd > 8 then break end
                if scan() then return end
                task.wait(0.2)
            end

            if active and retryAttempted == false then
                log("RETRY BUTTON TIMEOUT")
            end
        end)
    end
end

log("STARTED | Auto Retry UI Test v2")
log("MODE | inspect normal Retry TextButton after RaidEnded")
