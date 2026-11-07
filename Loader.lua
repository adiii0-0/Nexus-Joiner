local CONFIG = {
    Name = "NexusJoiner",
    Urls = {
        "https://raw.githubusercontent.com/adiii0-0/SAE-/main/NexusJoiner.lua",
    },
    PlaceIds = {},
    CacheBust = true,
    Retries = 2,
    RetryDelay = 1.5,
    MinLength = 5000,
    Timeout = 10,
}

local StarterGui = game:GetService("StarterGui")
local env = (typeof(getgenv) == "function" and getgenv()) or _G

local function notify(text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = CONFIG.Name,
            Text = text,
            Duration = duration or 4,
        })
    end)
end

local function fail(message, detail)
    local line = "[" .. CONFIG.Name .. "] " .. message
    if detail then line = line .. " | " .. tostring(detail) end
    warn(line)
    notify(message, 6)
end

local function isAllowedPlace()
    if #CONFIG.PlaceIds == 0 then return true end
    for _, id in ipairs(CONFIG.PlaceIds) do
        if game.PlaceId == id then return true end
    end
    return false
end

local function looksValid(body)
    if type(body) ~= "string" or #body < CONFIG.MinLength then
        return false
    end
    local head = string.sub(body, 1, 16)
    if string.sub(head, 1, 1) == "<" then return false end
    if string.sub(head, 1, 4) == "404:" then return false end
    return true
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and looksValid(body) then return body end

    local requestFunction = (syn and syn.request) or request or http_request
        or (http and http.request) or (fluxus and fluxus.request)

    if requestFunction then
        local requestOk, response = pcall(requestFunction, {
            Url = url,
            Method = "GET",
            Headers = { ["Cache-Control"] = "no-cache" },
        })
        if requestOk and type(response) == "table"
            and response.StatusCode == 200 and looksValid(response.Body) then
            return response.Body
        end
    end

    return nil
end

local function withTimeout(fn, seconds)
    if typeof(task) == "table" and task.delay then
        local done, result = false, nil
        task.spawn(function()
            local ok, v = pcall(fn)
            done, result = true, (ok and v or nil)
        end)
        local elapsed = 0
        while not done and elapsed < seconds do
            elapsed = elapsed + task.wait(0.1)
        end
        return done and result or nil
    end
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function download()
    for _, baseUrl in ipairs(CONFIG.Urls) do
        for attempt = 0, CONFIG.Retries do
            local url = baseUrl
            if CONFIG.CacheBust then
                url = url
                    .. (string.find(url, "?", 1, true) and "&" or "?")
                    .. "t=" .. tostring(os.time())
            end

            local body = withTimeout(function()
                return httpGet(url)
            end, CONFIG.Timeout)

            if body then return body end

            if attempt < CONFIG.Retries then
                task.wait(CONFIG.RetryDelay)
            end
        end
    end
    return nil
end

local function main()
    if env.NEXUSJOINER_LOADING then
        notify("Already loading...", 2)
        return
    end

    if not isAllowedPlace() then
        fail("This game is not supported.")
        return
    end

    if type(loadstring) ~= "function" and type(load) ~= "function" then
        fail("Your executor does not support loadstring/load.")
        return
    end

    env.NEXUSJOINER_LOADING = true

    local body = download()
    if not body then
        env.NEXUSJOINER_LOADING = false
        fail("Download failed. Check your connection.")
        return
    end

    local compile = loadstring or load
    local chunk, compileError = compile(body, "=" .. CONFIG.Name)
    if not chunk then
        env.NEXUSJOINER_LOADING = false
        fail("Compile failed.", compileError)
        return
    end

    local ok, runtimeError = pcall(chunk)
    env.NEXUSJOINER_LOADING = false

    if not ok then
        fail("Runtime error.", runtimeError)
    else
        notify("Loaded successfully.", 3)
    end
end

main()
