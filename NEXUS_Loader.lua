local CONFIG = {
    Url = "https://raw.githubusercontent.com/adiii0-0/Nexus-Joiner/main/NEXUS_JOINER_LATEST.lua",
    Folder = "NEXUS",
    CacheFile = "NEXUS/loader_cache.lua",
    LocalFile = "NEXUS/NEXUS_JOINER_LATEST.lua",
    MinSize = 2000,
    Retries = 2,
}

local StarterGui = game:GetService("StarterGui")

local function Notify(Text)
    warn("[NEXUS LOADER] " .. Text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Nexus Utility", Text = Text, Duration = 6 })
    end)
end

local function RequestFunction()
    return (syn and syn.request) or request or http_request or (http and http.request) or (fluxus and fluxus.request)
end

local function Fetch(Url)
    local Full = Url .. (string.find(Url, "?", 1, true) and "&t=" or "?t=") .. tostring(os.time())
    local Ok, Body = pcall(function() return game:HttpGet(Full, true) end)
    if Ok and type(Body) == "string" and #Body >= CONFIG.MinSize then return Body end
    local RF = RequestFunction()
    if RF then
        local ROk, R = pcall(RF, { Url = Full, Method = "GET" })
        if ROk and type(R) == "table" and tonumber(R.StatusCode) == 200 and type(R.Body) == "string" and #R.Body >= CONFIG.MinSize then
            return R.Body
        end
    end
    return nil
end

local function ReadLocal(Path)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    local Ok, Body = pcall(function()
        if isfile(Path) then return readfile(Path) end
        return nil
    end)
    if Ok and type(Body) == "string" and #Body >= CONFIG.MinSize then return Body end
    return nil
end

local function WriteCache(Body)
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(CONFIG.Folder) then
            makefolder(CONFIG.Folder)
        end
        writefile(CONFIG.CacheFile, Body)
    end)
end

local Compile = loadstring or load
if type(Compile) ~= "function" then
    Notify("This executor has no loadstring.")
    return
end

if not game:IsLoaded() then game.Loaded:Wait() end

local Sources = {}
if string.find(CONFIG.Url, "YOUR_", 1, true) then
    warn("[NEXUS LOADER] Url is not set, using the local file.")
else
    Sources[#Sources + 1] = {
        Name = "online",
        Save = true,
        Get = function()
            for Attempt = 1, CONFIG.Retries do
                local Body = Fetch(CONFIG.Url)
                if Body then return Body end
                if Attempt < CONFIG.Retries then task.wait(1) end
            end
            return nil
        end,
    }
end
Sources[#Sources + 1] = { Name = "cached copy", Get = function() return ReadLocal(CONFIG.CacheFile) end }
Sources[#Sources + 1] = { Name = "local file", Get = function() return ReadLocal(CONFIG.LocalFile) end }

local Chunk, Used, Body = nil, nil, nil
for _, Src in ipairs(Sources) do
    local Fetched = Src.Get()
    if Fetched then
        local Fn, Err = Compile(Fetched, "=NexusJoiner")
        if type(Fn) == "function" then
            Chunk, Used, Body = Fn, Src.Name, Fetched
            if Src.Save then WriteCache(Fetched) end
            break
        end
        warn("[NEXUS LOADER] " .. Src.Name .. " did not compile: " .. tostring(Err))
    end
end

if not Chunk then
    Notify("Could not load Nexus Utility. Check the link or put the file in " .. CONFIG.LocalFile)
    return
end

print("[NEXUS LOADER] loading from " .. Used)
local Ok, RuntimeError = pcall(Chunk, Body)
if not Ok then Notify("Nexus Utility error: " .. tostring(RuntimeError)) end
