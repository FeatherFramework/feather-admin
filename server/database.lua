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

local function InitializeDatabase()
    DB.awaitReady()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_audit_outbox (
            event_id VARCHAR(128) NOT NULL PRIMARY KEY, payload MEDIUMTEXT NOT NULL,
            state VARCHAR(16) NOT NULL DEFAULT 'pending', attempt_count INT UNSIGNED NOT NULL DEFAULT 0,
            next_attempt BIGINT NOT NULL DEFAULT 0, lease_owner CHAR(36) NULL, lease_until BIGINT NULL,
            audit_event_id CHAR(36) NULL, last_code VARCHAR(128) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, delivered_at TIMESTAMP NULL,
            INDEX idx_admin_audit_retry (state, next_attempt), INDEX idx_admin_audit_lease (state, lease_until)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_bans (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            account_id CHAR(36) NOT NULL,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id CHAR(36) NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            expires_at DATETIME NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            admin_license VARCHAR(100) NULL,
            admin_account_id CHAR(36) NOT NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id CHAR(36) NULL,
            admin_character_name VARCHAR(150) NULL,
            revoked_by VARCHAR(100) NULL,
            revoked_by_account_id CHAR(36) NULL,
            revoked_by_character_id CHAR(36) NULL,
            revoked_by_character_name VARCHAR(150) NULL,
            revoked_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_bans_account_active (account_id, active),
            INDEX idx_fa_bans_admin_account (admin_account_id),
            INDEX idx_fa_bans_license_active (license, active),
            INDEX idx_fa_bans_expires (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_warnings (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            account_id CHAR(36) NOT NULL,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id CHAR(36) NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_account_id CHAR(36) NOT NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id CHAR(36) NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_warnings_account (account_id),
            INDEX idx_fa_warnings_admin_account (admin_account_id),
            INDEX idx_fa_warnings_license (license)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_kicks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            account_id CHAR(36) NOT NULL,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id CHAR(36) NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_account_id CHAR(36) NOT NULL,
            admin_name VARCHAR(100) NOT NULL,
            admin_character_id CHAR(36) NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_kicks_account (account_id),
            INDEX idx_fa_kicks_admin_account (admin_account_id),
            INDEX idx_fa_kicks_license (license)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_reports (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            reporter_account_id CHAR(36) NOT NULL,
            reporter_license VARCHAR(100) NOT NULL,
            reporter_name VARCHAR(100) NULL,
            reporter_character_id CHAR(36) NULL,
            reporter_character_name VARCHAR(150) NULL,
            category VARCHAR(50) NOT NULL,
            message VARCHAR(500) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'open',
            assigned_admin_account_id CHAR(36) NULL,
            assigned_admin_license VARCHAR(100) NULL,
            assigned_admin_name VARCHAR(100) NULL,
            assigned_admin_character_id CHAR(36) NULL,
            assigned_admin_character_name VARCHAR(150) NULL,
            resolution VARCHAR(500) NULL,
            closed_admin_account_id CHAR(36) NULL,
            closed_admin_license VARCHAR(100) NULL,
            closed_admin_name VARCHAR(100) NULL,
            closed_admin_character_id CHAR(36) NULL,
            closed_admin_character_name VARCHAR(150) NULL,
            claimed_at DATETIME NULL,
            closed_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_reports_reporter_account (reporter_account_id, status),
            INDEX idx_fa_reports_assigned_account (assigned_admin_account_id, status),
            INDEX idx_fa_reports_status_created (status, created_at),
            INDEX idx_fa_reports_reporter_status (reporter_license, status),
            INDEX idx_fa_reports_assigned_status (assigned_admin_license, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_cases (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            source_report_id BIGINT UNSIGNED NULL,
            target_account_id CHAR(36) NOT NULL,
            target_license VARCHAR(100) NOT NULL,
            target_name VARCHAR(100) NULL,
            target_character_id CHAR(36) NULL,
            target_character_name VARCHAR(150) NULL,
            title VARCHAR(100) NOT NULL,
            summary VARCHAR(500) NOT NULL,
            priority VARCHAR(20) NOT NULL DEFAULT 'normal',
            status VARCHAR(20) NOT NULL DEFAULT 'open',
            created_admin_account_id CHAR(36) NOT NULL,
            created_admin_license VARCHAR(100) NULL,
            created_admin_name VARCHAR(100) NULL,
            created_admin_character_id CHAR(36) NULL,
            created_admin_character_name VARCHAR(150) NULL,
            assigned_admin_account_id CHAR(36) NULL,
            assigned_admin_license VARCHAR(100) NULL,
            assigned_admin_name VARCHAR(100) NULL,
            assigned_admin_character_id CHAR(36) NULL,
            assigned_admin_character_name VARCHAR(150) NULL,
            resolution VARCHAR(500) NULL,
            closed_admin_account_id CHAR(36) NULL,
            closed_admin_license VARCHAR(100) NULL,
            closed_admin_name VARCHAR(100) NULL,
            closed_admin_character_id CHAR(36) NULL,
            closed_admin_character_name VARCHAR(150) NULL,
            claimed_at DATETIME NULL,
            closed_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE INDEX idx_fa_cases_source_report (source_report_id),
            INDEX idx_fa_cases_target_account (target_account_id, status),
            INDEX idx_fa_cases_assigned_account (assigned_admin_account_id, status),
            INDEX idx_fa_cases_status_created (status, created_at),
            INDEX idx_fa_cases_target_status (target_license, status),
            INDEX idx_fa_cases_assigned_status (assigned_admin_license, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_case_links (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            case_id BIGINT UNSIGNED NOT NULL,
            link_type VARCHAR(30) NOT NULL,
            link_id VARCHAR(128) NOT NULL,
            label VARCHAR(150) NULL,
            details VARCHAR(500) NULL,
            admin_account_id CHAR(36) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NULL,
            admin_character_id CHAR(36) NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE INDEX idx_fa_case_links_unique (case_id, link_type, link_id),
            INDEX idx_fa_case_links_admin_account (admin_account_id),
            INDEX idx_fa_case_links_case (case_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_player_notes (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            target_account_id CHAR(36) NOT NULL,
            target_name VARCHAR(100) NULL,
            target_character_id CHAR(36) NULL,
            target_character_name VARCHAR(150) NULL,
            body VARCHAR(1000) NOT NULL,
            revision INT UNSIGNED NOT NULL DEFAULT 1,
            created_admin_account_id CHAR(36) NOT NULL,
            created_admin_name VARCHAR(100) NULL,
            created_admin_character_id CHAR(36) NULL,
            created_admin_character_name VARCHAR(150) NULL,
            updated_admin_account_id CHAR(36) NOT NULL,
            updated_admin_name VARCHAR(100) NULL,
            updated_admin_character_id CHAR(36) NULL,
            updated_admin_character_name VARCHAR(150) NULL,
            archived TINYINT(1) NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_notes_target (target_account_id, archived, created_at),
            INDEX idx_fa_notes_creator (created_admin_account_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_player_note_revisions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            note_id BIGINT UNSIGNED NOT NULL,
            revision INT UNSIGNED NOT NULL,
            body VARCHAR(1000) NOT NULL,
            change_type VARCHAR(20) NOT NULL,
            admin_account_id CHAR(36) NOT NULL,
            admin_name VARCHAR(100) NULL,
            admin_character_id CHAR(36) NULL,
            admin_character_name VARCHAR(150) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE INDEX idx_fa_note_revision (note_id, revision),
            INDEX idx_fa_note_revision_actor (admin_account_id),
            INDEX idx_fa_note_revision_created (note_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_chat_conversations (
            conversation_id CHAR(36) NOT NULL PRIMARY KEY,
            target_account_id CHAR(36) NOT NULL,
            assigned_account_id CHAR(36) NOT NULL,
            target_character_name VARCHAR(150) NULL,
            status VARCHAR(16) NOT NULL DEFAULT 'open',
            last_sequence BIGINT UNSIGNED NOT NULL DEFAULT 0,
            closed_by_account_id CHAR(36) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            closed_at TIMESTAMP NULL,
            archived_at TIMESTAMP NULL,
            INDEX idx_fa_chat_target (target_account_id, status),
            INDEX idx_fa_chat_staff (assigned_account_id, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    ]])
    if tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'feather_admin_chat_conversations'
        AND COLUMN_NAME = 'target_character_name']])) == 0 then
        DB.exec('ALTER TABLE feather_admin_chat_conversations ADD COLUMN target_character_name VARCHAR(150) NULL')
    end
    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_chat_messages (
            message_id CHAR(36) NOT NULL PRIMARY KEY,
            conversation_id CHAR(36) NOT NULL,
            author_account_id CHAR(36) NOT NULL,
            submission_id CHAR(36) NOT NULL,
            sequence BIGINT UNSIGNED NOT NULL,
            body TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY idx_fa_chat_submission (conversation_id, author_account_id, submission_id),
            UNIQUE KEY idx_fa_chat_sequence (conversation_id, sequence),
            CONSTRAINT fk_fa_chat_conversation FOREIGN KEY (conversation_id)
                REFERENCES feather_admin_chat_conversations (conversation_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    ]])

    DB.exec([[
        CREATE TABLE IF NOT EXISTS feather_admin_chat_case_links (
            conversation_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id BIGINT UNSIGNED NOT NULL,
            linked_by_account_id CHAR(36) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_fa_chat_internal_case (case_id),
            CONSTRAINT fk_fa_chat_link_conversation FOREIGN KEY (conversation_id)
                REFERENCES feather_admin_chat_conversations (conversation_id),
            CONSTRAINT fk_fa_chat_link_case FOREIGN KEY (case_id)
                REFERENCES feather_admin_cases (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    ]])
    local linkType = DB.value([[SELECT DATA_TYPE FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='feather_admin_case_links' AND COLUMN_NAME='link_id']])
    if linkType ~= 'varchar' then
        DB.exec('ALTER TABLE feather_admin_case_links MODIFY link_id VARCHAR(128) NOT NULL')
    end
    AdminDatabase.ready = true
    local callbacks = AdminDatabase.callbacks
    AdminDatabase.callbacks = {}
    for _, callback in ipairs(callbacks) do
        local succeeded, problem = pcall(callback)
        if not succeeded then
            print(('[feather-admin] Database-ready callback failed: %s'):format(tostring(problem)))
        end
    end
end

CreateThread(function()
    local succeeded, problem = pcall(InitializeDatabase)
    if not succeeded then
        print(('[feather-admin] Database initialization failed: %s'):format(tostring(problem)))
    end
end)
