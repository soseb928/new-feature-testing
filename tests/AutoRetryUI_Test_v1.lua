-- NexusPlay Auto Retry UI Test v1
-- TESTING ONLY: activates the game's normal visible Retry UI button.
-- Does not invoke hidden remotes or bypass server validation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

local active = true
local retrying = false
local lastRetryAt = 0

local function log(msg)
    print("[Auto Retry UI Test v1] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function findRetryButton()
    -- Confirmed from manual UI inspection:
    -- PlayerGui.RaidHUD.Frame.Frame.TextButton
    local raidHUD = PlayerGui:FindFirstChild("RaidHUD")
    if not raidHUD then return nil end

    local frame = raidHUD:FindFirstChild("Frame")
    if not frame then return nil end

    local inner = frame:FindFirstChild("Frame")
    if not inner then return nil end

    local button = inner:FindFirstChild("TextButton")
    if button and button:IsA("GuiButton") then
        return button
    end

    return nil
end

local function activateRetry()
    if not active or retrying then return false end
    if os.clock() - lastRetryAt < 2 then return false end

    local button = findRetryButton()
    if not button then
        log("RETRY BUTTON NOT FOUND")
        return false
    end

    local visible = false
    pcall(function() visible = button.Visible end)

    if not visible then
        log("RETRY BUTTON FOUND BUT NOT VISIBLE")
        return false
    end

    retrying = true
    lastRetryAt = os.clock()

    log("RETRY UI FOUND | " .. button:GetFullName())
    log("RETRY UI ACTIVATE | using normal GuiButton:Activate()")

    local ok, err = pcall(function()
        button:Activate()
    end)

    log("RETRY UI RESULT | ok=" .. tostring(ok) .. " | err=" .. tostring(err))

    task.delay(3, function()
        retrying = false
    end)

    return ok
end

local function watchRaidEnd(remote)
    if not remote:IsA("RemoteEvent") or remote.Name ~= "RaidEnded_Signal" then
        return
    end

    remote.OnClientEvent:Connect(function(success)
        if not success then
            log("RAID END | success=false | skip")
            return
        end

        log("RAID END | success=true | waiting for normal Retry UI")

        task.spawn(function()
            local deadline = os.clock() + 5

            while active and os.clock() < deadline do
                if activateRetry() then
                    return
                end
                task.wait(0.25)
            end

            if active then
                log("RETRY UI TIMEOUT | no visible normal Retry button found")
            end
        end)
    end)
end

for _, obj in ipairs(RaidsService:GetChildren()) do
    watchRaidEnd(obj)
end

RaidsService.ChildAdded:Connect(watchRaidEnd)

log("STARTED | Auto Retry UI Test v1")
log("MODE | waits for RaidEnded_Signal then activates the game's normal Retry button")
