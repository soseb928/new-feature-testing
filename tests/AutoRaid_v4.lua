-- NexusPlay Auto Raid v4
-- CLEAN BUILD / TESTING ONLY
-- Uses the game's normal BossIslandService.CreateIslandQueue_Method.
-- No payload spoofing, no damage manipulation, no server-validation bypass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

local QueueRemote = BossIslandService:FindFirstChild("CreateIslandQueue_Method")
local RetryRemote = BossIslandService:FindFirstChild("Retry_Method")
local ReturnRemote = BossIslandService:FindFirstChild("Return_Method")
local RaidDataSignal = RaidsService:FindFirstChild("RaidDataUpdated_Signal")
local RaidEndedSignal = RaidsService:FindFirstChild("RaidEnded_Signal")

local PREFIX = "[Auto Raid v4]"
local ENABLED = true
local DIFFICULTY = 5
local QUEUE_INTERVAL = 5

-- Set this to the raid you want. The script validates the config before queueing.
-- Examples: Jogo, Yuta, Choso, Toji, Sukuna, AToji, Maki, AGojo, StarRage, AKashimo, Judge, CurseCalamity
local SELECTED_RAID = "Jogo"

local CONFIGS = {
    StarRage = {max=5},
    Choso = {max=5},
    AKashimo = {max=5},
    Yuta = {max=5},
    Judge = {max=5},
    Jogo = {max=5},
    Toji = {max=5},
    Sukuna = {max=5},
    AToji = {max=5},
    Maki = {max=5},
    AGojo = {max=5},
    CurseCalamity = {max=3},
}

local active = false
local lastQueue = 0
local raidEnded = false

local function log(s)
    print(PREFIX .. " " .. os.date("%H:%M:%S") .. " | " .. tostring(s))
end

local function selfCheck()
    local ok = true
    local checks = {
        {"NetworkComm", NetworkComm},
        {"BossIslandService", BossIslandService},
        {"RaidsService", RaidsService},
        {"CreateIslandQueue_Method", QueueRemote},
        {"Retry_Method", RetryRemote},
        {"Return_Method", ReturnRemote},
        {"RaidDataUpdated_Signal", RaidDataSignal},
        {"RaidEnded_Signal", RaidEndedSignal},
    }

    for _, c in ipairs(checks) do
        if c[2] then
            log("CHECK PASS | " .. c[1])
        else
            log("CHECK FAIL | " .. c[1])
            ok = false
        end
    end

    local cfg = CONFIGS[SELECTED_RAID]
    if cfg then
        log("CHECK PASS | ConfigID=" .. SELECTED_RAID .. " | maxDifficulty=" .. cfg.max)
    else
        log("CHECK FAIL | unknown ConfigID=" .. tostring(SELECTED_RAID))
        ok = false
    end

    if DIFFICULTY < 1 then
        log("CHECK FAIL | invalid Difficulty")
        ok = false
    elseif cfg and DIFFICULTY > cfg.max then
        log("CHECK FAIL | Difficulty " .. tostring(DIFFICULTY) .. " exceeds max " .. tostring(cfg.max))
        ok = false
    else
        log("CHECK PASS | Difficulty=" .. tostring(DIFFICULTY))
    end

    return ok
end

local function queueRaid(reason)
    if not ENABLED or active then return false end
    if not QueueRemote then
        log("QUEUE FAIL | CreateIslandQueue_Method missing")
        return false
    end
    if os.clock() - lastQueue < QUEUE_INTERVAL then return false end

    lastQueue = os.clock()

    local payload = {
        Difficulty = DIFFICULTY,
        ConfigID = SELECTED_RAID,
        Modifiers = {},
    }

    log("QUEUE | reason=" .. tostring(reason) .. " | ConfigID=" .. SELECTED_RAID .. " | Difficulty=" .. tostring(DIFFICULTY))

    local ok, result = pcall(function()
        return QueueRemote:InvokeServer(payload)
    end)

    log("QUEUE RESULT | ok=" .. tostring(ok) .. " | result=" .. tostring(result))

    if ok and result ~= false then
        active = true
        raidEnded = false
        log("QUEUE ACCEPTED")
        return true
    end

    log("QUEUE REJECTED | server returned false or call failed")
    return false
end

if RaidDataSignal and RaidDataSignal:IsA("RemoteEvent") then
    RaidDataSignal.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        local players = data.Players
        local count = 0
        if type(players) == "table" then
            for _ in pairs(players) do count += 1 end
        end

        if count > 0 or data.RetryTime ~= nil then
            active = true
        end

        log("STATE | players=" .. tostring(count) .. " | RaidID=" .. tostring(data.RaidID) .. " | BossID=" .. tostring(data.BossID) .. " | Difficulty=" .. tostring(data.Difficulty))
    end)
end

if RaidEndedSignal and RaidEndedSignal:IsA("RemoteEvent") then
    RaidEndedSignal.OnClientEvent:Connect(function(success)
        raidEnded = true
        active = false
        log("RAID END | success=" .. tostring(success))
    end)
end

log("START | CLEAN BUILD v4")
log("MODE | normal CreateIslandQueue_Method only")
log("TARGET | " .. SELECTED_RAID .. " | Difficulty " .. tostring(DIFFICULTY))

if not selfCheck() then
    log("ABORT | self-check failed; nothing was invoked")
    return
end

task.spawn(function()
    task.wait(1)
    queueRaid("startup")

    while ENABLED do
        task.wait(1)

        if not active and raidEnded then
            queueRaid("previous raid ended")
        elseif not active and os.clock() - lastQueue >= QUEUE_INTERVAL then
            queueRaid("idle")
        end
    end
end)
