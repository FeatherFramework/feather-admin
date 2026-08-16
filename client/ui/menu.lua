AdminUI = {
    Pages = {},
    targetPlayer = nil,
    currentPage = nil,
    toggleStates = {}
}

AdminUI.Styles = {
    header = { ['color'] = '#999' },
    subheader = { ['font-size'] = '1.778vmin', ['color'] = '#CC9900' },
    button = { ['color'] = '#E0E0E0' },
    danger = { ['color'] = '#CC3333' }
}

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
            ['height'] = '350px',
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
        AdminUI.targetPlayer = nil
        AdminUI.currentPage = nil
    end
})

function AdminUI.RegisterPage(key)
    if AdminUI.Pages[key] then
        AdminUI.Pages[key]:UnRegister()
    end

    local page = AdminMenu:RegisterPage(('feather-admin:%s'):format(key))
    AdminUI.Pages[key] = page
    return page
end

function AdminUI.AddHeader(page, title, subtitle)
    page:RegisterElement('header', {
        value = title,
        slot = 'header',
        style = AdminUI.Styles.header
    })

    if subtitle then
        page:RegisterElement('subheader', {
            value = subtitle,
            slot = 'header',
            style = AdminUI.Styles.subheader
        })
    end

    page:RegisterElement('line', { slot = 'header' })
end

function AdminUI.AddButton(page, label, callback, style)
    return page:RegisterElement('button', {
        label = label,
        slot = 'content',
        style = style or AdminUI.Styles.button
    }, callback)
end

function AdminUI.AddFooter(page)
    page:RegisterElement('bottomline', {
        slot = 'footer',
        style = {}
    })
end

function AdminUI.AddFooterButton(page, label, callback, style)
    page:RegisterElement('line', {
        slot = 'footer',
        style = {}
    })

    local button = page:RegisterElement('button', {
        label = label,
        slot = 'footer',
        style = style or AdminUI.Styles.button
    }, callback)

    page:RegisterElement('line', {
        slot = 'footer',
        style = {}
    })

    return button
end

function AdminUI.OpenPage(key)
    local page = AdminUI.Pages[key]
    if not page then
        print(('Feather Admin page is not registered: %s'):format(tostring(key)))
        return false
    end

    AdminUI.currentPage = key
    AdminMenu:Open({
        startupPage = page,
        menuFocus = true,
        cursorFocus = true,
        overrideMenu = true,
        allowKeys = true
    })

    return true
end

function AdminUI.SetTarget(playerId)
    AdminUI.targetPlayer = tonumber(playerId)
end

function AdminUI.GetTarget()
    return AdminUI.targetPlayer
end

function AdminUI.RunAction(label, callback)
    callback()
    Feather.Notify.Notify(label, 2000)
end

local function getToggleStateKey(action)
    local target = AdminUI.GetTarget() or GetPlayerServerId(PlayerId())
    return ('%s:%s'):format(target, action)
end

function AdminUI.GetToggleLabel(label, action)
    local enabled = AdminUI.toggleStates[getToggleStateKey(action)]
    if enabled == nil then return label end
    return ('%s: %s'):format(label, AdminTranslate(enabled and 'status_on' or 'status_off'))
end

function AdminUI.RunToggleAction(label, action, element, callback)
    local stateKey = getToggleStateKey(action)
    local enabled = not AdminUI.toggleStates[stateKey]

    callback(enabled)
    AdminUI.toggleStates[stateKey] = enabled
    element:update({ label = AdminUI.GetToggleLabel(label, action) })
end

function AdminUI.Close()
    AdminMenu:Close({})
end

function AdminUI.OpenPedParent()
    local selfId = GetPlayerServerId(PlayerId())
    AdminUI.OpenBoosters(AdminUI.GetTarget() == selfId)
end
