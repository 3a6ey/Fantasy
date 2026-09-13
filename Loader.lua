--                      SKIDDING TIME
--                  FANTASY DEBUG SUITE v2
--              Enhanced diagnostics & protections
--

local startTime = tick()
local STEP_COUNT = 0
local FAIL_COUNT = 0
local TEST_RESULTS = {}

local function divider(char, len)
    print(string.rep(char or "-", len or 50))
end

local function header(text)
    divider("=", 50)
    print(("  %s"):format(text))
    divider("=", 50)
end

local function step(name, fn)
    STEP_COUNT = 1
    local ok, err = pcall(fn)
    local elapsed = tick() - startTime

    if ok then
        print(("[OK]   %-40s %.3fs"):format(name, elapsed))
    else
        FAIL_COUNT += 1
        warn(("[FAIL] %-40s %s"):format(name, tostring(err)))
    end
    return ok
end

local function test(name, fn)
    local ok, result = pcall(fn)
    table.insert(TEST_RESULTS, {name = name, passed = ok, result = result})
    
    if ok then
        print(("   ✓ %s"):format(name))
    else
        warn(("   ✗ %s — %s"):format(name, tostring(result)))
    end
    return ok
end

local function checkExists(name, val)
    if val ~= nil then
        print(("   + %-32s available"):format(name))
        return true
    else
        warn(("   - %-32s missing"):format(name))
        return false
    end
end

-- ========================================================
header("🧭 FANTASY DEBUG SUITE — INITIALIZATION")
-- ========================================================

step("game:IsLoaded()", function()
    repeat task.wait() until game:IsLoaded()
end)

local Players = game:GetService("Players")
local localPlayer

step("Fetch LocalPlayer", function()
    localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
    assert(localPlayer, "LocalPlayer not found")
end)

step("Wait for Character (15s timeout)", function()
    assert(localPlayer, "LocalPlayer missing")
    local deadline = tick() + 15
    repeat
        task.wait()
        assert(tick() < deadline, "timed out")
    until localPlayer.Character
end)

step("Wait for PlayerGui (15s timeout)", function()
    assert(localPlayer, "LocalPlayer missing")
    local deadline = tick() + 15
    repeat
        task.wait()
        assert(tick() < deadline, "timed out")
    until localPlayer:FindFirstChild("PlayerGui")
end)

task.wait(1)

-- ========================================================
header("🔍 EXPLOIT ENVIRONMENT INVENTORY")
-- ========================================================

local env = getfenv and getfenv() or {}

local categories = {
    ["Hooks & Metamethods"] = {
        "hookfunction", "hookmetamethod", "getrawmetatable", "setrawmetatable",
        "setreadonly", "isreadonly", "newcclosure", "iscclosure", "islclosure",
    },
    ["Namecall & Calls"] = {
        "getnamecallmethod", "checkcaller", "getcallingscript",
    },
    ["Closures & Bytecode"] = {
        "getupvalue", "setupvalue", "getconstant", "setconstant",
        "getprotos", "getgc", "getinstances", "getnilinstances",
    },
    ["Environment & Globals"] = {
        "getgenv", "getrenv", "getfenv", "setfenv", "getsenv",
    },
    ["Signals & Connections"] = {
        "getconnections", "firesignal", "fireclickdetector",
        "firetouchinterest", "fireproximityprompt",
    },
    ["Filesystem"] = {
        "writefile", "readfile", "isfile", "isfolder",
        "makefolder", "delfile", "listfiles",
    },
    ["Scripts & Execution"] = {
        "loadstring", "require", "getscriptbytecode",
        "getscripthash", "decompile",
    },
    ["Misc"] = {
        "identifyexecutor", "setclipboard", "request", "http_request",
        "queue_on_teleport", "isnetworkowner", "gethui",
    },
}

local totalFound, totalChecked = 0, 0

for categoryName, funcs in pairs(categories) do
    print("")
    print(("-- %s"):format(categoryName))
    for _, fname in pairs(funcs) do
        totalChecked += 1
        local val = _G[fname] or env[fname] or (getgenv and getgenv()[fname])
        if checkExists(fname, val) then
            totalFound += 1
        end
    end
end

print("")
divider("-", 50)
print(("Summary: %d / %d functions found (%.0f%%)"):format(
    totalFound, totalChecked, (totalFound / totalChecked) * 100
))

if identifyexecutor then
    local ok, name, version = pcall(identifyexecutor)
    if ok then
        print(("Executor: %s %s"):format(tostring(name), tostring(version or "")))
    end
end

-- ========================================================
header("🛡️  SETTING UP PROTECTIONS")
-- ========================================================

local protect = (newcclosure) or function(f) return f end

if not hookfunction then
    warn("hookfunction unavailable — function-level hooks skipped")
else
    step("Mask gcinfo (memory info)", function()
        assert(gcinfo, "gcinfo does not exist")
        hookfunction(gcinfo, protect(function()
            return math.random(200, 350)
        end))
    end)

    step("Mask collectgarbage (GC info)", function()
        assert(collectgarbage, "collectgarbage does not exist")
        local old
        old = hookfunction(collectgarbage, protect(function(opt, ...)
            if opt == "count" then return math.random(200, 350) * 1024 end
            return old(opt, ...)
        end))
    end)

    step("Block Player:Kick()", function()
        assert(localPlayer, "LocalPlayer unavailable")
        hookfunction(localPlayer.Kick, protect(function(...)
            warn("⛔ Direct Kick() intercepted and blocked")
            task.wait(9e9)
        end))
    end)
end

if not hookmetamethod then
    warn("hookmetamethod unavailable — __namecall hook skipped")
else
    step("Hook __namecall (block remote Kick)", function()
        local h
        h = hookmetamethod(game, "__namecall", protect(function(self, ...)
            if checkcaller and checkcaller() then
                return h(self, ...)
            end
            local method = getnamecallmethod and getnamecallmethod()
            if method == "Kick" then
                warn("⛔ Remote Kick() via __namecall blocked")
                task.wait(9e9)
                return
            end
            return h(self, ...)
        end))
    end)
end

step("Disable gameplay-paused notification", function()
    local gs = game:FindFirstChildOfClass("GuiService")
    assert(gs, "GuiService not found")
    gs:SetGameplayPausedNotificationEnabled(false)
end)

-- ========================================================
header("🧪 FUNCTIONAL TESTS")
-- ========================================================

print("")
test("Test game:IsLoaded() state", function()
    return game:IsLoaded()
end)

test("Test LocalPlayer access", function()
    return localPlayer ~= nil
end)

test("Test Character existence", function()
    return localPlayer.Character ~= nil
end)

test("Test PlayerGui existence", function()
    return localPlayer:FindFirstChild("PlayerGui") ~= nil
end)

test("Test Humanoid access", function()
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end)

test("Test ReplicatedStorage access", function()
    return game:GetService("ReplicatedStorage") ~= nil
end)

test("Test HttpGet capability", function()
    local ok = pcall(function()
        game:HttpGet("https://httpbin.org/status/200", true)
    end)
    return ok
end)

test("Test newcclosure availability", function()
    return newcclosure ~= nil
end)

test("Test hookfunction availability", function()
    return hookfunction ~= nil
end)

-- ========================================================
header("📊 PERFORMANCE DIAGNOSTICS")
-- ========================================================

step("Measure FPS", function()
    local RunService = game:GetService("RunService")
    local frames = 0
    local conn
    conn = RunService.Heartbeat:Connect(function() frames += 1 end)
    task.wait(1)
    conn:Disconnect()
    print(("   ~%d FPS"):format(frames))
    if frames < 15 then
        warn("   Low FPS detected!")
    end
end)

step("Count instances in game", function()
    local count = #game:GetDescendants()
    print(("   %d instances"):format(count))
    if count > 50000 then
        warn("   Suspiciously high — possible leak")
    end
end)

step("Scan for duplicate LocalScripts", function()
    local seen, dupes = {}, 0
    for _, v in pairs(localPlayer.PlayerScripts:GetDescendants()) do
        if v:IsA("LocalScript") then
            seen[v.Name] = (seen[v.Name] or 0) + 1
            if seen[v.Name] > 1 then dupes += 1 end
        end
    end
    if dupes > 0 then
        warn(("   %d duplicates found"):format(dupes))
    else
        print("   No duplicates found")
    end
end)

step("Check error history (LogService)", function()
    local LogService = game:GetService("LogService")
    local errCount = 0
    for _, entry in pairs(LogService:GetLogHistory()) do
        if entry.messageType == Enum.MessageType.MessageError then
            errCount += 1
        end
    end
    print(("   %d errors in history"):format(errCount))
    if errCount > 10 then
        warn("   High error count — possible systemic issue")
    end
end)

step("Check server ping", function()
    local stats = game:GetService("Stats")
    local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    print(("   %dms"):format(math.floor(ping)))
    if ping > 200 then
        warn("   High ping detected!")
    end
end)

-- ========================================================
header("📊 TEST SUMMARY")
-- ========================================================

local passedTests = 0
for _, result in pairs(TEST_RESULTS) do
    if result.passed then
        passedTests += 1
    end
end

print(("Passed: %d / %d tests"):format(passedTests, #TEST_RESULTS))
divider("-", 50)

-- ========================================================
header("📦 LOADING ADONIS BYPASS")
-- ========================================================

local adonisUrl = "https://raw.githubusercontent.com/3a6ey/testadonis/refs/heads/main/test.lua"
local adonisCode

step("Download Adonis Bypass", function()
    adonisCode = game:HttpGet(adonisUrl)
    assert(type(adonisCode) == "string" and #adonisCode > 0, "empty response from Adonis URL")
end)

if adonisCode then
    local loadedAdonis
    step("Compile Adonis Bypass", function()
        local err
        loadedAdonis, err = loadstring(adonisCode)
        assert(loadedAdonis, "compile error: " .. tostring(err))
    end)

    if loadedAdonis then
        step("Execute Adonis Bypass", function()
            local ok, err = pcall(loadedAdonis)
            assert(ok, tostring(err))
            task.wait(0.5) -- Даем байпасу немного времени на инициализацию
        end)
    end
end

-- ========================================================
header("🚀 LOADING FANTASY MAIN HUB")
-- ========================================================

local fantasyMainUrl = "https://raw.githubusercontent.com/3a6ey/Fantasy/refs/heads/main/Main.lua" 
local mainCode

step("Download Main Hub", function()
    mainCode = game:HttpGet(fantasyMainUrl)
    assert(type(mainCode) == "string" and #mainCode > 0, "empty response from Main URL")
end)

if mainCode then
    local loadedMain
    step("Compile Main Hub", function()
        local err
        loadedMain, err = loadstring(mainCode)
        assert(loadedMain, "compile error: " .. tostring(err))
    end)

    if loadedMain then
        step("Execute Main Hub", function()
            local ok, err = pcall(loadedMain)
            assert(ok, tostring(err))
        end)
    end
end

-- ========================================================
local statusEmoji = FAIL_COUNT == 0 and "✅" or "⚠️"
header(("%s DONE in %.2fs | Steps: %d | Failures: %d"):format(
    statusEmoji, tick() - startTime, STEP_COUNT, FAIL_COUNT
))
-- ========================================================
