function MainAllPlayersMenu() --Main all players menu (Menu starts here)
    AdminMenu:Close({})

    local allPlayersPage = AdminMenu:RegisterPage("feather-admin:allPlayersPage")
    allPlayersPage:RegisterElement("header", {
        value = AdminTranslate("allPlayersHeader"),
        slot = 'header',
        style = {}
    })
    for k, v in pairs(ClientAllPlayers) do
        allPlayersPage:RegisterElement("button", {
            label = AdminTranslate("playerId") .. ': ' .. v,
            style = {}
        }, function()
            AdminMenu:Close({})
            local selectedPlayerPage = AdminMenu:RegisterPage("feather-admin:selectedPlayerPage")
            selectedPlayerPage:RegisterElement("header", {
                value = AdminTranslate("selectedPlayerHeader"),
                slot = 'header',
                style = {}
            })
            selectedPlayerPage:RegisterElement("button", {
                label = AdminTranslate("boosters"),
                style = {}
            }, function()
                AdminMenu:Close({})
                boostersMenu(v)
            end)
            selectedPlayerPage:RegisterElement("button", {
                label = AdminTranslate("troll"),
                style = {}
            }, function()
                AdminMenu:Close({})
                trollMenu(v)
            end)

            AdminMenu:Open({
                startupPage = selectedPlayerPage
            })
        end)
    end

    AdminMenu:Open({
        startupPage = allPlayersPage
    })
end
