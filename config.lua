Config = {

    -- Keyboard shortcut used to open the admin menu.
    controls = {
        enabled = true,    -- Set to false to disable the shortcut.
        openMenu = 'PGDN', -- Feather key name; PGDN is Page Down.
    },

    -- Chat command used to open the admin menu.
    commands = {
        enabled = true,                      -- Set to false to disable the command.
        openMenu = 'adminMenu',              -- Used in chat as /adminMenu.
        suggestionKey = 'command_suggestion' -- Translation key for chat help text.
    },

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
