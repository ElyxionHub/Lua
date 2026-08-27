--[[
    elyxionHub - Brainrot Edition
    Owner: Lavatrapgaming1
    Features:
      - Auto Equip Best Brainrot (auto-detect from inventory)
      - Auto Place In Slot (multi-slot support)
      - Auto Collect Money (all slots)
]]

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "elyxionHub",
    Icon = "rbxassetid://13548131415563",
    Author = "By lavatrapgaming1",
    Folder = "elyxionHub",
    Size = UDim2.fromOffset(580, 480),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 150,
    Background = "rbxassetid://135481314155653",
    BackgroundImageTransparency = 0.42,
    HideSearchBar = false,
    ScrollBarEnabled = false,
    User = { Enabled = true, Anonymous = false },
})

Window:EditOpenButton({
    Title = "Open elyxionHub ",
    Icon = "rbxassetid://135481314155653",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("007BFF"),
        Color3.fromHex("00BFFF")
    ),
    Draggable = true,
})

local Tabs = {
    Info = Window:Tab({ Title = "Info", Icon = "ghost" }),
    Main = Window:Tab({ Title = "Main", Icon = "gem" }),
    Inventory = Window:Tab({ Title = "Inventory", Icon = "cog" }),
    Buy = Window:Tab({ Title = "Buy", Icon = "badge-dollar-sign" }),
}

local InfoTab = Tabs.Info
local MainTab = Tabs.Main
local InventoryTab = Tabs.Inventory

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

-- Automatic Game Detection
local gameName = "Unknown"
local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if success and info then
    gameName = info.Name
end

-- ============================================================
-- INFO TAB
-- ============================================================
InfoTab:Section({
    Title = "Info",
    Desc = "Owner: Lavatrapgaming1\nRoblox: Anjaboss11\nTikTok: lavatrapgaming1\nDiscord: Lavatrapgaming",
    Box = true,
    BoxBorder = true,
})

InfoTab:Section({
    Title = "Current Game",
    Desc = "Game: " .. gameName .. "\nPlaceId: " .. tostring(game.PlaceId),
    Box = true,
    BoxBorder = true,
})

InfoTab:Section({
    Title = "Discord Group",
    Desc = "If u want to support Join our discord",
    Box = true,
    BoxBorder = true,
})

InfoTab:Button({
    Title = "Copy Discord Link",
    Icon = "copy",
    Callback = function()
        setclipboard("https://discord.gg/vAHRXGdkG")
        WindUI:Notify({
            Title = "Copied!",
            Content = "Discord link has been copied to clipboard",
            Duration = 3
        })
    end
})

-- ============================================================
-- REMOTE HELPERS (safe fetch, never errors if missing)
-- ============================================================
local function GetRemote(name)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    return remotes:FindFirstChild(name)
end

local HotbarEquipRemote     = GetRemote("HotbarEquip")
local PodiumRemote          = GetRemote("PodiumInteraction")
local CollectMoneyRemote    = GetRemote("CollectMoney")

-- getnilinstances support (executor dependent)
local getnil = getnilinstances or get_nil_instances or (getgenv and getgenv().getnilinstances)

local function Notify(title, content, dur)
    WindUI:Notify({ Title = title, Content = content, Duration = dur or 3 })
end

-- ============================================================
-- BRAINROT VALUE DETECTION
-- ============================================================
-- Parses income strings like "$1.5M/s", "2.3K/s", "12,500/s"
local SUFFIX = {
    [""] = 1, K = 1e3, M = 1e6, B = 1e9, T = 1e12, QA = 1e15, QD = 1e15, QI = 1e18,
}

local function ParseNumber(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return 0 end
    local clean = str:gsub(",", ""):gsub("%$", "")
    local num, suf = clean:match("([%d%.]+)%s*([A-Za-z]*)")
    if not num then return 0 end
    local value = tonumber(num) or 0
    local mult = SUFFIX[string.upper(suf or "")]
    return value * (mult or 1)
end

-- Rarity fallback ranking (used only when no income data is found)
local RARITY_RANK = {
    ["common"] = 1, ["uncommon"] = 2, ["rare"] = 3, ["epic"] = 4,
    ["legendary"] = 5, ["mythic"] = 6, ["brainrot god"] = 7, ["god"] = 7,
    ["secret"] = 8, ["og"] = 9, ["admin"] = 10,
}

local MUTATION_BONUS = {
    ["gold"] = 1.25, ["diamond"] = 1.5, ["rainbow"] = 2, ["candy"] = 2,
    ["bloodrot"] = 3, ["celestial"] = 4, ["lava"] = 1.4, ["galaxy"] = 2.5,
}

-- Extract a numeric score from an instance representing a brainrot
local function ScoreObject(obj)
    local score = 0
    local nameLower = string.lower(obj.Name or "")

    -- 1) Attributes are the most reliable source
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if ok and attrs then
        for key, val in pairs(attrs) do
            local k = string.lower(tostring(key))
            if k:find("generation") or k:find("income") or k:find("persec")
               or k:find("money") or k:find("cash") or k:find("profit")
               or k:find("value") or k:find("price") or k:find("worth") then
                local n = ParseNumber(val)
                if n > score then score = n end
            end
        end
        for key, val in pairs(attrs) do
            local k = string.lower(tostring(key))
            if k:find("rarity") or k:find("tier") then
                local r = RARITY_RANK[string.lower(tostring(val))]
                if r and score == 0 then score = r * 1000 end
            end
            if k:find("mutation") or k:find("trait") then
                local m = MUTATION_BONUS[string.lower(tostring(val))]
                if m then score = score * m end
            end
        end
    end

    -- 2) Child values / string labels (e.g. "Generation" NumberValue, GUI text)
    local okd, desc = pcall(function() return obj:GetDescendants() end)
    if okd and desc then
        for _, d in ipairs(desc) do
            local dn = string.lower(d.Name)
            if d:IsA("ValueBase") then
                if dn:find("generation") or dn:find("income") or dn:find("value")
                   or dn:find("price") or dn:find("cash") or dn:find("money") then
                    local n = ParseNumber(d.Value)
                    if n > score then score = n end
                end
            elseif d:IsA("TextLabel") or d:IsA("TextBox") then
                local txt = tostring(d.Text or "")
                if txt:find("/s") or txt:find("%$") then
                    local n = ParseNumber(txt)
                    if n > score then score = n end
                end
            end
        end
    end

    -- 3) Name-embedded income, e.g. "Pipi Avocado [$1.2M/s]"
    if score == 0 and (nameLower:find("/s") or nameLower:find("%$")) then
        score = ParseNumber(obj.Name)
    end

    -- 4) Name-embedded rarity / mutation as last resort
    if score == 0 then
        for rar, rank in pairs(RARITY_RANK) do
            if nameLower:find(rar, 1, true) then
                score = math.max(score, rank * 1000)
            end
        end
        if score == 0 then score = 1 end
    end

    for mut, bonus in pairs(MUTATION_BONUS) do
        if nameLower:find(mut, 1, true) then
            score = score * bonus
        end
    end

    return score
end

-- Collect every candidate brainrot from inventory (nil instances + backpack)
local function GetInventoryBrainrots()
    local list = {}

    if getnil then
        local ok, objs = pcall(getnil)
        if ok and objs then
            for _, obj in ipairs(objs) do
                local isCandidate = false
                local okc = pcall(function()
                    isCandidate = obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Configuration")
                end)
                if okc and isCandidate and obj.Name ~= "" then
                    local okid, id = pcall(function() return obj:GetDebugId() end)
                    if okid then
                        table.insert(list, {
                            Object = obj,
                            Name = obj.Name,
                            DebugId = id,
                            Score = ScoreObject(obj),
                        })
                    end
                end
            end
        end
    end

    -- Fallback: backpack tools (for executors without getnilinstances)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local okid, id = pcall(function() return tool:GetDebugId() end)
                table.insert(list, {
                    Object = tool,
                    Name = tool.Name,
                    DebugId = okid and id or "",
                    Score = ScoreObject(tool),
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.Score > b.Score end)
    return list
end

local function GetBestBrainrot(blacklistNames)
    local list = GetInventoryBrainrots()
    for _, entry in ipairs(list) do
        local skip = false
        if blacklistNames then
            for _, bn in ipairs(blacklistNames) do
                if entry.Name == bn then skip = true break end
            end
        end
        if not skip then return entry, list end
    end
    return nil, list
end

-- ============================================================
-- ACTIONS
-- ============================================================
local function EquipBrainrot(entry)
    if not entry then return false end
    if not HotbarEquipRemote then return false end
    local ok = pcall(function()
        HotbarEquipRemote:FireServer(entry.Object)
    end)
    return ok
end

local function PlaceInSlot(slotIndex)
    if not PodiumRemote then return false end
    local ok = pcall(function()
        PodiumRemote:FireServer({
            action = "place",
            podiumIndex = slotIndex,
        })
    end)
    return ok
end

-- ============================================================
-- BASE DETECTION  (workspace.BASE1.BaseTemplate.Floor1["Podium 2"]["Collection Button"])
-- ============================================================
State_MyBase = nil   -- cached base model

local function GetPlayerNameVariants()
    local t = { LocalPlayer.Name, LocalPlayer.DisplayName }
    local out = {}
    for _, v in ipairs(t) do
        if v and v ~= "" then out[string.lower(v)] = true end
    end
    return out
end

-- Is this BASE model owned by the local player?
local function BaseBelongsToMe(base)
    local names = GetPlayerNameVariants()

    -- 1) Attributes: Owner / OwnerName / Player / UserId
    local ok, attrs = pcall(function() return base:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            local lk = string.lower(tostring(k))
            if lk:find("owner") or lk:find("player") or lk:find("user") then
                local sv = tostring(v)
                if names[string.lower(sv)] then return true end
                if tonumber(sv) and tonumber(sv) == LocalPlayer.UserId then return true end
            end
        end
    end

    -- 2) Owner ValueBase children (StringValue "Owner", ObjectValue -> Player)
    local okd, desc = pcall(function() return base:GetDescendants() end)
    if okd and desc then
        for _, d in ipairs(desc) do
            local dn = string.lower(d.Name)
            if d:IsA("ObjectValue") and d.Value == LocalPlayer then
                return true
            elseif d:IsA("ValueBase") and (dn:find("owner") or dn:find("player") or dn:find("user")) then
                local sv = tostring(d.Value)
                if names[string.lower(sv)] then return true end
                if tonumber(sv) and tonumber(sv) == LocalPlayer.UserId then return true end
            elseif (d:IsA("TextLabel") or d:IsA("TextBox")) then
                -- 3) Base sign / billboard showing the owner's name
                local txt = string.lower(tostring(d.Text or ""))
                for n in pairs(names) do
                    if txt:find(n, 1, true) then return true end
                end
            end
        end
    end

    return false
end

-- Every BASE model in workspace (BASE1, BASE2, Base_3, "Base 4"...)
local function GetAllBases()
    local bases = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if string.lower(obj.Name):match("^base[%s_]*%d*$") and obj:IsA("Model") or
           (string.lower(obj.Name):match("^base") and obj:FindFirstChild("BaseTemplate")) then
            table.insert(bases, obj)
        end
    end
    -- fallback: anything named BASE* anywhere near the top
    if #bases == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do
            if string.lower(obj.Name):find("^base") then
                table.insert(bases, obj)
            end
        end
    end
    return bases
end

-- Detect (and cache) the local player's base
-- Ownership only — never falls back to "nearest" (that often picks the wrong plot)
local function GetMyBase(forceRescan)
    if State_MyBase and State_MyBase.Parent and not forceRescan then
        return State_MyBase
    end
    State_MyBase = nil

    local bases = GetAllBases()

    -- Ownership data only (attributes, Owner values, name signs)
    for _, base in ipairs(bases) do
        local ok, mine = pcall(BaseBelongsToMe, base)
        if ok and mine then
            State_MyBase = base
            return base
        end
    end

    return nil
end

-- Find the container that actually holds the floors (BaseTemplate or the base itself)
local function GetBaseTemplate(base)
    if not base then return nil end
    return base:FindFirstChild("BaseTemplate") or base
end

-- Collect ALL money: fires CollectMoney for every podium index in YOUR base
-- Remote: ReplicatedStorage.Remotes.CollectMoney:FireServer(index)
local function GetCollectRemote()
    local ok, remote = pcall(function()
        return game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5):WaitForChild("CollectMoney", 5)
    end)
    if ok then return remote end
    return CollectMoneyRemote
end

-- Fire the remote for one podium index
local function CollectSlot(slotIndex)
    local remote = GetCollectRemote()
    if not remote then return false end
    local args = { slotIndex }
    local ok = pcall(function()
        remote:FireServer(unpack(args))
    end)
    return ok
end

-- Pull every podium index out of the player's own base (all floors)
-- If ownership detection fails (no base), use fixed range 1..CollectMax — never nearest base
local function GetMyPodiumIndexes(base)
    local found, seen = {}, {}
    base = base or GetMyBase()

    local function add(n)
        n = tonumber(n)
        if n and n > 0 and n <= 200 and not seen[n] then
            seen[n] = true
            table.insert(found, n)
        end
    end

    if base then
        local template = GetBaseTemplate(base)
        pcall(function()
            for _, obj in ipairs(template:GetDescendants()) do
                if string.lower(obj.Name):find("podium") then
                    add(obj.Name:match("(%d+)"))
                end
            end
        end)
    end

    -- Fixed range fallback (no nearest-base logic)
    if #found == 0 then
        local maxSlots = (State and State.CollectMax) or 30
        for i = 1, maxSlots do add(i) end
    end

    table.sort(found)
    return found
end

-- Collect every podium in the base
local function CollectEverything(_, perFireDelay)
    local base = GetMyBase()
    local indexes = GetMyPodiumIndexes(base)
    local fired = 0
    for _, idx in ipairs(indexes) do
        if CollectSlot(idx) then fired = fired + 1 end
        if perFireDelay and perFireDelay > 0 then task.wait(perFireDelay) end
    end
    return fired, #indexes, base and base.Name or "unknown base"
end


-- ============================================================
-- STATE
-- ============================================================
local State = {
    AutoEquipBest   = false,
    AutoPlace       = false,
    AutoCollect     = false,

    EquipDelay      = 1,
    PlaceDelay      = 1,
    CollectDelay    = 1,

    SlotList        = {1,2,3,4,5,6,7,8,9,10},   -- slots used for placing
    CollectMax      = 30,                       -- brute-force sweep ceiling for collecting
    MaxSlot         = 10,

    PlacedNames     = {},   -- names already placed, so we move to the next best
    LastBest        = "None",
}

local function ParseSlotString(str, fallbackMax)
    local out = {}
    if not str or str == "" or string.lower(str) == "all" then
        for i = 1, fallbackMax do out[i] = i end
        return out
    end
    for chunk in string.gmatch(str, "[^,]+") do
        chunk = chunk:gsub("%s", "")
        local a, b = chunk:match("^(%d+)%-(%d+)$")
        if a and b then
            for i = tonumber(a), tonumber(b) do table.insert(out, i) end
        elseif tonumber(chunk) then
            table.insert(out, tonumber(chunk))
        end
    end
    if #out == 0 then
        for i = 1, fallbackMax do out[i] = i end
    end
    return out
end

-- ============================================================
-- MAIN TAB : AUTO EQUIP + AUTO PLACE (COMBINED)
-- ============================================================
MainTab:Section({
    Title = "Auto Brainrot",
    Desc = "Auto detects the strongest brainrot in your inventory, equips it, then places it into your podium slots.",
    Box = true,
    BoxBorder = true,
})

local BestParagraph = MainTab:Paragraph({
    Title = "Detected Best Brainrot",
    Desc = "Scanning...",
    Image = "gem",
    ImageSize = 20,
})

local function RefreshBestLabel()
    local best, list = GetBestBrainrot()
    if best then
        State.LastBest = best.Name
        local top = {}
        for i = 1, math.min(5, #list) do
            table.insert(top, string.format("%d. %s  (%s)", i, list[i].Name, tostring(math.floor(list[i].Score))))
        end
        BestParagraph:SetDesc("BEST: " .. best.Name .. "\n\nTop found:\n" .. table.concat(top, "\n"))
    else
        BestParagraph:SetDesc("No brainrot found in inventory.\n(Executor may not support getnilinstances)")
    end
    return best
end

MainTab:Button({
    Title = "Scan / Refresh Best Brainrot",
    Icon = "refresh-cw",
    Callback = function()
        local best = RefreshBestLabel()
        Notify("Scan Done", best and ("Best: " .. best.Name) or "Nothing found", 3)
    end
})

MainTab:Button({
    Title = "Equip Best Brainrot (Once)",
    Icon = "hand",
    Callback = function()
        local best = GetBestBrainrot()
        if best and EquipBrainrot(best) then
            Notify("Equipped", best.Name, 3)
        else
            Notify("Failed", "Could not equip best brainrot", 3)
        end
    end
})

MainTab:Toggle({
    Title = "Auto Equip Best Brainrot",
    Desc = "Keeps the highest value brainrot equipped",
    Icon = "gem",
    Default = false,
    Callback = function(v) State.AutoEquipBest = v end
})

MainTab:Slider({
    Title = "Equip Delay (s)",
    Step = 1,
    Value = { Min = 1, Max = 30, Default = 1 },
    Callback = function(v) State.EquipDelay = tonumber(v) or 1 end
})

MainTab:Divider()

MainTab:Section({
    Title = "Auto Place In Slot (Multi Slot)",
    Desc = "Equips best brainrot then places it. Cycles through every slot you list.",
    Box = true,
    BoxBorder = true,
})

MainTab:Input({
    Title = "Slots To Use",
    Desc = "Examples: all  |  1-8  |  1,2,3,5,9",
    Value = "1-10",
    Placeholder = "1-10",
    Callback = function(txt)
        State.SlotList = ParseSlotString(txt, State.MaxSlot)
        Notify("Slots Set", "#" .. #State.SlotList .. " slots", 2)
    end
})

MainTab:Slider({
    Title = "Max Slot (for 'all')",
    Step = 1,
    Value = { Min = 1, Max = 30, Default = 10 },
    Callback = function(v)
        State.MaxSlot = tonumber(v) or 10
    end
})

MainTab:Toggle({
    Title = "Auto Equip + Auto Place In Slot",
    Desc = "Combined: detect best -> equip -> place in next free slot",
    Icon = "layout-grid",
    Default = false,
    Callback = function(v)
        State.AutoPlace = v
        if v then State.PlacedNames = {} end
    end
})

MainTab:Slider({
    Title = "Place Delay (s)",
    Step = 1,
    Value = { Min = 1, Max = 30, Default = 1 },
    Callback = function(v) State.PlaceDelay = tonumber(v) or 1 end
})

MainTab:Button({
    Title = "Place Best In All Slots (Once)",
    Icon = "layout-grid",
    Callback = function()
        local placed = {}
        for _, slot in ipairs(State.SlotList) do
            local best = GetBestBrainrot(placed)
            if not best then break end
            EquipBrainrot(best)
            task.wait(0.35)
            PlaceInSlot(slot)
            table.insert(placed, best.Name)
            task.wait(0.35)
        end
        Notify("Done", "Placed " .. #placed .. " brainrot(s)", 3)
    end
})

MainTab:Button({
    Title = "Reset Placed Memory",
    Icon = "rotate-ccw",
    Callback = function()
        State.PlacedNames = {}
        Notify("Reset", "Placed list cleared", 2)
    end
})

MainTab:Divider()

-- ============================================================
-- MAIN TAB : AUTO COLLECT MONEY
-- ============================================================
MainTab:Section({
    Title = "Auto Collect Money (ALL Slots)",
    Desc = "Detects YOUR base by ownership only (never nearest). Fires CollectMoney for every podium index.\nIf no owned base is found, uses fixed slot range 1–CollectMax.",
    Box = true,
    BoxBorder = true,
})

local BaseParagraph = MainTab:Paragraph({
    Title = "Detected Base",
    Desc = "Not scanned yet",
    Image = "house",
    ImageSize = 20,
})

local function RefreshBaseLabel()
    local base = GetMyBase(true)
    local indexes = GetMyPodiumIndexes(base)
    if not base then
        BaseParagraph:SetDesc(
            "No owned base found (ownership only — no nearest fallback).\n" ..
            "Collect will use fixed range 1–" .. tostring((State and State.CollectMax) or 30) ..
            "\nIndexes: " .. table.concat(indexes, ", ")
        )
        return nil
    end
    BaseParagraph:SetDesc(
        "MY BASE: " .. base.Name ..
        "\nPodiums found: " .. #indexes ..
        (#indexes > 0 and ("\nIndexes: " .. table.concat(indexes, ", ")) or "")
    )
    return base
end

MainTab:Button({
    Title = "Detect My Base",
    Icon = "house",
    Callback = function()
        local base = RefreshBaseLabel()
        Notify("Base Detection", base and ("Your base: " .. base.Name) or "No base found", 4)
    end
})

MainTab:Toggle({
    Title = "Auto Collect ALL Money",
    Desc = "Fires CollectMoney for every podium in your owned base (or fixed range). No nearest-base fallback.",
    Icon = "coins",
    Default = false,
    Callback = function(v) State.AutoCollect = v end
})

MainTab:Slider({
    Title = "Collect Cycle Delay (s)",
    Desc = "Wait between full sweeps",
    Step = 1,
    Value = { Min = 1, Max = 60, Default = 1 },
    Callback = function(v) State.CollectDelay = tonumber(v) or 1 end
})

MainTab:Button({
    Title = "Collect ALL Now (Once)",
    Icon = "coins",
    Callback = function()
        local fired, total, baseName = CollectEverything(nil, 0.05)
        Notify("Collected", "Base " .. tostring(baseName) .. " — fired " .. fired .. "/" .. total .. " buttons", 4)
    end
})

MainTab:Button({
    Title = "Rescan Base (if you moved/rejoined)",
    Icon = "refresh-cw",
    Callback = function()
        State_MyBase = nil
        local base = RefreshBaseLabel()
        Notify("Rescanned", base and base.Name or "No base found", 3)
    end
})

-- ============================================================
-- INVENTORY TAB : LIST + MANUAL EQUIP
-- ============================================================
InventoryTab:Section({
    Title = "Inventory Scanner",
    Desc = "Lists every brainrot found in your inventory, ranked by value.",
    Box = true,
    BoxBorder = true,
})

local InvList = InventoryTab:Paragraph({
    Title = "Inventory",
    Desc = "Press Scan Inventory",
    Image = "list",
    ImageSize = 20,
})

local InvMap = {}   -- name -> entry
local InvDropdown

InventoryTab:Button({
    Title = "Scan Inventory",
    Icon = "search",
    Callback = function()
        local list = GetInventoryBrainrots()
        InvMap = {}
        local names, lines = {}, {}
        for i, e in ipairs(list) do
            local label = e.Name
            if InvMap[label] then label = e.Name .. " #" .. i end
            InvMap[label] = e
            table.insert(names, label)
            if i <= 15 then
                table.insert(lines, string.format("%d. %s  —  %s", i, e.Name, tostring(math.floor(e.Score))))
            end
        end
        InvList:SetDesc(#list == 0 and "Nothing found." or (table.concat(lines, "\n") .. "\n\nTotal: " .. #list))
        if InvDropdown and InvDropdown.Refresh then
            InvDropdown:Refresh(names)
        end
        Notify("Inventory", #list .. " item(s) found", 3)
    end
})

InvDropdown = InventoryTab:Dropdown({
    Title = "Select Brainrot",
    Values = {},
    Value = nil,
    Callback = function(sel) State.SelectedInv = sel end
})

InventoryTab:Button({
    Title = "Equip Selected",
    Icon = "hand",
    Callback = function()
        local e = State.SelectedInv and InvMap[State.SelectedInv]
        if e and EquipBrainrot(e) then
            Notify("Equipped", e.Name, 3)
        else
            Notify("Failed", "Select a brainrot first", 3)
        end
    end
})

InventoryTab:Dropdown({
    Title = "Place Selected Into Slot",
    Values = (function()
        local t = {}
        for i = 1, 30 do t[i] = tostring(i) end
        return t
    end)(),
    Value = "1",
    Callback = function(v) State.ManualSlot = tonumber(v) or 1 end
})

InventoryTab:Button({
    Title = "Place Selected In Chosen Slot",
    Icon = "layout-grid",
    Callback = function()
        local e = State.SelectedInv and InvMap[State.SelectedInv]
        if not e then Notify("Failed", "Select a brainrot first", 3) return end
        EquipBrainrot(e)
        task.wait(0.35)
        PlaceInSlot(State.ManualSlot or 1)
        Notify("Placed", e.Name .. " -> slot " .. tostring(State.ManualSlot or 1), 3)
    end
})

-- ============================================================
-- LOOPS
-- ============================================================
-- Auto Equip Best
task.spawn(function()
    while task.wait(0.5) do
        if State.AutoEquipBest then
            pcall(function()
                local best = GetBestBrainrot()
                if best and best.Name ~= State.LastEquipped then
                    if EquipBrainrot(best) then
                        State.LastEquipped = best.Name
                    end
                end
            end)
            task.wait(State.EquipDelay)
        end
    end
end)

-- Auto Equip + Place (multi slot cycle)
task.spawn(function()
    while task.wait(0.5) do
        if State.AutoPlace then
            pcall(function()
                for _, slot in ipairs(State.SlotList) do
                    if not State.AutoPlace then break end
                    local best = GetBestBrainrot(State.PlacedNames)
                    if not best then
                        State.PlacedNames = {}   -- nothing left, reset and rescan
                        break
                    end
                    EquipBrainrot(best)
                    task.wait(0.35)
                    PlaceInSlot(slot)
                    table.insert(State.PlacedNames, best.Name)
                    task.wait(State.PlaceDelay)
                end
            end)
            task.wait(State.PlaceDelay)
        end
    end
end)

-- Auto Collect
task.spawn(function()
    while task.wait(0.5) do
        if State.AutoCollect then
            pcall(function()
                local base = GetMyBase()
                local indexes = GetMyPodiumIndexes(base)
                for _, idx in ipairs(indexes) do
                    if not State.AutoCollect then break end
                    CollectSlot(idx)
                    task.wait(0.05)
                end
            end)
            task.wait(State.CollectDelay)
        end
    end
end)

-- Initial scan
task.spawn(function()
    task.wait(1)
    pcall(RefreshBestLabel)
end)

if not getnil then
    Notify("Warning", "Your executor has no getnilinstances — falling back to Backpack scan", 6)
end
if not HotbarEquipRemote or not PodiumRemote or not CollectMoneyRemote then
    Notify("Warning", "Some remotes not found in ReplicatedStorage.Remotes", 6)
end

print("elyxionHub loaded!")
