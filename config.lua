Config = {}

Config.checkForUpdates = true -- Check for Updates?

-- NEW: pick "qb", "esx", "standalone", or "auto" (detects qb-core/es_extended else standalone)
Config.Framework = "auto"

-- NEW: debug prints in F8
Config.Debug = true

-- Optional: global on-duty rule for QB (ignored on ESX; Standalone ignores job locks)
Config.Elevators_OnDutyOnly = false

Config.Elevators = {
    PillboxElevatorNorth = {
        [1] = {
            coords = vec3(332.37, -595.56, 43.28),
            heading = 70.65,
            title = 'Floor 2',
            description = 'Main Floor',
            target = { width = 5, length = 4 },
            groups = { 'police', 'ambulance' }, -- keep your groups exactly as is
            -- onDutyOnly = true, -- (optional) per-floor override
        },
        [2] = {
            coords = vec3(344.31, -586.12, 28.79),
            heading = 252.84,
            title = 'Floor 1',
            description = 'Lower Floor',
            target = { width = 5, length = 4 },
            -- no groups -> open to everyone
        },
    },
}
