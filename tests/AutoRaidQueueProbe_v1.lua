-- NexusPlay Auto Raid Queue Probe v1
-- TESTING ONLY
-- Passive diagnostic: observes normal CreateIslandQueue_Method calls.
-- It does not invoke, modify, or spoof any remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local BossIslandService = NetworkComm:WaitForChild("BossIslandService")
local Target = BossIslandService:WaitForChild("CreateIslandQueue_Method")

local function safe(v, depth)
    depth = depth or 0
    if depth > 4 then return "<depth>" end
    local tv = typeof(v)
    if tv ~= "table" then return tostring(v) end
    local out = {}
    for k, x in pairs(v) do
        out[tostring(k)] = safe(x, depth + 1)
    end
    return out
end

local function dump(v, indent)
    indent = indent or ""
    if type(v) ~= "table" then
        print(indent .. tostring(v))
        return
    end
    for k, x in pairs(v) do
        if type(x) == "table" then
            print(indent .. tostring(k) .. " = {")
            dump(x, indent .. "  ")
            print(indent .. "}")
        else
            print(indent .. tostring(k) .. " = " .. tostring(x))
        end
    end
end

local hooked = false
local oldNamecall

if hookmetamethod and getnamecallmethod and newcclosure then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if self == Target and method == "InvokeServer" then
            print("[Auto Raid Queue Probe v1] ===== NORMAL QUEUE CALL =====")
            local args = table.pack(...)
            print("[Auto Raid Queue Probe v1] argc=" .. tostring(args.n))
            for i = 1, args.n do
                print("[Auto Raid Queue Probe v1] ARG " .. tostring(i) .. ":")
                dump(args[i], "  ")
            end
            print("[Auto Raid Queue Probe v1] ===== END QUEUE CALL =====")
        end

        return oldNamecall(self, ...)
    end))
    hooked = true
else
    print("[Auto Raid Queue Probe v1] ERROR | executor lacks hookmetamethod/getnamecallmethod/newcclosure")
end

print("[Auto Raid Queue Probe v1] STARTED | hooked=" .. tostring(hooked))
print("[Auto Raid Queue Probe v1] ACTION | now manually start ONE raid from the normal game UI")
print("[Auto Raid Queue Probe v1] ACTION | do not enable Auto Raid yet")
