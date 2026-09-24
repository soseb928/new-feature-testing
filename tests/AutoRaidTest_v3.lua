-- NexusPlay Auto Raid Test v3
-- TESTING ONLY: auto-detects the current raid's RaidID/BossID and Difficulty.
-- It does not hardcode Jogo/Megumi/Gojo. Retry remains delegated to Nexus Hub.
-- Uses only the game's normal CreateIslandQueue_Method.

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

local ENABLED = true
local QUEUE_DELAY = 4

local currentRaidId = nil
local currentBossId = nil
local currentDifficulty = nil
local currentModifiers = {}
local haveRaidData = false
local raidActive = false
local queueBusy = false
local lastQueueAt = 0
local lastEndAt = 0
local lastLobbyRemovedAt = 0

local function log(msg)
    print("[Auto Raid Test v2] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function countTable(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function copyTable(t)
    if type(t) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

local function scanRaidData(data, source)
    if type(data) ~= "table" then return false end

    local raidId = data.RaidID
    local bossId = data.BossID
    local difficulty = data.Difficulty

    if raidId ~= nil then
        currentRaidId = tostring(raidId)
    end

    if bossId ~= nil then
        currentBossId = tostring(bossId)
    end

    if difficulty ~= nil then
        currentDifficulty = tonumber(difficulty) or difficulty
    end

    if type(data.Modifiers) == "table" then
        currentModifiers = copyTable(data.Modifiers)
    end

    if currentRaidId or currentBossId or currentDifficulty then
        haveRaidData = true
        log(
            "SCAN | source=" .. tostring(source)
            .. " | RaidID=" .. tostring(currentRaidId)
            .. " | BossID=" .. tostring(currentBossId)
            .. " | Difficulty=" .. tostring(currentDifficulty)
            .. " | Modifiers=" .. tostring(countTable(currentModifiers))
        )
        return true
    end

    return false
end

local function normalize(s)
    return string.lower(tostring(s or "")):gsub("[^%w]", "")
end

local function resolveConfigId()
    if currentRaidId and currentRaidId ~= "" then
        return currentRaidId, "RaidID"
    end

    local known = {
        megumi = "Megumi",
        jogo = "Jogo",
        yuta = "Yuta",
        choso = "Choso",
        sukuna = "Sukuna",
        toji = "Toji",
        maki = "Maki",
        awakenedtoji = "AToji",
        awakenedgojo = "AGojo",
        gojo = "AGojo",
        judge = "Judge",
        starrage = "StarRage",
        yuki = "StarRage",
        lightning = "AKashimo",
        awakenedlightninggod = "AKashimo",
        cursecalamity = "CurseCalamity",
    }

    local cfg = known[normalize(currentBossId)]
    if cfg then
        return cfg, "BossIDMap"
    end

    return nil, "unresolved"
end

local function raidLabel()
    return currentRaidId or currentBossId or "UNKNOWN"
end

local function queueDetectedRaid(reason)
    if not ENABLED or queueBusy then return false end
    if not haveRaidData then
        log("QUEUE SKIP | no RaidDataUpdated scan available yet")
        return false
    end
    if currentDifficulty == nil then
        log("QUEUE SKIP | Difficulty not detected")
        return false
    end
    if os.clock() - lastQueueAt < QUEUE_DELAY then return false end

    local resolved, source = resolveConfigId()
    if not resolved then
        log("QUEUE SKIP | ConfigID unresolved | BossID=" .. tostring(currentBossId) .. " | RaidID=" .. tostring(currentRaidId))
        return false
    end

    queueBusy = true
    lastQueueAt = os.clock()

    local payload = {
        Difficulty = currentDifficulty,
        ConfigID = resolved,
        Modifiers = currentModifiers or {},
    }

    log(
        "QUEUE | reason=" .. tostring(reason)
        .. " | scanned RaidID=" .. tostring(currentRaidId)
        .. " | BossID=" .. tostring(currentBossId)
        .. " | ConfigID=" .. tostring(resolved)
        .. " | ConfigSource=" .. tostring(source)
        .. " | Difficulty=" .. tostring(currentDifficulty)
    )

    local ok, result = pcall(function()
        return CreateQueue:InvokeServer(payload)
    end)

    log("QUEUE RESULT | ok=" .. tostring(ok) .. " | result=" .. tostring(result))

    queueBusy = false
    return ok and result ~= false
end

if RaidDataSignal and RaidDataSignal:IsA("RemoteEvent") then
    RaidDataSignal.OnClientEvent:Connect(function(data)
        scanRaidData(data, "RaidDataUpdated")

        if type(data) == "table" then
            local players = data.Players
            local playerCount = type(players) == "table" and countTable(players) or 0

            if playerCount > 0 or data.RetryTime ~= nil then
                raidActive = true
            end

            log(
                "STATE | RaidID=" .. tostring(currentRaidId)
                .. " | Difficulty=" .. tostring(currentDifficulty)
                .. " | Players=" .. tostring(playerCount)
            )
        end
    end)
end

if RaidEndSignal and RaidEndSignal:IsA("RemoteEvent") then
    RaidEndSignal.OnClientEvent:Connect(function(success)
        lastEndAt = os.clock()
        log(
            "RAID END | success=" .. tostring(success)
            .. " | scanned raid=" .. tostring(raidLabel())
            .. " | difficulty=" .. tostring(currentDifficulty)
        )
    end)
end

if LobbyRemovedSignal and LobbyRemovedSignal:IsA("RemoteEvent") then
    LobbyRemovedSignal.OnClientEvent:Connect(function()
        lastLobbyRemovedAt = os.clock()
        raidActive = false
        log(
            "LOBBY REMOVED | retained scan="
            .. tostring(raidLabel())
            .. " | difficulty=" .. tostring(currentDifficulty)
        )
    end)
end

log("STARTED | Auto Raid Test v2")
log("MODE | scan RaidID/BossID/Difficulty automatically from RaidDataUpdated")
log("MODE | resolve ConfigID from RaidID or detected BossID")
log("MODE | no hardcoded Jogo/Megumi/Gojo")
log("RETRY | delegated to existing Nexus Hub retry")

task.spawn(function()
    -- First wait for the game's current raid data instead of inventing a raid.
    log("WAIT | scanning current raid...")
    local deadline = os.clock() + 15

    while ENABLED and os.clock() < deadline and not haveRaidData do
        task.wait(0.25)
    end

    if not haveRaidData then
        log("SCAN TIMEOUT | no RaidDataUpdated received")
        return
    end

    log(
        "DETECTED | RaidID=" .. tostring(currentRaidId)
        .. " | BossID=" .. tostring(currentBossId)
        .. " | Difficulty=" .. tostring(currentDifficulty)
    )

    -- Do not queue while already inside the detected raid.
    while ENABLED do
        task.wait(0.5)

        if not raidActive
            and os.clock() - lastEndAt >= 4
            and os.clock() - lastLobbyRemovedAt >= 2
        then
            queueDetectedRaid("detected raid ended")
            task.wait(1)
        end
    end
end)
