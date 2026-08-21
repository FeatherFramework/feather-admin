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

    -- Resources displayed on the read-only Server Overview page.
    serverOverview = {
        resources = {
            'feather-core',
            'feather-menu',
            'feather-inventory',
            'feather-character',
            'feather-admin'
        }
    },
    -----------------------------------------------------

    -- Limits and timing for server-wide staff announcements.
    announcements = {
        maxTitleLength = 60,    -- Maximum optional title length.
        maxMessageLength = 300, -- Maximum required message length.
        cooldownSeconds = 30,   -- Delay between announcements from one staff member.
        duration = 8000         -- Time the announcement remains visible in milliseconds.
    },
    -----------------------------------------------------

    -- Player report command, limits, and available categories.
    reports = {
        enabled = true,          -- Set to false to disable player report submission.
        command = 'report',      -- Used in chat as /report <category> <message>.
        cooldownSeconds = 120,   -- Delay between reports from one player.
        maxOpenPerPlayer = 3,    -- Maximum open or claimed reports per account.
        maxMessageLength = 500,  -- Maximum player report length.
        maxResolutionLength = 500, -- Maximum staff closing-resolution length.
        pageLimit = 20,          -- Reports shown on each staff page.
        categories = {
            { value = 'player', labelKey = 'report_category_player' },
            { value = 'bug', labelKey = 'report_category_bug' },
            { value = 'question', labelKey = 'report_category_question' },
            { value = 'other', labelKey = 'report_category_other' }
        }
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
        activeBanLimit = 20,    -- Active bans shown on each browser page.
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

    -- Persistent staff cases created from serious player reports.
    cases = {
        pageLimit = 20,          -- Cases shown on each queue page.
        activityLimit = 20,      -- Recent records available for linking.
        maxTitleLength = 100,    -- Maximum case title length.
        maxSummaryLength = 500,  -- Maximum opening summary length.
        maxResolutionLength = 500,
        priorities = {
            { value = 'normal', labelKey = 'case_priority_normal' },
            { value = 'high', labelKey = 'case_priority_high' },
            { value = 'critical', labelKey = 'case_priority_critical' },
            { value = 'low', labelKey = 'case_priority_low' }
        }
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
