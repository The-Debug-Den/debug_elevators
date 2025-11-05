-- debug_elevators/server.lua

local RESOURCE = GetCurrentResourceName()
local resourceName = "debug_elevators"
if RESOURCE ~= "debug_elevators" then
    resourceName = ("debug_elevators (%s)"):format(RESOURCE)
end

-- version from fxmanifest (index arg required)
local curVersion = GetResourceMetadata(RESOURCE, "version", 0) or "0.0.0"
local GITHUB_API = "https://api.github.com/repos/The-Debug-Den/debug_elevators/releases/latest"
local GITHUB_FALLBACK = "https://github.com/The-Debug-Den/debug_elevators"

-- simple debug print gate
local function dprint(msg)
    if Config and Config.Debug then
        print(("[debug_elevators] %s"):format(msg))
    end
end

---------------------------------------------------------------------
-- Standalone notice (server console, once)
---------------------------------------------------------------------
CreateThread(function()
    Wait(500) -- let config/deps settle
    local forced = (Config and Config.Framework and Config.Framework ~= "auto") and Config.Framework or nil
    local qbStarted  = GetResourceState('qb-core') == 'started'
    local esxStarted = GetResourceState('es_extended') == 'started'
    local effective  = forced or (qbStarted and 'qb') or (esxStarted and 'esx') or 'standalone'

    if effective == 'standalone' then
        print("^3[debug_elevators]^0 Job groups are ^3ignored^0 because framework is ^3Standalone^0.")
    else
        dprint(("framework detected: %s"):format(effective))
    end
end)

---------------------------------------------------------------------
-- Update checker (quiet unless outdated, or Debug=true)
---------------------------------------------------------------------
if Config and Config.checkForUpdates then
    local function GetRepoInformations(cb)
        -- GitHub requires a User-Agent; set minimal headers
        PerformHttpRequest(GITHUB_API, function(code, body, headers)
            if code == 200 and body then
                local ok, data = pcall(json.decode, body)
                if ok and data then
                    local tag  = data.tag_name or curVersion
                    local url  = data.html_url or GITHUB_FALLBACK
                    local desc = data.body or ""
                    return cb(tag, url, desc, code)
                end
            end
            -- fallback path (no hard wait loops, always returns)
            return cb(curVersion, GITHUB_FALLBACK, "", code or 0)
        end, "GET", "", { ["User-Agent"] = "debug_elevators/1.0" })
    end

    local function CheckVersion()
        GetRepoInformations(function(repoVersion, repoURL, repoBody, code)
            if repoVersion ~= curVersion then
                Wait(4000)
                print(("^0[^3WARNING^0] %s is ^1NOT ^0up to date!"):format(resourceName))
                print(("^0[^3WARNING^0] Your Version: ^2%s^0"):format(curVersion))
                print(("^0[^3WARNING^0] Latest Version: ^2%s^0"):format(repoVersion))
                print(("^0[^3WARNING^0] Get the latest Version from: ^2%s^0"):format(repoURL))
                if repoBody and repoBody ~= "" then
                    print("^0[^3WARNING^0] Changelog:^0")
                    print("^1" .. repoBody .. "^0")
                end
            else
                if Config.Debug then
                    Wait(4000)
                    print(("^0[^2INFO^0] %s is up to date! (^2%s^0)"):format(resourceName, curVersion))
                end
            end
        end)
    end

    -- initial check + hourly checks
    CreateThread(function()
        CheckVersion()
        while true do
            Wait(3600000) -- 1 hour
            CheckVersion()
        end
    end)
end
