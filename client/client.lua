ESX, QBCore = nil, nil
local framework, PlayerData, target
local printedStandaloneNotice = false

local function dprint(msg)
    if Config and Config.Debug then
        print(("[debug_elevators] %s"):format(msg))
    end
end

local function resolveFramework()
    if Config and Config.Framework and Config.Framework ~= "auto" then
        return Config.Framework
    end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

local function pickTarget()
   
    local order = { 'qb-target', 'ox_target', 'qtarget' }
    for _, res in ipairs(order) do
        if GetResourceState(res) == 'started' then return res end
    end
    return nil
end

-- Safe getter for job name
local function getJobName()
    if not PlayerData or not PlayerData.job then return nil end
    return PlayerData.job.name
end

-- Check if floor is allowed for this player under current framework
local function canUseFloor(floorCfg)
    -- no groups means open to all
    if not floorCfg.groups or #floorCfg.groups == 0 then return true end

  if framework == 'standalone' then
    return true
end

    -- QB/ESX: enforce groups
    local job = getJobName()
    if not job then return false end
    for i = 1, #floorCfg.groups do
        if job == floorCfg.groups[i] then
            return true
        end
    end
    return false
end

-- ========= Framework init =========
CreateThread(function()
    if framework then return end

    framework = resolveFramework()
    if framework == 'esx' then
        -- ESX
        ESX = exports.es_extended and exports.es_extended:getSharedObject() or ESX
        if not ESX then
            local sx; TriggerEvent('esx:getSharedObject', function(o) sx = o end); ESX = sx
        end

        PlayerData = ESX and ESX.GetPlayerData() or nil
        while not (PlayerData and PlayerData.job) do
            Wait(100)
            PlayerData = ESX and ESX.GetPlayerData() or nil
        end

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            if xPlayer then PlayerData = xPlayer end
        end)

        RegisterNetEvent('esx:setJob', function(job)
            if not PlayerData then PlayerData = {} end
            PlayerData.job = job
        end)

    elseif framework == 'qb' then
        -- QBCore
        QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or QBCore
        PlayerData = QBCore and QBCore.Functions.GetPlayerData() or nil

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore and QBCore.Functions.GetPlayerData() or PlayerData
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            if not PlayerData then PlayerData = {} end
            PlayerData.job = job
        end)
    else
        -- Standalone: leave PlayerData nil
    end
end)

-- ========= Target init =========
CreateThread(function()
    while not framework do Wait(100) end
    target = pickTarget()
    if target then
        if Config and Config.Debug then
            dprint(("using target: %s"):format(target))
        end
    else
        print("^1[debug_elevators]^0 No target resource found (qb-target / ox_target / qtarget). Zones will not be created.")
    end
end)


-- ========= Teleport =========
AddEventHandler('debug_elevators:goToFloor', function(data)
    local elevator, floor = data.elevator, data.floor
    local cfg = Config.Elevators[elevator] and Config.Elevators[elevator][floor]
    if not cfg then return end

    local coords, heading = cfg.coords, cfg.heading or 0.0
    local ped = cache and cache.ped or PlayerPedId()

    DoScreenFadeOut(1500)
    while not IsScreenFadedOut() do Wait(10) end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    while not HasCollisionLoadedAroundEntity(ped) do Wait(0) end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading)

    Wait(300) -- shorter pause feels snappier; tweak to taste
    DoScreenFadeIn(1500)
end)

-- ========= Feedback =========
AddEventHandler('debug_elevators:noAccess', function()
    -- Use ox_lib notify for players; print is reserved for debug/standalone notice
    if lib and lib.notify then
        lib.notify({
            title = 'No Access',
            description = 'You do not have access to this floor.',
            type = 'error'
        })
    else
        if TriggerEvent then
    TriggerEvent('chat:addMessage', { args = { '^1Elevator', 'No Access: You do not have access to this floor.' } })
else
    dprint("No Access (lib missing and chat:addMessage unavailable)")
end
    end
end)

-- ========= Menu =========
AddEventHandler('debug_elevators:openMenu', function(data)
    local elevator = data.elevator
    local current = data.floor
    local elevatorData = Config.Elevators[elevator]
    if not elevatorData then return end

    local Options = {}
    for k, v in pairs(elevatorData) do
        local isCurrent = (k == current)
        local allowed = canUseFloor(v)

        if isCurrent then
            table.insert(Options, {
                title = ("%s (Current)"):format(v.title or ("Floor "..tostring(k))),
                description = v.description,
                event = '',
            })
        elseif allowed then
            table.insert(Options, {
                title = v.title or ("Floor "..tostring(k)),
                description = v.description,
                event = 'debug_elevators:goToFloor',
                args = { elevator = elevator, floor = k }
            })
        else
            table.insert(Options, {
                title = v.title or ("Floor "..tostring(k)),
                description = v.description,
                event = 'debug_elevators:noAccess'
            })
        end
    end

    if lib and lib.registerContext then
        lib.registerContext({
            id = 'elevator_menu',
            title = 'Elevator Menu',
            options = Options
        })
        lib.showContext('elevator_menu')
    else
        print("[debug_elevators] ox_lib context missing; cannot open menu.")
    end
end)

-- ========= Zone creation (qb-target, qtarget, ox_target) =========
local function createElevatorZone(elevKey, idx, floorCfg)
    local t       = floorCfg.target or {}
    local width   = t.width or 2.0
    local length  = t.length or 2.0
    local height  = t.height or 3.0
    local heading = (t.heading ~= nil and t.heading) or floorCfg.heading or 0.0
    local name    = ("%s:%s"):format(elevKey, idx)

    if target == 'ox_target' then
        -- ox_target: table API + onSelect callback
        if exports.ox_target and exports.ox_target.addBoxZone then
            exports.ox_target:addBoxZone({
                name       = name,
                coords     = floorCfg.coords,
                size       = vec3(length, width, height),  -- length, width, height
                rotation   = heading,
                debug      = false,                        -- set true to visualize
                drawSprite = false,
                options    = {
                    {
                        name     = name .. ':use',
                        icon     = 'fa-solid fa-hand',
                        label    = 'Interact',
                        onSelect = function()
                            TriggerEvent('debug_elevators:openMenu', { elevator = elevKey, floor = idx })
                        end
                    }
                }
            })
        else
            dprint("^1[debug_elevators]^0 ox_target is started but export addBoxZone is missing")
        end

    else
        -- qb-target / qtarget: function signature AddBoxZone(name, coords, length, width, zoneOpts, targetOpts)
        if exports[target] and exports[target].AddBoxZone then
            exports[target]:AddBoxZone(
                name,
                floorCfg.coords,
                length,                   -- length first
                width,                    -- then width
                {
                    name = name,
                    heading = heading,
                    debugPoly = false,
                    minZ = floorCfg.coords.z - 1.5,
                    maxZ = floorCfg.coords.z + 1.5,
                },
                {
                    options = {
                        {
                            event    = 'debug_elevators:openMenu',
                            icon     = 'fa-solid fa-hand',
                            label    = 'Interact',
                            elevator = elevKey,
                            floor    = idx,
                        },
                    },
                    distance = 1.5
                }
            )
        else
            print(("^1[debug_elevators]^0 %s does not expose AddBoxZone"):format(tostring(target)))
        end
    end
end

CreateThread(function()
    -- Wait for framework + target to resolve
    while framework == nil do Wait(100) end
    if not target then
        if Config and Config.Debug then
            print("^1[debug_elevators]^0 No target resource found (qb-target / ox_target / qtarget). Zones will not be created.")
        end
        return
    end

    local count = 0
    for elevKey, floors in pairs(Config.Elevators) do
        for idx, floorCfg in pairs(floors) do
            createElevatorZone(elevKey, idx, floorCfg)
            count = count + 1
        end
    end

    if Config and Config.Debug then
        dprint(("zones registered via %s: %d"):format(target, count))
    end
end)
