-- Feather Admin canonical Character UUID cutover.
-- Back up the database, then run once on an existing installation.

ALTER TABLE `feather_admin_staff_accounts`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_bans`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_warnings`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_kicks`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_actions`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_role_changes`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_reports`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_cases`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `feather_admin_case_links`
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `feather_admin_bans`
    ADD COLUMN IF NOT EXISTS `account_id` CHAR(36) NULL AFTER `id`,
    ADD COLUMN IF NOT EXISTS `admin_account_id` CHAR(36) NULL AFTER `admin_license`,
    ADD COLUMN IF NOT EXISTS `revoked_by_account_id` CHAR(36) NULL AFTER `revoked_by`,
    MODIFY COLUMN `character_id` CHAR(36) NULL,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL,
    MODIFY COLUMN `revoked_by_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_warnings`
    ADD COLUMN IF NOT EXISTS `account_id` CHAR(36) NULL AFTER `id`,
    ADD COLUMN IF NOT EXISTS `admin_account_id` CHAR(36) NULL AFTER `admin_license`,
    MODIFY COLUMN `character_id` CHAR(36) NULL,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_kicks`
    ADD COLUMN IF NOT EXISTS `account_id` CHAR(36) NULL AFTER `id`,
    ADD COLUMN IF NOT EXISTS `admin_account_id` CHAR(36) NULL AFTER `admin_license`,
    MODIFY COLUMN `character_id` CHAR(36) NULL,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_actions`
    ADD COLUMN IF NOT EXISTS `admin_account_id` CHAR(36) NULL AFTER `id`,
    ADD COLUMN IF NOT EXISTS `target_account_id` CHAR(36) NULL AFTER `action`,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL,
    MODIFY COLUMN `target_character_id` CHAR(36) NULL;

CREATE INDEX IF NOT EXISTS `idx_fa_actions_admin_account`
    ON `feather_admin_actions` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_actions_target_account`
    ON `feather_admin_actions` (`target_account_id`);

ALTER TABLE `feather_admin_role_changes`
    MODIFY COLUMN `target_character_id` CHAR(36) NOT NULL,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_reports`
    ADD COLUMN IF NOT EXISTS `reporter_account_id` CHAR(36) NULL AFTER `id`,
    ADD COLUMN IF NOT EXISTS `assigned_admin_account_id` CHAR(36) NULL AFTER `status`,
    ADD COLUMN IF NOT EXISTS `closed_admin_account_id` CHAR(36) NULL AFTER `resolution`,
    MODIFY COLUMN `reporter_character_id` CHAR(36) NULL,
    MODIFY COLUMN `assigned_admin_character_id` CHAR(36) NULL,
    MODIFY COLUMN `closed_admin_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_cases`
    ADD COLUMN IF NOT EXISTS `target_account_id` CHAR(36) NULL AFTER `source_report_id`,
    ADD COLUMN IF NOT EXISTS `created_admin_account_id` CHAR(36) NULL AFTER `status`,
    ADD COLUMN IF NOT EXISTS `assigned_admin_account_id` CHAR(36) NULL AFTER `created_admin_character_name`,
    ADD COLUMN IF NOT EXISTS `closed_admin_account_id` CHAR(36) NULL AFTER `resolution`,
    MODIFY COLUMN `target_character_id` CHAR(36) NULL,
    MODIFY COLUMN `created_admin_character_id` CHAR(36) NULL,
    MODIFY COLUMN `assigned_admin_character_id` CHAR(36) NULL,
    MODIFY COLUMN `closed_admin_character_id` CHAR(36) NULL;

ALTER TABLE `feather_admin_case_links`
    ADD COLUMN IF NOT EXISTS `admin_account_id` CHAR(36) NULL AFTER `details`,
    MODIFY COLUMN `admin_character_id` CHAR(36) NULL;

CREATE INDEX IF NOT EXISTS `idx_fa_bans_account_active`
    ON `feather_admin_bans` (`account_id`, `active`);
CREATE INDEX IF NOT EXISTS `idx_fa_bans_admin_account`
    ON `feather_admin_bans` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_warnings_account`
    ON `feather_admin_warnings` (`account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_warnings_admin_account`
    ON `feather_admin_warnings` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_kicks_account`
    ON `feather_admin_kicks` (`account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_kicks_admin_account`
    ON `feather_admin_kicks` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_reports_reporter_account`
    ON `feather_admin_reports` (`reporter_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_reports_assigned_account`
    ON `feather_admin_reports` (`assigned_admin_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_cases_target_account`
    ON `feather_admin_cases` (`target_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_cases_assigned_account`
    ON `feather_admin_cases` (`assigned_admin_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_case_links_admin_account`
    ON `feather_admin_case_links` (`admin_account_id`);

CREATE TABLE IF NOT EXISTS `feather_admin_player_notes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_account_id` CHAR(36) NOT NULL,
    `target_name` VARCHAR(100) NULL,
    `target_character_id` CHAR(36) NULL,
    `target_character_name` VARCHAR(150) NULL,
    `body` VARCHAR(1000) NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `created_admin_account_id` CHAR(36) NOT NULL,
    `created_admin_name` VARCHAR(100) NULL,
    `created_admin_character_id` CHAR(36) NULL,
    `created_admin_character_name` VARCHAR(150) NULL,
    `updated_admin_account_id` CHAR(36) NOT NULL,
    `updated_admin_name` VARCHAR(100) NULL,
    `updated_admin_character_id` CHAR(36) NULL,
    `updated_admin_character_name` VARCHAR(150) NULL,
    `archived` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_fa_notes_target` (`target_account_id`, `archived`, `created_at`),
    INDEX `idx_fa_notes_creator` (`created_admin_account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `feather_admin_player_note_revisions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `note_id` BIGINT UNSIGNED NOT NULL,
    `revision` INT UNSIGNED NOT NULL,
    `body` VARCHAR(1000) NOT NULL,
    `change_type` VARCHAR(20) NOT NULL,
    `admin_account_id` CHAR(36) NOT NULL,
    `admin_name` VARCHAR(100) NULL,
    `admin_character_id` CHAR(36) NULL,
    `admin_character_name` VARCHAR(150) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `idx_fa_note_revision` (`note_id`, `revision`),
    INDEX `idx_fa_note_revision_actor` (`admin_account_id`),
    INDEX `idx_fa_note_revision_created` (`note_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
