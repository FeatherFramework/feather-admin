function MainAdminMenu()
    FeatherAdminMenu:Close({})

    local mainMenuPage = FeatherAdminMenu:RegisterPage("feather-admin:mainMenuPage")
    mainMenuPage:RegisterElement("header", {
        value = "Feather Admin",
        slot = 'header',
        style = {}
    })
    mainMenuPage:RegisterElement("button", {
        label = "Players",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        MainAllPlayersMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = "Developer Tools",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        devToolsMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = "Boosters",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        boostersMenu()
    end)
    mainMenuPage:RegisterElement("button", {
        label = "Teleport",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        teleportsMenu()
    end)

    FeatherAdminMenu:Open({
        startupPage = mainMenuPage
    })
end