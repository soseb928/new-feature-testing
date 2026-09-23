-- NexusPlay Retry Diagnostic v3
-- TESTING ONLY: new-feature-testing
-- Diagnostic/normal API use only. Does not hook, spoof, or bypass server validation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")

local RetryMethod = BossIslandService:WaitForChild("Retry_Method")

local active = false
local retryBusy = false
local conns = {}
local log = {}
local gui

local state = {
    raidId = nil,
    bossId = nil,
    difficulty = nil,
    modifiers = nil,
    retryTime = nil,
    retryingPlayers = nil,
    players = nil,
    lastRaidEnd = nil,
}

local function emit(msg)
    local line = os.date("%H:%M:%S") .. " | " .. tostring(msg)
    print("[NexusRetryDiag v3] " .. line)
    table.insert(log, line)
    if #log > 120 then table.remove(log, 1) end
    if gui and gui.log then gui.log.Text = table.concat(log, "\n") end
end

local function disconnect()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
end

local function tableCount(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

local function describeRaidData(data, label)
    if type(data) ~= "table" then
        emit(label .. " | non-table payload=" .. tostring(data))
        return
    end

    state.raidId = data.RaidID or data.BossID
    state.bossId = data.BossID
    state.difficulty = data.Difficulty
    state.modifiers = data.Modifiers
    state.retryTime = data.RetryTime
    state.retryingPlayers = data.RetryingPlayers
    state.players = data.Players

    emit(
        label
        .. " | RaidID=" .. tostring(state.raidId)
        .. " | BossID=" .. tostring(state.bossId)
        .. " | Difficulty=" .. tostring(state.difficulty)
        .. " | Players=" .. tostring(tableCount(state.players))
        .. " | RetryingPlayers=" .. tostring(tableCount(state.retryingPlayers))
        .. " | RetryTime=" .. tostring(state.retryTime)
    )
end

local function attach(remote)
    if not remote:IsA("RemoteEvent") then return end

    local name = remote.Name
    local c = remote.OnClientEvent:Connect(function(...)
        local a = table.pack(...)

        if name == "RaidDataUpdated_Signal" then
            describeRaidData(a[1], "RAID DATA")
        elseif name == "RaidEnded_Signal" then
            state.lastRaidEnd = os.clock()
            emit("RAID END | success=" .. tostring(a[1]))
        elseif name == "LobbyRemoved_Signal" then
            local d = a[1]
            if type(d) == "table" then
                emit(
                    "LOBBY REMOVED"
                    .. " | RaidID=" .. tostring(d.RaidID)
                    .. " | IsTeleporting=" .. tostring(d.IsTeleporting)
                    .. " | Players=" .. tostring(tableCount(d.Players))
                )
            else
                emit("LOBBY REMOVED | payload=" .. tostring(d))
            end
        elseif name == "MatchStateUpdated_Signal" then
            emit("MATCH STATE | " .. tostring(a[1]))
        elseif name == "ReturnToMain_Signal" then
            emit("RETURN TO MAIN | argc=" .. tostring(a.n))
        elseif name == "ReturnToLobby_Method" then
            emit("UNEXPECTED REMOTEEVENT NAME | ReturnToLobby_Method")
        end
    end)

    table.insert(conns, c)
end

local function scan()
    for _, child in ipairs(RaidsService:GetChildren()) do attach(child) end
    for _, child in ipairs(BossIslandService:GetChildren()) do attach(child) end

    table.insert(conns, RaidsService.ChildAdded:Connect(attach))
    table.insert(conns, BossIslandService.ChildAdded:Connect(attach))
end

local function snapshot(tag)
    emit(
        "SNAPSHOT " .. tag
        .. " | RaidID=" .. tostring(state.raidId)
        .. " | Players=" .. tostring(tableCount(state.players))
        .. " | RetryingPlayers=" .. tostring(tableCount(state.retryingPlayers))
        .. " | RetryTime=" .. tostring(state.retryTime)
    )
end

local function invokeRetry(source)
    if retryBusy then
        emit("RETRY SKIP | busy")
        return
    end

    retryBusy = true
    local t0 = os.clock()

    snapshot("BEFORE " .. source)
    emit("RETRY CALL | BossIslandService.Retry_Method | source=" .. source)

    local ok, result = pcall(function()
        return RetryMethod:InvokeServer()
    end)

    local dt = os.clock() - t0
    retryBusy = false

    emit(
        "RETRY RESULT"
        .. " | ok=" .. tostring(ok)
        .. " | result=" .. tostring(result)
        .. " | elapsed=" .. string.format("%.3f", dt) .. "s"
    )

    task.delay(0.25, function()
        snapshot("AFTER 0.25s " .. source)
    end)

    task.delay(1.0, function()
        snapshot("AFTER 1.0s " .. source)
    end)

    task.delay(3.0, function()
        snapshot("AFTER 3.0s " .. source)
    end)
end

local function start()
    if active then
        emit("START | already active")
        return
    end

    active = true
    table.clear(log)
    emit("STARTED | Retry Diagnostic v3")
    emit("WATCH | RaidsService + BossIslandService")
    emit("IMPORTANT | this version has a unique prefix; use this loadstring only")
    scan()
end

local function stop()
    active = false
    disconnect()
    emit("STOPPED")
end

local function makeUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "NexusRetryDiagnosticV3"
    sg.ResetOnSpawn = false
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(720, 520)
    root.Position = UDim2.new(0.5, -360, 0.5, -260)
    root.Parent = sg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "Nexus Retry Diagnostic v3"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.fromOffset(110, 32)
    startBtn.Position = UDim2.fromOffset(10, 48)
    startBtn.Text = "START"
    startBtn.Parent = root
    startBtn.MouseButton1Click:Connect(start)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.fromOffset(110, 32)
    stopBtn.Position = UDim2.fromOffset(130, 48)
    stopBtn.Text = "STOP"
    stopBtn.Parent = root
    stopBtn.MouseButton1Click:Connect(stop)

    local retryBtn = Instance.new("TextButton")
    retryBtn.Size = UDim2.fromOffset(170, 32)
    retryBtn.Position = UDim2.fromOffset(250, 48)
    retryBtn.Text = "TEST RETRY METHOD"
    retryBtn.Parent = root
    retryBtn.MouseButton1Click:Connect(function()
        invokeRetry("manual button")
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 55)
    status.Position = UDim2.fromOffset(10, 88)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Text = "Start, run a raid normally, then inspect the automatic retry trace."
    status.Parent = root

    local logBox = Instance.new("TextLabel")
    logBox.Size = UDim2.new(1, -20, 1, -155)
    logBox.Position = UDim2.fromOffset(10, 145)
    logBox.BackgroundTransparency = 0.1
    logBox.Font = Enum.Font.Code
    logBox.TextSize = 10
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.TextWrapped = false
    logBox.Text = ""
    logBox.Parent = root

    gui = {log = logBox}
end

makeUI()

-- Start automatically so the test cannot accidentally use an old state.
start()

-- Automatic retry trigger: only after a successful raid end.
table.insert(conns, RaidsService.RaidEnded_Signal.OnClientEvent:Connect(function(success)
    if success == true and active then
        task.wait(0.1)
        invokeRetry("automatic after RaidEnded")
    end
end))
