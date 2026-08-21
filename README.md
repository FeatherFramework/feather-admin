# Feather Admin

Feather Admin adds an in-game admin menu to RedM servers that use the Feather Framework. Its default permissions use numeric staff levels `50`, `75`, and `99`.

## Features

- Browse connected players and search online or offline characters through one Players directory
- Review player capacity, uptime, OneSync mode, and configured Feather resource health
- Send confirmed server-wide announcements with configurable limits and cooldowns
- View character details, economy values, role level, and identifiers
- Teleport to a player, bring them to you, or send them back
- Spectate another player, including players outside normal streaming range
- Kick an online player from the Moderation page with a required reason
- Issue persistent warnings and review moderation history
- Apply permanent or temporary account bans
- See online or offline status directly on player search results
- Revoke active bans from the in-game menu
- Block banned accounts before they enter the server
- Add or remove dollars, gold, tokens, and experience
- Give configured inventory items to online players with quantity and capacity checks
- Restore a player's saved character model, clothing, and appearance
- Use clearly grouped Teleportation, Character Management, Player Tools, and Special Effects pages
- Toggle god mode, invisibility, infinite stamina, and noclip
- Heal or kill a player
- Teleport to a map waypoint
- Automatically teleport when a new waypoint is placed
- Change a player into a configured human or animal model
- Inspect entities and display player bones for development work
- Freeze, cage, handcuff, or remove a player from a vehicle
- Apply several optional player effects
- Open the menu with a key or chat command
- Store admin actions in the database and review them from a paginated Admin Logs page
- Search and filter online or offline characters, assign staff roles with required reasons, and review role-change history
- Filter admin logs by administrator, player, action, or date
- Record admin actions in the server console and optionally Discord

## Dependencies

- `feather-core`
- `feather-menu`
- `feather-inventory`

These resources must already be installed. They also need to start before Feather Admin.

Feather Admin creates its moderation and durable action-audit database tables automatically when the resource starts. No SQL import is required.

## Installation

1. Download Feather Admin.
2. Place its folder inside your server's `resources` folder.
3. Make sure the folder is named `feather-admin`.
4. Make sure `feather-core` and `feather-menu` are also installed.
5. Open your `server.cfg` file with a text editor.
6. Add these lines in this order:

   ```cfg
   ensure feather-core
   ensure feather-menu
   ensure feather-inventory
   ensure feather-admin
   ```

7. Save `server.cfg` and restart your server.

## Permissions

Every menu action has a minimum numeric role level in `configs/permissions.lua`. The default tiers are:

- Level `50` — Moderator: player support, warnings, kicks, spectating, travel, healing, and reviving
- Level `75` — Senior Admin: bans, unbans, identifier searches, item grants, admin-log review, character repair, advanced status tools, appearance tools, and reversible player effects
- Level `99` — Owner: staff role management, economy adjustments, sensitive log details, and the most disruptive special effects

These are numeric checks; the role names are only friendly labels. You can rename the roles without changing permission behavior.

For an existing Feather database, add the two staff levels once:

```sql
INSERT INTO roles (name, level)
SELECT 'moderator', 50
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE level = 50);

INSERT INTO roles (name, level)
SELECT 'senior_admin', 75
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE level = 75);
```

Adjust individual values to fit your staff structure. Keep `menu.open` at or below the lowest staff level that should be able to open the menu.

Buttons a staff member cannot use are hidden. Self-target buttons also follow `configs/hierarchy.lua`. Every request is checked again by the server, so changing the local menu does not grant permission.

Staff also cannot target an account with an equal or higher role level. This hierarchy is configured in `configs/hierarchy.lua`. The active character controls a staff member's authority, while the highest role held anywhere on the target account controls its protection.

If an administrator cannot open the menu, confirm that their active character meets the numeric level configured for `menu.open`.

### Emergency role recovery

The server console can restore a character's role without an active admin character:

```text
featherSetRole <characterId> <roleLevel>
```

To allow a trusted server administrator to run the same command in game, add this ACE permission in `server.cfg`:

```cfg
add_ace group.admin feather.admin.recover allow
```

This ACE permits only the recovery command. It does not grant access to the admin menu on civilian characters. The selected numeric role level must identify exactly one row in the `roles` table.

## Configuration

Most server owners only need to edit `configs/config.lua`. Open it with a text editor to change the following settings:

- `controls.enabled`: turn keyboard access on or off
- `controls.openMenu`: choose the key used to open the menu; the default is `PGDN` (Page Down)
- `commands.enabled`: turn chat-command access on or off
- `commands.openMenu`: change the menu command; the default is `adminMenu`
- `commands.recoverRole`: change the emergency role recovery command
- `commands.recoverAce`: change the ACE permission required for in-game recovery
- `configs/permissions.lua`: choose the minimum numeric role level for every admin action
- `configs/hierarchy.lua`: control staff hierarchy, helpful exemptions, and allowed self-actions
- `logging.webhook`: optionally send admin action logs to a Discord webhook
- `serverOverview.resources`: choose which resources appear on Server Overview
- `announcements`: configure title/message limits, cooldown, and display duration
- `economy.maxAmount`: limit the size of a single balance adjustment
- `inventory.maxGrantQuantity`: limit the quantity in one admin item grant
- `staff.searchLimit`: set the number of offline staff-search results per page
- `staff.historyLimit`: set the number of role-history records per page
- `staff.minSearchLength`: require a minimum staff-search length
- `staff.maxReasonLength`: limit required role-change reasons
- `moderation.searchLimit`: limit offline search results
- `moderation.minSearchLength`: require a minimum offline-search length
- `moderation.historyLimit`: limit the history records shown
- `moderation.maxReasonLength`: set the maximum warning or ban reason length
- `moderation.maxBanMinutes`: set the longest allowed temporary ban
- `moderation.banMessage`: change the message shown to banned players
- `pedChanger.modelLoadTimeout`: set how long the game waits for a player model to load
- `pedChanger.categories`: choose which human and animal models appear in the menu

Only ped models listed in `configs/config.lua` can be used. This prevents players from requesting unapproved models.

## Usage

With the default settings, a staff character at level `50` or higher can open the menu by pressing **Page Down** or entering this command in chat:

```text
/adminMenu
```

Choose **Players** to browse connected players or search all characters by character ID, account name, character name, or complete license identifier. Results show whether each character is online or offline. Online characters expose live actions; offline characters expose database-safe moderation and staff-role tools. Selected-player actions are grouped under Player Information, Moderation, Teleportation, Character Management, Player Tools, and Special Effects.

Open **Character Management**, then **Inventory**, to browse configured item categories, choose an item and quantity, and confirm the grant. Item limits, available slots, and weight are validated by Feather Inventory before anything is added.

Owners can select an online or offline character through **Players**, open **Staff Role**, choose a configured role, enter a required reason, and confirm the change. The Players search includes a role filter, and role history is paginated. Every promotion, demotion, or other role change is stored against the affected character. A role can never be assigned above the acting character's own level. Self-edits and changes to equal- or higher-ranked accounts are blocked; use the emergency recovery command when no eligible owner character is available.

Player searches use prefix matching for names. License searches require the complete `license:` identifier and the `moderation.search_identifiers` permission. Use **Self Tools** for travel, status, and appearance actions that apply to your own character.

Senior staff can open **Staff & Oversight**, then **Admin Logs**, to review durable action records. Choose an action from the categorized action picker, filter completed or blocked attempts, filter names by their beginning, and enter dates as `MM-DD-YYYY`. License identifiers and economy details are visible only to staff with `audit.sensitive` permission.

Staff with `server.announce` permission can open **Server Operations**, then **Announcements**, enter an optional title and required message, review the confirmation page, and send it to every connected player.

Every page has a **Back** button. Use **Close** on the main page or tap **ESC** to exit the menu.

Use **Self Tools** for personal travel, status, and appearance actions. While noclip is active, use `W`/`S` to move forward or backward, `A`/`D` to strafe, `Space`/`Ctrl` to move vertically, `Shift` to change speed, and `Backspace` to exit. A small on-screen panel shows these controls and the current speed.

The remaining feature roadmap and planned navigation layout are documented in `MASTER_PLAN.md`.

## Localization

All English menu text is stored in `translations/en_us.lua`. Server owners who only want to change wording can edit the text on the right side of each entry.

## Common Problems

### The menu does not open

- Confirm that `feather-core`, `feather-menu`, and `feather-admin` are running.
- Confirm that the administrator's active character meets the `permissions['menu.open']` level.
- Check that keyboard or command access is enabled in `configs/config.lua`.

### Feather Admin does not start

- Confirm that the folder is named `feather-admin`.
- Check that the three `ensure` lines are in the correct order in `server.cfg`.
- Look in the server console for the first error shown during startup.

### A ped model does not appear

- Confirm that the model is listed under `pedChanger.categories` in `configs/config.lua`.
- Check the model name for spelling mistakes.

## Development

This resource is under active development. Test new versions on a private or test server before using them on a live server.

For Feather Framework documentation, visit [featherframework.net/api](https://featherframework.net/api).
