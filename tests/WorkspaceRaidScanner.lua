-- WorkspaceRaidScanner.lua
-- Passive diagnostic: reads workspace only; does not invoke remotes or modify instances.

local TAG="[Workspace Raid Scanner]"
local function log(...) print(TAG, ...) end

local keywords={"queue","raid","jogo","megumi","gojo","sukuna","maki","toji","judge","island","boss","lobby"}

local function interesting(name)
    local n=string.lower(name)
    for _,k in ipairs(keywords) do
        if string.find(n,k,1,true) then return true end
    end
    return false
end

local function posOf(o)
    if o:IsA("BasePart") then return tostring(o.Position)
    elseif o:IsA("Model") then
        local p=o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart",true)
        return p and tostring(p.Position) or "no-part"
    end
    return "-"
end

log("START | passive workspace scan")
log("ROOT CHILDREN")
for _,o in ipairs(workspace:GetChildren()) do
    log("ROOT | "..o:GetFullName().." | "..o.ClassName)
end

log("MATCHED DESCENDANTS")
local count=0
for _,o in ipairs(workspace:GetDescendants()) do
    if interesting(o.Name) then
        count+=1
        log(string.format("MATCH | %s | %s | Pos=%s",o:GetFullName(),o.ClassName,posOf(o)))
    end
end

log("DONE | matches="..count)
