Feather = exports['feather-core'].initiate()
FeatherMenu = exports['feather-menu'].initiate()

InMenu = false
ClientAllPlayers = {}
AdminPermissions = {}
AdminPlayerDirectory = {
    query = '',
    results = {},
    selected = nil,
    roles = {},
    roleFilterId = nil
}

AdminStaff = {
    roles = {},
    players = {},
    results = {},
    selectedTarget = nil,
    pendingTarget = nil,
    selectedRole = nil,
    roleFilterId = nil,
    reason = '',
    searchQuery = nil,
    searchPage = 1,
    searchHasNext = false,
    history = {},
    historyPage = 1,
    historyHasNext = false,
    origin = 'online'
}

function AdminTranslate(key)
    return Feather.Locale.translate(0, key)
end
