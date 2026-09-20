-- Awakened Limitless Damage Diagnostic Scanner
-- TEST ONLY: observes Humanoid.HealthChanged.
-- Does not alter damage, cooldowns, remotes, or skill payloads.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local S = {active=false, connection=nil, target=nil, humanoid=nil, skill="UNMARKED", before=nil, hits=0, total=0, events={}}

local function getHumanoid(model)
    return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
end

local function nearestHumanoid()
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local best, bestDist
    for _, h in ipairs(workspace:GetDescendants()) do
        if h:IsA("Humanoid") and h.Health > 0 and h.Parent ~= c then
            local model = h.Parent
            local hrp = model and model:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = model, d
                end
            end
        end
    end
    return best
end

function S.Mark(skillName)
    S.skill = tostring(skillName or "UNMARKED")
    S.hits, S.total = 0, 0
    S.before = S.humanoid and S.humanoid.Health
    S.t0 = os.clock()
    print("[AwkScanner] MARK", S.skill, "HP before", S.before)
end

function S.Start(targetModel)
    S.Stop()
    local target = targetModel or nearestHumanoid()
    local h = getHumanoid(target)
    if not h then
        warn("[AwkScanner] No valid target.")
        return false
    end

    S.target, S.humanoid, S.before = target, h, h.Health
    S.active, S.t0 = true, os.clock()

    S.connection = h.HealthChanged:Connect(function(newHealth)
        if not S.active then return end
        local oldHealth = S.before
        S.before = newHealth
        if oldHealth and newHealth < oldHealth then
            local damage = oldHealth - newHealth
            S.hits += 1
            S.total += damage

            local event = {
                skill=S.skill, before=oldHealth, after=newHealth,
                damage=damage, hit=S.hits, total=S.total,
                elapsed=os.clock()-S.t0, killed=newHealth <= 0
            }
            table.insert(S.events, event)

            print(string.format(
                "[AwkScanner] %s | %.2f -> %.2f | damage %.2f | hit %d | %.3fs%s",
                event.skill, event.before, event.after, event.damage,
                event.hit, event.elapsed, event.killed and " | KILL" or ""
            ))
        end
    end)

    print("[AwkScanner] Started:", target:GetFullName(), "HP", h.Health)
    return true
end

function S.Stop()
    if S.connection then
        S.connection:Disconnect()
        S.connection = nil
    end
    S.active = false
end

function S.Summary()
    print("========== Awakened Limitless Scanner ==========")
    for i, e in ipairs(S.events) do
        print(i, e.skill, e.before, e.after, e.damage, e.hit, e.elapsed, e.killed and "KILL" or "")
    end
    print("================================================")
    return S.events
end

function S.Clear()
    table.clear(S.events)
    print("[AwkScanner] Log cleared")
end

return S
