--[[
    Nexus Utility loader
    Loads NEXUS_JOINER_LATEST.lua from your link. If the link is not set or is down,
    it falls back to the last copy that worked, then to a file in your executor's workspace.
]]

-- CONFIG
local CONFIG = {
    -- raw link to NEXUS_JOINER_LATEST.lua (GitHub "Raw" button). Leave the YOUR_ words to use the local file only.
    Url = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/NEXUS_JOINER_LATEST.lua",
    Folder = "NEXUS",
    CacheFile = "NEXUS/loader_cache.lua",       -- last copy downloaded successfully
    LocalFile = "NEXUS/NEXUS_JOINER_LATEST.lua", -- put the script here (executor workspace) for offline use
    MinSize = 2000,                              -- anything smaller is treated as a failed download
    Retries = 2,
}

-- SERVICES
local StarterGui = game:GetService("StarterGui")

-- UTILITIES
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

-- LOGIC
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

local Chunk, Used = nil, nil
for _, Src in ipairs(Sources) do
    local Body = Src.Get()
    if Body then
        local Fn, Err = Compile(Body, "=NexusJoiner")
        if type(Fn) == "function" then
            Chunk, Used = Fn, Src.Name
            if Src.Save then WriteCache(Body) end
            break
        end
        warn("[NEXUS LOADER] " .. Src.Name .. " did not compile: " .. tostring(Err))
    end
end

if not Chunk then
    Notify("Could not load Nexus Utility. Check the link or put the file in " .. CONFIG.LocalFile)
    return
end

-- INIT
print("[NEXUS LOADER] loading from " .. Used)
local Ok, RuntimeError = pcall(Chunk)
if not Ok then Notify("Nexus Utility error: " .. tostring(RuntimeError)) end
