-- NexusPlay Manual Retry Observer v1
-- TESTING ONLY: observes the game's visible Retry UI and raid state.
-- Does not invoke hidden remotes or bypass server validation.
-- User must press the game's normal Retry button manually.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")

local active = true
local conns = {}
local watchedButtons = {}
local log = {}

local function emit(msg)
    local line = os.date("%H:%M:%S") .. " | " .. tostring(msg)
    print("[ManualRetryObserver v1] " .. line)
    table.insert(log, line)
    if #log > 150 then table.remove(log, 1) end
end

local function disconnect()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
end

local function describe(obj)
    local text = ""
    pcall(function() text = obj.Text end)

    emit(
        "UI CANDIDATE | "
        .. obj:GetFullName()
        .. " | Class=" .. obj.ClassName
        .. " | Text=" .. tostring(text)
        .. " | Visible=" .. tostring(obj.Visible)
    )
end

local function isRetryCandidate(obj)
    if not obj:IsA("GuiButton") then return false end

    local name = string.lower(obj.Name)
    local text = ""
    pcall(function() text = string.lower(obj.Text or "") end)

    return name:find("retry", 1, true)
        or text:find("retry", 1, true)
        or name:find("again", 1, true)
        or text:find("again", 1, true)
end

local function watch(obj)
    if not active or not isRetryCandidate(obj) or watchedButtons[obj] then return end

    watchedButtons[obj] = true
    describe(obj)

    local ok, conn = pcall(function()
        return obj.Activated:Connect(function()
            emit("NORMAL RETRY UI ACTIVATED | " .. obj:GetFullName())
            emit("ACTION | user clicked the game's visible Retry button")
            emit("WATCH | now capture RaidDataUpdated/LobbyRemoved/MatchState changes")
        end)
    end)

    if ok and conn then
        table.insert(conns, conn)
    end
end

local function scanGui()
    local pg = LocalPlayer:WaitForChild("PlayerGui")

    for _, obj in ipairs(pg:GetDescendants()) do
        watch(obj)
    end

    table.insert(conns, pg.DescendantAdded:Connect(function(obj)
        watch(obj)
    end))

    emit("GUI WATCH | PlayerGui descendants")
end

local function attachRemote(remote)
    if not remote:IsA("RemoteEvent") then return end

    local name = remote.Name

    local conn = remote.OnClientEvent:Connect(function(...)
        local args = table.pack(...)

        if name == "RaidDataUpdated_Signal" then
            local d = args[1]
            if type(d) == "table" then
                emit(
                    "RAID DATA"
                    .. " | RaidID=" .. tostring(d.RaidID or d.BossID)
                    .. " | Players=" .. tostring(type(d.Players) == "table" and #d.Players or 0)
                    .. " | RetryTime=" .. tostring(d.RetryTime)
                    .. " | RetryingPlayers=" .. tostring(d.RetryingPlayers)
                )
            else
                emit("RAID DATA | non-table")
            end

        elseif name == "LobbyRemoved_Signal" then
            local d = args[1]
            emit("LOBBY REMOVED | " .. tostring(d))

        elseif name == "MatchStateUpdated_Signal" then
            emit("MATCH STATE | " .. tostring(args[1]))

        elseif name == "RaidEnded_Signal" then
            emit("RAID END | success=" .. tostring(args[1]))
        end
    end)

    table.insert(conns, conn)
end

for _, obj in ipairs(RaidsService:GetChildren()) do
    attachRemote(obj)
end

for _, obj in ipairs(BossIslandService:GetChildren()) do
    attachRemote(obj)
end

table.insert(conns, RaidsService.ChildAdded:Connect(attachRemote))
table.insert(conns, BossIslandService.ChildAdded:Connect(attachRemote))

scanGui()

emit("STARTED | Manual Retry Observer v1")
emit("IMPORTANT | run one raid normally")
emit("IMPORTANT | after RaidEnded, press the game's normal Retry button manually")
emit("IMPORTANT | do NOT press any Retry button created by this script; this script creates none")
