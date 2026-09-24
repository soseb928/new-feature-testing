-- NexusPlay Retry Handler Inspector v3
-- TESTING ONLY: observes the normal Retry button and surrounding UI state.
-- Does not click, invoke remotes, fire remotes, or synthesize input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local active = true
local conns = {}
local snapshots = {}
local lastRaidEnd = 0

local function log(msg)
    print("[Retry Handler Inspector v3] " .. os.date("%H:%M:%S") .. " | " .. tostring(msg))
end

local function safe(fn, fallback)
    local ok, v = pcall(fn)
    if ok then return v end
    return fallback
end

local function findButton()
    local hud = PlayerGui:FindFirstChild("RaidHUD")
    if not hud then return nil end
    local a = hud:FindFirstChild("Frame")
    local b = a and a:FindFirstChild("Frame")
    local button = b and b:FindFirstChild("TextButton")
    return button and button:IsA("TextButton") and button or nil
end

local function attrs(obj)
    local parts = {}
    for k, v in pairs(safe(function() return obj:GetAttributes() end, {})) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "<none>"
end

local function tags(obj)
    local ok, list = pcall(function() return CollectionService:GetTags(obj) end)
    if not ok or #list == 0 then return "<none>" end
    return table.concat(list, ", ")
end

local function describeTree(root, depth)
    depth = depth or 0
    if not root or depth > 3 then return end

    log(
        string.rep("  ", depth)
        .. root:GetFullName()
        .. " | Class=" .. root.ClassName
        .. " | Visible=" .. tostring(safe(function() return root.Visible end, "n/a"))
        .. " | Active=" .. tostring(safe(function() return root.Active end, "n/a"))
        .. " | Attrs=" .. attrs(root)
        .. " | Tags=" .. tags(root)
    )

    for _, child in ipairs(root:GetChildren()) do
        describeTree(child, depth + 1)
    end
end

local function snapshot(label)
    local button = findButton()
    log("SNAPSHOT | " .. label)

    if not button then
        log("SNAPSHOT | Retry button missing")
        return
    end

    local info = {
        visible = button.Visible,
        active = button.Active,
        interactable = safe(function() return button.Interactable end, nil),
        parent = button.Parent and button.Parent:GetFullName() or "nil",
        attrs = attrs(button),
        tags = tags(button),
    }

    log(
        "BUTTON STATE"
        .. " | Visible=" .. tostring(info.visible)
        .. " | Active=" .. tostring(info.active)
        .. " | Interactable=" .. tostring(info.interactable)
        .. " | Parent=" .. tostring(info.parent)
    )
    log("BUTTON STATE | Attrs=" .. info.attrs)
    log("BUTTON STATE | Tags=" .. info.tags)

    snapshots[label] = info
end

local function watchButton()
    local button = findButton()
    if not button then return false end

    if snapshots.__watched ~= button then
        snapshots.__watched = button
        log("RETRY BUTTON FOUND | " .. button:GetFullName())

        local props = {"Visible", "Active", "Interactable", "Selected", "Text", "ZIndex"}
        for _, prop in ipairs(props) do
            local ok, signal = pcall(function()
                return button:GetPropertyChangedSignal(prop)
            end)
            if ok and signal then
                table.insert(conns, signal:Connect(function()
                    log("BUTTON PROPERTY CHANGED | " .. prop .. "=" .. tostring(safe(function() return button[prop] end, "?")))
                end))
            end
        end

        -- These are observation-only listeners. They report when the USER manually
        -- activates the real button.
        table.insert(conns, button.Activated:Connect(function(input, clickCount)
            log("USER RETRY ACTIVATED | input=" .. tostring(input and input.UserInputType)
                .. " | clickCount=" .. tostring(clickCount))
            snapshot("immediately after user Retry activation")
        end))

        table.insert(conns, button.MouseButton1Click:Connect(function()
            log("USER MOUSEBUTTON1CLICK | normal Retry click observed")
        end))

        describeTree(button.Parent, 2)
        return true
    end

    return true
end

local function attachRaidRemote(obj)
    if not obj:IsA("RemoteEvent") or obj.Name ~= "RaidEnded_Signal" then return end

    table.insert(conns, obj.OnClientEvent:Connect(function(success)
        if not success then return end
        lastRaidEnd = os.clock()
        log("RAID END | success=true")
        snapshot("RaidEnded")
        task.spawn(function()
            for i = 1, 25 do
                if not active or os.clock() - lastRaidEnd > 8 then break end
                watchButton()
                task.wait(0.2)
            end
        end)
    end))
end

local NetworkComm = ReplicatedStorage:WaitForChild("NetworkComm")
local RaidsService = NetworkComm:WaitForChild("RaidsService")

for _, obj in ipairs(RaidsService:GetChildren()) do
    attachRaidRemote(obj)
end
table.insert(conns, RaidsService.ChildAdded:Connect(attachRaidRemote))

watchButton()

log("STARTED | Retry Handler Inspector v3")
log("IMPORTANT | Complete one raid, then manually press the normal Retry button once")
log("IMPORTANT | This inspector only observes the real UI activation and surrounding state")
