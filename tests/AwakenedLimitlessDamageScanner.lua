-- Awakened Limitless Damage Diagnostic Scanner
-- TEST ONLY: observes Humanoid.HealthChanged.
-- Does not alter damage, cooldowns, remotes, or skill payloads.
-- Includes a small target-selection UI.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local S = {
    active=false, connection=nil, target=nil, humanoid=nil,
    skill="UNMARKED", before=nil, hits=0, total=0, events={},
    ui=nil, selected=nil
}

local MOVES = {
    "AwakenedLimitlessRed",
    "AwakenedLimitlessRedline",
    "AwakenedLimitlessAzureHalo",
    "AwakenedLimitlessAzureHalo2",
    "AwakenedLimitlessHollowPurple",
    "AwakenedLimitlessHollowNuke",
    "AwakenedLimitlessVoidInterval",
    "AwakenedLimitlessBoundlessPressure",
    "AwakenedLimitlessReversalBurst",
}

local function getHumanoid(model)
    if not model or not model:IsA("Model") then return nil end
    return model:FindFirstChildOfClass("Humanoid")
end

local function getRoot(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

local function getTargets()
    local out, seen = {}, {}
    for _, h in ipairs(workspace:GetDescendants()) do
        if h:IsA("Humanoid") and h.Health > 0 then
            local model = h.Parent
            if model and model:IsA("Model") and model ~= LP.Character and not seen[model] then
                seen[model] = true
                table.insert(out, model)
            end
        end
    end
    table.sort(out, function(a,b)
        return a:GetFullName():lower() < b:GetFullName():lower()
    end)
    return out
end

local function nearestHumanoid()
    local c = LP.Character
    local root = c and getRoot(c)
    if not root then return nil end

    local best, bestDist
    for _, model in ipairs(getTargets()) do
        local hrp = getRoot(model)
        local h = getHumanoid(model)
        if hrp and h then
            local d = (hrp.Position-root.Position).Magnitude
            if not bestDist or d < bestDist then
                best, bestDist = model, d
            end
        end
    end
    return best
end

local function log(msg)
    print("[AwkScanner] "..tostring(msg))
    if S.ui and S.ui.log then
        S.ui.log.Text = tostring(msg)
    end
end

function S.Mark(skillName)
    S.skill = tostring(skillName or "UNMARKED")
    S.hits, S.total = 0, 0
    S.before = S.humanoid and S.humanoid.Health
    S.t0 = os.clock()
    log(string.format("MARK %s | HP before: %s", S.skill, S.before and string.format("%.2f",S.before) or "N/A"))
end

function S.Start(targetModel)
    S.Stop()

    local target = targetModel or S.selected or nearestHumanoid()
    local h = getHumanoid(target)

    if not target or not h then
        warn("[AwkScanner] No valid target. Select a target in the UI first.")
        return false
    end

    S.target, S.humanoid, S.before = target, h, h.Health
    S.active, S.t0 = true, os.clock()
    S.hits, S.total = 0, 0

    S.connection = h.HealthChanged:Connect(function(newHealth)
        if not S.active then return end

        local oldHealth = S.before
        S.before = newHealth

        if oldHealth and newHealth < oldHealth then
            local damage = oldHealth-newHealth
            S.hits += 1
            S.total += damage

            local event = {
                skill=S.skill, before=oldHealth, after=newHealth,
                damage=damage, hit=S.hits, total=S.total,
                elapsed=os.clock()-S.t0, killed=newHealth <= 0,
                target=target:GetFullName()
            }

            table.insert(S.events,event)

            local msg = string.format(
                "%s | %.2f -> %.2f | DMG %.2f | HIT %d | %.3fs%s",
                event.skill,event.before,event.after,event.damage,
                event.hit,event.elapsed,event.killed and " | KILL" or ""
            )
            log(msg)
        end
    end)

    log(string.format("Monitoring %s | HP %.2f/%.2f",target:GetFullName(),h.Health,h.MaxHealth))
    return true
end

function S.Stop()
    if S.connection then
        S.connection:Disconnect()
        S.connection=nil
    end
    S.active=false
    if S.ui and S.ui.status then S.ui.status.Text="Status: STOPPED" end
end

function S.Summary()
    print("========== Awakened Limitless Scanner ==========")
    for i,e in ipairs(S.events) do
        print(i,e.skill,e.before,e.after,e.damage,e.hit,e.elapsed,e.killed and "KILL" or "")
    end
    print("================================================")
    return S.events
end

function S.Clear()
    table.clear(S.events)
    S.hits,S.total=0,0
    log("Log cleared")
end

function S.DestroyUI()
    if S.ui and S.ui.gui then S.ui.gui:Destroy() end
    S.ui=nil
end

function S.CreateUI()
    S.DestroyUI()

    local gui=Instance.new("ScreenGui")
    gui.Name="AwakenedLimitlessScanner"
    gui.ResetOnSpawn=false
    gui.Parent=LP:WaitForChild("PlayerGui")

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(430,520)
    frame.Position=UDim2.new(0.5,-215,0.5,-260)
    frame.BackgroundTransparency=0.08
    frame.Parent=gui

    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=frame

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-20,0,32)
    title.Position=UDim2.fromOffset(10,8)
    title.BackgroundTransparency=1
    title.Text="Awakened Limitless Damage Scanner"
    title.TextSize=18
    title.Font=Enum.Font.GothamBold
    title.Parent=frame

    local status=Instance.new("TextLabel")
    status.Size=UDim2.new(1,-20,0,22)
    status.Position=UDim2.fromOffset(10,42)
    status.BackgroundTransparency=1
    status.Text="Status: STOPPED"
    status.TextXAlignment=Enum.TextXAlignment.Left
    status.Font=Enum.Font.Gotham
    status.TextSize=13
    status.Parent=frame

    local targetLabel=Instance.new("TextLabel")
    targetLabel.Size=UDim2.new(1,-20,0,22)
    targetLabel.Position=UDim2.fromOffset(10,67)
    targetLabel.BackgroundTransparency=1
    targetLabel.Text="Target: none"
    targetLabel.TextXAlignment=Enum.TextXAlignment.Left
    targetLabel.TextSize=13
    targetLabel.Parent=frame

    local list=Instance.new("ScrollingFrame")
    list.Size=UDim2.new(1,-20,0,135)
    list.Position=UDim2.fromOffset(10,94)
    list.BackgroundTransparency=0.2
    list.ScrollBarThickness=6
    list.Parent=frame

    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,3)
    layout.Parent=list

    local function refreshTargets()
        for _,c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end

        local targets=getTargets()
        for _,model in ipairs(targets) do
            local h=getHumanoid(model)
            local b=Instance.new("TextButton")
            b.Size=UDim2.new(1,-6,0,28)
            b.Text=string.format("%s  [%.0f/%.0f]",model.Name,h.Health,h.MaxHealth)
            b.TextSize=12
            b.Font=Enum.Font.Gotham
            b.Parent=list

            b.MouseButton1Click:Connect(function()
                S.selected=model
                targetLabel.Text="Target: "..model:GetFullName()
                log("Selected "..model:GetFullName())
            end)
        end
        list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+5)
    end

    local refresh=Instance.new("TextButton")
    refresh.Size=UDim2.fromOffset(130,30)
    refresh.Position=UDim2.fromOffset(10,235)
    refresh.Text="Refresh Targets"
    refresh.Parent=frame
    refresh.MouseButton1Click:Connect(refreshTargets)

    local nearest=Instance.new("TextButton")
    nearest.Size=UDim2.fromOffset(130,30)
    nearest.Position=UDim2.fromOffset(150,235)
    nearest.Text="Nearest Target"
    nearest.Parent=frame
    nearest.MouseButton1Click:Connect(function()
        local t=nearestHumanoid()
        if t then
            S.selected=t
            targetLabel.Text="Target: "..t:GetFullName()
            log("Selected nearest "..t:GetFullName())
        else
            log("No target found")
        end
    end)

    local start=Instance.new("TextButton")
    start.Size=UDim2.fromOffset(130,30)
    start.Position=UDim2.fromOffset(290,235)
    start.Text="START"
    start.Parent=frame
    start.MouseButton1Click:Connect(function()
        if S.Start(S.selected) then status.Text="Status: MONITORING" end
    end)

    local stop=Instance.new("TextButton")
    stop.Size=UDim2.fromOffset(130,30)
    stop.Position=UDim2.fromOffset(10,270)
    stop.Text="STOP"
    stop.Parent=frame
    stop.MouseButton1Click:Connect(function()
        S.Stop()
        status.Text="Status: STOPPED"
    end)

    local clear=Instance.new("TextButton")
    clear.Size=UDim2.fromOffset(130,30)
    clear.Position=UDim2.fromOffset(150,270)
    clear.Text="Clear Log"
    clear.Parent=frame
    clear.MouseButton1Click:Connect(function() S.Clear() end)

    local summary=Instance.new("TextButton")
    summary.Size=UDim2.fromOffset(130,30)
    summary.Position=UDim2.fromOffset(290,270)
    summary.Text="Print Summary"
    summary.Parent=frame
    summary.MouseButton1Click:Connect(function() S.Summary() end)

    local skillLabel=Instance.new("TextLabel")
    skillLabel.Size=UDim2.new(1,-20,0,22)
    skillLabel.Position=UDim2.fromOffset(10,307)
    skillLabel.BackgroundTransparency=1
    skillLabel.Text="Mark skill before testing:"
    skillLabel.TextXAlignment=Enum.TextXAlignment.Left
    skillLabel.Parent=frame

    local skillList=Instance.new("ScrollingFrame")
    skillList.Size=UDim2.new(1,-20,0,125)
    skillList.Position=UDim2.fromOffset(10,332)
    skillList.BackgroundTransparency=0.2
    skillList.ScrollBarThickness=6
    skillList.Parent=frame

    local skillLayout=Instance.new("UIListLayout")
    skillLayout.Padding=UDim.new(0,3)
    skillLayout.Parent=skillList

    for _,move in ipairs(MOVES) do
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,-6,0,26)
        b.Text=move
        b.TextSize=11
        b.Font=Enum.Font.Gotham
        b.Parent=skillList
        b.MouseButton1Click:Connect(function() S.Mark(move) end)
    end
    skillList.CanvasSize=UDim2.fromOffset(0,skillLayout.AbsoluteContentSize.Y+5)

    local logLabel=Instance.new("TextLabel")
    logLabel.Size=UDim2.new(1,-20,0,35)
    logLabel.Position=UDim2.fromOffset(10,462)
    logLabel.BackgroundTransparency=1
    logLabel.Text="Ready. Select a target, START, then mark/test a skill."
    logLabel.TextWrapped=true
    logLabel.TextXAlignment=Enum.TextXAlignment.Left
    logLabel.TextSize=11
    logLabel.Parent=frame

    S.ui={gui=gui,status=status,log=logLabel}
    refreshTargets()
    return gui
end

S.CreateUI()
return S
