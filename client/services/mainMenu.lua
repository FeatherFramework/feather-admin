function MainAdminMenu()
    AdminMenu:Close({})

    local mainMenuPage = AdminMenu:RegisterPage("feather-admin:mainMenuPage")
    mainMenuPage:RegisterElement("header", {
        value = AdminTranslate("adminHeader"),
        slot = 'header',
        style = {}
    })
    mainMenuPage:RegisterElement("button", {
        label = AdminTranslate("players"),
        style = {}
    }, function()
        AdminMenu:Close({})
        MainAllPlayersMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = AdminTranslate("developerTools"),
        style = {}
    }, function()
        AdminMenu:Close({})
        devToolsMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = AdminTranslate("boosters"),
        style = {}
    }, function()
        AdminMenu:Close({})
        boostersMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = AdminTranslate("teleport"),
        style = {}
    }, function()
        AdminMenu:Close({})
        teleportsMenu()
    end)

    AdminMenu:Open({
        startupPage = mainMenuPage
    })
end
