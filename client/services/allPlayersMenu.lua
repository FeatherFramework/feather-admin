function MainAllPlayersMenu() --Main all players menu (Menu starts here)
    FeatherAdminMenu:Close({})

    local allPlayersPage = FeatherAdminMenu:RegisterPage("feather-admin:allPlayersPage")
    allPlayersPage:RegisterElement("header", {
        value = "All Players",
        slot = 'header',
        style = {}
    })
    for k, v in pairs(ClientAllPlayers) do
        allPlayersPage:RegisterElement("button", {
            label = 'Player Id: ' .. v,
            style = {}
        }, function()
            FeatherAdminMenu:Close({})
            local selectedPlayerPage = FeatherAdminMenu:RegisterPage("feather-admin:selectedPlayerPage")
            selectedPlayerPage:RegisterElement("header", {
                value = "Selected Player",
                slot = 'header',
                style = {}
            })
            selectedPlayerPage:RegisterElement("button", {
                label = "Boosters",
                style = {}
            }, function()
                FeatherAdminMenu:Close({})
                boostersMenu(v)
            end)
            selectedPlayerPage:RegisterElement("button", {
                label = "Troll",
                style = {}
            }, function()
                FeatherAdminMenu:Close({})
                trollMenu(v)
            end)

            FeatherAdminMenu:Open({
                startupPage = selectedPlayerPage
            })
        end)
    end

    FeatherAdminMenu:Open({
        startupPage = allPlayersPage
    })
end