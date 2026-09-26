-- Zen'in Elite Config Scanner
-- Passive diagnostic only: scans client-visible descendants and raid remotes/data for
-- names containing Zenin/Elite, then reports nearby candidates. Does not invoke remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

local function pathOf(x)
    local ok, p = pcall(function() return x:GetFullName() end)
    return ok and p or "?"
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function matches(s)
    s = lower(s)
    return s:find("zenin", 1, true) or s:find("zen'in", 1, true) or s:find("elite", 1, true)
end

print("================================================")
print("[Zenin Scanner] START")
print("[Zenin Scanner] Player =", player and player.Name or "?")

local seen = {}
local function report(inst, why)
    if seen[inst] then return end
    seen[inst] = true
    print(string.format("[Zenin Scanner] MATCH | %s | %s | class=%s", why, pathOf(inst), inst.ClassName))
end

for _, root in ipairs({Workspace, ReplicatedStorage}) do
    print("[Zenin Scanner] ROOT", root:GetFullName())
    for _, inst in ipairs(root:GetDescendants()) do
        if matches(inst.Name) then
            report(inst, "name")
        end
        if inst:IsA("StringValue") or inst:IsA("IntValue") or inst:IsA("NumberValue") or inst:IsA("BoolValue") then
            local ok, v = pcall(function() return inst.Value end)
            if ok and matches(v) then
                report(inst, "value=" .. tostring(v))
            end
        end
    end
end

local net = ReplicatedStorage:FindFirstChild("NetworkComm")
local boss = net and net:FindFirstChild("BossIslandService")
if boss then
    print("[Zenin Scanner] BossIslandService remotes:")
    for _, x in ipairs(boss:GetChildren()) do
        print("  ", x.Name, x.ClassName)
    end
end

local raid = net and net:FindFirstChild("RaidsService")
if raid then
    print("[Zenin Scanner] RaidsService remotes:")
    for _, x in ipairs(raid:GetChildren()) do
        print("  ", x.Name, x.ClassName)
    end
end

local qz = Workspace:FindFirstChild("QueueZones", true)
if qz then
    print("[Zenin Scanner] QueueZones =", pathOf(qz))
    for _, x in ipairs(qz:GetDescendants()) do
        print("[Zenin Scanner] QUEUEZONE |", pathOf(x), "| class=" .. x.ClassName)
    end
else
    print("[Zenin Scanner] QueueZones not found")
end

print("[Zenin Scanner] END")
print("================================================")
