

if getgenv().__FantasyLoaded then
    pcall(getgenv().__FantasyLoaded)
    task.wait(0.1)
end

getgenv().__FantasyLoaded = function()
    if getgenv().__FantasyLibrary then
        pcall(function() getgenv().__FantasyLibrary:Unload() end)
    end
    getgenv().__FantasyLoaded  = nil
    getgenv().__FantasyLibrary = nil
end

local LIBRARY_CHOICE = getgenv().__FantasyLib or "Obsidian"

local LIB_URLS = {
    Obsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua",
    Linoria  = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
                --https://github.com/mstudio45/LinoriaLib/blob/main/Library.lua
}
local THEME_URLS = {
    Obsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua",
    Linoria  = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua",
}
local SAVE_URLS = {
    Obsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua",
    Linoria  = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua",
}

local Library = loadstring(game:HttpGet(LIB_URLS[LIBRARY_CHOICE] or LIB_URLS.Obsidian))()

getgenv().__FantasyLibrary = Library

local Toggles = Library.Toggles
local Options  = Library.Options

local Window = Library:CreateWindow({
    Title      = "Fantasy",
    Center     = true,
    AutoShow   = true,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

-- Tabs stay exactly as they were: Game / Fun / Hitbox / Settings
local Tabs = {
    Game    = Window:AddTab("Game",    "activity"),
    Fun     = Window:AddTab("Fun",     "party-popper"),
    Hitbox  = Window:AddTab("Hitbox",  "crosshair"),
    Settings = Window:AddTab("Settings", "settings"),
}

----------------------------------------------------------------
-- Core services / helpers
----------------------------------------------------------------

local Players    = game:GetService("Players")
local Lighting   = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player     = Players.LocalPlayer

local function Notify(opts)
    pcall(function() Library:Notify(opts) end)
end

local function safeReadFile(path)
    if not (isfile and readfile) then return nil end
    local ok, val = pcall(function() return isfile(path) and readfile(path) end)
    return ok and val or nil
end
local saveSettingsEnabled = safeReadFile("Fantasy/save_settings") ~= "false"

----------------------------------------------------------------
-- Loadstring cache system (used by "External Tools" in Settings)
----------------------------------------------------------------

local SCRIPT_CACHE = {
    RemoteSpy = { name = "Remote Spy",              url = "https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua", path = "Fantasy/cache/RemoteSpy.lua" },
    Adonis    = { name = "Adonis Anticheat Bypass", url = "https://raw.githubusercontent.com/3a6ey/testadonis/refs/heads/main/test.lua", path = "Fantasy/cache/AdonisBypass.lua" },
    IY        = { name = "Infinite Yield",          url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",       path = "Fantasy/cache/InfiniteYield.lua" },
    Dex       = { name = "Dex Explorer",            url = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua",              path = "Fantasy/cache/Dex.lua" },
    Cobalt    = { name = "Remote Spy Cobalt",       url = "https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau",    path = "Fantasy/cache/Cobalt.lua" },
    Fly       = { name = "Fly",                     url = "https://raw.githubusercontent.com/3a6ey/the-streets/refs/heads/main/fly.lua", path = "Fantasy/cache/Fly.lua" },
}

local cacheEnabled   = (isfile and readfile and isfile("Fantasy/cache_enabled")  and readfile("Fantasy/cache_enabled")  == "true") or false
local alwaysCheckUpd = (isfile and readfile and isfile("Fantasy/always_check_upd") and readfile("Fantasy/always_check_upd") == "true") or false

local function canCache()
    return isfile and writefile and makefolder and true or false
end

local function ensureCacheFolder()
    if not makefolder then return end
    pcall(makefolder, "Fantasy")
    pcall(makefolder, "Fantasy/cache")
end

local function getCached(key)
    if not canCache() then return nil end
    local entry = SCRIPT_CACHE[key]
    if not entry then return nil end
    local ok, content = pcall(function()
        return isfile(entry.path) and readfile(entry.path) or nil
    end)
    return ok and content or nil
end

local function saveCache(key, content)
    if not canCache() then return end
    ensureCacheFolder()
    local entry = SCRIPT_CACHE[key]
    if entry then pcall(writefile, entry.path, content) end
end

local function fetchRemote(url)
    local ok, content = pcall(game.HttpGet, game, url)
    return ok and content or nil
end

local function loadScript(key)
    local entry = SCRIPT_CACHE[key]
    if not entry then return end
    local content = nil
    if cacheEnabled and canCache() then
        local cached = getCached(key)
        if cached then
            if alwaysCheckUpd then
                local remote = fetchRemote(entry.url)
                if remote and remote ~= cached then
                    saveCache(key, remote)
                    content = remote
                    Notify({ Title = entry.name, Description = "Updated from remote", Duration = 3 })
                else
                    content = cached
                end
            else
                content = cached
            end
        else
            content = fetchRemote(entry.url)
            if content then
                saveCache(key, content)
                Notify({ Title = entry.name, Description = "Cached for next time", Duration = 2 })
            end
        end
    else
        content = fetchRemote(entry.url)
    end
    if content then
        local ok, err = pcall(loadstring(content))
        if not ok then
            Notify({ Title = entry.name, Description = "Failed: " .. tostring(err), Duration = 5 })
        end
    else
        Notify({ Title = entry.name, Description = "Failed to load", Duration = 4 })
    end
end

player.Idled:Connect(function()
    setthreadcontext(8)
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

----------------------------------------------------------------
-- SHARED STATE — used by both the Hitbox tab and the Fun tab.
----------------------------------------------------------------

local killAuraNPCs = {}
local playerChars  = {}

local function rebuildPlayerChars()
    table.clear(playerChars)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then playerChars[p.Character] = true end
        p.CharacterAdded:Connect(function(c) playerChars[c] = true end)
        p.CharacterRemoving:Connect(function(c) playerChars[c] = nil end)
    end
end
rebuildPlayerChars()
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) playerChars[c] = true end)
    p.CharacterRemoving:Connect(function(c) playerChars[c] = nil end)
end)

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then
        local model = obj.Parent
        if model and model:IsA("Model") and not playerChars[model] then
            killAuraNPCs[model] = true
        end
    end
end)
workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Humanoid") then
        local ok, parent = pcall(function() return obj.Parent end)
        if ok and parent then killAuraNPCs[parent] = nil end
    end
end)
task.spawn(function()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") then
            local model = obj.Parent
            if model and model:IsA("Model") and not playerChars[model] then
                killAuraNPCs[model] = true
            end
        end
    end
end)

----------------------------------------------------------------
-- ============================================================
-- GAME TAB
-- ============================================================
----------------------------------------------------------------

local GameLeft    = Tabs.Game:AddLeftGroupbox("Visual",      "eye")
local GameLoadBox = Tabs.Game:AddLeftGroupbox("Loadstrings", "code")
local GameRight   = Tabs.Game:AddRightGroupbox("Utility",    "settings")

local brightLoop
local noFogLoop
local infJump = UIS.InputBegan:Connect(function(input, gpe)
    if gpe or input.KeyCode ~= Enum.KeyCode.Space then return end
    if not (Toggles.InfiniteJumpToggle and Toggles.InfiniteJumpToggle.Value) then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

GameLeft:AddButton({
    Text = "Full Bright",
    Func = function()
        Lighting.Brightness     = 2
        Lighting.ClockTime      = 14
        Lighting.FogEnd         = 100000
        Lighting.GlobalShadows  = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end,
})
GameLeft:AddToggle("LoopFBToggle", {
    Text    = "Loop FullBright",
    Default = false,
    Callback = function(v)
        if v then
            if brightLoop then brightLoop:Disconnect() end
            brightLoop = RunService.RenderStepped:Connect(function()
                Lighting.Brightness     = 2
                Lighting.ClockTime      = 14
                Lighting.FogEnd         = 100000
                Lighting.GlobalShadows  = false
                Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            end)
        else
            if brightLoop then brightLoop:Disconnect(); brightLoop = nil end
        end
    end,
})
GameLeft:AddButton({
    Text = "No Fog",
    Func = function()
        pcall(function()
            Lighting.FogEnd = 100000
            for _, v in pairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v:Destroy() end
            end
        end)
    end,
})
GameLeft:AddToggle("LoopNoFogToggle", {
    Text    = "Loop No Fog",
    Default = false,
    Callback = function(v)
        if v then
            if noFogLoop then noFogLoop:Disconnect() end
            local alive = true
            noFogLoop = { Disconnect = function() alive = false end }
            task.spawn(function()
                while alive do
                    Lighting.FogEnd   = 100000
                    Lighting.FogStart = 100000
                    task.wait(0.5)
                end
            end)
        else
            if noFogLoop then noFogLoop:Disconnect(); noFogLoop = nil end
        end
    end,
})
GameLeft:AddButton({
    Text = "Apply Shader",
    Func = function()
        local light = game.Lighting
        for _, v in ipairs(light:GetChildren()) do pcall(function() v:Destroy() end) end
        local ter   = workspace.Terrain
        local color = Instance.new("ColorCorrectionEffect")
        local bloom = Instance.new("BloomEffect")
        local sun   = Instance.new("SunRaysEffect")
        local blur  = Instance.new("BlurEffect")
        color.Parent = light; bloom.Parent = light; sun.Parent = light; blur.Parent = light
        color.Enabled = true; color.Contrast = 0.15; color.Brightness = 0.1
        color.Saturation = 0.25; color.TintColor = Color3.fromRGB(255, 222, 211)
        bloom.Enabled = true; bloom.Intensity = 0.05; bloom.Size = 32; bloom.Threshold = 1
        sun.Enabled = true; sun.Intensity = 0.2; sun.Spread = 1
        blur.Enabled = false; blur.Size = 6
        ter.WaterColor = Color3.fromRGB(10, 10, 24); ter.WaterWaveSize = 0.15
        ter.WaterWaveSpeed = 22; ter.WaterTransparency = 1; ter.WaterReflectance = 0.05
        light.Ambient = Color3.fromRGB(0, 0, 0); light.Brightness = 4
        light.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
        light.ColorShift_Top = Color3.fromRGB(0, 0, 0)
        light.ExposureCompensation = 0; light.FogColor = Color3.fromRGB(132, 132, 132)
        light.GlobalShadows = true; light.OutdoorAmbient = Color3.fromRGB(112, 117, 128)
        light.Outlines = false
    end,
})

GameLoadBox:AddButton({ Text = "Infinite Yield",    DoubleClick = true, Func = function() task.spawn(function() loadScript("IY") end) end })
GameLoadBox:AddButton({ Text = "Dex Explorer",      DoubleClick = true, Func = function() task.spawn(function() loadScript("Dex") end) end })
GameLoadBox:AddButton({ Text = "Remote Spy Cobalt", DoubleClick = true, Func = function() task.spawn(function() loadScript("Cobalt") end) end })
GameLoadBox:AddButton({ Text = "Remote Spy",        DoubleClick = true, Func = function() task.spawn(function() loadScript("RemoteSpy") end) end })
GameLoadBox:AddButton({
    Text = "Anti-Fling",
    DoubleClick = true,
    Func = function()
        local RS = game:GetService("RunService")
        local PLR = game:GetService("Players")
        local function watchPlayer(p)
            if p == player then return end
            local det, charParts = false, {}
            local char, hrp
            local function onChar(c)
                char = c; det = false; table.clear(charParts)
                repeat task.wait() hrp = c:FindFirstChild("HumanoidRootPart") until hrp
                for _, part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then charParts[#charParts+1] = part end
                end
            end
            onChar(p.Character or p.CharacterAdded:Wait())
            p.CharacterAdded:Connect(onChar)
            local zero = Vector3.zero
            local pp   = PhysicalProperties.new(0,0,0)
            RS.Heartbeat:Connect(function()
                if not (char and char:IsDescendantOf(workspace)) then return end
                if not (hrp and hrp:IsDescendantOf(char)) then return end
                if hrp.AssemblyAngularVelocity.Magnitude > 50 or hrp.AssemblyLinearVelocity.Magnitude > 100 then
                    if not det then
                        pcall(game.StarterGui.SetCore, game.StarterGui, "ChatMakeSystemMessage", {
                            Text = "Fling detected: " .. p.Name, Color = Color3.fromRGB(255, 200, 0)
                        })
                        det = true
                    end
                    for i = 1, #charParts do
                        local part = charParts[i]
                        if part and part.Parent then
                            part.CanCollide = false
                            part.AssemblyAngularVelocity = zero
                            part.AssemblyLinearVelocity  = zero
                            part.CustomPhysicalProperties = pp
                        end
                    end
                end
            end)
        end
        for _, p in ipairs(PLR:GetPlayers()) do watchPlayer(p) end
        PLR.PlayerAdded:Connect(watchPlayer)
        local lastPos
        RS.Heartbeat:Connect(function()
            local char = player.Character
            local hrp  = char and char.PrimaryPart
            if not hrp then return end
            if hrp.AssemblyLinearVelocity.Magnitude > 250 or hrp.AssemblyAngularVelocity.Magnitude > 250 then
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.AssemblyLinearVelocity  = Vector3.zero
                if lastPos then hrp.CFrame = lastPos end
                pcall(game.StarterGui.SetCore, game.StarterGui, "ChatMakeSystemMessage", {
                    Text = "You were flung. Neutralized.", Color = Color3.fromRGB(255, 0, 0)
                })
            elseif hrp.AssemblyLinearVelocity.Magnitude < 50 then
                lastPos = hrp.CFrame
            end
        end)
        Notify({ Title = "Anti-Fling", Description = "Active", Duration = 3 })
    end,
})

----------------------------------------------------------------
-- CHANGED: "Max Zoom + NoCam" was a one-shot Button before — you had
-- to click it every time you respawned or the game reset your zoom
-- distance, and there was no way to turn the constant-max-zoom setter
-- back off. It's now a Toggle: ON continuously re-applies max zoom +
-- disables the camera "pop-in" (via the Popper constant patch) every
-- Heartbeat, and turning it OFF restores the original zoom distance
-- and re-enables normal camera collision so the game behaves normally
-- again without needing a rejoin.
----------------------------------------------------------------

local noCamZoomCon = nil
local noCamOrigMaxZoom = player.CameraMaxZoomDistance
local noCamPopperPatched = {}   -- tracks which functions we've flipped, so toggling off can restore them exactly

local function patchPopperConstants(disable)
    -- The Popper module is what pulls your camera in when something
    -- gets between it and your character. Its "0.25" / "0" constants
    -- are the pop distance switch; swapping them disables/enables that
    -- pull-in behavior. Wrapped in pcall since getgc/getconstants/
    -- setconstant aren't guaranteed on every executor.
    local sc = (debug and debug.setconstant) or setconstant
    local gc = (debug and debug.getconstants) or getconstants
    if not (sc and getgc and gc) then return end
    pcall(function()
        local playerScripts = player:FindFirstChild("PlayerScripts")
        local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
        local camModule = module and module:FindFirstChild("CameraModule")
        local zoomController = camModule and camModule:FindFirstChild("ZoomController")
        local pop = zoomController and zoomController:FindFirstChild("Popper")
        if not pop then return end
        for _, v in pairs(getgc()) do
            if type(v) == "function" and getfenv(v).script == pop then
                for i, v1 in pairs(gc(v)) do
                    if disable then
                        if tonumber(v1) == 0.25 then
                            noCamPopperPatched[v] = noCamPopperPatched[v] or {}
                            noCamPopperPatched[v][i] = 0.25
                            sc(v, i, 0)
                        end
                    else
                        if noCamPopperPatched[v] and noCamPopperPatched[v][i] ~= nil then
                            sc(v, i, noCamPopperPatched[v][i])
                        end
                    end
                end
            end
        end
    end)
    if not disable then noCamPopperPatched = {} end
end

GameRight:AddToggle("NoCamMaxZoomToggle", {
    Text = "Max Zoom + NoCam",
    Default = false,
    Tooltip = "Continuously keeps max zoom distance and disables camera pop-in",
    Callback = function(v)
        if v then
            pcall(function() player.CameraMaxZoomDistance = 999999 end)
            patchPopperConstants(true)
            if noCamZoomCon then noCamZoomCon:Disconnect() end
            -- re-apply every Heartbeat: some games reset CameraMaxZoomDistance
            -- on respawn or on a timer, so a one-shot set isn't enough to
            -- keep this "on" the way a toggle implies
            noCamZoomCon = RunService.Heartbeat:Connect(function()
                if player.CameraMaxZoomDistance ~= 999999 then
                    pcall(function() player.CameraMaxZoomDistance = 999999 end)
                end
            end)
        else
            if noCamZoomCon then noCamZoomCon:Disconnect(); noCamZoomCon = nil end
            pcall(function() player.CameraMaxZoomDistance = noCamOrigMaxZoom end)
            patchPopperConstants(false)
        end
    end,
})

GameRight:AddToggle("InfiniteJumpToggle", {
    Text = "Infinite Jump", Default = false,
})

GameRight:AddButton({
    Text = "Third Person",
    Func = function()
        pcall(function()
            player.CameraMode            = Enum.CameraMode.Classic
            player.CameraMaxZoomDistance = 555
            player.CameraMinZoomDistance = 0.5
        end)
    end,
})
local autoJumpAlive = false
GameRight:AddToggle("AutoJumpToggle", {
    Text = "Infinite Jump (Hold)", Default = false,
    Callback = function(v)
        autoJumpAlive = v
        if v then
            task.spawn(function()
                while autoJumpAlive do
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then
                        local char = player.Character
                        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
                        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                    end
                    task.wait(0.05)
                end
            end)
        end
    end,
})

----------------------------------------------------------------
-- NEW: Instant Proximity Prompts — fires ProximityPrompts the moment
-- they're interactable instead of waiting out their HoldDuration.
-- Uses the executor-native fireproximityprompt when available (fires
-- the prompt exactly as if held for its full duration, safest/most
-- compatible option); falls back to zeroing HoldDuration on every
-- prompt in the workspace (present and future) when that function
-- isn't exposed. Also patches a common "CircleAction" timed-hold UI
-- module via hookfunction, matching the same instant-press pattern,
-- if the game happens to use that module — wrapped entirely in pcall
-- so games that don't have it are completely unaffected.
----------------------------------------------------------------

local instantPromptState = {
    promptCon       = nil,   -- PromptButtonHoldBegan connection (fireproximityprompt path)
    descendantCon   = nil,   -- DescendantAdded connection (fallback path)
    patchedPrompts  = {},    -- [prompt] = originalHoldDuration, for the fallback path
    circleHookOn    = false,
}

local function instantPrompts_Enable()
    if fireproximityprompt then
        if instantPromptState.promptCon then return end
        instantPromptState.promptCon = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
            fireproximityprompt(prompt)
        end)
    else
        -- Fallback: force every prompt's hold time to 0 so the built-in
        -- hold-to-interact system finishes instantly on its own. Original
        -- durations are recorded so they can be restored on disable.
        local function zeroDelay(instance)
            if instance:IsA("ProximityPrompt") and instantPromptState.patchedPrompts[instance] == nil then
                instantPromptState.patchedPrompts[instance] = instance.HoldDuration
                instance.HoldDuration = 0
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            zeroDelay(obj)
        end
        if not instantPromptState.descendantCon then
            instantPromptState.descendantCon = workspace.DescendantAdded:Connect(zeroDelay)
        end
    end

    -- Optional CircleAction hook: some games gate timed hold-actions
    -- through a ReplicatedStorage.Module.UI module instead of (or in
    -- addition to) ProximityPrompt. This mirrors the same "skip the
    -- timer" idea for that specific pattern, but only activates if the
    -- module actually exists — harmless no-op everywhere else.
    if not instantPromptState.circleHookOn then
        local success, CircleAction = pcall(function()
            local moduleFolder = ReplicatedStorage:FindFirstChild("Module")
            if moduleFolder then
                local uiModule = moduleFolder:FindFirstChild("UI")
                if uiModule then
                    return require(uiModule).CircleAction
                end
            end
        end)
        if success and type(CircleAction) == "table" and CircleAction.Press and hookfunction then
            local oldPress
            local await
            local ok = pcall(function()
                oldPress = hookfunction(CircleAction.Press, newcclosure and newcclosure(function(...)
                    local action = CircleAction.Spec
                    if action and action.Timed and not (action.ReleaseCallback or action.ShouldHotwire or await) then
                        local originalTimed = action.Timed
                        action.Timed = false
                        await = task.defer(function()
                            action.Timed = originalTimed
                            await = nil
                        end)
                    end
                    return oldPress(...)
                end) or function(...)
                    local action = CircleAction.Spec
                    if action and action.Timed and not (action.ReleaseCallback or action.ShouldHotwire or await) then
                        local originalTimed = action.Timed
                        action.Timed = false
                        await = task.defer(function()
                            action.Timed = originalTimed
                            await = nil
                        end)
                    end
                    return oldPress(...)
                end)
            end)
            instantPromptState.circleHookOn = ok
        end
    end
end

local function instantPrompts_Disable()
    if instantPromptState.promptCon then
        instantPromptState.promptCon:Disconnect()
        instantPromptState.promptCon = nil
    end
    if instantPromptState.descendantCon then
        instantPromptState.descendantCon:Disconnect()
        instantPromptState.descendantCon = nil
    end
    -- restore every HoldDuration we changed via the fallback path
    for prompt, originalDuration in pairs(instantPromptState.patchedPrompts) do
        pcall(function()
            if prompt and prompt.Parent then
                prompt.HoldDuration = originalDuration
            end
        end)
    end
    table.clear(instantPromptState.patchedPrompts)
    -- Note: the CircleAction hookfunction patch is intentionally left in
    -- place once applied (hookfunction's returned original can be used to
    -- unhook on executors that support it, but there's no universal
    -- unhook guarantee across executors) — its internal Timed flag only
    -- ever forces `false` at the instant of a press and restores itself
    -- via task.defer either way, so leaving it connected has no visible
    -- effect once the toggle is off.
end

GameRight:AddToggle("InstantProximityPromptsToggle", {
    Text = "Instant Proximity Prompts",
    Default = false,
    Tooltip = "Skips ProximityPrompt hold time so prompts fire instantly",
    Callback = function(v)
        if v then
            instantPrompts_Enable()
        else
            instantPrompts_Disable()
        end
    end,
})

local GameMove = Tabs.Game:AddRightGroupbox("Movement", "wind")

local noclipCon     = nil
local noclipCharCon = nil
local noclipParts   = {}

local function buildNoclipParts()
    table.clear(noclipParts)
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then noclipParts[#noclipParts + 1] = part end
    end
end

local flySpeed   = 1
local flyCharCon = nil

local function startFly()
    _G.Speed = flySpeed
    task.spawn(function() loadScript("Fly") end)
end

GameMove:AddToggle("FlyToggle", {
    Text = "Fly", Default = false,
    Callback = function(v)
        if v then
            startFly()
            flyCharCon = player.CharacterAdded:Connect(function()
                if not (Toggles.FlyToggle and Toggles.FlyToggle.Value) then return end
                task.wait(0.1); startFly()
            end)
        else
            if flyCharCon then flyCharCon:Disconnect(); flyCharCon = nil end
            _G.Speed = 0
            task.wait(0.1)
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChildOfClass("BodyGyro") or obj:FindFirstChildOfClass("BodyVelocity") then
                    obj:Destroy()
                end
            end
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end,
}):AddKeyPicker("FlyKeybind", {
    Default = "None", Text = "Fly Keybind", NoUI = false, Mode = "Toggle",
    Callback = function(v)
        if Toggles.FlyToggle then Toggles.FlyToggle:SetValue(v) end
    end,
})
GameMove:AddSlider("FlySpeedSlider", {
    Text = "Fly Speed", Min = 1, Max = 50, Default = 1, Rounding = 0,
    Callback = function(v)
        flySpeed = v; _G.Speed = v
        if Toggles.FlyToggle and Toggles.FlyToggle.Value then
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChildOfClass("BodyGyro") or obj:FindFirstChildOfClass("BodyVelocity") then
                    obj:Destroy()
                end
            end
            task.wait(0.05); startFly()
        end
    end,
})

local walkSpeedEnabled = false
local walkSpeedCon     = nil
local customWalkSpeed  = 16

local function applyWalkSpeed(hum)
    if not hum then return end
    if sethiddenproperty then
        pcall(sethiddenproperty, hum, "WalkSpeed", customWalkSpeed)
    else
        hum.WalkSpeed = customWalkSpeed
    end
end

local function hookWalkSpeed(hum)
    -- prevent game from resetting WalkSpeed via __newindex hook
    if hookmetamethod and getrawmetatable then
        pcall(function()
            local mt = getrawmetatable(hum)
            local old = mt.__newindex
            mt.__newindex = newcclosure and newcclosure(function(self, k, v)
                if k == "WalkSpeed" and walkSpeedEnabled and self == hum then
                    old(self, k, customWalkSpeed)
                else
                    old(self, k, v)
                end
            end) or function(self, k, v)
                if k == "WalkSpeed" and walkSpeedEnabled and self == hum then
                    old(self, k, customWalkSpeed)
                else
                    old(self, k, v)
                end
            end
        end)
    end
end

local noAccelCon     = nil

GameMove:AddToggle("WalkSpeedToggle", {
    Text = "Change WalkSpeed", Default = false,
    Callback = function(v)
        walkSpeedEnabled = v
        if v then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hookWalkSpeed(hum); applyWalkSpeed(hum) end
            walkSpeedCon = RunService.Heartbeat:Connect(function()
                local char = player.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum then applyWalkSpeed(hum) end
            end)
            player.CharacterAdded:Connect(function(char)
                if not walkSpeedEnabled then return end
                local hum = char:WaitForChild("Humanoid", 5)
                if hum then hookWalkSpeed(hum); applyWalkSpeed(hum) end
            end)
        else
            if walkSpeedCon then walkSpeedCon:Disconnect(); walkSpeedCon = nil end
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})

GameMove:AddToggle("NoAccelToggle", {
    Text = "No Acceleration",
    Default = false,
    Tooltip = "Instant max speed (WalkSpeed based)",

    Callback = function(v)
        if v then
            noAccelCon = RunService.RenderStepped:Connect(function()
                if not walkSpeedEnabled then return end

                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then return end

                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    local dir = moveDir.Unit

                    hrp.AssemblyLinearVelocity = Vector3.new(
                        dir.X * customWalkSpeed,
                        hrp.AssemblyLinearVelocity.Y,
                        dir.Z * customWalkSpeed
                    )
                end
            end)
        else
            if noAccelCon then
                noAccelCon:Disconnect()
                noAccelCon = nil
            end
        end
    end,
})

GameMove:AddSlider("WalkSpeedSlider", {
    Text = "Walk Speed", Min = 1, Max = 1000, Default = 16, Rounding = 0,
    Callback = function(v)
        customWalkSpeed = v
        if walkSpeedEnabled then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then applyWalkSpeed(hum) end
        end
    end,
})
GameMove:AddInput("WalkSpeedInput", {
    Text = "Walk Speed (type)", Default = "16", Numeric = true, Placeholder = "any value",
    Callback = function(v)
        local n = tonumber(v); if not n then return end
        customWalkSpeed = math.max(1, math.floor(n))
        if walkSpeedEnabled then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then applyWalkSpeed(hum) end
        end
    end,
})

----------------------------------------------------------------
-- CHANGED: CFrame Speed and CFrame Fly used to share ONE slider
-- (customCFSpeed, default 50) even though they're two different
-- movement modes — cranking speed for one silently changed the other
-- too. They now have fully independent sliders:
--   CFrame Speed -> customCFSpeedValue,     default 50  (ground-based)
--   CFrame Fly   -> customCFFlySpeedValue,  default 100 (free-flight)
--
-- CFrame Fly also used to slowly sink because nothing ever cancelled
-- gravity/vertical drift between input ticks — only the four/six
-- direction keys added velocity, but nothing zeroed out the falling
-- motion the Humanoid state machine still wanted to apply in between.
-- Fix: every tick we now explicitly hold Y-velocity at 0 whenever the
-- player isn't pressing Space/Ctrl, instead of only ever *adding*
-- upward or downward offsets on top of whatever residual fall speed
-- was already there.
----------------------------------------------------------------

local cfSpeedCon        = nil
local customCFSpeedValue = 50

GameMove:AddToggle("CFSpeedToggle", {
    Text = "CFrame Speed",
    Default = false,

    Callback = function(v)
        if v then
            cfSpeedCon = RunService.RenderStepped:Connect(function()
                local char = player.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local cam = workspace.CurrentCamera
                local moveDir = Vector3.zero

                if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end

                if moveDir.Magnitude > 0 then
                    local flat = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                    hrp.CFrame += flat * (customCFSpeedValue * 0.016)
                end
            end)
        else
            if cfSpeedCon then
                cfSpeedCon:Disconnect()
                cfSpeedCon = nil
            end
        end
    end,
})
GameMove:AddSlider("CFSpeedSlider", {
    Text = "CFrame Speed", Min = 1, Max = 500, Default = 50, Rounding = 0,
    Callback = function(v) customCFSpeedValue = v end,
})
GameMove:AddInput("CFSpeedInput", {
    Text = "CFrame Speed (type)", Default = "50", Numeric = true, Placeholder = "any value",
    Callback = function(v)
        local n = tonumber(v); if not n then return end
        customCFSpeedValue = math.max(1, math.floor(n))
    end,
})

local cfFlyCon           = nil
local customCFFlySpeedValue = 100

GameMove:AddToggle("CFFlyToggle", {
    Text = "CFrame Fly",
    Default = false,
    Tooltip = "Smooth fly (no gravity, no jumping)",

    Callback = function(v)
        if v then
            cfFlyCon = RunService.RenderStepped:Connect(function()
                local char = player.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then return end

                -- FIX: zero out linear + angular velocity every tick,
                -- unconditionally, BEFORE reading input. This is what
                -- actually stops the slow downward drift — previously
                -- velocity was only zeroed once at toggle-on, so the
                -- Physics humanoid state still accumulated a falling
                -- velocity between RenderStepped ticks that the offset
                -- below never fully cancelled out.
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Physics)

                local cam = workspace.CurrentCamera
                local moveDir = Vector3.zero

                -- WASD
                if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end

                -- Up / Down
                if UIS:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir += Vector3.new(0, 1, 0)
                end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                    moveDir -= Vector3.new(0, 1, 0)
                end

                -- Movement — note this uses customCFFlySpeedValue now,
                -- fully independent from CFrame Speed's slider.
                if moveDir.Magnitude > 0 then
                    local dir = moveDir.Unit
                    hrp.CFrame = hrp.CFrame + dir * (customCFFlySpeedValue * 0.016)
                end
                -- when moveDir is zero (no keys held) we intentionally do
                -- nothing further here: velocity was already zeroed above,
                -- so the player holds position exactly instead of drifting
                -- or sinking.
            end)
        else
            if cfFlyCon then
                cfFlyCon:Disconnect()
                cfFlyCon = nil
            end

            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end,
})
GameMove:AddSlider("CFFlySpeedSlider", {
    Text = "CFrame Fly Speed", Min = 1, Max = 500, Default = 100, Rounding = 0,
    Callback = function(v) customCFFlySpeedValue = v end,
})
GameMove:AddInput("CFFlySpeedInput", {
    Text = "CFrame Fly Speed (type)", Default = "100", Numeric = true, Placeholder = "any value",
    Callback = function(v)
        local n = tonumber(v); if not n then return end
        customCFFlySpeedValue = math.max(1, math.floor(n))
    end,
})

GameMove:AddDivider()
GameMove:AddToggle("NoclipToggle", {
    Text = "Noclip", Default = false,
    Callback = function(v)
        if v then
            buildNoclipParts()
            noclipCon = RunService.Stepped:Connect(function()
                for i = 1, #noclipParts do
                    local part = noclipParts[i]
                    if part and part.Parent then part.CanCollide = false end
                end
            end)
            noclipCharCon = player.CharacterAdded:Connect(function()
                task.wait(0.1); buildNoclipParts()
            end)
        else
            if noclipCon     then noclipCon:Disconnect();     noclipCon     = nil end
            if noclipCharCon then noclipCharCon:Disconnect(); noclipCharCon = nil end
            task.wait()
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CanCollide = true end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            end
            table.clear(noclipParts)
        end
    end,
})

local GameTeleport = Tabs.Game:AddRightGroupbox("Teleport", "map-pin")

local WORKSPACE_FILTER_IGNORE = {
    Script=true, LocalScript=true, ModuleScript=true,
    RemoteEvent=true, RemoteFunction=true,
    BindableEvent=true, BindableFunction=true,
    StringValue=true, IntValue=true, BoolValue=true,
    NumberValue=true, ObjectValue=true,
    CFrameValue=true, Vector3Value=true, Color3Value=true,
    WorldModel=true, Terrain=true, Camera=true,
}

local showAllWorkspaceItems = false  -- declared BEFORE getWorkspaceItems

local function getWorkspaceItems()
    local items = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        local cls = obj.ClassName
        if showAllWorkspaceItems then
            if not WORKSPACE_FILTER_IGNORE[cls] then
                items[#items + 1] = obj.Name
            end
        else
            if obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("BasePart") then
                items[#items + 1] = obj.Name
            end
        end
    end
    table.sort(items)
    if #items == 0 then items[1] = "No items" end
    return items
end

local function getInstancesOfName(name)
    local list = {}
    local n = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == name then
            n = n + 1
            list[#list + 1] = name .. " #" .. n
        end
    end
    if #list == 0 then list[1] = "None" end
    return list
end

local selectedItem     = ""
local selectedIndex    = 1
local teleportAllItems = true
local itemDropdown     = nil
local instanceDropdown = nil
local loopTeleportCon  = nil

local function refreshInstanceDropdown()
    if not instanceDropdown then return end
    local list = getInstancesOfName(selectedItem)
    selectedIndex = 1
    pcall(function()
        instanceDropdown:SetValues(list)
        instanceDropdown:SetValue(list[1])
    end)
end

itemDropdown = GameTeleport:AddDropdown("ItemTeleportDropdown", {
    Text = "Select Item", Values = getWorkspaceItems(), Default = getWorkspaceItems()[1], Searchable = true,
    Callback = function(v) selectedItem = v; refreshInstanceDropdown() end,
})
selectedItem = getWorkspaceItems()[1]

GameTeleport:AddButton({
    Text = "Refresh List",
    Func = function()
        local items = getWorkspaceItems()
        pcall(function() itemDropdown:SetValues(items) end)
        refreshInstanceDropdown()
    end,
})
GameTeleport:AddToggle("ShowAllItemsToggle", {
    Text = "Show All Workspace Objects", Default = false,
    Tooltip = "Include all objects in workspace, not just Folders/Models/BaseParts",
    Callback = function(v)
        showAllWorkspaceItems = v
        local items = getWorkspaceItems()
        pcall(function() itemDropdown:SetValues(items) end)
        refreshInstanceDropdown()
    end,
})

local initInstances = getInstancesOfName(selectedItem)
instanceDropdown = GameTeleport:AddDropdown("ItemInstanceDropdown", {
    Text = "Select Instance", Values = initInstances, Default = initInstances[1],
    Callback = function(v)
        local n = v:match("#(%d+)$")
        selectedIndex = tonumber(n) or 1
    end,
})
GameTeleport:AddToggle("TeleportAllToggle", {
    Text = "Teleport All with Name", Default = true,
    Tooltip = "ON = all items with this name; OFF = only selected instance",
    Callback = function(v) teleportAllItems = v end,
})

local function doItemTeleport()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local count, idx = 0, 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == selectedItem then
            idx = idx + 1
            if teleportAllItems or idx == selectedIndex then
                for _, v in pairs(obj:GetDescendants()) do
                    if v:IsA("BasePart") then v.CFrame = hrp.CFrame end
                end
                if obj:IsA("BasePart") then obj.CFrame = hrp.CFrame end
                count = count + 1
                if not teleportAllItems then break end
            end
        end
    end
    if count == 0 then
        Notify({ Title = "Teleport", Description = '"' .. selectedItem .. '" not found', Duration = 3 })
    end
    return count
end

GameTeleport:AddButton({
    Text = "Teleport Item to Me",
    Func = function() doItemTeleport() end,
})
GameTeleport:AddToggle("LoopItemTeleportToggle", {
    Text = "Loop Teleport Item", Default = false,
    Callback = function(v)
        if v then
            local running = true
            loopTeleportCon = { Disconnect = function() running = false end }
            task.spawn(function()
                while running do doItemTeleport(); task.wait(0.1) end
            end)
        else
            if loopTeleportCon then loopTeleportCon:Disconnect(); loopTeleportCon = nil end
        end
    end,
})
----------------------------------------------------------------
-- ============================================================
-- HITBOX TAB
-- ============================================================
----------------------------------------------------------------

local HBMain   = Tabs.Hitbox:AddLeftGroupbox("Hitbox Expander",  "crosshair")
local HBReach  = Tabs.Hitbox:AddLeftGroupbox("Reach",            "move")
local HBNpc    = Tabs.Hitbox:AddRightGroupbox("NPC Hitbox",      "user")

local hbSize       = 8
local hbTransp     = 0
local hbPart       = "HumanoidRootPart"
local hbHighlights = {}
local hbColor      = Color3.fromRGB(255, 50, 50)
local hbOutlineTransp = 0
local hbOrigSizes  = {}
local hbTargetMode = "All"
local hbTargetName = ""

local npcHBSize     = 10
local npcHBTarget   = "All"
local npcHBCon      = nil
local npcHBOrigSizes = {}

local reachSize     = 60
local reachOrigData = {}

local function getHBTargets()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        if hbTargetMode == "Specific Player" and p.Name ~= hbTargetName then continue end
        if Toggles.HBTeamCheck.Value and p.Team == player.Team then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local root = char:FindFirstChild(hbPart)
        if root then table.insert(out, { root = root, p = p }) end
    end
    return out
end

local hbCon = nil

local function startHB()
    if hbCon then hbCon:Disconnect() end
    for _, t in ipairs(getHBTargets()) do
        if not hbOrigSizes[t.root] then
            hbOrigSizes[t.root] = { size = t.root.Size, transp = t.root.Transparency }
        end
    end
    hbCon = RunService.Heartbeat:Connect(function()
        if not (Toggles.HitboxToggle and Toggles.HitboxToggle.Value) then return end
        for _, t in ipairs(getHBTargets()) do
            local root = t.root
            if root and root.Parent then
                if not hbOrigSizes[root] then
                    hbOrigSizes[root] = { size = root.Size, transp = root.Transparency }
                end
                root.Size         = Vector3.new(hbSize, hbSize, hbSize)
                root.Transparency = hbTransp
                root.CanCollide   = false
            end
        end
    end)
end

local function stopHB()
    if hbCon then hbCon:Disconnect(); hbCon = nil end
    for root, data in pairs(hbOrigSizes) do
        pcall(function()
            if root and root.Parent then
                root.Size        = data.size
                root.Transparency = data.transp
            end
        end)
    end
    hbOrigSizes = {}
end

local function refreshHighlights()
    for _, hl in pairs(hbHighlights) do pcall(function() hl:Destroy() end) end
    hbHighlights = {}
    if not (Toggles.HBHighlightToggle and Toggles.HBHighlightToggle.Value) then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        if hbTargetMode == "Specific Player" and p.Name ~= hbTargetName then continue end
        if Toggles.HBTeamCheck.Value and p.Team == player.Team then continue end
        local char = p.Character
        if not char then continue end
        local hl = Instance.new("Highlight")
        hl.FillColor         = hbColor
        hl.FillTransparency  = 1
        hl.OutlineColor      = hbColor
        hl.OutlineTransparency = hbOutlineTransp
        hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee           = char
        hl.Parent            = workspace
        hbHighlights[p]      = hl
    end
end

local function getNpcHBTargets()
    local out, n = {}, 0
    local filterByName = npcHBTarget ~= "All"
    for model in pairs(killAuraNPCs) do
        if not model.Parent then continue end
        if filterByName and model.Name ~= npcHBTarget then continue end
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if not hrp or hrp.ReceiveAge ~= 0 then continue end
        n = n + 1
        out[n] = { root = hrp, model = model }
    end
    return out
end

local function startNpcHB()
    if npcHBCon then npcHBCon:Disconnect() end
    for _, t in ipairs(getNpcHBTargets()) do
        if not npcHBOrigSizes[t.root] then
            npcHBOrigSizes[t.root] = { size = t.root.Size, transp = t.root.Transparency }
        end
    end
    npcHBCon = RunService.Heartbeat:Connect(function()
        if not (Toggles.NpcHitboxToggle and Toggles.NpcHitboxToggle.Value) then return end
        for _, t in ipairs(getNpcHBTargets()) do
            local root = t.root
            if root and root.Parent then
                if not npcHBOrigSizes[root] then
                    npcHBOrigSizes[root] = { size = root.Size, transp = root.Transparency }
                end
                root.Size         = Vector3.new(npcHBSize, npcHBSize, npcHBSize)
                root.Transparency = 1
                root.CanCollide   = false
            end
        end
    end)
end

local function stopNpcHB()
    if npcHBCon then npcHBCon:Disconnect(); npcHBCon = nil end
    for root, data in pairs(npcHBOrigSizes) do
        pcall(function()
            if root and root.Parent then
                root.Size        = data.size
                root.Transparency = data.transp
            end
        end)
    end
    npcHBOrigSizes = {}
end

local function applyReach()
    local char = player.Character
    if not char then return end
    for _, tool in ipairs(char:GetDescendants()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and not reachOrigData[tool] then
                reachOrigData[tool] = {
                    handle  = handle,
                    size    = handle.Size,
                    gripPos = tool.GripPos,
                }
            end
            if handle then
                handle.Massless = true
                handle.Size     = Vector3.new(reachSize, reachSize, reachSize)
                tool.GripPos    = Vector3.new(0, 0, 0)
                local char2 = player.Character
                local hum   = char2 and char2:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() end
            end
        end
    end
end

local function restoreReach()
    for tool, data in pairs(reachOrigData) do
        pcall(function()
            if data.handle and data.handle.Parent then
                data.handle.Size = data.size
                data.handle.Massless = false
            end
            if tool and tool.Parent then
                tool.GripPos = data.gripPos
            end
        end)
    end
    reachOrigData = {}
end

HBMain:AddToggle("HitboxToggle", {
    Text = "Enable Hitbox Expander", Default = false,
    Callback = function(v)
        if v then startHB() else stopHB() end
    end,
})
HBMain:AddSlider("HitboxSizeSlider", {
    Text = "Hitbox Size", Min = 1, Max = 60, Default = 8, Suffix = "st", Rounding = 0,
    Callback = function(v) hbSize = v end,
})
HBMain:AddDropdown("HitboxPartDropdown", {
    Text    = "Target Part",
    Values  = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso" },
    Default = "HumanoidRootPart",
    Callback = function(v)
        if Toggles.HitboxToggle and Toggles.HitboxToggle.Value then stopHB() end
        hbPart = v
        if Toggles.HitboxToggle and Toggles.HitboxToggle.Value then startHB() end
    end,
})

local function getOtherPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "No players") end
    return names
end

local hbTargetDropdown
HBMain:AddDropdown("HitboxTargetModeDropdown", {
    Text    = "Target Mode",
    Values  = { "All", "Specific Player" },
    Default = "All",
    Callback = function(v)
        hbTargetMode = v
        if hbTargetDropdown then
            pcall(function()
                hbTargetDropdown:SetDisabled(v ~= "Specific Player", "Set Target Mode to \"Specific Player\" first")
            end)
        end
        if Toggles.HBHighlightToggle and Toggles.HBHighlightToggle.Value then refreshHighlights() end
    end,
})
hbTargetDropdown = HBMain:AddDropdown("HitboxTargetPlayerDropdown", {
    Text = "Specific Player", Values = getOtherPlayerNames(), Default = getOtherPlayerNames()[1], Searchable = true,
    Callback = function(v)
        hbTargetName = v
        if Toggles.HBHighlightToggle and Toggles.HBHighlightToggle.Value then refreshHighlights() end
    end,
})
hbTargetName = getOtherPlayerNames()[1]
pcall(function()
    hbTargetDropdown:SetDisabled(true, "Set Target Mode to \"Specific Player\" first")
end)

Players.PlayerAdded:Connect(function()
    pcall(function() hbTargetDropdown:SetValues(getOtherPlayerNames()) end)
end)
Players.PlayerRemoving:Connect(function()
    task.wait()
    pcall(function() hbTargetDropdown:SetValues(getOtherPlayerNames()) end)
end)

HBMain:AddToggle("HBTeamCheck", {
    Text = "Team Check", Default = false,
    Callback = function(v)
        if Toggles.HBHighlightToggle and Toggles.HBHighlightToggle.Value then refreshHighlights() end
    end,
})
HBMain:AddDivider()
HBMain:AddToggle("HBHighlightToggle", {
    Text = "Show Highlight", Default = false,
    Callback = function(v)
        refreshHighlights()
    end,
})
HBMain:AddDropdown("HBColorDropdown", {
    Text    = "Highlight Color",
    Values  = { "Red", "Green", "Blue", "Yellow", "White", "Cyan", "Pink", "Orange" },
    Default = "Red",
    Callback = function(v)
        local colors = {
            Red    = Color3.fromRGB(255, 50,  50),
            Green  = Color3.fromRGB(50,  255, 80),
            Blue   = Color3.fromRGB(50,  100, 255),
            Yellow = Color3.fromRGB(255, 230, 50),
            White  = Color3.fromRGB(255, 255, 255),
            Cyan   = Color3.fromRGB(50,  220, 255),
            Pink   = Color3.fromRGB(255, 100, 180),
            Orange = Color3.fromRGB(255, 150, 30),
        }
        hbColor = colors[v] or Color3.fromRGB(255, 50, 50)
        for _, hl in pairs(hbHighlights) do
            pcall(function() hl.FillColor = hbColor; hl.OutlineColor = hbColor end)
        end
    end,
})
HBMain:AddSlider("HBOutlineTranspSlider", {
    Text = "Outline Transparency", Min = 0, Max = 90, Default = 0, Suffix = "%", Rounding = 0,
    Callback = function(v)
        hbOutlineTransp = v / 100
        for _, hl in pairs(hbHighlights) do
            pcall(function() hl.OutlineTransparency = hbOutlineTransp end)
        end
    end,
})
HBMain:AddSlider("HBTranspSlider", {
    Text = "HRP Transparency", Min = 0, Max = 100, Default = 0, Suffix = "%", Rounding = 0,
    Callback = function(v) hbTransp = v / 100 end,
})

local hbSeeThroughAdornments = {}
local hbSeeThroughOn = false

local function clearSeeThroughAdornments()
    for _, ad in pairs(hbSeeThroughAdornments) do pcall(function() ad:Destroy() end) end
    table.clear(hbSeeThroughAdornments)
end

local function refreshSeeThroughAdornments()
    if not hbSeeThroughOn then
        clearSeeThroughAdornments()
        return
    end
    local current = {}
    for _, t in ipairs(getHBTargets()) do
        current[t.root] = true
        if not hbSeeThroughAdornments[t.root] then
            local ad = Instance.new("BoxHandleAdornment")
            ad.Adornee       = t.root
            ad.AlwaysOnTop   = true
            ad.ZIndex        = 1
            ad.Color3        = hbColor
            ad.Transparency  = 0.4
            ad.Size          = Vector3.new(hbSize, hbSize, hbSize)
            ad.Parent        = t.root
            hbSeeThroughAdornments[t.root] = ad
        else
            hbSeeThroughAdornments[t.root].Size = Vector3.new(hbSize, hbSize, hbSize)
        end
    end
    for root, ad in pairs(hbSeeThroughAdornments) do
        if not current[root] then
            pcall(function() ad:Destroy() end)
            hbSeeThroughAdornments[root] = nil
        end
    end
end

HBMain:AddToggle("HBSeeThroughToggle", {
    Text = "See Through Walls", Default = false,
    Tooltip = "Renders the expanded hitbox on top of everything, including walls",
    Callback = function(v)
        hbSeeThroughOn = v
        refreshSeeThroughAdornments()
    end,
})

task.spawn(function()
    while true do
        if hbSeeThroughOn then refreshSeeThroughAdornments() end
        task.wait(0.5)
    end
end)

HBReach:AddToggle("ReachToggle", {
    Text = "Enable Reach", Default = false,
    Tooltip = "Expands equipped tool Handle size for extended reach",
    Callback = function(v)
        if v then
            applyReach()
        else
            restoreReach()
        end
    end,
})
HBReach:AddSlider("ReachSizeSlider", {
    Text = "Reach Size", Min = 1, Max = 200, Default = 60, Suffix = "st", Rounding = 0,
    Callback = function(v)
        reachSize = v
        if Toggles.ReachToggle and Toggles.ReachToggle.Value then restoreReach(); applyReach() end
    end,
})
HBReach:AddButton({
    Text = "Apply Reach",
    Func = function()
        if Toggles.ReachToggle and Toggles.ReachToggle.Value then restoreReach(); applyReach() end
    end,
})
HBReach:AddButton({
    Text = "Remove Reach",
    Func = function()
        restoreReach()
        if Toggles.ReachToggle then Toggles.ReachToggle:SetValue(false) end
    end,
})

HBNpc:AddToggle("NpcHitboxToggle", {
    Text = "Enable NPC Hitbox", Default = false,
    Tooltip = "Expands hitbox of network-owned NPCs (ones visible in ESP)",
    Callback = function(v)
        if v then startNpcHB() else stopNpcHB() end
    end,
})
HBNpc:AddSlider("NpcHitboxSizeSlider", {
    Text = "NPC Hitbox Size", Min = 1, Max = 100, Default = 10, Suffix = "st", Rounding = 0,
    Callback = function(v) npcHBSize = v end,
})
HBNpc:AddInput("NpcHitboxTargetInput", {
    Text = "NPC Name (blank = All)", Default = "", Numeric = false, Placeholder = "NPC name or leave blank",
    Callback = function(v)
        npcHBTarget = (v == "" or v == nil) and "All" or v
        if Toggles.NpcHitboxToggle and Toggles.NpcHitboxToggle.Value then stopNpcHB(); startNpcHB() end
    end,
})
HBNpc:AddDivider()

local npcHBHighlights  = {}
local npcHBHighlightColor = Color3.fromRGB(80, 200, 255)

local function clearNpcHBHighlights()
    for _, hl in pairs(npcHBHighlights) do pcall(function() hl:Destroy() end) end
    table.clear(npcHBHighlights)
end

local function refreshNpcHBHighlights()
    if not (Toggles.NpcHitboxHighlightToggle and Toggles.NpcHitboxHighlightToggle.Value) then
        clearNpcHBHighlights()
        return
    end
    local current = {}
    for _, t in ipairs(getNpcHBTargets()) do
        current[t.model] = true
        if not npcHBHighlights[t.model] then
            local hl = Instance.new("Highlight")
            hl.FillColor         = npcHBHighlightColor
            hl.FillTransparency  = 1
            hl.OutlineColor      = npcHBHighlightColor
            hl.OutlineTransparency = 0
            hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee           = t.model
            hl.Parent            = workspace
            npcHBHighlights[t.model] = hl
        end
    end
    for model, hl in pairs(npcHBHighlights) do
        if not current[model] then
            pcall(function() hl:Destroy() end)
            npcHBHighlights[model] = nil
        end
    end
end

HBNpc:AddToggle("NpcHitboxHighlightToggle", {
    Text = "Show Highlight", Default = false,
    Tooltip = "Outlines every NPC whose hitbox is currently expanded",
    Callback = function(v)
        refreshNpcHBHighlights()
    end,
})
HBNpc:AddDropdown("NpcHitboxHighlightColorDropdown", {
    Text    = "Highlight Color",
    Values  = { "Cyan", "Red", "Green", "Yellow", "White", "Pink", "Orange" },
    Default = "Cyan",
    Callback = function(v)
        local colors = {
            Cyan   = Color3.fromRGB(80,  200, 255),
            Red    = Color3.fromRGB(255, 50,  50),
            Green  = Color3.fromRGB(50,  255, 80),
            Yellow = Color3.fromRGB(255, 230, 50),
            White  = Color3.fromRGB(255, 255, 255),
            Pink   = Color3.fromRGB(255, 100, 180),
            Orange = Color3.fromRGB(255, 150, 30),
        }
        npcHBHighlightColor = colors[v] or Color3.fromRGB(80, 200, 255)
        for _, hl in pairs(npcHBHighlights) do
            pcall(function() hl.FillColor = npcHBHighlightColor; hl.OutlineColor = npcHBHighlightColor end)
        end
    end,
})

task.spawn(function()
    while true do
        if Toggles.NpcHitboxHighlightToggle and Toggles.NpcHitboxHighlightToggle.Value then
            refreshNpcHBHighlights()
        end
        task.wait(2)
    end
end)

HBNpc:AddDivider()
HBNpc:AddButton({
    Text = "Reset Stuck Sizes",
    Tooltip = "If an NPC's hitbox stays expanded after it dies/despawns, this snaps every tracked size back",
    Func = function()
        for root, data in pairs(npcHBOrigSizes) do
            pcall(function()
                if root and root.Parent then
                    root.Size        = data.size
                    root.Transparency = data.transp
                end
            end)
        end
        npcHBOrigSizes = {}
        clearNpcHBHighlights()
        Notify({ Title = "NPC Hitbox", Description = "Sizes reset", Duration = 2 })
    end,
})

local HBVisuals = Tabs.Hitbox:AddRightGroupbox("Visuals", "sparkles")

local defaultFOV = workspace.CurrentCamera.FieldOfView
HBVisuals:AddSlider("FOVSlider", {
    Text = "Field of View", Min = 40, Max = 120, Default = defaultFOV, Rounding = 0,
    Callback = function(v)
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = v end
    end,
})
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local cam = workspace.CurrentCamera
    if cam and Options.FOVSlider then
        cam.FieldOfView = Options.FOVSlider.Value
    end
end)

HBVisuals:AddDivider()

local skySavedInstances = {}
local skyHidden = false

local function findSkyInstances()
    local list = {}
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Sky") then table.insert(list, v) end
    end
    return list
end

HBVisuals:AddToggle("HideSkyToggle", {
    Text = "Hide Sky", Default = false,
    Tooltip = "Removes the sky (sun/moon/stars/clouds) so the background goes flat",
    Callback = function(v)
        skyHidden = v
        if v then
            skySavedInstances = findSkyInstances()
            for _, sky in ipairs(skySavedInstances) do
                sky.Parent = nil
            end
        else
            for _, sky in ipairs(skySavedInstances) do
                sky.Parent = Lighting
            end
            skySavedInstances = {}
        end
    end,
})

HBVisuals:AddDivider()

local originalBrightness   = Lighting.Brightness
local originalOutdoorAmb   = Lighting.OutdoorAmbient
local brightnessOverridden = false

HBVisuals:AddSlider("BrightnessSlider", {
    Text = "Brightness", Min = 0, Max = 5, Default = originalBrightness, Rounding = 1,
    Callback = function(v)
        brightnessOverridden = true
        Lighting.Brightness = v
    end,
})
HBVisuals:AddButton({
    Text = "Reset Brightness",
    Func = function()
        Lighting.Brightness     = originalBrightness
        Lighting.OutdoorAmbient = originalOutdoorAmb
        brightnessOverridden    = false
        pcall(function() Options.BrightnessSlider:SetValue(originalBrightness) end)
    end,
})

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        if Toggles.HBHighlightToggle and Toggles.HBHighlightToggle.Value then refreshHighlights() end
        if Toggles.HitboxToggle and Toggles.HitboxToggle.Value then startHB() end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if hbHighlights[p] then
        pcall(function() hbHighlights[p]:Destroy() end)
        hbHighlights[p] = nil
    end
end)

----------------------------------------------------------------
-- ============================================================
-- FUN TAB
-- ============================================================
----------------------------------------------------------------

local FunSelection  = Tabs.Fun:AddLeftGroupbox("Selection",  "mouse-pointer")
local FunTeleport   = Tabs.Fun:AddLeftGroupbox("Teleport",   "map-pin")
local FunPossession = Tabs.Fun:AddLeftGroupbox("Possession", "shield")
local FunActions    = Tabs.Fun:AddLeftGroupbox("Actions",    "sword")
local FunVisibility = Tabs.Fun:AddRightGroupbox("Visibility", "eye")
local FunAuras      = Tabs.Fun:AddRightGroupbox("Auras",      "activity")
local FunOrbitAll   = Tabs.Fun:AddRightGroupbox("Orbit Aura", "rotate-cw")
local FunBait       = Tabs.Fun:AddRightGroupbox("NPC Bait",   "target")
local FunCamera     = Tabs.Fun:AddRightGroupbox("Camera",     "camera")

local currentNPC            = nil
local followCon             = nil
local orbitCon              = nil
local savedChar             = nil
local mouse                 = player:GetMouse()

local multiSelectedNPCs = {}
local multiHighlights   = {}

local selHL = Instance.new("Highlight")
selHL.FillTransparency    = 1
selHL.OutlineTransparency = 1
selHL.Parent              = workspace

local function isNPC(model)
    return not playerChars[model] and (model:FindFirstChildOfClass("Humanoid") ~= nil or model:FindFirstChild("HumanoidRootPart") ~= nil)
end

local function flashHL(model, color)
    task.spawn(function()
        selHL.Adornee             = model
        selHL.OutlineColor        = color
        selHL.OutlineTransparency = 0
        task.wait(0.4)
        selHL.OutlineTransparency = 1
    end)
end

local netOwnerESPOn       = false
local netOwnerRadius      = 200
local killAuraRadius      = 20
local freezeAuraRadius    = 20
local netOwnerBBs         = {}
local netOwnerLoop        = nil
local netOwnerConAdded    = nil
local netOwnerConRemoving = nil

local function removeNetOwnerBB(model)
    local entry = netOwnerBBs[model]
    if entry then
        pcall(function() entry.bb:Destroy() end)
        netOwnerBBs[model] = nil
    end
end

local function addNetOwnerBB(model, hrp)
    if netOwnerBBs[model] then return end
    if not isNPC(model) then return end
    hrp = hrp or model:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "__NetOwnerBB"; bb.Size = UDim2.new(0, 160, 0, 28)
    bb.StudsOffset = Vector3.new(0, 4, 0); bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false; bb.Parent = hrp
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0); lbl.Position = UDim2.new(0,0,0,0)
    lbl.BackgroundTransparency = 1; lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold; lbl.Text = "..."
    lbl.TextColor3 = Color3.fromRGB(180,180,180); lbl.Parent = bb
    netOwnerBBs[model] = { bb = bb, lbl = lbl }
end

local function clearNetOwnerBBs()
    for model in pairs(netOwnerBBs) do removeNetOwnerBB(model) end
end

local function startNetOwnerLoop()
    if netOwnerLoop then return end
    for model in pairs(killAuraNPCs) do addNetOwnerBB(model) end
    netOwnerConAdded = workspace.DescendantAdded:Connect(function(obj)
        if not obj:IsA("Humanoid") then return end
        local model = obj.Parent
        if not model or not model:IsA("Model") then return end
        if not netOwnerESPOn then return end
        task.spawn(function()
            local hrp = model:WaitForChild("HumanoidRootPart", 3)
            if hrp and netOwnerESPOn then addNetOwnerBB(model, hrp) end
        end)
    end)
    netOwnerConRemoving = workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("Humanoid") then removeNetOwnerBB(obj.Parent) end
    end)
    netOwnerLoop = true
    task.spawn(function()
        while netOwnerLoop do
            local char  = player.Character
            local myHRP = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = myHRP and myHRP.Position
            for model, entry in pairs(netOwnerBBs) do
                if not model.Parent then removeNetOwnerBB(model); continue end
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if myPos and (hrp.Position - myPos).Magnitude > netOwnerRadius then
                        entry.bb.Enabled = false; continue
                    end
                    entry.bb.Enabled = true
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health <= 0 then
                        entry.lbl.Text = "??"; entry.lbl.TextColor3 = Color3.fromRGB(255,255,255); continue
                    end
                    if hrp.ReceiveAge == 0 then
                        entry.lbl.Text = model.Name; entry.lbl.TextColor3 = Color3.fromRGB(80,255,120)
                    else
                        entry.lbl.Text = model.Name; entry.lbl.TextColor3 = Color3.fromRGB(255,90,90)
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

local function stopNetOwnerLoop()
    netOwnerESPOn = false; netOwnerLoop = false
    if netOwnerConAdded    then netOwnerConAdded:Disconnect();    netOwnerConAdded    = nil end
    if netOwnerConRemoving then netOwnerConRemoving:Disconnect(); netOwnerConRemoving = nil end
    clearNetOwnerBBs()
end

local function removeMultiHL(model)
    local hl = multiHighlights[model]
    if hl then pcall(function() hl:Destroy() end); multiHighlights[model] = nil end
end

mouse.Button1Down:Connect(function()
    if not (Toggles.ClickSelectNPC.Value or Toggles.MultiSelectToggle.Value) then return end
    local target = mouse.Target
    if not target then return end
    local model = target:FindFirstAncestorOfClass("Model")
    if not model then model = target.Parent end
    if not model then return end
    if not isNPC(model) then return end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if Toggles.MultiSelectToggle.Value then
        if multiSelectedNPCs[model] then
            multiSelectedNPCs[model] = nil; removeMultiHL(model)
        else
            multiSelectedNPCs[model] = true
            local hum = model:FindFirstChildOfClass("Humanoid")
            local dead  = not hum or hum.Health <= 0
            local owned = hrp.ReceiveAge == 0
            local hl = Instance.new("Highlight")
            hl.FillTransparency = 0.7; hl.OutlineTransparency = 0
            hl.FillColor    = dead and Color3.fromRGB(255,255,255) or (owned and Color3.fromRGB(0,200,80) or Color3.fromRGB(255,200,0))
            hl.OutlineColor = hl.FillColor; hl.Adornee = model; hl.Parent = workspace
            multiHighlights[model] = hl
        end
        return
    end
    if Toggles.ClickSelectNPC.Value then
        currentNPC = model
        flashHL(model, hrp.ReceiveAge == 0 and Color3.fromRGB(0,255,80) or Color3.fromRGB(255,80,80))
    end
end)

local simRadLoop
task.spawn(function()
    local setSimRad = sethiddenproperty and function()
        pcall(sethiddenproperty, player, "SimulationRadius", 100)
    end or function()
        pcall(function() player.SimulationRadius = 100 end)
    end
    local alive = true
    simRadLoop = { Disconnect = function() alive = false end }
    while alive do setSimRad(); task.wait(0.1) end
end)

task.spawn(function()
    while true do
        if next(multiHighlights) then
            for model, hl in pairs(multiHighlights) do
                if not model.Parent then
                    pcall(function() hl:Destroy() end); multiHighlights[model] = nil; continue
                end
                local hrp   = model:FindFirstChild("HumanoidRootPart")
                local hum   = model:FindFirstChildOfClass("Humanoid")
                local dead  = not hum or hum.Health <= 0
                local owned = hrp and hrp.ReceiveAge == 0
                local col   = dead and Color3.fromRGB(255,255,255) or (owned and Color3.fromRGB(0,200,80) or Color3.fromRGB(255,200,0))
                pcall(function() hl.FillColor = col; hl.OutlineColor = col end)
            end
        end
        task.wait(0.2)
    end
end)

local function npcDo(fn)
    if not currentNPC then Notify({ Title = "NPC Control", Description = "Select an NPC first", Duration = 2 }); return end
    local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
    if not hrp then Notify({ Title = "NPC Control", Description = "HumanoidRootPart not found", Duration = 2 }); return end
    if hrp.ReceiveAge ~= 0 then
        local t = tick()
        repeat task.wait(0.05) until hrp.ReceiveAge == 0 or tick() - t > 3
        if hrp.ReceiveAge ~= 0 then Notify({ Title = "NPC Control", Description = "No ownership after 3s", Duration = 2 }); return end
    end
    fn()
end

FunSelection:AddToggle("ClickSelectNPC", {
    Text = "Click to Select NPC", Default = false,
    Tooltip = "Click an NPC to select it",
})
FunSelection:AddButton({
    Text = "Unselect NPC",
    Func = function() currentNPC = nil; selHL.Adornee = nil; selHL.OutlineTransparency = 1 end,
})
FunSelection:AddToggle("MultiSelectToggle", {
    Text = "Multi Select NPCs", Default = false,
    Tooltip = "Click NPCs to add/remove from selection",
})
FunSelection:AddButton({
    Text = "Unselect Multi",
    Func = function()
        for model in pairs(multiSelectedNPCs) do removeMultiHL(model) end
        table.clear(multiSelectedNPCs)
    end,
})

local savedBringPos    = nil
local teleportMultiCon = nil
local teleportAnyCon   = nil
local teleportAnyRadius     = 200
local teleportAnyKeepRadius = 5

FunTeleport:AddButton({
    Text = "Save Position",
    Func = function()
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then Notify({ Title = "Save Position", Description = "No character", Duration = 2 }); return end
        savedBringPos = hrp.CFrame
        local p = hrp.Position
        Notify({ Title = "Position Saved", Description = ("X:%.1f Y:%.1f Z:%.1f"):format(p.X, p.Y, p.Z), Duration = 4 })
    end,
})
FunTeleport:AddButton({
    Text = "Teleport Selected to Position",
    Func = function()
        if not savedBringPos then Notify({ Title = "Teleport", Description = "Save a position first", Duration = 2 }); return end
        if not currentNPC    then Notify({ Title = "Teleport", Description = "Select an NPC first",   Duration = 2 }); return end
        npcDo(function() currentNPC:PivotTo(savedBringPos) end)
    end,
})
FunTeleport:AddToggle("TeleportMultiToggle", {
    Text = "Teleport Multi to Position", Default = false,
    Callback = function(v)
        if v then
            if not savedBringPos then
                Notify({ Title = "Teleport Multi", Description = "Save a position first", Duration = 2 })
                if Toggles.TeleportMultiToggle then Toggles.TeleportMultiToggle:SetValue(false) end; return
            end
            local running = true
            teleportMultiCon = { Disconnect = function() running = false end }
            task.spawn(function()
                while running do
                    for model in pairs(multiSelectedNPCs) do
                        if not model.Parent then continue end
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if not hrp or hrp.ReceiveAge ~= 0 then continue end
                        local offset = Vector3.new(math.random(-3,3), 0, math.random(-3,3))
                        model:PivotTo(savedBringPos * CFrame.new(offset))
                    end
                    task.wait(0.1)
                end
            end)
        else
            if teleportMultiCon then teleportMultiCon:Disconnect(); teleportMultiCon = nil end
        end
    end,
})
FunTeleport:AddButton({
    Text = "Teleport Any NPC to Position",
    Func = function()
        if not savedBringPos then Notify({ Title = "Teleport Any", Description = "Save a position first", Duration = 2 }); return end
        local count = 0
        local char  = player.Character
        local myHRP = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = myHRP and myHRP.Position
        for model in pairs(killAuraNPCs) do
            if not model.Parent or model == char then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.ReceiveAge == 0 then
                if myPos and (hrp.Position - myPos).Magnitude > teleportAnyRadius then continue end
                local offset = Vector3.new(math.random(-3,3), 0, math.random(-3,3))
                model:PivotTo(savedBringPos * CFrame.new(offset)); count = count + 1
            end
        end
        Notify({ Title = "Teleport Any", Description = count .. " NPC(s) teleported", Duration = 3 })
    end,
})
FunTeleport:AddToggle("TeleportAnyNPCToggle", {
    Text = "Teleport Any NPC to Position", Default = false,
    Callback = function(v)
        if v then
            if not savedBringPos then
                Notify({ Title = "Teleport Any", Description = "Save a position first", Duration = 2 })
                if Toggles.TeleportAnyNPCToggle then Toggles.TeleportAnyNPCToggle:SetValue(false) end; return
            end
            local running = true
            teleportAnyCon = { Disconnect = function() running = false end }
            task.spawn(function()
                while running do
                    local char   = player.Character
                    local myHRP  = char and char:FindFirstChild("HumanoidRootPart")
                    local myPos  = myHRP and myHRP.Position
                    local savedPos = savedBringPos.Position
                    for model in pairs(killAuraNPCs) do
                        if not model.Parent or model == char then continue end
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if not hrp or hrp.ReceiveAge ~= 0 then continue end
                        if myPos and (hrp.Position - myPos).Magnitude > teleportAnyRadius then continue end
                        if (hrp.Position - savedPos).Magnitude > teleportAnyKeepRadius then
                            local offset = Vector3.new(math.random(-2,2), 0, math.random(-2,2))
                            model:PivotTo(savedBringPos * CFrame.new(offset))
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            if teleportAnyCon then teleportAnyCon:Disconnect(); teleportAnyCon = nil end
        end
    end,
})
FunTeleport:AddSlider("TeleportAnyRadius", {
    Text = "Search Radius (m)", Min = 10, Max = 1000, Default = 200, Suffix = "m", Rounding = 0,
    Callback = function(v) teleportAnyRadius = v end,
})
FunTeleport:AddSlider("TeleportAnyKeepRadius", {
    Text = "Keep Radius (m)", Min = 1, Max = 50, Default = 5, Suffix = "m", Rounding = 0,
    Callback = function(v) teleportAnyKeepRadius = v end,
})

local npcNoclipCon   = nil
local npcNoclipParts = {}

local function buildNpcNoclipParts()
    table.clear(npcNoclipParts)
    if not currentNPC or not currentNPC.Parent then return end
    for _, part in ipairs(currentNPC:GetDescendants()) do
        if part:IsA("BasePart") then npcNoclipParts[#npcNoclipParts + 1] = part end
    end
end

FunTeleport:AddToggle("NpcNoclipToggle", {
    Text = "NPC Noclip", Default = false,
    Tooltip = "Selected NPC passes through everything",
    Callback = function(v)
        if v then
            if not currentNPC then
                Notify({ Title = "NPC Noclip", Description = "Select an NPC first", Duration = 2 })
                if Toggles.NpcNoclipToggle then Toggles.NpcNoclipToggle:SetValue(false) end; return
            end
            buildNpcNoclipParts()
            local lastAge = nil
            npcNoclipCon = RunService.Stepped:Connect(function()
                if not currentNPC or not currentNPC.Parent then return end
                local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if hrp.ReceiveAge == 0 and lastAge ~= nil and lastAge ~= 0 then buildNpcNoclipParts() end
                lastAge = hrp.ReceiveAge
                for i = 1, #npcNoclipParts do
                    local part = npcNoclipParts[i]
                    if part and part.Parent then part.CanCollide = false end
                end
            end)
        else
            if npcNoclipCon then npcNoclipCon:Disconnect(); npcNoclipCon = nil end
            for i = 1, #npcNoclipParts do
                local part = npcNoclipParts[i]
                if part and part.Parent then part.CanCollide = true end
            end
            table.clear(npcNoclipParts)
        end
    end,
})
FunTeleport:AddToggle("TeleportCursorToggle", {
    Text = "Teleport NPC to Cursor", Default = false,
}):AddKeyPicker("TeleportNPCKey", {
    Default = "T", Text = "Teleport Key", NoUI = false,
    Callback = function()
        if not (Toggles.TeleportCursorToggle and Toggles.TeleportCursorToggle.Value) or not currentNPC then return end
        local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
        if not hrp or hrp.ReceiveAge ~= 0 then return end
        currentNPC:PivotTo(CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)))
    end,
})

FunPossession:AddToggle("ControlNPC", {
    Text = "Control NPC", Default = false,
    Tooltip = "Control the selected NPC (requires ownership)",
    Callback = function(v)
        if v then
            if not currentNPC then
                Notify({ Title = "Control NPC", Description = "Select an NPC first", Duration = 2 })
                Toggles.ControlNPC:SetValue(false); return
            end
            local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
            if not hrp or hrp.ReceiveAge ~= 0 then
                Notify({ Title = "Control NPC", Description = "No Network Ownership", Duration = 2 })
                Toggles.ControlNPC:SetValue(false); return
            end
            savedChar = player.Character
            player.Character = currentNPC
            workspace.CurrentCamera.CameraSubject = hrp
            if savedChar then
                local charHRP = savedChar:FindFirstChild("HumanoidRootPart")
                if charHRP then charHRP.Anchored = true; charHRP.CFrame = hrp.CFrame * CFrame.new(0,-3,0) end
                for _, part in ipairs(savedChar:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("SpecialMesh") then pcall(function() part.Transparency = 1 end) end
                    if part:IsA("Decal") or part:IsA("Texture") then pcall(function() part.Transparency = 1 end) end
                end
            end
            followCon = RunService.Heartbeat:Connect(function()
                if not currentNPC or not currentNPC.Parent then return end
                if not savedChar or not savedChar.Parent then return end
                local npcHRP  = currentNPC:FindFirstChild("HumanoidRootPart")
                local charHRP = savedChar:FindFirstChild("HumanoidRootPart")
                if npcHRP and charHRP then charHRP.CFrame = npcHRP.CFrame * CFrame.new(0,-3,0) end
            end)
            task.spawn(function()
                local wasControlling = true
                while Toggles.ControlNPC and Toggles.ControlNPC.Value do
                    task.wait(0.2)
                    if not currentNPC or not currentNPC.Parent then break end
                    local npcHRP = currentNPC:FindFirstChild("HumanoidRootPart")
                    if not npcHRP then break end
                    if npcHRP.ReceiveAge ~= 0 then
                        if wasControlling then
                            wasControlling = false
                            if savedChar then
                                player.Character = savedChar
                                local hum = savedChar:FindFirstChildOfClass("Humanoid")
                                if hum then workspace.CurrentCamera.CameraSubject = hum end
                            end
                        end
                    else
                        if not wasControlling then
                            wasControlling = true
                            player.Character = currentNPC
                            workspace.CurrentCamera.CameraSubject = npcHRP
                        end
                    end
                end
            end)
        else
            if followCon then followCon:Disconnect(); followCon = nil end
            if savedChar then
                for _, part in ipairs(savedChar:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then pcall(function() part.Transparency = 0 end) end
                    if part:IsA("Decal") or part:IsA("Texture") then pcall(function() part.Transparency = 0 end) end
                end
                local charHRP = savedChar and savedChar.Parent and savedChar:FindFirstChild("HumanoidRootPart")
                if charHRP then
                    charHRP.Anchored = false
                    if currentNPC then
                        local npcHRP = currentNPC:FindFirstChild("HumanoidRootPart")
                        if npcHRP then charHRP.CFrame = npcHRP.CFrame end
                    end
                end
                player.Character = savedChar
                local hum = savedChar:FindFirstChildOfClass("Humanoid")
                if hum then workspace.CurrentCamera.CameraSubject = hum end
                savedChar = nil
            end
        end
    end,
})
FunPossession:AddToggle("FollowNPC", {
    Text = "NPC Follow Me", Default = false,
    Callback = function(v)
        if v then
            if not currentNPC then
                Notify({ Title = "Follow NPC", Description = "Select an NPC first", Duration = 2 })
                Toggles.FollowNPC:SetValue(false); return
            end
            followCon = RunService.Heartbeat:Connect(function()
                if not currentNPC or not currentNPC.Parent then return end
                local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
                if not hrp or hrp.ReceiveAge ~= 0 then return end
                local hum  = currentNPC:FindFirstChildOfClass("Humanoid")
                local char = player.Character
                local myHRP = char and char:FindFirstChild("HumanoidRootPart")
                if hum and myHRP then hum:MoveTo(myHRP.Position + Vector3.new(-4, 0, 0)) end
            end)
        else
            if followCon then followCon:Disconnect(); followCon = nil end
        end
    end,
})

local orbitRadius = 12
FunPossession:AddToggle("OrbitNPCToggle", {
    Text = "Orbit Me", Default = false,
    Callback = function(v)
        if v then
            if not currentNPC then
                Notify({ Title = "Orbit", Description = "Select an NPC first", Duration = 2 })
                Toggles.OrbitNPCToggle:SetValue(false); return
            end
            local angle = 0
            orbitCon = RunService.Heartbeat:Connect(function(dt)
                if not currentNPC or not currentNPC.Parent then return end
                local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
                if not hrp or hrp.ReceiveAge ~= 0 then return end
                local char  = player.Character
                local myHRP = char and char:FindFirstChild("HumanoidRootPart")
                if not myHRP then return end
                angle = angle + dt * 1.5
                local offset = Vector3.new(math.cos(angle)*orbitRadius, 0, math.sin(angle)*orbitRadius)
                currentNPC:PivotTo(CFrame.new(myHRP.Position + offset))
            end)
        else
            if orbitCon then orbitCon:Disconnect(); orbitCon = nil end
        end
    end,
})
FunPossession:AddSlider("OrbitRadiusSlider", {
    Text = "Orbit Radius (m)", Min = 2, Max = 50, Default = 12, Suffix = "m", Rounding = 0,
    Callback = function(v) orbitRadius = v end,
})

FunActions:AddButton({ Text = "Kill",      Func = function() npcDo(function() local h = currentNPC:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(15) end end) end })
FunActions:AddButton({ Text = "Ragdoll",   Func = function() npcDo(function() local h = currentNPC:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(17) end end) end })
FunActions:AddButton({ Text = "Sit",       Func = function() npcDo(function() local h = currentNPC:FindFirstChildOfClass("Humanoid"); if h then h.Sit = not h.Sit end end) end })
FunActions:AddButton({ Text = "Jump",      Func = function() npcDo(function() local h = currentNPC:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(3) end end) end })
FunActions:AddButton({ Text = "Freeze",    Func = function() npcDo(function()
    local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = not hrp.Anchored; Notify({ Title = "Freeze NPC", Description = hrp.Anchored and "Frozen" or "Unfrozen", Duration = 2 }) end
end) end })
FunActions:AddButton({ Text = "Bring",     Func = function() npcDo(function() if player.Character then currentNPC:PivotTo(player.Character:GetPivot()) end end) end })
FunActions:AddButton({ Text = "Go to NPC", Func = function()
    if not currentNPC then Notify({ Title = "NPC", Description = "Select an NPC first", Duration = 2 }); return end
    local char = player.Character; if char then char:PivotTo(currentNPC:GetPivot()) end
end })
FunActions:AddButton({ Text = "Punish",    Func = function() npcDo(function() currentNPC:PivotTo(CFrame.new(0, 10000, 0)) end) end })

FunVisibility:AddToggle("NetOwnerESP", {
    Text = "Network Owner ESP", Default = false,
    Callback = function(v) netOwnerESPOn = v; if v then startNetOwnerLoop() else stopNetOwnerLoop() end end,
})
FunVisibility:AddSlider("NetOwnerRadius", {
    Text = "ESP Radius (m)", Min = 1, Max = 1000, Default = 200, Suffix = "m", Rounding = 0,
    Callback = function(v) netOwnerRadius = v end,
})

local killAuraOn    = false
local freezeAuraOn  = false
local anchorAuraOn  = false
local anchorAuraRadius = 20
local auraLoopCon   = nil

local function ensureAuraLoop()
    if auraLoopCon then return end
    local running = true
    auraLoopCon = { Disconnect = function() running = false end }
    task.spawn(function()
        while running do
            if killAuraOn or freezeAuraOn or anchorAuraOn then
                local char  = player.Character
                local myHRP = char and char:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local myPos = myHRP.Position
                    for model in pairs(killAuraNPCs) do
                        if not model.Parent then killAuraNPCs[model] = nil; continue end
                        if model == char then continue end
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if not hrp or hrp.ReceiveAge ~= 0 then continue end
                        local dist  = (hrp.Position - myPos).Magnitude
                        local hum   = model:FindFirstChildOfClass("Humanoid")
                        local alive = hum and hum.Health > 0 and hum.Health == hum.Health
                        local killed = false
                        if killAuraOn and alive and dist <= killAuraRadius then hum:ChangeState(15); killed = true end
                        if freezeAuraOn and alive and not killed and dist <= freezeAuraRadius then
                            hum.WalkSpeed = 0; hum.JumpPower = 0; hum:ChangeState(8)
                        end
                        if anchorAuraOn and dist <= anchorAuraRadius then hrp.Anchored = true end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

local function stopAuraLoop()
    if auraLoopCon then auraLoopCon:Disconnect(); auraLoopCon = nil end
end
local function onAuraDisable()
    if not killAuraOn and not freezeAuraOn and not anchorAuraOn then stopAuraLoop() end
end

FunAuras:AddToggle("KillAura", {
    Text = "Kill Aura", Default = false,
    Callback = function(v) killAuraOn = v; if v then ensureAuraLoop() else onAuraDisable() end end,
}):AddKeyPicker("KillAuraKeybind", {
    Default = "None", Text = "Killaura keybind", NoUI = false, Mode = "Toggle",
    Callback = function(v)
        if Toggles.KillAura then Toggles.KillAura:SetValue(v) end
    end,
})
FunAuras:AddDivider()
FunAuras:AddToggle("FreezeAura", {
    Text = "Freeze Aura", Default = false,
    Callback = function(v)
        freezeAuraOn = v
        if not v then
            for model in pairs(killAuraNPCs) do
                if model.Parent then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
                end
            end
            onAuraDisable()
        else ensureAuraLoop() end
    end,
})
FunAuras:AddDivider()
FunAuras:AddToggle("AnchorAura", {
    Text = "Anchor Aura", Default = false,
    Callback = function(v)
        anchorAuraOn = v
        if not v then
            for model in pairs(killAuraNPCs) do
                if model.Parent then
                    local hrp = model:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.Anchored = false end
                end
            end
            onAuraDisable()
        else ensureAuraLoop() end
    end,
})
FunAuras:AddDivider()
FunAuras:AddSlider("KillAuraRadius",   { Text = "Kill Radius (m)",   Min = 10, Max = 1000, Default = 20, Suffix = "m", Rounding = 0, Callback = function(v) killAuraRadius   = v end })
FunAuras:AddSlider("FreezeAuraRadius", { Text = "Freeze Radius (m)", Min = 10, Max = 1000, Default = 20, Suffix = "m", Rounding = 0, Callback = function(v) freezeAuraRadius = v end })
FunAuras:AddSlider("AnchorAuraRadius", { Text = "Anchor Radius (m)", Min = 10, Max = 1000, Default = 20, Suffix = "m", Rounding = 0, Callback = function(v) anchorAuraRadius = v end })

local orbitAllRadius = 20
local orbitAllCon    = nil
local orbitAllAngles = {}

FunOrbitAll:AddToggle("OrbitAllToggle", {
    Text = "Orbit All NPCs", Default = false,
    Callback = function(v)
        if v then
            if orbitAllCon then orbitAllCon:Disconnect() end
            orbitAllAngles = {}
            orbitAllCon = RunService.Heartbeat:Connect(function(dt)
                local char  = player.Character
                local myHRP = char and char:FindFirstChild("HumanoidRootPart")
                if not myHRP then return end
                local myPos = myHRP.Position
                local i = 0
                for model in pairs(killAuraNPCs) do
                    if not model.Parent or model == char then continue end
                    local hrp = model:FindFirstChild("HumanoidRootPart")
                    if not hrp or hrp.ReceiveAge ~= 0 then continue end
                    if (hrp.Position - myPos).Magnitude > orbitAllRadius then continue end
                    i = i + 1
                    orbitAllAngles[model] = (orbitAllAngles[model] or (i * math.pi * 2 / 8)) + dt * 1.5
                    local angle  = orbitAllAngles[model]
                    local offset = Vector3.new(math.cos(angle)*8, 0, math.sin(angle)*8)
                    model:PivotTo(CFrame.new(myPos + offset))
                end
            end)
        else
            if orbitAllCon then orbitAllCon:Disconnect(); orbitAllCon = nil end
            orbitAllAngles = {}
        end
    end,
})
FunOrbitAll:AddSlider("OrbitAllRadius", { Text = "Orbit Radius (m)", Min = 5, Max = 500, Default = 20, Suffix = "m", Rounding = 0, Callback = function(v) orbitAllRadius = v end })

local baitTargetName = ""
local baitDropdown   = nil
local loopBaitAllCon = nil

local function getBaitPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "No players") end
    return names
end

baitDropdown = FunBait:AddDropdown("BaitTargetDropdown", {
    Text = "Target Player", Values = getBaitPlayerNames(), Default = getBaitPlayerNames()[1], Searchable = true,
    Callback = function(v) baitTargetName = v end,
})
baitTargetName = getBaitPlayerNames()[1]

Players.PlayerAdded:Connect(function()   pcall(function() baitDropdown:SetValues(getBaitPlayerNames()) end) end)
Players.PlayerRemoving:Connect(function() task.wait(); pcall(function() baitDropdown:SetValues(getBaitPlayerNames()) end) end)

FunBait:AddToggle("LoopBaitAllToggle", {
    Text = "Loop Bait (all NPCs)", Default = false,
    Callback = function(v)
        if v then
            local running = true
            loopBaitAllCon = { Disconnect = function() running = false end }
            task.spawn(function()
                while running do
                    local target    = Players:FindFirstChild(baitTargetName)
                    local targetHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        for model in pairs(killAuraNPCs) do
                            if not model.Parent then continue end
                            local hrp = model:FindFirstChild("HumanoidRootPart")
                            if hrp and hrp.ReceiveAge == 0 then
                                for _, part in ipairs(model:GetChildren()) do
                                    if part:IsA("BasePart") then part.CanCollide = false end
                                end
                                model:PivotTo(CFrame.new(targetHRP.Position + Vector3.new(0, 5, 0)))
                            end
                        end
                    end
                    task.wait(0.5)
                end
                for model in pairs(killAuraNPCs) do
                    if model.Parent then
                        for _, part in ipairs(model:GetChildren()) do
                            if part:IsA("BasePart") then part.CanCollide = true end
                        end
                    end
                end
            end)
        else
            if loopBaitAllCon then loopBaitAllCon:Disconnect(); loopBaitAllCon = nil end
        end
    end,
})
FunBait:AddButton({
    Text = "Send NPC to Target",
    Func = function()
        npcDo(function()
            local target    = Players:FindFirstChild(baitTargetName)
            local targetHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not targetHRP then Notify({ Title = "NPC Bait", Description = "Target has no character", Duration = 3 }); return end
            currentNPC:PivotTo(CFrame.new(targetHRP.Position + Vector3.new(0, 5, 0)))
        end)
    end,
})

FunCamera:AddButton({
    Text = "Spectate",
    Func = function()
        if not currentNPC then Notify({ Title = "Spectate", Description = "Select an NPC first", Duration = 2 }); return end
        local hrp = currentNPC:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        workspace.CurrentCamera.CameraSubject = hrp
    end,
})
FunCamera:AddButton({
    Text = "Unspectate",
    Func = function()
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then workspace.CurrentCamera.CameraSubject = hum end
    end,
})
----------------------------------------------------------------
-- ============================================================
-- SETTINGS TAB
-- ============================================================
----------------------------------------------------------------

local ThemeManager = loadstring(game:HttpGet(THEME_URLS[LIBRARY_CHOICE] or THEME_URLS.Obsidian))()
local SaveManager  = loadstring(game:HttpGet(SAVE_URLS[LIBRARY_CHOICE]  or SAVE_URLS.Obsidian))()

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
    "MenuKeybind", "DPIDropdown", "AutoexecuteToggle",
    "ItemTeleportDropdown", "ItemInstanceDropdown",
    "BaitTargetDropdown", "HitboxTargetPlayerDropdown",
})
ThemeManager:SetFolder("Fantasy")
SaveManager:SetFolder("Fantasy")

SaveManager:BuildConfigSection(Tabs["Settings"])
ThemeManager:ApplyToTab(Tabs["Settings"])

local LibBox = Tabs["Settings"]:AddLeftGroupbox("UI Library", "layers")
local chosenLib = LIBRARY_CHOICE
LibBox:AddDropdown("LibraryChoice", {
    Text = "Library", Values = { "Obsidian", "Linoria" }, Default = LIBRARY_CHOICE,
    Callback = function(v) chosenLib = v; getgenv().__FantasyLib = v end,
})
LibBox:AddButton({
    Text = "Reload with Selected Library",
    Func = function()
        getgenv().__FantasyLib = chosenLib
        pcall(function() Library:Unload() end)
        task.wait(0.3)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/3a6ey/testadonis/refs/heads/main/test.lua"))()
    end,
})
LibBox:AddDivider()
LibBox:AddToggle("CacheScriptsToggle", {
    Text = "Cache Scripts Locally", Default = false,
    Tooltip = "Save loadstrings to Fantasy/cache/ folder and load from there",
    Callback = function(v)
        cacheEnabled = v
        if writefile and saveSettingsEnabled then pcall(writefile, "Fantasy/cache_enabled", tostring(v)) end
        if v and canCache() then
            ensureCacheFolder()
        elseif v and not canCache() then
            Notify({ Title = "Cache", Description = "Executor doesn't support file I/O", Duration = 4 })
            if Toggles.CacheScriptsToggle then Toggles.CacheScriptsToggle:SetValue(false) end
        end
    end,
})
if safeReadFile("Fantasy/cache_enabled") == "true" then
    task.defer(function() Toggles.CacheScriptsToggle:SetValue(true) end)
end
LibBox:AddToggle("AlwaysCheckUpdToggle", {
    Text = "Always Check for Updates", Default = false,
    Callback = function(v)
        alwaysCheckUpd = v
        if writefile and saveSettingsEnabled then pcall(writefile, "Fantasy/always_check_upd", tostring(v)) end
    end,
})
if safeReadFile("Fantasy/always_check_upd") == "true" then
    task.defer(function() Toggles.AlwaysCheckUpdToggle:SetValue(true) end)
end
LibBox:AddToggle("SaveSettingsToggle", {
    Text = "Save Settings Automatically", Default = saveSettingsEnabled,
    Callback = function(v)
        saveSettingsEnabled = v
        if writefile then pcall(writefile, "Fantasy/save_settings", tostring(v)) end
    end,
})
LibBox:AddButton({
    Text = "Download All Scripts Now",
    Func = function()
        if not canCache() then
            Notify({ Title = "Cache", Description = "Executor doesn't support file I/O", Duration = 4 }); return
        end
        ensureCacheFolder()
        task.spawn(function()
            local total, count = 0, 0
            for key, entry in pairs(SCRIPT_CACHE) do
                total = total + 1
                local content = fetchRemote(entry.url)
                if content then saveCache(key, content); count = count + 1 end
            end
            local libFiles = {
                { url = LIB_URLS[LIBRARY_CHOICE]   or LIB_URLS.Obsidian,   path = "Fantasy/cache/Library_"      .. LIBRARY_CHOICE .. ".lua" },
                { url = THEME_URLS[LIBRARY_CHOICE] or THEME_URLS.Obsidian, path = "Fantasy/cache/ThemeManager_" .. LIBRARY_CHOICE .. ".lua" },
                { url = SAVE_URLS[LIBRARY_CHOICE]  or SAVE_URLS.Obsidian,  path = "Fantasy/cache/SaveManager_"  .. LIBRARY_CHOICE .. ".lua" },
            }
            for _, f in ipairs(libFiles) do
                total = total + 1
                local content = fetchRemote(f.url)
                if content then pcall(writefile, f.path, content); count = count + 1 end
            end
            Notify({ Title = "Cache", Description = count .. "/" .. total .. " files cached", Duration = 5 })
        end)
    end,
})

local MenuGroup = Tabs["Settings"]:AddRightGroupbox("Menu", "wrench")
MenuGroup:AddToggle("ShowUICursorToggle", {
    Text = "Show UI Cursor", Default = false,
    Callback = function(v) Library.ShowCustomCursor = v end,
})
Toggles.ShowUICursorToggle:OnChanged(function(v)
    if writefile and saveSettingsEnabled then pcall(writefile, "Fantasy/show_ui_cursor", tostring(v)) end
end)
if safeReadFile("Fantasy/show_ui_cursor") == "true" then
    task.defer(function() Toggles.ShowUICursorToggle:SetValue(true) end)
end

MenuGroup:AddToggle("ShowGameCursorToggle", {
    Text = "Show Game Cursor", Default = true,
    Callback = function(v) UIS.MouseIconEnabled = v end,
})
Toggles.ShowGameCursorToggle:OnChanged(function(v)
    if writefile and saveSettingsEnabled then pcall(writefile, "Fantasy/show_game_cursor", tostring(v)) end
end)
do
    local val = safeReadFile("Fantasy/show_game_cursor")
    if val == "false" then task.defer(function() Toggles.ShowGameCursorToggle:SetValue(false) end) end
end

MenuGroup:AddDivider()

local defaultSize = isfile and isfile("Fantasy/UISize") and readfile("Fantasy/UISize") or "100%"
MenuGroup:AddDropdown("DPIDropdown", {
    Text = "UI Size", Values = { "50%", "60%", "70%", "80%", "90%", "100%" }, Default = defaultSize,
    Callback = function() end,
})
Options.DPIDropdown:OnChanged(function(v)
    pcall(function() if writefile then writefile("Fantasy/UISize", v) end end)
    local n = tonumber((v:gsub("%%", "")))
    if n then Library:SetDPIScale(n) end
end)
Options.DPIDropdown:SetValue(defaultSize)

MenuGroup:AddDivider()

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'LeftAlt', NoUI = false, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddDivider()

MenuGroup:AddToggle("AutoexecuteToggle", {
    Text = "Autoexecute", Default = false,
})
local wasAutoExec = isfile and isfile("Fantasy/autoexec") and readfile("Fantasy/autoexec") == "true"
Toggles.AutoexecuteToggle:OnChanged(function(v)
    if writefile then pcall(writefile, "Fantasy/autoexec", tostring(v)) end
end)
if wasAutoExec then Toggles.AutoexecuteToggle:SetValue(true) end

MenuGroup:AddDivider()

MenuGroup:AddButton({
    Text = "Unload Script", Risky = true,
    Func = function() Library:Unload() end,
})

SaveManager:LoadAutoloadConfig()

getgenv().__FantasyLoaded = function()
    if getgenv().__FantasyLibrary then
        pcall(function() getgenv().__FantasyLibrary:Unload() end)
    end
    getgenv().__FantasyLoaded  = nil
    getgenv().__FantasyLibrary = nil
end

Library:OnUnload(function()
    getgenv().__FantasyLoaded  = nil
    getgenv().__FantasyLibrary = nil

    local togglesToReset = {
        "LoopFBToggle", "LoopNoFogToggle", "InfiniteJumpToggle", "AutoJumpToggle",
        "NoclipToggle", "FlyToggle", "WalkSpeedToggle", "NoAccelToggle", "CFSpeedToggle", "CFFlyToggle",
        "NoCamMaxZoomToggle", "InstantProximityPromptsToggle",
        "LoopItemTeleportToggle", "TeleportAllToggle",
        "FollowNPC", "ControlNPC", "ClickSelectNPC", "TeleportCursorToggle",
        "OrbitNPCToggle", "NpcNoclipToggle", "MultiSelectToggle", "TeleportMultiToggle",
        "TeleportAnyNPCToggle", "NetOwnerESP", "KillAura", "FreezeAura", "AnchorAura",
        "LoopBaitAllToggle", "AutoexecuteToggle", "CacheScriptsToggle",
        "AlwaysCheckUpdToggle", "OrbitAllToggle", "ShowAllItemsToggle", "HitboxToggle", "HBHighlightToggle", "HBTeamCheck", "HBSeeThroughToggle", "NpcHitboxToggle", "NpcHitboxHighlightToggle", "ReachToggle", "HideSkyToggle",
    }
    for _, name in ipairs(togglesToReset) do
        if Toggles[name] then pcall(function() Toggles[name]:SetValue(false) end) end
    end

    pcall(function() infJump:Disconnect()    end)
    pcall(function() simRadLoop:Disconnect() end)
    if noFogLoop    then noFogLoop:Disconnect();    noFogLoop    = nil end
    if brightLoop   then brightLoop:Disconnect();   brightLoop   = nil end
    pcall(stopNetOwnerLoop)
    if followCon       then followCon:Disconnect()      end
    killAuraOn = false; freezeAuraOn = false; anchorAuraOn = false
    if auraLoopCon     then auraLoopCon:Disconnect();     auraLoopCon     = nil end
    if loopBaitAllCon  then loopBaitAllCon:Disconnect();  loopBaitAllCon  = nil end
    if orbitCon        then orbitCon:Disconnect();        orbitCon        = nil end
    if orbitAllCon     then orbitAllCon:Disconnect();     orbitAllCon     = nil end
    if walkSpeedCon    then walkSpeedCon:Disconnect();    walkSpeedCon    = nil end
    if noAccelCon      then noAccelCon:Disconnect();      noAccelCon      = nil end
    if cfSpeedCon      then cfSpeedCon:Disconnect();      cfSpeedCon      = nil end
    if cfFlyCon        then cfFlyCon:Disconnect();        cfFlyCon        = nil end
    if noCamZoomCon    then noCamZoomCon:Disconnect();    noCamZoomCon    = nil end
    pcall(instantPrompts_Disable)
    if hbCon           then hbCon:Disconnect();           hbCon           = nil end
    if npcHBCon        then npcHBCon:Disconnect();        npcHBCon        = nil end
    for _, hl in pairs(hbHighlights) do pcall(function() hl:Destroy() end) end
    stopHB(); stopNpcHB(); restoreReach()
    clearNpcHBHighlights()
    hbSeeThroughOn = false
    clearSeeThroughAdornments()

    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = defaultFOV end
    end)
    pcall(function()
        if skyHidden then
            for _, sky in ipairs(skySavedInstances) do
                sky.Parent = Lighting
            end
        end
        if brightnessOverridden then
            Lighting.Brightness     = originalBrightness
            Lighting.OutdoorAmbient = originalOutdoorAmb
        end
    end)
    pcall(function() player.CameraMaxZoomDistance = noCamOrigMaxZoom end)
    if noclipCon       then noclipCon:Disconnect();       noclipCon       = nil end
    if noclipCharCon   then noclipCharCon:Disconnect();   noclipCharCon   = nil end
    if loopTeleportCon then loopTeleportCon:Disconnect(); loopTeleportCon = nil end
    if npcNoclipCon    then npcNoclipCon:Disconnect();    npcNoclipCon    = nil end
    if teleportMultiCon then teleportMultiCon:Disconnect(); teleportMultiCon = nil end
    if teleportAnyCon   then teleportAnyCon:Disconnect();   teleportAnyCon   = nil end

    pcall(function() selHL:Destroy() end)
    for _, hl in pairs(multiHighlights) do pcall(function() hl:Destroy() end) end
    table.clear(multiSelectedNPCs); table.clear(multiHighlights)
    if savedChar then player.Character = savedChar end
    print("Fantasy Unloaded.")
end)

print("Fantasy Loaded.")
