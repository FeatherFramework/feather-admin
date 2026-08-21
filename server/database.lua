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

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_role_changes (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            target_license VARCHAR(100) NOT NULL,
            target_name VARCHAR(100) NULL,
            target_character_id BIGINT UNSIGNED NOT NULL,
            target_character_name VARCHAR(150) NOT NULL,
            old_role_id BIGINT UNSIGNED NOT NULL,
            old_role_name VARCHAR(100) NOT NULL,
            old_role_level INT NOT NULL,
            new_role_id BIGINT UNSIGNED NOT NULL,
            new_role_name VARCHAR(100) NOT NULL,
            new_role_level INT NOT NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id BIGINT UNSIGNED NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_role_changes_character (target_character_id),
            INDEX idx_fa_role_changes_target_license (target_license),
            INDEX idx_fa_role_changes_admin_license (admin_license),
            INDEX idx_fa_role_changes_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_reports (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            reporter_license VARCHAR(100) NOT NULL,
            reporter_name VARCHAR(100) NULL,
            reporter_character_id BIGINT UNSIGNED NULL,
            reporter_character_name VARCHAR(150) NULL,
            category VARCHAR(50) NOT NULL,
            message VARCHAR(500) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'open',
            assigned_admin_license VARCHAR(100) NULL,
            assigned_admin_name VARCHAR(100) NULL,
            assigned_admin_character_id BIGINT UNSIGNED NULL,
            assigned_admin_character_name VARCHAR(150) NULL,
            resolution VARCHAR(500) NULL,
            closed_admin_license VARCHAR(100) NULL,
            closed_admin_name VARCHAR(100) NULL,
            closed_admin_character_id BIGINT UNSIGNED NULL,
            closed_admin_character_name VARCHAR(150) NULL,
            claimed_at DATETIME NULL,
            closed_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_reports_status_created (status, created_at),
            INDEX idx_fa_reports_reporter_status (reporter_license, status),
            INDEX idx_fa_reports_assigned_status (assigned_admin_license, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_cases (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            source_report_id BIGINT UNSIGNED NULL,
            target_license VARCHAR(100) NOT NULL,
            target_name VARCHAR(100) NULL,
            target_character_id BIGINT UNSIGNED NULL,
            target_character_name VARCHAR(150) NULL,
            title VARCHAR(100) NOT NULL,
            summary VARCHAR(500) NOT NULL,
            priority VARCHAR(20) NOT NULL DEFAULT 'normal',
            status VARCHAR(20) NOT NULL DEFAULT 'open',
            created_admin_license VARCHAR(100) NULL,
            created_admin_name VARCHAR(100) NULL,
            created_admin_character_id BIGINT UNSIGNED NULL,
            created_admin_character_name VARCHAR(150) NULL,
            assigned_admin_license VARCHAR(100) NULL,
            assigned_admin_name VARCHAR(100) NULL,
            assigned_admin_character_id BIGINT UNSIGNED NULL,
            assigned_admin_character_name VARCHAR(150) NULL,
            resolution VARCHAR(500) NULL,
            closed_admin_license VARCHAR(100) NULL,
            closed_admin_name VARCHAR(100) NULL,
            closed_admin_character_id BIGINT UNSIGNED NULL,
            closed_admin_character_name VARCHAR(150) NULL,
            claimed_at DATETIME NULL,
            closed_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE INDEX idx_fa_cases_source_report (source_report_id),
            INDEX idx_fa_cases_status_created (status, created_at),
            INDEX idx_fa_cases_target_status (target_license, status),
            INDEX idx_fa_cases_assigned_status (assigned_admin_license, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_case_links (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            case_id BIGINT UNSIGNED NOT NULL,
            link_type VARCHAR(30) NOT NULL,
            link_id BIGINT UNSIGNED NOT NULL,
            label VARCHAR(150) NULL,
            details VARCHAR(500) NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NULL,
            admin_character_id BIGINT UNSIGNED NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE INDEX idx_fa_case_links_unique (case_id, link_type, link_id),
            INDEX idx_fa_case_links_case (case_id, created_at)
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
