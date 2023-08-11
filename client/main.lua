CreateThread(function()
    TriggerServerEvent('feather-admin:StorePlayersInfo')
    if Config.Setup.OpenMenu.button then
        while true do
            Wait(5)
            if IsControlJustReleased(0, 0xA5BDCD3C) then
                if not Inmenu then
                    Inmenu = true
                    mainAdminMenu()
                end
            end
        end
    else
        RegisterCommand(Config.Setup.OpenMenu.commandName, function()
            Inmenu = true
            mainAdminMenu()
        end)
    end
end)