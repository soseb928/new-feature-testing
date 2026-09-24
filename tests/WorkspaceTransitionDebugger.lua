-- WorkspaceTransitionDebugger.lua
-- Passive only: observes workspace InstanceAdded/Removed.
local TAG="[Workspace Transition]"
local function log(...) print(TAG, ...) end
local watch={"raid","jogo","megumi","gojo","sukuna","maki","toji","judge","island","boss","queue","lobby","spawnpoint"}
local function relevant(n)
 n=string.lower(n)
 for _,k in ipairs(watch) do if string.find(n,k,1,true) then return true end end
 return false
end
local seen={}
local function emit(prefix,o)
 if not o or not o.Parent or not relevant(o.Name) then return end
 local p=o:GetFullName()
 if prefix=="ADD" and seen[p] then return end
 if prefix=="ADD" then seen[p]=true end
 log(prefix.." | "..p.." | "..o.ClassName)
end
log("START | passive transition debugger")
log("INITIAL SCAN")
for _,o in ipairs(workspace:GetDescendants()) do emit("EXIST",o) end
workspace.DescendantAdded:Connect(function(o) task.defer(function() emit("ADD",o) end) end)
workspace.DescendantRemoving:Connect(function(o)
 if relevant(o.Name) then log("REMOVE | "..o:GetFullName().." | "..o.ClassName) end
 seen[o:GetFullName()]=nil
end)
log("WATCHING | start raid normally now; no remotes are called")