function AdminUI.OpenAnnouncementConfirmation(title, message)
    if not AdminUI.CanUse('server.announce') then
        AdminUI.NotifyActionDenied()
        return
    end

    local valid, cleanTitle, cleanMessage = AdminAnnouncements.Validate(title, message)
    if not valid then
        Feather.Notify.RightNotify(AdminTranslate('invalid_announcement'), 3000)
        return
    end
    AdminAnnouncements.form.title = cleanTitle
    AdminAnnouncements.form.message = cleanMessage

    local page = AdminUI.RegisterPage('announcement_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_announcement'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('announcement_title'),
            cleanTitle ~= '' and cleanTitle or AdminTranslate('not_available')),
        ('%s: %s'):format(AdminTranslate('announcement_message'), cleanMessage)
    }, '\n'))
    AdminUI.AddButton(page, AdminTranslate('send_announcement'), function()
        if not AdminAnnouncements.Send(cleanTitle, cleanMessage) then
            Feather.Notify.RightNotify(AdminTranslate('announcement_failed'), 3000)
        end
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenAnnouncements)
    AdminUI.OpenPage('announcement_confirmation')
end

function AdminUI.OpenAnnouncements()
    if not AdminUI.CanUse('server.announce') then
        AdminUI.NotifyActionDenied()
        return
    end

    local page = AdminUI.RegisterPage('announcements')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('announcements'))
    AdminUI.AddInput(page, AdminTranslate('announcement_title'), AdminTranslate('optional'), function(data)
        AdminAnnouncements.form.title = data.value
    end, AdminAnnouncements.form.title)
    AdminUI.AddInput(page, AdminTranslate('announcement_message'), AdminTranslate('required'), function(data)
        AdminAnnouncements.form.message = data.value
    end, AdminAnnouncements.form.message)
    AdminUI.AddButton(page, AdminTranslate('continue'), function()
        AdminUI.OpenAnnouncementConfirmation(AdminAnnouncements.form.title, AdminAnnouncements.form.message)
    end)
    AdminUI.AddText(page, AdminTranslate('announcement_help'))
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenNavigationSection('server_operations')
    end)
    AdminUI.OpenPage('announcements')
end

AdminUI.RegisterNavigationItem('server_operations', {
    key = 'announcements',
    labelKey = 'announcements',
    order = 20,
    permission = 'server.announce',
    open = AdminUI.OpenAnnouncements
})
