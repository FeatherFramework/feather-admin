# Feather Admin Master Plan

This plan keeps Feather Admin organized around the kind of work a staff member is performing. New features should register themselves with the appropriate navigation section instead of adding more hard-coded buttons to the main menu.

Progress is tracked with explicit symbols: `✅` is implemented and `⬜` is still planned. Update this file whenever a roadmap feature is completed or its scope changes.

## Contract 1 identity cutover status

- ✅ Online identity resolves through Core account/session context and the Character profile provider.
- ✅ Persistent staff authority is keyed by Core account UUID.
- ✅ Admin character-reference columns use `CHAR(36)` on clean installs and have an existing-database migration.
- ✅ Online player directory and action auditing preserve UUID Character IDs.
- ✅ Moderation persistence has canonical target/admin account UUID columns and account-based hierarchy helpers.
- ✅ Moderation search, warning, kick, ban, history, unban, and connection-gate handlers use Core accounts and UUID Character snapshots.
- ✅ Moderation contract smoke coverage verifies identity, schema, connection identifiers, fail-closed targeting, and removal of retired joins.
- ✅ Legacy-dependent domains fail closed during migration.
- ✅ Retired numeric Character-table economy and staff-role handlers are removed;
  their dormant UI remains fail-closed pending dedicated providers.
- ✅ Moderation permissions are enabled after the account-contract handler cutover.
- ✅ Reports persistence and handler ownership use reporter/assigned/closing account UUIDs.
- ✅ Report contract and transactional workflow smoke tests pass; `/report` and Player Reports are enabled.
- ✅ Staff Cases use canonical account and Character UUIDs for targets, creators,
  assignments, closures, linked-record actors, hierarchy checks, and activity history.
  Contract, rollback persistence, and live menu workflow tests pass.
- ⬜ Economy and staff-directory workflows return through dedicated providers;
  no legacy Character/User join fallback is permitted.
- ⬜ A dedicated role/policy provider replaces the temporary Admin-owned staff assignment store.

## Navigation Structure

```text
Main Menu
|- Players
|  |- Player Information
|  |- Moderation
|  |- Staff Role
|  |- Teleportation
|  |- Character Management
|  |  |- Balances & Economy
|  |  |- Inventory
|  |  `- Restore Character Appearance
|  `- Player Tools
|     |- Player Status
|     |- Appearance
|     `- Special Effects
|- Server Operations
|  |- Server Overview
|  |- Announcements
|  |- World Controls
|  |- Entity Cleanup
|  `- Resource Health
|- Moderation Center
|  |- Player Reports
|  |- Staff Cases
|  |- Active Bans
|  `- Player Notes
|- Staff & Oversight
|  |- Staff Directory
|  |- Staff Duty
|  |- Staff Chat
|  `- Admin Logs
|- Self Tools
|  |- Travel
|  |- Player Status
|  `- Appearance
`- Developer Tools
   |- Entity Inspector
   |- Bone Viewer
   |- Copy Position
   |- Routing Buckets
   `- Entity Manager
```

Sections with no implemented and permitted entries remain hidden. The navigation registry in `client/ui/navigation.lua` lets each future feature add its own entry without changing the main menu.

## Implementation Rules

Every new action must:

- Have its own numeric permission in `configs/permissions.lua`.
- Be checked again on the server; client visibility is never authorization.
- Respect account hierarchy and the applicable `allowSelf` setting.
- Use Feather Core RPC with a per-source rate limit.
- Validate and normalize every client value on the server.
- Write a durable Admin Log entry for mutations and blocked sensitive actions.
- Return one authoritative result notification to avoid duplicate messages.
- Use a confirmation page for destructive or difficult-to-reverse actions.
- Add translations rather than embedding player-facing text in page code.
- Remain hidden when its dependency or integration is unavailable.

## Phase 1 - Server Operations

- ✅ **Server Overview**
   - Show player count, uptime, OneSync state, and required Feather resource health.
   - Keep the first version read-only.

- ✅ **Announcements**
   - Send a server-wide message with a required message and optional title.
   - Add length limits, cooldowns, confirmation, and durable logging.

- ⬜ **World Controls**
   - Add time and weather controls only through the server's authoritative sync resource.
   - Use an adapter so Feather Admin never competes with another weather script.

- ⬜ **Entity Cleanup**
   - Clean abandoned peds, objects, wagons, or vehicles by explicit category.
   - Show a preview/count and require confirmation before deletion.
   - Exclude player-owned, occupied, mission, and protected entities.

- ⬜ **Detailed Resource Health**
   - Show resource states and dependency failures.
   - Defer resource restart controls until an allowlist and recovery safeguards exist.

## Phase 2 - Moderation Center

- ✅ **Active Ban Browser**
   - Search, page, inspect, and revoke active bans without first locating a character.

- ✅ **Player Reports**
   - Let players submit categorized reports with cooldowns.
   - Staff can claim, release, teleport to, reply to, and close reports.

- ✅ **Staff Cases**
   - Convert serious reports into durable cases linked to the source report, warnings, kicks, bans, and audit rows.
   - ✅ Player Notes appear in account activity and can be linked as durable case evidence; live linking passes.

- ✅ **Player Notes**
   - Store internal notes with author, character, timestamps, and edit history.
   - Separate note permissions from moderation-action permissions.
   - ✅ Account-scoped persistence, hierarchy enforcement, revision-conflict protection,
     immutable edit/archive history, dedicated permissions, and the player-profile UI are implemented.
     Online and offline live workflows pass.

- ⬜ **Optional Sanctions**
   - Add mute or jail only after their owning chat/jail resources expose authoritative APIs.
   - Avoid standalone state that other resources cannot enforce.

## Phase 3 - Player and Character Support

- ✅ **Inventory Inspection and Removal**
   - View inventory, inspect metadata, and remove items with confirmation.
   - Keep the existing Give Item flow as a separate permission.
   - ✅ UUID Character lookup, read-only instance inspection, separate permissions,
     confirmed exact-instance removal, locked ownership validation, and destroy-guard
     enforcement are implemented. Online/offline removal and equipped-weapon veto tests pass.

- ✅ **Weapon and Ammo Support**
   - Integrate through Feather Weapons rather than manipulating loadouts directly.
   - ✅ Readiness and catalog contracts, unique issuance, atomic online/offline
     ammunition grants, separate permissions, confirmations, limits, and auditing
     are implemented. Contract coverage and live online/offline weapon issuance
     and ammunition-grant workflows pass.

- ⬜ **Horse and Wagon Assistance**
   - Find, bring, repair, revive, or dismiss owned entities through their owning resource APIs.

- ⬜ **Character Repair Tools**
   - Add narrowly scoped repairs for known failure states.
   - Avoid broad character resets that can erase legitimate progress.

## Phase 4 - Staff Operations

- ⬜ **Staff Duty**
   - Track on-duty state, duty start/end, and active admin character.
   - Optionally require duty for disruptive actions without making emergency access impossible.

- ⬜ **Staff Chat**
   - Add permission-scoped staff communication with rate limits and audit options.

- ⬜ **Staff Activity Summary**
   - Summarize durable action counts and duty sessions without turning raw counts into performance scores.

- ⬜ **Permission Viewer**
   - Show the current character's role level and available action groups for troubleshooting.

## Phase 5 - Developer and Diagnostics

- ⬜ **Routing Bucket Viewer**
   - Display the current instance and permitted membership information through Feather Core's protected instance API.

- ⬜ **Entity Manager**
   - Inspect nearby entities, ownership, model, network ID, and mission state.
   - Restrict deletion to a separately permitted and confirmed action.

- ⬜ **Zone and Interior Diagnostics**
   - Display zone, interior, room, and coordinate information for resource development.

## Phase 6 - Release Readiness

- ⬜ Add repeatable permission, hierarchy, RPC, database, and navigation tests.
- ⬜ Verify every page's Back route and every main-page Close route.
- ⬜ Complete translation-key and configuration audits after each phase.
- ⬜ Add database migrations for existing installations alongside clean-install schemas.
- ⬜ Document upgrade steps and breaking changes for server owners.
- ⬜ Profile large player directories, audit tables, and moderation searches with realistic data volumes.

## Recommended Build Order

Next, build **Character Repair Tools** through Feather Character's authoritative
profile and appearance contracts. Horse and Wagon Assistance should wait until
their owning resources expose suitable APIs, and World Controls should wait until
its time/weather integration is selected.
