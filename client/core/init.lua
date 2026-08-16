Feather = exports['feather-core'].initiate()
FeatherMenu = exports['feather-menu'].initiate()

InMenu = false
ClientAllPlayers = {}

function AdminTranslate(key)
    return Feather.Locale.translate(0, key)
end
