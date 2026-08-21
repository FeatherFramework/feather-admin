Config = {

    -- Keyboard shortcut used to open the admin menu.
    controls = {
        enabled = true,    -- Set to false to disable the shortcut.
        openMenu = 'PGDN', -- Feather key name; PGDN is Page Down.
    },
    -----------------------------------------------------

    -- Chat command used to open the admin menu.
    commands = {
        enabled = true,                      -- Set to false to disable the command.
        openMenu = 'adminMenu',              -- Used in chat as /adminMenu.
        suggestionKey = 'command_suggestion', -- Translation key for chat help text.
        recoverRole = 'featherSetRole',       -- ACE-protected role recovery command.
        recoverAce = 'feather.admin.recover'  -- ACE required to use role recovery in game.
    },
    -----------------------------------------------------

    -- Admin action logs are always written to the server console.
    logging = {
        webhook = '',                  -- Optional Discord webhook URL.
        webhookName = 'Feather Admin', -- Name shown for Discord messages.
        webhookAvatar = ''             -- Optional image URL.
    },
    -----------------------------------------------------

    -- Limits a single economy adjustment to a safe amount.
    economy = {
        maxAmount = 1000000
    },
    -----------------------------------------------------

    -- Limits the quantity added by one admin item grant.
    inventory = {
        maxGrantQuantity = 100
    },
    -----------------------------------------------------

    -- Limits offline character searches in Staff Management.
    staff = {
        searchLimit = 20,       -- Characters shown on each search page.
        historyLimit = 20,      -- Role changes shown on each history page.
        minSearchLength = 2,    -- Minimum characters required for a search.
        maxReasonLength = 200   -- Maximum required role-change reason length.
    },
    -----------------------------------------------------

    -- Limits and messages used by persistent moderation tools.
    moderation = {
        searchLimit = 25,       -- Maximum offline results shown at once.
        minSearchLength = 2,    -- Minimum characters required for offline search.
        historyLimit = 50,      -- Maximum history records returned at once.
        maxReasonLength = 200,  -- Maximum ban or warning reason length.
        maxBanMinutes = 525600, -- Longest temporary ban (one year); use 0 for permanent.
        banDurations = {        -- Options shown in the ban duration dropdown.
            { label = 'Permanent', minutes = 0 },
            { label = '1 Hour', minutes = 60 },
            { label = '6 Hours', minutes = 360 },
            { label = '1 Day', minutes = 1440 },
            { label = '3 Days', minutes = 4320 },
            { label = '7 Days', minutes = 10080 },
            { label = '30 Days', minutes = 43200 }
        },
        banMessage = 'You are banned from this server.'
    },
    -----------------------------------------------------

    -- Ped models available through the Change Ped Model menu.
    pedChanger = {
        modelLoadTimeout = 10000, -- Maximum loading time in milliseconds.
        categories = {
            {
                labelKey = 'human_peds', -- Category translation key.
                models = {
                    -- labelKey controls the menu text; model is the game model name.
                    { labelKey = 'micah_bell',          model = 'cs_micahbell' },
                    { labelKey = 'dutch_van_der_linde', model = 'cs_dutch' }
                }
            },
            {
                labelKey = 'animal_peds', -- Category translation key.
                models = {
                    { labelKey = 'alligator', model = 'a_c_alligator_02' },
                    { labelKey = 'bear',      model = 'a_c_bear_01' }
                }
            }
        }
    }
}
