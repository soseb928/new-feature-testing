-- Awakened Limitless Damage Diagnostic Scanner
-- TEST ONLY: observes replicated health state. Does not alter damage/cooldowns/remotes.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local S={active=false,connection=nil,target=nil,healthObject=nil,healthKind=nil,before=nil,skill="UNMARKED",hits=0,total=0,events={},ui=nil,selected=nil}

local MOVES={"AwakenedLimitlessRed","AwakenedLimitlessRedline","AwakenedLimitlessAzureHalo","AwakenedLimitlessAzureHalo2","AwakenedLimitlessHollowPurple","AwakenedLimitlessHollowNuke","AwakenedLimitlessVoidInterval","AwakenedLimitlessBoundlessPressure","AwakenedLimitlessReversalBurst"}

local function getHumanoid(m)
    return m and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") or nil
end
local function getRoot(m)
    if not m then return nil end
    local direct=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
    if direct and direct:IsA("BasePart") then return direct end
    return m:FindFirstChildWhichIsA("BasePart",true)
end

local function resolveCandidate(inst)
    if not inst then return nil end
    if inst:IsA("Model") then return inst end
    local model=inst:FindFirstAncestorOfClass("Model")
    return model or inst
end

local function candidateName(inst)
    local parts={}
    local cur=inst
    for _=1,4 do
        if not cur then break end
        table.insert(parts,cur.Name:lower())
        cur=cur.Parent
    end
    return table.concat(parts,"/")
end

local function getHealthSource(m)
    local h=getHumanoid(m)
    if h then return h,"Humanoid" end
    for _,name in ipairs({"Health","HP","CurrentHealth"}) do
        local v=m and m:FindFirstChild(name,true)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return v,"Value" end
    end
    for _,name in ipairs({"Health","HP","CurrentHealth"}) do
        local ok,val=pcall(function() return m:GetAttribute(name) end)
        if ok and type(val)=="number" then return m,"Attribute:"..name end
    end
    return nil,nil
end
local function readHealth(obj,kind)
    if not obj then return nil end
    if kind=="Humanoid" or kind=="Value" then return obj.Health or obj.Value end
    local attr=kind and kind:match("^Attribute:(.+)$")
    if attr then return obj:GetAttribute(attr) end
end
local function connectHealth(obj,kind,fn)
    if kind=="Humanoid" then return obj.HealthChanged:Connect(fn) end
    if kind=="Value" then return obj.Changed:Connect(function(v) if type(v)=="number" then fn(v) end end) end
    local attr=kind and kind:match("^Attribute:(.+)$")
    if attr then return obj:GetAttributeChangedSignal(attr):Connect(function() fn(obj:GetAttribute(attr)) end) end
end

local function getTargets()
    local out,seen={},{}
    local function add(inst)
        local model=resolveCandidate(inst)
        if not model or model==LP.Character or seen[model] then return end
        local root=getRoot(model)
        if not root then return end
        local source,kind=getHealthSource(model)
        local hp=readHealth(source,kind)
        local name=candidateName(inst)
        local named=name:find("punch") or name:find("bag") or name:find("dummy") or name:find("training") or name:find("target")
        if hp and hp>0 or named then
            seen[model]=true
            table.insert(out,model)
        end
    end

    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") then
            add(d)
        elseif d:IsA("BasePart") then
            local n=candidateName(d)
            if n:find("punch") or n:find("bag") or n:find("dummy") or n:find("training") or n:find("target") then
                add(d)
            end
        end
    end

    table.sort(out,function(a,b)
        local an=a:GetFullName():lower(); local bn=b:GetFullName():lower()
        local function score(n)
            if n:find("punch") or n:find("bag") then return 0 end
            if n:find("dummy") or n:find("training") or n:find("target") then return 1 end
            return 2
        end
        local sa,sb=score(an),score(bn)
        if sa~=sb then return sa<sb end
        return an<bn
    end)
    return out
end

local function log(msg)
    print("[AwkScanner] "..tostring(msg))
    if S.ui and S.ui.log then S.ui.log.Text=tostring(msg) end
end

function S.Mark(name)
    S.skill=tostring(name or "UNMARKED"); S.hits=0; S.total=0
    S.before=readHealth(S.healthObject,S.healthKind); S.t0=os.clock()
    log(string.format("MARK %s | HP before: %s",S.skill,S.before and string.format("%.2f",S.before) or "N/A"))
end

function S.Start(target)
    S.Stop()
    target=target or S.selected
    if not target then warn("[AwkScanner] Select a target first."); return false end
    local source,kind=getHealthSource(target)
    local hp=readHealth(source,kind)
    if not source or not hp then
        warn("[AwkScanner] Target has no supported replicated health source: "..target:GetFullName())
        return false
    end
    S.target,S.healthObject,S.healthKind,S.before=target,source,kind,hp
    S.active=true; S.t0=os.clock(); S.hits=0; S.total=0
    S.connection=connectHealth(source,kind,function(newHealth)
        if not S.active then return end
        local old=S.before; S.before=newHealth
        if old and type(newHealth)=="number" and newHealth<old then
            local dmg=old-newHealth; S.hits+=1; S.total+=dmg
            local e={skill=S.skill,before=old,after=newHealth,damage=dmg,hit=S.hits,total=S.total,elapsed=os.clock()-S.t0,killed=newHealth<=0,target=target:GetFullName()}
            table.insert(S.events,e)
            log(string.format("%s | %.2f -> %.2f | DMG %.2f | HIT %d | %.3fs%s",e.skill,e.before,e.after,e.damage,e.hit,e.elapsed,e.killed and " | KILL" or ""))
        end
    end)
    log(string.format("Monitoring %s | HP %.2f | source %s",target:GetFullName(),hp,kind))
    return true
end

function S.Stop()
    if S.connection then S.connection:Disconnect(); S.connection=nil end
    S.active=false
    if S.ui and S.ui.status then S.ui.status.Text="Status: STOPPED" end
end
function S.Summary()
    print("========== Awakened Limitless Scanner ==========")
    for i,e in ipairs(S.events) do print(i,e.skill,e.before,e.after,e.damage,e.hit,e.elapsed,e.killed and "KILL" or "") end
    print("================================================")
    return S.events
end
function S.Clear() table.clear(S.events); S.hits=0; S.total=0; log("Log cleared") end
function S.DestroyUI() if S.ui and S.ui.gui then S.ui.gui:Destroy() end; S.ui=nil end

function S.CreateUI()
    S.DestroyUI()
    local gui=Instance.new("ScreenGui"); gui.Name="AwakenedLimitlessScanner"; gui.ResetOnSpawn=false; gui.Parent=LP:WaitForChild("PlayerGui")
    local frame=Instance.new("Frame"); frame.Size=UDim2.fromOffset(460,560); frame.Position=UDim2.new(.5,-230,.5,-280); frame.BackgroundTransparency=.08; frame.Parent=gui
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=frame
    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-20,0,30); title.Position=UDim2.fromOffset(10,7); title.BackgroundTransparency=1; title.Text="Awakened Limitless Damage Scanner"; title.TextSize=18; title.Font=Enum.Font.GothamBold; title.Parent=frame
    local status=Instance.new("TextLabel"); status.Size=UDim2.new(1,-20,0,20); status.Position=UDim2.fromOffset(10,39); status.BackgroundTransparency=1; status.Text="Status: STOPPED"; status.TextXAlignment=Enum.TextXAlignment.Left; status.Parent=frame
    local targetLabel=Instance.new("TextLabel"); targetLabel.Size=UDim2.new(1,-20,0,35); targetLabel.Position=UDim2.fromOffset(10,62); targetLabel.BackgroundTransparency=1; targetLabel.Text="Target: none"; targetLabel.TextWrapped=true; targetLabel.TextXAlignment=Enum.TextXAlignment.Left; targetLabel.Parent=frame

    local list=Instance.new("ScrollingFrame"); list.Size=UDim2.new(1,-20,0,170); list.Position=UDim2.fromOffset(10,100); list.BackgroundTransparency=.2; list.ScrollBarThickness=6; list.Parent=frame
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,3); layout.Parent=list

    local function refresh()
        for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local targets=getTargets()
        if #targets==0 then
            local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-6,0,28); l.Text="No candidate targets found"; l.Parent=list
        end
        for _,m in ipairs(targets) do
            local source,kind=getHealthSource(m); local hp=readHealth(source,kind)
            local healthText=kind and string.format("%s | HP %.0f",kind,hp or 0) or "HP source unknown"
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-6,0,28); b.Text=string.format("%s  [%s]",m.Name,healthText); b.TextSize=11; b.Font=Enum.Font.Gotham; b.Parent=list
            b.MouseButton1Click:Connect(function()
                S.selected=m; targetLabel.Text="Target: "..m:GetFullName(); log("Selected "..m:GetFullName())
            end)
        end
        list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+5)
    end

    local refreshButton=Instance.new("TextButton"); refreshButton.Size=UDim2.fromOffset(140,30); refreshButton.Position=UDim2.fromOffset(10,275); refreshButton.Text="Refresh Targets"; refreshButton.Parent=frame; refreshButton.MouseButton1Click:Connect(refresh)
    local nearest=Instance.new("TextButton"); nearest.Size=UDim2.fromOffset(140,30); nearest.Position=UDim2.fromOffset(160,275); nearest.Text="Nearest Target"; nearest.Parent=frame; nearest.MouseButton1Click:Connect(function()
        local c=LP.Character; local r=c and getRoot(c); local best,dist,bestPriority
        if r then
            for _,m in ipairs(getTargets()) do
                local p=getRoot(m)
                if p then
                    local d=(p.Position-r.Position).Magnitude
                    local n=m:GetFullName():lower()
                    local priority=(n:find("punch") or n:find("bag") or n:find("dummy") or n:find("training") or n:find("target")) and 0 or 1
                    if not best or priority < (bestPriority or 2) or (priority==(bestPriority or 2) and d<dist) then
                        best,bestPriority,dist=m,priority,d
                    end
                end
            end
        end
        if best then S.selected=best; targetLabel.Text="Target: "..best:GetFullName(); log("Selected nearest "..best:GetFullName()) else log("No target found") end
    end)
    local start=Instance.new("TextButton"); start.Size=UDim2.fromOffset(140,30); start.Position=UDim2.fromOffset(310,275); start.Text="START"; start.Parent=frame; start.MouseButton1Click:Connect(function() if S.Start(S.selected) then status.Text="Status: MONITORING" end end)
    local stop=Instance.new("TextButton"); stop.Size=UDim2.fromOffset(140,30); stop.Position=UDim2.fromOffset(10,310); stop.Text="STOP"; stop.Parent=frame; stop.MouseButton1Click:Connect(function() S.Stop(); status.Text="Status: STOPPED" end)
    local clear=Instance.new("TextButton"); clear.Size=UDim2.fromOffset(140,30); clear.Position=UDim2.fromOffset(160,310); clear.Text="Clear Log"; clear.Parent=frame; clear.MouseButton1Click:Connect(function() S.Clear() end)
    local summary=Instance.new("TextButton"); summary.Size=UDim2.fromOffset(140,30); summary.Position=UDim2.fromOffset(310,310); summary.Text="Print Summary"; summary.Parent=frame; summary.MouseButton1Click:Connect(function() S.Summary() end)

    local skillLabel=Instance.new("TextLabel"); skillLabel.Size=UDim2.new(1,-20,0,20); skillLabel.Position=UDim2.fromOffset(10,348); skillLabel.BackgroundTransparency=1; skillLabel.Text="Mark skill before testing:"; skillLabel.TextXAlignment=Enum.TextXAlignment.Left; skillLabel.Parent=frame
    local skillList=Instance.new("ScrollingFrame"); skillList.Size=UDim2.new(1,-20,0,125); skillList.Position=UDim2.fromOffset(10,372); skillList.BackgroundTransparency=.2; skillList.ScrollBarThickness=6; skillList.Parent=frame
    local sl=Instance.new("UIListLayout"); sl.Padding=UDim.new(0,3); sl.Parent=skillList
    for _,move in ipairs(MOVES) do
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-6,0,26); b.Text=move; b.TextSize=11; b.Font=Enum.Font.Gotham; b.Parent=skillList; b.MouseButton1Click:Connect(function() S.Mark(move) end)
    end
    skillList.CanvasSize=UDim2.fromOffset(0,sl.AbsoluteContentSize.Y+5)
    local logLabel=Instance.new("TextLabel"); logLabel.Size=UDim2.new(1,-20,0,40); logLabel.Position=UDim2.fromOffset(10,500); logLabel.BackgroundTransparency=1; logLabel.Text="Refresh targets. Nearest prioritizes Punch/Bag/Dummy/Training/Target names."; logLabel.TextWrapped=true; logLabel.TextXAlignment=Enum.TextXAlignment.Left; logLabel.TextSize=11; logLabel.Parent=frame
    S.ui={gui=gui,status=status,log=logLabel}; refresh(); return gui
end

S.CreateUI()
return S
