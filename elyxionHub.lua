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
    Title = "Open elyxionHub",
    Icon = "rbxassetid://135481314155653",
    CornerRadius = UDim.new(0, 16),
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
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

local InfoTab = Tabs.Info
local MainTab = Tabs.Main
local SettingsTab = Tabs.Settings

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Automatic Game Detection
local gameName = "Unknown"
local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if success and info then
    gameName = info.Name
end

-- ============================================================
-- ALL SETTING / STATE
-- ============================================================
local AfkFarmEnabled = false
local AutoItemEnabled = false
local AutoVoteEnabled = false
local FullbrightEnabled = false
local TargetMap = ""

local BhopSystemMaster = false
local AutoBhopEnabled = false
local BhopDelay = 0
local lastJumpTime = 0

local originalPosition = nil
local noItemTimer = 0
local savedAfkState = false
local savedCollectState = false
local savedVoteState = false
local isFakeMapDisabled = false

local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows
}

local itemPositionCache = {}
local nextbotCachePositions = {}
local lastNextbotCheck = 0

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
-- MAIN TAB (Features)
-- ============================================================
MainTab:Section({ Title = "Farm" })

local AfkToggle = MainTab:Toggle({
    Title = "Afk Farm",
    Desc = "Sky / Fly (Anchored up)",
    Value = false,
    Callback = function(state)
        local char = LocalPlayer.Character
        if char and char:GetAttribute("Downed") then return end
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        AfkFarmEnabled = state
        if noItemTimer < 15 then
            savedAfkState = AfkFarmEnabled
        end

        if AfkFarmEnabled then
            originalPosition = hrp.Position + Vector3.new(0, 200, 0)
            hrp.CFrame = CFrame.new(originalPosition)
            task.wait(0.1)
            hrp.Anchored = true
        else
            hrp.Anchored = false
        end
    end
})

local ItemToggle = MainTab:Toggle({
    Title = "Auto Tokens",
    Desc = "Auto farm tokens (safe from nextbots)",
    Value = false,
    Callback = function(state)
        local char = LocalPlayer.Character
        if char and char:GetAttribute("Downed") then return end
        AutoItemEnabled = state
        if not isFakeMapDisabled then
            savedCollectState = AutoItemEnabled
        end
    end
})

MainTab:Section({ Title = "Vote" })

local VoteToggle = MainTab:Toggle({
    Title = "Auto VoteMap",
    Desc = "Automatically vote for selected map",
    Value = false,
    Callback = function(state)
        AutoVoteEnabled = state
        savedVoteState = AutoVoteEnabled
    end
})

MainTab:Input({
    Title = "Target Map Name",
    Placeholder = "Example: Backrooms",
    Callback = function(text)
        TargetMap = string.lower(text)
    end
})

MainTab:Section({ Title = "Movement" })

local BhopToggle = MainTab:Toggle({
    Title = "Auto Jump (Bhop)",
    Desc = "Enable auto jump system",
    Value = false,
    Callback = function(state)
        BhopSystemMaster = state
        if not BhopSystemMaster then
            AutoBhopEnabled = false
        end
    end
})

MainTab:Slider({
    Title = "Bhop Delay",
    Desc = "Delay between jumps",
    Step = 0.05,
    Value = { Min = 0, Max = 1, Default = 0 },
    Callback = function(val)
        BhopDelay = val
    end
})

-- ============================================================
-- SETTINGS TAB
-- ============================================================
SettingsTab:Section({ Title = "Visual" })

local FullbrightToggle = SettingsTab:Toggle({
    Title = "Fullbright",
    Desc = "Brighten the entire map",
    Value = false,
    Callback = function(state)
        FullbrightEnabled = state
        if FullbrightEnabled then
            originalLighting.Ambient = Lighting.Ambient
            originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            originalLighting.Brightness = Lighting.Brightness
            originalLighting.ClockTime = Lighting.ClockTime
            originalLighting.FogEnd = Lighting.FogEnd
            originalLighting.GlobalShadows = Lighting.GlobalShadows

            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 999999
            Lighting.GlobalShadows = false
        else
            Lighting.Ambient = originalLighting.Ambient
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            Lighting.Brightness = originalLighting.Brightness
            Lighting.ClockTime = originalLighting.ClockTime
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.GlobalShadows = originalLighting.GlobalShadows
        end
    end
})

Lighting.Changed:Connect(function()
    if FullbrightEnabled then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 999999
        Lighting.GlobalShadows = false
    end
end)

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function getVoteSlotForMap(mapName)
    if mapName == "" then return nil end
    for _, v in pairs(PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") and v.Visible then
            local textLower = string.lower(v.Text)
            if string.find(textLower, mapName, 1, true) then
                local current = v
                while current and current ~= PlayerGui do
                    local num = tonumber(current.Name) or tonumber(string.match(current.Name, "%d+"))
                    if num and num >= 1 and num <= 4 then
                        return num
                    end
                    current = current.Parent
                end
            end
        end
    end
    return nil
end

local function isPlayerAsset(instance)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and instance:IsDescendantOf(player.Character) then
            return true
        end
    end
    return false
end

local function getAllItems()
    local items = {}
    local currentRawParts = {}

    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Model") then
            local nameLower = string.lower(v.Name)
            if string.find(nameLower, "bubble") then
                local isVisualEffect = v:FindFirstChildWhichIsA("ParticleEmitter")
                    or v:FindFirstChildWhichIsA("Trail")
                    or v:FindFirstChildWhichIsA("Beam")
                    or (v.ClassName == "Accessory")
                local hasAnimation = v:FindFirstChildWhichIsA("Animation") or v:FindFirstChildWhichIsA("Animator")

                if not isVisualEffect and not hasAnimation and not isPlayerAsset(v) then
                    local part = (v:IsA("BasePart") and v) or v:FindFirstChildWhichIsA("BasePart")
                    if part then
                        table.insert(currentRawParts, part)
                    end
                end
            end
        end
    end

    for _, part in ipairs(currentRawParts) do
        local partId = part:GetDebugId()
        local currentPos = part.Position
        local lastPos = itemPositionCache[partId]

        if lastPos then
            if (currentPos - lastPos).Magnitude <= 1 then
                table.insert(items, part)
            end
        else
            table.insert(items, part)
        end
        itemPositionCache[partId] = currentPos
    end

    for id, _ in pairs(itemPositionCache) do
        local found = false
        for _, part in ipairs(currentRawParts) do
            if part:GetDebugId() == id then
                found = true
                break
            end
        end
        if not found then
            itemPositionCache[id] = nil
        end
    end

    return items
end

local function updateNextbotCache()
    if (os.clock() - lastNextbotCheck) < 0.15 then return end
    lastNextbotCheck = os.clock()
    table.clear(nextbotCachePositions)

    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:GetAttribute("Nextbot") == true then
            local root = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")
            if root then
                table.insert(nextbotCachePositions, root.Position)
            end
        end
    end
end

local function isNextbotNear(position, range)
    range = range or 20
    updateNextbotCache()
    for _, nbotPos in ipairs(nextbotCachePositions) do
        if (position - nbotPos).Magnitude <= range then
            return true
        end
    end
    return false
end

local function getClosestSafeItem(hrp, items)
    local closest, minDst = nil, math.huge
    for _, part in ipairs(items) do
        local dst = (hrp.Position - part.Position).Magnitude
        if dst < minDst and not isNextbotNear(part.Position, 25) then
            closest = part
            minDst = dst
        end
    end
    return closest
end

local function safeTeleportTo(hrp, targetPos, duration)
    local startPos = hrp.Position
    local startTime = os.clock()
    local successMove = true

    while (os.clock() - startTime) < duration do
        local alpha = (os.clock() - startTime) / duration
        if alpha > 1 then alpha = 1 end
        local currentLerpPos = startPos:Lerp(targetPos, alpha)
        hrp.CFrame = CFrame.new(currentLerpPos)

        if isNextbotNear(hrp.Position, 22) or isNextbotNear(targetPos, 22) then
            successMove = false
            break
        end
        RunService.Heartbeat:Wait()
    end

    if successMove then
        hrp.CFrame = CFrame.new(targetPos)
    end
    return successMove
end

-- ============================================================
-- LOOPS
-- ============================================================

-- Auto Vote
task.spawn(function()
    while true do
        task.wait(1)
        if AutoVoteEnabled and TargetMap ~= "" then
            local slot = getVoteSlotForMap(TargetMap)
            if slot then
                pcall(function()
                    ReplicatedStorage.Events.Vote:FireServer(slot)
                end)
            end
        end
    end
end)

-- Auto Tokens + AFK logic
task.spawn(function()
    while true do
        local items = getAllItems()
        local char = LocalPlayer.Character
        local isDowned = char and char:GetAttribute("Downed")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        -- Anti Fake Map
        if #items > 50 then
            if not isFakeMapDisabled then
                isFakeMapDisabled = true
                AutoItemEnabled = false
                if ItemToggle then ItemToggle:Set(false) end
                WindUI:Notify({
                    Title = "Anti-Fake Map",
                    Content = "Detected broken map (>50 tokens). Auto Tokens disabled.",
                    Duration = 4
                })
            end
        elseif isFakeMapDisabled then
            isFakeMapDisabled = false
            AutoItemEnabled = savedCollectState
            if ItemToggle then ItemToggle:Set(savedCollectState) end
        end

        -- No item timer
        if #items == 0 then
            noItemTimer = noItemTimer + 0.5
            if noItemTimer >= 15 and AfkFarmEnabled and not isDowned then
                AfkFarmEnabled = false
                if AfkToggle then AfkToggle:Set(false) end
                if hrp then hrp.Anchored = false end
            end
        else
            noItemTimer = 0
            if savedAfkState and not AfkFarmEnabled and not isDowned then
                task.wait(0.5)
                local recheckItems = getAllItems()
                if #recheckItems > 0 and not (char and char:GetAttribute("Downed")) then
                    AfkFarmEnabled = true
                    if AfkToggle then AfkToggle:Set(true) end
                    if hrp then
                        originalPosition = hrp.Position + Vector3.new(0, 200, 0)
                        hrp.CFrame = CFrame.new(originalPosition)
                        task.wait(0.1)
                        hrp.Anchored = true
                    end
                end
            end
        end

        -- Collect tokens
        if AutoItemEnabled and not isDowned and #items > 0 and hrp and not isFakeMapDisabled then
            local item = getClosestSafeItem(hrp, items)
            if item and not isNextbotNear(item.Position, 25) and not isNextbotNear(hrp.Position, 25) then
                local startPos = hrp.Position
                hrp.Anchored = false
                local successMove = safeTeleportTo(hrp, item.Position, 0.12)

                if successMove and not isNextbotNear(hrp.Position, 22) then
                    pcall(function()
                        local collectId = item.Parent:GetAttribute("Id")
                            or item:GetAttribute("Id")
                            or "a19ac91bff904b7385e826fd6a23dc01"
                        ReplicatedStorage.Events.Interact:FireServer("Collect", collectId)
                    end)
                    task.wait(0.9)
                end

                isDowned = char and char:GetAttribute("Downed")
                if AutoItemEnabled and not isDowned and noItemTimer < 15 then
                    if AfkFarmEnabled and originalPosition then
                        safeTeleportTo(hrp, originalPosition, 0.1)
                        hrp.Anchored = true
                    else
                        safeTeleportTo(hrp, startPos, 0.1)
                    end
                end
            end
        end

        task.wait(1)
    end
end)

-- AFK safety (move higher if nextbot near)
task.spawn(function()
    while true do
        task.wait(0.1)
        local char = LocalPlayer.Character
        local isDowned = char and char:GetAttribute("Downed")
        if AfkFarmEnabled and not isDowned and originalPosition then
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and isNextbotNear(hrp.Position, 25) then
                hrp.Anchored = false
                originalPosition = originalPosition + Vector3.new(0, 80, 0)
                hrp.CFrame = CFrame.new(originalPosition)
                task.wait(0.05)
                hrp.Anchored = true
            end
        end
    end
end)

-- Re-anchor AFK if somehow unanchored
task.spawn(function()
    while true do
        task.wait(2)
        local char = LocalPlayer.Character
        local isDowned = char and char:GetAttribute("Downed")
        if AfkFarmEnabled and not AutoItemEnabled and not isDowned and noItemTimer < 15 then
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Anchored == false then
                originalPosition = hrp.Position + Vector3.new(0, 200, 0)
                hrp.CFrame = CFrame.new(originalPosition)
                task.wait(0.1)
                hrp.Anchored = true
            end
        end
    end
end)

-- Bhop
RunService.Heartbeat:Connect(function()
    if not BhopSystemMaster or not AutoBhopEnabled then return end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            if (os.clock() - lastJumpTime) >= BhopDelay then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                lastJumpTime = os.clock()
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space and BhopSystemMaster then
        AutoBhopEnabled = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space and BhopSystemMaster then
        AutoBhopEnabled = false
    end
end)

-- Character handling (Downed)
local function setupCharacter(char)
    char:GetAttributeChangedSignal("Downed"):Connect(function()
        local isDowned = char:GetAttribute("Downed")
        local hrp = char:FindFirstChild("HumanoidRootPart")

        if isDowned then
            AutoItemEnabled = false
            AfkFarmEnabled = false
            if ItemToggle then ItemToggle:Set(false) end
            if AfkToggle then AfkToggle:Set(false) end
            if hrp then hrp.Anchored = false end
        else
            task.wait(1)
            if hrp then
                originalPosition = hrp.Position + Vector3.new(0, 200, 0)
                hrp.CFrame = CFrame.new(originalPosition)
                task.wait(0.2)
                hrp.Anchored = true
                AfkFarmEnabled = savedAfkState
                if not isFakeMapDisabled then
                    AutoItemEnabled = savedCollectState
                end
                if AfkToggle then AfkToggle:Set(savedAfkState) end
                if ItemToggle and not isFakeMapDisabled then
                    ItemToggle:Set(savedCollectState)
                end
            end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(setupCharacter)
if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end

-- Anti AFK kick
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

print("elyxionHub loaded!")
