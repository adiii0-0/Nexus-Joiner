--[[
    SHELLSHOCK | Loader
    Fetches the hosted (obfuscated) hub and runs it.
    Edit CONFIG.Urls, then host this file or give users the one-liner from the bottom comment.
]]

-- ============================== CONFIG ==============================
local CONFIG = {
    Name = "SHELLSHOCK",

    -- Tried in order. Put your raw script URL first, a mirror second.
    Urls = {
        "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/ShellshockHub.lua",
        -- "https://your-mirror.example/ShellshockHub.lua",
    },

    -- Only run in these places. Leave empty to run anywhere.
    PlaceIds = {},

    CacheBust = true,      -- appends ?t=<time> so CDN caches don't serve an old build
    Retries = 2,           -- extra attempts per URL
    RetryDelay = 1.5,      -- seconds between attempts
    MinLength = 5000,      -- anything shorter is treated as an error page
}

-- ============================== SERVICES ==============================
local StarterGui = game:GetService("StarterGui")

-- ============================== STATE ==============================
local env = (getgenv and getgenv()) or _G

-- ============================== UTILITIES ==============================
local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = CONFIG.Name,
            Text = text,
            Duration = 4,
        })
    end)
end

local function fail(message)
    warn("[" .. CONFIG.Name .. " loader] " .. message)
    notify(message)
end

local function isAllowedPlace()
    if #CONFIG.PlaceIds == 0 then
        return true
    end
    for _, placeId in ipairs(CONFIG.PlaceIds) do
        if game.PlaceId == placeId then
            return true
        end
    end
    return false
end

local function looksValid(body)
    if type(body) ~= "string" or #body < CONFIG.MinLength then
        return false
    end
    local head = string.sub(body, 1, 16)
    if string.sub(head, 1, 1) == "<" or string.sub(head, 1, 4) == "404:" then
        return false
    end
    return true
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and looksValid(body) then
        return body
    end

    local requestFunction = (syn and syn.request) or request or http_request
        or (http and http.request) or (fluxus and fluxus.request)
    if requestFunction then
        local requestOk, response = pcall(requestFunction, { Url = url, Method = "GET" })
        if requestOk and type(response) == "table"
            and response.StatusCode == 200 and looksValid(response.Body) then
            return response.Body
        end
    end

    return nil
end

local function download()
    for _, baseUrl in ipairs(CONFIG.Urls) do
        for attempt = 0, CONFIG.Retries do
            local url = baseUrl
            if CONFIG.CacheBust then
                url = url .. (string.find(url, "?", 1, true) and "&" or "?") .. "t=" .. os.time()
            end

            local body = httpGet(url)
            if body then
                return body
            end

            if attempt < CONFIG.Retries then
                task.wait(CONFIG.RetryDelay)
            end
        end
    end
    return nil
end

-- ============================== LOGIC ==============================
local function main()
    if env.SHELLSHOCK_LOADING then
        return
    end

    if not isAllowedPlace() then
        fail("This game is not supported.")
        return
    end

    if #CONFIG.Urls == 0 or string.find(CONFIG.Urls[1], "YOUR_USER", 1, true) then
        fail("Loader URL is not set.")
        return
    end

    if type(loadstring) ~= "function" then
        fail("Your executor does not support loadstring.")
        return
    end

    env.SHELLSHOCK_LOADING = true

    local body = download()
    if not body then
        env.SHELLSHOCK_LOADING = false
        fail("Download failed. Check your connection and try again.")
        return
    end

    local chunk, compileError = loadstring(body, "=" .. CONFIG.Name)
    if not chunk then
        env.SHELLSHOCK_LOADING = false
        fail("Script failed to compile.")
        warn("[" .. CONFIG.Name .. " loader] " .. tostring(compileError))
        return
    end

    local ok, runtimeError = pcall(chunk)
    env.SHELLSHOCK_LOADING = false

    if not ok then
        fail("Script errored on start.")
        warn("[" .. CONFIG.Name .. " loader] " .. tostring(runtimeError))
    end
end

-- ============================== INIT ==============================
main()

--[[
    One-liner for users (host this loader file, or paste the loader itself):

    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/loader.lua"))()
]]
