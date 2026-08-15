Config = {

    controls = {
        enabled = true,
        openMenu = 'PGDN', -- [pagedown]
    },

    commands = {
        enabled = true,
        openMenu = 'adminMenu',
        suggestion = 'Open the Feather Admin menu'
    },

    pedChanger = {
        modelLoadTimeout = 10000,
        categories = {
            {
                label = 'Human Peds',
                models = {
                    { label = 'Micah Bell', model = 'cs_micahbell' },
                    { label = 'Dutch van der Linde', model = 'cs_dutch' }
                }
            },
            {
                label = 'Animal Peds',
                models = {
                    { label = 'Alligator', model = 'a_c_alligator_02' },
                    { label = 'Bear', model = 'a_c_bear_01' }
                }
            }
        }
    }
}
