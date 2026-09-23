-- NexusPlay Universal Raid Scanner v1
-- Diagnostic only: observes normal client-side raid events/state.
-- Does NOT InvokeServer, FireServer, modify damage, teleport, prompts, or gameplay state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")
local ArenaService = NetworkComm:FindFirstChild("ArenaService")

local State = {
    active = false,
    connections = {},
    log = {},
    gui = nil,
    current = {
        bossId = nil,
        raidId = nil,
        difficulty = nil,
        modifiers = nil,
        players = nil,
        userIds = nil,
        retryTime = nil,
        retryingPlayers = nil,
        boss = nil,
        matchState = nil,
        startTime = nil,
    },
}

local function stringify(v, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return "<depth>"
    end

    local tv = typeof(v)

    if v == nil then
        return "nil"
    elseif tv == "string" or tv == "number" or tv == "boolean" then
        return tostring(v)
    elseif tv == "Instance" then
        local ok, full = pcall(function() return v:GetFullName() end)
        return ok and full or v.Name
    elseif tv == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
    elseif tv == "CFrame" then
        return "CFrame"
    elseif tv == "table" then
        if seen[v] then return "<cycle>" end
        seen[v] = true

        local parts = {}
        for k, x in pairs(v) do
            if #parts >= 40 then
                table.insert(parts, "...")
                break
            end
            table.insert(parts, "[" .. stringify(k, depth + 1, seen) .. "]=" .. stringify(x, depth + 1, seen))
        end

        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    return tostring(v)
end

local function countTable(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

local function modifierText(mods)
    if type(mods) ~= "table" then
        return tostring(mods)
    end

    local out = {}
    for k, v in pairs(mods) do
        if v == true then
            table.insert(out, tostring(k))
        else
            table.insert(out, tostring(k) .. "=" .. tostring(v))
        end
    end

    table.sort(out)
    return #out > 0 and table.concat(out, ", ") or "none"
end

local function summary()
    local s = State.current

    return table.concat({
        "BossID: " .. tostring(s.bossId),
        "RaidID: " .. tostring(s.raidId),
        "Difficulty: " .. tostring(s.difficulty),
        "Modifiers: " .. modifierText(s.modifiers),
        "Players: " .. tostring(countTable(s.players)),
        "RetryingPlayers: " .. tostring(countTable(s.retryingPlayers)),
        "RetryTime: " .. tostring(s.retryTime),
        "MatchState: " .. tostring(s.matchState),
        "Boss: " .. tostring(s.boss),
        "StartTime: " .. tostring(s.startTime),
    }, "\n")
end

local function emit(msg)
    local line = os.date("%H:%M:%S") .. " | " .. tostring(msg)
    print("[RaidScanner v1] " .. line)

    table.insert(State.log, line)
    if #State.log > 120 then
        table.remove(State.log, 1)
    end

    if State.gui then
        if State.gui.summary then
            State.gui.summary.Text = summary()
        end
        if State.gui.log then
            State.gui.log.Text = table.concat(State.log, "\n")
        end
    end
end

local function disconnectAll()
    for _, c in ipairs(State.connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(State.connections)
end

local function attachRemote(remote, category)
    if not remote or not remote:IsA("RemoteEvent") then
        return
    end

    local connection = remote.OnClientEvent:Connect(function(...)
        local args = table.pack(...)

        emit("EVENT | " .. category .. "." .. remote.Name .. " | argc=" .. tostring(args.n))

        for i = 1, args.n do
            emit("ARG" .. tostring(i) .. " | " .. stringify(args[i]))
        end

        -- Parse known raid state without assuming a particular boss/config.
        if remote.Name == "RaidDataUpdated_Signal" and type(args[1]) == "table" then
            local data = args[1]

            State.current.bossId = data.BossID
            State.current.raidId = data.RaidID or data.BossID
            State.current.difficulty = data.Difficulty
            State.current.modifiers = data.Modifiers
            State.current.players = data.Players
            State.current.userIds = data.UserIDs
            State.current.retryTime = data.RetryTime
            State.current.retryingPlayers = data.RetryingPlayers

            if type(data.State) == "table" then
                State.current.startTime = data.State.StartTime
            end

            emit("RAID DETECTED | BossID=" .. tostring(State.current.bossId)
                .. " | RaidID=" .. tostring(State.current.raidId)
                .. " | Difficulty=" .. tostring(State.current.difficulty)
                .. " | Modifiers=" .. modifierText(State.current.modifiers)
                .. " | Players=" .. tostring(countTable(State.current.players))
                .. " | Retrying=" .. tostring(countTable(State.current.retryingPlayers)))
        elseif remote.Name == "RaidBossSpawned_Signal" then
            State.current.boss = args[1]
            emit("BOSS SPAWN | " .. stringify(args[1]))
        elseif remote.Name == "MatchStateUpdated_Signal" then
            State.current.matchState = args[1]
            emit("MATCH STATE | " .. stringify(args[1]))
        elseif remote.Name == "RaidEnded_Signal" then
            emit("RAID END | success=" .. tostring(args[1]) .. " | payload=" .. stringify(args[2]))
        elseif remote.Name == "LobbyRemoved_Signal" then
            emit("LOBBY REMOVED | " .. stringify(args[1]))
        elseif remote.Name == "StartBossHandler_Signal" then
            emit("BOSS HANDLER | " .. stringify(args[1]) .. " | " .. stringify(args[2]) .. " | " .. stringify(args[3]))
        end
    end)

    table.insert(State.connections, connection)
end

local function scanFolder(folder, category)
    if not folder then return end

    for _, child in ipairs(folder:GetChildren()) do
        attachRemote(child, category)
    end

    table.insert(State.connections, folder.ChildAdded:Connect(function(child)
        attachRemote(child, category)
        emit("REMOTE ADDED | " .. category .. "." .. child.Name .. " | " .. child.ClassName)
    end))
end

local function resetState()
    State.current = {
        bossId = nil,
        raidId = nil,
        difficulty = nil,
        modifiers = nil,
        players = nil,
        userIds = nil,
        retryTime = nil,
        retryingPlayers = nil,
        boss = nil,
        matchState = nil,
        startTime = nil,
    }

    if State.gui and State.gui.summary then
        State.gui.summary.Text = summary()
    end
end

local function start()
    if State.active then return end

    State.active = true
    resetState()
    disconnectAll()

    emit("STARTED | passive universal raid scanner")
    emit("WATCH | RaidsService + BossIslandService + ArenaService")
    emit("SAFE MODE | no RemoteFunction/RemoteEvent calls are sent")

    scanFolder(RaidsService, "RaidsService")
    scanFolder(BossIslandService, "BossIslandService")
    scanFolder(ArenaService, "ArenaService")
end

local function stop()
    if not State.active then return end

    State.active = false
    disconnectAll()
    emit("STOPPED")
end

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusRaidUniversalScannerV1"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(760, 560)
    root.Position = UDim2.new(0.5, -380, 0.5, -280)
    root.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 34)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "Nexus Universal Raid Scanner v1"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 38)
    info.Position = UDim2.fromOffset(10, 42)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.Text = "Start scanner, then start any raid normally. It automatically records the boss/raid data and lifecycle events."
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = root

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.fromOffset(130, 32)
    startBtn.Position = UDim2.fromOffset(10, 88)
    startBtn.Text = "START SCANNER"
    startBtn.Parent = root
    startBtn.MouseButton1Click:Connect(start)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.fromOffset(100, 32)
    stopBtn.Position = UDim2.fromOffset(150, 88)
    stopBtn.Text = "STOP"
    stopBtn.Parent = root
    stopBtn.MouseButton1Click:Connect(stop)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.fromOffset(100, 32)
    resetBtn.Position = UDim2.fromOffset(260, 88)
    resetBtn.Text = "RESET"
    resetBtn.Parent = root
    resetBtn.MouseButton1Click:Connect(resetState)

    local summaryBox = Instance.new("TextLabel")
    summaryBox.Size = UDim2.new(0.45, -15, 1, -135)
    summaryBox.Position = UDim2.fromOffset(10, 130)
    summaryBox.BackgroundTransparency = 0.1
    summaryBox.Font = Enum.Font.Code
    summaryBox.TextSize = 12
    summaryBox.TextXAlignment = Enum.TextXAlignment.Left
    summaryBox.TextYAlignment = Enum.TextYAlignment.Top
    summaryBox.TextWrapped = false
    summaryBox.Text = summary()
    summaryBox.Parent = root

    local logBox = Instance.new("TextLabel")
    logBox.Size = UDim2.new(0.55, -15, 1, -135)
    logBox.Position = UDim2.new(0.45, 5, 0, 130)
    logBox.BackgroundTransparency = 0.1
    logBox.Font = Enum.Font.Code
    logBox.TextSize = 10
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.TextWrapped = false
    logBox.Text = ""
    logBox.Parent = root

    State.gui = {
        root = gui,
        summary = summaryBox,
        log = logBox,
    }
end

makeUI()
