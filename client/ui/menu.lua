AdminUI = {
    Pages = {},
    targetPlayer = nil,
    currentPage = nil,
    toggleStates = {},
    pendingToggles = {},
    nextToggleRequest = 0,
    menuId = nil,
    pageGeneration = 0,
    openSequence = 0
}

AdminUI.Styles = {
    header = { ['color'] = '#999' },
    subheader = { ['font-size'] = '1.778vmin', ['color'] = '#CC9900' },
    text = {
        ['color'] = '#C0C0C0',
        ['font-size'] = '1.481vmin',
        ['font-variant'] = 'small-caps',
        ['line-height'] = '1.8',
        ['white-space'] = 'pre-line',
    },
    button = { ['color'] = '#E0E0E0' }
}

local Menu = exports['feather-menu-v2']

local function RequireMenuResult(result, operation)
    if type(result) ~= 'table' or result.ok ~= true then
        local code = type(result) == 'table' and result.code or 'invalid_result'
        local message = type(result) == 'table' and result.message or 'Menu provider returned an invalid result.'
        error(('[feather-admin] %s failed (%s): %s'):format(operation, tostring(code), tostring(message)), 0)
    end
    return result.value
end

local function ResetMenuState()
    AdminUI.menuId = nil
    AdminUI.Pages = {}
    AdminUI.currentPage = nil
    AdminUI.openSequence = AdminUI.openSequence + 1
end

local function EnsureMenu()
    if AdminUI.menuId then return AdminUI.menuId end

    local created = RequireMenuResult(Menu:CreateMenu({
        key = 'admin',
        draggable = true,
        resizable = true,
        closable = true,
        controller = true,
        position = { x = '22%', y = '50%' },
        size = {
            width = '32rem',
            minWidth = '24rem',
            maxWidth = '92vw',
            maxHeight = '88vh',
            breakpoints = {
                ['720'] = '25rem',
                ['1080'] = '32rem',
                ['1440'] = '36rem',
                ['2160'] = '42rem'
            }
        },
        theme = {
            preset = 'redemption',
            accent = '#CC9900',
            radius = '6px'
        },
        focus = { keyboard = true, cursor = true }
    }), 'create menu')

    AdminUI.menuId = created.menuId
    RequireMenuResult(Menu:RegisterMenuLifecycle(AdminUI.menuId, function(event)
        if event.event == 'opened' or event.event == 'resumed' then
            InMenu = true
            DisplayRadar(false)
        elseif event.event == 'closed' then
            InMenu = false
            DisplayRadar(true)
            AdminUI.targetPlayer = nil
            AdminUI.currentPage = nil
        end
    end), 'register menu lifecycle')

    return AdminUI.menuId
end

local function NextElementKey(page, elementType)
    page.nextElement = page.nextElement + 1
    return ('%s-%s-%d'):format(page.key, elementType, page.nextElement)
end

local function AddElement(page, elementType, settings, callback)
    local menuId = EnsureMenu()
    settings.key = settings.key or NextElementKey(page, elementType)

    local handle
    local wrappedCallback
    if callback then
        wrappedCallback = function(event)
            return callback(event, handle)
        end
    end

    local created = RequireMenuResult(
        Menu:AddElement(menuId, page.id, elementType, settings, wrappedCallback),
        ('add %s element'):format(elementType)
    )
    handle = { id = created.elementId, pageId = page.id }
    function handle:update(changes)
        RequireMenuResult(
            Menu:UpdateElement(EnsureMenu(), self.pageId, self.id, changes),
            ('update %s element'):format(elementType)
        )
    end
    return handle
end

local function NormalizeOptions(options)
    local normalized, originals = {}, {}
    for index, option in ipairs(options or {}) do
        local original = type(option) == 'table' and option or { display = tostring(option), value = option }
        local value = original.value
        if value == nil then value = index end
        normalized[#normalized + 1] = {
            value = value,
            label = tostring(original.label or original.display or value),
            disabled = original.disabled == true
        }
        originals[#originals + 1] = original
    end
    return normalized, originals
end

local function LegacyChoiceCallback(callback, originals)
    if not callback then return nil end
    return function(event, element)
        for _, option in ipairs(originals) do
            if option.value == event.value then
                return callback({ value = option, action = event.action }, element)
            end
        end
    end
end

local function HtmlToText(html)
    return tostring(html or '')
        :gsub('<br%s*/?>', '\n')
        :gsub('</div%s*>', '\n')
        :gsub('<[^>]+>', '')
        :gsub('&quot;', '"')
        :gsub('&#39;', "'")
        :gsub('&lt;', '<')
        :gsub('&gt;', '>')
        :gsub('&amp;', '&')
        :gsub('^%s+', '')
        :gsub('%s+$', '')
        :gsub('[ \t]+\n', '\n')
        :gsub('\n[ \t]+', '\n')
        :gsub('\n\n+', '\n')
end

function AdminUI.RegisterPage(key)
    local menuId = EnsureMenu()
    local previous = AdminUI.Pages[key]
    AdminUI.pageGeneration = AdminUI.pageGeneration + 1
    local pageKey = ('%s-%d'):format(key, AdminUI.pageGeneration)
    local created = RequireMenuResult(Menu:CreatePage(menuId, { key = pageKey }), 'create page')
    local page = { id = created.pageId, key = pageKey, nextElement = 0 }
    AdminUI.Pages[key] = page

    if previous then
        RequireMenuResult(Menu:DestroyPage(menuId, previous.id, page.id), 'replace page')
    end
    return page
end

function AdminUI.AddHeader(page, title, subtitle)
    AddElement(page, 'header', {
        value = title,
        slot = 'header'
    })

    if subtitle then
        AddElement(page, 'subheader', {
            value = subtitle,
            slot = 'header'
        })
    end

    AddElement(page, 'line', { slot = 'header' })
end

function AdminUI.AddButton(page, label, callback, style)
    return AddElement(page, 'button', {
        label = label,
        slot = 'content'
    }, callback)
end

function AdminUI.AddHtmlButton(page, html, callback, style)
    return AddElement(page, 'button', {
        label = HtmlToText(html),
        slot = 'content'
    }, callback)
end

function AdminUI.AddInput(page, label, placeholder, callback, value)
    return AddElement(page, 'input', {
        label = label,
        placeholder = placeholder,
        value = value or '',
        slot = 'content'
    }, callback)
end

function AdminUI.AddDropdown(page, options, placeholder, callback)
    local normalized, originals = NormalizeOptions(options)
    return AddElement(page, 'dropdown', {
        options = normalized,
        value = normalized[1] and normalized[1].value,
        placeholder = placeholder,
        slot = 'content'
    }, LegacyChoiceCallback(callback, originals))
end

function AdminUI.AddText(page, value, style)
    return AddElement(page, 'textdisplay', {
        value = value,
        slot = 'content'
    })
end

function AdminUI.AddLine(page)
    return AddElement(page, 'line', { slot = 'content' })
end

function AdminUI.AddArrows(page, label, options, selectedIndex, callback)
    local normalized, originals = NormalizeOptions(options)
    local selected = originals[(tonumber(selectedIndex) or 0) + 1] or originals[1]
    return AddElement(page, 'arrows', {
        label = label,
        options = normalized,
        value = selected and selected.value,
        slot = 'content'
    }, LegacyChoiceCallback(callback, originals))
end

function AdminUI.AddFooter(page)
    AddElement(page, 'bottomline', { slot = 'footer' })
end

function AdminUI.AddFooterButton(page, label, callback, style)
    return AddElement(page, 'button', {
        label = label,
        slot = 'footer'
    }, callback)
end

function AdminUI.OpenPage(key)
    local page = AdminUI.Pages[key]
    if not page then
        print(('Feather Admin page is not registered: %s'):format(tostring(key)))
        return false
    end

    local menuId = EnsureMenu()
    AdminUI.currentPage = key
    AdminUI.openSequence = AdminUI.openSequence + 1
    local sequence = AdminUI.openSequence
    CreateThread(function()
        local ready = Menu:AwaitReady(5000)
        if type(ready) ~= 'table' or ready.ok ~= true then
            local message = type(ready) == 'table' and ready.message or 'invalid readiness result'
            print(('[feather-admin] menu is not ready: %s'):format(tostring(message)))
            return
        end
        if sequence ~= AdminUI.openSequence or menuId ~= AdminUI.menuId
            or AdminUI.Pages[key] ~= page then return end
        local opened = Menu:OpenMenu(menuId, {
            pageId = page.id,
            keyboard = true,
            cursor = true,
            replace = true
        })
        if type(opened) ~= 'table' or opened.ok ~= true then
            print(('[feather-admin] open menu failed (%s): %s'):format(
                tostring(opened and opened.code), tostring(opened and opened.message)))
        end
    end)

    return true
end

function AdminUI.SetTarget(playerId)
    AdminUI.targetPlayer = tonumber(playerId)
end

function AdminUI.GetTarget()
    return AdminUI.targetPlayer
end

function AdminUI.CanUse(action)
    return AdminPermissions[action] == true
end

function AdminUI.NotifyActionDenied()
    Feather.Notify.RightNotify(AdminTranslate('action_not_permitted'), 3000)
end

function AdminUI.IsSelfTarget(target)
    local targetId = tonumber(target or AdminUI.GetTarget())
    return targetId ~= nil and targetId == GetPlayerServerId(PlayerId())
end

function AdminUI.CanUseOnTarget(action, ...)
    if not AdminUI.CanUse(action) then return false end
    local target
    if select('#', ...) == 0 then
        target = AdminUI.GetTarget()
    else
        target = select(1, ...)
    end
    -- An explicit nil represents an offline target. It must not fall back
    -- to the last live menu target, which may be the acting administrator.
    if target == nil then return true end
    if not AdminUI.IsSelfTarget(target) then return true end

    local hierarchy = type(Config.hierarchy) == 'table' and Config.hierarchy or {}
    local allowSelf = type(hierarchy.allowSelf) == 'table' and hierarchy.allowSelf or {}
    return allowSelf[action] == true
end

function AdminUI.RequireUseOnTarget(action, ...)
    if AdminUI.CanUseOnTarget(action, ...) then return true end

    AdminUI.NotifyActionDenied()
    return false
end

function AdminUI.CanUseAnyAction(actions)
    for _, action in ipairs(actions or {}) do
        if AdminUI.CanUse(action) then return true end
    end
    return false
end

function AdminUI.RequireAnyUseOnTarget(actions, ...)
    for _, action in ipairs(actions or {}) do
        if AdminUI.CanUseOnTarget(action, ...) then return true end
    end
    AdminUI.NotifyActionDenied()
    return false
end

function AdminUI.CanUseAny(prefix)
    for action, allowed in pairs(AdminPermissions) do
        if allowed and action:sub(1, #prefix) == prefix then return true end
    end
    return false
end

function AdminUI.RunAction(label, callback)
    local succeeded = callback()
    if succeeded ~= false then
        Feather.Notify.RightNotify(label, 2000)
    end
    return succeeded
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

function AdminUI.SetToggleState(action, enabled, target)
    local stateTarget = tonumber(target) or AdminUI.GetTarget() or GetPlayerServerId(PlayerId())
    AdminUI.toggleStates[('%s:%s'):format(stateTarget, action)] = enabled == true
end

function AdminUI.RunToggleAction(label, action, element, callback)
    local stateKey = getToggleStateKey(action)
    local enabled = not AdminUI.toggleStates[stateKey]

    callback(enabled)
    AdminUI.toggleStates[stateKey] = enabled
    element:update({ label = AdminUI.GetToggleLabel(label, action) })
end

function AdminUI.RunServerToggleAction(label, action, element, callback)
    local stateKey = getToggleStateKey(action)
    for _, pending in pairs(AdminUI.pendingToggles) do
        if pending.stateKey == stateKey then return false end
    end

    AdminUI.nextToggleRequest = AdminUI.nextToggleRequest + 1
    local requestId = AdminUI.nextToggleRequest
    AdminUI.pendingToggles[requestId] = {
        stateKey = stateKey,
        label = label,
        element = element,
        enabled = not AdminUI.toggleStates[stateKey]
    }
    callback(requestId)

    CreateThread(function()
        Wait(10000)
        AdminUI.pendingToggles[requestId] = nil
    end)
    return true
end

function AdminUI.ResolveServerToggle(requestId, succeeded)
    local pending = AdminUI.pendingToggles[tonumber(requestId)]
    if not pending then return end
    AdminUI.pendingToggles[tonumber(requestId)] = nil
    if succeeded ~= true then return end

    AdminUI.toggleStates[pending.stateKey] = pending.enabled
    pcall(function()
        pending.element:update({
            label = ('%s: %s'):format(pending.label,
                AdminTranslate(pending.enabled and 'status_on' or 'status_off'))
        })
    end)
end

function AdminUI.Close()
    AdminUI.openSequence = AdminUI.openSequence + 1
    if not AdminUI.menuId then return end
    local closed = Menu:CloseMenu(AdminUI.menuId)
    if type(closed) ~= 'table' or closed.ok ~= true then
        print(('[feather-admin] close menu failed (%s): %s'):format(
            tostring(closed and closed.code), tostring(closed and closed.message)))
    end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= 'feather-menu-v2' then return end
    ResetMenuState()
    InMenu = false
    DisplayRadar(true)
end)

function AdminUI.OpenPedParent()
    AdminUI.OpenAppearance()
end
