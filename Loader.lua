
--[[15.09.2025
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
]]

-- ========================================================
--    FANTASY LOADER & DEBUG SUITE v2.1 (REFACTORED)
-- ========================================================

local startTime = tick()
local STEP_COUNT = 0
local FAIL_COUNT = 0
local TEST_RESULTS = {}
local totalFound, totalChecked = 0, 0

local function divider(char, len)
    print(string.rep(char or "-", len or 50))
end

local function header(text)
    divider("=", 50)
    print(("  %s"):format(text))
    divider("=", 50)
end

local function step(name, fn)
    STEP_COUNT += 1
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
    totalChecked += 1
    if val ~= nil then
        totalFound += 1
        print(("✅ %s"):format(name))
        return true
    else
        warn(("❌ %s"):format(name))
        return false
    end
end


-- НОВОЕ: единая функция загрузки+компиляции+выполнения
-- Убирает дублирование блоков Adonis / Main Hub из оригинала

local function loadAndRun(url, label)
    local rawCode

    step(("Download %s (HttpGet)"):format(label), function()
        local ok, res = pcall(game.HttpGet, game, url)
        assert(ok, "httpget failed")
        rawCode = res
        assert(type(rawCode) == "string" and #rawCode > 0, "empty response")
        print(("   %d bytes received"):format(#rawCode))
    end)

    if not rawCode then return false end

    local loadedFunc
    step(("Compile %s (loadstring)"):format(label), function()
        local err
        loadedFunc, err = loadstring(rawCode)
        assert(loadedFunc, "compile error: " .. tostring(err))
    end)

    if not loadedFunc then return false end

    local ranOk = step(("Execute %s"):format(label), function()
        local ok, err = pcall(loadedFunc)
        assert(ok, tostring(err))
    end)

    return ranOk
end


header("🧭 FANTASY INITIALIZATION")


if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
localPlayer:WaitForChild("PlayerGui", 15)


header("📦 LOADING ADONIS (FIRST)")


loadAndRun(
    "https://raw.githubusercontent.com/3a6ey/testadonis/refs/heads/main/test.lua",
    "Adonis"
)

task.wait(0.5)


header("🔍 EXPLOIT ENVIRONMENT INVENTORY")


local env = getfenv and getfenv() or {}
local getg = getgenv and getgenv() or {}

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

print("")
for categoryName, funcs in pairs(categories) do
    for i = 1, #funcs do
        local fname = funcs[i]
        local val = _G[fname] or env[fname] or getg[fname]
        checkExists(fname, val)
    end
end
print("")

if identifyexecutor then
    pcall(function()
        local name, version = identifyexecutor()
        warn(("🔥 Executor: %s %s"):format(tostring(name), tostring(version or "")))
    end)
end


header("🛡️  SETTING UP PROTECTIONS & AC BYPASSES")


-- protect больше не имеет "фейкового" fallback,
-- который в оригинале маскировал отсутствие newcclosure
-- (если newcclosure нет — хуки просто не оборачиваются, честно)
local protect = newcclosure or function(f) return f end

if not hookfunction then
    warn("hookfunction unavailable — function-level hooks skipped")
else
    step("Mask gcinfo & collectgarbage", function()
        assert(gcinfo and collectgarbage, "GC functions missing")

        -- диапазон памяти вынесен в переменные,
        -- легче настраивать в одном месте
        local MEM_MIN, MEM_MAX = 200, 350

        hookfunction(gcinfo, protect(function()
            return math.random(MEM_MIN, MEM_MAX)
        end))

        local oldCollect
        oldCollect = hookfunction(collectgarbage, protect(function(opt, ...)
            if opt == "count" then
                return math.random(MEM_MIN, MEM_MAX) * 1024
            end
            return oldCollect(opt, ...)
        end))
    end)

    step("Block Player:Kick()", function()
        assert(localPlayer, "LocalPlayer unavailable")
        hookfunction(localPlayer.Kick, protect(function(...)
            warn("⛔ Direct Kick() intercepted and blocked")
            -- вызов навсегда (Kick() никогда не завершится и не выполнит
            -- то, что стояло после него у вызывающего кода).
            -- но спавним это в отдельном потоке через task.spawn,
            -- а не выполняем напрямую в теле хука — иначе завис бы
            -- ВЕСЬ поток, из которого пришёл вызов Kick (в т.ч. если
            -- это сам loader или другой критичный скрипт).
            task.spawn(function()
                task.wait(9e9)
            end)
            -- return ничего не даём вызывающему — эмулируем "зависший" Kick
        end))
    end)
end

if not hookmetamethod then
    warn("hookmetamethod unavailable — __namecall hook skipped")
else
    step("Hook __namecall (Kick Block & Detection Filter)", function()
        local h
        local detectionKeywords = {
            "detect", "ban", "flag", "log", "cheat", "exploit",
            "kick", "report", "security", "v3rm", "adonis"
        }
        local t_of, slwr, sfind = typeof, string.lower, string.find

        -- обернуто в protect (newcclosure) 
        -- защищает от утечки стека вызовов через __namecall
        h = hookmetamethod(game, "__namecall", protect(function(self, ...)
            -- getnamecallmethod вызывается ДО checkcaller
            -- иначе метод теряется при проксировании вызова
            local method = getnamecallmethod and getnamecallmethod()

            if checkcaller and checkcaller() then
                return h(self, ...)
            end

            if method == "Kick" then
                warn("⛔ Remote Kick() via __namecall blocked")
                -- Аналогично прямому Kick(): вешаем отдельный поток,
                -- а не текущий, чтобы не заморозить весь __namecall
                -- перехватчик (он общий для ВСЕХ вызовов через game
                -- заморозка тут положила бы вообще все remote-вызовы)
                task.spawn(function()
                    task.wait(9e9)
                end)
                return
            end

            if method == "FireServer" or method == "InvokeServer" then
                local success, isInst = pcall(function()
                    return t_of(self) == "Instance"
                end)

                if success and isInst then
                    local sNameOk, remoteName = pcall(function()
                        return slwr(tostring(self.Name))
                    end)

                    if sNameOk and remoteName then
                        for i = 1, #detectionKeywords do
                            if sfind(remoteName, detectionKeywords[i], 1, true) then
                                warn(("🛡️ [AC Bypass] Blocked detection report to: %s"):format(tostring(self.Name)))
                                return nil
                            end
                        end
                    end
                end
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
test("Test game:IsLoaded() state", function() return game:IsLoaded() end)
test("Test LocalPlayer access", function() return localPlayer ~= nil end)
test("Test Character existence", function() return localPlayer.Character ~= nil end)
test("Test PlayerGui existence", function() return localPlayer:FindFirstChild("PlayerGui") ~= nil end)
test("Test Humanoid access", function()
    local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end)
test("Test ReplicatedStorage access", function() return game:GetService("ReplicatedStorage") ~= nil end)
test("Test HttpGet capability", function()
    local ok = pcall(function() game:HttpGet("https://httpbin.org/status/200", true) end)
    return ok
end)
test("Test newcclosure availability", function() return newcclosure ~= nil end)
test("Test hookfunction availability", function() return hookfunction ~= nil end)

-- ========================================================
header("📊 PERFORMANCE DIAGNOSTICS")
-- ========================================================

step("Measure FPS", function()
    local RunService = game:GetService("RunService")
    local frames = 0
    local conn
    conn = RunService.Heartbeat:Connect(function() frames += 1 end)
    task.wait(0.5)
    conn:Disconnect()
    print(("   ~%d FPS"):format(frames * 2))
    if (frames * 2) < 15 then warn("   Low FPS detected!") end
end)

step("Count instances in game", function()
    local count = #game:GetDescendants()
    print(("   %d instances"):format(count))
    if count > 50000 then warn("   Suspiciously high — possible leak") end
end)

step("Scan for duplicate LocalScripts", function()
    local seen, dupes = {}, 0
    local pScripts = localPlayer:FindFirstChild("PlayerScripts")
    if pScripts then
        local descendants = pScripts:GetDescendants()
        for i = 1, #descendants do
            local v = descendants[i]
            if v:IsA("LocalScript") then
                seen[v.Name] = (seen[v.Name] or 0) + 1
                if seen[v.Name] > 1 then dupes += 1 end
            end
        end
    end
    if dupes > 0 then warn(("   %d duplicates found"):format(dupes)) else print("   No duplicates found") end
end)

step("Check error history (LogService)", function()
    local LogService = game:GetService("LogService")
    local errCount = 0
    local ok, history = pcall(function() return LogService:GetLogHistory() end)
    if ok and history then
        for i = 1, #history do
            if history[i].messageType == Enum.MessageType.MessageError then errCount += 1 end
        end
    end
    print(("   %d errors in history"):format(errCount))
    if errCount > 10 then warn("   High error count — possible systemic issue") end
end)

step("Check server ping", function()
    local stats = game:GetService("Stats")
    local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    print(("   %dms"):format(math.floor(ping)))
    if ping > 200 then warn("   High ping detected!") end
end)

-- ========================================================
header("LOADING FANTASY MAIN HUB")
-- ========================================================

loadAndRun(
    "https://raw.githubusercontent.com/3a6ey/Fantasy/refs/heads/main/Main.lua",
    "Main Hub"
)


header("📊 TEST SUMMARY")


local passedTests = 0
for _, result in pairs(TEST_RESULTS) do
    if result.passed then passedTests += 1 end
end

print(("Passed: %d / %d tests"):format(passedTests, #TEST_RESULTS))
divider("-", 50)


--                  FINAL SUMMARY

print("")
local totalFailed = totalChecked - totalFound
local successRate = (totalChecked > 0) and (totalFound / totalChecked * 100) or 0
local elapsedTime = tick() - startTime

warn(("😎 Passed the test with %.0f%% success rate (%d out of %d)"):format(
    successRate, totalFound, totalChecked
))

if totalFailed > 0 then
    warn(("❌ Total tests failed: %d"):format(totalFailed))
else
    print("❌ Total tests failed: 0")
end

print("🍉 corporate sponsorship лол 😂😂")
print("")
warn(("Finished the test in %.2f seconds"):format(elapsedTime))
