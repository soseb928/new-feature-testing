-- NexusPlay Auto Raid Test v1
-- TESTING ONLY: starts raids through the game's normal BossIslandService queue.
-- No damage spoofing, no server-validation bypass, no hidden payload construction.
-- Retry is intentionally NOT implemented here; use the existing Nexus Hub retry system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

local CreateQueue = BossIslandService:WaitForChild("CreateIslandQueue_Method")
local RaidDataSignal = RaidsService:FindFirstChild("RaidDataUpdated_Signal")
local RaidEndSignal = RaidsService:FindFirstChild("RaidEnded_Signal")
local LobbyRemovedSignal = RaidsService:FindFirstChild("LobbyRemoved_Signal")

-- Change these for testing another supported raid.
local CONFIG_ID = "Jogo"
local DIFFICULTY = 5
local MODIFIERS = {}

local ENABLED = true
local QUEUE_DELAY = 3
local RETRY_SCAN_DELAY = 1

local busy = false
local activeRaid = false
local currentRaidId = nil
local lastQueueAt = 0
local lastEndAt = 0
local lastLobbyRemovedAt = 0

local function log(msg)
    print("[Auto Raid Test v1] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function getRaidData()
    local out = nil
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local hud = pg and pg:FindFirstChild("RaidHUD")
        if hud then
            -- UI presence is only used as a local state hint.
            out = hud
        end
    end)
    return out
end

local function inRaid()
    local result = false
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild("RaidHUD") then
            result = true
        end
    end)
    return result
end

local function queueRaid(reason)
    if not ENABLED or busy then return false end
    if os.clock() - lastQueueAt < QUEUE_DELAY then return false end

    busy = true
    lastQueueAt = os.clock()

    log("QUEUE | reason=" .. tostring(reason))
    log("QUEUE | ConfigID=" .. tostring(CONFIG_ID)
        .. " | Difficulty=" .. tostring(DIFFICULTY))

    local payload = {
        Difficulty = DIFFICULTY,
        ConfigID = CONFIG_ID,
        Modifiers = MODIFIERS,
    }

    local ok, result = pcall(function()
        return CreateQueue:InvokeServer(payload)
    end)

    log("QUEUE RESULT | ok=" .. tostring(ok) .. " | result=" .. tostring(result))

    busy = false
    return ok and result ~= false
end

if RaidDataSignal and RaidDataSignal:IsA("RemoteEvent") then
    RaidDataSignal.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end

        local id = data.RaidID or data.BossID
        if id then
            currentRaidId = tostring(id)
            activeRaid = true

            log("RAID DATA | RaidID=" .. tostring(id)
                .. " | Players=" .. tostring(type(data.Players) == "table" and #data.Players or 0)
                .. " | RetryTime=" .. tostring(data.RetryTime))
        end
    end)
end

if RaidEndSignal and RaidEndSignal:IsA("RemoteEvent") then
    RaidEndSignal.OnClientEvent:Connect(function(success)
        lastEndAt = os.clock()
        log("RAID END | success=" .. tostring(success))
        -- Do not queue here. Existing Nexus Hub retry is responsible for retry.
    end)
end

if LobbyRemovedSignal and LobbyRemovedSignal:IsA("RemoteEvent") then
    LobbyRemovedSignal.OnClientEvent:Connect(function(data)
        lastLobbyRemovedAt = os.clock()
        activeRaid = false
        currentRaidId = nil
        log("LOBBY REMOVED | waiting before checking whether a retry already created a new raid")
    end)
end

task.spawn(function()
    log("STARTED | Auto Raid Test v1")
    log("CONFIG | " .. tostring(CONFIG_ID) .. " | difficulty " .. tostring(DIFFICULTY))
    log("RETRY | intentionally delegated to existing Nexus Hub retry")

    task.wait(1)
    queueRaid("initial")

    while ENABLED do
        task.wait(RETRY_SCAN_DELAY)

        if not activeRaid and not busy then
            -- Give the game's normal retry flow time to recreate the raid.
            if os.clock() - lastEndAt >= 4
                and os.clock() - lastLobbyRemovedAt >= 2
            then
                queueRaid("no active raid")
            end
        end
    end
end)
