-- NexusPlay Raid Debug Monitor
-- TEST ONLY: observes raid state. Does NOT start raids, invoke retry, teleport, or modify remotes.
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local S = {
    running = false,
    thread = nil,
    gui = nil,
    logs = {},
    last = {},
    interval = 0.5,
    maxLogs = 200,
}

local RAID_DEFS = {
    {name="StarRage", zones={"StarRage","StarRageRaid"}, boss={"yuki","awakened star","star rage"}},
    {name="Blood", zones={"Choso"}, boss={"choso"}},
    {name="Lightning", zones={"AKashimo"}, boss={"awakened lightning god"}},
    {name="Yuta", zones={"Yuta"}, boss={"cursed prodigy"}},
    {name="Judge", zones={"Judge"}, boss={"deadly judge"}},
    {name="Jogo", zones={"Jogo"}, boss={"jogo"}},
    {name="Toji", zones={"Toji"}, boss={"sorcerer killer"}},
    {name="Sukuna", zones={"Sukuna"}, boss={"king of curses"}},
    {name="Awakened Toji", zones={"AToji"}, boss={"awakened toji"}},
    {name="Maki", zones={"Maki"}, boss={"awakened zen'in"}},
    {name="Awakened Gojo", zones={"AGojo"}, boss={"the honored one","gojo"}},
    {name="Curse Calamity", zones={"CurseCalamity"}, boss={"heian raider","the follower","calamity curse"}},
}

local function low(v)
    return string.lower(tostring(v or ""))
end

local function rootOf(x)
    if not x then return nil end
    if x:IsA("BasePart") then return x end
    if x:IsA("Model") then
        local h = x:FindFirstChild("HumanoidRootPart")
        if h and h:IsA("BasePart") then return h end
        if x.PrimaryPart then return x.PrimaryPart end
        return x:FindFirstChildWhichIsA("BasePart", true)
    end
    return x:FindFirstChildWhichIsA("BasePart", true)
end

local function getMyRoot()
    local c = LP.Character
    return c and rootOf(c)
end

local function fullName(x)
    return x and x:GetFullName() or "-"
end

local function findQueueZones()
    local f = workspace:FindFirstChild("QueueZones")
    if f then return f end
    local map = workspace:FindFirstChild("Map")
    if map then
        f = map:FindFirstChild("QueueZones", true)
        if f then return f end
    end
    return workspace:FindFirstChild("QueueZones", true)
end

local function getQueueMatches()
    local qz = findQueueZones()
    if not qz then return {} end
    local out = {}
    for _, d in ipairs(qz:GetDescendants()) do
        local n = low(d.Name)
        for _, def in ipairs(RAID_DEFS) do
            for _, zone in ipairs(def.zones) do
                if n == low(zone) or n:find(low(zone), 1, true) then
                    table.insert(out, {def=def, inst=d})
                    break
                end
            end
        end
    end
    return out
end

local function readTextFields(inst)
    local rows = {}
    if not inst then return rows end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text
            if t and t ~= "" then
                local n = low(d.Name)
                if n:find("duration") or n:find("player") or n:find("count") or n:find("status") or n:find("timer") or low(t):find("starting") or low(t):find("second") or low(t):find("retry") then
                    table.insert(rows, d.Name .. "=" .. tostring(t))
                end
            end
        end
    end
    table.sort(rows)
    return rows
end

local function findBosses()
    local me = getMyRoot()
    local out = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d ~= LP.Character then
            local name = low(d:GetFullName())
            local matched
            for _, def in ipairs(RAID_DEFS) do
                for _, tag in ipairs(def.boss) do
                    if name:find(low(tag), 1, true) then
                        matched = def.name
                        break
                    end
                end
                if matched then break end
            end
            if matched then
                local r = rootOf(d)
                local hum = d:FindFirstChildOfClass("Humanoid")
                local hp = hum and hum.Health or nil
                local maxhp = hum and hum.MaxHealth or nil
                local dist = (me and r) and (r.Position - me.Position).Magnitude or nil
                table.insert(out, {
                    raid=matched,
                    path=d:GetFullName(),
                    hp=hp,
                    maxhp=maxhp,
                    dist=dist,
                })
            end
        end
    end
    table.sort(out, function(a,b)
        return (a.dist or math.huge) < (b.dist or math.huge)
    end)
    return out
end

local function inspectRaidRemotes()
    local results = {}
    local services = {
        "BossIslandService",
        "RaidsService",
    }
    for _, serviceName in ipairs(services) do
        local service = Net and nil
        local folder = RepStorage:FindFirstChild("NetworkComm")
        local obj = folder and folder:FindFirstChild(serviceName)
        if obj then
            table.insert(results, serviceName .. " found")
            for _, d in ipairs(obj:GetChildren()) do
                local n = low(d.Name)
                if n:find("raid") or n:find("retry") or n:find("ready") or n:find("island") or n:find("return") then
                    table.insert(results, "  " .. d.Name .. " [" .. d.ClassName .. "]")
                end
            end
        else
            table.insert(results, serviceName .. " missing")
        end
    end
    return results
end

local function snapshot()
    local rows = {}
    local place = game.PlaceId
    local q = getQueueMatches()
    local bosses = findBosses()

    table.insert(rows, "PlaceId=" .. tostring(place))
    table.insert(rows, "PlaceName=" .. tostring(game.Name))
    table.insert(rows, "QueueZones=" .. tostring(#q))
    for _, x in ipairs(q) do
        local texts = readTextFields(x.inst)
        table.insert(rows, "QUEUE " .. x.def.name .. " -> " .. fullName(x.inst))
        if #texts > 0 then
            for _, t in ipairs(texts) do table.insert(rows, "  " .. t) end
        end
    end

    table.insert(rows, "BossMatches=" .. tostring(#bosses))
    for _, b in ipairs(bosses) do
        table.insert(rows, string.format("BOSS %s | %.1f/%.1f | dist=%s | %s",
            b.raid, b.hp or -1, b.maxhp or -1,
            b.dist and string.format("%.1f", b.dist) or "-",
            b.path))
    end

    local remotes = inspectRaidRemotes()
    for _, r in ipairs(remotes) do table.insert(rows, "REMOTE " .. r) end

    local textBlob = table.concat(rows, "\n")
    return rows, textBlob
end

local function emit(msg)
    print("[RaidDebug] " .. tostring(msg))
    table.insert(S.logs, os.date("%H:%M:%S") .. " | " .. tostring(msg))
    if #S.logs > S.maxLogs then table.remove(S.logs, 1) end
    if S.gui and S.gui.log then
        S.gui.log.Text = table.concat(S.logs, "\n")
    end
end

local function diffSnapshot(rows)
    local now = {}
    for _, row in ipairs(rows) do now[row] = true end
    for _, row in ipairs(rows) do
        if not S.last[row] then emit(row) end
    end
    for row in pairs(S.last) do
        if not now[row] then emit("REMOVED " .. row) end
    end
    S.last = now
end

function S.Snapshot()
    local rows, blob = snapshot()
    print("[RaidDebug] ===== SNAPSHOT =====")
    print(blob)
    print("[RaidDebug] ===== END SNAPSHOT =====")
    return rows
end

function S.Start()
    if S.running then return end
    S.running = true
    emit("Monitor started")
    S.thread = task.spawn(function()
        while S.running do
            local ok, err = pcall(function()
                local rows = snapshot()
                diffSnapshot(rows)
            end)
            if not ok then emit("SCAN ERROR: " .. tostring(err)) end
            task.wait(S.interval)
        end
    end)
end

function S.Stop()
    S.running = false
    emit("Monitor stopped")
end

function S.Clear()
    table.clear(S.logs)
    table.clear(S.last)
    if S.gui and S.gui.log then S.gui.log.Text = "" end
end

function S.CreateUI()
    if S.gui and S.gui.root then S.gui.root:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusRaidDebugMonitor"
    gui.ResetOnSpawn = false
    gui.Parent = LP:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(560, 500)
    root.Position = UDim2.new(0.5, -280, 0.5, -250)
    root.BackgroundTransparency = 0.08
    root.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.fromOffset(10, 8)
    title.BackgroundTransparency = 1
    title.Text = "Nexus Raid Debug Monitor"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 42)
    info.Position = UDim2.fromOffset(10, 40)
    info.BackgroundTransparency = 1
    info.TextWrapped = true
    info.Text = "Diagnostic only: observes queue, raid place, bosses, UI text and raid-related remotes. No raid/retry actions are sent."
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = root

    local start = Instance.new("TextButton")
    start.Size = UDim2.fromOffset(120, 30)
    start.Position = UDim2.fromOffset(10, 88)
    start.Text = "START"
    start.Parent = root
    start.MouseButton1Click:Connect(function() S.Start() end)

    local stop = Instance.new("TextButton")
    stop.Size = UDim2.fromOffset(120, 30)
    stop.Position = UDim2.fromOffset(140, 88)
    stop.Text = "STOP"
    stop.Parent = root
    stop.MouseButton1Click:Connect(function() S.Stop() end)

    local snap = Instance.new("TextButton")
    snap.Size = UDim2.fromOffset(120, 30)
    snap.Position = UDim2.fromOffset(270, 88)
    snap.Text = "SNAPSHOT"
    snap.Parent = root
    snap.MouseButton1Click:Connect(function() S.Snapshot() end)

    local clear = Instance.new("TextButton")
    clear.Size = UDim2.fromOffset(120, 30)
    clear.Position = UDim2.fromOffset(400, 88)
    clear.Text = "CLEAR"
    clear.Parent = root
    clear.MouseButton1Click:Connect(function() S.Clear() end)

    local log = Instance.new("TextLabel")
    log.Size = UDim2.new(1, -20, 1, -130)
    log.Position = UDim2.fromOffset(10, 125)
    log.BackgroundTransparency = 0.15
    log.TextWrapped = false
    log.TextYAlignment = Enum.TextYAlignment.Top
    log.TextXAlignment = Enum.TextXAlignment.Left
    log.Font = Enum.Font.Code
    log.TextSize = 11
    log.Text = ""
    log.Parent = root

    S.gui = {root=gui, log=log}
    return gui
end

S.CreateUI()
return S
