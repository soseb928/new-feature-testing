-- NexusPlay Auto Retry UI Test v4
-- TESTING ONLY: invokes the already-existing Retry UI signal.
-- This does not call Retry_Method or construct server payloads.
-- It relies on the execution environment exposing firesignal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

local active = true
local busy = false
local lastAttempt = 0

local function log(msg)
    print("[Auto Retry UI Test v4] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function findRetryButton()
    local hud = PlayerGui:FindFirstChild("RaidHUD")
    if not hud then return nil end

    local frame = hud:FindFirstChild("Frame")
    local inner = frame and frame:FindFirstChild("Frame")
    local button = inner and inner:FindFirstChild("TextButton")

    if button and button:IsA("TextButton") and button.Visible and button.Active then
        return button
    end

    return nil
end

local function tryRetry()
    if not active or busy then return false end
    if os.clock() - lastAttempt < 2 then return false end

    local fire = rawget(getfenv and getfenv() or {}, "firesignal")
    if type(fire) ~= "function" then
        fire = firesignal
    end

    if type(fire) ~= "function" then
        log("FIRESIGNAL UNAVAILABLE | executor does not expose firesignal")
        return false
    end

    local button = findRetryButton()
    if not button then
        log("RETRY BUTTON NOT FOUND")
        return false
    end

    busy = true
    lastAttempt = os.clock()

    log("RETRY BUTTON FOUND | " .. button:GetFullName())
    log("RETRY SIGNAL | MouseButton1Click")
    log("RETRY SIGNAL | invoking existing UI signal only")

    local ok, err = pcall(function()
        fire(button.MouseButton1Click)
    end)

    log("RETRY SIGNAL RESULT | ok=" .. tostring(ok) .. " | err=" .. tostring(err))

    task.delay(4, function()
        busy = false
    end)

    return ok
end

local function attach(obj)
    if not obj:IsA("RemoteEvent") or obj.Name ~= "RaidEnded_Signal" then
        return
    end

    obj.OnClientEvent:Connect(function(success)
        if not success then return end

        log("RAID END | success=true | waiting for Retry UI")

        task.spawn(function()
            local deadline = os.clock() + 6

            while active and os.clock() < deadline do
                if tryRetry() then return end
                task.wait(0.25)
            end

            if active then
                log("RETRY ATTEMPT TIMEOUT")
            end
        end)
    end)
end

for _, obj in ipairs(RaidsService:GetChildren()) do
    attach(obj)
end

RaidsService.ChildAdded:Connect(attach)

log("STARTED | Auto Retry UI Test v4")
log("MODE | after RaidEnded, trigger the existing Retry button MouseButton1Click signal")
