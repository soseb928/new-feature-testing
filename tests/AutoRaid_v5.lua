-- NexusPlay Auto Raid v5
-- Clean queue test. Uses normal game queue remote and legitimate queue-zone positioning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")
local QueueRemote = BossIslandService:WaitForChild("CreateIslandQueue_Method")

local SELECTED_RAID = "Jogo"
local DIFFICULTY = 5
local PREFIX = "[Auto Raid v5]"

local function log(s) print(PREFIX.." "..os.date("%H:%M:%S").." | "..tostring(s)) end

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function findQueuePad(name)
    local qz = workspace:FindFirstChild("QueueZones")
    if not qz then
        local map = workspace:FindFirstChild("Map")
        qz = map and map:FindFirstChild("QueueZones", true)
    end
    if not qz then
        qz = workspace:FindFirstChild("QueueZones", true)
    end
    if not qz then return nil end

    local p = qz:FindFirstChild(name) or qz:FindFirstChild(name, true)
    if p then return p end

    local want = string.lower(name)
    for _, d in ipairs(qz:GetDescendants()) do
        if string.find(string.lower(d.Name), want, 1, true) then
            return d
        end
    end
    return nil
end

local function getPosition(inst)
    if not inst then return nil end
    local ok, pos = pcall(function()
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Attachment") then
            return inst.WorldPosition
        elseif inst:IsA("Model") then
            return inst:GetPivot().Position
        end
    end)
    if ok and typeof(pos) == "Vector3" then return pos end

    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

log("START | clean v5")
log("CHECK | searching QueueZones for "..SELECTED_RAID)

local pad = findQueuePad(SELECTED_RAID)
if not pad then
    log("FAIL | QueueZone "..SELECTED_RAID.." not found")
    return
end

local pos = getPosition(pad)
if not pos then
    log("FAIL | QueueZone found but position unavailable")
    return
end

log("PASS | QueueZone="..pad:GetFullName())
log("PASS | QueuePosition="..tostring(pos))

local hrp = getHRP()
if not hrp then
    log("FAIL | HumanoidRootPart unavailable")
    return
end

local before = hrp.Position
log("STATE | player distance to queue zone="..tostring((before-pos).Magnitude))

pcall(function()
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
end)

task.wait(0.5)

hrp = getHRP()
if not hrp then
    log("FAIL | HumanoidRootPart disappeared")
    return
end

log("STATE | player distance after positioning="..tostring((hrp.Position-pos).Magnitude))

local payload = {
    Difficulty = DIFFICULTY,
    ConfigID = SELECTED_RAID,
    Modifiers = {},
}

log("QUEUE | ConfigID="..SELECTED_RAID.." | Difficulty="..DIFFICULTY)

local ok, result = pcall(function()
    return QueueRemote:InvokeServer(payload)
end)

log("QUEUE RESULT | ok="..tostring(ok).." | result="..tostring(result))

if ok and result ~= false then
    log("SUCCESS | server accepted queue request")
else
    log("REJECTED | server still rejected normal queue request")
end
