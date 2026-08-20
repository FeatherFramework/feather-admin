Feather = exports['feather-core'].initiate()
FeatherMenu = exports['feather-menu'].initiate()

InMenu = false
ClientAllPlayers = {}
AdminPermissions = {}

AdminStaff = {
    roles = {},
    players = {},
    results = {},
    selectedTarget = nil,
    selectedRole = nil,
    searchQuery = nil,
    origin = 'online'
}

function AdminTranslate(key)
    return Feather.Locale.translate(0, key)
end
