# Feather Admin

Feather Admin adds an in-game admin menu to RedM servers that use the Feather Framework. By default, only characters with numeric role level `99` can open the menu or use its tools.

## Features

- View everyone currently connected to the server
- View character details, economy values, role level, and identifiers
- Teleport to a player, bring them to you, or send them back
- Spectate another player, including players outside normal streaming range
- Kick a player with a required reason
- Issue persistent warnings and review moderation history
- Apply permanent or temporary account bans
- Search for and moderate players who are currently offline
- Revoke active bans from the in-game menu
- Block banned accounts before they enter the server
- Add or remove dollars, gold, tokens, and experience
- Restore a player's saved character model, clothing, and appearance
- Use admin tools on yourself or another player
- Toggle god mode, invisibility, infinite stamina, and noclip
- Heal or kill a player
- Teleport to a map waypoint
- Automatically teleport when a new waypoint is placed
- Change a player into a configured human or animal model
- Inspect entities and display player bones for development work
- Freeze, cage, handcuff, or remove a player from a vehicle
- Apply several optional player effects
- Open the menu with a key or chat command
- Record admin actions in the server console and optionally Discord

## Dependencies

- `feather-core`
- `feather-menu`

These resources must already be installed. They also need to start before Feather Admin.

Feather Admin creates its moderation database tables automatically when the resource starts. No SQL import is required.

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
   ensure feather-admin
   ```

7. Save `server.cfg` and restart your server.

## Permissions

Every menu action has a minimum numeric role level in `configs/permissions.lua`. All actions require level `99` by default, preserving full administrator-only access.

Lower individual values to give junior staff limited access. For example, changing `players.view` to `50` lets level 50 staff view connected players. Keep `menu.open` at or below the lowest staff level that should be able to open the menu.

Buttons a staff member cannot use are hidden. Every player-affecting request is checked again by the server, so changing the local menu does not grant permission.

If an administrator cannot open the menu, confirm that their active character meets the numeric level configured for `menu.open`.

## Configuration

Most server owners only need to edit `config.lua`. Open it with a text editor to change the following settings:

- `controls.enabled`: turn keyboard access on or off
- `controls.openMenu`: choose the key used to open the menu; the default is `PGDN` (Page Down)
- `commands.enabled`: turn chat-command access on or off
- `commands.openMenu`: change the menu command; the default is `adminMenu`
- `configs/permissions.lua`: choose the minimum numeric role level for every admin action
- `logging.webhook`: optionally send admin action logs to a Discord webhook
- `economy.maxAmount`: limit the size of a single balance adjustment
- `moderation.searchLimit`: limit offline search results
- `moderation.historyLimit`: limit the history records shown
- `moderation.maxReasonLength`: set the maximum warning or ban reason length
- `moderation.maxBanMinutes`: set the longest allowed temporary ban
- `moderation.banMessage`: change the message shown to banned players
- `pedChanger.modelLoadTimeout`: set how long the game waits for a player model to load
- `pedChanger.categories`: choose which human and animal models appear in the menu

Only ped models listed in `config.lua` can be used. This prevents players from requesting unapproved models.

## Usage

With the default settings, an authorized administrator can open the menu by pressing **Page Down** or entering this command in chat:

```text
/adminMenu
```

Choose **Players** to select another connected player. Tools opened directly from the main menu apply to the administrator when appropriate.

Every page has a **Back** button. Use **Close** on the main page or tap **ESC** to exit the menu.

## Localization

All English menu text is stored in `translations/en_us.lua`. Server owners who only want to change wording can edit the text on the right side of each entry.

## Common Problems

### The menu does not open

- Confirm that `feather-core`, `feather-menu`, and `feather-admin` are running.
- Confirm that the administrator's active character meets the `permissions['menu.open']` level.
- Check that keyboard or command access is enabled in `config.lua`.

### Feather Admin does not start

- Confirm that the folder is named `feather-admin`.
- Check that the three `ensure` lines are in the correct order in `server.cfg`.
- Look in the server console for the first error shown during startup.

### A ped model does not appear

- Confirm that the model is listed under `pedChanger.categories` in `config.lua`.
- Check the model name for spelling mistakes.

## Development

This resource is under active development. Test new versions on a private or test server before using them on a live server.

For Feather Framework documentation, visit [featherframework.net/api](https://featherframework.net/api).
