AdminDatabase = {
    ready = false,
    callbacks = {}
}

function AdminDatabase.OnReady(callback)
    if type(callback) ~= 'function' then return end
    if AdminDatabase.ready then
        local succeeded, problem = pcall(callback)
        if not succeeded then
            print(('[feather-admin] Database-ready callback failed: %s'):format(tostring(problem)))
        end
        return
    end
    AdminDatabase.callbacks[#AdminDatabase.callbacks + 1] = callback
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_bans (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id INT NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            expires_at DATETIME NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id INT NULL,
            admin_character_name VARCHAR(150) NULL,
            revoked_by VARCHAR(100) NULL,
            revoked_by_character_id INT NULL,
            revoked_by_character_name VARCHAR(150) NULL,
            revoked_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_bans_license_active (license, active),
            INDEX idx_fa_bans_expires (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_warnings (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id INT NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id INT NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_warnings_license (license)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_kicks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id INT NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id INT NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_kicks_license (license)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_actions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NULL,
            admin_character_id INT NULL,
            admin_character_name VARCHAR(150) NULL,
            action VARCHAR(100) NOT NULL,
            target_license VARCHAR(100) NULL,
            target_name VARCHAR(100) NULL,
            target_character_id INT NULL,
            target_character_name VARCHAR(150) NULL,
            details VARCHAR(500) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_actions_admin_license (admin_license),
            INDEX idx_fa_actions_target_license (target_license),
            INDEX idx_fa_actions_action (action),
            INDEX idx_fa_actions_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    AdminDatabase.ready = true
    local callbacks = AdminDatabase.callbacks
    AdminDatabase.callbacks = {}
    for _, callback in ipairs(callbacks) do
        local succeeded, problem = pcall(callback)
        if not succeeded then
            print(('[feather-admin] Database-ready callback failed: %s'):format(tostring(problem)))
        end
    end
end)
