--[[
    NexusPlay Hub
    Version: 1.0.2
    Rebranded/refactored build.

    Notes:
    - This file is based on the authorized source supplied by the user.
    - Remote execution, HTTP, filesystem, teleport, and executor-specific
      APIs are intentionally preserved for compatibility with the original
      project.
--]]
local NEXUSPLAY_METADATA = {
    Name = "NexusPlay Hub",
    Version = "1.0.2",
    Build = "NEXUSPLAY-HUB-V1.0.2",
}


local NEXUS_LV = {}
NEXUSG = getgenv()
NEXUSG.NexusPlayHubLoaded = false
if NEXUSG.NexusPlayHub and NEXUSG.NexusPlayHub.stop then pcall(NEXUSG.NexusPlayHub.stop) end
NEXUSG.NexusPlayHubSession = (NEXUSG.NexusPlayHubSession or 0) + 1
local SESSION = NEXUSG.NexusPlayHubSession

NEXUS_BUILD = "NEXUSPLAY-HUB-V1.0.2"
NEXUSG.NEXUS_BUILD = NEXUS_BUILD
print("[NexusPlay Hub] build " .. NEXUS_BUILD .. " loaded (bring engine active)")

NEXUS_IMG_FOLDER = "NexusPlayHub_Images"
NEXUS_IMG_MEMO   = NEXUS_IMG_MEMO or {}

function NexusImgHash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return string.format("%x", h) .. "_" .. tostring(#s)
end

function NexusImgExt(url)
    local low = tostring(url):lower()
    low = low:gsub("%?.*$", "")
    if low:match("%.png$")  then return ".png"  end
    if low:match("%.jpe?g$") then return ".jpg" end
    if low:match("%.webp$") then return ".webp" end
    if low:match("%.bmp$")  then return ".bmp"  end
    if low:match("%.tga$")  then return ".tga"  end
    return ".png"
end

function NexusImgDownload(url)
    local body
    local req = (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or (getgenv and getgenv().request)
        or request
    if type(req) == "function" then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
            local b = res.Body or res.body
            if type(b) == "string" and #b > 0 then body = b end
        end
    end
    if not body then
        local ok2, res2 = pcall(function() return game:HttpGetAsync(url) end)
        if ok2 and type(res2) == "string" and #res2 > 0 then body = res2 end
    end
    if not body then
        local ok3, res3 = pcall(function() return game:HttpGet(url, true) end)
        if ok3 and type(res3) == "string" and #res3 > 0 then body = res3 end
    end
    return body
end

function NexusResolveImage(v)
    if v == nil or v == false then return v end
    if type(v) == "number" then return v end
    local s = tostring(v)
    if s == "" then return s end

    -- not a web link (roblox image id, rbxassetid://, rbxthumb://, material
    -- icon name, already cached rbxasset://...) -> return it exactly as it was
    if not s:lower():match("^https?://") then return v end

    if NEXUS_IMG_MEMO[s] ~= nil then return NEXUS_IMG_MEMO[s] end

    -- a roblox asset link with an id inside -> just use that id
    if s:lower():match("roblox") then
        local id = s:match("[?&]id=(%d+)") or s:match("/asset/?%?id=(%d+)")
        if id then
            NEXUS_IMG_MEMO[s] = id
            return id
        end
    end

    local getAsset = getcustomasset
        or getsynasset
        or (syn and syn.get_custom_asset)
        or (fluxus and fluxus.get_custom_asset)
    if type(getAsset) ~= "function" or type(writefile) ~= "function" then
        NEXUS_IMG_MEMO[s] = ""
        return ""
    end

    pcall(function()
        if makefolder and (not isfolder or not isfolder(NEXUS_IMG_FOLDER)) then
            makefolder(NEXUS_IMG_FOLDER)
        end
    end)

    local path = NEXUS_IMG_FOLDER .. "/" .. NexusImgHash(s) .. NexusImgExt(s)
    local have = false
    pcall(function() if isfile and isfile(path) then have = true end end)

    if not have then
        local body = NexusImgDownload(s)
        if type(body) ~= "string" or #body < 8 then
            NEXUS_IMG_MEMO[s] = ""
            return ""
        end
        local okw = pcall(function() writefile(path, body) end)
        if not okw then
            NEXUS_IMG_MEMO[s] = ""
            return ""
        end
    end

    local asset
    pcall(function() asset = getAsset(path) end)
    if type(asset) ~= "string" or asset == "" then
        NEXUS_IMG_MEMO[s] = ""
        return ""
    end

    NEXUS_IMG_MEMO[s] = asset
    return asset
end

NEXUSG.NexusResolveImage = NexusResolveImage

 NEXUS_LV.HttpService = game:GetService("HttpService")
 NEXUS_LV.SETTINGS_DIR   = "NexusPlayHub"
 NEXUS_LV.SETTINGS_FILE  = "NexusPlayHub/NexusPlayHub_Settings.dat"
 NEXUS_LV.SETTINGS_OLD   = "NexusPlayHub_Settings.json"
 NEXUS_LV.CFG_KEY        = "NexusPlayHub|v1|cfg|key"
local Settings = {}

-- Settings are scrambled on disk so the .dat shows only noise in a text
-- editor. XOR is symmetric, so this one routine both seals and opens it.
 NEXUS_LV.cfgXor = function(str)
    local key = NEXUS_LV.CFG_KEY
    local kl, out = #key, {}
    for i = 1, #str do
        local k = string.byte(key, ((i - 1) % kl) + 1)
        out[i] = string.char(bit32.bxor(string.byte(str, i), bit32.bxor(k, (i * 7) % 251)))
    end
    return table.concat(out)
end
 NEXUS_LV.cfgSeal = function(plain)
    local x, hex = NEXUS_LV.cfgXor(plain), {}
    for i = 1, #x do hex[i] = string.format("%02X", string.byte(x, i)) end
    return "NXO1" .. table.concat(hex)
end
 NEXUS_LV.cfgOpen = function(blob)
    if type(blob) ~= "string" then return nil end
    if string.sub(blob, 1, 4) ~= "NXO1" then return blob end
    local bytes = {}
    for pair in string.gmatch(string.sub(blob, 5), "%x%x") do
        bytes[#bytes + 1] = string.char(tonumber(pair, 16))
    end
    return NEXUS_LV.cfgXor(table.concat(bytes))
end
 NEXUS_LV.cfgFolder = function()
    pcall(function()
        if makefolder and isfolder and not isfolder(NEXUS_LV.SETTINGS_DIR) then
            makefolder(NEXUS_LV.SETTINGS_DIR)
        end
    end)
end
NEXUS_LV.loadSettings = function()
    pcall(function()
        NEXUS_LV.cfgFolder()
        if isfile and isfile(NEXUS_LV.SETTINGS_FILE) then
            local plain = NEXUS_LV.cfgOpen(readfile(NEXUS_LV.SETTINGS_FILE))
            if plain then Settings = NEXUS_LV.HttpService:JSONDecode(plain) or {} end
        elseif isfile and isfile(NEXUS_LV.SETTINGS_OLD) then
            Settings = NEXUS_LV.HttpService:JSONDecode(readfile(NEXUS_LV.SETTINGS_OLD)) or {}
        end
    end)
end
local function saveSettings()
    pcall(function()
        if not writefile then return end
        NEXUS_LV.cfgFolder()
        writefile(NEXUS_LV.SETTINGS_FILE, NEXUS_LV.cfgSeal(NEXUS_LV.HttpService:JSONEncode(Settings)))
    end)
end
NEXUS_LV.loadSettings()

local function S(key, default)
    if Settings[key] == nil then return default end
    return Settings[key]
end

local function PT(section, key, name, cb)
    local v = S(key, false)
    pcall(function() cb(v) end)
    return section:CreateToggle({ Name = name, CurrentValue = v, Callback = function(on)
        cb(on)
        Settings[key] = on
        saveSettings()
    end }, "NEXUS_" .. tostring(key))
end
local CONNS = {}
NEXUSG.NexusPlayHub = { stop = function()
    for _, cc in ipairs(CONNS) do pcall(function() cc:Disconnect() end) end
    CONNS = {}

    pcall(function() ClientDescCache = { t = -1, folder = nil, list = {} } end)

    pcall(function() WsCache = { t = -1, list = nil } end)
    pcall(function() TgtCache = {} end)
    pcall(function() NexusLabelCache = { folder = nil, set = nil, arr = nil, t = -1, dirty = true } end)
    pcall(function() NexusPartCache = {} end)
    pcall(function() NexusPDC = nil end)
    pcall(function() NexusNpcMemo = setmetatable({ key = "", t = 0, m = nil }, { __mode = "v" }) end)
    pcall(function() ShikiNameMemo = setmetatable({}, { __mode = "k" }) end)
    pcall(function() ShikiBossModel = nil end)
end }

 NEXUS_LV.Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
 NEXUS_LV.TweenService = game:GetService("TweenService")
local RepStorage   = game:GetService("ReplicatedStorage")
 NEXUS_LV.UserInput    = game:GetService("UserInputService")
local NexusLighting = game:GetService("Lighting")
local LocalPlayer  = NEXUS_LV.Players.LocalPlayer

-- ===== [NEXUS-OPT] job pool + invoke gate =====
NEXUS_OPT = NEXUS_OPT or {}
NEXUS_OPT.MAX_WORKERS  = NEXUS_OPT.MAX_WORKERS  or 8
NEXUS_OPT.MAX_INFLIGHT = NEXUS_OPT.MAX_INFLIGHT or 8
NEXUS_OPT.CD_SCALE     = NEXUS_OPT.CD_SCALE     or 0.5
NEXUS_OPT.QMAX         = NEXUS_OPT.QMAX         or 512
NEXUS_OPT.stats = { queued = 0, ran = 0, dropQ = 0, dropInv = 0, inflight = 0, peakQ = 0, invOk = 0 }

NEXUSG.NEXUS_OPT_GEN = (NEXUSG.NEXUS_OPT_GEN or 0) + 1
local NEXUS_OPT_GEN = NEXUSG.NEXUS_OPT_GEN

local NEXUS_Q, NEXUS_QH, NEXUS_QT = {}, 1, 0

function NexusQ(fn, ...)
    if type(fn) ~= "function" then return end
    local st = NEXUS_OPT.stats
    local size = NEXUS_QT - NEXUS_QH + 1
    if size >= NEXUS_OPT.QMAX then
        st.dropQ = st.dropQ + 1
        return
    end
    NEXUS_QT = NEXUS_QT + 1
    NEXUS_Q[NEXUS_QT] = table.pack(fn, ...)
    st.queued = st.queued + 1
    if (size + 1) > st.peakQ then st.peakQ = size + 1 end
end

for _ = 1, NEXUS_OPT.MAX_WORKERS do
    task.spawn(function()
        while NEXUSG.NEXUS_OPT_GEN == NEXUS_OPT_GEN do
            if NEXUS_QH <= NEXUS_QT then
                local job = NEXUS_Q[NEXUS_QH]
                NEXUS_Q[NEXUS_QH] = nil
                NEXUS_QH = NEXUS_QH + 1
                if job then
                    NEXUS_OPT.stats.ran = NEXUS_OPT.stats.ran + 1
                    pcall(table.unpack(job, 1, job.n))
                end
            else
                -- [NEXUS-FIX] was 0.01; 8 idle workers burned ~800 wakeups/sec
                task.wait(0.05)
            end
        end
    end)
end

function NexusGatedInvoke(rem, ...)
    if not rem then return nil end
    local st = NEXUS_OPT.stats
    if st.inflight >= NEXUS_OPT.MAX_INFLIGHT then
        st.dropInv = st.dropInv + 1
        return nil
    end
    st.inflight = st.inflight + 1
    -- namecall form on purpose: the hub's own __namecall hook must still see this
    -- call (it tracks MyModel and enforces MAX_DMG_WAITING / MAX_START_WAITING)
    local args = table.pack(...)
    local ok, res = pcall(function()
        return rem:InvokeServer(table.unpack(args, 1, args.n))
    end)
    st.inflight = st.inflight - 1
    if ok then
        st.invOk = st.invOk + 1
        return res
    end
    return nil
end
-- ===== [/NEXUS-OPT] =====

function nexusRig(m)
    if not m then return nil, nil end
    return m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
end

-- [NEXUS-OPT] Paragraph panels kept a fixed height, so long status text ran
-- underneath the next element (the "Refresh Status" button). Give every panel
-- body an automatic height so the layout reflows instead of overlapping.
NexusFitSeen = NexusFitSeen or setmetatable({}, { __mode = "k" })
NexusFitT = 0
function NexusFitPanels()
    local plr = LocalPlayer
    local pg  = plr and plr:FindFirstChild("PlayerGui")
    local hub = pg and pg:FindFirstChild("NexusPlayHub")
    if not hub then return end
    for _, d in ipairs(hub:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "Body" and not NexusFitSeen[d] then
            NexusFitSeen[d] = true
            pcall(function()
                d.TextWrapped    = false
                d.TextXAlignment = Enum.TextXAlignment.Left
                d.AutomaticSize  = Enum.AutomaticSize.Y
                d.Size           = UDim2.new(1, 0, 0, 0)
                local p = d.Parent
                if p then
                    p.AutomaticSize = Enum.AutomaticSize.Y
                    p.Size = UDim2.new(p.Size.X.Scale, p.Size.X.Offset, 0, 0)
                end
            end)
        end
    end
end

function nexusPanelSet(panel, txt)
    pcall(function() panel:SetText(txt) end)
    pcall(function() panel:Set(txt) end)
    local now = os.clock()
    if (now - (NexusFitT or 0)) >= 1 then
        NexusFitT = now
        pcall(NexusFitPanels)
    end
end

function NexusReqAccum(tot, order, list)
    for _, r in ipairs(list) do
        if tot[r.id] == nil then tot[r.id] = 0 order[#order + 1] = r.id end
        tot[r.id] = tot[r.id] + r.need
    end
end

function NexusReqTotals(tot, order, have)
    local needTotal, ownTotal = 0, 0
    for _, id in ipairs(order) do
        local nd, hv = tot[id], (have[id] or 0)
        needTotal = needTotal + nd
        ownTotal  = ownTotal + math.min(hv, nd)
    end
    return needTotal, ownTotal, (needTotal > 0) and math.floor((ownTotal / needTotal) * 100) or 100
end

 NEXUS_LV.ATTACK_RANGE = 150
 NEXUS_LV.AURA_RANGE   = 500
 NEXUS_LV.BRING_RANGE  = 500
local BRING_OFFSET = 4
BRING_GAP          = 0.05

 NEXUS_LV.AURA_MODE    = "Back"
local OX, OY, OZ   = 0, 0, 0
 NEXUS_LV.QUEST_TARGET = ""
 NEXUS_LV.TICK         = 0
 NEXUS_LV.HIT_PLAYERS  = false
 NEXUS_LV.SPEED        = 150
 NEXUS_LV.MIN_SPEED    = 0
 NEXUS_LV.MAX_SPEED    = 400
 NEXUS_LV.TOGGLE_KEY   = Enum.KeyCode.V

LOOP_GAP      = 0.05
SCAN_CACHE    = 1.5
TGT_CACHE_SEC = 0.05
BOSS_GAP        = 0.03
NEXUS_IDLE       = 0.6

function NexusSetSmooth(on)
    if on then

        LOOP_GAP, SCAN_CACHE, TGT_CACHE_SEC = 0.08, 1.0, 0.10
        BOSS_GAP, CLIENT_SCAN_SEC           = 0.08, 0.05
    else
        LOOP_GAP, SCAN_CACHE, TGT_CACHE_SEC = 0.05, 1.5, 0.05
        BOSS_GAP, CLIENT_SCAN_SEC           = 0.03, 0.05
    end
end
CLIENT_SCAN_SEC = 0.05

WsCache = WsCache or { t = -1, list = nil }
function wsDesc()
    local now = os.clock()
    if WsCache.list and (now - WsCache.t) < SCAN_CACHE then return WsCache.list end
    local ok, l = pcall(function() return workspace:GetDescendants() end)
    if not ok or type(l) ~= "table" then return WsCache.list or {} end
    WsCache.list, WsCache.t = l, now
    return l
end

ClientDescCache = ClientDescCache or { t = -1, folder = nil, list = {} }
function clientDesc(folder)
    if not folder then return {} end
    local now = os.clock()
    if ClientDescCache.folder == folder and (now - ClientDescCache.t) < CLIENT_SCAN_SEC then
        return ClientDescCache.list
    end
    local ok, l = pcall(function() return folder:GetDescendants() end)
    if not ok or type(l) ~= "table" then return ClientDescCache.list or {} end
    ClientDescCache.folder, ClientDescCache.list, ClientDescCache.t = folder, l, now
    return l
end

NEXUS_LABEL_RESYNC = 2.0
NexusLabelCache = NexusLabelCache or { folder = nil, set = nil, arr = nil, t = -1, dirty = true }

function clientLabels(folder)
    if not folder then return {} end
    local C = NexusLabelCache
    local now = os.clock()

    if C.folder ~= folder then

        if C.conns then
            for _, c in ipairs(C.conns) do pcall(function() c:Disconnect() end) end
        end
        C.folder, C.set, C.arr, C.dirty, C.conns = folder, nil, nil, true, {}
        local added = folder.DescendantAdded:Connect(function(d)
            if d.ClassName == "TextLabel" then
                local S = NexusLabelCache
                if S.folder == folder and S.set and not S.set[d] then
                    S.set[d] = true
                    S.arr[#S.arr + 1] = d
                end
            end
        end)
        local removing = folder.DescendantRemoving:Connect(function(d)
            local S = NexusLabelCache
            if S.folder == folder and S.set and S.set[d] then
                S.set[d] = nil
                -- [NEXUS-FIX] Was rebuilding the entire array on every single
                -- label removal. The getter rebuilds on dirty, so defer to it.
                S.dirty = true
            end
        end)
        C.conns = { added, removing }
        CONNS[#CONNS + 1] = added
        CONNS[#CONNS + 1] = removing
    end

    if (not C.arr) or C.dirty or (now - C.t) >= NEXUS_LABEL_RESYNC then
        local set, arr = {}, {}

        for _, d in ipairs(clientDesc(folder)) do
            if d.ClassName == "TextLabel" then
                set[d] = true
                arr[#arr + 1] = d
            end
        end
        C.set, C.arr, C.t, C.dirty = set, arr, now, false
    end
    return C.arr
end

NEXUS_PRUNE = NEXUS_PRUNE or {}
function NexusPruneRegister(getter) NEXUS_PRUNE[#NEXUS_PRUNE + 1] = getter end
NEXUS_PruneRuns, NEXUS_PruneDropped = 0, 0
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        task.wait(5)
        local now = os.clock()
        for _, getter in ipairs(NEXUS_PRUNE) do
            local ok, t = pcall(getter)
            if ok and type(t) == "table" then
                for k in pairs(t) do
                    if typeof(k) == "Instance" and not k.Parent then
                        t[k] = nil
                        NEXUS_PruneDropped = NEXUS_PruneDropped + 1
                    end
                end
            end
        end
        if type(NexusPartCache) == "table" then
            for nm, obj in pairs(NexusPartCache) do
                if not (typeof(obj) == "Instance" and obj.Parent) then NexusPartCache[nm] = nil end
            end
        end

        if WsCache.list and (now - WsCache.t) > 5 then WsCache.list = nil end
        if ClientDescCache.list and #ClientDescCache.list > 0 and (now - ClientDescCache.t) > 5 then
            ClientDescCache.list, ClientDescCache.folder, ClientDescCache.t = {}, nil, -1
        end
        NEXUS_PruneRuns = NEXUS_PruneRuns + 1
    end
end)

local Net             = RepStorage:WaitForChild("NetworkComm")

function NexusRemote(service, ...)
    local svc = Net:FindFirstChild(service) or Net:WaitForChild(service, 10)
    if not svc then return nil end
    local names = { ... }
    for _, n in ipairs(names) do
        local r = svc:FindFirstChild(n)
        if r then return r end
    end

    for _, n in ipairs(names) do
        local ok, r = pcall(function() return svc:WaitForChild(n, 5) end)
        if ok and r then return r end
    end
    return nil
end

local StartSkill      = NexusRemote("SkillService",  "StartSkilll_Method", "StartSkill_Method")
local DamageCharacter = NexusRemote("CombatService", "DamageCharacter_Method")
 NEXUS_LV.AcceptQuest     = NexusRemote("QuestService",  "AcceptQuest_Method")
NEXUSG.NEXUS_REMOTES_OK   = (StartSkill ~= nil) and (DamageCharacter ~= nil)
NEXUSG.NEXUS_SKILL_REMOTE = StartSkill and StartSkill.Name or "MISSING"
if not StartSkill then warn("[NEXUS] SkillService start-skill remote not found -- attacks disabled") end
if not DamageCharacter then warn("[NEXUS] CombatService.DamageCharacter_Method not found -- damage disabled") end

NexusAccT = NexusAccT or {}
function NexusSafeAccept(id)
    if not id or id == "" then return false end
    local saved
    local m = NexusQuestMods and NexusQuestMods()
    if m and m.ok then pcall(function() saved = m.QC:GetSavedQuest(id) end) end

    if saved and not saved.IsFinished and (tonumber(saved.Points) or 0) > 0 then return false end
    local now = os.clock()
    if (now - (NexusAccT[id] or -1)) < 0.75 then return false end
    NexusAccT[id] = now
    local ok = false
    pcall(function() NEXUS_LV.AcceptQuest:InvokeServer(id) ok = true end)
    return ok
end

 NEXUS_LV.UseItem         = Net.InventoryService.UseItem_Method
lastChestArgs = nil

local QUEST_DATA = {
    {"Bully1","Lv0"},{"Bully2","Lv10"},{"q2mob1","Lv25"},{"q2mob2","Lv40"},
    {"q3mob1","Lv55"},{"q3mob2","Lv70"},{"q5mob1","Lv85"},{"q5mob2","Lv100"},
    {"CursedFighter","Lv115"},{"CursedFighter2","Lv130"},{"q6mob1","Lv150"},{"q6mob2","Lv170"},
    {"ShoreCrawler1","Lv200"},{"ShoreCrawler2","Lv220"},{"DeepSeaCurse","Lv240"},{"Diver1","Lv270"},
    {"Diver2","Lv300"},{"CursedMonster","Lv320"},{"CursedSpirit1","Lv350"},{"CursedSpirit2","Lv370"},
    {"CursedBeast","Lv400"},{"CursedMonster1","Lv430"},{"CursedMonster2","Lv450"},{"CurseUser","Lv470"},
    {"TransfiguredMonster1","Lv500"},{"TransfiguredMonster2","Lv530"},{"Granny1","Lv550"},{"Granny2","Lv570"},
    {"Granny3","Lv600"},{"Manager1","Lv630"},{"Manager2","Lv660"},{"Kid1","Lv690"},
    {"FightClub1","Lv720"},{"FightClub2","Lv750"},{"Momo1","Lv780"},{"Momo2","Lv810"},
    {"Momo3","Lv840"},{"Suda1","Lv870"},{"Suda2","Lv900"},{"Manager2_1","Lv930"},
    {"Manager2_2","Lv960"},{"Manager2_3","Lv990"},{"Hinata1","Lv1020"},{"Hinata2","Lv1050"},
    {"Hinata3","Lv1080"},{"Hinata4","Lv1110"},{"OldMan1","Lv1140"},{"OldMan2","Lv1170"},
    {"OldMan3","Lv1200"},{"Shino1","Lv1210"},{"Shino2","Lv1230"},{"MysteriousSorcerer1","Lv1280"},
    {"MysteriousSorcerer2","Lv1320"},{"MysteriousSorcerer3","Lv1360"},{"WoundedSpy1","Lv1400"},{"WoundedSpy2","Lv1430"},
    {"WoundedSpy3","Lv1460"},{"Miwa1","Lv1460"},{"Miwa2","Lv1480"},{"JujutsuCourier1","Lv1500"},
    {"JujutsuCourier2","Lv1550"},{"JujutsuCourier3","Lv1600"},{"CurseHunter1","Lv1650"},{"CurseHunter2","Lv1700"},
    {"CurseHunter3","Lv1750"},
    {"DisgracedSorcerer1","Lv1850"},{"DisgracedSorcerer2","Lv1900"},{"DisgracedSorcerer3","Lv1950"},
    {"StrandedSurvivor1","Lv1970"},{"StrandedSurvivor2","Lv2000"},{"StrandedSurvivor3","Lv2050"},
    {"Castaway1","Lv2100"},{"Castaway2","Lv2150"},{"Castaway3","Lv2200"},
    {"Scavenger1","Lv2450"},{"Scavenger2","Lv2500"},{"Scavenger3","Lv2550"},
    {"HermitSorcerer1","Lv2650"},{"HermitSorcerer2","Lv2700"},{"HermitSorcerer3","Lv2750"},
    {"LastGuardian1","Lv2850"},{"LastGuardian2","Lv2900"},{"LastGuardian3","Lv2950"},
}

function NexusSupervise(name, fn)
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            local ok = pcall(fn)
            if ok then break end
            task.wait(0.5)
        end
    end)
end

 NEXUS_LV.QUEST_LIST = {}
for _, q in ipairs(QUEST_DATA) do table.insert(NEXUS_LV.QUEST_LIST, q[1]) end
local selQuest = 1
 NEXUS_LV.AutoNext = false
 NEXUS_LV.updateQuestLabel = nil
local function currentQuestId()   return QUEST_DATA[selQuest] and QUEST_DATA[selQuest][1] or "Bully1" end
NEXUS_LV.currentQuestName = function() return QUEST_DATA[selQuest] and QUEST_DATA[selQuest][2] or "?" end

local Characters = workspace:WaitForChild("Characters")
 NEXUS_LV.ServerF    = Characters:WaitForChild("Server")
local PlayersF   = NEXUS_LV.ServerF:WaitForChild("Players")
local NPCsF      = NEXUS_LV.ServerF:WaitForChild("NPCs", 20) or NEXUS_LV.ServerF:FindFirstChild("NPCs")

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if (not NPCsF) or (not NPCsF.Parent) then
            local f = NEXUS_LV.ServerF:FindFirstChild("NPCs")
            if f then NPCsF = f end
        end
        task.wait(1)
    end
end)

MyModel = nil

NexusDmgLastDone = os.clock()
NexusStartLastDone = os.clock()
local dmgWaiting = 0
local startWaiting = 0
 NEXUS_LV.MAX_DMG_WAITING = 5
 NEXUS_LV.MAX_START_WAITING = 4
pcall(function()

    if NEXUSG.NexusPlayHubHooked then return end
    NEXUSG.NexusPlayHubHooked = true
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if m == "InvokeServer" and typeof(self) == "Instance" then
            if self == DamageCharacter then
                local a = {...}
                local info = a[3]

                if typeof(info) == "table" then
                    local lc = info.LocalCharacter
                    if typeof(lc) == "Instance" and lc.Parent == PlayersF then
                        MyModel = lc
                    elseif type(lc) == "table" then
                        pcall(function()
                            local sm = lc.ServerModel
                            if typeof(sm) == "Instance" and sm.Parent == PlayersF then MyModel = sm end
                        end)
                    end
                end

                if dmgWaiting > 0 and (os.clock() - (NexusDmgLastDone or 0)) > 3 then dmgWaiting = 0 end
                if dmgWaiting >= NEXUS_LV.MAX_DMG_WAITING then return end
                dmgWaiting = dmgWaiting + 1
                local ok, r = pcall(old, self, ...)
                dmgWaiting = dmgWaiting - 1
                NexusDmgLastDone = os.clock()
                if ok then return r end
                return
            elseif self == StartSkill then
                local a = {...}
                if typeof(a[2]) == "Instance" and a[2].Parent == PlayersF then
                    MyModel = a[2]
                elseif type(a[2]) == "table" then
                    pcall(function()
                        local sm = a[2].ServerModel
                        if typeof(sm) == "Instance" and sm.Parent == PlayersF then MyModel = sm end
                    end)
                end
                if startWaiting > 0 and (os.clock() - (NexusStartLastDone or 0)) > 3 then startWaiting = 0 end
                if startWaiting >= NEXUS_LV.MAX_START_WAITING then return end
                startWaiting = startWaiting + 1
                local ok2, r2 = pcall(old, self, ...)
                startWaiting = startWaiting - 1
                NexusStartLastDone = os.clock()
                if ok2 then return r2 end
                return
            elseif self == NEXUS_LV.UseItem then

                lastChestArgs = table.pack(...)
            end
        end
        return old(self, ...)
    end)
end)

NexusCC = NexusCC or { t = -1, mod = nil }

function NexusCharacterController()
    local now = os.clock()
    if NexusCC.mod and (now - NexusCC.t) < 5 then return NexusCC.mod end
    local ok, mod = pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local cl = ps and ps:FindFirstChild("Client")
        local ct = cl and cl:FindFirstChild("Controllers")
        local cc = ct and ct:FindFirstChild("CharacterController")
        if cc then return require(cc) end
        return nil
    end)
    NexusCC.t = now
    if ok and type(mod) == "table" then NexusCC.mod = mod end
    return NexusCC.mod
end

function NexusLocalChar()
    local cc = NexusCharacterController()
    if not cc then return nil end
    local ok, lc = pcall(function() return cc.LocalCharacter end)
    if ok and type(lc) == "table" then return lc end
    return nil
end

NexusOwnMemo = NexusOwnMemo or { m = nil, t = -1 }

function NexusOwnServerModel()
    local now = os.clock()
    local c = NexusOwnMemo
    if c.m and c.m.Parent == PlayersF and (now - c.t) < 0.25 then return c.m end
    local m

    local lc = NexusLocalChar()
    if lc then
        pcall(function()
            local sm = lc.ServerModel
            if typeof(sm) == "Instance" and sm.Parent == PlayersF then m = sm end
        end)
    end

    if not m then
        pcall(function()
            local cf = workspace:FindFirstChild("Characters")
            local clientF = cf and cf:FindFirstChild("Client")
            local myC = clientF and (clientF:FindFirstChild(LocalPlayer.Name .. "_Client")
                or clientF:FindFirstChild((LocalPlayer.DisplayName or LocalPlayer.Name) .. "_Client"))
            local ch = myC and myC:FindFirstChild("HumanoidRootPart")
            if not ch then return end
            local best, bd
            for _, sm in ipairs(PlayersF:GetChildren()) do
                local sh = sm:FindFirstChild("HumanoidRootPart")
                if sh then
                    local d = (sh.Position - ch.Position).Magnitude
                    if not bd or d < bd then best, bd = sm, d end
                end
            end
            if best and bd and bd <= 8 then m = best end
        end)
    end

    if m then c.m, c.t = m, now return m end
    return nil
end

NexusModelMemo = NexusModelMemo or { m = nil, t = -1 }
local function getModel()

    -- [NEXUS-OPT] keep a confirmed own-model lock so camera-nearest cannot hijack it
    local locked = NEXUS_LOCKED_MODEL
    if locked and locked.Parent == PlayersF and locked:FindFirstChild("HumanoidRootPart") then
        return locked
    end

    local mine = NexusOwnServerModel()
    if mine then MyModel = mine NEXUS_LOCKED_MODEL = mine return mine end

    if MyModel and MyModel.Parent == PlayersF then return MyModel end
    local char = LocalPlayer.Character
    if char and char.Parent == PlayersF then MyModel = char return char end

    local refPos
    if char and char:FindFirstChild("HumanoidRootPart") then
        refPos = char.HumanoidRootPart.Position
    elseif workspace.CurrentCamera then
        refPos = workspace.CurrentCamera.CFrame.Position
    end
    if refPos then

        local now = os.clock()
        local mc = NexusModelMemo
        if mc.m and mc.m.Parent and (now - mc.t) < 0.05 then return mc.m end
        local best, bestD
        for _, m2 in ipairs(PlayersF:GetChildren()) do
            local hrp = m2:FindFirstChild("HumanoidRootPart")
            if hrp then
                local p = hrp.Position
                local dx, dy, dz = p.X - refPos.X, p.Y - refPos.Y, p.Z - refPos.Z
                local d = dx * dx + dy * dy + dz * dz
                if not bestD or d < bestD then best, bestD = m2, d end
            end
        end
        mc.m, mc.t = best, now
        return best
    end
    return nil
end

MY_ISLAND_ONLY = true
 NEXUS_LV.ISLAND_MARGIN = 60

IslandFolderCache = { t = -1, folder = nil }
NEXUS_LV.getBossIslandsFolder = function()
    local now = os.clock()
    local f = IslandFolderCache.folder
    if f and f.Parent and (now - IslandFolderCache.t) < 3 then return f end
    f = nil
    local map = workspace:FindFirstChild("Map")
    local geo = map and map:FindFirstChild("Geometry")
    if geo then f = geo:FindFirstChild("BossIslands") end
    if not f then
        for _, d in ipairs(wsDesc()) do
            if d.Name == "BossIslands" and (d:IsA("Folder") or d:IsA("Model")) then f = d break end
        end
    end
    IslandFolderCache.folder = f
    IslandFolderCache.t = now
    return f
end

IslandListCache = { t = -1, list = {} }
NEXUS_LV.getIslandList = function()
    local now = os.clock()
    if IslandListCache.t >= 0 and (now - IslandListCache.t) < 2 then return IslandListCache.list end
    local list = {}
    local folder = NEXUS_LV.getBossIslandsFolder()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
                if ok and cf and size then
                    table.insert(list, {
                        model  = m,
                        cf     = cf,
                        center = cf.Position,
                        half   = (size * 0.5) + Vector3.new(NEXUS_LV.ISLAND_MARGIN, NEXUS_LV.ISLAND_MARGIN, NEXUS_LV.ISLAND_MARGIN),
                    })
                end
            end
        end
    end
    IslandListCache.list = list
    IslandListCache.t = now
    return list
end

NEXUS_LV.nearestIsland = function(pos)
    local best, bestD
    for _, isl in ipairs(NEXUS_LV.getIslandList()) do
        local d = (isl.center - pos).Magnitude
        if not bestD or d < bestD then best, bestD = isl, d end
    end
    return best, bestD
end

NEXUS_LV.islandOf = function(pos)
    local best, bestD
    for _, isl in ipairs(NEXUS_LV.getIslandList()) do
        local rel = isl.cf:PointToObjectSpace(pos)
        if math.abs(rel.X) <= isl.half.X and math.abs(rel.Y) <= isl.half.Y and math.abs(rel.Z) <= isl.half.Z then
            local d = (isl.center - pos).Magnitude
            if not bestD or d < bestD then best, bestD = isl, d end
        end
    end
    return best
end

MyIslandCache = { t = -1, isl = nil }
NEXUS_LV.myIsland = function()
    local now = os.clock()
    if MyIslandCache.t >= 0 and (now - MyIslandCache.t) < 0.4 then return MyIslandCache.isl end
    local isl = nil
    local mdl = getModel()
    local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
    if hrp then
        isl = NEXUS_LV.islandOf(hrp.Position) or (NEXUS_LV.nearestIsland(hrp.Position))
    end
    MyIslandCache.isl = isl
    MyIslandCache.t = now
    return isl
end

function onMyIsland(pos)
    if not MY_ISLAND_ONLY then return true end
    local islands = NEXUS_LV.getIslandList()
    if #islands <= 1 then return true end
    local mine = NEXUS_LV.myIsland()
    if not mine then return true end
    local here = NEXUS_LV.islandOf(pos)
    if not here then return true end
    return here.model == mine.model
end

IGNORED_NPC_NAMES = { "lv.1 punching bag", "punching bag" }

NEXUS_HIT_BAG = NEXUS_HIT_BAG or false
NEXUS_LV.textMatchesIgnored = function(txt)
    local low = string.lower(txt)
    for _, ig in ipairs(IGNORED_NPC_NAMES) do
        if string.find(low, ig, 1, true) then return true end
    end
    return false
end
PunchingBagPosCache = { t = -1, list = {} }
function refreshPunchingBagPositions()
    local now = os.clock()
    if PunchingBagPosCache.t >= 0 and (now - PunchingBagPosCache.t) < 0.2 then
        return PunchingBagPosCache.list
    end
    local list = {}
    local ok = pcall(function()
        local ClientF = Characters:FindFirstChild("Client")
        if not ClientF then return end
        for _, d in ipairs(clientLabels(ClientF)) do
            if d:IsA("TextLabel") and NEXUS_LV.textMatchesIgnored(d.Text) then
                local rig = d:FindFirstAncestorWhichIsA("Model")
                local h = rig and rig:FindFirstChild("HumanoidRootPart")
                if h then table.insert(list, h.Position) end
            end
        end
    end)
    if ok then
        PunchingBagPosCache.list = list
        PunchingBagPosCache.t = now
    end
    return PunchingBagPosCache.list
end

NEXUS_PET_FOLDER = "Shikigami"
NexusPetSet = {}
NexusPetScanAt = 0
function nexusBaseName(n)
    n = string.lower(tostring(n or ""))
    n = string.gsub(n, "_server$", "")
    n = string.gsub(n, "_client$", "")
    return n
end
function nexusRefreshPets()
    if os.clock() - NexusPetScanAt < 0.5 then return end
    NexusPetScanAt = os.clock()
    local set = {}
    pcall(function()
        local sf = Characters:FindFirstChild("Server")
        local pf = sf and sf:FindFirstChild(NEXUS_PET_FOLDER)
        if not pf then return end
        for _, m in ipairs(pf:GetChildren()) do
            set[m] = true
            local b = nexusBaseName(m.Name)
            if #b > 0 then set[b] = true end
        end
    end)
    NexusPetSet = set
end
function nexusIsPetModel(m)
    if not m then return false end
    nexusRefreshPets()
    local pet = false
    pcall(function()
        if NexusPetSet[m] then pet = true return end
        if m:FindFirstAncestor(NEXUS_PET_FOLDER) then pet = true return end
        local par = m.Parent
        while par do
            if par.Name == NEXUS_PET_FOLDER then pet = true return end
            par = par.Parent
        end
        if NexusPetSet[nexusBaseName(m.Name)] then pet = true end
    end)
    return pet
end

function nexusFilterPetsRaw(targets)
    if type(targets) ~= "table" then return targets end
    local out = {}
    for _, m in ipairs(targets) do
        if not nexusIsPetModel(m) then out[#out + 1] = m end
    end
    return out
end

-- [NEXUS-OPT] filter once per tick per list instead of once per skill
NEXUS_PETF = NEXUS_PETF or setmetatable({}, { __mode = "k" })
function nexusFilterPets(targets)
    if type(targets) ~= "table" then return targets end
    local now = os.clock()
    local hit = NEXUS_PETF[targets]
    if hit and (now - hit.t) < 0.05 and hit.n == #targets then return hit.out end
    local out = nexusFilterPetsRaw(targets)
    NEXUS_PETF[targets] = { out = out, t = now, n = #targets }
    return out
end

NexusLvCache = NexusLvCache or {}
NexusLvCacheAt = NexusLvCacheAt or 0
function nexusLevelOf(m)
    if not m then return nil end
    local now = os.clock()
    if (now - NexusLvCacheAt) > 1 then NexusLvCache, NexusLvCacheAt = {}, now end
    local hit = NexusLvCache[m]
    if hit ~= nil then
        if hit == false then return nil end
        return hit
    end
    local lv
    local function grab(s)
        if not s then return end
        local n = string.match(string.lower(tostring(s)), "lv%.?%s*(%d+)")
        n = n and tonumber(n)
        if n and (not lv or n > lv) then lv = n end
    end
    pcall(function()
        grab(m.Name)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("TextLabel") then grab(d.Text) end
        end
    end)
    NexusLvCache[m] = (lv == nil) and false or lv
    return lv
end

function nexusIsLv1(m)
    local lv = nexusLevelOf(m)
    return lv == nil or lv <= 1
end

NEXUS_BAG_TTL = 5
NEXUS_BAG_CACHE = NEXUS_BAG_CACHE or {}
NEXUS_BAG_AT = NEXUS_BAG_AT or 0
function NexusBagCacheClear() NEXUS_BAG_CACHE = {} end
NexusPruneRegister(function() return NEXUS_BAG_CACHE end)
function isPunchingBag(m)
    if not m then return false end
    local now = os.clock()
    if (now - NEXUS_BAG_AT) > NEXUS_BAG_TTL then NEXUS_BAG_CACHE, NEXUS_BAG_AT = {}, now end
    local hit = NEXUS_BAG_CACHE[m]
    if hit ~= nil then return hit end
    local v = NexusBagTest(m)
    NEXUS_BAG_CACHE[m] = v
    return v
end
function NexusBagTest(m)
    if not m then return false end

    if NEXUS_HIT_BAG then return false end

    local ok, nm = pcall(function() return m.Name end)
    if ok and nm and NEXUS_LV.textMatchesIgnored(nm) then return true end

    local ok2, hitB = pcall(function()
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("TextLabel") and NEXUS_LV.textMatchesIgnored(d.Text) then return true end
        end
        return false
    end)
    if ok2 and hitB then return true end

    local ok3, hitC = pcall(function()
        local h = m:FindFirstChild("HumanoidRootPart")
        if not h then return false end
        for _, pos in ipairs(refreshPunchingBagPositions()) do
            if (h.Position - pos).Magnitude < 25 then return true end
        end
        return false
    end)
    if ok3 and hitC then return true end
    return false
end
function computeTargets(range)
    range = range or NEXUS_LV.ATTACK_RANGE
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not myHRP then return {}, nil, nil end

    if outerVoidPausing then return {}, myModel, myHRP end
    local myPos = myHRP.Position
    local targets = {}
    local function scan(folder)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do
            if m ~= myModel and not isPunchingBag(m) and not nexusIsPetModel(m) then
                local h, hum = nexusRig(m)

                local alive = (hum and hum.Health > 0) or (NEXUS_HIT_BAG and not hum)
                if h and alive and (h.Position - myPos).Magnitude <= range and onMyIsland(h.Position) then
                    table.insert(targets, m)
                end
            end
        end
    end
    scan(NPCsF)
    if NEXUS_LV.HIT_PLAYERS then scan(PlayersF) end

    if (AutoOuterRaidOn or AutoJogoRaidOn or AutoBloodRaidOn) and nexusInRaidServer() then

        local cached = outerAddCache
        if cached and #cached > 0 then
            local adds = {}
            for _, m in ipairs(cached) do
                if m and m.Parent and not isPunchingBag(m) and not nexusIsPetModel(m) then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health > 0 then table.insert(adds, m) end
                end
            end
            if #adds > 0 then
                local function posOf(x)
                    local p = x:FindFirstChild("HumanoidRootPart") or (x:IsA("Model") and x.PrimaryPart)
                    return p and p.Position or nil
                end
                table.sort(adds, function(a, b)
                    local ap, bp = posOf(a), posOf(b)
                    local ad = ap and (ap - myPos).Magnitude or math.huge
                    local bd = bp and (bp - myPos).Magnitude or math.huge
                    return ad < bd
                end)
                return adds, myModel, myHRP
            end
        end
    end

    if AutoSorcRaidOn and nexusInRaidServer() and (sorcBossLocked or (type(sorcAddCache) == "table" and #sorcAddCache > 0)) then
        local lock = {}
        for _, m in ipairs(sorcAddCache) do
            if m and m.Parent and m ~= myModel and not isPunchingBag(m) and not nexusIsPetModel(m) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health > 0 then table.insert(lock, m) end
            end
        end
        if #lock > 0 then
            local function shPos(x)
                local p = x:FindFirstChild("HumanoidRootPart") or (x:IsA("Model") and x.PrimaryPart)
                return p and p.Position or nil
            end
            table.sort(lock, function(a, b)
                local ap, bp = shPos(a), shPos(b)
                local ad = ap and (ap - myPos).Magnitude or math.huge
                local bd = bp and (bp - myPos).Magnitude or math.huge
                return ad < bd
            end)
            return lock, myModel, myHRP
        end

        if sorcBossLocked then return {}, myModel, myHRP end
    end
    return targets, myModel, myHRP
end

TgtCache = TgtCache or {}
NexusRangeCache = NexusRangeCache or {}
NEXUS_LV.collectTargets = function(range)
    if range == nil then
        local now = os.clock()
        if TgtCache.a and (now - (TgtCache.t or 0)) < TGT_CACHE_SEC then
            return TgtCache.a, TgtCache.b, TgtCache.c
        end
        local a, b, c = computeTargets(nil)

        if b then
            TgtCache.a, TgtCache.b, TgtCache.c, TgtCache.t = a, b, c, now
        end
        return a, b, c
    end

    local now = os.clock()
    local slot = NexusRangeCache[range]
    if slot and (now - slot.t) < TGT_CACHE_SEC and slot.b then
        return slot.a, slot.b, slot.c
    end
    local a, b, c = computeTargets(range)
    if b then
        if not slot then slot = {} NexusRangeCache[range] = slot end
        slot.a, slot.b, slot.c, slot.t = a, b, c, now
    end
    return a, b, c
end

NEXUS_BRING_LAST, NEXUS_BRING_LAST_T, NEXUS_BRING_MODEL, NEXUS_BRING_HRP = nil, 0, nil, nil
function NexusActiveList()
    local ring = NEXUS_BRING_LAST
    if ring and #ring > 0 and (os.clock() - NEXUS_BRING_LAST_T) < 1
        and NEXUS_BRING_HRP and NEXUS_BRING_HRP.Parent then
        return ring, NEXUS_BRING_MODEL, NEXUS_BRING_HRP
    end
    return NEXUS_LV.collectTargets()
end
function NexusRunList(fn) fn(NexusActiveList()) end
function NexusListJob(fn) NexusBusyT = os.clock() pcall(NexusRunList, fn) end
function NexusRunNamed(fn, name) fn(name, NexusActiveList()) end
function NexusNamedJob(fn, name) NexusBusyT = os.clock() pcall(NexusRunNamed, fn, name) end

NexusBusyT = 0
NEXUS_IDLE_GAP = 0.2
function NexusGap()
    return (os.clock() - NexusBusyT < 1) and LOOP_GAP or NEXUS_IDLE_GAP
end

NEXUS_LV.getNearest = function(range)
    local targets, myModel, myHRP = NEXUS_LV.collectTargets(range)
    if not myHRP or #targets == 0 then return nil, myModel, myHRP end
    local nearest, nd
    for _, m in ipairs(targets) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h then
            local d = (h.Position - myHRP.Position).Magnitude
            if not nd or d < nd then nearest, nd = m, d end
        end
    end
    return nearest, myModel, myHRP
end

-- [NEXUS-OPT] one nearest-target-position routine, memoized per tick.
-- Replaces 7 byte-identical inline copies. Same math, same fallback value.
-- The 0.05s memo means N skills firing on the same target list in one tick
-- walk that list once instead of N times.
NEXUS_NEARPOS = NEXUS_NEARPOS or setmetatable({}, { __mode = "k" })
NEXUS_LV.nearestPos = function(targets, myHRP)
    if not myHRP then return nil end
    if type(targets) ~= "table" then return myHRP.Position end
    local now = os.clock()
    local c = NEXUS_NEARPOS[targets]
    if c and (now - c.t) < 0.05 and c.n == #targets and c.hrp == myHRP then
        return c.pos
    end
    local best, bd
    for _, m in ipairs(targets) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h then
            local d = (h.Position - myHRP.Position).Magnitude
            if not bd or d < bd then best, bd = h.Position, d end
        end
    end
    local out = best or myHRP.Position
    NEXUS_NEARPOS[targets] = { pos = out, t = now, n = #targets, hrp = myHRP }
    return out
end

 NEXUS_LV.combo = 1

startLast = {}
START_GAP = 0.15
function startReady(key)
    if NEXUS_RAMPAGE_ON then return true end
    local now = os.clock()
    local last = startLast[key]
    if last and (now - last) < START_GAP then return false end
    startLast[key] = now
    return true
end

dmgLast = {}
DMG_GAP = 0.05
function damageReady(key)
    if NEXUS_RAMPAGE_ON then return true end
    local now = os.clock()
    local last = dmgLast[key]
    if last and (now - last) < DMG_GAP then return false end
    dmgLast[key] = now
    return true
end

NEXUS_FLY_TTL = 3
NEXUS_LV.nexusFlyTable = function()
    local store = {}
    return setmetatable({}, {
        __index = function(_, k)
            local at = store[k]
            if at and (os.clock() - at) < NEXUS_FLY_TTL then return true end
            store[k] = nil
            return nil
        end,
        __newindex = function(_, k, v)
            store[k] = v and os.clock() or nil
        end,
        __len = function() return 0 end,
    })
end
dmgInflight = NEXUS_LV.nexusFlyTable()
startInflight = NEXUS_LV.nexusFlyTable()
local function attackList(targets, myModel, myHRP)
    targets = nexusFilterPets(targets)
    if not myModel or not myHRP or #targets == 0 then return end
    local first = targets[1]:FindFirstChild("HumanoidRootPart")
    local dir = (first and (first.Position - myHRP.Position).Unit) or myHRP.CFrame.LookVector

    if startReady("Punch") and not startInflight["Punch"] then
        startInflight["Punch"] = true
        task.spawn(function()
            pcall(function() NexusGatedInvoke(StartSkill, "Punch", myModel, dir, nil, NEXUS_LV.combo, 1) end)
            startInflight["Punch"] = false
        end)
    end
    if damageReady("Punch") and not dmgInflight["Punch"] then
        dmgInflight["Punch"] = true
        task.spawn(function()
            pcall(function()
                NexusGatedInvoke(DamageCharacter, targets, true, {
                    WindowID = myModel.Name .. "_Punch",
                    LocalCharacter = myModel,
                    SkillID = "Punch",
                    CanParry = true,
                    Origin = myHRP.CFrame,
                })
            end)
            dmgInflight["Punch"] = false
        end)
    end
    NEXUS_LV.combo = NEXUS_LV.combo % 5 + 1
end

local FastOn = false
 NEXUS_LV.KillOn = false
 NEXUS_LV.essenceBusy = false
 NEXUS_LV.crateBusy = false
local STICK_OFFSET = 4

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if FastOn then
            NexusQ(NexusListJob, attackList)
        end
        task.wait(math.max(NEXUS_LV.TICK, LOOP_GAP))
    end
end)

GLOBAL_SKILL_GAP = 0.01
 NEXUS_LV.fireLast = {}

-- [NEXUS-OPT] real per-skill cooldown from CombatConfig, cached forever
NEXUS_CD_CACHE = NEXUS_CD_CACHE or {}
function NexusSkillCooldown(key)
    local c = NEXUS_CD_CACHE[key]
    if c ~= nil then return c end
    c = false
    pcall(function()
        local cfg = require(RepStorage.Configs.CombatConfig)
        local d = cfg.SkillData and cfg.SkillData[key]
        if type(d) == "table" and tonumber(d.Cooldown) then c = tonumber(d.Cooldown) end
    end)
    NEXUS_CD_CACHE[key] = c
    return c
end

function NexusClearMoveGates() NEXUS_LV.fireLast = {} end
NEXUS_LV.globalReady = function(key)
    key = key or "_"
    if NEXUS_RAMPAGE_ON then return true end
    local now = os.clock()
    local last = NEXUS_LV.fireLast[key]
    local gap = GLOBAL_SKILL_GAP
    local cd = NexusSkillCooldown(key)
    if cd then
        local scaled = cd * (NEXUS_OPT.CD_SCALE or 0.5)
        if scaled > gap then gap = scaled end
    end
    if last and (now - last) < gap then return false end
    NEXUS_LV.fireLast[key] = now
    return true
end

function NexusFlags()
    if type(NexusPDC) ~= "table" then
        pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local cl = ps and ps:FindFirstChild("Client")
            local ct = cl and cl:FindFirstChild("Controllers")
            local md = ct and ct:FindFirstChild("PlayerDataController")
            if md then NexusPDC = require(md) end
        end)
    end
    if type(NexusPDC) ~= "table" then return nil end
    local data = NexusPDC.PlayerData
    if type(data) ~= "table" then return nil end
    local flags = data.Flags
    if type(flags) ~= "table" then return nil end
    return flags
end

function NexusSetFlag(name, value)
    local flags = NexusFlags()
    if not flags then return false end
    if flags[name] == value then return true end
    flags[name] = value
    return true
end

task.spawn(function()
    local flags = NexusFlags()
    if not flags then return end
    for _, k in ipairs({
        "GachaPullPity", "GachaUniquePullPity", "CratePity", "BossIslandLimits",
        "ClaimedEventDays", "TowerDayCompletions", "TradeRatings", "TrialCTsCompleted",
        "ArenaOpponents", "ReadAllCache",
    }) do
        if flags[k] == nil then flags[k] = {} end
    end
end)
local BlackFlashOn = false

BF_CD      = BF_CD or {}
BF_EXISTS  = BF_EXISTS or {}
BF_LAST    = BF_LAST or {}
BF_PAYLOAD = BF_PAYLOAD or {}

BF_CHARGES     = tonumber(S("BFCharges", 2)) or 2
BF_INTERVAL_MS = tonumber(S("BFIntervalMs", 1000)) or 1000
function NexusBFCooldown(skill)
    local cd = BF_CD[skill]
    if cd ~= nil then return cd end
    cd = 1
    local ok = false
    pcall(function()
        local cfg = require(RepStorage.Configs.CombatConfig)
        local d = cfg.SkillData and cfg.SkillData[skill]
        if type(d) == "table" then
            ok = true
            cd = tonumber(d.Cooldown) or 1
        end
    end)
    BF_CD[skill] = cd
    BF_EXISTS[skill] = ok
    return cd
end
function NexusBFExists(skill)
    if BF_EXISTS[skill] == nil then NexusBFCooldown(skill) end
    return BF_EXISTS[skill] == true
end

function NexusBFStartReady(skill)
    local now = os.clock()
    local last = BF_LAST[skill]

    local gap = NexusBFCooldown(skill)
    local ms = tonumber(BF_INTERVAL_MS) or 0
    if ms > 0 then gap = ms / 1000 end
    if last and (now - last) < gap then return false end
    BF_LAST[skill] = now
    return true
end

function NexusBFPayload(skill, myModel)
    local p = BF_PAYLOAD[skill]
    if not p then
        p = { Knockback = { Duration = 0.2, Distance = 20 }, SkillID = skill }
        BF_PAYLOAD[skill] = p
    end
    p.WindowID = myModel.Name .. "_" .. skill
    p.LocalCharacter = myModel
    return p
end

function NexusBFCast(skill, targets, myModel, myHRP)
    if not myModel or not myHRP or not targets or #targets == 0 then return end
    if not NexusBFExists(skill) then return end

    -- Rebuild the target list at cast time so a boss that respawns/replaces
    -- its model is not hit through a stale Instance reference.
    local liveTargets = {}
    for _, t in ipairs(targets) do
        if t and t.Parent then
            local hum = t:FindFirstChildOfClass("Humanoid")
            local hrp = t:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                liveTargets[#liveTargets + 1] = t
            end
        end
    end
    if #liveTargets == 0 then return end

    local first = liveTargets[1]:FindFirstChild("HumanoidRootPart")
    local dir = (first and (first.Position - myHRP.Position).Unit) or myHRP.CFrame.LookVector

    if NexusBFStartReady(skill) and not startInflight[skill] then
        startInflight[skill] = true
        dmgInflight[skill] = true

        NexusSetFlag("CanBlackFlash", true)
        NexusSetFlag("BlackFlashSkill", skill)

        task.spawn(function()
            local charges = tonumber(BF_CHARGES) or 2
            local payload = NexusBFPayload(skill, myModel)

            -- StartSkill must complete before the first damage request.
            pcall(function()
                NexusGatedInvoke(StartSkill, skill, myModel, dir, nil, charges)
            end)

            -- Bosses can take a little longer to commit the skill state than
            -- regular NPCs. Retry the damage window a few times instead of
            -- relying on one frame-perfect request.
            task.wait(0.05)

            for attempt = 1, 3 do
                local current = {}
                for _, t in ipairs(liveTargets) do
                    if t and t.Parent then
                        local hum = t:FindFirstChildOfClass("Humanoid")
                        local hrp = t:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 then
                            current[#current + 1] = t
                        end
                    end
                end

                if #current == 0 then break end

                pcall(function()
                    NexusGatedInvoke(DamageCharacter, current, true, payload)
                end)

                task.wait(0.05)
            end

            startInflight[skill] = false
            dmgInflight[skill] = false
        end)
    elseif damageReady(skill) and not dmgInflight[skill] then
        -- Fallback damage window when the skill is already active.
        dmgInflight[skill] = true
        local payload = NexusBFPayload(skill, myModel)
        task.spawn(function()
            pcall(function()
                NexusGatedInvoke(DamageCharacter, liveTargets, true, payload)
            end)
            dmgInflight[skill] = false
        end)
    end
end
local function enableBlackFlash(skill)
    NexusSetFlag("CanBlackFlash", true)
    NexusSetFlag("BlackFlashSkill", skill or "BlackFlashSkill1")
end
local function blackFlashList(targets, myModel, myHRP)
    NexusBFCast("BlackFlashSkill1", nexusFilterPets(targets), myModel, myHRP)
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if BlackFlashOn or NEXUS_LV.KillOn then enableBlackFlash() end
        task.wait(1)
    end
end)

 NEXUS_LV.BlackFlash2On = false
 NEXUS_LV.BlackFlash3On = false
function fireBlackFlash(skillName, targets, myModel, myHRP)
    NexusBFCast(skillName, nexusFilterPets(targets), myModel, myHRP)
end
function NexusRunBF(name) fireBlackFlash(name, NexusActiveList()) end
function NexusBFJob(name) NexusBusyT = os.clock() pcall(NexusRunBF, name) end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do

        if BlackFlashOn and NEXUS_LV.globalReady("BlackFlashSkill1") then NexusQ(NexusListJob, blackFlashList) end
        if NEXUS_LV.BlackFlash2On and NEXUS_LV.globalReady("BlackFlashSkill2") then NexusQ(NexusBFJob, "BlackFlashSkill2") end
        if NEXUS_LV.BlackFlash3On and NexusBFExists("BlackFlashSkill3") and NEXUS_LV.globalReady("BlackFlashSkill3") then
            NexusQ(NexusBFJob, "BlackFlashSkill3")
        end
        task.wait(NexusGap())
    end
end)

 NEXUS_LV.SukunaOn = false
 NEXUS_LV.HakariOn = false
 NEXUS_LV.PlungeOn = false
NEXUS_LV.plungeList = function(targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end

    local pos = NEXUS_LV.nearestPos(targets, myHRP)

    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, "Plunge", myModel, pos)
    end) end)

    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_Plunge",
            LocalCharacter = myModel,
            SkillID = "Plunge",
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.PlungeOn then
            NexusQ(NexusListJob, NEXUS_LV.plungeList)
        end
        task.wait(LOOP_GAP)
    end
end)

SKILL_GAP = 0.01
TOTAL_GAP = 0.02

SKILL_BUDGET = 30
 NEXUS_LV.skillFireLast = {}
 NEXUS_LV.skillLastReq = {}
 NEXUS_LV.activeCache = {}
 NEXUS_LV.activeCacheT = 0

function NexusClearSkillGates()
    NEXUS_LV.skillFireLast = {}
    NEXUS_LV.skillLastReq = {}
    NEXUS_LV.activeCache = {}
    NEXUS_LV.activeCacheT = 0
end

NEXUS_REAL_CD_MIN = 3
NEXUS_SKILL_CD    = {}
NEXUS_SKILL_CD_AT = {}
function NexusSkillCd(name)
    if not name then return nil end
    local v = NEXUS_SKILL_CD[name]
    if v ~= nil then
        if v == false then return nil end
        return v
    end
    local cd = nil
    pcall(function()
        local cc = require(RepStorage.Configs.CombatConfig)
        local d  = cc and cc.SkillData and cc.SkillData[name]
        if type(d) == "table" then cd = tonumber(d.Cooldown) end
    end)
    NEXUS_SKILL_CD[name] = cd or false
    return cd
end

local function skillReady(name)
    name = name or "_"

    if NEXUS_RAMPAGE_ON then return true end
    local now = os.clock()
    NEXUS_LV.skillLastReq[name] = now

    local last = NEXUS_LV.skillFireLast[name]
    if last and (now - last) < SKILL_GAP then return false end

    local realCd = NexusSkillCd(name)
    if realCd and realCd >= NEXUS_REAL_CD_MIN then
        local at = NEXUS_SKILL_CD_AT[name]
        if at and (now - at) < realCd then
            NEXUS_LV.skillLastReq[name] = nil
            return false
        end
        NEXUS_SKILL_CD_AT[name] = now
        NEXUS_LV.skillFireLast[name]    = now
        return true
    end

    if (now - NEXUS_LV.activeCacheT) >= 0.05 then
        local a = {}
        for k, t in pairs(NEXUS_LV.skillLastReq) do
            if (now - t) < 0.3 then a[#a + 1] = k end
        end
        table.sort(a)
        NEXUS_LV.activeCache = a
        NEXUS_LV.activeCacheT = now
    end

    local n = #NEXUS_LV.activeCache
    if n > 0 then
        local slot = (math.floor(now / TOTAL_GAP) % n) + 1
        if NEXUS_LV.activeCache[slot] ~= name then return false end
    end
    NEXUS_LV.skillFireLast[name] = now
    return true
end

 NEXUS_LV.FugaOn = false
NEXUS_LV.fugaList = function(targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady("Fuga") then return end

    local pos = NEXUS_LV.nearestPos(targets, myHRP)

    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, "Fuga", myModel, pos)
    end) end)

    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_Fuga",
            LocalCharacter = myModel,
            SkillID = "Fuga",
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.FugaOn or NEXUS_LV.SukunaOn then
            NexusQ(NexusListJob, NEXUS_LV.fugaList)
        end
        task.wait(LOOP_GAP)
    end
end)

NEXUS_LV.fireSkill = function(skillName, targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady(skillName) then return end

    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, skillName, myModel, pos)
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_" .. skillName,
            LocalCharacter = myModel,
            SkillID = skillName,
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end
function NexusRunSkill(name) NEXUS_LV.fireSkill(name, NEXUS_LV.collectTargets()) end
function NexusSkillJob(name) NexusBusyT = os.clock() pcall(NexusRunSkill, name) end
 NEXUS_LV.DismantleOn = false
 NEXUS_LV.WebSlamOn   = false
 NEXUS_LV.CleaveOn    = false
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.DismantleOn or NEXUS_LV.SukunaOn then NexusQ(NexusSkillJob, "Dismantle") end
        if NEXUS_LV.WebSlamOn   or NEXUS_LV.SukunaOn then NexusQ(NexusSkillJob, "WebSlam") end
        if NEXUS_LV.CleaveOn    or NEXUS_LV.SukunaOn then NexusQ(NexusSkillJob, "Cleave") end
        task.wait(NexusGap())
    end
end)

local hakari = { s1 = false, s2 = false, s3 = false, s4 = false }
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if hakari.s1 or NEXUS_LV.HakariOn then NexusQ(NexusSkillJob, "GamblerSkill1") end
        if hakari.s2 or NEXUS_LV.HakariOn then NexusQ(NexusSkillJob, "GamblerSkill2") end
        if hakari.s3 or NEXUS_LV.HakariOn then NexusQ(NexusSkillJob, "GamblerSkill3") end
        if hakari.s4 or NEXUS_LV.HakariOn then NexusQ(NexusSkillJob, "GamblerSkill4") end
        task.wait(NexusGap())
    end
end)

NEXUS_LV.fireBlue = function(targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady("Blue") then return end
    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, "Blue", myModel, pos, nil, {})
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_Blue",
            LocalCharacter = myModel,
            SkillID = "Blue",
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end

 NEXUS_LV.LimitlessOn = false
local limitless = { red = false, blue = false, blue2 = false, purple = false }
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if limitless.red    or NEXUS_LV.LimitlessOn then NexusQ(NexusSkillJob, "Red") end
        if limitless.blue   or NEXUS_LV.LimitlessOn then NexusQ(NexusListJob, NEXUS_LV.fireBlue) end
        if limitless.blue2  or NEXUS_LV.LimitlessOn then NexusQ(NexusSkillJob, "Blue2") end
        if limitless.purple or NEXUS_LV.LimitlessOn then NexusQ(NexusSkillJob, "HollowPurple") end
        task.wait(NexusGap())
    end
end)

-- Awakened Limitless casts through StartSkilll_Method with FIVE arguments:
--   1 skillId, 2 my character, 3 RELATIVE offset vector (target - self, Y ~= 0),
--   4 an empty table, 5 the target list.
-- The generic fireSkill only sent 3 args and an ABSOLUTE position, so the
-- server silently ignored every cast. Confirmed from a live remote capture.
function fireAwkLimitless(skillName, targets, myModel, myHRP)
    if not myModel or not myHRP or not targets or #targets == 0 then return end
    if not skillReady(skillName) then return end

    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    if not pos then return end
    local off = pos - myHRP.Position
    local dir = Vector3.new(off.X, 0.0001, off.Z)

    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, skillName, myModel, dir, {}, targets)
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_" .. skillName,
            LocalCharacter = myModel,
            SkillID = skillName,
        })
    end) end)
end

 NEXUS_LV.AwkLimitlessOn = false
-- Awakened Limitless kit (verified live against CombatConfig.SkillData).
-- "AwakenedLimitlessAwakening" is deliberately excluded: it is the awakening
-- trigger and has no cooldown, so spamming it would fight the awakened state.
NEXUS_AWK_LIMITLESS_MOVES = {
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
NEXUS_AWK_LIMITLESS_STEP = 3
NEXUS_AWK_LIMITLESS_I    = 0
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.AwkLimitlessOn then
            local n = #NEXUS_AWK_LIMITLESS_MOVES
            if n > 0 then
                local step = NEXUS_AWK_LIMITLESS_STEP
                if step > n then step = n end
                for _ = 1, step do
                    NEXUS_AWK_LIMITLESS_I = (NEXUS_AWK_LIMITLESS_I % n) + 1
                    NexusQ(NexusNamedJob, fireAwkLimitless, NEXUS_AWK_LIMITLESS_MOVES[NEXUS_AWK_LIMITLESS_I])
                end
            end
        end
        task.wait(NexusGap())
    end
end)

 NEXUS_LV.FastInfAuraOn = false
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.FastInfAuraOn then NexusQ(NexusSkillJob, "InfinityAuraSkill1") end
        task.wait(NexusGap())
    end
end)

NexusSMOn     = false
NexusSMVec    = vector.create(-15.395651817321777, 0.00009999999747378752, -2.1383278369903564)

NEXUS_SM_RANGE = 500

function NexusSMModel()
    local m = NexusOwnServerModel()
    if m and m.Parent then return m end
    local ok, r = pcall(function()
        local f = workspace:WaitForChild("Characters"):WaitForChild("Server"):WaitForChild("Players")
        local lc = NexusLocalChar()
        local sm = lc and lc.ServerModel
        if typeof(sm) == "Instance" and sm.Parent == f then return sm end
        return nil
    end)
    if ok then return r end
    return nil
end

function NexusSMAim(model)
    local targets, myModel, myHRP = NEXUS_LV.collectTargets()
    local origin = (myHRP and myHRP.Position)
        or (model and model.PrimaryPart and model.PrimaryPart.Position)
    if not origin then return nil end
    local best, bd
    for _, m in ipairs(targets or {}) do
        local h = m and m:FindFirstChild("HumanoidRootPart")
        if h then
            local d = (h.Position - origin).Magnitude
            if d <= NEXUS_SM_RANGE and (not bd or d < bd) then best, bd = h.Position, d end
        end
    end
    local dir
    if best then
        dir = (best - origin) * Vector3.new(1, 0, 1)
    elseif model and model.PrimaryPart then
        dir = model.PrimaryPart.CFrame.LookVector * Vector3.new(1, 0, 1)
    end
    if not dir or dir.Magnitude < 0.001 then return nil end
    return dir + Vector3.new(1e-4, 1e-4, 1e-4), targets, myModel, myHRP
end

function NexusSMFire()
    local model = NexusSMModel()
    if not model then return end
    local dir, targets, myModel, myHRP = NexusSMAim(model)
    if not dir then dir = NexusSMVec end
    NexusGatedInvoke(StartSkill, "ShrineSlash", model, dir, {})

    if targets and #targets > 0 and myModel and myHRP then
        task.spawn(function() pcall(function()
            NexusGatedInvoke(DamageCharacter, targets, true, {
                WindowID = myModel.Name .. "_ShrineSlash",
                LocalCharacter = myModel,
                SkillID = "ShrineSlash",
                CanParry = true,
                Origin = myHRP.CFrame,
            })
        end) end)
    end
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusSMOn then task.spawn(function() pcall(NexusSMFire) end) end
        task.wait(NexusGap())
    end
end)

local CopyOn = false
local copy = { y1=false, y2=false, y3=false, y4=false, rbasic=false, rcrit=false, r1=false, r2=false, r3=false, r4=false }
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if copy.y1     or CopyOn then NexusQ(NexusSkillJob, "YutaSkill1") end
        if copy.y2     or CopyOn then NexusQ(NexusSkillJob, "YutaSkill2") end
        if copy.y3     or CopyOn then NexusQ(NexusSkillJob, "YutaSkill3") end
        if copy.y4     or CopyOn then NexusQ(NexusSkillJob, "YutaSkill4") end
        if copy.rbasic or CopyOn then NexusQ(NexusSkillJob, "RikaBasic") end
        if copy.rcrit  or CopyOn then NexusQ(NexusSkillJob, "RikaCrit") end
        if copy.r1     or CopyOn then NexusQ(NexusSkillJob, "RikaSkill1") end
        if copy.r2     or CopyOn then NexusQ(NexusSkillJob, "RikaSkill2") end
        if copy.r3     or CopyOn then NexusQ(NexusSkillJob, "RikaSkill3") end
        if copy.r4     or CopyOn then NexusQ(NexusSkillJob, "RikaSkill4") end
        task.wait(NexusGap())
    end
end)

local BloodOn = false
local blood = { s1 = false, s2 = false, s3 = false, s4 = false, s5 = false, domain = false }

NEXUS_LV.fireBloodSkill1 = function(targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady("AwakenedBloodMSkill1") then return end
    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, "AwakenedBloodMSkill1", myModel, pos, nil, {})
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_AwakenedBloodMSkill1",
            LocalCharacter = myModel,
            SkillID = "AwakenedBloodMSkill1",
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end

NEXUS_LV.fireBloodDomain = function(targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady("AwakenedBloodMDomain") then return end
    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, "AwakenedBloodMDomain", myModel, pos, nil, pos)
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_AwakenedBloodMDomain",
            LocalCharacter = myModel,
            SkillID = "AwakenedBloodMDomain",
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if blood.s1 or BloodOn then NexusQ(NexusListJob, NEXUS_LV.fireBloodSkill1) end
        if blood.s2 or BloodOn then NexusQ(NexusNamedJob, fireSkill5, "AwakenedBloodMSkill2") end
        if blood.s3 or BloodOn then NexusQ(NexusSkillJob, "AwakenedBloodMSkill3") end
        if blood.s4 or BloodOn then NexusQ(NexusNamedJob, fireSkill5, "AwakenedBloodMSkill4") end
        if blood.s5 or BloodOn then NexusQ(NexusSkillJob, "AwakenedBloodMSkill5") end
        if blood.domain or BloodOn then NexusQ(NexusListJob, NEXUS_LV.fireBloodDomain) end
        task.wait(NexusGap())
    end
end)

local function fireSkill5(skillName, targets, myModel, myHRP)
    if not myModel or not myHRP or #targets == 0 then return end
    if not skillReady(skillName) then return end
    local pos = NEXUS_LV.nearestPos(targets, myHRP)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(StartSkill, skillName, myModel, pos, nil, {})
    end) end)
    task.spawn(function() pcall(function()
        NexusGatedInvoke(DamageCharacter, targets, true, {
            WindowID = myModel.Name .. "_" .. skillName,
            LocalCharacter = myModel,
            SkillID = skillName,
            CanParry = true,
            Origin = myHRP.CFrame,
        })
    end) end)
end
local StarRageOn = false
local starrage = { s1 = false, s2 = false, s3 = false, s4 = false, s5 = false }
 NEXUS_LV.ProjectionOn = false
local projection = { s1 = false, s2 = false, s3 = false, s4 = false }
local BeastAmberOn = false
local beast = { tf = false, s1 = false, s2 = false, s3 = false, s4 = false }
 NEXUS_LV.LarpOn = false
local larp = { s1 = false, s2 = false, s3 = false, ult = false }
 NEXUS_LV.JudgemanOn = false
local judge = { s1 = false, s2 = false, s3 = false, s4 = false }
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do

        if starrage.s1 or StarRageOn then NexusQ(NexusSkillJob, "AwakenedStarRageSkill1") end
        if starrage.s2 or StarRageOn then NexusQ(NexusSkillJob, "AwakenedStarRageSkill2") end
        if starrage.s3 or StarRageOn then NexusQ(NexusNamedJob, fireSkill5, "AwakenedStarRageSkill3") end
        if starrage.s4 or StarRageOn then NexusQ(NexusNamedJob, fireSkill5, "AwakenedStarRageSkill4") end
        if starrage.s5 or StarRageOn then NexusQ(NexusNamedJob, fireSkill5, "AwakenedStarRageSkill5") end

        if projection.s1 or NEXUS_LV.ProjectionOn then NexusQ(NexusSkillJob, "ProjectionSkill1") end
        if projection.s2 or NEXUS_LV.ProjectionOn then NexusQ(NexusSkillJob, "ProjectionSkill2") end
        if projection.s3 or NEXUS_LV.ProjectionOn then NexusQ(NexusSkillJob, "ProjectionSkill3") end
        if projection.s4 or NEXUS_LV.ProjectionOn then NexusQ(NexusSkillJob, "ProjectionSkill4") end

        if beast.tf or BeastAmberOn then NexusQ(NexusSkillJob, "BeastAmberTransform") end
        if beast.s1 or BeastAmberOn then NexusQ(NexusSkillJob, "BeastAmberSkill1") end
        if beast.s2 or BeastAmberOn then NexusQ(NexusSkillJob, "BeastAmberSkill2") end
        if beast.s3 or BeastAmberOn then NexusQ(NexusSkillJob, "BeastAmberSkill3") end
        if beast.s4 or BeastAmberOn then NexusQ(NexusSkillJob, "BeastAmberSkill4") end

        if larp.s1 or NEXUS_LV.LarpOn then NexusQ(NexusSkillJob, "LarpSkill1") end
        if larp.s2 or NEXUS_LV.LarpOn then NexusQ(NexusSkillJob, "LarpSkill2") end
        if larp.s3 or NEXUS_LV.LarpOn then NexusQ(NexusSkillJob, "LarpSkill3") end
        if larp.ult or NEXUS_LV.LarpOn then NexusQ(NexusSkillJob, "LarpUlt") end

        if judge.s1 or NEXUS_LV.JudgemanOn then NexusQ(NexusSkillJob, "JudgemanSkill1") end
        if judge.s2 or NEXUS_LV.JudgemanOn then NexusQ(NexusSkillJob, "JudgemanSkill2") end
        if judge.s3 or NEXUS_LV.JudgemanOn then NexusQ(NexusSkillJob, "JudgemanSkill3") end
        if judge.s4 or NEXUS_LV.JudgemanOn then NexusQ(NexusSkillJob, "JudgemanSkill4") end
        task.wait(NexusGap())
    end
end)

TenShadowsOn = false
tenshadow = {
    ts1=false, bun1=false, bun2=false,
    ts2=false, shi1=false, shi2=false,
    ts3=false, kur2=false, kur1e=false, kur2e=false,
    ts4=false, nue2=false, nue3=false, nue1=false,
    ts5=false, mah3=false, mah1=false, mah5e=false, mah2=false,
    ts6=false, ele1=false, ele2=false, ele3=false,
}

function fireSummon(skillName)
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    if not skillReady(skillName) then return end
    pcall(function()
        NexusGatedInvoke(StartSkill, skillName, myModel, myHRP.Position)
    end)
end
function NexusSummonJob(name) NexusBusyT = os.clock() pcall(fireSummon, name) end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do

        if tenshadow.ts1 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill1") end
        if tenshadow.ts2 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill2") end
        if tenshadow.ts3 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill3") end
        if tenshadow.ts4 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill4") end
        if tenshadow.ts5 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill5") end
        if tenshadow.ts6 or TenShadowsOn then NexusQ(NexusSummonJob, "TenShadowsSkill6") end

        if tenshadow.bun1 or TenShadowsOn then NexusQ(NexusSkillJob, "BunnySkill1") end
        if tenshadow.bun2 or TenShadowsOn then NexusQ(NexusSkillJob, "BunnySkill2") end

        if tenshadow.shi1 or TenShadowsOn then NexusQ(NexusSkillJob, "ShiroSkill1") end
        if tenshadow.shi2 or TenShadowsOn then NexusQ(NexusSkillJob, "ShiroSkill2Enhanced") end

        if tenshadow.kur2 or TenShadowsOn then NexusQ(NexusSkillJob, "KuroSkill2") end
        if tenshadow.kur1e or TenShadowsOn then NexusQ(NexusSkillJob, "KuroSkill1Enhanced") end
        if tenshadow.kur2e or TenShadowsOn then NexusQ(NexusSkillJob, "KuroSkill2Enhanced") end

        if tenshadow.nue2 or TenShadowsOn then NexusQ(NexusSkillJob, "NueSkill2") end
        if tenshadow.nue3 or TenShadowsOn then NexusQ(NexusNamedJob, fireSkill5, "NueSkill3") end
        if tenshadow.nue1 or TenShadowsOn then NexusQ(NexusNamedJob, fireSkill5, "NueSkill1") end

        if tenshadow.mah3 or TenShadowsOn then NexusQ(NexusSkillJob, "MahoragaSkill3") end
        if tenshadow.mah1 or TenShadowsOn then NexusQ(NexusSkillJob, "MahoragaSkill1") end
        if tenshadow.mah5e or TenShadowsOn then NexusQ(NexusNamedJob, fireSkill5, "MahoragaSkill5Enhanced") end
        if tenshadow.mah2 or TenShadowsOn then NexusQ(NexusNamedJob, fireSkill5, "MahoragaSkill2") end

        if tenshadow.ele1 or TenShadowsOn then NexusQ(NexusSkillJob, "MaxElephantSkill1") end
        if tenshadow.ele2 or TenShadowsOn then NexusQ(NexusSkillJob, "MaxElephantSkill2") end
        if tenshadow.ele3 or TenShadowsOn then NexusQ(NexusSkillJob, "MaxElephantSkill3") end
        task.wait(NexusGap())
    end
end)

 NEXUS_LV.QuickShapeOn = false
 NEXUS_LV.FocusItem = Net.InventoryService.FocusItem_Method
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.QuickShapeOn then
            pcall(function() NEXUS_LV.FocusItem:InvokeServer(1) end)
            task.wait(0.5)
            if NEXUS_LV.QuickShapeOn and NEXUSG.NexusPlayHubSession == SESSION then
                pcall(function() NEXUS_LV.FocusItem:InvokeServer(2) end)
            end
            task.wait(0.5)
        else
            task.wait(0.1)
        end
    end
end)

AutoSlotSel     = 0
NexusSlotToggles = {}
NexusSlotBusy    = false
NEXUS_SLOT_GAP   = 0.3

function NexusFocusSlot(slot)
    pcall(function()
        local args = { slot }
        RepStorage:WaitForChild("NetworkComm"):WaitForChild("InventoryService"):WaitForChild("FocusItem_Method"):InvokeServer(unpack(args))
    end)
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        local slot = tonumber(AutoSlotSel) or 0
        if NexusSWBusy or NexusSWHold then
            task.wait(0.1)
        elseif slot > 0 then
            NexusFocusSlot(slot)
            task.wait(NEXUS_SLOT_GAP)
        else
            task.wait(0.4)
        end
    end
end)

function NexusAddSlotSwitch(section, slot)
    local key = "AutoSlot" .. tostring(slot)
    local v = S(key, false)
    if v and AutoSlotSel == 0 then
        AutoSlotSel = slot
    elseif v then
        v = false
        Settings[key] = false
    end
    NexusSlotToggles[slot] = section:CreateToggle({
        Name = "Auto Equip Slot " .. tostring(slot),
        CurrentValue = v,
        Callback = function(on)
            if NexusSlotBusy then return end
            if on then
                NexusSlotBusy = true
                for s2, o2 in pairs(NexusSlotToggles) do
                    if s2 ~= slot then
                        pcall(function() o2:Set(false) end)
                        Settings["AutoSlot" .. tostring(s2)] = false
                    end
                end
                NexusSlotBusy = false
                AutoSlotSel = slot
            elseif AutoSlotSel == slot then
                AutoSlotSel = 0
            end
            Settings[key] = on
            saveSettings()
        end,
    }, "NEXUS_" .. key)
end

AutoSlot1On = false
AutoSlot2On = false

NexusSWSMOn   = false
NexusSWBusy   = false
NEXUS_SW_HOLD = 0.55
NexusSWFillOn = false
NexusSWHold   = false
NexusSWBack   = 0

NexusSWInvMemo = NexusSWInvMemo or { c = nil, t = -1 }
function NexusSWInv()
    local m = NexusSWInvMemo
    if m.c then return m.c end
    if os.clock() - m.t < 2 then return nil end
    m.t = os.clock()
    pcall(function() m.c = require(LocalPlayer.PlayerScripts.Client.Controllers.InventoryController) end)
    return m.c
end

NexusSWSlots = NexusSWSlots or { t = -1, mark = 0, focused = 0 }
function NexusSWScan()
    local s = NexusSWSlots
    local now = os.clock()
    if now - s.t < 0.5 then return s.mark, s.focused end
    s.t = now
    local mark, focused = 0, 0
    pcall(function()
        local ic = NexusSWInv()
        local ci = ic and ic.CurrentInventory
        if not ci then return end
        local eq  = ci.EquippedItems
        local fid = ci.FocusedItem
        for i = 1, 5 do
            local id = eq and eq[i]
            if id then
                if fid == id then focused = i end
                if mark == 0 then
                    local it = ci:GetItem(id)
                    if it and tostring(it.ConfigID) == "SukunaPassive" then mark = i end
                end
            end
        end
    end)
    s.mark, s.focused = mark, focused
    return mark, focused
end

function NexusSWReady()
    local ok, ready = pcall(function()
        local lc = NexusLocalChar()
        local cs = lc and lc.CharacterStates
        if not cs then return false end
        if (tonumber(cs.SukunaPassivePowerUpPercent) or 0) < 100 then return false end
        local cd = cs.Cooldowns and cs.Cooldowns["ShrineSlash"]
        if cd == nil then return true end
        if type(cd) == "table" then
            return (tonumber(cd.TimeElapsed) or 0) >= (tonumber(cd.Duration) or 0)
        end
        return false
    end)
    return (ok and ready) and true or false
end

function NexusSWRelease()
    local back = NexusSWBack
    NexusSWBack = 0
    NexusSWHold = false
    if back > 0 then pcall(NexusFocusSlot, back) end
    NexusSWSlots.t = -1
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if not NexusSWSMOn then
            if NexusSWHold then NexusSWRelease() end
            task.wait(0.5)
        elseif not NexusSWReady() then

            if NexusSWFillOn then
                local mark, cur = NexusSWScan()
                if mark > 0 and cur ~= mark then
                    if not NexusSWHold then
                        NexusSWBack = (cur > 0 and cur) or (tonumber(AutoSlotSel) or 0)
                    end
                    NexusSWHold = true
                    pcall(NexusFocusSlot, mark)
                    NexusSWSlots.t = -1
                end
            elseif NexusSWHold then
                NexusSWRelease()
            end
            task.wait(0.25)
        else
            local mark, cur = NexusSWScan()
            if mark == 0 then
                task.wait(1)
            else
                local back = NexusSWBack
                if back == 0 then back = (cur > 0 and cur) or (tonumber(AutoSlotSel) or 0) end
                NexusSWBusy = true
                pcall(function()
                    if cur ~= mark then
                        pcall(NexusFocusSlot, mark)
                        task.wait(0.12)
                    end
                    pcall(NexusSMFire)
                    task.wait(NEXUS_SW_HOLD)
                    if back > 0 and back ~= mark then pcall(NexusFocusSlot, back) end
                end)
                NexusSWBack = 0
                NexusSWHold = false
                NexusSWSlots.t = -1
                NexusSWBusy = false
                NexusBusyT  = os.clock()
                task.wait(0.3)
            end
        end
    end
end)

local function auraGoal(nh)
    local base = nh.Position
    local off
    if NEXUS_LV.AURA_MODE == "Top" then
        off = Vector3.new(0, STICK_OFFSET, 0)
    elseif NEXUS_LV.AURA_MODE == "Bottom" then
        off = Vector3.new(0, -STICK_OFFSET, 0)
    elseif NEXUS_LV.AURA_MODE == "Back" then

        local lv = nh.CFrame.LookVector
        local flatLv = Vector3.new(lv.X, 0, lv.Z)
        if flatLv.Magnitude < 0.01 then flatLv = Vector3.new(0, 0, 1) else flatLv = flatLv.Unit end
        off = flatLv * -STICK_OFFSET
    else
        off = nh.CFrame.LookVector * STICK_OFFSET
    end
    local pos = base + off + Vector3.new(OX, OY, OZ)

    local flat = Vector3.new(base.X, pos.Y, base.Z)
    if (flat - pos).Magnitude < 0.1 then
        return CFrame.new(pos)
    end
    return CFrame.new(pos, flat)
end

 NEXUS_LV.BringOn = false

 NEXUS_LV.killAuraTarget, NEXUS_LV.killAuraHRP = nil, nil
CONNS[#CONNS+1] = RunService.Heartbeat:Connect(function(dt)
    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
    if not NEXUS_LV.KillOn then return end
    if anyBringActive() then return end
    if NEXUS_LV.essenceBusy or NEXUS_LV.crateBusy then return end
    local n, hrp = NEXUS_LV.killAuraTarget, NEXUS_LV.killAuraHRP
    if not (n and n.Parent and hrp and hrp.Parent) then return end
    local nh = n:FindFirstChild("HumanoidRootPart")
    if not nh then return end
    local goal = auraGoal(nh)
    pcall(function()

        if (hrp.Position - goal.Position).Magnitude > STICK_OFFSET + 3 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = goal
        end
    end)
end)

 NEXUS_LV.killBFtick = 0
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do

        if NEXUS_LV.KillOn and not (anyBringActive and anyBringActive()) then
            local n, mm, hrp = NEXUS_LV.getNearest(NEXUS_LV.AURA_RANGE)
            NEXUS_LV.killAuraTarget, NEXUS_LV.killAuraHRP = n, hrp
            if n and hrp then
                NEXUS_LV.killBFtick = NEXUS_LV.killBFtick + 1
                if NEXUS_LV.killBFtick % 2 == 0 then
                    enableBlackFlash()
                    NexusQ(pcall, blackFlashList, {n}, mm, hrp)
                else
                    NexusQ(pcall, attackList, {n}, mm, hrp)
                end
            end
        else
            NEXUS_LV.killAuraTarget, NEXUS_LV.killAuraHRP = nil, nil
        end
        task.wait(math.max(0.02, LOOP_GAP * 0.6))
    end
end)

NEXUS_BRING_T = NEXUS_BRING_T or {}
NEXUS_BRING_FLY = NEXUS_BRING_FLY or {}
NEXUS_BRING_COMBO = 1
NEXUS_BRING_TICK = 0
function NexusBringLane(key, gap)
    local now = os.clock()
    local fly = NEXUS_BRING_FLY[key]
    if fly and (now - fly) < NEXUS_FLY_TTL then return false end
    local last = NEXUS_BRING_T[key]
    if last and (now - last) < (gap or DMG_GAP) then return false end
    NEXUS_BRING_T[key] = now
    return true
end

function NexusBringPlace(h, goal)
    if not (h and h.Parent) then return end
    local dx, dy, dz = h.Position.X - goal.X, h.Position.Y - goal.Y, h.Position.Z - goal.Z
    if (dx * dx + dy * dy + dz * dz) > 0.25 then
        pcall(function()
            h.AssemblyLinearVelocity = Vector3.zero
            h.CFrame = CFrame.new(goal)
        end)
    end
end

function NexusBringPump(targets, myModel, myHRP, bfSkill)
    if type(targets) ~= "table" or not myModel or not myHRP then return end
    targets = nexusFilterPets(targets)
    local n = #targets
    if n == 0 then return end

    local live = {}
    for i = 1, n do
        local m = targets[i]
        if m and m.Parent then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then live[#live + 1] = m end
        end
    end
    n = #live
    if n == 0 then return end

    NEXUS_BRING_LAST, NEXUS_BRING_LAST_T = live, os.clock()
    NEXUS_BRING_MODEL, NEXUS_BRING_HRP = myModel, myHRP
    local first = live[1]:FindFirstChild("HumanoidRootPart")
    local dir = (first and (first.Position - myHRP.Position).Unit) or myHRP.CFrame.LookVector
    NEXUS_BRING_TICK = NEXUS_BRING_TICK + 1
    local bfTurn = (NEXUS_BRING_TICK % 2 == 0)

    if not bfTurn and NexusBringLane("startPunch", START_GAP) then
        NEXUS_BRING_FLY.startPunch = os.clock()
        local combo = NEXUS_BRING_COMBO
        NEXUS_BRING_COMBO = combo % 5 + 1
        task.spawn(function()
            pcall(function() NexusGatedInvoke(StartSkill, "Punch", myModel, dir, nil, combo, 1) end)
            NEXUS_BRING_FLY.startPunch = nil
        end)
    end

    if NexusBringLane("dmgPunch", DMG_GAP) then
        NEXUS_BRING_FLY.dmgPunch = os.clock()
        local org = myHRP.CFrame
        task.spawn(function()
            pcall(function()
                NexusGatedInvoke(DamageCharacter, live, true, {
                    WindowID = myModel.Name .. "_Punch",
                    LocalCharacter = myModel,
                    SkillID = "Punch",
                    CanParry = true,
                    Origin = org,
                })
            end)
            NEXUS_BRING_FLY.dmgPunch = nil
        end)
    end

    if bfTurn then
        bfSkill = bfSkill or "BlackFlashSkill1"
        NexusSetFlag("CanBlackFlash", true)
        NexusSetFlag("BlackFlashSkill", bfSkill)
        NexusQ(pcall, NexusBFCast, bfSkill, live, myModel, myHRP, true)
    end
end

local broughtOrigins = {}

NexusPruneRegister(function() return broughtOrigins end)
NEXUS_LV.restoreBrought = function()
    for m, cf in pairs(broughtOrigins) do
        if m and m.Parent then
            local h = m:FindFirstChild("HumanoidRootPart")
            if h then pcall(function() h.CFrame = cf end) end
        end
    end
    broughtOrigins = {}
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.BringOn then
            local targets, mm, hrp = NEXUS_LV.collectTargets(NEXUS_LV.BRING_RANGE)
            if hrp and #targets > 0 then
                for i, m in ipairs(targets) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then
                        if not broughtOrigins[m] then broughtOrigins[m] = h.CFrame end
                        local angle = (i / #targets) * math.pi * 2
                        local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 0, math.sin(angle) * BRING_OFFSET)
                        pcall(function()
                            local goal = hrp.Position + off

                            local dx, dy, dz = h.Position.X - goal.X, h.Position.Y - goal.Y, h.Position.Z - goal.Z
                            if (dx * dx + dy * dy + dz * dz) > 0.25 then
                                h.AssemblyLinearVelocity = Vector3.zero
                                h.CFrame = CFrame.new(goal)
                            end
                        end)
                    end
                end
                NexusQ(NexusBringPump, targets, mm, hrp)
            end
        end
        task.wait(LOOP_GAP)
    end
end)

 NEXUS_LV.BringAllOn = false
NEXUS_LV.collectAllNPCs = function()
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not myHRP or not NPCsF then return {}, nil, nil end
    local targets = {}
    for _, m in ipairs(NPCsF:GetChildren()) do
        if m ~= myModel and not isPunchingBag(m) then
            local h, hum = nexusRig(m)
            if h and hum and hum.Health > 0 and onMyIsland(h.Position) then
                table.insert(targets, m)
            end
        end
    end
    return targets, myModel, myHRP
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.BringAllOn then
            local targets, mm, hrp = NEXUS_LV.collectAllNPCs()
            if hrp and #targets > 0 then
                for i, m in ipairs(targets) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then
                        if not broughtOrigins[m] then broughtOrigins[m] = h.CFrame end
                        local angle = (i / #targets) * math.pi * 2
                        local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 0, math.sin(angle) * BRING_OFFSET)
                        pcall(function()
                            local goal = hrp.Position + off

                            local dx, dy, dz = h.Position.X - goal.X, h.Position.Y - goal.Y, h.Position.Z - goal.Z
                            if (dx * dx + dy * dy + dz * dz) > 0.25 then
                                h.AssemblyLinearVelocity = Vector3.zero
                                h.CFrame = CFrame.new(goal)
                            end
                        end)
                    end
                end
                NexusQ(NexusBringPump, targets, mm, hrp)
            end
        end
        task.wait(LOOP_GAP)
    end
end)

 NEXUS_LV.ReachOn = false

local reachTargets, reachHRP = {}, nil
CONNS[#CONNS+1] = RunService.Heartbeat:Connect(function(dt)
    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
    if not NEXUS_LV.ReachOn then return end
    local hrp = reachHRP
    if not (hrp and hrp.Parent) then return end
    local far, fd
    for _, m in ipairs(reachTargets) do
        if m.Parent then
            local h = m:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (h.Position - hrp.Position).Magnitude
                if d > 12 and (not fd or d < fd) then far, fd = h, d end
            end
        end
    end
    if far then
        local goal = auraGoal(far)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = goal
        end)
    end
end)
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.ReachOn then
            local targets, mm, hrp = NEXUS_LV.collectAllNPCs()
            reachTargets, reachHRP = targets or {}, hrp
            if hrp and #targets > 0 then
                NexusQ(pcall, attackList, targets, mm, hrp)
            end
        else
            reachTargets, reachHRP = {}, nil
        end
        task.wait(math.max(0.02, LOOP_GAP * 0.6))
    end
end)

local flying = false
local bv, bg

local QuestOn = false

QuestScanCache = QuestScanCache or {
    nameT = -1, fullT = -1, name = "", lbl = nil,
    posT = -1, posKey = nil, pos = {},
    npcT = -1, a = nil, b = nil, c = nil,
}
function questParseName(txt)
    local nm = string.match(txt, "([%a%s]+)%s*%(%d+/%d+%)")
    if not nm or #nm <= 2 then return nil end
    nm = nm:gsub("^%s+", ""):gsub("%s+$", "")
    nm = nm:gsub("^[Dd]efeat%s+the%s+", ""):gsub("^[Dd]efeat%s+", ""):gsub("^[Kk]ill%s+", ""):gsub("^[Cc]ollect%s+", "")
    nm = nm:gsub("s$", "")
    return nm
end

NexusQMods = NexusQMods or { t = -1 }
function NexusQuestMods()
    local m, now = NexusQMods, os.clock()
    if m.ok and (now - m.t) < 5 then return m end
    m.t = now
    local Ctrl = LocalPlayer:FindFirstChild("PlayerScripts")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Client")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Controllers")
    if not Ctrl then return m end
    pcall(function() m.QC = require(Ctrl.QuestController) end)
    pcall(function() m.QCfg = require(RepStorage.Configs.QuestConfig) end)
    pcall(function() m.NPCc = require(RepStorage.Configs.NPCConfig) end)
    pcall(function() m.Interact = require(Ctrl.InterfaceController.Interfaces.Interact) end)

    pcall(function() m.AIC = require(Ctrl.AIController) end)
    m.ok = (m.QC ~= nil and m.QCfg ~= nil)
    return m
end

NexusQInfo = NexusQInfo or { t = -1, id = nil, kind = "", name = "" }
function NexusQuestInfo()
    local q, now = NexusQInfo, os.clock()
    if (now - q.t) < 0.5 then return q end
    q.t = now
    local m = NexusQuestMods()
    if not m.ok then q.id, q.kind, q.name = nil, "", "" return q end
    local id
    pcall(function() id = m.QC:GetActiveQuest() end)

    if not id then id = NexusRctQuestId() or currentQuestId() end
    q.id = id
    local cfg = id and m.QCfg.Quests and m.QCfg.Quests[id]
    if not cfg then q.kind, q.name = "", "" return q end
    local ty = cfg.Type
    if ty == "Fetch" or ty == "NewFetch" then
        q.kind, q.name = "Fetch", ""
    elseif ty == "Enemies" then
        local eid = cfg.EnemyID
        pcall(function()
            local s = m.QC:GetSavedQuest(id)
            if s and s.EnemyID then eid = s.EnemyID end
        end)
        local e = eid and m.NPCc and m.NPCc.NPCs and m.NPCc.NPCs[eid]
        q.kind, q.name = "Enemies", (e and e.Name) or ""
    else
        q.kind, q.name = tostring(ty), ""
    end
    return q
end

NexusSkipCap = NexusSkipCap or false
NexusCapI = NexusCapI or { t = -1 }
function NexusCapInfo()
    local c, now = NexusCapI, os.clock()
    if (now - c.t) < 0.3 then return c end
    c.t = now
    c.on, c.pos, c.rad, c.need, c.pts, c.done = false, nil, 0, 0, 0, false
    local m = NexusQuestMods()
    if not m.ok then return c end
    local id
    pcall(function() id = m.QC:GetActiveQuest() end)
    if not id then id = NexusRctQuestId() or currentQuestId() end
    local cfg = id and m.QCfg.Quests and m.QCfg.Quests[id]
    if not cfg or cfg.Type ~= "Capture" then c.names = nil return c end
    c.on, c.id = true, id
    c.need = tonumber(cfg.PointRequirement) or 0
    local saved
    pcall(function() saved = m.QC:GetSavedQuest(id) end)
    c.pts  = (saved and tonumber(saved.Points)) or 0
    c.done = (c.need > 0 and c.pts >= c.need)
    local capId = (saved and saved.CaptureID) or cfg.CaptureID
    if capId then
        local area
        pcall(function()
            area = workspace.Container.QuestAreas.Capture:FindFirstChild(capId)
        end)
        if area then
            local pp = area.PrimaryPart or area:FindFirstChildWhichIsA("BasePart")
            if pp then c.pos, c.rad = pp.Position, pp.Size.X * 0.45 end
        end
    end
    local names, seen = {}, {}
    local function add(eid)
        local e = eid and m.NPCc and m.NPCc.NPCs and m.NPCc.NPCs[eid]
        local nm = e and e.Name and string.lower(e.Name)

        if nm then nm = string.match(nm, "^%s*(.-)%s*$") end
        if nm and nm ~= "" and not seen[nm] then seen[nm] = true names[#names + 1] = nm end
    end
    if type(cfg.EnemyIDs) == "table" then for _, eid in pairs(cfg.EnemyIDs) do add(eid) end end
    add(cfg.EnemyID)
    if saved then add(saved.EnemyID) end
    c.names = names
    return c
end

NEXUS_CAP_DRIFT = 0.45
NEXUS_CAP_LEASH = 0.75
NEXUS_CAP_LIFT  = 6
NEXUS_CAP_TICK  = 0.2

function NexusCapPoint()
    local c = NexusCapInfo()
    if not c.on or c.done then return nil end
    if not c.pos or (c.rad or 0) <= 0 then return nil end
    return c.pos, c.rad
end

function NexusCapKeepInside(hrp, slack)
    if not hrp then return false end
    local pos, rad = NexusCapPoint()
    if not pos then return false end

    if NexusCapPhase == "gather" then return false end

    if NexusCapPhase == "roam" then return false end
    local d = hrp.Position - pos
    local flat = Vector3.new(d.X, 0, d.Z).Magnitude
    if flat <= rad * (slack or NEXUS_CAP_DRIFT) and math.abs(d.Y) <= rad * 0.5 then
        return false
    end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, NEXUS_CAP_LIFT, 0))
    end)
    return true
end

NEXUS_LV.questTarget = function()
    if NEXUS_LV.QUEST_TARGET ~= "" then return NEXUS_LV.QUEST_TARGET end
    local cap = NexusCapInfo()
    if cap.on then return (cap.names and cap.names[1]) or "" end
    local qi = NexusQuestInfo()
    if qi.name ~= "" then return qi.name end
    if qi.kind == "Fetch" then return "" end
    local qc, now = QuestScanCache, os.clock()
    if (now - qc.nameT) < 0.2 then return qc.name end
    local lbl = qc.lbl
    if lbl and lbl.Parent and (now - qc.fullT) < 1 then
        local nm = questParseName(lbl.Text)
        if nm then
            qc.name, qc.nameT = nm, now
            return nm
        end
    end
    qc.fullT, qc.nameT, qc.name, qc.lbl = now, now, "", nil
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d.ClassName == "TextLabel" then
                local nm = questParseName(d.Text)
                if nm then
                    qc.name, qc.lbl = nm, d
                    return nm
                end
            end
        end
    end
    return ""
end
NEXUS_LV.questTargetPositions = function()
    local qt = NEXUS_LV.questTarget()
    if qt == "" then return {} end

    local cap = NexusCapInfo()
    if cap.on and cap.names and #cap.names > 0 then
        local cc, cnow = QuestScanCache, os.clock()
        if cc.capT and (cnow - cc.capT) < CLIENT_SCAN_SEC then return cc.capP end
        local chits = {}
        local CF = workspace.Characters:FindFirstChild("Client")
        if CF then
            local nms, nn = cap.names, #cap.names
            for _, d in ipairs(clientLabels(CF)) do
                if d.ClassName == "TextLabel" then
                    local lt = string.lower(d.Text)
                    for i = 1, nn do
                        if string.find(lt, nms[i], 1, true) then
                            local rig = d:FindFirstAncestorWhichIsA("Model")
                            local h = rig and rig:FindFirstChild("HumanoidRootPart")
                            if h then chits[#chits + 1] = h.Position end
                            break
                        end
                    end
                end
            end
        end
        cc.capP, cc.capT = chits, cnow
        return chits
    end
    local qc, now = QuestScanCache, os.clock()
    if qc.posKey == qt and (now - qc.posT) < CLIENT_SCAN_SEC then return qc.pos end
    local hits = {}
    local ClientF = workspace.Characters:FindFirstChild("Client")
    if ClientF then
        local target = string.lower(qt)
        for _, d in ipairs(clientLabels(ClientF)) do
            if d.ClassName == "TextLabel" and string.find(string.lower(d.Text), target, 1, true) then
                local rig = d:FindFirstAncestorWhichIsA("Model")
                local hrp = rig and rig:FindFirstChild("HumanoidRootPart")
                if hrp then hits[#hits + 1] = hrp.Position end
            end
        end
    end
    qc.pos, qc.posKey, qc.posT = hits, qt, now
    return hits
end

function NexusAIQuestList()
    local out = {}
    local m = NexusQuestMods()
    local AIC = m and m.AIC
    if not AIC or type(AIC.ActiveAIs) ~= "table" then return out end
    local c = NexusCapInfo()
    local names = c and c.names
    if not names or #names == 0 then return out end
    for _, ai in pairs(AIC.ActiveAIs) do
        local st = ai and ai.AIStates
        local cfg = st and st.NPCConfig
        local nm = cfg and cfg.Name
        local hit = false
        if type(nm) == "string" then
            nm = string.lower(string.match(nm, "^%s*(.-)%s*$") or "")
            for i = 1, #names do
                if nm == names[i] or string.find(nm, names[i], 1, true) then hit = true break end
            end
        end
        if hit then
            local sm = ai.ServerModel or (ai.Character and ai.Character.ServerModel)
            local pp = sm and sm.Parent and sm.PrimaryPart
            if pp then out[#out + 1] = { sm = sm, pp = pp } end
        end
    end
    return out
end

function NexusAIBring(anchor)
    local m = NexusQuestMods()
    local AIC = m and m.AIC
    if not AIC or type(AIC.ActiveAIs) ~= "table" then return 0, 0 end
    local c = NexusCapInfo()
    local names = c and c.names
    if not names or #names == 0 then return 0, 0 end
    local capC, capR = NexusCapPoint()
    local center = capC or anchor
    if not center then return 0, 0 end
    local rad = capR or 30
    local list = NexusAIQuestList()
    local n = #list
    if n == 0 then return 0, 0 end
    local moved = 0
    for i = 1, n do
        local e = list[i]

        local d = e.pp.Position - center
        local settled = capC ~= nil
            and Vector3.new(d.X, 0, d.Z).Magnitude <= rad * 0.8
            and math.abs(d.Y) <= rad * 0.5
        if not settled then
            local angle = (i / n) * math.pi * 2
            local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 2, math.sin(angle) * BRING_OFFSET)
            pcall(function()
                e.sm:PivotTo(CFrame.new(center + off))
                e.pp.AssemblyLinearVelocity = Vector3.zero
            end)
            moved = moved + 1
        end
    end
    return n, moved
end

NEXUS_LV.collectQuestNPCs = function()
    local qc, now = QuestScanCache, os.clock()
    if qc.a and (now - qc.npcT) < TGT_CACHE_SEC and qc.c and qc.c.Parent then
        return qc.a, qc.b, qc.c
    end
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not myHRP or not NPCsF then return {}, nil, nil end
    if NEXUS_LV.questTarget() == "" then return {}, myModel, myHRP end
    local hits = NEXUS_LV.questTargetPositions()
    local targets = {}
    local nh = #hits
    if nh > 0 then
        for _, m in ipairs(NPCsF:GetChildren()) do
            if m ~= myModel then
                local h = m:FindFirstChild("HumanoidRootPart")
                if h then
                    local hp = h.Position
                    local near = false
                    for i = 1, nh do
                        local p = hits[i]
                        local dx, dy, dz = hp.X - p.X, hp.Y - p.Y, hp.Z - p.Z
                        if (dx * dx + dy * dy + dz * dz) < 100 then near = true break end
                    end
                    if near then
                        local hum = m:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 and onMyIsland(hp) and not isPunchingBag(m) then
                            targets[#targets + 1] = m
                        end
                    end
                end
            end
        end
    end
    qc.a, qc.b, qc.c, qc.npcT = targets, myModel, myHRP, now
    return targets, myModel, myHRP
end

 NEXUS_LV.FastQuestOn = false
local fastQuestBrought = {}

NexusPruneRegister(function() return fastQuestBrought end)
local fastQuestFrozenPos = nil

NexusLockPos = nil
NexusLockUntil = 0
NexusLockActive = false
function nexusLockAt(pos)
    NexusLockPos = pos
    NexusLockUntil = os.clock() + 0.5
    NexusLockActive = true
end
function nexusLockRelease()
    if not NexusLockActive then return end
    NexusLockActive = false
    NexusLockPos = nil
    pcall(function()
        local cur = getModel()
        local hum = cur and cur:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.UseJumpPower = true
            hum.JumpPower = 50
        end
    end)
end
CONNS[#CONNS+1] = RunService.Heartbeat:Connect(function()
    if NexusLockPos and os.clock() <= NexusLockUntil then
        pcall(function()
            local cur = getModel()
            local hrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(NexusLockPos)
            local hum = cur:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 0
                hum.UseJumpPower = true
                hum.JumpPower = 0
            end
        end)
    elseif NexusLockActive then
        nexusLockRelease()
    end
end)

AutoDagonBossOn = false
DAGON_BOSS_TAG = "dagon"
function findDagonBoss()
    return nexusNpcFromTags({ DAGON_BOSS_TAG })
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoDagonBossOn then
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then
                local boss = findDagonBoss()
                if boss then
                    local npcs = { boss }
                    local h = boss:FindFirstChild("HumanoidRootPart")
                    if h then

                        local tp = h.Position + Vector3.new(0, 0, 6)
                        pcall(function()
                            chrp.AssemblyLinearVelocity = Vector3.zero
                            chrp.CFrame = CFrame.new(tp)
                        end)
                        nexusLockAt(tp)
                    end

                    NexusQ(NexusBringPump, npcs, cur, chrp)
                    task.wait(BRING_GAP)
                else
                    task.wait(NEXUS_IDLE)
                end
            else
                task.wait(NEXUS_IDLE)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

NexusBossPick = { "Lv.Gojo" }
BossTabOn = false
function nexusBossWants()
    local wantGojo, wantDagon, wantRemnant = false, false, false
    local extras = {}
    if BossTabOn then
        for _, v in ipairs(NexusBossPick or {}) do
            local s = string.lower(tostring(v))
            if string.find(s, "gojo", 1, true) and not string.find(s, "sensei", 1, true) then wantGojo = true end
            if string.find(s, "dagon", 1, true) then wantDagon = true end
            if string.find(s, "curse remnant", 1, true) then wantRemnant = true end

            local tag = NEXUS_BOSS_STANDALONE and NEXUS_BOSS_STANDALONE[s]
            if tag then extras[#extras + 1] = tag end
        end
    end
    return wantGojo, wantDagon, wantRemnant, extras
end
function nexusApplyBossTab()
    local wantGojo, wantDagon, wantRemnant, extras = nexusBossWants()
    AutoGojoOn = wantGojo
    BringGojoOn = wantGojo
    AutoDagonBossOn = wantDagon
    BossRemnantOn = wantRemnant
    if nexusApplyBossExtras then nexusApplyBossExtras(extras) end
    NexusDropAnchor("remnant")
    if wantGojo then task.spawn(function() NexusSafeAccept("GojoInf3") end) end
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        local wantGojo, wantDagon, wantRemnant, extras = nexusBossWants()
        AutoGojoOn = wantGojo
        BringGojoOn = wantGojo
        AutoDagonBossOn = wantDagon
        BossRemnantOn = wantRemnant

        if nexusApplyBossExtras then nexusApplyBossExtras(extras) end
        task.wait(0.5)
    end
end)

AutoLumenConvertOn = false
LumenConvertAmount = 1000000
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoLumenConvertOn then
            pcall(function()
                local args = { LumenConvertAmount }
                RepStorage:WaitForChild("NetworkComm"):WaitForChild("PlayerService"):WaitForChild("LumenConvert_Method"):InvokeServer(unpack(args))
            end)
            task.wait(0.5)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

SHADOW_ISLAND_POS = Vector3.new(-1846.26, 169.25, -20722.9)
SHIKI_POS = Vector3.new(-2344.97, 375.01, -20950.63)
AutoShikigamiOn = false
NEXUS_SHIKI_GAP = 0.5
AutoKillShikigamiOn = false
ShadowAltarCount = 0
ShadowPick = { "all" }

function nexusWordsOf(label)
    local out = {}
    for w in string.gmatch(string.lower(tostring(label or "")), "%a+") do
        if w ~= "lv" then out[#out + 1] = w end
    end
    return out
end
NexusWordSetMemo = NexusWordSetMemo or { n = 0, m = {} }
function nexusWordsOfCached(label)
    local k = tostring(label or "")
    local v = NexusWordSetMemo.m[k]
    if v then return v end
    v = nexusWordsOf(k)
    if NexusWordSetMemo.n > 512 then NexusWordSetMemo.m, NexusWordSetMemo.n = {}, 0 end
    NexusWordSetMemo.m[k], NexusWordSetMemo.n = v, NexusWordSetMemo.n + 1
    return v
end
function nexusTextMatchesWords(text, words)
    if not text or not words or #words == 0 then return false end
    local low = " " .. string.gsub(string.lower(tostring(text)), "[^%a]+", " ") .. " "
    for _, w in ipairs(words) do
        if not string.find(low, " " .. w .. " ", 1, true) then return false end
    end
    return true
end
function nexusTextMatchesAnyTag(text, tags)
    if not tags then return false end
    for _, tg in ipairs(tags) do
        if nexusTextMatchesWords(text, nexusWordsOfCached(tg)) then return true end
    end
    return false
end
function nexusValidNpc(m)
    if not m then return false end
    local h, hum = nexusRig(m)
    if not h or not hum or hum.Health <= 0 then return false end
    if nexusIsPlayerModel(m) then return false end
    if nexusIsPetModel(m) then return false end
    local bag = false
    pcall(function() if isPunchingBag and isPunchingBag(m) then bag = true end end)
    if bag then return false end
    return true
end
function nexusStrictNpcNear(pos, tags, radius)
    if not NPCsF or not pos then return nil end
    local r = radius or 25
    local best, bestD
    for _, m in ipairs(NPCsF:GetChildren()) do
        if nexusValidNpc(m) and nexusTextMatchesAnyTag(m.Name, tags) then
            local h = m:FindFirstChild("HumanoidRootPart")
            local dd = (h.Position - pos).Magnitude
            if dd <= r and (not bestD or dd < bestD) then best, bestD = m, dd end
        end
    end
    return best
end

NexusNpcMemo = setmetatable({ key = "", t = 0, m = nil }, { __mode = "v" })
-- [NEXUS-OPT] A player wearing the Toji clan shows "Toji" on their nameplate,
-- and the label fallback below used to accept that player's rig as the boss.
-- Reject anything that belongs to a real player, and ignore clan labels.
function nexusTagRigIsPlayer(m)
    if not m then return false end
    local hit = false
    pcall(function()
        if nexusIsPlayerModel and nexusIsPlayerModel(m) then
            hit = true
            return
        end
        if PlayersF and m:IsDescendantOf(PlayersF) then
            hit = true
            return
        end
        local nm = tostring(m.Name)
        local base = string.match(nm, "^(.-)_Client$")
        if base and PlayersF and PlayersF:FindFirstChild(base .. "_Server") then
            hit = true
            return
        end
        for _, pl in ipairs(NEXUS_LV.Players:GetPlayers()) do
            if nm == pl.Name or nm == (pl.Name .. "_Client") or nm == tostring(pl.UserId) then
                hit = true
                return
            end
        end
    end)
    return hit
end

function nexusTagLabelOk(txt)
    local t = string.lower(tostring(txt or ""))
    if string.find(t, "clan", 1, true) then return false end
    return true
end

function nexusNpcFromTags(tags)
    if not NPCsF or not tags or #tags == 0 then return nil end
    local key = table.concat(tags, "\1")
    local memo = NexusNpcMemo
    if memo.m and memo.key == key and (os.clock() - memo.t) < 0.25 and nexusValidNpc(memo.m) then
        return memo.m
    end
    local myPos
    pcall(function()
        local m = getModel()
        local h = m and m:FindFirstChild("HumanoidRootPart")
        if h then myPos = h.Position end
    end)
    local best, bestD
    local function consider(m)
        if not m or not nexusValidNpc(m) then return end
        if nexusTagRigIsPlayer(m) then return end
        local h = m:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local d = myPos and (h.Position - myPos).Magnitude or 0
        if not bestD or d < bestD then best, bestD = m, d end
    end

    for _, m in ipairs(NPCsF:GetChildren()) do
        if nexusTextMatchesAnyTag(m.Name, tags) then consider(m) end
    end

    if not best then
        pcall(function()
            for _, m in ipairs(NPCsF:GetChildren()) do
                if nexusValidNpc(m) then
                    for _, d in ipairs(m:GetDescendants()) do
                        if d:IsA("TextLabel") and nexusTextMatchesAnyTag(d.Text, tags) then
                            consider(m)
                            break
                        end
                    end
                end
            end
        end)
    end

    if not best then
        pcall(function()
            local cf = Characters:FindFirstChild("Client")
            if not cf then return end
            for _, d in ipairs(clientLabels(cf)) do
                if d:IsA("TextLabel") and nexusTextMatchesAnyTag(d.Text, tags)
                    and nexusTagLabelOk(d.Text) then
                    local rig = d:FindFirstAncestorOfClass("Model")
                    if rig and not nexusIsPetModel(rig) and not nexusTagRigIsPlayer(rig) then
                        if nexusValidNpc(rig) then
                            consider(rig)
                        else
                            local h = rig:FindFirstChild("HumanoidRootPart")
                            if h then consider(nexusStrictNpcNear(h.Position, tags, 25)) end
                        end
                    end
                end
            end
        end)
    end
    memo.key, memo.t, memo.m = key, os.clock(), best
    return best
end

function nexusForgetNpcMemo()
    NexusNpcMemo.key, NexusNpcMemo.m = "", nil
end

SHIKI_KILL_POS = Vector3.new(-2347.85, 375.01, -20953.93)
ShikiForcedCombat = false
ShikiPrevFast = false
ShikiPrevBF = false
function shikiSetCombat(on)
    if on then
        if not ShikiForcedCombat then
            ShikiPrevFast = FastOn
            ShikiPrevBF = BlackFlashOn
            ShikiForcedCombat = true
        end
        FastOn = true
        BlackFlashOn = true
        pcall(function() enableBlackFlash() end)
    elseif ShikiForcedCombat then
        ShikiForcedCombat = false
        FastOn = ShikiPrevFast
        BlackFlashOn = ShikiPrevBF
    end
end

NEXUS_SHIKI_BASES = nil
NEXUS_SHIKI_DISP  = {}

function nexusShikiRoster()
    if NEXUS_SHIKI_BASES then return NEXUS_SHIKI_BASES end
    local bases = {}
    pcall(function()
        local sc = require(RepStorage.Configs.ShikigamiConfig)
        for id, v in pairs(sc.Shikigami or {}) do
            local disp = (type(v) == "table" and v.Name) or tostring(id)
            local base = string.lower(tostring(disp))
            bases[#bases + 1] = base
            NEXUS_SHIKI_DISP[base] = tostring(disp)
        end
    end)
    if #bases == 0 then
        for _, b in ipairs({ "bunny", "kuro", "nue", "shiro", "mahoraga" }) do
            bases[#bases + 1] = b
            NEXUS_SHIKI_DISP[b] = string.upper(string.sub(b, 1, 1)) .. string.sub(b, 2)
        end
    end
    table.sort(bases)
    NEXUS_SHIKI_BASES = bases
    return bases
end

SHADOW_EXACT_NAMES = {}
for _, b in ipairs(nexusShikiRoster()) do
    SHADOW_EXACT_NAMES[#SHADOW_EXACT_NAMES + 1] = "lv.1 " .. b
end
function shadowNorm(v)
    local t = string.lower(tostring(v or ""))
    t = string.gsub(t, "%s+", " ")
    t = string.gsub(t, "^ ", "")
    t = string.gsub(t, " $", "")
    return t
end
function shadowExact(text, names)
    if not text or not names then return false end
    local t = shadowNorm(text)
    if t == "" then return false end
    for _, n in ipairs(names) do
        if t == n then return true end
    end
    return false
end

function shadowInShikiFolder(m)
    if not m then return true end
    local bad = false
    pcall(function()
        if m:FindFirstAncestor(NEXUS_PET_FOLDER) then bad = true return end
        local par = m.Parent
        while par do
            if par.Name == NEXUS_PET_FOLDER then bad = true return end
            par = par.Parent
        end
    end)
    return bad
end

function nexusTpTo(pos)
    local cur = getModel()
    local hrp = cur and cur:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos)
    end)
end

function shadowWantedTags()
    local out = {}
    for _, v in ipairs(ShadowPick or {}) do
        local s = shadowNorm(v)
        if s == "all" then return SHADOW_EXACT_NAMES end
        for _, ok in ipairs(SHADOW_EXACT_NAMES) do
            if s == ok then table.insert(out, ok) end
        end
    end
    if #out == 0 then return SHADOW_EXACT_NAMES end
    return out
end

ShikiNameMemo = setmetatable({}, { __mode = "k" })

function nexusShikiModelName(m)
    if not m then return nil end
    local c = ShikiNameMemo[m]
    if type(c) == "string" then return c end
    if type(c) == "number" and (os.clock() - c) < 2 then return nil end

    local found = nil
    local own = shadowNorm(m.Name)
    if string.sub(own, 1, 5) == "lv.1 " then
        found = own
    else

        pcall(function()
            for _, d in ipairs(m:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = shadowNorm(d.Text)
                    if string.sub(t, 1, 5) == "lv.1 " then found = t return end
                end
            end
        end)

        if not found then
            pcall(function()
                local h = m:FindFirstChild("HumanoidRootPart")
                local cf = Characters and Characters:FindFirstChild("Client")
                if not h or not cf then return end
                for _, d in ipairs(clientLabels(cf)) do
                    if d:IsA("TextLabel") then
                        local t = shadowNorm(d.Text)
                        if string.sub(t, 1, 5) == "lv.1 " then
                            local rig = d:FindFirstAncestorWhichIsA("Model")
                            if rig and not shadowInShikiFolder(rig) then
                                local rh = rig:FindFirstChild("HumanoidRootPart")
                                if rh and (rh.Position - h.Position).Magnitude < 25 then
                                    found = t
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        end
    end

    ShikiNameMemo[m] = found or os.clock()
    return found
end

function shadowNameOk(m, tags)
    if not m or not tags or #tags == 0 then return false end
    if shadowInShikiFolder(m) then return false end
    if shadowExact(m.Name, tags) then return true end
    local nm = nexusShikiModelName(m)
    if not nm then return false end
    for _, t in ipairs(tags) do
        if nm == t then return true end
    end
    return false
end

function findShadowTarget(tags)
    if not NPCsF or not tags or #tags == 0 then return nil end

    for _, m in ipairs(NPCsF:GetChildren()) do
        if not shadowInShikiFolder(m) and shadowExact(m.Name, tags)
            and nexusValidNpc(m) and nexusIsLv1(m) then
            return m
        end
    end

    for _, m in ipairs(NPCsF:GetChildren()) do
        if not shadowInShikiFolder(m) and nexusValidNpc(m) and nexusIsLv1(m)
            and shadowNameOk(m, tags) then
            return m
        end
    end
    return nil
end

function nexusIsPlayerModel(m)
    local isPlayer = false
    pcall(function()
        local Players = NEXUS_LV.Players
        if Players:GetPlayerFromCharacter(m) then isPlayer = true return end
        local n = m.Name
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Name == n or pl.DisplayName == n then isPlayer = true return end
        end
    end)
    return isPlayer
end
function findShikiNear(pos, radius)
    if not NPCsF or not pos then return nil end
    local tags = shadowWantedTags()
    local named, namedD
    for _, m in ipairs(NPCsF:GetChildren()) do
        if not shadowInShikiFolder(m) and nexusValidNpc(m) and nexusIsLv1(m)
            and shadowNameOk(m, tags) then
            local h = m:FindFirstChild("HumanoidRootPart")
            local dd = (h.Position - pos).Magnitude
            if dd <= radius then
                if not namedD or dd < namedD then named, namedD = m, dd end
            end
        end
    end
    return named
end

SHIKI_BASE_NAMES = nexusShikiRoster()
ShikiSeen        = {}
ShikiOptDirty    = false
ShikiHooked      = false
nxShikiDrop      = nil

function nexusShikiLabel(base)

    return "Lv.1 " .. (NEXUS_SHIKI_DISP[base]
        or (string.upper(string.sub(base, 1, 1)) .. string.sub(base, 2)))
end

function nexusShikiBaseOf(m)
    if not m or shadowInShikiFolder(m) then return nil end

    local nm = nexusShikiModelName(m) or shadowNorm(m.Name)
    if string.sub(nm, 1, 5) ~= "lv.1 " then return nil end
    local base = string.sub(nm, 6)
    for _, b in ipairs(SHIKI_BASE_NAMES) do
        if base == b then return b end
    end
    return nil
end

function nexusShikiRegister(m)
    local b = nexusShikiBaseOf(m)
    if b and not ShikiSeen[b] then
        ShikiSeen[b] = true
        ShikiOptDirty = true
    end
end

function nexusShikiResync()
    if not NPCsF then return end
    local fresh = {}
    for _, m in ipairs(NPCsF:GetChildren()) do
        local b = nexusShikiBaseOf(m)
        if b then fresh[b] = true end
    end
    for _, b in ipairs(SHIKI_BASE_NAMES) do
        if (fresh[b] or false) ~= (ShikiSeen[b] or false) then ShikiOptDirty = true end
        ShikiSeen[b] = fresh[b] or nil
    end
end

function nexusShikiOptions()
    local out = { "All" }
    for _, b in ipairs(SHIKI_BASE_NAMES) do
        if ShikiSeen[b] then out[#out + 1] = nexusShikiLabel(b) end
    end

    if #out == 1 then
        for _, b in ipairs(SHIKI_BASE_NAMES) do out[#out + 1] = nexusShikiLabel(b) end
    end
    return out
end

task.spawn(function()
    local lastSync = 0
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NPCsF and not ShikiHooked then
            ShikiHooked = true
            pcall(function()
                CONNS[#CONNS+1] = NPCsF.ChildAdded:Connect(function(m) task.defer(nexusShikiRegister, m) end)
                CONNS[#CONNS+1] = NPCsF.ChildRemoved:Connect(function() task.defer(nexusShikiResync) end)
            end)
            pcall(nexusShikiResync)
        end
        if ShikiOptDirty then
            ShikiOptDirty = false
            if nxShikiDrop then pcall(function() nxShikiDrop:Refresh(nexusShikiOptions()) end) end
        end
        if (os.clock() - lastSync) > 5 then
            lastSync = os.clock()
            pcall(nexusShikiResync)
        end
        task.wait(0.5)
    end
end)

SHIKI_SET        = "Set1"
SHIKI_ESSENCE_ID = "ShadowEssence"
ShikiState       = "Idle"
ShikiEssence     = 0
ShikiActive      = 0
ShikiTotal       = 6
ShikiNeed        = 0
ShikiBossName    = "None"
ShikiBossHP      = "-"
ShikiBossModel   = nil
ShikiAction      = "-"
ShikiFarm        = "Idle"
ShikiDamage      = 0
ShikiFitLbl      = nil
ShikiBossMaxHP   = 0
NexusAltarMethod  = nil
ShikiCycles      = 0
NexusAltarRem     = nil
NexusAltarSet     = nil
ShikiAltarDirty  = true
ShikiAltarHooked = setmetatable({}, { __mode = "k" })
ShikiAltarCache  = { used = 0, total = 6, t = 0 }
NexusPDC          = nil
ShikiEssCache    = { n = 0, t = 0 }

function nexusAltarRemote()
    if NexusAltarRem then return NexusAltarRem end
    pcall(function() NexusAltarRem = Net.QuestService.TenShadows_UseAltar_Method end)
    return NexusAltarRem
end

function nexusAltarSet()
    if NexusAltarSet and NexusAltarSet.Parent then return NexusAltarSet end
    NexusAltarSet = nil
    pcall(function()
        local map   = workspace:FindFirstChild("Map")
        local nodes = map and map:FindFirstChild("Nodes")
        local root  = nodes and nodes:FindFirstChild("TenShadowsAltars")
        NexusAltarSet = root and root:FindFirstChild(SHIKI_SET) or nil
    end)
    if NexusAltarSet then
        ShikiAltarDirty = true
        for _, a in ipairs(NexusAltarSet:GetChildren()) do
            if not ShikiAltarHooked[a] then
                ShikiAltarHooked[a] = true
                pcall(function()
                    CONNS[#CONNS+1] = a:GetAttributeChangedSignal("Used"):Connect(function() ShikiAltarDirty = true end)
                end)
            end
        end
    end
    return NexusAltarSet
end

function nexusAltarCount()
    local f = nexusAltarSet()
    if not f then return 0, 6 end
    if not ShikiAltarDirty and (os.clock() - ShikiAltarCache.t) < 1 then
        return ShikiAltarCache.used, ShikiAltarCache.total
    end
    local used, total = 0, 0
    for _, a in ipairs(f:GetChildren()) do
        total = total + 1
        if a:GetAttribute("Used") then used = used + 1 end
    end
    if total == 0 then total = 6 end
    ShikiAltarCache.used, ShikiAltarCache.total, ShikiAltarCache.t = used, total, os.clock()
    ShikiAltarDirty = false
    return used, total
end

function nexusPlayerData()
    if not NexusPDC then
        pcall(function()
            NexusPDC = require(LocalPlayer
                .PlayerScripts.Client.Controllers.PlayerDataController)
        end)
    end
    local d
    pcall(function() d = NexusPDC and NexusPDC.PlayerData or nil end)
    return d
end

function nexusEssenceCount()
    if (os.clock() - ShikiEssCache.t) < 0.5 then return ShikiEssCache.n end
    local n = nil
    local cc = NexusCharacterController()
    if cc then
        pcall(function()
            local lc = cc.LocalCharacter
            local inv = lc and lc.Inventory
            if inv and inv.GetItemCount then
                n = tonumber(inv:GetItemCount(SHIKI_ESSENCE_ID))
            end
        end)
    end
    if not n then
        n = 0
        local d = nexusPlayerData()
        if d and d.Inventory and d.Inventory.Items then
            for _, it in pairs(d.Inventory.Items) do
                if type(it) == "table" and it.ConfigID == SHIKI_ESSENCE_ID then
                    n = n + (tonumber(it.Count) or 1)
                end
            end
        end
    end
    ShikiEssCache.n, ShikiEssCache.t = n, os.clock()
    return n
end

function nexusAltarMethod()
    if NexusAltarMethod then return NexusAltarMethod end
    pcall(function()
        local nc = require(LocalPlayer
            .PlayerScripts.Client.Controllers.NetworkController)
        NexusAltarMethod = nc.GetRemoteMethod("QuestService", "TenShadows_UseAltar")
    end)
    return NexusAltarMethod
end

function nexusActivateOne(a, idx)
    if a:GetAttribute("Used") then return true end
    local m = nexusAltarMethod()
    if m then
        pcall(function() m:Call(SHIKI_SET, idx):await() end)
    else
        local rem = nexusAltarRemote()
        if not rem then return false end
        pcall(function() rem:InvokeServer(SHIKI_SET, idx) end)
    end
    local deadline = os.clock() + 2
    while os.clock() < deadline do
        if a:GetAttribute("Used") then return true end
        task.wait(0.05)
    end
    return a:GetAttribute("Used") and true or false
end

function nexusActivateAltars()
    local f = nexusAltarSet()
    if not f then return 0 end
    local done = 0
    for _, a in ipairs(f:GetChildren()) do
        if not AutoShikigamiOn then break end
        if not a:GetAttribute("Used") then
            local idx = tonumber(string.match(a.Name, "%d+"))
            if idx then
                for attempt = 1, 3 do
                    if not AutoShikigamiOn then break end
                    ShikiAction = "Placing essence on Altar " .. idx
                        .. (attempt > 1 and ("  (retry " .. (attempt - 1) .. ")") or "")
                    if nexusActivateOne(a, idx) then
                        done = done + 1
                        ShikiAltarDirty = true
                        break
                    end
                    task.wait(0.25)
                end
                task.wait(NEXUS_SHIKI_GAP)
            end
        end
    end
    if done > 0 then ShikiAltarDirty = true end
    ShikiAction = "-"
    return done
end

function nexusBossHPOf(m)
    if not m then return nil, nil end
    local hrp = m:FindFirstChild("HumanoidRootPart")
    local dbg = hrp and hrp:FindFirstChild("CharDebug")
    local fr = dbg and dbg:FindFirstChild("Frame")
    local hp = fr and fr:FindFirstChild("Health")
    local lb = hp and hp:FindFirstChildOfClass("TextLabel")
    if not lb then return nil, nil end
    local a, b = string.match(tostring(lb.Text), "([%d%.]+)%s*/%s*([%d%.]+)")
    return tonumber(a), tonumber(b)
end

function nexusBossAlive(m)
    if not m or not m.Parent then return false end
    local c = nexusBossHPOf(m)
    if c then return c > 0 end
    local hum = m:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

function nexusShikiSpawnTarget(radius)
    if not NPCsF then return nil end
    local best, bd
    for _, m in ipairs(NPCsF:GetChildren()) do
        if m:IsA("Model") and not shadowInShikiFolder(m)
            and not nexusIsPetModel(m) and not nexusIsPlayerModel(m) then
            local h = m:FindFirstChild("HumanoidRootPart")
            if h and nexusBossAlive(m) then
                local dd = (h.Position - SHIKI_POS).Magnitude
                if dd <= (radius or 400) and (not bd or dd < bd) then best, bd = m, dd end
            end
        end
    end
    return best
end

function nexusShikiTrack(t)
    if not t then return end
    ShikiBossModel = t
    local nm
    pcall(function() nm = nexusShikiModelName(t) end)
    if nm and nm ~= "" then
        local lab = nm
        pcall(function() lab = nexusShikiLabel(nm) end)
        ShikiBossName = lab
    elseif ShikiBossName == nil or ShikiBossName == "None" or ShikiBossName == "-" then
        ShikiBossName = "Shikigami"
    end
    local c, mx = nexusBossHPOf(t)
    if c and mx and mx > 0 then
        if (ShikiBossMaxHP or 0) <= 0 or mx > ShikiBossMaxHP then ShikiBossMaxHP = mx end
        ShikiBossHP = NexusComma(math.floor(c)) .. " / " .. NexusComma(math.floor(mx))
            .. "  (" .. math.floor((c / mx) * 100) .. "%)"
        ShikiDamage = math.max((ShikiBossMaxHP or mx) - c, 0)
    end
end

function nexusShikiFitPanel()
    local l = ShikiFitLbl
    if l and l.Parent then
        if l.AbsoluteSize.Y + 1 < l.TextBounds.Y then
            pcall(function() l.Size = UDim2.new(1, 0, 0, 0) end)
        end
        return
    end
    ShikiFitLbl = nil
    local plr = LocalPlayer
    local pg = plr and plr:FindFirstChild("PlayerGui")
    local hub = pg and pg:FindFirstChild("NexusPlayHub")
    if not hub then return end
    for _, d in ipairs(hub:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "Body" then
            local p = d.Parent
            local t = p and p:FindFirstChild("Title")
            if t and t:IsA("TextLabel") and tostring(t.Text) == "Shikigami Status" then
                pcall(function()
                    d.TextWrapped = false
                    d.TextXAlignment = Enum.TextXAlignment.Left
                    d.AutomaticSize = Enum.AutomaticSize.Y
                    d.Size = UDim2.new(1, 0, 0, 0)
                    p.AutomaticSize = Enum.AutomaticSize.Y
                    p.Size = UDim2.new(p.Size.X.Scale, p.Size.X.Offset, 0, 0)
                end)
                ShikiFitLbl = d
                return
            end
        end
    end
end

function nexusShikiTarget()
    local tags = shadowWantedTags()
    local t = findShadowTarget(tags)
    if not t then t = findShikiNear(SHIKI_POS, 400) end
    if not t then t = nexusShikiSpawnTarget(400) end
    return t
end

function nexusShikiStrike(t, cur, chrp)
    local h = t:FindFirstChild("HumanoidRootPart")
    if h then
        pcall(function()
            chrp.AssemblyLinearVelocity = Vector3.zero
            chrp.AssemblyAngularVelocity = Vector3.zero
            chrp.CFrame = CFrame.new(h.Position + Vector3.new(0, 0, 6))
        end)
        nexusLockAt(h.Position + Vector3.new(0, 0, 6))
    end
    if ShikiBossModel ~= t then
        ShikiBossMaxHP, ShikiDamage = 0, 0
        pcall(function()
            local hum = t:FindFirstChildOfClass("Humanoid")
            local _c0, _mx0 = nexusBossHPOf(t)
            if _mx0 and _mx0 > 0 then
                ShikiBossMaxHP = _mx0
            elseif hum then
                ShikiBossMaxHP = hum.MaxHealth
            end
        end)
    end
    ShikiBossModel = t
    local base = nexusShikiBaseOf(t)
    ShikiBossName = base and nexusShikiLabel(base) or tostring(t.Name)
    ShikiFarm = "Fighting"
    ShikiAction = "Attacking " .. tostring(ShikiBossName)
    local npcs = { t }

    NexusQ(NexusBringPump, npcs, cur, chrp)
end

function NexusShikiStatusText()

    ShikiActive, ShikiTotal = nexusAltarCount()
    ShikiEssence = nexusEssenceCount()
    ShikiNeed = math.max(ShikiTotal - ShikiActive, 0)
    if ShikiBossModel and ShikiBossModel.Parent then

        local c, mx = nexusBossHPOf(ShikiBossModel)
        if c and mx and mx > 0 then
            if (ShikiBossMaxHP or 0) <= 0 or mx > ShikiBossMaxHP then ShikiBossMaxHP = mx end
            ShikiBossHP = NexusComma(math.floor(c)) .. " / " .. NexusComma(math.floor(mx))
                .. "  (" .. math.floor((c / mx) * 100) .. "%)"
            ShikiDamage = math.max((ShikiBossMaxHP or mx) - c, 0)
        end
    elseif ShikiBossModel then
        ShikiBossModel, ShikiBossHP = nil, "-"
    end

    local short = math.max(ShikiNeed - (tonumber(ShikiEssence) or 0), 0)
    local gate
    if ShikiNeed <= 0 then
        gate = "Ready - All Pillars Active"
    elseif short > 0 then
        gate = "BLOCKED - Need " .. short .. " More Essence"
    else
        gate = "Ready To Summon"
    end
    local function onOff(v) return v and "ON" or "OFF" end
    local dmg = (ShikiDamage and ShikiDamage > 0) and NexusComma(math.floor(ShikiDamage)) or "-"
    return table.concat({
        "Auto Summon        " .. onOff(AutoShikigamiOn),
        "Auto Kill          " .. onOff(AutoKillShikigamiOn),
        "Shadow Essence     " .. tostring(ShikiEssence),
        "Pillars Activated  " .. tostring(ShikiActive) .. " / " .. tostring(ShikiTotal),
        "Essence Required   " .. tostring(ShikiNeed),
        "Essence Short      " .. tostring(short),
        "Gate               " .. gate,
        "Summon Status      " .. tostring(ShikiState),
        "Farming Status     " .. tostring(ShikiFarm),
        "Current Action     " .. tostring(ShikiAction),
        "Current Shikigami  " .. tostring(ShikiBossName),
        "Shikigami HP       " .. tostring(ShikiBossHP),
        "Damage Dealt       " .. dmg,
        "Cycles Completed   " .. tostring(ShikiCycles),
    }, "\n")
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoShikigamiOn then
            ShikiState = "Checking Inventory"
            ShikiFarm = "Checking"
            ShikiAction = "Reading inventory and altars"
            ShikiActive, ShikiTotal = nexusAltarCount()
            ShikiEssence = nexusEssenceCount()
            ShikiNeed = math.max(ShikiTotal - ShikiActive, 0)

            if ShikiNeed > 0 and ShikiEssence < ShikiNeed then

                ShikiState = "Waiting - Need " .. ShikiNeed .. " Essence (have " .. ShikiEssence .. ")"
                ShikiFarm = "Waiting"
                ShikiAction = "Short " .. math.max(ShikiNeed - ShikiEssence, 0) .. " essence"
                if ShikiForcedCombat then shikiSetCombat(false) end
                task.wait(1)
            elseif ShikiNeed > 0 then

                ShikiState = "Activating Pillars"
                ShikiFarm = "Activating"
                nexusActivateAltars()
                ShikiState = "Summoning"
                ShikiFarm = "Summoning"
                task.wait(NEXUS_SHIKI_GAP)
            else

                ShikiState = "Waiting For Spawn"
                ShikiFarm = "Summoning"
                ShikiAction = "Waiting for spawn"
                local boss, deadline = nil, os.clock() + 45
                while AutoShikigamiOn and os.clock() < deadline do
                    boss = nexusShikiTarget()
                    if boss then break end
                    task.wait(0.15)
                end
                if boss then
                    ShikiCycles = ShikiCycles + 1
                    ShikiState = "Fighting"
                    ShikiFarm = "Moving"
                    ShikiAction = "Moving to boss"
                    nexusShikiTrack(boss)
                    shikiSetCombat(true)
                    local guard = os.clock() + 300
                    local lost = 0
                    while AutoShikigamiOn and os.clock() < guard do

                        if not nexusBossAlive(boss) then
                            local nxt = nexusShikiTarget()
                            if nxt and nexusBossAlive(nxt) and nxt ~= boss then
                                boss = nxt
                                ShikiBossMaxHP, ShikiDamage = 0, 0
                                nexusShikiTrack(boss)
                            else
                                break
                            end
                        end
                        local cur = getModel()
                        local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
                        if chrp then
                            lost = 0
                            ShikiFarm = "Fighting"
                            nexusShikiStrike(boss, cur, chrp)
                            nexusShikiTrack(boss)
                        else
                            lost = lost + 1
                            ShikiAction = "Waiting for character"
                            if lost > 200 then break end
                        end
                        task.wait(0.05)
                    end
                    shikiSetCombat(false)
                    ShikiBossName, ShikiBossHP, ShikiBossModel = "None", "-", nil
                    ShikiBossMaxHP, ShikiDamage = 0, 0
                    ShikiState = "Completed"
                    ShikiFarm = "Returning"
                    ShikiAction = "Returning to summon area"
                    pcall(function() nexusTpTo(SHIKI_KILL_POS) end)
                    ShikiAltarDirty = true

                    ShikiEssCache.t = -1
                    task.wait(0.4)
                else
                    ShikiState = "Waiting"
                    ShikiFarm = "Waiting"
                    ShikiAction = "No shikigami found near the circle"
                    task.wait(0.5)
                end
            end

        elseif AutoKillShikigamiOn then
            if ShikiState ~= "Idle" then ShikiState = "Idle" end
            if ShikiFarm ~= "Hunting" then
                ShikiFarm = "Hunting"
                ShikiAction = "Scanning for shikigami"
            end
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then

                local t = nexusShikiTarget()
                if t and nexusBossAlive(t) then
                    ShikiFarm = "Fighting"
                    nexusShikiStrike(t, cur, chrp)
                    nexusShikiTrack(t)
                    task.wait(0.05)
                else
                    if ShikiFarm ~= "Hunting" then
                        ShikiFarm = "Hunting"
                        ShikiAction = "Scanning for shikigami"
                    end
                    ShikiBossName, ShikiBossHP, ShikiBossModel = "None", "-", nil
                    ShikiBossMaxHP, ShikiDamage = 0, 0
                    task.wait(NEXUS_IDLE)
                end
            else
                task.wait(NEXUS_IDLE)
            end
        else
            if ShikiForcedCombat then shikiSetCombat(false) end
            if ShikiState ~= "Idle" then ShikiState = "Idle" end
            ShikiBossName, ShikiBossHP, ShikiBossModel = "-", "-", nil
            task.wait(NEXUS_IDLE)
        end
    end
end)

AutoKillBossOn = false
BringBossOn = false
FindBossHopOn = false
selectedBoss = "All"
BOSS_TAG_MAP = {
    ["Lv.Dagon"] = "dagon", ["Lv.Kuro"] = "kuro", ["Lv.Bunny"] = "bunny", ["Lv.Nue"] = "nue",
    ["Lv.Shiro"] = "shiro", ["Lv.Mahoraga"] = "mahoraga",
    ["Lv.1 Dagon"] = "dagon",
    ["Lv.1 Kuro"] = "kuro",
    ["Lv.1 Bunny"] = "bunny",
    ["Lv.1 Nue"] = "nue",
    ["Lv.1 Shiro"] = "shiro",
    ["Lv.1 Mahoraga"] = "mahoraga",

    ["Lv.1 Toji"] = "toji",
    ["Gojo Sensei"] = "gojo sensei",
    ["Lv.1 Flame Disaster"] = "flame disaster",
    ["Lv.1 Cursed Anomaly"] = "cursed anomaly",
    ["Lv.1 Ryu"] = "ryu",
    ["Lv.1 Lightning Vessel"] = "lightning vessel",
}

NEXUS_BOSS_STANDALONE = {
    ["lv.1 toji"]             = "toji",
    ["gojo sensei"]           = "gojo sensei",
    ["lv.1 flame disaster"]   = "flame disaster",
    ["lv.1 cursed anomaly"]   = "cursed anomaly",
    ["lv.1 ryu"]              = "ryu",
    ["lv.1 lightning vessel"] = "lightning vessel",
}

NexusBossExtraTags = {}

NexusBossBusy = false
function nexusBossHold(v)
    v = v and true or false
    if NexusBossBusy == v then return end
    NexusBossBusy = v
    if v then
        pcall(NexusDropAnchor)
    else
        pcall(NexusDropAnchor, "boss")
        nexusForgetNpcMemo()
    end
end
NexusBossOwned = false
function nexusApplyBossExtras(extras)
    NexusBossExtraTags = extras or {}
    if #NexusBossExtraTags > 0 then
        AutoKillBossOn = true
        NexusBossOwned = true
    elseif NexusBossOwned then

        AutoKillBossOn = false
        NexusBossOwned = false
    end
    nexusForgetNpcMemo()
end

BOSS_STALL_SEC = 8
bossLast, bossLastHp, bossHpTime = nil, 0, 0
function bossSearchTags()

    if NexusBossExtraTags and #NexusBossExtraTags > 0 then return NexusBossExtraTags end
    local t = BOSS_TAG_MAP[selectedBoss]
    if t then return { t } end
    return {}
end

function findSelectedBoss()
    return nexusNpcFromTags(bossSearchTags())
end

bossHopBusy = false
function bossServerHop()
    if bossHopBusy then return end
    bossHopBusy = true
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local placeId = game.PlaceId
    local jobId = game.JobId
    local plr = LocalPlayer
    pcall(function() writefile("nexus_findboss.txt", "1") end)
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueteleport or queue_teleport
    if q and NEXUSG.NexusPlayHubLoader then pcall(function() q(NEXUSG.NexusPlayHubLoader) end) end
    local best, bestPlayers
    local ok, body = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    if ok and body then
        local okD, data = pcall(function() return HttpService:JSONDecode(body) end)
        if okD and data and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= jobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" and s.playing < s.maxPlayers then
                    if not bestPlayers or s.playing < bestPlayers then best, bestPlayers = s.id, s.playing end
                end
            end
        end
    end
    pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "No boss here -- server hopping...", Type = "Info", Duration = 3 }) end)
    NexusAllowTp = true
    if best then
        pcall(function() TeleportService:TeleportToPlaceInstance(placeId, best, plr) end)
    else
        pcall(function() TeleportService:Teleport(placeId, plr) end)
    end
    task.wait(4)
    NexusAllowTp = false
    bossHopBusy = false
end
NexusSupervise("bosshunter", function()

    pcall(function()
        if isfile and isfile("nexus_findboss.txt") then
            pcall(function() delfile("nexus_findboss.txt") end)
            AutoKillBossOn = true
            FindBossHopOn = true
        end
    end)
    local noBossSince = nil
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoKillBossOn or FindBossHopOn then
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then
                local boss = findSelectedBoss()
                if boss then
                    noBossSince = nil

                    local bhum = boss:FindFirstChildOfClass("Humanoid")
                    local hp = bhum and bhum.Health or 0
                    if bossLast ~= boss then
                        bossLast, bossLastHp, bossHpTime = boss, hp, os.clock()
                    elseif hp < (bossLastHp - 0.01) then
                        bossLastHp, bossHpTime = hp, os.clock()
                    elseif (os.clock() - bossHpTime) > BOSS_STALL_SEC then
                        bossLast, bossLastHp, bossHpTime = nil, 0, os.clock()
                        nexusForgetNpcMemo()
                        pcall(NexusDropAnchor, "boss")
                    end
                    if AutoKillBossOn then
                        nexusBossHold(true)
                        local npcs = { boss }
                        local h = boss:FindFirstChild("HumanoidRootPart")
                        if h then
                            if BringBossOn then
                                pcall(function()
                                    chrp.AssemblyLinearVelocity = Vector3.zero
                                    h.AssemblyLinearVelocity = Vector3.zero
                                    h.CFrame = CFrame.new(chrp.Position + Vector3.new(BRING_OFFSET, 0, 0))
                                end)
                            else
                                pcall(function()
                                    chrp.AssemblyLinearVelocity = Vector3.zero
                                    chrp.CFrame = CFrame.new(h.Position + Vector3.new(0, 0, 6))
                                end)
                                nexusLockAt(h.Position + Vector3.new(0, 0, 6))
                            end
                        end

                        NexusQ(NexusBringPump, npcs, cur, chrp)
                        task.wait(BOSS_GAP)
                    else
                        nexusBossHold(false)
                        task.wait(BOSS_GAP)
                    end
                else
                    nexusBossHold(false)

                    if bossLast then
                        bossLast, bossLastHp, bossHpTime = nil, 0, os.clock()
                        nexusForgetNpcMemo()
                    end
                    if FindBossHopOn then
                        if not noBossSince then noBossSince = os.clock() end

                        if (os.clock() - noBossSince) > 6 then
                            noBossSince = nil
                            bossServerHop()
                        else
                            task.wait(BOSS_GAP)
                        end
                    else
                        noBossSince = nil
                        task.wait(BOSS_GAP)
                    end
                end
            else
                nexusBossHold(false)
                task.wait(BOSS_GAP)
            end
        else
            nexusBossHold(false)
            noBossSince = nil
            task.wait(BOSS_GAP)
        end
    end
end)

BringQuestOn = false
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if BringQuestOn then
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then
                local npcs = NEXUS_LV.collectQuestNPCs()
                if #npcs > 0 then

                    NexusCapKeepInside(chrp)
                    pcall(function() chrp.AssemblyLinearVelocity = Vector3.zero end)
                    local capC, capR = NexusCapPoint()

                    pcall(NexusAIBring, chrp.Position)
                    for i, m in ipairs(npcs) do
                        local h = m:FindFirstChild("HumanoidRootPart")
                        if h then

                            local settled = false
                            if capC then
                                local cd = h.Position - capC
                                settled = Vector3.new(cd.X, 0, cd.Z).Magnitude <= capR * 0.8
                                    and math.abs(cd.Y) <= capR * 0.5
                            end
                            if not settled then
                                local angle = (i / #npcs) * math.pi * 2
                                local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 0, math.sin(angle) * BRING_OFFSET)
                                NexusBringPlace(h, chrp.Position + off)
                            end
                        end
                    end

                    NexusQ(NexusBringPump, npcs, cur, chrp)
                    task.wait(BRING_GAP)
                else
                    task.wait(NEXUS_IDLE)
                end
            else
                task.wait(NEXUS_IDLE)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

AutoGojoOn = false
BringGojoOn = false

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoGojoOn or BringGojoOn then
            NexusSafeAccept("GojoInf3")
        end
        task.wait(LOOP_GAP)
    end
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if BringGojoOn then
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then
                local npcs = NEXUS_LV.collectQuestNPCs()
                if #npcs > 0 then

                    NexusCapKeepInside(chrp)
                    pcall(function() chrp.AssemblyLinearVelocity = Vector3.zero end)
                    local capC, capR = NexusCapPoint()

                    pcall(NexusAIBring, chrp.Position)
                    for i, m in ipairs(npcs) do
                        local h = m:FindFirstChild("HumanoidRootPart")
                        if h then

                            local settled = false
                            if capC then
                                local cd = h.Position - capC
                                settled = Vector3.new(cd.X, 0, cd.Z).Magnitude <= capR * 0.8
                                    and math.abs(cd.Y) <= capR * 0.5
                            end
                            if not settled then
                                local angle = (i / #npcs) * math.pi * 2
                                local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 0, math.sin(angle) * BRING_OFFSET)
                                NexusBringPlace(h, chrp.Position + off)
                            end
                        end
                    end

                    NexusQ(NexusBringPump, npcs, cur, chrp)
                    task.wait(BRING_GAP)
                else
                    task.wait(NEXUS_IDLE)
                end
            else
                task.wait(NEXUS_IDLE)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)


NEXUS_STICK_DROP = 60
NexusAnchors = NexusAnchors or {}

function NexusDropAnchor(key)
    if key then NexusAnchors[key] = nil else NexusAnchors = {} end
end

function NexusStickTo(key, hrp, targetHRP)
    if not hrp then return false end
    local a = NexusAnchors[key]
    if a then
        local t, ok = a.tgt, true
        if not (t and t.Parent) then ok = false end
        if ok then
            local hum = t.Parent:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then ok = false end
            if ok and (t.Position - a.home).Magnitude > NEXUS_STICK_DROP then ok = false end
        end
        if not ok then a = nil NexusAnchors[key] = nil end
    end
    if not a then
        if not targetHRP then return false end
        a = { tgt = targetHRP }
        NexusAnchors[key] = a
    end

    a.cf = auraGoal(a.tgt)
    a.home = a.tgt.Position
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        local p, g = hrp.Position, a.cf.Position
        local dx, dy, dz = p.X - g.X, p.Y - g.Y, p.Z - g.Z
        if (dx * dx + dy * dy + dz * dz) > 0.01 then hrp.CFrame = a.cf end
    end)
    return true
end

StarQ1On, StarQ2On, StarQ3On, StarQ4On, StarQ5On = false, false, false, false, false

StarQ6On, StarQ7On = false, false
NEXUS_STAR_Q6_ID = "StarCult5_1"
NEXUS_STAR_Q7_ID = "StarCultRescueQuest"
StarBossOn = false
starTick = 0

function NexusStarAnyOn()
    return StarQ1On or StarQ2On or StarQ3On or StarQ4On or StarQ5On or StarQ6On or StarQ7On or StarBossOn
end

STAR_Q1_MODEL = "CultInvite"
StarQ1Busy = false

StarQ1Cache = nil
function NexusFindCultInvite()
    if StarQ1Cache and StarQ1Cache.Parent then return StarQ1Cache end
    local found
    pcall(function() found = workspace:FindFirstChild(STAR_Q1_MODEL, true) end)
    StarQ1Cache = found
    return found
end

function NexusPressF()
    local done = false
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        done = true
    end)
    if not done and keypress and keyrelease then
        pcall(function()
            keypress(0x46)
            task.wait(0.05)
            keyrelease(0x46)
        end)
    end
end

function NexusStarCultInvite()
    if StarQ1Busy then return false end
    local mdl = NexusFindCultInvite()
    if not mdl then return false end
    local pivot
    pcall(function() pivot = mdl:GetPivot().Position end)
    if not pivot then return false end
    local me = getModel()
    local hrp = me and me:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    StarQ1Busy = true

    for _ = 1, 5 do
        if not StarQ1On or NEXUSG.NexusPlayHubSession ~= SESSION then break end
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(pivot + Vector3.new(0, 3, 0))
        end)
        task.wait(0.2)

        pcall(function()
            if not fireproximityprompt then return end
            for _, p in ipairs(mdl:GetDescendants()) do
                if p:IsA("ProximityPrompt") then fireproximityprompt(p) end
            end
        end)
        NexusPressF()
        task.wait(0.2)
    end
    StarQ1Busy = false
    return true
end

function NexusStarNPCs(nameLow)
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not myHRP or not NPCsF then return {}, nil, nil end
    local hits = {}
    pcall(function()
        local ClientF = Characters:FindFirstChild("Client")
        if not ClientF then return end
        for _, d in ipairs(clientLabels(ClientF)) do
            if d:IsA("TextLabel") and string.find(string.lower(d.Text), nameLow, 1, true) then
                local rig = d:FindFirstAncestorWhichIsA("Model")
                local h = rig and rig:FindFirstChild("HumanoidRootPart")
                if h then table.insert(hits, h.Position) end
            end
        end
    end)
    local targets = {}
    for _, m in ipairs(NPCsF:GetChildren()) do
        if m ~= myModel and not isPunchingBag(m) then
            local h, hum = nexusRig(m)
            if h and hum and hum.Health > 0 then
                if string.find(string.lower(m.Name), nameLow, 1, true) then
                    table.insert(targets, m)
                else
                    for _, pos in ipairs(hits) do
                        if (h.Position - pos).Magnitude < 10 then
                            table.insert(targets, m)
                            break
                        end
                    end
                end
            end
        end
    end
    return targets, myModel, myHRP
end

function NexusStarKill(list, myModel, myHRP)
    if not myModel or not myHRP or #list == 0 then return end
    local inRange = {}
    for _, m in ipairs(list) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h and (h.Position - myHRP.Position).Magnitude <= NEXUS_LV.ATTACK_RANGE then
            inRange[#inRange + 1] = m
        end
    end
    if #inRange == 0 then return end
    starTick = starTick + 1
    if starTick % 2 == 0 then
        enableBlackFlash()
        NexusQ(pcall, blackFlashList, inRange, myModel, myHRP)
    else
        NexusQ(pcall, attackList, inRange, myModel, myHRP)
    end
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusStarAnyOn() then

            if StarQ1On then NexusOwnAccept("StarCultRecruiter1") end
            if StarQ2On then NexusOwnAccept("StarCult1_1") end
            if StarQ3On then NexusOwnAccept("StarCult2_1") end
            if StarQ4On then NexusOwnAccept("StarCult3_1") end
            if StarQ5On then NexusOwnAccept("StarCult4_1") end
            if StarQ6On then NexusOwnAccept(NEXUS_STAR_Q6_ID) end
            if StarQ7On then NexusOwnAccept(NEXUS_STAR_Q7_ID) end
            task.wait(0.5)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if StarBossOn then
            local list, mdl, hrp = NexusStarNPCs("lunatic cultist")
            if hrp then
                if #list > 0 then
                    local nearest, nd
                    for _, m in ipairs(list) do
                        local h = m:FindFirstChild("HumanoidRootPart")
                        if h then
                            local d = (h.Position - hrp.Position).Magnitude
                            if not nd or d < nd then nearest, nd = h, d end
                        end
                    end
                    if nearest then NexusStickTo("starboss", hrp, nearest) end
                end
                NexusStarKill(list, mdl, hrp)
                task.wait(math.max(0.03, LOOP_GAP))
            else
                task.wait(NEXUS_IDLE)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

RctQ1On, RctQ2On, RctQ3On = false, false, false
InfQ1On, InfQ2On, InfQ3On = false, false, false
SGKaya1On, SGKaya2On, SGToshi1On, SGRen1On = false, false, false, false
NexusBarrierPos = nil

function NexusRctAnyOn()
    return RctQ1On or RctQ2On or RctQ3On or InfQ1On or InfQ2On or InfQ3On or SGKaya1On or SGKaya2On or SGToshi1On or SGRen1On
end

function NexusStarQuestOn()
    return StarQ1On or StarQ2On or StarQ3On or StarQ4On or StarQ5On or StarQ6On or StarQ7On
end

function NexusRctQuestId()
    if RctQ1On then return "ShokoRCT1" end
    if RctQ2On then return "ShokoRCT2" end
    if RctQ3On then return "ShokoRCT3" end
    if InfQ1On then return "GojoInf1" end
    if InfQ2On then return "GojoInf2" end
    if InfQ3On then return "GojoInf3" end

    if SGKaya1On then return "GrandmotherKaya1" end
    if SGKaya2On then return "GrandmotherKaya2" end
    if SGToshi1On then return "GroundskeeperToshi1" end
    if SGRen1On then return "LittleRen1" end

    if StarQ1On then return "StarCultRecruiter1" end
    if StarQ2On then return "StarCult1_1" end
    if StarQ3On then return "StarCult2_1" end
    if StarQ4On then return "StarCult3_1" end
    if StarQ5On then return "StarCult4_1" end
    if StarQ6On then return NEXUS_STAR_Q6_ID end
    if StarQ7On then return NEXUS_STAR_Q7_ID end

    if EvoQ1On then return "Evolution1" end
    if VitQ1On then return "Vitality1" end
    if VitQ2On then return "Vitality2" end
    if VitQ3On then return "Vitality3" end
    if OffQ1On then return "Offense1" end
    if OffQ2On then return "Offense2" end
    if OffQ3On then return "Offense3" end
    if EvoQ3On then return "Evolution3" end

    if NexusHRQuestId then
        local hrId = NexusHRQuestId()
        if hrId then return hrId end
    end

    if NexusKMQuestId then
        local kmId = NexusKMQuestId()
        if kmId then return kmId end
    end
    return nil
end

function NexusQuestEngineOn()

    if NexusBossBusy then return false end
    return QuestOn or NexusRctAnyOn() or NexusStarQuestOn() or (NexusEvoAnyOn and NexusEvoAnyOn())
        or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn())
end

NexusOwnedQuests  = {}
NexusQuestCancel  = nil

function nexusCancelRemote()
    if NexusQuestCancel then return NexusQuestCancel end
    pcall(function() NexusQuestCancel = Net.QuestService.CancelQuest_Method end)
    return NexusQuestCancel
end

function NexusOwnAccept(id)
    if not id or id == "" then return false end

    local ok = NexusSafeAccept(id)
    if ok then NexusOwnedQuests[id] = true end
    return ok
end

function NexusReleaseOwnedId(id)
    if not id or not NexusOwnedQuests[id] then return false end
    NexusOwnedQuests[id] = nil
    local rem = nexusCancelRemote()
    if not rem then return false end
    return pcall(function() rem:InvokeServer(id) end)
end

function NexusReleaseOwned()
    local ids = {}
    for id in pairs(NexusOwnedQuests) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do NexusReleaseOwnedId(id) end
    return #ids
end

-- [NEXUS-OPT] Star Rage quest line: check whether a quest is already running,
-- cancel it, take the new one, then push it to finish fast.
function NexusActiveQuestId()
    local id
    pcall(function()
        local m = NexusQuestMods()
        if m and m.ok then id = m.QC:GetActiveQuest() end
    end)
    if id == "" then id = nil end
    return id
end

NEXUS_STAR_SWAP_WAIT = 0.35
NEXUS_STAR_FETCH_TRIES = 6
function NexusStarQuestSwap(id)
    if not id or id == "" then return false end
    local act = NexusActiveQuestId()

    if act == id then
        pcall(NexusFetchItem, id, NEXUS_STAR_FETCH_TRIES)
        return true
    end

    if act then
        local rem = nexusCancelRemote()
        if rem then pcall(function() rem:InvokeServer(act) end) end
        NexusOwnedQuests[act] = nil
        task.wait(NEXUS_STAR_SWAP_WAIT)
    end

    local ok = NexusOwnAccept(id)
    if ok then pcall(NexusFetchItem, id, NEXUS_STAR_FETCH_TRIES) end
    return ok
end

task.spawn(function()
    local was = false
    while NEXUSG.NexusPlayHubSession == SESSION do
        local now = QuestOn or BringQuestOn or NexusRctAnyOn() or NexusStarQuestOn()
            or (NexusEvoAnyOn and NexusEvoAnyOn()) or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn()) or false
        if was and not now then pcall(NexusReleaseOwned) end
        was = now
        task.wait(0.25)
    end
end)

NexusFetchedItem = nil
function NexusFetchRemote()
    if NexusFetchedItem then return NexusFetchedItem end
    pcall(function() NexusFetchedItem = Net.QuestService.FetchedItem_Signal end)
    if not NexusFetchedItem then
        pcall(function()
            NexusFetchedItem = RepStorage:WaitForChild("NetworkComm")
                :WaitForChild("QuestService"):WaitForChild("FetchedItem_Signal")
        end)
    end
    return NexusFetchedItem
end

function NexusFetchItem(id, times)
    local rem = NexusFetchRemote()
    if not rem then return end
    for _ = 1, (times or 10) do
        if NEXUSG.NexusPlayHubSession ~= SESSION then return end
        pcall(function() rem:FireServer(id) end)
        task.wait(0.12)
    end
end

NexusPartCache = {}
function NexusFindPartPos(name)
    local obj = NexusPartCache[name]
    if not (obj and obj.Parent) then
        obj = nil
        pcall(function() obj = workspace:FindFirstChild(name, true) end)
        NexusPartCache[name] = obj
    end
    if not obj then return nil end
    local pos
    pcall(function()
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") then
            pos = obj:GetPivot().Position
        end
    end)
    return pos
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusRctAnyOn() then
            if RctQ1On then NexusSafeAccept("ShokoRCT1") end
            if RctQ2On then NexusSafeAccept("ShokoRCT2") end
            if RctQ3On then NexusSafeAccept("ShokoRCT3") end
            if InfQ1On then NexusSafeAccept("GojoInf1") end
            if InfQ2On then NexusSafeAccept("GojoInf2") end
            if InfQ3On then NexusSafeAccept("GojoInf3") end
            if SGKaya1On then NexusSafeAccept("GrandmotherKaya1") end
            if SGKaya2On then NexusSafeAccept("GrandmotherKaya2") end
            if SGToshi1On then NexusSafeAccept("GroundskeeperToshi1") end
            if SGRen1On then NexusSafeAccept("LittleRen1") end
            task.wait(0.5)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

LazyFogOn      = false
LazyGateBusy   = false
CurseRemnantOn = false
BossRemnantOn  = false
LAZY_FOG_PART  = "FogSealedGate"
LAZY_FOG_DELAY = 0.5

function NexusObjPos(obj)
    if not obj then return nil end
    local pos
    pcall(function()
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") then
            pos = obj:GetPivot().Position
        elseif obj:IsA("Attachment") then
            pos = obj.WorldPosition
        end
    end)
    return pos
end

function NexusAllNamed(name)
    local out = {}
    pcall(function()
        for _, d in ipairs(wsDesc()) do
            if d.Name == name and NexusObjPos(d) then out[#out + 1] = d end
        end
    end)
    pcall(function()
        table.sort(out, function(a, b)
            local pa, pb = NexusObjPos(a), NexusObjPos(b)
            if not pa or not pb then return false end
            if pa.X ~= pb.X then return pa.X < pb.X end
            if pa.Y ~= pb.Y then return pa.Y < pb.Y end
            return pa.Z < pb.Z
        end)
    end)
    return out
end

NexusPromptSet = NexusPromptSet or nil
function NexusPromptList()
    if NexusPromptSet then return NexusPromptSet end
    local set = {}
    pcall(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.ClassName == "ProximityPrompt" then set[d] = true end
        end
    end)
    NexusPromptSet = set
    pcall(function()
        CONNS[#CONNS + 1] = workspace.DescendantAdded:Connect(function(d)
            if d.ClassName == "ProximityPrompt" then set[d] = true end
        end)
        CONNS[#CONNS + 1] = workspace.DescendantRemoving:Connect(function(d)
            if set[d] then set[d] = nil end
        end)
    end)
    return set
end

function NexusInteractF(obj)
    pcall(function()
        if not fireproximityprompt then return end
        if obj then
            for _, p in ipairs(obj:GetDescendants()) do
                if p:IsA("ProximityPrompt") then fireproximityprompt(p) end
            end
            local parent = obj.Parent
            if parent then
                for _, p in ipairs(parent:GetDescendants()) do
                    if p:IsA("ProximityPrompt") then fireproximityprompt(p) end
                end
            end
        end

        local mdl = getModel()
        local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
        if hrp then
            local hpos = hrp.Position
            for p in pairs(NexusPromptList()) do
                local par = p.Parent
                if par then
                    local ppos = NexusObjPos(par)
                    if ppos and (ppos - hpos).Magnitude <= 25 then fireproximityprompt(p) end
                end
            end
        end
    end)
    NexusPressF()
end

LAZY_ACCEPT_TRIES = 5
function NexusQuestAccepted(questId)
    local ok, has = pcall(function()
        local client = LocalPlayer.PlayerScripts.Client
        local PD = require(client.Controllers.PlayerDataController)
        return PD.PlayerData.Quests[questId] ~= nil
    end)
    return (ok and has) and true or false
end

function NexusLazyGate(partName, questId)
    if LazyGateBusy then return end
    LazyGateBusy = true
    task.spawn(function()
        local pos
        local ok = pcall(function()
            local list = NexusAllNamed(partName)
            pos = (list[1] and NexusObjPos(list[1])) or NexusFindPartPos(partName)
            if pos then
                pcall(function() nexusTpTo(pos + Vector3.new(0, 3, 0)) end)
                task.wait(LAZY_FOG_DELAY)
            end
            for _ = 1, LAZY_ACCEPT_TRIES do
                if NEXUSG.NexusPlayHubSession ~= SESSION then break end
                pcall(function() NEXUS_LV.AcceptQuest:InvokeServer(questId) end)
                task.wait(0.25)
                if NexusQuestAccepted(questId) then break end
            end
        end)
        pcall(function() Library:Notify({
            Title = "NEXUSPLAY HUB",
            Content = (ok and pos) and (partName .. " done") or ("No " .. partName .. " found"),
            Type = (ok and pos) and "Success" or "Error", Duration = 3,
        }) end)
        LazyGateBusy = false
    end)
end

LAZY_GATE_TRIES    = 8
LAZY_GATE_CHECK    = 0.12
LAZY_GATE_PASSES   = 6
LAZY_GATE_DEADLINE = 12
NexusTengenSig      = nil
NexusInteractIF     = nil

function NexusFogRoot()
    local r
    pcall(function() r = workspace.Map.StaticNPCs end)
    return r or workspace
end

function NexusInteract()
    if NexusInteractIF then return NexusInteractIF end
    pcall(function()
        local client = LocalPlayer:FindFirstChild("PlayerScripts")
        client = client and client:FindFirstChild("Client")
        if not client then return end
        local IC = require(client.Controllers.InterfaceController)
        NexusInteractIF = IC:GetInterfaceHandler("Interact")
    end)
    return NexusInteractIF
end

function NexusSignalHeal()
    local h = NexusInteract()
    if not h or not h.Interacted then return false end
    local fired = false
    pcall(function()
        local fire = h.Interacted.Fire
        if type(fire) ~= "function" then return end
        if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" or type(debug.setupvalue) ~= "function" then return end
        local runner, deadIdx
        for i = 1, 8 do
            local ok, v = pcall(debug.getupvalue, fire, i)
            if not ok then break end
            if typeof(v) == "thread" and coroutine.status(v) == "dead" then deadIdx = i end
            if typeof(v) == "function" then runner = v end
        end
        if not deadIdx then return end

        local ok = false
        if runner then ok = pcall(debug.setupvalue, fire, deadIdx, coroutine.create(runner)) end
        if not ok then pcall(debug.setupvalue, fire, deadIdx, nil) end
        fired = true
    end)
    return fired
end

function nexusGateOpen(e)
    if not e then return false end
    local p = e.prompt
    if not p then return false end
    local ok, enabled = pcall(function() return p.Parent ~= nil and p.Enabled end)
    if not ok then return true end
    return not enabled
end

function NexusGateHandler(e)
    if e.conn and e.conn.Connected then return e.conn end
    e.conn = nil
    local h = NexusInteract()
    if not h or not h.Interacted or not e.prompt then return nil end
    if type(debug) ~= "table" or type(debug.getupvalues) ~= "function" then return nil end
    pcall(function()
        local item = h.Interacted._handlerListHead
        while item do
            if item.Connected and type(item._fn) == "function" then
                local ok, ups = pcall(debug.getupvalues, item._fn)
                if ok and type(ups) == "table" then
                    for _, v in pairs(ups) do
                        if v == e.prompt then e.conn = item return end
                    end
                end
            end
            item = item._next
        end
    end)
    return e.conn
end

function NexusGateInteract(e)
    local conn = NexusGateHandler(e)
    if conn then
        local co = coroutine.create(function() conn._fn(e.prompt) end)
        local ok, err = coroutine.resume(co)
        if ok then return true end
        if err and tostring(err):find("dead coroutine") then NexusSignalHeal() end
        return false
    end

    NexusSignalHeal()
    local h = NexusInteract()
    if h and h.Interacted then
        local co = coroutine.create(function() h.Interacted:Fire(e.prompt) end)
        local ok, err = coroutine.resume(co)
        if not ok and err and tostring(err):find("dead coroutine") then NexusSignalHeal() end
    end
    pcall(function()
        if e.prompt and fireproximityprompt then fireproximityprompt(e.prompt) end
    end)
    return false
end

function nexusOpenGate(e)
    if nexusGateOpen(e) then return true end
    local deadline = os.clock() + LAZY_GATE_DEADLINE
    for _ = 1, LAZY_GATE_TRIES do
        if (not LazyFogOn) or NEXUSG.NexusPlayHubSession ~= SESSION then return false end
        if os.clock() > deadline then break end
        NexusGateInteract(e)
        task.wait(LAZY_GATE_CHECK)
        if nexusGateOpen(e) then return true end

        pcall(function() nexusTpTo(e.pos + Vector3.new(0, 3, 0)) end)
    end
    return nexusGateOpen(e)
end

function NexusFinishTengen()
    if not NexusTengenSig then
        pcall(function() NexusTengenSig = Net.QuestService.FinishTengen_Signal end)
    end
    if NexusTengenSig then pcall(function() NexusTengenSig:FireServer() end) end
end

LAZY_FOG_DEDUPE = 8
function NexusFogPoints()
    local raw = {}
    local root = NexusFogRoot()
    local ok, all = pcall(function() return root:GetDescendants() end)
    if ok and type(all) == "table" then
        for _, d in ipairs(all) do
            if d.Name == LAZY_FOG_PART then
                local p = NexusObjPos(d)
                if p then

                    local prompt = nil
                    pcall(function()
                        local pp = d.PrimaryPart
                        if pp then prompt = pp:FindFirstChildWhichIsA("ProximityPrompt") end
                        if not prompt then prompt = d:FindFirstChildWhichIsA("ProximityPrompt", true) end
                    end)
                    raw[#raw + 1] = { pos = p, obj = d, prompt = prompt, conn = nil }
                end
            end
        end
    end

    pcall(function()
        table.sort(raw, function(a, b)
            if a.pos.X ~= b.pos.X then return a.pos.X < b.pos.X end
            if a.pos.Y ~= b.pos.Y then return a.pos.Y < b.pos.Y end
            return a.pos.Z < b.pos.Z
        end)
    end)
    local out = {}
    for _, e in ipairs(raw) do
        local dupe = false
        for _, k in ipairs(out) do
            if (k.pos - e.pos).Magnitude <= LAZY_FOG_DEDUPE then dupe = true break end
        end
        if not dupe then out[#out + 1] = e end
    end
    return out
end

LAZY_FOG_ACCEPT_WAIT = 1.5
LAZY_FOG_STEP_WAIT   = 0.35
LAZY_FOG_TP_SETTLE   = 0.15

function NexusLazyWorkerBody(gen)
    while NEXUSG.NexusPlayHubSession == SESSION and NEXUSG.NexusLazyGen == gen do
        if not LazyFogOn then
            task.wait(NEXUS_IDLE)
        else
            NexusSafeAccept("TengenFog")
            task.wait(LAZY_FOG_ACCEPT_WAIT)
            NexusSignalHeal()
            local pass, total, done = 0, 0, 0
            repeat
                pass = pass + 1
                local pts = NexusFogPoints()
                total, done = #pts, 0
                if total == 0 then break end
                for _, e in ipairs(pts) do
                    if (not LazyFogOn) or NEXUSG.NexusPlayHubSession ~= SESSION
                        or NEXUSG.NexusLazyGen ~= gen then break end
                    if nexusGateOpen(e) then
                        done = done + 1
                    else
                        pcall(function() nexusTpTo(e.pos + Vector3.new(0, 3, 0)) end)
                        task.wait(LAZY_FOG_TP_SETTLE)
                        if nexusOpenGate(e) then
                            done = done + 1
                            task.wait(LAZY_FOG_STEP_WAIT)
                        end

                    end
                end
            until done >= total or pass >= LAZY_GATE_PASSES
                or (not LazyFogOn) or NEXUSG.NexusPlayHubSession ~= SESSION
                or NEXUSG.NexusLazyGen ~= gen

            if LazyFogOn and NEXUSG.NexusLazyGen == gen then
                if total == 0 then
                    task.wait(1)
                elseif done >= total then

                    NexusFinishTengen()
                    LazyFogOn = false
                    Settings["LazyFogOn"] = false
                    pcall(function() saveSettings() end)
                    pcall(function() Library:Notify({
                        Title = "NEXUSPLAY HUB",
                        Content = "Lazy Sorcerer: all " .. total .. " FogSealedGate done - stopped",
                        Type = "Success", Duration = 4,
                    }) end)
                else
                    LazyFogOn = false
                    Settings["LazyFogOn"] = false
                    pcall(function() saveSettings() end)
                    pcall(function() Library:Notify({
                        Title = "NEXUSPLAY HUB",
                        Content = "Lazy Sorcerer: " .. done .. "/" .. total ..
                                  " gates opened - stopped (accept the quest, then retry)",
                        Type = "Error", Duration = 5,
                    }) end)
                end
            end
        end
    end
end

function NexusLazyEnsureWorker()
    local t = NEXUSG.NexusLazyThread

    if typeof(t) == "thread" and coroutine.status(t) ~= "dead" and NEXUSG.NexusLazyOwner == SESSION then
        return t
    end
    local gen = (NEXUSG.NexusLazyGen or 0) + 1
    NEXUSG.NexusLazyGen = gen
    NEXUSG.NexusLazyOwner = SESSION
    NEXUSG.NexusLazyThread = task.spawn(function()
        NexusLazyWorkerBody(gen)
        if NEXUSG.NexusLazyGen == gen then NEXUSG.NexusLazyThread = nil end
    end)
    return NEXUSG.NexusLazyThread
end

NexusLazyEnsureWorker()

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if CurseRemnantOn or BossRemnantOn then
            local list, mdl, hrp = NexusStarNPCs("curse remnant")
            if hrp and #list > 0 then
                local nearest, nd
                for _, m in ipairs(list) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then
                        local d = (h.Position - hrp.Position).Magnitude
                        if not nd or d < nd then nearest, nd = h, d end
                    end
                end
                if nearest then NexusStickTo("remnant", hrp, nearest) end
                NexusStarKill(list, mdl, hrp)
                task.wait(math.max(0.03, LOOP_GAP))
            else
                task.wait(0.2)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

local questNPCs, questMyModel, questMyHRP = {}, nil, nil
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusQuestEngineOn() or AutoGojoOn then
            local t, mm, hrp = NEXUS_LV.collectQuestNPCs()
            questNPCs, questMyModel, questMyHRP = t or {}, mm, hrp

            if NEXUS_LV.FastQuestOn and hrp and #questNPCs > 0 then

                for m, broughtPos in pairs(fastQuestBrought) do
                    if not m.Parent then
                        fastQuestBrought[m] = nil
                    elseif typeof(broughtPos) == "Vector3" then
                        local h = m:FindFirstChild("HumanoidRootPart")
                        if h and (h.Position - broughtPos).Magnitude > 15 then

                            fastQuestBrought[m] = nil
                        end
                    end
                end

                local arrived = false
                for _, m in ipairs(questNPCs) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h and (h.Position - hrp.Position).Magnitude <= 20 then
                        arrived = true break
                    end
                end
                if arrived then
                    if #questNPCs == 1 then

                        local m = questNPCs[1]
                        if not fastQuestBrought[m] then
                            local h = m:FindFirstChild("HumanoidRootPart")
                            if h then
                                fastQuestBrought[m] = h.Position
                                pcall(function() hrp.CFrame = auraGoal(h) end)
                            end
                        end
                    else

                        fastQuestFrozenPos = hrp.CFrame
                        for i, m in ipairs(questNPCs) do
                            if not fastQuestBrought[m] then
                                local h = m:FindFirstChild("HumanoidRootPart")
                                if h then
                                    local angle = (i / math.max(#questNPCs, 1)) * math.pi * 2
                                    local tx = hrp.Position.X + math.cos(angle) * BRING_OFFSET
                                    local tz = hrp.Position.Z + math.sin(angle) * BRING_OFFSET
                                    local boughtPos = Vector3.new(tx, h.Position.Y, tz)
                                    fastQuestBrought[m] = boughtPos
                                    pcall(function() h.CFrame = CFrame.new(boughtPos) end)
                                end
                            end
                        end
                    end
                end
            end

        else
            questNPCs = {}
            fastQuestFrozenPos = nil
        end

        task.wait(0.03)
    end
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do

        if QuestOn or BringQuestOn then
            NexusOwnAccept(currentQuestId())
        end
        task.wait(LOOP_GAP)
    end
end)

NexusFetchBusy = false

NEXUS_FETCH_SETTLE = 0.5
function NexusFetchItems()
    local c = workspace:FindFirstChild("Container")
    local f = c and c:FindFirstChild("QuestFetch")
    local out = {}
    if f then
        for _, m in ipairs(f:GetChildren()) do
            local ok, piv = pcall(function() return m:GetPivot().Position end)
            if ok then out[#out + 1] = { model = m, pos = piv } end
        end
    end
    return out
end
function NexusFetchPrompt(m)
    local n = m:FindFirstChild("_INTERACTOR")
    local pp = n and n:FindFirstChildWhichIsA("ProximityPrompt")
    if pp then return pp end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
end
function NexusFetchGrab(pp)
    if not pp then return end

    pcall(function() pp.RequiresLineOfSight = false end)
    pcall(function() pp.MaxActivationDistance = math.max(pp.MaxActivationDistance, 60) end)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(pp, 1) end)
    end
    local m = NexusQuestMods()
    if m.Interact and m.Interact.Interacted then
        pcall(function() m.Interact.Interacted:Fire(pp) end)
    end
end

NexusFetchIdCache = { t = -1, id = nil, ids = nil }
function NexusFetchQuestItemIds()
    local c, now = NexusFetchIdCache, os.clock()
    local qi = NexusQuestInfo()
    if c.id == qi.id and (now - c.t) < 2 then return c.ids end
    c.t, c.id, c.ids = now, qi.id, nil
    local m = NexusQuestMods()
    local out = {}

    local saved
    pcall(function() saved = m.QC and qi.id and m.QC:GetSavedQuest(qi.id) end)
    if type(saved) == "table" and type(saved.ItemID) == "string" then out[#out + 1] = saved.ItemID end
    local cfg = qi.id and m.QCfg and m.QCfg.Quests and m.QCfg.Quests[qi.id]
    local list = cfg and cfg.ItemIDs
    if type(list) == "table" then
        for _, v in pairs(list) do
            if type(v) == "string" and v ~= out[1] then out[#out + 1] = v end
        end
    end
    if #out > 0 then c.ids = out end
    return c.ids
end

function NexusFetchCredit(times)
    local ids = NexusFetchQuestItemIds()
    if not ids then return end
    for _, id in ipairs(ids) do NexusFetchItem(id, times or 1) end
end

NexusFetchPin = nil
NexusFetchPinConn = nil
function NexusFetchHold(pos)
    NexusFetchPin = pos

    pcall(function()
        local hrp = NexusMyHRP and NexusMyHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(pos)
        end
    end)
    if NexusFetchPinConn then return end
    NexusFetchPinConn = RunService.Heartbeat:Connect(function()
        if NEXUSG.NexusPlayHubSession ~= SESSION then
            if NexusFetchPinConn then
                NexusFetchPinConn:Disconnect()
                NexusFetchPinConn = nil
            end
            return
        end
        local p = NexusFetchPin
        if not p then return end
        local hrp = NexusMyHRP and NexusMyHRP()
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(p)
            end)
        end
    end)
    pcall(function() table.insert(CONNS, NexusFetchPinConn) end)
end

function NexusFetchRelease()
    NexusFetchPin = nil
end

task.spawn(function()
    task.wait(1)
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusQuestEngineOn() and NexusQuestInfo().kind == "Fetch" then
            local items = NexusFetchItems()
            if #items > 0 then
                local hrp = NexusMyHRP and NexusMyHRP()
                if hrp then
                    NexusFetchBusy = true

                    local p = hrp.Position
                    local best, bd = nil, math.huge
                    for _, it in ipairs(items) do
                        local dx, dy, dz = it.pos.X - p.X, it.pos.Y - p.Y, it.pos.Z - p.Z
                        local d = dx * dx + dy * dy + dz * dz
                        if d < bd then bd, best = d, it end
                    end
                    if best and best.model.Parent then
                        local pp = NexusFetchPrompt(best.model)
                        if pp then

                            NexusFetchHold(best.pos + Vector3.new(0, 4, 0))
                            task.wait(NEXUS_FETCH_SETTLE)
                            NexusFetchGrab(pp)

                            local waited = 0
                            while best.model.Parent and waited < 1.2 do
                                task.wait(0.1)
                                waited = waited + 0.1
                            end
                            if best.model.Parent then
                                NexusFetchGrab(pp)
                                task.wait(0.3)
                            end
                            if best.model.Parent then
                                NexusFetchCredit(1)
                                task.wait(0.15)
                            end
                            NexusFetchRelease()
                        else
                            task.wait(0.2)
                        end
                    end
                else
                    task.wait(0.2)
                end
            else

                local ids = NexusFetchQuestItemIds()
                local handled = false
                if ids then
                    for _, id in ipairs(ids) do
                        local pos = NexusFindPartPos(id)
                        if pos then
                            handled = true
                            NexusFetchBusy = true
                            NexusFetchHold(pos + Vector3.new(0, 3, 0))
                            task.wait(NEXUS_FETCH_SETTLE)
                            NexusFetchItem(id, 10)
                            task.wait(0.2)
                            NexusFetchRelease()
                        end
                    end
                end
                if not handled then
                    NexusFetchRelease()
                    NexusFetchBusy = false
                    task.wait(0.3)
                end
            end
        else
            if NexusFetchPin then NexusFetchRelease() end
            NexusFetchBusy = false
            task.wait(0.4)
        end
        task.wait(0.05)
    end
end)

AutoPickOn = false
NexusPickList = nil
NexusQuestSync = false

function NexusQuestReqLevel(id, label)
    local m = NexusQuestMods()
    local cfg = m.ok and m.QCfg.Quests and m.QCfg.Quests[id]
    if cfg then
        local r = cfg.Requirements
        if type(r) == "table" and tonumber(r.Level) then return tonumber(r.Level), cfg end
    end
    return tonumber(tostring(label):match("(%d+)")) or 0, cfg
end

function NexusQuestFarmable(cfg)
    if not cfg then return true end
    if cfg.IsOneTime == true then return false end
    local t = cfg.Type
    if t == "Fetch" or t == "NewFetch" or t == "Exchange" then return false end
    if NexusSkipCap and t == "Capture" then return false end
    return true
end

function NexusBuildPickList()
    if NexusPickList then return NexusPickList end
    local m = NexusQuestMods()
    if not m.ok then return nil end
    local list = {}
    for i, q in ipairs(QUEST_DATA) do
        local lv, cfg = NexusQuestReqLevel(q[1], q[2])
        if NexusQuestFarmable(cfg) then list[#list + 1] = { i = i, lv = lv } end
    end
    table.sort(list, function(a, b) if a.lv == b.lv then return a.i < b.i end return a.lv < b.lv end)
    NexusPickList = list
    return list
end

function NexusMyLevel()
    local lv = 0
    pcall(function()
        local PD = require(LocalPlayer.PlayerScripts.Client.Controllers.PlayerDataController)
        lv = tonumber(PD:GetStats().Level) or 0
    end)
    return lv
end

function NexusBestQuestIndex(level)
    local list = NexusBuildPickList()
    if not list or #list == 0 then return nil end
    for k = #list, 1, -1 do
        if list[k].lv <= level then return list[k].i end
    end
    return list[1].i
end

function NexusApplyQuestIndex(idx)
    if not idx or idx == selQuest or not QUEST_DATA[idx] then return end
    local prevId = currentQuestId()
    selQuest = idx
    if NEXUS_LV.updateQuestLabel then pcall(NEXUS_LV.updateQuestLabel) end
    if nxQuestDrop and NexusQuestOptions and NexusQuestOptions[idx] then
        NexusQuestSync = true
        pcall(function() nxQuestDrop:Set(NexusQuestOptions[idx]) end)
        NexusQuestSync = false
    end

    if QuestOn then
        task.spawn(function()
            local newId = currentQuestId()
            if prevId and prevId ~= newId then pcall(NexusReleaseOwnedId, prevId) end
            NexusOwnAccept(newId)
        end)
    end
end

task.spawn(function()
    task.wait(1)
    local lastLv = -1
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoPickOn then
            local lv = NexusMyLevel()
            if lv > 0 and lv ~= lastLv then
                lastLv = lv
                NexusApplyQuestIndex(NexusBestQuestIndex(lv))
            end
            task.wait(0.5)
        else
            lastLv = -1
            task.wait(1)
        end
    end
end)

NexusAscOn          = false
NexusAscBusy        = false
NexusAscReady       = false
NexusAscPanel       = nil
NexusAscLastText    = nil
NexusAscDirty       = true
NexusAscNextAttempt = 0
NexusAscM           = NexusAscM or { t = -1 }
NexusAscReqCache    = NexusAscReqCache or {}
NexusAscUICache     = nil

function NexusAscMods()
    local m, now = NexusAscM, os.clock()
    if m.ok and (now - m.t) < 5 then return m end
    m.t = now
    local Ctrl = LocalPlayer:FindFirstChild("PlayerScripts")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Client")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Controllers")
    if not Ctrl then return m end
    pcall(function() m.PD  = require(Ctrl.PlayerDataController) end)
    pcall(function() m.SC  = require(RepStorage.Configs.StatsConfig) end)
    pcall(function() m.IC  = require(RepStorage.Configs.ItemConfig) end)
    pcall(function() m.Rem = RepStorage.NetworkComm.PlayerService.GradeRankUp_Method end)
    m.ok = (m.PD ~= nil and m.SC ~= nil)
    return m
end

function NexusComma(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    s = s:gsub("^,", "")
    return neg and ("-" .. s) or s
end

function NexusAscTouch() NexusAscDirty = true end

function NexusAscNext()
    local m = NexusAscMods()
    if not m.ok then return nil, nil, nil end
    local nxt
    pcall(function()
        local lv = m.PD.PlayerData.Stats.Level
        nxt = m.SC.SubGrades[m.SC.GetSubGradeFromLevel(lv)].NextGrade
    end)
    if not nxt then return nil, nil, nil end
    local sg = m.SC.SubGrades[nxt]
    if not sg or sg.CannotGradeTo then return nil, nxt, sg end

    local c = NexusAscReqCache
    if c.grade ~= nxt then
        local entry
        pcall(function() entry = m.SC.GradeRankUpRequirements[nxt] end)
        c.grade   = nxt
        c.reqs    = entry and entry.Requirements
        c.needIds = {}
        c.names   = {}
        for _, r in ipairs(c.reqs or {}) do
            if r.Type == "Item" and r.Item then
                c.needIds[r.Item] = true
                local ic
                pcall(function() ic = m.IC and m.IC.Items and m.IC.Items[r.Item] end)
                c.names[r.Item] = (ic and ic.Name) or tostring(r.Item)
            end
        end
    end
    return c.reqs, nxt, sg
end

function NexusAscCountMany(needIds)
    local m, have = NexusAscMods(), {}
    if not needIds then return have end
    for id in pairs(needIds) do have[id] = 0 end
    pcall(function()
        for _, it in pairs(m.PD.PlayerData.Inventory.Items) do
            if type(it) == "table" then
                local id = it.ConfigID
                if id ~= nil then
                    local cur = have[id]
                    if cur then have[id] = cur + (tonumber(it.Count) or 1) end
                end
            end
        end
    end)
    return have
end

function NexusAscCount(cfgId)
    return NexusAscCountMany({ [cfgId] = true })[cfgId] or 0
end

function NexusAscStat(m, name)
    local v
    pcall(function() v = m.PD.PlayerData.Stats[name] end)
    if v == nil then pcall(function() v = m.PD:GetStats()[name] end) end
    return tonumber(v) or 0
end

function NexusAscBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading grade data...", false end

    local reqs, nxt, sg = NexusAscNext()
    if not reqs then
        if sg and sg.CannotGradeTo then return "Max grade reached - nothing left to ascend to.", false end
        return "No ascension available right now.", false
    end

    local c    = NexusAscReqCache
    local have = NexusAscCountMany(c.needIds)
    local RULE = string.rep("\226\148\128", 30)

    local missItems, missLevel, missOther, metLines = {}, nil, {}, {}
    local shortCount = 0

    for _, r in ipairs(reqs) do
        local name, hv, nd
        if r.Type == "Item" then
            name = (c.names and c.names[r.Item]) or tostring(r.Item)
            nd   = tonumber(r.Amount) or 0
            hv   = have[r.Item] or 0
        elseif r.Type == "Stat" then
            name = tostring(r.Stat)
            nd   = tonumber(r.Value) or 0
            hv   = NexusAscStat(m, r.Stat)
        else
            name, nd, hv = tostring(r.Type), 1, 0
        end

        if hv >= nd then
            metLines[#metLines + 1] = "\226\128\162  " .. name .. "  \194\183  " .. NexusComma(hv) .. " / " .. NexusComma(nd)
        else
            shortCount = shortCount + 1
            local gap = nd - hv
            if r.Type == "Item" then
                missItems[#missItems + 1] = "\226\128\162  " .. name .. "  =  " .. NexusComma(gap)
            elseif r.Type == "Stat" and r.Stat == "Level" then
                missLevel = "\226\128\162  Levels Needed  =  " .. NexusComma(gap)
            else
                missOther[#missOther + 1] = "\226\128\162  " .. name .. "  =  " .. NexusComma(gap)
            end
        end
    end

    local ready = (shortCount == 0)
    local L = {}
    L[#L + 1] = "Next Grade  \194\183  " .. tostring((sg and sg.Name) or nxt)
    L[#L + 1] = RULE

    if ready then
        L[#L + 1] = "ALL REQUIREMENTS MET"
        for _, s in ipairs(metLines) do L[#L + 1] = s end
        L[#L + 1] = RULE
        L[#L + 1] = NexusAscOn
            and "Status  \194\183  Ready - ascending now"
            or  "Status  \194\183  Ready - enable Auto Ascension"
    else
        if #missItems > 0 then
            L[#L + 1] = "ITEMS MISSING"
            for _, s in ipairs(missItems) do L[#L + 1] = s end
        end
        if missLevel then
            if #missItems > 0 then L[#L + 1] = "" end
            L[#L + 1] = "LEVEL REQUIREMENT"
            L[#L + 1] = missLevel
        end
        if #missOther > 0 then
            L[#L + 1] = ""
            L[#L + 1] = "OTHER REQUIREMENTS"
            for _, s in ipairs(missOther) do L[#L + 1] = s end
        end
        if #metLines > 0 then
            L[#L + 1] = ""
            L[#L + 1] = "COMPLETED"
            for _, s in ipairs(metLines) do L[#L + 1] = s end
        end
        L[#L + 1] = RULE
        L[#L + 1] = "Status  \194\183  Waiting on " .. shortCount .. " requirement" .. (shortCount == 1 and "" or "s")
    end

    return table.concat(L, "\n"), ready
end

function NexusAscUI()
    local u = NexusAscUICache
    if u and u.body and u.body.Parent and u.row and u.row.Parent then return u end
    u = nil
    pcall(function()
        local pg  = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hub = pg and pg:FindFirstChild("NexusPlayHub")
        if not hub then return end
        for _, d in ipairs(hub:GetDescendants()) do
            if d:IsA("TextLabel") and d.Name == "Title" and d.Text == "Ascension Requirements" then
                local para = d.Parent
                local body = para and para:FindFirstChild("Body")
                if body and body:IsA("TextLabel") and para.Parent then
                    u = { title = d, para = para, body = body, row = para.Parent, w = -1 }
                end
                break
            end
        end
    end)
    NexusAscUICache = u
    return u
end

function NexusAscFit(txt)
    local u = NexusAscUI()
    if not u then return end
    pcall(function()
        local body, para, row, title = u.body, u.para, u.row, u.title

        local scale = 1
        if title.Size.Y.Offset > 0 and title.AbsoluteSize.Y > 0 then
            scale = title.AbsoluteSize.Y / title.Size.Y.Offset
        end
        if scale < 0.05 then scale = 1 end
        local w = body.AbsoluteSize.X / scale
        if w < 40 then w = (row.AbsoluteSize.X / scale) - 28 end
        u.w = body.AbsoluteSize.X
        if w < 40 then return end
        body.TextWrapped    = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        local h = game:GetService("TextService")
            :GetTextSize(txt, body.TextSize, body.Font, Vector2.new(w, 100000)).Y
        h = math.ceil(h) + 4
        local padTop, padBot = 10, 10
        local p = para:FindFirstChildOfClass("UIPadding")
        if p then padTop, padBot = p.PaddingTop.Offset, p.PaddingBottom.Offset end
        local total = body.Position.Y.Offset + h + padTop + padBot
        body.Size = UDim2.new(1, 0, 0, h)
        para.Size = UDim2.new(1, 0, 0, total)
        row.Size  = UDim2.new(1, 0, 0, total)

        u.h, u.total = h, total

        if not u.hooked then
            u.hooked = true

            local function restore()
                local c = NexusAscUICache
                if c ~= u or not body.Parent then return end
                if not c.h or c.h <= 0 or c.applying then return end
                if body.Size.Y.Offset == c.h and row.Size.Y.Offset == c.total then return end
                c.applying = true
                pcall(function()
                    body.Size = UDim2.new(1, 0, 0, c.h)
                    para.Size = UDim2.new(1, 0, 0, c.total)
                    row.Size  = UDim2.new(1, 0, 0, c.total)
                end)
                c.applying = false
            end
            for _, inst in ipairs({ body, para, row }) do
                local ok, hook = pcall(function()
                    return inst:GetPropertyChangedSignal("Size"):Connect(restore)
                end)
                if ok and hook and CONNS then CONNS[#CONNS + 1] = hook end
            end
        end
    end)
end

function NexusAscEnforce()
    local u = NexusAscUICache
    if not u or not u.h or u.h <= 0 then return end
    local body, row = u.body, u.row
    if not body or not body.Parent or not row then return end
    if body.Size.Y.Offset ~= u.h or row.Size.Y.Offset ~= u.total then
        pcall(function()
            body.Size = UDim2.new(1, 0, 0, u.h)
            u.para.Size = UDim2.new(1, 0, 0, u.total)
            row.Size  = UDim2.new(1, 0, 0, u.total)
        end)
    end
end

function NexusAscRefresh()
    local txt, ready = NexusAscBuild()
    NexusAscReady = ready
    if txt ~= NexusAscLastText then
        NexusAscLastText = txt
        if NexusAscPanel then
            nexusPanelSet(NexusAscPanel, txt)
        end
        NexusAscFit(txt)

        task.defer(function() NexusAscFit(txt) end)
    else

        local u = NexusAscUI()
        if u and u.body and u.body.Parent then
            if u.body.AbsoluteSize.X ~= u.w or not u.h or u.h <= 0 or u.body.Size.Y.Offset ~= u.h then
                NexusAscFit(txt)
            end
        end
    end
    return ready
end

NexusReqUICache   = NexusReqUICache or {}
NexusReqLast      = NexusReqLast or {}
NexusReqNameCache = NexusReqNameCache or {}
NexusRctPanel     = nil
NexusInfPanel     = nil
NexusGatePanel    = nil
NexusSGHideoPanel = nil
NexusSGRenPanel   = nil
NexusSGGojoPanel  = nil
NexusGateIds      = { "Gate1", "Gate2", "Gate3", "Gate4" }

function NexusReqUI(title)
    local u = NexusReqUICache[title]
    if u and u.body and u.body.Parent and u.row and u.row.Parent then return u end
    u = nil
    pcall(function()
        local pg  = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hub = pg and pg:FindFirstChild("NexusPlayHub")
        if not hub then return end
        for _, d in ipairs(hub:GetDescendants()) do
            if d:IsA("TextLabel") and d.Name == "Title" and d.Text == title then
                local para = d.Parent
                local body = para and para:FindFirstChild("Body")
                if body and body:IsA("TextLabel") and para.Parent then
                    u = { title = d, para = para, body = body, row = para.Parent, w = -1 }
                end
                break
            end
        end
    end)
    NexusReqUICache[title] = u
    return u
end

function NexusReqFit(title, txt)
    local u = NexusReqUI(title)
    if not u then return end
    pcall(function()
        local body, para, row, ttl = u.body, u.para, u.row, u.title
        local scale = 1
        if ttl.Size.Y.Offset > 0 and ttl.AbsoluteSize.Y > 0 then
            scale = ttl.AbsoluteSize.Y / ttl.Size.Y.Offset
        end
        if scale < 0.05 then scale = 1 end
        local w = body.AbsoluteSize.X / scale
        if w < 40 then w = (row.AbsoluteSize.X / scale) - 28 end
        u.w = body.AbsoluteSize.X
        if w < 40 then return end
        body.TextWrapped    = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        local h = game:GetService("TextService")
            :GetTextSize(txt, body.TextSize, body.Font, Vector2.new(w, 100000)).Y
        h = math.ceil(h) + 4
        local padTop, padBot = 10, 10
        local p = para:FindFirstChildOfClass("UIPadding")
        if p then padTop, padBot = p.PaddingTop.Offset, p.PaddingBottom.Offset end
        local total = body.Position.Y.Offset + h + padTop + padBot
        body.Size = UDim2.new(1, 0, 0, h)
        para.Size = UDim2.new(1, 0, 0, total)
        row.Size  = UDim2.new(1, 0, 0, total)
        u.h, u.total = h, total
        if not u.hooked then
            u.hooked = true
            local function restore()
                local c = NexusReqUICache[title]
                if c ~= u or not body.Parent then return end
                if not c.h or c.h <= 0 or c.applying then return end
                if body.Size.Y.Offset == c.h and row.Size.Y.Offset == c.total then return end
                c.applying = true
                pcall(function()
                    body.Size = UDim2.new(1, 0, 0, c.h)
                    para.Size = UDim2.new(1, 0, 0, c.total)
                    row.Size  = UDim2.new(1, 0, 0, c.total)
                end)
                c.applying = false
            end
            for _, inst in ipairs({ body, para, row }) do
                local ok, hook = pcall(function()
                    return inst:GetPropertyChangedSignal("Size"):Connect(restore)
                end)
                if ok and hook and CONNS then CONNS[#CONNS + 1] = hook end
            end
        end
    end)
end

function NexusReqEnforce(title)
    local u = NexusReqUICache[title]
    if not u or not u.h or u.h <= 0 then return end
    local body, row = u.body, u.row
    if not body or not body.Parent or not row then return end
    if body.Size.Y.Offset ~= u.h or row.Size.Y.Offset ~= u.total then
        pcall(function()
            body.Size   = UDim2.new(1, 0, 0, u.h)
            u.para.Size = UDim2.new(1, 0, 0, u.total)
            row.Size    = UDim2.new(1, 0, 0, u.total)
        end)
    end
end

NexusReqChanges = NexusReqChanges or 0
NexusUiIdle     = NexusUiIdle or {}
NexusReqCh      = true
NexusRollCh     = true
NexusCrateCh    = true
function NexusUiPass(key, changed, skipN)
    local st = NexusUiIdle[key]
    if not st then st = { idle = 0, c = 0 } NexusUiIdle[key] = st end
    if changed then
        st.idle = 0
    else
        st.idle = st.idle + 1
        if st.idle > 60 then st.idle = 60 end
    end
    if st.idle < 6 then return true end
    st.c = st.c + 1
    if st.c >= (skipN or 4) then st.c = 0 return true end
    return false
end

function NexusReqRefresh(title, panel, txt)
    if not panel or not txt then return false end
    if txt ~= NexusReqLast[title] then
        NexusReqLast[title] = txt
        NexusReqChanges = NexusReqChanges + 1
        pcall(function() panel:SetText(txt) end)
        pcall(function() panel:Set(txt) end)
        NexusReqFit(title, txt)
        task.defer(function() NexusReqFit(title, txt) end)
        return true
    else
        local u = NexusReqUI(title)
        if u and u.body and u.body.Parent then
            if u.body.AbsoluteSize.X ~= u.w or not u.h or u.h <= 0 or u.body.Size.Y.Offset ~= u.h then
                NexusReqFit(title, txt)
            end
        end
    end
    return false
end

NEXUS_STATUS_HOOKS = NEXUS_STATUS_HOOKS or {}

function nexusStatusHook(fn)
    if type(fn) == "function" then NEXUS_STATUS_HOOKS[#NEXUS_STATUS_HOOKS + 1] = fn end
    return fn
end

function nexusStatusRepaint()
    pcall(function()
        if NexusBannerPanel and NexusBannerText then
            NexusReqRefresh("Banner Status", NexusBannerPanel, NexusBannerText())
        end
    end)
    pcall(function()
        if NexusClanPanel and NexusClanText then
            NexusReqRefresh("Clan Roll Status", NexusClanPanel, NexusClanText(false))
        end
    end)
    pcall(function()
        if NexusShopPanel and NexusShopText then
            NexusReqRefresh("Clan Roll Shop", NexusShopPanel, NexusShopText(false))
        end
    end)
    pcall(function()
        if NexusSClanPanel and NexusClanText then
            NexusReqRefresh("Special Clan Roll Status", NexusSClanPanel, NexusClanText(true))
        end
    end)
    pcall(function()
        if NexusSShopPanel and NexusShopText then
            NexusReqRefresh("Special Clan Roll Shop", NexusSShopPanel, NexusShopText(true))
        end
    end)
    pcall(function()
        if NexusRctPanel and NexusReqExchBuild then
            NexusReqRefresh("RCT Requirements", NexusRctPanel, NexusReqExchBuild(
                "RCTExchange", "RCT",
                "Reverse Cursed Technique  \194\183  Exchange",
                "You already have Reverse Cursed Technique."))
        end
    end)
    pcall(function()
        if NexusInfPanel and NexusReqExchBuild then
            NexusReqRefresh("Infinity Aura Requirements", NexusInfPanel, NexusReqExchBuild(
                "InfinityAuraExchange", "InfinityAura",
                "Infinity Aura  \194\183  Exchange",
                "You already have Infinity Aura."))
        end
    end)
    pcall(function()
        if NexusGatePanel and NexusReqGatesBuild then
            NexusReqRefresh("Lazy Sorcerer Gate Requirements", NexusGatePanel, NexusReqGatesBuild())
        end
    end)
    pcall(function()
        if NexusSGHideoPanel and NexusReqExchBuild then
            NexusReqRefresh("A Rare Trade Requirements", NexusSGHideoPanel, NexusReqExchBuild(
                "MerchantHideo1", nil,
                "A Rare Trade  \194\183  Exchange",
                "A Rare Trade is already finished."))
        end
        if NexusSGRenPanel and NexusReqExchBuild then
            NexusReqRefresh("A Little Trade Requirements", NexusSGRenPanel, NexusReqExchBuild(
                "LittleRen2", nil,
                "A Little Trade  \194\183  Exchange",
                "A Little Trade is already finished."))
        end
        if NexusSGGojoPanel and NexusReqExchBuild then
            NexusReqRefresh("Awaken Limitless Requirements", NexusSGGojoPanel, NexusReqExchBuild(
                "KidGojoExchange", "AwakenedLimitless",
                "Awaken Limitless  \194\183  Exchange",
                "You already have Awakened Limitless."))
        end
    end)
    pcall(function()
        if NexusEvoPanel and NexusEvoReqBuild then
            NexusReqRefresh("Evolution Requirements", NexusEvoPanel, NexusEvoReqBuild())
        end
    end)
    pcall(function()
        if NexusSHRPanel and NexusHRReqBuild then
            NexusReqRefresh("Sorcery Restrictor Requirements", NexusSHRPanel, NexusHRReqBuild("SHR"))
        end
    end)
    pcall(function()
        if NexusPHRPanel and NexusHRReqBuild then
            NexusReqRefresh("Physical Restrictor Requirements", NexusPHRPanel, NexusHRReqBuild("PHR"))
        end
    end)
    pcall(function()
        if NexusKMPanel and NexusKMReqBuild then
            NexusReqRefresh("Raiko Pillar Status", NexusKMPanel, NexusKMReqBuild())
        end
    end)
    pcall(function()
        if NexusKMMonkPanel and NexusKMMonkBuild then
            NexusReqRefresh("High Monk Status", NexusKMMonkPanel, NexusKMMonkBuild())
        end
    end)
    pcall(function()
        if NexusKMKamuPanel and NexusKMKamuBuild then
            NexusReqRefresh("Kamutoke Requirements", NexusKMKamuPanel, NexusKMKamuBuild())
        end
    end)
    pcall(function()
        if NexusCTPanel and NexusCTStatusText then
            NexusReqRefresh("CT Skin Shop Status", NexusCTPanel, NexusCTStatusText())
        end
    end)
    pcall(function()
        if NexusInfRaidPanel and NexusInfStatusText then
            NexusReqRefresh("Infinity Raid Status", NexusInfRaidPanel, NexusInfStatusText())
        end
    end)
    pcall(function()
        if NexusSmPanel and NexusSmStatusText then
            NexusReqRefresh("Smooth / FPS Status", NexusSmPanel, NexusSmStatusText())
        end
    end)
    pcall(function()
        if ShikiPanel and NexusShikiStatusText then
            local t = NexusShikiStatusText()
            nexusPanelSet(ShikiPanel, t)
            pcall(function() nexusShikiFitPanel() end)
        end
    end)
    return true
end

function nexusStatusForce()
    NexusReqLast = {}
    NexusUiIdle  = {}
    pcall(function() NexusAscDirty    = true end)
    pcall(function() NexusRollCh      = true end)
    pcall(function() NexusReqCh       = true end)
    pcall(function() NexusCTDirty     = true end)
    pcall(function() ShikiOptDirty   = true end)
    pcall(function() NexusBannerSyncT = 0 end)
    pcall(function() if NexusBannerSync then NexusBannerSync() end end)
    pcall(function()
        if NexusSafeRefresh then
            NexusSafeLastTxt = ""
            NexusSafeRefresh(true)
        end
    end)
    pcall(nexusStatusRepaint)
    for i = 1, #NEXUS_STATUS_HOOKS do pcall(NEXUS_STATUS_HOOKS[i]) end
    pcall(NexusFitPanels)
    return true
end

function nexusRefreshButton(tab)
    if not tab then return nil end
    local btn
    pcall(function()
        btn = tab:CreateButton({ Name = "Refresh Status", Callback = function()
            task.spawn(function() pcall(nexusStatusForce) end)
        end })
    end)
    return btn
end

function NexusReqName(id)
    local n = NexusReqNameCache[id]
    if n then return n end
    local nm
    pcall(function()
        local m = NexusAscMods()
        nm = m.IC and m.IC.Items and m.IC.Items[id] and m.IC.Items[id].Name
    end)
    nm = nm or tostring(id)
    NexusReqNameCache[id] = nm
    return nm
end

function NexusReqSpec(questId)
    local q
    pcall(function()
        local m = NexusQuestMods()
        q = m.QCfg and m.QCfg.Quests and m.QCfg.Quests[questId]
    end)
    if not q or not q.Requirements then return nil, 0 end
    local list = {}
    for _, pair in ipairs(q.Requirements.Items or {}) do
        local id, amt = pair[1], tonumber(pair[2]) or 0
        if id then list[#list + 1] = { id = id, need = amt } end
    end
    return list, tonumber(q.Requirements.Level) or 0
end

function NexusReqDone(questId, rewardId)
    local done = false
    pcall(function()
        local m = NexusQuestMods()
        local sq = m.QC and m.QC.GetSavedQuest and m.QC:GetSavedQuest(questId)
        if type(sq) == "table" and sq.IsFinished then done = true end
    end)
    if not done and rewardId then
        if (NexusAscCountMany({ [rewardId] = true })[rewardId] or 0) > 0 then done = true end
    end
    return done
end

function NexusReqExchBuild(questId, rewardId, heading, ownedMsg)
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE = string.rep("\226\148\128", 30)
    if NexusReqDone(questId, rewardId) then
        return heading .. "\n" .. RULE .. "\n" .. ownedMsg
            .. "\n" .. RULE .. "\nStatus  \194\183  Exchange disabled - not needed"
    end
    local list, lvl = NexusReqSpec(questId)
    if not list or #list == 0 then return heading .. "\n" .. RULE .. "\nRequirement data unavailable." end
    local need = {}
    for _, r in ipairs(list) do need[r.id] = true end
    local have = NexusAscCountMany(need)
    local miss, met, short = {}, {}, 0
    for _, r in ipairs(list) do
        local hv, nm = have[r.id] or 0, NexusReqName(r.id)
        if hv >= r.need then
            met[#met + 1] = "\226\128\162  " .. nm .. "  \194\183  " .. NexusComma(hv) .. " / " .. NexusComma(r.need)
        else
            short = short + 1
            miss[#miss + 1] = "\226\128\162  " .. nm .. "  \194\183  " .. NexusComma(hv) .. " / " .. NexusComma(r.need)
                .. "   (missing " .. NexusComma(r.need - hv) .. ")"
        end
    end
    local myLvl = NexusAscStat(m, "Level")
    local lvlGap = (lvl > 0 and myLvl < lvl) and (lvl - myLvl) or nil
    if lvlGap then short = short + 1 end
    local L = { heading, RULE }
    if #miss > 0 then
        L[#L + 1] = "ITEMS MISSING"
        for _, s in ipairs(miss) do L[#L + 1] = s end
    end
    if lvlGap then
        if #miss > 0 then L[#L + 1] = "" end
        L[#L + 1] = "LEVEL REQUIREMENT"
        L[#L + 1] = "\226\128\162  Levels Needed  =  " .. NexusComma(lvlGap)
    end
    if #met > 0 then
        if #miss > 0 or lvlGap then L[#L + 1] = "" end
        L[#L + 1] = "COMPLETED"
        for _, s in ipairs(met) do L[#L + 1] = s end
    end
    L[#L + 1] = RULE
    L[#L + 1] = (short == 0)
        and "Status  \194\183  Ready to exchange"
        or  ("Status  \194\183  Waiting on " .. short .. " requirement" .. (short == 1 and "" or "s"))
    return table.concat(L, "\n")
end

function NexusReqGatesBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE = string.rep("\226\148\128", 30)
    local specs, done, need = {}, {}, {}
    local unlocked = 0
    for i, gid in ipairs(NexusGateIds) do
        specs[i] = (NexusReqSpec(gid))
        done[i]  = NexusReqDone(gid, nil)
        if done[i] then unlocked = unlocked + 1 end
        for _, r in ipairs(specs[i] or {}) do need[r.id] = true end
    end
    local have = NexusAscCountMany(need)

    local totals, order = {}, {}
    for i, list in ipairs(specs) do
        if list and not done[i] then
            for _, r in ipairs(list) do
                if totals[r.id] == nil then totals[r.id] = 0 order[#order + 1] = r.id end
                totals[r.id] = totals[r.id] + r.need
            end
        end
    end
    local L = {}
    L[#L + 1] = "Lazy Sorcerer Gates  \194\183  " .. unlocked .. " / " .. #NexusGateIds .. " unlocked"
    L[#L + 1] = RULE
    if #order > 0 then
        L[#L + 1] = "TOTAL MATERIALS (remaining gates)"
        for _, id in ipairs(order) do
            local hv, nd = have[id] or 0, totals[id]
            local tail = (hv >= nd) and "  \226\128\148  OK" or ("   (missing " .. NexusComma(nd - hv) .. ")")
            L[#L + 1] = "\226\128\162  " .. NexusReqName(id) .. "  \194\183  " .. NexusComma(hv) .. " / " .. NexusComma(nd) .. tail
        end
    else
        L[#L + 1] = "All gates are already unlocked."
    end
    for i, gid in ipairs(NexusGateIds) do
        L[#L + 1] = ""
        L[#L + 1] = "GATE " .. i
        if done[i] then
            L[#L + 1] = "\226\128\162  This gate is already unlocked."
        else
            local list = specs[i]
            if not list or #list == 0 then
                L[#L + 1] = "\226\128\162  Requirement data unavailable."
            else
                local short = 0
                for _, r in ipairs(list) do
                    local hv = have[r.id] or 0
                    local tail
                    if hv >= r.need then
                        tail = "  \226\128\148  OK"
                    else
                        short = short + 1
                        tail = "   (missing " .. NexusComma(r.need - hv) .. ")"
                    end
                    L[#L + 1] = "\226\128\162  " .. NexusReqName(r.id) .. "  \194\183  "
                        .. NexusComma(hv) .. " / " .. NexusComma(r.need) .. tail
                end
                L[#L + 1] = (short == 0) and "\226\128\162  Ready to unlock"
                    or ("\226\128\162  Waiting on " .. short .. " item" .. (short == 1 and "" or "s"))
            end
        end
    end
    return table.concat(L, "\n")
end

NexusEvoPanel = nil
NEXUS_EVO_QUESTS = {
    { id = "Evolution1", label = "Auto Evolve",        grp = "Evolution Trainer" },
    { id = "Evolution2", label = "Auto Sacrifice",     grp = "Evolution Trainer" },
    { id = "Evolution3", label = "Auto Transcend",     grp = "Evolution Trainer" },
    { id = "Offense1",   label = "Strength",           grp = "Offense Trainer" },
    { id = "Offense2",   label = "Stamina",            grp = "Offense Trainer" },
    { id = "Offense3",   label = "Courage",            grp = "Offense Trainer" },
    { id = "Vitality1",  label = "Vitality Shard",     grp = "Vitality Trainer" },
    { id = "Vitality2",  label = "Vitality Fragment",  grp = "Vitality Trainer" },
    { id = "Vitality3",  label = "Vitality Gem",       grp = "Vitality Trainer" },
    { id = "Sorcery1",   label = "Restricted",         grp = "Sorcery Trainer" },
    { id = "Sorcery2",   label = "Cursed",             grp = "Sorcery Trainer" },
    { id = "Sorcery3",   label = "Limit",              grp = "Sorcery Trainer" },
}
NexusEvoExchIds = nil

function nexusEvoExchanges()
    if NexusEvoExchIds then return NexusEvoExchIds end
    local out = {}
    pcall(function()
        local m = NexusQuestMods()
        local Q = m.QCfg and m.QCfg.Quests
        if not Q then return end
        for id, q in pairs(Q) do
            if type(q) == "table" and q.Type == "Exchange" then
                local l = string.lower(id)
                if string.find(l, "evolution", 1, true) or string.find(l, "sorcery", 1, true)
                or string.find(l, "vitality", 1, true)  or string.find(l, "offense", 1, true)
                or string.find(l, "transcend", 1, true) or string.find(l, "sacrifice", 1, true) then
                    out[#out + 1] = id
                end
            end
        end
        table.sort(out)
    end)
    NexusEvoExchIds = out
    return out
end

function NexusEvoReqBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE = string.rep("\226\148\128", 30)
    local BUL, MID = "\226\128\162  ", "  \194\183  "

    local specs, lvls, done, need = {}, {}, {}, {}
    for i, q in ipairs(NEXUS_EVO_QUESTS) do
        local list, lv = NexusReqSpec(q.id)
        specs[i], lvls[i] = list, lv
        done[i] = NexusReqDone(q.id, nil)
        for _, r in ipairs(list or {}) do need[r.id] = true end
    end
    local exch = nexusEvoExchanges()
    local especs, elvls, edone = {}, {}, {}
    for i, id in ipairs(exch) do
        local list, lv = NexusReqSpec(id)
        especs[i], elvls[i] = list, lv
        edone[i] = NexusReqDone(id, nil)
        for _, r in ipairs(list or {}) do need[r.id] = true end
    end
    local have  = NexusAscCountMany(need)
    local myLvl = NexusAscStat(m, "Level")

    local function itemLine(id, nd)
        local hv = have[id] or 0
        local tail = (hv >= nd) and "  \226\128\148  OK" or ("   (missing " .. NexusComma(nd - hv) .. ")")
        return BUL .. NexusReqName(id) .. MID .. NexusComma(hv) .. " / " .. NexusComma(nd) .. tail
    end

    local function block(L, list, lv, isDone)
        if isDone then L[#L + 1] = BUL .. "Completed" return 0 end
        if not list or #list == 0 then
            if lv and lv > 0 and myLvl < lv then
                L[#L + 1] = BUL .. "Level" .. MID .. NexusComma(myLvl) .. " / " .. NexusComma(lv)
                    .. "   (missing " .. NexusComma(lv - myLvl) .. ")"
                return 1
            end
            L[#L + 1] = BUL .. "No item requirement"
            return 0
        end
        local short = 0
        for _, r in ipairs(list) do
            if (have[r.id] or 0) < r.need then short = short + 1 end
            L[#L + 1] = itemLine(r.id, r.need)
        end
        if lv and lv > 0 and myLvl < lv then
            short = short + 1
            L[#L + 1] = BUL .. "Level" .. MID .. NexusComma(myLvl) .. " / " .. NexusComma(lv)
                .. "   (missing " .. NexusComma(lv - myLvl) .. ")"
        end
        return short
    end

    local totals, order, finished = {}, {}, 0
    for i, list in ipairs(specs) do
        if done[i] then finished = finished + 1 end
        if list and not done[i] then
            for _, r in ipairs(list) do
                if totals[r.id] == nil then totals[r.id] = 0 order[#order + 1] = r.id end
                totals[r.id] = totals[r.id] + r.need
            end
        end
    end
    for i, list in ipairs(especs) do
        if list and not edone[i] then
            for _, r in ipairs(list) do
                if totals[r.id] == nil then totals[r.id] = 0 order[#order + 1] = r.id end
                totals[r.id] = totals[r.id] + r.need
            end
        end
    end

    local L = {}
    L[#L + 1] = "Auto Evolution" .. MID .. finished .. " / " .. #NEXUS_EVO_QUESTS .. " quests complete"
    L[#L + 1] = RULE
    if #order > 0 then
        L[#L + 1] = "TOTAL REMAINING MATERIALS"
        local tOwned, tNeed, tMiss, tOk = 0, 0, 0, 0
        for _, id in ipairs(order) do
            local nd = totals[id]
            local hv = have[id] or 0
            tOwned = tOwned + hv
            tNeed  = tNeed  + nd
            if hv >= nd then tOk = tOk + 1 else tMiss = tMiss + (nd - hv) end
            L[#L + 1] = itemLine(id, nd)
        end

        L[#L + 1] = BUL .. "Total owned" .. MID .. NexusComma(tOwned)
        L[#L + 1] = BUL .. "Total required" .. MID .. NexusComma(tNeed)
        L[#L + 1] = BUL .. "Total missing" .. MID .. NexusComma(tMiss)
        L[#L + 1] = BUL .. "Materials complete" .. MID .. tOk .. " / " .. #order
    else
        L[#L + 1] = "Everything is complete - nothing left to farm."
    end

    local grp = nil
    for i, q in ipairs(NEXUS_EVO_QUESTS) do
        if q.grp ~= grp then
            grp = q.grp
            L[#L + 1] = ""
            L[#L + 1] = string.upper(grp)
        end
        local lv = lvls[i] or 0
        local head = q.label .. ((lv > 0) and ("  [Lv." .. NexusComma(lv) .. "]") or "")
        local body = {}
        local short = block(body, specs[i], lv, done[i])
        local state
        if done[i] then state = "Completed"
        elseif short == 0 then state = "Ready"
        else state = "Missing " .. short end
        L[#L + 1] = head .. MID .. state
        for _, ln in ipairs(body) do L[#L + 1] = "  " .. ln end
    end

    if #exch > 0 then
        L[#L + 1] = ""
        L[#L + 1] = "EXCHANGES"
        for i, id in ipairs(exch) do
            local lv = elvls[i] or 0
            local body = {}
            local short = block(body, especs[i], lv, edone[i])
            local state
            if edone[i] then state = "Completed"
            elseif short == 0 then state = "Ready to exchange"
            else state = "Missing " .. short end
            L[#L + 1] = NexusReqName(id) .. ((lv > 0) and ("  [Lv." .. NexusComma(lv) .. "]") or "") .. MID .. state
            for _, ln in ipairs(body) do L[#L + 1] = "  " .. ln end
        end
    end

    L[#L + 1] = RULE
    L[#L + 1] = (#order == 0) and ("Status" .. MID .. "All requirements met")
        or ("Status" .. MID .. #order .. " item type" .. ((#order == 1) and "" or "s") .. " still needed")
    return table.concat(L, "\n")
end

SHRQ1On, SHRQ2On, SHRQ3On = false, false, false
PHRQ1On, PHRQ2On, PHRQ3On = false, false, false

NEXUS_HR_ACCEPT_GAP = 2.0
NEXUS_HR_EXCH_GAP   = 3.0
NEXUS_HR_EXCH_TRIES = 2
NEXUS_HR_VERIFY     = 0.25
NEXUS_HR_VERIFY_N   = 12

NexusSHRPanel   = nil
NexusPHRPanel   = nil
NexusHRToggles  = NexusHRToggles or {}
NexusHRLastFire = {}
NexusHRDoneSeen = {}
NexusHRWarned   = {}
NexusHRExchLast = {}
NexusHRExchBusy = false
NexusHRSnap     = { t = -1, map = {} }
NexusHRAct      = { t = -1, id = nil }

NEXUS_HR_LINES = {
    SHR = {
        key   = "SHR",
        npc   = "Sorcery Heavenly Restrictor",
        title = "Sorcery Restrictor Requirements",
        quests = {
            { id = "SHR1", key = "SHRQ1On", label = "Train I" },
            { id = "SHR2", key = "SHRQ2On", label = "Train II" },
            { id = "SHR3", key = "SHRQ3On", label = "Train III" },
        },
        exchanges = {
            { id = "SHR4", reward = "SorceryHR", label = "Sorcery Heavenly Restriction", once = false },
        },
    },
    PHR = {
        key   = "PHR",
        npc   = "Physical Heavenly Restrictor",
        title = "Physical Restrictor Requirements",
        quests = {
            { id = "PHR1", key = "PHRQ1On", label = "Endurance I" },
            { id = "PHR2", key = "PHRQ2On", label = "Endurance II" },
            { id = "PHR3", key = "PHRQ3On", label = "Endurance III" },
        },
        exchanges = {
            { id = "PHR4",      reward = "PhysicalHR", label = "Physical Heavenly Restriction", once = false },
            { id = "Invertion", reward = "Invertion",  label = "Inversion I",                   once = true  },
        },
    },
}
NEXUS_HR_ORDER = { "SHR", "PHR" }

function NexusHRNotify(msg, kind)
    pcall(function()
        Library:Notify({ Title = "NEXUSPLAY HUB", Content = tostring(msg), Type = kind or "Info", Duration = 6 })
    end)
end

function NexusHROn(id)
    if id == "SHR1" then return SHRQ1On end
    if id == "SHR2" then return SHRQ2On end
    if id == "SHR3" then return SHRQ3On end
    if id == "PHR1" then return PHRQ1On end
    if id == "PHR2" then return PHRQ2On end
    if id == "PHR3" then return PHRQ3On end
    return false
end

function NexusHRSetOn(id, on)
    if id == "SHR1" then SHRQ1On = on
    elseif id == "SHR2" then SHRQ2On = on
    elseif id == "SHR3" then SHRQ3On = on
    elseif id == "PHR1" then PHRQ1On = on
    elseif id == "PHR2" then PHRQ2On = on
    elseif id == "PHR3" then PHRQ3On = on
    else return end
    local key
    for _, fam in ipairs(NEXUS_HR_ORDER) do
        for _, q in ipairs(NEXUS_HR_LINES[fam].quests) do
            if q.id == id then key = q.key end
        end
    end
    if key then
        pcall(function() Settings[key] = on end)
        pcall(saveSettings)
    end
    local t = NexusHRToggles[id]
    if t then
        pcall(function() t:Set(on) end)
        pcall(function() t:SetValue(on) end)
    end
end

function NexusSHRAnyOn() return SHRQ1On or SHRQ2On or SHRQ3On end
function NexusPHRAnyOn() return PHRQ1On or PHRQ2On or PHRQ3On end
function NexusHRAnyOn()  return NexusSHRAnyOn() or NexusPHRAnyOn() end

function NexusHRCfg(id)
    local q
    pcall(function()
        local m = NexusQuestMods()
        q = m.QCfg and m.QCfg.Quests and m.QCfg.Quests[id]
    end)
    return q
end

function NexusHRSaves()
    local s, now = NexusHRSnap, os.clock()
    if (now - s.t) < 0.4 then return s.map end
    s.t = now
    local map = {}
    pcall(function()
        local m = NexusQuestMods()
        local all = m.QC and m.QC.GetSavedQuests and m.QC:GetSavedQuests()
        if type(all) == "table" then
            for id, q in pairs(all) do map[id] = q end
        end
    end)
    s.map = map
    return map
end

function NexusHRState(id)
    local cfg = NexusHRCfg(id)
    local sq  = NexusHRSaves()[id]
    if sq == nil then
        pcall(function()
            local m = NexusQuestMods()
            if m.QC and m.QC.GetSavedQuest then sq = m.QC:GetSavedQuest(id) end
        end)
    end
    local st = {
        id       = id,
        name     = (cfg and cfg.Name) or id,
        kind     = (cfg and cfg.Type) or "",
        level    = (cfg and cfg.Requirements and tonumber(cfg.Requirements.Level)) or 0,
        prereq   = (cfg and cfg.Requirements and cfg.Requirements.Quest) or nil,
        need     = (cfg and tonumber(cfg.PointRequirement)) or 0,
        points   = 0,
        accepted = false,
        finished = false,
    }
    if type(sq) == "table" then
        st.accepted = true
        st.points   = tonumber(sq.Points) or 0
        st.finished = (sq.IsFinished and true) or false
    end
    if st.need > 0 and st.points > st.need then st.points = st.need end
    return st
end

function NexusHRActive()
    local a, now = NexusHRAct, os.clock()
    if (now - a.t) < 0.4 then return a.id end
    a.t  = now
    a.id = nil
    pcall(function()
        local m = NexusQuestMods()
        local q = m.QC and m.QC.GetActiveQuest and m.QC:GetActiveQuest()
        if type(q) == "table" then a.id = q.ID or q.id end
        if type(q) == "string" then a.id = q end
    end)
    return a.id
end

function NexusHRBlocked(id)
    local st = NexusHRState(id)
    local lvl = NexusAscStat(NexusAscMods(), "Level")
    if st.level > 0 and lvl < st.level then
        return "Level " .. NexusComma(lvl) .. " / " .. NexusComma(st.level)
    end
    if st.prereq then
        local p = NexusHRState(st.prereq)
        if not p.finished then return "Requires " .. p.name end
    end
    return nil
end

function NexusHRNextId()
    for _, fam in ipairs(NEXUS_HR_ORDER) do
        for _, q in ipairs(NEXUS_HR_LINES[fam].quests) do
            if NexusHROn(q.id) then
                local st = NexusHRState(q.id)
                if not st.finished then return q.id, st end
            end
        end
    end
    return nil, nil
end

function NexusHRQuestId()
    local id = NexusHRNextId()
    if id and not NexusHRBlocked(id) then return id end
    return nil
end

function NexusHRKick(id)
    if not NexusHROn(id) then return end
    local st  = NexusHRState(id)
    if st.finished then
        NexusHRDoneSeen[id] = true
        NexusHRNotify(st.name .. " is already complete.", "Info")
        return
    end
    local why = NexusHRBlocked(id)
    if why then
        NexusHRWarned[id] = true
        NexusHRNotify(st.name .. " is locked  -  " .. why, "Info")
        return
    end
    NexusHRLastFire[id] = os.clock()
    NexusHRSnap.t, NexusHRAct.t = -1, -1
    NexusOwnAccept(id)
end

function NexusHRSweep()
    for _, fam in ipairs(NEXUS_HR_ORDER) do
        for _, q in ipairs(NEXUS_HR_LINES[fam].quests) do
            if NexusHROn(q.id) then
                local st = NexusHRState(q.id)
                if st.finished and not NexusHRDoneSeen[q.id] then
                    NexusHRDoneSeen[q.id] = true
                    NexusHRSetOn(q.id, false)
                    NexusHRNotify(st.name .. " complete  -  reward claimed.", "Success")
                end
            end
        end
    end
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusHRAnyOn() then
            local id, st = NexusHRNextId()
            if id and st then
                local why = NexusHRBlocked(id)
                if why then
                    if not NexusHRWarned[id] then
                        NexusHRWarned[id] = true
                        NexusHRNotify(st.name .. " is locked  -  " .. why, "Info")
                    end
                else
                    NexusHRWarned[id] = nil
                    local now  = os.clock()
                    local full = (st.need > 0 and st.points >= st.need)

                    if (full or NexusHRActive() ~= id)
                    and (now - (NexusHRLastFire[id] or 0)) >= NEXUS_HR_ACCEPT_GAP then
                        NexusHRLastFire[id] = now
                        NexusHRSnap.t, NexusHRAct.t = -1, -1
                        NexusOwnAccept(id)
                    end
                end
            end
            NexusHRSweep()
            task.wait(0.5)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

function NexusHRExchCheck(ex, have)
    local list, lvl = NexusReqSpec(ex.id)
    list = list or {}
    if not have then
        local want = {}
        for _, r in ipairs(list) do want[r.id] = true end
        have = NexusAscCountMany(want)
    end
    local cfg    = NexusHRCfg(ex.id)
    local prereq = (cfg and cfg.Requirements and cfg.Requirements.Quest) or nil
    local myLvl  = NexusAscStat(NexusAscMods(), "Level")
    local miss   = {}
    for _, r in ipairs(list) do
        local hv = have[r.id] or 0
        if hv < r.need then
            miss[#miss + 1] = NexusReqName(r.id) .. " " .. NexusComma(hv) .. "/" .. NexusComma(r.need)
        end
    end
    if lvl and lvl > 0 and myLvl < lvl then
        miss[#miss + 1] = "Level " .. NexusComma(myLvl) .. "/" .. NexusComma(lvl)
    end
    if prereq then
        local p = NexusHRState(prereq)
        if not p.finished then miss[#miss + 1] = p.name .. " (quest)" end
    end
    return (#miss == 0), miss, have, list, (lvl or 0), prereq
end

function NexusHRExchDone(ex)
    if not ex.once then return false end
    local done = false
    pcall(function() done = NexusReqDone(ex.id, ex.reward) end)
    return done
end

function NexusHRExchange(ex)
    if not ex then return end
    if NexusHRExchBusy then return end
    local now = os.clock()
    if (now - (NexusHRExchLast[ex.id] or 0)) < NEXUS_HR_EXCH_GAP then return end
    NexusHRExchLast[ex.id] = now
    NexusHRExchBusy = true
    task.spawn(function()
        pcall(function()
            if NexusHRExchDone(ex) then
                NexusHRNotify(ex.label .. " has already been exchanged. It is a one-time exchange, so it will "
                    .. "never be attempted again.", "Info")
                return
            end
            local ready, miss = NexusHRExchCheck(ex)
            if not ready then

                NexusHRNotify("You don't have the required materials for this exchange. Complete the required "
                    .. "quests or collect the missing materials first.  Missing: " .. table.concat(miss, ", "), "Error")
                return
            end
            local before, got = NexusAscCount(ex.reward), false
            for _ = 1, NEXUS_HR_EXCH_TRIES do
                pcall(function() NEXUS_LV.AcceptQuest:InvokeServer(ex.id) end)
                for _ = 1, NEXUS_HR_VERIFY_N do
                    task.wait(NEXUS_HR_VERIFY)
                    if NexusAscCount(ex.reward) > before then got = true break end
                end

                if got or not (NexusHRExchCheck(ex)) then break end
            end
            NexusHRSnap.t = -1
            if got then
                NexusHRNotify(ex.label .. " exchanged successfully.", "Success")
            else
                NexusHRNotify(ex.label .. " exchange sent, but the reward was not detected yet. Check your "
                    .. "inventory before trying again.", "Info")
            end
        end)
        NexusHRExchBusy = false
    end)
end

function NexusHRReqBuild(fam)
    local line = NEXUS_HR_LINES[fam]
    if not line then return "Loading data..." end
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE  = string.rep("\226\148\128", 30)
    local BUL   = "\226\128\162  "
    local MID   = "  \194\183  "
    local OKTAG = "  \226\128\148  OK"
    local myLvl = NexusAscStat(m, "Level")

    local qst, qsp, want = {}, {}, {}
    for i, q in ipairs(line.quests) do
        qst[i] = NexusHRState(q.id)
        qsp[i] = (NexusReqSpec(q.id)) or {}
        for _, r in ipairs(qsp[i]) do want[r.id] = true end
    end
    local esp, edn = {}, {}
    for i, ex in ipairs(line.exchanges) do
        esp[i] = (NexusReqSpec(ex.id)) or {}
        edn[i] = NexusHRExchDone(ex)
        want[ex.reward] = true
        for _, r in ipairs(esp[i]) do want[r.id] = true end
    end
    local have = NexusAscCountMany(want)

    local tot, order = {}, {}
    for i, list in ipairs(qsp) do
        if not qst[i].finished then
            NexusReqAccum(tot, order, list)
        end
    end
    for i, list in ipairs(esp) do
        if not edn[i] then
            NexusReqAccum(tot, order, list)
        end
    end
    local needTotal, ownTotal, pct = NexusReqTotals(tot, order, have)

    local function itemLine(id, nd, pad)
        local hv   = have[id] or 0
        local tail = (hv >= nd) and OKTAG or ("   (missing " .. NexusComma(nd - hv) .. ")")
        return (pad or "") .. BUL .. NexusReqName(id) .. MID .. NexusComma(hv) .. " / " .. NexusComma(nd) .. tail
    end

    local doneN, cur, doneList, leftList = 0, nil, {}, {}
    for i in ipairs(line.quests) do
        local st = qst[i]
        if st.finished then
            doneN = doneN + 1
            doneList[#doneList + 1] = st.name
        else
            leftList[#leftList + 1] = st.name
            if not cur then cur = i end
        end
    end
    local L = {}
    L[#L + 1] = line.npc .. MID .. doneN .. " / " .. #line.quests .. " quests complete"
    L[#L + 1] = RULE
    L[#L + 1] = "QUEST PROGRESS"
    if cur then
        local st, q = qst[cur], line.quests[cur]
        local obj
        if st.kind == "Capture" then obj = "Capture and hold the quest area"
        elseif st.kind == "Enemies" then obj = "Defeat the quest enemies"
        elseif st.kind == "Fetch" then obj = "Collect the quest items"
        else obj = (st.kind ~= "" and st.kind) or "-" end
        L[#L + 1] = BUL .. "Current quest" .. MID .. st.name
            .. ((st.level > 0) and ("  [Lv." .. NexusComma(st.level) .. "]+") or "")
        L[#L + 1] = BUL .. "Current objective" .. MID .. obj
        if st.need > 0 then
            L[#L + 1] = BUL .. "Progress" .. MID .. NexusComma(st.points) .. " / " .. NexusComma(st.need)
                .. "   (" .. math.floor((st.points / st.need) * 100) .. "%)"
        else
            L[#L + 1] = BUL .. "Progress" .. MID .. (st.accepted and "accepted" or "not started")
        end
        L[#L + 1] = BUL .. "Automation" .. MID .. (NexusHROn(q.id)
            and "ON  -  Auto Quest is driving this quest" or "OFF  -  enable the toggle above")
        local why = NexusHRBlocked(q.id)
        if why then L[#L + 1] = BUL .. "Locked" .. MID .. why end
    else
        L[#L + 1] = BUL .. "Current quest" .. MID .. "none  -  every quest in this line is complete"
    end
    L[#L + 1] = BUL .. "Completed quests" .. MID .. ((#doneList > 0) and table.concat(doneList, ", ") or "none yet")
    L[#L + 1] = BUL .. "Remaining quests" .. MID .. ((#leftList > 0) and table.concat(leftList, ", ") or "none")
    L[#L + 1] = BUL .. "Completion" .. MID .. ((doneN == #line.quests)
        and "Quest line complete" or (doneN .. " / " .. #line.quests .. " done"))
    L[#L + 1] = BUL .. "Your level" .. MID .. NexusComma(myLvl)

    L[#L + 1] = RULE
    L[#L + 1] = "INVENTORY REQUIREMENTS"
    if #order == 0 then
        L[#L + 1] = BUL .. "Nothing left to collect for this line"
    else
        for _, id in ipairs(order) do L[#L + 1] = itemLine(id, tot[id]) end
    end

    L[#L + 1] = RULE
    L[#L + 1] = "TOTAL REQUIREMENTS"
    L[#L + 1] = BUL .. "Total items required" .. MID .. NexusComma(needTotal)
    L[#L + 1] = BUL .. "Total items owned" .. MID .. NexusComma(ownTotal)
    L[#L + 1] = BUL .. "Total missing items" .. MID .. NexusComma(math.max(0, needTotal - ownTotal))
    L[#L + 1] = BUL .. "Overall completion" .. MID .. pct .. "%"

    L[#L + 1] = RULE
    L[#L + 1] = "INDIVIDUAL QUEST REQUIREMENTS"
    for i, q in ipairs(line.quests) do
        local st, list = qst[i], qsp[i]
        local short = 0
        for _, r in ipairs(list) do
            if (have[r.id] or 0) < r.need then short = short + 1 end
        end
        local why, state = NexusHRBlocked(q.id), nil
        if st.finished then state = "Completed"
        elseif why then state = "Locked  -  " .. why
        elseif short == 0 then state = st.accepted and "In progress" or "Ready to start"
        else state = "Missing " .. short .. " item" .. ((short == 1) and "" or "s") end
        L[#L + 1] = st.name .. ((st.level > 0) and ("  [Lv." .. NexusComma(st.level) .. "]") or "") .. MID .. state
        if #list == 0 then
            L[#L + 1] = "  " .. BUL .. "No item requirement"
        else
            for _, r in ipairs(list) do L[#L + 1] = itemLine(r.id, r.need, "  ") end
        end
        if st.need > 0 then
            L[#L + 1] = "  " .. BUL .. "Progress" .. MID .. NexusComma(st.points) .. " / " .. NexusComma(st.need)
                .. (st.finished and OKTAG or ("   (missing " .. NexusComma(math.max(0, st.need - st.points)) .. ")"))
        end
    end

    L[#L + 1] = RULE
    L[#L + 1] = "EXCHANGE REQUIREMENTS"
    local exReady = 0
    for i, ex in ipairs(line.exchanges) do
        local ready, miss, _, _, lvl, prereq = NexusHRExchCheck(ex, have)
        local state
        if edn[i] then state = "Already exchanged  (one-time)"
        elseif ready then state = "Ready for Exchange" exReady = exReady + 1
        else state = "Not ready  -  missing " .. #miss end
        L[#L + 1] = ex.label .. ((lvl > 0) and ("  [Lv." .. NexusComma(lvl) .. "]") or "") .. MID .. state
        for _, r in ipairs(esp[i]) do L[#L + 1] = itemLine(r.id, r.need, "  ") end
        if lvl > 0 then
            L[#L + 1] = "  " .. BUL .. "Level" .. MID .. NexusComma(myLvl) .. " / " .. NexusComma(lvl)
                .. ((myLvl >= lvl) and OKTAG or ("   (missing " .. NexusComma(lvl - myLvl) .. ")"))
        end
        if prereq then
            local p = NexusHRState(prereq)
            L[#L + 1] = "  " .. BUL .. "Requires quest" .. MID .. p.name
                .. (p.finished and OKTAG or "   (not complete)")
        end
        if ex.once then
            L[#L + 1] = "  " .. BUL .. "One-time exchange" .. MID .. (edn[i] and "already used" or "available")
        end
        L[#L + 1] = "  " .. BUL .. "Owned" .. MID .. NexusReqName(ex.reward) .. MID .. NexusComma(have[ex.reward] or 0)
        L[#L + 1] = "  " .. BUL .. "Ready for Exchange" .. MID
            .. (edn[i] and "No  -  already exchanged" or (ready and "Yes" or "No"))
    end

    L[#L + 1] = RULE
    if needTotal > 0 and ownTotal < needTotal then
        L[#L + 1] = "Status" .. MID .. NexusComma(needTotal - ownTotal) .. " item"
            .. (((needTotal - ownTotal) == 1) and "" or "s") .. " still needed"
    elseif exReady > 0 then
        L[#L + 1] = "Status" .. MID .. exReady .. " exchange" .. ((exReady == 1) and "" or "s") .. " ready"
    else
        L[#L + 1] = "Status" .. MID .. "All requirements met"
    end
    return table.concat(L, "\n")
end

NEXUS_KM_GAP  = 2.0
NEXUS_KM_TICK = 0.5

NexusKMPanel     = nil
NexusKMMonkPanel = nil
NexusKMKamuPanel = nil
NexusKMToggles   = NexusKMToggles or {}
NexusKMLastFire  = {}
NexusKMWarned    = {}
NexusKMExWarned  = {}
NexusKMRuns      = 0

NEXUS_KM_LINES = {
    RK1 = { npc = "Raiko Pillar I", quest = "Monk1", key = "KMQ1On",
        exchange = { id = "ExMonk1", label = "Channel Its Energy I", reward = "IkazuchiShard", once = true } },
    RK2 = { npc = "Raiko Pillar II", quest = "Monk2", key = "KMQ2On",
        exchange = { id = "ExMonk2", label = "Channel Its Energy II", reward = "IkazuchiShard", once = true } },
    RK3 = { npc = "Raiko Pillar III", quest = "Monk3", key = "KMQ3On",
        exchange = { id = "ExMonk3", label = "Channel Its Energy III", reward = "IkazuchiShard", once = true } },
}
NEXUS_KM_ORDER = { "RK1", "RK2", "RK3" }
NEXUS_KM_HM    = { npc = "High Monk", boss = "Raiden Monk", quest = "HighMonk1", key = "KMHMOn" }
NEXUS_KM_KAMU  = { id = "Yorozu1", label = "Kamutoke", reward = "Kamutoke", once = true }

function NexusKMNotify(msg, kind)
    pcall(function()
        Library:Notify({ Title = "NEXUSPLAY HUB", Content = msg, Type = kind or "Info", Duration = 7 })
    end)
end

function NexusKMOn(id)
    if id == "Monk1" then return KMQ1On end
    if id == "Monk2" then return KMQ2On end
    if id == "Monk3" then return KMQ3On end
    if id == "HighMonk1" then return KMHMOn end
    return false
end

function NexusKMPillarsOn() return (KMQ1On or KMQ2On or KMQ3On) and true or false end
function NexusKMAnyOn() return (NexusKMPillarsOn() or KMHMOn) and true or false end

function NexusKMGap(key)
    local now = os.clock()
    if (now - (NexusKMLastFire[key] or 0)) < NEXUS_KM_GAP then return false end
    NexusKMLastFire[key] = now
    return true
end

function NexusKMRewards(id)
    local cfg = NexusHRCfg(id)
    local out = {}
    if cfg and type(cfg.Rewards) == "table" then
        for _, r in ipairs(cfg.Rewards) do
            if type(r) == "table" and r.ConfigID then
                out[#out + 1] = NexusReqName(r.ConfigID) .. " x" .. NexusComma(tonumber(r.Count) or 1)
            end
        end
    end
    if #out == 0 then return "-" end
    return table.concat(out, ", ")
end

function NexusKMQuestId()
    for _, fam in ipairs(NEXUS_KM_ORDER) do
        local line = NEXUS_KM_LINES[fam]
        if NexusKMOn(line.quest) then
            local st = NexusHRState(line.quest)
            if not st.finished and not NexusHRBlocked(line.quest) then return line.quest end
        end
    end
    if KMHMOn and not NexusHRBlocked(NEXUS_KM_HM.quest) then return NEXUS_KM_HM.quest end
    return nil
end

function NexusKMExchange(ex, opts)
    if not ex then return false end
    opts = opts or {}
    if NexusHRExchDone(ex) then
        if not opts.quiet then
            NexusKMNotify(ex.label .. " has already been exchanged, so it will not be attempted again.", "Info")
        end
        return false
    end
    local ready, miss = NexusHRExchCheck(ex)
    if not ready then
        if not opts.quiet then
            NexusKMNotify((opts.missText or "You don't have the required materials for this exchange. ")
                .. "Missing: " .. table.concat(miss, ", "), "Error")
        end
        return false
    end
    NexusHRExchange(ex)
    return true
end

function NexusKMKamutoke()
    NexusKMExchange(NEXUS_KM_KAMU, {
        missText = "You are missing the required materials to exchange Kamutoke. ",
    })
end

function NexusKMKick(id)
    if not id then return end
    NexusKMWarned[id] = nil
    NexusHRSnap.t, NexusHRAct.t = -1, -1
    local st = NexusHRState(id)
    local why = NexusHRBlocked(id)
    if why then
        NexusKMWarned[id] = true
        NexusKMNotify(st.name .. " is locked  -  " .. why, "Info")
        return
    end
    if st.finished and id ~= NEXUS_KM_HM.quest then return end
    if NexusKMGap(id) then NexusOwnAccept(id) end
end

function NexusKMStep()
    for _, fam in ipairs(NEXUS_KM_ORDER) do
        local line = NEXUS_KM_LINES[fam]
        if NexusKMOn(line.quest) then
            local st = NexusHRState(line.quest)
            if not st.finished then
                local why = NexusHRBlocked(line.quest)
                if why then
                    if not NexusKMWarned[line.quest] then
                        NexusKMWarned[line.quest] = true
                        NexusKMNotify(st.name .. " is locked  -  " .. why, "Info")
                    end
                else
                    NexusKMWarned[line.quest] = nil
                    local full = (st.need > 0 and st.points >= st.need)
                    if (full or NexusHRActive() ~= line.quest) and NexusKMGap(line.quest) then
                        NexusHRSnap.t, NexusHRAct.t = -1, -1
                        NexusOwnAccept(line.quest)
                    end
                end
                return
            end

            local ex = line.exchange
            if ex and not NexusHRExchDone(ex) then
                local ready, miss = NexusHRExchCheck(ex)
                if ready then
                    NexusKMExWarned[ex.id] = nil
                    if NexusKMGap("ex:" .. ex.id) then NexusKMExchange(ex, { quiet = true }) end
                elseif not NexusKMExWarned[ex.id] then
                    NexusKMExWarned[ex.id] = true
                    NexusKMNotify("You don't have the required materials for the " .. ex.label
                        .. " exchange. Complete the required quests or collect the missing materials "
                        .. "first.  Missing: " .. table.concat(miss, ", "), "Error")
                end
            end
        end
    end

    if KMHMOn then
        local id  = NEXUS_KM_HM.quest
        local st  = NexusHRState(id)
        local why = NexusHRBlocked(id)
        if why then
            if not NexusKMWarned[id] then
                NexusKMWarned[id] = true
                NexusKMNotify(st.name .. " is locked  -  " .. why, "Info")
            end
        else
            NexusKMWarned[id] = nil
            if st.finished then
                if NexusKMGap(id) then
                    NexusHRSnap.t, NexusHRAct.t = -1, -1
                    NexusOwnAccept(id)
                    NexusKMRuns = NexusKMRuns + 1
                end
            elseif NexusHRActive() ~= id and NexusKMGap(id) then
                NexusHRSnap.t, NexusHRAct.t = -1, -1
                NexusOwnAccept(id)
            end
        end
    end
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusKMAnyOn() then
            pcall(NexusKMStep)
            task.wait(NEXUS_KM_TICK)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

function NexusKMReqBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE  = string.rep("\226\148\128", 30)
    local BUL   = "\226\128\162  "
    local MID   = "  \194\183  "
    local OKTAG = "  \226\128\148  OK"
    local myLvl = NexusAscStat(m, "Level")

    local qst, esp, edn, want = {}, {}, {}, {}
    for i, fam in ipairs(NEXUS_KM_ORDER) do
        local line = NEXUS_KM_LINES[fam]
        qst[i] = NexusHRState(line.quest)
        esp[i] = (NexusReqSpec(line.exchange.id)) or {}
        edn[i] = NexusHRExchDone(line.exchange)
        want[line.exchange.reward] = true
        for _, r in ipairs(esp[i]) do want[r.id] = true end
    end
    local have = NexusAscCountMany(want)

    local function itemLine(id, nd, pad)
        local hv   = have[id] or 0
        local tail = (hv >= nd) and OKTAG or ("   (missing " .. NexusComma(nd - hv) .. ")")
        return (pad or "") .. BUL .. NexusReqName(id) .. MID .. NexusComma(hv) .. " / " .. NexusComma(nd) .. tail
    end

    local tot, order = {}, {}
    for i in ipairs(NEXUS_KM_ORDER) do
        if not edn[i] then
            NexusReqAccum(tot, order, esp[i])
        end
    end
    local needTotal, ownTotal, pct = NexusReqTotals(tot, order, have)

    local doneN, cur, doneList, leftList = 0, nil, {}, {}
    local ptsNow, ptsNeed = 0, 0
    for i, fam in ipairs(NEXUS_KM_ORDER) do
        local st = qst[i]
        ptsNow  = ptsNow + st.points
        ptsNeed = ptsNeed + st.need
        if st.finished then
            doneN = doneN + 1
            doneList[#doneList + 1] = NEXUS_KM_LINES[fam].npc
        else
            leftList[#leftList + 1] = NEXUS_KM_LINES[fam].npc
            if not cur then cur = i end
        end
    end

    local L = {}
    L[#L + 1] = "Raiko Pillars" .. MID .. doneN .. " / 3 pillars complete"
    L[#L + 1] = RULE
    L[#L + 1] = "QUEST PROGRESS"
    if cur then
        local st   = qst[cur]
        local line = NEXUS_KM_LINES[NEXUS_KM_ORDER[cur]]
        L[#L + 1] = BUL .. "Current NPC" .. MID .. line.npc
        L[#L + 1] = BUL .. "Current quest" .. MID .. st.name
            .. ((st.level > 0) and ("  [Lv." .. NexusComma(st.level) .. "]+") or "")
        L[#L + 1] = BUL .. "Current objective" .. MID .. "Defeat enemies inside the quest area"
        if st.need > 0 then
            L[#L + 1] = BUL .. "Current progress" .. MID .. NexusComma(st.points) .. " / " .. NexusComma(st.need)
                .. "   (" .. math.floor((st.points / st.need) * 100) .. "%)"
        else
            L[#L + 1] = BUL .. "Current progress" .. MID .. (st.accepted and "accepted" or "not started")
        end
        L[#L + 1] = BUL .. "Automation" .. MID .. (NexusKMOn(st.id)
            and "ON  -  Auto Quest is driving this quest" or "OFF  -  enable the toggle above")
        local why = NexusHRBlocked(st.id)
        if why then L[#L + 1] = BUL .. "Locked" .. MID .. why end
    else
        L[#L + 1] = BUL .. "Current quest" .. MID .. "none  -  all three pillars are complete"
    end
    L[#L + 1] = BUL .. "Total required points" .. MID .. NexusComma(ptsNow) .. " / " .. NexusComma(ptsNeed)
    L[#L + 1] = BUL .. "Completed" .. MID .. ((#doneList > 0) and table.concat(doneList, ", ") or "none yet")
    L[#L + 1] = BUL .. "Remaining" .. MID .. ((#leftList > 0) and table.concat(leftList, ", ") or "none")
    L[#L + 1] = BUL .. "Completion status" .. MID .. ((doneN == 3) and "Quest line complete"
        or (doneN .. " / 3 done"))
    L[#L + 1] = BUL .. "Your level" .. MID .. NexusComma(myLvl)

    L[#L + 1] = RULE
    L[#L + 1] = "QUEST DETAILS"
    for i, fam in ipairs(NEXUS_KM_ORDER) do
        local line, st = NEXUS_KM_LINES[fam], qst[i]
        local why      = NexusHRBlocked(line.quest)
        local state
        if st.finished then state = "Completed"
        elseif why then state = "Locked  -  " .. why
        elseif st.accepted then state = "In progress"
        else state = "Ready to start" end
        L[#L + 1] = line.npc .. MID .. state
        L[#L + 1] = "  " .. BUL .. "Quest 1" .. MID .. st.name .. MID
            .. NexusComma(st.points) .. " / " .. NexusComma(st.need)
            .. (st.finished and OKTAG or ("   (missing " .. NexusComma(math.max(0, st.need - st.points)) .. ")"))
        L[#L + 1] = "  " .. BUL .. "Quest 1 reward" .. MID .. NexusKMRewards(line.quest)
        L[#L + 1] = "  " .. BUL .. "Quest 2" .. MID .. line.exchange.label
            .. MID .. (edn[i] and "Exchanged" or (st.finished and "Awaiting hand-in" or "Locked until Quest 1 is done"))
        for _, r in ipairs(esp[i]) do L[#L + 1] = itemLine(r.id, r.need, "    ") end
        L[#L + 1] = "  " .. BUL .. "Quest 2 reward" .. MID .. NexusKMRewards(line.exchange.id)
    end

    L[#L + 1] = RULE
    L[#L + 1] = "INVENTORY REQUIREMENTS  (live scan)"
    if #order == 0 then
        L[#L + 1] = BUL .. "Nothing left to collect for this line"
    else
        for _, id in ipairs(order) do L[#L + 1] = itemLine(id, tot[id]) end
    end
    L[#L + 1] = BUL .. "Total items required" .. MID .. NexusComma(needTotal)
    L[#L + 1] = BUL .. "Total items owned" .. MID .. NexusComma(ownTotal)
    L[#L + 1] = BUL .. "Total missing items" .. MID .. NexusComma(math.max(0, needTotal - ownTotal))
    L[#L + 1] = BUL .. "Overall completion" .. MID .. pct .. "%"
    L[#L + 1] = BUL .. "Ikazuchi Shards owned" .. MID .. NexusComma(have["IkazuchiShard"] or 0)

    L[#L + 1] = RULE
    L[#L + 1] = "EXCHANGE READINESS"
    local exReady = 0
    for i, fam in ipairs(NEXUS_KM_ORDER) do
        local ex = NEXUS_KM_LINES[fam].exchange
        local ready, miss, _, _, lvl, prereq = NexusHRExchCheck(ex, have)
        local state
        if edn[i] then state = "Already exchanged  (one-time)"
        elseif ready then state = "Ready for Exchange" exReady = exReady + 1
        else state = "Not ready  -  missing " .. #miss end
        L[#L + 1] = ex.label .. ((lvl > 0) and ("  [Lv." .. NexusComma(lvl) .. "]") or "") .. MID .. state
        if prereq then
            local p = NexusHRState(prereq)
            L[#L + 1] = "  " .. BUL .. "Requires quest" .. MID .. p.name
                .. (p.finished and OKTAG or "   (not complete)")
        end
        L[#L + 1] = "  " .. BUL .. "Ready for Exchange" .. MID
            .. (edn[i] and "No  -  already exchanged" or (ready and "Yes" or "No"))
    end

    L[#L + 1] = RULE
    if needTotal > 0 and ownTotal < needTotal then
        L[#L + 1] = "Status" .. MID .. NexusComma(needTotal - ownTotal) .. " item"
            .. (((needTotal - ownTotal) == 1) and "" or "s") .. " still needed"
    elseif exReady > 0 then
        L[#L + 1] = "Status" .. MID .. exReady .. " exchange" .. ((exReady == 1) and "" or "s") .. " ready"
    else
        L[#L + 1] = "Status" .. MID .. "All requirements met"
    end
    return table.concat(L, "\n")
end

function NexusKMMonkBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE  = string.rep("\226\148\128", 30)
    local BUL   = "\226\128\162  "
    local MID   = "  \194\183  "
    local OKTAG = "  \226\128\148  OK"
    local myLvl = NexusAscStat(m, "Level")
    local id    = NEXUS_KM_HM.quest
    local st    = NexusHRState(id)
    local why   = NexusHRBlocked(id)

    local L = {}
    L[#L + 1] = NEXUS_KM_HM.npc .. MID .. "repeatable boss quest"
    L[#L + 1] = RULE
    L[#L + 1] = "QUEST STATUS"
    L[#L + 1] = BUL .. "Current quest" .. MID .. st.name
        .. ((st.level > 0) and ("  [Lv." .. NexusComma(st.level) .. "]+") or "")
    L[#L + 1] = BUL .. "Objective" .. MID .. "Defeat the boss  -  " .. NEXUS_KM_HM.boss
    local prog
    if why then prog = "locked"
    elseif st.finished then prog = "complete  -  handing in and restarting"
    elseif st.accepted then prog = "accepted  -  hunting the boss"
    else prog = "not started" end
    L[#L + 1] = BUL .. "Current progress" .. MID .. prog
    L[#L + 1] = BUL .. "Completion status" .. MID .. (st.finished and "Ready to claim" or (st.accepted and "In progress" or "Not started"))
    L[#L + 1] = BUL .. "Repeatable" .. MID .. "Yes  -  restarts automatically while the toggle is on"
    L[#L + 1] = BUL .. "Runs completed this session" .. MID .. NexusComma(NexusKMRuns)
    L[#L + 1] = BUL .. "Automation" .. MID .. (KMHMOn
        and "ON  -  Auto Quest is driving this quest" or "OFF  -  enable the toggle above")
    if why then L[#L + 1] = BUL .. "Locked" .. MID .. why end

    L[#L + 1] = RULE
    L[#L + 1] = "REQUIREMENTS"
    L[#L + 1] = BUL .. "Level" .. MID .. NexusComma(myLvl) .. " / " .. NexusComma(st.level)
        .. ((myLvl >= st.level) and OKTAG or ("   (missing " .. NexusComma(st.level - myLvl) .. ")"))
    if st.prereq then
        local p = NexusHRState(st.prereq)
        L[#L + 1] = BUL .. "Requires quest" .. MID .. p.name .. (p.finished and OKTAG or "   (not complete)")
    end
    L[#L + 1] = BUL .. "Required items" .. MID .. "none  -  this quest only needs the boss killed"

    L[#L + 1] = RULE
    L[#L + 1] = "REWARD DETAILS"
    L[#L + 1] = BUL .. "Per run" .. MID .. NexusKMRewards(id)
    L[#L + 1] = RULE
    L[#L + 1] = "Status" .. MID .. (why and ("Locked  -  " .. why)
        or (KMHMOn and "Running" or "Idle  -  toggle is off"))
    return table.concat(L, "\n")
end

function NexusKMKamuBuild()
    local m = NexusAscMods()
    if not m.ok then return "Loading data..." end
    local RULE  = string.rep("\226\148\128", 30)
    local BUL   = "\226\128\162  "
    local MID   = "  \194\183  "
    local OKTAG = "  \226\128\148  OK"
    local myLvl = NexusAscStat(m, "Level")
    local ex    = NEXUS_KM_KAMU
    local list, lvl = NexusReqSpec(ex.id)
    list = list or {}

    local want = { [ex.reward] = true }
    for _, r in ipairs(list) do want[r.id] = true end
    local have = NexusAscCountMany(want)
    local done = NexusHRExchDone(ex)

    local L = {}
    L[#L + 1] = "Kamutoke" .. MID .. (done and "already unlocked" or "exchange")
    L[#L + 1] = RULE
    L[#L + 1] = "REQUIRED MATERIALS  (live inventory scan)"
    local needTotal, ownTotal, missN = 0, 0, 0
    for _, r in ipairs(list) do
        local hv = have[r.id] or 0
        needTotal = needTotal + r.need
        ownTotal  = ownTotal + math.min(hv, r.need)
        if hv < r.need then missN = missN + 1 end
        L[#L + 1] = BUL .. NexusReqName(r.id) .. MID .. NexusComma(hv) .. " / " .. NexusComma(r.need)
            .. ((hv >= r.need) and OKTAG or ("   (missing " .. NexusComma(r.need - hv) .. ")"))
    end
    if #list == 0 then L[#L + 1] = BUL .. "No material requirement found" end

    L[#L + 1] = RULE
    L[#L + 1] = "TOTALS"
    L[#L + 1] = BUL .. "Total required" .. MID .. NexusComma(needTotal)
    L[#L + 1] = BUL .. "Total owned" .. MID .. NexusComma(ownTotal)
    L[#L + 1] = BUL .. "Total missing" .. MID .. NexusComma(math.max(0, needTotal - ownTotal))
    L[#L + 1] = BUL .. "Materials complete" .. MID .. (#list - missN) .. " / " .. #list
    if lvl and lvl > 0 then
        L[#L + 1] = BUL .. "Level" .. MID .. NexusComma(myLvl) .. " / " .. NexusComma(lvl)
            .. ((myLvl >= lvl) and OKTAG or ("   (missing " .. NexusComma(lvl - myLvl) .. ")"))
    end

    L[#L + 1] = RULE
    L[#L + 1] = "EXCHANGE"
    local ready, miss = NexusHRExchCheck(ex, have)
    L[#L + 1] = BUL .. "Reward" .. MID .. NexusKMRewards(ex.id)
    L[#L + 1] = BUL .. "Owned" .. MID .. NexusReqName(ex.reward) .. MID .. NexusComma(have[ex.reward] or 0)
    L[#L + 1] = BUL .. "Ready for Exchange" .. MID
        .. (done and "No  -  already exchanged" or (ready and "Yes" or "No"))
    if not done and not ready then
        L[#L + 1] = BUL .. "Missing" .. MID .. table.concat(miss, ", ")
    end
    L[#L + 1] = RULE
    L[#L + 1] = "Status" .. MID .. (done and "Kamutoke already owned"
        or (ready and "All materials ready  -  press the button" or (missN .. " material"
        .. ((missN == 1) and "" or "s") .. " still missing")))
    return table.concat(L, "\n")
end

task.spawn(function()
    task.wait(1.5)
    while NEXUSG.NexusPlayHubSession == SESSION do

      if NexusUiPass("req", NexusReqCh) then
        local c0 = NexusReqChanges
        pcall(function()
            if NexusRctPanel then
                NexusReqRefresh("RCT Requirements", NexusRctPanel, NexusReqExchBuild(
                    "RCTExchange", "RCT",
                    "Reverse Cursed Technique  \194\183  Exchange",
                    "You already have Reverse Cursed Technique."))
            end
            if NexusInfPanel then
                NexusReqRefresh("Infinity Aura Requirements", NexusInfPanel, NexusReqExchBuild(
                    "InfinityAuraExchange", "InfinityAura",
                    "Infinity Aura  \194\183  Exchange",
                    "You already have Infinity Aura."))
            end
            if NexusGatePanel then
                NexusReqRefresh("Lazy Sorcerer Gate Requirements", NexusGatePanel, NexusReqGatesBuild())
            end
            if NexusSGHideoPanel then
                NexusReqRefresh("A Rare Trade Requirements", NexusSGHideoPanel, NexusReqExchBuild(
                    "MerchantHideo1", nil,
                    "A Rare Trade  \194\183  Exchange",
                    "A Rare Trade is already finished."))
            end
            if NexusSGRenPanel then
                NexusReqRefresh("A Little Trade Requirements", NexusSGRenPanel, NexusReqExchBuild(
                    "LittleRen2", nil,
                    "A Little Trade  \194\183  Exchange",
                    "A Little Trade is already finished."))
            end
            if NexusSGGojoPanel then
                NexusReqRefresh("Awaken Limitless Requirements", NexusSGGojoPanel, NexusReqExchBuild(
                    "KidGojoExchange", "AwakenedLimitless",
                    "Awaken Limitless  \194\183  Exchange",
                    "You already have Awakened Limitless."))
            end
            if NexusEvoPanel then
                NexusReqRefresh("Evolution Requirements", NexusEvoPanel, NexusEvoReqBuild())
            end

            if NexusSHRPanel and NexusHRReqBuild then
                NexusReqRefresh("Sorcery Restrictor Requirements", NexusSHRPanel, NexusHRReqBuild("SHR"))
            end
            if NexusPHRPanel and NexusHRReqBuild then
                NexusReqRefresh("Physical Restrictor Requirements", NexusPHRPanel, NexusHRReqBuild("PHR"))
            end

            if NexusKMPanel and NexusKMReqBuild then
                NexusReqRefresh("Raiko Pillar Status", NexusKMPanel, NexusKMReqBuild())
            end
            if NexusKMMonkPanel and NexusKMMonkBuild then
                NexusReqRefresh("High Monk Status", NexusKMMonkPanel, NexusKMMonkBuild())
            end
            if NexusKMKamuPanel and NexusKMKamuBuild then
                NexusReqRefresh("Kamutoke Requirements", NexusKMKamuPanel, NexusKMKamuBuild())
            end
        end)
        pcall(function()
            NexusReqEnforce("RCT Requirements")
            NexusReqEnforce("Infinity Aura Requirements")
            NexusReqEnforce("Lazy Sorcerer Gate Requirements")
            NexusReqEnforce("Evolution Requirements")
            NexusReqEnforce("Sorcery Restrictor Requirements")
            NexusReqEnforce("Physical Restrictor Requirements")
            NexusReqEnforce("Raiko Pillar Status")
            NexusReqEnforce("High Monk Status")
            NexusReqEnforce("Kamutoke Requirements")
        end)
        NexusReqCh = (NexusReqChanges ~= c0)
      end
        task.wait(0.5)
    end
end)

NexusRollM           = { t = 0, ok = false }
NexusRoll1On         = false
NexusRoll10On        = false
NexusRoll100On       = false
NexusClanRollOn      = false
NexusSClanRollOn     = false
NexusClanWL          = {}
NexusSClanWL         = {}
NexusBannerPick      = nil
NexusBannerPulls     = 0
NexusRollLastErr     = nil
NexusClanStatus      = "Idle"
NexusSClanStatus     = "Idle"
NexusClanGot         = nil
NexusSClanGot        = nil
NexusClanTgl         = nil
NexusSClanTgl        = nil
NexusBannerPanel     = nil
NexusClanPanel       = nil
NexusShopPanel       = nil
NexusSClanPanel      = nil
NexusSShopPanel      = nil
NexusClanIdByLabel   = {}
NexusBannerIdByLabel = {}
nxBannerDrop        = nil
NexusBannerSig       = nil

function NexusRollMods()
    local m, now = NexusRollM, os.clock()
    if m.ok and (now - m.t) < 5 then return m end
    m.t = now
    local Ctrl = LocalPlayer:FindFirstChild("PlayerScripts")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Client")
    Ctrl = Ctrl and Ctrl:FindFirstChild("Controllers")
    if Ctrl then pcall(function() m.PD = require(Ctrl.PlayerDataController) end) end
    pcall(function() m.CC = require(RepStorage.Configs.ClanConfig) end)
    pcall(function() m.GC = require(RepStorage.Configs.CTGachaConfig) end)
    pcall(function() m.SC = require(RepStorage.Configs.StatsConfig) end)
    pcall(function() m.Pull  = RepStorage.NetworkComm.CTGachaService.Pull_Method end)
    pcall(function() m.Roll  = RepStorage.NetworkComm.ClanService.RollClan_Method end)
    pcall(function() m.SRoll = RepStorage.NetworkComm.ClanService.RollSpecialClan_Method end)
    m.ok = (m.CC ~= nil and m.GC ~= nil)
    return m
end

function NexusRollStat(name)
    local m = NexusRollMods()
    if not m.PD then return nil end
    local v
    pcall(function()
        local d = m.PD.PlayerData
        if d and d.Stats then v = d.Stats[name] end
    end)
    if v == nil then
        pcall(function()
            local s = m.PD:GetStats()
            if type(s) == "table" then v = s[name] end
        end)
    end
    return v
end

function NexusClanName(id)
    local m, nm = NexusRollMods(), nil
    pcall(function()
        local c = m.CC and m.CC.Clans and m.CC.Clans[id]
        nm = c and c.Name
    end)
    return nm or tostring(id)
end

function NexusClanRarity(id)
    local m, r = NexusRollMods(), nil
    pcall(function()
        local c = m.CC and m.CC.Clans and m.CC.Clans[id]
        r = c and c.Rarity
    end)
    return r
end

function NexusGradeName(r)
    local m, nm = NexusRollMods(), nil
    pcall(function()
        local g = m.SC and m.SC.Grades and m.SC.Grades[r]
        nm = g and g.Name
    end)
    return nm or ("Rarity " .. tostring(r))
end

function NexusBannerLabel(id)
    if not id then return "" end
    local s = (tostring(id):gsub("Banner$", ""))
    s = (s:gsub("(%l)(%u)", "%1 %2"))
    return s
end

function NexusActiveBanners()
    local m = NexusRollMods()
    local out = {}
    if not m.GC then return out end
    pcall(function()
        local tl, now = m.GC.BannerTimeline, os.time()
        if type(tl) ~= "table" then return end
        for i = 1, #tl do
            local e = tl[i]
            if e and e.Duration and e.Duration[2] and e.Duration[2] > now then
                if type(e.BannerIDs) == "table" then
                    for _, id in ipairs(e.BannerIDs) do out[#out + 1] = id end
                end
                return
            end
        end
    end)
    if #out == 0 then
        pcall(function()
            for id in pairs(m.GC.Banners or {}) do out[#out + 1] = id end
            table.sort(out)
        end)
    end
    return out
end

function NexusBannerLabels()
    local ids, labels = NexusActiveBanners(), {}
    NexusBannerIdByLabel = {}
    for _, id in ipairs(ids) do
        local l = NexusBannerLabel(id)
        labels[#labels + 1] = l
        NexusBannerIdByLabel[l] = id
    end
    return labels
end

function NexusBannerSync()
    if not nxBannerDrop then return end
    local ids = NexusActiveBanners()
    local sig = table.concat(ids, "|")
    if sig == NexusBannerSig then return end
    NexusBannerSig = sig
    local labels = NexusBannerLabels()
    pcall(function() nxBannerDrop:Refresh(labels) end)
    local keep = false
    for i = 1, #ids do
        if ids[i] == NexusBannerPick then keep = true break end
    end
    if keep then

        pcall(function() nxBannerDrop:Set(NexusBannerLabel(NexusBannerPick)) end)
    elseif labels[1] then

        NexusBannerPick = NexusBannerIdByLabel[labels[1]]
        Settings["BannerPick"] = NexusBannerPick
        pcall(saveSettings)
        pcall(function() nxBannerDrop:Set(labels[1]) end)
        pcall(function()
            Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Banner rotation changed \226\134\146 now on " .. labels[1], Type = "Info", Duration = 5 })
        end)
    end
end

function NexusClanLabels()
    local m = NexusRollMods()
    local rows = {}
    pcall(function()
        for id, c in pairs(m.CC.Clans or {}) do
            if type(c) == "table" then
                rows[#rows + 1] = { id = id, name = c.Name or id, r = tonumber(c.Rarity) or 0 }
            end
        end
    end)
    table.sort(rows, function(a, b)
        if a.r ~= b.r then return a.r > b.r end
        return a.name < b.name
    end)
    local labels = {}
    NexusClanIdByLabel = {}
    for _, row in ipairs(rows) do
        local l = row.name .. "  \226\128\148  " .. NexusGradeName(row.r)
        labels[#labels + 1] = l
        NexusClanIdByLabel[l] = row.id
    end
    return labels
end

function NexusClanIds(choice)
    local out = {}
    if type(choice) ~= "table" then choice = { choice } end
    for _, l in ipairs(choice) do
        local id = NexusClanIdByLabel[tostring(l)]
        if id then out[#out + 1] = id end
    end
    return out
end

function NexusClanLabelsFor(ids)
    local out = {}
    for _, id in ipairs(ids or {}) do
        for l, cid in pairs(NexusClanIdByLabel) do
            if cid == id then
                out[#out + 1] = l
                break
            end
        end
    end
    return out
end

function NexusBannerAmount()
    if NexusRoll100On then return 100 end
    if NexusRoll10On  then return 10  end
    if NexusRoll1On   then return 1   end
    return nil
end

function NexusBannerTick()
    local n = NexusBannerAmount()
    if not n or not NexusBannerPick then return end
    local m = NexusRollMods()
    if not m.Pull then return end
    local ok = pcall(function() m.Pull:InvokeServer(NexusBannerPick, n) end)
    if ok then NexusBannerPulls = NexusBannerPulls + n end
end

function NexusClanHave(wl)
    local cur = NexusRollStat("Clan")
    if not cur then return nil end
    for _, id in ipairs(wl or {}) do
        if id == cur then return cur end
    end
    return nil
end

function NexusTurnOff(tgl)
    if not tgl then return end
    pcall(function() tgl:Set(false) end)
    pcall(function() tgl:SetValue(false) end)
end

function NexusClanTick(special)
    local on = special and NexusSClanRollOn or NexusClanRollOn
    local wl = special and NexusSClanWL or NexusClanWL
    if not on then
        if special then NexusSClanStatus = "Off" else NexusClanStatus = "Off" end
        return
    end
    if #wl == 0 then
        if special then NexusSClanStatus = "Pick at least one clan to whitelist"
        else NexusClanStatus = "Pick at least one clan to whitelist" end
        return
    end

    local hit = NexusClanHave(wl)
    if hit then
        if special then
            NexusSClanRollOn = false
            NexusSClanGot    = hit
            NexusSClanStatus = "Stopped \226\128\148 you have " .. NexusClanName(hit)
            NexusTurnOff(NexusSClanTgl)
        else
            NexusClanRollOn = false
            NexusClanGot    = hit
            NexusClanStatus = "Stopped \226\128\148 you have " .. NexusClanName(hit)
            NexusTurnOff(NexusClanTgl)
        end
        return
    end
    local left = tonumber(NexusRollStat(special and "SpecialClanRolls" or "ClanRolls")) or 0
    if left < 1 then
        if special then NexusSClanStatus = "Waiting \226\128\148 no special rolls left"
        else NexusClanStatus = "Waiting \226\128\148 no clan rolls left" end
        return
    end
    local m = NexusRollMods()
    local rem = special and m.SRoll or m.Roll
    if not rem then return end
    local ok, res = pcall(function() return rem:InvokeServer(special and true or false) end)
    if not ok then
        if special then NexusSClanStatus = "Retrying after a server error"
        else NexusClanStatus = "Retrying after a server error" end
        return
    end
    local got = (type(res) == "string" and res) or NexusRollStat("Clan")
    if special then
        NexusSClanGot    = got
        NexusSClanStatus = "Rolling..."
    else
        NexusClanGot    = got
        NexusClanStatus = "Rolling..."
    end
end

function NexusBannerText()
    local L = {}
    local ids = NexusActiveBanners()
    L[#L + 1] = "Active Banners"
    if #ids == 0 then
        L[#L + 1] = "\226\128\162  none detected"
    else
        for _, id in ipairs(ids) do
            local mark = (id == NexusBannerPick) and "\226\134\146  " or "\226\128\162  "
            L[#L + 1] = mark .. NexusBannerLabel(id)
        end
    end
    local n = NexusBannerAmount()
    L[#L + 1] = ""
    L[#L + 1] = "Selected \194\183 " .. (NexusBannerPick and NexusBannerLabel(NexusBannerPick) or "none")
    L[#L + 1] = "Rolling  \194\183 " .. (n and ("x" .. n .. " every 0.5s") or "off")
    L[#L + 1] = "Pulled   \194\183 " .. NexusComma(NexusBannerPulls)
    return table.concat(L, "\n")
end

function NexusClanText(special)
    local L    = {}
    local wl   = special and NexusSClanWL or NexusClanWL
    local st   = special and NexusSClanStatus or NexusClanStatus
    local got  = special and NexusSClanGot or NexusClanGot
    local left = tonumber(NexusRollStat(special and "SpecialClanRolls" or "ClanRolls")) or 0
    local cur  = NexusRollStat("Clan")
    L[#L + 1] = "Current Clan \194\183 " .. (cur and (NexusClanName(cur) .. "  (" .. NexusGradeName(NexusClanRarity(cur)) .. ")") or "none")
    L[#L + 1] = (special and "Special Rolls \194\183 " or "Clan Rolls   \194\183 ") .. NexusComma(left)
    L[#L + 1] = ""
    L[#L + 1] = "Whitelist"
    if #wl == 0 then
        L[#L + 1] = "\226\128\162  nothing selected"
    else
        for _, id in ipairs(wl) do
            local mark = (cur == id) and "\226\156\148  " or "\226\128\162  "
            L[#L + 1] = mark .. NexusClanName(id) .. "  \226\128\148  " .. NexusGradeName(NexusClanRarity(id))
        end
    end
    L[#L + 1] = ""
    L[#L + 1] = "Status \194\183 " .. tostring(st)
    if got then L[#L + 1] = "Last   \194\183 " .. NexusClanName(got) end
    return table.concat(L, "\n")
end

function NexusShopText(special)
    local m = NexusRollMods()
    local rows = {}
    pcall(function()
        for _, e in pairs(m.CC.RerollShop or {}) do
            if type(e) == "table" then
                local n = special and e.SpecialRolls or e.Rolls
                if n then rows[#rows + 1] = { p = tonumber(e.Price) or 0, n = tonumber(n) or 0 } end
            end
        end
    end)
    table.sort(rows, function(a, b) return a.p < b.p end)
    local L = {}
    L[#L + 1] = special and "Special Clan Roll Purchases" or "Clan Roll Purchases"
    if #rows == 0 then
        L[#L + 1] = "\226\128\162  none available"
    else
        for _, r in ipairs(rows) do
            local word
            if special then
                word = (r.n == 1) and " Special Roll" or " Special Rolls"
            else
                word = (r.n == 1) and " Roll" or " Rolls"
            end
            L[#L + 1] = "\226\128\162  " .. NexusComma(r.p) .. " Lumen  =  " .. NexusComma(r.n) .. word
        end
    end
    return table.concat(L, "\n")
end

task.spawn(function()
    task.wait(2)
    while NEXUSG.NexusPlayHubSession == SESSION do
        local ok, err = pcall(function()

            if (os.clock() - (NexusBannerSyncT or 0)) >= 2 then
                NexusBannerSyncT = os.clock()
                NexusBannerSync()
            end

            if NexusUiPass("roll", NexusRollCh) then
                local c0 = NexusReqChanges
                if NexusBannerPanel then NexusReqRefresh("Banner Status", NexusBannerPanel, NexusBannerText()) end
                if NexusClanPanel   then NexusReqRefresh("Clan Roll Status", NexusClanPanel, NexusClanText(false)) end
                if NexusShopPanel   then NexusReqRefresh("Clan Roll Shop", NexusShopPanel, NexusShopText(false)) end
                if NexusSClanPanel  then NexusReqRefresh("Special Clan Roll Status", NexusSClanPanel, NexusClanText(true)) end
                if NexusSShopPanel  then NexusReqRefresh("Special Clan Roll Shop", NexusSShopPanel, NexusShopText(true)) end
                NexusReqEnforce("Banner Status")
                NexusReqEnforce("Clan Roll Status")
                NexusReqEnforce("Clan Roll Shop")
                NexusReqEnforce("Special Clan Roll Status")
                NexusReqEnforce("Special Clan Roll Shop")
                NexusRollCh = (NexusReqChanges ~= c0)
            end

            NexusBannerTick()
            NexusClanTick(false)
            NexusClanTick(true)
        end)
        if not ok then NexusRollLastErr = tostring(err) end
        task.wait(0.5)
    end
end)

function NexusAscNPC()
    local npc
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        local sn  = map and map:FindFirstChild("StaticNPCs")
        npc = sn and sn:FindFirstChild("GradeRankUp")
    end)
    return npc
end

function NexusDoAscend()
    if NexusAscBusy then return end
    NexusAscBusy = true
    NexusAscNextAttempt = os.clock() + 3
    task.spawn(function()
        local m = NexusAscMods()
        NexusAscNext()
        local watch  = NexusAscReqCache.needIds or {}
        local before = NexusAscCountMany(watch)

        local hrp  = NexusMyHRP and NexusMyHRP()
        local back = hrp and hrp.CFrame
        local npc  = NexusAscNPC()

        if hrp and npc then
            local ok, pos = pcall(function() return npc:GetPivot().Position end)
            if ok and pos then
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
                end)
                task.wait(0.25)
            end
        end

        local _, stillReady = NexusAscBuild()
        if stillReady then
            pcall(function() m.Rem:InvokeServer() end)
        end

        local done, t0 = false, os.clock()
        while os.clock() - t0 < 2.5 do
            task.wait(0.1)
            local after = NexusAscCountMany(watch)
            for id, v in pairs(before) do
                if (after[id] or 0) < v then done = true break end
            end
            if done then break end
        end

        if hrp and back then pcall(function() hrp.CFrame = back end) end

        NexusAscNextAttempt = os.clock() + (done and 1 or 6)
        NexusAscReqCache.grade = nil
        NexusAscLastText = nil
        NexusAscBusy = false
        NexusAscRefresh()
    end)
end

task.spawn(function()
    task.wait(1.5)
    local lastSafety = 0
    while NEXUSG.NexusPlayHubSession == SESSION do
        local now = os.clock()

        local uc = NexusAscUICache
        if uc and uc.body and uc.body.Parent and uc.body.AbsoluteSize.X ~= uc.w then NexusAscDirty = true end

        NexusAscEnforce()

        if NexusAscDirty or (now - lastSafety) >= 5 then
            NexusAscDirty = false
            lastSafety = now
            NexusAscRefresh()
        end

        if NexusAscOn and NexusAscReady and not NexusAscBusy and now >= NexusAscNextAttempt then
            NexusDoAscend()
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    task.wait(2)
    local m = NexusAscMods()
    for _, sname in ipairs({ "DataChanged", "StatChanged" }) do
        pcall(function()
            local sig = m.PD and m.PD[sname]
            if sig and sig.Connect then
                CONNS[#CONNS + 1] = sig:Connect(function()
                    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
                    NexusAscTouch()
                end)
            end
        end)
    end
end)

local questHoverPos = nil
CONNS[#CONNS+1] = RunService.RenderStepped:Connect(function(dt)
    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
    if not (NexusQuestEngineOn() or AutoGojoOn) then questHoverPos = nil return end
    local mdl = getModel()
    local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if NexusFetchBusy then questHoverPos = nil return end

    local cap = NexusCapInfo()
    if cap.on and cap.pos and not cap.done then
        local ax, ay, az = cap.pos.X, cap.pos.Y, cap.pos.Z
        local anchor = CFrame.new(ax, ay + 4, az)
        local mp = hrp.Position
        local dx, dy, dz = mp.X - ax, mp.Y - ay, mp.Z - az
        local r2 = cap.rad * cap.rad
        if (dx * dx + dy * dy + dz * dz) > r2 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = anchor
            end)
            questHoverPos = anchor
            return
        end
        local n = #questNPCs
        if n > 0 then
            local ring = 0
            for i = 1, n do
                local h = questNPCs[i] and questNPCs[i]:FindFirstChild("HumanoidRootPart")
                if h then
                    local hp = h.Position
                    local ex, ey, ez = hp.X - ax, hp.Y - ay, hp.Z - az
                    if (ex * ex + ey * ey + ez * ez) > r2 then
                        local sx, sy, sz = hp.X - mp.X, hp.Y - mp.Y, hp.Z - mp.Z
                        if (sx * sx + sy * sy + sz * sz) <= (NEXUS_LV.BRING_RANGE * NEXUS_LV.BRING_RANGE) then
                            ring = ring + 1
                            local a = (ring / n) * 6.2831853
                            pcall(function()
                                h.AssemblyLinearVelocity = Vector3.zero
                                h.CFrame = CFrame.new(ax + math.cos(a) * STICK_OFFSET, ay + 3, az + math.sin(a) * STICK_OFFSET)
                            end)
                        end
                    end
                end
            end
        end
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = anchor
        end)
        questHoverPos = anchor
        return
    end

    if #questNPCs == 0 then
        if questHoverPos then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = questHoverPos
            end)
        end
        return
    end

    if NEXUS_LV.FastQuestOn and fastQuestFrozenPos and #questNPCs > 1 then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = fastQuestFrozenPos
        end)
        questHoverPos = fastQuestFrozenPos
        return
    end


    local nearest, nd
    local mp = hrp.Position
    for _, m in ipairs(questNPCs) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h then
            local hp = h.Position
            local dx, dy, dz = hp.X - mp.X, hp.Y - mp.Y, hp.Z - mp.Z
            local d = dx * dx + dy * dy + dz * dz
            if not nd or d < nd then nearest, nd = h, d end
        end
    end
    if nearest then

        NexusStickTo("quest", hrp, nearest)
        questHoverPos = hrp.CFrame
    end
end)

function anyBringActive()
    return NEXUS_LV.BringOn or NEXUS_LV.BringAllOn or BringQuestOn or BringGojoOn or BringRaidNpcOn
end

 NEXUS_LV.questBFtick = 0
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if (NexusQuestEngineOn() or AutoGojoOn) and #questNPCs > 0 and questMyModel and questMyHRP then
            local inRange = {}
            local mp = questMyHRP.Position
            local r2 = NEXUS_LV.ATTACK_RANGE * NEXUS_LV.ATTACK_RANGE
            for _, m in ipairs(questNPCs) do
                local h = m:FindFirstChild("HumanoidRootPart")
                if h then
                    local hp = h.Position
                    local dx, dy, dz = hp.X - mp.X, hp.Y - mp.Y, hp.Z - mp.Z
                    if (dx * dx + dy * dy + dz * dz) <= r2 then inRange[#inRange + 1] = m end
                end
            end
            if #inRange > 0 then
                NEXUS_LV.questBFtick = NEXUS_LV.questBFtick + 1
                if NEXUS_LV.questBFtick % 2 == 0 then
                    enableBlackFlash()
                    NexusQ(pcall, blackFlashList, inRange, questMyModel, questMyHRP)
                else
                    NexusQ(pcall, attackList, inRange, questMyModel, questMyHRP)
                end
            end
        end
        task.wait(math.max(0.02, LOOP_GAP * 0.6))
    end
end)

NoclipOn = false
local noclipCache, noclipModel = {}, nil
 NEXUS_LV.noclipActive = false
CONNS[#CONNS+1] = RunService.Stepped:Connect(function()
    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
    local shouldNoclip = NoclipOn
    if not shouldNoclip then

        if NEXUS_LV.noclipActive then
            for _, e in ipairs(noclipCache) do
                if e.part and e.part.Parent then pcall(function() e.part.CanCollide = e.orig end) end
            end
            NEXUS_LV.noclipActive = false
        end
        return
    end
    local mdl = getModel()
    if not mdl then noclipCache = {} noclipModel = nil NEXUS_LV.noclipActive = false return end
    if mdl ~= noclipModel then
        noclipModel = mdl
        noclipCache = {}
        for _, p in ipairs(mdl:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(noclipCache, { part = p, orig = p.CanCollide }) end
        end
    end

    for _, e in ipairs(noclipCache) do
        if e.part and e.part.Parent and e.part.CanCollide then e.part.CanCollide = false end
    end
    NEXUS_LV.noclipActive = true
end)

local keys = { W=false, A=false, S=false, D=false, Up=false, Down=false }

NEXUS_LV.getBody = function()
    local m = getModel()
    if m then return m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid") end
    return nil, nil
end

NEXUS_LV.stopFly = function()
    flying = false
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end
    local _, hum = NEXUS_LV.getBody()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

NEXUS_LV.startFly = function()
    local hrp, hum = NEXUS_LV.getBody()
    if not hrp then return end
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    bg = Instance.new("BodyGyro")
    bg.P = 9e4 bg.D = 750 bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9) bg.CFrame = hrp.CFrame bg.Parent = hrp
    bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero bv.MaxForce = Vector3.new(9e9, 9e9, 9e9) bv.Parent = hrp
    if hum then pcall(function() hum.PlatformStand = true end) end
    flying = true
end

CONNS[#CONNS+1] = RunService.RenderStepped:Connect(function()
    if NEXUSG.NexusPlayHubSession ~= SESSION then return end
    if not flying then return end
    local hrp, hum = NEXUS_LV.getBody()
    if not hrp then return end
    if not (bv and bv.Parent == hrp) then NEXUS_LV.startFly() return end
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if keys.W then dir = dir + cam.CFrame.LookVector end
    if keys.S then dir = dir - cam.CFrame.LookVector end
    if keys.A then dir = dir - cam.CFrame.RightVector end
    if keys.D then dir = dir + cam.CFrame.RightVector end
    if keys.Up then dir = dir + Vector3.new(0, 1, 0) end
    if keys.Down then dir = dir - Vector3.new(0, 1, 0) end
    if dir.Magnitude == 0 and hum then dir = hum.MoveDirection end
    if dir.Magnitude > 0 then dir = dir.Unit end

    local targetVel = dir * NEXUS_LV.SPEED
    bv.Velocity = bv.Velocity:Lerp(targetVel, 0.25)
    bg.CFrame = bg.CFrame:Lerp(cam.CFrame, 0.35)
end)

CONNS[#CONNS+1] = NEXUS_LV.UserInput.InputEnded:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.W then keys.W = false
    elseif k == Enum.KeyCode.A then keys.A = false
    elseif k == Enum.KeyCode.S then keys.S = false
    elseif k == Enum.KeyCode.D then keys.D = false
    elseif k == Enum.KeyCode.Space then keys.Up = false
    elseif k == Enum.KeyCode.LeftShift then keys.Down = false
    end
end)

CONNS[#CONNS+1] = LocalPlayer.CharacterAdded:Connect(function()
    if flying then task.wait(1) NEXUS_LV.startFly() end
end)

AntiAfkOn   = (AntiAfkOn == nil) and true or AntiAfkOn
AntiTpOn    = (AntiTpOn == nil) and true or AntiTpOn
NexusAllowTp = false

NEXUS_AfkNudges  = 0
NEXUS_AfkMethod  = "-"
NEXUS_AfkBlocked = 0

if not NEXUSG.NexusAfkHook then
    NEXUSG.NexusAfkHook = true
    pcall(function()
        local TPS = game:GetService("TeleportService")
        local AFK_TP = {
            Teleport = true, TeleportAsync = true, TeleportToPlaceInstance = true,
            TeleportToSpawnByName = true, TeleportToPrivateServer = true,
            TeleportPartyAsync = true,
        }
        local mt = getrawmetatable(game)
        local oldNc = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if AntiAfkOn and not NexusAllowTp then
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    local ok, nm = pcall(function() return self.Name end)
                    if ok and type(nm) == "string" and string.find(nm, "TPAFK") then
                        NEXUS_AfkBlocked = NEXUS_AfkBlocked + 1
                        return
                    end
                elseif AFK_TP[method] and self == TPS then
                    NEXUS_AfkBlocked = NEXUS_AfkBlocked + 1
                    return
                end
            end
            return oldNc(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

pcall(function()
    CONNS[#CONNS+1] = LocalPlayer.Idled:Connect(function()
        if NEXUSG.NexusPlayHubSession ~= SESSION then return end
        if not AntiAfkOn then return end
        local ok = pcall(function()
            local VU = game:GetService("VirtualUser")
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
        if ok then
            NEXUS_AfkNudges = NEXUS_AfkNudges + 1
            NEXUS_AfkMethod = "VirtualUser"
        end
    end)
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AntiAfkOn then
            local ok = pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true, Enum.KeyCode.Insert, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.Insert, false, game)
            end)
            if ok then
                NEXUS_AfkNudges = NEXUS_AfkNudges + 1
                if NEXUS_AfkMethod == "-" then NEXUS_AfkMethod = "VirtualInput" end
            end
        end
        task.wait(25)
    end
end)

NEXUS_TP_METHODS = {
    Teleport = 1, TeleportAsync = 1, TeleportToPlaceInstance = 1,
    TeleportToSpawnByName = 1, TeleportToPrivateServer = 1,
    TeleportPartyAsync = 1,
    Kick = 3,

    FireServer = 2, InvokeServer = 2,
}
NEXUS_NameMemo = {}

NEXUS_TpInstMemo = setmetatable({}, { __mode = "k" })
NEXUS_TP_NAMES = {
    "rejoin", "serverhop", "changeserver", "switchserver", "newserver",
    "teleporttoplace", "teleportgame", "teleportplayer", "sendtogame",
    "lobbyteleport", "gotolobby", "returntolobby", "kickplayer",
    "afkkick", "idlekick", "kickidle", "idletimeout", "afktimeout",
}
function NEXUS_IsBlockedName(n)
    local memo = NEXUS_NameMemo[n]
    if memo ~= nil then return memo end
    local clean = string.gsub(string.lower(tostring(n)), "[^a-z]", "")
    local hit = false
    for _, bad in ipairs(NEXUS_TP_NAMES) do
        if string.find(clean, bad, 1, true) then hit = true break end
    end
    NEXUS_NameMemo[n] = hit
    return hit
end

if not NEXUSG.NexusTpGuard then
    NEXUSG.NexusTpGuard = true

    pcall(function()
        local TS = game:GetService("TeleportService")
        for _, name in ipairs({ "Teleport", "TeleportAsync", "TeleportToPlaceInstance",
                                "TeleportToSpawnByName", "TeleportToPrivateServer",
                                "TeleportPartyAsync" }) do
            pcall(function()
                local original = TS[name]
                if type(original) ~= "function" or not hookfunction then return end
                local hooked
                hooked = hookfunction(original, function(...)
                    if AntiTpOn and not NexusAllowTp then
                        warn("[NEXUSPLAY HUB] blocked TeleportService:" .. name .. " (Anti Teleport ON)")
                        return nil
                    end
                    return hooked(...)
                end)
            end)
        end
    end)

    pcall(function()
        if not hookmetamethod then return end
        local oldNC
        oldNC = hookmetamethod(game, "__namecall", function(self, ...)

            local guardTp = AntiTpOn and not NexusAllowTp
            if guardTp or AntiAfkOn then
                local kind = NEXUS_TP_METHODS[getnamecallmethod()]
                if kind == 3 and not NexusAllowTp then

                    return nil
                elseif guardTp then
                    if kind == 1 then
                        return nil
                    elseif kind == 2 then
                        local v = NEXUS_TpInstMemo[self]
                        if v == nil then
                            v = NEXUS_IsBlockedName(self.Name) and true or false
                            NEXUS_TpInstMemo[self] = v
                        end
                        if v then return nil end
                    end
                end
            end
            return oldNC(self, ...)
        end)
    end)

    pcall(function()
        if not getconnections then return end

        NEXUS_TpSeen = NEXUS_TpSeen or {}
        NexusPruneRegister(function() return NEXUS_TpSeen end)
        local function nexusGuardRemote(d)
            if NEXUS_TpSeen[d] then return end
            if not (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then return end
            if not NEXUS_IsBlockedName(d.Name) then return end
            NEXUS_TpSeen[d] = true
            local sig = d:IsA("RemoteEvent") and d.OnClientEvent or d.OnClientInvoke
            pcall(function()
                for _, c in ipairs(getconnections(sig)) do pcall(function() c:Disable() end) end
            end)
        end
        for _, root in ipairs({ RepStorage, game:GetService("ReplicatedFirst") }) do
            if root then
                for _, d in ipairs(root:GetDescendants()) do pcall(nexusGuardRemote, d) end
                CONNS[#CONNS+1] = root.DescendantAdded:Connect(function(d)
                    if AntiTpOn then pcall(nexusGuardRemote, d) end
                end)
            end
        end
    end)
end

 NEXUS_LV.AutoChestOn = false
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NEXUS_LV.AutoChestOn and lastChestArgs then
            pcall(function() NEXUS_LV.UseItem:InvokeServer(table.unpack(lastChestArgs, 1, lastChestArgs.n)) end)
            task.wait(0.1)
        else
            task.wait(0.2)
        end
    end
end)

RAID_ISLAND_RADIUS = 350

function nexusPadHold(pos, frames)
    if not pos then return end

    local cf = CFrame.new(pos)
    for _ = 1, (frames or 6) do
        local m = getModel()
        local h = m and m:FindFirstChild("HumanoidRootPart")
        if h then
            pcall(function()
                h.AssemblyLinearVelocity = Vector3.zero
                h.AssemblyAngularVelocity = Vector3.zero
                local p = h.Position
                local dx, dy, dz = p.X - pos.X, p.Y - pos.Y, p.Z - pos.Z
                if (dx * dx + dy * dy + dz * dz) > 0.01 then h.CFrame = cf end
            end)
        end
        task.wait()
    end
end

function findNearestTaggedBoss(tag, filter)
    local ClientF = Characters:FindFirstChild("Client")
    if not ClientF then return nil end
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    local tagList = tag
    if type(tagList) ~= "table" then tagList = { tag } end
    local wordSets = {}
    for _, tg in ipairs(tagList) do wordSets[#wordSets + 1] = nexusWordsOfCached(tg) end
    local function tagHit(txt)
        for _, ws in ipairs(wordSets) do
            if nexusTextMatchesWords(txt, ws) then return true end
        end
        return false
    end
    local bossPos, bestTagD
    for _, d in ipairs(clientLabels(ClientF)) do
        if d:IsA("TextLabel") and tagHit(d.Text) then
            local rig = d:FindFirstAncestorWhichIsA("Model")
            local h = rig and rig:FindFirstChild("HumanoidRootPart")
            if h then
                if myHRP then

                    local dd = (h.Position - myHRP.Position).Magnitude
                    if dd <= RAID_ISLAND_RADIUS and onMyIsland(h.Position)
                        and (not filter or filter(h.Position))
                        and (not bestTagD or dd < bestTagD) then
                        bossPos, bestTagD = h.Position, dd
                    end
                elseif (not filter or filter(h.Position)) and not bossPos then
                    bossPos = h.Position
                end
            end
        end
    end
    if not bossPos then return nil end

    if NPCsF then
        local best, bestD
        for _, m in ipairs(NPCsF:GetChildren()) do
            local h, hum = nexusRig(m)
            if h and hum and hum.Health > 0 and nexusValidNpc(m)
                and (not filter or filter(h.Position)) then
                local dd = (h.Position - bossPos).Magnitude
                if dd < 25 and (not bestD or dd < bestD) then best, bestD = m, dd end
            end
        end
        if best then return best, best:FindFirstChild("HumanoidRootPart") end
    end
    return nil
end

 NEXUS_LV.AutoRaidOn = false
 NEXUS_LV.CreateIslandQueue = Net.BossIslandService.CreateIslandQueue_Method
 NEXUS_LV.RetryRaid         = Net.BossIslandService.Retry_Method

NexusReturnRaid = Net.BossIslandService.Return_Method

NexusAdvanceSiege = nil
pcall(function() NexusAdvanceSiege = Net.BossIslandService.AdvanceNextSiegeSection_Signal end)
SIEGE_ADVANCE_SEC = 60
SIEGE_DOOR_WAIT = 8
function nexusSiegeHasDoor()
    return nexusSiegePromptPart() ~= nil
end
function nexusSiegeAdvance()
    if not NexusAdvanceSiege then return false end
    return (pcall(function() NexusAdvanceSiege:FireServer() end))
end
function nexusSiegeCtrl()
    local ctrl
    pcall(function()
        local lp = LocalPlayer
        local ps = lp and lp:FindFirstChild("PlayerScripts")
        local cl = ps and ps:FindFirstChild("Client")
        local co = cl and cl:FindFirstChild("Controllers")
        local md = co and co:FindFirstChild("BossIslandController")
        if md then ctrl = require(md) end
    end)
    if type(ctrl) == "table" then return ctrl end
    return nil
end

function nexusSiegePromptPart()
    local ctrl = nexusSiegeCtrl()
    if not ctrl then return nil end
    local part
    pcall(function()
        local act = ctrl.ActiveIsland
        if act then
            local p = act.AdvanceNextMapPrompt
            if typeof(p) == "Instance" then part = p end
        end
    end)
    return part
end

function nexusSiegePromptPos(inst)
    if typeof(inst) ~= "Instance" then return nil end
    local pos
    pcall(function()
        if inst:IsA("BasePart") then
            pos = inst.Position
        elseif inst:IsA("Attachment") then
            pos = inst.WorldPosition
        elseif inst:IsA("Model") then
            pos = inst:GetPivot().Position
        end
    end)
    if not pos then pcall(function() pos = inst.Position end) end
    if not pos then pcall(function() pos = inst.WorldPosition end) end
    if not pos then pcall(function() pos = inst.CFrame.Position end) end
    if typeof(pos) == "Vector3" then return pos end
    return nil
end

function nexusInteractHandler()
    local h
    pcall(function()
        local lp = LocalPlayer
        local ps = lp and lp:FindFirstChild("PlayerScripts")
        local cl = ps and ps:FindFirstChild("Client")
        local co = cl and cl:FindFirstChild("Controllers")
        local md = co and co:FindFirstChild("InterfaceController")
        if md then
            local ic = require(md)
            h = ic:GetInterfaceHandler("Interact")
        end
    end)
    if type(h) == "table" then return h end
    return nil
end

function nexusFirePrompt(pr)
    if not pr then return false end
    pcall(function() pr.Enabled = true end)
    pcall(function() pr.HoldDuration = 0 end)
    pcall(function()
        if pr.MaxActivationDistance < 200 then pr.MaxActivationDistance = 200 end
    end)
    local fired = false
    local h = nexusInteractHandler()
    if h and type(h.Interacted) == "table" then
        fired = pcall(function() h.Interacted:Fire(pr) end)
    end
    if not fired and type(fireproximityprompt) == "function" then
        fired = pcall(fireproximityprompt, pr)
    end
    if not fired then
        fired = pcall(function()
            pr:InputHoldBegin()
            task.wait(0.12)
            pr:InputHoldEnd()
        end)
    end
    return fired
end

function nexusFindAdvancePrompt(root)
    local part = nexusSiegePromptPart()
    local pr
    if part then
        pcall(function() pr = part:FindFirstChildWhichIsA("ProximityPrompt", true) end)
        if pr then return pr, part end
    end
    local scan = {}
    if part then scan[#scan + 1] = part end
    if root and root.Parent then scan[#scan + 1] = root end
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        local geo = map and map:FindFirstChild("Geometry")
        local f = geo and geo:FindFirstChild("BossIslands")
        if f then scan[#scan + 1] = f end
    end)
    for _, r in ipairs(scan) do
        pcall(function()
            for _, d in ipairs(r:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local txt = string.lower(tostring(d.ActionText) .. " " .. tostring(d.ObjectText))
                    if string.find(txt, "advance", 1, true) or string.find(txt, "next", 1, true) then
                        pr = d
                        break
                    end
                end
            end
        end)
        if pr then break end
    end
    if pr then
        local hp = pr.Parent
        if hp then return pr, hp end
    end
    return pr, part
end

function nexusSiegeDoorHop(root)
    local pr, part = nexusFindAdvancePrompt(root)
    local pos = nexusSiegePromptPos(part) or nexusSiegePromptPos(pr and pr.Parent)
    if pos then
        pcall(function() nexusPadHold(pos + Vector3.new(0, 3, 0), 2) end)
    end
    if not pr then return false end
    if nexusFirePrompt(pr) then return true end
    return false
end

local RaidCfg = {
    difficulty = 5,
    map = { Easy = 1, Normal = 2, Hard = 3, Nightmare = 4, Calamity = 5 },
    active = { AGojo = false },
}
STAR_PAD_LIFT = 3.5
function starRageTopPos(inst)

    if not inst then return nil end
    local part = inst
    if not inst:IsA("BasePart") then
        part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return nil end
    return part.Position + Vector3.new(0, (part.Size.Y / 2) + STAR_PAD_LIFT, 0)
end

NEXUS_CLICK_SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }

NEXUS_BTN_TXT = setmetatable({}, { __mode = "k" })
function nexusButtonText(d)
    local now = os.clock()
    local c = NEXUS_BTN_TXT[d]
    if c and (now - c.t) < 0.5 then return c.s end
    local txt = ""
    if d:IsA("TextButton") then txt = d.Text or "" end
    if txt == "" then
        for _, k in ipairs(d:GetDescendants()) do
            if k:IsA("TextLabel") then
                local t = k.Text
                if t and t ~= "" then txt = txt .. " " .. t end
            end
        end
    end
    txt = string.lower(txt)
    NEXUS_BTN_TXT[d] = { s = txt, t = now }
    return txt
end

function clickPopups(...)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local kws, n = { ... }, select("#", ...)
    for i = 1, n do kws[i] = string.lower(tostring(kws[i] or "")) end
    local clicked = false
    for _, d in ipairs(pg:GetDescendants()) do
        local hit = false
        if d:IsA("GuiButton") and d.Visible then
            local txt = nexusButtonText(d)
            for i = 1, n do
                if kws[i] ~= "" and string.find(txt, kws[i], 1, true)
                    and not (kws[i] == "retry" and string.find(txt, "auto", 1, true)) then
                    hit = true
                    break
                end
            end
        end
        if hit then
            for _, sname in ipairs(NEXUS_CLICK_SIGNALS) do
                pcall(function()
                    if getconnections then
                        for _, cn in ipairs(getconnections(d[sname])) do
                            pcall(function() cn:Fire() end)
                        end
                    end
                end)
            end
            pcall(function() firesignal(d.MouseButton1Click) end)
            clicked = true
        end
    end
    return clicked
end
local function clickPopup(keyword) return clickPopups(keyword) end

function nexusSettingsCtrl()
    local ctrl
    pcall(function()
        local lp = LocalPlayer
        local ps = lp and lp:FindFirstChild("PlayerScripts")
        local cl = ps and ps:FindFirstChild("Client")
        local co = cl and cl:FindFirstChild("Controllers")
        local md = co and co:FindFirstChild("SettingsController")
        if md then ctrl = require(md) end
    end)
    if type(ctrl) == "table" then return ctrl end
    return nil
end

NEXUS_NATIVE_RETRY_T = 0
function nexusNativeAutoRetry()
    if (os.clock() - NEXUS_NATIVE_RETRY_T) < 15 then return end
    NEXUS_NATIVE_RETRY_T = os.clock()
    pcall(function()
        local sc = nexusSettingsCtrl()
        if not sc or type(sc.SetSetting) ~= "function" then return end
        if tonumber(sc:GetSetting("AUTO_RETRY_RAID")) ~= 1 then
            sc:SetSetting("AUTO_RETRY_RAID", 1)
        end
    end)
end

function nexusRaidRetryNow()
    clickPopups("next", "close")
    nexusNativeAutoRetry()
    local pressed = clickPopups("retry")
    if not pressed then pressed = clickPopups("confirm", "claim") end
    pcall(function() NEXUS_LV.RetryRaid:InvokeServer() end)
    return pressed
end

RAID_PAD_RADIUS  = 10
RAID_OUTSIDE_SEC = 2
RAID_STALL_SEC   = 12
INF_STUCK_SEC    = 25

RAID_QUEUE_GAP   = 1
RAID_ISLE_MARGIN = 80

RaidZonesCache = RaidZonesCache or { folder = nil }
function nexusQueueZones()
    local f = RaidZonesCache.folder
    if f and f.Parent then return f end
    f = workspace:FindFirstChild("QueueZones")
    if not f then
        local map = workspace:FindFirstChild("Map")
        f = map and map:FindFirstChild("QueueZones")
        if not f and map then f = map:FindFirstChild("QueueZones", true) end
    end
    if not f then f = workspace:FindFirstChild("QueueZones", true) end
    RaidZonesCache.folder = f
    return f
end

function nexusRaidPadPos(p)
    if not p then return nil end
    local pos = starRageTopPos(p)
    if pos then return pos end
    local part = p:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position + Vector3.new(0, (part.Size.Y / 2) + STAR_PAD_LIFT, 0) end
    local ok, cf, size = pcall(function() return p:GetBoundingBox() end)
    if ok and cf and size then return cf.Position + Vector3.new(0, (size.Y / 2) + STAR_PAD_LIFT, 0) end
    local att = p:FindFirstChildWhichIsA("Attachment", true)
    if att then
        local ok2, wp = pcall(function() return att.WorldPosition end)
        if ok2 and wp then return wp + Vector3.new(0, STAR_PAD_LIFT, 0) end
    end
    return nil
end
function nexusRaidMyPos()
    local m = getModel()
    local h = m and m:FindFirstChild("HumanoidRootPart")
    if not h then return nil end
    return h.Position
end

function nexusRaidDiff(cfg)
    local d = cfg.difficulty or RaidCfg.difficulty or 5
    if cfg.maxDifficulty and d > cfg.maxDifficulty then d = cfg.maxDifficulty end
    if d < 1 then d = 1 end
    return d
end

NEXUS_RAID_REG = NEXUS_RAID_REG or {}

function nexusRaidEngine(cfg)
    NEXUS_RAID_REG[#NEXUS_RAID_REG + 1] = cfg
    local pad, lblSrc, lblDur, lblCnt = nil, nil, nil, nil
    local isleT, isleList, queueT = -1, {}, 0
    local isleFolder, isleNeedles = nil, nil
    local padMissT, lblMissT = -1, -1
    local myIsle = nil
    local isOn = cfg.isOn

    local function getPad()
        if pad and pad.Parent then return pad end
        pad = nil
        local pnow = os.clock()
        if padMissT >= 0 and (pnow - padMissT) < 1 then return nil end
        local qz = nexusQueueZones()
        if not qz then padMissT = pnow return nil end
        for _, nm in ipairs(cfg.zones) do
            local f = qz:FindFirstChild(nm) or qz:FindFirstChild(nm, true)
            if f then pad = f break end
        end
        if not pad then
            for _, d in ipairs(qz:GetChildren()) do
                local ln = string.lower(d.Name)
                for _, nm in ipairs(cfg.zones) do
                    if string.find(ln, string.lower(nm), 1, true) then pad = d break end
                end
                if pad then break end
            end
        end
        if pad then padMissT = -1 else padMissT = pnow end
        return pad
    end

    local function padInfo(p)
        p = p or getPad()
        if not p then return nil, nil, nil end
        local inow = os.clock()
        if lblSrc ~= p or not (lblDur and lblDur.Parent) then
            if lblSrc == p and lblMissT >= 0 and (inow - lblMissT) < 1 then

            else
                lblSrc, lblDur, lblCnt = p, nil, nil

                pcall(function()
                    for _, d in ipairs(p:GetDescendants()) do
                        if d:IsA("TextLabel") then
                            local n = string.lower(d.Name)
                            if n == "duration" then lblDur = d
                            elseif n == "playercount" then lblCnt = d end
                        end
                    end
                end)
                if lblDur and lblDur.Parent then lblMissT = -1 else lblMissT = inow end
            end
        end
        local txt = (lblDur and lblDur.Parent) and lblDur.Text or nil
        local secs
        if txt then
            local low = string.lower(txt)
            local n = string.match(low, "(%d+)%s*second") or string.match(low, "starting in%s*(%d+)")
            secs = n and tonumber(n) or nil
        end
        return txt, secs, ((lblCnt and lblCnt.Parent) and lblCnt.Text or nil)
    end

    local function isles()
        local now = os.clock()
        if isleT >= 0 and (now - isleT) < 2 then return isleList end
        local list = {}
        local folder = isleFolder
        if not (folder and folder.Parent) then
            local map = workspace:FindFirstChild("Map")
            local geo = map and map:FindFirstChild("Geometry")
            folder = geo and geo:FindFirstChild("BossIslands")
            if not folder then folder = workspace:FindFirstChild("BossIslands", true) end
            isleFolder = folder
        end
        if not isleNeedles then
            local nd = {}
            for _, nm in ipairs(cfg.isles or {}) do
                local t = string.lower(nm)
                nd[#nd + 1] = { t = t, tN = (string.gsub(t, "[^%a]", "")) }
            end
            isleNeedles = nd
        end
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") then
                    local ln = string.lower(m.Name)
                    local lnN = string.gsub(ln, "[^%a]", "")
                    local hit = false
                    for _, nd in ipairs(isleNeedles) do
                        local t, tN = nd.t, nd.tN
                        if string.find(ln, t, 1, true) then
                            hit = true
                            break
                        elseif tN ~= "" and lnN ~= "" and
                            (string.find(lnN, tN, 1, true) or string.find(tN, lnN, 1, true)) then
                            hit = true
                            break
                        end
                    end
                    if hit then
                        local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
                        if ok and cf and size then
                            list[#list + 1] = {
                                model  = m,
                                cf     = cf,
                                center = cf.Position,
                                half   = (size * 0.5) + Vector3.new(RAID_ISLE_MARGIN, RAID_ISLE_MARGIN, RAID_ISLE_MARGIN),
                            }
                        end
                    end
                end
            end
        end
        isleList, isleT = list, now
        return list
    end
    local function hasIsles()
        return #isles() > 0
    end
    local function inIsle(pos)
        if not pos then return false end
        for _, isl in ipairs(isles()) do
            local rel = isl.cf:PointToObjectSpace(pos)
            if math.abs(rel.X) <= isl.half.X and math.abs(rel.Y) <= isl.half.Y and math.abs(rel.Z) <= isl.half.Z then
                return true
            end
        end
        return false
    end

    local function isleOf(pos)
        if not pos then return nil end
        for _, isl in ipairs(isles()) do
            local rel = isl.cf:PointToObjectSpace(pos)
            if math.abs(rel.X) <= isl.half.X and math.abs(rel.Y) <= isl.half.Y and math.abs(rel.Z) <= isl.half.Z then
                return isl
            end
        end
        return nil
    end
    local function lockIsle()
        local isl = isleOf(nexusRaidMyPos())
        if isl then myIsle = isl.model end
        return myIsle
    end
    local function clearIsle() myIsle = nil end

    local function inMyIsle(pos)
        if not pos then return false end
        if #isles() == 0 then return true end
        if myIsle and myIsle.Parent then
            for _, isl in ipairs(isles()) do
                if isl.model == myIsle then
                    local rel = isl.cf:PointToObjectSpace(pos)
                    return math.abs(rel.X) <= isl.half.X
                        and math.abs(rel.Y) <= isl.half.Y
                        and math.abs(rel.Z) <= isl.half.Z
                end
            end
        end
        myIsle = nil
        return inIsle(pos)
    end

    local function land()
        local pos = nexusRaidMyPos()
        local best, bestD
        for _, isl in ipairs(isles()) do
            local d = pos and (isl.center - pos).Magnitude or 0
            if not bestD or d < bestD then best, bestD = isl, d end
        end
        if not best then return false end
        myIsle = best.model
        nexusPadHold(best.center + Vector3.new(0, best.half.Y * 0.35, 0), 4)
        lockIsle()
        return true
    end
    local function findBoss()

        if not (myIsle and myIsle.Parent) then lockIsle() end
        return findNearestTaggedBoss(cfg.tag, inMyIsle)
    end

    local function doQueue(force)
        local now = os.clock()
        if not force and (now - queueT) < RAID_QUEUE_GAP then return false end
        queueT = now
        clearIsle()
        pcall(function()
            NEXUS_LV.CreateIslandQueue:InvokeServer({

                Difficulty = nexusRaidDiff(cfg),
                ConfigID = cfg.config,
                Modifiers = {},
            })
        end)
        return true
    end

    task.spawn(function()

      while NEXUSG.NexusPlayHubSession == SESSION do
        local ok, err = pcall(function()
        local inThis = false
        local outsideT = nil
        local stallT = os.clock()
        local sawBoss = false
        local sawSiegeBoss = false
        local hardT = os.clock()
        while NEXUSG.NexusPlayHubSession == SESSION do
            if not isOn() then
                inThis, outsideT = false, nil
                clearIsle()
                stallT = os.clock()
                sawBoss, hardT = false, os.clock()
                sawSiegeBoss = false
                NexusInfReturning = false
                task.wait(NEXUS_IDLE)
            else
                local mdl = getModel()
                local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    task.wait(0.1)
                else
                    local boss, bh = findBoss()
                    if boss and bh then

                        inThis, outsideT = true, nil
                        stallT = os.clock()
                        sawBoss, hardT = true, os.clock()
                        local bossChkT = 0
                        if cfg.bossTag and findNearestTaggedBoss(cfg.bossTag, inMyIsle) then sawSiegeBoss = true end
                        while isOn() and NEXUSG.NexusPlayHubSession == SESSION do
                            boss, bh = findBoss()
                            if not (boss and bh) then break end
                            if cfg.bossTag and not sawSiegeBoss and (os.clock() - bossChkT) >= 1 then
                                bossChkT = os.clock()
                                if findNearestTaggedBoss(cfg.bossTag, inMyIsle) then sawSiegeBoss = true end
                            end
                            local cur = getModel()
                            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
                            if chrp then
                                if BringRaidNpcOn then
                                    pcall(function()
                                        chrp.AssemblyLinearVelocity = Vector3.zero
                                        bh.AssemblyLinearVelocity = Vector3.zero
                                        NexusBringPlace(bh, chrp.Position + Vector3.new(BRING_OFFSET, 0, 0))
                                    end)
                                else
                                    pcall(function()
                                        chrp.AssemblyLinearVelocity = Vector3.zero
                                        chrp.CFrame = auraGoal(bh)
                                    end)
                                end

                                enableBlackFlash()
                                NexusQ(pcall, blackFlashList, {boss}, cur, chrp)
                                NexusQ(pcall, attackList, {boss}, cur, chrp)
                            end
                            task.wait(0.05)
                        end
                        stallT = os.clock()
                    elseif inThis then

                        clickPopup("next"); clickPopup("close")
                        local siegeAdvanced = false
                        if cfg.siege then
                            local advT, adv0 = 0, os.clock()
                            local sawDoor = false
                            while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - adv0) < SIEGE_ADVANCE_SEC do
                                if findBoss() then siegeAdvanced = true break end
                                if hasIsles() and not inIsle(nexusRaidMyPos()) then break end
                                if nexusSiegeHasDoor() then
                                    sawDoor = true
                                    if (os.clock() - advT) >= 0.5 then
                                        advT = os.clock()
                                        clickPopups("next", "close", "advance", "continue", "enter")
                                        if not nexusSiegeDoorHop(myIsle) then nexusSiegeAdvance() end
                                    end
                                elseif sawDoor then
                                    siegeAdvanced = true
                                    break
                                elseif (os.clock() - adv0) > SIEGE_DOOR_WAIT then
                                    break
                                end
                                task.wait(LOOP_GAP)
                            end
                        end
                        if siegeAdvanced then
                            stallT = os.clock()
                            sawBoss, hardT = true, os.clock()
                        elseif cfg.infinite then

                        NexusInfReturning = true
                        pcall(function() NexusReturnRaid:InvokeServer() end)
                        clearIsle()
                        local tR, lastR = os.clock(), os.clock()
                        while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - tR) < 8 do

                            if getPad() or not inIsle(nexusRaidMyPos()) then break end
                            if (os.clock() - lastR) >= 0.5 then
                                clickPopups("next", "close")
                                pcall(function() NexusReturnRaid:InvokeServer() end)
                                lastR = os.clock()
                            end
                            task.wait(LOOP_GAP)
                        end
                        NexusInfReturning = false
                        inThis, outsideT = false, nil
                        stallT = os.clock()
                        sawBoss, hardT = false, os.clock()
                        doQueue(true)
                        else
                        sawSiegeBoss = false
                        nexusRaidRetryNow()
                        local t0, lastRetry = os.clock(), os.clock()
                        while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t0) < (cfg.siege and 14 or 6) do
                            if findBoss() then break end
                            if (os.clock() - lastRetry) >= 0.25 then
                                nexusRaidRetryNow()
                                lastRetry = os.clock()
                            end

                            if hasIsles() and not inIsle(nexusRaidMyPos()) then
                                if not outsideT then
                                    outsideT = os.clock()
                                elseif (os.clock() - outsideT) >= RAID_OUTSIDE_SEC then
                                    break
                                end
                            else
                                outsideT = nil
                            end
                            task.wait(LOOP_GAP)
                        end
                        if not findBoss() then
                            inThis, outsideT = false, nil
                            stallT = os.clock()
                            if not getPad() then
                                pcall(function() NexusReturnRaid:InvokeServer() end)
                            end
                            if cfg.siege then
                                clearIsle()
                                doQueue(true)
                                local tS = os.clock()
                                while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - tS) < 12 do
                                    if findBoss() or nexusSiegeHasDoor() then break end
                                    if getPad() then break end
                                    clickPopups("next", "close", "confirm", "start")
                                    nexusRaidRetryNow()
                                    if (os.clock() - tS) > 4 then doQueue(true) end
                                    if (os.clock() - tS) > 7 then
                                        pcall(function() NexusReturnRaid:InvokeServer() end)
                                    end
                                    task.wait(0.35)
                                end
                                stallT = os.clock()
                                hardT = os.clock()
                            end
                        end
                        end
                    else
                        local p = getPad()
                        if p then

                            hardT = os.clock()
                            local padPos = nexusRaidPadPos(p)
                            if padPos then nexusPadHold(padPos, 6) end
                            doQueue()
                            padPos = nexusRaidPadPos(p) or padPos
                            if padPos then nexusPadHold(padPos, 4) end
                            local t0, lastTp = os.clock(), 0
                            while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t0) < 30 do
                                if findBoss() then break end
                                if not (p and p.Parent) then break end
                                padPos = nexusRaidPadPos(p) or padPos
                                local _, secs = padInfo(p)

                                local me = nexusRaidMyPos()
                                if padPos and ((not me) or (me - padPos).Magnitude > RAID_PAD_RADIUS) then
                                    nexusPadHold(padPos, 2)
                                elseif padPos and (os.clock() - lastTp) >= 0.25 then
                                    lastTp = os.clock()
                                    nexusPadHold(padPos, 1)
                                end
                                if secs and secs <= 0 then break end
                                if hasIsles() and inIsle(nexusRaidMyPos()) then break end
                                task.wait(0.05)
                            end

                            local t1 = os.clock()
                            outsideT = nil
                            while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t1) < 8 do
                                if findBoss() then break end
                                if hasIsles() then
                                    if inIsle(nexusRaidMyPos()) then
                                        outsideT = nil
                                    else
                                        if not outsideT then
                                            outsideT = os.clock()
                                        elseif (os.clock() - outsideT) >= RAID_OUTSIDE_SEC then
                                            outsideT = nil
                                            land()
                                        end
                                    end
                                elseif getPad() and (os.clock() - t1) > 2 then
                                    break
                                end
                                task.wait(0.1)
                            end
                            stallT = os.clock()
                        else
                            local me = nexusRaidMyPos()
                            if hasIsles() and inIsle(me) then

                                clickPopup("next"); clickPopup("close")
                                if cfg.infinite then

                                    if sawBoss or (os.clock() - stallT) >= RAID_STALL_SEC then
                                        NexusInfReturning = true
                                        pcall(function() NexusReturnRaid:InvokeServer() end)
                                        clearIsle()
                                        sawBoss = false
                                        hardT = os.clock()
                                    end
                                else
                                    nexusRaidRetryNow()
                                end
                                local t2 = os.clock()
                                while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t2) < 3 do
                                    if findBoss() then break end
                                    if hasIsles() and not inIsle(nexusRaidMyPos()) then break end
                                    task.wait(LOOP_GAP)
                                end
                                if cfg.infinite then NexusInfReturning = false end
                                if not findBoss() and (os.clock() - stallT) >= RAID_STALL_SEC then
                                    stallT = os.clock()
                                    hardT = os.clock()
                                    doQueue(true)
                                end
                            elseif hasIsles() and me then

                                if not outsideT then outsideT = os.clock() end
                                if (os.clock() - outsideT) < RAID_OUTSIDE_SEC then
                                    task.wait(0.1)
                                else
                                    outsideT = nil
                                    stallT = os.clock()
                                    doQueue(true)
                                    task.wait(0.25)
                                end
                            else

                                outsideT = nil
                                local skip = false
                                if cfg.infinite then

                                    if (os.clock() - hardT) >= INF_STUCK_SEC then
                                        hardT = os.clock()
                                        NexusInfReturning = false
                                        sawBoss = false
                                        clearIsle()
                                        clickPopups("next", "close")
                                        pcall(function() NexusReturnRaid:InvokeServer() end)
                                        task.wait(0.5)
                                        doQueue(true)
                                        skip = true
                                    end

                                    if not skip then
                                        local okW, isOpen = pcall(nexusInfWindow)
                                        if okW and isOpen == false then
                                            hardT = os.clock()
                                            skip = true
                                            task.wait(1)
                                        end
                                    end
                                end
                                if not skip then
                                doQueue()

                                local t2 = os.clock()
                                while isOn() and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t2) < 4 do
                                    local np = getPad()
                                    if np then
                                        local npp = nexusRaidPadPos(np)
                                        if npp then nexusPadHold(npp, 4) end
                                        break
                                    end
                                    if findBoss() then break end
                                    task.wait(0.05)
                                end
                                stallT = os.clock()
                                end
                            end
                        end
                    end
                end
            end
        end
        end)
        if not ok then
            NexusRaidLastErr = tostring(err)
            clearIsle()
            task.wait(0.5)
        end
      end
    end)

    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            if isOn() then
                clickPopup("next")
                clickPopup("close")
                nexusNativeAutoRetry()
            end
            task.wait(isOn() and 0.3 or NEXUS_IDLE)
        end
    end)
end

nexusRaidEngine({
    zones  = { "StarRage", "StarRageRaid" },
    config = "StarRage",
    tag    = "yuki",
    isles  = { "starrage" },
    isOn   = function() return NEXUS_LV.AutoRaidOn end,
})

local AutoBloodRaidOn = false
nexusRaidEngine({
    zones  = { "Choso" },
    config = "Choso",
    tag    = "choso",
    isles  = { "choso" },
    isOn   = function() return AutoBloodRaidOn end,
})

AutoLightningRaidOn = false
nexusRaidEngine({
    zones  = { "AKashimo" },
    config = "AKashimo",
    tag    = "awakened lightning god",
    isles  = { "akashimo", "lightning" },
    isOn   = function() return AutoLightningRaidOn end,
})

AutoYutaRaidOn = false
nexusRaidEngine({
    zones  = { "Yuta" },
    config = "Yuta",
    tag    = "cursed prodigy",
    isles  = { "yuta" },
    isOn   = function() return AutoYutaRaidOn end,
})

function makeIslandRaid(key, zoneName, configID, bossTag)
    nexusRaidEngine({
        zones  = { zoneName },
        config = configID,
        tag    = bossTag,
        isles  = { configID, zoneName },
        isOn   = function() return RaidCfg.active[key] == true end,
    })
end

makeIslandRaid("Judge",  "Judge",  "Judge",  "deadly judge")
makeIslandRaid("Jogo",   "Jogo",   "Jogo",   "jogo")
makeIslandRaid("Toji",   "Toji",   "Toji",   "sorcerer killer")
makeIslandRaid("Sukuna", "Sukuna", "Sukuna", "king of curses")
makeIslandRaid("AToji",  "AToji",  "AToji",  "awakened toji")
makeIslandRaid("Maki",   "Maki",   "Maki",   "awakened zen'in")
makeIslandRaid("AGojo", "AGojo", "AGojo", { "the honored one", "gojo" })

AutoCurseCalamityOn = false
CURSE_CALAMITY_TAGS = { "heian raider", "the follower", "calamity curse" }
CURSE_CALAMITY_BOSS_TAGS = { "the follower", "calamity curse" }
nexusRaidEngine({
    zones         = { "CurseCalamity" },
    config        = "CurseCalamity",
    tag           = CURSE_CALAMITY_TAGS,
    siege         = true,
    bossTag       = CURSE_CALAMITY_BOSS_TAGS,
    maxDifficulty = 3,
    isles         = { "cursecalamity", "calamity" },
    isOn          = function() return AutoCurseCalamityOn end,
})

BringRaidNpcOn = false
RAID_BRING_RANGE = 300
RAID_BRING_RANGE_MIN = 300
RAID_BRING_RANGE_MAX = 1000
RAID_NPC_SCAN_SEC = 0.2
NEXUS_RAID_NPC_CACHE = { t = -1, list = {} }

function nexusCollectRaidNPCs(tags, range)
    local myModel = getModel()
    local myHRP = myModel and myModel:FindFirstChild("HumanoidRootPart")
    if not (myHRP and NPCsF) then return {}, myModel, myHRP end

    local now = os.clock()
    local cache = NEXUS_RAID_NPC_CACHE
    if cache.t >= 0 and (now - cache.t) < RAID_NPC_SCAN_SEC then
        local live = {}
        for _, m in ipairs(cache.list) do
            if m.Parent and nexusValidNpc(m) then live[#live + 1] = m end
        end
        return live, myModel, myHRP
    end

    local out, seen = {}, {}
    local myPos = myHRP.Position
    local myIsle = NEXUS_LV.islandOf(myPos)

    pcall(function()
        for _, m in ipairs(NPCsF:GetChildren()) do
            local h = m:FindFirstChild("HumanoidRootPart")
            if h and not seen[m] and nexusValidNpc(m) then
                local p = h.Position
                if (p - myPos).Magnitude <= range then
                    local mine = true
                    if myIsle then
                        local isl = NEXUS_LV.islandOf(p)
                        mine = (isl ~= nil and isl.model == myIsle.model)
                    end
                    if mine then
                        seen[m] = true
                        out[#out + 1] = m
                    end
                end
            end
        end
    end)

    local ClientF = Characters:FindFirstChild("Client")
    if ClientF and tags then
        local spots = {}
        pcall(function()
            for _, d in ipairs(clientLabels(ClientF)) do
                if d:IsA("TextLabel") and nexusTextMatchesAnyTag(d.Text, tags) then
                    local rig = d:FindFirstAncestorWhichIsA("Model")
                    local h = rig and rig:FindFirstChild("HumanoidRootPart")
                    if h and (h.Position - myPos).Magnitude <= range then
                        spots[#spots + 1] = h.Position
                    end
                end
            end
        end)
        if #spots > 0 then
            pcall(function()
                for _, m in ipairs(NPCsF:GetChildren()) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h and not seen[m] and nexusValidNpc(m)
                        and (h.Position - myPos).Magnitude <= range
                        and onMyIsland(h.Position) then
                        for _, sp in ipairs(spots) do
                            if (h.Position - sp).Magnitude < 25 then
                                seen[m] = true
                                out[#out + 1] = m
                                break
                            end
                        end
                    end
                end
            end)
        end
    end

    cache.list, cache.t = out, now
    return out, myModel, myHRP
end

NEXUS_RAID_TAG_CACHE = { t = 0, tags = nil }
function nexusActiveRaidTags()
    local now = os.clock()
    local c = NEXUS_RAID_TAG_CACHE
    if (now - c.t) < 0.5 then return c.tags end
    local tags = nil
    local function add(src)
        if not src then return end
        if type(src) ~= "table" then src = { src } end
        tags = tags or {}
        for _, v in ipairs(src) do tags[#tags + 1] = v end
    end
    for _, cfg in ipairs(NEXUS_RAID_REG) do
        local on = false
        pcall(function() on = cfg.isOn() == true end)
        if on then
            add(cfg.tag)
            add(cfg.bossTag)
        end
    end
    c.tags, c.t = tags, now
    return tags
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if BringRaidNpcOn then
            local tags = nexusActiveRaidTags()
            local npcs, cur, chrp
            if tags then npcs, cur, chrp = nexusCollectRaidNPCs(tags, RAID_BRING_RANGE) end
            if chrp and npcs and #npcs > 0 then

                NexusCapKeepInside(chrp)
                pcall(function() chrp.AssemblyLinearVelocity = Vector3.zero end)
                local capC, capR = NexusCapPoint()

                pcall(NexusAIBring, chrp.Position)
                for i, m in ipairs(npcs) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then

                        local settled = false
                        if capC then
                            local cd = h.Position - capC
                            settled = Vector3.new(cd.X, 0, cd.Z).Magnitude <= capR * 0.8
                                and math.abs(cd.Y) <= capR * 0.5
                        end
                        if not settled then
                            local angle = (i / #npcs) * math.pi * 2
                            local off = Vector3.new(math.cos(angle) * BRING_OFFSET, 0, math.sin(angle) * BRING_OFFSET)
                            NexusBringPlace(h, chrp.Position + off)
                        end
                    end
                end

                NexusQ(NexusBringPump, npcs, cur, chrp)
                task.wait(BRING_GAP)
            else
                task.wait(NEXUS_IDLE)
            end
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

AutoInfSukunaRaidOn = false
nexusRaidEngine({
    zones      = { "SukunaInf" },
    config     = "SukunaInf",
    difficulty = 1,
    tag        = "king of curses",
    infinite   = true,
    isles      = { "sukunainf", "sukuna" },
    isOn       = function() return AutoInfSukunaRaidOn end,
})

AutoInfTojiRaidOn = false
nexusRaidEngine({
    zones      = { "TojiInf" },
    config     = "TojiInf",
    difficulty = 1,
    tag        = "sorcerer killer",
    infinite   = true,
    isles      = { "tojiinf", "toji" },
    isOn       = function() return AutoInfTojiRaidOn end,
})

NexusInfW = NexusInfW or { interval = 3600, duration = 1200, mult = nil, read = false }
function nexusInfCfg()
    if NexusInfW.read then return end
    pcall(function()
        local m = require(RepStorage:WaitForChild("Configs"):WaitForChild("RaidsConfig"))
        NexusInfW.interval = tonumber(m.InfiniteRaidOpenInterval) or NexusInfW.interval
        NexusInfW.duration = tonumber(m.InfiniteRaidOpenDuration) or NexusInfW.duration
        NexusInfW.mult     = m.InfiniteRaid_DMGRewardMultiplier
        NexusInfW.read     = true
    end)
end

function nexusInfWindow()
    nexusInfCfg()
    local iv, du = NexusInfW.interval, NexusInfW.duration
    local now = math.floor(workspace:GetServerTimeNow())
    local into = now - math.floor(now / iv) * iv
    if into < du then return true, du - into end
    return false, iv - into
end
function nexusInfClock(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end
function nexusInfNum(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return string.format("%d", n)
end

NexusInfList = {
    { label = "King of Curses",  zone = "SukunaInf", tag = "king of curses",  on = function() return AutoInfSukunaRaidOn end },
    { label = "Sorcerer Killer", zone = "TojiInf",   tag = "sorcerer killer", on = function() return AutoInfTojiRaidOn   end },
}
function nexusInfActive()
    for _, r in ipairs(NexusInfList) do
        if r.on() then return r end
    end
    return nil
end

NexusInfReturning = false
NexusInfDmg = NexusInfDmg or { dmg = 0, dps = 0, rank = 0, t = 0 }
NexusInfLD  = NexusInfLD  or { dmg = 0, hits = {}, conn = nil, model = nil, last = 0 }
task.spawn(function()
    local sig
    pcall(function() sig = Net:WaitForChild("RaidsService", 20):WaitForChild("InfDamageData_Signal", 20) end)
    if not sig then return end
    local c = sig.OnClientEvent:Connect(function(d)
        if type(d) ~= "table" then return end
        NexusInfDmg.dmg  = tonumber(d[1]) or NexusInfDmg.dmg
        NexusInfDmg.dps  = tonumber(d[2]) or 0
        NexusInfDmg.rank = tonumber(d[3]) or 0
        NexusInfDmg.t    = os.clock()
    end)
    pcall(function() table.insert(CONNS, c) end)
end)
function nexusInfMeter(hum, model)
    if NexusInfLD.model == model then return end
    if NexusInfLD.conn then pcall(function() NexusInfLD.conn:Disconnect() end) end
    NexusInfLD.conn, NexusInfLD.model, NexusInfLD.last = nil, model, (hum and hum.Health or 0)
    if not hum then return end
    NexusInfLD.conn = hum.HealthChanged:Connect(function(hp)
        local drop = NexusInfLD.last - hp
        NexusInfLD.last = hp
        if drop <= 0 then return end
        NexusInfLD.dmg = NexusInfLD.dmg + drop
        local t = os.clock()
        local h = NexusInfLD.hits
        h[#h + 1] = { t, drop }
        while h[1] and (t - h[1][1]) > 5 do table.remove(h, 1) end
    end)
    pcall(function() table.insert(CONNS, NexusInfLD.conn) end)
end
function nexusInfLocalDps()
    local t, sum = os.clock(), 0
    local h = NexusInfLD.hits
    for i = 1, #h do
        if (t - h[i][1]) <= 5 then sum = sum + h[i][2] end
    end
    return sum / 5
end
function nexusInfMult(dmg)
    nexusInfCfg()
    local t = NexusInfW.mult
    if type(t) ~= "table" then return 0, 0 end
    local mult, idx = 0, 0
    for i, j in ipairs(t) do
        if j[1] < dmg then mult, idx = j[2], i end
    end
    local nx = t[idx + 1]
    return mult, (nx and math.max(0, nx[1] - dmg) or 0)
end

NexusInfB = NexusInfB or { model = nil, hum = nil, t = -1, tag = "" }
function nexusInfBoss(tag)
    local m, hum = NexusInfB.model, NexusInfB.hum
    if NexusInfB.tag == tag and m and m.Parent and hum and hum.Parent and hum.Health > 0 then
        return m, hum
    end
    local now = os.clock()
    if NexusInfB.tag == tag and (now - NexusInfB.t) < 1 then return nil, nil end
    NexusInfB.t, NexusInfB.tag = now, tag
    m = findNearestTaggedBoss(tag, nil)
    hum = m and m:FindFirstChildOfClass("Humanoid") or nil
    NexusInfB.model, NexusInfB.hum = m, hum
    return m, hum
end

NexusInfP = NexusInfP or { pad = nil, dur = nil, cnt = nil, t = -1, zone = "" }
function nexusInfPad(zone)
    local now = os.clock()
    if NexusInfP.zone == zone and (now - NexusInfP.t) < 1 then
        local p = NexusInfP.pad
        if not p or p.Parent then
            return p, (NexusInfP.dur and NexusInfP.dur.Parent) and NexusInfP.dur.Text or nil,
                      (NexusInfP.cnt and NexusInfP.cnt.Parent) and NexusInfP.cnt.Text or nil
        end
    end
    NexusInfP.t, NexusInfP.zone = now, zone
    NexusInfP.pad, NexusInfP.dur, NexusInfP.cnt = nil, nil, nil
    local qz = nexusQueueZones()
    if not qz then return nil end
    local p = qz:FindFirstChild(zone) or qz:FindFirstChild(zone, true)
    if not p then return nil end
    NexusInfP.pad = p
    pcall(function()
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("TextLabel") then
                local n = string.lower(d.Name)
                if n == "duration" then NexusInfP.dur = d
                elseif n == "playercount" then NexusInfP.cnt = d end
            end
        end
    end)
    return p, (NexusInfP.dur and NexusInfP.dur.Text or nil), (NexusInfP.cnt and NexusInfP.cnt.Text or nil)
end

InfRaidNotifyOn = false
task.spawn(function()
    local was = nil
    while NEXUSG.NexusPlayHubSession == SESSION do
        local open, left = nexusInfWindow()
        if InfRaidNotifyOn and was == false and open then
            pcall(function()
                Library:Notify({
                    Title = "NEXUSPLAY HUB",
                    Content = "Infinity Raid is OPEN  -  closes in " .. nexusInfClock(left),
                    Type = "Success",
                    Duration = 8,
                })
            end)
        end
        was = open
        task.wait(1)
    end
end)

function NexusInfStatusText()
    local L = {}
    local open, left = nexusInfWindow()
    if open then
        L[1] = "Raid Window  : OPEN  -  closes in " .. nexusInfClock(left)
        L[2] = "Next Spawn   : now  (open " .. math.floor(NexusInfW.duration / 60) .. " min every "
               .. math.floor(NexusInfW.interval / 60) .. " min)"
    else
        L[1] = "Raid Window  : CLOSED"
        L[2] = "Next Spawn   : " .. nexusInfClock(left) .. "  (" .. os.date("%H:%M:%S", os.time() + math.floor(left)) .. ")"
    end
    local r = nexusInfActive()
    if not r then
        NexusInfLD.dmg, NexusInfLD.hits = 0, {}
        L[#L + 1] = "Status       : Off  -  flip an Infinity switch"
        return table.concat(L, "\n")
    end
    local model, hum = nexusInfBoss(r.tag)
    if NexusInfReturning then
        L[#L + 1] = "Status       : Cleared  -  returning to lobby"
        L[#L + 1] = "Boss         : " .. r.label .. " (defeated)"
    elseif hum and hum.Health > 0 then
        nexusInfMeter(hum, model)
        L[#L + 1] = "Status       : Fighting"
        L[#L + 1] = "Boss         : " .. r.label
        L[#L + 1] = string.format("Boss HP      : %s / %s  (%.1f%%)", nexusInfNum(hum.Health),
                    nexusInfNum(hum.MaxHealth), (hum.MaxHealth > 0 and (hum.Health / hum.MaxHealth * 100) or 0))
    else
        local pad, dur, cnt = nexusInfPad(r.zone)
        if pad then
            L[#L + 1] = "Status       : Starting  -  on the join pad" .. (dur and ("  (" .. tostring(dur) .. ")") or "")
            if cnt then L[#L + 1] = "Players      : " .. tostring(cnt) end
        else
            L[#L + 1] = "Status       : Starting  -  queueing the raid"
        end
        L[#L + 1] = "Boss         : " .. r.label .. " (not spawned yet)"
    end

    local dmg, dps, src
    if NexusInfDmg.t > 0 then
        dmg, dps, src = NexusInfDmg.dmg, NexusInfDmg.dps, ""
    else
        dmg, dps, src = NexusInfLD.dmg, nexusInfLocalDps(), "  (live meter)"
    end
    local mult, need = nexusInfMult(dmg)
    L[#L + 1] = "My Damage    : " .. nexusInfNum(dmg) .. "   DPS: " .. nexusInfNum(dps) .. src
    L[#L + 1] = "Rank         : " .. (NexusInfDmg.t > 0 and tostring(NexusInfDmg.rank) or "-")
    L[#L + 1] = string.format("Reward Mult  : x%.2f%s", mult,
                (need > 0 and ("   (next tier in " .. nexusInfNum(need) .. " dmg)") or "   (max tier)"))
    return table.concat(L, "\n")
end

NexusCTX = {
    { "LimitlessExtra",       "Limitless",               "ExchangeLimitlessExtra",       1,  100, 5 },
    { "ShrineExtra",          "Shrine",                  "ExchangeShrineExtra",          1,  100, 5 },
    { "BeastAmberExtra",      "Beast Amber",             "ExchangeBeastAmberExtra",      1,  100, 5 },
    { "ProjectionExtra",      "Projection Sorcery",      "ExchangeProjectionExtra",      1,  100, 5 },
    { "GamblerExtra",         "Love Train",              "ExchangeGamblerExtra",         1,  100, 5 },
    { "JudgemanExtra",        "Judgeman",                "ExchangeJudgemanExtra",        1,  100, 5 },
    { "LarpExtra",            "Cursed Energy Discharge", "ExchangeLarpExtra",            1,  100, 5 },
    { "YutaExtra",            "Copy",                    "ExchangeYutaExtra",            1,  100, 5 },
    { "SFAExtra",             "Solo Forbidden Area",     "ExchangeSFAExtra",             1,   30, 4 },
    { "DFlamesExtra",         "Disaster Flames",         "ExchangeDFlamesExtra",         3,   30, 4 },
    { "StarRageExtra",        "Star Rage",               "ExchangeStarRageExtra",        3,   30, 4 },
    { "BloodMExtra",          "Blood Manipulation",      "ExchangeBloodMExtra",          3,   30, 4 },
    { "DisasterTidesExtra",   "Disaster Tides",          "ExchangeDisasterTidesExtra",   3,   30, 4 },
    { "RatioExtra",           "Ratio",                   "ExchangeRatioExtra",          10,   15, 3 },
    { "CursedSpeechExtra",    "Cursed Speech",           "ExchangeCursedSpeechExtra",   10,   15, 3 },
    { "StrawDollExtra",       "Straw Doll",              "ExchangeStrawDollExtra",      10,   10, 2 },
    { "ExplodingFleshExtra",  "Exploding Flesh",         "ExchangeExplodingFleshExtra", 10,   10, 2 },

    { "AwakenedStarRageExtra","Awk Star Rage",           nil,                            0,    0, 6 },
    { "AwakenedBloodMExtra",  "Awk Blood-M",             nil,                            0,    0, 6 },
    { "TenShadowsExtra",      "Ten Shadows",             nil,                            0,    0, 6 },
}
NexusCTGrade = { [6] = "Awakened", [5] = "Special Grade", [4] = "Grade 4", [3] = "Grade 3", [2] = "Grade 2" }
NexusCTOrder = { 5, 4, 3, 2, 6 }

NexusCTSkins = {
    { "Item3",  "SFA Boosted",              500,   "+200 HP" },
    { "Item1",  "Disaster Tides Boosted",   1000,  "+10% DMG" },
    { "Item8",  "True ISOH Flaming",        3500,  "+10% DMG" },
    { "Item2",  "Judgeman Boosted",         3500,  "+10% DMG" },
    { "Item5",  "Limitless Boosted",        3500,  "+10% DMG" },
    { "Item7",  "Soul Split Katana Boosted",3500,  "+10% DMG" },
    { "Item4",  "Shrine Boosted",           5000,  "+10% DMG" },
    { "Item6",  "Copy Boosted",             7500,  "+10% DMG" },
    { "Item9",  "Awk Blood-M Boosted",      10000, "+10% DMG, +10% ATK" },
    { "Item10", "Awk Star Rage Boosted",    10000, "+10% DMG, +10% ATK" },
}
NexusCTById = {}
for _, e in ipairs(NexusCTX) do NexusCTById[e[1]] = e end

NexusInvC = nil
function nexusInvC()
    if NexusInvC then return NexusInvC end
    pcall(function() NexusInvC = require(LocalPlayer.PlayerScripts.Client.Controllers.InventoryController) end)
    return NexusInvC
end
function nexusCTCount(id)
    local c = nexusInvC()
    local inv = c and c.CurrentInventory
    if not inv then return 0 end
    local ok, sup = pcall(function() return inv:GetSupply(id) end)
    if not ok or not sup then return 0 end
    return tonumber(sup.Count) or 0
end
function nexusCTDust() return nexusCTCount("CursedDust") end
function nexusCTComma(n)
    n = tostring(math.floor(tonumber(n) or 0))
    local out = n:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

NexusCTDirty = true
task.spawn(function()
    local sig
    pcall(function() sig = Net:WaitForChild("InventoryService", 20):WaitForChild("InventoryChanged_Signal", 20) end)
    if not sig then return end
    local c = sig.OnClientEvent:Connect(function() NexusCTDirty = true end)
    pcall(function() table.insert(CONNS, c) end)
end)

NexusQAccept, NexusBuyEvent = nil, nil
function nexusCTRemotes()
    if not NexusQAccept then pcall(function() NexusQAccept = Net:WaitForChild("QuestService", 10):WaitForChild("AcceptQuest_Method", 10) end) end
    if not NexusBuyEvent then pcall(function() NexusBuyEvent = Net:WaitForChild("InventoryService", 10):WaitForChild("BuyEventItem_Method", 10) end) end
end
function nexusCTBuySkin(key)
    nexusCTRemotes()
    if not NexusBuyEvent then return end
    task.spawn(function()
        pcall(function() NexusBuyEvent:InvokeServer("CTSkinShop", key) end)
        NexusCTDirty = true
    end)
end

NexusCTS = { runs = 0, used = 0, dust = 0 }
AutoCTExchangeOn = false
NexusCTPickList = { "LimitlessExtra" }
NexusCTSelected = { LimitlessExtra = true }
function nexusCTSetPick(list)
    NexusCTPickList = list or {}
    local set = {}
    for i = 1, #NexusCTPickList do set[NexusCTPickList[i]] = true end
    NexusCTSelected = set
end
NexusCTAmt  = 0
NexusCTDone = {}
NexusCTNote = ""
function nexusCTReset()
    NexusCTDone, NexusCTNote = {}, ""
    NexusCTDirty = true
end

task.spawn(function()
    local fails = 0
    while NEXUSG.NexusPlayHubSession == SESSION do
        if not AutoCTExchangeOn then
            fails = 0
            task.wait(1)
        else

            local did = false
            for i = 1, #NexusCTPickList do
                if not AutoCTExchangeOn then break end
                local e = NexusCTById[NexusCTPickList[i]]
                if e and e[3] then
                    local id     = e[1]
                    local have   = nexusCTCount(id)
                    local done   = NexusCTDone[id] or 0
                    local remain = (NexusCTAmt > 0) and (NexusCTAmt - done) or have
                    if remain >= e[4] and have >= e[4] then
                        nexusCTRemotes()
                        local before = nexusCTDust()
                        if NexusQAccept then pcall(function() NexusQAccept:InvokeServer(e[3]) end) end

                        local t0 = os.clock()
                        local after = before
                        while (os.clock() - t0) < 1.5 do
                            task.wait(0.1)
                            after = nexusCTDust()
                            if after ~= before then break end
                        end
                        if after > before then
                            did, fails = true, 0
                            NexusCTDone[id] = done + e[4]
                            NexusCTS.runs = NexusCTS.runs + 1
                            NexusCTS.used = NexusCTS.used + e[4]
                            NexusCTS.dust = NexusCTS.dust + (after - before)
                            NexusCTNote = ""
                            NexusCTDirty = true
                            task.wait(0.25)
                        else
                            fails = fails + 1
                            NexusCTNote = "server refused (" .. fails .. "/3)"
                            NexusCTDirty = true
                            if fails >= 3 then
                                AutoCTExchangeOn = false
                                fails = 0
                                pcall(function()
                                    Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Auto Exchange stopped: the server rejected the exchange", Type = "Warning", Duration = 6 })
                                end)
                            end
                            task.wait(0.5)
                        end
                    end
                end
            end
            if not did then

                if #NexusCTPickList == 0 then
                    NexusCTNote = "nothing selected"
                else
                    NexusCTNote = "waiting - target reached / not enough extras"
                end
                NexusCTDirty = true
                task.wait(1)
            end
        end
    end
end)

function NexusCTStatusText()
    local L = {}
    local dust = nexusCTDust()
    L[1] = "Cursed Dust  : " .. nexusCTComma(dust)
    local target = (NexusCTAmt > 0) and (NexusCTAmt .. " each") or "all"
    L[#L + 1] = "Selected     : " .. #NexusCTPickList .. " CT  x" .. target
    L[#L + 1] = "Auto Exchange: " .. (AutoCTExchangeOn and "ON" or "OFF") ..
        ((NexusCTNote ~= "") and ("   - " .. NexusCTNote) or "")
    for i = 1, #NexusCTPickList do
        local e = NexusCTById[NexusCTPickList[i]]
        if e then
            local pad  = string.rep(" ", math.max(1, 22 - #e[2]))
            local done = NexusCTDone[e[1]] or 0
            local have = nexusCTCount(e[1])
            L[#L + 1] = "   \226\128\162 " .. e[2] .. pad ..
                (e[3] and ("(" .. e[4] .. " \226\134\146 " .. e[5] .. " dust)") or "(no exchange)") ..
                "  have " .. have ..
                (NexusCTAmt > 0 and ("  done " .. done .. "/" .. NexusCTAmt) or ("  done " .. done))
        end
    end
    L[#L + 1] = "Session      : " .. NexusCTS.runs .. " exchanges  -  " .. NexusCTS.used ..
                " extras used  -  +" .. nexusCTComma(NexusCTS.dust) .. " dust"

    local afford, nextName, nextNeed = 0, nil, nil
    for _, sk in ipairs(NexusCTSkins) do
        if dust >= sk[3] then
            afford = afford + 1
        elseif not nextName then
            nextName, nextNeed = sk[2], sk[3] - dust
        end
    end
    L[#L + 1] = "Skins        : " .. afford .. "/" .. #NexusCTSkins .. " affordable" ..
        (nextName and ("   next: " .. nextName .. " (need " .. nexusCTComma(nextNeed) .. " more)") or "   ALL affordable")

    for _, g in ipairs(NexusCTOrder) do
        local rows, total = {}, 0
        for _, e in ipairs(NexusCTX) do
            if e[6] == g then
                local c = nexusCTCount(e[1])
                if c > 0 or NexusCTSelected[e[1]] then
                    local pad = string.rep(" ", math.max(1, 22 - #e[2]))
                    local worth = ""
                    if e[3] and e[4] > 0 then
                        local runs = math.floor(c / e[4])
                        if runs > 0 then worth = "   (" .. nexusCTComma(runs * e[5]) .. " dust)" end
                    end
                    rows[#rows + 1] = "  " .. e[2] .. pad .. "= " .. c .. worth
                    total = total + c
                end
            end
        end
        if #rows > 0 then
            L[#L + 1] = ""
            L[#L + 1] = NexusCTGrade[g] .. "   (" .. total .. ")"
            L[#L + 1] = "\226\128\148\226\128\148\226\128\148\226\128\148\226\128\148\226\128\148\226\128\148\226\128\148\226\128\148"
            for _, r in ipairs(rows) do L[#L + 1] = r end
        end
    end
    return table.concat(L, "\n")
end

TrialOn      = false
TrialNextOn  = false
TrialChamber = 1
TRIAL_MAX    = 12
TrialRuns, TrialRestarts = 0, 0
TrialPhase   = "off"
TRIAL_STALL_SEC  = 20
TRIAL_START_WAIT = 8
TRIAL_END_WAIT   = 4
TRIAL_BACKOFF    = 1

function trialResetFind() TrialPhase = "off" end

function trialTowerCfg()
    if type(NexusTTCfg) ~= "table" then
        pcall(function() NexusTTCfg = require(RepStorage.Configs.TrialTowerConfig) end)
    end
    return (type(NexusTTCfg) == "table") and NexusTTCfg or nil
end
function trialIslandCfg()
    if type(NexusBICfg) ~= "table" then
        pcall(function() NexusBICfg = require(RepStorage.Configs.BossIslandsConfig) end)
    end
    return (type(NexusBICfg) == "table") and NexusBICfg or nil
end
function trialIslandCtrl()
    if type(NexusBIC) ~= "table" then
        pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local cl = ps and ps:FindFirstChild("Client")
            local ct = cl and cl:FindFirstChild("Controllers")
            local md = ct and ct:FindFirstChild("BossIslandController")
            if md then NexusBIC = require(md) end
        end)
    end
    return (type(NexusBIC) == "table") and NexusBIC or nil
end

function trialClears(id)
    if not id then return 0 end
    if type(NexusPDC) ~= "table" then pcall(NexusFlags) end
    local v
    pcall(function() v = NexusPDC.PlayerData.Leaderstats.TowersCompleted[id] end)
    return tonumber(v) or 0
end
function trialId(n) return "C" .. tostring(n or TrialChamber) end
function trialTower(id)
    local cfg = trialTowerCfg()
    return (cfg and cfg.Towers and cfg.Towers[id or trialId()]) or nil
end

function trialCanStart(id)
    local t = trialTower(id)
    if not t then return false end
    if not t.LastTower then return true end
    return trialClears(t.LastTower) > 0
end

function trialTowerOfFloor(configId)
    local cfg = trialTowerCfg()
    if not (cfg and configId) then return nil end
    for id, t in pairs(cfg.Towers) do
        for _, f in ipairs(t.Floors or {}) do
            if f == configId then return id end
        end
    end
    return nil
end

function trialActiveIsland()
    local c = trialIslandCtrl()
    local isl = c and c.ActiveIsland
    if type(isl) ~= "table" then return nil end
    local cfg = trialIslandCfg()
    local d = cfg and cfg.Islands and cfg.Islands[isl.ConfigID]
    if not (d and d.IsTowerFloor) then return nil end
    return isl
end

function trialInOtherIsland()
    local c = trialIslandCtrl()
    local isl = c and c.ActiveIsland
    if type(isl) ~= "table" then return false end
    return trialActiveIsland() == nil
end

function trialMyBosses()
    local isl = trialActiveIsland()
    if not isl then return {} end
    local out = {}
    local function add(npc)
        if type(npc) ~= "table" then return end
        local m
        pcall(function() m = (npc.Character and npc.Character.ServerModel) or npc.ServerModel end)
        if typeof(m) == "Instance" and m.Parent then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if (not hum) or hum.Health > 0 then out[#out + 1] = m end
        end
    end
    add(isl.BossNPC)
    add(isl.WaveBossNPC)
    if #out == 0 then

        local m = isl.BossServerModel or isl.WaveBossServerModel
        if typeof(m) == "Instance" and m.Parent then out[#out + 1] = m end
    end
    return out
end

function trialStartRemote()
    local ok, r = pcall(function()
        local svc = Net:FindFirstChild("TrialTowerService")
        return svc and svc:FindFirstChild("StartTower_Method")
    end)
    return ok and r or nil
end
function trialReturnRemote()
    local ok, r = pcall(function()
        local svc = Net:FindFirstChild("BossIslandService")
        return svc and svc:FindFirstChild("Return_Method")
    end)
    return ok and r or nil
end
function trialLeaveNow()
    pcall(clickPopups, "next", "close")
    local ret = trialReturnRemote()
    if ret then pcall(function() ret:InvokeServer() end) end
end

function trialHookEvents()
    if TRIAL_HOOKED then return end
    local c = trialIslandCtrl()
    if not c then return end
    TRIAL_HOOKED = true
    pcall(function()
        local a = c.IslandCreated:Connect(function() TRIAL_EVT_START = os.clock() end)
        local b = c.IslandEnded:Connect(function() TRIAL_EVT_END = os.clock() end)
        CONNS[#CONNS + 1] = a
        CONNS[#CONNS + 1] = b
    end)
end

function trialAdvance()
    local t = trialTower(trialId())
    local cfg = trialTowerCfg()
    local nt = t and t.NextTower and cfg and cfg.Towers[t.NextTower]
    if not nt then return false end
    TrialChamber = tonumber(nt.Index) or TrialChamber
    Settings["TrialChamber"] = "Chamber " .. TrialChamber
    pcall(saveSettings)
    return true
end

NexusSupervise("trial", function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if not TrialOn then
            TrialPhase = "off"
            task.wait(NEXUS_IDLE)
        else
            trialHookEvents()
            local isl = trialActiveIsland()
            if isl then

                local towerId = trialTowerOfFloor(isl.ConfigID) or trialId()
                local before  = trialClears(towerId)
                TrialPhase = "fight " .. tostring(towerId)
                local lastHP, lastDrop = nil, os.clock()
                while TrialOn and NEXUSG.NexusPlayHubSession == SESSION and trialActiveIsland() do
                    local mine = trialMyBosses()
                    if #mine == 0 then
                        task.wait(0.1)
                    else
                        local boss = mine[1]
                        local bh   = boss:FindFirstChild("HumanoidRootPart")
                        local hum  = boss:FindFirstChildOfClass("Humanoid")
                        local hp   = hum and hum.Health
                        if hp and (lastHP == nil or hp < lastHP) then lastHP, lastDrop = hp, os.clock() end
                        if (os.clock() - lastDrop) > TRIAL_STALL_SEC then break end
                        local cur  = getModel()
                        local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
                        if bh and chrp then
                            pcall(function()
                                chrp.AssemblyLinearVelocity  = Vector3.zero
                                chrp.AssemblyAngularVelocity = Vector3.zero
                                chrp.CFrame = auraGoal(bh)
                            end)
                            enableBlackFlash()
                            NexusQ(pcall, blackFlashList, mine, cur, chrp)
                            NexusQ(pcall, attackList, mine, cur, chrp)
                        end
                        task.wait(0.05)
                    end
                end

                TrialPhase = "result"
                trialLeaveNow()
                local t0, after = os.clock(), before
                while (os.clock() - t0) < TRIAL_END_WAIT do
                    after = trialClears(towerId)
                    if after > before then break end
                    if trialActiveIsland() then break end
                    task.wait(0.2)
                end
                if after > before then
                    TrialRuns = TrialRuns + 1

                    if TrialNextOn and towerId == trialId() then trialAdvance() end
                else
                    TrialRestarts = TrialRestarts + 1
                end
                task.wait(0.2)
            elseif trialInOtherIsland() then
                TrialPhase = "waiting (in a raid)"
                task.wait(1)
            else

                local id = trialId()
                if not trialCanStart(id) then
                    TrialPhase = "locked " .. id

                    if TrialNextOn then
                        local best
                        for i = 1, TRIAL_MAX do
                            if trialCanStart("C" .. i) then best = i end
                        end
                        if best and best ~= TrialChamber then
                            TrialChamber = best
                            Settings["TrialChamber"] = "Chamber " .. best
                            pcall(saveSettings)
                        end
                    end
                    task.wait(1)
                else
                    TrialPhase = "start " .. id
                    local st = trialStartRemote()
                    local sent = false
                    if st then
                        local ok, res = pcall(function() return st:InvokeServer(id) end)
                        sent = ok and res ~= false and res ~= nil
                    end

                    local t0 = os.clock()
                    while TrialOn and NEXUSG.NexusPlayHubSession == SESSION and (os.clock() - t0) < TRIAL_START_WAIT do
                        if trialActiveIsland() then break end
                        task.wait(0.1)
                    end
                    if trialActiveIsland() then
                        TRIAL_BACKOFF = 1
                    else

                        TrialPhase = "retry " .. id .. " (" .. (sent and "no floor" or "refused") .. ")"
                        trialLeaveNow()
                        TRIAL_BACKOFF = math.min((TRIAL_BACKOFF or 1) * 2, 8)
                        task.wait(TRIAL_BACKOFF)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if TrialOn then pcall(clickPopups, "next", "close") end
        task.wait((TrialOn) and 0.3 or NEXUS_IDLE)
    end
end)

AutoOuterRaidOn  = false
inOuterRaid      = false
OUTER_BOSS_TAG   = "awakened star"
outerAddCache    = {}
outerVoidPausing = false
ReadySignal = Net.RaidsService.Ready_Signal
RetrySignal = Net.RaidsService.RetryRaid_Method

NEXUS_RAID_PLACE_NAME = "Raids"
NexusRaidPlaceCache   = nil
function nexusInRaidServer()
    if NexusRaidPlaceCache ~= nil then return NexusRaidPlaceCache end
    local isRaid = nil
    pcall(function()
        local RS = RepStorage
        local lib = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Libraries")
        local mod = lib and lib:FindFirstChild("PlaceHelper")
        if not mod then return end
        local ph = require(mod)
        if type(ph) ~= "table" then return end
        if type(ph.IsPlace) == "function" then
            local ok, v = pcall(function() return ph:IsPlace(NEXUS_RAID_PLACE_NAME) end)
            if ok and type(v) == "boolean" then isRaid = v return end
        end
        if type(ph.GetPlaceName) == "function" then
            local ok, v = pcall(function() return ph:GetPlaceName() end)
            if ok and type(v) == "string" then isRaid = (v == NEXUS_RAID_PLACE_NAME) return end
        end
        if type(ph.GetPlaceID) == "function" then
            local ok, v = pcall(function() return ph:GetPlaceID(NEXUS_RAID_PLACE_NAME) end)
            if ok and tonumber(v) then isRaid = (game.PlaceId == tonumber(v)) end
        end
    end)
    if isRaid == nil then

        isRaid = (game.PlaceId == 70619325627859)
    end
    NexusRaidPlaceCache = isRaid
    return isRaid
end

NEXUS_RAMPAGE_ON    = false
NEXUS_RAMPAGE_BUSY  = false
NEXUS_RAMPAGE_SPEED = 0.0001
NEXUS_RAMPAGE_SAVED = nil
NEXUS_DELAY_CONTROLS = {}
NexusMaxPotentialToggle = nil

function NexusRampageNotify(msg, kind)
    pcall(function()
        Library:Notify({ Title = "NEXUSPLAY HUB", Content = tostring(msg), Type = kind or "Info", Duration = 6 })
    end)
end

function NexusDelaySlider(section, opts)
    opts = opts or {}
    local cb = opts.Callback
    local last = tonumber(opts.CurrentValue)
    local handle
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.Callback = function(v)
        if NEXUS_RAMPAGE_BUSY then return end
        if NEXUS_RAMPAGE_ON then

            NEXUS_RAMPAGE_BUSY = true
            pcall(function() if handle then handle:Set(last) end end)
            NEXUS_RAMPAGE_BUSY = false
            NexusRampageNotify("Unlock Max Potential is ON -- " .. tostring(opts.Name)
                .. " is locked. Turn Max Potential off to change it.", "Warning")
            return
        end
        last = tonumber(v) or last
        if cb then cb(v) end
    end
    handle = section:CreateSlider(o)
    NEXUS_DELAY_CONTROLS[#NEXUS_DELAY_CONTROLS + 1] = {
        handle = handle,
        name   = tostring(opts.Name or "Setting"),
        value  = function() return last end,
    }
    return handle
end

function NexusRampageResyncControls()
    NEXUS_RAMPAGE_BUSY = true
    for _, c in ipairs(NEXUS_DELAY_CONTROLS) do
        pcall(function()
            local v = c.value()
            if v ~= nil and c.handle then c.handle:Set(v) end
        end)
    end
    NEXUS_RAMPAGE_BUSY = false
end

function NexusRampageClearGates()
    pcall(function() if NexusClearMoveGates then NexusClearMoveGates() end end)
    pcall(function() if NexusClearSkillGates then NexusClearSkillGates() end end)
    pcall(function() startLast = {} end)
    pcall(function() dmgLast = {} end)
    pcall(function() TgtCache = {} end)
end

function NexusSetRampage(on)
    on = on and true or false
    if on == NEXUS_RAMPAGE_ON then return end
    if on then

        NEXUS_RAMPAGE_SAVED = {
            LOOP_GAP         = LOOP_GAP,
            NEXUS_IDLE_GAP    = NEXUS_IDLE_GAP,
            TGT_CACHE_SEC    = TGT_CACHE_SEC,
            SKILL_GAP        = SKILL_GAP,
            TOTAL_GAP        = TOTAL_GAP,
            GLOBAL_SKILL_GAP = GLOBAL_SKILL_GAP,
            START_GAP        = START_GAP,
            DMG_GAP          = DMG_GAP,
            SKILL_BUDGET     = SKILL_BUDGET,
            BRING_GAP        = BRING_GAP,
        }
        local s = NEXUS_RAMPAGE_SPEED
        LOOP_GAP, NEXUS_IDLE_GAP, TGT_CACHE_SEC = s, s, s
        SKILL_GAP, TOTAL_GAP, GLOBAL_SKILL_GAP = s, s, s
        START_GAP, DMG_GAP, BRING_GAP = s, s, s
        SKILL_BUDGET = 9999
        NEXUS_RAMPAGE_ON = true
        NexusRampageClearGates()
        NexusRampageNotify("MAX POTENTIAL UNLOCKED  -  no delay, no cooldown. Delay settings are locked.", "Warning")
    else
        NEXUS_RAMPAGE_ON = false
        local sv = NEXUS_RAMPAGE_SAVED
        if sv then
            LOOP_GAP         = sv.LOOP_GAP
            NEXUS_IDLE_GAP    = sv.NEXUS_IDLE_GAP
            TGT_CACHE_SEC    = sv.TGT_CACHE_SEC
            SKILL_GAP        = sv.SKILL_GAP
            TOTAL_GAP        = sv.TOTAL_GAP
            GLOBAL_SKILL_GAP = sv.GLOBAL_SKILL_GAP
            START_GAP        = sv.START_GAP
            DMG_GAP          = sv.DMG_GAP
            SKILL_BUDGET     = sv.SKILL_BUDGET
            BRING_GAP        = sv.BRING_GAP
        end
        NEXUS_RAMPAGE_SAVED = nil
        NexusRampageClearGates()
        NexusRampageResyncControls()
        NexusRampageNotify("Max Potential off  -  normal speed restored and settings unlocked.", "Success")
    end
end

NexusConfirmGui = nil
function NexusConfirmClose()
    if NexusConfirmGui then
        pcall(function() NexusConfirmGui:Destroy() end)
        NexusConfirmGui = nil
    end
end

function NexusConfirmPopup(o)
    o = o or {}
    NexusConfirmClose()
    local gui = Instance.new("ScreenGui")
    gui.Name = "NEXUS_Confirm"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local placed = false
    pcall(function()
        if gethui then gui.Parent = gethui() placed = true end
    end)
    if not placed then pcall(function() gui.Parent = game:GetService("CoreGui") placed = true end) end
    if not placed then pcall(function() gui.Parent = NEXUS_LV.Players.LocalPlayer:WaitForChild("PlayerGui") end) end
    NexusConfirmGui = gui

    local shade = Instance.new("TextButton")
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shade.BackgroundTransparency = 0.4
    shade.BorderSizePixel = 0
    shade.AutoButtonColor = false
    shade.Text = ""
    shade.ZIndex = 1
    shade.Parent = gui

    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(420, 250)
    box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    box.BorderSizePixel = 0
    box.ZIndex = 2
    box.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = box
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 2
    stroke.Parent = box

    local title = Instance.new("TextLabel")
    title.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    title.BackgroundTransparency = 0
    title.Position = UDim2.fromOffset(0, 0)
    title.Size = UDim2.new(1, 0, 0, 44)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = tostring(o.title or "ARE YOU SURE?")
    title.ZIndex = 3
    title.Parent = box

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(20, 62)
    body.Size = UDim2.new(1, -40, 0, 120)
    body.Font = Enum.Font.Gotham
    body.TextSize = 14
    body.TextColor3 = Color3.fromRGB(255, 255, 255)
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = tostring(o.text or "")
    body.ZIndex = 3
    body.Parent = box

    local function makeButton(text, xScale, color, cb)
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(0.5, 1)
        b.Position = UDim2.new(xScale, 0, 1, -18)
        b.Size = UDim2.fromOffset(160, 40)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        b.AutoButtonColor = true
        b.ZIndex = 3
        b.Parent = box
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = b
        b.Activated:Connect(function()
            NexusConfirmClose()
            pcall(cb)
        end)
        return b
    end

    makeButton("Yes", 0.28, Color3.fromRGB(255, 0, 0), o.onYes)
    makeButton("No", 0.72, Color3.fromRGB(0, 0, 0), o.onNo)

    shade.Activated:Connect(function()
        NexusConfirmClose()
        pcall(o.onNo)
    end)
    return gui
end

function NexusMaxPotentialSetSwitch(v)
    NEXUS_RAMPAGE_BUSY = true
    pcall(function()
        if NexusMaxPotentialToggle then NexusMaxPotentialToggle:Set(v and true or false) end
    end)
    NEXUS_RAMPAGE_BUSY = false
end

function NexusConfirmMaxPotential()
    NexusConfirmPopup({
        title = "ARE YOU SURE?",
        text  = "This removes every speed limit. Fast Attack, Fast Black Flash and all Fast "
             .. "Skills spam with no cooldown, and the delay settings stay locked.\n\n"
             .. "THIS WILL BE LAGGY. Turning it off restores everything.",
        onYes = function()
            NexusMaxPotentialSetSwitch(true)
            NexusSetRampage(true)
        end,
        onNo = function()
            NexusMaxPotentialSetSwitch(false)
            NexusSetRampage(false)
        end,
    })
end

NexusShopState = {}
NexusShopBusy = false
NexusShopLoopOn = false
NexusShopStatusOn = false
 NEXUS_LV.NexusShopMods = nil

local function NexusShopM()
    if NEXUS_LV.NexusShopMods then return NEXUS_LV.NexusShopMods end
    local ok, m = pcall(function()
        local RS = RepStorage
        local C = NEXUS_LV.Players.LocalPlayer.PlayerScripts.Client.Controllers
        local npc
        pcall(function() npc = require(RS.Configs.NPCConfig.StaticNPCs.Shops) end)
        return {
            Event = require(RS.Configs.EventConfig),
            Item  = require(RS.Configs.ItemConfig),
            Inv   = require(C.InventoryController),
            Data  = require(C.PlayerDataController),
            Char  = require(C.CharacterController),
            Npc   = npc,
        }
    end)
    if ok then NEXUS_LV.NexusShopMods = m end
    return NEXUS_LV.NexusShopMods
end

local function NexusComma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function NexusShopNotify(msg, kind)
    pcall(function()
        Library:Notify({ Title = "NEXUS SHOP", Content = tostring(msg), Type = kind or "Info", Duration = 6 })
    end)
end

NEXUS_LV.NexusShopName = function(key)
    local M = NexusShopM()
    local n = M and M.Npc and M.Npc[key] and M.Npc[key].Name
    return tostring(n or key)
end

NEXUS_LV.NexusCurName = function(id)
    local M = NexusShopM()
    local it = M and M.Item and M.Item.Items and M.Item.Items[id]
    return tostring((it and it.Name) or id)
end

NEXUS_LV.NexusCurCount = function(id)
    local M = NexusShopM()
    if not M then return 0 end
    local c = 0
    pcall(function()
        local ch = M.Char.LocalCharacter
        if ch and ch.Inventory then
            local s = ch.Inventory:GetSupply(id)
            c = (s and s.Count) or 0
        end
    end)
    return c or 0
end

NEXUS_LV.NexusBought = function(shopKey, itemKey)
    local M = NexusShopM()
    if not M then return 0 end
    local n = 0
    pcall(function()
        local p = M.Data.PlayerData and M.Data.PlayerData.EventPurchases
        n = (p and p[shopKey] and p[shopKey][itemKey]) or 0
    end)
    return n or 0
end

NEXUS_LV.NexusShopTimer = function(cfg)
    local e = tonumber(cfg and cfg.EndTimeStamp)
    if not e then return "n/a" end
    local left = e - workspace:GetServerTimeNow()
    if left <= 0 then return "restocking" end
    local d = math.floor(left / 86400)
    local h = math.floor(left % 86400 / 3600)
    local m = math.floor(left % 3600 / 60)
    local s = math.floor(left % 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm %ds", m, s)
end

NEXUS_LV.NexusShopStatus = function(st)
    local cfg = st.cfg
    local cur = cfg.Currency
    local have = NEXUS_LV.NexusCurCount(cur)
    local line = NEXUS_LV.NexusCurName(cur) .. ": " .. NexusComma(have)
    local key = st.sel
    if not key then
        return line .. "  |  no item selected  |  Restock: " .. NEXUS_LV.NexusShopTimer(cfg)
    end
    local it = cfg.Shop[key]
    local price = (it.Price and it.Price[2]) or 0
    local bought = NEXUS_LV.NexusBought(st.key, key)
    local stock = math.max((it.MaxStock or 0) - bought, 0)
    local afford = price > 0 and math.floor(have / price) or 0
    local canBuy = math.min(afford, stock)
    return line
        .. "  |  " .. tostring(it.Title)
        .. "  |  can buy now: " .. NexusComma(canBuy)
        .. "  |  stock: " .. NexusComma(stock) .. "/" .. NexusComma(it.MaxStock or 0)
        .. "  |  bought " .. NexusComma(st.done) .. "/" .. NexusComma(st.target)
        .. "  |  Restock: " .. NEXUS_LV.NexusShopTimer(cfg)
end

NEXUS_LV.NexusShopRefresh = function(st)
    local txt = NEXUS_LV.NexusShopStatus(st)
    if txt == st.lastText then return end
    st.lastText = txt
    pcall(function()
        if st.label.SetText then st.label:SetText(txt) else st.label:Set(txt) end
    end)
end

NEXUS_LV.NexusShopStatusLoop = function()
    if NexusShopStatusOn then return end
    NexusShopStatusOn = true
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            for _, st in pairs(NexusShopState) do NEXUS_LV.NexusShopRefresh(st) end
            task.wait(1)
        end
        NexusShopStatusOn = false
    end)
end

NEXUS_LV.NexusShopStopAuto = function(st, msg, kind)
    st.auto = false
    NexusShopBusy = true
    pcall(function() if st.autoToggle then st.autoToggle:Set(false) end end)
    NexusShopBusy = false
    if msg then NexusShopNotify(msg, kind) end
end

NEXUS_LV.NexusShopCheck = function(st)
    local key = st.sel
    if not key then return false, "Select an item first.", "Warning" end
    local it = st.cfg.Shop[key]
    if not it then return false, "That item is gone from the shop.", "Error" end
    if st.done >= st.target then
        return false, ("Auto Buy finished: %s x%d."):format(it.Title, st.done), "Success"
    end
    local bought = NEXUS_LV.NexusBought(st.key, key)
    if it.MaxStock and bought >= it.MaxStock then
        return false, ("%s is out of stock (%d/%d)."):format(it.Title, bought, it.MaxStock), "Warning"
    end
    local price = (it.Price and it.Price[2]) or 0
    local have = NEXUS_LV.NexusCurCount(st.cfg.Currency)
    if have < price then
        return false, ("You need %s more %s to buy this item.")
            :format(NexusComma(price - have), NEXUS_LV.NexusCurName(st.cfg.Currency)), "Warning"
    end
    return true
end

NEXUS_LV.NexusShopBuyOnce = function(shopKey, itemKey)
    local M = NexusShopM()
    if not M then return false end
    return (pcall(function()
        local p = M.Inv:BuyEventItem(shopKey, itemKey)
        if type(p) == "table" then
            if p.await then p:await() elseif p.Await then p:Await() end
        end
    end))
end

NEXUS_LV.NexusShopAutoLoop = function()
    if NexusShopLoopOn then return end
    NexusShopLoopOn = true
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            local any = false
            for _, st in pairs(NexusShopState) do
                if st.auto then
                    any = true
                    local ok, msg, kind = NEXUS_LV.NexusShopCheck(st)
                    if not ok then
                        NEXUS_LV.NexusShopStopAuto(st, msg, kind)
                    elseif NEXUS_LV.NexusShopBuyOnce(st.key, st.sel) then
                        st.done = st.done + 1
                        st.lastText = nil
                    end
                end
            end
            if not any then break end
            task.wait(0.2)
        end
        NexusShopLoopOn = false
    end)
end

NexusAbx = NexusAbx or {}
NexusAbx.state    = { sel = nil, auto = false, toggles = {}, lastText = nil, label = nil, autoToggle = nil }
NexusAbx.busy     = false
NexusAbx.loopOn   = false
NexusAbx.statusOn = false
NexusAbx.mods     = nil

function NexusAbx.M()
    if NexusAbx.mods then return NexusAbx.mods end
    local ok, m = pcall(function()
        local RS = RepStorage
        local C = NEXUS_LV.Players.LocalPlayer.PlayerScripts.Client.Controllers
        return {
            Npc   = require(RS.Configs.NPCConfig).StaticNPCs.PassiveAbilityExchange,
            Quest = require(RS.Configs.QuestConfig),
            Item  = require(RS.Configs.ItemConfig),
            QC    = require(C.QuestController),
            Data  = require(C.PlayerDataController),
            Char  = require(C.CharacterController),
        }
    end)
    if ok then NexusAbx.mods = m end
    return NexusAbx.mods
end

function NexusAbx.Num(n)

    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function NexusAbx.Notify(msg, kind)
    pcall(function()
        Library:Notify({ Title = "NEXUS EXCHANGE", Content = tostring(msg), Type = kind or "Info", Duration = 6 })
    end)
end

function NexusAbx.ItemName(id)
    local M = NexusAbx.M()
    local it = M and M.Item and M.Item.Items and M.Item.Items[id]
    return tostring((it and it.Name) or id)
end

function NexusAbx.Have(id)
    local M = NexusAbx.M()
    if not M or not id then return 0 end
    local n = 0
    pcall(function()
        local ch = M.Char.LocalCharacter
        if ch and ch.Inventory then
            local s = ch.Inventory:GetSupply(id)
            n = (s and s.Count) or 0
        end
    end)
    return n or 0
end

function NexusAbx.Level()
    local M = NexusAbx.M()
    if not M then return 0 end
    local lv = 0
    pcall(function()
        local s = M.Data.PlayerData and M.Data.PlayerData.Stats
        lv = tonumber(s and s.Level) or 0
    end)
    return lv or 0
end

function NexusAbx.List()
    local M = NexusAbx.M()
    local out = {}
    if not M or not M.Npc then return out end
    pcall(function()
        local main = M.Npc.Interaction and M.Npc.Interaction.Dialogue and M.Npc.Interaction.Dialogue.Main
        for _, entry in ipairs(main or {}) do
            local d = entry.Dialogue
            for _, o in ipairs((d and d.Options) or {}) do
                if o.QuestID then
                    local q = M.Quest.Quests[o.QuestID]
                    if q then
                        out[#out + 1] = {
                            id     = o.QuestID,
                            title  = tostring(q.Name or o.Text or o.QuestID),
                            level  = tonumber(q.Requirements and q.Requirements.Level) or 0,
                            items  = (q.Requirements and q.Requirements.Items) or {},
                            reward = q.Rewards and q.Rewards[1] and q.Rewards[1].ConfigID,
                        }
                    end
                end
            end
        end
    end)
    return out
end

function NexusAbx.CostText(e)
    local parts = {}
    for _, it in ipairs(e.items) do
        parts[#parts + 1] = NexusAbx.Num(it[2]) .. " " .. NexusAbx.ItemName(it[1])
    end
    return table.concat(parts, ", ")
end

function NexusAbx.Check(e)
    local lv = NexusAbx.Level()
    if e.level > 0 and lv < e.level then
        return false, ("needs Lv %s (you are %s)"):format(NexusAbx.Num(e.level), NexusAbx.Num(lv))
    end
    for _, it in ipairs(e.items) do
        local have = NexusAbx.Have(it[1])
        if have < (tonumber(it[2]) or 0) then
            return false, ("needs %s more %s"):format(NexusAbx.Num(it[2] - have), NexusAbx.ItemName(it[1]))
        end
    end
    return true, ""
end

function NexusAbx.Status()
    local st = NexusAbx.state
    local head = "Level: " .. NexusAbx.Num(NexusAbx.Level())
    local e = st.sel
    if not e then return head .. "  |  no ability selected" end
    local mats = {}
    for _, it in ipairs(e.items) do
        mats[#mats + 1] = ("%s %s/%s"):format(NexusAbx.ItemName(it[1]), NexusAbx.Num(NexusAbx.Have(it[1])), NexusAbx.Num(it[2]))
    end
    local ok, why = NexusAbx.Check(e)
    local owned = NexusAbx.Have(e.reward)
    return head
        .. "  |  " .. e.title
        .. "  |  " .. table.concat(mats, ", ")
        .. "  |  " .. (ok and "ready to exchange" or why)
        .. (owned > 0 and ("  |  already owned: " .. NexusAbx.Num(owned)) or "")
end

function NexusAbx.Refresh()
    local st = NexusAbx.state
    if not st.label then return end
    local txt = NexusAbx.Status()
    if txt == st.lastText then return end
    st.lastText = txt
    pcall(function()
        if st.label.SetText then st.label:SetText(txt) else st.label:Set(txt) end
    end)
end

function NexusAbx.StatusLoop()
    if NexusAbx.statusOn then return end
    NexusAbx.statusOn = true
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            NexusAbx.Refresh()
            task.wait(1)
        end
        NexusAbx.statusOn = false
    end)
end

function NexusAbx.StopAuto(msg, kind)
    NexusAbx.state.auto = false
    NexusAbx.busy = true
    pcall(function() if NexusAbx.state.autoToggle then NexusAbx.state.autoToggle:Set(false) end end)
    NexusAbx.busy = false
    if msg then NexusAbx.Notify(msg, kind) end
end

function NexusAbx.ExchangeOnce(e)
    local M = NexusAbx.M()
    if not M then return false end
    return (pcall(function() M.QC:AcceptQuest(e.id) end))
end

function NexusAbx.AutoLoop()
    if NexusAbx.loopOn then return end
    NexusAbx.loopOn = true
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION and NexusAbx.state.auto do
            local e = NexusAbx.state.sel
            if not e then
                NexusAbx.StopAuto("Auto Exchange stopped: nothing selected.", "Warning")
                break
            end
            local ok, why = NexusAbx.Check(e)
            if not ok then
                NexusAbx.StopAuto(("Auto Exchange stopped: %s %s."):format(e.title, why), "Warning")
                break
            end
            local before = NexusAbx.Have(e.reward)
            NexusAbx.ExchangeOnce(e)
            NexusAbx.state.lastText = nil
            task.wait(1)
            if e.reward and NexusAbx.Have(e.reward) > before then
                NexusAbx.StopAuto(("Exchange done: %s."):format(e.title), "Success")
                break
            end
        end
        NexusAbx.loopOn = false
    end)
end

function NexusBuildAbilityExchange(tab)
    local M = NexusAbx.M()
    local list = NexusAbx.List()
    tab:CreateSection("Ability Exchanger")
    if #list == 0 then
        tab:CreateLabel("No passive ability exchanges found in this game.")
        return
    end
    local st = NexusAbx.state
    st.sel, st.auto, st.toggles, st.lastText = nil, false, {}, nil
    st.label = tab:CreateParagraph({
        Title = ((M and M.Npc and tostring(M.Npc.Name)) or "Passive Ability Exchange") .. " \u{2014} Live Status",
        Text  = "loading...",
    })
    nexusRefreshButton(tab)

    for _, e in ipairs(list) do
        local entry = e
        st.toggles[entry.id] = tab:CreateToggle({
            Name = ("Select %s \u{2014} %s"):format(entry.title, NexusAbx.CostText(entry)),
            CurrentValue = false,
            Callback = function(on)
                if NexusAbx.busy then return end
                if on then

                    NexusAbx.busy = true
                    for k, h in pairs(st.toggles) do
                        if k ~= entry.id then pcall(function() h:Set(false) end) end
                    end
                    NexusAbx.busy = false
                    st.sel = entry
                elseif st.sel and st.sel.id == entry.id then
                    st.sel = nil
                    if st.auto then NexusAbx.StopAuto("Auto Exchange stopped: ability deselected.", "Warning") end
                end
                st.lastText = nil
                NexusAbx.Refresh()
            end,
        })
    end

    tab:CreateButton({
        Name = "Exchange Selected Ability",
        Callback = function()
            local e = st.sel
            if not e then
                NexusAbx.Notify("Select an ability first.", "Warning")
                return
            end
            local ok, why = NexusAbx.Check(e)
            if not ok then
                NexusAbx.Notify(("%s: %s."):format(e.title, why), "Warning")
                return
            end
            if NexusAbx.ExchangeOnce(e) then
                NexusAbx.Notify(("Exchange sent: %s."):format(e.title), "Success")
            else
                NexusAbx.Notify(("Exchange failed: %s."):format(e.title), "Error")
            end
            st.lastText = nil
            NexusAbx.Refresh()
        end,
    })

    st.autoToggle = tab:CreateToggle({
        Name = "Auto Exchange",
        CurrentValue = false,
        Callback = function(on)
            if NexusAbx.busy then return end
            if not on then
                st.auto = false
                return
            end
            local e = st.sel
            if not e then
                NexusAbx.StopAuto("Select an ability first.", "Warning")
                return
            end
            local ok, why = NexusAbx.Check(e)
            if not ok then
                NexusAbx.StopAuto(("%s: %s."):format(e.title, why), "Warning")
                return
            end
            st.auto = true
            NexusAbx.AutoLoop()
        end,
    })

    st.lastText = nil
    NexusAbx.Refresh()
    NexusAbx.StatusLoop()
end

-- [NEXUS-OPT] event shops hidden from the Shop tab by user request
NEXUS_SHOP_HIDE_PAT = { "patrick", "summer festival", "ct skin" }
function NexusShopHidden(key)
    local nm = ""
    pcall(function() nm = string.lower(tostring(NEXUS_LV.NexusShopName(key))) end)
    if nm == "" then return false end
    for _, p in ipairs(NEXUS_SHOP_HIDE_PAT) do
        if string.find(nm, p, 1, true) then return true end
    end
    return false
end

function NexusBuildShopTab(tab)
    local M = NexusShopM()
    if not M or not M.Event or not M.Event.ActiveEvents then
        tab:CreateSection("Shop")
        tab:CreateLabel("No exchange shops found in this game.")
        pcall(function() NexusBuildAbilityExchange(tab) end)
        return
    end
    local shops = {}
    for _, key in pairs(M.Event.ActiveEvents) do
        local cfg = M.Event.Events[key]
        if cfg and cfg.Type == "EventShop" and type(cfg.Shop) == "table"
            and not NexusShopHidden(key) then
            shops[#shops + 1] = { key = key, cfg = cfg }
        end
    end
    table.sort(shops, function(a, b) return NEXUS_LV.NexusShopName(a.key) < NEXUS_LV.NexusShopName(b.key) end)
    if #shops == 0 then
        tab:CreateSection("Shop")
        tab:CreateLabel("No exchange shops are active right now.")
        pcall(function() NexusBuildAbilityExchange(tab) end)
        return
    end

    for _, s in ipairs(shops) do
        local cfg = s.cfg
        local st = { key = s.key, cfg = cfg, sel = nil, target = 1, done = 0, auto = false, toggles = {} }
        NexusShopState[s.key] = st

        tab:CreateSection(NEXUS_LV.NexusShopName(s.key))
        st.label = tab:CreateParagraph({ Title = "Live Status", Text = "loading..." })
        nexusRefreshButton(tab)

        local items = {}
        for k, it in pairs(cfg.Shop) do items[#items + 1] = { k = k, it = it } end
        table.sort(items, function(a, b)
            local ao, bo = a.it.LayoutOrder or 999, b.it.LayoutOrder or 999
            if ao ~= bo then return ao < bo end
            return tostring(a.it.Title) < tostring(b.it.Title)
        end)

        for _, e in ipairs(items) do
            local key, it = e.k, e.it
            local price = (it.Price and it.Price[2]) or 0
            local label = ("Select %s \u{2014} %s %s"):format(
                tostring(it.Title), NexusComma(price), NEXUS_LV.NexusCurName((it.Price and it.Price[1]) or cfg.Currency))
            st.toggles[key] = tab:CreateToggle({
                Name = label,
                CurrentValue = false,
                Callback = function(on)
                    if NexusShopBusy then return end
                    if on then

                        NexusShopBusy = true
                        for k2, h in pairs(st.toggles) do
                            if k2 ~= key then pcall(function() h:Set(false) end) end
                        end
                        NexusShopBusy = false
                        st.sel, st.done = key, 0
                        pcall(function() st.input:SetTitle("How many to buy \u{2014} " .. tostring(it.Title)) end)
                    elseif st.sel == key then
                        st.sel = nil
                        pcall(function() st.input:SetTitle("How many to buy (select an item first)") end)
                        if st.auto then NEXUS_LV.NexusShopStopAuto(st, "Auto Buy stopped: item deselected.", "Warning") end
                    end
                    st.lastText = nil
                    NEXUS_LV.NexusShopRefresh(st)
                end,
            })
        end

        st.input = tab:CreateInput({
            Name = "How many to buy (select an item first)",
            CurrentValue = "1",
            PlaceholderText = "amount",
            Callback = function(txt)
                local n = math.floor(tonumber(txt) or 1)
                st.target = math.max(1, n)
                st.done = 0
                st.lastText = nil
            end,
        })

        st.autoToggle = tab:CreateToggle({
            Name = "Auto Buy",
            CurrentValue = false,
            Callback = function(on)
                if NexusShopBusy then return end
                if not on then
                    st.auto = false
                    return
                end
                local ok, msg, kind = NEXUS_LV.NexusShopCheck(st)
                if not ok then
                    st.done = 0
                    NEXUS_LV.NexusShopStopAuto(st, msg, kind)
                    return
                end
                st.done = 0
                st.auto = true
                NEXUS_LV.NexusShopAutoLoop()
            end,
        })

        NEXUS_LV.NexusShopRefresh(st)
    end

    pcall(function() NexusBuildAbilityExchange(tab) end)

    NEXUS_LV.NexusShopStatusLoop()
end

NEXUS_LOADER_URL = "https://raw.githubusercontent.com/soseb928/nexus-hub/refs/heads/main/NexusPlay_Hub.lua"
AutoExecOn       = false
AutoExecDelayOn  = false
AutoExecDelaySec = 0
NEXUS_DELAY_OPTIONS = { 5, 10, 15, 20, 30, 40, 50, 60 }
NexusDelayToggles = {}
NexusDelayBusy    = false

do
(function()
    for _, s in ipairs(NEXUS_DELAY_OPTIONS) do
        if AutoExecDelaySec == 0 and S("AutoExecDelay" .. tostring(s), false) then
            AutoExecDelaySec = s
            AutoExecDelayOn  = true
        end
    end
end)()
end

NEXUS_AUTOEXEC_NAME = "NexusPlayHub_AutoExec"
NEXUS_AUTOEXEC_EXTS = { ".lua", ".txt" }
NEXUS_AUTOEXEC_DIRS = {
    "autoexec", "Autoexec", "AutoExec", "AUTOEXEC", "autoexecute", "auto_exec", "autoexecs",
    "scripts/autoexec", "Scripts/autoexec", "workspace/autoexec", "Workspace/autoexec",
    "../autoexec", "../Autoexec", "../AutoExec", "../autoexecute", "../workspace/autoexec",
}
NEXUS_AUTOEXEC_WROTE = {}
NexusQueueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueteleport or queue_teleport
NexusQueueArmed = false

function NexusAutoExecDelaySec()
    local sec = tonumber(AutoExecDelaySec) or 0
    if not AutoExecDelayOn then sec = 0 end
    if sec < 0 then sec = 0 end
    return sec
end

function NexusAutoExecCode()
    local url = NEXUS_LOADER_URL
    if type(url) ~= "string" or #url == 0 then return nil end
    local sec = NexusAutoExecDelaySec()
    local out = "-- NexusPlayHub auto execute (auto generated, delay " .. tostring(sec) .. " sec)\n"

    out = out .. "local NEXUS_W = (task and task.wait) or wait\n"
    out = out .. "if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end\n"
    out = out .. "local NEXUS_P = game:GetService(\"Players\")\n"
    out = out .. "while not NEXUS_P.LocalPlayer do NEXUS_W(0.1) end\n"
    if sec > 0 then

        out = out .. "NEXUS_W(" .. sec .. ")\n"
    end
    out = out .. "loadstring(game:HttpGet(\"" .. url .. "\"))()\n"
    return out
end

function NexusAutoExecArm()
    if NexusQueueArmed or not NexusQueueTeleport then return false end
    if not AutoExecOn then return false end
    local code = NexusAutoExecCode()
    if not code then return false end
    local ok = pcall(NexusQueueTeleport, code)
    if ok then NexusQueueArmed = true end
    return ok
end

function NexusAutoExecDisarm()
    NexusQueueArmed = false
    pcall(function()
        if NexusQueueTeleport then NexusQueueTeleport("") end
    end)
end

function NexusAutoExecSave()
    local code = NexusAutoExecCode()
    if not (code and writefile) then return false end
    local wrote = false
    NEXUS_AUTOEXEC_WROTE = {}
    for _, d in ipairs(NEXUS_AUTOEXEC_DIRS) do
        pcall(function()
            if isfolder and makefolder and not isfolder(d) then pcall(makefolder, d) end
            if (not isfolder) or isfolder(d) then
                for _, ext in ipairs(NEXUS_AUTOEXEC_EXTS) do
                    local path = d .. "/" .. NEXUS_AUTOEXEC_NAME .. ext
                    local ok = pcall(writefile, path, code)
                    if ok and ((not isfile) or isfile(path)) then
                        wrote = true
                        NEXUS_AUTOEXEC_WROTE[#NEXUS_AUTOEXEC_WROTE + 1] = path
                    end
                end
            end
        end)
    end

    if not wrote then
        for _, ext in ipairs(NEXUS_AUTOEXEC_EXTS) do
            pcall(function()
                local path = NEXUS_AUTOEXEC_NAME .. ext
                writefile(path, code)
                wrote = true
                NEXUS_AUTOEXEC_WROTE[#NEXUS_AUTOEXEC_WROTE + 1] = path
            end)
        end
    end
    return wrote
end

function NexusAutoExecRemove()
    for _, d in ipairs(NEXUS_AUTOEXEC_DIRS) do
        for _, ext in ipairs(NEXUS_AUTOEXEC_EXTS) do
            pcall(function()
                local path = d .. "/" .. NEXUS_AUTOEXEC_NAME .. ext
                if isfile and isfile(path) then
                    if delfile then pcall(delfile, path) end
                    if isfile(path) and writefile then pcall(writefile, path, "") end
                end
            end)
        end
    end
    for _, ext in ipairs(NEXUS_AUTOEXEC_EXTS) do
        pcall(function()
            local path = NEXUS_AUTOEXEC_NAME .. ext
            if isfile and isfile(path) then
                if delfile then pcall(delfile, path) end
                if isfile(path) and writefile then pcall(writefile, path, "") end
            end
        end)
    end
    NEXUS_AUTOEXEC_WROTE = {}
end

function NexusAddDelaySwitch(section, sec)
    local key = "AutoExecDelay" .. tostring(sec)
    local v = S(key, false)
    if v and AutoExecDelaySec == 0 then
        AutoExecDelaySec = sec
        AutoExecDelayOn  = true
    elseif v and AutoExecDelaySec ~= sec then

        v = false
        Settings[key] = false
    end
    NexusDelayToggles[sec] = section:CreateToggle({
        Name = tostring(sec) .. " Sec Auto execute delay",
        CurrentValue = v,
        Callback = function(on)
            if NexusDelayBusy then return end
            if on then
                NexusDelayBusy = true
                for s2, o2 in pairs(NexusDelayToggles) do
                    if s2 ~= sec then
                        pcall(function() o2:Set(false) end)
                        Settings["AutoExecDelay" .. tostring(s2)] = false
                    end
                end
                NexusDelayBusy = false
                AutoExecDelaySec = sec
                AutoExecDelayOn  = true
            elseif AutoExecDelaySec == sec then
                AutoExecDelaySec = 0
                AutoExecDelayOn  = false
            end
            Settings[key] = on
            saveSettings()
            task.spawn(function() pcall(NexusAutoExecApply) end)
        end,
    }, "NEXUS_" .. key)
end

function NexusAutoExecApply()
    if AutoExecOn then
        NexusAutoExecSave()
        NexusAutoExecArm()
    else
        NexusAutoExecRemove()
        NexusAutoExecDisarm()
    end
end

pcall(function()
    CONNS[#CONNS + 1] = NEXUS_LV.Players.LocalPlayer.OnTeleport:Connect(function(State)
        if not AutoExecOn then return end
        if State == Enum.TeleportState.Failed then NexusQueueArmed = false end
        NexusAutoExecArm()
    end)
end)
pcall(function()
    CONNS[#CONNS + 1] = game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        NexusQueueArmed = false
        if AutoExecOn then NexusAutoExecArm() end
    end)
end)

task.spawn(function()
    task.wait(2)
    pcall(NexusAutoExecApply)
end)

EvoQ1On, EvoQ3On            = false, false
OffQ1On, OffQ2On, OffQ3On   = false, false, false
VitQ1On, VitQ2On, VitQ3On   = false, false, false

function NexusEvoAnyOn()
    return EvoQ1On or EvoQ3On or OffQ1On or OffQ2On or OffQ3On or VitQ1On or VitQ2On or VitQ3On
end

function NexusEvoAccept(id, times)
    for _ = 1, (times or 1) do
        NexusSafeAccept(id)
        task.wait(0.15)
    end
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusEvoAnyOn() then
            if EvoQ1On then NexusSafeAccept("Evolution1") end
            if EvoQ3On then NexusSafeAccept("Evolution3") end
            if OffQ1On then NexusSafeAccept("Offense1") end
            if OffQ2On then NexusSafeAccept("Offense2") end
            if OffQ3On then NexusSafeAccept("Offense3") end
            if VitQ1On then NexusSafeAccept("Vitality1") end
            if VitQ2On then NexusSafeAccept("Vitality2") end
            if VitQ3On then NexusSafeAccept("Vitality3") end
            task.wait(0.5)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

sorcAddCache   = {}
sorcBossLocked = false

NexusBossFrameCache = NexusBossFrameCache or { frame = nil }
function shadowRaidBossFrame()
    local cached = NexusBossFrameCache.frame
    if cached and cached.Parent then return cached end
    NexusBossFrameCache.frame = nil

    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local hud = pg:FindFirstChild("HUD")
    if hud then
        local fr = hud:FindFirstChild("Frame")
        local cf = fr and fr:FindFirstChild("ContentFrame")
        local bh = cf and cf:FindFirstChild("BossHP")
        if bh then NexusBossFrameCache.frame = bh return bh end
    end

    local found
    pcall(function() found = pg:FindFirstChild("BossHP", true) end)
    NexusBossFrameCache.frame = found
    return found
end

function shadowRaidHpText()
    local bh = shadowRaidBossFrame(); if not bh then return "" end
    local out = ""
    pcall(function()
        local mp = bh:FindFirstChild("MainPart")
        local de = mp and mp:FindFirstChild("Detail")
        local hp = de and de:FindFirstChild("HP")
        if not hp then hp = bh:FindFirstChild("HP", true) end
        if hp then out = tostring(hp.Text) end
    end)
    return out
end

function shadowRaidTextImmune(t)
    t = string.lower(tostring(t or ""))
    if t == "" then return false end
    t = string.gsub(t, "<[^>]->", "")
    t = string.gsub(t, "[^%a]", "")
    return string.find(t, "immune", 1, true) ~= nil
end

function shadowRaidReadImmune()
    if shadowRaidTextImmune(shadowRaidHpText()) then return true end
    local hit = false
    pcall(function()
        local bh = shadowRaidBossFrame()
        if not bh then return end
        for _, d in ipairs(bh:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and shadowRaidTextImmune(d.Text) then hit = true return end
        end
    end)
    if hit then return true end
    pcall(function()
        local ClientF = Characters and Characters:FindFirstChild("Client")
        if not ClientF then return end
        for _, d in ipairs(clientLabels(ClientF)) do
            if d:IsA("TextLabel") and shadowRaidTextImmune(d.Text) then hit = true return end
        end
    end)
    return hit
end

function shadowRaidModelsFromTags(tags)
    local out = {}
    local ClientF = Characters and Characters:FindFirstChild("Client")
    if not ClientF or not NPCsF or not tags then return out end
    local spots = {}
    for _, d in ipairs(clientLabels(ClientF)) do
        if d:IsA("TextLabel") then
            local low = string.lower(tostring(d.Text))
            for _, tg in ipairs(tags) do
                if string.find(low, tg, 1, true) then
                    local rig = d:FindFirstAncestorWhichIsA("Model")
                    local h = rig and rig:FindFirstChild("HumanoidRootPart")
                    if h then table.insert(spots, h.Position) end
                    break
                end
            end
        end
    end
    if #spots == 0 then return out end
    local seen = {}
    for _, m in ipairs(NPCsF:GetChildren()) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h and not seen[m] and nexusValidNpc(m) then
            for _, p in ipairs(spots) do
                if (h.Position - p).Magnitude < 25 then
                    seen[m] = true
                    table.insert(out, m)
                    break
                end
            end
        end
    end
    return out
end

function shadowRaidHighlightSpots()
    local spots = {}
    local ClientF = Characters and Characters:FindFirstChild("Client")
    if not ClientF then return spots end

    for _, d in ipairs(clientDesc(ClientF)) do
        if string.find(string.lower(d.Name), "bosshighlight", 1, true) then
            local rig = d:FindFirstAncestorWhichIsA("Model")
            if rig then
                local p
                pcall(function()
                    local h = rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChild("Hitbox")
                    if h and h:IsA("BasePart") then
                        p = h.Position
                    elseif h and h:IsA("Model") then
                        p = h:GetPivot().Position
                    else
                        p = rig:GetPivot().Position
                    end
                end)
                if p then table.insert(spots, p) end
            end
        end
    end
    return spots
end

NexusBringRaidOn        = false
NEXUS_RAID_BRING_RANGE  = 350
NEXUS_RAID_BRING_OFFSET = 4
NexusRaidBringOrigins   = {}
pcall(function() NexusPruneRegister(function() return NexusRaidBringOrigins end) end)
function nexusRaidBringRestore()
    for m, cf in pairs(NexusRaidBringOrigins) do
        if m and m.Parent then
            local h = m:FindFirstChild("HumanoidRootPart")
            if h then pcall(function() h.CFrame = cf end) end
        end
    end
    NexusRaidBringOrigins = {}
end

function nexusRaidNpcTags()
    local tags = {}
    local function add(t)
        if type(t) == "string" and t ~= "" then table.insert(tags, string.lower(t)) end
    end
    add(OUTER_BOSS_TAG)
    add("star remnant")
    return tags
end

function nexusRaidNpcList()
    local out, seen = {}, {}

    local okS, sorc = pcall(sorcRaidModels)
    if okS and type(sorc) == "table" then
        for _, m in ipairs(sorc) do
            if m and m.Parent and nexusValidNpc(m) and not seen[m] then
                seen[m] = true
                table.insert(out, m)
            end
        end
    end

    local ok, list = pcall(shadowRaidModelsFromTags, nexusRaidNpcTags())
    if ok and type(list) == "table" then
        for _, m in ipairs(list) do
            if m and m.Parent and nexusValidNpc(m) and not seen[m] then
                seen[m] = true
                table.insert(out, m)
            end
        end
    end

    local spots
    pcall(function() spots = shadowRaidHighlightSpots() end)
    if type(spots) == "table" and #spots > 0 and NPCsF then
        for _, m in ipairs(NPCsF:GetChildren()) do
            if not seen[m] and nexusValidNpc(m) then
                local h = m:FindFirstChild("HumanoidRootPart")
                if h then
                    for _, p in ipairs(spots) do
                        if (h.Position - p).Magnitude < 40 then
                            seen[m] = true
                            table.insert(out, m)
                            break
                        end
                    end
                end
            end
        end
    end
    return out
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusBringRaidOn then
            pcall(function()
                local mm = getModel()
                local hrp = mm and mm:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local range = tonumber(NEXUS_RAID_BRING_RANGE) or 350
                local near, far, farH, farD = {}, nil, nil, nil
                for _, m in ipairs(nexusRaidNpcList()) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then
                        local d = (h.Position - hrp.Position).Magnitude
                        if d <= range then
                            table.insert(near, m)
                        elseif not farD or d < farD then
                            far, farH, farD = m, h, d
                        end
                    end
                end

                if #near == 0 then
                    if farH then nexusTpTo(farH.Position + Vector3.new(0, 3, 0)) end
                    return
                end

                for i, m in ipairs(near) do
                    local h = m:FindFirstChild("HumanoidRootPart")
                    if h then
                        if not NexusRaidBringOrigins[m] then NexusRaidBringOrigins[m] = h.CFrame end
                        local angle = (i / #near) * math.pi * 2
                        local off = Vector3.new(math.cos(angle) * NEXUS_RAID_BRING_OFFSET, 0, math.sin(angle) * NEXUS_RAID_BRING_OFFSET)
                        pcall(function()
                            local goal = hrp.Position + off

                            local dx, dy, dz = h.Position.X - goal.X, h.Position.Y - goal.Y, h.Position.Z - goal.Z
                            if (dx * dx + dy * dy + dz * dz) > 0.25 then
                                h.AssemblyLinearVelocity = Vector3.zero
                                h.CFrame = CFrame.new(goal)
                            end
                        end)
                    end
                end
                NexusQ(NexusBringPump, near, mm, hrp)
            end)
        end
        task.wait(NexusBringRaidOn and LOOP_GAP or NEXUS_IDLE)
    end
end)

SORC_MAIN_ID  = "RaidMegumi"
SORC_ADD_IDS  = { IslandKuro = true, IslandShiro = true }
SORC_FINAL_ID = "IslandMahoraga"
SORC_BRING_OFFSET = 4
sorcAICtrl = nil
function sorcAIController()
    if sorcAICtrl then return sorcAICtrl end
    pcall(function()
        local ps  = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
        local cl  = ps and ps:FindFirstChild("Client")
        local ctr = cl and cl:FindFirstChild("Controllers")
        local ai  = ctr and ctr:FindFirstChild("AIController")
        if ai then sorcAICtrl = require(ai) end
    end)
    return sorcAICtrl
end

function sorcLiveAIs()
    local out = {}
    local ai = sorcAIController()
    if not ai or type(ai.ActiveAIs) ~= "table" then return out end
    pcall(function()
        for sm, obj in pairs(ai.ActiveAIs) do
            if sm and sm.Parent and obj then
                local id, st
                pcall(function() id = obj.AIStates and obj.AIStates.NPCConfig and obj.AIStates.NPCConfig.ID end)
                if not id then pcall(function() id = obj.Character and obj.Character._imfunny end) end
                pcall(function() st = obj.Character and obj.Character.CharacterStates end)
                local hum = sm:FindFirstChildOfClass("Humanoid")
                if id and hum and hum.Health > 0 then
                    table.insert(out, { model = sm, id = tostring(id), states = st })
                end
            end
        end
    end)
    return out
end

function sorcMainModel()
    for _, e in ipairs(sorcLiveAIs()) do
        if e.id == SORC_MAIN_ID and nexusValidNpc(e.model) then return e.model, e.states end
    end
    return nil, nil
end

function sorcFinalModel()
    for _, e in ipairs(sorcLiveAIs()) do
        if e.id == SORC_FINAL_ID and nexusValidNpc(e.model) then return e.model, e.states end
    end
    return nil, nil
end

function sorcAddModels()
    local out = {}
    for _, e in ipairs(sorcLiveAIs()) do
        if e.id ~= SORC_MAIN_ID and e.id ~= SORC_FINAL_ID and nexusValidNpc(e.model) then
            local isAdd = SORC_ADD_IDS[e.id] == true
            if not isAdd and e.states and e.states.IsShikigami then isAdd = true end
            if isAdd then table.insert(out, e.model) end
        end
    end
    return out
end

function sorcRaidModels()
    local out, seen = {}, {}
    local function push(m)
        if m and m.Parent and not seen[m] then seen[m] = true table.insert(out, m) end
    end
    push((sorcMainModel()))
    for _, m in ipairs(sorcAddModels()) do push(m) end
    push((sorcFinalModel()))
    return out
end

function sorcModelById(id)
    if not id then return nil, nil end
    for _, e in ipairs(sorcLiveAIs()) do
        if e.id == id and nexusValidNpc(e.model) then return e.model, e.states end
    end
    return nil, nil
end

function sorcImmuneOf(st)
    if st then
        local a = tonumber(st.IsImmortal) or 0
        local b = tonumber(st.IsInvincible) or 0
        if a > 0 or b > 0 then return true end
    end
    local hud = false
    pcall(function() hud = shadowRaidReadImmune() end)
    return hud
end
function sorcMainImmune()
    local m, st = sorcMainModel()
    if not m then return false end
    return sorcImmuneOf(st)
end

function sorcAddQuota()
    local killed, total
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name ~= "NexusPlayHub" then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local a, b = string.match(tostring(d.Text), "Shikigami%s*(%d+)%s*/%s*(%d+)")
                        if a and b then killed, total = tonumber(a), tonumber(b) return end
                    end
                end
            end
        end
    end)
    return killed, total
end

function sorcAddsCleared()
    local killed, total = sorcAddQuota()
    if killed and total then
        if killed < total then return false end
        return #sorcAddModels() == 0
    end
    return #sorcAddModels() == 0
end

function sorcReadyUp()
    local up = false
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name ~= "NexusPlayHub" then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local low = string.lower(tostring(d.Text))
                        if low == "ready" or string.find(low, "ready ending in", 1, true) then
                            up = true
                            return
                        end
                    end
                end
            end
        end
    end)
    return up
end

function sorcClickReady()
    pcall(function() ReadySignal:FireServer() end)
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name ~= "NexusPlayHub" then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextButton") and string.lower(tostring(d.Text)) == "ready" then
                        local fs = rawget(getfenv(), "firesignal")
                        if type(fs) == "function" then
                            pcall(function() fs(d.Activated) end)
                            pcall(function() fs(d.MouseButton1Click) end)
                        end
                    end
                end
            end
        end
    end)
end

sorcTick = 0
function sorcNearest(list, pos)
    local best, bd
    for _, m in ipairs(list) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h then
            local d = (h.Position - pos).Magnitude
            if not bd or d < bd then best, bd = m, d end
        end
    end
    return best
end
function sorcStrike(list, mdl, hrp)
    if not mdl or not hrp or #list == 0 then return end
    local near = sorcNearest(list, hrp.Position)
    local nh = near and near:FindFirstChild("HumanoidRootPart")
    if nh then
        pcall(function()
            local goal = auraGoal(nh)
            if (hrp.Position - goal.Position).Magnitude > STICK_OFFSET + 3 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = goal
            end
        end)
    end
    if not (FastOn or BlackFlashOn) then
        sorcTick = sorcTick + 1
        if sorcTick % 2 == 0 then
            enableBlackFlash()
            NexusQ(pcall, blackFlashList, list, mdl, hrp)
        else
            NexusQ(pcall, attackList, list, mdl, hrp)
        end
    end
end

function sorcEngage(list, mdl, hrp)
    if type(list) ~= "table" or not mdl or not hrp then return 0 end
    local live = {}
    for _, m in ipairs(list) do
        if m and m.Parent and nexusValidNpc(m) and m:FindFirstChild("HumanoidRootPart") then
            table.insert(live, m)
        end
    end
    sorcAddCache = live
    if #live == 0 then return 0 end
    if not NexusBringRaidOn then
        sorcStrike(live, mdl, hrp)
        return #live
    end
    local range = tonumber(NEXUS_RAID_BRING_RANGE) or 350
    local near, far, farD = {}, nil, nil
    for _, m in ipairs(live) do
        local h = m:FindFirstChild("HumanoidRootPart")
        local d = (h.Position - hrp.Position).Magnitude
        if d <= range then
            table.insert(near, m)
        elseif not farD or d < farD then
            far, farD = m, d
        end
    end
    if #near == 0 then
        if far then
            local h = far:FindFirstChild("HumanoidRootPart")
            if h then nexusTpTo(h.Position + Vector3.new(0, 3, 0)) end
        end
        return 0
    end
    for i, m in ipairs(near) do
        local h = m:FindFirstChild("HumanoidRootPart")
        if h then
            if type(NexusRaidBringOrigins) == "table" and not NexusRaidBringOrigins[m] then
                NexusRaidBringOrigins[m] = h.CFrame
            end
            local ang  = (i / #near) * math.pi * 2
            local goal = hrp.Position + Vector3.new(math.cos(ang) * SORC_BRING_OFFSET, 0, math.sin(ang) * SORC_BRING_OFFSET)
            pcall(function()
                local dx, dy, dz = h.Position.X - goal.X, h.Position.Y - goal.Y, h.Position.Z - goal.Z
                if (dx * dx + dy * dy + dz * dz) > 0.25 then
                    h.AssemblyLinearVelocity = Vector3.zero
                    h.CFrame = CFrame.new(goal)
                end
            end)
        end
    end
    NexusQ(NexusBringPump, near, mdl, hrp)
    return #near
end

AutoSorcRaidOn   = false
sorcSawMain      = false
sorcSawFinal     = false
sorcReadyAt      = 0
sorcPhase        = "idle"
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoSorcRaidOn and nexusInRaidServer() then
            pcall(function()
                local mdl = getModel()
                local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                if sorcReadyUp() and (os.clock() - sorcReadyAt) > 3 then
                    sorcReadyAt = os.clock()
                    sorcPhase = "ready"
                    sorcClickReady()
                end
                local final = sorcFinalModel()
                local main  = sorcMainModel()
                local adds  = sorcAddModels()
                if final then

                    sorcSawFinal = true
                    sorcPhase = "final boss"
                    sorcBossLocked = true
                    local list = { final }
                    for _, m in ipairs(adds) do table.insert(list, m) end
                    sorcEngage(list, mdl, hrp)
                elseif main then
                    sorcSawMain = true
                    if sorcMainImmune() then

                        sorcBossLocked = true
                        if #adds > 0 then
                            sorcPhase = "adds"
                            sorcEngage(adds, mdl, hrp)
                        elseif not sorcAddsCleared() then

                            sorcPhase = "waiting for adds"
                            task.wait(0.1)
                        else

                            sorcPhase = "waiting for immunity to drop"
                            task.wait(0.1)
                        end
                    else

                        sorcPhase = "main npc"
                        sorcBossLocked = false
                        local list = { main }
                        for _, m in ipairs(adds) do table.insert(list, m) end
                        sorcEngage(list, mdl, hrp)
                    end
                elseif #adds > 0 then

                    sorcPhase = "adds"
                    sorcEngage(adds, mdl, hrp)
                elseif sorcSawMain or sorcSawFinal then

                    sorcPhase = "clear - confirming"
                    clickPopup("next"); clickPopup("close")
                    local clear, waited = true, 0
                    while waited < NEXUS_RAID_RETRY_WAIT do
                        task.wait(0.1)
                        waited = waited + 0.1
                        if not AutoSorcRaidOn then clear = false break end
                        if sorcMainModel() or sorcFinalModel() or #sorcAddModels() > 0 then clear = false break end
                    end
                    if clear and AutoSorcRaidOn then
                        sorcPhase = "retry"
                        pcall(function() RetrySignal:InvokeServer() end)
                        sorcSawMain, sorcSawFinal = false, false
                        task.wait(1)
                    end
                else
                    sorcPhase = "waiting for raid"
                end
            end)
            task.wait(LOOP_GAP)
        else
            sorcSawMain, sorcSawFinal = false, false
            sorcAddCache = {}
            sorcBossLocked = false
            sorcPhase = "idle"
            task.wait(NEXUS_IDLE)
        end
    end
end)

NEXUS_RAID_RETRY_WAIT = 1
YUKI_RAID_ID  = "Yuki"
yukiSpecCache = nil
function yukiSpec()
    if yukiSpecCache then return yukiSpecCache end
    pcall(function()
        local RS  = RepStorage
        local cfg = require(RS.Configs.RaidsConfig)
        local y   = cfg and cfg.RaidsData and cfg.RaidsData[YUKI_RAID_ID]
        if not y or not y.BaseNPCConfig then return end
        local s = {
            raidName     = tostring(y.Name),
            mainId       = tostring(y.BaseNPCConfig.ID),
            mainName     = tostring(y.BaseNPCConfig.Name),
            minionIds    = {},
            minionNames  = {},
            immunePhases = 0,
            phases       = {},
        }
        for _, key in ipairs({ "StarRemnantBaseNPCConfig", "GravityCoreBaseNPCConfig" }) do
            local c = y[key]
            if c and c.ID then
                s.minionIds[tostring(c.ID)] = true
                table.insert(s.minionNames, tostring(c.Name or c.ID))
            end
        end
        local ph = y.BaseNPCConfig.SkillMoveset and y.BaseNPCConfig.SkillMoveset.Phases
        if type(ph) == "table" then
            for _, p in pairs(ph) do
                if type(p) == "table" and p.PhaseLock then
                    s.immunePhases = s.immunePhases + 1
                    table.insert(s.phases, tostring(p.ID) .. "@" .. tostring(p.HealthPercent))
                end
            end
        end
        if s.mainId ~= "nil" then yukiSpecCache = s end
    end)
    return yukiSpecCache
end

function yukiMainModel()
    local s = yukiSpec()
    if not s then return nil, nil end
    return sorcModelById(s.mainId)
end

function yukiMinionModels()
    local s = yukiSpec()
    local mainId = s and s.mainId or nil
    local byId, others = {}, {}
    for _, e in ipairs(sorcLiveAIs()) do
        if e.id ~= mainId and nexusValidNpc(e.model) then
            if s and s.minionIds[e.id] then
                table.insert(byId, e.model)
            else
                table.insert(others, e.model)
            end
        end
    end
    for _, m in ipairs(others) do table.insert(byId, m) end
    return byId
end

function yukiBreakables(myPos)
    local out = {}
    if not myPos then return out end
    local range = tonumber(NEXUS_LV.AURA_RANGE) or 350
    local function scan(folder)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and not m:FindFirstChildOfClass("Humanoid") then
                local h = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                local bad = false
                pcall(function()
                    if nexusIsPlayerModel(m) or nexusIsPetModel(m) then bad = true end
                end)
                if h and not bad and (h.Position - myPos).Magnitude <= range then table.insert(out, m) end
            end
        end
    end
    scan(NPCsF)
    if NEXUS_LV.ServerF then
        for _, f in ipairs(NEXUS_LV.ServerF:GetChildren()) do
            if f:IsA("Folder") and f ~= NPCsF and f ~= PlayersF then scan(f) end
        end
    end
    return out
end

yukiSawMain   = false
yukiReadyAt   = 0
yukiPhaseSeen = 0
yukiPhase     = "idle"
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoOuterRaidOn and nexusInRaidServer() then
            pcall(function()
                local mdl = getModel()
                local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                inOuterRaid = true

                if sorcReadyUp() and (os.clock() - yukiReadyAt) > 3 then
                    yukiReadyAt = os.clock()
                    yukiPhase = "ready"
                    sorcClickReady()
                end
                local main, mstates = yukiMainModel()
                if main then
                    yukiSawMain = true
                    if sorcImmuneOf(mstates) then

                        local mins = yukiMinionModels()
                        for _, m in ipairs(yukiBreakables(hrp.Position)) do table.insert(mins, m) end
                        outerAddCache = mins
                        sorcBossLocked = true
                        if #mins > 0 then
                            local s = yukiSpec()
                            yukiPhase = "immunity phase " .. tostring(yukiPhaseSeen + 1)
                                .. (s and (" of " .. tostring(s.immunePhases)) or "")
                            sorcEngage(mins, mdl, hrp)
                        else

                            yukiPhase = "waiting for minions"
                            task.wait(0.1)
                        end
                    else

                        if sorcBossLocked then yukiPhaseSeen = yukiPhaseSeen + 1 end
                        sorcBossLocked = false
                        outerAddCache = {}
                        yukiPhase = "main npc"
                        local list = { main }

                        for _, m in ipairs(yukiMinionModels()) do table.insert(list, m) end
                        sorcEngage(list, mdl, hrp)
                    end
                else
                    local mins = yukiMinionModels()
                    if #mins > 0 then

                        outerAddCache = mins
                        yukiPhase = "minions"
                        sorcEngage(mins, mdl, hrp)
                    elseif yukiSawMain then

                        sorcBossLocked = false
                        outerAddCache = {}
                        yukiPhase = "complete - confirming"
                        clickPopup("next"); clickPopup("close")
                        local clear, waited = true, 0
                        while waited < NEXUS_RAID_RETRY_WAIT do
                            task.wait(0.1)
                            waited = waited + 0.1
                            if not AutoOuterRaidOn then clear = false break end
                            if yukiMainModel() or #yukiMinionModels() > 0 then clear = false break end
                        end
                        if clear and AutoOuterRaidOn then
                            yukiPhase = "retry"
                            pcall(function() RetrySignal:InvokeServer() end)
                            yukiSawMain = false
                            yukiPhaseSeen = 0
                            task.wait(0.5)
                        end
                    else
                        yukiPhase = "waiting for raid"
                        outerAddCache = {}
                    end
                end
            end)
            task.wait(LOOP_GAP)
        else
            inOuterRaid = false
            yukiSawMain = false
            yukiPhaseSeen = 0
            yukiPhase = "idle"
            outerAddCache = {}
            task.wait(NEXUS_IDLE)
        end
    end
end)

AutoJogoRaidOn = false
inJogoRaid     = false
JOGO_RAID_ID   = "Jogo"
JogoSkipSignal = nil
pcall(function() JogoSkipSignal = Net.RaidsService.SkipCurrentHandler_Signal end)
jogoSpecCache = nil

function jogoSpec()
    if jogoSpecCache then return jogoSpecCache end
    pcall(function()
        local RS  = RepStorage
        local cfg = require(RS.Configs.RaidsConfig)
        local j   = cfg and cfg.RaidsData and cfg.RaidsData[JOGO_RAID_ID]
        if not j or not j.BaseNPCConfig then return end
        local s = {
            raidName    = tostring(j.Name),
            bossId      = tostring(j.BaseNPCConfig.ID),
            bossName    = tostring(j.BaseNPCConfig.Name),
            minionIds   = {},
            minionNames = {},
            pillarIds   = {},
            lockPhases  = {},
            endsOnBossDeath = (j.DontEndOnBossDeath ~= true),
        }
        local names = nil
        pcall(function() names = require(RS.Configs.NPCConfig.NPCs.JogoRaidNPCs) end)
        local function addMinion(id)
            if not id then return end
            id = tostring(id)
            if s.minionIds[id] then return end
            s.minionIds[id] = true
            local nm = names and names[id] and names[id].Name
            table.insert(s.minionNames, tostring(nm or id))
        end
        for _, e in ipairs(j.StartingNPC or {}) do
            addMinion(e.NPCConfig and e.NPCConfig.ID or e.ID)
        end
        for _, e in ipairs(j.Phase50NPC or {}) do addMinion(e.ID) end
        for _, e in ipairs(j.FirePillarNPC or {}) do
            if e.ID then s.pillarIds[tostring(e.ID)] = true end
        end
        local ph = j.BaseNPCConfig.SkillMoveset and j.BaseNPCConfig.SkillMoveset.Phases
        if type(ph) == "table" then
            for _, p in pairs(ph) do
                if type(p) == "table" and p.PhaseLock then
                    table.insert(s.lockPhases, tonumber(p.HealthPercent) or 0)
                end
            end
            table.sort(s.lockPhases, function(a, b) return a > b end)
        end
        if s.bossId ~= "nil" then jogoSpecCache = s end
    end)
    return jogoSpecCache
end

function jogoRaidController()
    local rc
    pcall(function() rc = require(LocalPlayer.PlayerScripts.Client.Controllers.RaidController) end)
    return rc
end
function jogoNpcFolder()
    local f
    pcall(function() f = workspace.Characters.Server.NPCs end)
    return f
end
function jogoAlive(m)
    if not m or not m.Parent then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    return m:FindFirstChild("HumanoidRootPart") ~= nil or m.PrimaryPart ~= nil
end

function jogoBossModel()
    local rb = jogoRaidController()
    rb = rb and rb.RaidBoss
    if rb then
        local mdl = rb.ServerModel
        if mdl and jogoAlive(mdl) then
            return mdl, (rb.Character and rb.Character.CharacterStates) or rb.AIStates
        end
    end
    local s = jogoSpec()
    if s then
        local mdl, st = sorcModelById(s.bossId)
        if mdl and jogoAlive(mdl) then return mdl, st end
    end
    return nil, nil
end
JOGO_PILLAR_SPAWN_RADIUS = 45
function jogoPillarSpawns()
    local out = {}
    pcall(function()
        for _, sp in ipairs(workspace.Map.Spawnpoints.Raid.FirePillars:GetChildren()) do
            if sp:IsA("BasePart") then table.insert(out, sp.Position) end
        end
    end)
    return out
end

function jogoMinionModels()
    local out, seen = {}, {}
    local boss = jogoBossModel()
    local pill = {}
    for _, m in ipairs(jogoPillarModels()) do pill[m] = true end
    local folder = jogoNpcFolder()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= boss and not pill[m] and jogoAlive(m) then
                seen[m] = true
                table.insert(out, m)
            end
        end
    end

    local s = jogoSpec()
    for _, e in ipairs(sorcLiveAIs()) do
        local m = e.model
        if m and m ~= boss and not seen[m] and not pill[m] and jogoAlive(m)
            and not (s and s.pillarIds[e.id]) then
            seen[m] = true
            table.insert(out, m)
        end
    end
    return out
end

function jogoPillarModels()
    local out = {}
    local folder = jogoNpcFolder()
    local spawns = jogoPillarSpawns()
    if not folder or #spawns == 0 then return out end
    local rb = jogoRaidController()
    rb = rb and rb.RaidBoss
    local boss = rb and rb.ServerModel or nil
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m ~= boss and m:FindFirstChild("FireBeam") and jogoAlive(m) then
            local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
            if pp then
                for _, sp in ipairs(spawns) do
                    if (pp.Position - sp).Magnitude <= JOGO_PILLAR_SPAWN_RADIUS then
                        table.insert(out, m)
                        break
                    end
                end
            end
        end
    end
    return out
end

function jogoPillarQuest()
    local rc = jogoRaidController()
    local e  = rc and type(rc.ActiveBossHandlers) == "table" and rc.ActiveBossHandlers.FirePillars
    if e then
        local killed, total
        pcall(function()
            local d = e.Data
            if type(d) == "table" then
                if type(d.EnemiesKilled) == "table" and type(d.EnemiesKilled.get) == "function" then
                    killed = tonumber(d.EnemiesKilled:get())
                end
                if type(d.EnemyCount) == "table" and type(d.EnemyCount.get) == "function" then
                    total = tonumber(d.EnemyCount:get())
                end
            end
        end)
        if killed and total and total > 0 and killed >= total then
            return false, killed, total
        end
        return true, killed, total
    end

    local killed, total = jogoMinionQuota("FirePillar")
    if killed and total and killed < total then return true, killed, total end
    return false, killed, total
end
function jogoPillarPhase()
    return (jogoPillarQuest())
end

jogoBringSaved     = nil
jogoBringForcedOff = false
function jogoBringOverride(active)
    if active then
        if not jogoBringForcedOff then
            jogoBringSaved     = (NexusBringRaidOn == true)
            jogoBringForcedOff = true
            NexusBringRaidOn    = false

            pcall(function() if type(nexusRaidBringRestore) == "function" then nexusRaidBringRestore() end end)
        else
            NexusBringRaidOn = false
        end
    elseif jogoBringForcedOff then
        jogoBringForcedOff = false
        NexusBringRaidOn    = (jogoBringSaved == true)
        jogoBringSaved     = nil
    end
end

JOGO_TP_COOLDOWN = 0.75
JOGO_TP_SLACK    = 18
jogoLockTarget   = nil
jogoTpAt         = 0

function jogoHit(list, mdl, hrp)
    if type(list) ~= "table" or #list == 0 or not mdl or not hrp then return end
    if not (FastOn or BlackFlashOn) then
        sorcTick = sorcTick + 1
        if sorcTick % 2 == 0 then
            enableBlackFlash()
            NexusQ(pcall, blackFlashList, list, mdl, hrp)
        else
            NexusQ(pcall, attackList, list, mdl, hrp)
        end
    end
end

function jogoGoTo(list, hrp)
    if type(list) ~= "table" or #list == 0 or not hrp then return nil end
    local tgt
    if jogoLockTarget and jogoLockTarget.Parent and nexusValidNpc(jogoLockTarget) then
        for _, m in ipairs(list) do if m == jogoLockTarget then tgt = m break end end
    end
    if not tgt then
        tgt = sorcNearest(list, hrp.Position)
        jogoLockTarget = tgt
        jogoTpAt = 0
    end
    local h = tgt and tgt:FindFirstChild("HumanoidRootPart")
    if h and (os.clock() - jogoTpAt) >= JOGO_TP_COOLDOWN then
        pcall(function()
            local goal = auraGoal(h)
            if (hrp.Position - goal.Position).Magnitude > (STICK_OFFSET + JOGO_TP_SLACK) then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = goal
                jogoTpAt = os.clock()
            end
        end)
    end
    return tgt
end

function jogoKillPillars(list, mdl, hrp)
    if type(list) ~= "table" or not mdl or not hrp then return 0 end
    local live = {}
    for _, m in ipairs(list) do
        if m and m.Parent and nexusValidNpc(m) and m:FindFirstChild("HumanoidRootPart") then
            table.insert(live, m)
        end
    end
    if #live == 0 then jogoLockTarget = nil return 0 end
    sorcAddCache = live
    jogoGoTo(live, hrp)
    jogoHit(live, mdl, hrp)
    return #live
end

function jogoReleaseBoss(boss)
    if not boss or type(NexusRaidBringOrigins) ~= "table" then return end
    local cf = NexusRaidBringOrigins[boss]
    if not cf then return end
    NexusRaidBringOrigins[boss] = nil
    pcall(function()
        local h = boss:FindFirstChild("HumanoidRootPart")
        if h then h.CFrame = cf end
    end)
end

function jogoMinionQuota(label)
    local killed, total
    local pat = "Defeat.-%((%d+)%s*/%s*(%d+)%)"
    if label then pat = "Defeat%s*" .. label .. ".-%((%d+)%s*/%s*(%d+)%)" end
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name ~= "NexusPlayHub" then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local a, b = string.match(tostring(d.Text), pat)
                        if a and b then killed, total = tonumber(a), tonumber(b) return end
                    end
                end
            end
        end
    end)
    return killed, total
end

function jogoSkipButton()
    local found = nil
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local hud = pg and pg:FindFirstChild("RaidHUD")
        if not hud then return end
        for _, d in ipairs(hud:GetDescendants()) do
            if d:IsA("TextButton") or d:IsA("ImageButton") then
                local txt = ""
                if d:IsA("TextButton") then txt = tostring(d.Text) end
                if string.lower(txt) ~= "skip" then
                    for _, c in ipairs(d:GetDescendants()) do
                        if c:IsA("TextLabel") and string.lower(tostring(c.Text)) == "skip" then
                            txt = "skip"
                            break
                        end
                    end
                end
                if string.lower(txt) == "skip" and d.Visible ~= false then
                    found = d
                    return
                end
            end
        end
    end)
    return found
end

function jogoClickSkip()
    local btn = jogoSkipButton()
    if not btn then return false end
    pcall(function()
        local fs = rawget(getfenv(), "firesignal")
        if type(fs) == "function" then
            pcall(function() fs(btn.Activated) end)
            pcall(function() fs(btn.MouseButton1Click) end)
        end
    end)
    pcall(function() if JogoSkipSignal then JogoSkipSignal:FireServer() end end)
    return true
end

jogoSawBoss   = false
jogoReadyAt   = 0
jogoSkipAt    = 0
jogoPhaseSeen = 0
jogoPhase     = "idle"

-- [NEXUS-OPT] The old code fired Retry the instant the boss model vanished,
-- which hopped out before the end-of-raid cutscene finished paying the reward.
-- Wait for the reward screen, claim it, then retry.
NEXUS_JOGO_REWARD_WAIT  = 8
NEXUS_JOGO_REWARD_WORDS = { "reward", "victory", "raid complete", "claim" }
NEXUS_JOGO_RETRY_DELAY  = 10   -- Jogo Raid only: wait this many seconds after the raid ends before retrying
function nexusJogoRewardUp()
    local up = false
    pcall(function()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, d in ipairs(pg:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                local t = string.lower(tostring(d.Text or ""))
                for _, w in ipairs(NEXUS_JOGO_REWARD_WORDS) do
                    if string.find(t, w, 1, true) then
                        up = true
                        return
                    end
                end
            end
        end
    end)
    return up
end
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoJogoRaidOn and nexusInRaidServer() then
            pcall(function()
                local mdl = getModel()
                local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                inJogoRaid = true

                jogoBringOverride(jogoPillarPhase())

                if sorcReadyUp() and (os.clock() - jogoReadyAt) > 3 then
                    jogoReadyAt = os.clock()
                    jogoPhase = "ready"
                    sorcClickReady()
                end

                if (os.clock() - jogoSkipAt) > 0.5 and jogoClickSkip() then
                    jogoSkipAt = os.clock()
                    jogoPhase = "skipping cutscene"
                end
                local boss, bstates = jogoBossModel()
                if boss then
                    jogoSawBoss = true

                    local pillars = jogoPillarModels()
                    local pillarPhase = (#pillars > 0) or jogoPillarPhase()
                    if pillarPhase or sorcImmuneOf(bstates) then

                        sorcBossLocked = true
                        if jogoLockTarget == boss then jogoLockTarget = nil end
                        jogoReleaseBoss(boss)
                        if #pillars > 0 then

                            outerAddCache = pillars
                            local killed, total = jogoMinionQuota("FirePillar")
                            jogoPhase = "flame pillars" .. (jogoBringForcedOff and " [bring off]" or "")
                                .. (killed and total and (" (" .. killed .. "/" .. total .. ")")
                                    or (" (" .. #pillars .. " left)"))
                            jogoKillPillars(pillars, mdl, hrp)
                        else

                            local mins = jogoMinionModels()
                            outerAddCache = mins
                            if #mins > 0 then
                                local killed, total = jogoMinionQuota()
                                jogoPhase = "minion phase " .. tostring(jogoPhaseSeen + 1)
                                    .. (killed and total and (" (" .. killed .. "/" .. total .. ")") or "")
                                if NexusBringRaidOn then
                                    sorcEngage(mins, mdl, hrp)
                                else
                                    sorcAddCache = mins
                                    jogoGoTo(mins, hrp)
                                    jogoHit(mins, mdl, hrp)
                                end
                            elseif pillarPhase then
                                jogoPhase = "waiting for flame pillars"
                                outerAddCache = {}
                                task.wait(0.1)
                            else
                                jogoPhase = "waiting for minions"
                                task.wait(0.1)
                            end
                        end
                    else

                        if sorcBossLocked then jogoPhaseSeen = jogoPhaseSeen + 1 end
                        sorcBossLocked = false
                        outerAddCache = {}
                        jogoPhase = "boss"
                        jogoLockTarget = boss
                        local list = { boss }
                        for _, m in ipairs(jogoMinionModels()) do table.insert(list, m) end
                        if NexusBringRaidOn then

                            sorcEngage(list, mdl, hrp)
                        else

                            sorcAddCache = list
                            jogoGoTo({ boss }, hrp)
                            jogoHit(list, mdl, hrp)
                        end
                    end
                else
                    if jogoSawBoss then

                        sorcBossLocked = false
                        outerAddCache = {}
                        sorcAddCache = {}
                        jogoPhase = "boss dead - waiting for reward"
                        jogoLockTarget = nil
                        jogoBringOverride(false)

                        local rw0, gotReward = os.clock(), false
                        while (os.clock() - rw0) < NEXUS_JOGO_REWARD_WAIT do
                            if not AutoJogoRaidOn then break end
                            if nexusJogoRewardUp() then
                                gotReward = true
                                break
                            end
                            task.wait(0.1)
                        end
                        if gotReward then
                            jogoPhase = "claiming reward"
                            local cw0 = os.clock()
                            while (os.clock() - cw0) < NEXUS_JOGO_REWARD_WAIT do
                                if not AutoJogoRaidOn then break end
                                clickPopup("claim"); clickPopup("next"); clickPopup("close")
                                if not nexusJogoRewardUp() then break end
                                task.wait(0.25)
                            end
                        end

                        local rd0 = os.clock()
                        while (os.clock() - rd0) < NEXUS_JOGO_RETRY_DELAY do
                            if not AutoJogoRaidOn then break end
                            local left = NEXUS_JOGO_RETRY_DELAY - (os.clock() - rd0)
                            if left < 0 then left = 0 end
                            jogoPhase = string.format("raid over - retry in %.0fs", left)
                            clickPopup("next"); clickPopup("close")
                            task.wait(0.25)
                        end

                        jogoPhase = "boss dead - retry"
                        clickPopup("next"); clickPopup("close")
                        pcall(function() RetrySignal:InvokeServer() end)
                        jogoSawBoss = false
                        jogoPhaseSeen = 0
                        local t0, last = os.clock(), os.clock()
                        while (os.clock() - t0) < 3 do
                            if not AutoJogoRaidOn then break end
                            if jogoBossModel() or #jogoMinionModels() > 0 or sorcReadyUp() then break end
                            if (os.clock() - last) >= 0.25 then
                                clickPopup("next"); clickPopup("close")
                                pcall(function() RetrySignal:InvokeServer() end)
                                last = os.clock()
                            end
                            task.wait(0.05)
                        end
                    else
                        local mins = jogoMinionModels()
                        if #mins > 0 then

                            outerAddCache = mins
                            jogoPhase = "starting npc waves"
                            if NexusBringRaidOn then
                                sorcEngage(mins, mdl, hrp)
                            else
                                sorcAddCache = mins
                                jogoGoTo(mins, hrp)
                                jogoHit(mins, mdl, hrp)
                            end
                        else
                            jogoPhase = "waiting for raid"
                            outerAddCache = {}
                        end
                    end
                end
            end)
            task.wait(LOOP_GAP)
        else
            inJogoRaid = false
            jogoBringOverride(false)
            jogoLockTarget = nil
            jogoSawBoss = false
            jogoPhaseSeen = 0
            jogoPhase = "idle"
            task.wait(NEXUS_IDLE)
        end
    end
end)

BLOOD_RAID_ID   = "BloodM"
AutoBloodRaidOn = false
inBloodRaid     = false
bloodSpecCache  = nil

function bloodSpec()
    if bloodSpecCache then return bloodSpecCache end
    pcall(function()
        local RS  = RepStorage
        local cfg = require(RS.Configs.RaidsConfig)
        local j   = cfg and cfg.RaidsData and cfg.RaidsData[BLOOD_RAID_ID]
        if not j or not j.BaseNPCConfig then return end
        local s = {
            raidName    = tostring(j.Name),
            bossId      = tostring(j.BaseNPCConfig.ID),
            bossName    = tostring(j.BaseNPCConfig.Name),
            minionIds   = {},
            minionNames = {},
            poolIds     = {},
            lockPhases  = {},
            endsOnBossDeath = (j.DontEndOnBossDeath ~= true),
        }
        local names = nil
        pcall(function() names = require(RS.Configs.NPCConfig.NPCs.BloodMNPCs) end)
        for _, e in pairs(j.StartingNPC or {}) do
            local c  = e.NPCConfig or e
            local id = c and c.ID and tostring(c.ID) or nil
            if id and not s.minionIds[id] then
                s.minionIds[id] = true
                local nm = names and names[id] and names[id].Name
                table.insert(s.minionNames, tostring(nm or id))
            end
        end
        for _, e in pairs(j.BloodPoolNPC or {}) do
            if e.ID then s.poolIds[tostring(e.ID)] = true end
        end
        local ph = j.BaseNPCConfig.SkillMoveset and j.BaseNPCConfig.SkillMoveset.Phases
        if type(ph) == "table" then
            for _, p in pairs(ph) do
                if type(p) == "table" and p.PhaseLock then
                    table.insert(s.lockPhases, tonumber(p.HealthPercent) or 0)
                end
            end
        end
        bloodSpecCache = s
    end)
    return bloodSpecCache
end

function bloodBossModel()
    local rc = jogoRaidController()
    local rb = rc and rc.RaidBoss
    if rb then
        local mdl = rb.ServerModel
        if mdl and jogoAlive(mdl) then
            return mdl, (rb.Character and rb.Character.CharacterStates) or rb.AIStates
        end
    end
    local s = bloodSpec()
    if s then
        local mdl, st = sorcModelById(s.bossId)
        if mdl and jogoAlive(mdl) then return mdl, st end
    end
    return nil, nil
end
BLOOD_POOL_WAYPOINT_RADIUS = 60

function bloodPoolWaypointPositions()
    local out = {}
    pcall(function()
        local mc = require(LocalPlayer.PlayerScripts.Client.Controllers.MapController)
        for i = 1, 12 do
            local w = mc:GetWaypoint(("BPIL_%d"):format(i))
            if w then
                local wp = w.WorldPosition
                if type(wp) == "table" and type(wp.get) == "function" then wp = wp:get() end
                if typeof(wp) == "Vector3" then
                    table.insert(out, wp - Vector3.new(0, 50, 0))
                end
            end
        end
    end)
    return out
end

function bloodPoolModels()
    local out, seen = {}, {}
    local s      = bloodSpec()
    local folder = jogoNpcFolder()
    local rc     = jogoRaidController()
    local rb     = rc and rc.RaidBoss
    local boss   = rb and rb.ServerModel or nil
    local spots  = bloodPoolWaypointPositions()
    if folder and #spots > 0 then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= boss and jogoAlive(m) then
                local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
                if pp then
                    for _, sp in ipairs(spots) do
                        if (pp.Position - sp).Magnitude <= BLOOD_POOL_WAYPOINT_RADIUS then
                            seen[m] = true
                            table.insert(out, m)
                            break
                        end
                    end
                end
            end
        end
    end
    for _, e in ipairs(sorcLiveAIs()) do
        if s and s.poolIds[e.id] and e.model and not seen[e.model] and jogoAlive(e.model) then
            seen[e.model] = true
            table.insert(out, e.model)
        end
    end
    return out
end

function bloodPoolQuest()
    local rc = jogoRaidController()
    local e
    if rc and type(rc.ActiveBossHandlers) == "table" then
        for k, v in pairs(rc.ActiveBossHandlers) do
            if type(k) == "string" and string.find(string.lower(k), "bloodpool") then e = v break end
        end
    end
    if e then
        local killed, total
        pcall(function()
            local d = e.Data
            if type(d) == "table" then
                if type(d.EnemiesKilled) == "table" and type(d.EnemiesKilled.get) == "function" then
                    killed = tonumber(d.EnemiesKilled:get())
                end
                if type(d.EnemyCount) == "table" and type(d.EnemyCount.get) == "function" then
                    total = tonumber(d.EnemyCount:get())
                end
            end
        end)
        if killed and total and total > 0 and killed >= total then
            return false, killed, total
        end
        return true, killed, total
    end

    local killed, total = jogoMinionQuota("BloodPool")
    if killed and total and killed < total then return true, killed, total end
    return false, killed, total
end
function bloodPoolPhase()
    return (bloodPoolQuest())
end

function bloodMinionModels()
    local out, seen = {}, {}
    local boss = bloodBossModel()
    local pool = {}
    for _, m in ipairs(bloodPoolModels()) do pool[m] = true end
    local folder = jogoNpcFolder()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m ~= boss and not pool[m] and jogoAlive(m) then
                seen[m] = true
                table.insert(out, m)
            end
        end
    end
    for _, e in ipairs(sorcLiveAIs()) do
        local m = e.model
        if m and m ~= boss and not seen[m] and not pool[m] and jogoAlive(m) then
            seen[m] = true
            table.insert(out, m)
        end
    end
    return out
end

BLOOD_TP_COOLDOWN = 0.75
BLOOD_TP_SLACK    = 18
bloodLockTarget   = nil
bloodTpAt         = 0
function bloodHit(list, mdl, hrp)
    if type(list) ~= "table" or #list == 0 or not mdl or not hrp then return end
    if not (FastOn or BlackFlashOn) then
        sorcTick = sorcTick + 1
        if sorcTick % 2 == 0 then
            enableBlackFlash()
            NexusQ(pcall, blackFlashList, list, mdl, hrp)
        else
            NexusQ(pcall, attackList, list, mdl, hrp)
        end
    end
end
function bloodGoTo(list, hrp)
    if type(list) ~= "table" or #list == 0 or not hrp then return nil end
    local tgt
    if bloodLockTarget and bloodLockTarget.Parent and jogoAlive(bloodLockTarget) then
        for _, m in ipairs(list) do if m == bloodLockTarget then tgt = m break end end
    end
    if not tgt then
        tgt = sorcNearest(list, hrp.Position)
        bloodLockTarget = tgt
        bloodTpAt = 0
    end
    local h = tgt and tgt:FindFirstChild("HumanoidRootPart")
    if h and (os.clock() - bloodTpAt) >= BLOOD_TP_COOLDOWN then
        pcall(function()
            local goal = auraGoal(h)
            if (hrp.Position - goal.Position).Magnitude > (STICK_OFFSET + BLOOD_TP_SLACK) then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = goal
                bloodTpAt = os.clock()
            end
        end)
    end
    return tgt
end

function bloodKillPools(list, mdl, hrp)
    if type(list) ~= "table" or not mdl or not hrp then return 0 end
    local live = {}
    for _, m in ipairs(list) do
        if jogoAlive(m) and m:FindFirstChild("HumanoidRootPart") then table.insert(live, m) end
    end
    if #live == 0 then bloodLockTarget = nil return 0 end
    sorcAddCache = live
    bloodGoTo(live, hrp)
    bloodHit(live, mdl, hrp)
    return #live
end

bloodBringSaved     = nil
bloodBringForcedOff = false
function bloodBringOverride(active)
    if active then
        if not bloodBringForcedOff then
            bloodBringSaved     = (NexusBringRaidOn == true)
            bloodBringForcedOff = true
            NexusBringRaidOn     = false
            pcall(function() if type(nexusRaidBringRestore) == "function" then nexusRaidBringRestore() end end)
        else
            NexusBringRaidOn = false
        end
    elseif bloodBringForcedOff then
        bloodBringForcedOff = false
        NexusBringRaidOn     = (bloodBringSaved == true)
        bloodBringSaved     = nil
    end
end

function bloodReleaseBoss(boss)
    if not boss or type(NexusRaidBringOrigins) ~= "table" then return end
    local cf = NexusRaidBringOrigins[boss]
    if not cf then return end
    NexusRaidBringOrigins[boss] = nil
    pcall(function()
        local h = boss:FindFirstChild("HumanoidRootPart")
        if h then h.CFrame = cf end
    end)
end

bloodSawBoss   = false
bloodReadyAt   = 0
bloodPhaseSeen = 0
bloodPhase     = "idle"
task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if AutoBloodRaidOn and nexusInRaidServer() then
            pcall(function()
                local mdl = getModel()
                local hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                inBloodRaid = true

                bloodBringOverride(bloodPoolPhase())

                if sorcReadyUp() and (os.clock() - bloodReadyAt) > 3 then
                    bloodReadyAt = os.clock()
                    bloodPhase = "ready"
                    sorcClickReady()
                end
                local boss, bstates = bloodBossModel()
                local pools = bloodPoolModels()
                local poolPhase = (#pools > 0) or bloodPoolPhase()
                if poolPhase then

                    if boss then bloodSawBoss = true bloodReleaseBoss(boss) end
                    sorcBossLocked = true
                    outerAddCache  = pools
                    local _, k2, t2 = bloodPoolQuest()
                    bloodPhase = "blood pools"
                        .. ((k2 and t2) and (" (" .. k2 .. "/" .. t2 .. ")") or (" (" .. #pools .. " left)"))
                        .. (bloodBringForcedOff and " [bring off]" or "")
                    if #pools > 0 then
                        bloodKillPools(pools, mdl, hrp)
                    else
                        outerAddCache = {}
                        task.wait(0.1)
                    end
                elseif boss then
                    bloodSawBoss = true
                    if sorcImmuneOf(bstates) then

                        sorcBossLocked = true
                        if bloodLockTarget == boss then bloodLockTarget = nil end
                        bloodReleaseBoss(boss)
                        local mins = bloodMinionModels()
                        outerAddCache = mins
                        if #mins > 0 then
                            bloodPhase = "immune phase - clearing spawns"
                            if NexusBringRaidOn then
                                sorcEngage(mins, mdl, hrp)
                            else
                                sorcAddCache = mins
                                bloodGoTo(mins, hrp)
                                bloodHit(mins, mdl, hrp)
                            end
                        else
                            bloodPhase = "immune phase - waiting"
                            task.wait(0.1)
                        end
                    else

                        if sorcBossLocked then bloodPhaseSeen = bloodPhaseSeen + 1 end
                        sorcBossLocked = false
                        outerAddCache  = {}
                        bloodPhase     = "boss"
                        bloodLockTarget = boss
                        local list = { boss }
                        for _, m in ipairs(bloodMinionModels()) do table.insert(list, m) end
                        if NexusBringRaidOn then
                            sorcEngage(list, mdl, hrp)
                        else
                            sorcAddCache = list
                            bloodGoTo({ boss }, hrp)
                            bloodHit(list, mdl, hrp)
                        end
                    end
                else
                    if bloodSawBoss then

                        sorcBossLocked = false
                        outerAddCache  = {}
                        sorcAddCache   = {}
                        bloodLockTarget = nil
                        bloodBringOverride(false)
                        bloodPhase = "complete - confirming"
                        clickPopup("next"); clickPopup("close")
                        local clear, waited = true, 0
                        while waited < NEXUS_RAID_RETRY_WAIT do
                            task.wait(0.1)
                            waited = waited + 0.1
                            if not AutoBloodRaidOn then clear = false break end
                            if bloodBossModel() then clear = false break end
                        end
                        if clear and AutoBloodRaidOn then
                            bloodPhase = "retry"
                            clickPopup("next"); clickPopup("close")
                            pcall(function() RetrySignal:InvokeServer() end)
                            bloodSawBoss   = false
                            bloodPhaseSeen = 0
                            task.wait(0.5)
                        end
                    else
                        local mins = bloodMinionModels()
                        if #mins > 0 then

                            outerAddCache = mins
                            bloodPhase = "blood spawn waves"
                            if NexusBringRaidOn then
                                sorcEngage(mins, mdl, hrp)
                            else
                                sorcAddCache = mins
                                bloodGoTo(mins, hrp)
                                bloodHit(mins, mdl, hrp)
                            end
                        else
                            bloodPhase = "waiting for raid"
                            outerAddCache = {}
                        end
                    end
                end
            end)
            task.wait(LOOP_GAP)
        else
            inBloodRaid = false
            bloodBringOverride(false)
            bloodLockTarget = nil
            bloodSawBoss = false
            bloodPhaseSeen = 0
            bloodPhase = "idle"
            task.wait(NEXUS_IDLE)
        end
    end
end)


do

    local LIB_URL = "https://raw.githubusercontent.com/soseb928/nexus-hub/refs/heads/main/NexusPlay_UI_Library.lua"

    NEXUS_TAB_IMAGES = {
        ["Farm"]          = "6022668911",
        ["Combat"]        = "4391741881",
        ["Boss"]          = "10653372143",
        ["Raid"]          = "6034848752",
        ["Shadow Island"] = "18511164704",
        ["Shop"]          = "9405933217",
        ["Roll"]          = "108719015966981",
        ["Movement"]      = "121667617719468",
        ["Misc"]          = "6022668909",
        ["Status"]        = "108364968985393",
        ["Settings"]      = "6031280882",
    }

    NEXUS_SECTION_IMAGES = {

        ["Auto Quest"]                     = "https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/i/3a6b1865-2510-4b88-8576-954660f8fd7d/df2snrf-2be64e55-996d-4953-9a10-ee8baa4da00b.png",
        ["Star Rage Awakening Quests"]     = "https://preview.redd.it/a-brief-rundown-of-tsukumo-yukis-star-rage-technique-part-2-v0-sj32tgdw97wd1.png?width=499&format=png&auto=webp&s=690c430977d170080eec4a9f5cd8d4344630798d",
        ["RCT Quest Line"]                 = "140187765819251",
        ["Infinity Trainer Quest Line"]    = "105818612964445",
        ["Lazy Sorcerer Quest Line"]       = "106482515749349",
        ["Evolution Trainer"]              = "127036267447610",
        ["Restrictor Quest Line"]          = "85365232906505",
        ["Kamutoke & Raiko Pillar Quests"] = "130825455952622",
        ["Currency Exchange"]              = "https://static.wikia.nocookie.net/jujutsu-zero/images/6/6c/Lumen.png/revision/latest?cb=20260505180429",
        ["CT Skin Shop"]                   = "122152972178680",
        ["Satoru Gojo"]                    = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQzJq4-5ZUExOzZCWYY4KSc5nduZJdYg9pWe6EukiiuNG8u3K1effHfqplZ&s=10",

        ["Basic Combat"]                   = "https://shared.fastly.steamstatic.com/community_assets/images/apps/1877020/92f09ecb4fd18d116a84b3fc621de627822df2a2.jpg",
        ["Are You Sure . . . ?"]            = "109438419344826",
        ["Passive Ability"]                = "133594135668131",
        ["Auto Skills"]                    = "97535762605474",
        ["Sukuna"]                         = "78414048903660",
        ["Hakari"]                         = "119671151693717",
        ["Limitless"]                      = "79198057405027",
        ["Copy"]                           = "138870070771495",
        ["Blood Manipulation"]             = "126854834898281",
        ["Awakened Star Rage"]             = "75870036044824",
        ["Ten Shadows"]                    = "78887186052530",
        ["Beast Amber"]                    = "82495253974343",
        ["Projection Sorcery"]             = "108674596204416",
        ["Larp"]                           = "133941487297830",
        ["Judgeman"]                       = "99674297807924",
        ["NPC Control"]                    = "10488924537",
        ["Equipment"]                      = "83953093844359",

        ["Teleport"]                       = "106917414457960",
        ["Boss Farm"]                      = "https://lh3.googleusercontent.com/R9yd2NGS1Bh_QpSaEw6yP75u4QbbNk_vuG43dhoKKeSua7Q_aKm340NR89jP71D5-qt7YeVWH_t2P3k_4F2hJS3Aq9Q=s128-rj-sc0x00ffffff",

        ["Overlord Raid"]                  = "https://media.forgecdn.net/avatars/thumbnails/1022/682/256/256/638546731992389772.jpg",
        ["Outer World Raid"]               = "https://i.redd.it/hqfk5ul5g4qg1.jpeg",
        ["Jujutsu Trial Tower"]            = "https://preview.redd.it/todo-and-yuji-shinjuku-vs-adult-geto-v0-hg45ku2aebgg1.jpg?width=256&format=pjpg&auto=webp&s=017d2369bf77a0b9cdb120cd2c60ce35261eba14",
        ["Infinity Raid"]                  = "https://discordpfp.gg/images/pfp/sukuna/sukuna-pfp-sukuna-throne--sukuna-throne.webp?d=card&v=2",

        ["Island Teleport"]                = "80889830955826",
        ["Shikigami Bosses"]               = "https://i.pinimg.com/236x/87/c2/0f/87c20f06799908f7c04a9a6f140d3a63.jpg",
        ["Shikigami Summon"]               = "76261802559168",


        ["Shop"]                           = "",
        ["Ability Exchanger"]              = "133594135668131",

        ["Infinite Raid Shop"]             = "71200487024459",
        ["Infinite Raid Shop II"]          = "71200487024459",
        ["Daily Shop I"]                   = "84500972339920",
        ["Daily Shop II"]                  = "84500972339920",
        ["Siege Shop"]                     = "70853487059545",
        ["Summer Festival Shop"]           = "108886123147100",
        ["Investigation Shop"]             = "104109907146403",
        ["St. Patrick's Event Shop"]       = "71263708196311",

        ["Banner Roll"]                    = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSnR9Qs0UyYAk-n2kD8xdvYBGjOTdqZxzTS64Lx--t6Tw&s",
        ["Clan Roll"]                      = "https://external-cdn.top.gg/discord/bots/1472614121961689302/d17833932abf08d965ea02cdcfb8e52c.webp",
        ["Special Clan Roll"]              = "https://styles.redditmedia.com/t5_gj1wzn/styles/communityIcon_de9emye855hg1.jpg?width=256&s=83165e5bba3090ca7aafeceafbf30f549c2e53d0",

        ["Noclip"]             = "124567096859122",
        ["Fly"]                            = "107978423323093",
        ["Vertical Movement"]              = "108545285832662",

        ["Anti Afk"]                     = "110361818009618",
        ["Crate Opener"]                   = "137089847431056",
        ["Auto Sell"]                      = "122344507964585",
        ["Trial CT & TP Block"]            = "137031107754509",
        ["Stats Points"]                   = "https://play-lh.googleusercontent.com/hEPNoY-EGgYPm17i4G-05O6zKpIN4SumzUOA5rjVtEthFCBH0u4mFzrfbzbm056wOX_CfebFbJlaAHyTH7W-Lg",

        ["Live Status"]                    = "129107298311224",
        ["My Position"]                    = "129107298311224",
        ["Teleport to Position"]           = "75648413395740",
        ["Teleport to Part / Model"]       = "75648413395740",

        ["Performance"]                    = "https://cdn-icons-png.flaticon.com/256/4406/4406377.png",
        ["Combat Settings"]                = "4391741881",
        ["Position Settings"]              = "118056171487418",
        ["Safety"]                         = "https://static.vecteezy.com/system/resources/previews/066/398/517/non_2x/security-protocol-semi-solid-glyph-icon-vector.jpg",
        ["Auto Execute"]                   = "88884583435189",
    }

    NEXUS_DEFAULT_TAB_IMAGE     = ""
    NEXUS_DEFAULT_SECTION_IMAGE = ""

    NEXUS_TAB_DESC = {
        ["Farm"]          = "Quest automation, evolution and exchange",
        ["Combat"]        = "Auto attacks, skills and cursed techniques",
        ["Boss"]          = "Boss teleport and automatic boss farming",
        ["Raid"]          = "Overlord, Outer World and Trial Tower",
        ["Shadow Island"] = "Island teleport, summons and bosses",
        ["Shop"]          = "CT Skin Shop, Infinite Raid Shop, Daily Shop, Siege Shop",
        ["Roll"]          = "Banner, clan and special clan rolling",
        ["Movement"]      = "Noclip, fly and vertical movement",
        ["Misc"]          = "Anti afk, crates, selling and trial tools",
        ["Status"]        = "Live status, position and teleport tools",
        ["Settings"]      = "Performance, combat, position, auto execute",
    }

    NEXUS_SECTION_DESC = {

        ["Auto Quest"]                     = "Pick a quest and farm it automatically",
        ["Star Rage Awakening Quests"]     = "Awakening quest chain for Lv.4000+",
        ["RCT Quest Line"]                 = "Reverse Cursed Technique quest chain",
        ["Infinity Trainer Quest Line"]    = "Infinity trainer quest chain",
        ["Lazy Sorcerer Quest Line"]       = "Lazy Sorcerer gate quest chain",
        ["Evolution Trainer"]              = "Automatic evolution quests and trainers",
        ["Restrictor Quest Line"]          = "Restrictor NPC quest chain",
        ["Kamutoke & Raiko Pillar Quests"] = "Pillar quest chain for both weapons",
        ["Currency Exchange"]              = "Convert Yen into Lumen automatically",
        ["CT Skin Shop"]                   = "Auto Exchange CT \226\134\146 Cursed Dust",
        ["Satoru Gojo"]                    = "Gojo Estate quest chain and Limitless awakening",

        ["Basic Combat"]                   = "Auto attack, black flash, plunge and reach",
        ["Are You Sure . . . ?"]           = "Nouthing...?",
        ["Passive Ability"]                = "Auto Use INF Aura and Auto Sukuna's Mark",
        ["Auto Skills"]                    = "One toggle per cursed technique",
        ["Sukuna"]                         = "Fuga and Dismantle automation",
        ["Hakari"]                         = "Hakari skill toggles",
        ["Limitless"]                      = "Red, Blue and Hollow Purple toggles",
        ["Copy"]                           = "Yuta copy skill toggles",
        ["Blood Manipulation"]             = "Blood Manipulation skill toggles",
        ["Awakened Star Rage"]             = "Awakened Star Rage skill toggles",
        ["Ten Shadows"]                    = "Shikigami summons and their skills",
        ["Beast Amber"]                    = "Beast Amber transform and skills",
        ["Projection Sorcery"]             = "Projection Sorcery skill toggles",
        ["Larp"]                           = "Larp skill toggles",
        ["Judgeman"]                       = "Judgeman skill toggles",
        ["NPC Control"]                    = "Bring NPCs to you and set bring range",
        ["Equipment"]                      = "Slots 1-5, SW Use S'M and SW Fill S'M",

        ["Teleport"]                  = "Quick teleport to the boss elevator",
        ["Boss Farm"]                      = "Select a boss and farm it automatically",

        ["Overlord Raid"]                  = "Select raid and difficulty, then auto run",
        ["Outer World Raid"]               = "Awakened Star Rage and Shadow raids",
        ["Jujutsu Trial Tower"]            = "Pick a chamber and clear it automatically",
        ["Infinity Raid"]                  = "Infinity - Sorcerer Killer, Infinity - King of Curses ect",

        ["Island Teleport"]                = "Teleport straight to Shadow Island",
        ["Shikigami Bosses"]               = "Select and auto kill Shikigami bosses",
        ["Shikigami Summon"]               = "Auto summon Shikigami with live status",


        ["Shop"]                           = "Exchange shops, shown when none are active",
        ["Ability Exchanger"]              = "Exchange passive abilities at the NPC",

        ["Infinite Raid Shop"]             = "Cursed Flesh, Gojo Clan, Domain and Heavenly Fragment",
        ["Infinite Raid Shop II"]          = "Cursed Crystals, Kenjaku, Toji, Tengen, Infinity Crate",
        ["Daily Shop I"]                   = "Inverted Spear, Zenin Clan, Limitless and Lumen",
        ["Daily Shop II"]                  = "Beast Amber, Awakening Shard, Kashimo, Sukuna, Shrine",
        ["Siege Shop"]                     = "Toji Clan, Bloodthirst, Siege Emblem, Zenin Crests",
        ["Summer Festival Shop"]           = "Noritoshi, Tsukumo, Summer Crate and Summer Emblems",
        ["Investigation Shop"]             = "Emblem Slot, Edo Crates, Sukuna and Hakari Clan",
        ["St. Patrick's Event Shop"]       = "x140 and x1400 Lumen exchanges",

        ["Banner Roll"]                    = "Auto roll the selected banner",
        ["Clan Roll"]                      = "Auto roll clans with live status",
        ["Special Clan Roll"]              = "Auto roll special clans and shop status",

        ["Noclip"]             = "Walk through walls with noclip",
        ["Fly"]                            = "Fly toggle and fly speed",
        ["Vertical Movement"]              = "Fly straight up or down",

        ["Anti Afk"]                     = "Anti AFK and anti teleport safety",
        ["Crate Opener"]                   = "Bulk open crates from your inventory",
        ["Auto Sell"]                      = "Automatically sell the items you choose",
        ["Trial CT & TP Block"]            = "Trial CT tools and teleport blocking",
        ["Stats Points"]                   = "Auto Stats Poin in skill trees",

        ["Live Status"]                    = "Live readout of everything running",
        ["My Position"]                    = "Copy your current coordinates",
        ["Teleport to Position"]           = "Teleport to typed coordinates",
        ["Teleport to Part / Model"]       = "Teleport to a named part or model",

        ["Performance"]                    = "Loop speed, caches and visual stripping",
        ["Combat Settings"]                = "Skill speed, skill budget and aura range",
        ["Position Settings"]              = "Aura position and X / Y / Z offsets",
        ["Safety"]                         = "Kick or hop when an admin or watched player joins",
        ["Auto Execute"]                   = "Run the hub automatically after joining",
    }

    NEXUS_DEFAULT_TAB_DESC     = ""
    NEXUS_DEFAULT_SECTION_DESC = ""

    NEXUS_WELCOME = 'WELCOME TO\n<font color="#f8042e">BEST FREE</font>\nNEXUSPLAY HUB'

    NEXUS_SUBTITLE = table.concat({
        "Thanks for using our services.",
        "We are committed to bringing the greatest",
        "experience to users !",
    }, "\n")

    NEXUS_HOME_CARDS = {
        { tab = "Farm",   title = "Farm",   desc = NEXUS_TAB_DESC["Farm"],   image = NEXUS_TAB_IMAGES["Farm"] },
        { tab = "Combat", title = "Combat", desc = NEXUS_TAB_DESC["Combat"], image = NEXUS_TAB_IMAGES["Combat"] },
        { tab = "Settings", title = "Settings", desc = NEXUS_TAB_DESC["Settings"], image = NEXUS_TAB_IMAGES["Settings"] },
    }

    local Luna = {}

    function Luna.Fail(msg)
        msg = "[NEXUSPLAY HUB] " .. tostring(msg)
        pcall(function() warn(msg) end)
        pcall(function() print(msg) end)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "NEXUSPLAY HUB", Text = msg, Duration = 12,
            })
        end)
    end

    do
        local ok, src = pcall(function() return game:HttpGet(LIB_URL .. "?v=" .. tostring(tick()), true) end)
        if not ok or type(src) ~= "string" or #src == 0 then
            Luna.Fail("could not download the UI library: " .. tostring(src))
            return
        end
        src = src:gsub("^\239\187\191", ""):gsub("^\255\254", ""):gsub("^%s+", "")
        local fn, err = loadstring(src)
        if not fn then
            Luna.Fail("the UI library did not compile: " .. tostring(err))
            return
        end
        local okRun, result = pcall(fn)
        if not okRun then
            Luna.Fail("the UI library errored while running: " .. tostring(result))
            return
        end
        if type(result) ~= "table" then
            Luna.Fail("the UI library did not return a table (got " .. type(result) .. ")")
            return
        end
        Luna.Lib = result
    end

    function Luna.TabImage(name)
        local v = NEXUS_TAB_IMAGES and NEXUS_TAB_IMAGES[name]
        if v == nil then v = NEXUS_DEFAULT_TAB_IMAGE end
        return NexusResolveImage(v or "")
    end

    function Luna.SectionImage(name)
        local v = NEXUS_SECTION_IMAGES and NEXUS_SECTION_IMAGES[name]
        if v == nil then v = NEXUS_DEFAULT_SECTION_IMAGE end
        return NexusResolveImage(v or "")
    end

    function Luna.TabDesc(name, fallback)
        local v = NEXUS_TAB_DESC and NEXUS_TAB_DESC[name]
        if v == nil or v == "" then v = fallback end
        if v == nil or v == "" then v = NEXUS_DEFAULT_TAB_DESC end
        return tostring(v or "")
    end

    function Luna.SectionDesc(name, fallback)
        local v = NEXUS_SECTION_DESC and NEXUS_SECTION_DESC[name]
        if v == nil or v == "" then v = fallback end
        if v == nil or v == "" then v = NEXUS_DEFAULT_SECTION_DESC end
        return tostring(v or "")
    end

    function Luna.Wrap(h)
        if type(h) ~= "table" then h = {} end
        local w = { Handle = h, Object = h }
        function w:Set(v) pcall(function() h:Set(v) end) return self end
        function w:Get()
            local ok, r = pcall(function() return h:Get() end)
            if ok then return r end
            return nil
        end
        function w:SetText(v)       pcall(function() h:SetText(v) end) return self end
        function w:SetTitle(v)      pcall(function() h:SetText(v) end) return self end
        function w:UpdateState(v)   pcall(function() h:Set(v and true or false) end) return self end
        function w:UpdateValue(v)   pcall(function() h:Set(v) end) return self end
        function w:UpdateOptions(o) pcall(function() h:SetOptions(o) end) return self end
        function w:SetOptions(o)    pcall(function() h:SetOptions(o) end) return self end
        function w:Refresh(o)       pcall(function() h:SetOptions(o) end) return self end
        function w:GetOptions()
            local ok, r = pcall(function() return h:GetOptions() end)
            if ok then return r end
            return {}
        end
        function w:Remove()  pcall(function() h:Remove() end) return self end
        function w:Destroy() pcall(function() h:Remove() end) return self end
        return w
    end

    function Luna.AttachControls(obj, getSection)
        function obj:CreateButton(o, flag)
            o = o or {}
            return Luna.Wrap(getSection():AddButton({
                text     = tostring(o.Name or o.Title or o.Text or "Button"),
                callback = o.Callback,
                flag     = o.Flag or flag,
            }))
        end

        function obj:CreateToggle(o, flag)
            o = o or {}
            return Luna.Wrap(getSection():AddToggle({
                text     = tostring(o.Name or o.Title or o.Text or "Toggle"),
                default  = (o.CurrentValue or o.Default) and true or false,
                callback = o.Callback,
                flag     = o.Flag or flag,
            }))
        end
        obj.CreateSwitch = obj.CreateToggle

        function obj:CreateSlider(o, flag)
            o = o or {}
            local rng = o.Range or {}
            local mn  = tonumber(rng[1]) or tonumber(o.Min) or 0
            local mx  = tonumber(rng[2]) or tonumber(o.Max) or 100
            local inc = tonumber(o.Increment) or tonumber(o.Step) or 1
            local dec = 0
            if inc > 0 and inc < 1 then
                local t = inc
                while t < 1 and dec < 4 do t = t * 10 dec = dec + 1 end
            end
            return Luna.Wrap(getSection():AddSlider({
                text     = tostring(o.Name or o.Title or o.Text or "Slider"),
                min      = mn,
                max      = mx,
                step     = inc,
                decimals = dec,
                default  = tonumber(o.CurrentValue) or mn,
                suffix   = o.Suffix or "",
                callback = o.Callback,
                flag     = o.Flag or flag,
            }))
        end

        function obj:CreateDropdown(o, flag)
            o = o or {}
            local multi = (o.MultipleOptions or o.Multi) and true or false
            local cur   = o.CurrentOption
            local def
            if type(cur) == "table" then
                if multi then def = cur else def = cur[1] end
            else
                def = cur
            end
            local cb = o.Callback
            return Luna.Wrap(getSection():AddDropdown({
                text     = tostring(o.Name or o.Title or o.Text or "Dropdown"),
                options  = o.Options or {},
                default  = def,
                multi    = multi,
                callback = function(v)
                    if not cb then return end
                    if multi and type(v) ~= "table" then v = { v } end
                    cb(v)
                end,
                flag = o.Flag or flag,
            }))
        end

        function obj:CreateInput(o, flag)
            o = o or {}
            local cb = o.Callback
            return Luna.Wrap(getSection():AddInput({
                text         = tostring(o.Name or o.Title or o.Text or "Input"),
                default      = tostring(o.CurrentValue or o.Default or ""),
                placeholder  = tostring(o.PlaceholderText or o.Placeholder or ""),
                clearOnEnter = o.RemoveTextAfterFocusLost and true or false,
                callback     = function(text, enter) if cb then cb(text, enter) end end,
                flag         = o.Flag or flag,
            }))
        end
        obj.CreateTextbox = obj.CreateInput

        function obj:CreateLabel(o, flag)
            local txt = o
            if type(o) == "table" then txt = o.Text or o.Name or o.Title or "" end
            return Luna.Wrap(getSection():AddLabel({ text = tostring(txt or "") }))
        end

        function obj:CreateParagraph(o)
            o = o or {}
            return Luna.Wrap(getSection():AddParagraph({
                title = tostring(o.Title or o.Name or ""),
                text  = tostring(o.Text or o.Content or ""),
            }))
        end

        function obj:CreateDivider()
            return Luna.Wrap(getSection():AddDivider())
        end

        function obj:CreateKeybind(o, flag)
            o = o or {}
            return Luna.Wrap(getSection():AddKeybind({
                text     = tostring(o.Name or o.Title or o.Text or "Keybind"),
                default  = o.CurrentKeybind or o.Default,
                callback = o.Callback,
                onChange = o.OnChange,
                flag     = o.Flag or flag,
            }))
        end

        function obj:CreateColorPicker(o, flag)
            o = o or {}
            return Luna.Wrap(getSection():AddColorPicker({
                text     = tostring(o.Name or o.Title or o.Text or "Color"),
                default  = o.Color or o.CurrentColor or o.Default,
                callback = o.Callback,
                flag     = o.Flag or flag,
            }))
        end
        return obj
    end

    function Luna.MakeSection(sec, title)
        local S = { Name = title, Section = sec }
        Luna.AttachControls(S, function() return sec end)
        function S:CreateSection() return S end
        function S:Open() pcall(function() sec:Open() end) return S end
        function S:Back() pcall(function() sec:Back() end) return S end
        function S:SetImage(id) pcall(function() sec:SetImage(NexusResolveImage(id)) end) return S end
        return S
    end

    function Luna.MakeTab(info)
        info = info or {}
        local name = tostring(info.Name or info.Title or "Tab")
        local tab = Luna.Window:AddTab({
            title = name,
            desc  = Luna.TabDesc(name, info.Desc or info.Description),
            image = Luna.TabImage(name),
        })

        for slot, cardInfo in ipairs(NEXUS_HOME_CARDS or {}) do
            if tostring(cardInfo.tab):lower() == name:lower() then
                pcall(function()
                    Luna.Window:SetFrontPageTab(slot, name, {
                        title = cardInfo.title or name,
                        desc  = cardInfo.desc or "",
                        image = NexusResolveImage(cardInfo.image or ""),
                    })
                end)
            end
        end

        local T = { Name = name, Tab = tab }
        local current

        local function getSection()
            if not current then
                current = tab:AddSection({
                    title = name,
                    desc  = Luna.SectionDesc(name),
                    image = Luna.SectionImage(name),
                })
            end
            return current
        end

        function T:CreateSection(title, desc)
            local t = tostring(title or "Section")
            current = tab:AddSection({
                title = t,
                desc  = Luna.SectionDesc(t, desc),
                image = Luna.SectionImage(t),
            })
            return Luna.MakeSection(current, t)
        end
        T.AddSection = T.CreateSection

        Luna.AttachControls(T, getSection)

        function T:Activate() pcall(function() tab:Open() end) return T end
        function T:Select()   pcall(function() tab:Open() end) return T end
        function T:Open()     pcall(function() tab:Open() end) return T end
        function T:Back()     pcall(function() tab:Back() end) return T end
        function T:SetImage(id) pcall(function() tab:SetImage(NexusResolveImage(id)) end) return T end
        return T
    end

    function Luna:CreateWindow(o)
        o = o or {}
        local cfg = o.ConfigSettings or {}
        local ok, ui = pcall(function()
            return Luna.Lib:CreateWindow({
                welcome   = tostring(NEXUS_WELCOME or o.Name or "NEXUSPLAY HUB"),
                subtitle  = tostring(NEXUS_SUBTITLE or o.Subtitle or ""),
                folder    = cfg.ConfigFolder or cfg.FolderName or "NEXUSPLAY_HUB",
                toggleKey = "RightShift",
                autoload  = true,
            })
        end)
        if not ok or type(ui) ~= "table" then
            Luna.Fail("the window could not be built: " .. tostring(ui))
            return nil
        end
        Luna.Window = ui

        local W = { Window = ui }
        function W:CreateTab(info) return Luna.MakeTab(info) end
        W.AddTab = W.CreateTab

        W.SetVisible = function(v) pcall(function() ui:SetVisible(v ~= false) end) end
        W.Show       = function() pcall(function() ui:Show() end) end
        W.Hide       = function() pcall(function() ui:Hide() end) end
        W.Toggle     = function() pcall(function() ui:Toggle() end) end
        W.Destroy    = function() pcall(function() ui:Destroy() end) end

        return setmetatable(W, {
            __newindex = function(t, k, v)
                if k == "Bind" or k == "ToggleKey" then
                    pcall(function() ui:SetToggleKey(v) end)
                    rawset(t, "_Bind", v)
                    return
                end
                rawset(t, k, v)
            end,
        })
    end

    function Luna:Notification(o)
        if type(o) == "string" then o = { Content = o } end
        o = o or {}
        local title = tostring(o.Title or "NEXUSPLAY HUB")
        local body  = tostring(o.Content or o.Text or "")
        local msg   = title
        if body ~= "" then msg = title .. "\n" .. body end
        pcall(function()
            if Luna.Window then
                Luna.Window:Notify({ text = msg, time = tonumber(o.Duration or o.Time) or 4 })
            end
        end)
    end
    Luna.Notify = Luna.Notification

    function Luna:Destroy()
        pcall(function() if Luna.Window then Luna.Window:Destroy() end end)
        pcall(function() if Luna.Window then Luna.Window:Hide() end end)
        Luna.Window = nil
    end
    if type(Luna) ~= "table" then
        warn("[NEXUSPLAY HUB] UI library did not return a usable object.")
        return
    end

    if NEXUSG.NexusUILib then pcall(function() NEXUSG.NexusUILib:Destroy() end) end
    NEXUSG.NexusUILib = Luna
    NEXUSG.NexusLuna = Luna

    Library = {
        Notify = function(_, o)
            o = o or {}
            local t = tostring(o.Type or "")
            local icon = "info"
            if t == "Success" then icon = "check_circle"
            elseif t == "Error" then icon = "report"
            elseif t == "Warning" then icon = "priority_high" end
            pcall(function()
                Luna:Notification({
                    Title       = o.Title or "NEXUSPLAY HUB",
                    Content     = o.Content or "",
                    Icon        = icon,
                    ImageSource = "Material",
                })
            end)
        end,
        Destroy = function() pcall(function() Luna:Destroy() end) end,
    }

    local Window = Luna:CreateWindow({
        Name           = "NEXUSPLAY HUB",
        Subtitle       = "NexusPlay Hub",
        LogoID         = "17006882295",
        LoadingEnabled = false,
        LoadingTitle   = "NEXUSPLAY HUB",
        LoadingSubtitle = "NexusPlay Hub",
        ConfigSettings = {
            RootFolder   = nil,
            ConfigFolder = "NEXUSPLAY_HUB",
        },
        KeySystem = false,
    })

    pcall(function() Window.Bind = Enum.KeyCode.RightShift end)

    task.spawn(function()
        for _ = 1, 15 do
            pcall(function() Window.SetVisible(true) end)
            pcall(function() if Window.HomeTab then Window.HomeTab:Activate() end end)
            task.wait()
        end
    end)

    NEXUS_TAB_ICONS = {
        ["Farm"]          = "grass",
        ["Combat"]        = "sports_mma",
        ["Boss"]          = "whatshot",
        ["Raid"]          = "shield",
        ["Shadow Island"] = "bedtime",
        ["Roll"]          = "casino",
        ["Movement"]      = "speed",
        ["Misc"]          = "apps",
        ["Status"]        = "info",
        ["Settings"]      = "settings",
    }
    function nexusTabIcon(name, fallback)
        local icon = NEXUS_TAB_ICONS and NEXUS_TAB_ICONS[name]
        if not icon or icon == "" then return fallback end
        return NexusResolveImage(tostring(icon))
    end

    QuestTab = nil
    pcall(function() QuestTab = Window:CreateTab({ Name = "Farm", Icon = nexusTabIcon("Farm", "list"), ImageSource = "Material" }) end)
    if not QuestTab then QuestTab = Window:CreateTab({ Name = "Farm", Icon = "list", ImageSource = "Material" }) end
    CombatTab = nil
    pcall(function() CombatTab = Window:CreateTab({ Name = "Combat", Icon = nexusTabIcon("Combat", "bolt"), ImageSource = "Material" }) end)
    if not CombatTab then CombatTab = Window:CreateTab({ Name = "Combat", Icon = "bolt", ImageSource = "Material" }) end
    BossTab = nil
    pcall(function() BossTab = Window:CreateTab({ Name = "Boss", Icon = nexusTabIcon("Boss", "person"), ImageSource = "Material" }) end)
    if not BossTab then BossTab = Window:CreateTab({ Name = "Boss", Icon = "person", ImageSource = "Material" }) end
    RaidTab = nil
    pcall(function() RaidTab = Window:CreateTab({ Name = "Raid", Icon = nexusTabIcon("Raid", "shield"), ImageSource = "Material" }) end)
    if not RaidTab then RaidTab = Window:CreateTab({ Name = "Raid", Icon = "shield", ImageSource = "Material" }) end
    ShadowTab = nil
    pcall(function() ShadowTab = Window:CreateTab({ Name = "Shadow Island", Icon = nexusTabIcon("Shadow Island", "person"), ImageSource = "Material" }) end)
    if not ShadowTab then ShadowTab = Window:CreateTab({ Name = "Shadow Island", Icon = "person", ImageSource = "Material" }) end
    RollTab = nil
    pcall(function() ShopTab = Window:CreateTab({ Name = "Shop", Icon = nexusTabIcon("Shop", "store"), ImageSource = "Material" }) end)
    if not ShopTab then ShopTab = Window:CreateTab({ Name = "Shop", Icon = "store", ImageSource = "Material" }) end
    pcall(function() NexusBuildShopTab(ShopTab) end)

    pcall(function() RollTab = Window:CreateTab({ Name = "Roll", Icon = nexusTabIcon("Roll", "casino"), ImageSource = "Material" }) end)
    if not RollTab then RollTab = Window:CreateTab({ Name = "Roll", Icon = "casino", ImageSource = "Material" }) end
    FlyTab = nil
    pcall(function() FlyTab = Window:CreateTab({ Name = "Movement", Icon = nexusTabIcon("Movement", "flight"), ImageSource = "Material" }) end)
    if not FlyTab then FlyTab = Window:CreateTab({ Name = "Movement", Icon = "flight", ImageSource = "Material" }) end
    MiscTab = nil
    pcall(function() MiscTab = Window:CreateTab({ Name = "Misc", Icon = nexusTabIcon("Misc", "person"), ImageSource = "Material" }) end)
    if not MiscTab then MiscTab = Window:CreateTab({ Name = "Misc", Icon = "person", ImageSource = "Material" }) end
    StatusTab = nil
    pcall(function() StatusTab = Window:CreateTab({ Name = "Status", Icon = nexusTabIcon("Status", "info"), ImageSource = "Material" }) end)
    if not StatusTab then StatusTab = Window:CreateTab({ Name = "Status", Icon = "info", ImageSource = "Material" }) end

    -- ===== [NEXUSPLAY] Investigation Automation =====
    NEXUS_INVESTIGATION_ON = NEXUS_INVESTIGATION_ON or false
    NEXUS_INV_ESSENCE_ON = NEXUS_INV_ESSENCE_ON or false
    NEXUS_INV_HIDDEN_ON = NEXUS_INV_HIDDEN_ON or false
    NEXUS_INV_REWARD_ON = NEXUS_INV_REWARD_ON or false
    NEXUS_INV_RETRY_ON = NEXUS_INV_RETRY_ON or false
    NEXUS_INV_DIFFICULTY = NEXUS_INV_DIFFICULTY or "Nightmare"
    NEXUS_INV_SESSION = NEXUS_INV_SESSION or 0
    NEXUS_INV_PREV_FAST = nil
    NEXUS_INV_PREV_REACH = nil

    local function NexusInvTextMatch(text, patterns)
        local s = string.lower(tostring(text or ""))
        for _, p in ipairs(patterns) do
            if string.find(s, p, 1, true) then return true end
        end
        return false
    end

    local function NexusInvUiTexts()
        local out = {}
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return out end

        pcall(function()
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = tostring(d.Text or "")
                    if t ~= "" then
                        out[#out + 1] = { obj = d, text = t }
                    end
                end
            end
        end)
        return out
    end

    local function NexusInvIsActive()
        local texts = NexusInvUiTexts()
        local hasRoom, hasLives, hasScore = false, false, false

        for _, v in ipairs(texts) do
            local t = string.lower(v.text)
            if string.find(t, "room:", 1, true) then hasRoom = true end
            if string.find(t, "lives left", 1, true) then hasLives = true end
            if string.find(t, "score:", 1, true) then hasScore = true end
        end

        return hasRoom and (hasLives or hasScore)
    end

    local function NexusInvObjective()
        local texts = NexusInvUiTexts()
        local best = ""

        for _, v in ipairs(texts) do
            local t = tostring(v.text or "")
            local low = string.lower(t)

            if string.find(low, "time elapsed", 1, true)
                or string.find(low, "room:", 1, true)
                or string.find(low, "clear time", 1, true)
                or string.find(low, "clear score", 1, true) then
                continue
            end

            if string.find(low, "collect", 1, true)
                or string.find(low, "eliminate", 1, true)
                or string.find(low, "defeat", 1, true)
                or string.find(low, "hidden", 1, true)
                or string.find(low, "crate", 1, true) then
                best = t
            end
        end

        return best
    end

    local function NexusInvRoot(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart
                or obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildWhichIsA("BasePart", true)
        end
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    local function NexusInvNearestEnemy()
        local player = getModel and getModel() or nil
        local root = player and player:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local best, bestDistance = nil, math.huge
        local folder = workspace:FindFirstChild("Characters")
        folder = folder and folder:FindFirstChild("Server")
        folder = folder and folder:FindFirstChild("NPCs")

        if not folder then return nil end

        pcall(function()
            for _, npc in ipairs(folder:GetChildren()) do
                local hum = npc:FindFirstChildOfClass("Humanoid")
                local hrp = npc:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < bestDistance then
                        best, bestDistance = npc, d
                    end
                end
            end
        end)

        return best
    end

    local function NexusInvFindObject(patterns)
        local player = getModel and getModel() or nil
        local root = player and player:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local best, bestDistance = nil, math.huge
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                local nm = string.lower(tostring(obj.Name or ""))
                if NexusInvTextMatch(nm, patterns) then
                    local part = NexusInvRoot(obj)
                    if part then
                        local d = (part.Position - root.Position).Magnitude
                        if d < bestDistance then
                            best, bestDistance = obj, d
                        end
                    end
                end
            end
        end)
        return best
    end

    local function NexusInvMoveTo(obj)
        local part = NexusInvRoot(obj)
        if not part then return false end

        local pos = part.Position + Vector3.new(0, 4, 0)
        local moved = false

        pcall(function()
            if nexusTpTo then
                moved = nexusTpTo(pos) and true or false
            end
        end)

        if not moved then
            local player = getModel and getModel() or nil
            local root = player and player:FindFirstChild("HumanoidRootPart")
            if root then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    root.CFrame = CFrame.new(pos)
                    moved = true
                end)
            end
        end

        return moved
    end

    local function NexusInvInteractNear(patterns)
        local player = getModel and getModel() or nil
        local root = player and player:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local used = false
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local holder = obj.Parent
                    local name = string.lower(tostring(holder and holder.Name or ""))
                    local action = string.lower(tostring(obj.ActionText or ""))
                    local promptName = name .. " " .. action

                    if NexusInvTextMatch(promptName, patterns)
                        and holder
                        and holder:IsA("BasePart")
                        and (holder.Position - root.Position).Magnitude <= 12 then

                        if fireproximityprompt then
                            pcall(function() fireproximityprompt(obj) end)
                            used = true
                        end
                    end
                end
            end
        end)

        return used
    end

    local function NexusInvActivateButton(patterns)
        local active = false
        local texts = NexusInvUiTexts()

        for _, v in ipairs(texts) do
            local button = v.obj
            if button:IsA("TextButton") and NexusInvTextMatch(v.text, patterns) then
                local visible = true
                pcall(function() visible = button.Visible end)

                if visible then
                    pcall(function() button:Activate() end)
                    active = true
                    break
                end
            end
        end

        return active
    end

    local function NexusInvCombatStep()
        if not NEXUS_INVESTIGATION_ON or not NexusInvIsActive() then return end

        -- Reuse the hub's existing combat engine instead of creating a second
        -- damage loop. This keeps the investigation automation compatible with
        -- Auto Attack, Reach & Kill, and the existing remote gates.
        FastOn = true
        if NEXUS_LV.ReachOn ~= nil then
            NEXUS_LV.ReachOn = true
        end

        local enemy = NexusInvNearestEnemy()
        if enemy then
            NexusInvMoveTo(enemy)
        end
    end

    function NexusSetInvestigation(on)
        NEXUS_INVESTIGATION_ON = on and true or false
        NEXUS_INV_SESSION = NEXUS_INV_SESSION + 1

        if not NEXUS_INVESTIGATION_ON then
            if NEXUS_INV_PREV_FAST ~= nil then FastOn = NEXUS_INV_PREV_FAST end
            if NEXUS_INV_PREV_REACH ~= nil and NEXUS_LV.ReachOn ~= nil then
                NEXUS_LV.ReachOn = NEXUS_INV_PREV_REACH
            end
            NEXUS_INV_PREV_FAST = nil
            NEXUS_INV_PREV_REACH = nil
            return
        end

        NEXUS_INV_PREV_FAST = FastOn
        NEXUS_INV_PREV_REACH = NEXUS_LV.ReachOn

        local runId = NEXUS_INV_SESSION
        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION
                and NEXUS_INVESTIGATION_ON
                and NEXUS_INV_SESSION == runId do

                if NexusInvIsActive() then
                    local objective = string.lower(NexusInvObjective())

                    if NEXUS_INV_ESSENCE_ON
                        and (string.find(objective, "essence", 1, true)
                            or string.find(objective, "collect", 1, true)) then
                        local essence = NexusInvFindObject({
                            "cursedessence",
                            "cursed essence",
                            "essence",
                        })
                        if essence then
                            NexusInvMoveTo(essence)
                            NexusInvInteractNear({ "essence", "collect", "pick" })
                        end

                    elseif NEXUS_INV_HIDDEN_ON
                        and string.find(objective, "hidden", 1, true) then
                        local hidden = NexusInvFindObject({
                            "hidden",
                            "mystery",
                            "secret",
                        })
                        if hidden then
                            NexusInvMoveTo(hidden)
                            NexusInvInteractNear({ "hidden", "investigate", "interact" })
                        end

                    elseif NEXUS_INV_HIDDEN_ON
                        and string.find(objective, "crate", 1, true) then
                        local crate = NexusInvFindObject({
                            "crate",
                            "chest",
                            "reward",
                        })
                        if crate then
                            NexusInvMoveTo(crate)
                            NexusInvInteractNear({ "crate", "open", "chest", "interact" })
                        end

                    else
                        NexusInvCombatStep()
                    end

                    if NEXUS_INV_REWARD_ON then
                        NexusInvActivateButton({
                            "open reward",
                            "claim reward",
                            "claim",
                            "open crate",
                        })
                    end

                    if NEXUS_INV_RETRY_ON then
                        NexusInvActivateButton({
                            "retry",
                            "play again",
                            "run again",
                        })
                    end
                end

                task.wait(0.35)
            end
        end)
    end

    pcall(function()
        local InvestigationTab = Window:CreateTab({
            Name = "Investigation",
            Icon = "search",
            ImageSource = "Material",
        })

        local section = InvestigationTab:CreateSection(
            "Investigations",
            "Automate Edo-Period Investigation runs"
        )

        PT(section, "NexusInvestigationOn", "Auto Investigation", function(on)
            NexusSetInvestigation(on)
        end)

        section:CreateDropdown({
            Name = "Select Difficulty",
            Options = { "Easy", "Normal", "Hard", "Nightmare" },
            CurrentOption = { S("InvestigationDifficulty", "Nightmare") },
            MultipleOptions = false,
            Callback = function(choice)
                local picked = (type(choice) == "table" and choice[1]) or choice
                NEXUS_INV_DIFFICULTY = picked or "Nightmare"
                Settings.InvestigationDifficulty = NEXUS_INV_DIFFICULTY
                saveSettings()
            end,
        })

        PT(section, "NexusInvestigationEssenceOn", "Auto Collect Essence", function(on)
            NEXUS_INV_ESSENCE_ON = on and true or false
        end)

        PT(section, "NexusInvestigationHiddenOn", "Auto Hidden Objectives", function(on)
            NEXUS_INV_HIDDEN_ON = on and true or false
        end)

        PT(section, "NexusInvestigationRewardOn", "Auto Open Reward", function(on)
            NEXUS_INV_REWARD_ON = on and true or false
        end)

        PT(section, "NexusInvestigationRetryOn", "Auto Retry", function(on)
            NEXUS_INV_RETRY_ON = on and true or false
        end)

        InvestigationTab:CreateParagraph({
            Title = "Automation Status",
            Content = "The automation activates when an Investigation room is detected. It reuses the hub combat engine and handles nearby objective interactions.",
        })
    end)
    -- ===== [/NEXUSPLAY] Investigation Automation =====

    -- ===== [NEXUSPLAY] Watcher NPC Teleport =====
    local function NexusWatcherSpawnpoints()
        local out = {}
        pcall(function()
            local folder = workspace.Map.Spawnpoints.NPCs
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("BasePart") and string.lower(obj.Name):match("^watcher%d*$") then
                    out[#out + 1] = obj
                end
            end
        end)
        return out
    end

    local function NexusWatcherRoot(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart
                or obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildWhichIsA("BasePart", true)
        end
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    local function NexusWatcherDisplayMatch(obj)
        if not obj then return false end
        local n = string.lower(tostring(obj.Name or ""))
        if n == "watcher" then return true end

        local matched = false
        pcall(function()
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = string.lower(tostring(d.Text or ""))
                    if t:match("^%s*watcher%s*$") then
                        matched = true
                        return
                    end
                end
            end
        end)
        return matched
    end

    function NexusFindWatcher()
        local npcFolder
        pcall(function() npcFolder = workspace.Characters.Server.NPCs end)
        if not npcFolder then return nil end

        -- One Watcher is active at a time. Prefer an actual NPC whose
        -- name/display text identifies it as Watcher.
        for _, npc in ipairs(npcFolder:GetChildren()) do
            if NexusWatcherDisplayMatch(npc) then
                if NexusWatcherRoot(npc) then
                    return npc
                end
            end
        end

        -- Fallback: match an active NPC to one of the known random
        -- Watcher spawn locations. Require a humanoid so ordinary map
        -- NPCs near a spawnpoint are not selected by mistake.
        local spawnpoints = NexusWatcherSpawnpoints()
        local best, bestDistance = nil, math.huge

        for _, npc in ipairs(npcFolder:GetChildren()) do
            local root = NexusWatcherRoot(npc)
            local humanoid = npc:FindFirstChildOfClass("Humanoid")
            if root and humanoid then
                for _, sp in ipairs(spawnpoints) do
                    local d = (root.Position - sp.Position).Magnitude
                    if d <= 25 and d < bestDistance then
                        best, bestDistance = npc, d
                    end
                end
            end
        end

        return best
    end

    local function NexusWatcherTeleportController(position)
        local function getRoot()
            local model = getModel and getModel() or nil
            return model and model:FindFirstChild("HumanoidRootPart")
        end

        local function reached(root)
            if not root or not root.Parent then return false end
            local ok, distance = pcall(function()
                return (root.Position - position).Magnitude
            end)
            return ok and distance <= 12
        end

        -- A teleport API returning without error does not mean the server
        -- accepted the movement. Always verify the player's actual position.
        for _ = 1, 3 do
            local root = getRoot()
            if reached(root) then return true end

            local moved = false

            -- Prefer the game's MapController so the server's movement
            -- validation is respected and raw CFrame correction is avoided.
            pcall(function()
                local ps = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
                local client = ps and ps:FindFirstChild("Client")
                local controllers = client and client:FindFirstChild("Controllers")
                local module = controllers and controllers:FindFirstChild("MapController")
                if module then
                    local controller = require(module)
                    if controller and controller.TeleportToPosition then
                        controller:TeleportToPosition(position)
                        moved = true
                    end
                end
            end)

            task.wait(0.12)
            root = getRoot()
            if reached(root) then return true end

            -- Existing NexusPlay movement helper.
            pcall(function()
                if nexusTpTo then
                    moved = nexusTpTo(position) and true or moved
                end
            end)

            task.wait(0.12)
            root = getRoot()
            if reached(root) then return true end

            -- Final local fallback.
            pcall(function()
                root = getRoot()
                if root then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    root.CFrame = CFrame.new(position)
                    moved = true
                end
            end)

            task.wait(0.12)
            root = getRoot()
            if reached(root) then return true end

            if not moved then
                task.wait(0.15)
            end
        end

        return false
    end

    function NexusTeleportToWatcher()
        local watcher = NexusFindWatcher()
        local part = NexusWatcherRoot(watcher)

        if not part then
            pcall(function()
                Library:Notify({
                    Title = "NEXUSPLAY HUB",
                    Content = "No active Watcher was found.",
                    Type = "Error",
                    Duration = 6,
                })
            end)
            return false
        end

        local targetPosition = part.Position + Vector3.new(0, 6, 0)
        local playerModel = getModel and getModel() or nil
        local root = playerModel and playerModel:FindFirstChild("HumanoidRootPart")

        if not root then
            local deadline = os.clock() + 5
            repeat
                task.wait(0.1)
                playerModel = getModel and getModel() or nil
                root = playerModel and playerModel:FindFirstChild("HumanoidRootPart")
            until root or os.clock() >= deadline
        end

        if not root then
            pcall(function()
                Library:Notify({
                    Title = "NEXUSPLAY HUB",
                    Content = "Your character model could not be found. Please wait and try again.",
                    Type = "Error",
                    Duration = 6,
                })
            end)
            return false
        end

        local moved = NexusWatcherTeleportController(targetPosition)

        if moved then
            task.wait(0.4)
            pcall(function()
                Library:Notify({
                    Title = "NEXUSPLAY HUB",
                    Content = "Teleported to the active Watcher.",
                    Type = "Success",
                    Duration = 4,
                })
            end)
            return true
        end

        pcall(function()
            Library:Notify({
                Title = "NEXUSPLAY HUB",
                Content = "Watcher was found, but the game rejected the teleport.",
                Type = "Error",
                Duration = 6,
            })
        end)
        return false
    end

    NEXUS_AUTO_WATCHER_ON = NEXUS_AUTO_WATCHER_ON or false
    NEXUS_AUTO_WATCHER_SESSION = NEXUS_AUTO_WATCHER_SESSION or 0
    NEXUS_AUTO_WATCHER_LAST = nil
    NEXUS_AUTO_WATCHER_NEXT = 0

    function NexusSetAutoWatcher(on)
        NEXUS_AUTO_WATCHER_ON = on and true or false
        NEXUS_AUTO_WATCHER_SESSION = NEXUS_AUTO_WATCHER_SESSION + 1

        if not NEXUS_AUTO_WATCHER_ON then
            NEXUS_AUTO_WATCHER_LAST = nil
            NEXUS_AUTO_WATCHER_NEXT = 0
            return
        end

        local runId = NEXUS_AUTO_WATCHER_SESSION
        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION
                and NEXUS_AUTO_WATCHER_ON
                and NEXUS_AUTO_WATCHER_SESSION == runId do

                local now = os.clock()
                if now >= NEXUS_AUTO_WATCHER_NEXT then
                    local watcher = NexusFindWatcher()
                    local part = NexusWatcherRoot(watcher)

                    if part and part.Parent then
                        local playerModel = getModel and getModel() or nil
                        local root = playerModel and playerModel:FindFirstChild("HumanoidRootPart")
                        local distance = root and (root.Position - part.Position).Magnitude or math.huge

                        -- Teleport when a new Watcher appears, or when the player
                        -- has been moved too far away from the active Watcher.
                        if watcher ~= NEXUS_AUTO_WATCHER_LAST or distance > 45 then
                            local targetPosition = part.Position + Vector3.new(0, 6, 0)
                            local moved = NexusWatcherTeleportController(targetPosition)

                            -- Only mark this Watcher as handled after verifying
                            -- that the player actually reached it. This prevents
                            -- a rejected/snap-back teleport from blocking retries.
                            if moved then
                                local verifyModel = getModel and getModel() or nil
                                local verifyRoot = verifyModel and verifyModel:FindFirstChild("HumanoidRootPart")
                                local verified = false
                                if verifyRoot then
                                    local ok, verifyDistance = pcall(function()
                                        return (verifyRoot.Position - targetPosition).Magnitude
                                    end)
                                    verified = ok and verifyDistance <= 12
                                end
                                if verified then
                                    NEXUS_AUTO_WATCHER_LAST = watcher
                                else
                                    NEXUS_AUTO_WATCHER_LAST = nil
                                end
                            else
                                NEXUS_AUTO_WATCHER_LAST = nil
                            end
                        end

                        -- Keep the loop responsive so a failed teleport or a
                        -- newly spawned random Watcher is retried quickly.
                        NEXUS_AUTO_WATCHER_NEXT = now + 0.75
                    else
                        -- No active Watcher yet. Keep checking for the next spawn.
                        NEXUS_AUTO_WATCHER_LAST = nil
                        NEXUS_AUTO_WATCHER_NEXT = now + 1
                    end
                end

                task.wait(0.25)
            end
        end)
    end

    pcall(function()
        local watcherSection = StatusTab:CreateSection("NPC Teleport", "Teleport directly to important NPCs")
        watcherSection:CreateButton({
            Name = "Teleport to Active Watcher",
            Callback = function()
                NexusTeleportToWatcher()
            end,
        })
        PT(watcherSection, "NexusAutoWatcherOn", "Auto Teleport to Watcher", function(on)
            NexusSetAutoWatcher(on)
        end)
    end)
    -- ===== [/NEXUSPLAY] Watcher NPC Teleport =====





    SettingsTab = nil
    pcall(function() SettingsTab = Window:CreateTab({ Name = "Settings", Icon = nexusTabIcon("Settings", "person"), ImageSource = "Material" }) end)
    if not SettingsTab then SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "person", ImageSource = "Material" }) end

    CombatTab:CreateSection("Basic Combat")
    PT(CombatTab, "FastOn", "Auto Attack", function(on) FastOn = on end)

    PT(CombatTab, "NexusHitBagOn", "Attack Punching Bag", function(on)
        NEXUS_HIT_BAG = on
        TgtCache = {}
        NexusRangeCache = {}
        NexusBagCacheClear()
        PunchingBagPosCache = { t = -1, list = {} }
    end)
    PT(CombatTab, "PlungeOn", "Auto Plunge", function(on) NEXUS_LV.PlungeOn = on end)
    PT(CombatTab, "KillOn", "Kill Nearest Aura", function(on) NEXUS_LV.KillOn = on end)
    PT(CombatTab, "ReachOn", "Reach & Kill", function(on) NEXUS_LV.ReachOn = on end)

    CombatTab:CreateSection("Are You Sure . . . ?")
    PT(CombatTab, "BlackFlashOn", "Serious punch", function(on) BlackFlashOn = on end)

    BF_CHARGES     = 999999
    BF_INTERVAL_MS = 1000
    BF_LAST = {}
    Settings.BFCharges    = BF_CHARGES
    Settings.BFIntervalMs = BF_INTERVAL_MS
    pcall(saveSettings)

    do
    (function()

        NEXUS_STRONGEST_ON = NEXUS_STRONGEST_ON or false

        local function nexusHoldInvincible(v)
            return pcall(function()
                local lc = NexusLocalChar()
                local cs = lc and lc.CharacterStates
                if cs then cs.IsInvincible = v end
            end)
        end

        function NexusStrongestSet(on)
            NEXUS_STRONGEST_ON = on and true or false
            if not NEXUS_STRONGEST_ON then
                nexusHoldInvincible(0)
                return
            end

            if NEXUS_STRONGEST_LOOP == SESSION then return end
            NEXUS_STRONGEST_LOOP = SESSION
            task.spawn(function()
                while NEXUSG.NexusPlayHubSession == SESSION do
                    if NEXUS_STRONGEST_ON then nexusHoldInvincible(100) end
                    task.wait(0.1)
                end

                if NEXUS_STRONGEST_LOOP == SESSION then NEXUS_STRONGEST_LOOP = nil end
            end)
        end
    end)()
    end
    PT(CombatTab, "NexusStrongestOn", "The strongest (Taking No dmage By Npc)", function(on) NexusStrongestSet(on) end)

    CombatTab:CreateSection("Passive Ability")
    PT(CombatTab, "FastInfAuraOn", "Auto Use INF Aura", function(on) NEXUS_LV.FastInfAuraOn = on end)
    PT(CombatTab, "NexusSMOn", "Auto Sukuna's Mark", function(on) NexusSMOn = on end)

    CombatTab:CreateSection("Auto Skills")

    NexusMaxPotentialToggle = CombatTab:CreateToggle({
        Name = "Unlock Max Potential",
        CurrentValue = false,
        Callback = function(on)
            if NEXUS_RAMPAGE_BUSY then return end
            if on then

                NexusMaxPotentialSetSwitch(false)
                NexusConfirmMaxPotential()
            else
                NexusSetRampage(false)
            end
        end,
    }, "NEXUS_MaxPotential")
    PT(CombatTab, "SukunaOn", "Auto Sukuna", function(on) NEXUS_LV.SukunaOn = on end)
    PT(CombatTab, "HakariOn", "Auto Hakari", function(on) NEXUS_LV.HakariOn = on end)
    PT(CombatTab, "LimitlessOn", "Auto Limitless", function(on) NEXUS_LV.LimitlessOn = on end)
    PT(CombatTab, "AwkLimitlessOn", "Awk Limitless All moves", function(on) NEXUS_LV.AwkLimitlessOn = on end)
    PT(CombatTab, "CopyOn", "Auto Copy", function(on) CopyOn = on end)
    PT(CombatTab, "BloodOn", "Auto Blood Manipulation", function(on) BloodOn = on end)
    PT(CombatTab, "StarRageOn", "Auto Awakened Star Rage", function(on) StarRageOn = on end)
    PT(CombatTab, "BeastAmberOn", "Auto Beast Amber", function(on) BeastAmberOn = on end)
    PT(CombatTab, "ProjectionOn", "Auto Projection Sorcery", function(on) NEXUS_LV.ProjectionOn = on end)
    PT(CombatTab, "LarpOn", "Auto Larp", function(on) NEXUS_LV.LarpOn = on end)
    PT(CombatTab, "JudgemanOn", "Auto Judgeman", function(on) NEXUS_LV.JudgemanOn = on end)
    PT(CombatTab, "TenShadowsOn", "Auto Ten Shadows", function(on) TenShadowsOn = on end)

    CombatTab:CreateSection("NPC Control")
    PT(CombatTab, "BringOn", "Bring NPCs", function(on)
        NEXUS_LV.BringOn = on
        if not on and not NEXUS_LV.BringAllOn then NEXUS_LV.restoreBrought() end
    end)
    PT(CombatTab, "BringAllOn", "Bring Every NPC", function(on)
        NEXUS_LV.BringAllOn = on
        if not on and not NEXUS_LV.BringOn then NEXUS_LV.restoreBrought() end
    end)
    CombatTab:CreateSlider({ Name = "Bring Range", Range = { 50, 2000 }, Increment = 1,
        CurrentValue = NEXUS_LV.BRING_RANGE, Callback = function(v) NEXUS_LV.BRING_RANGE = v end })

    CombatTab:CreateSection("Equipment")
    for _, nexusSlot in ipairs({ 1, 2, 3, 4, 5 }) do
        NexusAddSlotSwitch(CombatTab, nexusSlot)
    end
    PT(CombatTab, "NexusSWSMOn", "SW Use S'M", function(on) NexusSWSMOn = on end)
    PT(CombatTab, "NexusSWFillOn", "SW Fill S'M", function(on) NexusSWFillOn = on end)

NexusVisOn      = false
NexusVisConn    = nil
NexusVisGen     = 0
NEXUS_VIS_CHUNK = 1500
NexusVisMapRoot = nil
NexusVisNpcRoot = nil

NexusVisStore   = setmetatable({}, { __mode = "k" })

function NexusVisRoots()
    local out = {}
    NexusVisMapRoot = workspace:FindFirstChild("Map")
    local chars = workspace:FindFirstChild("Characters")
    NexusVisNpcRoot = chars and chars:FindFirstChild("Server") or nil
    if NexusVisMapRoot then out[#out + 1] = { root = NexusVisMapRoot, gui = true } end
    if NexusVisNpcRoot then out[#out + 1] = { root = NexusVisNpcRoot, gui = false } end
    return out
end

function NexusVisHideOne(o, allowGui)
    pcall(function()
        if o:IsA("BasePart") then
            o.LocalTransparencyModifier = 1
        elseif o:IsA("Decal") then
            if NexusVisStore[o] == nil then NexusVisStore[o] = o.Transparency end
            o.Transparency = 1
        elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
            or o:IsA("Light") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
            if NexusVisStore[o] == nil then NexusVisStore[o] = o.Enabled end
            o.Enabled = false
        elseif o.ClassName == "Highlight" then
            if NexusVisStore[o] == nil then NexusVisStore[o] = o.Enabled end
            o.Enabled = false
        elseif allowGui and (o.ClassName == "BillboardGui" or o.ClassName == "SurfaceGui") then
            if NexusVisStore[o] == nil then NexusVisStore[o] = o.Enabled end
            o.Enabled = false
        end
    end)
end

function NexusVisScan(gen, hide)
    for _, e in ipairs(NexusVisRoots()) do
        local list = e.root:GetDescendants()
        local n = 0
        for i = 1, #list do
            if gen ~= NexusVisGen then return end
            local o = list[i]
            if hide then
                NexusVisHideOne(o, e.gui)
            elseif o:IsA("BasePart") then
                pcall(function() o.LocalTransparencyModifier = 0 end)
            end
            n = n + 1
            if n >= NEXUS_VIS_CHUNK then n = 0 task.wait() end
        end
    end
end

function NexusVisRestoreStored()
    for o, v in pairs(NexusVisStore) do
        pcall(function()
            if type(v) == "boolean" then o.Enabled = v else o.Transparency = v end
        end)
    end
    NexusVisStore = setmetatable({}, { __mode = "k" })
end

function NexusVisApply(on)
    NexusVisOn  = on
    NexusVisGen = NexusVisGen + 1
    local gen  = NexusVisGen

    if on then

        if not NexusVisConn then
            NexusVisConn = workspace.DescendantAdded:Connect(function(o)
                if not NexusVisOn then return end
                if NexusVisMapRoot and o:IsDescendantOf(NexusVisMapRoot) then
                    NexusVisHideOne(o, true)
                elseif NexusVisNpcRoot and o:IsDescendantOf(NexusVisNpcRoot) then
                    NexusVisHideOne(o, false)
                end
            end)
            pcall(function() CONNS[#CONNS + 1] = NexusVisConn end)
        end
        task.spawn(function() NexusVisScan(gen, true) end)
    else

        if NexusVisConn then
            pcall(function() NexusVisConn:Disconnect() end)
            NexusVisConn = nil
        end
        task.spawn(function()
            NexusVisScan(gen, false)
            NexusVisRestoreStored()
        end)
    end
end

NexusSmLevel      = NexusSmLevel or 0
NexusSmAuto       = NexusSmAuto or false
NexusSmTarget     = NexusSmTarget or 60
NexusSmHideMine   = NexusSmHideMine or false
NexusSmHideOthers = NexusSmHideOthers or false
NexusSmMute       = NexusSmMute or false
NexusSmNoVfx      = NexusSmNoVfx or false
NexusSmCap        = NexusSmCap or 0
NexusSmCapOn      = NexusSmCapOn or false
NexusSmBusy       = false
NexusSmProg       = 0
NexusSmFps        = 0
NexusSmAvg        = 0
NexusSmNote       = "off"
NexusSmNames      = { [0] = "OFF", [1] = "LIGHT", [2] = "FAST", [3] = "EXTREME", [4] = "POTATO" }

local SM_CHUNK  = 900
local SM_QCHUNK = 250
local SM_QGAP   = 0.25
-- [NEXUS-FIX] Upper bound for the DescendantAdded queue. Without this a VFX
-- storm could grow NexusSmQueue without limit and pin every instance in RAM.
SM_QMAX = 2000

NEXUS_VFX_CLASS = {
    ParticleEmitter = true, Trail = true, Beam = true, Smoke = true,
    Fire = true, Sparkles = true, Highlight = true,
}

function NexusSmFresh()
    NexusSmR = {
        effects = {}, atmos = {}, lights = {}, emits = {}, highs = {}, bills = {},
        decals = {}, meshTex = {}, meshFid = {},
        matI = {}, matV = {}, matR = {},
        hidden = {}, vfx = setmetatable({}, { __mode = "k" }), lighting = nil,
    }
end
if not NexusSmR then NexusSmFresh() end

-- [NEXUS-FIX] vfx is now a set keyed by instance, so count it by iteration.
function NexusSmVfxCount()
    local n = 0
    if NexusSmR and NexusSmR.vfx then
        for _ in pairs(NexusSmR.vfx) do n = n + 1 end
    end
    return n
end
-- Let the shared pruner drop destroyed VFX every 5s.
pcall(function() NexusPruneRegister(function() return NexusSmR and NexusSmR.vfx end) end)

function NexusSmCapFn()
    if type(setfpscap) == "function" then return setfpscap end
    if type(set_fps_cap) == "function" then return set_fps_cap end
    return nil
end

function NexusSmReadCap()
    if type(getfpscap) == "function" then
        local ok, v = pcall(getfpscap)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return nil
end

function NexusSmApplyCap()
    local f = NexusSmCapFn()
    if not f then return false end

    pcall(function() f(NexusSmCap == 0 and 9999 or NexusSmCap) end)
    return true
end

function NexusSmSetCap(n)
    NexusSmCap = tonumber(n) or 0
    NexusSmCapOn = true
    if not NexusSmApplyCap() then
        pcall(function() Library:Notify("This executor has no setfpscap", 5) end)
    end
end

function NexusSmLightDown()
    if NexusSmR.lighting then return end
    local L, T = NexusLighting, workspace:FindFirstChildOfClass("Terrain")
    local UGS
    pcall(function() UGS = UserSettings():GetService("UserGameSettings") end)
    local snap = {}
    pcall(function() snap.shadows = L.GlobalShadows end)
    pcall(function() snap.tech    = L.Technology end)
    pcall(function() snap.envD    = L.EnvironmentDiffuseScale end)
    pcall(function() snap.envS    = L.EnvironmentSpecularScale end)
    pcall(function() snap.qual    = settings().Rendering.QualityLevel end)
    pcall(function() snap.saved   = UGS and UGS.SavedQualityLevel end)
    pcall(function() snap.wave    = T and T.WaterWaveSize end)
    pcall(function() snap.wspeed  = T and T.WaterWaveSpeed end)
    pcall(function() snap.refl    = T and T.WaterReflectance end)
    pcall(function() snap.vol     = UGS and UGS.MasterVolume end)
    NexusSmR.lighting = snap

    pcall(function() L.GlobalShadows = false end)
    pcall(function() L.EnvironmentDiffuseScale = 0 end)
    pcall(function() L.EnvironmentSpecularScale = 0 end)

    if not pcall(function() L.Technology = Enum.Technology.Compatibility end) then
        pcall(function() sethiddenproperty(L, "Technology", 2) end)
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
    pcall(function() if UGS then UGS.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end end)
    if T then
        pcall(function() T.WaterWaveSize = 0 end)
        pcall(function() T.WaterWaveSpeed = 0 end)
        pcall(function() T.WaterReflectance = 0 end)
    end
end

function NexusSmLightUp()
    local snap = NexusSmR.lighting
    if not snap then return end
    local L, T = NexusLighting, workspace:FindFirstChildOfClass("Terrain")
    local UGS
    pcall(function() UGS = UserSettings():GetService("UserGameSettings") end)
    pcall(function() if snap.shadows ~= nil then L.GlobalShadows = snap.shadows end end)
    if snap.tech then
        if not pcall(function() L.Technology = snap.tech end) then
            pcall(function() sethiddenproperty(L, "Technology", snap.tech.Value) end)
        end
    end
    pcall(function() if snap.envD then L.EnvironmentDiffuseScale = snap.envD end end)
    pcall(function() if snap.envS then L.EnvironmentSpecularScale = snap.envS end end)
    pcall(function() if snap.qual then settings().Rendering.QualityLevel = snap.qual end end)
    pcall(function() if UGS and snap.saved then UGS.SavedQualityLevel = snap.saved end end)
    if T then
        pcall(function() if snap.wave then T.WaterWaveSize = snap.wave end end)
        pcall(function() if snap.wspeed then T.WaterWaveSpeed = snap.wspeed end end)
        pcall(function() if snap.refl then T.WaterReflectance = snap.refl end end)
    end
    pcall(function() if UGS and snap.vol and not NexusSmMute then UGS.MasterVolume = snap.vol end end)
    NexusSmR.lighting = nil
end

function NexusSmKillFx()
    local R = NexusSmR
    for _, c in ipairs(NexusLighting:GetDescendants()) do
        if c:IsA("PostEffect") then
            if c.Enabled then
                R.effects[#R.effects + 1] = c
                c.Enabled = false
            end
        elseif c:IsA("Atmosphere") then
            local seen = false
            for _, a in ipairs(R.atmos) do
                if a[1] == c then seen = true break end
            end
            if not seen then R.atmos[#R.atmos + 1] = { c, c.Density, c.Haze, c.Glare } end
            pcall(function() c.Density = 0 c.Haze = 0 c.Glare = 0 end)
        end
    end
end

function NexusSmRestoreFx()
    local R = NexusSmR
    for _, e in ipairs(R.effects) do pcall(function() e.Enabled = true end) end
    R.effects = {}
    for _, a in ipairs(R.atmos) do
        pcall(function() a[1].Density = a[2] a[1].Haze = a[3] a[1].Glare = a[4] end)
    end
    R.atmos = {}
end

NexusSmVfxConn = nil

function NexusSmVfxOne(o)
    local cn = o.ClassName
    if NEXUS_VFX_CLASS[cn] then
        if o.Enabled then
            local R = NexusSmR
            R.vfx[o] = true
            o.Enabled = false
        end
        return true
    elseif cn == "Explosion" then
        pcall(function() o.Visible = false end)
        return true
    end
    return false
end

function NexusSmVfxSweep()
    task.spawn(function()
        local roots = { workspace, RepStorage, NexusLighting }
        local lp = LocalPlayer
        if lp and lp.Character then roots[#roots + 1] = lp.Character end
        for _, root in ipairs(roots) do
            local ok, list = pcall(function() return root:GetDescendants() end)
            if ok and list then
                for i = 1, #list do
                    if NEXUSG.NexusPlayHubSession ~= SESSION or not NexusSmNoVfx then return end
                    local o = list[i]
                    if o.Parent then pcall(NexusSmVfxOne, o) end
                    if i % SM_CHUNK == 0 then task.wait() end
                end
            end
        end
    end)
end

function NexusSmVfxApply(on)
    NexusSmNoVfx = on
    if on then
        if not NexusSmVfxConn then

            NexusSmVfxConn = workspace.DescendantAdded:Connect(function(o)
                if not NexusSmNoVfx then return end
                local cn = o.ClassName
                if NEXUS_VFX_CLASS[cn] then
                    if o.Enabled then
                        local R = NexusSmR
                        R.vfx[o] = true
                        o.Enabled = false
                    end
                elseif cn == "Explosion" then
                    pcall(function() o.Visible = false end)
                end
            end)
            pcall(function() CONNS[#CONNS + 1] = NexusSmVfxConn end)
        end
        NexusSmVfxSweep()
    else
        if NexusSmVfxConn then
            pcall(function() NexusSmVfxConn:Disconnect() end)
            NexusSmVfxConn = nil
        end
        local R = NexusSmR
        for o in pairs(R.vfx) do pcall(function() o.Enabled = true end) end
        R.vfx = setmetatable({}, { __mode = "k" })
    end
end

function NexusSmMine(inst)
    if NexusSmHideMine then return false end
    local ch = LocalPlayer and LocalPlayer.Character
    if not ch then return false end
    local ok, res = pcall(function() return inst:IsDescendantOf(ch) end)
    return ok and res
end

function NexusSmApply(inst, lvl)
    local R, cn = NexusSmR, inst.ClassName
    if lvl >= 2 then
        if cn == "ParticleEmitter" or cn == "Trail" or cn == "Beam" or cn == "Smoke" or cn == "Fire" or cn == "Sparkles" then
            if inst.Enabled and not NexusSmMine(inst) then
                R.emits[#R.emits + 1] = inst
                inst.Enabled = false
            end
            return
        elseif cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight" then
            if inst.Enabled then
                R.lights[#R.lights + 1] = inst
                inst.Enabled = false
            end
            return
        elseif cn == "Highlight" then
            if inst.Enabled and not NexusSmMine(inst) then
                R.highs[#R.highs + 1] = inst
                inst.Enabled = false
            end
            return
        end
    end
    if lvl >= 3 then
        if cn == "Decal" or cn == "Texture" then
            if inst.Transparency < 1 then
                R.decals[#R.decals + 1] = { inst, inst.Transparency }
                inst.Transparency = 1
            end
            return
        elseif cn == "BillboardGui" then
            if inst.Enabled and not NexusSmMine(inst) then
                R.bills[#R.bills + 1] = inst
                inst.Enabled = false
            end
            return
        elseif cn == "MeshPart" then
            if inst.TextureID ~= "" then
                R.meshTex[#R.meshTex + 1] = { inst, inst.TextureID }
                pcall(function() inst.TextureID = "" end)
            end
            if inst.RenderFidelity ~= Enum.RenderFidelity.Performance then
                R.meshFid[#R.meshFid + 1] = { inst, inst.RenderFidelity }
                pcall(function() inst.RenderFidelity = Enum.RenderFidelity.Performance end)
            end
        end
    end
    if lvl >= 4 and inst:IsA("BasePart") then
        if inst.Material ~= Enum.Material.SmoothPlastic then
            local n = #R.matI + 1
            R.matI[n], R.matV[n], R.matR[n] = inst, inst.Material, inst.Reflectance
            pcall(function() inst.Material = Enum.Material.SmoothPlastic inst.Reflectance = 0 end)
        end
    end
end

function NexusSmRestoreInst()
    local R = NexusSmR
    for _, e in ipairs(R.emits)  do pcall(function() e.Enabled = true end) end
    for _, e in ipairs(R.lights) do pcall(function() e.Enabled = true end) end
    for _, e in ipairs(R.highs)  do pcall(function() e.Enabled = true end) end
    for _, e in ipairs(R.bills)  do pcall(function() e.Enabled = true end) end
    for _, d in ipairs(R.decals) do pcall(function() d[1].Transparency = d[2] end) end
    for _, m in ipairs(R.meshTex) do pcall(function() m[1].TextureID = m[2] end) end
    for _, m in ipairs(R.meshFid) do pcall(function() m[1].RenderFidelity = m[2] end) end
    for i = 1, #R.matI do
        local inst, mat, refl = R.matI[i], R.matV[i], R.matR[i]
        pcall(function() inst.Material = mat inst.Reflectance = refl end)
    end
    for _, h in ipairs(R.hidden) do pcall(function() h[1].LocalTransparencyModifier = h[2] end) end
    R.emits, R.lights, R.highs, R.bills = {}, {}, {}, {}
    R.decals, R.meshTex, R.meshFid = {}, {}, {}
    R.matI, R.matV, R.matR, R.hidden = {}, {}, {}, {}
end

function NexusSmHideChar(char)
    if not char then return end
    local R = NexusSmR
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then
            if d.LocalTransparencyModifier < 1 then
                R.hidden[#R.hidden + 1] = { d, d.LocalTransparencyModifier }
                pcall(function() d.LocalTransparencyModifier = 1 end)
            end
        elseif d:IsA("BillboardGui") and d.Enabled then
            R.bills[#R.bills + 1] = d
            d.Enabled = false
        end
    end
end

function NexusSmHideAll()
    for _, pl in ipairs(NEXUS_LV.Players:GetPlayers()) do
        if pl ~= LocalPlayer then NexusSmHideChar(pl.Character) end
    end
end

function NexusSmSweep(lvl)
    if NexusSmBusy then return end
    NexusSmBusy = true
    task.spawn(function()
        local list = wsDesc()
        local total = #list
        for i = 1, total do
            if NEXUSG.NexusPlayHubSession ~= SESSION or NexusSmLevel ~= lvl then break end
            local inst = list[i]
            if inst.Parent then pcall(NexusSmApply, inst, lvl) end
            if i % SM_CHUNK == 0 then
                NexusSmProg = math.floor(i / total * 100)
                task.wait()
            end
        end
        NexusSmProg = 100
        NexusSmBusy = false
    end)
end

NexusSmQueue, NexusSmQN, NexusSmQConn = {}, 0, nil

function NexusSmQStart()
    if NexusSmQConn then return end
    NexusSmQConn = workspace.DescendantAdded:Connect(function(inst)
        -- [NEXUS-FIX] Drop new work once the backlog is full.
        if NexusSmQN >= SM_QMAX then return end
        NexusSmQN = NexusSmQN + 1
        NexusSmQueue[NexusSmQN] = inst
    end)
    pcall(function() CONNS[#CONNS + 1] = NexusSmQConn end)
end

function NexusSmQStop()
    if NexusSmQConn then
        pcall(function() NexusSmQConn:Disconnect() end)
        NexusSmQConn = nil
    end
    NexusSmQueue, NexusSmQN = {}, 0
end

NexusSmFrames, NexusSmLastT, NexusSmFpsConn = 0, os.clock(), nil

function NexusSmMeterOn()
    if NexusSmFpsConn then return end

    NexusSmFpsConn = RunService.RenderStepped:Connect(function()
        NexusSmFrames = NexusSmFrames + 1
    end)
    pcall(function() CONNS[#CONNS + 1] = NexusSmFpsConn end)
end

function NexusSmMeterOff()
    if NexusSmFpsConn then
        pcall(function() NexusSmFpsConn:Disconnect() end)
        NexusSmFpsConn = nil
    end
    NexusSmFps, NexusSmAvg = 0, 0
end

function NexusSmSetLevel(lvl, why)
    lvl = math.clamp(tonumber(lvl) or 0, 0, 4)
    if lvl == NexusSmLevel then return end
    local old = NexusSmLevel
    NexusSmLevel = lvl
    NexusSmNote = why or "manual"

    if lvl == 0 then
        NexusSmQStop()
        NexusSmRestoreInst()
        NexusSmRestoreFx()
        NexusSmLightUp()
        NexusSmProg = 0
        if not NexusSmAuto then NexusSmMeterOff() end
        return
    end

    if lvl < old then NexusSmRestoreInst() end

    NexusSmMeterOn()
    NexusSmLightDown()
    NexusSmKillFx()
    NexusSmQStart()
    NexusSmSweep(lvl)
    if lvl >= 3 or NexusSmHideOthers then NexusSmHideAll() end
    if lvl >= 4 or NexusSmMute then
        pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = 0 end)
    end
end

function NexusSmStatusText()
    local ping, mem = 0, 0
    pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    pcall(function() mem = game:GetService("Stats"):GetTotalMemoryUsageMb() end)
    local R = NexusSmR
    local live = NexusSmReadCap()
    local capTxt
    if not NexusSmCapFn() then
        capTxt = "not supported by this executor"
    else
        capTxt = (NexusSmCap == 0 and "Unlimited" or tostring(NexusSmCap))
        if live then capTxt = capTxt .. "  (live " .. tostring(math.floor(live)) .. ")" end
    end
    local L = {}
    L[#L + 1] = string.format("FPS %d   avg %d   ping %dms   mem %dMB",
        math.floor(NexusSmFps + 0.5), math.floor(NexusSmAvg + 0.5), math.floor(ping + 0.5), math.floor(mem))
    L[#L + 1] = string.format("Mode  %s%s", NexusSmNames[NexusSmLevel] or "?",
        NexusSmBusy and string.format("   (applying %d%%)", NexusSmProg) or "")
    L[#L + 1] = string.format("Auto  %s   target %d fps   [%s]",
        NexusSmAuto and "ON" or "off", NexusSmTarget, NexusSmNote)
    L[#L + 1] = string.format("Cap   %s", capTxt)
    L[#L + 1] = string.format("VFX   %s", NexusSmNoVfx and ("ALL KILLED  (" .. NexusSmVfxCount() .. ")") or "normal")
    L[#L + 1] = ""
    L[#L + 1] = string.format("Effects off   %d      Lights off  %d", #R.emits, #R.lights)
    L[#L + 1] = string.format("Outlines off  %d      Labels off  %d", #R.highs, #R.bills)
    L[#L + 1] = string.format("Decals hidden %d      Mesh tex    %d", #R.decals, #R.meshTex)
    L[#L + 1] = string.format("Mesh detail   %d      Flattened   %d", #R.meshFid, #R.matI)
    L[#L + 1] = string.format("Blur/Bloom    %d      Players hid %d", #R.effects, #R.hidden)
    return table.concat(L, "\n")
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        -- [NEXUS-FIX] This used to require NexusSmLevel > 0. With the queue
        -- running at level 0 nothing ever drained it, so the table grew
        -- forever and held a hard reference to every spawned instance.
        -- Now it always drains; at level 0 the entries are simply discarded.
        if NexusSmQN > 0 then
            local lvl, took = NexusSmLevel, 0
            local nq, nn = {}, 0
            for i = 1, NexusSmQN do
                local inst = NexusSmQueue[i]
                NexusSmQueue[i] = nil
                if lvl > 0 then
                    if took < SM_QCHUNK then
                        took = took + 1
                        if inst and inst.Parent then pcall(NexusSmApply, inst, lvl) end
                    elseif inst and inst.Parent and nn < SM_QMAX then
                        nn = nn + 1
                        nq[nn] = inst
                    end
                end
            end
            NexusSmQueue, NexusSmQN = nq, nn
        end
        task.wait(SM_QGAP)
    end
end)

task.spawn(function()
    local bad, good, acc = 0, 0, 0
    while NEXUSG.NexusPlayHubSession == SESSION do
        task.wait(0.5)
        if NexusSmFpsConn then
            local now = os.clock()
            local dt = now - NexusSmLastT
            if dt > 0 then
                NexusSmFps = NexusSmFrames / dt
                NexusSmAvg = (NexusSmAvg > 0) and (NexusSmAvg * 0.7 + NexusSmFps * 0.3) or NexusSmFps
            end
            NexusSmFrames, NexusSmLastT = 0, now

            acc = acc + 1
            if acc >= 4 and NexusSmAuto and not NexusSmBusy then
                acc = 0
                local f = NexusSmAvg
                if f > 0 then
                    if f < NexusSmTarget then
                        good = 0
                        bad = bad + 1

                        if bad >= 2 and NexusSmLevel < 4 then
                            bad = 0
                            NexusSmSetLevel(NexusSmLevel + 1, string.format("auto up (%d fps)", math.floor(f)))
                        end
                    elseif f > NexusSmTarget + 15 then
                        bad = 0
                        good = good + 1
                        if good >= 5 and NexusSmLevel > 1 then
                            good = 0
                            NexusSmSetLevel(NexusSmLevel - 1, string.format("auto down (%d fps)", math.floor(f)))
                        end
                    else
                        bad, good = 0, 0
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        if NexusSmCapOn then
            local live = NexusSmReadCap()
            local want = (NexusSmCap == 0) and 9999 or NexusSmCap

            if live and math.abs(live - want) > 1 then pcall(NexusSmApplyCap) end
        end
        if NexusSmLevel > 0 then
            pcall(NexusSmKillFx)
            pcall(function()
                local L = NexusLighting
                if L.GlobalShadows then L.GlobalShadows = false end
            end)
            if NexusSmLevel >= 3 or NexusSmHideOthers then pcall(NexusSmHideAll) end
        end
        task.wait(3)
    end
end)

CONNS[#CONNS + 1] = { Disconnect = function()
    pcall(NexusSmQStop)
    pcall(NexusSmMeterOff)
    pcall(function() NexusSmVfxApply(false) end)
    pcall(NexusSmRestoreInst)
    pcall(NexusSmRestoreFx)
    pcall(NexusSmLightUp)
end }

CONNS[#CONNS + 1] = { Disconnect = function()
    if NexusVisConn then pcall(function() NexusVisConn:Disconnect() end) NexusVisConn = nil end
end }

    SettingsTab:CreateSection("Performance")
    NexusDelaySlider(SettingsTab, { Name = "Loop Speed sec", Range = { 0.02, 0.5 }, Increment = 0.01, CurrentValue = LOOP_GAP, Callback = function(v) LOOP_GAP = v end })
    NexusDelaySlider(SettingsTab, { Name = "Scan Cache sec", Range = { 0.1, 2 }, Increment = 0.01, CurrentValue = SCAN_CACHE, Callback = function(v) SCAN_CACHE = v end })
    NexusDelaySlider(SettingsTab, { Name = "Target Cache sec", Range = { 0.02, 0.5 }, Increment = 0.01, CurrentValue = TGT_CACHE_SEC, Callback = function(v) TGT_CACHE_SEC = v end })
    PT(SettingsTab, "RemoveVisualOn", "Remove NPCs & Map (Visual)", function(on)
        NexusVisApply(on)
    end)

    NexusSmPanel = SettingsTab:CreateParagraph({ Title = "Smooth / FPS Status", Text = "Loading..." })
    nexusRefreshButton(SettingsTab)
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            pcall(function() NexusReqRefresh("Smooth / FPS Status", NexusSmPanel, NexusSmStatusText()) end)

            task.wait((NexusSmLevel > 0 or NexusSmAuto or NexusSmNoVfx) and 0.5 or 2)
        end
    end)

    SettingsTab:CreateDropdown({
        Name          = "Boost Level",
        Options       = { "Off", "1 - Light", "2 - Fast", "3 - Extreme", "4 - Potato" },
        CurrentOption = { "Off" },
        MultipleOptions = false,
        Callback = function(choice)
            local c = (type(choice) == "table" and choice[1]) or choice
            local lvl = tonumber(tostring(c):match("^(%d)")) or 0
            NexusSmAuto = false
            NexusSmSetLevel(lvl, "manual")
        end,
    })

    PT(SettingsTab, "SmoothAutoOn", "Auto Fix Lag (adaptive)", function(on)
        NexusSmAuto = on
        if on then
            NexusSmMeterOn()
            NexusSmNote = "watching fps"
            if NexusSmLevel == 0 then NexusSmSetLevel(1, "auto start") end
        else
            NexusSmNote = "off"
            if NexusSmLevel == 0 then NexusSmMeterOff() end
        end
    end)

    SettingsTab:CreateSlider({ Name = "Target FPS", Range = { 20, 240 }, Increment = 5,
        CurrentValue = NexusSmTarget, Callback = function(v) NexusSmTarget = v end })

    SettingsTab:CreateDropdown({
        Name          = "FPS Cap (fix 30 fps lock)",
        Options       = { "Unlimited", "30", "60", "75", "120", "144", "165", "240", "360" },
        CurrentOption = { "Unlimited" },
        MultipleOptions = false,
        Callback = function(choice)
            local c = (type(choice) == "table" and choice[1]) or choice
            NexusSmSetCap(tonumber(c) or 0)
        end,
    })

    PT(SettingsTab, "SmoothNoVfxOn", "Kill ALL VFX (every single one)", function(on)
        NexusSmVfxApply(on)
    end)

    PT(SettingsTab, "SmoothHideMineOn", "Also Strip MY Own Effects", function(on)
        NexusSmHideMine = on
    end)

    PT(SettingsTab, "SmoothHideOthersOn", "Hide Other Players", function(on)
        NexusSmHideOthers = on
        if on then
            NexusSmHideAll()
        else
            for _, h in ipairs(NexusSmR.hidden) do
                pcall(function() h[1].LocalTransparencyModifier = h[2] end)
            end
            NexusSmR.hidden = {}
        end
    end)

    PT(SettingsTab, "SmoothMuteOn", "Mute Game Sounds", function(on)
        NexusSmMute = on
        pcall(function()
            local UGS = UserSettings():GetService("UserGameSettings")
            if on then
                UGS.MasterVolume = 0
            else
                UGS.MasterVolume = (NexusSmR.lighting and NexusSmR.lighting.vol) or 0.5
            end
        end)
    end)

    SettingsTab:CreateButton({ Name = "Restore Graphics (undo the boost)", Callback = function()
        NexusSmAuto = false
        NexusSmSetLevel(0, "restored")
        pcall(function() NexusSmVfxApply(false) end)
        pcall(function() Library:Notify("Graphics restored", 4) end)
    end })

    SettingsTab:CreateSection("Combat Settings")
    NexusDelaySlider(SettingsTab, { Name = "Skill Speed sec", Range = { 0.01, 1 }, Increment = 0.01, CurrentValue = SKILL_GAP, Callback = function(v) SKILL_GAP = v end })
    NexusDelaySlider(SettingsTab, { Name = "Skill Budget per sec", Range = { 20, 200 }, Increment = 1, CurrentValue = SKILL_BUDGET, Callback = function(v) SKILL_BUDGET = v end })
    SettingsTab:CreateSlider({ Name = "Aura Range", Range = { 50, 20000 }, Increment = 1,
        CurrentValue = NEXUS_LV.AURA_RANGE, Callback = function(v) NEXUS_LV.AURA_RANGE = v end })

    SettingsTab:CreateSection("Position Settings")
    SettingsTab:CreateDropdown({
        Name          = "Aura Position",
        Options       = { "Top", "Front", "Bottom", "Back" },
        CurrentOption = { NEXUS_LV.AURA_MODE },
        MultipleOptions = false,
        Callback = function(choice)
            NEXUS_LV.AURA_MODE = (type(choice) == "table" and choice[1]) or choice
            pcall(NexusDropAnchor)
        end,
    })
    SettingsTab:CreateSlider({ Name = "Offset X", Range = { -200, 200 }, Increment = 1,
        CurrentValue = OX, Callback = function(v) OX = v end })
    SettingsTab:CreateSlider({ Name = "Offset Y", Range = { -200, 200 }, Increment = 1,
        CurrentValue = OY, Callback = function(v) OY = v end })
    SettingsTab:CreateSlider({ Name = "Offset Z", Range = { -200, 200 }, Increment = 1,
        CurrentValue = OZ, Callback = function(v) OZ = v end })

    SettingsTab:CreateSection("Safety")

    NexusSafeKickAdmin = false
    NexusSafeHopAdmin  = false
    NexusSafeKickSel   = false
    NexusSafeHopSel    = false
    NexusSafeInputTxt  = ""
    NexusSafeBusy      = false
    NexusSafeArmed     = false
    NexusSafeWatchOn   = false
    NexusSafeLabel     = nil
    NexusSafeLastTxt   = nil
    NEXUS_SAFE_GROUP_RANK = 100
    NexusSafeInputBox  = nil

    NexusSafeList = {}
    do
        local saved = S("NexusSafeList", {})
        if type(saved) == "table" then
            for _, v in ipairs(saved) do
                if type(v) == "string" then
                    local nm, idtxt = v:match("^(.-)|(.*)$")
                    if nm and nm ~= "" then
                        NexusSafeList[#NexusSafeList + 1] = { name = nm, id = tonumber(idtxt) }
                    end
                elseif type(v) == "table" and (v.name or v.id) then
                    NexusSafeList[#NexusSafeList + 1] = {
                        name = v.name and tostring(v.name) or ("User " .. tostring(v.id)),
                        id   = tonumber(v.id),
                    }
                end
            end
        end
    end

    function NexusSafeSaveList()
        local flat = {}
        for _, e in ipairs(NexusSafeList) do
            flat[#flat + 1] = tostring(e.name or "") .. "|" .. tostring(e.id or "")
        end
        Settings["NexusSafeList"] = flat
        saveSettings()
    end

    function NexusSafeListText()
        if #NexusSafeList == 0 then
            return "Empty -- type a Username or User ID above, then press Input."
        end
        local Players = NEXUS_LV.Players
        local parts = {}
        for i, e in ipairs(NexusSafeList) do
            local here = false
            for _, p in ipairs(Players:GetPlayers()) do
                if (e.id and p.UserId == e.id)
                    or (e.name and p.Name:lower() == tostring(e.name):lower()) then
                    here = true
                    break
                end
            end
            parts[#parts + 1] = i .. ". " .. tostring(e.name or "?") ..
                (e.id and ("  [" .. tostring(e.id) .. "]") or "  [name only]") ..
                (here and "   << IN SERVER" or "")
        end
        return table.concat(parts, "\n")
    end

    function NexusSafeRefresh(force)
        if not NexusSafeLabel then return end
        local txt = NexusSafeListText()
        if not force and txt == NexusSafeLastTxt then return end
        NexusSafeLastTxt = txt

        pcall(function() NexusSafeLabel:Set(txt) end)
    end

    function NexusSafeReadBox()
        if NexusSafeInputBox then
            local ok, v = pcall(function() return NexusSafeInputBox:Get() end)
            if ok and type(v) == "string" and v ~= "" then return v end
        end
        return NexusSafeInputTxt or ""
    end

    function NexusSafeIsSelected(plr)
        for _, e in ipairs(NexusSafeList) do
            if e.id and plr.UserId == e.id then return true end
            if e.name then
                local n = tostring(e.name):lower()
                if plr.Name:lower() == n then return true end
                if plr.DisplayName and plr.DisplayName:lower() == n then return true end
            end
        end
        return false
    end

    function NexusSafeIsAdmin(plr)
        if game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId then
            return true, "game owner"
        end
        if game.CreatorType == Enum.CreatorType.Group then
            local rank = 0
            pcall(function() rank = plr:GetRankInGroup(game.CreatorId) end)
            if rank >= NEXUS_SAFE_GROUP_RANK then return true, "group rank " .. rank end
        end

        local hit
        pcall(function()
            for k, v in pairs(plr:GetAttributes()) do
                local kl = tostring(k):lower()
                if (kl:find("admin") or kl:find("moder") or kl:find("staff")
                    or kl:find("command") or kl:find("permission"))
                    and v ~= nil and v ~= false and v ~= 0 and v ~= "" then
                    hit = "attribute " .. tostring(k) .. "=" .. tostring(v)
                    break
                end
            end
        end)
        if hit then return true, hit end
        pcall(function()
            for _, tag in ipairs(game:GetService("CollectionService"):GetTags(plr)) do
                local tl = tostring(tag):lower()
                if tl:find("admin") or tl:find("moder") or tl:find("staff") then
                    hit = "tag " .. tostring(tag)
                    break
                end
            end
        end)
        if hit then return true, hit end
        return false
    end

    function NexusSafeRaw(obj, methodName)
        local ok, fn = pcall(function() return obj[methodName] end)
        if not ok or type(fn) ~= "function" then return nil end
        if restorefunction then pcall(restorefunction, fn) end
        local ok2, fresh = pcall(function() return obj[methodName] end)
        if not ok2 or type(fresh) ~= "function" then fresh = fn end
        if clonefunction then
            local ok3, c = pcall(clonefunction, fresh)
            if ok3 and type(c) == "function" then fresh = c end
        end
        return fresh
    end

    function NexusSafeKickRaw(msg)
        local plr = LocalPlayer
        local k = NexusSafeRaw(plr, "Kick")
        if k then pcall(k, plr, msg) end
        task.wait(1)
        if plr.Parent then pcall(function() plr:Kick(msg) end) end
    end

    function NexusSafeHop(reason)
        local TeleportService = game:GetService("TeleportService")
        local HttpService     = game:GetService("HttpService")
        local placeId, jobId  = game.PlaceId, game.JobId
        local plr = LocalPlayer
        local q = queue_on_teleport or (syn and syn.queue_on_teleport)
            or (fluxus and fluxus.queue_on_teleport) or queueteleport or queue_teleport
        if q and NEXUSG.NexusPlayHubLoader then pcall(function() q(NEXUSG.NexusPlayHubLoader) end) end
        local cands = {}
        local ok, body = pcall(function()
            return game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
        end)
        if ok and body then
            local okD, data = pcall(function() return HttpService:JSONDecode(body) end)
            if okD and data and data.data then
                for _, s in ipairs(data.data) do
                    if s.id ~= jobId and type(s.playing) == "number" and type(s.maxPlayers) == "number"
                        and s.playing < s.maxPlayers then
                        cands[#cands + 1] = { id = s.id, playing = s.playing }
                    end
                end
                table.sort(cands, function(a, b) return a.playing < b.playing end)
            end
        end
        NexusAllowTp = true
        local tpi = NexusSafeRaw(TeleportService, "TeleportToPlaceInstance")
        local tp  = NexusSafeRaw(TeleportService, "Teleport")

        for i = 1, 4 do
            local c = cands[i]
            if not c then break end
            if tpi then pcall(tpi, TeleportService, placeId, c.id, plr)
            else pcall(function() TeleportService:TeleportToPlaceInstance(placeId, c.id, plr) end) end
            task.wait(4)
            if not plr.Parent then return end
        end

        if tp then pcall(tp, TeleportService, placeId, plr)
        else pcall(function() TeleportService:Teleport(placeId, plr) end) end
        task.wait(4)

    end

    function NexusSafeAct(plr, why, hop)
        if NexusSafeBusy then return end
        NexusSafeBusy = true
        local msg = "[NEXUSPLAY HUB] Safety -- " .. why .. ": " .. plr.Name .. " (" .. tostring(plr.UserId) .. ")"
        pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = msg, Type = "Warning", Duration = 5 }) end)
        pcall(function() NexusSafeLabel:Set(msg) end)
        NexusSafeLastTxt = msg
        warn(msg)
        task.spawn(function()
            local plr = LocalPlayer

            local prevTp, prevAfk = AntiTpOn, AntiAfkOn
            NexusAllowTp = true
            AntiTpOn    = false
            AntiAfkOn   = false
            if hop then
                pcall(function() NexusSafeHop(msg) end)
                if plr.Parent then

                    pcall(function() NexusSafeKickRaw(msg) end)
                end
            else
                pcall(function() NexusSafeKickRaw(msg) end)
                task.wait(2)
                if plr.Parent then

                    NexusAllowTp = true
                    pcall(function() NexusSafeHop(msg) end)
                end
            end

            task.wait(12)
            AntiTpOn    = prevTp
            AntiAfkOn   = prevAfk
            NexusAllowTp = false
            NexusSafeBusy = false
        end)
    end

    function NexusSafeCheck(plr)
        if NexusSafeBusy or not plr then return end
        if plr == LocalPlayer then return end
        if (NexusSafeKickSel or NexusSafeHopSel) and NexusSafeIsSelected(plr) then

            return NexusSafeAct(plr, "watch-listed player joined", NexusSafeHopSel)
        end
        if NexusSafeKickAdmin or NexusSafeHopAdmin then
            local isAdm, why = NexusSafeIsAdmin(plr)
            if isAdm then
                return NexusSafeAct(plr,
                    "player with admin commands / permissions joined (" .. tostring(why) .. ")",
                    NexusSafeHopAdmin)
            end
        end
    end

    function NexusSafeOn()
        return NexusSafeKickAdmin or NexusSafeHopAdmin or NexusSafeKickSel or NexusSafeHopSel
    end

    function NexusSafeScanNow()
        if not NexusSafeOn() then return end
        for _, p in ipairs(NEXUS_LV.Players:GetPlayers()) do
            NexusSafeCheck(p)
            if NexusSafeBusy then return true end
        end
        return false
    end

    function NexusSafeWatch()
        if NexusSafeWatchOn then return end
        NexusSafeWatchOn = true
        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION and NexusSafeOn() do
                pcall(NexusSafeScanNow)
                task.wait(2)
            end
            NexusSafeWatchOn = false
        end)
    end

    function NexusSafeArm()
        NexusSafeBusy = false
        NexusSafeWatch()
        if NexusSafeArmed then NexusSafeScanNow() return end
        NexusSafeArmed = true
        CONNS[#CONNS + 1] = NEXUS_LV.Players.PlayerAdded:Connect(function(p)
            if not NexusSafeOn() then return end
            task.spawn(function()
                pcall(function() NexusSafeCheck(p) end)

                for _ = 1, 2 do
                    if NexusSafeBusy or not p.Parent then return end
                    task.wait(1.5)
                    if not NexusSafeOn() then return end
                    pcall(function() NexusSafeCheck(p) end)
                end
            end)
        end)
        NexusSafeScanNow()
    end

    function NexusSafeAdd(txt)
        txt = (tostring(txt or ""):gsub("^%s*(.-)%s*$", "%1"))
        if txt == "" then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Type a Username or User ID first", Type = "Info", Duration = 3 }) end)
            return
        end
        local Players = NEXUS_LV.Players
        local entry
        local id = tonumber(txt)
        if id then
            entry = { id = math.floor(id) }
            pcall(function() entry.name = Players:GetNameFromUserIdAsync(entry.id) end)
            entry.name = entry.name or ("User " .. entry.id)
        else
            entry = { name = txt }
            pcall(function() entry.id = Players:GetUserIdFromNameAsync(txt) end)
        end
        for _, e in ipairs(NexusSafeList) do
            if (entry.id and e.id == entry.id)
                or (e.name and entry.name and tostring(e.name):lower() == tostring(entry.name):lower()) then
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = entry.name .. " is already on the list", Type = "Info", Duration = 3 }) end)
                return
            end
        end
        NexusSafeList[#NexusSafeList + 1] = entry
        NexusSafeSaveList()
        NexusSafeInputTxt = ""
        pcall(function() if NexusSafeInputBox then NexusSafeInputBox:Set("") end end)
        NexusSafeRefresh(true)
        pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Watching " .. tostring(entry.name), Type = "Success", Duration = 3 }) end)
        NexusSafeScanNow()
    end

    PT(SettingsTab, "NexusSafeKickAdmin", "KICK IF AD JOIN", function(on)
        NexusSafeKickAdmin = on
        if on then
            NexusSafeBusy = false
            NexusSafeArm()
        end
    end)
    PT(SettingsTab, "NexusSafeHopAdmin", "HOP IF AD JOIN", function(on)
        NexusSafeHopAdmin = on
        if on then
            NexusSafeBusy = false
            NexusSafeArm()
        end
    end)
    PT(SettingsTab, "NexusSafeKickSel", "KICK IF SELECTED PLAYER JOIN", function(on)
        NexusSafeKickSel = on
        if on then
            NexusSafeBusy = false
            NexusSafeArm()
        end
    end)
    PT(SettingsTab, "NexusSafeHopSel", "HOP IF SELECTED PLAYER JOIN", function(on)
        NexusSafeHopSel = on
        if on then
            NexusSafeBusy = false
            NexusSafeArm()
        end
    end)

    NexusSafeInputBox = SettingsTab:CreateInput({
        Name = "Username or User ID",
        PlaceholderText = "Jannat_us   or   1234567890",
        RemoveTextAfterFocusLost = false,
        Callback = function(text, enter)
            NexusSafeInputTxt = text
            if enter then NexusSafeAdd(text) end
        end,
    })
    SettingsTab:CreateButton({ Name = "Input (add to watch list)", Callback = function()
        NexusSafeAdd(NexusSafeReadBox())
    end })
    SettingsTab:CreateButton({ Name = "Check Server Now", Callback = function()
        NexusSafeBusy = false
        if not NexusSafeOn() then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Turn a Safety switch on first", Type = "Info", Duration = 3 }) end)
            return
        end
        NexusSafeRefresh(true)
        if not NexusSafeScanNow() then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Safety: nobody in this server matched", Type = "Info", Duration = 3 }) end)
        end
    end })
    SettingsTab:CreateButton({ Name = "Remove Last", Callback = function()
        if #NexusSafeList == 0 then return end
        table.remove(NexusSafeList)
        NexusSafeSaveList()
        NexusSafeRefresh(true)
    end })
    SettingsTab:CreateButton({ Name = "Clear Watch List", Callback = function()
        NexusSafeList = {}
        NexusSafeSaveList()
        NexusSafeRefresh(true)
    end })
    NexusSafeLabel = SettingsTab:CreateParagraph({ Title = "Watched Players", Text = NexusSafeListText() })
    nexusRefreshButton(SettingsTab)
    NexusSafeLastTxt = NexusSafeListText()
    NexusSafeRefresh(true)

    CONNS[#CONNS + 1] = NEXUS_LV.Players.PlayerAdded:Connect(function(p)
        task.defer(function()
            pcall(NexusSafeRefresh)
            if NexusSafeOn() then pcall(function() NexusSafeCheck(p) end) end
        end)
    end)
    CONNS[#CONNS + 1] = NEXUS_LV.Players.PlayerRemoving:Connect(function()
        task.defer(function() pcall(NexusSafeRefresh) end)
    end)

    if NexusSafeOn() then NexusSafeArm() end

    ;(function()
        local Players     = NEXUS_LV.Players
        local UserService = game:GetService("UserService")
        local CoreGuiSvc  = game:GetService("CoreGui")
        local LP          = Players.LocalPlayer

        local function track(c)
            if c then CONNS[#CONNS + 1] = c end
            return c
        end
        local function alive() return NEXUSG.NexusPlayHubSession == SESSION end

        local MY_ID = LP.UserId
        local REAL_NAME, REAL_DISPLAY = LP.Name, LP.DisplayName
        do
            local ok, infos = pcall(function()
                return UserService:GetUserInfosByUserIdsAsync({ MY_ID })
            end)
            if ok and type(infos) == "table" and infos[1] then
                if infos[1].Username and infos[1].Username ~= "" then REAL_NAME = infos[1].Username end
                if infos[1].DisplayName and infos[1].DisplayName ~= "" then REAL_DISPLAY = infos[1].DisplayName end
            end
            pcall(function() LP.Name = REAL_NAME end)
            pcall(function() LP.DisplayName = REAL_DISPLAY end)
        end

        local PROTECT_TEXT = tostring(S("NXAV_Text", "Protected by Nexus") or "")
        if PROTECT_TEXT == "" then PROTECT_TEXT = "Protected by Nexus" end

        local BODY_PARTS = {
            "UpperTorso", "LowerTorso",
            "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand",
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        }
        local COLOR_KEYS = {
            "HeadColor3", "TorsoColor3", "LeftArmColor3",
            "RightArmColor3", "LeftLegColor3", "RightLegColor3",
        }

        local function getClientFolder()
            local chars = workspace:FindFirstChild("Characters")
            return chars and chars:FindFirstChild("Client") or nil
        end

        local RealNames = {}
        local function stashName(p)
            if not RealNames[p] then RealNames[p] = { name = p.Name, display = p.DisplayName } end
            return RealNames[p]
        end
        local function realNameOf(p)
            local s = RealNames[p]
            return s and s.name or p.Name
        end
        for _, p in ipairs(Players:GetPlayers()) do stashName(p) end
        RealNames[LP] = { name = REAL_NAME, display = REAL_DISPLAY }

        local NameOverride = {}
        local ProtectOn = false

        local function writeProps(p, ov)
            pcall(function() p.Name = ov.name end)
            pcall(function() p.DisplayName = ov.display end)
        end
        local function restorePlayerName(p)
            local s = RealNames[p]
            if not s then return end
            pcall(function() p.Name = s.name end)
            pcall(function() p.DisplayName = s.display end)
        end
        local function wantedFor(p, which)
            local ov = NameOverride[p]
            if ov then return ov[which] end
            local s = RealNames[p]
            return s and s[which] or nil
        end

        local function getCharacter()
            local folder = getClientFolder()
            if not folder then return nil end
            local m = folder:FindFirstChild(REAL_NAME .. "_Client") or folder:FindFirstChild(LP.Name .. "_Client")
            if m then return m end
            local cam = workspace.CurrentCamera
            local subj = cam and cam.CameraSubject
            if subj then
                local node = subj
                if subj:IsA("Humanoid") or subj:IsA("BasePart") then node = subj.Parent end
                while node and node.Parent and node.Parent ~= folder do node = node.Parent end
                if node and node.Parent == folder then return node end
            end
            return nil
        end
        local function getCharacterOf(p)
            if p == LP then return getCharacter() end
            local folder = getClientFolder()
            if not folder then return nil end
            return folder:FindFirstChild(realNameOf(p) .. "_Client")
                or folder:FindFirstChild(p.Name .. "_Client")
        end

        local tagBound = setmetatable({}, { __mode = "k" })
        local function nameTagLabel(p)
            local model = getCharacterOf(p)
            if not model then return nil end
            local bb = model:FindFirstChildOfClass("BillboardGui")
            if not bb then return nil end
            local ov = NameOverride[p]
            for _, d in ipairs(bb:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = tostring(d.Text)
                    if t:find("@", 1, true) or (ov and t == ov.tag) then return d end
                end
            end
            return nil
        end
        local function wantedTag(p)
            local ov = NameOverride[p]
            return ov and ov.tag or ("@" .. (wantedFor(p, "name") or p.Name))
        end
        local function pushNameTag(p)
            local lbl = nameTagLabel(p)
            if not lbl then return end
            local want = wantedTag(p)
            if lbl.Text ~= want then pcall(function() lbl.Text = want end) end
        end
        local function bindNameTag(p)
            local lbl = nameTagLabel(p)
            if not lbl or tagBound[lbl] then return end
            tagBound[lbl] = true
            local guard = false
            track(lbl:GetPropertyChangedSignal("Text"):Connect(function()
                if guard or not alive() then return end
                local want = wantedTag(p)
                if lbl.Text ~= want then guard = true pcall(function() lbl.Text = want end) guard = false end
            end))
            pushNameTag(p)
        end

        local function tabRowUserId(lbl)
            local node = lbl
            for _ = 1, 8 do
                node = node.Parent
                if not node then return nil end
                local id = node.Name:match("^PlayerEntry_(%d+)$")
                if id then return tonumber(id) end
            end
            return nil
        end

        local tabBound = setmetatable({}, { __mode = "k" })
        local TabLabels = {}

        local function bindTabLabel(lbl)
            if tabBound[lbl] then return end
            local uid = tabRowUserId(lbl)
            if not uid then return end
            tabBound[lbl] = true
            TabLabels[uid] = lbl
            local guard = false
            local function enforce()
                if guard or not alive() then return end
                local p = Players:GetPlayerByUserId(uid)
                if not p then return end
                local want = wantedFor(p, "display")
                if want and lbl.Text ~= want then
                    guard = true pcall(function() lbl.Text = want end) guard = false
                end
            end
            track(lbl:GetPropertyChangedSignal("Text"):Connect(enforce))
            enforce()
        end

        local function scanTabList()
            local pl = CoreGuiSvc:FindFirstChild("PlayerList")
            if not pl then return 0 end
            local n = 0
            for _, d in ipairs(pl:GetDescendants()) do
                if d:IsA("TextLabel") and d.Name == "PlayerName" then bindTabLabel(d) n = n + 1 end
            end
            return n
        end

        local function pushTabFor(p)
            local lbl = TabLabels[p.UserId]
            if not (lbl and lbl.Parent) then scanTabList() lbl = TabLabels[p.UserId] end
            if lbl and lbl.Parent then
                local want = wantedFor(p, "display")
                if want and lbl.Text ~= want then pcall(function() lbl.Text = want end) end
            end
        end

        do
            local function hookList(pl)
                track(pl.DescendantAdded:Connect(function(d)
                    if alive() and d:IsA("TextLabel") and d.Name == "PlayerName" then
                        task.defer(bindTabLabel, d)
                    end
                end))
            end
            local pl = CoreGuiSvc:FindFirstChild("PlayerList")
            if pl then hookList(pl) end
            track(CoreGuiSvc.ChildAdded:Connect(function(c)
                if alive() and c.Name == "PlayerList" then
                    task.defer(function() scanTabList() hookList(c) end)
                end
            end))
            scanTabList()
        end

        local function sweepGuiTextOnce()
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            local descendants = pg:GetDescendants()
            for p, ov in pairs(NameOverride) do
                local s = RealNames[p]
                if s then
                    local pn = s.name:gsub("%W", "%%%0")
                    local pd = s.display:gsub("%W", "%%%0")
                    for _, d in ipairs(descendants) do
                        if d:IsA("TextLabel") or d:IsA("TextButton") then
                            local t = d.Text
                            if t ~= "" and (t:find(s.name, 1, true) or t:find(s.display, 1, true)) then
                                local new = t:gsub(pd, ov.display):gsub(pn, ov.name)
                                if new ~= t then pcall(function() d.Text = new end) end
                            end
                        end
                    end
                end
            end
        end

        local function applyProtectTo(p)
            stashName(p)
            NameOverride[p] = { name = PROTECT_TEXT, display = PROTECT_TEXT, tag = PROTECT_TEXT }
            writeProps(p, NameOverride[p])
            bindNameTag(p)
            pushNameTag(p)
            pushTabFor(p)
        end
        local function protectAll()
            scanTabList()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then applyProtectTo(p) end
            end
        end
        local function protectStop()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    NameOverride[p] = nil
                    restorePlayerName(p)
                    pushNameTag(p)
                    pushTabFor(p)
                end
            end
        end

        track(Players.PlayerAdded:Connect(function(p)
            if not alive() then return end
            task.delay(1.2, function()
                if not alive() then return end
                stashName(p)
                if ProtectOn then applyProtectTo(p) end
            end)
        end))
        track(Players.PlayerRemoving:Connect(function(p)
            NameOverride[p] = nil RealNames[p] = nil TabLabels[p.UserId] = nil
        end))

        local function inspectRig()
            local char = getCharacter()
            if not char then return nil, "Character not found -- are you fully spawned in?" end
            local visual = char:FindFirstChild("Visual")
            if not visual then return nil, "No 'Visual' model found -- unrecognized character build." end
            local outerHum = char:FindFirstChildOfClass("Humanoid")
            local visHum   = visual:FindFirstChildOfClass("Humanoid")
            local found = visual:FindFirstChild("Head") and 1 or 0
            for _, n in ipairs(BODY_PARTS) do if visual:FindFirstChild(n) then found = found + 1 end end
            local animJoints, motors = 0, 0
            for _, d in ipairs(visual:GetDescendants()) do
                if d:IsA("AnimationConstraint") then animJoints = animJoints + 1
                elseif d:IsA("Motor6D") then motors = motors + 1 end
            end
            return { char = char, visual = visual,
                outerRig = outerHum and outerHum.RigType.Name or "unknown",
                visRig = visHum and visHum.RigType.Name or "none",
                partsFound = found, animJoints = animJoints, motors = motors }
        end

        local function setProp(inst, prop, value)
            local ok = pcall(function() inst[prop] = value end)
            if not ok and typeof(setscriptable) == "function" then
                ok = pcall(function() setscriptable(inst, prop, true) inst[prop] = value end)
            end
            return ok
        end
        local function setAsset(inst, prop, value)
            if value == nil or value == "" then return false end
            return setProp(inst, prop, value)
        end

        local Snapshot = nil
        local function collectClothing(container)
            return {
                shirt = container:FindFirstChildOfClass("Shirt"),
                pants = container:FindFirstChildOfClass("Pants"),
                tee   = container:FindFirstChildOfClass("ShirtGraphic"),
                bc    = container:FindFirstChildOfClass("BodyColors"),
            }
        end
        local function takeSnapshot(char, visual)
            local snap = { parts = {}, accessories = {}, layers = {}, charMeshes = {} }
            local function snapPart(name)
                local p = visual:FindFirstChild(name)
                if p and p:IsA("MeshPart") then
                    snap.parts[name] = { MeshId = p.MeshId, TextureID = p.TextureID, Color = p.Color }
                end
            end
            snapPart("Head")
            for _, n in ipairs(BODY_PARTS) do snapPart(n) end
            for _, container in ipairs({ char, visual }) do
                local c = collectClothing(container)
                local entry = { container = container }
                entry.shirt = c.shirt and c.shirt.ShirtTemplate or nil
                entry.pants = c.pants and c.pants.PantsTemplate or nil
                entry.tee   = c.tee and c.tee.Graphic or nil
                if c.bc then
                    entry.colors = {}
                    for _, k in ipairs(COLOR_KEYS) do entry.colors[k] = c.bc[k] end
                end
                table.insert(snap.layers, entry)
                for _, ch in ipairs(container:GetChildren()) do
                    if ch:IsA("Accoutrement") then
                        table.insert(snap.accessories, { inst = ch, parent = container })
                    elseif ch:IsA("CharacterMesh") then
                        table.insert(snap.charMeshes, { inst = ch, parent = container })
                    end
                end
            end
            local vHead = visual:FindFirstChild("Head")
            if vHead then
                local d = vHead:FindFirstChildOfClass("Decal")
                snap.faceDecal = d and { inst = d, texture = d.Texture } or nil
            end
            return snap
        end

        local function restore()
            local rig, err = inspectRig()
            NameOverride[LP] = nil
            restorePlayerName(LP)
            pushNameTag(LP)
            pushTabFor(LP)
            if not rig then return false, err end
            if not Snapshot then return true, "Name restored (no appearance change to undo)." end
            local char, visual = rig.char, rig.visual
            for _, container in ipairs({ char, visual }) do
                for _, ch in ipairs(container:GetChildren()) do
                    if ch:IsA("Accoutrement") then
                        local isOriginal = false
                        for _, o in ipairs(Snapshot.accessories) do if o.inst == ch then isOriginal = true break end end
                        if not isOriginal then pcall(function() ch:Destroy() end) end
                    end
                end
            end
            for _, o in ipairs(Snapshot.accessories) do
                if o.inst and o.inst.Parent ~= o.parent then pcall(function() o.inst.Parent = o.parent end) end
            end
            for _, o in ipairs(Snapshot.charMeshes) do
                if o.inst and o.inst.Parent ~= o.parent then pcall(function() o.inst.Parent = o.parent end) end
            end
            for name, data in pairs(Snapshot.parts) do
                local p = visual:FindFirstChild(name)
                if p and p:IsA("MeshPart") then
                    setProp(p, "MeshId", data.MeshId)
                    setProp(p, "TextureID", data.TextureID)
                    setProp(p, "Color", data.Color)
                end
            end
            for _, entry in ipairs(Snapshot.layers) do
                local container = entry.container
                if container and container.Parent then
                    local c = collectClothing(container)
                    if c.shirt and entry.shirt then pcall(function() c.shirt.ShirtTemplate = entry.shirt end) end
                    if c.pants and entry.pants then pcall(function() c.pants.PantsTemplate = entry.pants end) end
                    if c.tee then
                        if entry.tee then pcall(function() c.tee.Graphic = entry.tee end)
                        else pcall(function() c.tee:Destroy() end) end
                    end
                    if c.bc and entry.colors then
                        for k, v in pairs(entry.colors) do pcall(function() c.bc[k] = v end) end
                    end
                end
            end
            local vHead = visual:FindFirstChild("Head")
            if vHead then
                local d = vHead:FindFirstChildOfClass("Decal")
                if Snapshot.faceDecal then
                    if d then pcall(function() d.Texture = Snapshot.faceDecal.texture end) end
                elseif d then pcall(function() d:Destroy() end) end
            end
            return true, "Restored original character and name."
        end

        local function clearAppearance(char, visual)
            for _, container in ipairs({ char, visual }) do
                local c = collectClothing(container)
                if c.shirt then pcall(function() c.shirt.ShirtTemplate = "" end) end
                if c.pants then pcall(function() c.pants.PantsTemplate = "" end) end
                if c.tee   then pcall(function() c.tee:Destroy() end) end
                for _, ch in ipairs(container:GetChildren()) do
                    if ch:IsA("Accoutrement") then
                        local isOriginal = false
                        for _, o in ipairs(Snapshot.accessories) do if o.inst == ch then isOriginal = true break end end
                        if isOriginal then pcall(function() ch.Parent = nil end)
                        else pcall(function() ch:Destroy() end) end
                    elseif ch:IsA("CharacterMesh") then
                        pcall(function() ch.Parent = nil end)
                    end
                end
            end
        end

        local function findAttachment(model, name)
            for _, p in ipairs(model:GetChildren()) do
                if p:IsA("BasePart") then
                    local a = p:FindFirstChild(name)
                    if a and a:IsA("Attachment") then return a end
                end
            end
            return nil
        end
        local function attachAccessory(visual, source)
            local acc = source:Clone()
            local handle = acc:FindFirstChild("Handle") or acc:FindFirstChildWhichIsA("BasePart")
            if not handle then acc:Destroy() return false, "no handle" end
            local hAtt = handle:FindFirstChildWhichIsA("Attachment")
            acc.Parent = visual
            for _, w in ipairs(handle:GetChildren()) do
                if w:IsA("Weld") or w:IsA("WeldConstraint") then pcall(function() w:Destroy() end) end
            end
            local isLayered = false
            for _, d in ipairs(acc:GetDescendants()) do if d:IsA("WrapLayer") then isLayered = true break end end
            if isLayered then
                handle.CanCollide = false handle.CanQuery = false handle.Massless = true
                return true, "layered"
            end
            local target = hAtt and findAttachment(visual, hAtt.Name)
            if not target then
                local head = visual:FindFirstChild("Head")
                if not head then acc:Destroy() return false, "no attachment point" end
                local ok = pcall(function()
                    handle.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
                    local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = head, handle w.Parent = handle
                end)
                handle.CanCollide = false handle.CanQuery = false handle.Massless = true
                return ok, ok and "fallback weld" or "weld failed"
            end
            local ok = pcall(function()
                handle.CFrame = target.WorldCFrame * hAtt.CFrame:Inverse()
                local w = Instance.new("WeldConstraint") w.Part0, w.Part1 = target.Parent, handle w.Parent = handle
            end)
            handle.CanCollide = false handle.CanQuery = false handle.Massless = true
            return ok, ok and "welded" or "weld failed"
        end

        local function resolveTargetHead(desc, ref)
            local hid = tonumber(desc.Head) or 0
            if hid ~= 0 then
                local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. hid) end)
                if ok and type(objs) == "table" and objs[1] then
                    local o = objs[1]
                    local sm = o:IsA("SpecialMesh") and o or o:FindFirstChildWhichIsA("SpecialMesh", true)
                    if not sm and o:IsA("MeshPart") then return o.MeshId, o.TextureID, "head asset " .. hid end
                    if sm and sm.MeshId ~= "" then return sm.MeshId, sm.TextureId, "head asset " .. hid end
                end
            end
            local rh = ref and ref:FindFirstChild("Head")
            if rh and rh:IsA("MeshPart") and rh.MeshId ~= "" then
                return rh.MeshId, rh.TextureID, "reference rig"
            end
            return nil, nil, "unavailable"
        end

        local function applyHead(vHead, desc, ref, applied, skipped)
            if not vHead then table.insert(skipped, "Head not available") return end
            local oldMesh, oldTex = vHead.MeshId, vHead.TextureID
            local mesh, tex, source = resolveTargetHead(desc, ref)
            if mesh then
                local didMesh = setAsset(vHead, "MeshId", mesh)
                local didTex  = setAsset(vHead, "TextureID", tex)
                if didMesh and didTex then
                    if vHead.MeshId == oldMesh and vHead.TextureID == oldTex then
                        table.insert(skipped, "Head unchanged -- target's head is identical to yours")
                    else
                        table.insert(applied, "Head + face (" .. source .. ")")
                    end
                elseif didMesh then
                    table.insert(applied, "Head shape (" .. source .. ")")
                    table.insert(skipped, "Face texture missing on target -- kept yours")
                else
                    table.insert(skipped, "Head could not be written")
                end
            else
                table.insert(skipped, "Head unchanged -- could not resolve target head (" .. source .. ")")
            end
            local faceId = tonumber(desc.Face) or 0
            if faceId ~= 0 then
                local ok = pcall(function()
                    local d = vHead:FindFirstChild("face") or vHead:FindFirstChildOfClass("Decal")
                    if not d then
                        d = Instance.new("Decal") d.Name = "face" d.Face = Enum.NormalId.Front d.Parent = vHead
                    end
                    d.Texture = "rbxassetid://" .. tostring(faceId)
                end)
                if ok then table.insert(applied, "Classic face decal")
                else table.insert(skipped, "Classic face decal could not be applied") end
            end
        end

        local ActiveUser = nil

        local function applyAvatar(username)
            local applied, skipped = {}, {}
            local rig, err = inspectRig()
            if not rig then return false, err, applied, skipped end
            local char, visual = rig.char, rig.visual
            local okId, uid = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
            if not okId or type(uid) ~= "number" then
                return false, "Invalid username -- that user does not exist.", applied, skipped
            end

            local trueName, trueDisplay = username, username
            local okInfo, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync({ uid }) end)
            if okInfo and type(infos) == "table" and infos[1] then
                if infos[1].Username and infos[1].Username ~= "" then trueName = infos[1].Username end
                if infos[1].DisplayName and infos[1].DisplayName ~= "" then trueDisplay = infos[1].DisplayName end
            end

            local okDesc, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(uid) end)
            if not okDesc or typeof(desc) ~= "Instance" then
                return false, "Could not retrieve that user's avatar.", applied, skipped
            end
            local ref
            local okRef, res = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if okRef then ref = res end

            if not Snapshot then Snapshot = takeSnapshot(char, visual) end
            clearAppearance(char, visual)
            table.insert(applied, "Cleared original outfit")
            if not ref then table.insert(skipped, "Body meshes + accessories: reference rig could not be built") end

            if ref then
                local swapped, failedParts = 0, {}
                for _, name in ipairs(BODY_PARTS) do
                    local dst, src = visual:FindFirstChild(name), ref:FindFirstChild(name)
                    if dst and src and dst:IsA("MeshPart") and src:IsA("MeshPart") then
                        local ok = setAsset(dst, "MeshId", src.MeshId)
                        setAsset(dst, "TextureID", src.TextureID)
                        pcall(function() setProp(dst, "Color", src.Color) end)
                        if ok then swapped = swapped + 1 else table.insert(failedParts, name) end
                    elseif dst then table.insert(failedParts, name) end
                end
                if swapped > 0 then table.insert(applied, ("Body meshes (%d/%d)"):format(swapped, #BODY_PARTS)) end
                if #failedParts > 0 then table.insert(skipped, "Body parts unchanged: " .. table.concat(failedParts, ", ")) end
            end

            applyHead(visual:FindFirstChild("Head"), desc, ref, applied, skipped)

            do
                local rShirt = ref and ref:FindFirstChildOfClass("Shirt")
                local rPants = ref and ref:FindFirstChildOfClass("Pants")
                local shirtTpl = rShirt and rShirt.ShirtTemplate or ""
                local pantsTpl = rPants and rPants.PantsTemplate or ""
                local sN, pN = 0, 0
                for _, container in ipairs({ char, visual }) do
                    local c = collectClothing(container)
                    if c.shirt and shirtTpl ~= "" then
                        if pcall(function() c.shirt.ShirtTemplate = shirtTpl end) then sN = sN + 1 end
                    end
                    if c.pants and pantsTpl ~= "" then
                        if pcall(function() c.pants.PantsTemplate = pantsTpl end) then pN = pN + 1 end
                    end
                end
                if sN > 0 then table.insert(applied, ("Shirt (%d layers)"):format(sN)) end
                if pN > 0 then table.insert(applied, ("Pants (%d layers)"):format(pN)) end
                if shirtTpl == "" then table.insert(skipped, "Target wears no shirt") end
                if pantsTpl == "" then table.insert(skipped, "Target wears no pants") end
                local teeId = tonumber(desc.GraphicTShirt) or 0
                if teeId ~= 0 then
                    local ok = pcall(function()
                        local tee = visual:FindFirstChildOfClass("ShirtGraphic") or Instance.new("ShirtGraphic")
                        tee.Graphic = "rbxassetid://" .. tostring(teeId)
                        tee.Parent = visual
                    end)
                    if ok then table.insert(applied, "Graphic t-shirt")
                    else table.insert(skipped, "Graphic t-shirt could not be applied") end
                end
            end

            do
                local rbc = ref and ref:FindFirstChildOfClass("BodyColors")
                if rbc then
                    local n = 0
                    for _, container in ipairs({ char, visual }) do
                        local bc = container:FindFirstChildOfClass("BodyColors")
                        if bc then
                            for _, k in ipairs(COLOR_KEYS) do
                                if pcall(function() bc[k] = rbc[k] end) then n = n + 1 end
                            end
                        end
                    end
                    if n > 0 then table.insert(applied, ("Body colors (%d values)"):format(n))
                    else table.insert(skipped, "Body colors could not be set") end
                else table.insert(skipped, "Body colors: target supplied none") end
            end

            if ref then
                local accOk, accFail, notes = 0, 0, {}
                for _, a in ipairs(ref:GetChildren()) do
                    if a:IsA("Accoutrement") then
                        local ok, how = attachAccessory(visual, a)
                        if ok then accOk = accOk + 1 else accFail = accFail + 1 table.insert(notes, a.Name .. " (" .. tostring(how) .. ")") end
                    end
                end
                if accOk > 0 then table.insert(applied, ("Accessories (%d)"):format(accOk)) end
                if accFail > 0 then table.insert(skipped, ("%d accessory/accessories failed: %s"):format(accFail, table.concat(notes, ", "))) end
            end

            do
                NameOverride[LP] = { name = trueName, display = trueDisplay, tag = "@" .. trueName }
                writeProps(LP, NameOverride[LP])
                bindNameTag(LP)
                pushNameTag(LP)
                pushTabFor(LP)
                sweepGuiTextOnce()
                table.insert(applied, ("Name: @%s (nametag) / \"%s\" (tab list + menus)")
                    :format(trueName, trueDisplay))
            end

            if desc.HeightScale ~= 1 or desc.WidthScale ~= 1 or desc.DepthScale ~= 1 or desc.HeadScale ~= 1 then
                table.insert(skipped, ("Body size ignored (H%.2f W%.2f D%.2f Head%.2f) -- game force-locks all scales to 1")
                    :format(desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale))
            end
            table.insert(skipped, "Animation pack ignored -- game uses its own AnimationConstraint system")
            table.insert(skipped, "Part sizes ignored -- resizing would break the welds to the outer R6 rig")

            if ref then pcall(function() ref:Destroy() end) end
            ActiveUser = trueName
            if #applied <= 1 then
                return false, "Almost nothing could be applied for " .. username .. ".", applied, skipped
            end
            return true, ("Applied %s (@%s)."):format(trueDisplay, trueName), applied, skipped
        end

        do
            local folder = getClientFolder()
            if folder then
                track(folder.ChildAdded:Connect(function(child)
                    if not alive() or not child.Name:match("_Client$") then return end
                    task.delay(1.5, function()
                        if not alive() then return end
                        if child.Name == REAL_NAME .. "_Client" or child.Name == LP.Name .. "_Client" then
                            if ActiveUser then Snapshot = nil pcall(applyAvatar, ActiveUser) end
                        end
                        for p in pairs(NameOverride) do pcall(bindNameTag, p) end
                    end)
                end))
            end
        end

        local nxavName  = ""
        local nxavBusy  = false
        local nxavPanel = nil

        local function nxavSet(msg)
            local t = tostring(msg)
            nexusPanelSet(nxavPanel, t)
            pcall(function() NexusReqFit("Avatar & Name Status", t) end)
        end

        local function nxavShowState()
            local rig, err = inspectRig()
            local others = 0
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then others = others + 1 end end
            if rig then
                nxavSet(("Outer %s rig + %s visual layer  -  parts %d/15, joints %d\nYou: %s (%s)\nApplied: %s   |   Renaming others: %s (%d in server)")
                    :format(rig.outerRig, rig.visRig, rig.partsFound, rig.animJoints,
                        REAL_NAME, REAL_DISPLAY, tostring(ActiveUser or "none"),
                        ProtectOn and ("on  -  \"" .. PROTECT_TEXT .. "\"") or "off", others))
            else
                nxavSet("[!] " .. tostring(err) .. "\nRenaming others: " .. (ProtectOn and "on" or "off"))
            end
        end

        local function nxavApply()
            if nxavBusy then return end
            local name = nxavName
            if name == "" then nxavSet("Enter a username first.") return end
            if #name < 3 or #name > 20 or name:match("[^%w_]") then
                nxavSet("Invalid username format.") return
            end
            nxavBusy = true
            nxavSet("Looking up \"" .. name .. "\"...")
            task.spawn(function()
                local ok, msg, applied, skipped = applyAvatar(name)
                local lines = { (ok and "[OK] " or "[X] ") .. tostring(msg) }
                if applied and #applied > 0 then table.insert(lines, "Applied: " .. table.concat(applied, ", ")) end
                if skipped and #skipped > 0 then
                    table.insert(lines, "Skipped:")
                    for _, s in ipairs(skipped) do table.insert(lines, "  - " .. s) end
                end
                nxavSet(table.concat(lines, "\n"))
                nxavBusy = false
            end)
        end

        SettingsTab:CreateInput({
            Name = "Avatar Username",
            CurrentValue = "",
            PlaceholderText = "Roblox username",
            RemoveTextAfterFocusLost = false,
            Callback = function(text, enter)
                nxavName = (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
                if enter then nxavApply() end
            end,
        })
        SettingsTab:CreateButton({ Name = "Apply Avatar + Name", Callback = function()
            nxavApply()
        end })
        SettingsTab:CreateButton({ Name = "Reset Avatar + Name", Callback = function()
            if nxavBusy then return end
            nxavBusy = true
            task.spawn(function()
                local ok, msg = restore()
                ActiveUser = nil
                nxavSet((ok and "[OK] " or "[X] ") .. tostring(msg))
                nxavBusy = false
            end)
        end })

        SettingsTab:CreateInput({
            Name = "Other Players Name Text",
            CurrentValue = PROTECT_TEXT,
            PlaceholderText = "Protected by Nexus",
            RemoveTextAfterFocusLost = false,
            Callback = function(text)
                local t = (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
                if t == "" then t = "Protected by Nexus" end
                PROTECT_TEXT = t
                Settings["NXAV_Text"] = t
                saveSettings()
                if ProtectOn then
                    protectAll()
                    nxavSet("Other players renamed to \"" .. t .. "\".")
                end
            end,
        })

        PT(SettingsTab, "NXAV_ProtectOn", "Rename Other Players", function(on)
            ProtectOn = on and true or false
            task.spawn(function()
                if ProtectOn then
                    protectAll()
                    local n = 0
                    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then n = n + 1 end end
                    nxavSet(("%d other player(s) renamed to \"%s\". Written once, held by events -- no loop.")
                        :format(n, PROTECT_TEXT))
                else
                    protectStop()
                    nxavSet("Other players restored to their real names.")
                end
            end)
        end)

        nxavPanel = SettingsTab:CreateParagraph({ Title = "Avatar & Name Status", Text = "Ready." })
        nexusStatusHook(function() pcall(nxavShowState) end)
        nexusRefreshButton(SettingsTab)

        task.spawn(function()
            task.wait(1)
            pcall(nxavShowState)
        end)
    end)()

    SettingsTab:CreateSection("Auto Execute")
    PT(SettingsTab, "AutoExecOn", "Auto Execute", function(on)
        AutoExecOn = on
        task.spawn(function() pcall(NexusAutoExecApply) end)
    end)
    for _, nexusSec in ipairs(NEXUS_DELAY_OPTIONS) do
        NexusAddDelaySwitch(SettingsTab, nexusSec)
    end

    task.spawn(function() pcall(NexusAutoExecApply) end)

    QuestTab:CreateSection("Auto Quest")

    BRING_GAP = tonumber(S("BringDelay", BRING_GAP)) or BRING_GAP

    NexusCapRoamOn = S("CapRoam", true)
    if NexusCapRoamOn == nil then NexusCapRoamOn = true end
    QuestTab:CreateToggle({ Name = "Capture: Roam Inside Area & Hunt", CurrentValue = NexusCapRoamOn,
        Callback = function(on)
            NexusCapRoamOn = on
            Settings["CapRoam"] = on
            pcall(saveSettings)
        end }, "NEXUS_CapRoam")

    PT(QuestTab, "CapGather", "Capture: Fetch Mobs From Spawn Nodes", function(v)
        NexusCapGatherOn = v
    end)

    NexusDelaySlider(QuestTab, { Name = "Bring Delay sec", Range = { 0.05, 2 }, Increment = 0.05,
        CurrentValue = BRING_GAP, Callback = function(v)
            BRING_GAP = tonumber(v) or 0.05
            Settings["BringDelay"] = BRING_GAP
            pcall(saveSettings)
        end })

    local questOptions, questOptionToIndex = {}, {}
    for i, q in ipairs(QUEST_DATA) do
        local label = q[2]
        if questOptionToIndex[label] then label = label .. " " .. tostring(i) end
        questOptions[i] = label
        questOptionToIndex[label] = i
    end
    NexusQuestOptions = questOptions

    PT(QuestTab, "QuestOn", "Auto Quest", function(on)
        QuestOn = on
        NexusDropAnchor()

        if on then task.spawn(function() NexusOwnAccept(currentQuestId()) end) end
    end)

    questLabel = QuestTab:CreateLabel({ Text = "Selected: " .. NEXUS_LV.currentQuestName(), Style = 2 })

    NEXUS_LV.updateQuestLabel = function()
        pcall(function() questLabel:Set("Selected: " .. NEXUS_LV.currentQuestName()) end)
    end

    nxQuestDrop = QuestTab:CreateDropdown({
        Name          = "Select Quest",
        Options       = questOptions,
        CurrentOption = { questOptions[selQuest] },
        MultipleOptions = false,
        Callback = function(choice)
            if NexusQuestSync then return end
            local picked = (type(choice) == "table" and choice[1]) or choice
            local idx = questOptionToIndex[picked]
            if idx then
                local prevId = currentQuestId()
                selQuest = idx
                NEXUS_LV.updateQuestLabel()

                if QuestOn or BringQuestOn then
                    task.spawn(function()
                        local newId = currentQuestId()
                        if prevId and prevId ~= newId then pcall(NexusReleaseOwnedId, prevId) end
                        NexusOwnAccept(newId)
                    end)
                end
            end
        end,
    })

    PT(QuestTab, "AutoNext", "Auto Next Quest", function(on) NEXUS_LV.AutoNext = on end)
    PT(QuestTab, "AutoPick", "Auto Select Next Quest", function(on)
        AutoPickOn = on
        if on then task.spawn(function() NexusApplyQuestIndex(NexusBestQuestIndex(NexusMyLevel())) end) end
    end)
    PT(QuestTab, "SkipCap", "Skip Progress Area Quests", function(on)
        NexusSkipCap = on
        NexusPickList = nil
        if on and AutoPickOn then
            task.spawn(function() NexusApplyQuestIndex(NexusBestQuestIndex(NexusMyLevel())) end)
        end
    end)

    PT(QuestTab, "FastQuestOn", "Bring NPC", function(on)
        NEXUS_LV.FastQuestOn = on
        if not on then fastQuestBrought = {} fastQuestFrozenPos = nil end
    end)
    PT(QuestTab, "AutoAsc", "Auto Ascension", function(on)
        NexusAscOn = on

        NexusAscLastText = nil
        NexusAscTouch()

        task.spawn(function() task.wait(0.1) NexusAscLastText = nil NexusAscRefresh() end)
    end)
    NexusAscPanel = QuestTab:CreateParagraph({ Title = "Ascension Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusAscLastText = nil NexusAscRefresh() end)

    QuestTab:CreateSection("Star Rage Awakening Quests")
    PT(QuestTab, "StarQ1On", "1 Quest 1 - The Recruiter", function(on)
        StarQ1On = on
        if on then task.spawn(function()
            NexusStarQuestSwap("StarCultRecruiter1")
            pcall(NexusStarCultInvite)
        end) end
    end)
    PT(QuestTab, "StarQ2On", "2 Quest 2 - Brother Orin", function(on)
        StarQ2On = on
        if on then task.spawn(function() NexusStarQuestSwap("StarCult1_1") end) end
    end)
    PT(QuestTab, "StarQ3On", "3 Quest 3 - Sister Veyra", function(on)
        StarQ3On = on
        if on then task.spawn(function() NexusStarQuestSwap("StarCult2_1") end) end
    end)
    PT(QuestTab, "StarQ4On", "4 Quest 4 - Brother Calix", function(on)
        StarQ4On = on
        if on then task.spawn(function() NexusStarQuestSwap("StarCult3_1") end) end
    end)
    PT(QuestTab, "StarQ5On", "5 Quest 5 - Aria", function(on)
        StarQ5On = on
        if on then task.spawn(function() NexusStarQuestSwap("StarCult4_1") end) end
    end)

    PT(QuestTab, "StarQ6On", "6 Quest 6 - Brother Tessik [Trial of Brother Tessik]", function(on)
        StarQ6On = on
        if on then task.spawn(function() NexusStarQuestSwap(NEXUS_STAR_Q6_ID) end) end
    end)

    PT(QuestTab, "StarQ7On", "7 Quest 7 - Suspicious Cultist II [Rescue Amanai]", function(on)
        StarQ7On = on
        if on then task.spawn(function() NexusStarQuestSwap(NEXUS_STAR_Q7_ID) end) end
    end)
    PT(QuestTab, "StarBossOn", "Auto Kill Lunatic Cultist Boss -> Void Trace", function(on) StarBossOn = on end)

    QuestTab:CreateButton({ Name = "Exchange Awk Star rage [20 Star Rage + Void Trace \226\134\146 Awk Star Rage]", Callback = function()
        task.spawn(function()
            pcall(function()
                local args = { "AmanaiExchange" }
                RepStorage:WaitForChild("NetworkComm"):WaitForChild("QuestService"):WaitForChild("AcceptQuest_Method"):InvokeServer(unpack(args))
            end)
        end)
    end })

    QuestTab:CreateSection("Satoru Gojo")

    QuestTab:CreateParagraph({ Title = "Grandmother Kaya", Text = "" })
    PT(QuestTab, "SGKaya1On", "Quest 1 : A Pinch of Flour [Lv.1300]+", function(on)
        SGKaya1On = on
        if on then task.spawn(function() NexusSafeAccept("GrandmotherKaya1") end) end
    end)
    PT(QuestTab, "SGKaya2On", "Quest 2 : A Dozen Eggs [Lv.1300]+", function(on)
        SGKaya2On = on
        if on then task.spawn(function() NexusSafeAccept("GrandmotherKaya2") end) end
    end)

    QuestTab:CreateParagraph({ Title = "Groundskeeper Toshi", Text = "" })
    PT(QuestTab, "SGToshi1On", "Quest 1 : Defend the Estate [Lv.1400]+", function(on)
        SGToshi1On = on
        if on then task.spawn(function() NexusSafeAccept("GroundskeeperToshi1") end) end
    end)

    QuestTab:CreateParagraph({ Title = "Merchant Hideo", Text = "" })
    QuestTab:CreateButton({ Name = "Exchange : A Rare Trade [Lv.1450]+", Callback = function()
        if NexusReqDone("MerchantHideo1", nil) then return end
        task.spawn(function() pcall(function() NEXUS_LV.AcceptQuest:InvokeServer("MerchantHideo1") end) end)
    end })
    NexusSGHideoPanel = QuestTab:CreateParagraph({ Title = "A Rare Trade Requirements", Text = "Loading..." })

    QuestTab:CreateParagraph({ Title = "Little Ren", Text = "" })
    PT(QuestTab, "SGRen1On", "Quest 1 : Find My Mom [Lv.1500]+", function(on)
        SGRen1On = on
        if on then task.spawn(function() NexusSafeAccept("LittleRen1") end) end
    end)
    QuestTab:CreateButton({ Name = "Exchange : A Little Trade [Lv.1500]+", Callback = function()
        if NexusReqDone("LittleRen2", nil) then return end
        task.spawn(function() pcall(function() NEXUS_LV.AcceptQuest:InvokeServer("LittleRen2") end) end)
    end })
    NexusSGRenPanel = QuestTab:CreateParagraph({ Title = "A Little Trade Requirements", Text = "Loading..." })

    QuestTab:CreateParagraph({ Title = "Satoru", Text = "" })
    QuestTab:CreateButton({ Name = "Exchange : Awaken Limitless [Lv.1500]+", Callback = function()
        if NexusReqDone("KidGojoExchange", "AwakenedLimitless") then return end
        task.spawn(function() pcall(function() NEXUS_LV.AcceptQuest:InvokeServer("KidGojoExchange") end) end)
    end })
    NexusSGGojoPanel = QuestTab:CreateParagraph({ Title = "Awaken Limitless Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)

    QuestTab:CreateSection("RCT Quest Line")
    PT(QuestTab, "RctQ1On", "Quest 1 : Emergency Treatment I [500]+", function(on)
        RctQ1On = on
        NexusDropAnchor()
        if on then task.spawn(function() NexusSafeAccept("ShokoRCT1") end) end
    end)
    PT(QuestTab, "RctQ2On", "Quest 2 : Emergency Treatment II [500]+", function(on)
        RctQ2On = on
        if on then task.spawn(function() NexusSafeAccept("ShokoRCT2") end) end
    end)
    PT(QuestTab, "RctQ3On", "Quest 3 Corrupted Technique [Lv.500]+", function(on)
        RctQ3On = on
        if on then task.spawn(function() NexusSafeAccept("ShokoRCT3") end) end
    end)

    QuestTab:CreateButton({ Name = "Exchange for RCT [1 Reversal, 1 Heavenly Frag, 1,000,000 Yen -> RCT]", Callback = function()

        if NexusReqDone("RCTExchange", "RCT") then return end
        task.spawn(function()
            pcall(function()
                local args = { "RCTExchange" }
                RepStorage:WaitForChild("NetworkComm"):WaitForChild("QuestService"):WaitForChild("AcceptQuest_Method"):InvokeServer(unpack(args))
            end)
        end)
    end })
    NexusRctPanel = QuestTab:CreateParagraph({ Title = "RCT Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)

    QuestTab:CreateSection("Infinity Trainer Quest Line")
    PT(QuestTab, "InfQ1On", "Drawn into infinity [2500]+", function(on)
        InfQ1On = on
        if on then task.spawn(function() NexusSafeAccept("GojoInf1") end) end
    end)
    PT(QuestTab, "InfQ2On", "Through the Barriers [Lv.2500]+", function(on)
        InfQ2On = on
        if not on then NexusBarrierPos = nil end
        if on then task.spawn(function() NexusSafeAccept("GojoInf2") end) end
    end)
    PT(QuestTab, "InfQ3On", "The Honored One [Lv.2500]+", function(on)
        InfQ3On = on
        if on then task.spawn(function() NexusSafeAccept("GojoInf3") end) end
    end)

    QuestTab:CreateButton({ Name = "Exchange for Infinity Aura [3 Reversal, 2 Domain Frags, 1 Limitless Extra, 10,000,000 Yen -> Infinity Aura ]", Callback = function()

        if NexusReqDone("InfinityAuraExchange", "InfinityAura") then return end
        task.spawn(function()
            pcall(function()
                local args = { "InfinityAuraExchange" }
                RepStorage:WaitForChild("NetworkComm"):WaitForChild("QuestService"):WaitForChild("AcceptQuest_Method"):InvokeServer(unpack(args))
            end)
        end)
    end })
    NexusInfPanel = QuestTab:CreateParagraph({ Title = "Infinity Aura Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)

    QuestTab:CreateSection("Lazy Sorcerer Quest Line")
    QuestTab:CreateButton({ Name = "Gate 1 [1,000 Lumens, 10,000 Yen, and 1 Iron]", Callback = function()
        NexusLazyGate("SealedGate", "Gate1")
    end })
    QuestTab:CreateButton({ Name = "Gate 2 [1,500 Lumens, 15,000 Yen, and 1 Cursed Iron]", Callback = function()
        NexusLazyGate("SealedGate2", "Gate2")
    end })
    QuestTab:CreateButton({ Name = "Gate 3 [30,000 Yen, and 1 Cursed Flesh]", Callback = function()
        NexusLazyGate("SealedGate3", "Gate3")
    end })
    QuestTab:CreateButton({ Name = "Gate 4 [100,000 Yen, and 1 Heavenly Fragment]", Callback = function()
        NexusLazyGate("SealedGate4", "Gate4")
    end })
    NexusGatePanel = QuestTab:CreateParagraph({ Title = "Lazy Sorcerer Gate Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    PT(QuestTab, "LazyFogOn", "Auto Lazy Sorcerer Quest [First, you need to finish all 4 gate quests to unlock the Lazy Sorcerer quest.]", function(on)
        LazyFogOn = on

        if on then NexusLazyEnsureWorker() end
    end)
    PT(QuestTab, "CurseRemnantOn", "Auto Kill Curse Remnant", function(on)
        CurseRemnantOn = on
        NexusDropAnchor("remnant")
    end)

    QuestTab:CreateSection("Evolution Trainer")
    QuestTab:CreateParagraph({ Title = "Auto Evolution Trainer", Text = "" })
    PT(QuestTab, "EvoQ1On", "Quest 1 - Auto Evolve [Lv.1000]+", function(on)
        EvoQ1On = on
        if on then task.spawn(function() NexusEvoAccept("Evolution1", 1) end) end
    end)
    QuestTab:CreateButton({ Name = "Quest 2 - Auto Sacrifice [Lv. 3333]+", Callback = function()
        task.spawn(function() NexusEvoAccept("Evolution2", 2) end)
    end })
    PT(QuestTab, "EvoQ3On", "Quest 3 - Auto Transcend [Lv.4500]+", function(on)
        EvoQ3On = on
        if on then task.spawn(function() NexusEvoAccept("Evolution3", 1) end) end
    end)

    QuestTab:CreateDivider()
    QuestTab:CreateParagraph({ Title = "Offense Trainer", Text = "" })
    PT(QuestTab, "OffQ1On", "Quest 1 - Strength [Lv.1500]+", function(on)
        OffQ1On = on
        if on then task.spawn(function() NexusEvoAccept("Offense1", 1) end) end
    end)
    PT(QuestTab, "OffQ2On", "Quest 2 - Stamina [Lv.2000]+", function(on)
        OffQ2On = on
        if on then task.spawn(function() NexusEvoAccept("Offense2", 1) end) end
    end)
    PT(QuestTab, "OffQ3On", "Quest 3 - Courage [Lv.3000]+", function(on)
        OffQ3On = on
        if on then task.spawn(function() NexusEvoAccept("Offense3", 1) end) end
    end)

    QuestTab:CreateDivider()
    QuestTab:CreateParagraph({ Title = "Vitality Trainer", Text = "" })
    PT(QuestTab, "VitQ1On", "Quest 1 - Vitality Shard [Lv.1500]+", function(on)
        VitQ1On = on
        if on then task.spawn(function() NexusEvoAccept("Vitality1", 1) end) end
    end)
    PT(QuestTab, "VitQ2On", "Quest 2 - Auto VitalityFragment [Lv.2000]+", function(on)
        VitQ2On = on
        if on then task.spawn(function() NexusEvoAccept("Vitality2", 1) end) end
    end)
    PT(QuestTab, "VitQ3On", "Vitality Gem [Lv.3000]+", function(on)
        VitQ3On = on
        if on then task.spawn(function() NexusEvoAccept("Vitality3", 1) end) end
    end)

    QuestTab:CreateDivider()
    QuestTab:CreateParagraph({ Title = "Auto Sorcery Trainer", Text = "" })
    QuestTab:CreateButton({ Name = "Quest 1 - Restricted [Lv.1500]+", Callback = function()
        task.spawn(function() NexusEvoAccept("Sorcery1", 1) end)
    end })
    QuestTab:CreateButton({ Name = "Quest 2 - Cursed [Lv.2000]+", Callback = function()
        task.spawn(function() NexusEvoAccept("Sorcery2", 1) end)
    end })
    QuestTab:CreateButton({ Name = "Quest 3 - Limit [Lv.3000]+", Callback = function()
        task.spawn(function() NexusEvoAccept("Sorcery3", 1) end)
    end })

    QuestTab:CreateDivider()
    NexusEvoPanel = QuestTab:CreateParagraph({ Title = "Evolution Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["Evolution Requirements"] = nil end)

    QuestTab:CreateSection("Restrictor Quest Line")

    QuestTab:CreateParagraph({ Title = "Sorcery Heavenly Restrictor NPC", Text = "" })
    NexusHRToggles["SHR1"] = PT(QuestTab, "SHRQ1On", "Train I [Lv.100]+", function(on)
        SHRQ1On = on
        if on then NexusHRDoneSeen["SHR1"] = nil task.spawn(function() NexusHRKick("SHR1") end) end
    end)
    NexusHRToggles["SHR2"] = PT(QuestTab, "SHRQ2On", "Train II [Lv.150]+", function(on)
        SHRQ2On = on
        if on then NexusHRDoneSeen["SHR2"] = nil task.spawn(function() NexusHRKick("SHR2") end) end
    end)
    NexusHRToggles["SHR3"] = PT(QuestTab, "SHRQ3On", "Train III [Lv.200]+", function(on)
        SHRQ3On = on
        if on then NexusHRDoneSeen["SHR3"] = nil task.spawn(function() NexusHRKick("SHR3") end) end
    end)

    QuestTab:CreateButton({ Name = "Exchange - Sorcery Heavenly Restriction [5 Attack Vow III, 5 Heavenly Frags, 1 SHR Binding]", Callback = function()
        NexusHRExchange(NEXUS_HR_LINES.SHR.exchanges[1])
    end })

    QuestTab:CreateDivider()
    NexusSHRPanel = QuestTab:CreateParagraph({ Title = "Sorcery Restrictor Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["Sorcery Restrictor Requirements"] = nil end)

    QuestTab:CreateDivider()
    QuestTab:CreateParagraph({ Title = "Physical Heavenly Restrictor NPC", Text = "" })
    NexusHRToggles["PHR1"] = PT(QuestTab, "PHRQ1On", "Endurance I [Lv.100]+", function(on)
        PHRQ1On = on
        if on then NexusHRDoneSeen["PHR1"] = nil task.spawn(function() NexusHRKick("PHR1") end) end
    end)
    NexusHRToggles["PHR2"] = PT(QuestTab, "PHRQ2On", "Endurance II [Lv.150]+", function(on)
        PHRQ2On = on
        if on then NexusHRDoneSeen["PHR2"] = nil task.spawn(function() NexusHRKick("PHR2") end) end
    end)
    NexusHRToggles["PHR3"] = PT(QuestTab, "PHRQ3On", "Endurance III [Lv.200]+", function(on)
        PHRQ3On = on
        if on then NexusHRDoneSeen["PHR3"] = nil task.spawn(function() NexusHRKick("PHR3") end) end
    end)
    QuestTab:CreateButton({ Name = "Exchange - Physical Heavenly Restriction [5 Attack Vow III, 5 Heavenly Frags, 1 PHR Binding]", Callback = function()
        NexusHRExchange(NEXUS_HR_LINES.PHR.exchanges[1])
    end })

    QuestTab:CreateButton({ Name = "Exchange - Inversion I [1 Physical HR, 1 Inverted Fragment]  (one-time only)", Callback = function()
        NexusHRExchange(NEXUS_HR_LINES.PHR.exchanges[2])
    end })

    QuestTab:CreateDivider()
    NexusPHRPanel = QuestTab:CreateParagraph({ Title = "Physical Restrictor Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["Physical Restrictor Requirements"] = nil end)

    QuestTab:CreateSection("Kamutoke & Raiko Pillar Quests")

    NexusKMToggles = NexusKMToggles or {}
    QuestTab:CreateParagraph({ Title = "Raiko Pillar NPCs", Text = "" })
    NexusKMToggles["Monk1"] = PT(QuestTab, "KMQ1On", "Raiko Pillar I  -  Challenge The Guardians I [Lv.500]+", function(on)
        KMQ1On = on
        if on then task.spawn(function() NexusKMKick("Monk1") end) end
    end)
    NexusKMToggles["Monk2"] = PT(QuestTab, "KMQ2On", "Raiko Pillar II  -  Challenge The Guardians II [Lv.500]+", function(on)
        KMQ2On = on
        if on then task.spawn(function() NexusKMKick("Monk2") end) end
    end)
    NexusKMToggles["Monk3"] = PT(QuestTab, "KMQ3On", "Raiko Pillar III  -  Challenge The Guardians III [Lv.500]+", function(on)
        KMQ3On = on
        if on then task.spawn(function() NexusKMKick("Monk3") end) end
    end)

    QuestTab:CreateDivider()
    NexusKMPanel = QuestTab:CreateParagraph({ Title = "Raiko Pillar Status", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["Raiko Pillar Status"] = nil end)

    QuestTab:CreateDivider()
    QuestTab:CreateParagraph({ Title = "High Monk NPC", Text = "" })
    NexusKMToggles["HighMonk1"] = PT(QuestTab, "KMHMOn", "High Monk  -  Defeat the Raiden Monk (repeatable)", function(on)
        KMHMOn = on
        if on then task.spawn(function() NexusKMKick("HighMonk1") end) end
    end)

    QuestTab:CreateDivider()
    NexusKMMonkPanel = QuestTab:CreateParagraph({ Title = "High Monk Status", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["High Monk Status"] = nil end)

    QuestTab:CreateDivider()

    QuestTab:CreateButton({ Name = "Auto Exchange Kamutoke [2 Heavenly Frag, 9 Iron, 3 Cursed Iron, 1 Thunderbolt, 1 Raiko Handle, 3 Ikazuchi Shard, 5 Kaminari Vein, 500k Yen]", Callback = function()
        NexusKMKamutoke()
    end })
    NexusKMKamuPanel = QuestTab:CreateParagraph({ Title = "Kamutoke Requirements", Text = "Loading..." })
    nexusRefreshButton(QuestTab)
    task.spawn(function() task.wait(1) NexusReqLast["Kamutoke Requirements"] = nil end)

    QuestTab:CreateSection("Currency Exchange")
    QuestTab:CreateDropdown({
        Name = "Select Convert Amount",
        Options = { "1000000", "100000", "10000" },
        CurrentOption = { "1000000" },
        MultipleOptions = false,
        Callback = function(choice)
            local picked = (type(choice) == "table" and choice[1]) or choice
            LumenConvertAmount = tonumber(picked) or 1000000
        end,
    })
    PT(QuestTab, "AutoLumenConvertOn", "Auto Convert \194\165 \226\134\146 Lumen", function(on) AutoLumenConvertOn = on end)

    ShopTab:CreateSection("CT Skin Shop")

    for _, sk in ipairs(NexusCTSkins) do
        local key, nm, price, bonus = sk[1], sk[2], sk[3], sk[4]
        ShopTab:CreateButton({
            Name = "Buy " .. nm .. "  [" .. nexusCTComma(price) .. " Cursed Dust]  " .. bonus,
            Callback = function() nexusCTBuySkin(key) end,
        })
    end

    NexusCTOpts, NexusCTLabel2Id = {}, {}
    for _, g in ipairs(NexusCTOrder) do
        for _, e in ipairs(NexusCTX) do
            if e[6] == g and e[3] then
                local lbl = NexusCTGrade[g] .. " - " .. e[2] .. " (" .. e[4] .. " \226\134\146 " .. e[5] .. " dust)"
                NexusCTOpts[#NexusCTOpts + 1] = lbl
                NexusCTLabel2Id[lbl] = e[1]
            end
        end
    end
    NexusCTAllOpt = "\226\152\133 Select All CT"
    table.insert(NexusCTOpts, 1, NexusCTAllOpt)
    ShopTab:CreateDropdown({
        Name = "Select CT Extra (multi-select, Grade 2 \226\134\146 Special Grade)",
        Options = NexusCTOpts,
        CurrentOption = { NexusCTOpts[2] },
        MultipleOptions = true,
        Callback = function(choice)
            local picks = (type(choice) == "table") and choice or { choice }
            local list, seen, all = {}, {}, false
            for i = 1, #picks do
                if picks[i] == NexusCTAllOpt then all = true end
            end
            if all then

                for _, g in ipairs(NexusCTOrder) do
                    for _, e in ipairs(NexusCTX) do
                        if e[6] == g and e[3] and not seen[e[1]] then
                            seen[e[1]] = true
                            list[#list + 1] = e[1]
                        end
                    end
                end
            else
                for i = 1, #picks do
                    local id = NexusCTLabel2Id[picks[i]]
                    if id and not seen[id] then
                        seen[id] = true
                        list[#list + 1] = id
                    end
                end
            end
            nexusCTSetPick(list)
            nexusCTReset()
        end,
    })
    if NexusCTOpts[2] then nexusCTSetPick({ NexusCTLabel2Id[NexusCTOpts[2]] }) end
    ShopTab:CreateInput({
        Name = "How many extras to convert per CT (empty / 0 = all)",
        PlaceholderText = "3",
        Callback = function(txt)
            local t = tostring(txt or ""):gsub("%s", "")
            NexusCTAmt = (t == "" or t:lower() == "all") and 0 or (tonumber(t) or 0)
            if NexusCTAmt < 0 then NexusCTAmt = 0 end
            nexusCTReset()
        end,
    })
    PT(ShopTab, "AutoCTExchangeOn", "Auto Exchange CT \226\134\146 Cursed Dust", function(on)
        AutoCTExchangeOn = on
        nexusCTReset()
    end)
    NexusCTPanel = ShopTab:CreateParagraph({ Title = "CT Skin Shop Status", Text = "Loading..." })
    nexusRefreshButton(ShopTab)
    task.spawn(function()

        while NEXUSG.NexusPlayHubSession == SESSION do
            if NexusCTDirty then
                NexusCTDirty = false
                pcall(function() NexusReqRefresh("CT Skin Shop Status", NexusCTPanel, NexusCTStatusText()) end)
            end
            task.wait(0.1)
        end
    end)

    FlyTab:CreateSection("Noclip")
    PT(FlyTab, "NoclipOn", "Noclip", function(on) NoclipOn = on end)

    FlyTab:CreateSection("Fly")

    local flyToggleObj

    local function applyFly(on)
        if on and not flying then NEXUS_LV.startFly()
        elseif (not on) and flying then NEXUS_LV.stopFly() end
    end
    flyToggleObj = FlyTab:CreateToggle({ Name = "Fly", CurrentValue = false,
        Callback = function(on) applyFly(on) end })

    local setFlyToggle = function(v)
        pcall(function() flyToggleObj:UpdateState(v) end)
        applyFly(v)
    end

    FlyTab:CreateSlider({ Name = "Fly Speed", Range = { NEXUS_LV.MIN_SPEED, NEXUS_LV.MAX_SPEED }, Increment = 1,
        CurrentValue = NEXUS_LV.SPEED, Callback = function(v) NEXUS_LV.SPEED = v end })

    FlyTab:CreateToggle({ Name = "Fly Up", CurrentValue = false,
        Callback = function(on) keys.Up = on end })
    FlyTab:CreateToggle({ Name = "Fly Down", CurrentValue = false,
        Callback = function(on) keys.Down = on end })

    CONNS[#CONNS+1] = NEXUS_LV.UserInput.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then keys.W = true
        elseif k == Enum.KeyCode.A then keys.A = true
        elseif k == Enum.KeyCode.S then keys.S = true
        elseif k == Enum.KeyCode.D then keys.D = true
        elseif k == Enum.KeyCode.Space then keys.Up = true
        elseif k == Enum.KeyCode.LeftShift then keys.Down = true
        end
    end)

    RaidTab:CreateSection("Overlord Raid")
    NexusRaidNames = { "Star Rage Raid", "Blood Raid", "Lightning God Raid", "Cursed Prodigy Raid", "Deadly Judge Raid", "Jogo Raid", "Sorcerer Killer Raid", "King of Curses Raid", "Awakened Toji Raid", "Maki Raid", "Curse Calamity Raid", "The Honored One Raid" }
    SelectedRaid = S("SelectedRaid", "Star Rage Raid")
    AutoRaidSwitchOn = false
    function nexusApplyRaid()
        NEXUS_LV.AutoRaidOn = false
        AutoBloodRaidOn = false
        AutoLightningRaidOn = false
        AutoYutaRaidOn = false
        AutoCurseCalamityOn = false
        for k in pairs(RaidCfg.active) do RaidCfg.active[k] = false end
        if not AutoRaidSwitchOn then return end
        local r = SelectedRaid
        if r == "Star Rage Raid" then NEXUS_LV.AutoRaidOn = true
        elseif r == "Blood Raid" then AutoBloodRaidOn = true
        elseif r == "Lightning God Raid" then AutoLightningRaidOn = true
        elseif r == "Cursed Prodigy Raid" then AutoYutaRaidOn = true
        elseif r == "Deadly Judge Raid" then RaidCfg.active.Judge = true
        elseif r == "Jogo Raid" then RaidCfg.active.Jogo = true
        elseif r == "Sorcerer Killer Raid" then RaidCfg.active.Toji = true
        elseif r == "King of Curses Raid" then RaidCfg.active.Sukuna = true
        elseif r == "Awakened Toji Raid" then RaidCfg.active.AToji = true
        elseif r == "Maki Raid" then RaidCfg.active.Maki = true
        elseif r == "Curse Calamity Raid" then AutoCurseCalamityOn = true
        elseif r == "The Honored One Raid" then RaidCfg.active.AGojo = true
        end
    end
    RaidTab:CreateDropdown({
        Name = "Select Raid",
        Options = NexusRaidNames,
        CurrentOption = { SelectedRaid },
        MultipleOptions = false,
        Callback = function(choice)
            SelectedRaid = (type(choice) == "table" and choice[1]) or choice
            Settings["SelectedRaid"] = SelectedRaid
            saveSettings()
            nexusApplyRaid()
        end,
    })
    PT(RaidTab, "AutoRaidSwitchOn", "Auto Raid", function(on) AutoRaidSwitchOn = on; nexusApplyRaid() end)

    local savedDiff = S("RaidDifficulty", "Calamity")
    if not RaidCfg.map[savedDiff] then savedDiff = "Calamity" end
    RaidCfg.difficulty = RaidCfg.map[savedDiff]
    RaidTab:CreateDropdown({
        Name          = "Raid Difficulty",
        Options       = { "Easy", "Normal", "Hard", "Nightmare", "Calamity" },
        CurrentOption = { savedDiff },
        MultipleOptions = false,
        Callback = function(choice)
            local picked = (type(choice) == "table" and choice[1]) or choice
            RaidCfg.difficulty = RaidCfg.map[picked] or 5
            Settings["RaidDifficulty"] = picked
            saveSettings()
        end,
    })

    PT(RaidTab, "BringRaidNpcOn", "Bring Raid NPC", function(on) BringRaidNpcOn = on end)
    RAID_BRING_RANGE = tonumber(S("RaidBringRange", RAID_BRING_RANGE)) or RAID_BRING_RANGE
    if RAID_BRING_RANGE > RAID_BRING_RANGE_MAX then RAID_BRING_RANGE = RAID_BRING_RANGE_MAX end
    if RAID_BRING_RANGE < RAID_BRING_RANGE_MIN then RAID_BRING_RANGE = RAID_BRING_RANGE_MIN end
    RaidTab:CreateSlider({ Name = "Bring Raid NPC Range", Range = { RAID_BRING_RANGE_MIN, RAID_BRING_RANGE_MAX }, Increment = 10,
        CurrentValue = RAID_BRING_RANGE, Callback = function(v)
            local nv = tonumber(v) or RAID_BRING_RANGE_MIN
            if nv > RAID_BRING_RANGE_MAX then nv = RAID_BRING_RANGE_MAX end
            if nv < RAID_BRING_RANGE_MIN then nv = RAID_BRING_RANGE_MIN end
            RAID_BRING_RANGE = nv
            Settings["RaidBringRange"] = nv
            saveSettings()
        end })

    RaidTab:CreateSection("Infinity Raid")
    PT(RaidTab, "AutoInfSukunaRaidOn", "Infinity - King of Curses", function(on) AutoInfSukunaRaidOn = on end)
    PT(RaidTab, "AutoInfTojiRaidOn", "Infinity - Sorcerer Killer", function(on) AutoInfTojiRaidOn = on end)
    PT(RaidTab, "InfRaidNotifyOn", "Infinity Raid Notification", function(on) InfRaidNotifyOn = on end)

    NexusInfRaidPanel = RaidTab:CreateParagraph({ Title = "Infinity Raid Status", Text = "Loading..." })
    nexusRefreshButton(RaidTab)
    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do
            pcall(function() NexusReqRefresh("Infinity Raid Status", NexusInfRaidPanel, NexusInfStatusText()) end)
            task.wait(nexusInfActive() and 0.2 or 1)
        end
    end)

    RaidTab:CreateSection("Outer World Raid")

    PT(RaidTab, "AutoOuterRaidOn", "Auto Awk Star Rage", function(on) AutoOuterRaidOn = on end)

    PT(RaidTab, "AutoSorcRaidOn", "Auto Sorcerer Raid", function(on) AutoSorcRaidOn = on end)

    PT(RaidTab, "AutoJogoRaidOn", "Auto Jogo Raid", function(on) AutoJogoRaidOn = on end)
    NEXUS_JOGO_REWARD_WAIT = tonumber(S("JogoRewardWait", NEXUS_JOGO_REWARD_WAIT)) or 8
    RaidTab:CreateSlider({ Name = "Jogo: Wait For Reward sec", Range = { 2, 20 }, Increment = 1,
        CurrentValue = NEXUS_JOGO_REWARD_WAIT, Callback = function(v)
            NEXUS_JOGO_REWARD_WAIT = tonumber(v) or 8
            Settings["JogoRewardWait"] = NEXUS_JOGO_REWARD_WAIT
            pcall(saveSettings)
        end })

    PT(RaidTab, "AutoBloodRaidOn", "Auto Blood Raid", function(on) AutoBloodRaidOn = on end)

    PT(RaidTab, "NexusBringRaidOn", "Bring Raid NPC", function(on)
        NexusBringRaidOn = on
        if not on then pcall(nexusRaidBringRestore) end
    end)
    NEXUS_RAID_BRING_RANGE = tonumber(S("RaidBringRange", 350)) or 350
    if NEXUS_RAID_BRING_RANGE < 50 then NEXUS_RAID_BRING_RANGE = 50 end
    if NEXUS_RAID_BRING_RANGE > 350 then NEXUS_RAID_BRING_RANGE = 350 end
    RaidTab:CreateSlider({ Name = "Bring NPC Range", Range = { 50, 350 }, Increment = 1,
        CurrentValue = NEXUS_RAID_BRING_RANGE, Callback = function(v)
            NEXUS_RAID_BRING_RANGE = tonumber(v) or 350
            Settings["RaidBringRange"] = NEXUS_RAID_BRING_RANGE
            saveSettings()
        end })

    RaidTab:CreateSection("Jujutsu Trial Tower")

    TrialSavedChamber = S("TrialChamber", "Chamber 1")
    TrialChamberOptions = {}
    for i = 1, 12 do TrialChamberOptions[i] = "Chamber " .. i end
    TrialChamber = tonumber(string.match(tostring(TrialSavedChamber), "%d+")) or 1
    if TrialChamber < 1 or TrialChamber > 12 then TrialChamber = 1 end
    TrialSavedChamber = "Chamber " .. TrialChamber
    RaidTab:CreateDropdown({
        Name          = "Trial Chamber",
        Options       = TrialChamberOptions,
        CurrentOption = { TrialSavedChamber },
        MultipleOptions = false,
        Callback = function(choice)
            local picked = (type(choice) == "table" and choice[1]) or choice
            local n = tonumber(string.match(tostring(picked), "%d+")) or 1
            if n < 1 or n > 12 then n = 1 end
            TrialChamber = n
            pcall(trialResetFind)
            Settings["TrialChamber"] = "Chamber " .. n
            saveSettings()
        end,
    })
    PT(RaidTab, "TrialOn", "Auto Trial", function(on) TrialOn = on end)

    PT(RaidTab, "TrialNextOn", "Auto Next Trial", function(on) TrialNextOn = on end)

    RollTab:CreateSection("Banner Roll")
    do
        local labels = NexusBannerLabels()
        local saved  = S("BannerPick", nil)
        local valid  = false
        for _, id in pairs(NexusBannerIdByLabel) do
            if id == saved then valid = true end
        end
        if valid then
            NexusBannerPick = saved
        elseif labels[1] then
            NexusBannerPick = NexusBannerIdByLabel[labels[1]]
        end
        nxBannerDrop = RollTab:CreateDropdown({
            Name            = "Banner",
            Options         = labels,
            CurrentOption   = { NexusBannerLabel(NexusBannerPick) },
            MultipleOptions = false,
            Callback = function(choice)
                local picked = (type(choice) == "table" and choice[1]) or choice
                NexusBannerPick = NexusBannerIdByLabel[tostring(picked)] or NexusBannerPick
                Settings["BannerPick"] = NexusBannerPick
                saveSettings()
            end,
        })
        NexusBannerSig = table.concat(NexusActiveBanners(), "|")
    end
    PT(RollTab, "NexusRoll1On",   "Roll 1",   function(on) NexusRoll1On   = on end)
    PT(RollTab, "NexusRoll10On",  "Roll 10",  function(on) NexusRoll10On  = on end)
    PT(RollTab, "NexusRoll100On", "Roll 100", function(on) NexusRoll100On = on end)
    NexusBannerPanel = RollTab:CreateParagraph({ Title = "Banner Status", Text = "Loading..." })
    nexusRefreshButton(RollTab)

    RollTab:CreateSection("Clan Roll")
    do
        local labels = NexusClanLabels()
        local saved  = S("ClanWL", nil)
        if type(saved) == "table" then NexusClanWL = saved end
        RollTab:CreateDropdown({
            Name            = "Whitelist Clans",
            Options         = labels,
            CurrentOption   = NexusClanLabelsFor(NexusClanWL),
            MultipleOptions = true,
            Callback = function(choice)
                NexusClanWL = NexusClanIds(choice)
                Settings["ClanWL"] = NexusClanWL
                saveSettings()
            end,
        })
    end
    NexusClanTgl   = PT(RollTab, "NexusClanRollOn", "Auto Clan Roll", function(on) NexusClanRollOn = on end)
    NexusClanPanel = RollTab:CreateParagraph({ Title = "Clan Roll Status", Text = "Loading..." })
    NexusShopPanel = RollTab:CreateParagraph({ Title = "Clan Roll Shop", Text = "Loading..." })
    nexusRefreshButton(RollTab)

    RollTab:CreateSection("Special Clan Roll")
    do
        local labels = NexusClanLabels()
        local saved  = S("SClanWL", nil)
        if type(saved) == "table" then NexusSClanWL = saved end
        RollTab:CreateDropdown({
            Name            = "Whitelist Clans (Special)",
            Options         = labels,
            CurrentOption   = NexusClanLabelsFor(NexusSClanWL),
            MultipleOptions = true,
            Callback = function(choice)
                NexusSClanWL = NexusClanIds(choice)
                Settings["SClanWL"] = NexusSClanWL
                saveSettings()
            end,
        })
    end
    NexusSClanTgl   = PT(RollTab, "NexusSClanRollOn", "Auto Special Clan Roll", function(on) NexusSClanRollOn = on end)
    NexusSClanPanel = RollTab:CreateParagraph({ Title = "Special Clan Roll Status", Text = "Loading..." })
    NexusSShopPanel = RollTab:CreateParagraph({ Title = "Special Clan Roll Shop", Text = "Loading..." })
    nexusRefreshButton(RollTab)

    MiscTab:CreateSection("Anti Afk")
    do

        local v = S("AntiAfkOn", true)
        AntiAfkOn = v
        MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = v, Callback = function(on)
            AntiAfkOn = on
            Settings["AntiAfkOn"] = on
            saveSettings()
        end }, "NEXUS_AntiAfkOn")
    end
    do

        local v = S("AntiTpOn", true)
        AntiTpOn = v
        MiscTab:CreateToggle({ Name = "Anti Teleport / Anti Rejoin", CurrentValue = v, Callback = function(on)
            AntiTpOn = on
            Settings["AntiTpOn"] = on
            saveSettings()
        end }, "NEXUS_AntiTpOn")
    end

    ;(function()
        local NXPlayers = NEXUS_LV.Players
        local NXRun     = RunService
        local NXRS      = RepStorage
        local NXlp      = NXPlayers.LocalPlayer
        local NXic, NXsc, NXinv, NXcc, NXbic
        pcall(function() NXic  = require(NXRS.Configs.ItemConfig) end)
        pcall(function() NXsc  = require(NXRS.Configs.StatsConfig) end)
        pcall(function() NXinv = require(NXlp.PlayerScripts.Client.Controllers.InventoryController) end)
        pcall(function() NXcc  = require(NXlp.PlayerScripts.Client.Controllers.CharacterController) end)
        pcall(function() NXbic = require(NXlp.PlayerScripts.Client.Controllers.BossIslandController) end)
        local NXuse, NXsell, NXbis
        pcall(function() NXuse  = Net.InventoryService.UseItem_Method end)
        pcall(function() NXsell = Net.InventoryService.SellItems_Method end)
        pcall(function() NXbis  = Net:FindFirstChild("BossIslandService") end)

        local function nxItems()
            local t = {}
            pcall(function()
                for _, it in pairs(NXinv.CurrentInventory.Items) do table.insert(t, it) end
            end)
            return t
        end
        local function nxCfg(it)
            if not NXic or not NXic.Items then return nil end
            return NXic.Items[tostring(it.ConfigID)]
        end
        local function nxName(it)
            local cfg = nxCfg(it)
            return tostring(it.Name or (cfg and cfg.Name) or it.ConfigID)
        end
        local function nxRar(it)
            local cfg = nxCfg(it)
            return tonumber(it.Rarity) or (cfg and tonumber(cfg.Rarity)) or 1
        end
        local function nxGrade(r)
            local g = NXsc and NXsc.Grades and NXsc.Grades[r]
            if g and g.Name then return tostring(g.Name) end
            return "Grade " .. tostring(r)
        end
        local function nxSay(msg, kind)
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = tostring(msg), Type = kind or "Info", Duration = 4 }) end)
        end
        local function nxEvent(a, b)
            local ok, e = pcall(function() return NXRun[a] end)
            if ok and e then return e end
            return NXRun[b]
        end

        MiscTab:CreateSection("Crate Opener")
        NX_CratePick   = "ALL CRATES"
        NX_CrateDelay  = 1
        NX_CrateBurst  = 10
        NX_CrateOpened = 0
        NX_CrateFail   = 0
        NX_CrateCalls  = 0
        NX_CrateOn     = false
        NX_CrateStat   = "Idle"
        NX_CrateCur    = "-"
        NX_CrateBusy   = 0
        NX_CrateOwned  = 0
        NX_CrateLootNm = {}
        NX_CratePanel  = nil
        NX_CrateTgl    = nil

        local nxCrateTok  = 0
        local nxCrateCf   = 0
        local nxCrateBase = nil
        local nxCrateLim  = nil
        pcall(function() nxCrateLim = NXic and NXic.BagSizeLimit and NXic.BagSizeLimit.Gear end)

        local function nxAmt(it)
            return tonumber(it and (it.Amount or it.Count or it.Quantity)) or 1
        end

        local function nxCrateRem()
            local f = NXRS:FindFirstChild("NetworkComm")
            if not f then return nil end
            local i = f:FindFirstChild("InventoryService")
            if not i then return nil end
            local r = i:FindFirstChild("UseItem_Method")
            if r and r:IsA("RemoteFunction") then return r end
            return nil
        end

        local function nxCrateWalk()
            local list, tot, gear, have = {}, 0, 0, {}
            for _, it in ipairs(nxItems()) do
                local a = nxAmt(it)
                if it.ConsumableType == "Crate" then
                    if a > 0 then
                        list[#list + 1] = { id = it.ID, nm = nxName(it), a = a }
                        tot = tot + a
                    end
                else
                    if it.Type == "Gear" then gear = gear + 1 end
                    local k = tostring(it.ConfigID)
                    have[k] = (have[k] or 0) + a
                    if NX_CrateLootNm[k] == nil then NX_CrateLootNm[k] = nxName(it) end
                end
            end
            table.sort(list, function(x, y) return x.a > y.a end)
            return list, tot, gear, have
        end

        local function nxCratePool()
            local list, tot, gear, have = nxCrateWalk()
            if NX_CratePick ~= "ALL CRATES" then
                local f = {}
                for _, c in ipairs(list) do
                    if c.nm == NX_CratePick then f[#f + 1] = c end
                end
                list = f
            end
            return list, tot, gear, have
        end

        local function nxCrateHalt(why)
            NX_CrateOn   = false
            NX_CrateBusy = 0
            NX_CrateStat = why or "Stopped"
            pcall(function() NexusTurnOff(NX_CrateTgl) end)
        end

        local function nxCrateFire(r, id, n)
            local ok, bad, fin = 0, 0, 0
            for _ = 1, n do
                task.spawn(function()
                    local s, v = pcall(function() return r:InvokeServer(id, 1) end)
                    if s and v then ok = ok + 1 else bad = bad + 1 end
                    fin = fin + 1
                end)
            end
            local t = 0
            while fin < n and t < 10 do t = t + task.wait(0.05) end
            return ok, bad, (fin < n)
        end

        local function nxCrateWork(my)
            while NX_CrateOn and my == nxCrateTok and NEXUSG.NexusPlayHubSession == SESSION do
                local r = nxCrateRem()
                if not r then nxCrateHalt("Remote missing \226\128\148 rejoin the game") break end

                local pool, tot, gear = nxCratePool()
                NX_CrateOwned = tot
                if nxCrateLim and gear >= nxCrateLim then
                    nxCrateHalt("Backpack full \226\128\148 sell gear") break
                end

                local c = pool[1]
                if not c then
                    if NX_CratePick == "ALL CRATES" then
                        nxCrateHalt("Finished \226\128\148 all crates opened")
                    else
                        nxCrateHalt("Finished \226\128\148 out of " .. tostring(NX_CratePick))
                    end
                    break
                end

                local n = NX_CrateBurst
                if n > c.a then n = c.a end
                if n < 1 then n = 1 end

                NX_CrateCur   = c.nm
                NX_CrateBusy  = n
                NX_CrateStat  = "Running"
                NX_CrateCalls = NX_CrateCalls + n

                local ok, bad, to = nxCrateFire(r, c.id, n)
                NX_CrateOpened = NX_CrateOpened + ok
                if bad > 0 then NX_CrateFail = NX_CrateFail + bad end

                if ok > 0 then
                    nxCrateCf = 0
                else
                    nxCrateCf = nxCrateCf + 1
                    if to then
                        NX_CrateStat = "No reply from server (" .. nxCrateCf .. "/15)"
                    else
                        NX_CrateStat = "Server refused (" .. nxCrateCf .. "/15)"
                    end
                    if nxCrateCf >= 15 then
                        nxCrateHalt("Stopped \226\128\148 server stopped replying, rejoin or raise the delay")
                        break
                    end
                end

                NX_CrateBusy = 0
                local w = NX_CrateDelay
                if ok == 0 and w < 0.5 then w = 0.5 end
                if w > 0 then task.wait(w) else task.wait() end
            end
            NX_CrateBusy = 0
        end

        local function nxCrateGo()
            local pool, tot, _, have = nxCratePool()
            NX_CrateOwned = tot
            if not pool[1] then
                nxCrateHalt("No crates in inventory")
                return
            end
            if not nxCrateRem() then
                nxCrateHalt("Remote missing \226\128\148 rejoin the game")
                return
            end
            nxCrateTok     = nxCrateTok + 1
            nxCrateCf      = 0
            NX_CrateOn     = true
            NX_CrateOpened = 0
            NX_CrateFail   = 0
            NX_CrateCalls  = 0
            nxCrateBase    = have
            NX_CrateStat   = "Starting..."
            task.spawn(nxCrateWork, nxCrateTok)
        end

        local nxCrateNames = { "ALL CRATES" }
        local function nxCrateScan()
            local seen = {}
            local list = { "ALL CRATES" }
            local cs = nxCrateWalk()
            for _, c in ipairs(cs) do
                if not seen[c.nm] then
                    seen[c.nm] = true
                    list[#list + 1] = c.nm
                end
            end
            nxCrateNames = list
            return list
        end
        nxCrateScan()

        local nxCrateDrop = MiscTab:CreateDropdown({
            Name = "Select Crate",
            Options = nxCrateNames,
            CurrentOption = { "ALL CRATES" },
            Callback = function(v)
                if type(v) == "table" then v = v[1] end
                NX_CratePick = tostring(v or "ALL CRATES")
            end,
        })
        MiscTab:CreateButton({ Name = "Refresh Crate List", Callback = function()
            local l = nxCrateScan()
            pcall(function() nxCrateDrop:SetOptions(l) end)
            nxSay("Crate list refreshed (" .. tostring(#l - 1) .. " types)", "Success")
        end })
        MiscTab:CreateInput({
            Name = "Crate Delay (sec)",
            CurrentValue = "1",
            PlaceholderText = "1",
            Callback = function(txt)
                local n = tonumber(txt)
                if n and n >= 0 and n <= 600 then
                    NX_CrateDelay = n
                    nxSay("Crate delay set to " .. tostring(n) .. "s", "Success")
                else
                    nxSay("Type a number between 0 and 600", "Error")
                end
            end,
        })
        MiscTab:CreateInput({
            Name = "Crates Per Burst",
            CurrentValue = "10",
            PlaceholderText = "10",
            Callback = function(txt)
                local n = tonumber(txt)
                if n and n >= 1 and n <= 100 then
                    NX_CrateBurst = math.floor(n)
                    nxSay("Opening x" .. tostring(NX_CrateBurst) .. " per burst", "Success")
                else
                    nxSay("Type a number between 1 and 100", "Error")
                end
            end,
        })
        NX_CrateTgl = PT(MiscTab, "NX_CrateOn", "Auto Open Crate", function(on)
            if on then
                if not NX_CrateOn then nxCrateGo() end
            else
                if NX_CrateOn then nxCrateHalt("Stopped by user") else NX_CrateOn = false end
            end
        end)
        NX_CratePanel = MiscTab:CreateParagraph({ Title = "Crate Status", Text = "Loading..." })
        nexusRefreshButton(MiscTab)

        local function nxCom(n)
            local ok, s = pcall(function() return NexusComma(n) end)
            if ok and s then return tostring(s) end
            return tostring(n)
        end

        local function nxCrateText(tot, have)
            local L = {}
            L[#L + 1] = "Status   : " .. tostring(NX_CrateStat)
            L[#L + 1] = "Crate    : " .. tostring(NX_CrateCur)
            L[#L + 1] = "Opening  : " .. tostring(NX_CrateBusy) .. " now  (burst " .. tostring(NX_CrateBurst) .. ")"
            L[#L + 1] = "Owned    : " .. nxCom(tot)
            L[#L + 1] = "Opened   : " .. nxCom(NX_CrateOpened) .. "   failed " .. tostring(NX_CrateFail)
            local goal = NX_CrateOpened + tot
            local pct  = 0
            if goal > 0 then pct = math.floor((NX_CrateOpened / goal) * 100) end
            L[#L + 1] = "Progress : " .. nxCom(NX_CrateOpened) .. " / " .. nxCom(goal) .. "  (" .. tostring(pct) .. "%)"
            L[#L + 1] = "\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128"
            L[#L + 1] = "Items obtained"
            local rows = {}
            if nxCrateBase then
                for k, v in pairs(have) do
                    local d = v - (nxCrateBase[k] or 0)
                    if d > 0 then rows[#rows + 1] = { nm = NX_CrateLootNm[k] or k, d = d } end
                end
            end
            table.sort(rows, function(a, b) return a.d > b.d end)
            if #rows == 0 then
                L[#L + 1] = "  nothing yet"
            else
                for i = 1, math.min(#rows, 12) do
                    L[#L + 1] = "  \226\128\162 " .. tostring(rows[i].nm) .. " = " .. nxCom(rows[i].d)
                end
                if #rows > 12 then L[#L + 1] = "  +" .. tostring(#rows - 12) .. " more" end
            end
            return table.concat(L, "\n")
        end

        task.spawn(function()
            task.wait(2)
            while NEXUSG.NexusPlayHubSession == SESSION do

                if NexusUiPass("crate", NexusCrateCh) then
                    local c0 = NexusReqChanges
                    pcall(function()
                        if NX_CratePanel then
                            local _, tot, _, have = nxCrateWalk()
                            NX_CrateOwned = tot
                            NexusReqRefresh("Crate Status", NX_CratePanel, nxCrateText(tot, have))
                        end
                    end)
                    NexusCrateCh = (NexusReqChanges ~= c0)
                end
                task.wait(0.5)
            end
        end)

        MiscTab:CreateSection("Auto Sell")
        NX_SellOn      = false
        NX_SellConfirm = false
        NX_SellRar     = {}
        NX_SellWL      = {}
        NX_Sold        = 0
        local nxGradeNames, nxGradeByName = {}, {}
        for i = 1, 8 do
            local nm = nxGrade(i)
            table.insert(nxGradeNames, nm)
            nxGradeByName[nm] = i
        end
        local nxSellLabel = MiscTab:CreateLabel("Pick a rarity to start")
        MiscTab:CreateDropdown({
            Name = "Sell Rarity",
            Options = nxGradeNames,
            CurrentOption = {},
            MultipleOptions = true,
            Callback = function(v)
                local picked = {}
                if type(v) == "table" then
                    for _, x in ipairs(v) do picked[tostring(x)] = true end
                elseif type(v) == "string" then
                    picked[v] = true
                end
                local newRar, blocked = {}, {}
                for nm in pairs(picked) do
                    local r = nxGradeByName[nm]
                    if r then
                        if r >= 5 and not NX_SellConfirm then
                            table.insert(blocked, nm)
                        else
                            newRar[r] = true
                        end
                    end
                end
                NX_SellRar = newRar
                if #blocked > 0 then
                    nxSay("Are you sure you want to select " .. table.concat(blocked, ", ") .. "? That is a high rarity. Turn ON 'Confirm High Rarity' then pick it again -- skipped for now.", "Warning")
                end
                local on = {}
                for r in pairs(NX_SellRar) do table.insert(on, nxGrade(r)) end
                table.sort(on)
                pcall(function()
                    if #on == 0 then
                        nxSellLabel:Set("Pick a rarity to start")
                    else
                        nxSellLabel:Set("Selling: " .. table.concat(on, ", "))
                    end
                end)
            end,
        })
        PT(MiscTab, "NX_SellConfirm", "Confirm High Rarity (Special Grade and up)", function(on) NX_SellConfirm = on end)
        local function nxGearNames()
            local seen, list = {}, {}
            for _, it in ipairs(nxItems()) do
                if it.Type == "Gear" then
                    local nm = nxName(it)
                    if not seen[nm] then
                        seen[nm] = true
                        table.insert(list, nm)
                    end
                end
            end
            table.sort(list)
            return list
        end
        local nxWlDrop = MiscTab:CreateDropdown({
            Name = "Whitelist (never sell)",
            Options = nxGearNames(),
            CurrentOption = {},
            MultipleOptions = true,
            Callback = function(v)
                NX_SellWL = {}
                local c = 0
                if type(v) == "table" then
                    for _, x in ipairs(v) do
                        NX_SellWL[tostring(x)] = true
                        c = c + 1
                    end
                elseif type(v) == "string" then
                    NX_SellWL[v] = true
                    c = 1
                end
                nxSay("Whitelist: " .. c .. " item name(s) kept", "Success")
            end,
        })
        MiscTab:CreateButton({ Name = "Refresh Gear List", Callback = function()
            local l = nxGearNames()
            pcall(function() nxWlDrop:SetOptions(l) end)
            nxSay("Gear list refreshed (" .. #l .. " names)", "Success")
        end })
        PT(MiscTab, "NX_SellOn", "Auto Sell", function(on) NX_SellOn = on end)
        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION do
                local any = false
                for _ in pairs(NX_SellRar) do
                    any = true
                    break
                end
                if NX_SellOn and any and NXsell then
                    local ids = {}
                    for _, it in ipairs(nxItems()) do
                        if it.Type == "Gear" and not it.Equipped and not it.Locked then
                            if NX_SellRar[nxRar(it)] and not NX_SellWL[nxName(it)] then
                                table.insert(ids, it.ID)
                            end
                        end
                    end
                    if #ids == 0 then
                        pcall(function() nxSellLabel:Set("Sold " .. NX_Sold .. " -- nothing to sell now") end)
                        task.wait(2)
                    else
                        while #ids > 0 and NX_SellOn do
                            local chunk = {}
                            for _ = 1, 40 do
                                if #ids == 0 then break end
                                table.insert(chunk, table.remove(ids))
                            end
                            local ok = pcall(function() return NXsell:InvokeServer(chunk) end)
                            if ok then NX_Sold = NX_Sold + #chunk end
                            pcall(function() nxSellLabel:Set("Sold " .. NX_Sold .. " items") end)
                            task.wait(0.35)
                        end
                    end
                else
                    if NX_SellOn and not any then
                        pcall(function() nxSellLabel:Set("Pick a rarity to start") end)
                    end
                    task.wait(1)
                end
            end
        end)

    end)()

    ;(function()
        MiscTab:CreateSection("Stats Points")

        local NXSP_PATHS = { "Offense", "Vitality", "Sorcery" }

        local function nxspReq(inst)
            if not inst then return nil end
            local ok, res = pcall(require, inst)
            if ok then return res end
            return nil
        end

        local nxspTreeCfg, nxspNpcCfg, nxspData, nxspInv, nxspNet
        pcall(function()
            local RS = RepStorage
            local cf = RS:FindFirstChild("Configs")
            if cf then
                nxspTreeCfg = nxspReq(cf:FindFirstChild("StatTreeConfig"))
                nxspNpcCfg  = nxspReq(cf:FindFirstChild("NPCConfig"))
            end
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local cl = ps and ps:FindFirstChild("Client")
            local ct = cl and cl:FindFirstChild("Controllers")
            if ct then
                nxspData = nxspReq(ct:FindFirstChild("PlayerDataController"))
                nxspInv  = nxspReq(ct:FindFirstChild("InventoryController"))
                nxspNet  = nxspReq(ct:FindFirstChild("NetworkController"))
            end
        end)

        local function nxspMethod(service, name)
            if not nxspNet then return nil end
            local ok, rm = pcall(function() return nxspNet.GetRemoteMethod(service, name) end)
            if ok then return rm end
            return nil
        end
        local nxspUnlockR = nxspMethod("StatTreeService", "UnlockNode")
        local nxspFocusR  = nxspMethod("StatTreeService", "FocusPath")
        local nxspFocusNPC = nxspNpcCfg and nxspNpcCfg.StaticNPCs and nxspNpcCfg.StaticNPCs.FocusPath

        local function nxspSupply(id)
            local inv = nxspInv and nxspInv.CurrentInventory
            if not inv then return 0 end
            local ok, supply = pcall(function() return inv:GetSupply(id) end)
            if not ok or type(supply) ~= "table" or not supply.Count then return 0 end
            return supply.Count
        end
        local function nxspPoints() return nxspSupply("StatPoints") end
        local function nxspYen()    return nxspSupply("Yen") end

        local function nxspFocusCost()
            local items = nxspFocusNPC and nxspFocusNPC.FocusRequirements and nxspFocusNPC.FocusRequirements.Items
            if not items then return nil end
            for _, req in ipairs(items) do
                if req[1] == "Yen" then return req[2] end
            end
            return nil
        end

        local function nxspComma(n)
            local s = tostring(math.floor(tonumber(n) or 0))
            local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
            return (out:gsub("^,", ""))
        end

        local function nxspLevels(treeId)
            local data = nxspData and nxspData.PlayerData
            if not data or not data.StatTrees then return {} end
            return data.StatTrees[treeId] or {}
        end

        local function nxspFocused()
            local data = nxspData and nxspData.PlayerData
            local f = data and data.FocusedStatTree
            if f == nil or f == "" then return nil end
            return f
        end

        local function nxspMaxLevel(node) return node.Levels or 1 end

        local function nxspIsPointNode(treeId, node)
            if not node.StatPointCost then return false end
            if node.Type == 1 or node.Type == 2 then return true end
            if node.Type == 3 then return nxspFocused() == treeId end
            return false
        end

        local function nxspParentId(entry)
            if type(entry) == "table" then return entry.ID end
            return entry
        end

        local function nxspReachable(node, levels)
            if not node.LastNodes or #node.LastNodes == 0 then return true end
            for _, entry in ipairs(node.LastNodes) do
                local id = nxspParentId(entry)
                if id and (levels[id] or 0) > 0 then return true end
            end
            return false
        end

        local function nxspProgress(treeId)
            local tree = nxspTreeCfg and nxspTreeCfg.Trees and nxspTreeCfg.Trees[treeId]
            if not tree then return 0, 0 end
            local levels = nxspLevels(treeId)
            local owned, total = 0, 0
            for _, node in pairs(tree.Nodes) do
                if node.Type ~= 3 and node.StatPointCost then
                    local cap = nxspMaxLevel(node)
                    total = total + cap
                    owned = owned + math.min(levels[node.ID] or 0, cap)
                end
            end
            return owned, total
        end

        local function nxspPickNode(treeId, points)
            local tree = nxspTreeCfg and nxspTreeCfg.Trees and nxspTreeCfg.Trees[treeId]
            if not tree then return nil end
            local levels = nxspLevels(treeId)
            local best
            for _, node in pairs(tree.Nodes) do
                if nxspIsPointNode(treeId, node)
                    and (levels[node.ID] or 0) < nxspMaxLevel(node)
                    and node.StatPointCost <= points
                    and nxspReachable(node, levels)
                then
                    if (not best)
                        or node.StatPointCost < best.StatPointCost
                        or (node.StatPointCost == best.StatPointCost and node.ID < best.ID) then
                        best = node
                    end
                end
            end
            return best
        end

        local function nxspInvoke(method, ...)
            if not method then return false end
            local args = table.pack(...)
            local ok, result = pcall(function()
                local promise = method:Call(table.unpack(args, 1, args.n))
                if type(promise) == "table" and promise.await then
                    local success, value = promise:await()
                    if not success then return false end
                    if value == nil then return true end
                    return value
                end
                return promise
            end)
            if ok then return result ~= false end
            local ok2, result2 = pcall(function()
                return method.RemoteFunction:InvokeServer(table.unpack(args, 1, args.n))
            end)
            if ok2 then return result2 ~= false end
            return false
        end

        local function nxspUnlock(treeId, nodeId) return nxspInvoke(nxspUnlockR, treeId, nodeId) end
        local function nxspFocus(pathId)          return nxspInvoke(nxspFocusR, pathId) end

        NXSP_AutoOn  = false
        NXSP_Path    = S("NXSP_Path", nil) or nxspFocused() or "Offense"
        local nxspFocusPick = S("NXSP_FocusPath", nil) or nxspFocused() or "Offense"
        local nxspFocusBusy, nxspFocusPending = false, nil
        local nxspStatus = "Idle. Pick a path, then turn the switch on."

        local nxspInfo  = MiscTab:CreateLabel("Stat Points: --   |   Focused: --")
        local nxspPanel = MiscTab:CreateLabel(nxspStatus)
        nexusRefreshButton(MiscTab)

        local function nxspSetStatus(text)
            nxspStatus = text
            pcall(function() nxspPanel:Set(text) end)
        end

        local function nxspRefresh()
            local focused = nxspFocused() or "none"
            local owned, total = nxspProgress(NXSP_Path)
            pcall(function()
                nxspInfo:Set("Stat Points: " .. tostring(nxspPoints())
                    .. "   |   Focused: " .. focused
                    .. "   |   " .. NXSP_Path .. ": " .. owned .. "/" .. total
                    .. "   |   Yen: " .. nxspComma(nxspYen()))
            end)
        end

        MiscTab:CreateDropdown({
            Name            = "Stat Point Path",
            Options         = NXSP_PATHS,
            CurrentOption   = { NXSP_Path },
            MultipleOptions = false,
            Callback = function(choice)
                local picked = (type(choice) == "table" and choice[1]) or choice
                NXSP_Path = tostring(picked)
                Settings["NXSP_Path"] = NXSP_Path
                saveSettings()
                nxspSetStatus("Points go to: " .. NXSP_Path .. " -- flip the switch below")
                nxspRefresh()
            end,
        })

        PT(MiscTab, "NXSP_AutoOn", "Auto Add Point", function(on) NXSP_AutoOn = on end)

        MiscTab:CreateDropdown({
            Name            = "Focus Path",
            Options         = NXSP_PATHS,
            CurrentOption   = { nxspFocusPick },
            MultipleOptions = false,
            Callback = function(choice)
                local picked = (type(choice) == "table" and choice[1]) or choice
                nxspFocusPick = tostring(picked)
                nxspFocusPending = nil
                Settings["NXSP_FocusPath"] = nxspFocusPick
                saveSettings()
            end,
        })

        MiscTab:CreateButton({ Name = "Apply Focus Path", Callback = function()
            if nxspFocusBusy then return end
            local pathId = nxspFocusPick
            if nxspFocused() == pathId then
                nxspSetStatus(pathId .. " is already your focused path")
                return
            end
            local need = nxspFocusCost()
            if need and nxspYen() < need then
                nxspSetStatus("Not enough Yen -- you need " .. nxspComma(need))
                return
            end
            if nxspFocusPending ~= pathId then
                nxspFocusPending = pathId
                nxspSetStatus("Press Apply Focus Path again to confirm " .. pathId
                    .. (need and (" (" .. nxspComma(need) .. " Yen)") or ""))
                task.delay(4, function()
                    if nxspFocusPending == pathId then
                        nxspFocusPending = nil
                        nxspSetStatus("Focus change cancelled -- press twice to confirm")
                    end
                end)
                return
            end
            nxspFocusPending = nil
            nxspFocusBusy = true
            nxspSetStatus("Focusing " .. pathId .. "...")
            task.spawn(function()
                nxspFocus(pathId)
                local done = false
                for _ = 1, 20 do
                    task.wait(0.15)
                    if nxspFocused() == pathId then done = true break end
                end
                nxspFocusBusy = false
                if done then
                    nxspSetStatus("Focused Path is now " .. pathId)
                else
                    nxspSetStatus("Server refused the focus change (Yen / requirement)")
                end
                nxspRefresh()
            end)
        end })

        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION do
                if NXSP_AutoOn then
                    local tree = NXSP_Path
                    if not (nxspTreeCfg and nxspUnlockR) then
                        nxspSetStatus("Stat tree remote not ready -- rejoin")
                        task.wait(2)
                    else
                        local points = nxspPoints()
                        local node = nxspPickNode(tree, points)
                        if not node then
                            if points <= 0 then
                                nxspSetStatus("Waiting for stat points... (" .. tree .. ")")
                            else
                                nxspSetStatus("Nothing left to buy in " .. tree .. " -- " .. points .. " points saved.")
                            end
                            task.wait(1.5)
                        else
                            if nxspUnlock(tree, node.ID) then
                                nxspSetStatus(("+ %s (%s) cost %d  |  %d points left"):format(
                                    tostring(node.Name or node.ID), tostring(node.ID),
                                    node.StatPointCost, math.max(points - node.StatPointCost, 0)))
                                task.wait(0.25)
                            else
                                nxspSetStatus("Server declined " .. tostring(node.Name or node.ID) .. " -- retrying...")
                                task.wait(1.2)
                            end
                            nxspRefresh()
                        end
                    end
                else
                    task.wait(NEXUS_IDLE)
                end
            end
        end)

        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION do
                pcall(nxspRefresh)
                task.wait(1.5)
            end
        end)

        pcall(function()
            local sig = RepStorage:FindFirstChild("NetworkComm")
            sig = sig and sig:FindFirstChild("StatTreeService")
            sig = sig and sig:FindFirstChild("StatTreeChanged_Signal")
            if sig and sig:IsA("RemoteEvent") then
                table.insert(CONNS, sig.OnClientEvent:Connect(function() pcall(nxspRefresh) end))
            end
        end)

        nxspRefresh()
    end)()

    NexusSetSmooth(true)
    Settings["UltraSmoothOn"] = true

    BossTab:CreateSection("Teleport")
    ELEVATOR_POS = Vector3.new(-750.55, -1585.64, 36055.8)
    BossTab:CreateButton({ Name = "Tp to Elevator", Callback = function()
        NexusQ(pcall, nexusTpTo, ELEVATOR_POS)
    end })

    do

    (function()
        NXTP = { entries = {}, byLabel = {}, pick = nil, search = "", all = false, running = false }

        local nxtpPts, nxtpZoneCfg
        pcall(function()
            local cfg = require(RepStorage.Configs.MapConfig)
            nxtpZoneCfg = cfg.ZoneConfig
            nxtpPts     = cfg.TeleportPoints.TeleportPoints
        end)

        local function nxtpReq(inst)
            if not inst then return nil end
            local ok, res = pcall(require, inst)
            if ok then return res end
            return nil
        end

        local nxtpMapCtrl, nxtpNetCtrl, nxtpDataCtrl, nxtpCharCtrl
        pcall(function()
            local plr    = LocalPlayer
            local ps     = plr:WaitForChild("PlayerScripts", 10)
            local client = ps and ps:WaitForChild("Client", 10)
            local ctrls  = client and client:FindFirstChild("Controllers")
            if not ctrls then return end
            nxtpMapCtrl  = nxtpReq(ctrls:FindFirstChild("MapController"))
            nxtpNetCtrl  = nxtpReq(ctrls:FindFirstChild("NetworkController"))
            nxtpDataCtrl = nxtpReq(ctrls:FindFirstChild("PlayerDataController"))
            nxtpCharCtrl = nxtpReq(ctrls:FindFirstChild("CharacterController"))
        end)

        local function nxtpMethod(service, name)
            if not nxtpNetCtrl then return nil end
            local ok, rm = pcall(function() return nxtpNetCtrl.GetRemoteMethod(service, name) end)
            if ok then return rm end
            return nil
        end
        local nxtpUseR    = nxtpMethod("MapService", "UseTeleportPoint")
        local nxtpUnlockR = nxtpMethod("MapService", "UnlockTeleportPoint")

        local function nxtpRoot()
            local r
            pcall(function()
                local m = getModel()
                r = m and m:FindFirstChild("HumanoidRootPart")
            end)
            if r then return r end
            pcall(function()
                local lc = nxtpCharCtrl and nxtpCharCtrl.LocalCharacter
                if lc and lc.ServerModel then r = lc.ServerModel.PrimaryPart end
            end)
            return r
        end
        local function nxtpPos()
            local r = nxtpRoot()
            return r and r.Position or nil
        end
        local function nxtpMove(pos)
            if not pos then return false end
            local moved = false
            pcall(function() moved = nexusTpTo(pos) and true or false end)
            if moved then return true end
            local r = nxtpRoot()
            if r and pcall(function() r.CFrame = CFrame.new(pos) end) then return true end
            if nxtpMapCtrl and pcall(function() nxtpMapCtrl:TeleportToPosition(pos) end) then return true end
            return false
        end

        local function nxtpZoneAt(pos)
            local folder = workspace:FindFirstChild("Map")
            folder = folder and folder:FindFirstChild("Zones")
            if not folder or not pos then return nil end
            local found
            pcall(function()
                for _, z in ipairs(folder:GetDescendants()) do
                    local cf, size
                    if z:IsA("BasePart") then
                        cf, size = z.CFrame, z.Size
                    elseif z:IsA("Model") then
                        local ok, a, b = pcall(function() return z:GetBoundingBox() end)
                        if ok then cf, size = a, b end
                    end
                    if cf and size then
                        local rel = cf:PointToObjectSpace(pos)
                        if math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2 then
                            local cfg = nxtpZoneCfg and nxtpZoneCfg.Zones and nxtpZoneCfg.Zones[z.Name]
                            found = (cfg and cfg.Name) or z.Name
                            return
                        end
                    end
                end
            end)
            return found
        end

        local function nxtpIsUnlocked(id)
            if nxtpMapCtrl then
                local ok, res = pcall(function() return nxtpMapCtrl:IsTeleportPointUnlocked(id) end)
                if ok then return res and true or false end
            end
            if nxtpDataCtrl and nxtpDataCtrl.PlayerData then
                local d = nxtpDataCtrl.PlayerData.TeleportPoints
                return (d and d[id] and d[id].Unlocked) and true or false
            end
            return false
        end

        local function nxtpCallUnlock(id)
            if not nxtpUnlockR then return false end
            local ok, res = pcall(function() return nxtpUnlockR:Call(id):await() end)
            return (ok and res) and true or false
        end

        local function nxtpDoTeleport(id)
            if nxtpMapCtrl and nxtpIsUnlocked(id) then
                if pcall(function() nxtpMapCtrl:TeleportToPoint(id) end) then return true, "MapController" end
            end
            if nxtpUseR then
                if pcall(function() nxtpUseR:Call(id) end) then return true, "Remote" end
            end
            local data = nxtpPts and nxtpPts[id]
            if data and data.TPCFrame and nxtpMove(data.TPCFrame.Position + Vector3.new(0, 4, 0)) then
                return true, "CFrame"
            end
            return false, "failed"
        end

        local function nxtpUnlockNear(e)
            if nxtpIsUnlocked(e.id) then return true, "already" end
            local data   = nxtpPts and nxtpPts[e.id]
            local prompt = data and data.Interactor
            local target = e.pos + Vector3.new(0, 5, 0)
            if typeof(prompt) == "Instance" and prompt.Parent and prompt.Parent:IsA("BasePart") then
                target = prompt.Parent.Position + Vector3.new(0, 5, 0)
            end
            if not nxtpMove(target) then return false, "no character" end
            local t0 = os.clock()
            while os.clock() - t0 < 5 do
                task.wait(0.25)
                local p = nxtpPos()
                if p and (p - target).Magnitude <= 20 then break end
                nxtpMove(target)
            end
            if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
                pcall(function() prompt.Enabled = true end)
                pcall(function() fireproximityprompt(prompt) end)
                task.wait(0.4)
                if nxtpIsUnlocked(e.id) then return true, "prompt" end
            end
            for _ = 1, 3 do
                nxtpMove(target)
                task.wait(0.3)
                if nxtpCallUnlock(e.id) or nxtpIsUnlocked(e.id) then return true, "remote" end
                task.wait(0.5)
            end
            return nxtpIsUnlocked(e.id), "rejected"
        end

        local function nxtpBuild()
            local out = {}
            if type(nxtpPts) == "table" then
                for id, data in pairs(nxtpPts) do
                    local sid   = tostring(id)
                    local pos   = (data and data.TPCFrame and data.TPCFrame.Position) or Vector3.zero
                    local name  = tostring((data and data.Name) or sid)
                    local zone  = nxtpZoneAt(pos)
                    local place = name
                    if name == sid then place = zone or "Unknown Area" end
                    local tp = (sid:match("^TP%d+$") and sid) or (sid:gsub("BossIslands_", "Raid: "))
                    table.insert(out, {
                        id   = id,
                        tp   = tp,
                        place = place,
                        zone = zone or "-",
                        pos  = pos,
                        raid = sid:find("BossIslands") ~= nil,
                        text = (tp .. " " .. place .. " " .. (zone or "")):lower(),
                    })
                end
            end
            table.sort(out, function(a, b)
                if a.raid ~= b.raid then return not a.raid end
                local na = tonumber(tostring(a.id):match("%d+"))
                local nb = tonumber(tostring(b.id):match("%d+"))
                if na and nb and not a.raid then return na < nb end
                return a.place:lower() < b.place:lower()
            end)
            NXTP.entries = out
            return out
        end
        nxtpBuild()

        local nxtpDrop, nxtpCount, nxtpInfo, nxtpStatus

        local function nxtpSay(txt)
            if nxtpStatus then pcall(function() nxtpStatus:Set(tostring(txt)) end) end
        end

        local function nxtpOptionLabel(e)
            return string.format("%s  ->  %s  [%s]", e.tp, e.place, nxtpIsUnlocked(e.id) and "UNLOCKED" or "LOCKED")
        end

        local function nxtpOptions()
            local q = tostring(NXTP.search or ""):lower()
            local opts = {}
            NXTP.byLabel = {}
            for _, e in ipairs(NXTP.entries) do
                if q == "" or (e.text:find(q, 1, true) ~= nil) then
                    local lab = nxtpOptionLabel(e)
                    table.insert(opts, lab)
                    NXTP.byLabel[lab] = e
                end
            end
            if #opts == 0 then table.insert(opts, "no match") end
            return opts
        end

        local function nxtpPicked()
            if not NXTP.pick then return nil end
            for _, e in ipairs(NXTP.entries) do
                if e.id == NXTP.pick then return e end
            end
            return nil
        end

        local function nxtpRefreshUI()
            local opts = nxtpOptions()
            if nxtpDrop then pcall(function() nxtpDrop:Refresh(opts) end) end
            local e = nxtpPicked()
            if e and nxtpDrop then
                local lab = nxtpOptionLabel(e)
                if NXTP.byLabel[lab] then pcall(function() nxtpDrop:Set(lab) end) end
            end
            if nxtpCount then
                local unlocked = 0
                for _, en in ipairs(NXTP.entries) do
                    if nxtpIsUnlocked(en.id) then unlocked = unlocked + 1 end
                end
                local shown = (opts[1] == "no match") and 0 or #opts
                pcall(function()
                    nxtpCount:Set(string.format("%d pts shown  |  %d / %d unlocked", shown, unlocked, #NXTP.entries))
                end)
            end
            if nxtpInfo then
                local txt = "Pick a teleport point"
                if e then
                    txt = string.format("%s  |  %s  |  %d, %d, %d  |  %s",
                        e.tp, e.zone, e.pos.X, e.pos.Y, e.pos.Z,
                        nxtpIsUnlocked(e.id) and "UNLOCKED" or "LOCKED")
                end
                pcall(function() nxtpInfo:Set(txt) end)
            end
        end

        nxtpInfo = BossTab:CreateLabel("Pick a teleport point")

        BossTab:CreateInput({
            Name = "Search Teleporter",
            PlaceholderText = "teleporter / place / zone...",
            CurrentValue = "",
            Callback = function(text)
                NXTP.search = tostring(text or "")
                nxtpRefreshUI()
            end,
        })

        nxtpDrop = BossTab:CreateDropdown({
            Name = "Teleport Point",
            Options = nxtpOptions(),
            CurrentOption = { (nxtpOptions())[1] },
            Callback = function(choice)
                local lab = choice
                if type(choice) == "table" then lab = choice[1] end
                local e = NXTP.byLabel[tostring(lab)]
                NXTP.pick = e and e.id or nil
                nxtpRefreshUI()
            end,
        })

        nxtpCount = BossTab:CreateLabel("0 pts shown")

        BossTab:CreateButton({ Name = "Tp to Teleport Point", Callback = function()
            task.spawn(function()
                local e = nxtpPicked()
                if not e then nxtpSay("No teleport point selected") return end
                if not nxtpIsUnlocked(e.id) then
                    nxtpSay("Locked -- unlocking " .. e.place .. " first...")
                    local ok = nxtpUnlockNear(e)
                    nxtpRefreshUI()
                    if not ok then nxtpSay("Server refused unlock for " .. e.place) return end
                end
                nxtpSay("Teleporting to " .. e.place .. " (" .. e.tp .. ")...")
                local ok, how = nxtpDoTeleport(e.id)
                nxtpSay(ok and ("Teleported to " .. e.place .. "  [" .. how .. "]") or ("Failed: " .. e.place))
                nxtpRefreshUI()
            end)
        end })

        BossTab:CreateButton({ Name = "Unlock Selected Point", Callback = function()
            task.spawn(function()
                local e = nxtpPicked()
                if not e then nxtpSay("No teleport point selected") return end
                local back = nxtpPos()
                nxtpSay("Going to " .. e.tp .. " (" .. e.place .. ")...")
                local ok, how = nxtpUnlockNear(e)
                if back then nxtpMove(back) end
                nxtpRefreshUI()
                nxtpSay(string.format("%s %s (%s)", e.tp, ok and "unlocked" or "refused", tostring(how)))
            end)
        end })

        BossTab:CreateButton({ Name = "Refresh Teleport Points", Callback = function()
            task.spawn(function()
                nxtpBuild()
                nxtpRefreshUI()
                nxtpSay("Refreshed -- " .. #NXTP.entries .. " points")
            end)
        end })

        local function nxtpRunUnlockAll()
            if NXTP.running then return end
            NXTP.running = true
            task.spawn(function()
                while NXTP.all and NEXUSG.NexusPlayHubSession == SESSION do
                    if not nxtpRoot() then
                        nxtpSay("on -- waiting for your character to load...")
                        task.wait(2)
                    else
                        local startPos = nxtpPos()
                        local locked = {}
                        for _, e in ipairs(NXTP.entries) do
                            if not nxtpIsUnlocked(e.id) then table.insert(locked, e) end
                        end
                        if #locked == 0 then
                            nxtpSay("on -- all " .. #NXTP.entries .. " points unlocked")
                            task.wait(5)
                        else
                            local done, failed = 0, 0
                            for idx, e in ipairs(locked) do
                                if not NXTP.all then break end
                                nxtpSay(string.format("on -- [%d/%d] going to %s (%s)...", idx, #locked, e.tp, e.place))
                                local ok, how = nxtpUnlockNear(e)
                                if ok then done = done + 1 else failed = failed + 1 end
                                nxtpSay(string.format("%s %s (%s)", e.tp, ok and "unlocked" or "refused", tostring(how)))
                                nxtpRefreshUI()
                                task.wait(0.4)
                            end
                            if startPos then nxtpMove(startPos) end
                            nxtpRefreshUI()
                            nxtpSay(string.format("on -- unlocked %d, refused %d", done, failed))
                            task.wait(6)
                        end
                    end
                end
                NXTP.running = false
            end)
        end

        BossTab:CreateToggle({ Name = "Unlock All Teleporters", CurrentValue = false, Callback = function(on)
            NXTP.all = on and true or false
            if NXTP.all then
                if not nxtpUnlockR then
                    nxtpSay("on -- unlock remote unavailable")
                    return
                end
                nxtpSay("on -- starting (walks you to each locked pillar)")
                nxtpRunUnlockAll()
            else
                nxtpSay("off -- unlock all stopped")
            end
        end })

        nxtpStatus = BossTab:CreateLabel("Ready -- pick a teleporter and press Tp")

        task.spawn(function()
            while NEXUSG.NexusPlayHubSession == SESSION do
                task.wait(3)
                pcall(nxtpRefreshUI)
            end
        end)

        nxtpRefreshUI()
    end)()
    end

    BossTab:CreateSection("Boss Farm")
    BossTab:CreateDropdown({
        Name = "Select Boss",

        Options = {
            "Lv.Gojo", "Gojo Sensei", "Lv.Dagon", "Lv.1 Curse Remnant",
            "Lv.1 Toji", "Lv.1 Flame Disaster", "Lv.1 Cursed Anomaly",
            "Lv.1 Ryu", "Lv.1 Lightning Vessel",
        },
        CurrentOption = { "Lv.Gojo" },
        MultipleOptions = true,
        Callback = function(choice)
            local list = {}
            if type(choice) == "table" then
                for _, v in ipairs(choice) do table.insert(list, tostring(v)) end
            elseif type(choice) == "string" then list = { choice } end
            NexusBossPick = list
            nexusApplyBossTab()
        end,
    })
    PT(BossTab, "BossTabOn", "Auto Kill Boss", function(on) BossTabOn = on; nexusApplyBossTab() end)

    ShadowTab:CreateSection("Island Teleport")
    ShadowTab:CreateButton({ Name = "Tp Shadow Island", Callback = function() nexusTpTo(SHADOW_ISLAND_POS) end })

    ShadowTab:CreateSection("Shikigami Bosses")

    nxShikiDrop = ShadowTab:CreateDropdown({
        Name = "Select Boss",
        Options = nexusShikiOptions(),
        CurrentOption = { "All" },
        MultipleOptions = true,
        Callback = function(choice)
            local list = {}
            if type(choice) == "table" then
                for _, v in ipairs(choice) do

                    table.insert(list, shadowNorm(v))
                end
            elseif type(choice) == "string" then list = { shadowNorm(choice) } end
            ShadowPick = list
        end,
    })
    ShikiOptDirty = true
    PT(ShadowTab, "AutoKillShikigamiOn", "Auto Kill Shikigami", function(on) AutoKillShikigamiOn = on end)

    ShadowTab:CreateSection("Shikigami Summon")
    PT(ShadowTab, "AutoShikigamiOn", "Auto Shikigami", function(on) AutoShikigamiOn = on end)
    NEXUS_SHIKI_GAP = tonumber(S("ShikiGap", NEXUS_SHIKI_GAP)) or NEXUS_SHIKI_GAP
    ShadowTab:CreateSlider({ Name = "Summon Delay sec", Range = { 0.1, 2 }, Increment = 0.05,
        CurrentValue = NEXUS_SHIKI_GAP, Callback = function(v)
            NEXUS_SHIKI_GAP = tonumber(v) or 0.5
            Settings["ShikiGap"] = NEXUS_SHIKI_GAP
            pcall(saveSettings)
        end })

    ShikiPanel = ShadowTab:CreateParagraph({ Title = "Shikigami Status", Text = "Idle" })
    nexusRefreshButton(ShadowTab)
    task.spawn(function()
        local last = ""
        local shikiIdle = 0
        while NEXUSG.NexusPlayHubSession == SESSION do
            local shikiChg = false
            if ShikiPanel then
                local txt = NexusShikiStatusText()
                if txt ~= last then
                    last = txt
                    shikiChg = true
                    nexusPanelSet(ShikiPanel, txt)
                    nexusShikiFitPanel()
                end
            end

            if shikiChg then shikiIdle = 0 else shikiIdle = shikiIdle + 1 end
            task.wait(shikiIdle >= 6 and 0.6 or 0.1)
        end
    end)

    StatusTab:CreateSection("Live Status")
    StatusLabel = StatusTab:CreateLabel({ Text = "Ready", Style = 2 })
    nexusRefreshButton(StatusTab)

    StatusTab:CreateSection("My Position")
    PosLabel = StatusTab:CreateLabel({ Text = "X: 0   Y: 0   Z: 0", Style = 2 })

    function NexusRootOf(m)
        if not m then return nil end
        local r = m:FindFirstChild("HumanoidRootPart")
            or m:FindFirstChild("Torso")
            or m:FindFirstChild("UpperTorso")
            or (m:IsA("Model") and m.PrimaryPart)
        if r and r:IsA("BasePart") then return r end
        return nil
    end

    function NexusMyHRP()
        local myName = LocalPlayer and LocalPlayer.Name or ""
        local myDisp = LocalPlayer and LocalPlayer.DisplayName or myName

        local own = NexusOwnServerModel()
        if own then
            local ro = NexusRootOf(own)
            if ro then return ro end
        end

        local r = NexusRootOf(LocalPlayer and LocalPlayer.Character)
        if r then return r end

        r = NexusRootOf(MyModel)
        if r then return r end
        local okG, mg = pcall(getModel)
        if okG then
            r = NexusRootOf(mg)
            if r then return r end
        end

        local okF = pcall(function()
            local charFolder = workspace:FindFirstChild("Characters")
            if not charFolder then return end
            local folders = {}
            local clientF = charFolder:FindFirstChild("Client")
            if clientF then table.insert(folders, clientF) end
            local serverF = charFolder:FindFirstChild("Server")
            if serverF then
                local pf = serverF:FindFirstChild("Players")
                if pf then table.insert(folders, pf) end
                table.insert(folders, serverF)
            end
            table.insert(folders, charFolder)
            for _, f in ipairs(folders) do
                for _, m in ipairs(f:GetChildren()) do
                    local n = m.Name
                    if n == myName or n == myDisp
                        or n:sub(1, #myName + 1) == (myName .. "_")
                        or n:sub(1, #myDisp + 1) == (myDisp .. "_") then
                        local rr = NexusRootOf(m)
                        if rr then r = rr return end
                    end
                end
            end
        end)
        if okF and r then return r end

        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local camPos = cam.CFrame.Position
            local charFolder = workspace:FindFirstChild("Characters")
            local clientF = charFolder and charFolder:FindFirstChild("Client")
            if not clientF then return end
            local best, bestD
            for _, m in ipairs(clientF:GetChildren()) do
                local rr = NexusRootOf(m)
                if rr then
                    local d = (rr.Position - camPos).Magnitude
                    if (not bestD) or d < bestD then best, bestD = rr, d end
                end
            end
            if best and bestD and bestD <= 60 then r = best end
        end)
        return r
    end

    function NexusRound2(n)
        return math.floor(n * 100 + 0.5) / 100
    end

    function NexusMyPos()
        local hrp = NexusMyHRP()
        local p
        if hrp then
            p = hrp.Position
        else
            local cam = workspace.CurrentCamera
            if not cam then return nil end
            p = cam.CFrame.Position
        end
        return NexusRound2(p.X), NexusRound2(p.Y), NexusRound2(p.Z), (hrp ~= nil)
    end

    function NexusCopy(txt)
        local ok = pcall(function()
            local cb = setclipboard or toclipboard or (syn and syn.write_clipboard)
            if not cb then error("no clipboard") end
            cb(txt)
        end)
        pcall(function()
            if ok then
                Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Copied: " .. txt, Type = "Success", Duration = 3 })
            else
                Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Clipboard not supported by your executor", Type = "Error", Duration = 3 })
            end
        end)
    end

    StatusTab:CreateButton({ Name = "Copy Position", Callback = function()
        local x, y, z = NexusMyPos()
        if not x then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Character not loaded", Type = "Error", Duration = 3 }) end)
            return
        end
        NexusCopy(x .. ", " .. y .. ", " .. z)
    end })

    StatusTab:CreateButton({ Name = "Copy Vector3.new", Callback = function()
        local x, y, z = NexusMyPos()
        if not x then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Character not loaded", Type = "Error", Duration = 3 }) end)
            return
        end
        NexusCopy("Vector3.new(" .. x .. ", " .. y .. ", " .. z .. ")")
    end })

    StatusTab:CreateSection("Teleport to Position")

    NexusTpBoxText = tostring(S("NexusTpBoxText", "") or "")

    function NexusParsePos(text)
        if type(text) ~= "string" then return nil end
        local nums = {}
        for n in string.gmatch(text, "%-?%d+%.?%d*") do
            nums[#nums + 1] = tonumber(n)
            if #nums == 3 then break end
        end
        if #nums < 3 then return nil end
        return nums[1], nums[2], nums[3]
    end

    StatusTab:CreateInput({
        Name = "Position (X, Y, Z)",
        CurrentValue = NexusTpBoxText,
        PlaceholderText = "1347.7, 677.09, 410.25",
        RemoveTextAfterFocusLost = false,
        MaxCharacters = 80,
        Callback = function(text)
            NexusTpBoxText = tostring(text or "")
            Settings["NexusTpBoxText"] = NexusTpBoxText
            saveSettings()
        end,
    }, "NEXUS_NexusTpBoxText")

    StatusTab:CreateButton({ Name = "Tp to Position", Callback = function()
        local x, y, z = NexusParsePos(NexusTpBoxText)
        if not x then
            pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Type a position like 1347.7, 677.09, 410.25", Type = "Error", Duration = 3 }) end)
            return
        end
        task.spawn(function()
            local ok = false
            pcall(function() ok = nexusTpTo(Vector3.new(x, y, z)) end)
            if ok then
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Teleported to " .. x .. ", " .. y .. ", " .. z, Type = "Success", Duration = 3 }) end)
            else
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Character not loaded", Type = "Error", Duration = 3 }) end)
            end
        end)
    end })

    StatusTab:CreateSection("Teleport to Part / Model")

    NexusTpPartText = tostring(S("NexusTpPartText", "") or "")
    NexusTpPartList, NexusTpPartKey, NexusTpPartIdx = {}, "", 0

    function NexusPosOfObject(obj)
        return NexusObjPos(obj)
    end

    function NexusCollectObjects(name)
        local exact, loose = {}, {}
        local low = string.lower(name)

        local lowMemo = {}
        pcall(function()
            for _, d in ipairs(wsDesc()) do
                local nm = d.Name
                if nm == name then
                    if NexusPosOfObject(d) then exact[#exact + 1] = d end
                else
                    local l = lowMemo[nm]
                    if l == nil then l = string.lower(nm) lowMemo[nm] = l end
                    if string.find(l, low, 1, true) and NexusPosOfObject(d) then
                        loose[#loose + 1] = d
                    end
                end
            end
        end)
        local list = (#exact > 0) and exact or loose
        pcall(function()
            table.sort(list, function(a, b)
                local pa, pb = NexusPosOfObject(a), NexusPosOfObject(b)
                if not pa or not pb then return false end
                if pa.X ~= pb.X then return pa.X < pb.X end
                if pa.Y ~= pb.Y then return pa.Y < pb.Y end
                return pa.Z < pb.Z
            end)
        end)
        return list
    end

    StatusTab:CreateInput({
        Name = "Part / Model Name",
        CurrentValue = NexusTpPartText,
        PlaceholderText = "FogSealedGate",
        RemoveTextAfterFocusLost = false,
        MaxCharacters = 80,
        Callback = function(text)
            NexusTpPartText = tostring(text or "")
            NexusTpPartList, NexusTpPartKey, NexusTpPartIdx = {}, "", 0
            Settings["NexusTpPartText"] = NexusTpPartText
            saveSettings()
        end,
    }, "NEXUS_NexusTpPartText")

    StatusTab:CreateButton({ Name = "Tp to Part / Model", Callback = function()
        task.spawn(function()
            local name = tostring(NexusTpPartText or ""):match("^%s*(.-)%s*$") or ""
            if name == "" then
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Type a part or model name first", Type = "Error", Duration = 3 }) end)
                return
            end

            local stale = (NexusTpPartKey ~= name) or (#NexusTpPartList == 0)
            if not stale then
                for _, o in ipairs(NexusTpPartList) do
                    if not (o and o.Parent) then stale = true break end
                end
            end
            if stale then
                NexusTpPartList = NexusCollectObjects(name)
                NexusTpPartKey  = name
                NexusTpPartIdx  = 0
            end
            local total = #NexusTpPartList
            if total == 0 then
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "No part or model named \"" .. name .. "\" found", Type = "Error", Duration = 3 }) end)
                return
            end

            NexusTpPartIdx = (NexusTpPartIdx % total) + 1
            local obj = NexusTpPartList[NexusTpPartIdx]
            local pos = NexusPosOfObject(obj)
            if not pos then
                NexusTpPartList = {}
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "That one despawned, press Tp again", Type = "Error", Duration = 3 }) end)
                return
            end
            local ok = false
            pcall(function() ok = nexusTpTo(pos + Vector3.new(0, 3, 0)) end)
            if ok then
                pcall(function() Library:Notify({
                    Title = "NEXUSPLAY HUB",
                    Content = obj.Name .. "  (" .. NexusTpPartIdx .. "/" .. total .. ")",
                    Type = "Success", Duration = 3,
                }) end)
            else
                pcall(function() Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Character not loaded", Type = "Error", Duration = 3 }) end)
            end
        end)
    end })

    task.spawn(function()
        local lastPos = nil
        while NEXUSG.NexusPlayHubSession == SESSION do
            local x, y, z, real = NexusMyPos()
            local ptxt
            if x then
                ptxt = "X: " .. x .. "   Y: " .. y .. "   Z: " .. z .. (real and "" or "   (camera)")
            else
                ptxt = "X: -   Y: -   Z: -   (waiting for character)"
            end
            if ptxt ~= lastPos then
                lastPos = ptxt
                pcall(function() PosLabel:Set(ptxt) end)
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while NEXUSG.NexusPlayHubSession == SESSION do

            local parts = {}
            if FastOn then table.insert(parts, "Attack") end
            if NEXUS_LV.KillOn then table.insert(parts, "Aura") end
            if NEXUS_LV.BringOn then table.insert(parts, "Bring") end
            if NEXUS_LV.BringAllOn then table.insert(parts, "BringAll") end
            if NEXUS_LV.ReachOn then table.insert(parts, "Reach") end
            if QuestOn then table.insert(parts, "Quest") end
            if AutoKillBossOn then table.insert(parts, "KillBoss(" .. tostring(selectedBoss) .. ")") end
            if FindBossHopOn then table.insert(parts, "FindBoss") end
            if NEXUS_LV.FastQuestOn then table.insert(parts, "FastQ") end
            if BringQuestOn then table.insert(parts, "BringQ") end
            if BlackFlashOn then table.insert(parts, "BF") end
            if NEXUS_LV.BlackFlash2On then table.insert(parts, "BF2") end
            if NEXUS_LV.BlackFlash3On then table.insert(parts, "BF3") end
            if NEXUS_LV.PlungeOn then table.insert(parts, "Plunge") end
            if NEXUS_LV.FugaOn then table.insert(parts, "Fuga") end
            if NEXUS_LV.DismantleOn then table.insert(parts, "Dismantle") end
            if NEXUS_LV.WebSlamOn then table.insert(parts, "WebSlam") end
            if NEXUS_LV.CleaveOn then table.insert(parts, "Cleave") end
            if NEXUS_LV.SukunaOn then table.insert(parts, "Sukuna") end
            if NEXUS_LV.HakariOn then table.insert(parts, "Hakari") end
            if NEXUS_LV.LimitlessOn then table.insert(parts, "Limitless") end
            if NEXUS_LV.AwkLimitlessOn then table.insert(parts, "AwkLimitless") end
            if NEXUS_LV.FastInfAuraOn then table.insert(parts, "InfAura") end
            if NexusSMOn then table.insert(parts, "SukunaMark") end
            if NexusSWSMOn then table.insert(parts, "SW-SM") end
            if NexusSWFillOn then table.insert(parts, "SM-Fill") end
            if CopyOn then table.insert(parts, "Copy") end
            if BloodOn then table.insert(parts, "Blood") end
            if StarRageOn then table.insert(parts, "StarRage") end
            if BeastAmberOn then table.insert(parts, "Beast") end
            if NEXUS_LV.ProjectionOn then table.insert(parts, "Projection") end
            if NEXUS_LV.LarpOn then table.insert(parts, "Larp") end
            if NEXUS_LV.JudgemanOn then table.insert(parts, "Judgeman") end
            if TenShadowsOn then table.insert(parts, "TenShadows") end
            if AutoGojoOn then table.insert(parts, "Gojo") end
            if BringGojoOn then table.insert(parts, "BringGojo") end
            if StarQ1On then table.insert(parts, "Star1") end
            if StarQ2On then table.insert(parts, "Star2") end
            if StarQ3On then table.insert(parts, "Star3") end
            if StarQ4On then table.insert(parts, "Star4") end
            if StarQ5On then table.insert(parts, "Star5") end
            if StarBossOn then table.insert(parts, "LunaticCultist") end
            if NEXUS_LV.QuickShapeOn then table.insert(parts, "QuickShape") end
            if AutoSlot1On then table.insert(parts, "Slot1") end
            if AutoSlot2On then table.insert(parts, "Slot2") end
            if NEXUS_LV.AutoChestOn then table.insert(parts, "Chest") end
            if NEXUS_LV.AutoRaidOn then table.insert(parts, "Raid") end
            if AutoBloodRaidOn then table.insert(parts, "BloodRaid") end
            if AutoLightningRaidOn then table.insert(parts, "LightningRaid") end
            if AutoOuterRaidOn then table.insert(parts, "OuterRaid") end
            if AutoYutaRaidOn then table.insert(parts, "YutaRaid") end
            if RaidCfg.active.Judge then table.insert(parts, "JudgeRaid") end
            if RaidCfg.active.Jogo then table.insert(parts, "JogoRaid") end
            if RaidCfg.active.Toji then table.insert(parts, "TojiRaid") end
            if RaidCfg.active.Sukuna then table.insert(parts, "SukunaRaid") end
            if RaidCfg.active.AToji then table.insert(parts, "ATojiRaid") end
            if RaidCfg.active.Maki then table.insert(parts, "MakiRaid") end
            if RaidCfg.active.AGojo then table.insert(parts, "AGojoRaid") end
            if AutoCurseCalamityOn then table.insert(parts, "CurseCalamityRaid") end
            if BringRaidNpcOn then table.insert(parts, "BringRaidNPC(" .. tostring(RAID_BRING_RANGE) .. ")") end
            if TrialOn then table.insert(parts, "Trial[C" .. tostring(TrialChamber) .. " " .. tostring(TrialRuns) .. "/" .. tostring(TrialRestarts) .. (TrialNextOn and " next" or "") .. " " .. tostring(TrialPhase) .. "]") end
            if flying then table.insert(parts, "Fly") end
            if AntiAfkOn then table.insert(parts, "AntiAFK[" .. tostring(NEXUS_AfkNudges) .. "/" .. tostring(NEXUS_AfkMethod) .. "]") end
            if AntiTpOn then table.insert(parts, "AntiTP") end
            if #parts == 0 then

                pcall(function() StatusLabel:Set("Active: OFF   |   Targets: 0") end)
                task.wait(2)
            else
                local t = select(1, NEXUS_LV.collectTargets())
                pcall(function() StatusLabel:Set("Active: " .. table.concat(parts, "+") .. "   |   Targets: " .. #t) end)
                task.wait(0.5)
            end
        end
    end)

    pcall(function()
        Library:Notify({ Title = "NEXUSPLAY HUB", Content = "Loaded successfully!", Type = "Success", Duration = 4 })
    end)
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        local farming = QuestOn or BringQuestOn or AutoGojoOn or BringGojoOn
            or (NexusRctAnyOn and NexusRctAnyOn()) or (NexusStarQuestOn and NexusStarQuestOn())
            or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn())
        if farming and NexusCapPoint() then
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if chrp then NexusCapKeepInside(chrp, NEXUS_CAP_LEASH) end
            task.wait(NEXUS_CAP_TICK)
        else
            task.wait(NEXUS_IDLE)
        end
    end
end)

NEXUS_STALE_GAP = 12
NEXUS_STALE_TICK = 3
NexusStaleT = {}
NexusStaleWarn = {}

function NexusCapAreaExists(capId)
    if not capId then return false end
    local found = false
    pcall(function()
        found = workspace.Container.QuestAreas.Capture:FindFirstChild(tostring(capId)) ~= nil
    end)
    return found
end

function NexusCapStaleFix(id)
    if not id or id == "" then return nil end
    local m = NexusQuestMods()
    if not m or not m.ok then return nil end
    local cfg = m.QCfg and m.QCfg.Quests and m.QCfg.Quests[id]
    if not cfg or cfg.Type ~= "Capture" then return nil end
    local saved
    pcall(function() saved = m.QC:GetSavedQuest(id) end)
    if not saved or saved.IsFinished then return nil end
    local capId = saved.CaptureID
    if not capId or NexusCapAreaExists(capId) then
        NexusStaleWarn[id] = nil
        return "ok"
    end
    local pts = tonumber(saved.Points) or 0
    if pts > 0 then

        if not NexusStaleWarn[id] then
            NexusStaleWarn[id] = true
            pcall(function()
                Library:Notify({ Title = "NEXUSPLAY HUB", Type = "Error", Duration = 9,
                    Content = id .. " was started on a different server, so its quest area does not "
                        .. "exist here and the " .. tostring(pts) .. " points cannot go up. Rejoin that "
                        .. "server, or cancel the quest to restart it here." })
            end)
        end
        return "locked"
    end
    local now = os.clock()
    if (now - (NexusStaleT[id] or -1)) < NEXUS_STALE_GAP then return "reset" end
    NexusStaleT[id] = now
    if not NexusQuestCancel then
        pcall(function() NexusQuestCancel = Net.QuestService.CancelQuest_Method end)
    end
    if NexusQuestCancel then pcall(function() NexusQuestCancel:InvokeServer(id) end) end
    task.wait(1)
    NexusAccT[id] = nil
    NexusSafeAccept(id)
    task.wait(1)
    local s2
    pcall(function() s2 = m.QC:GetSavedQuest(id) end)
    local fixed = s2 and NexusCapAreaExists(s2.CaptureID)
    pcall(function()
        Library:Notify({ Title = "NEXUSPLAY HUB", Type = fixed and "Success" or "Info", Duration = 6,
            Content = fixed
                and (id .. ": quest area was from another server, so it was re-issued here. Farming now.")
                or (id .. ": quest area missing on this server, retrying...") })
    end)
    return "reset"
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        local farming = QuestOn or BringQuestOn or AutoGojoOn or BringGojoOn
            or (NexusRctAnyOn and NexusRctAnyOn()) or (NexusStarQuestOn and NexusStarQuestOn())
            or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn())
        if not farming then
            task.wait(NEXUS_IDLE)
        else
            local m = NexusQuestMods()
            local seen, ids = {}, {}
            local function push(v) if v and v ~= "" and not seen[v] then seen[v] = true ids[#ids + 1] = v end end
            if m and m.ok then
                local act
                pcall(function() act = m.QC:GetActiveQuest() end)
                push(act)
            end
            if NexusHRQuestId then pcall(function() push(NexusHRQuestId()) end) end
            if NexusKMQuestId then pcall(function() push(NexusKMQuestId()) end) end
            if NexusRctQuestId then pcall(function() push(NexusRctQuestId()) end) end
            if currentQuestId then pcall(function() push(currentQuestId()) end) end
            for i = 1, #ids do pcall(NexusCapStaleFix, ids[i]) end
            task.wait(NEXUS_STALE_TICK)
        end
    end
end)

NEXUS_ROAM_SPEED = 55
NEXUS_ROAM_TURN  = 1.15
NEXUS_ROAM_NEAR  = 5
NEXUS_ROAM_SWEEP = 0.55
NEXUS_ROAM_CLAMP = 0.70
NEXUS_ROAM_SNAP  = 250
NEXUS_ROAM_PICK  = 0.35
NexusRoamAngle = 0

function NexusCapClamp(p, center, rad)
    local d = p - center
    local flat = Vector3.new(d.X, 0, d.Z)
    local lim = rad * NEXUS_ROAM_CLAMP
    if flat.Magnitude > lim and flat.Magnitude > 0 then
        flat = flat.Unit * lim
    end
    local ylim = rad * 0.35
    local y = math.clamp(p.Y, center.Y - ylim, center.Y + ylim)
    return Vector3.new(center.X + flat.X, y, center.Z + flat.Z)
end

task.spawn(function()
    local nextPick, best = 0, nil
    while NEXUSG.NexusPlayHubSession == SESSION do
        local farming = QuestOn or BringQuestOn or AutoGojoOn or BringGojoOn
            or (NexusRctAnyOn and NexusRctAnyOn()) or (NexusStarQuestOn and NexusStarQuestOn())
            or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn())
        local center, rad = NexusCapPoint()
        if not (farming and center and NexusCapRoamOn) then
            if NexusCapPhase == "roam" then NexusCapPhase = "hold" end
            best = nil
            task.wait(NEXUS_IDLE)
        else
            local cur = getModel()
            local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
            if not chrp then
                best = nil
                task.wait(NEXUS_IDLE)
            else
                NexusCapPhase = "roam"
                local now = os.clock()
                if now >= nextPick then
                    nextPick = now + NEXUS_ROAM_PICK

                    pcall(NexusAIBring, chrp.Position)
                    best = nil
                    local bd = math.huge
                    local list = NexusAIQuestList()
                    for i = 1, #list do
                        local pp = list[i].pp
                        if pp and pp.Parent then
                            local dc = pp.Position - center
                            if Vector3.new(dc.X, 0, dc.Z).Magnitude <= rad and math.abs(dc.Y) <= rad then
                                local d = (pp.Position - chrp.Position).Magnitude
                                if d < bd then bd, best = d, pp end
                            end
                        end
                    end
                end

                local dt = RunService.Heartbeat:Wait() or 0.016
                if dt > 0.2 then dt = 0.2 end
                NexusRoamAngle = (NexusRoamAngle + NEXUS_ROAM_TURN * dt) % (math.pi * 2)

                local target
                if best and best.Parent then

                    local mp = best.Position
                    local b = chrp.Position - mp
                    b = Vector3.new(b.X, 0, b.Z)
                    local bearing = (b.Magnitude > 0.1) and math.atan2(b.Z, b.X) or NexusRoamAngle
                    bearing = bearing + NEXUS_ROAM_TURN * dt
                    target = Vector3.new(
                        mp.X + math.cos(bearing) * NEXUS_ROAM_NEAR,
                        mp.Y + 2,
                        mp.Z + math.sin(bearing) * NEXUS_ROAM_NEAR
                    )
                else

                    target = Vector3.new(
                        center.X + math.cos(NexusRoamAngle) * rad * NEXUS_ROAM_SWEEP,
                        center.Y + 3,
                        center.Z + math.sin(NexusRoamAngle) * rad * NEXUS_ROAM_SWEEP
                    )
                end
                target = NexusCapClamp(target, center, rad)

                local p = chrp.Position
                local d = target - p
                local flat = Vector3.new(d.X, 0, d.Z)
                local dist = flat.Magnitude
                local step = flat
                if dist > NEXUS_ROAM_SNAP then
                    step = flat
                elseif dist > NEXUS_ROAM_SPEED * dt then
                    step = flat.Unit * (NEXUS_ROAM_SPEED * dt)
                end
                local np = p + step
                np = Vector3.new(np.X, p.Y + (target.Y - p.Y) * math.min(1, dt * 6), np.Z)
                pcall(function()
                    chrp.AssemblyLinearVelocity = Vector3.zero
                    chrp.AssemblyAngularVelocity = Vector3.zero
                    if dist > 0.6 then
                        local dir = flat.Unit
                        chrp.CFrame = CFrame.new(np, Vector3.new(np.X + dir.X, np.Y, np.Z + dir.Z))
                    else
                        chrp.CFrame = CFrame.new(np)
                    end
                end)
            end
        end
    end
end)

NEXUS_CAP_NODE_WAIT = 1.8
NEXUS_CAP_HAUL_WAIT = 0.6
NEXUS_CAP_NODE_HOP  = 3
NexusCapPhase = "idle"
NexusCapRoamOn = true
NexusCapGatherOn = false

NexusCapM = NexusCapM or { t = -1, n = 0 }
NexusCapN = NexusCapN or { key = nil, list = nil, i = 1, miss = 0 }

function NexusCapMobs()
    local c, now = NexusCapM, os.clock()
    if (now - c.t) < 0.3 then return c.n end
    c.t, c.n = now, 0
    local cap = NexusCapInfo()
    if not cap.on or not cap.names or #cap.names == 0 then return 0 end
    local CF = workspace.Characters and workspace.Characters:FindFirstChild("Client")
    if not CF then return 0 end
    local nms, nn, n = cap.names, #cap.names, 0
    for _, d in ipairs(clientLabels(CF)) do
        if d.ClassName == "TextLabel" then
            local lt = string.lower(d.Text)
            for i = 1, nn do
                if string.find(lt, nms[i], 1, true) then n = n + 1 break end
            end
        end
    end
    c.n = n
    return n
end

function NexusCapNodes()
    local cap = NexusCapInfo()
    if not cap.on or not cap.pos then return nil end
    local st, key = NexusCapN, tostring(cap.id)
    if st.key == key and st.list and #st.list > 0 then return st.list end
    local qs
    pcall(function() qs = workspace.Map.Spawnpoints.QuestSpawnpoints end)
    if not qs then return nil end
    local list = {}
    for _, c in ipairs(qs:GetChildren()) do
        if c:IsA("BasePart") then
            local v = c.Position - cap.pos
            list[#list + 1] = { p = c.Position, d = Vector3.new(v.X, 0, v.Z).Magnitude }
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    st.key, st.list, st.i, st.miss = key, list, 1, 0
    if #list == 0 then return nil end
    return list
end

task.spawn(function()
    while NEXUSG.NexusPlayHubSession == SESSION do
        local farming = QuestOn or BringQuestOn or AutoGojoOn or BringGojoOn
            or (NexusRctAnyOn and NexusRctAnyOn()) or (NexusStarQuestOn and NexusStarQuestOn())
            or (NexusHRAnyOn and NexusHRAnyOn()) or (NexusKMAnyOn and NexusKMAnyOn())
        local capPos, capRad = NexusCapPoint()
        if not (farming and capPos and NexusCapGatherOn) then
            NexusCapPhase = "idle"
            task.wait(NEXUS_IDLE)
        elseif NexusCapMobs() > 0 then

            NexusCapPhase = "hold"
            NexusCapN.miss = 0
            task.wait(0.4)
        else

            local nodes = NexusCapNodes()
            if not nodes then
                NexusCapPhase = "hold"
                task.wait(NEXUS_IDLE)
            else
                NexusCapPhase = "gather"
                local st = NexusCapN
                if st.i > #nodes then st.i = 1 end
                local node = nodes[st.i]
                local cur = getModel()
                local chrp = cur and cur:FindFirstChild("HumanoidRootPart")
                if chrp and node then
                    pcall(function()
                        chrp.AssemblyLinearVelocity = Vector3.zero
                        chrp.CFrame = CFrame.new(node.p + Vector3.new(0, 6, 0))
                    end)
                    task.wait(NEXUS_CAP_NODE_WAIT)
                    if NexusCapMobs() > 0 then
                        st.miss = 0
                    else
                        st.miss = st.miss + 1
                        if st.miss >= NEXUS_CAP_NODE_HOP then
                            st.miss, st.i = 0, st.i + 1
                        end
                    end

                    NexusCapPhase = "hold"
                    local pos2 = NexusCapPoint()
                    if pos2 then
                        pcall(function()
                            chrp.AssemblyLinearVelocity = Vector3.zero
                            chrp.CFrame = CFrame.new(pos2 + Vector3.new(0, NEXUS_CAP_LIFT, 0))
                        end)
                    end
                    task.wait(NEXUS_CAP_HAUL_WAIT)
                else
                    task.wait(NEXUS_IDLE)
                end
            end
        end
    end
end)


-- ===== [NEXUS-OPT] load flag + live diagnostics =====
NEXUSG.NEXUS_LV        = NEXUS_LV
NEXUSG.NEXUS_OPT       = NEXUS_OPT
NEXUSG.NexusPlayHubLoaded  = true
NEXUSG.NEXUS_OPT_BUILD = "OPT-1"
function NexusOptStats()
    local s = NEXUS_OPT.stats
    return {
        queued   = s.queued,
        ran      = s.ran,
        dropQ    = s.dropQ,
        dropInv  = s.dropInv,
        inflight = s.inflight,
        peakQ    = s.peakQ,
        invOk    = s.invOk,
    }
end
NEXUSG.NexusOptStats = NexusOptStats
print("[NEXUS] optimizer build OPT-1 active (pool=" .. tostring(NEXUS_OPT.MAX_WORKERS) .. " inflight=" .. tostring(NEXUS_OPT.MAX_INFLIGHT) .. ")")
-- ===== [/NEXUS-OPT] =====
