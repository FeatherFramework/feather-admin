-- Feather Admin canonical Character UUID cutover for pre-Contract-1 databases.
-- Back up the database, then run once before starting the updated resource.
-- Role data is intentionally not migrated here; feather-roles owns it.

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

CREATE INDEX IF NOT EXISTS `idx_fa_actions_admin_account` ON `feather_admin_actions` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_actions_target_account` ON `feather_admin_actions` (`target_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_bans_account_active` ON `feather_admin_bans` (`account_id`, `active`);
CREATE INDEX IF NOT EXISTS `idx_fa_bans_admin_account` ON `feather_admin_bans` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_warnings_account` ON `feather_admin_warnings` (`account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_warnings_admin_account` ON `feather_admin_warnings` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_kicks_account` ON `feather_admin_kicks` (`account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_kicks_admin_account` ON `feather_admin_kicks` (`admin_account_id`);
CREATE INDEX IF NOT EXISTS `idx_fa_reports_reporter_account` ON `feather_admin_reports` (`reporter_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_reports_assigned_account` ON `feather_admin_reports` (`assigned_admin_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_cases_target_account` ON `feather_admin_cases` (`target_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_cases_assigned_account` ON `feather_admin_cases` (`assigned_admin_account_id`, `status`);
CREATE INDEX IF NOT EXISTS `idx_fa_case_links_admin_account` ON `feather_admin_case_links` (`admin_account_id`);
