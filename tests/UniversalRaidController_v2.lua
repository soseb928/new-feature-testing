-- NexusPlay Universal Raid Controller v1
-- TESTING ONLY: new-feature-testing
-- Uses normal client/server raid APIs observed from the game's raid lifecycle.
-- No damage spoofing, teleport spoofing, remote-hooking, or server-validation bypass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")

local RetryMethod = BossIslandService:WaitForChild("Retry_Method")

local State = {
    active = false,
    autoRetry = true,
    retryBusy = false,
    retryCount = 0,
    raidActive = false,
    lastEndAt = 0,
    lastRetryRequestAt = 0,
    connections = {},
    log = {},
    gui = nil,
    current = {
        raidId = nil,
        bossId = nil,
        difficulty = nil,
        modifiers = nil,
        matchState = nil,
        boss = nil,
        startTime = nil,
        retryTime = nil,
        retryingPlayers = nil,
    },
}

local function emit(msg)
    local line = os.date("%H:%M:%S") .. " | " .. tostring(msg)
    print("[UniversalRaidController v1] " .. line)

    table.insert(State.log, line)
    if #State.log > 100 then
        table.remove(State.log, 1)
    end

    if State.gui and State.gui.log then
        State.gui.log.Text = table.concat(State.log, "\n")
    end

    if State.gui and State.gui.status then
        State.gui.status.Text =
            "Raid: " .. tostring(State.current.raidId or State.current.bossId or "none")
            .. "\nState: " .. tostring(State.current.matchState)
            .. "\nActive: " .. tostring(State.raidActive)
            .. "\nAuto Retry: " .. tostring(State.autoRetry)
            .. "\nRetries: " .. tostring(State.retryCount)
    end
end

local function disconnectAll()
    for _, c in ipairs(State.connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(State.connections)
end

local function resetCurrent()
    State.raidActive = false
    State.current = {
        raidId = nil,
        bossId = nil,
        difficulty = nil,
        modifiers = nil,
        matchState = nil,
        boss = nil,
        startTime = nil,
        retryTime = nil,
        retryingPlayers = nil,
    }
end

local function retryRaid(reason)
    if not State.active or not State.autoRetry then
        return false
    end

    if State.retryBusy then
        emit("RETRY SKIP | already waiting for previous retry request")
        return false
    end

    if os.clock() - State.lastRetryRequestAt < 2.0 then
        emit("RETRY SKIP | retry request cooldown")
        return false
    end

    State.retryBusy = true
    State.lastRetryRequestAt = os.clock()
    emit("RETRY | request | reason=" .. tostring(reason))

    task.spawn(function()
        task.wait(0.75)

        local ok, result = pcall(function()
            return RetryMethod:InvokeServer()
        end)

        State.retryBusy = false

        if ok then
            State.retryCount += 1
            emit("RETRY response | " .. tostring(result))
        else
            emit("RETRY error | " .. tostring(result))
        end
    end)

    return true
end

local function attachRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then
        return
    end

    local name = remote.Name

    local connection = remote.OnClientEvent:Connect(function(...)
        local args = table.pack(...)

        if name == "MatchStateUpdated_Signal" then
            State.current.matchState = args[1]

            -- MatchState 3 was observed at raid start.
            if args[1] == 3 then
                State.raidActive = true
                emit("RAID STATE | started | MatchState=3")
            else
                emit("MATCH STATE | " .. tostring(args[1]))
            end

        elseif name == "RaidDataUpdated_Signal" then
            local data = args[1]

            if type(data) == "table" then
                State.current.bossId = data.BossID
                State.current.raidId = data.RaidID or data.BossID
                State.current.difficulty = data.Difficulty
                State.current.modifiers = data.Modifiers
                State.current.retryTime = data.RetryTime
                State.current.retryingPlayers = data.RetryingPlayers

                if type(data.State) == "table" then
                    State.current.startTime = data.State.StartTime
                end

                if data.Players ~= nil then
                    State.raidActive = next(data.Players) ~= nil
                end

                emit(
                    "RAID DATA | "
                    .. tostring(State.current.raidId)
                    .. " | Difficulty=" .. tostring(State.current.difficulty)
                    .. " | RetryTime=" .. tostring(State.current.retryTime)
                )
            end

        elseif name == "RaidBossSpawned_Signal" then
            State.current.boss = args[1]
            State.raidActive = true
            emit("BOSS SPAWN | detected")

        elseif name == "StartBossHandler_Signal" then
            -- Generic progression signal. Do not depend on boss-specific handler names.
            emit(
                "HANDLER | "
                .. tostring(args[1])
                .. " | "
                .. tostring(args[2])
                .. " | "
                .. tostring(args[3])
            )

        elseif name == "RaidEnded_Signal" then
            State.lastEndAt = os.clock()
            State.raidActive = false

            local success = args[1]
            emit("RAID END | success=" .. tostring(success))

            -- The game has already validated the raid result.
            -- Retry only after the server reports the raid has ended.
            if success == true then
                retryRaid("RaidEnded_Signal")
            end

        elseif name == "LobbyRemoved_Signal" then
            local data = args[1]

            if type(data) == "table" then
                emit(
                    "LOBBY REMOVED | IsTeleporting="
                    .. tostring(data.IsTeleporting)
                    .. " | RaidID="
                    .. tostring(data.RaidID)
                )
            else
                emit("LOBBY REMOVED")
            end
        end
    end)

    table.insert(State.connections, connection)
end

local function scanFolder(folder)
    if not folder then
        return
    end

    for _, child in ipairs(folder:GetChildren()) do
        attachRemote(child)
    end

    table.insert(State.connections, folder.ChildAdded:Connect(function(child)
        attachRemote(child)
    end))
end

local function start()
    if State.active then
        emit("START | already active")
        return
    end

    State.active = true
    State.retryBusy = false
    State.retryCount = 0
    State.lastEndAt = 0
    State.lastRetryRequestAt = 0
    resetCurrent()
    table.clear(State.log)

    emit("STARTED | universal raid lifecycle controller")
    emit("WATCH | RaidsService + BossIslandService")
    emit("AUTO RETRY | " .. tostring(State.autoRetry))
    emit("QUEUE | intentionally not hardcoded; raid-start API was not universally confirmed")

    scanFolder(RaidsService)
    scanFolder(BossIslandService)
end

local function stop()
    if not State.active then
        return
    end

    State.active = false
    State.retryBusy = false
    disconnectAll()

    emit("STOPPED")
end

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusUniversalRaidControllerV1"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(650, 500)
    root.Position = UDim2.new(0.5, -325, 0.5, -250)
    root.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "Nexus Universal Raid Controller v1"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 42)
    info.Position = UDim2.fromOffset(10, 42)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Text =
        "Universal lifecycle detection + server-validated retry. Start the raid normally; this controller observes it and requests retry after a successful RaidEnded event."
    info.Parent = root

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.fromOffset(130, 32)
    startBtn.Position = UDim2.fromOffset(10, 92)
    startBtn.Text = "START"
    startBtn.Parent = root
    startBtn.MouseButton1Click:Connect(start)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.fromOffset(100, 32)
    stopBtn.Position = UDim2.fromOffset(150, 92)
    stopBtn.Text = "STOP"
    stopBtn.Parent = root
    stopBtn.MouseButton1Click:Connect(stop)

    local retryBtn = Instance.new("TextButton")
    retryBtn.Size = UDim2.fromOffset(150, 32)
    retryBtn.Position = UDim2.fromOffset(260, 92)
    retryBtn.Text = "AUTO RETRY: ON"
    retryBtn.Parent = root
    retryBtn.MouseButton1Click:Connect(function()
        State.autoRetry = not State.autoRetry
        retryBtn.Text = State.autoRetry and "AUTO RETRY: ON" or "AUTO RETRY: OFF"
        emit("AUTO RETRY | " .. tostring(State.autoRetry))
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.42, -15, 1, -140)
    status.Position = UDim2.fromOffset(10, 135)
    status.BackgroundTransparency = 0.1
    status.Font = Enum.Font.Code
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Text = "Raid: none\nState: nil\nActive: false\nAuto Retry: true\nRetries: 0"
    status.Parent = root

    local log = Instance.new("TextLabel")
    log.Size = UDim2.new(0.58, -15, 1, -140)
    log.Position = UDim2.new(0.42, 5, 0, 135)
    log.BackgroundTransparency = 0.1
    log.Font = Enum.Font.Code
    log.TextSize = 10
    log.TextXAlignment = Enum.TextXAlignment.Left
    log.TextYAlignment = Enum.TextYAlignment.Top
    log.TextWrapped = false
    log.Text = ""
    log.Parent = root

    State.gui = {
        root = gui,
        status = status,
        log = log,
    }
end

makeUI()
