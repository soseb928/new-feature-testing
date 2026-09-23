-- NexusPlay Auto Raid + Auto Retry TEST v2
-- Uses the game's existing raid RemoteFunctions with server-side validation.
-- TEST ONLY: no damage spoofing, no teleport manipulation, no prompt spoofing.
-- Designed for the Megumi raid observed by RaidDebugMonitor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Net = ReplicatedStorage:WaitForChild("NetworkComm")
local BossIsland = Net:WaitForChild("BossIslandService")
local Raids = Net:WaitForChild("RaidsService")

local CreateIslandQueue = BossIsland:WaitForChild("CreateIslandQueue_Method")
local RetryRaid = BossIsland:WaitForChild("Retry_Method")

local RaidBossSpawned = Raids:FindFirstChild("RaidBossSpawned_Signal")
local RaidEnded = Raids:FindFirstChild("RaidEnded_Signal")
local RaidDataUpdated = Raids:FindFirstChild("RaidDataUpdated_Signal")
local LobbyRemoved = Raids:FindFirstChild("LobbyRemoved_Signal")
local MatchStateUpdated = Raids:FindFirstChild("MatchStateUpdated_Signal")

local State = {
    enabled = false,
    busy = false,
    retrying = false,
    bossAlive = false,
    inRaid = false,
    lastQueue = 0,
    lastRetry = 0,
    retryDelay = 1.0,
    queueDelay = 2.0,
    difficulty = 5,
    configId = "Megumi",
    modifiers = { Hardcore = true, Weaken = true },
    connections = {},
    gui = nil,
    log = {},
}

local function log(msg)
    local line = os.date("%H:%M:%S") .. " | " .. tostring(msg)
    print("[AutoRaidTest v2] " .. line)
    table.insert(State.log, line)
    if #State.log > 80 then table.remove(State.log, 1) end
    if State.gui and State.gui.log then
        State.gui.log.Text = table.concat(State.log, "\n")
    end
end

local function disconnectAll()
    for _, c in ipairs(State.connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(State.connections)
end

local function invokeQueue(reason)
    if not State.enabled or State.busy then return false end
    if (os.clock() - State.lastQueue) < State.queueDelay then return false end

    State.lastQueue = os.clock()
    State.busy = true

    log("QUEUE request | ConfigID=" .. State.configId
        .. " | Difficulty=" .. State.difficulty
        .. " | Modifiers=Hardcore,Weaken"
        .. " | reason=" .. tostring(reason))

    local ok, result = pcall(function()
        return CreateIslandQueue:InvokeServer({
            Difficulty = State.difficulty,
            ConfigID = State.configId,
            Modifiers = State.modifiers,
        })
    end)

    if ok then
        log("QUEUE response | " .. tostring(result))
    else
        log("QUEUE error | " .. tostring(result))
    end

    task.delay(3, function()
        State.busy = false
    end)

    return ok
end

local function invokeRetry(reason)
    if not State.enabled then return false end
    if State.retrying then return false end
    if (os.clock() - State.lastRetry) < State.retryDelay then return false end

    State.lastRetry = os.clock()
    State.retrying = true
    log("RETRY request | reason=" .. tostring(reason))

    local ok, result = pcall(function()
        return RetryRaid:InvokeServer()
    end)

    if ok then
        log("RETRY response | " .. tostring(result))
    else
        log("RETRY error | " .. tostring(result))
    end

    task.delay(2, function()
        State.retrying = false
    end)

    return ok
end

local function attach()
    disconnectAll()

    if RaidBossSpawned then
        table.insert(State.connections, RaidBossSpawned.OnClientEvent:Connect(function(boss)
            State.inRaid = true
            State.bossAlive = true
            State.busy = false
            State.retrying = false
            log("BOSS SPAWNED | " .. tostring(boss))
        end))
    end

    if RaidDataUpdated then
        table.insert(State.connections, RaidDataUpdated.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end

            local boss = data.BossID
            local retrying = data.RetryingPlayers
            local players = data.Players
            local retryTime = data.RetryTime

            if boss then
                State.inRaid = true
            end

            local retryCount = 0
            if type(retrying) == "table" then
                for _ in pairs(retrying) do retryCount += 1 end
            end

            if retryCount > 0 then
                State.retrying = true
                log("STATE | RetryingPlayers=" .. tostring(retryCount)
                    .. " | RetryTime=" .. tostring(retryTime))
            end

            local playerCount = 0
            if type(players) == "table" then
                for _ in pairs(players) do playerCount += 1 end
            end

            if playerCount == 0 and retryCount == 0 and boss then
                log("STATE | raid player list empty")
            end
        end))
    end

    if RaidEnded then
        table.insert(State.connections, RaidEnded.OnClientEvent:Connect(function(success, summary)
            State.bossAlive = false
            State.inRaid = true
            log("RAID ENDED | success=" .. tostring(success))

            if type(summary) == "table" and type(summary.Summary) == "table" then
                log("SUMMARY | placement=" .. tostring(summary.Summary.Placement)
                    .. " | time=" .. tostring(summary.Summary.TimeTaken))
            end

            if State.enabled and success then
                task.delay(State.retryDelay, function()
                    if State.enabled then
                        invokeRetry("RaidEnded_Signal")
                    end
                end)
            end
        end))
    end

    if LobbyRemoved then
        table.insert(State.connections, LobbyRemoved.OnClientEvent:Connect(function(data)
            log("LOBBY REMOVED | " .. tostring(data))
        end))
    end

    if MatchStateUpdated then
        table.insert(State.connections, MatchStateUpdated.OnClientEvent:Connect(function(state)
            log("MATCH STATE | " .. tostring(state))
        end))
    end
end

local function start()
    if State.enabled then return end

    State.enabled = true
    State.busy = false
    State.retrying = false
    State.bossAlive = false
    State.inRaid = false

    attach()

    log("STARTED | v2 | server-validated queue/retry controller")
    log("CONFIG | Megumi / Difficulty 5 / Hardcore+Weaken")

    task.spawn(function()
        task.wait(0.5)

        if State.enabled and not State.inRaid then
            invokeQueue("initial")
        end

        while State.enabled do
            task.wait(1)

            if not State.inRaid and not State.retrying then
                invokeQueue("idle")
            end

            if State.retrying and (os.clock() - State.lastRetry) > 8 then
                State.retrying = false
                State.inRaid = false
                log("RETRY TIMEOUT -> allowing fresh queue")
            end
        end
    end)
end

local function stop()
    if not State.enabled then return end

    State.enabled = false
    State.busy = false
    State.retrying = false

    disconnectAll()
    log("STOPPED")
end

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusAutoRaidTestV2"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(620, 440)
    root.Position = UDim2.new(0.5, -310, 0.5, -220)
    root.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "Nexus Auto Raid TEST v2"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 48)
    info.Position = UDim2.fromOffset(10, 42)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.Text = "Megumi raid lifecycle test. Uses existing queue/retry RemoteFunctions only."
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = root

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.fromOffset(130, 32)
    startBtn.Position = UDim2.fromOffset(10, 96)
    startBtn.Text = "START AUTO RAID"
    startBtn.Parent = root
    startBtn.MouseButton1Click:Connect(start)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.fromOffset(130, 32)
    stopBtn.Position = UDim2.fromOffset(150, 96)
    stopBtn.Text = "STOP"
    stopBtn.Parent = root
    stopBtn.MouseButton1Click:Connect(stop)

    local logBox = Instance.new("TextLabel")
    logBox.Size = UDim2.new(1, -20, 1, -140)
    logBox.Position = UDim2.fromOffset(10, 138)
    logBox.BackgroundTransparency = 0.1
    logBox.Font = Enum.Font.Code
    logBox.TextSize = 11
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.TextWrapped = false
    logBox.Text = ""
    logBox.Parent = root

    State.gui = {root=gui, log=logBox}
end

makeUI()
