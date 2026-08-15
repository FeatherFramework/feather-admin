Feather = exports['feather-core'].initiate()
FeatherMenu = exports['feather-menu'].initiate()

InMenu = false

AdminMenu = FeatherMenu:RegisterMenu('feather-admin:AdminMenu', {
    top = '3%',
    left = '3%',
    ['720width'] = '400px',
    ['1080width'] = '500px',
    ['2kwidth'] = '600px',
    ['4kwidth'] = '800px',
    style = {},
    contentslot = {
        style = {
            ['height'] = '300px',
            ['min-height'] = '300px'
        }
    },
    draggable = true,
    canclose = true
}, {
    opened = function()
        InMenu = true
    end,
    closed = function()
        InMenu = false
    end
})
