# Feather Admin Master Plan

This plan keeps Feather Admin organized around the kind of work a staff member is performing. New features should register themselves with the appropriate navigation section instead of adding more hard-coded buttons to the main menu.

Progress is tracked with checkboxes: `[x]` is implemented and `[ ]` is still planned. Update this file whenever a roadmap feature is completed or its scope changes.

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

- [x] **Server Overview**
   - Show player count, uptime, OneSync state, and required Feather resource health.
   - Keep the first version read-only.

- [x] **Announcements**
   - Send a server-wide message with a required message and optional title.
   - Add length limits, cooldowns, confirmation, and durable logging.

- [ ] **World Controls**
   - Add time and weather controls only through the server's authoritative sync resource.
   - Use an adapter so Feather Admin never competes with another weather script.

- [ ] **Entity Cleanup**
   - Clean abandoned peds, objects, wagons, or vehicles by explicit category.
   - Show a preview/count and require confirmation before deletion.
   - Exclude player-owned, occupied, mission, and protected entities.

- [ ] **Detailed Resource Health**
   - Show resource states and dependency failures.
   - Defer resource restart controls until an allowlist and recovery safeguards exist.

## Phase 2 - Moderation Center

- [ ] **Active Ban Browser**
   - Search, page, inspect, and revoke active bans without first locating a character.

- [ ] **Player Reports**
   - Let players submit categorized reports with cooldowns.
   - Staff can claim, release, teleport to, reply to, and close reports.

- [ ] **Staff Cases**
   - Convert serious reports into durable cases linked to warnings, kicks, bans, notes, and audit rows.

- [ ] **Player Notes**
   - Store internal notes with author, character, timestamps, and edit history.
   - Separate note permissions from moderation-action permissions.

- [ ] **Optional Sanctions**
   - Add mute or jail only after their owning chat/jail resources expose authoritative APIs.
   - Avoid standalone state that other resources cannot enforce.

## Phase 3 - Player and Character Support

- [ ] **Inventory Inspection and Removal**
   - View inventory, inspect metadata, and remove items with confirmation.
   - Keep the existing Give Item flow as a separate permission.

- [ ] **Weapon and Ammo Support**
   - Integrate through Feather Weapons rather than manipulating loadouts directly.

- [ ] **Horse and Wagon Assistance**
   - Find, bring, repair, revive, or dismiss owned entities through their owning resource APIs.

- [ ] **Character Repair Tools**
   - Add narrowly scoped repairs for known failure states.
   - Avoid broad character resets that can erase legitimate progress.

## Phase 4 - Staff Operations

- [ ] **Staff Duty**
   - Track on-duty state, duty start/end, and active admin character.
   - Optionally require duty for disruptive actions without making emergency access impossible.

- [ ] **Staff Chat**
   - Add permission-scoped staff communication with rate limits and audit options.

- [ ] **Staff Activity Summary**
   - Summarize durable action counts and duty sessions without turning raw counts into performance scores.

- [ ] **Permission Viewer**
   - Show the current character's role level and available action groups for troubleshooting.

## Phase 5 - Developer and Diagnostics

- [ ] **Routing Bucket Viewer**
   - Display the current instance and permitted membership information through Feather Core's protected instance API.

- [ ] **Entity Manager**
   - Inspect nearby entities, ownership, model, network ID, and mission state.
   - Restrict deletion to a separately permitted and confirmed action.

- [ ] **Zone and Interior Diagnostics**
   - Display zone, interior, room, and coordinate information for resource development.

## Phase 6 - Release Readiness

- [ ] Add repeatable permission, hierarchy, RPC, database, and navigation tests.
- [ ] Verify every page's Back route and every main-page Close route.
- [ ] Complete translation-key and configuration audits after each phase.
- [ ] Add database migrations for existing installations alongside clean-install schemas.
- [ ] Document upgrade steps and breaking changes for server owners.
- [ ] Profile large player directories, audit tables, and moderation searches with realistic data volumes.

## Recommended Build Order

Next, build the **Active Ban Browser**. It will exercise the Moderation Center navigation with a database-backed feature before more complex reports or entity cleanup are introduced.
